"""Make the restored arena ground for the Chapter 1 ending (S6 beacon epilogue).

Reads the palette-bound arena ground (presentation/arena/arena_ground.png, 800x480, made by
make_arena_ground_from_reference.py) and writes presentation/arena/arena_ground_restored.png: the same arena after
the victory, peaceful and restored. Every edit is a palette-step edit on the existing pixels; nothing is moved, so
the colliders in core/arena_layout.gd still match every wall, pillar, rubble pile and the altar.

The edits, in order:
1. a light field (in palette ramp steps): a moderate lift everywhere, more in the dark forest ring, a soft warm-teal
   pool of light centred on the platform that spills over the plaza, a glow along the rune ring and around the
   medallion. Each pixel moves up its own ramp (grass, stone, dirt) by floor(lift + Bayer threshold), so the falloff
   is an ordered dither between neighbouring ramp steps; the darkest joints get less lift, which keeps the contrast;
2. the rune ring: glyphs one or two steps brighter (teal -> pale), the dark glyph slots glow teal next to a glyph,
   and a soft dithered pale-teal halo on the grass just inside and outside the ring stones; the same around the
   medallion on the platform;
3. warm-teal light on the platform and the inner plaza: the brightest lifted stone takes pale cyan (p) or cream (1)
   in an ordered checker, so the light reads warm and teal at once;
4. moss creeps one pixel onto stone where it already grows (seeded, only where 3+ neighbours are green);
5. a few small clusters of flowers and petals in the moss on the stones (seeded).

Only palette colours, opaque; the reserved combat colours (gold x,y and red z,A) are never written.
Deterministic (fixed SEED): two runs give byte-identical files.
Run from the project root:  python tools/art/make_arena_restored_ground.py
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
SRC = ROOT / "presentation" / "arena" / "arena_ground.png"
OUT = ROOT / "presentation" / "arena" / "arena_ground_restored.png"
SEED = 20261021
W, H = 800, 480

# geometry measured on arena_ground.png (screen = world coordinates)
RING_C = (400.0, 244.0)        # rune ring centre
RING_R = (152.0, 92.0)         # ellipse through the glyph band
PLATFORM_C = (400.0, 248.0)    # the raised round platform
PLATFORM_R = 52.0
MEDAL_C = (400.0, 245.0)       # the shield medallion
MEDAL_R = 22.0
POOL_C = (400.0, 250.0)        # the pool of light
POOL_R = (330.0, 200.0)
# the walkable clearing (core/arena_layout.gd BOUNDARY): outside it is the forest ring
BOUNDARY = [(110, 88), (246, 88), (262, 76), (372, 74), (430, 74), (546, 76), (556, 88), (694, 88), (694, 200),
            (744, 206), (744, 276), (694, 280), (694, 418), (108, 418), (108, 276), (76, 270), (76, 200), (110, 192)]

LIFT_CLEARING = 0.75   # ramp steps everywhere inside the clearing
LIFT_FOREST = 1.0      # ramp steps in the forest ring
POOL_LIFT = 1.05       # extra steps at the pool centre
RING_LIFT = 0.6        # extra steps on the ring band
GREEN_LIGHT_EXTRA = 0.35  # grass and moss take a little more of the light than stone (warm yellow-green tops)
STONE_BASE = 0.2       # stone and dirt outside the light keep their tones
BAND_EDGE = 0.2        # width (in steps) of the dithered edge between two light bands on stone and dirt
# the threshold that decides which pixels of a fractional lift step up: mostly the pixel's own brightness against
# its neighbours (highlights step up first, so the texture is kept and flat areas get no checker), a little Bayer
TEXTURE_GAIN = 1.0 / 40.0
BAYER_MIX = 0.08
INK_DROP = 0.7         # the darkest pixels (ink, stone_1, dirt_1) get this much less lift: keeps the contrast

GREEN = ["2", "3", "4", "5", "6", "7"]
STONE = ["e", "f", "g", "h", "i", "j"]
DIRT = ["8", "9", "a", "b", "c", "d"]
GLYPH_UP = {"t": "u", "u": "o", "o": "p", "p": "p"}
BAYER8 = [
    [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26], [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22], [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21],
]
# flower looks: (petal, centre)
FLOWERS = [("p", "6"), ("s", "1"), ("v", "p"), ("1", "6"), ("o", "1"), ("s", "p")]

palette = artlib.load_palette()
RESERVED = set(palette.reserved)


def bayer(x: int, y: int) -> float:
    return (BAYER8[y & 7][x & 7] + 0.5) / 64.0


def luma(rgb: tuple[int, int, int]) -> float:
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def texture_threshold(grid: list[list[str]]) -> list[list[float]]:
    lum = Image.new("L", (W, H))
    lum.putdata([int(luma(palette.by_symbol[grid[y][x]])) for y in range(H) for x in range(W)])
    mean = lum.filter(ImageFilter.MedianFilter(5)).load()  # a median ignores the thin dark joints
    lp = lum.load()
    out = []
    for y in range(H):
        row = []
        for x in range(W):
            t = 0.5 + (lp[x, y] - mean[x, y]) * TEXTURE_GAIN + BAYER_MIX * (bayer(x, y) - 0.5)
            row.append(min(0.999, max(0.0, t)))
        out.append(row)
    return out


def load_symbols() -> list[list[str]]:
    rev = {rgb: sym for sym, rgb in palette.by_symbol.items()}
    img = Image.open(SRC).convert("RGB")
    assert img.size == (W, H), img.size
    px = img.load()
    return [[rev[px[x, y]] for x in range(W)] for y in range(H)]


def mask_image(pred, grid: list[list[str]]) -> Image.Image:
    m = Image.new("L", (W, H), 0)
    m.putdata([255 if pred(grid[y][x]) else 0 for y in range(H) for x in range(W)])
    return m


def ell(x: float, y: float, c: tuple[float, float], r: tuple[float, float]) -> float:
    return math.hypot((x - c[0]) / r[0], (y - c[1]) / r[1])


def smooth(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ring_distance(grid: list[list[str]]) -> list[list[int]]:
    """Pixel distance (1..4, else 0) from the ring's stones, by repeated 3x3 dilation."""
    def is_ring(x: int, y: int) -> bool:
        return abs(ell(x, y, RING_C, RING_R) - 1.0) < 0.1 and (grid[y][x] in STONE or grid[y][x] in "tuop1")
    m = Image.new("L", (W, H), 0)
    m.putdata([255 if is_ring(x, y) else 0 for y in range(H) for x in range(W)])
    out = [[0] * W for _ in range(H)]
    prev = m.load()
    cur_img = m
    for d in range(1, 5):
        cur_img = cur_img.filter(ImageFilter.MaxFilter(3))
        cur = cur_img.load()
        for y in range(H):
            for x in range(W):
                if cur[x, y] and not prev[x, y]:
                    out[y][x] = d
        prev = cur
    return out


