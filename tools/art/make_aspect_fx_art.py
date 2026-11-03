"""The aspects' effects redrawn in the Star Staff's style, phase 3 of the effects redo (owner 2026-11-02: "i like the effects of
the staff skill, can you redo all effects, aspects, attacks of mobs and hero except the golem"; "Yes, start phase 3").

The faint dotted outlines become solid glowing shapes with palette ramps, hard alpha and dithered fades (tools/art/staff_fx.py).
Every frame keeps its name, count, size and anchor, so the game and the editable SpriteFrames keep working. The live part
(motes, sparks, dust, rings on the ground, light) is presentation/common/aspect_view.gd.

    Phantom Cut   fx_phantom_start_1..5   48x48 @24,44   lilac flames rising round his feet into a ring
                  fx_phantom_end_1..4     48x48 @24,44   the ring sinking and going out
                  fx_phantom_marker_1..4  16x16 @8,15    a lilac diamond over the marked target, pulsing
                  fx_phantom_spark_1..5   32x32 centre   a lilac forked spark where an echo lands
    Echo Step     fx_echo_vanish_1..5     48x48 @24,42   a teal column and ring as the echo or he leaves
                  fx_echo_arrive_1..5     48x48 @24,42   the same in reverse as he arrives
                  fx_echo_bubble_1..4     40x48 @20,44   the shell round the echo, shimmering
                  fx_echo_dust_1..5       32x16 @16,12   dust at the feet
                  fx_echo_trail_h/v/d/head_1..4         the light the recall leaves (tiles along the path, and its head)
    Lantern       fx_lantern_pool_idle_1..4  96x48 centre  the lantern's ring of light on the ground
                  fx_lantern_pool_open_1..3  96x48 centre  the ring opening when it is placed
                  fx_lantern_pool_pulse_1..5 96x48 centre  a pulse running out across the ring
                  fx_lantern_motes_1..6   32x40 @16,38   motes rising off the lantern
                  fx_lantern_spark_1..6   32x32 centre   a spark of light
    Sprint        fx_sprint_start_1..5    48x40 @24,35   a burst of wind and dust as he sets off
                  fx_sprint_end_1..4      48x40 @24,35   the wind dying
                  fx_sprint_lines_1..4    48x40 @36,35   speed lines behind him
                  fx_sprint_wind_1..4     40x40 @14,35   wind curling off his back
                  fx_sprint_dust_1..6     40x16 @28,12   dust behind his feet
    Stone Ward    fx_ward_barrier_1..6    48x48 @16,44   the ward's shield of light before him
                  fx_ward_absorb_1..4     48x48 @16,44   the shield taking a blow
                  fx_ward_store_1..3_1..4 48x48 @16,44   the shield holding one, two or three stored blows
                  fx_ward_block_1..5      32x32 centre   the spark where a blow hits it
                  fx_ward_cracks_1..4     96x48 centre   glowing cracks in the ground where it is released
                  fx_ward_shockwave_1..8  144x80 @72,50   the released ring running out across the ground
(The lantern itself, the stone slabs, the echo's silhouettes, the Phantom ghosts and arcs, the per-pose glow outlines and the
three skill strikes keep their art: they already read well and their live part is new.)

    python tools/art/make_aspect_fx_art.py            # writes art/src; then validate, build and preview the art
    python tools/art/make_aspect_fx_art.py --sheet    # also art/reference/aspect_fx_v1/frames.png (every frame at 3x)
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import staff_fx as F  # noqa: E402
from make_hero_fx_art import diamond, dots, ring, spike, write_fixed  # noqa: E402
from make_form_fx_art import bolt, jag, puff  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "art/reference/aspect_fx_v1/frames.png"

LILAC = ["1", "p", "v", "l", "k"]   # Phantom Cut
TEAL = ["1", "p", "u", "t", "k"]    # Echo Step, Stone Ward, the lantern's light
WIND = ["1", "p", "o", "n", "m"]    # Sprint


def ground_band(c: F.Canvas, cx: float, cy: float, rx: float, ry: float, width: float, colours: list[str], power: float,
                fill: float = 0.0) -> None:
    """A flat band of light on the ground (an ellipse rx by ry, `width` px thick toward the inside), bright at its outer edge,
    cooling inward; `fill` (0..1) dithers a faint floor of light inside it; `power` fades it all."""
    if power <= 0:
        return
    steps = int((rx + ry) * 6)
    for k in range(steps):
        a = k / steps * math.tau
        for d in range(int(width) + 1):
            f = d / max(1.0, width)
            x = cx + math.cos(a) * (rx - d)
            y = cy + math.sin(a) * (ry - d * ry / rx)
            sym = colours[min(4, 1 + int(f * 3) + (0 if power > 0.6 else 1))]
            c.put(x, y, sym, power * F.clamp01((1.1 - f) / 0.5))
        c.put(cx + math.cos(a) * (rx + 1), cy + math.sin(a) * (ry + 1), colours[3], power * 0.5)
    if fill > 0:
        c.disc(cx, cy, rx - width, ry - width * ry / rx, colours[3], fill * power, over=False)


def column(c: F.Canvas, cx: float, foot: float, height: float, width: float, colours: list[str], power: float) -> None:
    """A pillar of light standing on `foot`, fading toward its top."""
    for y in range(int(height)):
        f = y / height
        half = width / 2 * (1 - 0.4 * f)
        for x in range(int(cx - half - 1), int(cx + half + 2)):
            d = abs(x - cx) / max(0.6, half)
            band = 0 if d < 0.4 else 1 if d < 0.9 else 2 if d < 1.4 else None
            if band is not None:
                c.put(x, foot - y, colours[min(4, band + int(f * 2))], power * F.clamp01((1 - f) / 0.35))


# ---------------------------------------------------------------------------------------------------------- Phantom Cut
def phantom_start(i: int) -> F.Sprite:
    c = F.Canvas(48, 48, 24, 44)
    rng = random.Random(10 + i)
    power = [0.6, 1.0, 1.0, 0.8, 0.5][i]
    ground_band(c, 24, 42, 9 + i * 2.5, 3 + i * 0.8, 2, LILAC, power)
    for k in range(5 + i):  # lilac tongues rising round his feet
        x = 24 + rng.uniform(-11, 11)
        h = rng.uniform(6, 14) * (0.6 + 0.2 * i)
        for s in range(int(h)):
            f = s / h
            c.put(x + math.sin(s * 0.6 + k) * 0.8, 42 - s, F.ramp(LILAC, 0.2 + f * 0.7), power * F.clamp01((1 - f) / 0.4))
    return c.sprite()


def phantom_end(i: int) -> F.Sprite:
    c = F.Canvas(48, 48, 24, 44)
    power = [1.0, 0.75, 0.5, 0.25][i]
    ground_band(c, 24, 42, 16 - i * 3, 5 - i * 0.9, 2, LILAC, power)
    dots(c, 24, 36 - i * 3, 9 - i, 5, ["p", "v"], power, i * 30)
    return c.sprite()


def phantom_marker(i: int) -> F.Sprite:
    c = F.Canvas(16, 16, 8, 15)
    r = [4, 5, 6, 5][i]
    diamond(c, 8, 7, r, "v")
    diamond(c, 8, 7, r - 1, "p" if i in (1, 2) else "v")
    c.put(8, 7, "1")
    c.put(8, 14, "v")
    return c.sprite()


def phantom_spark(i: int) -> F.Sprite:
    c = F.Canvas(32, 32, 16, 16)
    rng = random.Random(40 + i)
    if i == 0:
        c.disc(16, 16, 3, 3, "1")
        c.halo("p")
        c.halo("v", 0.6)
    elif i in (1, 2):
        for k in range(5):
            a = k * math.tau / 5 + rng.uniform(-0.2, 0.2) + i * 0.4
            bolt(c, jag(rng, 16, 16, 16 + math.cos(a) * (9 + i * 3), 16 + math.sin(a) * (9 + i * 3), 3, 2), 1.0 if i == 1 else 0.8, LILAC)
        c.disc(16, 16, 1.5, 1.5, "1")
    else:
        ring(c, 16, 16, 10 + i * 2, "v", 1.0 if i == 3 else 0.5, 6, 24, i * 15)
    return c.sprite()


# ---------------------------------------------------------------------------------------------------------- Echo Step
def echo_vanish(i: int, arrive: bool = False) -> F.Sprite:
    """A teal column and ring where the echo or he leaves (arrive: the same played backwards)."""
    c = F.Canvas(48, 48, 24, 42)
    k = 4 - i if arrive else i
    power = [1.0, 1.0, 0.8, 0.55, 0.3][k]
    column(c, 24, 41, 34 - k * 4, 9 - k * 1.5, TEAL, power)
    ground_band(c, 24, 41, 8 + k * 3, 2.6 + k * 0.9, 2, TEAL, power)
    if k >= 2:
        dots(c, 24, 26, 9 + k * 2, 6, ["p", "u"], power, k * 20)
    return c.sprite()


def echo_bubble(i: int) -> F.Sprite:
    """The shell round the echo: a tall oval of light, bright on its rim, a highlight running round it."""
    c = F.Canvas(40, 48, 20, 44)
    cx, cy, rx, ry = 20, 24, 14, 20
    for k in range(240):
        a = k / 240 * math.tau
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        glint = math.cos(a - (i * math.pi / 2 + 0.6))
        c.put(x, y, "p" if glint > 0.85 else "u")
        c.put(cx + math.cos(a) * (rx - 1), cy + math.sin(a) * (ry - 1), "t", 0.5)
    ground_band(c, 20, 43, 9, 2.5, 1, TEAL, 0.8)
    return c.sprite()


def echo_dust(i: int) -> F.Sprite:
    c = F.Canvas(32, 16, 16, 12)
    for dx in (-1, 1):
        puff(c, 16 + dx * (3 + i * 2.2), 10.5 - i * 0.5, 2.0 + i * 0.45, 1.0 if i < 4 else 0.5)
    return c.sprite()


def echo_trail(kind: str, i: int) -> F.Sprite:
    """A tile of the light the recall leaves along its path: h (16x8 @0,4), v (8x16 @4,0), d (16x16 @0,0) and the head."""
    power = [1.0, 0.8, 0.55, 0.3][i]
    if kind == "head":
        c = F.Canvas(16, 16, 8, 8)
        c.disc(8, 8, 3 - i * 0.5, 3 - i * 0.5, "1", power)
        c.halo("p", power)
        c.halo("u", power * 0.6)
        return c.sprite()
    if kind == "h":
        c = F.Canvas(16, 8, 0, 4)
        pts = [(x, 4) for x in range(16)]
    elif kind == "v":
        c = F.Canvas(8, 16, 4, 0)
        pts = [(4, y) for y in range(16)]
    else:
        c = F.Canvas(16, 16, 0, 0)
        pts = [(x, x) for x in range(16)]
    for x, y in pts:
        c.put(x, y, "p" if i < 2 else "u", power)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.put(x + dx, y + dy, "u" if i < 2 else "t", power * 0.7, over=False)
    return c.sprite()


# ---------------------------------------------------------------------------------------------------------- Spirit Lantern
def pool(i: int, kind: str) -> F.Sprite:
    """The lantern's ring of light on the ground (96x48): idle (a slow shimmer), open (growing out), pulse (a wave runs out)."""
    c = F.Canvas(96, 48, 48, 24)
    rx, ry = 44, 20
    if kind == "open":
        f = (i + 1) / 3
        ground_band(c, 48, 24, rx * f, ry * f, 3, TEAL, 1.0, 0.12 * f)
    elif kind == "idle":
        ground_band(c, 48, 24, rx, ry, 3, TEAL, 0.9, 0.1)
        for k in range(10):  # motes of light sitting in the ring, twinkling in turn
            a = k / 10 * math.tau + 0.3
            if (k + i) % 3 == 0:
                c.put(48 + math.cos(a) * rx * 0.6, 24 + math.sin(a) * ry * 0.6, "p")
    else:
        ground_band(c, 48, 24, rx, ry, 3, TEAL, 0.9, 0.1)
        f = (i + 1) / 5
        ground_band(c, 48, 24, rx * f, ry * f, 2, ["1", "1", "p", "u", "t"], 1.0 - 0.6 * f)
    return c.sprite()


