"""The hero's attack sheet: every swing of every weapon with the area it hits (owner 2026-11-02: "can you send me a attack sheet
of the hero with its attack range").

Each cell is a piece of ground seen from above with the 16 px tile grid, the hero (facing right) in the swing's active pose with
its slash, and the hit area the game uses, read from core/tuning.gd so the sheet always matches the game. The slash is drawn the
way presentation/common/swing_arc.gd draws it in the game (the same maths): its outer edge is the reach, its ends the arc.
    a blade (core/weapons.gd swing_reach, swing_arc_dot): what is within its reach of the hero's feet and inside its arc
        (facing.dot(direction) >= the arc's dot) is hit; a target counts with its own radius, so a big one is hit a bit farther
    the Star Staff: the cast snaps onto the nearest enemy inside the aim cone within its range (the pale cone), or goes off at
        full range straight ahead (drawn here); its burst hits everything in its circle, all the way round
Writes art/reference/hero_fx_v1/attack_ranges.png. Needs the built art (art/build/sprites.json and its frames).

    python tools/art/attack_range_sheet.py
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/reference/hero_fx_v1/attack_ranges.png"
SPRITES = json.loads((ROOT / "art/build/sprites.json").read_text(encoding="utf-8"))["frames"]
TUNING = (ROOT / "core/tuning.gd").read_text(encoding="utf-8")
ZOOM = 3
CELL = (150, 104)  # world px
TILE = 16

BG = (24, 26, 34)
GROUND = (36, 40, 50)
GRID = (47, 52, 64)
INK = (232, 228, 214)
DIM = (150, 156, 170)


def const(name: str):
    m = re.search(rf"^const {name}\b[^=]*=\s*(.+?)(?:\s+#.*)?$", TUNING, re.M)
    assert m, name
    v = m.group(1).strip()
    if v.startswith("["):
        return [float(x) for x in v.strip("[]").split(",")]
    return float(v)


def font(size: int) -> ImageFont.FreeTypeFont:
    for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf", "ARIALN.TTF"):
        try:
            return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            continue
    return ImageFont.load_default()


def frame(key: str) -> tuple[Image.Image, int, int] | None:
    if key not in SPRITES:
        return None
    f = SPRITES[key]
    img = Image.open(ROOT / "art/build/sprites" / f"{key}.png").convert("RGBA")
    return img, int(f.get("ax", img.width // 2)), int(f.get("ay", img.height // 2))


def paste(dst: Image.Image, key: str, wx: float, wy: float) -> None:
    """A game frame with its anchor at world (wx, wy) of the cell, at the sheet's zoom."""
    got = frame(key)
    if got is None:
        return
    img, ax, ay = got
    big = img.resize((img.width * ZOOM, img.height * ZOOM), Image.NEAREST)
    dst.alpha_composite(big, (int(round((wx - ax) * ZOOM)), int(round((wy - ay) * ZOOM))))


def ground(feet: tuple[float, float]) -> Image.Image:
    w, h = CELL[0] * ZOOM, CELL[1] * ZOOM
    img = Image.new("RGBA", (w, h), GROUND + (255,))
    d = ImageDraw.Draw(img)
    ox, oy = feet[0] % TILE, feet[1] % TILE
    for x in range(int(ox), CELL[0], TILE):
        d.line([(x * ZOOM, 0), (x * ZOOM, h)], fill=GRID, width=1)
    for y in range(int(oy), CELL[1], TILE):
        d.line([(0, y * ZOOM), (w, y * ZOOM)], fill=GRID, width=1)
    return img


