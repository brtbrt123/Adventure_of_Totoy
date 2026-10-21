"""Beacon epilogue effect art (Chapter 1, S6): the forest beacon lit over the restored arena.

Draws, procedurally and palette-bound (Totoy 36, hard alpha, no reserved gold x,y or red z,A):
- fx_beacon_<1..8>         48x240, anchor (24,232): the beacon loop. A pillar of cream / pale-teal light rising from
                           the platform past the top of the screen: shimmering core, rising motes, pulsing base halo;
- fx_beacon_ignite_<1..8>  48x240, anchor (24,232): spark -> line shoots up -> column widens -> overshoot -> settle;
- fx_beacon_pool_<1..6>    160x80, anchor (80,40): floor glow ellipse around the base (rx 70, ry 31), pulse loop;
- fx_beacon_ripple_<1..6>  208x96, anchor (104,48): the ring that spreads over the floor when the beacon lights;
- fx_firefly_<a|b|c>_<1..4> 8x8, anchor (4,4): small glowing motes (warm, pale, teal) blinking;
- fx_petal_<a|b|c>_<1..8>  8x8, anchor (4,4): drifting petals / leaves tumbling (pale cream, leaf green, mint).

Writes art/reference/beacon_epilogue/ (beacon_epilogue_v1.png + .json sheet, preview_contact.png, ignite_strip.png)
and the review renders docs/previews/arena_restored_v1.png, docs/previews/arena_before_after.png and
docs/previews/beacon_ignite.gif (the restored ground comes from make_arena_restored_ground.py; run that first).
Deterministic (fixed seeds). Run from the project root:  python tools/art/make_beacon_epilogue_art.py
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
OUT_DIR = ROOT / "art" / "reference" / "beacon_epilogue"
PREVIEWS = ROOT / "docs" / "previews"
GROUND = ROOT / "presentation" / "arena" / "arena_ground.png"
RESTORED = ROOT / "presentation" / "arena" / "arena_ground_restored.png"
SEED = 20261021
BASE_WORLD = (400, 240)  # the platform centre: where the beacon stands

palette = artlib.load_palette()
RESERVED = set(palette.reserved)
Grid = list[list[str]]

BAYER8 = [
    [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26], [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22], [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21],
]


def bayer(x: int, y: int) -> float:
    return (BAYER8[y & 7][x & 7] + 0.5) / 64.0


def new(w: int, h: int) -> Grid:
    return [["."] * w for _ in range(h)]


def put(g: Grid, x: int, y: int, s: str) -> None:
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        g[y][x] = s


def to_image(g: Grid) -> Image.Image:
    h, w = len(g), len(g[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img.putdata([(*palette.by_symbol[s], 255) if s != "." else (0, 0, 0, 0) for row in g for s in row])
    return img


def smooth(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------------------------
# the beacon

BW, BH = 64, 240
BAX, BAY = 32, 232       # anchor: the base of the pillar on the platform
CX = 31.5                # the pillar's centre line (between columns 31 and 32)
WIDTH = 1.3              # overall width factor of the pillar
MOTE_PERIOD = 120        # motes repeat every 120 px of height: 15 px per frame over the 8-frame loop


def light_sym(d: float, core: float, inner: float, mid: float, outer: float, glow: float, x: int, y: int,
              density: float = 1.0) -> str | None:
    """The light at distance d from the centre line: cream core, pale cyan, light blue, teal, sparse dark teal."""
    if d < core:
        return "1"
    if d < inner:
        return "p"
    b = bayer(x, y)
    if d < mid:
        # pale cyan and cream-white mixed: the light reads warm-teal, not blue
        return ("o" if b < 0.45 else "p") if b < 0.95 * density else "1"
    if d < outer:
        k = 1.0 - (d - mid) / max(0.01, outer - mid)
        return "u" if b < (0.25 + 0.6 * k) * density else None
    if d < glow:
        k = 1.0 - (d - outer) / max(0.01, glow - outer)
        return "t" if b < 0.3 * k * density else None
    return None


def draw_column(g: Grid, t: float, top: int, scale: float, bright: float = 0.0, flare: float = 1.0) -> None:
    """The pillar from the base (BAY) up to row `top`. t = loop phase in 0..1, scale = width factor."""
    for y in range(max(0, top), BAY + 1):
        h = BAY - y
        scale_w = scale * WIDTH
        sh = 0.55 * math.sin(h / 9.0 - t * 2 * math.pi) + 0.35 * math.sin(h / 4.3 + t * 4 * math.pi)
        fl = flare * 5.0 * math.exp(-h / 9.0)          # the flare where the light meets the stone
        # the top 70 rows thin out and the dither fades, so a cut-off pillar still looks endless
        fade = smooth((y - max(0, top)) / 70.0) if top <= 0 else smooth((y - top) / 14.0)
        dens = 0.35 + 0.65 * fade
        core = (1.2 + 0.35 * sh + bright) * scale_w * (0.6 + 0.4 * fade) + fl * 0.35
        inner = core + (1.6 + 0.4 * sh) * scale_w + fl * 0.5
        mid = inner + (1.8 + 0.6 * sh) * scale_w + fl * 0.6
        outer = mid + (3.2 + 0.8 * sh) * scale_w + fl * 0.8
        glow = outer + 4.0 * scale_w + fl
        if fade < 0.35:
            core = 0.0
        for x in range(BW):
            d = abs(x + 0.5 - CX - 0.5)
            s = light_sym(d, core, inner, mid, outer, glow, x, y, dens)
            if s:
                g[y][x] = s
        # a slow shimmer band that brightens the core as it climbs
        band = (h / 46.0 - t) % 1.0
        if band < 0.06 and fade > 0.5:
            for x in range(BW):
                if g[y][x] == "p":
                    g[y][x] = "1"
                elif g[y][x] == "o":
                    g[y][x] = "p"


def draw_halo(g: Grid, rx: float, ry: float, front: bool, cols: str = "po", dashed: float = 0.0) -> None:
    """An ellipse ring around the base (front = the lower half, drawn over the pillar)."""
    n = int(2 * math.pi * rx * 1.3) + 8
    for i in range(n):
        a = 2 * math.pi * i / n
        x = BAX - 0.5 + rx * math.cos(a)
        y = BAY + ry * math.sin(a)
        if (math.sin(a) >= 0) != front:
            continue
        if dashed and (i * 7 % 10) / 10.0 < dashed:
            continue
        sym = cols[0] if math.sin(a) > 0.2 else cols[-1]
        put(g, int(round(x)), int(round(y)), sym)


def draw_motes(g: Grid, t: float, count: int, rng_seed: int, spread: float = 11.0, top_h: int = 232) -> None:
    rng = random.Random(rng_seed)
    for i in range(count):
        ox = rng.uniform(-spread, spread)
        h0 = rng.uniform(0, MOTE_PERIOD)
        streak = rng.random() < 0.35
        for copy in (0, 1):
            h = (h0 + t * MOTE_PERIOD + copy * MOTE_PERIOD) % (2 * MOTE_PERIOD)
            if h > top_h:
                continue
            # the motes drift a little sideways as they climb
            x = int(round(BAX - 0.5 + ox + 1.5 * math.sin(h / 17.0 + i)))
            y = int(round(BAY - 2 - h))
            sym = "1" if abs(ox) < 5 else ("p" if i % 2 else "s")
            put(g, x, y, sym)
            if streak:
                put(g, x, y + 1, "o" if abs(ox) >= 5 else "p")


def base_glow(g: Grid, rx: float, ry: float, cols: str = "1p") -> None:
    for y in range(BH):
        for x in range(BW):
            q = ((x + 0.5 - BAX) / rx) ** 2 + ((y + 0.5 - BAY) / ry) ** 2
            if q < 0.45:
                g[y][x] = cols[0]
            elif q < 1.0 and bayer(x, y) < 0.8 * (1 - q) / 0.55:
                g[y][x] = cols[1]


def star(g: Grid, cx: int, cy: int, arm: int, core: str = "1", ray: str = "p", tip: str = "o") -> None:
    put(g, cx, cy, core)
    for k in range(1, arm + 1):
        s = ray if k < arm else tip
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            put(g, cx + dx, cy + dy, s)
    if arm >= 3:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            put(g, cx + dx, cy + dy, ray)


def beacon_loop(k: int) -> Grid:
    t = k / 8.0
    g = new(BW, BH)
    pulse = 0.5 + 0.5 * math.cos(2 * math.pi * t)
    hrx = 13.0 + 4.0 * pulse
    draw_halo(g, hrx, hrx * 0.38, front=False, cols="ou")
    draw_halo(g, hrx + 5, (hrx + 5) * 0.38, front=False, cols="ut", dashed=0.5)
    draw_column(g, t, 0, 1.0)
    base_glow(g, 7 + 1.5 * pulse, 2.6 + 0.6 * pulse)
    draw_halo(g, hrx, hrx * 0.38, front=True, cols="po")
    draw_halo(g, hrx + 5, (hrx + 5) * 0.38, front=True, cols="ou", dashed=0.5)
    draw_motes(g, t, 16, SEED + 1)
    return g


def beacon_ignite(k: int) -> Grid:
    g = new(BW, BH)
    if k == 1:   # a spark on the medallion (teal-edged so it reads on the pale stone)
        for dx, dy in ((-2, -1), (2, -1), (-2, 1), (2, 1), (-1, -2), (1, -2), (-1, 2), (1, 2)):
            put(g, BAX + dx, BAY - 3 + dy, "t")
        star(g, BAX, BAY - 3, 3)
        put(g, BAX - 4, BAY - 7, "p")
        put(g, BAX + 4, BAY - 8, "o")
    elif k == 2:  # the spark flares, a small ring opens on the stone
        base_glow(g, 6, 2.4, "po")
        draw_halo(g, 12, 4.5, front=False, cols="u")
        for dx, dy in ((-2, -1), (2, -1), (-2, 1), (2, 1), (-1, -2), (1, -2), (-1, 2), (1, 2)):
            put(g, BAX + dx, BAY - 4 + dy, "u")
        star(g, BAX, BAY - 4, 5)
        draw_halo(g, 12, 4.5, front=True, cols="p")
        for dx, dy in ((-7, -8), (6, -10), (-2, -14), (3, -17)):
            put(g, BAX + dx, BAY + dy, "p")
    elif k in (3, 4):  # a thin line shoots up (to a third, then past the top)
        top = BAY - 80 if k == 3 else 0
        for y in range(top, BAY):
            put(g, BAX, y, "1")
            put(g, BAX - 1, y, "p" if k == 4 or (y % 2) else ".")
            if k == 4 and bayer(BAX + 1, y) < 0.5:
                put(g, BAX + 1, y, "o")
        if k == 3:
            star(g, BAX, top, 3)
            draw_motes(g, 0.0, 6, SEED + 2, spread=3, top_h=80)
        base_glow(g, 6, 2.4)
        star(g, BAX, BAY - 2, 3)
        draw_halo(g, 10, 4, front=False, cols="o")
        draw_halo(g, 10, 4, front=True, cols="p")
    elif k == 5:  # the column opens: the strike, a big flash on the platform
        draw_column(g, 0.6, 0, 0.55, bright=0.4, flare=1.8)
        base_glow(g, 15, 5.5)
        draw_halo(g, 19, 7, front=False, cols="o")
        draw_halo(g, 19, 7, front=True, cols="p")
    elif k == 6:  # overshoot: wider and brighter than the loop
        draw_halo(g, 21, 8, front=False, cols="u")
        draw_column(g, 0.75, 0, 1.35, bright=1.0, flare=1.5)
        base_glow(g, 11, 4)
        draw_halo(g, 21, 8, front=True, cols="o")
        draw_motes(g, 0.75, 22, SEED + 3, spread=14)
    elif k == 7:  # settle
        draw_halo(g, 18, 7, front=False, cols="ou")
        draw_column(g, 0.875, 0, 1.12, bright=0.4, flare=1.2)
        base_glow(g, 9, 3.4)
        draw_halo(g, 18, 7, front=True, cols="po")
        draw_motes(g, 0.875, 18, SEED + 1)
    else:        # 8: the loop's first frame with one more ring: hand over to fx_beacon_1
        g = beacon_loop(0)
        draw_halo(g, 22, 8, front=True, cols="u", dashed=0.4)
    return g


# ---------------------------------------------------------------------------------------------------------------
# the floor pool, the ripple, fireflies, petals

PW, PH, PAX, PAY = 160, 80, 80, 40
POOL_RX, POOL_SQUASH = 70.0, 0.45


def pool_frame(k: int) -> Grid:
    t = (k - 1) / 6.0
    pulse = 0.5 + 0.5 * math.cos(2 * math.pi * t)        # 1 at frame 1, 0 at frame 4
    rx = POOL_RX * (0.95 + 0.05 * pulse)
    ry = rx * POOL_SQUASH
    g = new(PW, PH)
    for y in range(PH):
        for x in range(PW):
            r = math.hypot((x + 0.5 - PAX) / rx, (y + 0.5 - PAY) / ry)
            if r >= 1.0:
                continue
            # bands of ordered dither at fixed levels (75/50/25/12 %), so the glow reads as soft rings of light and
            # not as noise; the band edges breathe with the pulse
            r2 = r / (0.96 + 0.06 * pulse)
            b = bayer(x, y)
            if r2 < 0.2:
                s, dens = ("1" if b < 0.3 else "p"), 0.75
            elif r2 < 0.42:
                s, dens = ("p" if b < 0.2 else "o"), 0.5
            elif r2 < 0.66:
                s, dens = ("o" if b < 0.08 else "u"), 0.25 + 0.25 * (pulse > 0.5) * (r2 < 0.5)
            elif r2 < 0.88:
                s, dens = "u", 0.125
            else:
                s, dens = "t", 0.125 * (0.5 + 0.5 * pulse)
            if b < dens:
                g[y][x] = s
    # a faint rim where the light ends (every third pixel, so it reads as a soft edge, not a line)
    n = int(2 * math.pi * rx * 1.2)
    for i in range(n):
        if i % 3:
            continue
        a = 2 * math.pi * (i + k * 2) / n
        put(g, int(round(PAX - 0.5 + rx * math.cos(a))), int(round(PAY - 0.5 + ry * math.sin(a))), "u" if math.sin(a) > 0 else "t")
    return g


RW, RH, RAX, RAY = 208, 96, 104, 48
RIPPLE_RX = [12, 28, 46, 64, 82, 98]


def ripple_frame(k: int) -> Grid:
    rx = RIPPLE_RX[k - 1]
    ry = rx * POOL_SQUASH
    g = new(RW, RH)
    life = (k - 1) / 5.0
    # leading edge, then two trailing bands that fade
    bands = [(0.0, "p" if k < 4 else "o", 1.0 - 0.75 * life), (1.6, "o" if k < 4 else "u", 0.85 - 0.6 * life),
             (3.4, "u" if k < 5 else "t", 0.55 - 0.4 * life), (5.4, "t", 0.3 - 0.2 * life)]
    n = int(2 * math.pi * rx * 1.6) + 16
    for off, sym, dens in bands:
        if dens <= 0:
            continue
        r_x = rx - off
        if r_x <= 1:
            continue
        r_y = r_x * POOL_SQUASH
        for i in range(n):
            a = 2 * math.pi * i / n
            x = int(round(RAX - 0.5 + r_x * math.cos(a)))
            y = int(round(RAY - 0.5 + r_y * math.sin(a)))
            if 0 <= x < RW and 0 <= y < RH and g[y][x] == "." and bayer(x, y) < dens:
                g[y][x] = sym
    # motes kicked up by the passing ring
    rng = random.Random(SEED + 10 + k)
    for _ in range(4 + k):
        a = rng.uniform(0, 2 * math.pi)
        x = int(round(RAX - 0.5 + (rx - 2) * math.cos(a)))
        y = int(round(RAY - 0.5 + (ry - 1) * math.sin(a) - rng.randint(2, 4 + k)))
        put(g, x, y, "p" if k < 4 else "o")
    return g


FIREFLY = {"a": ("1", "7", "6"), "b": ("1", "s", "j"), "c": ("p", "o", "u")}   # core, glow, dim
FIREFLY_LOOK = {"a": "warm yellow-green", "b": "pale cream", "c": "pale teal"}


def firefly_frame(v: str, k: int) -> Grid:
    core, glow, dim = FIREFLY[v]
    g = new(8, 8)
    c = 4
    if k == 1:          # nearly out: one dim pixel
        put(g, c, c, dim)
    elif k in (2, 4):   # half: core and a dim plus
        put(g, c, c, glow if k == 2 else core)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(g, c + dx, c + dy, dim)
    else:               # 3, full: the 3x3 mote
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                put(g, c + dx, c + dy, dim if (dx and dy) else glow)
        put(g, c, c, core)
    return g


PETAL = {"a": ("1", "s"), "b": ("7", "5"), "c": ("p", "o")}   # body, shade
PETAL_LOOK = {"a": "pale cream blossom petal", "b": "small leaf", "c": "mint-pale petal"}


def petal_frame(v: str, k: int) -> Grid:
    body, shade = PETAL[v]
    g = new(8, 8)
    ang = (k - 1) * math.pi / 4.0 * 0.75          # turns 135 degrees over the loop and back via the tumble
    tumble = abs(math.cos((k - 1) * math.pi / 4.0))  # 1 flat, 0 edge-on
    half_l = 2.6
    half_w = 0.85 + 0.75 * tumble
    ca, sa = math.cos(ang), math.sin(ang)
    for y in range(8):
        for x in range(8):
            dx, dy = x + 0.5 - 4.0, y + 0.5 - 4.0
            u = dx * ca + dy * sa
            w = -dx * sa + dy * ca
            if (u / half_l) ** 2 + (w / half_w) ** 2 <= 1.0:
                g[y][x] = shade if (w > 0.25 and tumble > 0.4) or (u > 1.2 and tumble <= 0.4) else body
    return g


# ---------------------------------------------------------------------------------------------------------------
# sheet, JSON, checks

def all_sprites() -> list[tuple[str, str, Grid, tuple[int, int], int]]:
    """(group, name, grid, anchor, ms)"""
    out = []
    for k in range(1, 9):
        out.append(("fx_beacon", f"fx_beacon_{k}", beacon_loop(k - 1), (BAX, BAY), 100))
    for k in range(1, 9):
        ms = [70, 70, 60, 60, 90, 100, 110, 100][k - 1]
        out.append(("fx_beacon_ignite", f"fx_beacon_ignite_{k}", beacon_ignite(k), (BAX, BAY), ms))
    for k in range(1, 7):
        out.append(("fx_beacon_pool", f"fx_beacon_pool_{k}", pool_frame(k), (PAX, PAY), 140))
    for k in range(1, 7):
        out.append(("fx_beacon_ripple", f"fx_beacon_ripple_{k}", ripple_frame(k), (RAX, RAY), 80))
    for v in "abc":
        for k in range(1, 5):
            out.append((f"fx_firefly_{v}", f"fx_firefly_{v}_{k}", firefly_frame(v, k), (4, 4), [260, 120, 220, 120][k - 1]))
    for v in "abc":
        for k in range(1, 9):
            out.append((f"fx_petal_{v}", f"fx_petal_{v}_{k}", petal_frame(v, k), (4, 4), 110))
    for _, name, g, _, _ in out:
        h, w = len(g), len(g[0])
        assert w % 8 == 0 and h % 8 == 0, (name, w, h)
        for row in g:
            for s in row:
                assert s == "." or (s in palette.by_symbol and s not in RESERVED), (name, s)
    return out


def pack(sprites, width: int = 1024) -> tuple[Image.Image, list[dict]]:
    rows: list[list] = []
    cur_group_prefix = None
    for sp in sprites:
        key = sp[0].rsplit("_", 1)[0] if sp[0].startswith(("fx_firefly", "fx_petal")) else sp[0]
        if key != cur_group_prefix:
            rows.append([])
            cur_group_prefix = key
        rows[-1].append(sp)
    placed = []
    x = y = 0
    row_h = 0
    for row in rows:
        x = 0
        y += row_h + (2 if row_h else 0)
        row_h = 0
        for group, name, g, anchor, ms in row:
            w, h = len(g[0]), len(g)
            if x + w > width:
                x = 0
                y += row_h + 2
                row_h = 0
            placed.append({"name": name, "group": group, "rect": [x, y, w, h], "anchor": list(anchor), "ms": ms, "grid": g})
            x += w + 2
            row_h = max(row_h, h)
    total_h = y + row_h
    total_h += (-total_h) % 8
    sheet = Image.new("RGBA", (width, total_h), (0, 0, 0, 0))
    for p in placed:
        sheet.paste(to_image(p["grid"]), (p["rect"][0], p["rect"][1]))
    return sheet, placed


def check_hard(path: Path) -> None:
    allowed = {(*rgb, 255) for s, rgb in palette.by_symbol.items() if s not in RESERVED}
    img = Image.open(path).convert("RGBA")
    for _, px in img.getcolors(1 << 24):
        if px[3] == 0:
            continue
        assert px in allowed, f"{path.name}: {px} is not an opaque palette colour (or is reserved)"


def check_opaque_palette(path: Path) -> None:
    allowed = {rgb for s, rgb in palette.by_symbol.items() if s not in RESERVED}
    img = Image.open(path)
    if img.mode == "RGBA":
        assert img.getchannel("A").getextrema() == (255, 255), f"{path.name}: not opaque"
    for _, px in img.convert("RGB").getcolors(1 << 24):
        assert px in allowed, f"{path.name}: {px} is not a palette colour (or is reserved)"


GROUP_DOC = {
    "fx_beacon": "the beacon loop: pillar of cream/pale-teal light from the platform past the top of the screen; shimmering core, a brightening band climbs the core once per loop, 16 motes rise (15 px per frame), the base halo pulses (rx 13..17). Loop 1..8 at ~100 ms. Draw over characters standing behind it, under characters in front of the base (sort by the anchor y = 240) or simply above everything in the cutscene.",
    "fx_beacon_ignite": "the start: 1 spark on the medallion, 2 it flares and a small ring opens, 3 a thin line shoots up a third of the way, 4 the line passes the top of the screen, 5 the column opens with a big flash on the platform (start fx_beacon_ripple and fx_beacon_pool here), 6 overshoot (wider and brighter), 7 settle, 8 = fx_beacon_1 plus one fading ring; then loop fx_beacon. Plays once.",
    "fx_beacon_pool": "floor glow around the base: dithered ellipse rx 70 ry 31 (the same 0.45 floor squash as the other floor effects), cream at the centre to pale teal at the rim. Draw on the ground layer, under characters and under fx_beacon. Pulse loop 1..6 at ~140 ms (frame 1 brightest and widest, frame 4 dimmest).",
    "fx_beacon_ripple": "a ring that spreads over the floor when the beacon lights: rx 12/28/46/64/82/98 px (ry = 0.45 rx), leading edge bright, trailing bands thin and fade, motes kicked up. Plays once from ignite 5, ~80 ms per frame, on the ground layer.",
    "fx_firefly": "fireflies, variants a warm yellow-green, b pale cream, c pale teal: 1 nearly out, 2 half, 3 full 3x3 mote, 4 half. Loop with a random start frame per firefly (260/120/220/120 ms); move each one slowly along a wandering path (about 6-12 px/s, sine wobble). Scatter 10-20 over the plaza and the forest edge.",
    "fx_petal": "drifting petals/leaves, variants a pale cream blossom, b small leaf, c mint-pale petal: 8 tumble frames (flat, turning, edge-on). Loop at ~110 ms while the petal drifts down and sideways (about 10-18 px/s down, sine sway of 6-10 px). Spawn above the top of the screen or from the forest edges.",
}


def write_sheet(sprites) -> list[dict]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet, placed = pack(sprites)
    png = OUT_DIR / "beacon_epilogue_v1.png"
    sheet.save(png)
    check_hard(png)
    table: dict[str, dict] = {}
    for p in placed:
        t = table.setdefault(p["group"], {"frames": 0, "size": p["rect"][2:], "anchor": p["anchor"], "ms": []})
        t["frames"] += 1
        t["ms"].append(p["ms"])
    extra = {
        "fx_beacon_pool": {"rx_px": POOL_RX, "ry_px": POOL_RX * POOL_SQUASH},
        "fx_beacon_ripple": {"rx_px": RIPPLE_RX, "ry_factor": POOL_SQUASH},
    }
    data = {
        "generator": "tools/art/make_beacon_epilogue_art.py (procedural, Pillow only, deterministic seeds)",
        "palette": "Totoy 36, hard alpha; no reserved gold x,y or red z,A",
        "scale": "1x game pixels (nearest-neighbour)",
        "status": "Reference art for the human's approval; NOT imported into art/src, not in art/build, not wired into the game",
        "frame_naming": "<group>_<n>, n from 1; fireflies and petals are fx_firefly_<variant>_<n>, fx_petal_<variant>_<n>",
        "world_placement": {"beacon_base": list(BASE_WORLD), "note": "fx_beacon, fx_beacon_ignite, fx_beacon_pool and fx_beacon_ripple are all placed with their anchor on the platform centre, world (400,240), over presentation/arena/arena_ground_restored.png"},
        "groups": GROUP_DOC,
        "group_table": {g: {**v, **extra.get(g, {})} for g, v in table.items()},
        "suggested_timeline": [
            "0 ms: the restored ground, fireflies blinking, a few petals drifting",
            "ignite 1..8 (70,70,60,60,90,100,110,100 ms = 660 ms) at (400,240)",
            "at ignite 5: ripple 1..6 (80 ms each) and the pool from frame 4 (dim) fading into its loop",
            "after ignite 8: fx_beacon loop at ~100 ms, the pool loop at ~140 ms, fireflies and petals keep going",
        ],
        "frames": [{k: v for k, v in p.items() if k != "grid"} for p in placed],
    }
    (OUT_DIR / "beacon_epilogue_v1.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    return placed


# ---------------------------------------------------------------------------------------------------------------
# review renders

def blit(dst: Image.Image, g: Grid, anchor: tuple[int, int], at: tuple[int, int]) -> None:
    img = to_image(g)
    dst.alpha_composite(img, (at[0] - anchor[0], at[1] - anchor[1]))


def scene_actors(rng_seed: int):
    rng = random.Random(rng_seed)
    flies = []
    while len(flies) < 22:
        x, y = rng.uniform(90, 710), rng.uniform(70, 430)
        if math.hypot((x - 400) / 1.6, y - 240) < 60:
            continue
        flies.append([x, y, rng.choice("aabbc"), rng.randrange(4), rng.uniform(0, 6.28)])
    petals = []
    for _ in range(16):
        petals.append([rng.uniform(250, 560), rng.uniform(40, 360), rng.choice("aaacb"), rng.randrange(8), rng.uniform(0, 6.28)])
    return flies, petals


def compose(ground: Image.Image, beacon: Grid | None, pool: Grid | None, ripple: Grid | None, flies, petals,
            t_ms: float = 0.0) -> Image.Image:
    img = ground.convert("RGBA")
    if pool is not None:
        blit(img, pool, (PAX, PAY), BASE_WORLD)
    if ripple is not None:
        blit(img, ripple, (RAX, RAY), BASE_WORLD)
    if beacon is not None:
        blit(img, beacon, (BAX, BAY), BASE_WORLD)
    for x, y, v, f0, ph in flies:
        k = (f0 + int(t_ms / 180)) % 4 + 1
        fx = x + 6 * math.sin(ph + t_ms / 900.0)
        fy = y + 3 * math.sin(ph * 1.7 + t_ms / 700.0)
        blit(img, firefly_frame(v, k), (4, 4), (int(round(fx)), int(round(fy))))
    for x, y, v, f0, ph in petals:
        k = (f0 + int(t_ms / 110)) % 8 + 1
        px = x + 7 * math.sin(ph + t_ms / 600.0) + t_ms * 0.006
        py = y + t_ms * 0.014
        blit(img, petal_frame(v, k), (4, 4), (int(round(px)), int(round(py))))
    return img.convert("RGB")


def label_sheet(placed: list[dict], bg: Image.Image, path: Path, scale: int = 3) -> None:
    """Every frame at `scale`x on a crop of the restored ground (and on dark ink for the small ones)."""
    groups: dict[str, list[dict]] = {}
    for p in placed:
        groups.setdefault(p["group"], []).append(p)
    rows = []
    for gname, frames in groups.items():
        sc = 10 if frames[0]["rect"][2] <= 8 else scale   # the small motes and petals at 10x
        w = (sum(f["rect"][2] for f in frames) + 4 * len(frames)) * sc
        h = max(f["rect"][3] for f in frames) * sc
        rows.append((gname, frames, w, h, sc))
    pad = 14
    total_w = max(r[2] for r in rows) + 16
    total_h = sum(r[3] + pad + 6 for r in rows) + 8
    out = Image.new("RGB", (total_w, total_h), (28, 24, 36))
    d = ImageDraw.Draw(out)
    y = 4
    for gname, frames, w, h, sc in rows:
        d.text((8, y), f"{gname}  ({len(frames)} frames, {frames[0]['rect'][2]}x{frames[0]['rect'][3]}, anchor {frames[0]['anchor'][0]},{frames[0]['anchor'][1]})", fill=(244, 236, 214))
        y += pad
        x = 8
        for f in frames:
            fw, fh = f["rect"][2], f["rect"][3]
            # background: the restored ground around the platform (sprites placed by their anchor at the base)
            ax, ay = f["anchor"]
            at = BASE_WORLD if fw > 8 else (190, 432)   # the small motes over the forest-edge grass
            tile = bg.crop((at[0] - ax, at[1] - ay, at[0] - ax + fw, at[1] - ay + fh)).convert("RGBA")
            tile.alpha_composite(to_image(f["grid"]))
            out.paste(tile.convert("RGB").resize((fw * sc, fh * sc), Image.NEAREST), (x, y))
            x += (fw + 4) * sc
        y += h + 6
    out.save(path)


def make_reviews(placed: list[dict]) -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    before = Image.open(GROUND).convert("RGB")
    after = Image.open(RESTORED).convert("RGB")
    check_opaque_palette(RESTORED)
    flies, petals = scene_actors(SEED + 20)

    # 1. the restored arena with the beacon lit, at 2x
    still = compose(after, beacon_loop(2), pool_frame(1), ripple_frame(6), flies, petals, t_ms=500)
    still.resize((1600, 960), Image.NEAREST).save(PREVIEWS / "arena_restored_v1.png")

    # 2. before / after, side by side (1x each, labelled)
    ba = Image.new("RGB", (800 * 2 + 12, 480 + 20), (28, 24, 36))
    ba.paste(before, (0, 20))
    ba.paste(after, (812, 20))
    d = ImageDraw.Draw(ba)
    d.text((6, 4), "current arena_ground.png", fill=(244, 236, 214))
    d.text((818, 4), "restored arena_ground_restored.png (no effects)", fill=(244, 236, 214))
    ba.save(PREVIEWS / "arena_before_after.png")

    # 3. the ignite GIF, at 2x, in a 320x180 camera view centred above the platform
    view = (240, 100, 560, 280)
    frames: list[tuple[Image.Image, int]] = []
    t = 0
    step = 60

    def shot(beacon, pool, ripple, ms):
        nonlocal t
        img = compose(after, beacon, pool, ripple, flies, petals, t_ms=t).crop(view).resize((640, 360), Image.NEAREST)
        frames.append((img, ms))
        t += ms

    for _ in range(6):                       # 360 ms of the calm, restored arena
        shot(None, None, None, step)
    ign_ms = [70, 70, 60, 60, 90, 100, 110, 100]
    ripple_k = 0
    pool_seq = [4, 4, 3, 2]
    for k in range(1, 9):
        rip = ripple_frame(ripple_k + 1) if k >= 5 and ripple_k < 6 else None
        pool = pool_frame(pool_seq[k - 5]) if k >= 5 else None
        if k >= 5:
            ripple_k += 1
        shot(beacon_ignite(k), pool, rip, ign_ms[k - 1])
    lk = 0
    pk = 1
    while t < 3000:
        rip = ripple_frame(ripple_k + 1) if ripple_k < 6 else None
        ripple_k += 1
        shot(beacon_loop(lk % 8), pool_frame(pk % 6 + 1), rip, 100)
        lk += 1
        if lk % 2 == 0:
            pk += 1
    frames[0][0].save(PREVIEWS / "beacon_ignite.gif", save_all=True, append_images=[f for f, _ in frames[1:]],
                      duration=[ms for _, ms in frames], loop=0, disposal=1, optimize=False)

    # an ignite strip (every ignite frame + loop 1, 2x, camera view) and the labelled contact sheet
    strip = Image.new("RGB", (9 * 242 - 2, 360), (28, 24, 36))
    for i in range(9):
        b = beacon_ignite(i + 1) if i < 8 else beacon_loop(0)
        pool = pool_frame([4, 4, 3, 2][i - 4]) if 4 <= i < 8 else (pool_frame(1) if i == 8 else None)
        rip = ripple_frame(i - 3) if 4 <= i < 8 else None
        img = compose(after, b, pool, rip, [], [], 0).crop((340, 100, 460, 280)).resize((240, 360), Image.NEAREST)
        strip.paste(img, (i * 242, 0))
    strip.save(OUT_DIR / "ignite_strip.png")
    label_sheet(placed, after, OUT_DIR / "preview_contact.png", scale=2)


def main() -> int:
    sprites = all_sprites()
    placed = write_sheet(sprites)
    make_reviews(placed)
    for p in sorted(OUT_DIR.glob("*.png")) + [PREVIEWS / "arena_restored_v1.png", PREVIEWS / "arena_before_after.png"]:
        if p.name.startswith("beacon_epilogue"):
            continue
        Image.open(p).verify()
    print(f"{len(sprites)} sprites -> {OUT_DIR.relative_to(ROOT)}; previews in {PREVIEWS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