def lantern_motes(i: int) -> F.Sprite:
    c = F.Canvas(32, 40, 16, 38)
    rng = random.Random(700)
    for k in range(7):
        x0 = 16 + rng.uniform(-9, 9)
        y = 30 - ((rng.uniform(0, 26) + i * 5) % 30)
        sym = "1" if (k + i) % 4 == 0 else rng.choice(["p", "u"])
        c.put(x0 + math.sin(i * 0.8 + k) * 1.2, y, sym)
        if sym == "1":
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c.put(x0 + math.sin(i * 0.8 + k) * 1.2 + dx, y + dy, "u", 0.8)
    return c.sprite()


def lantern_spark(i: int) -> F.Sprite:
    c = F.Canvas(32, 32, 16, 16)
    if i == 0:
        c.disc(16, 16, 2.5, 2.5, "1")
        c.halo("p")
    elif i < 4:
        for k in range(4):
            spike(c, 16, 16, k * math.pi / 2 + i * 0.2, 2 + i, 6 + i * 2, TEAL)
        c.disc(16, 16, 1.5, 1.5, "1")
    else:
        dots(c, 16, 16, 9 + i, 6, ["u", "t"], 0.8 if i == 4 else 0.45, i * 25)
    return c.sprite()


# ---------------------------------------------------------------------------------------------------------- Sprint
def streaks(c: F.Canvas, x_front: float, rows: list[tuple[float, float]], power: float, cut: float = 0.0) -> None:
    for y, ln in rows:
        for s in range(int(ln)):
            f = s / ln
            if f < cut:
                continue
            c.put(x_front - s, y, F.ramp(WIND, f * 0.8), power * F.clamp01((1 - f) / 0.35))


