"""Rootcrown v2, the chapter 1 final map (docs/FINAL_SCENE_chapter1.md): the art and the map data the owner approved as pictures on
2026-11-26 ("Yes, looks right") become the game's.

    python tools/art/make_rootcrown_art.py
    # then: validate_art.py, build_art.py, preview_art.py; tools/godot/generate_prop_scenes.py (restore the hollow_trial_*
    # prop scenes it reformats); tools/godot/generate_map_scenes.py --only rootcrown_layered --reset; bake_maps.gd

The first build (2026-11-09, cut from a new Higgsfield painting, 640x360) was rejected in the owner's playtest; it is in git
history (commit d002faac). v2 is made from the other forest scenes' own art:
  Floor   docs/previews/rootcrown_v2/floor.png, stitched by tools/art/make_rootcrown_v2_preview.py from the Root Hollow,
          Woodland Approach and Hollow Trial floor pixels (tools/art/quilt_ground.py) -> presentation/forest/rootcrown_layered_ground.png
          (1024x720), checked to be in Totoy 36 without the reserved colours.
  Tower   art/reference/rootcrown_v2/tower_dark.png and tower_lit.png (tools/art/make_rootcrown_tower.py) -> art/src
          rootcrown_tower_dark/lit.txt (padded on the right to 128x152, anchor at the feet), one state pair, data/props/
          prop_defs_rootcrown.json (w, h = the unpadded 123x152, the padding trimmed in prop_art.json, as the village walls);
          each state's moonlight cast shadow fx_shadow_<type>_1 (+ _flipped_1, both cast by the unlit silhouette: the flame
          casts none) and contact shadow in presentation/common/prop_art.json and art/reference/shadow_layers/manifest.json,
          like tools/art/make_village_walls.py.
  Props   every other prop is an existing forest prop; the 12 first-build props (rootcrown_stone_*, _lantern_*, _rubble_*,
          _roots_*, _briars_*) are removed (art/src, art/build/sprites, presentation/props).
  Map     data/scenes/rootcrown_layered_props.json from the approved layout (make_rootcrown_v2_preview.py: the prop list, the
          tower, the entry, exit and checkpoint); the walkable outline is traced from the floor's own dirt (the clearing, the
          tower's forecourt and grass mound, the climb in), so the hero walks where the ground is earth.
"""
from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import make_rootcrown_v2_preview as v2  # noqa: E402
from make_village_walls import INK, PAD, cast_shadow, contact_shadow  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
REF = ROOT / "art" / "reference" / "rootcrown_v2"
FLOOR_SRC = ROOT / "docs" / "previews" / "rootcrown_v2" / "floor.png"
FLOOR = ROOT / "presentation" / "forest" / "rootcrown_layered_ground.png"
DEFS = ROOT / "data" / "props" / "prop_defs_rootcrown.json"
ART = ROOT / "presentation" / "common" / "prop_art.json"
SHADOW = ROOT / "art" / "reference" / "shadow_layers" / "manifest.json"
SCENE = ROOT / "data" / "scenes" / "rootcrown_layered_props.json"
TOWER_PAIR = ("rootcrown_tower_dark", "rootcrown_tower_lit")
## The tower's stone body only (measured on tower_dark.png: the drum spans x 30..92 above its base, anchor x 63); its roots,
## shed stones and ferns stay walkable.
TOWER_COLLIDERS = [[-22.0, -14.0, 10.0], [-8.0, -16.0, 11.0], [6.0, -16.0, 11.0], [20.0, -14.0, 10.0]]
NOTES = {
    "rootcrown_tower_dark": "the forest beacon, dark, crowned by the Colossus's roots; lit once the guardian falls (state pair)",
    "rootcrown_tower_lit": "the forest beacon lit: a blue-white flame in its broken top, blue light in its crack (state pair)",
}
OLD = ["rootcrown_stone_1", "rootcrown_stone_2", "rootcrown_stone_3", "rootcrown_lantern_1", "rootcrown_lantern_2",
       "rootcrown_rubble_1", "rootcrown_rubble_2", "rootcrown_roots_1", "rootcrown_roots_2", "rootcrown_roots_3",
       "rootcrown_briars_1", "rootcrown_briars_2"]


