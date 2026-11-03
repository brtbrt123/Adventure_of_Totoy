"""The weapon forms' effects redrawn in the Star Staff's style, phase 2 of the effects redo (owner 2026-11-02: "i like the effects
of the staff skill, can you redo all effects, aspects, attacks of mobs and hero except the golem"; "Yes, start phase 2").

The Black Katana form, the daggers' Lightning Form and the chain scythe's Reaper's Coil. Every frame keeps its name, count, size
and anchor, so the game and the editable SpriteFrames keep working; each is drawn in code with tools/art/staff_fx.py (Totoy 36,
hard alpha, ordered dithering for fades, glow rims, noise fire). The live part (embers, crackles, sparks, dust, rings on the
ground, light) is presentation/common/form_view.gd.

    Black Katana   fx_black_aura_back/front_1..6   64x64 @32,56   black fire with violet rims, behind him and around his feet
    Lightning      fx_lightning_aura_back/front_1..10  64x64 @32,56   arcs crackling over him and at his feet
                   fx_lightning_afterimage_1..6   64x64 @32,56   his outline left as streaks where he blinked from
                   fx_lightning_blink_1..5        32x32 @16,30   the flash where he leaves or arrives
                   fx_lightning_spark_1..6        32x32 centre   a spark of forked rays
                   fx_lightning_cut_<dir>_1..4    64x64 centre   the cut through the target, 8 directions
                   fx_lightning_chain_1..4        32x16 @0,8     a tile of the bolt between blink points (ends meet at y 8)
                   fx_lightning_ground_1..4       32x16 centre   the scorch a sky strike leaves (drawn at 2x)
                   fx_lightning_strike_1..8       32x160 @16,152 the sky strike: leader, bolt, burst, ring, fragments, embers
    Reaper's Coil  fx_scythe_spin_back/front_1..4 96x64 @48,56   the scythe swung round on its chain (far and near halves)
                   fx_scythe_flying_1..8          32x32 centre   the thrown scythe turning
                   fx_chain_link_1..4             32x8 @0,4      chain links with a running glint (tiled along the chain)
                   fx_chain_hook_1..5             32x32 centre   the bite (1-3) and the clink sparks (4-5)
                   fx_chain_stagger_1..6          32x32 centre   the stagger burst on the dragged target's chest
                   fx_chain_stars_1..4            32x16 @16,12   dizzy stars
                   fx_chain_land_1..4             32x24 @16,18   the dust where a missed hook lands
                   fx_chain_dust_1..4             64x16 @8,14    dust kicked up by a dragged target's feet
                   fx_chain_scuff_1..4            32x16 centre   the drag marks on the ground
                   fx_chain_pull_1..4             64x48 @12,44   speed lines behind the dragged target
(fx_black_slash, fx_chain_whip and fx_scythe_arc_* are not drawn by the game any more and are left as they are.)

    python tools/art/make_form_fx_art.py            # writes art/src; then validate, build and preview the art
    python tools/art/make_form_fx_art.py --sheet    # also art/reference/form_fx_v1/frames.png (every frame at 3x, for review)
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import staff_fx as F  # noqa: E402
from make_hero_fx_art import dots, ring, spike, write_fixed  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "art/reference/form_fx_v1/frames.png"

BOLT = ["1", "p", "o", "n", "m"]      # lightning: white core to blue
VOID = ["0", "k", "l", "v", "p"]      # black fire: ink core, violet rim, pale tips
TEAL = ["1", "p", "u", "t", "k"]      # the coil's scythe and magic
STEEL = ["j", "i", "h", "g", "f"]     # chain links
DUST = ["j", "i", "h"]


# --------------------------------------------------------------------------------------------------------- helpers
def jag(rng: random.Random, x0: float, y0: float, x1: float, y1: float, rough: float, depth: int = 4) -> list[tuple[float, float]]:
    """A jagged path from (x0, y0) to (x1, y1) by midpoint displacement (a lightning bolt's shape)."""
    pts = [(x0, y0), (x1, y1)]
    amp = rough
    for _ in range(depth):
        out = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            mx, my = (ax + bx) / 2, (ay + by) / 2
            dx, dy = bx - ax, by - ay
            ln = math.hypot(dx, dy) or 1.0
            off = rng.uniform(-amp, amp)
            out += [(mx - dy / ln * off, my + dx / ln * off), (bx, by)]
        pts = out
        amp *= 0.55
    return pts


def bolt(c: F.Canvas, pts: list[tuple[float, float]], power: float = 1.0, colours: list[str] = BOLT, thick: bool = False) -> None:
    """A bolt along `pts`: a white core, a pale body around it, a dithered blue halo; `power` fades it (1 = full)."""
    if power <= 0:
        return
    body = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = int(max(abs(bx - ax), abs(by - ay))) + 1
        for i in range(n + 1):
            body.append((ax + (bx - ax) * i / n, ay + (by - ay) * i / n))
    lead = 0 if power > 0.7 else 1 if power > 0.4 else 2
    for x, y in body:  # halo first, core last
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, 1), (1, -1), (-1, -1)):
            c.put(x + dx, y + dy, colours[min(4, lead + 3)], 0.4 * power, over=False)
    for x, y in body:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if thick else ((1, 0), (0, 1)):
            c.put(x + dx, y + dy, colours[min(4, lead + 1 + (0 if thick else 1))], min(1.0, power * 1.2))
    for x, y in body:
        c.put(x, y, colours[lead], min(1.0, power * 1.5))


