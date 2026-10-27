"""Review image and reach numbers for a layered scene (data/scenes/<scene>_props.json + data/props/prop_defs.json):
the Stag glade (default) or the village (--scene village_layered).

Draws the approved ground, every prop sprite at its place (y-sorted), the walkable outline (cyan), the prop colliders
(orange, solid props) and the openings; tints what a body of STAG radius can reach (green) and prints the shares of the
fight area a radius-20 Stag and the hero (radius 6) reach, and whether entrance -> exit is connected for the hero.
It is an approximation of the core's collision (outline inset by the body radius, circles); the real rule is checked by
tests/core/test_glade_layered.gd. Output: docs/previews/glade_layered_overlay.png (3x).

Run: python tools/art/preview_layered_glade.py [--scene glade_layered|village_layered] [--out FILE] [--no-reach]
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "data" / "scenes" / "glade_layered_props.json"
DEFS = ROOT / "data" / "props" / "prop_defs.json"
PROPS_DIRS = [ROOT / "art" / "reference" / "layered_pilot" / "props", ROOT / "art" / "reference" / "layered_village" / "props",
              ROOT / "data" / "props" / "cutouts_forest"]
# a scene whose runtime ground is not delivered yet is previewed on its generated source
SOURCE_GROUNDS = {"forest_layered": ROOT / "art" / "reference" / "layered_forest" / "forest_ground_only.png"}
ZOOM = 3
HERO = 6.0
STEP = 2.0


def load(scene_id: str = "glade_layered") -> tuple[dict, dict]:
    path = ROOT / "data" / "scenes" / f"{scene_id}_props.json"
    return json.loads(path.read_text(encoding="utf-8")), json.loads(DEFS.read_text(encoding="utf-8"))


def prop_image(name: str) -> Path:
    for d in PROPS_DIRS:
        if (d / name).exists():
            return d / name
    raise FileNotFoundError(name)


def shown(p: dict, state_on: bool) -> str:
    """The type a placement shows: its on_type when the preview state is ON (gate open, every pedestal lit)."""
    return p["on_type"] if state_on and "on_type" in p else p["type"]


def circles(scene: dict, defs: dict, state_on: bool = False) -> list[tuple[float, float, float]]:
    out = []
    for p in scene["props"]:
        d = defs["props"][shown(p, state_on)]
        if not d["solid"]:
            continue
        flip = -1.0 if p.get("flip") else 1.0
        for dx, dy, r in d["colliders"]:
            out.append((p["x"] + dx * flip, p["y"] + dy, r))
    return out


def _seg_dist(px: float, py: float, a: tuple[float, float], b: tuple[float, float]) -> float:
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def _inside(px: float, py: float, poly: list[tuple[float, float]]) -> bool:
    n = len(poly)
    c = False
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi:
            c = not c
        j = i
    return c


def edges(scene: dict) -> list[tuple[tuple[float, float], tuple[float, float]]]:
    """The outline's edges that are NOT openings (edges lying on the world border)."""
    w, h = scene["size"]
    poly = [tuple(p) for p in scene["outline"]]
    out = []
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        on = (a[0] == b[0] == 0) or (a[0] == b[0] == w) or (a[1] == b[1] == 0) or (a[1] == b[1] == h)
        if not on:
            out.append((a, b))
    return out


def free_grid(scene: dict, defs: dict, radius: float, state_on: bool = False):
    w, h = scene["size"]
    poly = [tuple(p) for p in scene["outline"]]
    solid = circles(scene, defs, state_on)
    walls = edges(scene)
    cols, rows = int(w / STEP), int(h / STEP)
    grid = [[False] * cols for _ in range(rows)]
    for j in range(rows):
        for i in range(cols):
            x, y = (i + 0.5) * STEP, (j + 0.5) * STEP
            if x < radius or y < radius or x > w - radius or y > h - radius:
                continue
            if not _inside(x, y, poly) and not any(_seg_dist(x, y, a, b) < 0.5 for a, b in walls):
                # outside the polygon: still free when it is in an opening's mouth (handled by the border test below)
                continue
            if any(_seg_dist(x, y, a, b) < radius for a, b in walls):
                continue
            if any(math.hypot(x - cx, y - cy) < r + radius for cx, cy, r in solid):
                continue
            grid[j][i] = True
    return grid, cols, rows