def pad8(n: int) -> int:
    return (n + 7) // 8 * 8


def install_floor() -> None:
    floor = Image.open(FLOOR_SRC).convert("RGB")
    palette = artlib.load_palette()
    allowed = {rgb for sym, rgb in palette.by_symbol.items() if sym not in palette.reserved}
    colours = {c for _, c in floor.getcolors(1 << 20)}
    assert floor.size == (v2.W, v2.H), f"the floor is {floor.size}, the map {v2.W}x{v2.H}"
    assert colours <= allowed, f"the floor left the palette: {sorted(colours - allowed)[:5]}"
    floor.save(FLOOR)
    print(f"floor: {FLOOR.relative_to(ROOT)} {floor.size[0]}x{floor.size[1]}, {len(colours)} palette colours")


def grid(img: Image.Image, pw: int, ph: int, symbol_of: dict, transparent: str) -> list[str]:
    w, h = img.size
    top = ph - h
    rows = []
    for y in range(ph):
        row = []
        for x in range(pw):
            if y < top or x >= w:
                row.append(transparent)
                continue
            r, g, b, a = img.getpixel((x, y - top))
            row.append(transparent if a < 128 else symbol_of[(r, g, b)])
        rows.append("".join(row))
    return rows


def install_tower() -> None:
    palette = artlib.load_palette()
    symbol_of = {rgb: sym for sym, rgb in palette.by_symbol.items()}
    cut = json.loads((REF / "tower_cut.json").read_text(encoding="utf-8"))
    ax, ay = round(cut["anchor"][0]), round(cut["anchor"][1])
    dark = Image.open(REF / "tower_dark.png").convert("RGBA")
    w, h = dark.size
    pw, ph = pad8(w), pad8(h)
    top = ph - h
    defs = {"version": 1, "props": {}}
    for name, src in zip(TOWER_PAIR, ("tower_dark.png", "tower_lit.png")):
        img = Image.open(REF / src).convert("RGBA")
        assert img.size == (w, h), "the two states share one canvas"
        header = ["# kind: sprite", f"# anchor: {ax},{ay + top}",
                  f"# Cut from art/reference/rootcrown_v2/{src} by tools/art/make_rootcrown_tower.py; installed by tools/art/make_rootcrown_art.py"]
        (ROOT / "art" / "src" / f"{name}.txt").write_text("\n".join(header + grid(img, pw, ph, symbol_of, palette.transparent)) + "\n",
                                                          encoding="utf-8")
        defs["props"][name] = {"w": w, "h": h, "anchor": [ax, ay], "base_width": int(cut["base_width"]), "solid": True,
                               "colliders": TOWER_COLLIDERS, "image": f"{name}.png", "locked": True, "note": NOTES[name],
                               "state_pair": list(TOWER_PAIR)}
    DEFS.write_text(json.dumps(defs, indent=1) + "\n", encoding="utf-8")
    # the shadows: every type its own pair of masks (the catalogue's rule), both cast by the unlit silhouette
    art = json.loads(ART.read_text(encoding="utf-8"))
    shadows = json.loads(SHADOW.read_text(encoding="utf-8"))
    casts = {o: cast_shadow(dark, (ax, ay), o == "flipped") for o in ("normal", "flipped")}
    for name, src in zip(TOWER_PAIR, ("tower_dark.png", "tower_lit.png")):
        obj = Image.open(REF / src).convert("RGBA")
        entry = {"trim": [0, top, w, h], "contact_shadow": contact_shadow(w, h), "cast_shadow": {}}
        manifest = {"object": name, "object_source": f"art/reference/rootcrown_v2/{src}", "object_size": [w, h],
                    "object_anchor": [ax, ay], "shadows": {}}
        for orientation, (image, feet, bounds) in casts.items():
            sprite = f"fx_shadow_{name}_1" if orientation == "normal" else f"fx_shadow_{name}_flipped_1"
            rows = ["# kind: sprite", f"# anchor: {feet[0]},{feet[1]}"]
            for y in range(image.height):
                rows.append("".join(symbol_of[INK] if image.getpixel((x, y))[3] else palette.transparent for x in range(image.width)))
            (ROOT / "art" / "src" / f"{sprite}.txt").write_text("\n".join(rows) + "\n", encoding="utf-8")
            entry["cast_shadow"][orientation] = sprite
            manifest["shadows"][orientation] = {"sprite": sprite, "size": list(image.size), "anchor": feet,
                                                "bounds_relative_to_feet": bounds, "blur_padding": PAD}
        manifest["object_rgba_sha256"] = hashlib.sha256(obj.tobytes()).hexdigest()
        art["props"][name] = entry
        shadows["props"][name] = manifest
    ART.write_text(json.dumps(art, indent=2) + "\n", encoding="utf-8")
    SHADOW.write_text(json.dumps(shadows, indent=2) + "\n", encoding="utf-8")
    print(f"tower: {w}x{h} (art padded to {pw}x{ph}), anchor {ax},{ay}; shadows fx_shadow_<type>_1 (+ flipped) for both states")