def sector(img: Image.Image, feet: tuple[float, float], reach: float, arc_dot: float, colour: tuple[int, int, int],
           fill: int = 72, dashed: bool = False) -> None:
    """The ground a blade's swing reaches: a circle sector of `reach` around the feet, half-angle acos(arc_dot) from facing right."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    half = math.degrees(math.acos(max(-1.0, min(1.0, arc_dot))))
    cx, cy, r = feet[0] * ZOOM, feet[1] * ZOOM, reach * ZOOM
    box = [cx - r, cy - r, cx + r, cy + r]
    if half >= 179.9:
        d.ellipse(box, fill=colour + (fill,))
    else:
        d.pieslice(box, -half, half, fill=colour + (fill,))
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    light = tuple(min(255, c + 60) for c in colour)
    if dashed:
        for a in range(int(-half), int(half), 6):
            d.arc(box, a, a + 3, fill=light, width=2)
    else:
        d.arc(box, -half if half < 179.9 else 0, half if half < 179.9 else 360, fill=light, width=3)
    if half < 179.9:
        for a in (-half, half):
            ex, ey = cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r
            if dashed:
                n = int(r // 10)
                for k in range(0, n, 2):
                    d.line([(cx + (ex - cx) * k / n, cy + (ey - cy) * k / n), (cx + (ex - cx) * (k + 1) / n, cy + (ey - cy) * (k + 1) / n)],
                           fill=light, width=2)
            else:
                d.line([(cx, cy), (ex, ey)], fill=light, width=2)


def circle(img: Image.Image, at: tuple[float, float], radius: float, colour: tuple[int, int, int], fill: int = 90) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy, r = at[0] * ZOOM, at[1] * ZOOM, radius * ZOOM
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour + (fill,), outline=tuple(min(255, c + 60) for c in colour) + (255,), width=3)
    img.alpha_composite(layer)


# the blades' slash, as presentation/common/swing_arc.gd draws it (keep the two in step)
SLASH_COLOURS = {"katana": ["1", "p", "v", "l", "k"], "daggers": ["1", "p", "o", "n", "l"], "scythe": ["1", "p", "u", "t", "k"]}
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
PAL = {c["symbol"]: tuple(bytes.fromhex(c["hex"][1:])) for c in json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))["colors"]}


def _round(v: float) -> int:
    """Godot's round(): halfway cases away from zero."""
    return int(math.floor(v + 0.5)) if v >= 0 else -int(math.floor(-v + 0.5))


def slash_pixels(reach: float, a0: float, a1: float, progress: float, fade: float, finisher: bool,
                 colours: list[str]) -> list[tuple[int, int, str, float]]:
    """The crescent around (0, 0): (x, y, symbol, alpha); swing_arc.gd _shape()."""
    tmax = min(11.0, reach * (0.34 if finisher else 0.28))
    cool = 0.0 if fade >= 1.0 else (1.0 - fade) * 1.8
    best: dict[tuple[int, int], tuple[float, float]] = {}
    steps = max(12, int(abs(a1 - a0) * reach * 2.5 * progress))
    for k in range(steps + 1):
        lead = k / steps
        a = a0 + (a1 - a0) * progress * lead
        dx, dy = math.cos(a), math.sin(a)
        thick = tmax * math.sin(math.pi * min(1.0, 0.05 + 0.93 * lead)) ** 0.65 * (0.5 + 0.5 * lead)
        for di in range(int(thick * 2.0) + 1):
            depth = di * 0.5
            f = depth / max(1.0, thick)
            level = (1.0 if depth < 0.75 else (2.0 if f < 0.7 else 3.0)) + (1.0 if lead < 0.3 else 0.0) + cool
            if fade >= 1.0 and lead > 0.72 and depth < 1.25:
                level = 0.0
            alpha = fade * min(1.0, max(0.0, (1.15 - f) / 0.5)) * min(1.0, max(0.0, (lead + 0.2) / 0.35))
            at = (_round(dx * (reach - depth)), _round(dy * (reach - depth)))
            if at not in best or level < best[at][0]:
                best[at] = (level, alpha)
    return [(x, y, colours[min(len(colours) - 1, int(lv))], al) for (x, y), (lv, al) in best.items()]


def slash(img: Image.Image, feet: tuple[float, float], reach: float, arc_dot: float, swing: int, finisher: bool,
          colours: list[str]) -> None:
    """The whole slash of swing `swing` (facing right: odd swings top to bottom) at the sheet's zoom."""
    half = math.acos(max(-1.0, min(1.0, arc_dot)))
    down = 1.0 if swing % 2 == 1 else -1.0
    layer = Image.new("RGBA", (CELL[0], CELL[1]), (0, 0, 0, 0))
    px = layer.load()
    for x, y, sym, alpha in slash_pixels(reach, -half * down, half * down, 1.0, 1.0, finisher, colours):
        wx, wy = int(feet[0]) + x, int(feet[1]) + y
        if 0 <= wx < CELL[0] and 0 <= wy < CELL[1] and (alpha >= 1.0 or (alpha > 0 and (BAYER[wy & 3][wx & 3] + 0.5) / 16 < alpha)):
            px[wx, wy] = PAL[sym] + (255,)
    img.alpha_composite(layer.resize((CELL[0] * ZOOM, CELL[1] * ZOOM), Image.NEAREST))


def feet_mark(img: Image.Image, feet: tuple[float, float]) -> None:
    d = ImageDraw.Draw(img)
    cx, cy = feet[0] * ZOOM, feet[1] * ZOOM
    d.line([(cx - 5, cy), (cx + 5, cy)], fill=INK, width=2)
    d.line([(cx, cy - 5), (cx, cy + 5)], fill=INK, width=2)


