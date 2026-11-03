"""Cuts the mage staff concept sheets (art/reference/staff_v1, image generation 2026-11-01) down to game-scale pixel frames for review.

Review stage: nothing goes into art/src. Output is art/reference/staff_v1/imported/<set>_<n>.png (Totoy 36, hard alpha) plus
imported.json (size and anchor of every frame) and imported_contact.png (every frame at 6x). The preview GIFs
(tools/art/preview_staff.py) and the staff cut-in (tools/art/export_staff_cutin.py) are built from these frames.

Each sheet is a grid of cells on magenta. Per set: one scale for the whole sheet (a reference measure becomes a game size), the
magenta and its pink fringe keyed out (import_warden_fx.background), every pixel snapped to Totoy 36 without gold or red, and an
anchor where the frame attaches in the game:

    hero        the 8 key poses; the hero is 35 px tall like hero2; anchor = the feet (the ground line is cut off)
                1 idle, 2 walk, 3 cast (thrust), 4 swing overhead, 5 plant the staff, 6 blink dissolve, 7 hurt, 8 call the star
    burst       Arcane Burst (6): the basic attack's small explosion, 34 px across at its largest; anchor = the centre
    burst_big   Great Burst (6): the combo finisher on a ground circle, 60 px across; anchor = the circle's centre
    blink       Blink (8): 1-4 depart, 5-8 arrive; the ring under the feet is 22 px across; anchor = the ring
    circle      the Disintegration circle (8: draw-in, then a loop), squashed 2:1 to lie on the ground, 64 px across
    star        the falling star (1-3, anchor = its head) and the impact (4-8, anchor = the ground point), the spray 36 px across
    scorch      the starburnt ground (4); the sheet drew two stacked patches, only the top one is kept; 44 px across

Fixes over the sheets: the crystal's centre came out magenta (keyed out as a hole), so small enclosed holes ringed by crystal colours
are filled with cream; the circle was drawn round and is squashed to a ground ellipse; the scorch keeps one patch.

    python tools/art/import_staff_concept.py
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_warden_fx import background, cells, content_box, palette, shrink  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/reference/staff_v1"
OUT = SOURCE / "imported"
HERO_HEIGHT = 35  # px: hero2's idle frame, feet to hair tip
CRYSTAL = set("ghijmnop1")  # the crescent and the glow around the centre

# set -> (file, grid, reference frame (0-based), measure "w"/"h", game px, anchor mode, vertical squash)
SHEETS: dict[str, tuple] = {
    "hero": ("Hero_Staff_Poses.png", (4, 2), 0, "h", HERO_HEIGHT, "feet", 1.0),
    "burst": ("Staff_Burst.png", (3, 2), 2, "w", 34, "centre", 1.0),
    "burst_big": ("Staff_Burst_Big.png", (3, 2), 0, "w", 44, "centre", 1.0),
    "blink": ("Staff_Blink.png", (4, 2), 0, "w", 22, "ring", 1.0),
    "circle": ("Disintegration_Circle.png", (4, 2), 0, "w", 64, "centre", 0.5),
    "star": ("Disintegration_Star.png", (4, 2), 3, "w", 36, "star", 1.0),
    "scorch": ("Disintegration_Scorch.png", (4, 1), 0, "w", 44, "patch", 1.0),
}


def ground_cut(im: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    """The hero cells stand on a dark ground line: the box ends just above it."""
    px = im.load()
    x0, y0, x1, y1 = box
    for y in range(y0 + (y1 - y0) // 2, y1):
        if sum(sum(px[x, y]) < 160 for x in range(x0, x1, 2)) > 0.6 * ((x1 - x0) // 2):
            return (x0, y0, x1, y)
    return box


def top_patch(im: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    """The scorch cells hold two stacked patches (with embers above): the box ends halfway between the first two dense row runs."""
    px = im.load()
    cx0, cy0, cx1, cy1 = content_box(im, box)
    counts = [sum(not background(*px[x, y]) for x in range(cx0, cx1, 2)) for y in range(cy0, cy1)]
    dense = [c > 0.35 * max(counts) for c in counts]
    runs, start = [], None
    for i, d in enumerate(dense + [False]):
        if d and start is None:
            start = i
        elif not d and start is not None:
            if i - start > (cy1 - cy0) // 10:
                runs.append((start, i))
            start = None
    if len(runs) < 2:
        return box
    return (box[0], box[1], box[2], cy0 + (runs[0][1] + runs[1][0]) // 2)


def patch_anchor(canvas: dict[tuple[int, int], str]) -> tuple[int, int]:
    """The centre of the scorch patch (its dense rows, not the embers above)."""
    rows = Counter(y for _, y in canvas)
    top = max(rows.values())
    ys = [y for y, c in rows.items() if c > 0.4 * top]
    xs = [x for x, y in canvas if min(ys) <= y <= max(ys)]
    return ((min(xs) + max(xs)) // 2, (min(ys) + max(ys)) // 2)


def fill_holes(canvas: dict[tuple[int, int], str], size: tuple[int, int]) -> None:
    """Small enclosed holes ringed by crystal colours (the magenta crystal centre) become cream."""
    w, h = size
    seen: set[tuple[int, int]] = set()
    for sy in range(h):
        for sx in range(w):
            if (sx, sy) in canvas or (sx, sy) in seen:
                continue
            comp, stack, edge = [], [(sx, sy)], False
            seen.add((sx, sy))
            while stack:
                x, y = stack.pop()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if not (0 <= nx < w and 0 <= ny < h):
                        edge = True
                    elif (nx, ny) not in canvas and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if edge or len(comp) > 12:
                continue
            ring = Counter(canvas[n] for x, y in comp for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)) if n in canvas)
            if sum(v for s, v in ring.items() if s in CRYSTAL) >= 0.6 * sum(ring.values()):
                for p in comp:
                    canvas[p] = "1"


def anchor_of(mode: str, n: int, canvas: dict[tuple[int, int], str], ref: tuple[float, float] | None) -> tuple[int, int]:
    xs = [x for x, _ in canvas]
    ys = [y for _, y in canvas]
    if mode == "feet":  # the middle of the lowest rows (the feet), at the bottom
        low = max(ys)
        feet = [x for x, y in canvas if y >= low - 3]
        return ((min(feet) + max(feet)) // 2, low)
    if mode == "patch":
        return patch_anchor(canvas)
    if mode == "star" and n < 3:  # the falling star's head: the lowest-rightmost pixel
        return max(canvas, key=lambda p: p[0] + p[1])
    assert ref is not None
    return (round(ref[0]), round(ref[1]))


def reference_anchor(mode: str, n: int, canvases: list[dict]) -> tuple[float, float] | None:
    """Sets whose frames stay put in the cell share one anchor, measured on one frame (cell coordinates, game px)."""
    def box(c):
        xs = [x for x, _ in c]
        ys = [y for _, y in c]
        return min(xs), min(ys), max(xs), max(ys)
    if mode == "centre":
        x0, y0, x1, y1 = box(canvases[0])
        return ((x0 + x1) / 2, (y0 + y1) / 2)
    if mode == "ring":  # the ring under the feet: depart frames use frame 1's, arrive frames frame 5's
        x0, y0, x1, y1 = box(canvases[0 if n < 4 else 4])
        return ((x0 + x1) / 2, y1 - 2)
    if mode == "star":  # the impact's ground point: the ring of frame 5
        x0, y0, x1, y1 = box(canvases[4])
        return ((x0 + x1) / 2, y1 - 3)
    return None


def import_set(name: str, colours: dict) -> list[tuple[dict, tuple[int, int], tuple[int, int]]]:
    file, grid, ref, measure, target, mode, squash = SHEETS[name]
    im = Image.open(SOURCE / file).convert("RGB")
    boxes = cells(im, grid)
    if name == "hero":
        boxes = [ground_cut(im, b) for b in boxes]
    if name == "scorch":
        boxes = [top_patch(im, b) for b in boxes]
    if squash != 1.0:  # lay the circle on the ground: halve its height (nearest, before the snap)
        im = im.resize((im.width, round(im.height * squash)), Image.NEAREST)
        boxes = [(x0, round(y0 * squash), x1, round(y1 * squash)) for x0, y0, x1, y1 in boxes]
    rb = content_box(im, boxes[ref])
    scale = target / ((rb[2] - rb[0]) if measure == "w" else (rb[3] - rb[1]))
    allowed = set(colours) - {"x", "y", "z", "A"}
    canvases, sizes = [], []
    for b in boxes:
        c = shrink(im, b, scale, allowed, colours)
        size = (int((b[2] - b[0]) * scale), int((b[3] - b[1]) * scale))
        if name == "hero":
            fill_holes(c, size)
        canvases.append(c)
        sizes.append(size)
    out = []
    for n, c in enumerate(canvases):
        if not c:
            continue
        anchor = anchor_of(mode, n, c, reference_anchor(mode, n, canvases))
        out.append((c, anchor, sizes[n]))
    return out


def to_image(canvas: dict, colours: dict) -> tuple[Image.Image, tuple[int, int]]:
    """Trimmed RGBA frame and the origin (the canvas position of its top-left pixel)."""
    xs = [x for x, _ in canvas]
    ys = [y for _, y in canvas]
    left, top = min(xs), min(ys)
    img = Image.new("RGBA", (max(xs) + 1 - left, max(ys) + 1 - top), (0, 0, 0, 0))
    for (x, y), s in canvas.items():
        img.putpixel((x - left, y - top), colours[s] + (255,))
    return img, (left, top)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    colours = palette()
    meta: dict = {"generator": "tools/art/import_staff_concept.py", "status": "review stage; not in art/src", "sets": {}}
    sheet_items = []
    for name in SHEETS:
        frames = import_set(name, colours)
        meta["sets"][name] = []
        for n, (canvas, (ax, ay), _) in enumerate(frames, start=1):
            img, (left, top) = to_image(canvas, colours)
            file = f"{name}_{n}.png"
            img.save(OUT / file)
            meta["sets"][name].append({"file": file, "w": img.width, "h": img.height, "ax": ax - left, "ay": ay - top})
            sheet_items.append((file, img, (ax - left, ay - top)))
        print(f"{name}: {len(frames)} frames, largest {max(m['w'] for m in meta['sets'][name])}x{max(m['h'] for m in meta['sets'][name])}")
    (OUT / "imported.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    # contact sheet: every frame at 6x on a dark tile, the anchor marked
    k, pad, x, y, row_h = 6, 8, 8, 8, 0
    sheet = Image.new("RGB", (1800, 2400), (24, 22, 32))
    for file, img, (ax, ay) in sheet_items:
        big = img.resize((img.width * k, img.height * k), Image.NEAREST)
        if x + big.width > sheet.width - pad:
            x, y, row_h = pad, y + row_h + pad, 0
        sheet.paste((40, 44, 56), (x, y, x + big.width, y + big.height))
        sheet.paste(big, (x, y), big)
        sheet.paste((224, 70, 63), (x + ax * k, y + ay * k, x + ax * k + k, y + ay * k + k))
        x += big.width + pad
        row_h = max(row_h, big.height)
    sheet.crop((0, 0, sheet.width, y + row_h + pad)).save(OUT / "imported_contact.png")
    print("wrote", OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
