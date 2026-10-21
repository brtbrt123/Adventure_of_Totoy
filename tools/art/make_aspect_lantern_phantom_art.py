"""Generate the review art for two new Aspects: SPIRIT LANTERN and PHANTOM CUT
(art/reference/aspects_lantern_phantom/).

v2 (2026-10-21, the human's review changes): the light pool covers the gameplay radius of about 44 px (rx 44 / ry 20,
96x48 canvas); Phantom Cut is a 5 s buff in which every attack echoes, so the glow overlay is made for every animated
frame of all three weapons, plus a buff start burst and end fade, and ghosts/echo arcs for the dagger and scythe.
The v1 files are kept in art/reference/aspects_lantern_phantom/v1/. In-game import: tools/art/import_lantern_phantom_sprites.py
(uses build() and the *_sprites() tables below, so the review sheets and art/src always hold the same pixels).

Everything is drawn procedurally, pixel by pixel, in the Totoy 36 palette with hard alpha only. Gold (x, y) and
red (z, A) are reserved for combat cues and never used. Translucency is faked with checkerboard / ordered dither.

Colour language
  Spirit Lantern: old stone lantern (stone ramp, ink outline) with a teal-white flame: 1 cream core, p water_6,
    o water_5, u teal_2 glass glow, t teal_1, a hint of v lilac at the flame tip and in the smoke. The light pool is
    a dithered teal disc with a dashed rim; each pulse sends a bright p/1 ring outward. Heal motes are teal/cream
    (the HUD's HP bar is teal t), Edge sparks are cream with lilac tails (the HUD's Edge bar is lilac v).
  Phantom Cut: the ghost is the katana hero2_attack frame recoloured: lilac v outline, checkerboard n/o body,
    p blade with 1 glints. Echo arcs are wide ghost crescents (1/p cutting edge, o body, dithered n inside, v rim)
    with dotted v trailing streaks.

Outputs (atlases at 1x game pixels; preview files are scaled copies for viewing):
  spirit_lantern_v2.png/.json   lantern prop (place 4, idle 6, pulse 4, fade 6), light pool (open 3, idle 4,
                                pulse 5), heal motes 6, Edge sparks 6
  phantom_cut_v2.png/.json      buff glow overlays (every animated frame of hero2 / totoy_dagger / totoy_scythe, 6
                                phases each), buff start 5 / end 4, ghosts and echo arcs per weapon and swing (x4),
                                echo spark 5, pending marker 4
  aspect_icons_v2.png/.json     ui_aspect_spirit_lantern_1, ui_aspect_phantom_cut_1 (24px, ring from
                                ui_aspect_gale_cut_1), ui_aspect_spirit_lantern_lit_1..4 (icon while the lantern burns)
  preview_contact_dark.png, preview_contact_grass.png (4x, labelled), spirit_lantern_sequence.gif,
  phantom_cut_{katana,dagger,scythe}.gif (+ _strip.png)
Run from the project root (deterministic, fixed seeds):
  python tools/art/make_aspect_lantern_phantom_art.py
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
import make_dual_dagger_art as M  # noqa: E402  (grid helpers, labelled sheet; no side effects on import)

ROOT = artlib.ROOT
OUT = ROOT / "art" / "reference" / "aspects_lantern_phantom"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)
GENERATOR = "tools/art/make_aspect_lantern_phantom_art.py (procedural, Pillow only, deterministic seeds)"

Grid = list
blank, put, get, copy, paste = M.blank, M.put, M.get, M.copy, M.paste
line_pts, outline_layer, mirror = M.line_pts, M.outline_layer, M.mirror


def to_image(g: Grid) -> Image.Image:
    return M.to_image(g)


def raw_image(g: Grid) -> Image.Image:
    """An existing sprite for side-by-side comparison only (may contain reserved colours, e.g. Breaking Edge's gold)."""
    im = Image.new("RGBA", (len(g[0]), len(g)), (0, 0, 0, 0))
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T:
                im.putpixel((x, y), PAL.by_symbol[c] + (255,))
    return im


def rnd(v: float) -> int:
    return math.floor(v + 0.5)


def load_sprite(name: str) -> tuple[Grid, tuple[int, int]]:
    s = artlib.parse_sprite(ROOT / "art" / "src" / f"{name}.txt")
    return [list(r) for r in s.rows], s.anchor


def lum(sym: str) -> float:
    r, g, b = PAL.by_symbol[sym]
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255


def star(g: Grid, cx: int, cy: int, arm: int, core: str = "1", inner: str = "p", outer: str = "o", diag: str | None = None) -> None:
    """A 4-point star: core pixel, arms of length `arm` (inner colour near the core, outer colour at the tips)."""
    put(g, cx, cy, core)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for i in range(1, arm + 1):
            put(g, cx + dx * i, cy + dy * i, inner if i <= max(1, arm // 2) else outer)
    if diag:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            put(g, cx + dx, cy + dy, diag)


def ellipse_ring(g: Grid, cx: float, cy: float, rx: float, ry: float, sym: str, keep=None, n: int = 0) -> list[tuple[int, int]]:
    """1px ellipse outline; keep(i, x, y) filters pixels (i = index along the ring)."""
    n = n or max(24, int(2 * math.pi * max(rx, ry) * 1.6))
    seen, pts = set(), []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rnd(cx + rx * math.cos(a)), rnd(cy + ry * math.sin(a))
        if (x, y) in seen:
            continue
        seen.add((x, y))
        if keep is None or keep(len(seen) - 1, x, y, a):
            put(g, x, y, sym)
            pts.append((x, y))
    return pts


# ================================================================================================ SPIRIT LANTERN
LANTERN = [  # 13 x 21, ground contact = bottom-centre (6, 20); F = glass (5 x 8)
    ".....000.....",
    "....0j.j0....",
    ".....0i0.....",
    "....0hih0....",
    "...0ghjhg0...",
    "..0ghhihhg0..",
    ".0fgggggggf0.",
    ".00000000000.",
    "..0hFFFFFg0..",
    "..0hFFFFFg0..",
    "..0hFFFFFg0..",
    "..0hFFFFFg0..",
    "..0hFFFFFg0..",
    "..0hFFFFFg0..",
    "..0hFFFFFg0..",
    "..0hFFFFFg0..",
    ".00000000000.",
    ".0hiiiiiiih0.",
    ".0ghhhhhhhg0.",
    "..0fffffff0..",
    "...0000000...",
]
LW, LH = 13, 21
GLASS_X, GLASS_Y, GLASS_W, GLASS_H = 4, 8, 5, 8
LC, LA = 32, (16, 29)  # lantern cell and its anchor (ground contact under the lantern)
L_OX, L_OY = LA[0] - 6, LA[1] - 20  # template origin in the cell


def glass(height: float, lean: float = 0.0, lit: str = "idle", tip: str | None = None) -> Grid:
    """The 5x8 glass pane with a flame of `height` px standing on its bottom row.
    lit: 'off' dark glass, 'idle' teal glow, 'flare' bright, 'white' everything near-white (pulse peak), 'dim' dying."""
    g = blank(GLASS_W, GLASS_H)
    bg = {"off": "k", "idle": "u", "flare": "o", "white": "p", "dim": "t"}[lit]
    for y in range(GLASS_H):
        for x in range(GLASS_W):
            c = bg
            if lit == "idle" and y < GLASS_H - height - 1:
                c = "t"  # the upper glass, away from the flame, is dimmer
            if lit == "flare" and y < GLASS_H - height - 1:
                c = "u"
            if lit == "dim" and y < 3:
                c = "k"
            g[y][x] = c
    if lit == "off":
        put(g, 0, 0, "l")
        put(g, 0, 1, "l")
        return g
    h = max(0.0, height)
    rows = int(math.ceil(h))
    for r in range(rows):
        f = min(1.0, r / max(1.0, h - 1))
        y = GLASS_H - 1 - r
        cx = 2 + lean * f * f
        w = 1.6 * (1 - f) ** 0.8 + 0.3
        for x in range(GLASS_W):
            d = abs(x - cx)
            if lit == "dim":
                if d < w * 0.7:
                    g[y][x] = "o" if f < 0.5 else "u"
                continue
            if d < 0.55 and f < 0.75:
                g[y][x] = "1"
            elif d < w * 0.75:
                g[y][x] = "p"
            elif d < w + 0.45:
                g[y][x] = "o" if lit != "white" else "1"
    if lit == "white":
        for y in range(GLASS_H):
            for x in range(GLASS_W):
                if g[y][x] in "op" and (x + y) % 2 == 0:
                    g[y][x] = "1"
    if tip and rows < GLASS_H:
        put(g, rnd(2 + lean), GLASS_H - 1 - rows, tip)
    return g


def lantern_body(gl: Grid, posts: str | None = None, cap_lit: bool = False) -> Grid:
    """The 13x21 lantern with the given glass pane; posts recolours the two glass posts (lit by the flame)."""
    g = [list(r) for r in LANTERN]
    for y in range(GLASS_H):
        for x in range(GLASS_W):
            g[GLASS_Y + y][GLASS_X + x] = gl[y][x]
    if posts:
        for y in range(GLASS_Y, GLASS_Y + GLASS_H):
            g[y][3] = posts[0]
            g[y][9] = posts[1] if len(posts) > 1 else posts[0]
    if cap_lit:  # the light catches the underside of the eave and the top of the base
        for x in range(2, 11):
            if g[6][x] in "gf":
                g[6][x] = "u" if x % 2 else "g"
        for x in range(2, 11):
            if g[17][x] == "i":
                g[17][x] = "j" if x % 2 else "o"
    return g


def lantern_cell(body: Grid, dy: int = 0) -> Grid:
    c = blank(LC, LC)
    paste(c, body, L_OX, L_OY + dy)
    return c


def puff(g: Grid, cx: float, cy: float, r: float, light: str, dark: str, density: float = 1.0, rng: random.Random | None = None) -> None:
    """A small dust ball: lit upper-left, shaded lower-right, optionally broken up."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x - cx, (y - cy) * 1.2)
            if d <= r:
                if rng is not None and rng.random() > density:
                    continue
                put(g, x, y, light if (x - cx) + (y - cy) < 0 else dark)


def lantern_place(k: int) -> Grid:
    """1 falling (unlit, speed lines), 2 lands: ignition flash + dust burst, 3 puffs spread + sparks, 4 puffs thin."""
    rng = random.Random(500 + k)
    if k == 1:
        c = lantern_cell(lantern_body(glass(0, lit="off")), dy=-6)
        for x, y0, n in ((L_OX + 3, L_OY - 10, 4), (L_OX + 9, L_OY - 9, 3), (L_OX + 6, L_OY - 12, 5)):
            for i in range(n):
                put(c, x, y0 + i, "v" if i < n - 1 else "o")
        return c
    if k == 2:
        c = lantern_cell(lantern_body(glass(8, lit="white"), posts="oo", cap_lit=True))
        base_y = LA[1]
        for s in (-1, 1):
            puff(c, LA[0] + s * 7, base_y - 1, 2.2, "j", "i")
            puff(c, LA[0] + s * 4, base_y, 1.6, "j", "h")
        for dx, dy in ((-9, -6), (9, -5), (-5, -9), (6, -10)):
            put(c, LA[0] + dx, base_y + dy, "1")
        return c
    if k == 3:
        c = blank(LC, LC)
        base_y = LA[1]
        for s in (-1, 1):
            puff(c, LA[0] + s * 10, base_y - 2, 2.4, "j", "i", 0.85, rng)
            puff(c, LA[0] + s * 6, base_y - 1, 1.8, "i", "h", 0.85, rng)
        paste(c, lantern_body(glass(3, lit="idle"), cap_lit=False), L_OX, L_OY)
        for dx, dy, col in ((-11, -9, "p"), (11, -8, "o"), (-6, -13, "o"), (7, -14, "p"), (1, -19, "u")):
            put(c, LA[0] + dx, base_y + dy, col)
        return c
    c = blank(LC, LC)
    base_y = LA[1]
    for s in (-1, 1):
        for _ in range(5):
            put(c, LA[0] + s * rng.randint(9, 14), base_y - rng.randint(1, 5), rng.choice("ijh"))
    paste(c, lantern_body(glass(5, lit="idle"), cap_lit=True), L_OX, L_OY)
    for dx, dy, col in ((-10, -13, "u"), (12, -12, "t"), (4, -21, "o")):
        put(c, LA[0] + dx, base_y + dy, col)
    return c


IDLE_FLAME = [(5, 0, None), (6, 0.8, "v"), (5.5, 0.4, None), (4.5, -0.6, None), (5, -0.9, "v"), (6, 0, "o")]


def motes(c: Grid, k: int, n: int, period: int, spots: list[tuple[int, int]], cols: str = "pouv") -> None:
    """Small motes rising off the lantern, looping every `period` frames."""
    for i, (sx, sy) in enumerate(spots[:n]):
        age = (k + i * period // max(1, n)) % period
        if age >= len(cols):
            continue
        put(c, sx + (1 if (age + i) % 3 == 0 else 0), sy - age * 2, cols[age])


def lantern_idle(k: int) -> Grid:
    h, lean, tip = IDLE_FLAME[k]
    c = lantern_cell(lantern_body(glass(h, lean, "idle", tip), cap_lit=True))
    motes(c, k, 3, 6, [(LA[0] - 5, LA[1] - 22), (LA[0] + 5, LA[1] - 21), (LA[0] + 1, LA[1] - 24)])
    return c


def lantern_pulse(k: int) -> Grid:
    """1 flare (flame fills the glass), 2 burst (white glass + rays), 3 rays out and broken, 4 settle."""
    cx, cy = LA[0], LA[1] - 12  # centre of the glass
    if k == 1:
        c = lantern_cell(lantern_body(glass(7.5, 0, "flare", "1"), posts="uh", cap_lit=True))
        for dx, dy in ((0, -15), (-8, -2), (8, -2)):
            put(c, cx + dx, cy + dy, "p")
        return c
    if k == 2:
        c = lantern_cell(lantern_body(glass(8, 0, "white"), posts="oo", cap_lit=True))
        for i in range(8):
            a = 2 * math.pi * i / 8 + math.pi / 8
            for r in range(9, 13 if i % 2 else 12):
                x, y = rnd(cx + math.cos(a) * r), rnd(cy + math.sin(a) * r * 0.9)
                if get(c, x, y) == T:
                    put(c, x, y, "1" if r < 10 else ("p" if r < 11 else "o"))
        return c
    if k == 3:
        c = lantern_cell(lantern_body(glass(6.5, 0.3, "flare", "v"), posts="uh", cap_lit=True))
        for i in range(8):
            a = 2 * math.pi * i / 8 + math.pi / 8
            for r in (12, 13, 14):
                x, y = rnd(cx + math.cos(a) * r), rnd(cy + math.sin(a) * r * 0.9)
                if get(c, x, y) == T and (r + i) % 2 == 0:
                    put(c, x, y, "o" if r < 14 else "u")
        return c
    c = lantern_cell(lantern_body(glass(5.5, 0.4, "idle", "v"), cap_lit=True))
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        if i % 2 == 0:
            put(c, rnd(cx + math.cos(a) * 14), rnd(cy + math.sin(a) * 13), "u")
    return c


def smoke(c: Grid, x0: int, y0: int, length: int, phase: int, cols: str = "vvgg") -> None:
    """A thin curling smoke wisp rising from (x0, y0)."""
    for i in range(length):
        x = x0 + rnd(1.3 * math.sin((i + phase) * 0.9))
        if (i + phase) % 4 == 3 and i > 1:
            continue
        put(c, x, y0 - i, cols[min(len(cols) - 1, i * len(cols) // max(1, length))])


def lantern_fade(k: int) -> Grid:
    """1-3 the flame shrinks and cools with a lilac smoke wisp, 4 unlit, 5 the lantern dissolves into motes, 6 motes."""
    top = (LA[0], LA[1] - 21)
    if k == 1:
        c = lantern_cell(lantern_body(glass(4, -0.4, "idle", "v")))
        smoke(c, top[0], top[1] - 1, 3, 0)
        return c
    if k == 2:
        c = lantern_cell(lantern_body(glass(2.5, 0, "dim")))
        smoke(c, top[0], top[1] - 1, 5, 1)
        return c
    if k == 3:
        gl = glass(0, lit="off")
        put(gl, 2, GLASS_H - 1, "u")
        c = lantern_cell(lantern_body(gl))
        smoke(c, top[0], top[1] - 1, 7, 2)
        return c
    if k == 4:
        c = lantern_cell(lantern_body(glass(0, lit="off")))
        smoke(c, top[0] + 1, top[1] - 3, 6, 3, "vgg")
        return c
    body = lantern_body(glass(0, lit="off"))
    c = blank(LC, LC)
    keep = 2 if k == 5 else 5
    for y, row in enumerate(body):
        for x, col in enumerate(row):
            if col == T:
                continue
            if (x + y * (1 if k == 5 else 2)) % keep == 0:
                put(c, L_OX + x, L_OY + y - (0 if k == 5 else 2), "v" if col == "0" else ("n" if lum(col) < 0.5 else "o"))
    rng = random.Random(600 + k)
    for _ in range(6 if k == 5 else 8):
        put(c, LA[0] + rng.randint(-7, 7), LA[1] - rng.randint(14, 27) - (0 if k == 5 else 3), rng.choice("pov"))
    return c


# ------------------------------------------------------------------------------------------------ light pool
PW, PH = 96, 48
PA = (48, 24)  # anchor = the lantern's ground point (pool centre)
PRX, PRY = 44.0, 20.0  # v2: the gameplay light radius is about 44 px (v1 was rx 29 / ry 12); same perspective squash
RS = PRX / 29.0  # ring offsets and thicknesses scale with the pool (v1 tuned them for rx 29)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def qnorm(x: int, y: int, s: float = 1.0) -> float:
    return math.hypot((x - PA[0]) / (PRX * s), (y - PA[1]) / (PRY * s))


def pool_base(phase: int, s: float = 1.0, bright: bool = False) -> Grid:
    """Dithered teal floor glow, denser near the lantern, with a dashed rim that drifts around with `phase`."""
    g = blank(PW, PH)
    rng = random.Random(4242)  # the same scatter every frame: only the rim and the twinkles move
    tw = random.Random(4300 + phase)
    for y in range(PH):
        for x in range(PW):
            q = qnorm(x, y, s)
            r = rng.random()
            if q >= 0.9:
                continue
            if q < 0.3:
                dens = 0.5
            else:
                dens = 0.06 + 0.30 * max(0.0, 1 - (q - 0.3) / 0.6) ** 1.6
            if bright:
                dens += 0.1
            if (q < 0.3 and (x + y) % 2 == 0) or (q >= 0.3 and r < dens and (x + y) % 2 == 0):
                g[y][x] = "u" if q < 0.5 else "t"
                if tw.random() < 0.04 and q < 0.75:
                    g[y][x] = "o"
    ellipse_ring(g, PA[0], PA[1], PRX * s, PRY * s, "u", keep=lambda i, x, y, a: (i + phase * 2) % 7 < 5)
    ellipse_ring(g, PA[0], PA[1], PRX * s - 1.4 * RS, PRY * s - 0.8 * RS, "t", keep=lambda i, x, y, a: (i + phase * 2 + 3) % 7 < 2)
    return g


def pool_open(k: int) -> Grid:
    s = (0.35, 0.68, 1.0)[k - 1]
    g = pool_base(k, s)
    ellipse_ring(g, PA[0], PA[1], PRX * s, PRY * s, "o" if k < 3 else "p", keep=lambda i, x, y, a: k < 3 or i % 3 != 0)
    if k == 1:
        ellipse_ring(g, PA[0], PA[1], PRX * s * 0.5, PRY * s * 0.5, "p")
    return g


def pool_idle(k: int) -> Grid:
    return pool_base(k)


def pool_pulse(k: int) -> Grid:
    """A bright ring sweeps from the lantern out to the rim (1 = flash at the lantern, 5 = breaks on the rim)."""
    g = pool_base(k, bright=k <= 2)
    s = (0.18, 0.42, 0.66, 0.86, 1.0)[k - 1]
    if k == 1:
        for y in range(PH):
            for x in range(PW):
                q = qnorm(x, y, 0.22)
                if q < 1.0:
                    g[y][x] = "p" if q < 0.55 else ("o" if (x + y) % 2 == 0 or q < 0.8 else g[y][x])
        return g
    outer = {2: "1", 3: "p", 4: "o", 5: "u"}[k]
    inner = {2: "p", 3: "o", 4: "u", 5: "t"}[k]
    rx, ry = PRX * s, PRY * s
    ellipse_ring(g, PA[0], PA[1], rx, ry, outer, keep=lambda i, x, y, a: k < 4 or (i % (3 if k == 4 else 2)) != 0)
    if k in (2, 3):  # v2: the bigger pool gets a 2 px leading edge on the strong frames
        ellipse_ring(g, PA[0], PA[1], rx + 0.9, ry + 0.6, outer if k == 3 else "p", keep=lambda i, x, y, a: i % 3 != 2)
    ellipse_ring(g, PA[0], PA[1], rx - 1.6 * RS, ry - 0.9 * RS, inner, keep=lambda i, x, y, a: k < 5 and (k < 4 or i % 2 == 0))
    if k in (2, 3, 4):  # thin trailing ripple inside the ring
        ellipse_ring(g, PA[0], PA[1], rx - 4.5 * RS, ry - 2.2 * RS, "u" if k < 4 else "t", keep=lambda i, x, y, a: i % 2 == 0)
    return g


# ------------------------------------------------------------------------------------------------ heal motes, edge sparks
HEAL_W, HEAL_H, HEAL_A = 32, 40, (16, 38)  # anchor = Totoy's feet
HEAL_MOTES = [  # x, start y (cell), delay (frames), kind
    (9, 31, 0, "plus"), (22, 28, 0, "wisp"), (15, 24, 1, "plus"), (25, 33, 1, "plus"), (6, 22, 2, "wisp"), (19, 30, 2, "plus"),
    (13, 33, 0, "wisp"), (4, 29, 1, "plus"), (27, 24, 2, "wisp"),
]


def heal_frame(k: int) -> Grid:
    """6 frames, one pulse: teal/cream plus-sparkles and wisps rise off Totoy and fade at the top."""
    g = blank(HEAL_W, HEAL_H)
    for x, y0, d, kind in HEAL_MOTES:
        age = (k - 1) - d
        if age < 0 or age > 3:
            continue
        y = y0 - age * 5
        if kind == "plus":
            if age == 0:
                put(g, x, y, "u")
            elif age == 1:
                star(g, x, y, 1, "1", "o", "o")
            elif age == 2:
                star(g, x, y, 2, "1", "p", "u")
            else:
                star(g, x, y, 1, "o", "t", "t")
        else:
            cols = ["ut", "puu", "pot", "ot"][age]
            for i, c in enumerate(cols):
                put(g, x + (1 if i == 2 and age % 2 else 0), y + i, c)
    if k <= 2:  # a soft teal ring at the feet as the pulse touches him
        ellipse_ring(g, HEAL_A[0], HEAL_A[1] - 1, 7 + k * 2, 2 + k * 0.5, "o" if k == 1 else "u", keep=lambda i, x, y, a: math.sin(a) > -0.2 and i % 2 == 0)
    return g


EDGE_W, EDGE_H, EDGE_A = 32, 32, (16, 16)  # anchor = Totoy's chest / weapon hand
EDGE_ANGLES = [200, 250, 300, 340, 30, 140]


def edge_frame(k: int) -> Grid:
    """6 frames: lilac-tailed cream sparks stream in to Totoy's chest and pop into a small star."""
    g = blank(EDGE_W, EDGE_H)
    cx, cy = EDGE_A
    if k <= 4:
        for i, deg in enumerate(EDGE_ANGLES):
            a = math.radians(deg + 8 * k)
            r = 15 - (k - 1) * 3.6 - (i % 2) * 1.5
            if r < 2:
                continue
            hx, hy = cx + math.cos(a) * r, cy + math.sin(a) * r
            tail = 3 if k > 1 else 2
            for j in range(tail, 0, -1):
                put(g, rnd(hx + math.cos(a) * j), rnd(hy + math.sin(a) * j), "v" if j > 1 else "p")
            put(g, rnd(hx), rnd(hy), "1")
    if k == 4:
        star(g, cx, cy, 1, "1", "p", "p")
    elif k == 5:
        star(g, cx, cy, 3, "1", "p", "v", "o")
    elif k == 6:
        ellipse_ring(g, cx, cy, 4, 4, "v", keep=lambda i, x, y, a: i % 2 == 0)
        put(g, cx, cy, "p")
    return g


# ================================================================================================ PHANTOM CUT
BLADE = set("klmn")  # the katana on hero2 frames is drawn in the water ramp; the body never uses it
BRIGHTEN = {"k": "m", "l": "n", "m": "o", "n": "p"}
# v2: Phantom Cut is a 5 s buff for every weapon. The hero bodies (hero2 / totoy_dagger / totoy_scythe) use only
# 0 8 9 a-f q r s (plus a handful of stray g h i j pixels), so each weapon's metal is found by colour:
#   katana: the black blade k l (m n); dagger: the steel j n o p (h = grips, g = guards stay plain);
#   scythe: blade and chain 1 t u p j (h = the haft stays plain).
WEAPONS = {  # weapon -> (hero frame set, metal symbols, brighten map, swings)
    "katana": ("hero2", BLADE, BRIGHTEN, 3),
    "dagger": ("totoy_dagger", set("jnop"), {"j": "p", "n": "o", "o": "p", "p": "1"}, 4),
    "scythe": ("totoy_scythe", set("1tupj"), {"t": "u", "u": "p", "p": "1", "1": "1", "j": "p"}, 3),
}
GLOW_STATES = [("idle", 4), ("walk", 6), ("dash", 4), ("parry", 6), ("hurt", 4)]  # + attack<s> 1-6 per swing
GLOW_PHASES = 6  # shimmer loop, about 80 ms per phase, independent of the hero frame


def glow_frame_names(weapon: str) -> list[str]:
    """Every hero frame the game animates while the buff can run (victory and the Reaper's Coil poses excluded)."""
    vid, _, _, swings = WEAPONS[weapon]
    names = [f"{vid}_{st}_right_{n}" for st, cnt in GLOW_STATES for n in range(1, cnt + 1)]
    names += [f"{vid}_attack{s}_right_{n}" for s in range(1, swings + 1) for n in range(1, 7)]
    return names


def trim(g: Grid, anchor: tuple[int, int]) -> tuple[Grid, tuple[int, int]]:
    """Crop to the opaque pixels plus the anchor, padded to multiples of 8 inside the source canvas (atlas space).
    The anchor moves with the crop, so drawing by anchor puts every pixel exactly where it was."""
    h, w = len(g), len(g[0])
    xs = [x for y in range(h) for x in range(w) if g[y][x] != T] + [min(anchor[0], w - 1)]
    ys = [y for y in range(h) for x in range(w) if g[y][x] != T] + [min(anchor[1], h - 1)]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    cw = min(w, -(-(x1 - x0 + 1) // 8) * 8)
    ch = min(h, -(-(y1 - y0 + 1) // 8) * 8)
    x0, y0 = min(x0, w - cw), min(y0, h - ch)
    return [row[x0:x0 + cw] for row in g[y0:y0 + ch]], (anchor[0] - x0, anchor[1] - y0)


def charge_overlay(src: Grid, phase: int, metal: set | None = None, brighten: dict | None = None) -> Grid:
    """Overlay for an armed hero frame: the weapon's metal brightened with a glint running along it, a shimmering
    lilac rim around it and motes rising off it. Same size and anchor as the hero frame; draw it on top.
    v2: any weapon (metal/brighten from WEAPONS) and three motes, so the 5 s buff reads as sustained."""
    metal = BLADE if metal is None else metal
    brighten = BRIGHTEN if brighten is None else brighten
    h, w = len(src), len(src[0])
    g = blank(w, h)
    blade = sorted([(x, y) for y in range(h) for x in range(w) if src[y][x] in metal])
    if not blade:
        return g
    n = len(blade)
    glint = (phase / 6) * 1.5 - 0.25
    for i, (x, y) in enumerate(blade):
        t = i / max(1, n - 1)
        d = abs(t - glint)
        g[y][x] = "1" if d < 0.05 else ("p" if d < 0.12 else brighten[src[y][x]])
    bset = set(blade)
    for (x, y) in blade:
        for dx, dy in ((0, -1), (0, 1), (1, 0), (-1, 0)):
            px, py = x + dx, y + dy
            if (px, py) in bset or get(src, px, py) != T or get(g, px, py) != T:
                continue
            if (px + py * 2 + phase) % 3 != 0:
                put(g, px, py, "o" if (px + phase) % 4 == 0 else "v")
    for (x, y) in blade:  # a dithered second halo, 2 px out, crawling with the phase
        for dx, dy in ((0, -2), (0, 2), (1, -1), (1, 1), (-1, -1), (-1, 1)):
            px, py = x + dx, y + dy
            if get(src, px, py) == T and get(g, px, py) == T and (px + py + phase) % 2 == 0 and (px + phase) % 3 != 0:
                put(g, px, py, "v")
    for i in range(3):
        age = (phase + 2 * i) % 6
        if age >= 4:
            continue
        bx, by = blade[int(n * (0.25 + 0.3 * i)) % n]
        put(g, bx + (1 if i % 2 else -1) * (age // 2), by - 2 - age * 2, "p" if age < 2 else "v")
    return g


def ghost(src: Grid, mode: str, BLADE: set = BLADE) -> Grid:  # noqa: N803  (v2: the weapon's metal symbols)
    """The phantom copy of a hero frame. Lilac outline, checkerboard body (fake translucency), bright blade.
    mode: form (half-drawn), full, fade (thinning), frag (scattered fragments)."""
    h, w = len(src), len(src[0])
    g = blank(w, h)
    for y in range(h):
        for x in range(w):
            c = src[y][x]
            if c == T:
                continue
            edge = any(get(src, x + dx, y + dy) == T for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            chk = (x + y) % 2 == 0
            if c in BLADE:
                if mode == "frag" and (x + y) % 3:
                    continue
                g[y][x] = "1" if (mode == "full" and x % 3 == 0) else ("p" if mode in ("full", "fade") else "o")
                continue
            L = lum(c)
            if mode == "full":
                if edge:
                    g[y][x] = "v"
                elif L < 0.25:
                    g[y][x] = "o" if chk else T
                elif L < 0.55:
                    g[y][x] = "p" if chk else "o"
                else:
                    g[y][x] = "1"
            elif mode == "form":
                if edge:
                    g[y][x] = "v" if chk else T
                elif (x % 2 == 0 and y % 2 == 0):
                    g[y][x] = "o" if L < 0.55 else "p"
            elif mode == "fade":
                if edge:
                    g[y][x] = "v" if (x + y) % 3 else T
                elif chk and (x + 2 * y) % 4 == 0:
                    g[y][x] = "n" if L < 0.25 else "o"
                elif chk:
                    g[y][x] = "v" if (x * 3 + y) % 5 == 0 else T
            else:  # frag
                if (x * 3 + y * 5) % 7 == 0:
                    g[y][x] = "v" if edge else "n"
    return g


def ghost_streaks(g: Grid, src: Grid, length: int) -> None:
    """Dotted lilac speed streaks trailing behind (to the left of) the ghost, on every third row."""
    h, w = len(src), len(src[0])
    for y in range(1, h, 3):
        xs = [x for x in range(w) if src[y][x] != T]
        if not xs:
            continue
        x0 = xs[0]
        for i in range(1, length + 1):
            if i % 2 and get(g, x0 - i, y) == T:
                put(g, x0 - i - (y % 2), y, "v" if i < length - 1 else "n")


# ------------------------------------------------------------------------------------------------ echo arcs
AW, AH, ARC_A = 96, 64, (40, 56)  # anchor = the ghost's feet
ARCS = {  # cx, cy, rx, ry, from_deg, to_deg (the swing runs from -> to), thickness, tilt_deg
    1: (46, 40, 34, 14, 168, -38, 7.0, -14),  # horizontal sweep: low behind, around the front, rising out to the right
    2: (40, 35, 28, 23, 68, -112, 7.5, 0),  # reverse rising arc: low front, up and over to the back
    3: (44, 35, 34, 25, -125, 78, 9.5, 0),  # overhead to low: over the head and down into the ground in front
}
SPANS = {1: (0.0, 0.55, 0.65), 2: (0.0, 1.0, 1.0), 3: (0.3, 1.0, 0.75), 4: (0.55, 1.0, 0.55)}


def arc_normal(rx: float, ry: float, a: float) -> tuple[float, float]:
    """Unit outward normal of the ellipse (rx cos a, ry sin a)."""
    nx, ny = math.cos(a) / rx, math.sin(a) / ry
    ln = math.hypot(nx, ny) or 1.0
    return nx / ln, ny / ln


def arc_frame(s: int, phase: int) -> Grid:
    cx, cy, rx, ry, a0, a1, thick, tilt = ARCS[s]
    t0, t1, tk = SPANS[phase]
    ct, sn = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))

    def P(x: float, y: float) -> tuple[int, int]:  # rotate around the arc centre by the tilt
        dx, dy = x - cx, y - cy
        return rnd(cx + dx * ct - dy * sn), rnd(cy + dx * sn + dy * ct)
    g = blank(AW, AH)
    rng = random.Random(7000 + s * 10 + phase)
    N = 420
    body = {}
    tang = []
    for i in range(N + 1):
        t = i / N
        if t < t0 or t > t1:
            continue
        a = math.radians(a0 + (a1 - a0) * t)
        # taper: thin at the start, fullest at ~65%, sharp leading tip
        lt = (t - t0) / max(1e-6, t1 - t0)
        prof = math.sin(math.pi * min(1.0, lt * 0.92 + 0.04)) ** 0.7
        if phase == 1:
            prof = lt ** 0.6 * (1 - max(0.0, lt - 0.85) / 0.15)
        w = max(0.6, thick * tk * prof)
        if phase == 4 and int(t * 26) % 3 == 0:
            continue
        k = 0.0
        nx, ny = arc_normal(rx, ry, a)
        while k <= w:
            x = cx + rx * math.cos(a) - nx * k
            y = cy + ry * math.sin(a) - ny * k
            p = P(x, y)
            kf = k / max(0.8, w)
            body[p] = min(body.get(p, 9.0), kf)
            k += 0.4
        tang.append((t, a, w))
    for (x, y), kf in body.items():
        chk = (x + y) % 2 == 0
        if phase == 4:
            col = "o" if kf < 0.4 else ("n" if chk else T)
        elif kf < 0.22:
            col = "1" if phase == 2 else "p"
        elif kf < 0.45:
            col = "p" if phase != 3 else "o"
        elif kf < 0.7:
            col = "o"
        else:
            col = "n" if chk else T
        if col != T:
            put(g, x, y, col)
    outline_layer(g, "v")
    # inner speed line and trailing streaks
    if phase in (2, 3):
        for t, a, w in tang[::3]:
            k = w + 2.5
            if int(t * 40) % 3 == 0:
                continue
            nx, ny = arc_normal(rx, ry, a)
            put(g, *P(cx + rx * math.cos(a) - nx * k, cy + ry * math.sin(a) - ny * k), "v")
    if phase >= 2:
        sgn = 1 if a1 > a0 else -1  # direction of travel in angle
        for t, a, w in tang[:: 34 if phase == 2 else 26]:
            if t > 0.8:
                continue
            nx, ny = arc_normal(rx, ry, a)
            x = cx + rx * math.cos(a) - nx * w * 0.3
            y = cy + ry * math.sin(a) - ny * w * 0.3
            # tangent pointing BACK along the swing
            dxa, dya = -(rx) * math.sin(a), (ry) * math.cos(a)
            ln = math.hypot(dxa, dya) or 1
            dxa, dya = -sgn * dxa / ln, -sgn * dya / ln
            L = 5 + rng.randint(0, 3) - (phase - 2) * 2
            for j in range(2, L):
                if j % 2 == 0 or phase == 2:
                    px, py = P(x + dxa * j + math.cos(a) * 2, y + dya * j + math.sin(a) * 2)
                    if get(g, px, py) == T:
                        put(g, px, py, "v" if j < L - 2 else "n")
    if phase == 4:
        for t, a, w in tang[::18]:
            px, py = P(cx + (rx + 3) * math.cos(a), cy + (ry + 2) * math.sin(a))
            put(g, px + rng.randint(-1, 1), py + rng.randint(-1, 1), rng.choice("vno"))
    return g


# ------------------------------------------------------------------------------------------------ v2: dagger and scythe echoes
DW, DH, DAG_A = 64, 48, (16, 44)  # dagger echo canvas, anchor = the ghost's feet
DAGGER_CUTS = {  # feet-relative (p0, p1, bow, width) per cut; the dagger's echoes are short fast slashes (reach ~20-30)
    1: [((4, -21), (27, -17), 2.0, 2.6), ((2, -15), (22, -12), 1.5, 1.8)],  # twin forward thrust-slashes
    2: [((9, -6), (25, -33), 4.0, 2.8)],  # rising backhand
    3: [((10, -26), (28, -6), 2.5, 2.4), ((10, -7), (27, -25), 2.5, 2.0)],  # crossed X at the lunge
    4: [((2, -38), (29, -3), 6.5, 3.8), ((12, -30), (31, -10), 2.0, 1.6)],  # finisher: big downward cut + a short echo
}


def cut_pixels(p0, p1, bow: float, width: float, t0: float, t1: float, taper_lead: bool) -> dict[tuple[int, int], float]:
    """Part [t0, t1] of a bowed, tapered cut (slash_shape with a time window): pixel -> fraction across."""
    out: dict[tuple[int, int], float] = {}
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(dx, dy)
    nx, ny = dy / ln, -dx / ln
    for i in range(301):
        t = i / 300
        if t < t0 or t > t1:
            continue
        lt = (t - t0) / max(1e-6, t1 - t0)
        prof = math.sin(math.pi * t) ** 0.7
        if taper_lead:
            prof *= min(1.0, lt * 2.5)
        w = max(0.5, width * prof)
        bx = p0[0] + dx * t + nx * bow * math.sin(math.pi * t)
        by = p0[1] + dy * t + ny * bow * math.sin(math.pi * t)
        k = 0.0
        while k <= w:
            p = (rnd(bx - nx * k), rnd(by - ny * k))
            out[p] = min(out.get(p, 9.0), k / max(0.6, w))
            k += 0.3
    return out


def dagger_arc(s: int, phase: int) -> Grid:
    """The dagger's echo: short fast ghost slashes, phases lead / peak / follow / fragments like the katana arcs."""
    g = blank(DW, DH)
    span = {1: (0.0, 0.6), 2: (0.0, 1.0), 3: (0.35, 1.0), 4: (0.6, 1.0)}[phase]
    rng = random.Random(7400 + s * 10 + phase)
    for ci, (p0, p1, bow, width) in enumerate(DAGGER_CUTS[s]):
        a0 = (p0[0] + DAG_A[0], p0[1] + DAG_A[1])
        a1 = (p1[0] + DAG_A[0], p1[1] + DAG_A[1])
        lag = 0.15 * ci if phase == 1 else 0.0  # the second blade trails the first a little
        px = cut_pixels(a0, a1, bow, width * (0.6 if phase == 4 else 1.0), max(0.0, span[0] - lag), max(0.05, span[1] - lag), phase == 1)
        for (x, y), f in px.items():
            chk = (x + y) % 2 == 0
            if phase == 4:
                col = ("o" if f < 0.4 else ("n" if chk else T)) if (x * 3 + y) % 4 else T
            elif f < 0.25:
                col = "1" if phase == 2 else "p"
            elif f < 0.55:
                col = "p" if phase != 3 else "o"
            else:
                col = "o" if chk or phase == 2 else "n"
            if col != T:
                put(g, x, y, col)
    outline_layer(g, "v")
    if phase in (2, 3):  # a few dotted speed ticks behind each cut's start
        for p0, p1, bow, width in DAGGER_CUTS[s]:
            dx, dy = p1[0] - p0[0], p1[1] - p0[1]
            ln = math.hypot(dx, dy)
            for j in range(2, 6 if phase == 2 else 4, 2):
                x, y = rnd(p0[0] + DAG_A[0] - dx / ln * j), rnd(p0[1] + DAG_A[1] - dy / ln * j)
                if get(g, x, y) == T:
                    put(g, x, y, "v" if j < 4 else "n")
    if phase == 4:
        for p0, p1, bow, width in DAGGER_CUTS[s]:
            for _ in range(3):
                t = rng.uniform(0.5, 1.0)
                put(g, rnd(p0[0] + (p1[0] - p0[0]) * t + DAG_A[0] + rng.randint(-2, 2)), rnd(p0[1] + (p1[1] - p0[1]) * t + DAG_A[1] + rng.randint(-2, 2)), rng.choice("vno"))
    return g


def ghost_recolour(src: Grid, phase: int) -> Grid:
    """An in-game arc (fx_scythe_arc_*) recoloured as a phantom echo: v rim, 1/p edge, o body, dithered n inside.
    The shape is untouched, so the echo matches the scythe's own swing exactly."""
    h, w = len(src), len(src[0])
    g = blank(w, h)
    for y in range(h):
        for x in range(w):
            c = src[y][x]
            if c == T:
                continue
            edge = any(get(src, x + dx, y + dy) == T for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            L = lum(c)
            chk = (x + y) % 2 == 0
            if phase == 4:
                col = ("v" if edge else ("o" if L > 0.55 else ("n" if chk else T))) if (x * 3 + y) % 3 else T
            elif edge:
                col = "v"
            elif L > 0.8:
                col = "1" if phase == 2 else "p"
            elif L > 0.55:
                col = "p" if phase != 3 else "o"
            elif L > 0.3:
                col = "o"
            else:
                col = "n" if chk else T
            if col != T:
                g[y][x] = col
    return g


START_W, START_H, START_A = 48, 48, (24, 44)  # buff start burst / end fade, anchor = Totoy's feet
CHEST = (2, -17)  # feet-relative chest / weapon hand of the hero frames


def phantom_start(k: int) -> Grid:
    """Buff start, 5 frames: a ghost star pinches at the chest, a lilac ring opens at the feet and ghost streaks rise
    around Totoy, then motes. Draw over the hero; the glow overlay starts with frame 1."""
    g = blank(START_W, START_H)
    fx, fy = START_A
    cx, cy = fx + CHEST[0], fy + CHEST[1]
    rng = random.Random(900 + k)
    if k == 1:
        star(g, cx, cy, 3, "1", "p", "v", "p")
        ellipse_ring(g, fx, fy - 1, 5, 1.6, "p", keep=lambda i, x, y, a: i % 2 == 0)
        return g
    if k == 2:
        star(g, cx, cy, 7, "1", "p", "v", "1")
        ellipse_ring(g, fx, fy - 1, 9, 3, "o", keep=lambda i, x, y, a: i % 4 != 3)
        ellipse_ring(g, fx, fy - 1, 8, 2.4, "v", keep=lambda i, x, y, a: i % 2 == 0)
    elif k == 3:
        star(g, cx, cy, 3, "p", "o", "v")
        ellipse_ring(g, fx, fy - 1, 14, 4.5, "v", keep=lambda i, x, y, a: i % 3 != 2)
        ellipse_ring(g, fx, fy - 1, 13, 4, "o", keep=lambda i, x, y, a: i % 3 == 0)
    elif k == 4:
        ellipse_ring(g, fx, fy - 1, 18, 5.5, "v", keep=lambda i, x, y, a: i % 3 == 0)
    # rising ghost streaks around the body (columns at fixed offsets), climbing with k
    for i, dx in enumerate((-11, -6, 7, 12, -2)):
        top = fy - 6 - (k - 1) * 7 - (i % 3) * 3
        ln = (3, 5, 6, 4, 2)[k - 1] - (i % 2)
        if k == 5 and i % 2:
            continue
        for j in range(max(1, ln)):
            col = "p" if j == 0 else ("o" if j < 2 else "v")
            if k >= 4 and j > 0:
                col = "v" if j % 2 else T
            if col != T:
                put(g, fx + dx, top + j, col)
    if k >= 4:
        for _ in range(4 if k == 4 else 6):
            put(g, fx + rng.randint(-14, 14), fy - rng.randint(10, 38), rng.choice("vov" if k == 4 else "vnv"))
    return g


def phantom_end(k: int) -> Grid:
    """Buff end, 4 frames: the glow tears off the weapon in lilac shreds that drift up and thin out, with a small ring
    closing at the feet. Draw over the hero; the glow overlay stops at frame 1."""
    g = blank(START_W, START_H)
    fx, fy = START_A
    cx, cy = fx + CHEST[0] + 4, fy + CHEST[1]
    rng = random.Random(950 + k)
    if k == 1:
        ellipse_ring(g, fx, fy - 1, 12, 3.8, "v", keep=lambda i, x, y, a: i % 2 == 0)
        star(g, cx, cy, 2, "p", "o", "v")
    elif k == 2:
        ellipse_ring(g, fx, fy - 1, 8, 2.6, "v", keep=lambda i, x, y, a: i % 3 != 1)
    elif k == 3:
        ellipse_ring(g, fx, fy - 1, 4, 1.4, "n", keep=lambda i, x, y, a: i % 2 == 0)
    n = (9, 8, 6, 3)[k - 1]
    for i in range(n):
        x = cx + rng.randint(-10, 10)
        y = cy - 2 - (k - 1) * 4 - rng.randint(0, 8)
        col = ("p", "o", "v", "n")[min(3, k - 1 + (i % 2))]
        put(g, x, y, col)
        if k <= 2 and i % 3 == 0:  # short shreds
            put(g, x, y + 1, "v")
            put(g, x + 1, y + 2, "n")
    return g


SPARK_W, SPARK_A = 32, (16, 16)


def echo_spark(k: int) -> Grid:
    """Where the echo lands: 1 pinch, 2 ghost star + ring, 3 ring opens, 4 broken ring + sparks, 5 motes."""
    g = blank(SPARK_W, SPARK_W)
    cx, cy = SPARK_A
    rng = random.Random(800 + k)
    if k == 1:
        star(g, cx, cy, 4, "1", "p", "v", "p")
    elif k == 2:
        ellipse_ring(g, cx, cy, 6, 6, "v", keep=lambda i, x, y, a: i % 4 != 3)
        star(g, cx, cy, 8, "1", "p", "o", "1")
        for dx, dy in ((2, 2), (-2, 2), (2, -2), (-2, -2)):
            put(g, cx + dx, cy + dy, "p")
        for dx, dy in ((3, 3), (-3, 3), (3, -3), (-3, -3)):
            put(g, cx + dx, cy + dy, "v")
    elif k == 3:
        star(g, cx, cy, 4, "p", "o", "v")
        ellipse_ring(g, cx, cy, 8, 8, "o", keep=lambda i, x, y, a: i % 3 != 2)
        ellipse_ring(g, cx, cy, 7, 7, "v", keep=lambda i, x, y, a: i % 2 == 0)
    elif k == 4:
        put(g, cx, cy, "v")
        ellipse_ring(g, cx, cy, 11, 11, "v", keep=lambda i, x, y, a: i % 3 == 0)
        for i in range(6):
            a = 2 * math.pi * i / 6 + 0.3
            for r in (8, 9):
                put(g, rnd(cx + math.cos(a) * r), rnd(cy + math.sin(a) * r), "p" if r == 8 else "o")
    else:
        for _ in range(7):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(9, 14)
            put(g, rnd(cx + math.cos(a) * r), rnd(cy + math.sin(a) * r), rng.choice("vnv"))
    return g


MARK_W, MARK_A = 16, (8, 15)  # anchor = bottom centre; place it 3 px above Totoy's head


def pending_marker(k: int) -> Grid:
    """4-frame loop: a small ghost katana (diagonal) with a dithered lilac halo, bobbing 1 px, glint running up."""
    g = blank(MARK_W, MARK_W)
    bob = (0, -1, -1, 0)[k - 1]
    p0, p1 = (4, 12 + bob), (12, 4 + bob)  # hilt end, tip
    pts = line_pts(*p0, *p1)
    blade = pts[2:]
    for i, (x, y) in enumerate(blade):
        put(g, x, y, "p")
        put(g, x + 1, y + 1, "o")
    gl = int((k - 1) / 4 * len(blade) + 1)
    for i in (gl - 1, gl):
        if 0 <= i < len(blade):
            put(g, *blade[i], "1")
    for x, y in pts[:2]:
        put(g, x, y, "v")
    put(g, pts[2][0] - 1, pts[2][1], "o")  # guard
    put(g, pts[2][0] + 1, pts[2][1] + 2, "o")
    outline_layer(g, "k")
    for y in range(MARK_W):
        for x in range(MARK_W):
            if g[y][x] == T and (x + y + k) % 2 == 0:
                if any(get(g, x + dx, y + dy) == "k" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    put(g, x, y, "v")
    return g


# ================================================================================================ icons
def lantern_icon(k: int = 0) -> Grid:
    """24px: a lit stone lantern standing on its pool of light. k=0 the static icon, 1-4 the 'lantern burning' flicker."""
    g, n = M.ring_from("ui_aspect_gale_cut_1", 8.6)
    tmp = blank(n, n)
    ellipse_ring(tmp, 11.5, 17.5, 7.5, 1.8, "t", keep=lambda i, x, y, a: i % 3 != 2)
    ellipse_ring(tmp, 11.5, 17.5, 5.0, 1.0, "u", keep=lambda i, x, y, a: math.sin(a) > 0.3)
    icon = [
        "...hjh...",
        "....j....",
        "..hjjjh..",
        ".hiiiiih.",
        "ggggggggg",
        ".gFFFFFg.",
        ".gFFFFFg.",
        ".gFFFFFg.",
        ".gFFFFFg.",
        ".gFFFFFg.",
        ".gFFFFFg.",
        "ggggggggg",
        ".hiiiiih.",
        "..ggggg..",
    ]
    flames = {
        0: ["tuuut", "uuouu", "uopou", "up1pu", "op1po", "o111o"],
        1: ["tuuut", "uuuvu", "uuopu", "uop1u", "op1po", "o111o"],
        2: ["tuuut", "uuouu", "uopou", "up1pu", "op1po", "o111o"],
        3: ["tuuut", "uvuuu", "upouu", "u1pou", "op1po", "o111o"],
        4: ["tuvut", "uopou", "up1pu", "up1pu", "o111o", "o111o"],
    }
    fl = flames[k]
    ox, oy = 7, 3
    for y, row in enumerate(icon):
        for x, c in enumerate(row):
            if c == "F":
                c = fl[y - 5][x - 2]
            if c != T:
                put(tmp, ox + x, oy + y, c)
    sparks = {0: [(5, 8, "o"), (18, 9, "v"), (17, 5, "u")], 1: [(5, 9, "o"), (18, 8, "v"), (6, 5, "u")], 2: [(5, 8, "o"), (18, 7, "o"), (17, 4, "v")],
              3: [(4, 9, "p"), (18, 9, "v"), (6, 6, "u")], 4: [(5, 7, "v"), (19, 8, "p"), (17, 5, "o")]}[k]
    for x, y, c in sparks:
        put(tmp, x, y, c)
    for y in range(n):
        for x in range(n):
            if tmp[y][x] != T and math.hypot(x - 11.5, y - 11.5) < 8.6:
                g[y][x] = tmp[y][x]
    return g


def slash_shape(p0: tuple[float, float], p1: tuple[float, float], bow: float, width: float) -> dict[tuple[int, int], float]:
    """A tapered, slightly bowed cut from p0 to p1: pixel -> fraction across (0 = convex edge, 1 = inner)."""
    out: dict[tuple[int, int], float] = {}
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(dx, dy)
    nx, ny = dy / ln, -dx / ln  # normal toward the convex side
    for i in range(201):
        t = i / 200
        w = width * math.sin(math.pi * t) ** 0.8
        bx = p0[0] + dx * t + nx * bow * math.sin(math.pi * t)
        by = p0[1] + dy * t + ny * bow * math.sin(math.pi * t)
        k = 0.0
        while k <= w:
            p = (rnd(bx - nx * k), rnd(by - ny * k))
            f = k / max(0.6, w)
            out[p] = min(out.get(p, 9.0), f)
            k += 0.3
    return out


def phantom_icon() -> Grid:
    """24px: a bright katana cut and its phantom echo (dithered lilac) a step behind it."""
    g, n = M.ring_from("ui_aspect_gale_cut_1", 8.6)
    tmp = blank(n, n)
    ghost_px = slash_shape((7.5, 20.5), (20.5, 7.5), 2.2, 2.8)
    for (x, y), f in ghost_px.items():
        x, y = x + 0, y + 0
        if f < 0.2:
            put(tmp, x, y, "v" if (x + y) % 2 == 0 else "n")
        elif (x + y) % 2 == 0:
            put(tmp, x, y, "o" if f < 0.6 else "v")
    real = slash_shape((2.5, 15.5), (15.5, 2.5), 2.2, 2.8)
    for (x, y), f in real.items():
        put(tmp, x, y, "1" if f < 0.3 else ("p" if f < 0.65 else "o"))
    for x, y, c in ((15, 5, "p"), (5, 13, "o"), (18, 16, "v"), (13, 19, "n")):
        put(tmp, x, y, c)
    for y in range(n):
        for x in range(n):
            if tmp[y][x] != T and math.hypot(x - 11.5, y - 11.5) < 8.6:
                g[y][x] = tmp[y][x]
    return g


# ================================================================================================ packing + json
def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")


COMMON = {
    "generator": GENERATOR,
    "palette": "Totoy 36, hard alpha; no reserved gold x,y or red z,A",
    "scale": "1x game pixels (nearest-neighbour; preview sheets are scaled copies)",
    "status": "Reference art for the human's approval; not imported into art/src, not wired into the game",
}


def pack(rows: list[list[tuple[str, Grid, tuple[int, int], dict]]], width: int) -> tuple[Image.Image, list[dict]]:
    placed, y = [], 0
    for row in rows:
        x, rh = 0, 0
        for name, g, anchor, extra in row:
            w, h = len(g[0]), len(g)
            if x + w > width:
                x, y = 0, y + rh
                rh = 0
            placed.append((name, g, x, y, anchor, extra))
            x += w
            rh = max(rh, h)
        y += rh
    im = Image.new("RGBA", (width, y), (0, 0, 0, 0))
    frames = []
    for name, g, x, yy, anchor, extra in placed:
        im.alpha_composite(to_image(g), (x, yy))
        frames.append({"name": name, "rect": [x, yy, len(g[0]), len(g)], "anchor": list(anchor), **extra})
    return im, frames


def check_hard(path: Path) -> None:
    errs = artlib.check_png(path, PAL)
    im = Image.open(path).convert("RGBA")
    bad = {PAL.by_symbol[s] for s in FORBIDDEN}
    if any(a == 255 and (r, g, b) in bad for _, (r, g, b, a) in im.getcolors(1 << 20)):
        errs.append("uses a reserved gold/red colour")
    if errs:
        raise SystemExit(f"{path.name}: {'; '.join(errs)}")


GHOST_SOURCE_FRAMES = (3, 4, 4, 5)  # <set>_attack<s>_right_<n> per ghost frame (active 3-4, recovery 5), every weapon
GHOST_MODES = ("form", "full", "fade", "frag")
GHOST_OFFSET = 8  # px ahead of Totoy (along his facing) where the phantom stands
ARC_ANCHORS = {"katana": ARC_A, "dagger": DAG_A, "scythe": (40, 56)}  # scythe = the fx_scythe_arc_* anchor


def trim_group(grids: list[Grid], anchor: tuple[int, int]) -> tuple[list[Grid], tuple[int, int]]:
    """trim() with one crop for all phases (the union of their pixels), so a group keeps one size and anchor."""
    union = blank(len(grids[0][0]), len(grids[0]))
    for g in grids:
        paste(union, g, 0, 0)
    crop, new_anchor = trim(union, anchor)
    dx, dy = anchor[0] - new_anchor[0], anchor[1] - new_anchor[1]
    w, h = len(crop[0]), len(crop)
    return [[row[dx:dx + w] for row in g[dy:dy + h]] for g in grids], new_anchor


def build_glow(weapon: str) -> dict[str, tuple[list[Grid], tuple[int, int], Grid, tuple[int, int]]]:
    """hero frame name -> (GLOW_PHASES trimmed overlays, their anchor, the hero frame, its anchor)."""
    _, metal, bright, _ = WEAPONS[weapon]
    out = {}
    for name in glow_frame_names(weapon):
        src, anc = load_sprite(name)
        ovs, oa = trim_group([charge_overlay(src, ph, metal, bright) for ph in range(GLOW_PHASES)], anc)
        out[name] = (ovs, oa, src, anc)
    return out


def build() -> dict:
    a: dict = {}
    a["place"] = [lantern_place(k) for k in range(1, 5)]
    a["idle"] = [lantern_idle(k) for k in range(6)]
    a["pulse"] = [lantern_pulse(k) for k in range(1, 5)]
    a["fade"] = [lantern_fade(k) for k in range(1, 7)]
    a["pool_open"] = [pool_open(k) for k in range(1, 4)]
    a["pool_idle"] = [pool_idle(k) for k in range(4)]
    a["pool_pulse"] = [pool_pulse(k) for k in range(1, 6)]
    a["heal"] = [heal_frame(k) for k in range(1, 7)]
    a["edge"] = [edge_frame(k) for k in range(1, 7)]
    a["glow"] = {w: build_glow(w) for w in WEAPONS}
    a["start"] = [phantom_start(k) for k in range(1, 6)]
    a["end"] = [phantom_end(k) for k in range(1, 5)]
    a["ghost"], a["arcs"] = {}, {}
    for w, (vid, metal, _, swings) in WEAPONS.items():
        a["ghost"][w], a["arcs"][w] = {}, {}
        for s in range(1, swings + 1):
            out = []
            for fn, mode in zip(GHOST_SOURCE_FRAMES, GHOST_MODES):
                src, anc = load_sprite(f"{vid}_attack{s}_right_{fn}")
                gg = ghost(src, mode, metal)
                if mode in ("full", "fade"):
                    ghost_streaks(gg, src, 6 if mode == "full" else 4)
                out.append((gg, anc, f"{vid}_attack{s}_right_{fn}"))
            a["ghost"][w][s] = out
            if w == "katana":
                a["arcs"][w][s] = [arc_frame(s, ph) for ph in (1, 2, 3, 4)]
            elif w == "dagger":
                a["arcs"][w][s] = [dagger_arc(s, ph) for ph in (1, 2, 3, 4)]
            else:
                a["arcs"][w][s] = [ghost_recolour(load_sprite(f"fx_scythe_arc_{s}_{ph}")[0], ph) for ph in (1, 2, 3, 4)]
    a["spark"] = [echo_spark(k) for k in range(1, 6)]
    a["marker"] = [pending_marker(k) for k in range(1, 5)]
    a["icon_lantern"] = lantern_icon(0)
    a["icon_lantern_lit"] = [lantern_icon(k) for k in range(1, 5)]
    a["icon_phantom"] = phantom_icon()
    return a


LANTERN_MS = {"place": (60, 60, 70, 80), "idle": (110,) * 6, "pulse": (50, 60, 60, 80), "fade": (90, 90, 100, 120, 90, 90),
              "pool_open": (50,) * 3, "pool_idle": (140,) * 4, "pool_pulse": (55,) * 5, "motes": (70,) * 6, "spark": (55,) * 6}


def lantern_sprites(a: dict) -> list[tuple[str, Grid, tuple[int, int], dict]]:
    """Every Spirit Lantern sprite in its in-game name (v2: heal motes = fx_lantern_motes, Edge sparks = fx_lantern_spark)."""
    out = []
    for key, src, anchor in (("place", "place", LA), ("idle", "idle", LA), ("pulse", "pulse", LA), ("fade", "fade", LA),
                             ("pool_open", "pool_open", PA), ("pool_idle", "pool_idle", PA), ("pool_pulse", "pool_pulse", PA),
                             ("motes", "heal", HEAL_A), ("spark", "edge", EDGE_A)):
        out += [(f"fx_lantern_{key}_{k + 1}", g, anchor, {"ms": LANTERN_MS[key][k]}) for k, g in enumerate(a[src])]
    return out


def phantom_sprites(a: dict) -> list[tuple[str, Grid, tuple[int, int], dict]]:
    """Every Phantom Cut sprite in its in-game name."""
    out = []
    for w in WEAPONS:
        for frame, (ovs, oa, _src, _sa) in a["glow"][w].items():
            out += [(f"fx_phantom_glow_{frame}_{ph + 1}", g, oa, {"hero_frame": frame, "phase": ph + 1, "ms": 80}) for ph, g in enumerate(ovs)]
    out += [(f"fx_phantom_start_{k + 1}", g, START_A, {"ms": (50, 60, 60, 70, 80)[k]}) for k, g in enumerate(a["start"])]
    out += [(f"fx_phantom_end_{k + 1}", g, START_A, {"ms": (70, 70, 80, 90)[k]}) for k, g in enumerate(a["end"])]
    for w in WEAPONS:
        for s, frames in a["ghost"][w].items():
            out += [(f"fx_phantom_ghost_{w}_{s}_{i + 1}", gg, anc, {"source": src, "mode": GHOST_MODES[i], "ms": (40, 60, 60, 70)[i]})
                    for i, (gg, anc, src) in enumerate(frames)]
    for w in WEAPONS:
        for s, arcs in a["arcs"][w].items():
            out += [(f"fx_phantom_arc_{w}_{s}_{ph + 1}", g, ARC_ANCHORS[w], {"swing": s, "phase": ("lead", "peak", "follow", "fragments")[ph], "ms": (35, 55, 55, 70)[ph]})
                    for ph, g in enumerate(arcs)]
    out += [(f"fx_phantom_spark_{k + 1}", g, SPARK_A, {"ms": (35, 50, 50, 55, 70)[k]}) for k, g in enumerate(a["spark"])]
    out += [(f"fx_phantom_marker_{k + 1}", g, MARK_A, {"ms": 120}) for k, g in enumerate(a["marker"])]
    return out


def icon_sprites(a: dict) -> list[tuple[str, Grid, tuple[int, int], dict]]:
    out = [("ui_aspect_spirit_lantern_1", a["icon_lantern"], (12, 12), {"use": "Aspect slot / HUD skill icon"}),
           ("ui_aspect_phantom_cut_1", a["icon_phantom"], (12, 12), {"use": "Aspect slot / HUD skill icon"})]
    out += [(f"ui_aspect_spirit_lantern_lit_{k + 1}", g, (12, 12), {"use": "optional: HUD icon while the lantern burns (loop about 120 ms)"})
            for k, g in enumerate(a["icon_lantern_lit"])]
    return out


def rows_by_group(sprites: list[tuple[str, Grid, tuple[int, int], dict]]) -> list[list]:
    """One packing row per sprite group (name without its trailing _N)."""
    rows: dict[str, list] = {}
    for e in sprites:
        rows.setdefault(e[0].rsplit("_", 1)[0], []).append(e)
    return list(rows.values())


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    a = build()
    written: list[Path] = []

    # 1. Spirit Lantern sheet
    sheet, frames = pack(rows_by_group(lantern_sprites(a)), 512)
    sheet.save(OUT / "spirit_lantern_v2.png")
    written.append(OUT / "spirit_lantern_v2.png")
    write_json(OUT / "spirit_lantern_v2.json", {
        **COMMON,
        "aspect": "Spirit Lantern (suggested display name: SPIRIT LANTERN; HUD/menu subtitle idea: 'LIGHT THAT MENDS')",
        "request": "Totoy sets a spirit lantern down at his feet; for about 5 s it glows and pulses; while Totoy stands in its light each pulse heals a little and gives Edge. v2: the light pool covers the gameplay radius of about 44 px.",
        "groups": {
            "fx_lantern_place_<1..4>": "32x32, anchor (16,29) = the lantern's ground point. 1 dropping in (unlit, speed lines; the lantern is 6 px up), 2 lands: ignition flash and dust burst, 3 dust spreads, sparks, small flame, 4 dust thins, flame up. Then loop idle.",
            "fx_lantern_idle_<1..6>": "32x32, anchor (16,29). Burning loop: the teal-white flame flickers (height and lean), lilac tip on 2 and 5, motes rise off the cap. About 110 ms per frame.",
            "fx_lantern_pulse_<1..4>": "32x32, anchor (16,29). One pulse: 1 flare, 2 burst (white glass, 8 rays), 3 rays out and breaking, 4 settle. Play on each core pulse, then back to idle.",
            "fx_lantern_fade_<1..6>": "32x32, anchor (16,29). Extinguish: 1-3 the flame shrinks and cools with a lilac smoke wisp, 4 unlit, 5 the lantern dissolves (dither) into motes, 6 last motes. The lantern is gone after 6.",
            "fx_lantern_pool_open_<1..3>": "96x48, anchor (48,24) = the same ground point as the lantern. Ground decal, draw UNDER every character. The pool opens from the lantern with a bright edge (with place 2-4).",
            "fx_lantern_pool_idle_<1..4>": "96x48, anchor (48,24). Dithered teal floor glow (rx 44, ry 20: an 88x40 px ellipse, the gameplay radius of about 44 px with the floor squash) with a dashed rim that drifts; loop about 140 ms per frame.",
            "fx_lantern_pool_pulse_<1..5>": "96x48, anchor (48,24). The pulse ring: 1 flash at the lantern, 2-4 a bright ring (2 px edge on 2-3) sweeps out, 5 it breaks on the rim. Starts with fx_lantern_pulse_1.",
            "fx_lantern_motes_<1..6>": "32x40, anchor (16,38) = Totoy's feet. Heal motes: plays over Totoy on a pulse while he stands in the light: teal ring at the feet, plus-sparkles and wisps rise and fade. Draw over the hero.",
            "fx_lantern_spark_<1..6>": "32x32, anchor (16,16) = Totoy's chest/weapon hand (about feet + (2,-15)). Edge sparks: cream sparks with lilac tails (the HUD Edge colour) stream in and pop. Start it 1-2 frames after fx_lantern_motes_1.",
        },
        "pool_radius_px": {"rx": PRX, "ry": PRY},
        "draw_order": ["fx_lantern_pool_* (floor decal)", "hero / boss / lantern sorted by their ground y", "fx_lantern_motes_*, fx_lantern_spark_* (over the hero)"],
        "frames": frames,
    })
    written.append(OUT / "spirit_lantern_v2.json")

    # 2. Phantom Cut sheet
    sheet, frames = pack(rows_by_group(phantom_sprites(a)), 1024)
    sheet.save(OUT / "phantom_cut_v2.png")
    written.append(OUT / "phantom_cut_v2.png")
    write_json(OUT / "phantom_cut_v2.json", {
        **COMMON,
        "aspect": "Phantom Cut (suggested display name: PHANTOM CUT; subtitle idea: 'THE BLADE REMEMBERS')",
        "request": "v2: a 5 s buff; EVERY basic attack during it spawns a delayed phantom copy of the same swing a moment later, for all three weapons. Delay, damage and cost are owner/core decisions.",
        "groups": {
            "fx_phantom_glow_<hero frame>_<1..6>": "Sustained buff glow, drawn ON TOP of the hero frame named <hero frame> (for example fx_phantom_glow_hero2_attack2_right_3_4 over hero2_attack2_right_3), placed by its own anchor at the hero's feet and mirrored with him. Cropped to the glow (anchor = the hero frame's feet point in the crop). Six shimmer phases, loop at about 80 ms over the whole 5 s, independent of the hero frame: the weapon's metal brightened with a cream glint running along it, a lilac rim and halo, three motes. Made for every frame of idle 1-4, walk 1-6, dash 1-4, parry 1-6, hurt 1-4 and attack<s> 1-6 of hero2 (katana, 3 swings), totoy_dagger (4 swings) and totoy_scythe (3 swings).",
            "fx_phantom_start_<1..5>": "48x48, anchor (24,44) = Totoy's feet. Buff start: ghost star at the chest, a lilac ring opens at the feet, ghost streaks rise, motes. Draw over the hero; start the glow with frame 1.",
            "fx_phantom_end_<1..4>": "48x48, anchor (24,44). Buff end: the glow tears off in lilac shreds that drift up, a small ring closes at the feet. The glow stops at frame 1.",
            "fx_phantom_ghost_<weapon>_<swing>_<1..4>": "The phantom: <set>_attack<swing>_right_<3,4,4,5> recoloured (lilac outline, checkerboard body, bright metal), weapon = katana (hero2) / dagger (totoy_dagger) / scythe (totoy_scythe). Same size/anchor as its source frame. 1 forming, 2 full (with speed streaks), 3 thinning, 4 fragments. Draw at Totoy's feet + ghost_offset_px along his facing, mirrored with him.",
            "fx_phantom_arc_<weapon>_<swing>_<1..4>": "The echo slash over the phantom, anchor = the phantom's feet. katana 96x64 (40,56): wide ghost crescents (v1 arcs). dagger 64x48 (16,44): short fast ghost slashes (1 twin thrust cuts, 2 rising backhand, 3 crossed X, 4 big downward finisher). scythe 96x64 (40,56): fx_scythe_arc_<swing>_<phase> recoloured, so the echo has the scythe's own crescent. Phases lead/peak/follow/fragments, about 35/55/55/70 ms.",
            "fx_phantom_spark_<1..5>": "32x32, anchor (16,16) = where an echo hits. Pinch, star + ring, ring opens, broken ring + sparks, motes. Start it on arc phase 2.",
            "fx_phantom_marker_<1..4>": "16x16, anchor (8,15) = bottom centre; place 3 px above Totoy's head while the buff runs (the 'echo pending' cue; loop about 120 ms). Small ghost katana, bobbing, glint running up.",
        },
        "suggested_timeline": "cast: fx_phantom_start 1-5 + glow + marker on. For 5 s: every swing's real hit, then about 0.25 s later ghost 1-4 + arc 1-4 of that weapon and swing (arc 2 = the phantom hit) and spark 1-5 on the target; echoes may overlap the next swing. At the end: glow and marker off, fx_phantom_end 1-4.",
        "ghost_offset_px": GHOST_OFFSET,
        "frames": frames,
    })
    written.append(OUT / "phantom_cut_v2.json")

    # 3. icons (unchanged from v1)
    sheet, frames = pack([icon_sprites(a)], 24 * 6)
    sheet.save(OUT / "aspect_icons_v2.png")
    written.append(OUT / "aspect_icons_v2.png")
    write_json(OUT / "aspect_icons_v2.json", {
        **COMMON,
        "style": "Ring copied from the existing ui_aspect_gale_cut_1 (24px), like the dagger and scythe icons; new interior drawn here. No 48px versions: the existing Aspect icons are 24px only (character menu slots draw the 24px icon). Unchanged from v1.",
        "frames": frames,
    })
    written.append(OUT / "aspect_icons_v2.json")
    for p in written:
        if p.suffix == ".png":
            check_hard(p)

    make_previews(a)
    make_lantern_gif(a)
    for w in WEAPONS:
        make_phantom_gif(a, w)
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*") if p.suffix in (".png", ".json", ".gif"))))
    return 0


# ================================================================================================ previews
BG_DARK = PAL.by_symbol["0"]
BG_GRASS = PAL.by_symbol["4"]


def on_cell(w: int, h: int, layers: list[tuple[Grid, int, int]]) -> Grid:
    g = blank(w, h)
    for lay, x, y in layers:
        paste(g, lay, x, y)
    return g


def over_hero(src: Grid, sa: tuple[int, int], ov: Grid, oa: tuple[int, int]) -> Grid:
    """A hero frame with an overlay placed by anchors (the overlay may be cropped)."""
    g = copy(src)
    paste(g, ov, sa[0] - oa[0], sa[1] - oa[1])
    return g


def make_previews(a: dict) -> None:
    im = to_image
    # lantern standing on its pool, every lantern frame
    def on_pool(lf: Grid, pf: Grid | None) -> Image.Image:
        layers = [] if pf is None else [(pf, 0, 4)]
        layers.append((lf, PA[0] - LA[0], PA[1] + 4 - LA[1]))
        return im(on_cell(PW, PH + 8, layers))
    comp_idle = [on_pool(a["idle"][k], a["pool_idle"][k % 4]) for k in range(6)]
    comp_pulse = [on_pool(a["pulse"][min(3, k)], a["pool_pulse"][k]) for k in range(5)]
    comp_place = [on_pool(a["place"][k], a["pool_open"][k - 1] if k else None) for k in range(4)]
    idle_src, idle_a = load_sprite("hero2_idle_right_1")
    hero_cells = []
    for k in range(6):
        g = blank(32, 40)
        paste(g, idle_src, HEAL_A[0] - idle_a[0], HEAL_A[1] - idle_a[1])
        paste(g, a["heal"][k], 0, 0)
        if k >= 1:
            paste(g, a["edge"][k - 1], HEAL_A[0] + 2 - EDGE_A[0], HEAL_A[1] - 15 - EDGE_A[1])
        hero_cells.append(im(g))
    # pool scale: Totoy (idle) standing at the edge of the light, 44 px right of the lantern
    scale = blank(PW + 8, PH + 24)
    paste(scale, a["pool_idle"][0], 4, 16)
    paste(scale, a["idle"][0], 4 + PA[0] - LA[0], 16 + PA[1] - LA[1])
    paste(scale, idle_src, 4 + PA[0] + 40 - idle_a[0], 16 + PA[1] - idle_a[1])
    groups = [
        ("SPIRIT LANTERN v2  lantern: place 1-4 | idle 1-6 | pulse 1-4 | fade 1-6 (unchanged)", [im(g) for g in a["place"] + a["idle"] + a["pulse"] + a["fade"]]),
        ("light pool v2 (rx 44 / ry 20, 88x40 px): open 1-3 | idle 1-4 | pulse 1-5 (floor decal)", [im(g) for g in a["pool_open"] + a["pool_idle"] + a["pool_pulse"]]),
        ("lantern on its pool: place+open | idle loop | pulse", comp_place + comp_idle + comp_pulse),
        ("scale: Totoy idle 40 px right of the lantern, just inside the 44 px light", [im(scale)]),
        ("heal motes (fx_lantern_motes) 1-6 | Edge sparks (fx_lantern_spark) 1-6", [im(g) for g in a["heal"] + a["edge"]]),
        ("over Totoy (idle 1): motes 1-6 with Edge sparks a frame later", hero_cells),
    ]
    for w in WEAPONS:
        glow = a["glow"][w]
        first = next(iter(glow))
        ovs, oa, src, sa = glow[first]
        groups.append((f"PHANTOM CUT v2  {w}: buff glow over {first}, phases 1-6", [im(over_hero(src, sa, ov, oa)) for ov in ovs]))
        groups.append((f"{w}: glow over every animated frame (idle, walk, dash, parry, hurt, attack 1-{WEAPONS[w][3]}), phase cycling",
                       [im(over_hero(src, sa, ovs[i % GLOW_PHASES], oa)) for i, (ovs, oa, src, sa) in enumerate(glow.values())]))
    groups.append(("buff start 1-5 | buff end 1-4 (raw)", [im(g) for g in a["start"] + a["end"]]))
    st_cells = []
    for k, g in enumerate(a["start"] + a["end"]):
        c = blank(START_W, START_H)
        paste(c, idle_src, START_A[0] - idle_a[0], START_A[1] - idle_a[1])
        if k < 5 or k == 5:  # glow under start 1-5 and end 1
            ovs, oa, _, _ = a["glow"]["katana"]["hero2_idle_right_1"]
            paste(c, ovs[k % 6], START_A[0] - oa[0], START_A[1] - oa[1])
        paste(c, g, 0, 0)
        st_cells.append(im(c))
    groups.append(("over Totoy: start 1-5 (glow on) | end 1-4 (glow off after end 1)", st_cells))
    for w in WEAPONS:
        ghosts = [im(gg) for s in a["ghost"][w] for gg, _, _ in a["ghost"][w][s]]
        groups.append((f"{w} phantom ghosts: swing 1-{WEAPONS[w][3]} x form/full/fade/fragments (from attack frames 3,4,4,5)", ghosts))
        aa = ARC_ANCHORS[w]
        aw, ah = len(a["arcs"][w][1][0][0]), len(a["arcs"][w][1][0])
        comp = []
        for s in a["arcs"][w]:
            for ph in range(4):
                gg, anc, _ = a["ghost"][w][s][ph]
                g = blank(aw, ah)
                paste(g, gg, aa[0] - anc[0], aa[1] - anc[1])
                paste(g, a["arcs"][w][s][ph], 0, 0)
                comp.append(im(g))
        groups.append((f"{w} echo arcs over the phantom: swing x lead/peak/follow/fragments", comp))
        rvg = []
        for s in a["ghost"][w]:
            src, anc = load_sprite(f"{WEAPONS[w][0]}_attack{s}_right_4")
            g = blank(88, 48)
            paste(g, src, 24 - anc[0], 44 - anc[1])
            gg, ganc, _ = a["ghost"][w][s][1]
            paste(g, gg, 24 + GHOST_OFFSET + 26 - ganc[0], 44 - ganc[1])
            rvg.append(im(g))
        groups.append((f"{w}: real attack frame 4 (left) and its phantom (right, spread apart for viewing)", rvg))
    groups.append(("echo spark 1-5 | pending marker 1-4", [im(g) for g in a["spark"] + a["marker"]]))
    groups.append(("ICONS 24px: spirit lantern, phantom cut, lantern burning 1-4 | next to breaking edge, gale cut, moon cleave",
                   [im(a["icon_lantern"]), im(a["icon_phantom"])] + [im(g) for g in a["icon_lantern_lit"]]
                   + [raw_image(load_sprite(f"ui_aspect_{nm}_1")[0]) for nm in ("breaking_edge", "gale_cut", "moon_cleave")]))
    for tag, bg in (("dark", BG_DARK), ("grass", BG_GRASS)):
        M.labelled_sheet(groups, bg, 4, 10).convert("RGB").save(OUT / f"preview_contact_{tag}.png")


SW_, SH_ = 192, 120  # GIF scene at game pixels (shown at 4x)


def arena_scene() -> Image.Image:
    """Grass with a few worn flagstones, like the ruins arena floor."""
    im = Image.new("RGBA", (SW_, SH_), BG_GRASS + (255,))
    d = ImageDraw.Draw(im)
    rng = random.Random(4)
    for _ in range(140):
        d.point((rng.randrange(SW_), rng.randrange(SH_)), fill=PAL.by_symbol[rng.choice("35")] + (255,))
    for fx, fy, w, h in ((20, 104, 14, 7), (36, 108, 12, 6), (150, 30, 14, 7), (166, 34, 10, 6), (8, 40, 12, 6)):
        d.rectangle((fx, fy, fx + w - 1, fy + h - 1), fill=PAL.by_symbol["g"] + (255,))
        d.line((fx, fy, fx + w - 2, fy), fill=PAL.by_symbol["h"] + (255,))
        d.line((fx, fy + h - 1, fx + w - 1, fy + h - 1), fill=PAL.by_symbol["f"] + (255,))
    return im


def save_gif(frames: list[tuple[Image.Image, int]], name: str, strip_name: str) -> None:
    Z = 4
    big = [im.convert("RGB").resize((SW_ * Z, SH_ * Z), Image.NEAREST) for im, _ in frames]
    big[0].save(OUT / name, save_all=True, append_images=big[1:], duration=[ms for _, ms in frames], loop=0, disposal=1)
    cols, Zs = 8, 2
    strip = Image.new("RGB", (cols * SW_ * Zs, ((len(frames) + cols - 1) // cols) * SH_ * Zs), BG_DARK)
    for i, (im, _) in enumerate(frames):
        strip.paste(im.convert("RGB").resize((SW_ * Zs, SH_ * Zs), Image.NEAREST), ((i % cols) * SW_ * Zs, (i // cols) * SH_ * Zs))
    strip.save(OUT / strip_name)


def hud_bars(hp: float, edge: float) -> Grid:
    """Mock HUD (top-left): HP bar in teal t, Edge bar in lilac v, the HUD's colours. Viewing only."""
    g = blank(52, 12)
    for x in range(50):
        for y in range(5):
            put(g, 1 + x, 1 + y, "t" if x < hp * 50 else "e")
        for y in range(2):
            put(g, 1 + x, 8 + y, "v" if x < edge * 50 else "e")
    outline_layer(g, "0")
    return g


def golem_flash(g: Grid) -> Grid:
    light = set("4567cdhijlmnorstu1")
    return [[("1" if c in light and (x + y) % 3 else ("p" if c in light else c)) for x, c in enumerate(row)] for y, row in enumerate(g)]


def make_lantern_gif(a: dict) -> None:
    """Totoy sets the lantern down, the pool opens; two pulses heal him and give Edge (bars fill); he walks out of the
    light and the third pulse passes him by; the lantern goes out."""
    scene = arena_scene()
    golem, (gax, gay) = load_sprite("golem2_idle_1")
    idle = [load_sprite(f"hero2_idle_right_{n}") for n in range(1, 5)]
    walk = [load_sprite(f"hero2_walk_right_{n}") for n in range(1, 7)]
    lant = (78, 92)  # lantern ground point
    out: list[tuple[Image.Image, int]] = []
    st = {"hp": 0.46, "edge": 0.30, "hx": 66, "flip": False}

    def hero_layer(fr: tuple[Grid, tuple[int, int]], flip: bool) -> tuple[Grid, int, int]:
        g, (ax, ay) = fr
        if flip:
            g, ax = mirror(g), len(g[0]) - 1 - ax
        return g, st["hx"] - ax, 90 - ay

    def compose(under: list, lantern: Grid | None, hero: tuple, over: list, ms: int) -> None:
        im = scene.copy()
        sg = blank(SW_, SH_)
        for g, x, y in under:
            paste(sg, g, x, y)
        paste(sg, golem, 160 - gax, 80 - gay)
        # sort hero and lantern by ground y (hero feet 90, lantern 92: the lantern stands in front)
        paste(sg, *hero)
        if lantern is not None:
            paste(sg, lantern, lant[0] - LA[0], lant[1] - LA[1])
        for g, x, y in over:
            paste(sg, g, x, y)
        paste(sg, hud_bars(st["hp"], st["edge"]), 4, 4)
        im.alpha_composite(to_image(sg))
        out.append((im, ms))

    pool_at = (lant[0] - PA[0], lant[1] - PA[1])
    t = 0
    for i in range(4):
        compose([], None, hero_layer(idle[i % 4], False), [], 130)
    for k in range(4):
        under = [(a["pool_open"][k - 1], *pool_at)] if k else []
        compose(under, a["place"][k], hero_layer(idle[(k + 1) % 4], False), [], (70, 60, 70, 80)[k])

    def pulse_seq(inside: bool, base_t: int) -> int:
        tt = base_t
        for k in range(7):
            under = [(a["pool_pulse"][k] if k < 5 else a["pool_idle"][tt % 4], *pool_at)]
            lf = a["pulse"][k] if k < 4 else a["idle"][tt % 6]
            over = []
            hero = hero_layer(idle[(tt // 2) % 4], st["flip"])
            if inside and k >= 1:
                feet = (st["hx"], 90)
                over.append((a["heal"][k - 1], feet[0] - HEAL_A[0], feet[1] - HEAL_A[1]))
                if k >= 2:
                    over.append((a["edge"][k - 2], feet[0] + 2 - EDGE_A[0], feet[1] - 15 - EDGE_A[1]))
                if k >= 3:
                    st["hp"] = min(1.0, st["hp"] + 0.03)
                if k >= 5:
                    st["edge"] = min(1.0, st["edge"] + 0.04)
            compose(under, lf, hero, over, (55, 60, 60, 70, 70, 70, 80)[k])
            tt += 1
        return tt

    def idle_run(n: int, base_t: int) -> int:
        tt = base_t
        for _ in range(n):
            compose([(a["pool_idle"][tt % 4], *pool_at)], a["idle"][tt % 6], hero_layer(idle[(tt // 2) % 4], st["flip"]), [], 110)
            tt += 1
        return tt

    t = idle_run(4, t)
    t = pulse_seq(True, t)
    t = idle_run(4, t)
    t = pulse_seq(True, t)
    # walks out of the light (to the left), then turns back to watch the next pulse pass him by
    st["flip"] = True
    for i in range(14):  # v2: 42 px out, so he ends about 54 px from the lantern, outside the 44 px light
        st["hx"] -= 3
        compose([(a["pool_idle"][t % 4], *pool_at)], a["idle"][t % 6], hero_layer(walk[i % 6], True), [], 80)
        t += 1
    st["flip"] = False
    t = idle_run(2, t)
    t = pulse_seq(False, t)
    t = idle_run(3, t)
    for k in range(6):
        under = [(a["pool_idle"][t % 4], *pool_at)] if k < 2 else []
        if k == 2:
            g = copy(a["pool_idle"][t % 4])
            for y, row in enumerate(g):
                for x, c in enumerate(row):
                    if c != T and (x + y) % 2:
                        g[y][x] = T
            under = [(g, *pool_at)]
        compose(under, a["fade"][k], hero_layer(idle[(t // 2) % 4], False), [], (90, 90, 100, 120, 90, 90)[k])
        t += 1
    for i in range(4):
        compose([], None, hero_layer(idle[i % 4], False), [], 140)
    save_gif(out, "spirit_lantern_sequence.gif", "spirit_lantern_sequence_strip.png")


GOLEM_LEFT = 21  # golem2_idle_1: feet x minus its leftmost pixel
GIF_STEP = 50  # ms per GIF frame in the timeline mock
BUFF_MS = 5000
CAST_MS = 400
SWING_FRAME_MS = 55  # attack frames 1-6 at 55 ms (illustrative; the core's swing tables set the real timing)
ECHO_DELAY_MS = 250  # real hit (attack frame 4) -> phantom appears (illustrative)


def buff_bar(left: float) -> Grid:
    """Mock HUD buff timer (top-left): the remaining 5 s in lilac v. Viewing only."""
    g = blank(52, 6)
    for x in range(50):
        for y in range(3):
            put(g, 1 + x, 1 + y, "v" if x < left * 50 else "e")
    outline_layer(g, "0")
    return g


def make_phantom_gif(a: dict, weapon: str) -> None:
    """One 5 s Phantom Cut buff with this weapon: cast (start burst, glow, marker), a full combo and two more swings,
    each real hit followed by its phantom echo about 0.25 s later (echoes overlap the next swing), then the buff ends
    (end fade). A mock buff timer runs top-left."""
    vid, _, _, swings = WEAPONS[weapon]
    scene = arena_scene()
    golem_i, (gax, gay) = load_sprite("golem2_idle_1")
    golem_h, (hax, hay) = load_sprite("golem2_hurt_1")
    hf = (62, 96)
    gx, gy = hf[0] + 22 + GOLEM_LEFT, 96
    chest = (gx - GOLEM_LEFT + 7, gy - 24)
    head_y = hf[1] - 33
    glow = a["glow"][weapon]
    t_cast, t_end = CAST_MS, CAST_MS + BUFF_MS
    swing_ms = 6 * SWING_FRAME_MS + 30
    plan = [(t_cast + 400 + i * swing_ms, i + 1) for i in range(swings)]
    t2 = plan[-1][0] + swing_ms + 700
    plan += [(t2 + i * swing_ms, i + 1) for i in range(2)]
    plan.append((plan[-1][0] + swing_ms + 900, 1))
    plan = [(ts, s) for ts, s in plan if ts + 3 * SWING_FRAME_MS < t_end]
    hits = [ts + 3 * SWING_FRAME_MS for ts, _ in plan]
    echoes = [(h + ECHO_DELAY_MS, s) for h, (_, s) in zip(hits, plan)]
    total = t_end + 4 * 80 + 500
    out: list[tuple[Image.Image, int]] = []
    for t in range(0, total, GIF_STEP):
        # hero frame
        name, n = f"{vid}_idle_right_{(t // 200) % 4 + 1}", 0
        for ts, s in plan:
            if ts <= t < ts + 6 * SWING_FRAME_MS:
                name = f"{vid}_attack{s}_right_{(t - ts) // SWING_FRAME_MS + 1}"
        src, sa = load_sprite(name)
        layers: list[tuple[Grid, int, int]] = []
        hurt = any(0 <= t - h < 160 for h in hits) or any(0 <= t - e - 60 < 180 for e, _ in echoes)
        flash = any(0 <= t - h < GIF_STEP for h in hits) or any(0 <= t - e - 60 < GIF_STEP for e, _ in echoes)
        g, (ax, ay) = (golem_h, (hax, hay)) if hurt else (golem_i, (gax, gay))
        shake = 2 if flash else (1 if hurt else 0)
        layers.append((golem_flash(g) if flash else g, gx - ax + shake, gy - ay))
        layers.append((src, hf[0] - sa[0], hf[1] - sa[1]))
        if t_cast <= t < t_end and name in glow:
            ovs, oa, _, _ = glow[name]
            layers.append((ovs[((t - t_cast) // 80) % GLOW_PHASES], hf[0] - oa[0], hf[1] - oa[1]))
        # echoes: ghost + arc at the phantom's feet, spark on the golem
        for e, s in echoes:
            k = (t - e) // 60
            if 0 <= k < 4:
                gg, ganc, _ = a["ghost"][weapon][s][k]
                px, py = hf[0] + GHOST_OFFSET, hf[1]
                layers.append((gg, px - ganc[0], py - ganc[1]))
                aa = ARC_ANCHORS[weapon]
                layers.append((a["arcs"][weapon][s][k], px - aa[0], py - aa[1]))
            ks = (t - e - 60) // 55
            if 0 <= ks < 5:
                layers.append((a["spark"][ks], chest[0] - SPARK_A[0], chest[1] - SPARK_A[1]))
        for h in hits:  # the real hit's small star
            if 0 <= t - h < 2 * GIF_STEP:
                sg = blank(16, 16)
                star(sg, 8, 8, 2, "1", "p", "o")
                layers.append((sg, chest[0] - 8, chest[1] - 8))
        if t_cast <= t < t_cast + 5 * 60:
            layers.append((a["start"][(t - t_cast) // 60], hf[0] - START_A[0], hf[1] - START_A[1]))
        if t_end <= t < t_end + 4 * 80:
            layers.append((a["end"][(t - t_end) // 80], hf[0] - START_A[0], hf[1] - START_A[1]))
        if t_cast + 120 <= t < t_end:
            layers.append((a["marker"][(t // 120) % 4], hf[0] + 1 - MARK_A[0], head_y - MARK_A[1]))
        left = 0.0 if t < t_cast else max(0.0, 1 - (t - t_cast) / BUFF_MS)
        layers.append((buff_bar(left), 4, 4))
        im = scene.copy()
        sgrid = blank(SW_, SH_)
        for g2, x, y in layers:
            paste(sgrid, g2, x, y)
        im.alpha_composite(to_image(sgrid))
        out.append((im, GIF_STEP))
    save_gif(out, f"phantom_cut_{weapon}.gif", f"phantom_cut_{weapon}_strip.png")


if __name__ == "__main__":
    raise SystemExit(main())
