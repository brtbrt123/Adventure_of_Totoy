"""Cut the depth occluders out of the painted scene grounds (village, forest route, Stag glade, arena).

Every tall prop in the paintings (gates, pillars, trunks, stones, pedestals, house walls, ...) is part of the flat ground
picture, so an actor standing BEHIND one (his feet north of the prop's base) used to be drawn over it. An occluder is the
part of a prop that rises above its base, cut out of the ground with hard alpha: presentation draws it again, in the
actors' y-sorted list with the sort key `base_y`, so it covers every actor whose feet are north of the base and stays
under every actor south of it (presentation/common/depth_occluders.gd).

Input: presentation/common/depth_occluders.json (hand-authored, one table per scene):
  scenes.<scene>.ground          the ground PNG (project-relative)
  scenes.<scene>.trim_symbols    palette symbols that always count as floor (grass, dirt, ...)
  scenes.<scene>.keep_symbols    palette symbols never floor (default "0", the ink outline)
  scenes.<scene>.ground_cover / ring / leak_guard / min_part   refinement settings (see cut_mask)
  scenes.<scene>.occluders[]     {id, base_y, poly: [[x, y], ...], refine?, keep?, leak_guard?, min_part?, hide_when?,
                                  note?}
    poly     a polygon in ground pixels, tight around the part of the prop above its base (a pixel is cut when its
             centre is inside)
    base_y   where the prop meets the ground: actors with feet y < base_y are behind it
    refine   (default true) the polygon is refined so only the prop is left: the floor colours around it are found
             (ground_set), floor pixels connected to the polygon's edge are dropped (with a leak guard so moss on the
             prop stays), small stray parts and single pixels go, pinholes fill (cut_mask). "keep" lists symbols that
             are never floor for this occluder (e.g. a brown trunk on brown dirt).
    hide_when  optional scene flag ("gate_open"): the occluder is not drawn while the flag is set
Output (per scene): presentation/common/occluders/<scene>_occluders.png (an atlas: every occluder's pixels copied from
the ground, everything else fully transparent) and <scene>_occluders.json ({scene, texture, occluders: [{id, base_y,
rect: [x, y, w, h] in the world, atlas: [x, y], pixels, ground_share (the share of floor-like pixels left, see
ground_like_share; tests/test_depth_occluders.py keeps it small), hide_when}]}).

Checks (exit 1 on a problem): every polygon inside the ground, at least 1 pixel cut, base_y not above the polygon's top,
unique ids, every cut pixel an opaque palette colour (the grounds are palette-only).
Deterministic: same input = byte-identical output.

Run from the project root:  python tools/art/make_depth_occluders.py [--preview DIR] [--scene NAME] [--out DIR]
After a change run Godot's import (AGENTS.md section 6) so the game loads the new atlas, then look at the scenes.
--preview writes <scene>_occluders_check.png into DIR: the ground 3x with the cut pixels tinted magenta, the polygons
outlined and the base lines red (for authoring; not committed).
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
TABLE = ROOT / "presentation" / "common" / "depth_occluders.json"
OUT_DIR = ROOT / "presentation" / "common" / "occluders"
ATLAS_WIDTH = 512
PAD = 1
PREVIEW_ZOOM = 3


def point_in_polygon(x: float, y: float, poly: list[tuple[float, float]]) -> bool:
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))


def polygon_mask(ground: Image.Image, occ: dict) -> set[tuple[int, int]]:
    """The pixels whose centre is inside the occluder's hand polygon."""
    poly = [(float(p[0]), float(p[1])) for p in occ["poly"]]
    x0 = max(0, int(min(p[0] for p in poly)))
    x1 = min(ground.width - 1, int(max(p[0] for p in poly)) + 1)
    y0 = max(0, int(min(p[1] for p in poly)))
    y1 = min(ground.height - 1, int(max(p[1] for p in poly)) + 1)
    mask: set[tuple[int, int]] = set()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if point_in_polygon(x + 0.5, y + 0.5, poly):
                mask.add((x, y))
    return mask


def ground_set(ground: Image.Image, symbol_of: dict, mask: set[tuple[int, int]], scene: dict, occ: dict) -> set[str]:
    """The palette symbols of the floor around the prop: the most frequent symbols of the ring (1..`ring` px outside
    the polygon) that together cover `ground_cover` of it, plus the scene's trim_symbols, minus the keep symbols (the
    ink outline by default, the scene's keep_symbols, the occluder's own "keep")."""
    px = ground.load()
    ring: set[tuple[int, int]] = set()
    edge = set(mask)
    for _ in range(int(scene.get("ring", 3))):
        grown = set()
        for (x, y) in edge:
            for dx, dy in N8:
                q = (x + dx, y + dy)
                if q not in mask and q not in ring and 0 <= q[0] < ground.width and 0 <= q[1] < ground.height:
                    grown.add(q)
        ring |= grown
        edge = grown
    counts: dict[str, int] = {}
    for q in ring:
        sym = symbol_of.get(px[q][:3], "")
        counts[sym] = counts.get(sym, 0) + 1
    total = max(1, sum(counts.values()))
    chosen: set[str] = set()
    acc = 0
    for sym, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        if acc >= total * float(scene.get("ground_cover", 0.85)):
            break
        chosen.add(sym)
        acc += n
    chosen |= set(scene.get("trim_symbols", ""))
    chosen -= set(scene.get("keep_symbols", "0")) | set(occ.get("keep", ""))
    return chosen