def branches(c: F.Canvas, rng: random.Random, pts: list[tuple[float, float]], n: int, length: float, power: float) -> None:
    for _ in range(n):
        x, y = pts[rng.randrange(1, len(pts) - 1)]
        a = rng.uniform(0, math.tau)
        ln = length * rng.uniform(0.5, 1.0)
        bolt(c, jag(rng, x, y, x + math.cos(a) * ln, y + math.sin(a) * ln, ln * 0.3, 2), power * 0.7)


def puff(c: F.Canvas, x: float, y: float, r: float, alpha: float = 1.0) -> None:
    """A dust puff: a solid lumpy blob, darker underneath and lighter on top."""
    c.disc(x, y + r * 0.15, r, r * 0.8, DUST[2], alpha)
    c.disc(x - r * 0.15, y - r * 0.05, r * 0.85, r * 0.65, DUST[1], alpha)
    c.disc(x - r * 0.3, y - r * 0.3, r * 0.5, r * 0.4, DUST[0], alpha)


def flame_field(w: int, h: int, t: float, seed: int, base: float, height: float, half: float, cx: float) -> np.ndarray:
    """Heat of a flame sheet rising from y = `base` (`half` wide at the base, `height` tall), turbulent and scrolling up with t."""
    xs, ys = F.grid(w, h)
    rise = (base - ys) / height  # 0 at the base, 1 at the top
    width = half * (1.0 - 0.75 * np.clip(rise, 0, 1)) + 0.5
    lateral = 1.0 - np.abs(xs - cx) / width
    n = F.fbm(xs * 0.2, (ys + t * 10.0) * 0.16, seed, 3)
    tongue = F.fbm(xs * 0.11 + 3.1, (ys + t * 14.0) * 0.07, seed + 9, 2)
    heat = lateral * 0.9 + (n - 0.5) * 0.9 + (tongue - 0.5) * 0.8 - np.clip(rise, 0, None) * 0.95
    heat[ys > base + 1.5] = -1.0
    return heat


