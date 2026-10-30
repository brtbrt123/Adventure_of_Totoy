"""Root Hollow blockout: the walkable shape, a palette-only placeholder ground and (with --write-scene) the scene data.

Root Hollow is the chapter 1 map between the forest route and the Stag glade (presentation/review/chapter1_expansion/LAYOUT.md): a broad
central clearing for the mixed fight, an optional shrine clearing up a quiet fork, a south loop with a pocket for escaping, and a
shortcut trail back toward the village. This tool draws the walkable shapes, traces them into the scene outline and paints a ground out
of the Totoy 36 grass and dirt ramps with hard alpha, so the map is playable now. The owner's approved painting replaces
presentation/forest/root_hollow_layered_ground.png later; the scene data keeps working as long as the walkable shape matches.

    python tools/art/make_root_hollow_blockout.py                 # the ground only
    python tools/art/make_root_hollow_blockout.py --write-scene   # also (over)write data/scenes/root_hollow_layered_props.json

--write-scene replaces hand edits of the JSON: run it once, then edit the JSON. Since the real props were registered (2026-10-30)
the scene file is maintained by hand: --write-scene refuses unless you also pass --force.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
W, H = 640, 400
GROUND = ROOT / "presentation/forest/root_hollow_layered_ground.png"
SCENE = ROOT / "data/scenes/root_hollow_layered_props.json"

# the walkable shapes: ("e", cx, cy, rx, ry) ellipses and ("t", width, [points]) trails
SHAPES = [
    ("t", 46, [(-10, 322), (70, 322), (150, 306), (215, 270)]),  # the way in from the forest
    ("e", 330, 206, 135, 86),  # the central clearing
    ("t", 40, [(150, 306), (210, 350), (300, 362), (400, 340), (445, 300)]),  # the south loop
    ("e", 470, 285, 62, 40),  # the pocket the loop passes
    ("t", 34, [(445, 285), (420, 240), (400, 215)]),  # the pocket back into the clearing
    ("t", 42, [(430, 170), (500, 130), (560, 100), (650, 100)]),  # east, to the glade
    ("t", 36, [(250, 170), (200, 140), (150, 112)]),  # the quiet fork to the shrine
    ("e", 110, 100, 100, 66),  # the shrine clearing
    ("t", 32, [(78, 60), (64, 30), (54, -10)]),  # the shortcut north
]
# which shapes are dirt (the rest of the walkable ground is mossy grass): the trails and the clearings
DIRT_TRAILS = [0, 2, 4, 5, 6, 8]
DIRT_ELLIPSES = [1, 7]


def walk_mask() -> Image.Image:
    img = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(img)
    for shape in SHAPES:
        if shape[0] == "e":
            _, cx, cy, rx, ry = shape
            draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
        else:
            _, width, points = shape
            draw.line(points, fill=255, width=width, joint="curve")
            for x, y in points:
                draw.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=255)
    return img


def dirt_mask() -> Image.Image:
    img = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(img)
    for index in DIRT_TRAILS:
        _, width, points = SHAPES[index]
        inner = max(8, width - 14)
        draw.line(points, fill=255, width=inner, joint="curve")
        for x, y in points:
            draw.ellipse([x - inner / 2, y - inner / 2, x + inner / 2, y + inner / 2], fill=255)
    for index in DIRT_ELLIPSES:
        _, cx, cy, rx, ry = SHAPES[index]
        draw.ellipse([cx - rx + 16, cy - ry + 14, cx + rx - 16, cy + ry - 14], fill=255)
    return img


def value_noise(rng: np.random.Generator, cell: int) -> np.ndarray:
    small = rng.random((H // cell + 2, W // cell + 2)).astype(np.float32)
    big = Image.fromarray((small * 255).astype(np.uint8)).resize(((W // cell + 2) * cell, (H // cell + 2) * cell), Image.BICUBIC)
    return np.asarray(big, dtype=np.float32)[:H, :W] / 255.0


def trace_outline(mask: np.ndarray) -> list[tuple[int, int]]:
    """The clockwise boundary of the one connected walkable region (square tracing on the pixel grid), simplified."""
    rows, cols = mask.shape
    ys, xs = np.nonzero(mask)
    start = (int(xs[np.argmin(ys * cols + xs)]), int(ys.min()))
    # Moore-neighbour tracing over pixel corners: walk the boundary pixels clockwise
    dirs = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]

    def inside(x: int, y: int) -> bool:
        return 0 <= x < cols and 0 <= y < rows and bool(mask[y, x])

    boundary = [start]
    current = start
    back = 4  # we entered going east, so the previous pixel is to the west
    guard = 0
    while guard < 200000:
        guard += 1
        found = False
        for k in range(8):
            d = (back + 1 + k) % 8
            nx, ny = current[0] + dirs[d][0], current[1] + dirs[d][1]
            if inside(nx, ny):
                back = (d + 4) % 8
                current = (nx, ny)
                found = True
                break
        if not found or (current == start and len(boundary) > 2):
            break
        boundary.append(current)
    return boundary


def simplify(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    """Douglas-Peucker on a closed loop (split at the two farthest points)."""
    def rdp(pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
        if len(pts) < 3:
            return pts
        (x1, y1), (x2, y2) = pts[0], pts[-1]
        best, index = 0.0, 0
        length = math.hypot(x2 - x1, y2 - y1)
        for i in range(1, len(pts) - 1):
            x0, y0 = pts[i]
            d = abs((x2 - x1) * (y1 - y0) - (x1 - x0) * (y2 - y1)) / length if length else math.hypot(x0 - x1, y0 - y1)
            if d > best:
                best, index = d, i
        if best > epsilon:
            return rdp(pts[: index + 1])[:-1] + rdp(pts[index:])
        return [pts[0], pts[-1]]

    far = max(range(len(points)), key=lambda i: math.hypot(points[i][0] - points[0][0], points[i][1] - points[0][1]))
    first = rdp(points[: far + 1])
    second = rdp(points[far:] + [points[0]])
    return first[:-1] + second[:-1]


def outline_for_scene(mask: np.ndarray) -> list[list[int]]:
    """The boundary as game points; mask edges that touch the world border snap to it so they read as openings."""
    padded = np.pad(mask, 1, constant_values=False)  # trace around the whole region including where it meets the border
    pts = trace_outline(padded)
    pts = [(x - 1, y - 1) for x, y in pts]
    simple = simplify([(float(x), float(y)) for x, y in pts], 2.2)
    out = []
    for x, y in simple:
        x = 0 if x <= 1 else (W if x >= W - 2 else x)
        y = 0 if y <= 1 else (H if y >= H - 2 else y)
        out.append([int(round(x)), int(round(y))])
    return out


def paint_ground(seed: int = 7) -> None:
    rng = np.random.default_rng(seed)
    pal = json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))
    color = {e["symbol"]: tuple(int(e["hex"][i:i + 2], 16) for i in (1, 3, 5)) for e in pal["colors"]}
    walk = np.asarray(walk_mask()) > 127
    dirt_img = dirt_mask().filter(ImageFilter.GaussianBlur(3.0))
    n_big, n_mid, n_fine = value_noise(rng, 24), value_noise(rng, 8), value_noise(rng, 3)
    dirt = (np.asarray(dirt_img, dtype=np.float32) / 255.0 + (n_mid - 0.5) * 0.55) > 0.5
    dirt &= walk
    shade = 0.45 * n_big + 0.35 * n_mid + 0.20 * n_fine
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5
    dither = np.tile(bayer, (H // 4 + 1, W // 4 + 1))[:H, :W] * 0.12
    ramps = {
        "outside": ["2", "2", "3"],
        "grass": ["2", "3", "3", "4", "4", "5"],
        "dirt": ["9", "a", "b", "b", "c", "c", "d"],
    }
    img = np.zeros((H, W, 3), dtype=np.uint8)
    for name, region in (("outside", ~walk), ("grass", walk & ~dirt), ("dirt", dirt)):
        ramp = ramps[name]
        idx = np.clip(((shade + dither) * len(ramp)).astype(int), 0, len(ramp) - 1)
        for i, sym in enumerate(ramp):
            sel = region & (idx == i)
            img[sel] = color[sym]
    # moss flecks and stones on the dirt, a few darker tufts on the grass: hard single pixels only
    flecks = rng.random((H, W))
    img[dirt & (flecks > 0.985)] = color["g"]
    img[dirt & (flecks < 0.01)] = color["8"]
    img[walk & ~dirt & (flecks > 0.99)] = color["5"]
    Image.fromarray(img, "RGB").save(GROUND)


def write_scene(outline: list[list[int]]) -> None:
    from random import Random
    mask = np.asarray(walk_mask()) > 127
    rng = Random(11)
    ys, xs = np.nonzero(mask[::4, ::4])
    boundary_samples = []
    for i in range(len(outline)):
        a, b = outline[i], outline[(i + 1) % len(outline)]
        steps = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) // 6))
        for s in range(steps):
            boundary_samples.append((a[0] + (b[0] - a[0]) * s / steps, a[1] + (b[1] - a[1]) * s / steps))
    samples = np.array(boundary_samples)
    exits = [pygame_rect for pygame_rect in ((0, 300, 7, 44), (633, 82, 7, 36), (36, 0, 36, 7))]

    def clear_of_exits(x: float, y: float) -> bool:
        for rx, ry, rw, rh in exits:
            if rx - 30 <= x <= rx + rw + 30 and ry - 30 <= y <= ry + rh + 30:
                return False
        return True

    props = []

    def add(kind: str, x: float, y: float) -> None:
        props.append({"id": "prop_%03d" % len(props), "type": kind, "x": int(round(x)), "y": int(round(y))})

    # the tree line: outside the walkable ground, 24-64 px from its edge, never in front of an opening
    placed: list[tuple[float, float]] = []
    candidates = [(x, y) for y in range(8, H + 1, 14) for x in range(0, W + 1, 14)]
    rng.shuffle(candidates)
    for x, y in candidates:
        xi, yi = min(W - 1, max(0, int(x))), min(H - 1, max(0, int(y)))
        if mask[yi, xi]:
            continue
        d = float(np.min(np.hypot(samples[:, 0] - x, samples[:, 1] - y)))
        if d < 24 or d > 64 or not clear_of_exits(x, y):
            continue
        if any(math.hypot(x - px, y - py) < 40 for px, py in placed):
            continue
        placed.append((x, y))
        add("woodland_tree_broad" if rng.random() < 0.55 else "woodland_tree_slender", x, y)
    # the shrine: a standing stone and two lanterns; a signpost at the fork; rocks at the pocket; bushes as soft decor
    add("forest_standing_stone", 108, 92)
    add("woodland_lantern", 62, 118)
    add("woodland_lantern", 150, 72)
    add("woodland_sign", 238, 160)
    add("woodland_rocks", 520, 316)
    add("woodland_rocks", 410, 366)
    for x, y in ((170, 190), (292, 350), (560, 150), (80, 240)):
        add("woodland_bush", x, y)
    mobs_center = [
        {"type": "boar", "x": 276, "y": 176},
        {"type": "boar", "x": 396, "y": 240},
        {"type": "mossling", "x": 330, "y": 214},
        {"type": "mossling", "x": 352, "y": 170},
    ]
    data = {
        "version": 1, "scene": "root_hollow_layered", "name": "ROOT HOLLOW", "size": [W, H],
        "ground": "res://presentation/forest/root_hollow_layered_ground.png",
        "outline": outline, "boundary_radius": 25, "boundary_spacing": 17, "prop_margin": 40,
        "entries": {"forest_side": [24, 322], "glade_side": [616, 100], "shortcut": [54, 24]},
        "default_entry": "forest_side",
        "exits": [
            {"id": "to_forest", "rect": [0, 300, 7, 44], "target_scene": "forest_layered", "target_entry": "north"},
            {"id": "to_glade", "rect": [633, 82, 7, 36], "target_scene": "glade_layered", "target_entry": "entrance"},
            {"id": "shortcut", "rect": [36, 0, 36, 7], "target_scene": "village_layered", "target_entry": "return",
             "requires_flag": "cleared_hollow_center", "blocked_text": "A knot of roots seals the shortcut. Clear the hollow first."},
        ],
        "checkpoints": [{"id": "root_hollow_layered_entrance", "position": [36, 322]}, {"id": "root_hollow_layered_east", "position": [600, 102]}],
        "npcs": [], "objects": [],
        "encounters": [
            {"id": "hollow_center", "name": "ROOT HOLLOW", "rect": [240, 150, 180, 112], "leash": 190, "mobs": mobs_center},
            {"id": "hollow_shrine", "name": "OVERGROWN SHRINE", "rect": [48, 66, 124, 76], "leash": 130,
             "reward": {"reward_id": "hollow_shrine_herbs", "kind": "item", "item": "herb", "name": "Herb", "quantity": 2},
             "mobs": [{"type": "mossling", "x": 96, "y": 116}, {"type": "mossling", "x": 138, "y": 92}, {"type": "mossling", "x": 146, "y": 124}]},
        ],
        "props": props,
    }
    SCENE.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-scene", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    paint_ground()
    outline = outline_for_scene(np.asarray(walk_mask()) > 127)
    print("ground written; outline has", len(outline), "points")
    if args.write_scene:
        if not args.force:
            raise SystemExit("the scene file is maintained by hand now (real props registered): pass --force to overwrite it")
        write_scene(outline)
        print("scene data written to", SCENE)


if __name__ == "__main__":
    main()