def lift_field(clear: Image.Image) -> tuple[list[list[float]], list[list[float]]]:
    """(base lift, light lift): the base is the overall brightening of the greens, the light is the pool, the ring
    glow and the medallion glow (stone and dirt only take the light, in bands)."""
    cl = clear.load()
    out = []
    base = []
    for y in range(H):
        row = []
        brow = []
        for x in range(W):
            c = cl[x, y] / 255.0
            brow.append(LIFT_CLEARING * c + LIFT_FOREST * (1 - c))
            lift = 0.0
            rp = ell(x, y, POOL_C, POOL_R)
            lift += POOL_LIFT * (max(0.0, 1.0 - rp) ** 1.6)
            rr = ell(x, y, RING_C, RING_R)
            lift += RING_LIFT * math.exp(-((rr - 1.0) / 0.075) ** 2)
            dm = math.hypot(x - MEDAL_C[0], y - MEDAL_C[1])
            lift += 0.8 * math.exp(-((dm - MEDAL_R - 4) / 7.0) ** 2)
            row.append(lift)
        out.append(row)
        base.append(brow)
    return base, out


def band_steps(lift: float, x: int, y: int) -> int:
    """Whole ramp steps for a light value: flat bands with a narrow ordered-dither edge between them, so flat stone
    stays flat (no checker) and the pool reads as soft rings of light."""
    n = math.floor(lift)
    t = (lift - n - 0.5) / BAND_EDGE + 0.5
    return int(n) + (1 if t > bayer(x, y) else 0)