# --------------------------------------------------------------------------------------------------------- Black Katana
def black_aura(i: int, front: bool) -> F.Sprite:
    """Black fire: tongues of flame that sway and flicker, an ink core, navy and blue inside, a violet rim and pale tips, embers
    above. Back: tall tongues behind him, the middle one past his head; front: low tongues round his feet. Loops over 6 frames."""
    c = F.Canvas(64, 64, 32, 56)
    xs, ys = F.grid(64, 64)
    t = i / 6.0
    if front:
        base, tongues = 58.0, [(-14, 8, 4.0), (-7, 6, 3.5), (1, 9, 4.0), (8, 7, 4.0), (15, 6, 3.5)]
    else:
        base, tongues = 56.0, [(-12, 20, 4.0), (-6, 28, 4.5), (0, 34, 5.0), (6, 27, 4.5), (12, 19, 4.0)]
    heat = np.full((64, 64), -1.0)
    tips = []
    for k, (dx, height, half) in enumerate(tongues):
        phase = t * math.tau + k * 1.7
        h = height * (0.82 + 0.18 * math.sin(phase * (1 + k % 2)))
        rise = (base - ys) / h
        cx = 32 + dx + 3.0 * np.sin(phase + ys * 0.18) * np.clip(rise, 0, 1) ** 0.8
        width = half * np.sqrt(np.clip(1.0 - np.clip(rise, 0, 1) ** 1.6, 0, 1))  # a round body tapering to a tip
        tongue = 1.0 - np.abs(xs - cx) / np.maximum(width, 0.35)
        tongue[(rise < 0) | (rise > 1)] = -1.0
        heat = np.maximum(heat, tongue)
        tips.append((32 + dx + 3.0 * math.sin(phase + (base - h) * 0.18), base - h))
    heat = heat + (F.fbm(xs * 0.3, (ys + t * 14.0) * 0.22, 23 + (9 if front else 0), 2) - 0.5) * 0.45
    # Hollow fire: the violet and blue rims solid, the dark core only every few pixels (Bayer), so the Black Form's dark
    # silhouette of him still reads inside it; the front layer thinner still, so his legs show.
    core_alpha = np.full((64, 64), 0.22 if front else 0.35)
    c.field(heat, [(0.62, "0"), (0.44, "k")], core_alpha)
    rim = np.where(heat > 0.44, -1.0, heat)
    c.field(rim, [(0.26, "l"), (0.06, "v")], np.full((64, 64), 0.75) if front else None)
    for x, y in tips:  # pale tips where the tongues lick out
        c.put(x, y + 1, "p")
        c.put(x, y + 2, "v")
    rng = random.Random(100 + i + (50 if front else 0))
    for _ in range(2 if front else 4):  # embers drifting up out of it
        c.put(rng.uniform(20, 44), rng.uniform(34, 44) if front else rng.uniform(4, 24), rng.choice(["v", "p"]))
    return c.sprite()


# ------------------------------------------------------------------------------------------------------------- Lightning
def lightning_aura(i: int, front: bool) -> F.Sprite:
    """Arcs crackling over him (back: shoulders to head and out) or at his feet (front); a new pattern every frame."""
    c = F.Canvas(64, 64, 32, 56)
    rng = random.Random(500 + i * 7 + (300 if front else 0))
    if front:
        for _ in range(2):
            x0 = rng.uniform(18, 30)
            x1 = rng.uniform(34, 46)
            pts = jag(rng, x0, rng.uniform(52, 57), x1, rng.uniform(52, 57), 4.0, 3)
            bolt(c, pts, rng.uniform(0.7, 1.0))
        if i % 3 == 0:
            dots(c, 32, 55, 13, 5, ["p", "o"], 1.0, rng.uniform(0, 360))
    else:
        for _ in range(2 + i % 2):
            a = rng.uniform(math.pi * 1.05, math.pi * 1.95)  # upward
            x0, y0 = 32 + rng.uniform(-6, 6), rng.uniform(30, 40)
            ln = rng.uniform(12, 22)
            pts = jag(rng, x0, y0, x0 + math.cos(a) * ln, y0 + math.sin(a) * ln, ln * 0.35, 3)
            bolt(c, pts, rng.uniform(0.6, 1.0))
            if rng.random() < 0.6:
                branches(c, rng, pts, 1, 6, 0.8)
        for _ in range(3):
            c.put(32 + rng.uniform(-16, 16), rng.uniform(12, 40), rng.choice(["1", "p", "o"]))
    return c.sprite()


def lightning_afterimage(i: int) -> F.Sprite:
    """His outline left as horizontal streaks (head, shoulders, body, legs), thinning and cooling over 6 frames."""
    c = F.Canvas(64, 64, 32, 56)
    profile = [(26, 3), (28, 4), (30, 3), (33, 6), (36, 7), (39, 7), (42, 6), (45, 5), (48, 5), (51, 6), (54, 6)]
    fade = [1.0, 0.85, 0.65, 0.45, 0.3, 0.15][i]
    shift = i * 2
    for k, (y, half) in enumerate(profile):
        ln = half * 2 + 10 - i
        x0 = 32 - half + shift
        for s in range(int(ln)):
            f = s / ln
            sym = F.ramp(["p", "o", "n", "m"], f * 0.8 + i * 0.12)
            c.put(x0 + s - (k % 3), y, sym, fade * F.clamp01((1 - f) / 0.4 + 0.2))
    return c.sprite()


