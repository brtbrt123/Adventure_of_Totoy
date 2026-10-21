"""Import the human's reference art (a sprite sheet and a portrait) as palette-bound game sprites.

The reference images are large painted pixel art with a baked-in checkerboard background and thousands of
colours. This tool cuts each pose out of the sheet, keys out the checkerboard, shrinks it with area
averaging, snaps every pixel to the Totoy 36 palette (no dithering, hard alpha, a 1px ink outline) and
writes text-grid sources into art/src with an `# anchor:` (the feet) so presentation can place and mirror
frames of different sizes. Re-run it to regenerate the hero art; the numbers below are the only choices.

Usage:
  python tools/art/import_reference.py --sheet art/reference/hero_sheet.jpg --portrait art/reference/hero_portrait.jpg
         [--scale 7.4] [--replace] [--preview OUT.png]
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

import artlib

LABEL_X = 300  # the row labels (WALK, ATTACK, ...) on the sheet are left of this

# (output state name, source box on the sheet (x0, y0, x1, y1), feet x on the sheet, allow gold)
# The sheet is a right-facing side view only. Boxes were measured from the sheet; a frame that shares a
# box with another pose was split by x. Frame 2.2 contains an enemy fighter, which is cropped away.
FRAMES: list[tuple[str, tuple[int, int, int, int], int, bool]] = [
    ("walk_right_1", (306, 21, 494, 287), 395, False),
    ("walk_right_2", (554, 25, 680, 287), 615, False),
    ("walk_right_3", (754, 21, 946, 287), 855, False),
    ("walk_right_4", (1007, 20, 1125, 287), 1065, False),
    ("dash_right_1", (337, 320, 629, 553), 510, False),
    ("attack_windup_right_1", (337, 320, 629, 553), 510, False),
    ("attack_active_right_1", (749, 320, 1062, 553), 815, False),
    ("attack_active_right_2", (1062, 320, 1601, 553), 1215, False),
    ("attack_recovery_right_1", (1641, 317, 1977, 553), 1710, False),
    ("parry_right_1", (325, 556, 517, 825), 430, False),
    ("parry_right_2", (566, 559, 733, 825), 650, False),
    ("parry_right_3", (812, 556, 1000, 825), 885, True),
    ("parry_recovery_right_1", (566, 559, 733, 825), 650, False),
    ("dead_right_1", (367, 888, 589, 1087), 480, False),
    ("dead_right_2", (800, 888, 1214, 1090), 930, False),
    ("dead_right_3", (1232, 937, 1494, 1087), 1360, False),
]
# idle reuses two standing walk poses
FRAME_COPIES: list[tuple[str, str]] = [("idle_right_1", "walk_right_2"), ("idle_right_2", "walk_right_4")]

PORTRAIT_BOX = (330, 0, 1590, 1260)  # square crop around the head of the portrait
PORTRAIT_SIZE = 48


def is_background(r: int, g: int, b: int) -> bool:
    """The sheet's fake-transparency checkerboard: two neutral greys (about 136 and 184)."""
    if max(r, g, b) - min(r, g, b) > 9:
        return False
    return 120 <= (r + g + b) // 3 <= 196


def figure_mask(image: Image.Image) -> Image.Image:
    px = image.load()
    mask = Image.new("L", image.size, 0)
    mp = mask.load()
    for y in range(image.height):
        for x in range(image.width):
            if not is_background(*px[x, y]):
                mp[x, y] = 255
    # close small holes inside the figure, drop isolated specks of misclassified checker pixels
    closed = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    return closed.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))


def srgb_to_lab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    def lin(c: float) -> float:
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


class Quantizer:
    def __init__(self, palette: artlib.Palette, allow_gold: bool) -> None:
        reserved = set(palette.reserved)
        if allow_gold:
            reserved -= {"x", "y"}  # the parry spark may use gold; red stays off the hero
        self.choices = [(sym, srgb_to_lab(rgb)) for sym, rgb in palette.by_symbol.items() if sym not in reserved]
        self.cache: dict[tuple[int, int, int], str] = {}

    def symbol(self, rgb: tuple[int, int, int]) -> str:
        hit = self.cache.get(rgb)
        if hit is None:
            lab = srgb_to_lab(rgb)
            hit = min(self.choices, key=lambda c: (c[1][0] - lab[0]) ** 2 * 1.4 + (c[1][1] - lab[1]) ** 2 + (c[1][2] - lab[2]) ** 2)[0]
            self.cache[rgb] = hit
        return hit


def shrink(image: Image.Image, mask: Image.Image, scale: float) -> tuple[Image.Image, Image.Image]:
    """Area-average downscale with premultiplied alpha, so the figure does not pick up background halos."""
    w, h = max(1, round(image.width / scale)), max(1, round(image.height / scale))
    r, g, b = image.split()
    pre = [ImageChops.multiply(c, mask) for c in (r, g, b)]
    small_pre = [c.resize((w, h), Image.BOX) for c in pre]
    small_a = mask.resize((w, h), Image.BOX)
    return Image.merge("RGB", small_pre), small_a