def sprint_start(i: int) -> F.Sprite:
    c = F.Canvas(48, 40, 24, 35)
    power = [1.0, 1.0, 0.85, 0.6, 0.35][i]
    streaks(c, 30, [(14, 10 + i * 4), (20, 14 + i * 4), (26, 12 + i * 4), (31, 8 + i * 3)], power, cut=max(0, (i - 2) * 0.25))
    ground_band(c, 24, 34, 6 + i * 3, 2 + i * 0.6, 1, WIND, power)
    for dx in (-8, -14):
        if i < 4:
            puff(c, 24 + dx - i * 2, 33 - i * 0.6, 2 + i * 0.5, 1.0 if i < 3 else 0.5)
    return c.sprite()


def sprint_end(i: int) -> F.Sprite:
    c = F.Canvas(48, 40, 24, 35)
    power = [0.9, 0.7, 0.45, 0.25][i]
    ground_band(c, 24, 34, 12 - i * 2, 3.5 - i * 0.6, 1, WIND, power)
    dots(c, 24, 22, 10 - i, 6, ["o", "n"], power, i * 30)
    return c.sprite()


def sprint_lines(i: int) -> F.Sprite:
    c = F.Canvas(48, 40, 36, 35)
    rng = random.Random(900 + i)
    rows = [(y + rng.randint(-1, 1), rng.randint(10, 22)) for y in (10, 15, 21, 27, 32)]
    streaks(c, 30 - i, rows, 1.0)
    return c.sprite()