def lightning_blink(i: int) -> F.Sprite:
    """Where he leaves or arrives: a flash up his height, a forked star at his chest, a ring, fragments."""
    c = F.Canvas(32, 32, 16, 30)
    rng = random.Random(900 + i)
    cx, cy = 16, 17
    if i == 0:
        for y in range(4, 31):
            c.put(cx, y, "1")
            c.put(cx - 1, y, "p", 0.8)
            c.put(cx + 1, y, "p", 0.8)
        c.disc(cx, 29, 5, 1.5, "o")
    elif i == 1:
        c.disc(cx, cy, 3, 3, "1")
        for k in range(6):
            a = k * math.tau / 6 + 0.3
            bolt(c, jag(rng, cx, cy, cx + math.cos(a) * 11, cy + math.sin(a) * 11, 3, 2), 1.0)
    elif i == 2:
        ring(c, cx, cy, 8, "p")
        ring(c, cx, cy, 9, "o", 0.7)
        c.disc(cx, cy, 1.5, 1.5, "1")
        for k in range(4):
            a = k * math.tau / 4 + 0.8
            bolt(c, jag(rng, cx + math.cos(a) * 9, cy + math.sin(a) * 9, cx + math.cos(a) * 14, cy + math.sin(a) * 14, 2, 1), 0.8)
    elif i == 3:
        ring(c, cx, cy, 11, "o", 1.0, 6, 25, rng.uniform(0, 60))
        ring(c, cx, cy, 12, "n", 0.6, 6, 30, rng.uniform(0, 60))
    else:
        dots(c, cx, cy, 13, 8, ["n", "m"], 0.7, 20)
    return c.sprite()


def lightning_spark(i: int) -> F.Sprite:
    c = F.Canvas(32, 32, 16, 16)
    rng = random.Random(1200 + i)
    cx = cy = 16
    if i == 0:
        c.disc(cx, cy, 3, 3, "1")
        c.halo("p")
        c.halo("o", 0.6)
    elif i in (1, 2):
        r = 9 if i == 1 else 13
        for k in range(6):
            a = k * math.tau / 6 + rng.uniform(-0.2, 0.2) + (0.5 if i == 2 else 0)
            bolt(c, jag(rng, cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r, 3, 2), 1.0 if i == 1 else 0.85)
        c.disc(cx, cy, 2 if i == 1 else 1.5, 2 if i == 1 else 1.5, "1")
    elif i == 3:
        for k in range(6):
            a = k * math.tau / 6 + 0.9
            bolt(c, jag(rng, cx + math.cos(a) * 9, cy + math.sin(a) * 9, cx + math.cos(a) * 14, cy + math.sin(a) * 14, 2, 1), 0.6)
    else:
        dots(c, cx, cy, 13 + i, 7, ["o", "n", "m"], 0.8 if i == 4 else 0.5, i * 20)
    return c.sprite()


def lightning_cut(direction: int, i: int) -> F.Sprite:
    """The cut through the target along direction `direction` (0 east, clockwise): a white line that widens into a forked
    bolt with branches, splits into fragments and dies to sparks."""
    c = F.Canvas(64, 64, 32, 32)
    a = direction * math.pi / 4
    dx, dy = math.cos(a), math.sin(a)
    rng = random.Random(2000 + direction * 10 + i)
    half = 26
    x0, y0, x1, y1 = 32 - dx * half, 32 - dy * half, 32 + dx * half, 32 + dy * half
    if i == 0:
        for s in range(-half, half + 1):
            f = (s + half) / (2 * half)
            c.put(32 + dx * s, 32 + dy * s, "1" if f > 0.3 else "p", F.clamp01(f * 2))
            c.put(32 + dx * s - dy, 32 + dy * s + dx, "o", 0.6 * F.clamp01(f * 2))
    elif i == 1:
        pts = jag(rng, x0, y0, x1, y1, 3.0, 4)
        bolt(c, pts, 1.0, thick=True)
        branches(c, rng, pts, 3, 9, 1.0)
        c.disc(32, 32, 2.5, 2.5, "1")
    elif i == 2:
        pts = jag(rng, x0, y0, x1, y1, 4.0, 4)
        n = len(pts)
        for k in range(0, n - 1, 3):  # the bolt breaks into pieces
            bolt(c, pts[k:k + 3], 0.7)
        dots(c, 32, 32, 14, 6, ["p", "o"], 1.0, direction * 45)
    else:
        dots(c, 32, 32, 18, 8, ["n", "m"], 0.6, direction * 45 + 20)
        dots(c, 32 + dx * 10, 32 + dy * 10, 5, 3, ["o"], 0.6, 0)
    return c.sprite()


