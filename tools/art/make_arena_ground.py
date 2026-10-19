"""Lay the ground of the ruins arena (800x480 = 50x30 tiles) on the 16x16 grid from the game's own tiles in art/src.

- grass_* everywhere outside the plaza;
- one big stone plaza (stone_* tiles in rows) with cut corners, a mossy rim (mossstone_*), a few grass tiles breaking
  into its edge, a few moss patches (mossstone_*) and a few worn spots (cracked_*);
- the overlay tiles from tools/art/make_plaza_tiles.py on top: the double ring (plaza_ring_*, a quarter mirrored four
  ways) and the medallion in the middle (plaza_emblem_*).

Every tile goes on a whole tile cell; tiles may be mirrored left-right (and the ring quarter both ways), never altered,
so every pixel is a palette colour. Writes presentation/arena/arena_ground.png. Deterministic (fixed seed).

Run from the project root:  python tools/art/make_arena_ground.py
(after editing the plaza tiles: python tools/art/make_plaza_tiles.py first, then validate/build/preview as usual)
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
SRC = artlib.SRC_DIR
OUT = ROOT / "presentation" / "arena" / "arena_ground.png"
T = 16
COLS, ROWS = 50, 30  # 800x480, must match Tuning.ARENA_SIZE
W, H = COLS * T, ROWS * T
SEED = 20261019
# the plaza, in tile cells (inclusive): leaves a grass border for the wall, the trees and the flowers
PLAZA = (4, 3, 45, 26)
CUT = 3  # corner cut, in cells
CENTER = (25, 15)  # the ring and the medallion are centred on this grid corner (world 400, 240)
# moss patches on the plaza: (col, row, radius in cells)
MOSS = [(9, 7, 3.4), (40, 21, 3.6), (11, 22, 2.8), (37, 6, 2.8), (25, 4, 2.2), (25, 25, 2.4), (6, 15, 2.6), (43, 13, 2.4),
        (17, 12, 1.8), (33, 18, 2.0), (20, 22, 1.6), (30, 8, 1.6), (13, 14, 1.5), (38, 14, 1.5), (28, 24, 1.4), (22, 7, 1.4)]
# where the grass has broken into the plaza's edge (centred on the rim): (col, row, radius in cells)
BREAKS = [(5, 4, 2.2), (44, 25, 2.4), (45, 4, 1.3)]
# worn, cracked spots: where the fallen stones lie (presentation/arena/arena_decor.gd)
CRACKED = [(14, 20, 1.3), (35, 9, 1.2), (31, 23, 1.0), (18, 6, 1.0)]

palette = artlib.load_palette()


def tile(name: str) -> Image.Image:
    lines = [ln for ln in (SRC / f"{name}.txt").read_text(encoding="utf-8").splitlines() if ln and not ln.startswith("#")]
    img = Image.new("RGBA", (len(lines[0]), len(lines)), (0, 0, 0, 0))
    for y, row in enumerate(lines):
        for x, ch in enumerate(row):
            if ch != palette.transparent:
                img.putpixel((x, y), palette.by_symbol[ch] + (255,))
    return img


def family(prefix: str, count: int) -> list[Image.Image]:
    return [tile(f"{prefix}_{i}") for i in range(1, count + 1)]


def in_plaza(c: int, r: int) -> bool:
    x0, y0, x1, y1 = PLAZA
    if not (x0 <= c <= x1 and y0 <= r <= y1):
        return False
    dx = min(c - x0, x1 - c)
    dy = min(r - y0, y1 - r)
    return dx + dy >= CUT  # cut corners (a diagonal)


def rim(c: int, r: int) -> bool:
    """A plaza cell next to the grass."""
    return in_plaza(c, r) and not all(in_plaza(c + dc, r + dr) for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def near(spots: list[tuple[int, int, float]], c: int, r: int, rnd: random.Random, grow: float = 0.0) -> bool:
    return any(math.hypot(c - sc, r - sr) <= rad + grow + rnd.uniform(-0.4, 0.4) for sc, sr, rad in spots)


def pick(pool: list[Image.Image], rnd: random.Random, avoid: set[int]) -> tuple[int, Image.Image]:
    """A random tile of the pool, not the same as its left or upper neighbour, mirrored half the time."""
    choices = [i for i in range(len(pool)) if i not in avoid] or list(range(len(pool)))
    i = rnd.choice(choices)
    img = pool[i]
    return i, (img.transpose(Image.FLIP_LEFT_RIGHT) if rnd.random() < 0.5 else img)


def main() -> int:
    rnd = random.Random(SEED)
    grass, stone, moss, cracked = family("grass", 16), family("stone", 16), family("mossstone", 8), family("cracked", 8)
    pools = {"grass": grass, "stone": stone, "moss": moss, "cracked": cracked}
    out = Image.new("RGBA", (W, H))
    kinds: list[list[str]] = [["grass"] * COLS for _ in range(ROWS)]
    for r in range(ROWS):
        for c in range(COLS):
            if not in_plaza(c, r):
                continue
            if near(BREAKS, c, r, rnd):
                kinds[r][c] = "grass"  # the grass has taken back a corner of the plaza
            elif rim(c, r) and rnd.random() < 0.2:
                kinds[r][c] = "grass"  # ragged edge: grass creeps in along the rim
            elif rim(c, r) or near(BREAKS, c, r, rnd, 1.2):
                kinds[r][c] = "moss"  # the mossy rim of the plaza
            elif in_plaza(c, r) and not all(in_plaza(c + dc, r + dr) for dc, dr in ((2, 0), (-2, 0), (0, 2), (0, -2))) and rnd.random() < 0.45:
                kinds[r][c] = "moss"  # a second, broken band of moss behind the rim
            elif near(MOSS, c, r, rnd):
                kinds[r][c] = "moss"
            elif near(CRACKED, c, r, rnd):
                kinds[r][c] = "cracked"
            else:
                kinds[r][c] = "stone"
    chosen: list[list[int]] = [[-1] * COLS for _ in range(ROWS)]
    for r in range(ROWS):
        for c in range(COLS):
            kind = kinds[r][c]
            avoid = set()
            if c > 0 and kinds[r][c - 1] == kind:
                avoid.add(chosen[r][c - 1])
            if r > 0 and kinds[r - 1][c] == kind:
                avoid.add(chosen[r - 1][c])
            i, img = pick(pools[kind], rnd, avoid)
            chosen[r][c] = i
            out.paste(img, (c * T, r * T))
            if kind == "moss":
                # moss that reads: clumps of grass-tile pixels (2x2 blocks) over the stone, thicker on the rim
                chance = 0.5 if rim(c, r) else 0.28
                _, g = pick(grass, rnd, set())
                for by in range(0, T, 2):
                    for bx in range(0, T, 2):
                        if rnd.random() < chance:
                            for yy in range(by, by + 2):
                                for xx in range(bx, bx + 2):
                                    out.putpixel((c * T + xx, r * T + yy), g.getpixel((xx, yy)))
    # the ring: a quarter of tiles, mirrored into the four quarters around CENTER
    ox, oy = CENTER[0] * T, CENTER[1] * T
    for path in sorted(SRC.glob("plaza_ring_*.txt")):
        _, _, tx, ty = path.stem.split("_")
        img = tile(path.stem)
        qx, qy = int(tx) * T, int(ty) * T  # inside the quarter; the quarter's bottom-right corner is the centre
        qw, qh = 11 * T, 7 * T
        lx, ty_ = ox - qw + qx, oy - qh + qy
        rx = ox + (qw - qx - T)
        by = oy + (qh - qy - T)
        mirrored_x = img.transpose(Image.FLIP_LEFT_RIGHT)
        out.alpha_composite(img, (lx, ty_))
        out.alpha_composite(mirrored_x, (rx, ty_))
        out.alpha_composite(img.transpose(Image.FLIP_TOP_BOTTOM), (lx, by))
        out.alpha_composite(mirrored_x.transpose(Image.FLIP_TOP_BOTTOM), (rx, by))
    # the medallion: 4x4 tiles centred on CENTER
    for n in range(16):
        out.alpha_composite(tile(f"plaza_emblem_{n + 1}"), (ox - 2 * T + (n % 4) * T, oy - 2 * T + (n // 4) * T))
    out = out.convert("RGB")
    allowed = set(palette.by_symbol.values())
    pixels = out.get_flattened_data() if hasattr(out, "get_flattened_data") else out.getdata()
    stray = {px for px in pixels if px not in allowed}
    if stray:
        print("ERROR: colours outside the palette", sorted(stray)[:5])
        return 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print("wrote", OUT, out.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