def sprint_wind(i: int) -> F.Sprite:
    """Wind curling off his back: two hooked streaks, rolling round over 4 frames."""
    c = F.Canvas(40, 40, 14, 35)
    for k, (cy, r) in enumerate(((16, 7), (26, 6))):
        a0 = i * 0.6 + k
        for s in range(18):
            f = s / 17
            a = a0 + f * 3.4
            c.put(10 + math.cos(a) * r * (1 - 0.3 * f) - f * 6, cy + math.sin(a) * r * 0.8, F.ramp(WIND, f * 0.8), F.clamp01((1 - f) / 0.4))
    return c.sprite()


def sprint_dust(i: int) -> F.Sprite:
    c = F.Canvas(40, 16, 28, 12)
    for k in range(3):
        x = 26 - k * 7 - i * 1.5
        r = 1.6 + k * 0.5 + i * 0.35
        puff(c, x, 11 - k * 0.4 - i * 0.4, r, 1.0 if i < 4 else 0.5)
    return c.sprite()


# ---------------------------------------------------------------------------------------------------------- Stone Ward
def shield(c: F.Canvas, power: float, thick: float, glints: int = 0, crack: float = 0.0) -> None:
    """The ward: a tall curved shield of teal light before him (48x48, his feet at 16,44; it stands at x 30)."""
    cx, cy, rx, ry = 22, 26, 12, 19
    for k in range(200):
        f = k / 199
        a = -math.pi * 0.42 + f * math.pi * 0.84
        x0, y0 = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        edge = math.sin(f * math.pi)
        for d in range(int(thick * edge) + 1):
            g = d / max(1.0, thick * edge)
            sym = TEAL[min(4, (0 if g < 0.2 and edge > 0.5 else 1) + int(g * 2.5))]
            c.put(x0 - d * 0.8, y0, sym, power * F.clamp01((1.1 - g) / 0.5))
    for g in range(glints):  # a bright pip per stored blow
        y = 16 + g * 9
        c.put(cx + rx - 1, y, "1")
        c.put(cx + rx - 2, y, "p")
        c.put(cx + rx - 1, y + 1, "p")
    if crack > 0:
        for s in range(int(14 * crack)):
            c.put(cx + rx - 3 - (s % 3), 18 + s, "t")