def step_ramp(ramp: list[str], i: int, lift: float, b: float) -> str:
    n = int(math.floor(lift + b))
    return ramp[max(0, min(len(ramp) - 1, i + n))]


def restore() -> Image.Image:
    rng = random.Random(SEED)
    g = load_symbols()
    src = [row[:] for row in g]

    clear = Image.new("L", (W, H), 0)
    ImageDraw.Draw(clear).polygon(BOUNDARY, fill=255)
    clear = clear.filter(ImageFilter.GaussianBlur(14))
    greenish = mask_image(lambda s: s in GREEN, src).filter(ImageFilter.BoxBlur(2)).load()
    glyph = mask_image(lambda s: s in "tuop", src)
    near_glyph = glyph.filter(ImageFilter.MaxFilter(3)).load()
    stone_m = mask_image(lambda s: s in STONE or s == "0", src)
    base, light = lift_field(clear)
    thr = texture_threshold(src)
    ring_dist = ring_distance(src)

    # 1. the light field on every ramp
    for y in range(H):
        for x in range(W):
            s = src[y][x]
            b = thr[y][x]
            L = base[y][x] + light[y][x]
            Ls = STONE_BASE + light[y][x]
            if s in "tuop":
                continue
            if s == "0":
                if greenish[x, y] > 110:
                    # ink in the forest/grass: a green below grass_1
                    n = int(math.floor(L - INK_DROP * 0.25 + b))
                    g[y][x] = "0" if n <= 0 else GREEN[min(len(GREEN) - 1, n - 1)]
                else:
                    n = band_steps(Ls - INK_DROP - 0.3, x, y)
                    g[y][x] = "0" if n <= 0 else STONE[min(len(STONE) - 1, n - 1)]
            elif s in GREEN:
                g[y][x] = step_ramp(GREEN, GREEN.index(s), L + GREEN_LIGHT_EXTRA * light[y][x], b)
            elif s in STONE:
                i = STONE.index(s)
                n = band_steps(Ls - (INK_DROP if i == 0 else 0.0), x, y)
                g[y][x] = STONE[max(0, min(len(STONE) - 1, i + n))]
            elif s in DIRT:
                i = DIRT.index(s)
                n = band_steps(Ls * 0.85 + 0.15 * base[y][x] - (INK_DROP if i == 0 else 0.0), x, y)
                g[y][x] = DIRT[max(0, min(len(DIRT) - 1, i + n))]

    # 2. the rune ring and the medallion
    for y in range(H):
        for x in range(W):
            s = src[y][x]
            rr = ell(x, y, RING_C, RING_R)
            dm = math.hypot(x - MEDAL_C[0], y - MEDAL_C[1])
            on_ring = abs(rr - 1.0) < 0.07
            on_medal = dm < MEDAL_R + 2
            if s in "tuop":
                if on_ring or on_medal:
                    g[y][x] = GLYPH_UP[s]
                else:
                    g[y][x] = GLYPH_UP[s] if s in "tu" else s
                continue
            if on_ring and near_glyph[x, y] and s in ("0", "e", "f", "g", "h"):
                # a teal glow bleeds out of every glyph stroke onto its tile
                g[y][x] = "t"
            # halo on the grass right next to the ring stones (inside and outside the ring)
            if (s in GREEN or (s == "0" and greenish[x, y] > 110)) and abs(rr - 1.0) < 0.2:
                d = ring_dist[y][x]
                if d == 1 and thr[y][x] > 0.2:
                    g[y][x] = "u"
                elif d == 2 and thr[y][x] > 0.45:
                    g[y][x] = "u" if thr[y][x] > 0.75 else "t"
                elif d == 3 and thr[y][x] > 0.7:
                    g[y][x] = "t"
            # the medallion's rim: its lit stone turns pale
            if MEDAL_R - 1 < dm < MEDAL_R + 9 and g[y][x] in ("i", "j") and thr[y][x] > 0.35:
                g[y][x] = "p"

    # 3. warm-teal light on the platform and the inner plaza: the top stone steps turn cream near the centre and
    # pale teal further out, highlights first (no checker on flat stone)
    for y in range(H):
        for x in range(W):
            rp = ell(x, y, POOL_C, (POOL_R[0] * 0.45, POOL_R[1] * 0.45))
            if rp >= 1.0 or abs(ell(x, y, RING_C, RING_R) - 1.0) < 0.08:
                continue
            k = smooth(1.0 - rp)
            t = thr[y][x]
            dp = math.hypot(x - PLATFORM_C[0], y - PLATFORM_C[1])
            if g[y][x] == "j" and src[y][x] in ("i", "j") and t > 1.0 - 0.6 * k and dp < PLATFORM_R + 6:
                g[y][x] = "1" if dp < PLATFORM_R - 8 else "p"
            elif g[y][x] == "7" and t > 1.0 - 0.3 * k:
                g[y][x] = "1"

    # 4. moss creeps one pixel onto the stone where it already grows
    snap = [row[:] for row in g]
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            s = snap[y][x]
            if s not in STONE:
                continue
            if abs(ell(x, y, RING_C, RING_R) - 1.0) < 0.1 or math.hypot(x - MEDAL_C[0], y - MEDAL_C[1]) < MEDAL_R + 4:
                continue
            greens = [snap[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx or dy) and snap[y + dy][x + dx] in GREEN]
            if len(greens) >= 3 and rng.random() < 0.45:
                # the moss takes the lighter of its neighbours' tones, but never brighter than the stone it covers
                cand = max(greens, key=GREEN.index)
                g[y][x] = GREEN[min(GREEN.index(cand), max(1, STONE.index(s)))]

    # 5. flowers and petals in a few mossy spots on the stones
    spots = []
    for y in range(90, 410, 2):
        for x in range(110, 690, 2):
            if g[y][x] not in GREEN:
                continue
            if abs(ell(x, y, RING_C, RING_R) - 1.0) < 0.12 or math.hypot(x - MEDAL_C[0], y - MEDAL_C[1]) < MEDAL_R + 6:
                continue
            st = sum(1 for dy in range(-3, 4) for dx in range(-3, 4) if 0 <= y + dy < H and 0 <= x + dx < W and stone_m.getpixel((x + dx, y + dy)))
            if 18 <= st <= 34:
                spots.append((x, y))
    rng.shuffle(spots)
    chosen: list[tuple[int, int]] = []
    for p in spots:
        if all(math.hypot(p[0] - q[0], p[1] - q[1]) > 38 for q in chosen):
            chosen.append(p)
        if len(chosen) >= 16:
            break
    for cx, cy in chosen:
        for _ in range(rng.randint(3, 6)):
            x = cx + rng.randint(-5, 5)
            y = cy + rng.randint(-3, 3)
            petal, centre = FLOWERS[rng.randrange(len(FLOWERS))]
            if not (2 <= x < W - 2 and 2 <= y < H - 2):
                continue
            if rng.random() < 0.55:
                # a tiny plus-shaped flower on a leaf
                g[y + 1][x + 1] = "4"
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    g[y + dy][x + dx] = petal
                g[y][x] = centre
            else:
                # a loose petal or two
                g[y][x] = petal
                if rng.random() < 0.5:
                    g[y][x + 1] = petal

    for row in g:
        for s in row:
            assert s not in RESERVED, s
    out = Image.new("RGB", (W, H))
    out.putdata([palette.by_symbol[g[y][x]] for y in range(H) for x in range(W)])
    return out


def main() -> int:
    img = restore()
    img.save(OUT, optimize=False)
    print(f"wrote {OUT.relative_to(ROOT)} ({W}x{H})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
