"""Turn the owner's target painting of the arena into the arena's ground art.

Reads art/reference/arena_target_look.png (807x488, the look the human asked for on 2026-10-21: a ruined stone
plaza in a forest clearing with a rune ring, a raised medallion platform, a statue shrine, an altar, broken walls
and a dense forest border), trims the flat screenshot border, resizes it to the arena (800x480, Tuning.ARENA_SIZE)
and turns it into hard pixel art in the Totoy 36 palette:

1. a mild grade (a little more contrast, a little less saturation so pale stone does not turn yellow-green);
2. a nearest-colour snap in Lab (lightness weighted, so stone, moss and dirt keep their light/dark structure) to the
   palette without the reserved combat colours (x, y, z, A). An ordered (Bayer) dither is available (DITHER) but off:
   the painting is already pixel-art-like at this size and the dither only added checker noise to the flagstones. A
   median pre-filter was tried too and dropped (it erased the dark joints between the stones and the rune glyphs);
3. a cleanup pass: lone pixels whose 8 neighbours mostly agree on one colour take that colour (the glowing rune
   colours are kept, so the ring still reads).

Writes presentation/arena/arena_ground.png (800x480, opaque, palette colours only). Deterministic: no randomness
(SEED is recorded for the art tools' convention; nothing random runs).
Run from the project root:  python tools/art/make_arena_ground_from_reference.py [--preview DIR]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageEnhance

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from import_reference import srgb_to_lab  # noqa: E402

ROOT = artlib.ROOT
SOURCE = ROOT / "art" / "reference" / "arena_target_look.png"
OUT = ROOT / "presentation" / "arena" / "arena_ground.png"
W, H = 800, 480
SEED = 20261021
# the screenshot's flat border: 5 grey rows at the top and one dark column at the left
TRIM = (1, 5, 807, 488)
# 4x4 Bayer matrix, values 0..15
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
DITHER = 0.0  # RGB amplitude of the ordered dither (0 = off, see above)
LIGHTNESS_WEIGHT = 2.0
# extra cost (Lab distance squared) of the violet ink for green-dominant pixels, so the dark forest reads green
INK_PENALTY = 120.0
# colours the cleanup never removes (the rune glow and the brightest highlights)
KEEP = {"u", "o", "p", "1"}

palette = artlib.load_palette()


def prepare(src: Image.Image) -> Image.Image:
    img = src.convert("RGB").crop(TRIM).resize((W, H), Image.LANCZOS)
    img = ImageEnhance.Contrast(img).enhance(1.05)
    return ImageEnhance.Color(img).enhance(0.95)


class Snapper:
    def __init__(self) -> None:
        reserved = set(palette.reserved)
        self.choices = [(sym, srgb_to_lab(rgb), rgb) for sym, rgb in palette.by_symbol.items() if sym not in reserved]
        self.cache: dict[tuple[int, int, int], str] = {}

    def snap(self, rgb: tuple[int, int, int]) -> str:
        hit = self.cache.get(rgb)
        if hit is None:
            lab = srgb_to_lab(rgb)
            # the ink is violet: a green shadow should stay green unless it is really black
            greenish = rgb[1] > rgb[0] and rgb[1] > rgb[2]
            best = min(self.choices, key=lambda c: (c[1][0] - lab[0]) ** 2 * LIGHTNESS_WEIGHT + (c[1][1] - lab[1]) ** 2 + (c[1][2] - lab[2]) ** 2 + (INK_PENALTY if greenish and c[0] in ("0", "8") else 0.0))
            hit = best[0]
            self.cache[rgb] = hit
        return hit


def snap_image(img: Image.Image) -> list[list[str]]:
    snapper = Snapper()
    px = img.load()
    grid: list[list[str]] = []
    for y in range(H):
        row: list[str] = []
        for x in range(W):
            r, g, b = px[x, y]
            d = (BAYER[y % 4][x % 4] / 15.0 - 0.5) * DITHER
            q = (min(255, max(0, int(r + d))) // 2 * 2, min(255, max(0, int(g + d))) // 2 * 2, min(255, max(0, int(b + d))) // 2 * 2)
            row.append(snapper.snap(q))
        grid.append(row)
    return grid


def cleanup(grid: list[list[str]], passes: int = 1) -> list[list[str]]:
    for _ in range(passes):
        out = [row[:] for row in grid]
        for y in range(H):
            for x in range(W):
                sym = grid[y][x]
                if sym in KEEP:
                    continue
                counts: dict[str, int] = {}
                same = 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        n = grid[min(H - 1, max(0, y + dy))][min(W - 1, max(0, x + dx))]
                        counts[n] = counts.get(n, 0) + 1
                        if n == sym:
                            same += 1
                if same <= 1:
                    best, count = max(counts.items(), key=lambda kv: kv[1])
                    if count >= 5:
                        out[y][x] = best
        grid = out
    return grid


def to_image(grid: list[list[str]]) -> Image.Image:
    out = Image.new("RGB", (W, H))
    po = out.load()
    for y in range(H):
        for x in range(W):
            po[x, y] = palette.by_symbol[grid[y][x]]
    return out


def build() -> Image.Image:
    return to_image(cleanup(snap_image(prepare(Image.open(SOURCE)))))


def check(img: Image.Image) -> list[str]:
    allowed = {rgb for sym, rgb in palette.by_symbol.items() if sym not in palette.reserved}
    problems: list[str] = []
    if img.size != (W, H):
        problems.append(f"size {img.size} is not {(W, H)}")
    stray = {c for c in img.convert("RGB").get_flattened_data() if c not in allowed}
    if stray:
        problems.append(f"colours outside the palette (or reserved): {sorted(stray)[:5]}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--preview", help="also write a 2x preview and the prepared (unsnapped) image into this folder")
    parser.add_argument("--out", default=str(OUT), help="output path (default: presentation/arena/arena_ground.png)")
    args = parser.parse_args()
    if not SOURCE.exists():
        print("missing", SOURCE)
        return 1
    out = build()
    problems = check(out)
    if problems:
        for p in problems:
            print("ERROR:", p)
        return 1
    path = Path(args.out)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    if args.preview:
        folder = Path(args.preview)
        folder.mkdir(parents=True, exist_ok=True)
        out.resize((W * 2, H * 2), Image.NEAREST).save(folder / "arena_ground_2x.png")
        prepare(Image.open(SOURCE)).save(folder / "arena_ground_prepared.png")
    print("wrote", path, out.size, "palette check OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