def remove_old() -> None:
    gone = 0
    for name in OLD:
        for path in (ROOT / "art" / "src" / f"{name}.txt", ROOT / "art" / "build" / "sprites" / f"{name}.png",
                     ROOT / "art" / "build" / "sprites" / f"{name}.png.import", ROOT / "presentation" / "props" / f"{name}.tscn",
                     ROOT / "presentation" / "props" / f"{name}.tscn.uid"):
            if path.exists():
                path.unlink()
                gone += 1
    print(f"first-build props removed: {len(OLD)} types, {gone} files")


# ------------------------------------------------------------------ the map data

def walkable_mask() -> np.ndarray:
    """Where the hero may walk: the floor's earth before the grass seats under the edge props (the clearing, the climb in,
    the tower's forecourt), the grass mound round the tower's foot, and the fight floor with 8 px round it."""
    seed = json.loads((ROOT / "docs" / "previews" / "rootcrown_v2" / "layout.json").read_text(encoding="utf-8"))["seed"]
    lab = v2.clearing_label(seed, None, islands=False)  # the grass islands are flat ground: walked over
    yy, xx = np.mgrid[0:v2.H, 0:v2.W].astype(np.float64)
    mx, my, rx, ry = v2.TOWER_MOUND
    lab |= ((xx - mx) / rx) ** 2 + ((yy - my) / ry) ** 2 < 1.0
    fx, fy, fw, fh = v2.FIGHT
    lab[max(0, fy - 8):fy + fh + 8, max(0, fx - 8):fx + fw + 8] = True  # the hero (r 6) reaches every point of it
    return lab


def trace(mask: np.ndarray) -> list[tuple[float, float]]:
    """The outer boundary of the one walkable region as a clockwise pixel-corner polygon (Moore tracing on the padded mask);
    rows and columns on the map's edge land exactly on the border, so the climb's bottom becomes the opening."""
    h, w = mask.shape
    m = np.zeros((h + 2, w + 2), dtype=bool)
    m[1:-1, 1:-1] = mask
    ys, xs = np.nonzero(m)
    start = (int(ys.min()), int(xs[ys == ys.min()].min()))
    dirs = [(-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1)]  # N NE E SE S SW W NW (clockwise on screen)
    pts = [start]
    cur, back = start, 6  # came from the west
    for _ in range(4 * (h + w) * 8):
        for k in range(8):
            d = (back + 1 + k) % 8
            ny, nx = cur[0] + dirs[d][0], cur[1] + dirs[d][1]
            if m[ny, nx]:
                back = (d + 4) % 8
                cur = (ny, nx)
                break
        if cur == start:
            break
        pts.append(cur)
    out = []
    for y, x in pts:
        px, py = min(max(x - 1 + 0.5, 0.0), w), min(max(y - 1 + 0.5, 0.0), h)
        px = 0.0 if x - 1 <= 0 else (float(w) if x - 1 >= w - 1 else px)
        py = 0.0 if y - 1 <= 0 else (float(h) if y - 1 >= h - 1 else py)
        out.append((px, py))
    return out