def flood(grid, cols, rows, start: tuple[float, float]):
    si, sj = int(start[0] / STEP), int(start[1] / STEP)
    best = None
    for dj in range(-3, 4):
        for di in range(-3, 4):
            i, j = si + di, sj + dj
            if 0 <= i < cols and 0 <= j < rows and grid[j][i]:
                best = (i, j)
                break
        if best:
            break
    seen = [[False] * cols for _ in range(rows)]
    if best is None:
        return seen
    stack = [best]
    seen[best[1]][best[0]] = True
    while stack:
        i, j = stack.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < cols and 0 <= b < rows and grid[b][a] and not seen[b][a]:
                seen[b][a] = True
                stack.append((a, b))
    return seen


def share(seen, rect: list[float]) -> float:
    x0, y0, rw, rh = rect
    hit = total = 0
    j = int(y0 / STEP)
    while j * STEP < y0 + rh:
        i = int(x0 / STEP)
        while i * STEP < x0 + rw:
            total += 1
            if j < len(seen) and i < len(seen[0]) and seen[j][i]:
                hit += 1
            i += 1
        j += 1
    return hit / max(1, total)


def render(scene: dict, defs: dict, out: Path, reach: bool, state_on: bool = False) -> dict:
    w, h = scene["size"]
    ground_path = ROOT / scene["ground"].replace("res://", "")
    if not ground_path.exists():
        ground_path = SOURCE_GROUNDS[scene["scene"]]
    ground = Image.open(ground_path).convert("RGBA")
    board = Image.new("RGBA", (w, h))
    board.paste(ground.resize((w, h), Image.NEAREST))
    for p in sorted(scene["props"], key=lambda q: q["y"]):
        d = defs["props"][shown(p, state_on)]
        img = Image.open(prop_image(d["image"])).convert("RGBA")
        if p.get("flip"):
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        ax = (img.size[0] - d["anchor"][0]) if p.get("flip") else d["anchor"][0]
        board.alpha_composite(img, (round(p["x"] - ax), round(p["y"] - d["anchor"][1])))
    stats = {}
    if reach and "stag_start" not in scene:
        g_hero, cols, rows = free_grid(scene, defs, HERO, state_on)
        hero_seen = flood(g_hero, cols, rows, scene["entries"][scene["default_entry"]])
        tint = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        tp = tint.load()
        for j in range(rows):
            for i in range(cols):
                if hero_seen[j][i]:
                    for dy in range(int(STEP)):
                        for dx in range(int(STEP)):
                            tp[int(i * STEP) + dx, int(j * STEP) + dy] = (0, 255, 120, 50)
        board.alpha_composite(tint)
        def ok(pt):
            return hero_seen[min(rows - 1, int(pt[1] / STEP))][min(cols - 1, int(pt[0] / STEP))]
        stats["entries_reached"] = {k: bool(ok(v)) for k, v in scene["entries"].items()}
        stats["checkpoints_reached"] = {c["id"]: bool(ok(c["position"])) for c in scene.get("checkpoints", [])}
        stats["npc_stands_reached"] = {n["id"]: bool(ok(n["position"])) for n in scene.get("npcs", [])}
        stats["interact_stands_reached"] = {o["id"]: bool(ok(o["stand"])) for o in scene.get("objects", [])}
        stats["exits_reached"] = {}
        for e in scene["exits"]:
            r = e["rect"]
            x = min(max(r[0] + r[2] / 2, HERO + 1), w - HERO - 1)
            y = min(max(r[1] + r[3] / 2, HERO + 1), h - HERO - 1)
            stats["exits_reached"][e["id"]] = bool(ok((x, y)))
    elif reach:
        stag_r = scene["stag_radius"]
        g_stag, cols, rows = free_grid(scene, defs, stag_r)
        seen = flood(g_stag, cols, rows, scene["stag_start"])
        stats["stag_share"] = share(seen, scene["fight_area"])
        g_hero, _, _ = free_grid(scene, defs, HERO)
        hero_seen = flood(g_hero, cols, rows, scene["entries"]["entrance"])
        ex = scene["exits"][1]["rect"]
        row = min(rows - 1, int(max(ex[1] + ex[3] / 2, HERO + 2) / STEP))  # the hero's centre stays HERO px inside the edge
        stats["hero_reaches_exit"] = any(hero_seen[row][int(x / STEP)] for x in range(int(ex[0]) + 2, int(ex[0] + ex[2]) - 1, 2))
        stats["hero_fight_area"] = share(hero_seen, scene["fight_area"])
        tint = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        tp = tint.load()
        for j in range(rows):
            for i in range(cols):
                if seen[j][i]:
                    for dy in range(int(STEP)):
                        for dx in range(int(STEP)):
                            tp[int(i * STEP) + dx, int(j * STEP) + dy] = (0, 255, 120, 60)
        board.alpha_composite(tint)
    big = board.resize((w * ZOOM, h * ZOOM), Image.NEAREST)
    d = ImageDraw.Draw(big)
    z = ZOOM
    poly = [(x * z, y * z) for x, y in scene["outline"]]
    d.line(poly + [poly[0]], fill=(0, 255, 255, 255), width=2)
    for cx, cy, r in circles(scene, defs, state_on):
        d.ellipse([(cx - r) * z, (cy - r) * z, (cx + r) * z, (cy + r) * z], outline=(255, 160, 0, 255))
    if "fight_area" in scene:
        fa = scene["fight_area"]
        d.rectangle([fa[0] * z, fa[1] * z, (fa[0] + fa[2]) * z, (fa[1] + fa[3]) * z], outline=(255, 255, 255, 255))
    for n in scene.get("npcs", []):
        px, py = n["position"]
        d.ellipse([px * z - 5, py * z - 5, px * z + 5, py * z + 5], outline=(255, 255, 255, 255), width=2)
        d.text((px * z + 7, py * z - 6), n["id"], fill=(255, 255, 255, 255))
    for o in scene.get("objects", []):
        sx, sy = o["stand"]
        d.rectangle([sx * z - 4, sy * z - 4, sx * z + 4, sy * z + 4], outline=(120, 200, 255, 255), width=2)
        d.text((sx * z + 7, sy * z - 6), o["id"], fill=(120, 200, 255, 255))
    for c in scene.get("checkpoints", []):
        cx, cy = c["position"]
        d.polygon([(cx * z, cy * z - 6), (cx * z + 6, cy * z), (cx * z, cy * z + 6), (cx * z - 6, cy * z)], outline=(255, 255, 0, 255))
    for e in scene["exits"]:
        r = e["rect"]
        d.rectangle([r[0] * z, r[1] * z, (r[0] + r[2]) * z, (r[1] + r[3]) * z], outline=(255, 0, 255, 255), width=2)
    for name, pt in scene["entries"].items():
        d.ellipse([pt[0] * z - 4, pt[1] * z - 4, pt[0] * z + 4, pt[1] * z + 4], fill=(255, 255, 0, 255))
    if "stag_start" in scene:
        sp = scene["stag_start"]
        d.ellipse([(sp[0] - scene["stag_radius"]) * z, (sp[1] - scene["stag_radius"]) * z, (sp[0] + scene["stag_radius"]) * z, (sp[1] + scene["stag_radius"]) * z], outline=(255, 80, 80, 255), width=2)
    out.parent.mkdir(parents=True, exist_ok=True)
    big.convert("RGB").save(out)
    return stats


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scene", default="glade_layered")
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--no-reach", action="store_true")
    ap.add_argument("--state-on", action="store_true", help="show the stateful props ON (the forest: gate open, pedestals lit)")
    args = ap.parse_args()
    scene, defs = load(args.scene)
    suffix = "_open" if args.state_on else ""
    out = args.out or ROOT / "docs" / "previews" / f"{args.scene.replace('_layered', '')}_layered_overlay{suffix}.png"
    stats = render(scene, defs, out, not args.no_reach, args.state_on)
    print(json.dumps(stats, indent=1))
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
