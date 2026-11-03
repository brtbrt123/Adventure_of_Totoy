"""The mobs' attack effects redrawn in the Star Staff's style, phase 4 of the effects redo (owner 2026-11-02: "i like the effects
of the staff skill, can you redo all effects, aspects, attacks of mobs and hero except the golem"; "Yes, start phase 4").

Chapter 1's creatures: the flat dithered dust and specks become solid lumpy puffs, shaded clods and stones, glowing motes and
rings (tools/art/staff_fx.py: Totoy 36, hard alpha, ordered dithering only for the last fade). Every frame keeps its name,
count, size and anchor, so the game and the editable SpriteFrames keep working. The live part (rocks that bounce, dust rings,
light, shake) is presentation/explore/mob_view.gd.

    fx_ch1_boar_crash_1..5        40x32 @20,30   the boar hitting a wall or the hero: a flash, dust bursting, clods flying
    fx_ch1_boar_dust_1..4         32x16 @28,14   dust behind its charging feet
    fx_ch1_leaf_puff_1..5         24x24 @12,16   leaves knocked loose, scattering and falling
    fx_ch1_moth_trail_1..4        32x8 @24,4     the glowmoth's trail of light
    fx_ch1_purify_sparkle_1..8    48x48 @24,40   a purified creature: light rising, a ring on the ground, sparkles
    fx_ch1_stag_slam_rubble_1..5  48x24 @24,22   the stag's slam: stones and dust thrown up and settling
    fx_glowmoth_orb_pop_1..4      16x16 centre   an orb bursting: a flash, a ring, sparks
(The root spikes, the glowing orb, the stag's chant, horns and summon and the Warden's attached effects keep their art: the
Warden's are pinned to its reviewed reference by tests/test_warden_art.py; their live part is new.)

    python tools/art/make_mob_fx_art.py            # writes art/src; then validate, build and preview the art
    python tools/art/make_mob_fx_art.py --sheet    # also art/reference/mob_fx_v1/frames.png (every frame at 4x)
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import staff_fx as F  # noqa: E402
from make_hero_fx_art import dots, ring, spike, write_fixed  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "art/reference/mob_fx_v1/frames.png"
EARTH = ["d", "c", "b", "9"]   # dust and clods, light to dark
STONE = ["j", "i", "h", "g", "f"]
LEAF = ["7", "6", "5", "4", "3"]
GLOW = ["1", "p", "u", "t", "k"]


def earth_puff(c: F.Canvas, x: float, y: float, r: float, alpha: float = 1.0) -> None:
    """A dust puff in earth colours: solid and lumpy, darker underneath, lit on top."""
    c.disc(x, y + r * 0.2, r, r * 0.78, EARTH[2], alpha)
    c.disc(x - r * 0.15, y - r * 0.05, r * 0.85, r * 0.64, EARTH[1], alpha)
    c.disc(x - r * 0.35, y - r * 0.35, r * 0.48, r * 0.38, EARTH[0], alpha)


def clod(c: F.Canvas, x: float, y: float, size: int, palette: list[str] = EARTH) -> None:
    """A small shaded lump of earth or stone (1-3 px)."""
    c.put(x, y, palette[1])
    if size >= 2:
        c.put(x + 1, y, palette[2])
        c.put(x, y - 1, palette[0])
    if size >= 3:
        c.put(x + 1, y + 1, palette[3])
        c.put(x, y + 1, palette[2])


def boar_crash(i: int) -> F.Sprite:
    c = F.Canvas(40, 32, 20, 30)
    rng = random.Random(31)
    if i == 0:
        c.disc(20, 22, 2.5, 2.5, "1")
        for d in range(3, 8):
            for x, y in ((20 + d, 22), (20 - d, 22), (20, 22 - d)):
                c.put(x, y, "j" if d < 6 else "i")
    spread = [4, 8, 12, 15, 17][i]
    alpha = [1.0, 1.0, 1.0, 0.8, 0.45][i]
    for k, dx in enumerate((-1.0, -0.4, 0.4, 1.0)):
        earth_puff(c, 20 + dx * spread, 27 - abs(dx) * 2 - i * 0.8, 2.6 + i * 0.6 - abs(dx) * 0.4, alpha)
    for k in range(7):  # clods thrown up in arcs
        a = math.pi + (k + 0.5) / 7 * math.pi
        t = (i + 1) / 5
        x = 20 + math.cos(a) * 15 * t
        y = 24 + math.sin(a) * 14 * t + 10 * t * t
        if i < 4:
            clod(c, x, y, 1 + k % 3)
    return c.sprite()


def boar_dust(i: int) -> F.Sprite:
    c = F.Canvas(32, 16, 28, 14)
    for k in range(3):
        earth_puff(c, 24 - k * 8 - i * 1.5, 12.5 - k * 0.4 - i * 0.5, 1.8 + k * 0.5 + i * 0.4, 1.0 if i < 3 else 0.5)
    return c.sprite()


def leaf_puff(i: int) -> F.Sprite:
    """Leaves knocked loose: shaded leaf shapes spreading out, turning and falling."""
    c = F.Canvas(24, 24, 12, 16)
    rng = random.Random(77)
    for k in range(7):
        a = rng.uniform(0, math.tau)
        sp = rng.uniform(4, 9)
        t = i / 4
        x = 12 + math.cos(a) * sp * (0.3 + t)
        y = 13 + math.sin(a) * sp * 0.6 * (0.3 + t) + 6 * t * t
        turn = (i + k) % 3
        shade = LEAF[k % 3 + 1]
        if turn == 0:
            c.line(x - 1, y, x + 1, y, shade)
            c.put(x, y - 1, LEAF[0])
        elif turn == 1:
            c.line(x, y - 1, x, y + 1, shade)
            c.put(x + 1, y, LEAF[4])
        else:
            c.line(x - 1, y + 1, x + 1, y - 1, shade)
        if i == 4 and k % 2:
            c.put(x, y, LEAF[2], 0.5)
    return c.sprite()


def moth_trail(i: int) -> F.Sprite:
    """The glowmoth's trail: glowing motes along its path, the newest bright, the oldest fading (it flies to the right end)."""
    c = F.Canvas(32, 8, 24, 4)
    for k in range(7):
        x = 24 - k * 4 - (i % 2) * 2
        y = 4 + math.sin(k * 1.3 + i) * 1.6
        f = k / 6
        c.put(x, y, F.ramp(GLOW, f * 0.9), F.clamp01((1 - f) / 0.5) + 0.2)
        if k < 2:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c.put(x + dx, y + dy, "u", 0.8)
    return c.sprite()


