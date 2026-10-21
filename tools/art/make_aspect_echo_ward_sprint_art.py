"""Generate the review art for three new Aspects: ECHO STEP, STONE WARD and SPRINT
(art/reference/aspects_echo_ward_sprint/).

REVIEW ONLY: nothing here is imported into art/src or art/build, and nothing is wired into the game.

Everything is drawn procedurally, pixel by pixel, in the Totoy 36 palette with hard alpha only. Gold (x, y) and
red (z, A) are reserved for combat cues and never used. Translucency is faked with checkerboard / ordered dither.
Helpers (grids, trim, pack, checks, the arena floor) come from make_aspect_lantern_phantom_art.py and
make_dual_dagger_art.py, so the style and the file format match the Spirit Lantern / Phantom Cut delivery.

Colour language
  Echo Step: the echo is a ghost of Totoy: lilac v outline, teal u / water o checkerboard body (fake translucency),
    a bright scanline that crawls down it, standing on a teal rune ring (t dashes, o/p rune ticks, v inner dots).
    Recall: a cream/water-white streak (1 p o) with a lilac fringe; the arrival shield is a water-white glint.
  Stone Ward: a stone slab (stone ramp f g h i j, ink outline) with a carved rune that lights teal (t u o p);
    the barrier is a dithered stone-grey crescent in front of Totoy with teal rune glints. Stored energy is a teal
    halo that grows in 3 levels. The shockwave is a pale ring (1 p o u t) with stone shards and dust; the cracks
    glow teal, then cool to ink.
  Sprint: bright pale cyan / white (1 p o, n for the faint tails): outline aura, speed lines, wind streaks,
    cyan afterimages; dust in the pale stone colours (j i).

Outputs (atlases at 1x game pixels; preview files are scaled copies for viewing):
  echo_step_v1.png/.json, stone_ward_v1.png/.json, sprint_v1.png/.json, aspect_icons_v1.png/.json
  preview_contact_dark.png, preview_contact_grass.png (4x, labelled)
  echo_step_sequence.gif, stone_ward_sequence.gif, sprint_sequence.gif (+ _strip.png at 2x)
Run from the project root (deterministic, fixed seeds; two runs give byte-identical files):
  python tools/art/make_aspect_echo_ward_sprint_art.py
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import make_aspect_lantern_phantom_art as LP  # noqa: E402  (helpers only; main() is guarded)
import make_dual_dagger_art as M  # noqa: E402

ROOT = artlib.ROOT
OUT = ROOT / "art" / "reference" / "aspects_echo_ward_sprint"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)
GENERATOR = "tools/art/make_aspect_echo_ward_sprint_art.py (procedural, Pillow only, deterministic seeds)"

Grid = list
blank, put, get, copy, paste = M.blank, M.put, M.get, M.copy, M.paste
line_pts, outline_layer, mirror = M.line_pts, M.outline_layer, M.mirror
to_image, rnd, load_sprite, lum, star, ellipse_ring, puff = LP.to_image, LP.rnd, LP.load_sprite, LP.lum, LP.star, LP.ellipse_ring, LP.puff
trim, trim_group, pack, check_hard, write_json = LP.trim, LP.trim_group, LP.pack, LP.check_hard, LP.write_json
BAYER = LP.BAYER
BG_DARK, BG_GRASS = LP.BG_DARK, LP.BG_GRASS
SW_, SH_ = LP.SW_, LP.SH_  # GIF scene 192x120 game pixels, shown at 4x

HERO_SETS = {"katana": "hero2", "dagger": "totoy_dagger", "scythe": "totoy_scythe"}
MOVE_STATES = [("idle", 4), ("walk", 6), ("dash", 4)]  # the frames Sprint and the Echo Step shield cover


def dz(x: int, y: int, level: float) -> bool:
    """Ordered (Bayer 4x4) dither: True for about `level` (0..1) of the pixels."""
    return BAYER[y % 4][x % 4] < level * 16


def is_edge(src: Grid, x: int, y: int) -> bool:
    return any(get(src, x + dx, y + dy) == T for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def outside_ring(src: Grid) -> list[tuple[int, int]]:
    """Transparent pixels 4-touching the silhouette (the 1px outline just outside it)."""
    h, w = len(src), len(src[0])
    return [(x, y) for y in range(h) for x in range(w) if src[y][x] == T
            and any(get(src, x + dx, y + dy) != T for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]


def pad(g: Grid, anchor: tuple[int, int], left: int, top: int, right: int, bottom: int) -> tuple[Grid, tuple[int, int]]:
    w, h = len(g[0]), len(g)
    out = blank(w + left + right, h + top + bottom)
    paste(out, g, left, top)
    return out, (anchor[0] + left, anchor[1] + top)


def move_frames(vid: str) -> list[str]:
    return [f"{vid}_{st}_right_{n}" for st, cnt in MOVE_STATES for n in range(1, cnt + 1)]


# ================================================================================================ ECHO STEP
EC, EA = 48, (24, 42)  # echo cells: 48x48, anchor = the echo's (Totoy's) feet
RING_RX, RING_RY = 12.0, 4.5
ECHO_POSE = "hero2_idle_right_1"
GHOST_BOB = (0, 0, -1, -1, -1, 0)


def echo_ghost(src: Grid, phase: int = 0, density: float = 1.0, bright: bool = False) -> Grid:
    """The echo: a ghost of the hero frame. Lilac outline, teal/water checkerboard body (fake translucency), a bright
    scanline crawling down it and a dropout row under the scanline. density < 1 thins it with ordered dither."""
    h, w = len(src), len(src[0])
    g = blank(w, h)
    rows = [y for y in range(h) if any(c != T for c in src[y])]
    if not rows:
        return g
    top, bot = rows[0], rows[-1]
    span = bot - top + 6
    scan = top + (phase * 6) % span
    for y in range(h):
        for x in range(w):
            c = src[y][x]
            if c == T:
                continue
            edge = is_edge(src, x, y)
            if density < 1 and not dz(x + 1, y + 2, density + (0.25 if edge else 0)):
                continue
            if y == scan + 1 and edge and x % 2:
                continue  # dropout row
            on_scan = scan - 1 <= y <= scan
            if edge:
                g[y][x] = "p" if bright else ("o" if on_scan else "v")
                continue
            chk = (x + y) % 2 == 0
            L = lum(c)
            if bright:
                g[y][x] = "1" if chk else "p"
            elif on_scan:
                g[y][x] = "p" if chk else "o"
            elif chk:
                g[y][x] = "u" if L < 0.3 else ("o" if L < 0.62 else "p")
    return g


def rune_ring(g: Grid, cx: float, cy: float, rx: float, ry: float, phase: int, half: str, dash: str = "u",
              tick: str = "p", tip: str = "o", inner: str = "v", density: float = 1.0) -> None:
    """The echo's floor ring. half: 'back' (upper half, drawn before the ghost) or 'front' (after it).
    Dashed ring, 6 rune ticks that turn slowly with phase, dotted inner ring."""
    def keep_half(y: float) -> bool:
        return (y < cy) if half == "back" else (y >= cy)
    n = max(24, int(2 * math.pi * rx * 1.6))
    seen = set()
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rnd(cx + rx * math.cos(a)), rnd(cy + ry * math.sin(a))
        if (x, y) in seen or not keep_half(cy + ry * math.sin(a)):
            continue
        seen.add((x, y))
        if (len(seen) + phase) % 5 < 3 and dz(x, y, density):
            put(g, x, y, dash)
    for k in range(6):
        a = 2 * math.pi * k / 6 + phase * math.pi / 18
        y = cy + ry * math.sin(a)
        if not keep_half(y):
            continue
        x, yy = rnd(cx + rx * math.cos(a)), rnd(y)
        if dz(x, yy, density + 0.3):
            put(g, x, yy, tick)
            put(g, x, yy - 1, tip)
    for i in range(0, 40, 4):
        a = 2 * math.pi * i / 40 - phase * math.pi / 12
        y = cy + ry * 0.55 * math.sin(a)
        if keep_half(y) and dz(i, 0, density + 0.3):
            put(g, rnd(cx + rx * 0.55 * math.cos(a)), rnd(y), inner)


def echo_motes(g: Grid, phase: int, n: int = 3, cols: str = "pov") -> None:
    for i in range(n):
        age = (phase + 2 * i) % 6
        if age >= len(cols) + 1:
            continue
        x = EA[0] + (-7, 6, 1, -3)[i % 4] + (1 if (age + i) % 3 == 0 else 0)
        y = EA[1] - 8 - age * 3 - i * 4
        put(g, x, y, cols[min(age, len(cols) - 1)])


def echo_cell(phase: int, density: float = 1.0, bright: bool = False, rx: float = RING_RX, ry: float = RING_RY,
              ring: dict | None = None, bob: int | None = None, motes: bool = True) -> Grid:
    src, anc = load_sprite(ECHO_POSE)
    g = blank(EC, EC)
    ring = ring or {}
    rune_ring(g, EA[0], EA[1], rx, ry, phase, "back", **ring)
    gh = echo_ghost(src, phase, density, bright)
    dy = GHOST_BOB[phase % 6] if bob is None else bob
    paste(g, gh, EA[0] - anc[0], EA[1] - anc[1] + dy)
    rune_ring(g, EA[0], EA[1], rx, ry, phase, "front", **ring)
    if motes:
        echo_motes(g, phase)
    return g


def echo_anchor(k: int) -> Grid:
    """The echo marker, 6-frame loop (about 100 ms)."""
    return echo_cell(k)


def echo_countdown(k: int) -> Grid:
    """Last ~20 ticks before the recall: the ring tightens and flickers bright, the echo flickers thin, four ticks close in."""
    rx = (10.5, 9.0, 7.5, 6.0)[k]
    ry = rx * RING_RY / RING_RX
    bright = k % 2 == 0
    ring = {"dash": "o" if bright else "u", "tick": "p" if bright else "o", "tip": "1" if bright else "p", "inner": "o" if bright else "v"}
    g = echo_cell(k, density=(0.85, 0.55, 0.75, 0.4)[k], rx=rx, ry=ry, ring=ring, bob=0, motes=False)
    for sx in (-1, 1):  # converging ticks on the ring's sides
        x = rnd(EA[0] + sx * (rx + 4 - k))
        for i in range(2):
            put(g, x - sx * i, EA[1], "p" if bright else "o")
        put(g, x + sx, EA[1], "v")
    if bright:  # the echo's head blinks
        put(g, EA[0] + 1, EA[1] - 34, "1")
    return g


def light_column(g: Grid, cx: int, y0: int, y1: int, half_w: float, core: str = "1", mid: str = "p", edge: str = "o",
                 density: float = 1.0, taper: bool = False) -> None:
    """A vertical beam; taper: narrower towards the top, dithered away over its top quarter, flared at the foot."""
    for y in range(y0, y1 + 1):
        f = (y - y0) / max(1, y1 - y0)  # 0 top .. 1 foot
        hw = half_w * (0.45 + 0.55 * f) + (1.0 if taper and y >= y1 - 1 else 0.0) if taper else half_w
        dens = density * (min(1.0, 0.25 + f * 3) if taper else 1.0)
        for x in range(int(cx - hw - 1), int(cx + hw + 2)):
            d = abs(x - cx)
            if d > hw or not dz(x, y, dens):
                continue
            put(g, x, y, core if d <= hw * 0.3 else (mid if d <= hw * 0.65 else edge))


def echo_place(k: int) -> Grid:
    """Placement burst (over Totoy, at his feet): 1 flash + small ring, 2 ring opens and the echo forms,
    3 ring overshoots with bright runes, 4 settles, 5 calm (the anchor loop takes over)."""
    fx, fy = EA
    chest = (fx + 1, fy - 17)
    if k == 1:
        g = blank(EC, EC)
        light_column(g, fx, fy - 30, fy, 2.5, density=0.6)
        star(g, chest[0], chest[1], 4, "1", "p", "o", diag="o")
        ellipse_ring(g, fx, fy, 4, 1.5, "p")
        return g
    if k == 2:
        g = echo_cell(1, density=0.35, rx=8, ry=3, ring={"dash": "o", "tick": "p", "tip": "1"}, motes=False)
        ellipse_ring(g, fx, fy, 9, 3.4, "p", keep=lambda i, x, y, a: i % 2 == 0)
        for a in (200, 250, 290, 340):
            r = 11
            put(g, rnd(chest[0] + r * math.cos(math.radians(a))), rnd(chest[1] + r * 0.9 * math.sin(math.radians(a))), "p")
        return g
    if k == 3:
        g = echo_cell(2, density=0.75, rx=14, ry=5.2, ring={"dash": "o", "tick": "1", "tip": "p", "inner": "o"}, motes=False)
        for a in (200, 250, 290, 340, 20):
            r = 15
            put(g, rnd(chest[0] + r * math.cos(math.radians(a))), rnd(chest[1] + r * 0.9 * math.sin(math.radians(a))), "o")
        return g
    if k == 4:
        g = echo_cell(3, ring={"dash": "u", "tick": "p", "tip": "1"})
        for a in (210, 330):
            put(g, rnd(chest[0] + 17 * math.cos(math.radians(a))), rnd(chest[1] + 15 * math.sin(math.radians(a))), "v")
        return g
    return echo_cell(4)


def echo_vanish(k: int) -> Grid:
    """Departure (where Totoy stood when the recall fires; the hero is not drawn): 1 a column of light,
    2 it pinches to a line and stretches up, 3 it breaks upward, 4 motes, 5 last motes. The floor ring grows and breaks."""
    g = blank(EC, EC)
    fx, fy = EA
    rng = random.Random(70 + k)
    if k == 1:
        light_column(g, fx + 1, fy - 34, fy, 4.5, taper=True)
        ellipse_ring(g, fx, fy, 6, 2.2, "p")
        for dx in (-7, 8):
            for i in range(3):
                put(g, fx + dx, fy - 8 - i * 7, "v")
    elif k == 2:
        light_column(g, fx + 1, fy - 42, fy, 2.2, core="1", mid="p", edge="o", taper=True)
        ellipse_ring(g, fx, fy, 10, 3.6, "o", keep=lambda i, x, y, a: i % 3 != 2)
        for dy in (8, 16, 24):
            put(g, fx - 3, fy - dy, "p")
            put(g, fx + 5, fy - dy - 3, "o")
    elif k == 3:
        for y in range(fy - 44, fy - 6):
            if (y // 3) % 2 == 0:
                put(g, fx + 1, y, "p" if y < fy - 30 else "o")
        ellipse_ring(g, fx, fy, 13, 4.8, "u", keep=lambda i, x, y, a: i % 3 == 0)
        for _ in range(7):
            put(g, fx + rng.randint(-6, 7), fy - rng.randint(6, 34), rng.choice("pov"))
    else:
        n = 8 if k == 4 else 4
        for _ in range(n):
            put(g, fx + rng.randint(-8, 9), fy - rng.randint(10, 40), rng.choice("ov" if k == 4 else "vn"))
        if k == 4:
            ellipse_ring(g, fx, fy, 15, 5.5, "v", keep=lambda i, x, y, a: i % 5 == 0)
    return g


def echo_arrive(k: int) -> Grid:
    """Arrival at the echo: 1 the echo flares white and streaks pull in, 2 flash (Totoy appears here) + ring,
    3 ring opens and the runes scatter, 4 broken ring, 5 motes."""
    fx, fy = EA
    chest = (fx + 1, fy - 17)
    rng = random.Random(90 + k)
    if k == 1:
        g = echo_cell(0, bright=True, ring={"dash": "p", "tick": "1", "tip": "1", "inner": "o"}, motes=False, bob=0)
        for a in (160, 200, 20, 340):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            for r in (12, 13, 15, 16):
                put(g, rnd(chest[0] + r * ca), rnd(chest[1] + r * sa), "p" if r < 14 else "o")
        return g
    g = blank(EC, EC)
    if k == 2:
        star(g, chest[0], chest[1], 6, "1", "p", "o", diag="p")
        light_column(g, fx + 1, fy - 34, fy, 3.0, density=0.5)
        ellipse_ring(g, fx, fy, 9, 3.4, "1")
        ellipse_ring(g, fx, fy, 7, 2.6, "p", keep=lambda i, x, y, a: i % 2 == 0)
    elif k == 3:
        ellipse_ring(g, fx, fy, 15, 5.6, "p", keep=lambda i, x, y, a: i % 4 != 3)
        ellipse_ring(g, fx, fy, 12.5, 4.6, "o", keep=lambda i, x, y, a: i % 2 == 0)
        for a in range(0, 360, 60):
            ca, sa = math.cos(math.radians(a + 15)), math.sin(math.radians(a + 15))
            put(g, rnd(chest[0] + 13 * ca), rnd(chest[1] + 13 * sa), "p")
            put(g, rnd(chest[0] + 15 * ca), rnd(chest[1] + 15 * sa), "o")
    elif k == 4:
        ellipse_ring(g, fx, fy, 18, 6.6, "u", keep=lambda i, x, y, a: i % 3 == 0)
        for _ in range(6):
            put(g, fx + rng.randint(-12, 12), fy - rng.randint(8, 30), rng.choice("pov"))
    else:
        for _ in range(4):
            put(g, fx + rng.randint(-12, 12), fy - rng.randint(12, 36), rng.choice("vo"))
        ellipse_ring(g, fx, fy, 19, 7.0, "v", keep=lambda i, x, y, a: i % 6 == 0)
    return g


def echo_bubble(k: int) -> Grid:
    """Generic invulnerability shield over any hero frame (40x48, anchor (20,44) = feet): a dithered bubble rim with a
    glint that sweeps round it; 4 frames, 4 sparser (fading)."""
    g = blank(40, 48)
    cx, cy, rx, ry = 20.5, 44 - 17, 12.0, 19.0
    dens = (1.0, 1.0, 0.8, 0.45)[k]
    glint_a = (-60, 20, 110, 200)[k]
    n = 160
    seen = set()
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rnd(cx + rx * math.cos(a)), rnd(cy + ry * math.sin(a))
        if (x, y) in seen:
            continue
        seen.add((x, y))
        ad = (math.degrees(a) - glint_a + 540) % 360 - 180
        if abs(ad) < 14:
            put(g, x, y, "1")
        elif abs(ad) < 32:
            put(g, x, y, "p")
        elif dz(x, y, 0.5 * dens):
            put(g, x, y, "o")
        elif dz(x + 2, y, 0.25 * dens):
            put(g, x, y, "n")
        # inner sheen, 2 px inside, on the upper-left only
        if math.cos(a) < -0.2 and math.sin(a) < 0.1 and dz(x, y, 0.3 * dens):
            put(g, rnd(cx + (rx - 2) * math.cos(a)), rnd(cy + (ry - 2) * math.sin(a)), "p")
    if k < 3:
        star(g, rnd(cx + rx * math.cos(math.radians(glint_a))), rnd(cy + ry * math.sin(math.radians(glint_a))), 2, "1", "p", "o")
    return g


def echo_shield_overlay(src: Grid, k: int) -> Grid:
    """Per-hero-frame shield: a water-white outline that hugs the silhouette with a glint running down it.
    Same size and anchor as the hero frame (trimmed by the caller); draw it on top."""
    h, w = len(src), len(src[0])
    g = blank(w, h)
    ring = outside_ring(src)
    if not ring:
        return g
    ys = [y for _, y in ring]
    top, bot = min(ys), max(ys)
    glint = top + (bot - top) * (k / 3.0)
    dens = (1.0, 1.0, 0.75, 0.4)[k]
    for x, y in ring:
        d = abs(y - glint)
        if d < 1.5:
            put(g, x, y, "1")
        elif d < 4:
            put(g, x, y, "p")
        elif dz(x, y, 0.6 * dens):
            put(g, x, y, "o")
    return g


TRAIL_TPL = {  # horizontal 16x8 tile, one row string per y (period divides 16 so it tiles); phases 1-4
    1: lambda x, y: {4: "1", 3: "p", 5: "p", 2: "o" if x % 2 == 0 else T, 6: "o" if x % 2 == 1 else T,
                     1: "v" if x % 4 == 1 else T, 7: "v" if x % 4 == 3 else T}.get(y, T),
    2: lambda x, y: {4: "1" if x % 8 < 3 else "p", 3: "o" if x % 2 == 0 else "v", 5: "o" if x % 2 == 1 else "v",
                     2: "v" if x % 4 == 0 else T, 6: "v" if x % 4 == 2 else T}.get(y, T),
    3: lambda x, y: {4: ("p" if x % 8 == 1 else "o") if x % 4 != 3 else T, 3: "v" if x % 4 == 1 else T,
                     5: "v" if x % 4 == 3 else T}.get(y, T),
    4: lambda x, y: {4: "o" if x % 8 == 2 else ("v" if x % 8 == 6 else T), 3: "v" if x % 16 == 11 else T,
                     5: "n" if x % 16 == 4 else T}.get(y, T),
}


def trail_h(ph: int, shift: int = 0) -> Grid:
    return [[TRAIL_TPL[ph]((x + shift) % 16, y) for x in range(16)] for y in range(8)]


def trail_d(ph: int) -> Grid:
    """45 degree tile (down-right), 16x16: tiles along the diagonal (offset 16,16)."""
    g = blank(16, 16)
    for y in range(16):
        for x in range(16):
            u = (y - x + 8) % 16 - 8
            if -3 <= u <= 3:
                g[y][x] = TRAIL_TPL[ph](x, 4 + u)
    return g


def trail_v(ph: int) -> Grid:
    h = trail_h(ph)
    return [[h[x][y] for x in range(8)] for y in range(16)]


def trail_head(ph: int) -> Grid:
    """Comet head at the echo end of the streak (16x16, anchor (8,8) = the echo's chest point)."""
    g = blank(16, 16)
    r = (4.5, 3.5, 2.5, 1.5)[ph - 1]
    for y in range(16):
        for x in range(16):
            d = abs(x - 7.5) + abs(y - 7.5) * 1.15
            if d <= r * 0.45:
                g[y][x] = "1"
            elif d <= r * 0.8:
                g[y][x] = "p"
            elif d <= r + 0.3:
                g[y][x] = "o" if ph < 3 else "v"
    if ph <= 2:
        for dx, dy in ((0, -6), (0, 6), (6, 0), (-6, 0)):
            put(g, 7 + dx // (ph + 0), 7 + dy // (ph + 0), "p" if ph == 1 else "o")
    return g


def echo_dust(k: int) -> Grid:
    """Dust kicked up at the feet on placement / departure / arrival (32x16, anchor (16,12))."""
    g = blank(32, 16)
    rng = random.Random(120 + k)
    spread = (3, 6, 9, 11, 12)[k - 1]
    r = (2.0, 2.4, 2.2, 1.6, 1.0)[k - 1]
    dens = (1.0, 0.95, 0.8, 0.6, 0.4)[k - 1]
    for s in (-1, 1):
        puff(g, 16 + s * spread, 12 - (k - 1) // 2, r, "j", "i", dens, rng)
        if k >= 2:
            puff(g, 16 + s * (spread - 3), 12 - k // 2 - 1, r * 0.7, "j", "v", dens * 0.9, rng)
    if k >= 3:
        for s in (-1, 1):
            put(g, 16 + s * (spread + 3), 12 - k, "v")
    return g


# ================================================================================================ STONE WARD
SLAB = [  # 11 x 24, ink outline; F = carved face (filled by slab_grid)
    "....000....",
    "...0jj00...",
    "..0jiih0...",
    "..0iihhg0..",
    ".0jihhhgf0.",
    ".0iihhhgf0.",
    ".0iihhhgf0.",
    ".0iihhggf0.",
    ".0jihhhgf0.",
    ".0iihhhgf0.",
    ".0iihhhgf0.",
    ".0iihhhgf0.",
    "0jiihhggff0",
    "0iihhhhgff0",
    "0iihhhhgff0",
    "0iihhhggff0",
    "0jiihhhgff0",
    "0iihhhhgff0",
    "0iihhhhgff0",
    "0iihhhhgff0",
    "0iiihhhggf0",
    "0hiihhhggf0",
    "0ggggggfff0",
    "00000000000",
]
SLAB_W, SLAB_H = 11, 24
RUNE = [(5, 6), (5, 7), (5, 8), (4, 9), (6, 9), (3, 10), (7, 10), (4, 11), (6, 11), (5, 12), (5, 13), (5, 14),
        (4, 15), (6, 15), (3, 16), (7, 16), (5, 17), (5, 18)]  # carved glyph, top to bottom
SLAB_CRACKS = [(7, 3), (6, 4), (6, 5), (7, 6), (8, 7), (2, 12), (3, 13), (3, 14), (2, 15), (8, 19), (7, 20), (8, 21), (5, 20), (4, 21)]
SLAB_DX = 7  # slab left edge = feet x + 7 (in front of Totoy)
HC, HA = (40, 40), (12, 35)  # composed ward hero frames: 40x40, anchor (12,35) = feet (as hero2_idle)


def slab_grid(rune: int = 0, glint: int = -1, cracks: int = 0) -> Grid:
    """rune 0 carved (dark), 1 dim teal, 2 lit, 3 bright; glint = index along the rune that flashes; cracks 1 = glowing."""
    g = [list(r) for r in SLAB]
    rcol = {0: ("f", "f"), 1: ("t", "t"), 2: ("u", "o"), 3: ("o", "p")}[rune]
    for i, (x, y) in enumerate(RUNE):
        c = rcol[0] if i % 3 else rcol[1]
        if glint >= 0 and abs(i - glint) <= 1:
            c = "1" if i == glint else "p"
        g[y][x] = c
    if cracks:
        for x, y in SLAB_CRACKS:
            if g[y][x] not in (T, "0"):
                g[y][x] = "p" if cracks == 1 else "0"
    return g


def slab_overlay(vis: int, dy: int = 0, rune: int = 0, glint: int = -1, cracks: int = 0, dust: int = 0) -> Grid:
    """The slab as an overlay in the 40x40 hero cell (anchor (12,35)); only the top `vis` rows show above the ground."""
    g = blank(*HC)
    slab = slab_grid(rune, glint, cracks)
    gx, gy = HA[0] + SLAB_DX, HA[1] + 1  # ground line under the slab
    vis = max(0, min(SLAB_H, vis))
    for y in range(vis):
        for x in range(SLAB_W):
            c = slab[y][x]
            if c != T:
                put(g, gx + x, gy - vis + y + dy, c)
    rng = random.Random(30 + vis + dust)
    if dust:
        for s in (-1, 1):
            puff(g, gx + 5 + s * (5 + dust), gy - 1, 1.6 + dust * 0.3, "j", "i", 0.9, rng)
    if 0 < vis < SLAB_H:  # rubble lip at the ground where it breaks through
        for x in range(-1, SLAB_W + 1):
            if (x * 7 + vis) % 3:
                put(g, gx + x, gy, "g" if x % 2 else "f")
        put(g, gx - 1, gy - 1, "h")
        put(g, gx + SLAB_W, gy - 1, "h")
    return g


def ward_raise_slab(k: int) -> Grid:
    """1 the ground splits and chips fly, 2 the slab is half up, 3 full height + 2 px overshoot, 4 settles, rune lights."""
    if k == 1:
        g = slab_overlay(5, dust=1)
        gx, gy = HA[0] + SLAB_DX, HA[1] + 1
        for dx, dy, c in ((-2, -5, "h"), (12, -6, "i"), (4, -9, "g"), (9, -10, "h"), (1, -8, "i")):
            put(g, gx + dx, gy + dy, c)
        return g
    if k == 2:
        return slab_overlay(15, dust=2)
    if k == 3:
        return slab_overlay(24, dy=-2, rune=1, dust=3)
    return slab_overlay(24, rune=2, glint=0)


def ward_hold_slab(k: int) -> Grid:
    return slab_overlay(24, rune=2, glint=(4, 9, 13, 17)[k])


def ward_drop_slab(k: int) -> Grid:
    """1 the slab cracks with light, 2 it splits into chunks that fall away, 3 rubble at the base."""
    if k == 1:
        return slab_overlay(24, rune=3, cracks=1)
    g = blank(*HC)
    slab = slab_grid(1, cracks=2)
    gx, gy = HA[0] + SLAB_DX, HA[1] + 1 - SLAB_H
    if k == 2:
        chunks = [((0, 0, 11, 8), (2, 6)), ((0, 8, 11, 16), (-1, 4)), ((0, 16, 11, 24), (0, 1))]
        for (x0, y0, x1, y1), (ox, oy) in chunks:
            for y in range(y0, y1):
                for x in range(x0, x1):
                    c = slab[y][x]
                    if c != T and (x + y) % 5:
                        put(g, gx + x + ox, gy + y + oy, c)
        rng = random.Random(41)
        for _ in range(6):
            put(g, gx + rng.randint(-3, 13), gy + rng.randint(4, 22), rng.choice("hij"))
        return g
    rng = random.Random(42)
    base = HA[1] + 1
    for cx, w in ((gx + 1, 4), (gx + 6, 3), (gx + 10, 2)):
        for x in range(w):
            put(g, cx + x, base - 1, "h" if x else "i")
            put(g, cx + x, base, "g")
        put(g, cx - 1, base, "0")
        put(g, cx + w, base, "0")
    for _ in range(6):
        put(g, gx + rng.randint(-4, 14), base - rng.randint(2, 6), rng.choice("ij"))
    return g


# barrier crescent (48x48, anchor (16,44) = feet; in front of the slab)
BC, BA = 48, (16, 44)
B_CX, B_CY, B_RX, B_RY = BA[0] + 13, BA[1] - 16, 9.0, 19.0
B_RUNES = [-70, -35, 0, 35, 70]  # rune glyph angles on the crescent (0 = straight ahead)


def b_q(x: int, y: int, s: float = 1.0) -> float:
    return math.hypot((x - B_CX) / (B_RX * s), (y - B_CY) / (B_RY * s))


def b_ang(x: int, y: int) -> float:
    return math.degrees(math.atan2((y - B_CY) / B_RY, (x - B_CX) / B_RX))


def barrier(phase: int, mode: str = "idle", ripple: int = -1) -> Grid:
    """Rune ward: a dithered stone-grey crescent dome in front of Totoy with teal rune glints.
    mode idle (6-phase loop) / absorb (bright flash, ripple from the hit point)."""
    g = blank(BC, BC)
    hot = mode == "absorb"
    for y in range(BC):
        for x in range(BC):
            if y > BA[1]:
                continue
            q = b_q(x, y)
            a = b_ang(x, y)
            if abs(a) > 100 or q > 1.04:
                continue
            chk = (x + y) % 2 == 0
            if q > 0.92:  # outer rim
                g[y][x] = ("p" if chk else "o") if hot else ("j" if a < -40 else ("i" if chk or a < 40 else "h"))
            elif q > 0.78:
                if chk:
                    g[y][x] = "o" if hot else ("i" if a < -30 else ("h" if a < 30 else "g"))
                elif q > 0.85 and not hot:
                    g[y][x] = "g" if a < 0 else "f"
            elif q > 0.66:
                if dz(x, y + phase, 0.4):
                    g[y][x] = ("p" if (y + phase) % 7 == 0 else "u") if hot else ("u" if (y + phase) % 9 == 0 else "t")
            elif 0.5 < q < 0.56 and abs(a) < 75 and (y + phase) % 3 == 0:
                g[y][x] = "o" if hot else "h"
            elif q > 0.2 and dz(x + phase, y, 0.1 if not hot else 0.22) and abs(a) < 80:
                g[y][x] = "u" if hot else "t"
    glint = (phase % 6) * (len(B_RUNES) + 1) / 6.0 - 0.5
    for i, a in enumerate(B_RUNES):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        x, y = rnd(B_CX + B_RX * 0.87 * ca), rnd(B_CY + B_RY * 0.87 * sa)
        lit = abs(i - glint) < 0.6
        col = ("1" if lit else "p") if hot else ("p" if lit else "u")
        for dx, dy in ((0, -1), (0, 0), (0, 1)):
            put(g, x + dx, y + dy, col)
        put(g, x - 1, y, "o" if lit or hot else "t")
    if ripple >= 0:  # ripple from the hit point at the front of the dome
        hx, hy = rnd(B_CX + B_RX), rnd(B_CY - 2)
        r = 2 + ripple * 2.5
        for i in range(48):
            a = 2 * math.pi * i / 48
            x, y = rnd(hx + r * 0.5 * math.cos(a)), rnd(hy + r * math.sin(a))
            if b_q(x, y) < 1.05 and i % (1 + ripple) == 0:
                put(g, x, y, "1" if ripple < 2 else "p")
    return g


def ward_absorb(k: int) -> Grid:
    if k == 3:
        g = barrier(k + 2, "idle", ripple=3)
        return g
    return barrier(k + 2, "absorb" if k < 2 else "idle", ripple=k)


def ward_store(level: int, k: int) -> Grid:
    """Stored energy, drawn over the barrier: 1 a few teal motes orbit the dome, 2 a teal halo + more motes,
    3 a bright halo, sparks and crackle. 4-frame loop each (about 90 ms)."""
    g = blank(BC, BC)
    halo = {1: 0.0, 2: 0.3, 3: 0.55}[level]
    hc = {1: "t", 2: "u", 3: "o"}[level]
    for y in range(BC):
        for x in range(BC):
            if y > BA[1]:
                continue
            q = b_q(x, y)
            a = b_ang(x, y)
            if 1.06 < q < 1.06 + 0.1 * level and abs(a) < 105 and dz(x + k, y + k * 2, halo):
                g[y][x] = hc
    n = {1: 3, 2: 5, 3: 8}[level]
    cols = {1: "uo", 2: "op", 3: "p1"}[level]
    for i in range(n):
        a = math.radians(-100 + (i * 200 / max(1, n - 1)) + k * 9 * (1 if i % 2 else -1))
        rr = 1.18 + 0.08 * ((i + k) % 3)
        x, y = rnd(B_CX + B_RX * rr * math.cos(a)), rnd(B_CY + B_RY * rr * math.sin(a))
        put(g, x, y, cols[(i + k) % 2])
        if level >= 2:
            put(g, x - 1 if i % 2 else x + 1, y + 1, "u")
    if level == 3:  # crackle: two short zig-zags off the rim that change each frame
        rng = random.Random(300 + k)
        for _ in range(2):
            a = math.radians(rng.randint(-80, 80))
            x, y = B_CX + B_RX * 1.05 * math.cos(a), B_CY + B_RY * 1.05 * math.sin(a)
            for s in range(4):
                x += math.cos(a) * 1.4 + rng.uniform(-0.8, 0.8)
                y += math.sin(a) * 1.4 + rng.uniform(-0.8, 0.8)
                put(g, rnd(x), rnd(y), "1" if s < 2 else "p")
    return g


def ward_block(k: int) -> Grid:
    """Block impact where a hit lands on the ward (32x32, anchor (16,16)): stone chips and teal/cream sparks."""
    g = blank(32, 32)
    c = 16
    rng = random.Random(55)
    chips = [(rng.uniform(-150, 150), rng.uniform(1.6, 2.6), rng.choice("hij")) for _ in range(7)]
    if k == 1:
        star(g, c, c, 3, "1", "1", "p", diag="p")
        ellipse_ring(g, c, c, 4, 4, "o", keep=lambda i, x, y, a: i % 2 == 0)
        return g
    if k == 2:
        star(g, c, c, 6, "1", "p", "o", diag="p")
        ellipse_ring(g, c, c, 6, 6, "u", keep=lambda i, x, y, a: i % 2 == 0)
    if k == 3:
        star(g, c, c, 3, "p", "o", "u")
        for a in range(0, 360, 45):
            ca, sa = math.cos(math.radians(a + 22)), math.sin(math.radians(a + 22))
            for r in (6, 7, 8):
                put(g, rnd(c + r * ca), rnd(c + r * sa), "p" if r < 8 else "o")
    if k == 4:
        for a in range(0, 360, 90):
            ca, sa = math.cos(math.radians(a + 45)), math.sin(math.radians(a + 45))
            put(g, rnd(c + 10 * ca), rnd(c + 10 * sa), "u")
    for ang, sp, col in chips:  # chips fly back toward the attacker (the +x side, mirrored by the caller) and fall
        t = k - 1
        if t <= 0:
            continue
        x = c + math.cos(math.radians(ang)) * sp * t * 2.2
        y = c + math.sin(math.radians(ang)) * sp * t * 1.6 + 0.6 * t * t
        if k == 5 and (int(x) + int(y)) % 2:
            continue
        put(g, rnd(x), rnd(y), col)
        if k <= 3:
            put(g, rnd(x) + 1, rnd(y), "0" if col != "j" else "h")
    if k == 5:
        for _ in range(4):
            put(g, c + rng.randint(-9, 9), c + rng.randint(-9, 6), rng.choice("uv"))
    return g


SWC, SWA = (144, 80), (72, 50)  # shockwave canvas, anchor = Totoy's feet (the ring centre)
SW_R = (6, 18, 30, 41, 50, 57, 62, 64)
SW_SQ = 0.45  # floor squash (ry = 0.45 rx)


def ward_shockwave(k: int) -> Grid:
    """Release: an expanding ring on the floor out to about 64 px with stone shards thrown up and dust at the rim.
    8 frames; 1 burst at the feet, 2-6 the ring sweeps out, 7 full radius, 8 breaks into dust."""
    g = blank(*SWC)
    cx, cy = SWA
    R = SW_R[k - 1]
    ry = R * SW_SQ
    lead = {1: "1", 2: "1", 3: "1", 4: "p", 5: "p", 6: "p", 7: "o", 8: "u"}[k]
    body = {1: "p", 2: "p", 3: "o", 4: "o", 5: "o", 6: "u", 7: "u", 8: "t"}[k]
    tail = {1: "o", 2: "u", 3: "u", 4: "u", 5: "t", 6: "t", 7: "t", 8: "v"}[k]
    if k == 1:
        star(g, cx, cy - 8, 6, "1", "p", "o", diag="p")
    if k <= 7:
        thick = 2 if k < 7 else 1
        for i in range(thick):
            ellipse_ring(g, cx, cy, R - i, ry - i * SW_SQ, lead if i == 0 else body,
                         keep=(None if k < 6 else (lambda i2, x, y, a: i2 % 7 != 0)))
        ellipse_ring(g, cx, cy, R - 3, (R - 3) * SW_SQ, body, keep=lambda i2, x, y, a: i2 % 2 == 0)
        if R > 10:
            ellipse_ring(g, cx, cy, R - 6, (R - 6) * SW_SQ, tail, keep=lambda i2, x, y, a: i2 % 3 == 0)
        if R > 20:
            ellipse_ring(g, cx, cy, R - 10, (R - 10) * SW_SQ, "t", keep=lambda i2, x, y, a: i2 % 5 == 0)
    else:
        ellipse_ring(g, cx, cy, R, ry, "u", keep=lambda i2, x, y, a: i2 % 4 == 0)
        ellipse_ring(g, cx, cy, R - 2, (R - 2) * SW_SQ, "v", keep=lambda i2, x, y, a: i2 % 6 == 1)
    # dust along the rim (frames 3-8)
    rng = random.Random(800 + k)
    if k >= 3:
        for i in range(14 if k < 8 else 10):
            a = 2 * math.pi * i / 14 + 0.2
            x, y = cx + (R + 1) * math.cos(a), cy + (ry + 1) * math.sin(a)
            puff(g, x, y - 1, (1.4 if k < 6 else 1.1) if k < 8 else 0.8, "j", "i", 0.75 if k < 7 else 0.45, rng)
    # stone shards thrown up: they ride just behind the ring and arc up and down
    if 2 <= k <= 6:  # a lip of broken earth pushed up along the front half of the ring
        n = int(2 * math.pi * R)
        for i in range(0, n, 3):
            a = 2 * math.pi * i / n
            if math.sin(a) < 0.15 or (i // 3) % 3 == 2:
                continue
            x, y = rnd(cx + (R + 1) * math.cos(a)), rnd(cy + (R + 1) * SW_SQ * math.sin(a))
            put(g, x, y - 1, "i" if (i // 3) % 2 else "j")
            put(g, x + 1, y - 1, "h")
            put(g, x, y, "g")
            put(g, x + 1, y, "f")
    srng = random.Random(77)
    shapes = ([".j.", "jih", "hgf", ".00"], ["ji", "hg", "00"], ["jh.", "igf", ".00"])
    for i in range(10):
        a = 2 * math.pi * i / 10 + srng.uniform(-0.25, 0.25)
        hmax = srng.uniform(8, 18)
        t = (k - 1) / 7
        if k == 8:
            continue
        r = R * 0.88
        z = hmax * 4 * t * (1 - t) + (3 if k == 1 else 0)
        x, y = rnd(cx + r * math.cos(a)), rnd(cy + r * SW_SQ * math.sin(a) - z)
        shp = shapes[i % 3]
        if (k + i) % 2:  # tumble: flip the chunk every other frame
            shp = [row[::-1] for row in shp]
        for yy, row in enumerate(shp):
            for xx, c in enumerate(row):
                if c != T:
                    put(g, x + xx - 1, y + yy - 1, c)
        if z > 3:  # shadow on the floor under a high shard
            sy = rnd(cy + r * SW_SQ * math.sin(a))
            put(g, x, sy, "e")
            put(g, x - 1, sy, "e")
    return g


CRC, CRA = (96, 48), (48, 24)  # crack decal canvas / anchor (Totoy's feet at release)


def crack_paths() -> list[list[tuple[int, int]]]:
    rng = random.Random(909)
    paths = []
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.25, 0.25)
        L = rng.uniform(22, 42)
        x, y = 0.0, 0.0
        pts = [(rnd(CRA[0] + x), rnd(CRA[1] + y * SW_SQ))]
        steps = int(L / 3)
        for s in range(steps):
            aa = a + rng.uniform(-0.5, 0.5)
            x += math.cos(aa) * 3
            y += math.sin(aa) * 3
            pts.append((rnd(CRA[0] + x), rnd(CRA[1] + y * SW_SQ * 1.0)))
        px = []
        for p0, p1 in zip(pts, pts[1:]):
            px += line_pts(p0[0], p0[1], p1[0], p1[1])
        paths.append(px)
        if i % 2 == 0:  # a branch
            j = len(px) // 2
            bx, by = px[j]
            ba = a + (0.7 if i % 4 == 0 else -0.7)
            e = (bx + math.cos(ba) * 8, by + math.sin(ba) * 8 * SW_SQ)
            paths.append(line_pts(bx, by, e[0], e[1]))
    return paths


def ward_cracks(k: int) -> Grid:
    """Floor decal at the release point (draw UNDER characters): 1 cracks glow teal-white, 2 glow cools,
    3 dark cracks with teal glints, 4 fading (dither)."""
    g = blank(*CRC)
    for x in range(CRA[0] - 7, CRA[0] + 8):  # crater
        for y in range(CRA[1] - 3, CRA[1] + 4):
            q = math.hypot((x - CRA[0]) / 6.5, (y - CRA[1]) / 3.0)
            if q <= 1:
                if k == 4 and not dz(x, y, 0.5):
                    continue
                g[y][x] = "0" if q > 0.75 else ("e" if (x + y) % 2 else "f")
    for pi, px in enumerate(crack_paths()):
        n = len(px)
        for i, (x, y) in enumerate(px):
            t = i / max(1, n - 1)
            if k == 4 and not dz(x, y, 0.55 - 0.4 * t):
                continue
            if k == 1:
                core = "1" if t < 0.3 else ("p" if t < 0.7 else "o")
                put(g, x, y, core)
                if (x + y) % 2 == 0 and get(g, x, y + 1) == T:
                    put(g, x, y + 1, "u")
            elif k == 2:
                put(g, x, y, "o" if t < 0.4 else ("u" if t < 0.75 else "t"))
                if get(g, x, y + 1) == T:
                    put(g, x, y + 1, "0")
            else:
                glint = k == 3 and (i + pi) % 6 == 0
                put(g, x, y, "u" if glint else "0")
                if get(g, x, y + 1) == T and dz(x, y, 0.5):
                    put(g, x, y + 1, "e")
    return g


# ================================================================================================ SPRINT
def sprint_aura(src: Grid, ph: int) -> Grid:
    """Faint pale-cyan outline over a hero frame with sparkles crawling round it and short streaks off the back.
    Same size and anchor as the hero frame (trimmed by the caller); draw it on top."""
    h, w = len(src), len(src[0])
    g = blank(w, h)
    ring = outside_ring(src)
    for x, y in ring:
        back = get(src, x + 1, y) != T  # the silhouette is to the right: a back edge (wind-swept side)
        top = get(src, x, y + 1) != T
        v = (x + 2 * y + ph) % 6
        if back or top:
            if v == 0:
                continue
            put(g, x, y, "p" if (y + ph) % 5 == 0 else "o")
        elif v == 1 and (y + ph) % 2 == 0:  # the front and underside: only a sparse shimmer
            put(g, x, y, "o")
    if ring:  # two sparkles that hop round the outline
        n = len(ring)
        srt = sorted(ring, key=lambda p: math.atan2(p[1] - h / 2, p[0] - w / 2))
        for j in (0, n // 2):
            x, y = srt[(ph * n // 6 + j) % n]
            put(g, x, y, "1")
    for y in range(1, h, 3):  # back streaks (the hero runs right, so behind = the left)
        if (y // 3 + ph) % 2:
            continue
        xs = [x for x in range(w) if src[y][x] != T]
        if not xs:
            continue
        x0 = xs[0]
        L = 3 + (y + ph) % 3
        for i in range(2, 2 + L):
            if get(src, x0 - i, y) == T:
                put(g, x0 - i, y, "o" if i < 4 else "n")
    return g


AFTER_STEP = 12  # px between afterimages (suggested: where the hero was 1, 2, 3 x ~150 ms ago)


def sprint_after(src: Grid, k: int) -> Grid:
    """Afterimage k (1 nearest, brightest .. 3 faintest): the hero frame as a cyan ghost, thinned by ordered dither."""
    h, w = len(src), len(src[0])
    g = blank(w, h)
    edge_lvl = (0.85, 0.55, 0.3)[k - 1]
    fill_lvl = (0.22, 0.1, 0.0)[k - 1]
    ecol = ("o", "n", "m")[k - 1]
    icol = ("n", "m", "m")[k - 1]
    for y in range(h):
        for x in range(w):
            if src[y][x] == T:
                continue
            if is_edge(src, x, y):
                if dz(x, y, edge_lvl):
                    g[y][x] = "p" if k == 1 and get(src, x, y - 1) == T and x % 3 == 0 else ecol
            elif dz(x + 1, y, fill_lvl):
                g[y][x] = icol
    return g


SPC, SPA = (48, 40), (36, 35)  # speed lines / start / end canvases: anchor = feet (lines trail to the left)


def sprint_lines(k: int) -> Grid:
    """Speed lines behind Totoy (4-frame loop, about 60 ms): lanes of streaks that slide back."""
    g = blank(*SPC)
    lanes = [(4, 14, 0), (9, 9, 5), (14, 12, 2), (19, 8, 7), (24, 13, 3), (29, 10, 6)]
    for i, (dy, L, off) in enumerate(lanes):
        if (i + k) % 4 == 3:
            continue
        x_end = SPA[0] - 6 - ((k * 7 + off * 3) % 14)
        y = SPA[1] - dy
        for j in range(L):
            x = x_end - j
            c = "1" if j == 0 else ("p" if j < 3 else ("o" if j < L - 3 else "n"))
            if j > L - 3 and j % 2:
                continue
            put(g, x, y, c)
    return g


WC, WA = (40, 40), (14, 35)


def sprint_wind(k: int) -> Grid:
    """Wind streaks wrapping round the front of the body and peeling back (4-frame loop, about 70 ms)."""
    g = blank(*WC)
    fx, fy = WA
    for j, (h0, h1, bulge, off) in enumerate(((-31, -18, 6, 0), (-22, -6, 7, 2), (-14, -2, 5, 1))):
        if (j + k) % 4 == 3:
            continue
        drift = (k + j) % 4
        n = 14
        for i in range(n):
            t = i / (n - 1)
            x = fx + 4 + bulge * math.sin(math.pi * t) - drift * 2 - (t * t) * 4
            y = fy + h0 + (h1 - h0) * t
            if (i + k + off) % 4 == 3:
                continue
            put(g, rnd(x), rnd(y), "p" if 0.3 < t < 0.7 else "o")
        # the tail peels back over the head / behind the feet
        tx, ty = rnd(fx + 4 - drift * 2 - 4), rnd(fy + h1)
        for i in range(1, 4 + drift):
            if i % 2:
                put(g, tx - i, ty + (1 if j == 2 else 0), "n" if i > 3 else "o")
    return g


DC, DA = (40, 16), (28, 12)


def sprint_dust(k: int) -> Grid:
    """Dust puffs kicked back from alternating feet (6-frame loop, about 60 ms)."""
    g = blank(*DC)
    rng = random.Random(600 + k)
    for born, foot in ((0, -2), (2, 3), (4, -2)):
        age = (k - born) % 6
        r = (1.6, 2.3, 2.5, 2.1, 1.5, 0.9)[age]
        dens = (1.0, 1.0, 0.85, 0.7, 0.5, 0.35)[age]
        x = DA[0] + foot - age * 3.2
        y = DA[1] - 1 - age * 0.6
        puff(g, x, y, r, "j", "i", dens, rng)
        if age == 0:
            put(g, DA[0] + foot + 2, DA[1], "j")
    return g


def sprint_start(k: int) -> Grid:
    """Sprint start burst at the feet: 1 ground flash, 2 ring + big dust kick back + lines, 3-4 the ring opens and
    the dust thins, 5 motes."""
    g = blank(*SPC)
    fx, fy = SPA[0] - 12, SPA[1]  # the burst is centred on the feet; anchor (24,35)
    rng = random.Random(700 + k)
    if k == 1:
        for x in range(fx - 7, fx + 8):
            put(g, x, fy, "1" if abs(x - fx) < 4 else "p")
        star(g, fx, fy - 2, 3, "1", "p", "o")
        for x, y in ((fx - 5, fy - 6), (fx + 5, fy - 7), (fx, fy - 11)):
            put(g, x, y, "p")
        return g
    rr = (0, 12, 16, 19, 20)[k - 1]
    ellipse_ring(g, fx, fy, rr, rr * 0.33, ("p", "o", "u", "v")[k - 2], keep=lambda i, x, y, a: k == 2 or i % (k - 1) == 0)
    if k <= 4:
        for i, r in enumerate((2.6, 2.2, 1.8)):
            puff(g, fx - 6 - i * 5 - (k - 2) * 3, fy - 2 - i, r * (1.0 if k < 4 else 0.7), "j", "i", (1.0, 0.85, 0.6)[k - 2], rng)
        for dy, L in ((-8, 8), (-14, 6), (-20, 7)):
            x0 = fx - 10 - (k - 2) * 4
            for j in range(L):
                if k == 4 and j % 2:
                    continue
                put(g, x0 - j, fy + dy, "p" if j < 2 else "o")
    else:
        for _ in range(5):
            put(g, fx - rng.randint(4, 20), fy - rng.randint(2, 14), rng.choice("op"))
    return g


def sprint_end(k: int) -> Grid:
    """Sprint end: the aura tears off in pale shreds that drift back and up, a last small puff (4 frames)."""
    g = blank(*SPC)
    fx, fy = SPA[0] - 12, SPA[1]
    rng = random.Random(710)
    for i in range(10):
        bx, by = fx + rng.randint(-6, 6), fy - rng.randint(4, 30)
        x, y = bx - k * (2 + i % 3), by - k * (1 + i % 2)
        if (i + k) % (2 if k < 3 else 3) == 0 and k > 1:
            continue
        put(g, x, y, "p" if k < 3 else ("o" if k < 4 else "n"))
        if k <= 2:
            put(g, x + 1, y, "o")
    if k <= 2:
        puff(g, fx - 3 - k * 2, fy - 1, 1.8 - 0.4 * k, "j", "i", 0.8)
    ellipse_ring(g, fx, fy, (12, 9, 6, 4)[k - 1], (12, 9, 6, 4)[k - 1] * 0.33, ("o", "u", "v", "v")[k - 1],
                 keep=lambda i, x, y, a: i % (k + 1) == 0)
    return g


# ================================================================================================ ICONS
def icon_base() -> tuple[Grid, int]:
    return M.ring_from("ui_aspect_gale_cut_1", 8.6)


def icon_clip(g: Grid, tmp: Grid, n: int) -> Grid:
    for y in range(n):
        for x in range(n):
            if tmp[y][x] != T and math.hypot(x - 11.5, y - 11.5) < 8.6:
                g[y][x] = tmp[y][x]
    return g


ICON_GHOST = [  # small Totoy echo silhouette, 7 x 12 (B = body, E = edge)
    "..EEE..",
    ".EBBBE.",
    ".EBBBE.",
    "..EBE..",
    ".EBBBE.",
    "EBBBBBE",
    "E.BBB.E",
    "..BBB..",
    ".EB.BE.",
    ".EB.BE.",
    ".E...E.",
    "EE...EE",
]


def echo_icon(k: int = 0) -> Grid:
    """24px: a lilac echo of Totoy on its rune ring, and a bright streak pulling back to it from the right.
    k 1-4: lit variant while the echo is out (the echo pulses)."""
    g, n = icon_base()
    tmp = blank(n, n)
    for x, y, c in ((5, 18, "t"), (6, 19, "t"), (8, 19, "o"), (10, 19, "t"), (12, 19, "t"), (13, 18, "t"), (9, 17, "v"), (6, 17, "v"), (12, 17, "v")):
        put(tmp, x, y, c)
    ecol, bcol = {0: ("v", "u"), 1: ("v", "u"), 2: ("o", "o"), 3: ("p", "o"), 4: ("o", "u")}[k]
    for y, row in enumerate(ICON_GHOST):
        for x, c in enumerate(row):
            if c == "E":
                put(tmp, 6 + x, 6 + y, ecol)
            elif c == "B" and (x + y) % 2 == 0:
                put(tmp, 6 + x, 6 + y, bcol)
            elif c == "B":
                put(tmp, 6 + x, 6 + y, "n" if k in (0, 1, 4) else "p")
    # recall streak: from the right edge into the echo's chest, arrowhead pointing at the echo
    for x in range(14, 21):
        put(tmp, x, 11, "1" if x < 17 else "p")
        if x % 2 == 0:
            put(tmp, x + 1, 10, "o")
            put(tmp, x, 12, "o")
    for d in (1, 2):
        put(tmp, 14 + d, 11 - d, "p")
        put(tmp, 14 + d, 11 + d, "p")
    put(tmp, 19, 14, "v")
    put(tmp, 18, 8, "v")
    return icon_clip(g, tmp, n)


def ward_icon(k: int = 0) -> Grid:
    """24px: a stone slab with its teal rune, and the ward's crescent in front. k 1-4: lit (charged) variant."""
    g, n = icon_base()
    tmp = blank(n, n)
    slab = [
        "...000...",
        "..0jjh0..",
        ".0jiihg0.",
        "0jiihhgf0",
        "0iihhhgf0",
        "0iihhhgf0",
        "0iihhhgf0",
        "0jihhhgf0",
        "0iihhhgf0",
        "0iihhhgf0",
        "0iihhhgf0",
        "0hihhggf0",
        "0ggggfff0",
        "000000000",
    ]
    ox, oy = 5, 4
    for y, row in enumerate(slab):
        for x, c in enumerate(row):
            if c != T:
                put(tmp, ox + x, oy + y, c)
    rc, rc2 = {0: ("t", "u"), 1: ("u", "o"), 2: ("o", "p"), 3: ("p", "1"), 4: ("u", "o")}[k]
    for i, (x, y) in enumerate(((4, 3), (4, 4), (3, 5), (5, 5), (2, 6), (6, 6), (3, 7), (5, 7), (4, 8), (4, 9), (3, 10), (5, 10))):
        put(tmp, ox + x, oy + y, rc2 if i in (0, 4, 5, 8) else rc)
    # crescent ward in front
    for i in range(30):
        a = math.radians(-80 + i * 160 / 29)
        x, y = rnd(14 + 5 * math.cos(a)), rnd(12 + 7.5 * math.sin(a))
        put(tmp, x, y, "o" if (i % 3 or k == 0) else "p")
        if i % 2 == 0:
            put(tmp, x - 1, y, "t" if k == 0 else "u")
    if k:
        for x, y in ((19, 6), (20, 13), (18, 18)):
            if (x + y + k) % 2 == 0:
                put(tmp, x, y, "p")
    return icon_clip(g, tmp, n)


def sprint_icon(k: int = 0) -> Grid:
    """24px: two bright chevrons racing right with speed lines behind. k 1-4: lit variant (the lines flow)."""
    g, n = icon_base()
    tmp = blank(n, n)
    for cx, col, edge in ((12, "o", "n"), (16, "1", "p")):
        for d in range(5):
            put(tmp, cx - 4 + d, 7 + d, col)
            put(tmp, cx - 4 + d, 16 - d, col)
            put(tmp, cx - 5 + d, 7 + d, edge)
            put(tmp, cx - 5 + d, 16 - d, edge)
        put(tmp, cx + 1, 11, col)
        put(tmp, cx + 1, 12, col)
    shift = (k - 1) % 4 if k else 0
    for y, L, off in ((8, 3, 0), (11, 5, 1), (13, 4, 2), (16, 2, 3)):
        x1 = 8 - (y in (8, 16))
        for j in range(L):
            if k and (j + shift + off) % 4 == 3:
                continue
            x = x1 - j
            if x >= 3:
                put(tmp, x, y if y < 16 else 15, "p" if j == 0 else ("o" if j < 3 else "n"))
    return icon_clip(g, tmp, n)


# ================================================================================================ build
def overlay_group(sets: list[str], fn, phases: int) -> dict:
    """hero frame name -> (trimmed overlays (one crop for all phases), anchor, hero frame, its anchor)."""
    out = {}
    for vid in sets:
        for name in move_frames(vid):
            src, anc = load_sprite(name)
            ovs, oa = trim_group([fn(src, p) for p in range(phases)], anc)
            out[name] = (ovs, oa, src, anc)
    return out


def build() -> dict:
    a: dict = {}
    sets = list(HERO_SETS.values())
    # echo step
    a["echo_anchor"] = [echo_anchor(k) for k in range(6)]
    a["echo_countdown"] = [echo_countdown(k) for k in range(4)]
    a["echo_place"] = [echo_place(k) for k in range(1, 6)]
    a["echo_vanish"] = [echo_vanish(k) for k in range(1, 6)]
    a["echo_arrive"] = [echo_arrive(k) for k in range(1, 6)]
    a["echo_trail_h"] = [trail_h(p) for p in range(1, 5)]
    a["echo_trail_d"] = [trail_d(p) for p in range(1, 5)]
    a["echo_trail_v"] = [trail_v(p) for p in range(1, 5)]
    a["echo_trail_head"] = [trail_head(p) for p in range(1, 5)]
    a["echo_bubble"] = [echo_bubble(k) for k in range(4)]
    a["echo_shield"] = overlay_group(sets, echo_shield_overlay, 4)
    a["echo_dust"] = [echo_dust(k) for k in range(1, 6)]
    # stone ward
    a["ward_slab_raise"] = [ward_raise_slab(k) for k in range(1, 5)]
    a["ward_slab_hold"] = [ward_hold_slab(k) for k in range(4)]
    a["ward_slab_drop"] = [ward_drop_slab(k) for k in range(1, 4)]
    a["ward_hero"], a["ward_hero_anchor"] = {}, {}
    for vid in sets:
        idle = [load_sprite(f"{vid}_idle_right_{n}") for n in range(1, 5)]
        # one canvas per weapon set that holds every idle frame and the slab (the scythe frames are 40x48)
        ax = max(HA[0], max(anc[0] for _, anc in idle))
        ay = max(HA[1], max(anc[1] for _, anc in idle))
        w = max(ax + SLAB_DX + SLAB_W + 2, max(ax + len(s[0]) - anc[0] for s, anc in idle))
        h = max(ay + HC[1] - HA[1], max(ay + len(s) - anc[1] for s, anc in idle))
        w, h = -(-w // 8) * 8, -(-h // 8) * 8
        a["ward_hero_anchor"][vid] = (ax, ay)
        for phase, slabs in (("raise", a["ward_slab_raise"]), ("hold", a["ward_slab_hold"]), ("drop", a["ward_slab_drop"])):
            frames = []
            for i, sl in enumerate(slabs):
                src, anc = idle[i % 4]
                g = blank(w, h)
                paste(g, src, ax - anc[0], ay - anc[1])
                paste(g, sl, ax - HA[0], ay - HA[1])
                frames.append(g)
            a["ward_hero"][(vid, phase)] = frames
    a["ward_barrier"] = [barrier(k) for k in range(6)]
    a["ward_absorb"] = [ward_absorb(k) for k in range(4)]
    a["ward_store"] = {lv: [ward_store(lv, k) for k in range(4)] for lv in (1, 2, 3)}
    a["ward_block"] = [ward_block(k) for k in range(1, 6)]
    a["ward_shockwave"] = [ward_shockwave(k) for k in range(1, 9)]
    a["ward_cracks"] = [ward_cracks(k) for k in range(1, 5)]
    # sprint
    a["sprint_start"] = [sprint_start(k) for k in range(1, 6)]
    a["sprint_lines"] = [sprint_lines(k) for k in range(4)]
    a["sprint_wind"] = [sprint_wind(k) for k in range(4)]
    a["sprint_dust"] = [sprint_dust(k) for k in range(6)]
    a["sprint_aura"] = overlay_group(sets, sprint_aura, 6)
    a["sprint_after"] = overlay_group(sets, lambda s, k: sprint_after(s, k + 1), 3)
    a["sprint_end"] = [sprint_end(k) for k in range(1, 5)]
    # icons
    a["icons"] = {"echo_step": [echo_icon(k) for k in range(5)], "stone_ward": [ward_icon(k) for k in range(5)],
                  "sprint": [sprint_icon(k) for k in range(5)]}
    return a


def S(name: str, g: Grid, anchor: tuple[int, int], **extra) -> tuple[str, Grid, tuple[int, int], dict]:
    return (name, g, anchor, extra)


ECHO_MS = {"anchor": 100, "countdown": 80, "place": (50, 60, 60, 70, 80), "vanish": (45, 55, 60, 70, 80),
           "arrive": (45, 50, 60, 70, 80), "trail": (40, 50, 60, 70), "bubble": 70, "shield": 70, "dust": 60}


def echo_sprites(a: dict) -> list:
    out = []
    out += [S(f"fx_echo_anchor_{k + 1}", g, EA, ms=ECHO_MS["anchor"]) for k, g in enumerate(a["echo_anchor"])]
    out += [S(f"fx_echo_countdown_{k + 1}", g, EA, ms=ECHO_MS["countdown"]) for k, g in enumerate(a["echo_countdown"])]
    out += [S(f"fx_echo_place_{k + 1}", g, EA, ms=ECHO_MS["place"][k]) for k, g in enumerate(a["echo_place"])]
    out += [S(f"fx_echo_vanish_{k + 1}", g, EA, ms=ECHO_MS["vanish"][k]) for k, g in enumerate(a["echo_vanish"])]
    out += [S(f"fx_echo_trail_h_{k + 1}", g, (0, 4), ms=ECHO_MS["trail"][k], tile="repeat every 16 px along +x") for k, g in enumerate(a["echo_trail_h"])]
    out += [S(f"fx_echo_trail_d_{k + 1}", g, (0, 0), ms=ECHO_MS["trail"][k], tile="repeat every (16,16) down-right") for k, g in enumerate(a["echo_trail_d"])]
    out += [S(f"fx_echo_trail_v_{k + 1}", g, (4, 0), ms=ECHO_MS["trail"][k], tile="repeat every 16 px along +y") for k, g in enumerate(a["echo_trail_v"])]
    out += [S(f"fx_echo_trail_head_{k + 1}", g, (8, 8), ms=ECHO_MS["trail"][k]) for k, g in enumerate(a["echo_trail_head"])]
    out += [S(f"fx_echo_arrive_{k + 1}", g, EA, ms=ECHO_MS["arrive"][k]) for k, g in enumerate(a["echo_arrive"])]
    out += [S(f"fx_echo_bubble_{k + 1}", g, (20, 44), ms=ECHO_MS["bubble"]) for k, g in enumerate(a["echo_bubble"])]
    for frame, (ovs, oa, _s, _a) in a["echo_shield"].items():
        out += [S(f"fx_echo_shield_{frame}_{p + 1}", g, oa, hero_frame=frame, phase=p + 1, ms=ECHO_MS["shield"]) for p, g in enumerate(ovs)]
    out += [S(f"fx_echo_dust_{k + 1}", g, (16, 12), ms=ECHO_MS["dust"]) for k, g in enumerate(a["echo_dust"])]
    return out


WARD_MS = {"raise": (50, 60, 60, 80), "hold": (100,) * 4, "drop": (60, 70, 90), "barrier": 90, "absorb": (40, 50, 60, 70),
           "store": 90, "block": (35, 45, 55, 60, 70), "shockwave": (40, 45, 50, 55, 60, 60, 70, 90), "cracks": (120, 160, 260, 300)}


def ward_sprites(a: dict) -> list:
    out = []
    for vid in HERO_SETS.values():
        for phase in ("raise", "hold", "drop"):
            out += [S(f"{vid}_ward_{phase}_right_{k + 1}", g, a["ward_hero_anchor"][vid], ms=WARD_MS[phase][k])
                    for k, g in enumerate(a["ward_hero"][(vid, phase)])]
    for phase in ("raise", "hold", "drop"):
        out += [S(f"fx_ward_slab_{phase}_{k + 1}", g, HA, ms=WARD_MS[phase][k]) for k, g in enumerate(a[f"ward_slab_{phase}"])]
    out += [S(f"fx_ward_barrier_{k + 1}", g, BA, ms=WARD_MS["barrier"]) for k, g in enumerate(a["ward_barrier"])]
    out += [S(f"fx_ward_absorb_{k + 1}", g, BA, ms=WARD_MS["absorb"][k]) for k, g in enumerate(a["ward_absorb"])]
    for lv in (1, 2, 3):
        out += [S(f"fx_ward_store_{lv}_{k + 1}", g, BA, level=lv, ms=WARD_MS["store"]) for k, g in enumerate(a["ward_store"][lv])]
    out += [S(f"fx_ward_block_{k + 1}", g, (16, 16), ms=WARD_MS["block"][k]) for k, g in enumerate(a["ward_block"])]
    out += [S(f"fx_ward_shockwave_{k + 1}", g, SWA, radius_px=SW_R[k], ms=WARD_MS["shockwave"][k]) for k, g in enumerate(a["ward_shockwave"])]
    out += [S(f"fx_ward_cracks_{k + 1}", g, CRA, ms=WARD_MS["cracks"][k]) for k, g in enumerate(a["ward_cracks"])]
    return out


SPRINT_MS = {"start": (40, 50, 60, 70, 80), "lines": 60, "wind": 70, "dust": 60, "aura": 80, "end": (70, 80, 90, 100)}


def sprint_sprites(a: dict) -> list:
    out = []
    out += [S(f"fx_sprint_start_{k + 1}", g, (24, 35), ms=SPRINT_MS["start"][k]) for k, g in enumerate(a["sprint_start"])]
    out += [S(f"fx_sprint_lines_{k + 1}", g, SPA, ms=SPRINT_MS["lines"]) for k, g in enumerate(a["sprint_lines"])]
    out += [S(f"fx_sprint_wind_{k + 1}", g, WA, ms=SPRINT_MS["wind"]) for k, g in enumerate(a["sprint_wind"])]
    out += [S(f"fx_sprint_dust_{k + 1}", g, DA, ms=SPRINT_MS["dust"]) for k, g in enumerate(a["sprint_dust"])]
    for frame, (ovs, oa, _s, _a) in a["sprint_aura"].items():
        out += [S(f"fx_sprint_aura_{frame}_{p + 1}", g, oa, hero_frame=frame, phase=p + 1, ms=SPRINT_MS["aura"]) for p, g in enumerate(ovs)]
    for frame, (ovs, oa, _s, _a) in a["sprint_after"].items():
        out += [S(f"fx_sprint_after_{frame}_{p + 1}", g, oa, hero_frame=frame, ghost=p + 1, behind_px=AFTER_STEP * (p + 1)) for p, g in enumerate(ovs)]
    out += [S(f"fx_sprint_end_{k + 1}", g, (24, 35), ms=SPRINT_MS["end"][k]) for k, g in enumerate(a["sprint_end"])]
    return out


def icon_sprites(a: dict) -> list:
    out = []
    for key in ("echo_step", "stone_ward", "sprint"):
        ims = a["icons"][key]
        out.append(S(f"ui_aspect_{key}_1", ims[0], (12, 12), use="Aspect slot / HUD skill icon"))
        out += [S(f"ui_aspect_{key}_lit_{k}", ims[k], (12, 12), use="optional: HUD icon while the aspect is active (loop about 120 ms)") for k in range(1, 5)]
    return out


def rows_by_group(sprites: list) -> list[list]:
    rows: dict[str, list] = {}
    for e in sprites:
        rows.setdefault(e[0].rsplit("_", 1)[0], []).append(e)
    return list(rows.values())


def group_table(sprites: list) -> dict:
    """group -> frame count, size(s), anchor(s), ms per frame (the same shape as the lantern/phantom manifest)."""
    t: dict[str, dict] = {}
    for name, g, anchor, extra in sprites:
        grp = name.rsplit("_", 1)[0]
        e = t.setdefault(grp, {"frames": 0, "sizes": [], "anchors": [], "ms": []})
        e["frames"] += 1
        sz, an = [len(g[0]), len(g)], list(anchor)
        if sz not in e["sizes"]:
            e["sizes"].append(sz)
        if an not in e["anchors"]:
            e["anchors"].append(an)
        if "ms" in extra:
            e["ms"].append(extra["ms"])
    for e in t.values():
        if len(e["sizes"]) == 1:
            e["size"] = e.pop("sizes")[0]
        if len(e["anchors"]) == 1:
            e["anchor"] = e.pop("anchors")[0]
        if not e["ms"]:
            e.pop("ms")
    return t


def check_sprites(sprites: list) -> None:
    for name, g, anchor, _ in sprites:
        w, h = len(g[0]), len(g)
        if w % 8 or h % 8 or w > 256 or h > 256:
            raise SystemExit(f"{name}: size {w}x{h} is not a multiple of 8 (max 256)")
        if any(len(r) != w for r in g):
            raise SystemExit(f"{name}: ragged rows")
        bad = {c for r in g for c in r if c != T and (c in FORBIDDEN or c not in PAL.by_symbol)}
        if bad:
            raise SystemExit(f"{name}: forbidden or unknown symbols {sorted(bad)}")
        if not any(c != T for r in g for c in r):
            raise SystemExit(f"{name}: empty")


COMMON = {
    "generator": GENERATOR,
    "palette": "Totoy 36, hard alpha; no reserved gold x,y or red z,A",
    "scale": "1x game pixels (nearest-neighbour; preview sheets are scaled copies)",
    "status": "Reference art for the human's approval; NOT imported into art/src, not in art/build, not wired into the game",
    "frame_naming": "<group>_<n>, n from 1; mirror around the anchor for a left-facing hero, as with the hero frames",
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    a = build()
    written: list[Path] = []
    sheets = [
        ("echo_step_v1", echo_sprites(a), 768, {
            "aspect": "Echo Step (suggested display name: ECHO STEP; subtitle idea: 'A STEP LEFT BEHIND')",
            "request": "Totoy leaves a glowing afterimage (the echo) where he stands, then moves and acts freely; after about 2 s he is pulled back to the echo, teleporting to it, with a brief invulnerable moment on arrival. Duration, cooldown and i-frames are owner/core decisions.",
            "groups": {
                "fx_echo_place_<1..5>": "48x48, anchor (24,42) = Totoy's feet where he places the echo. Over the hero: 1 flash + column, 2 the ring opens and the echo forms, 3 overshoot with bright runes, 4 settle, 5 calm. Then loop fx_echo_anchor.",
                "fx_echo_anchor_<1..6>": "48x48, anchor (24,42) = the echo's feet (fixed world point). The echo: a dithered lilac/teal ghost of Totoy's idle pose on a teal rune ring (the ring's back half is drawn behind the ghost, its front half in front), a scanline crawls down it, motes rise. Loop about 100 ms. Sort with characters by its ground y.",
                "fx_echo_countdown_<1..4>": "48x48, anchor (24,42). Replaces the anchor loop for the last ~20 ticks before the recall (4 x 80 ms = 320 ms): the ring tightens and flickers bright, the echo flickers thin, ticks close in.",
                "fx_echo_vanish_<1..5>": "48x48, anchor (24,42) = where Totoy stood when the recall fires. The hero is NOT drawn here: 1 a column of light, 2 it pinches to a line, 3 it breaks upward, 4-5 motes.",
                "fx_echo_trail_h|d|v_<1..4>": "The recall streak, tiled from the departure point to the echo. h: 16x8, anchor (0,4) on the line, repeat every 16 px along +x. d: 16x16 45-degree (down-right), anchor (0,0), repeat every (16,16). v: 8x16, anchor (4,0), repeat every 16 px along +y. For other angles rotate the h tile around its anchor (nearest filtering) or mirror h/d/v. Phases 1-4 are the streak's life (flash, flow, break, motes), not a loop; draw at chest height (feet - 14).",
                "fx_echo_trail_head_<1..4>": "16x16, anchor (8,8). The comet head at the echo end of the streak (chest height), same phases as the trail.",
                "fx_echo_arrive_<1..5>": "48x48, anchor (24,42) = the echo's feet. 1 the echo flares white and streaks pull in (the echo itself stops here), 2 flash + ring (Totoy is drawn at the echo from this frame), 3 the ring opens, 4 broken ring, 5 motes.",
                "fx_echo_bubble_<1..4>": "40x48, anchor (20,44) = Totoy's feet. Generic invulnerability shield over ANY hero frame: dithered bubble rim with a glint sweeping round it, 4 fading. Start with fx_echo_arrive_2; loop 1-3 while the i-frames last, end on 4.",
                "fx_echo_shield_<hero frame>_<1..4>": "Alternative to the bubble: a water-white outline hugging the exact hero frame with a glint running down it, cropped (anchor = the hero frame's feet in the crop). See the naming rule in the README. Covered: idle 1-4, walk 1-6, dash 1-4 of hero2, totoy_dagger and totoy_scythe.",
                "fx_echo_dust_<1..5>": "32x16, anchor (16,12) = feet. Pale dust kicked out at placement, departure and arrival.",
            },
            "suggested_timeline": "cast: fx_echo_place 1-5 over Totoy (+ fx_echo_dust), then fx_echo_anchor loop at that point. ~2 s later minus 320 ms: fx_echo_countdown 1-4. Recall: fx_echo_vanish 1-5 at Totoy's position (hero hidden), trail h/d/v + head 1-4 from there to the echo, fx_echo_arrive 1-5 at the echo (anchor stops at arrive 1; hero drawn at the echo from arrive 2), fx_echo_bubble (or shield) 1-3 looping during i-frames, then 4, fx_echo_dust at arrive 2.",
        }),
        ("stone_ward_v1", ward_sprites(a), 768, {
            "aspect": "Stone Ward (suggested display name: STONE WARD; subtitle idea: 'WHAT STRIKES, RETURNS')",
            "request": "Totoy raises a stone ward for about 1 s; hits taken while it is up are blocked and stored, then released as a shockwave when the ward drops. Duration, stored-damage math and shockwave radius are owner/core decisions; the art ring reaches 64 px.",
            "groups": {
                "<set>_ward_raise|hold|drop_right_<n>": "hero2 / totoy_dagger 40x40, anchor (12,35); totoy_scythe 48x48, anchor (19,43) (= feet). Full hero frames (hero naming convention) for hero2, totoy_dagger, totoy_scythe: the idle frames 1-4 with the stone slab in front. raise 4 (ground splits, half up, full + overshoot, settle and the rune lights), hold 4 (loop about 100 ms, a glint runs down the rune), drop 3 (cracks glow, the slab splits and falls, rubble).",
                "fx_ward_slab_raise|hold|drop_<n>": "40x40, anchor (12,35). The same slab as an overlay only (draw OVER any hero frame at the feet), for weapon sets or poses without composed frames.",
                "fx_ward_barrier_<1..6>": "48x48, anchor (16,44) = Totoy's feet. The rune ward: a dithered stone-grey crescent dome in front of him with teal rune glints; loop about 90 ms from raise 3 to drop 1. Draw over the hero and slab.",
                "fx_ward_absorb_<1..4>": "48x48, anchor (16,44). Replaces the barrier for 4 frames when a hit is absorbed: bright flash, ripple from the front, back to normal.",
                "fx_ward_store_<level>_<1..4>": "48x48, anchor (16,44). Stored-energy glow drawn OVER the barrier, level 1 (1 hit), 2 (2 hits), 3 (3+ hits or max), loop about 90 ms each.",
                "fx_ward_block_<1..5>": "32x32, anchor (16,16) = the hit point on the ward front (about feet + (22,-16)). Stone chips and teal/cream sparks; the chips fly back toward the attacker (+x).",
                "fx_ward_shockwave_<1..8>": "144x80, anchor (72,50) = Totoy's feet. Release: ring radius 6, 18, 30, 41, 50, 57, 62, 64 px (floor squash ry = 0.45 rx) with stone shards thrown up and dust at the rim. Start with drop 1.",
                "fx_ward_cracks_<1..4>": "96x48, anchor (48,24) = Totoy's feet. Floor decal, draw UNDER characters, with shockwave 1: cracks glow, cool, dark with glints, fade.",
            },
            "suggested_timeline": "cast: <set>_ward_raise 1-4 (barrier from raise 3), hold loop for ~1 s. Each absorbed hit: fx_ward_block 1-5 at the hit point + fx_ward_absorb 1-4 instead of the barrier, then fx_ward_store_<hits> over the barrier. Drop: <set>_ward_drop 1-3, barrier and store off, fx_ward_shockwave 1-8 + fx_ward_cracks 1-4 at the feet.",
        }),
        ("sprint_v1", sprint_sprites(a), 1024, {
            "aspect": "Sprint (suggested display name: SPRINT; subtitle idea: 'WIND AT THE HEELS')",
            "request": "Totoy's movement speed is doubled for 3 s. Speed and duration are owner/core decisions.",
            "groups": {
                "fx_sprint_start_<1..5>": "48x40, anchor (24,35) = feet. Start burst: ground flash, ring and a big dust kick back, lines, motes.",
                "fx_sprint_lines_<1..4>": "48x40, anchor (36,35) = feet (the lines trail to the left = behind a right-facing hero). Loop about 60 ms while sprinting and moving.",
                "fx_sprint_wind_<1..4>": "40x40, anchor (14,35) = feet. Wind streaks wrapping the front of the body and peeling back; loop about 70 ms. Draw over the hero.",
                "fx_sprint_dust_<1..6>": "40x16, anchor (28,12) = feet. Dust puffs from alternating feet, drifting back; loop about 60 ms while moving.",
                "fx_sprint_aura_<hero frame>_<1..6>": "Faint pale-cyan outline overlay for the exact hero frame (same naming rule as fx_phantom_glow), cropped, anchor = the hero frame's feet in the crop. 6 phases about 80 ms, independent of the hero frame. Covered: idle 1-4, walk 1-6, dash 1-4 of hero2, totoy_dagger, totoy_scythe.",
                "fx_sprint_after_<hero frame>_<1..3>": "Afterimages: the hero frame as a cyan ghost, 1 nearest/brightest to 3 faintest. Draw BEHIND the hero, at where he was 1, 2, 3 x ~150 ms ago, or at behind_px along the reverse facing; mirrored with him.",
                "fx_sprint_end_<1..4>": "48x40, anchor (24,35) = feet. The aura tears off in pale shreds, a last puff, a closing ring.",
            },
            "suggested_timeline": "cast: fx_sprint_start 1-5 at the feet. For 3 s: aura on every frame, lines + dust while moving, wind loop, 3 afterimages while moving. End: aura off, fx_sprint_end 1-4.",
            "afterimage_step_px": AFTER_STEP,
        }),
        ("aspect_icons_v1", icon_sprites(a), 24 * 5, {
            "style": "Ring copied from the existing ui_aspect_gale_cut_1 (24px), like every other Aspect icon; new interior drawn here. 24px only (no 48px versions exist for Aspects). _lit_1..4 are optional loops for the HUD while the aspect is active.",
        }),
    ]
    for stem, sprites, width, meta in sheets:
        check_sprites(sprites)
        sheet, frames = pack(rows_by_group(sprites), width)
        sheet.save(OUT / f"{stem}.png")
        check_hard(OUT / f"{stem}.png")
        write_json(OUT / f"{stem}.json", {**COMMON, **meta, "group_table": group_table(sprites), "sprite_count": len(sprites), "frames": frames})
        written += [OUT / f"{stem}.png", OUT / f"{stem}.json"]
        print(f"{stem}: {len(sprites)} sprites, sheet {sheet.width}x{sheet.height}")
    make_previews(a)
    make_echo_gif(a)
    make_ward_gif(a)
    make_sprint_gif(a)
    for p in OUT.glob("*.png"):
        check_hard(p) if p.stem.endswith("_v1") else None
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*") if p.suffix in (".png", ".json", ".gif"))))
    return 0


# ================================================================================================ previews
im = to_image


def over(src: Grid, sa: tuple[int, int], ov: Grid, oa: tuple[int, int], w: int | None = None, h: int | None = None,
         fa: tuple[int, int] | None = None) -> Grid:
    """Compose a hero frame and an overlay by anchors on a (w,h) canvas with the feet at fa."""
    w = w or len(src[0])
    h = h or len(src)
    fa = fa or sa
    g = blank(w, h)
    paste(g, src, fa[0] - sa[0], fa[1] - sa[1])
    paste(g, ov, fa[0] - oa[0], fa[1] - oa[1])
    return g


def make_previews(a: dict) -> None:
    idle, ia = load_sprite("hero2_idle_right_1")
    groups = []
    # ---- echo
    groups.append(("ECHO STEP  anchor loop 1-6 | countdown 1-4 (last ~20 ticks)", [im(g) for g in a["echo_anchor"] + a["echo_countdown"]]))
    place_comp = [im(over(idle, ia, g, EA, EC, EC, EA)) for g in a["echo_place"]]
    groups.append(("placement burst 1-5 (raw) | over Totoy", [im(g) for g in a["echo_place"]] + place_comp))
    groups.append(("vanish 1-5 at the departure point (hero hidden) | arrive 1-5 at the echo", [im(g) for g in a["echo_vanish"] + a["echo_arrive"]]))
    arr = []
    for k, g in enumerate(a["echo_arrive"]):
        c = blank(EC, EC)
        if k >= 1:
            paste(c, idle, EA[0] - ia[0], EA[1] - ia[1])
            paste(c, a["echo_bubble"][min(3, k - 1)], EA[0] - 20, EA[1] - 44)
        paste(c, g, 0, 0)
        arr.append(im(c))
    groups.append(("arrival composed: arrive 1-5, Totoy from 2 with the bubble shield 1-4", arr))
    groups.append(("shield: bubble 1-4 (generic) over idle | outline 1-4 over idle 1 | outline 1-4 over dash 2",
                   [im(over(idle, ia, g, (20, 44), 40, 48, (20, 44))) for g in a["echo_bubble"]]
                   + [im(over(idle, ia, ov, a["echo_shield"]["hero2_idle_right_1"][1])) for ov in a["echo_shield"]["hero2_idle_right_1"][0]]
                   + [im(over(*load_sprite("hero2_dash_right_2"), ov, a["echo_shield"]["hero2_dash_right_2"][1])) for ov in a["echo_shield"]["hero2_dash_right_2"][0]]))
    tiles = []
    for p in range(4):  # trails tiled: 4 x h, 2 x d, 2 x v + head
        g = blank(64, 40)
        for i in range(4):
            paste(g, a["echo_trail_h"][p], i * 16, 2)
        paste(g, a["echo_trail_head"][p], 56, -2 + 0)
        for i in range(2):
            paste(g, a["echo_trail_d"][p], 4 + i * 16, 12 + i * 16 - 4)
        for i in range(2):
            paste(g, a["echo_trail_v"][p], 50, 14 + i * 16 - 4)
        tiles.append(im(g))
    groups.append(("recall trail phases 1-4 (flash, flow, break, motes): h x4 + head, d x2, v x2 (tiled)", tiles))
    groups.append(("dust 1-5", [im(g) for g in a["echo_dust"]]))
    # ---- ward
    for vid in ("hero2",):
        frames = a["ward_hero"][(vid, "raise")] + a["ward_hero"][(vid, "hold")] + a["ward_hero"][(vid, "drop")]
        groups.append((f"STONE WARD  {vid}_ward: raise 1-4 | hold 1-4 | drop 1-3", [im(g) for g in frames]))
    groups.append(("dagger / scythe sets: raise 4, hold 1, drop 1",
                   [im(a["ward_hero"][(v, ph)][i]) for v in ("totoy_dagger", "totoy_scythe") for ph, i in (("raise", 3), ("hold", 0), ("drop", 0))]))

    def hold_with(k: int, ov: list[Grid]) -> Image.Image:
        c = blank(BC, BC)
        hf = a["ward_hero"][("hero2", "hold")][k % 4]
        paste(c, hf, BA[0] - HA[0], BA[1] - HA[1])
        for o in ov:
            paste(c, o, 0, 0)
        return im(c)
    groups.append(("barrier 1-6 (raw) | over the hold pose", [im(g) for g in a["ward_barrier"]] + [hold_with(k, [g]) for k, g in enumerate(a["ward_barrier"])]))
    groups.append(("absorb 1-4 over hold | block sparks 1-5 (raw)", [hold_with(k, [g]) for k, g in enumerate(a["ward_absorb"])] + [im(g) for g in a["ward_block"]]))
    groups.append(("stored energy level 1, 2, 3 (frames 1-4 each) over barrier + hold",
                   [hold_with(k, [a["ward_barrier"][k], a["ward_store"][lv][k]]) for lv in (1, 2, 3) for k in range(4)]))
    groups.append(("release shockwave 1-8 (radius 6..64 px, ry = 0.45 rx)", [im(g) for g in a["ward_shockwave"]]))
    groups.append(("ground cracks decal 1-4", [im(g) for g in a["ward_cracks"]]))
    sw_comp = []
    for k in range(8):
        c = blank(*SWC)
        paste(c, a["ward_cracks"][min(3, k // 2)], SWA[0] - CRA[0], SWA[1] - CRA[1])
        hf = a["ward_hero"][("hero2", "drop")][min(2, k)]
        paste(c, hf, SWA[0] - HA[0], SWA[1] - HA[1])
        paste(c, a["ward_shockwave"][k], 0, 0)
        sw_comp.append(im(c))
    groups.append(("drop + shockwave + cracks composed", sw_comp))
    # ---- sprint
    groups.append(("SPRINT  start 1-5 | lines 1-4 | wind 1-4 | dust 1-6 | end 1-4",
                   [im(g) for g in a["sprint_start"] + a["sprint_lines"] + a["sprint_wind"] + a["sprint_dust"] + a["sprint_end"]]))
    run = []
    for k in range(6):
        name = f"hero2_walk_right_{k + 1}"
        src, sa = load_sprite(name)
        c = blank(64, 48)
        f = (44, 42)
        for gi in (3, 2, 1):
            ov, oa = a["sprint_after"][name][0][gi - 1], a["sprint_after"][name][1]
            paste(c, ov, f[0] - AFTER_STEP * gi - oa[0], f[1] - oa[1])
        paste(c, a["sprint_lines"][k % 4], f[0] - SPA[0], f[1] - SPA[1])
        paste(c, a["sprint_dust"][k], f[0] - DA[0], f[1] - DA[1])
        paste(c, src, f[0] - sa[0], f[1] - sa[1])
        ovs, oa, _, _ = a["sprint_aura"][name]
        paste(c, ovs[k], f[0] - oa[0], f[1] - oa[1])
        paste(c, a["sprint_wind"][k % 4], f[0] - WA[0], f[1] - WA[1])
        run.append(im(c))
    groups.append(("sprinting composed: walk 1-6 + aura + afterimages 1-3 + lines + dust + wind", run))
    for vid in HERO_SETS.values():
        cells = []
        for i, name in enumerate(move_frames(vid)):
            ovs, oa, src, sa = a["sprint_aura"][name]
            cells.append(im(over(src, sa, ovs[i % 6], oa)))
        groups.append((f"{vid}: aura over idle 1-4, walk 1-6, dash 1-4 (phase cycling)", cells))
    groups.append(("afterimages 1-3 of walk 2 and dash 2 (raw)",
                   [im(g) for n in ("hero2_walk_right_2", "hero2_dash_right_2") for g in a["sprint_after"][n][0]]))
    st = []
    for k, g in enumerate(a["sprint_start"] + a["sprint_end"]):
        c = over(idle, ia, g, (24, 35), 48, 40, (24, 35))
        if 0 < k < 9:
            ovs, oa, _, _ = a["sprint_aura"]["hero2_idle_right_1"]
            paste(c, ovs[k % 6], 24 - oa[0], 35 - oa[1])
        st.append(im(c))
    groups.append(("over Totoy: start 1-5 (aura on from 2) | end 1-4", st))
    # ---- icons
    ic = a["icons"]
    groups.append(("ICONS 24px: echo step, stone ward, sprint | next to gale cut, phantom cut, spirit lantern",
                   [im(ic[k][0]) for k in ("echo_step", "stone_ward", "sprint")]
                   + [LP.raw_image(load_sprite(f"ui_aspect_{nm}_1")[0]) for nm in ("gale_cut", "phantom_cut", "spirit_lantern")]))
    groups.append(("lit variants 1-4: echo step | stone ward | sprint", [im(ic[k][i]) for k in ("echo_step", "stone_ward", "sprint") for i in range(1, 5)]))
    for tag, bg in (("dark", BG_DARK), ("grass", BG_GRASS)):
        M.labelled_sheet(groups, bg, 4, 10).convert("RGB").save(OUT / f"preview_contact_{tag}.png")


# ================================================================================================ GIFs
GIF_STEP = 50
FEET_Y = 92


def save_gif(frames: list[tuple[Image.Image, int]], name: str, strip_name: str) -> None:
    Z = 4
    big = [f.convert("RGB").resize((SW_ * Z, SH_ * Z), Image.NEAREST) for f, _ in frames]
    big[0].save(OUT / name, save_all=True, append_images=big[1:], duration=[ms for _, ms in frames], loop=0, disposal=1)
    cols, Zs = 8, 2
    strip = Image.new("RGB", (cols * SW_ * Zs, ((len(frames) + cols - 1) // cols) * SH_ * Zs), BG_DARK)
    for i, (f, _) in enumerate(frames):
        strip.paste(f.convert("RGB").resize((SW_ * Zs, SH_ * Zs), Image.NEAREST), ((i % cols) * SW_ * Zs, (i // cols) * SH_ * Zs))
    strip.save(OUT / strip_name)


def place(layers: list, g: Grid, anchor: tuple[int, int], at: tuple[int, int], flip: bool = False) -> None:
    if flip:
        g, anchor = mirror(g), (len(g[0]) - 1 - anchor[0], anchor[1])
    layers.append((g, at[0] - anchor[0], at[1] - anchor[1]))


def render(scene: Image.Image, under: list, layers: list) -> Image.Image:
    out = scene.copy()
    sg = blank(SW_, SH_)
    for g, x, y in under + layers:
        paste(sg, g, x, y)
    out.alpha_composite(to_image(sg))
    return out


def timer_bar(left: float, col: str) -> Grid:
    g = blank(52, 6)
    for x in range(50):
        for y in range(3):
            put(g, 1 + x, 1 + y, col if x < left * 50 else "e")
    outline_layer(g, "0")
    return g


def make_echo_gif(a: dict) -> None:
    """Place the echo, walk to the golem and cut it, the countdown, the recall (vanish, trail, arrival with the
    shield bubble), idle. A mock echo timer runs top-left."""
    scene = LP.arena_scene()
    golem_i, ga = load_sprite("golem2_idle_1")
    golem_h, gha = load_sprite("golem2_hurt_1")
    echo_at = (44, FEET_Y)
    stop_x = 118
    gx = stop_x + 22 + LP.GOLEM_LEFT
    t_place, life = 400, 2000
    t_recall = t_place + life
    t_walk0 = t_place + 300
    speed = 0.06  # px per ms (illustrative)
    t_walk1 = t_walk0 + int((stop_x - echo_at[0]) / speed)
    t_atk = t_walk1 + 50
    t_hit = t_atk + 3 * 55
    total = t_recall + 1000
    out = []
    for t in range(0, total, GIF_STEP):
        under, L = [], []
        hurt = 0 <= t - t_hit < 200
        g, gan = (golem_h, gha) if hurt else (golem_i, ga)
        place(L, LP.golem_flash(g) if 0 <= t - t_hit < GIF_STEP else g, gan, (gx + (2 if 0 <= t - t_hit < GIF_STEP else 0), FEET_Y))
        # hero position / frame
        if t < t_walk0:
            hx, name = echo_at[0], f"hero2_idle_right_{(t // 200) % 4 + 1}"
        elif t < t_walk1:
            hx, name = echo_at[0] + int((t - t_walk0) * speed), f"hero2_walk_right_{((t - t_walk0) // 100) % 6 + 1}"
        elif t < t_recall:
            hx = stop_x
            name = f"hero2_attack1_right_{(t - t_atk) // 55 + 1}" if t_atk <= t < t_atk + 6 * 55 else f"hero2_idle_right_{(t // 200) % 4 + 1}"
        else:
            hx, name = echo_at[0], f"hero2_idle_right_{(t // 200) % 4 + 1}"
        src, sa = load_sprite(name)
        k_arr = (t - t_recall) // 60
        hero_visible = t < t_recall or k_arr >= 1
        # echo marker (sorted before the hero: it stands further back)
        if t_place + 5 * 60 <= t < t_recall:
            if t >= t_recall - 4 * 80:
                place(L, a["echo_countdown"][min(3, (t - (t_recall - 320)) // 80)], EA, echo_at)
            else:
                place(L, a["echo_anchor"][(t // 100) % 6], EA, echo_at)
        if hero_visible:
            place(L, src, sa, (hx, FEET_Y))
        if t_place <= t < t_place + 5 * 60:
            place(L, a["echo_place"][(t - t_place) // 60], EA, echo_at)
            place(L, a["echo_dust"][min(4, (t - t_place) // 60)], (16, 12), echo_at)
        if 0 <= t - t_hit < 2 * GIF_STEP:
            sg = blank(16, 16)
            star(sg, 8, 8, 2, "1", "p", "o")
            place(L, sg, (8, 8), (gx - LP.GOLEM_LEFT + 7, FEET_Y - 24))
        if t >= t_recall:
            kv = (t - t_recall) // 60
            if kv < 5:
                place(L, a["echo_vanish"][kv], EA, (stop_x, FEET_Y))
            kt = (t - t_recall) // 50
            if kt < 4:  # trail from the departure point back to the echo, head at the echo
                y = FEET_Y - 14
                x0, x1 = echo_at[0], stop_x
                tile = a["echo_trail_h"][kt]
                for x in range(x0, x1, 16):
                    seg = [row[:min(16, x1 - x)] for row in tile]
                    L.append((seg, x, y - 4))
                place(L, a["echo_trail_head"][kt], (8, 8), (echo_at[0] + 1, y))
            if k_arr < 5:
                place(L, a["echo_arrive"][k_arr], EA, echo_at)
            if 1 <= k_arr and (t - t_recall - 60) // 70 < 6:
                kb = (t - t_recall - 60) // 70
                place(L, a["echo_bubble"][min(3, kb if kb < 3 else (3 if kb >= 5 else kb % 3))], (20, 44), echo_at)
            if 1 <= k_arr < 6:
                place(L, a["echo_dust"][k_arr - 1], (16, 12), echo_at)
        left = 0.0 if t < t_place else max(0.0, 1 - (t - t_place) / life)
        L.append((timer_bar(left, "v"), 4, 4))
        out.append((render(scene, under, L), GIF_STEP))
    save_gif(out, "echo_step_sequence.gif", "echo_step_sequence_strip.png")


def make_ward_gif(a: dict) -> None:
    """Raise the ward, the golem sweeps twice (blocked: sparks, absorb flash, stored glow 1 then 2), the ward drops and
    the shockwave runs out and hits the golem. A mock ward timer runs top-left."""
    scene = LP.arena_scene()
    golem_i, ga = load_sprite("golem2_idle_1")
    golem_h, gha = load_sprite("golem2_hurt_1")
    sweep = [load_sprite(f"golem2_sweep_{n}") for n in range(1, 7)]
    hf = (72, FEET_Y)
    gx = 134
    t_raise = 400
    t_hold = t_raise + 4 * 60
    t_drop = t_hold + 1100
    sweeps = [t_raise + 160, t_raise + 160 + 520]
    hit_off = 3 * 70  # sweep frame 4 lands
    hits = [s + hit_off for s in sweeps]
    t_ring_hit = t_drop + 4 * 55  # ring radius ~50 px reaches the golem front
    total = t_drop + 8 * 60 + 1100
    hit_pt = (hf[0] + 22, hf[1] - 16)
    out = []
    for t in range(0, total, GIF_STEP):
        under, L = [], []
        # golem
        g, gan = golem_i, ga
        for s in sweeps:
            if s <= t < s + 6 * 70:
                g, gan = sweep[(t - s) // 70]
        hurt = 0 <= t - t_ring_hit < 300
        if hurt:
            g, gan = golem_h, gha
        flash = 0 <= t - t_ring_hit < 2 * GIF_STEP
        place(L, LP.golem_flash(g) if flash else g, gan, (gx + (3 if hurt else 0), FEET_Y), flip=False)
        # hero / ward
        if t < t_raise:
            src, sa = load_sprite(f"hero2_idle_right_{(t // 200) % 4 + 1}")
        elif t < t_hold:
            src, sa = a["ward_hero"][("hero2", "raise")][(t - t_raise) // 60], HA
        elif t < t_drop:
            src, sa = a["ward_hero"][("hero2", "hold")][((t - t_hold) // 100) % 4], HA
        elif t < t_drop + 3 * 70:
            src, sa = a["ward_hero"][("hero2", "drop")][(t - t_drop) // 70], HA
        else:
            src, sa = load_sprite(f"hero2_idle_right_{(t // 200) % 4 + 1}")
        if t >= t_drop:
            kc = (t - t_drop) // 140
            if kc < 4:
                place(under, a["ward_cracks"][kc], CRA, hf)
        place(L, src, sa, hf)
        nhits = sum(1 for h in hits if t >= h)
        if t_raise + 2 * 60 <= t < t_drop:
            absorbing = [h for h in hits if 0 <= t - h < 4 * 50]
            if absorbing:
                place(L, a["ward_absorb"][(t - absorbing[-1]) // 50], BA, hf)
            else:
                place(L, a["ward_barrier"][(t // 90) % 6], BA, hf)
            if nhits:
                place(L, a["ward_store"][min(3, nhits)][(t // 90) % 4], BA, hf)
        for h in hits:
            kb = (t - h) // 50
            if 0 <= kb < 5:
                place(L, a["ward_block"][kb], (16, 16), hit_pt)
        if t >= t_drop:
            ks = (t - t_drop) // 55
            if ks < 8:
                place(L, a["ward_shockwave"][ks], SWA, hf)
        left = 0.0 if t < t_raise else max(0.0, 1 - (t - t_raise) / (t_drop - t_raise))
        L.append((timer_bar(left, "u"), 4, 4))
        for i in range(min(3, nhits) if t < t_drop + 100 else 0):  # stored-hit pips (viewing only)
            pip = blank(4, 4)
            for yy in range(1, 3):
                for xx in range(1, 3):
                    put(pip, xx, yy, "o")
            outline_layer(pip, "0")
            L.append((pip, 58 + i * 5, 5))
        out.append((render(scene, under, L), GIF_STEP))
    save_gif(out, "stone_ward_sequence.gif", "stone_ward_sequence_strip.png")


def make_sprint_gif(a: dict) -> None:
    """Walk, the sprint start burst, 3 s of sprint (double speed, turning at the arena edge: aura, afterimages, lines,
    dust, wind), the end fade, walk. A mock sprint timer runs top-left."""
    scene = LP.arena_scene()
    golem_i, ga = load_sprite("golem2_idle_1")
    t_start, dur = 600, 3000
    t_end = t_start + dur
    total = t_end + 1100
    walk_v, sprint_v = 0.04, 0.08  # px per ms (illustrative: 2x)
    x, flip = 30.0, False
    hist: list[tuple[str, float, bool]] = []
    out = []
    wf = 0.0  # walk phase (frames)
    for t in range(0, total, GIF_STEP):
        sprinting = t_start <= t < t_end
        v = sprint_v if sprinting else walk_v
        if t > 0:
            x += (-v if flip else v) * GIF_STEP
            wf += GIF_STEP / (60 if sprinting else 120)
        if x > 168 and not flip:
            flip = True
        if x < 24 and flip:
            flip = False
        name = f"hero2_walk_right_{int(wf) % 6 + 1}"
        src, sa = load_sprite(name)
        hx = rnd(x)
        under, L = [], []
        place(L, golem_i, ga, (158, 58))
        if sprinting or (t_end <= t < t_end + 100):
            for gi in (3, 2, 1):  # afterimages from the history (1 step = 50 ms back)
                if len(hist) >= gi * 3 and sprinting:
                    hn, hxp, hfl = hist[-gi * 3]
                    ovs, oa, _, _ = a["sprint_after"][hn]
                    place(L, ovs[gi - 1], oa, (rnd(hxp), FEET_Y), hfl)
        if sprinting:
            place(L, a["sprint_lines"][(t // 60) % 4], SPA, (hx, FEET_Y), flip)
            place(L, a["sprint_dust"][(t // 60) % 6], DA, (hx, FEET_Y), flip)
        place(L, src, sa, (hx, FEET_Y), flip)
        if sprinting and t >= t_start + 50:
            ovs, oa, _, _ = a["sprint_aura"][name]
            place(L, ovs[((t - t_start) // 80) % 6], oa, (hx, FEET_Y), flip)
            place(L, a["sprint_wind"][(t // 70) % 4], WA, (hx, FEET_Y), flip)
        if t_start <= t < t_start + 5 * 50:
            place(L, a["sprint_start"][(t - t_start) // 50], (24, 35), (hx, FEET_Y), flip)
        if t_end <= t < t_end + 4 * 80:
            place(L, a["sprint_end"][(t - t_end) // 80], (24, 35), (hx, FEET_Y), flip)
        left = 0.0 if t < t_start else max(0.0, 1 - (t - t_start) / dur)
        L.append((timer_bar(left, "o"), 4, 4))
        hist.append((name, x, flip))
        out.append((render(scene, under, L), GIF_STEP))
    save_gif(out, "sprint_sequence.gif", "sprint_sequence_strip.png")


if __name__ == "__main__":
    raise SystemExit(main())