def lightning_chain(i: int) -> F.Sprite:
    """A 32 px tile of the bolt between two blink points; both ends at y 8 so tiles join along the line."""
    c = F.Canvas(32, 16, 0, 8)
    rng = random.Random(3000 + i)
    pts = jag(rng, 0, 8, 31, 8, 4.5, 4)
    pts[0], pts[-1] = (0, 8), (31, 8)
    bolt(c, pts, 1.0 if i % 2 == 0 else 0.8)
    if i in (1, 3):
        branches(c, rng, pts, 1, 5, 0.7)
    return c.sprite()


def lightning_ground(i: int) -> F.Sprite:
    """The scorch a sky strike leaves: a dark burn with cracks, hot edges cooling, then fading out."""
    c = F.Canvas(32, 16, 16, 8)
    fade = [1.0, 0.9, 0.6, 0.3][i]
    rng = random.Random(77)
    c.disc(16, 8, 10, 4.5, "e", fade)
    c.disc(16, 8, 7, 3.2, "0", fade)
    for k in range(6):
        a = k * math.tau / 6 + rng.uniform(-0.3, 0.3)
        for s in range(5, 14):
            c.put(16 + math.cos(a) * s, 8 + math.sin(a) * s * 0.45, "0" if s < 10 else "e", fade * 0.9)
    if i < 2:  # the hot glow at the rim and in the cracks
        for k in range(10):
            a = k * math.tau / 10
            c.put(16 + math.cos(a) * 7.5, 8 + math.sin(a) * 3.5, "o" if i == 0 else "n", 0.9)
        c.put(16, 8, "p" if i == 0 else "o")
    return c.sprite()