def purify_sparkle(i: int) -> F.Sprite:
    """A creature purified: a column of light rising, a ring opening on the ground, sparkles drifting up and out."""
    c = F.Canvas(48, 48, 24, 40)
    rng = random.Random(500)
    power = [1.0, 1.0, 1.0, 0.9, 0.75, 0.55, 0.35, 0.2][i]
    if i < 4:
        h = 14 + i * 7
        for y in range(int(h)):
            f = y / h
            half = (3.5 - i * 0.6) * (1 - 0.5 * f)
            for x in range(int(24 - half - 1), int(24 + half + 2)):
                d = abs(x - 24) / max(0.6, half)
                band = 0 if d < 0.4 else 1 if d < 0.9 else 2 if d < 1.4 else None
                if band is not None:
                    c.put(x, 40 - y, GLOW[min(4, band + int(f * 2))], power * F.clamp01((1 - f) / 0.35))
    rx = 5 + i * 2.2
    c.arc(24, 40, rx, rx * 0.36, 0, 360, "p" if i < 4 else "u", power)
    c.arc(24, 40, rx + 1, rx * 0.36 + 0.5, 0, 360, "u", power * 0.6)
    for k in range(8):  # sparkles drifting up
        x = 24 + rng.uniform(-14, 14)
        y = 38 - rng.uniform(0, 10) - i * 3.2
        if y > 2:
            big = (k + i) % 3 == 0
            c.put(x, y, "1" if big else "p", power)
            if big:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    c.put(x + dx, y + dy, "u", power)
    return c.sprite()


def stag_slam_rubble(i: int) -> F.Sprite:
    """The stag's slam: stones and clods thrown up from the cracked ground, then dust settling."""
    c = F.Canvas(48, 24, 24, 22)
    rng = random.Random(901)
    t = (i + 1) / 5
    alpha = [1.0, 1.0, 1.0, 0.75, 0.4][i]
    for dx in (-15, -8, 0, 8, 15):
        earth_puff(c, 24 + dx * (0.6 + 0.5 * t), 20 - i * 0.6, 2.2 + i * 0.5, alpha)
    for k in range(9):
        x0 = 24 + rng.uniform(-14, 14)
        v = rng.uniform(5, 10)
        x = x0 + (x0 - 24) * 0.4 * t
        y = 20 - v * math.sin(t * math.pi) * 1.2
        if i < 4:
            clod(c, x, y, 1 + k % 3, STONE if k % 2 else EARTH)
    return c.sprite()


def orb_pop(i: int) -> F.Sprite:
    c = F.Canvas(16, 16, 8, 8)
    if i == 0:
        c.disc(8, 8, 3, 3, "1")
        c.halo("p")
        c.halo("u", 0.6)
    elif i == 1:
        ring(c, 8, 8, 5, "p")
        ring(c, 8, 8, 6, "u", 0.7)
        c.put(8, 8, "1")
    elif i == 2:
        for k in range(6):
            spike(c, 8, 8, k * math.pi / 3 + 0.3, 4, 7, ["p", "u", "t"])
    else:
        dots(c, 8, 8, 7, 6, ["u", "t"], 0.6, 25)
    return c.sprite()


def families() -> list[tuple[str, list[F.Sprite]]]:
    return [("fx_ch1_boar_crash", [boar_crash(i) for i in range(5)]),
            ("fx_ch1_boar_dust", [boar_dust(i) for i in range(4)]),
            ("fx_ch1_leaf_puff", [leaf_puff(i) for i in range(5)]),
            ("fx_ch1_moth_trail", [moth_trail(i) for i in range(4)]),
            ("fx_ch1_purify_sparkle", [purify_sparkle(i) for i in range(8)]),
            ("fx_ch1_stag_slam_rubble", [stag_slam_rubble(i) for i in range(5)]),
            ("fx_glowmoth_orb_pop", [orb_pop(i) for i in range(4)])]


def main() -> int:
    written: list[str] = []
    rows = families()
    for fam, frames in rows:
        for i, s in enumerate(frames):
            write_fixed(f"{fam}_{i + 1}", s, written)
    print(f"wrote {len(written)} frames")
    if "--sheet" in sys.argv:
        zoom = 4
        cell = max(max(s.img.width for s in r) for _, r in rows) * zoom + 6
        heights = [max(s.img.height for s in r) * zoom + 6 for _, r in rows]
        out = Image.new("RGB", (8 * cell, sum(heights)), (60, 66, 58))
        y = 0
        for (_, r), h in zip(rows, heights):
            for k, s in enumerate(r):
                img = s.img.resize((s.img.width * zoom, s.img.height * zoom), Image.NEAREST)
                out.paste(img, (k * cell + 3, y + 3), img)
            y += h
        SHEET.parent.mkdir(parents=True, exist_ok=True)
        out.save(SHEET)
        print("sheet:", SHEET, out.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