def main() -> int:
    rng = const("ATTACK_RANGE")
    dmg = const("ATTACK_DAMAGE")
    blades = [
        ("Katana", "hero2", "katana", (138, 111, 168), const("SWING_RANGE_MULT"), const("ATTACK_ARC_DOT"), const("SWING_DAMAGE_MULT")),
        ("Dual daggers", "totoy_dagger", "daggers", (120, 176, 214), const("DAGGER_SWING_RANGE_MULT"), const("ATTACK_ARC_DOT"),
         const("DAGGER_SWING_DAMAGE_MULT")),
        ("Chain scythe", "totoy_scythe", "scythe", (90, 170, 150), const("SCYTHE_SWING_RANGE_MULT"), const("SCYTHE_ARC_DOT"),
         const("SCYTHE_SWING_DAMAGE_MULT")),
    ]
    staff_radius = const("STAFF_BURST_RADIUS")
    staff_range = const("STAFF_BURST_RANGE")
    staff_cone = const("STAFF_AIM_CONE_DOT")
    staff_dmg = const("STAFF_SWING_DAMAGE_MULT")
    cw, ch = CELL[0] * ZOOM, CELL[1] * ZOOM
    pad, head, label = 14, 54, 58
    cols = 4
    rows = len(blades) + 1
    sheet = Image.new("RGBA", (pad + cols * (cw + pad), head + rows * (ch + label + pad) + 70), BG + (255,))
    d = ImageDraw.Draw(sheet)
    title, small, tiny = font(30), font(19), font(16)
    d.text((pad, 12), "Totoy's attacks: what each swing hits (from core/tuning.gd)", font=title, fill=INK)
    y = head
    for name, hero_set, trail_set, colour, mults, arc_dot, dmults in blades:
        for i, (m, dm) in enumerate(zip(mults, dmults)):
            x = pad + i * (cw + pad)
            feet = (44.0, 70.0)
            cell = ground(feet)
            reach = rng * m
            sector(cell, feet, reach, arc_dot, colour, fill=40)
            slash(cell, feet, reach, arc_dot, i + 1, i == len(mults) - 1, SLASH_COLOURS[trail_set])
            paste(cell, f"{hero_set}_attack{i + 1}_right_4", *feet)
            feet_mark(cell, feet)
            sheet.alpha_composite(cell, (x, y + label))
            arc = 2 * math.degrees(math.acos(arc_dot))
            d.text((x, y + 4), f"{name}: swing {i + 1}" + (" (finisher)" if i == len(mults) - 1 else ""), font=small, fill=INK)
            d.text((x, y + 30), f"reach {reach:g} px ({reach / TILE:.1f} tiles), arc {arc:.0f}\u00b0, damage {dmg * dm:g}",
                   font=tiny, fill=DIM)
        y += ch + label + pad
    teal = (80, 190, 190)
    for i, (r, dm) in enumerate(zip(staff_radius, staff_dmg)):
        x = pad + i * (cw + pad)
        feet = (18.0, 62.0)
        cell = ground(feet)
        sector(cell, feet, staff_range, staff_cone, (110, 150, 170), fill=26, dashed=True)
        at = (feet[0] + staff_range, feet[1])
        circle(cell, at, r, teal)
        paste(cell, f"totoy_staff_attack{i + 1}_right_4", *feet)
        paste(cell, ("fx_staff_burst_big_3" if i == 2 else "fx_staff_burst_3"), at[0], at[1] - (20 if i == 2 else 15))
        feet_mark(cell, feet)
        feet_mark(cell, at)
        sheet.alpha_composite(cell, (x, y + label))
        d.text((x, y + 4), f"Star Staff: cast {i + 1}" + (" (Great Burst)" if i == 2 else " (Arcane Burst)"), font=small, fill=INK)
        d.text((x, y + 30), f"burst radius {r:g} px ({2 * r / TILE:.1f} tiles across), damage {dmg * dm:g} to all in it",
               font=tiny, fill=DIM)
    x = pad + 3 * (cw + pad)
    notes = [
        "How to read it",
        "Ground grid: 16 px tiles. + marks the hero's feet",
        "(and the burst's centre).",
        "",
        "Blades: an enemy is hit when its edge is inside",
        "the coloured slice in front of the hero (bigger",
        "enemies are hit a little farther out). The slash",
        "is drawn on that slice's edge, turned with him.",
        "",
        f"Staff: the cast snaps onto the nearest enemy in",
        f"the dashed cone (within {staff_range:g} px, \u00b1{math.degrees(math.acos(staff_cone)):.0f}\u00b0), else it",
        "goes off at full range straight ahead (shown).",
        "Its burst hits everything in the circle.",
        "",
        "Damage: base attack damage x the swing's multiplier",
        "(counters, aspects and forms change it).",
    ]
    for k, line in enumerate(notes):
        d.text((x, y + 6 + k * 23), line, font=small if k == 0 else tiny, fill=INK if k == 0 else DIM)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(OUT)
    print("wrote", OUT, sheet.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