def lightning_strike(i: int) -> F.Sprite:
    """The sky strike, 160 px tall with its foot at (16, 152): 1 flash and leader, 2 leader halfway down, 3-4 the full bolt,
    5 the burst, 6 a wide ring, 7 fragments, 8 embers."""
    c = F.Canvas(32, 160, 16, 152)
    rng = random.Random(4100)
    full = jag(rng, 16 + rng.uniform(-4, 4), 0, 16, 152, 9.0, 6)
    if i == 0:
        for x in range(32):
            c.put(x, 0, "p", 0.5)
            c.put(x, 1, "o", 0.35)
        bolt(c, full[: len(full) // 4], 0.9)
    elif i == 1:
        bolt(c, full[: len(full) // 2], 1.0)
        branches(c, random.Random(4200), full[: len(full) // 2], 2, 10, 0.8)
    elif i in (2, 3):
        bolt(c, full, 1.0, thick=True)
        branches(c, random.Random(4300 + i), full, 4, 12, 1.0)
        c.disc(16, 152, 6, 3, "1")
        c.disc(16, 152, 9, 4, "p", 0.6)
    elif i == 4:
        bolt(c, full[len(full) // 2:], 0.6)
        c.disc(16, 148, 8, 8, "1")
        c.halo("p")
        c.halo("o", 0.6)
        for k in range(8):
            spike(c, 16, 148, k * math.pi / 4, 9, 14, ["p", "o", "n"])
    elif i == 5:
        c.arc(16, 152, 14, 5.5, 0, 360, "p")
        c.arc(16, 152, 15, 6, 0, 360, "o", 0.7)
        c.disc(16, 150, 3, 3, "p")
        bolt(c, full[int(len(full) * 0.8):], 0.4)
    elif i == 6:
        for k in range(8):
            a = k * math.tau / 8 + 0.2
            c.put(16 + math.cos(a) * 13, 146 + math.sin(a) * 9, "o")
            c.put(16 + math.cos(a) * 15, 146 + math.sin(a) * 10, "n", 0.7)
    else:
        for k in range(6):
            c.put(16 + rng.uniform(-12, 12), rng.uniform(132, 150), rng.choice(["o", "n", "m"]), 0.8)
    return c.sprite()


# ---------------------------------------------------------------------------------------------------------- Reaper's Coil
def scythe_spin(i: int, front: bool) -> F.Sprite:
    """The scythe swung round him on its chain: a teal crescent sweeping round an ellipse at his feet, white at the blade,
    the tail dithering away. Back = the far half (drawn behind him), front = the near half."""
    c = F.Canvas(96, 64, 48, 56)
    cx, cy, rx, ry = 48, 50, 40, 13
    lead = i * math.pi / 2 + 0.4
    span = math.pi * 1.25
    steps = 160
    for k in range(steps + 1):
        f = k / steps  # 0 at the tail, 1 at the blade
        a = lead - span * (1 - f)
        near = math.sin(a) >= 0
        if near != front:
            continue
        thick = 1 + 4.5 * f ** 1.5
        for d in range(int(thick) + 1):
            depth = d / max(1.0, thick)
            x = cx + math.cos(a) * (rx - d * 0.6)
            y = cy + math.sin(a) * (ry - d * 0.25) - d * 0.9  # the band stands up a little (the blade is tall)
            sym = TEAL[0] if f > 0.9 and d <= 1 else TEAL[min(4, 1 + int(depth * 2.2) + (1 if f < 0.4 else 0))]
            c.put(x, y, sym, F.clamp01(f / 0.35) * F.clamp01((1.1 - depth) / 0.5))
    bx, by = cx + math.cos(lead) * rx, cy + math.sin(lead) * ry  # the blade's glint
    if (math.sin(lead) >= 0) == front:
        c.put(bx, by - 2, "1")
        c.put(bx + 1, by - 3, "p")
    return c.sprite()


def scythe_flying(i: int) -> F.Sprite:
    """The thrown scythe turning end over end: a crescent blade on a short haft, 8 steps of 45 degrees, a faint spin trail."""
    c = F.Canvas(32, 32, 16, 16)
    a0 = i * math.pi / 4
    for k in range(12):  # the spin trail
        a = a0 - 1.0 - k * 0.12
        c.put(16 + math.cos(a) * 12, 16 + math.sin(a) * 12, "t", 0.55 * (1 - k / 12))
    hx, hy = math.cos(a0 + math.pi), math.sin(a0 + math.pi)
    for s_ in range(0, 9):  # the haft
        c.put(16 + hx * s_, 16 + hy * s_, "9" if s_ % 3 else "b")
        c.put(16 + hx * s_ + hy * 0.6, 16 + hy * s_ - hx * 0.6, "8")
    for k in range(20):  # the blade: a crescent from the head out and round, thick in the middle
        f = k / 19
        a = a0 + f * 1.9
        r = 3 + 10 * math.sin(f * math.pi * 0.85)
        x, y = 16 + math.cos(a) * r, 16 + math.sin(a) * r
        c.put(x, y, "1" if 0.3 < f < 0.9 else "p")
        thick = 1 + int(2 * math.sin(f * math.pi))
        for d in range(1, thick + 1):
            c.put(x - math.cos(a) * d, y - math.sin(a) * d, "u" if d == 1 else "t")
    c.halo("k", 0.5)
    return c.sprite()


def chain_link(i: int) -> F.Sprite:
    """A 32 px run of chain: oval links seen side-on and face-on in turn, a glint running along (4 frames)."""
    c = F.Canvas(32, 8, 0, 4)
    for k in range(5):
        x = k * 7 + 1
        if k % 2 == 0:  # face-on link: an oval ring
            c.arc(x + 3, 4, 3.2, 2, 0, 360, STEEL[1])
            c.put(x + 3, 2, STEEL[0])
        else:  # side-on: a bar
            c.line(x, 4, x + 5, 4, STEEL[2])
            c.line(x + 1, 3, x + 4, 3, STEEL[1])
    glint = (i * 8 + 4) % 32
    c.put(glint, 3, "1")
    c.put(glint + 1, 3, "p")
    c.put(glint, 4, "u")
    return c.sprite()


def chain_hook(i: int) -> F.Sprite:
    """Frames 1-3: the hook biting (a flash, a cross in a ring, the ring opening); 4-5: the clink's sparks."""
    c = F.Canvas(32, 32, 16, 16)
    cx = cy = 16
    if i == 0:
        c.disc(cx, cy, 3, 3, "1")
        for d in range(3, 8):
            for x, y in ((cx + d, cy), (cx - d, cy), (cx, cy + d), (cx, cy - d)):
                c.put(x, y, "p" if d < 6 else "u")
    elif i == 1:
        ring(c, cx, cy, 7, "p")
        ring(c, cx, cy, 8, "u", 0.8)
        for d in range(-4, 5):
            c.put(cx + d, cy, "1")
            c.put(cx, cy + d, "1")
    elif i == 2:
        ring(c, cx, cy, 10, "u", 1.0, 8, 15)
        ring(c, cx, cy, 11, "t", 0.6, 8, 20, 22)
        c.put(cx, cy, "p")
    elif i == 3:
        for k in range(6):
            spike(c, cx, cy, k * math.pi / 3 + 0.2, 3, 9, ["1", "p", "u"])
    else:
        dots(c, cx, cy, 11, 6, ["u", "t"], 0.8, 30)
    return c.sprite()


def chain_stagger(i: int) -> F.Sprite:
    """The stagger burst on the dragged target's chest: a flash, a teal ring with ticks, it widens and breaks into motes."""
    c = F.Canvas(32, 32, 16, 16)
    cx = cy = 16
    if i == 0:
        c.disc(cx, cy, 4, 4, "1")
        c.halo("p")
        c.halo("u", 0.6)
    else:
        r = [0, 7, 10, 12, 13.5, 14.5][i]
        alpha = [1, 1, 1, 0.8, 0.55, 0.3][i]
        ring(c, cx, cy, r, "p" if i < 3 else "u", alpha, 0 if i < 3 else 8, 0 if i < 3 else 18)
        ring(c, cx, cy, r + 1, "u" if i < 3 else "t", alpha * 0.6)
        for k in range(8):
            a = k * math.pi / 4 + i * 0.15
            spike(c, cx, cy, a, r - 3, r - 1, ["1", "p", "u"], alpha=alpha)
        if i < 3:
            c.disc(cx, cy, 1.5, 1.5, "p")
    return c.sprite()


def chain_stars(i: int) -> F.Sprite:
    """Three little stars circling over a dazed head (4 frames, a quarter turn)."""
    c = F.Canvas(32, 16, 16, 12)
    for k in range(3):
        a = i * math.pi / 2 / 3 + k * math.tau / 3
        x, y = 16 + math.cos(a) * 9, 8 + math.sin(a) * 3
        near = math.sin(a) > 0
        sym = "x" if near else "y"
        c.put(x, y, "1" if near else sym)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.put(x + dx, y + dy, sym)
    return c.sprite()


def chain_land(i: int) -> F.Sprite:
    """Dust thrown up where a missed hook lands: puffs spreading and settling."""
    c = F.Canvas(32, 24, 16, 18)
    spread = [3, 6, 9, 11][i]
    alpha = [1.0, 1.0, 1.0, 0.5][i]
    for k, dx in enumerate((-1, 1)):
        puff(c, 16 + dx * spread, 16 - i * 0.6, 2.5 + i * 0.6, alpha)
    puff(c, 16, 14 - i * 1.2, 2.8 + i * 0.5, alpha)
    if i < 2:
        for k in range(4):
            a = math.pi + k * math.pi / 3 + 0.3
            c.put(16 + math.cos(a) * (5 + i * 3), 14 + math.sin(a) * (5 + i * 3), "j")
    return c.sprite()


def chain_dust(i: int) -> F.Sprite:
    """Dust kicked up behind a dragged target's feet: a trail of puffs growing and fading (the target is at the left)."""
    c = F.Canvas(64, 16, 8, 14)
    for k in range(5):
        x = 10 + k * 9 + i * 2
        r = 1.6 + k * 0.45 + i * 0.4
        alpha = 1.0 if i < 3 else 0.5
        puff(c, x, 12 - k * 0.5 - i * 0.6, r, alpha)
    return c.sprite()


def chain_scuff(i: int) -> F.Sprite:
    """Drag marks on the ground: two dark streaks, fading."""
    c = F.Canvas(32, 16, 16, 8)
    fade = [0.9, 0.7, 0.45, 0.25][i]
    for row, ln in ((6, 24), (10, 20)):
        for s in range(ln):
            f = s / ln
            c.put(4 + s, row + (1 if s % 9 == 4 else 0), "9" if f > 0.3 else "a", fade * F.clamp01(f / 0.25))
    return c.sprite()


def chain_pull(i: int) -> F.Sprite:
    """Speed lines behind a target being dragged (it is at the left foot of the frame, the lines stream right)."""
    c = F.Canvas(64, 48, 12, 44)
    rng = random.Random(6000 + i)
    for k in range(7):
        y = 8 + k * 5 + rng.randint(-1, 1)
        x0 = 16 + rng.randint(0, 8) + i * 3
        ln = rng.randint(14, 30)
        for s in range(ln):
            f = s / ln
            c.put(x0 + s, y, F.ramp(["1", "p", "u", "t"], f), F.clamp01((1 - f) / 0.5))
    return c.sprite()


# ----------------------------------------------------------------------------------------------------------------- main
def families() -> list[tuple[str, list[F.Sprite]]]:
    out = [("fx_black_aura_back", [black_aura(i, False) for i in range(6)]),
           ("fx_black_aura_front", [black_aura(i, True) for i in range(6)]),
           ("fx_lightning_aura_back", [lightning_aura(i, False) for i in range(10)]),
           ("fx_lightning_aura_front", [lightning_aura(i, True) for i in range(10)]),
           ("fx_lightning_afterimage", [lightning_afterimage(i) for i in range(6)]),
           ("fx_lightning_blink", [lightning_blink(i) for i in range(5)]),
           ("fx_lightning_spark", [lightning_spark(i) for i in range(6)])]
    for d, name in enumerate(["e", "se", "s", "sw", "w", "nw", "n", "ne"]):
        out.append((f"fx_lightning_cut_{name}", [lightning_cut(d, i) for i in range(4)]))
    out += [("fx_lightning_chain", [lightning_chain(i) for i in range(4)]),
            ("fx_lightning_ground", [lightning_ground(i) for i in range(4)]),
            ("fx_lightning_strike", [lightning_strike(i) for i in range(8)]),
            ("fx_scythe_spin_back", [scythe_spin(i, False) for i in range(4)]),
            ("fx_scythe_spin_front", [scythe_spin(i, True) for i in range(4)]),
            ("fx_scythe_flying", [scythe_flying(i) for i in range(8)]),
            ("fx_chain_link", [chain_link(i) for i in range(4)]),
            ("fx_chain_hook", [chain_hook(i) for i in range(5)]),
            ("fx_chain_stagger", [chain_stagger(i) for i in range(6)]),
            ("fx_chain_stars", [chain_stars(i) for i in range(4)]),
            ("fx_chain_land", [chain_land(i) for i in range(4)]),
            ("fx_chain_dust", [chain_dust(i) for i in range(4)]),
            ("fx_chain_scuff", [chain_scuff(i) for i in range(4)]),
            ("fx_chain_pull", [chain_pull(i) for i in range(4)])]
    return out


def main() -> int:
    written: list[str] = []
    rows = families()
    for fam, frames in rows:
        for i, s in enumerate(frames):
            write_fixed(f"{fam}_{i + 1}", s, written)
    print(f"wrote {len(written)} frames")
    if "--sheet" in sys.argv:
        _sheet(rows)
    return 0


def _sheet(rows: list[tuple[str, list[F.Sprite]]]) -> None:
    zoom = 3
    cell = max(max(s.img.width for s in r) for _, r in rows) * zoom + 6
    width = max(len(r) for _, r in rows) * cell
    heights = [max(s.img.height for s in r) * zoom + 6 for _, r in rows]
    out = Image.new("RGB", (min(width, 10 * cell), sum(heights)), (34, 38, 48))
    y = 0
    for (_, r), h in zip(rows, heights):
        for k, s in enumerate(r[:10]):
            img = s.img.resize((s.img.width * zoom, s.img.height * zoom), Image.NEAREST)
            out.paste(img, (k * cell + 3, y + 3), img)
        y += h
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    out.save(SHEET)
    print("sheet:", SHEET, out.size)


if __name__ == "__main__":
    raise SystemExit(main())