def simplify(pts: list[tuple[float, float]], tol: float) -> list[tuple[float, float]]:
    """Douglas-Peucker on a closed ring; points on the map's border are kept so the opening stays on it."""
    def dp(seg: list[tuple[float, float]]) -> list[tuple[float, float]]:
        if len(seg) < 3:
            return seg
        (x0, y0), (x1, y1) = seg[0], seg[-1]
        L = math.hypot(x1 - x0, y1 - y0) or 1e-9
        best, idx = -1.0, 0
        for i in range(1, len(seg) - 1):
            x, y = seg[i]
            dist = abs((x1 - x0) * (y0 - y) - (x0 - x) * (y1 - y0)) / L
            if dist > best:
                best, idx = dist, i
        if best > tol:
            return dp(seg[: idx + 1])[:-1] + dp(seg[idx:])
        return [seg[0], seg[-1]]
    # split the ring at its two farthest-apart points so the recursion has fixed ends
    a = 0
    b = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    ring = dp(pts[a:b + 1])[:-1] + dp(pts[b:] + [pts[0]])[:-1]
    out = []
    for p in ring:
        if not out or p != out[-1]:
            out.append(p)
    return out


def shoelace(poly: list[tuple[float, float]]) -> float:
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1])) / 2.0


def outline() -> list[list[int]]:
    poly = simplify(trace(walkable_mask()), 2.0)
    poly = [(round(x), round(y)) for x, y in poly]
    clean = []
    for p in poly:
        if not clean or p != clean[-1]:
            clean.append(p)
    if clean[0] == clean[-1]:
        clean.pop()
    # clockwise on screen (y down) is a positive shoelace sum, as the first build's outline
    if shoelace(clean) < 0:
        clean.reverse()
    return [list(p) for p in clean]


def write_scene() -> None:
    ring = outline()
    bottom = sorted(x for x, y in ring if y == v2.H)
    assert len(bottom) >= 2, "the climb must open on the map's bottom edge"
    x0, x1 = bottom[0], bottom[-1]
    props = [{"id": "beacon", "type": TOWER_PAIR[0], "x": v2.TOWER[0], "y": v2.TOWER[1], "flip": False, "shadow_radius": 40,
              "when": "flag:cleared_rootcrown", "on_type": TOWER_PAIR[1]}]
    count: dict[str, int] = {}
    for q in v2.rootcrown_props():
        short = q["type"]
        for prefix in ("root_hollow_", "hollow_trial_", "woodland_", "forest_", "glade_"):
            short = short.removeprefix(prefix)
        count[short] = count.get(short, 0) + 1
        props.append({"id": f"{short}_{count[short]}", "type": q["type"], "x": q["x"], "y": q["y"], "flip": bool(q["flip"])})
    data = {"version": 1, "scene": "rootcrown_layered", "name": "ROOTCROWN", "size": [v2.W, v2.H],
            "ground": "res://presentation/forest/rootcrown_layered_ground.png", "outline": ring, "boundary_radius": 25,
            "boundary_spacing": 17, "prop_margin": 40, "entries": {"glade_side": list(v2.ENTRY)}, "default_entry": "glade_side",
            "exits": [{"id": "to_glade", "rect": [x0, v2.H - 6, x1 - x0, 6], "target_scene": "glade_layered",
                       "target_entry": "rootcrown_side"}],
            "checkpoints": [{"id": "rootcrown_layered_stair", "position": list(v2.CHECKPOINT)}], "npcs": [], "objects": [],
            "props": props}
    SCENE.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print(f"map: {SCENE.relative_to(ROOT)} {v2.W}x{v2.H}, outline {len(ring)} points, {len(props)} props, exit x {x0}..{x1}")


def main() -> int:
    install_floor()
    install_tower()
    remove_old()
    write_scene()
    return 0


if __name__ == "__main__":
    sys.exit(main())
