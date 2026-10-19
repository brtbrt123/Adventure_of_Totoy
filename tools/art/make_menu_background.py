"""Compose the title-screen background from the game's own art.

A dusk view of the Mossbound Colossus's arena: grass outside, a ring of ruined flagstones and cracked ground in the
middle, ruins, trees and walls around the edge, all from the real tiles and props in art/src, then graded to dusk and
snapped to the Totoy 36 palette (no reserved gold/red). No characters are in the picture.

Writes presentation/menu/menu_background.png (320x180). Deterministic (fixed seed).
Run from the project root:  python tools/art/make_menu_background.py [--preview]
"""
from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from import_reference import srgb_to_lab  # noqa: E402

ROOT = artlib.ROOT
SRC = artlib.SRC_DIR
OUT = ROOT / "presentation" / "menu" / "menu_background.png"
W, H = 320, 180
SEED = 20261019

palette = artlib.load_palette()


def grid_image(name: str) -> tuple[Image.Image, tuple[int, int] | None]:
    lines = (SRC / f"{name}.txt").read_text(encoding="utf-8").splitlines()
    anchor = None
    rows = []
    for line in lines:
        if line.startswith("# anchor:"):
            x, y = line.split(":")[1].split(",")
            anchor = (int(x), int(y))
        elif not line.startswith("#"):
            rows.append(line)
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != palette.transparent:
                img.putpixel((x, y), palette.by_symbol[ch] + (255,))
    return img, anchor


# ---------------------------------------------------------------- ground
def tiled(rnd: random.Random, pool: list[Image.Image]) -> Image.Image:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for gy in range(-1, 12):
        for gx in range(20):
            tile = rnd.choice(pool)
            if rnd.random() < 0.5:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            layer.paste(tile, (gx * 16, gy * 16))
    return layer


def blob_noise(rnd: random.Random, cell: int, amount: float) -> Image.Image:
    """Smooth value noise in [-amount, amount] as an L image (128 = 0), chunky so the edge looks hand-made."""
    small = Image.new("L", (W // cell + 2, H // cell + 2))
    for y in range(small.height):
        for x in range(small.width):
            small.putpixel((x, y), rnd.randrange(256))
    return small.resize((small.width * cell, small.height * cell), Image.BICUBIC).crop((0, 0, W, H))


def build_ground(rnd: random.Random) -> Image.Image:
    grass_layer = tiled(rnd, [grid_image(f"grass_{i}")[0] for i in range(1, 17)])
    stone_layer = tiled(rnd, [grid_image(f"stone_{i}")[0] for i in range(1, 17)] * 2 + [grid_image(f"cracked_{i}")[0] for i in range(1, 9)])
    moss_layer = tiled(rnd, [grid_image(f"mossstone_{i}")[0] for i in range(1, 9)] + [grid_image(f"stone_{i}")[0] for i in range(1, 9)])
    noise = blob_noise(rnd, 14, 0.12)
    cx, cy, rx, ry = 160.0, 118.0, 140.0, 58.0
    ground = grass_layer.copy()
    gp, sp, mp, npx, op = grass_layer.load(), stone_layer.load(), moss_layer.load(), noise.load(), ground.load()
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - cx) / rx, (y - cy) / ry) + (npx[x, y] / 255.0 - 0.5) * 0.30
            if d < 0.86:
                op[x, y] = sp[x, y]
            elif d < 1.0:
                op[x, y] = mp[x, y]  # mossy flagstones fade into the grass
    return ground