def ground_like_share(ground: Image.Image, symbol_of: dict, pixels: set[tuple[int, int]], floor: set[str]) -> float:
    """The share of an occluder's pixels that look like floor: a floor symbol with at least 6 of its 8 neighbours floor
    symbols too (a patch of grass / dirt texture, not a moss fleck or an outline pixel on the prop)."""
    if not pixels:
        return 0.0
    px = ground.load()

    def sym(q: tuple[int, int]) -> str:
        if 0 <= q[0] < ground.width and 0 <= q[1] < ground.height:
            return symbol_of.get(px[q][:3], "")
        return ""

    n = 0
    for (x, y) in pixels:
        if sym((x, y)) in floor and sum(1 for dx, dy in N8 if sym((x + dx, y + dy)) in floor) >= 6:
            n += 1
    return n / len(pixels)


def cut_mask(ground: Image.Image, symbol_of: dict, occ: dict, scene: dict) -> tuple[set[tuple[int, int]], set[str]]:
    """The occluder's pixels: the hand polygon, refined (unless "refine": false) so only the prop is left:
    1. the floor symbols around the prop (ground_set);
    2. a flood from the polygon's edge through floor pixels drops them; the flood only enters a floor pixel with at
       least `leak_guard` of its 8 neighbours floor (or outside the polygon), so it cannot slip through a 1-2 px gap in
       the prop's outline into moss or grass painted ON the prop (the hand polygon is the other guard);
    3. only connected prop parts of at least `min_part` px stay (stray floor specks go);
    4. single pixels with at most one prop neighbour go, pinholes (a dropped pixel with 3+ prop neighbours of 4) fill.
    Returns (pixels, the floor symbols used)."""
    mask = polygon_mask(ground, occ)
    floor = ground_set(ground, symbol_of, mask, scene, occ)
    if not occ.get("refine", True) or not mask:
        return mask, floor
    px = ground.load()
    guard = int(occ.get("leak_guard", scene.get("leak_guard", 5)))

    def is_floor(q: tuple[int, int]) -> bool:
        return symbol_of.get(px[q][:3], "") in floor

    def floor_neighbours(q: tuple[int, int]) -> int:
        return sum(1 for dx, dy in N8 if (q[0] + dx, q[1] + dy) not in mask or is_floor((q[0] + dx, q[1] + dy)))

    dropped: set[tuple[int, int]] = set()
    queue: deque = deque()
    for q in sorted(mask):
        if any((q[0] + dx, q[1] + dy) not in mask for dx, dy in N4) and is_floor(q) and floor_neighbours(q) >= guard:
            dropped.add(q)
            queue.append(q)
    while queue:
        p = queue.popleft()
        for dx, dy in N4:
            q = (p[0] + dx, p[1] + dy)
            if q in mask and q not in dropped and is_floor(q) and floor_neighbours(q) >= guard:
                dropped.add(q)
                queue.append(q)
    prop = mask - dropped
    # connected parts (8-neighbour); keep those of at least min_part pixels
    min_part = int(occ.get("min_part", scene.get("min_part", 12)))
    seen: set[tuple[int, int]] = set()
    kept: set[tuple[int, int]] = set()
    for start in sorted(prop):
        if start in seen:
            continue
        part = [start]
        seen.add(start)
        i = 0
        while i < len(part):
            p = part[i]
            i += 1
            for dx, dy in N8:
                q = (p[0] + dx, p[1] + dy)
                if q in prop and q not in seen:
                    seen.add(q)
                    part.append(q)
        if len(part) >= min_part:
            kept.update(part)
    prop = kept
    # single-pixel noise and pinholes
    prop = {q for q in prop if sum(1 for dx, dy in N4 if (q[0] + dx, q[1] + dy) in prop) >= 2}
    holes = {q for q in mask - prop if sum(1 for dx, dy in N4 if (q[0] + dx, q[1] + dy) in prop) >= 3}
    return prop | holes, floor