def ward_barrier(i: int) -> F.Sprite:
    c = F.Canvas(48, 48, 16, 44)
    shield(c, [0.4, 0.75, 1.0, 1.0, 1.0, 1.0][i], 2.5 + min(i, 3) * 0.6)
    if i >= 3:
        y = 12 + (i - 3) * 9  # a glint running down it
        c.put(33, y, "1")
        c.put(33, y + 1, "p")
    return c.sprite()


def ward_absorb(i: int) -> F.Sprite:
    c = F.Canvas(48, 48, 16, 44)
    shield(c, 1.0, 4.5 - i * 0.6)
    if i < 2:
        ring(c, 34, 26, 4 + i * 4, "p", 1.0, 6, 20, i * 20)
        c.put(34, 26, "1")
    return c.sprite()


def ward_store(level: int, i: int) -> F.Sprite:
    c = F.Canvas(48, 48, 16, 44)
    shield(c, [0.85, 1.0, 1.0, 0.9][i], 3.0 + level * 0.4, glints=level, crack=0.0 if level < 3 else 0.6)
    return c.sprite()


def ward_block(i: int) -> F.Sprite:
    c = F.Canvas(32, 32, 16, 16)
    if i == 0:
        c.disc(16, 16, 3, 3, "1")
        c.halo("p")
        c.halo("u", 0.6)
    elif i < 3:
        for k in range(6):
            spike(c, 16, 16, k * math.pi / 3 + i * 0.3, 2 + i * 2, 7 + i * 3, TEAL)
        c.disc(16, 16, 1.5, 1.5, "1")
    else:
        dots(c, 16, 16, 11 + i, 6, ["u", "t"], 0.8 if i == 3 else 0.45, i * 20)
    return c.sprite()


def ward_cracks(i: int) -> F.Sprite:
    """Glowing cracks in the ground where the ward is released: bright first, cooling to dark seams."""
    c = F.Canvas(96, 48, 48, 24)
    rng = random.Random(1234)
    glow = ["1", "p", "u", "t"][i]
    for k in range(7):
        a = k / 7 * math.tau + rng.uniform(-0.25, 0.25)
        ln = rng.uniform(26, 42)
        pts = jag(rng, 48, 24, 48 + math.cos(a) * ln, 24 + math.sin(a) * ln * 0.42, 4, 3)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = int(max(abs(bx - ax), abs(by - ay))) + 1
            for s in range(n + 1):
                x, y = ax + (bx - ax) * s / n, ay + (by - ay) * s / n
                c.put(x, y + 1, "0", 0.9)
                c.put(x, y, glow if i < 3 else "e", [1.0, 1.0, 0.8, 0.6][i])
    return c.sprite()