# ---------------------------------------------------------------- props
def place(canvas: Image.Image, name: str, feet: tuple[int, int], flip: bool = False) -> None:
    img, anchor = grid_image(name)
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
        anchor = (img.width - 1 - anchor[0], anchor[1]) if anchor else None
    ax, ay = anchor if anchor else (img.width // 2, img.height - 1)
    canvas.alpha_composite(img, (feet[0] - ax, feet[1] - ay))


def shadow(canvas: Image.Image, centre: tuple[int, int], rx: int, ry: int, strength: float = 0.55) -> None:
    layer = Image.new("L", (W, H), 0)
    ImageDraw.Draw(layer).ellipse((centre[0] - rx, centre[1] - ry, centre[0] + rx, centre[1] + ry), fill=int(255 * strength))
    dark = Image.new("RGBA", (W, H), (10, 8, 20, 0))
    dark.putalpha(layer)
    canvas.alpha_composite(dark)


def add_props(canvas: Image.Image) -> None:
    items = [
        # (name, feet x, feet y, flip): sorted by y below so nearer props cover farther ones
        ("prop_nature_6", 18, 64, False), ("prop_nature_7", 58, 52, True), ("prop_nature_5", 268, 50, False), ("prop_nature_6", 306, 66, True),
        ("prop_ruins_1", 30, 104, False), ("prop_ruins_3", 290, 100, True), ("prop_ruins_6", 66, 128, False),
        ("prop_ruins_2", 254, 124, True), ("prop_wall_1", 22, 172, False), ("prop_wall_1", 298, 172, True),
        ("prop_nature_1", 8, 128, False), ("prop_nature_1", 312, 132, True), ("prop_small_3", 120, 168, False),
        ("prop_small_1", 214, 170, False), ("prop_small_5", 168, 176, False), ("prop_nature_8", 40, 160, False), ("prop_nature_8", 282, 158, True),
    ]
    for name, x, y, flip in sorted(items, key=lambda i: i[2]):
        shadow(canvas, (x, y), 12, 3, 0.45)
        place(canvas, name, (x, y), flip)


# ---------------------------------------------------------------- grading
def grade(img: Image.Image) -> Image.Image:
    rgb = img.convert("RGB")
    # dusk: slightly cool and a little dark (the palette's darks are few, so the grade stays gentle)
    tint = Image.new("RGB", rgb.size, (212, 208, 242))
    dusk = ImageChops.multiply(rgb, tint).point(lambda v: int(v * 0.9))
    # a soft pool of moonlight on the arena floor
    glow = Image.new("L", rgb.size, 0)
    ImageDraw.Draw(glow).ellipse((60, 70, 260, 170), fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(22))
    dusk = ImageChops.add(dusk, Image.merge("RGB", [glow.point(lambda v: int(v * 0.4)), glow.point(lambda v: int(v * 0.5)), glow.point(lambda v: int(v * 0.65))]))
    # vignette: darker toward the corners, and a little toward the top where the title sits
    vig = Image.radial_gradient("L").resize((W, H)).point(lambda v: int(max(0, v - 70) * 0.9))
    top = Image.linear_gradient("L").resize((W, H)).rotate(180).point(lambda v: int(v * 0.22 if v > 120 else 0))
    shade = ImageChops.add(vig, top)
    dark = Image.new("RGB", rgb.size, (28, 24, 36))
    out = Image.composite(dark, dusk, shade)
    # calm band behind the menu so the lettering reads
    band = Image.new("L", rgb.size, 0)
    ImageDraw.Draw(band).rounded_rectangle((92, 76, 228, 144), radius=16, fill=110)
    band = band.filter(ImageFilter.GaussianBlur(10))
    return Image.composite(dark, out, band)


class Snapper:
    def __init__(self) -> None:
        reserved = set(palette.reserved)
        self.choices = [(sym, srgb_to_lab(rgb), rgb) for sym, rgb in palette.by_symbol.items() if sym not in reserved]
        self.cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}

    def snap(self, rgb: tuple[int, int, int]) -> tuple[int, int, int]:
        hit = self.cache.get(rgb)
        if hit is None:
            lab = srgb_to_lab(rgb)
            best = min(self.choices, key=lambda c: (c[1][0] - lab[0]) ** 2 * 1.4 + (c[1][1] - lab[1]) ** 2 + (c[1][2] - lab[2]) ** 2)
            hit = best[2]
            self.cache[rgb] = hit
        return hit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", action="store_true", help="also write a 4x preview next to the output")
    args = parser.parse_args()
    rnd = random.Random(SEED)
    canvas = build_ground(rnd)
    add_props(canvas)
    graded = grade(canvas)
    snapper = Snapper()
    out = Image.new("RGB", graded.size)
    px = graded.load()
    po = out.load()
    for y in range(H):
        for x in range(W):
            po[x, y] = snapper.snap(px[x, y])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    allowed = {rgb for sym, rgb in palette.by_symbol.items() if sym not in palette.reserved}
    stray = {c for c in out.getdata() if c not in allowed}
    if stray:
        print("ERROR: colours outside the palette:", sorted(stray)[:5])
        return 1
    if args.preview:
        out.resize((W * 4, H * 4), Image.NEAREST).save(OUT.with_name("menu_background_preview.png"))
    print("wrote", OUT, out.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