def build_scene(name: str, scene: dict, palette: artlib.Palette, preview: Path | None, out_dir: Path = OUT_DIR) -> list[str]:
    problems: list[str] = []
    ground = Image.open(ROOT / scene["ground"]).convert("RGBA")
    symbol_of = {rgb: sym for sym, rgb in palette.by_symbol.items()}
    entries = []
    ids: set[str] = set()
    for occ in scene["occluders"]:
        oid = occ["id"]
        if oid in ids:
            problems.append(f"{name}: duplicate occluder id {oid}")
        ids.add(oid)
        poly = occ["poly"]
        if len(poly) < 3:
            problems.append(f"{name}/{oid}: a polygon needs at least 3 points")
            continue
        if any(p[0] < 0 or p[1] < 0 or p[0] > ground.width or p[1] > ground.height for p in poly):
            problems.append(f"{name}/{oid}: polygon outside the {ground.width}x{ground.height} ground")
        if occ["base_y"] < min(p[1] for p in poly):
            problems.append(f"{name}/{oid}: base_y {occ['base_y']} is above the polygon's top")
        mask, floor = cut_mask(ground, symbol_of, occ, scene)
        if not mask:
            problems.append(f"{name}/{oid}: no pixel cut")
            continue
        xs = [p[0] for p in mask]
        ys = [p[1] for p in mask]
        rect = (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)
        share = ground_like_share(ground, symbol_of, mask, floor)
        entries.append({"occ": occ, "mask": mask, "rect": rect, "ground_share": share})
    # shelf packing in the order of the table (deterministic)
    x = y = shelf = 0
    for e in entries:
        w, h = e["rect"][2], e["rect"][3]
        if x + w + PAD > ATLAS_WIDTH:
            x = 0
            y += shelf + PAD
            shelf = 0
        e["atlas"] = (x, y)
        x += w + PAD
        shelf = max(shelf, h)
    atlas_h = max(1, y + shelf)
    atlas = Image.new("RGBA", (ATLAS_WIDTH, atlas_h), (0, 0, 0, 0))
    gpx = ground.load()
    apx = atlas.load()
    out = []
    for e in entries:
        rx, ry = e["rect"][0], e["rect"][1]
        ax, ay = e["atlas"]
        for (px_, py_) in sorted(e["mask"]):
            c = gpx[px_, py_]
            if c[3] != 255 or c[:3] not in palette.rgb_set:
                problems.append(f"{name}/{e['occ']['id']}: pixel {px_},{py_} is not an opaque palette colour")
                break
            apx[ax + px_ - rx, ay + py_ - ry] = c
        occ = e["occ"]
        out.append({"id": occ["id"], "base_y": occ["base_y"], "rect": list(e["rect"]), "atlas": [ax, ay],
                    "pixels": len(e["mask"]), "ground_share": round(e["ground_share"], 4),
                    "hide_when": occ.get("hide_when", "")})
    out_dir.mkdir(parents=True, exist_ok=True)
    png = out_dir / f"{name}_occluders.png"
    atlas.save(png, optimize=False)
    texture = "res://" + (OUT_DIR / png.name).relative_to(ROOT).as_posix()
    manifest = {"scene": name, "ground": "res://" + scene["ground"], "texture": texture, "occluders": out}
    with open(out_dir / f"{name}_occluders.json", "w", newline="\n", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=1)
        fh.write("\n")
    print(f"{name}: {len(out)} occluders, {sum(o['pixels'] for o in out)} pixels, atlas {ATLAS_WIDTH}x{atlas_h}")
    if preview is not None:
        write_preview(name, ground, entries, preview)
    return problems


def write_preview(name: str, ground: Image.Image, entries: list[dict], folder: Path) -> None:
    z = PREVIEW_ZOOM
    img = ground.convert("RGB")
    px = img.load()
    for e in entries:
        for (x, y) in e["mask"]:
            r, g, b = px[x, y]
            px[x, y] = ((r + 255) // 2, g // 2, (b + 255) // 2)
    img = img.resize((img.width * z, img.height * z), Image.NEAREST)
    d = ImageDraw.Draw(img)
    for e in entries:
        occ = e["occ"]
        pts = [(p[0] * z, p[1] * z) for p in occ["poly"]]
        d.line(pts + [pts[0]], fill=(255, 255, 0), width=1)
        xs = [p[0] for p in occ["poly"]]
        d.line([(min(xs) * z, occ["base_y"] * z), (max(xs) * z, occ["base_y"] * z)], fill=(255, 0, 0), width=2)
        d.text((min(xs) * z + 2, min(p[1] for p in occ["poly"]) * z + 2), occ["id"], fill=(255, 255, 255))
    folder.mkdir(parents=True, exist_ok=True)
    img.save(folder / f"{name}_occluders_check.png")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--preview", type=Path, default=None, help="write <scene>_occluders_check.png into this folder")
    ap.add_argument("--scene", default="", help="only this scene")
    ap.add_argument("--out", type=Path, default=OUT_DIR, help="output folder (tests write elsewhere and compare)")
    args = ap.parse_args()
    palette = artlib.load_palette()
    table = json.loads(TABLE.read_text(encoding="utf-8"))
    problems: list[str] = []
    for name, scene in table["scenes"].items():
        if args.scene and name != args.scene:
            continue
        problems += build_scene(name, scene, palette, args.preview, args.out)
    for p in problems:
        print("PROBLEM: " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