def ward_shockwave(i: int) -> F.Sprite:
    """The released ward runs out across the ground as a ring of light with stones kicked up on it (144x80 @72,50)."""
    c = F.Canvas(144, 80, 72, 50)
    f = (i + 1) / 8
    rx, ry = 12 + 56 * F.ease_out(f), 5 + 22 * F.ease_out(f)
    ground_band(c, 72, 50, rx, ry, 4 - f * 2, TEAL, 1.0 - 0.75 * f, 0.06 * (1 - f))
    rng = random.Random(55)
    for k in range(10):  # stones kicked up on the ring's front
        a = k / 10 * math.tau + rng.uniform(-0.2, 0.2)
        x, y = 72 + math.cos(a) * rx, 50 + math.sin(a) * ry - rng.uniform(2, 6) * math.sin(f * math.pi)
        if i < 6:
            c.put(x, y, "g")
            c.put(x + 1, y, "f")
            c.put(x, y - 1, "i")
    return c.sprite()


# ---------------------------------------------------------------------------------------------------------- main
def families() -> list[tuple[str, list[F.Sprite]]]:
    return [
        ("fx_phantom_start", [phantom_start(i) for i in range(5)]),
        ("fx_phantom_end", [phantom_end(i) for i in range(4)]),
        ("fx_phantom_marker", [phantom_marker(i) for i in range(4)]),
        ("fx_phantom_spark", [phantom_spark(i) for i in range(5)]),
        ("fx_echo_vanish", [echo_vanish(i) for i in range(5)]),
        ("fx_echo_arrive", [echo_vanish(i, True) for i in range(5)]),
        ("fx_echo_bubble", [echo_bubble(i) for i in range(4)]),
        ("fx_echo_dust", [echo_dust(i) for i in range(5)]),
        ("fx_echo_trail_h", [echo_trail("h", i) for i in range(4)]),
        ("fx_echo_trail_v", [echo_trail("v", i) for i in range(4)]),
        ("fx_echo_trail_d", [echo_trail("d", i) for i in range(4)]),
        ("fx_echo_trail_head", [echo_trail("head", i) for i in range(4)]),
        ("fx_lantern_pool_idle", [pool(i, "idle") for i in range(4)]),
        ("fx_lantern_pool_open", [pool(i, "open") for i in range(3)]),
        ("fx_lantern_pool_pulse", [pool(i, "pulse") for i in range(5)]),
        ("fx_lantern_motes", [lantern_motes(i) for i in range(6)]),
        ("fx_lantern_spark", [lantern_spark(i) for i in range(6)]),
        ("fx_sprint_start", [sprint_start(i) for i in range(5)]),
        ("fx_sprint_end", [sprint_end(i) for i in range(4)]),
        ("fx_sprint_lines", [sprint_lines(i) for i in range(4)]),
        ("fx_sprint_wind", [sprint_wind(i) for i in range(4)]),
        ("fx_sprint_dust", [sprint_dust(i) for i in range(6)]),
        ("fx_ward_barrier", [ward_barrier(i) for i in range(6)]),
        ("fx_ward_absorb", [ward_absorb(i) for i in range(4)]),
        ("fx_ward_store_1", [ward_store(1, i) for i in range(4)]),
        ("fx_ward_store_2", [ward_store(2, i) for i in range(4)]),
        ("fx_ward_store_3", [ward_store(3, i) for i in range(4)]),
        ("fx_ward_block", [ward_block(i) for i in range(5)]),
        ("fx_ward_cracks", [ward_cracks(i) for i in range(4)]),
        ("fx_ward_shockwave", [ward_shockwave(i) for i in range(8)]),
    ]


def main() -> int:
    written: list[str] = []
    rows = families()
    for fam, frames in rows:
        for i, s in enumerate(frames):
            write_fixed(f"{fam}_{i + 1}", s, written)
    print(f"wrote {len(written)} frames")
    if "--sheet" in sys.argv:
        zoom = 3
        cell = max(max(s.img.width for s in r) for _, r in rows) * zoom + 6
        heights = [max(s.img.height for s in r) * zoom + 6 for _, r in rows]
        out = Image.new("RGB", (8 * cell, sum(heights)), (34, 38, 48))
        y = 0
        for (_, r), h in zip(rows, heights):
            for k, s in enumerate(r[:8]):
                img = s.img.resize((s.img.width * zoom, s.img.height * zoom), Image.NEAREST)
                out.paste(img, (k * cell + 3, y + 3), img)
            y += h
        SHEET.parent.mkdir(parents=True, exist_ok=True)
        out.save(SHEET)
        print("sheet:", SHEET, out.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