def to_grid(small_pre: Image.Image, small_a: Image.Image, quant: Quantizer, palette: artlib.Palette, threshold: int = 120) -> list[list[str]]:
    w, h = small_a.size
    pp, ap = small_pre.load(), small_a.load()
    grid = [[palette.transparent] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            a = ap[x, y]
            if a < threshold:
                continue
            r, g, b = pp[x, y]
            k = 255.0 / a
            grid[y][x] = quant.symbol((min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k))))
    return grid


def outline(grid: list[list[str]], palette: artlib.Palette, ink: str = "0") -> None:
    """Give the silhouette a 1px ink edge inside the figure (keeps size) so it reads on the grass."""
    h, w = len(grid), len(grid[0])
    lab_ink = srgb_to_lab(palette.by_symbol[ink])[0]
    edge = []
    for y in range(h):
        for x in range(w):
            if grid[y][x] == palette.transparent:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or grid[ny][nx] == palette.transparent:
                    edge.append((x, y))
                    break
    for x, y in edge:
        if srgb_to_lab(palette.by_symbol[grid[y][x]])[0] > lab_ink + 14:
            grid[y][x] = ink


def despeckle(grid: list[list[str]], transparent: str) -> None:
    """Remove isolated opaque pixels (JPEG noise and loose effect crumbs) so the silhouette stays clean."""
    h, w = len(grid), len(grid[0])
    loose = []
    for y in range(h):
        for x in range(w):
            if grid[y][x] == transparent:
                continue
            around = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if (dx or dy) and 0 <= x + dx < w and 0 <= y + dy < h and grid[y + dy][x + dx] != transparent:
                        around += 1
            if around <= 1:
                loose.append((x, y))
    for x, y in loose:
        grid[y][x] = transparent


def trim(grid: list[list[str]], transparent: str) -> tuple[list[list[str]], int, int]:
    rows = [i for i, r in enumerate(grid) if any(c != transparent for c in r)]
    cols = [i for i in range(len(grid[0])) if any(r[i] != transparent for r in grid)]
    if not rows:
        return grid, 0, 0
    x0, x1, y0, y1 = cols[0], cols[-1] + 1, rows[0], rows[-1] + 1
    return [r[x0:x1] for r in grid[y0:y1]], x0, y0


def write_sprite(path: Path, grid: list[list[str]], anchor: tuple[int, int] | None, note: str, transparent: str) -> None:
    h, w = len(grid), len(grid[0])
    cw, ch = -(-(w + 2) // 8) * 8, -(-(h + 2) // 8) * 8
    canvas = [[transparent] * cw for _ in range(ch)]
    for y in range(h):
        for x in range(w):
            canvas[y + 1][x + 1] = grid[y][x]
    lines = ["# kind: sprite"]
    if anchor is not None:
        lines.append(f"# anchor: {anchor[0] + 1},{anchor[1] + 1}")
    lines.append(f"# {note}")
    lines += ["".join(row) for row in canvas]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--portrait", type=Path, required=True)
    parser.add_argument("--scale", type=float, default=8.6, help="source pixels per game pixel for the sheet")
    parser.add_argument("--replace", action="store_true", help="delete the old totoy_* sources first")
    parser.add_argument("--out", type=Path, default=artlib.SRC_DIR)
    args = parser.parse_args()

    palette = artlib.load_palette()
    sheet = Image.open(args.sheet).convert("RGB")
    mask = figure_mask(sheet)
    if args.replace:
        for old in args.out.glob("totoy_*.txt"):
            old.unlink()
    written: dict[str, Path] = {}
    for name, box, feet_x, gold in FRAMES:
        crop = sheet.crop(box)
        cmask = mask.crop(box)
        small_pre, small_a = shrink(crop, cmask, args.scale)
        grid = to_grid(small_pre, small_a, Quantizer(palette, gold), palette)
        despeckle(grid, palette.transparent)
        outline(grid, palette)
        trimmed, ox, oy = trim(grid, palette.transparent)
        anchor_x = (feet_x - box[0]) / args.scale - ox
        anchor_y = len(trimmed)  # the bottom of the figure
        path = args.out / f"totoy_{name}.txt"
        write_sprite(path, trimmed, (round(anchor_x), anchor_y), f"imported from the reference sheet, scale {args.scale}", palette.transparent)
        written[name] = path
    for copy_name, source_name in FRAME_COPIES:
        (args.out / f"totoy_{copy_name}.txt").write_text(written[source_name].read_text(encoding="utf-8"), encoding="utf-8", newline="\n")

    portrait = Image.open(args.portrait).convert("RGB").crop(PORTRAIT_BOX)
    small = portrait.resize((PORTRAIT_SIZE, PORTRAIT_SIZE), Image.BOX)
    quant = Quantizer(palette, False)
    grid = [[quant.symbol(small.getpixel((x, y))) for x in range(PORTRAIT_SIZE)] for y in range(PORTRAIT_SIZE)]
    lines = ["# kind: sprite", "# imported from the reference portrait"] + ["".join(row) for row in grid]
    (args.out / "totoy_portrait.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {len(FRAMES) + len(FRAME_COPIES)} hero frames and the portrait to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
