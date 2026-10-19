"""Draw the title logo: a carved stone plaque with gold-edged Cinzel capitals, gems, wings and vines.

Follows the layout of the logo the human supplied (385x215 px, too small to enlarge: "ADVENTURE" over a small
violet-winged "OF" over "TOTOY", teal gems on the top and bottom of the plaque, vines at both ends) but is redrawn
sharp at 1800x920 and graded to the game's dusk mood (grey-green stone, cream-and-bronze letters, teal and violet
gems, mossy vines). Drawn at 2x and reduced for smooth edges.

Writes presentation/menu/title_logo.png (RGBA). Deterministic (fixed seed). Needs presentation/fonts/Cinzel.ttf.
Run from the project root:  python tools/art/make_title_logo.py
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "presentation" / "fonts" / "Cinzel.ttf"
OUT = ROOT / "presentation" / "menu" / "title_logo.png"
W, H = 1800, 920
S = 2  # supersampling

INK = (28, 24, 36)
BROWN_D = (46, 33, 30)
BROWN = (98, 69, 61)
BRONZE = (152, 121, 89)
CREAM = (244, 236, 214)
STONE_L = (115, 119, 105)
STONE_M = (90, 98, 94)
STONE_D = (47, 50, 49)
GREEN_D = (38, 48, 28)
GREEN = (63, 82, 38)
GREEN_L = (127, 147, 72)
TEAL = (63, 127, 122)
TEAL_L = (106, 168, 154)
VIOLET = (138, 111, 168)
VIOLET_D = (74, 56, 120)
VIOLET_L = (190, 160, 232)


def sc(v: float) -> int:
    return int(round(v * S))


def font(size: float, weight: int = 800) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), sc(size))
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def layer() -> Image.Image:
    return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))


def poly(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(sc(x), sc(y)) for x, y in points]


def mask_of(points: list[tuple[float, float]]) -> Image.Image:
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).polygon(poly(points), fill=255)
    return m


def vgradient(top: tuple[int, int, int], bottom: tuple[int, int, int], y0: float, y1: float, mid: tuple[int, int, int] | None = None) -> Image.Image:
    """A full-canvas vertical gradient between y0 and y1 (final px)."""
    g = Image.new("RGB", (1, H * S))
    for y in range(H * S):
        t = min(1.0, max(0.0, (y / S - y0) / max(1.0, y1 - y0)))
        if mid is None:
            c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        elif t < 0.5:
            c = tuple(int(top[i] + (mid[i] - top[i]) * t * 2) for i in range(3))
        else:
            c = tuple(int(mid[i] + (bottom[i] - mid[i]) * (t - 0.5) * 2) for i in range(3))
        g.putpixel((0, y), c)
    return g.resize((W * S, H * S))


def paste(dst: Image.Image, color_or_img, mask: Image.Image) -> None:
    src = color_or_img if isinstance(color_or_img, Image.Image) else Image.new("RGB", dst.size, color_or_img)
    dst.paste(src.convert("RGBA"), (0, 0), mask)


# ---------------------------------------------------------------- plaque
PLAQUE = [(130, 92), (760, 92), (800, 70), (860, 34), (900, 26), (940, 34), (1000, 70), (1040, 92), (1670, 92),
          (1750, 175), (1772, 330), (1772, 600), (1750, 740), (1670, 826),
          (1040, 826), (1000, 850), (940, 884), (900, 894), (860, 884), (800, 850), (760, 826), (130, 826),
          (50, 740), (28, 600), (28, 330), (50, 175)]


def draw_plaque(rnd: random.Random) -> Image.Image:
    out = layer()
    full = mask_of(PLAQUE)
    # outer dark edge
    ImageDraw.Draw(out).polygon(poly(PLAQUE), fill=INK + (255,))
    edge = full.filter(ImageFilter.GaussianBlur(sc(9))).point(lambda v: 255 if v >= 250 else 0)
    rim = edge  # the body of the stone, a little inside the outline
    stone = vgradient((128, 112, 112), (40, 34, 44), 30, 890, mid=(78, 68, 76))
    noise = Image.effect_noise((W * S, H * S), 42).filter(ImageFilter.GaussianBlur(sc(1.2)))
    stone = ImageChops.blend(stone, Image.merge("RGB", [noise, noise, noise]), 0.12)
    paste(out, stone, rim)
    # bevel: a light line on the upper-left of the inner edge, dark on the lower-right
    inner = full.filter(ImageFilter.GaussianBlur(sc(20))).point(lambda v: 255 if v >= 250 else 0)
    rim_band = ImageChops.subtract(rim, inner)
    hl = ImageChops.subtract(rim_band, ImageChops.offset(rim_band, sc(7), sc(7)))
    sh = ImageChops.subtract(rim_band, ImageChops.offset(rim_band, -sc(7), -sc(7)))
    paste(out, (214, 210, 186), hl.point(lambda v: int(v * 0.8)))
    paste(out, BROWN_D, sh.point(lambda v: int(v * 0.85)))
    # inner panel: a darker recessed field with its own thin frame
    field = full.filter(ImageFilter.GaussianBlur(sc(34))).point(lambda v: 255 if v >= 250 else 0)
    field_edge = ImageChops.subtract(field, field.filter(ImageFilter.GaussianBlur(sc(3))).point(lambda v: 255 if v >= 250 else 0))
    paste(out, (36, 38, 44), field.point(lambda v: int(v * 0.30)))
    paste(out, (170, 150, 110), field_edge.point(lambda v: int(v * 0.55)))
    d = ImageDraw.Draw(out)
    # hairline cracks and chips in the stone
    crack = random.Random(5)
    for _ in range(9):
        x, y = crack.uniform(220, 1580), crack.uniform(140, 800)
        pts = [(x, y)]
        for _ in range(crack.randint(3, 6)):
            x += crack.uniform(-40, 40)
            y += crack.uniform(10, 45)
            pts.append((x, y))
        d.line(poly(pts), fill=(22, 18, 28, 150), width=sc(2.2))
    # rivets in the four corners
    for cx, cy in ((92, 140), (1708, 140), (92, 778), (1708, 778)):
        d.ellipse((sc(cx - 14), sc(cy - 14), sc(cx + 14), sc(cy + 14)), fill=INK + (255,))
        d.ellipse((sc(cx - 10), sc(cy - 10), sc(cx + 10), sc(cy + 10)), fill=BRONZE + (255,))
        d.ellipse((sc(cx - 6), sc(cy - 7), sc(cx + 1), sc(cy)), fill=CREAM + (220,))
    return out


# ---------------------------------------------------------------- lettering
def text_runs(parts: list[tuple[str, float]], centre_x: float, baseline: float, tracking: float) -> list[tuple[str, ImageFont.FreeTypeFont, float, float]]:
    """parts: (text, font size). Returns (char, font, x, size) laid out and centred on centre_x."""
    items = []
    total = 0.0
    for text, size in parts:
        f = font(size)
        for ch in text:
            adv = f.getlength(ch) / S + tracking
            items.append((ch, f, total, size, adv))
            total += adv
    total -= tracking
    start = centre_x - total / 2
    return [(ch, f, start + x, size) for ch, f, x, size, adv in items]


def carve(out: Image.Image, runs, baseline: float, y_top: float, y_bottom: float) -> None:
    mask = Image.new("L", (W * S, H * S), 0)
    md = ImageDraw.Draw(mask)
    for ch, f, x, size in runs:
        md.text((sc(x), sc(baseline)), ch, font=f, fill=255, anchor="ls")
    outer = Image.new("L", mask.size, 0)
    od = ImageDraw.Draw(outer)
    for ch, f, x, size in runs:
        od.text((sc(x), sc(baseline)), ch, font=f, fill=255, anchor="ls", stroke_width=sc(11))
    mid = Image.new("L", mask.size, 0)
    mdd = ImageDraw.Draw(mid)
    for ch, f, x, size in runs:
        mdd.text((sc(x), sc(baseline)), ch, font=f, fill=255, anchor="ls", stroke_width=sc(5))
    # drop shadow, outline, bronze rim
    shadow = ImageChops.offset(outer, sc(5), sc(9)).filter(ImageFilter.GaussianBlur(sc(5)))
    paste(out, INK, shadow.point(lambda v: int(v * 0.7)))
    paste(out, INK, outer)
    paste(out, BROWN, mid)
    # letter face: cream at the top to bronze at the bottom
    face = vgradient((250, 244, 224), (140, 108, 78), y_top, y_bottom, mid=(214, 190, 140))
    noise = Image.effect_noise(mask.size, 30).filter(ImageFilter.GaussianBlur(sc(0.8)))
    face = ImageChops.blend(face, Image.merge("RGB", [noise, noise, noise]), 0.08)
    paste(out, face, mask)
    # bevel
    hl = ImageChops.subtract(mask, ImageChops.offset(mask, sc(4), sc(5)))
    sh = ImageChops.subtract(mask, ImageChops.offset(mask, -sc(4), -sc(5)))
    paste(out, (255, 252, 240), hl.point(lambda v: int(v * 0.85)))
    paste(out, BROWN_D, sh.point(lambda v: int(v * 0.75)))


# ---------------------------------------------------------------- gems, wings, vines
def gem(out: Image.Image, cx: float, cy: float, r: float, base, light) -> None:
    glow = layer()
    ImageDraw.Draw(glow).ellipse((sc(cx - r * 1.9), sc(cy - r * 1.9), sc(cx + r * 1.9), sc(cy + r * 1.9)), fill=light + (110,))
    out.alpha_composite(glow.filter(ImageFilter.GaussianBlur(sc(r * 0.7))))
    d = ImageDraw.Draw(out)
    top = (cx, cy - r * 1.35)
    right = (cx + r * 0.92, cy)
    bottom = (cx, cy + r * 1.35)
    left = (cx - r * 0.92, cy)
    k = 1.32  # bezel
    bez = [(cx, cy - r * 1.35 * k), (cx + r * 0.92 * k, cy), (cx, cy + r * 1.35 * k), (cx - r * 0.92 * k, cy)]
    d.polygon(poly(bez), fill=INK + (255,))
    bez2 = [(cx, cy - r * 1.35 * 1.18), (cx + r * 0.92 * 1.18, cy), (cx, cy + r * 1.35 * 1.18), (cx - r * 0.92 * 1.18, cy)]
    d.polygon(poly(bez2), fill=BRONZE + (255,))
    d.line(poly(bez2 + [bez2[0]]), fill=CREAM + (200,), width=sc(2))
    centre = (cx, cy)
    d.polygon(poly([top, right, centre]), fill=light + (255,))
    d.polygon(poly([top, left, centre]), fill=tuple(int((a + b) / 2) for a, b in zip(light, base)) + (255,))
    d.polygon(poly([bottom, right, centre]), fill=base + (255,))
    d.polygon(poly([bottom, left, centre]), fill=tuple(int(c * 0.62) for c in base) + (255,))
    d.line(poly([top, bottom]), fill=(255, 255, 255, 70), width=sc(1.5))
    d.line(poly([left, right]), fill=(255, 255, 255, 70), width=sc(1.5))
    d.polygon(poly([(cx - r * 0.12, cy - r * 0.8), (cx + r * 0.12, cy - r * 0.5), (cx - r * 0.05, cy - r * 0.2)]), fill=(255, 255, 255, 215))


def leaf(d: ImageDraw.ImageDraw, cx: float, cy: float, length: float, width: float, angle: float, fill, outline, rib=None) -> None:
    pts = []
    n = 14
    for i in range(n + 1):
        t = i / n
        x = t * length
        y = math.sin(math.pi * t) * width * 0.5 * (1.0 - 0.25 * t)
        pts.append((x, y))
    for i in range(n, -1, -1):
        t = i / n
        x = t * length
        y = -math.sin(math.pi * t) * width * 0.5 * (1.0 - 0.25 * t)
        pts.append((x, y))
    ca, sa = math.cos(angle), math.sin(angle)
    world = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    d.polygon(poly(world), fill=fill + (255,), outline=outline + (255,), width=sc(2))
    if rib is not None:
        d.line(poly([(cx, cy), (cx + length * 0.92 * ca, cy + length * 0.92 * sa)]), fill=rib + (200,), width=sc(1.5))


def wing(out: Image.Image, cx: float, cy: float, direction: int) -> None:
    d = ImageDraw.Draw(out)
    feathers = [(-30, 118, 30, VIOLET_D), (-10, 142, 34, VIOLET), (10, 128, 32, VIOLET), (28, 98, 26, VIOLET_L)]
    for ang, length, width, color in feathers:
        a = math.radians(ang)
        if direction < 0:
            a = math.pi - a
        leaf(d, cx, cy, length, width, a, color, INK, rib=(230, 215, 255))
    leaf(d, cx, cy, 78, 20, math.radians(50) if direction > 0 else math.pi - math.radians(50), VIOLET_L, INK, rib=(255, 255, 255))


def spline(points: list[tuple[float, float]], per: int = 14) -> list[tuple[float, float]]:
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(per):
            t = s / per
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t ** 3) for k in range(2)))
    out.append(points[-1])
    return out


def vine(out: Image.Image, points: list[tuple[float, float]], rnd: random.Random, thick: float = 17.0, leaf_every: float = 30.0) -> None:
    path = spline(points)
    d = ImageDraw.Draw(out)
    d.line(poly(path), fill=INK + (255,), width=sc(thick + 6), joint="curve")
    d.line(poly(path), fill=GREEN_D + (255,), width=sc(thick), joint="curve")
    d.line(poly([(x - 1.5, y - 1.5) for x, y in path]), fill=GREEN + (255,), width=sc(thick * 0.5), joint="curve")
    travelled = 0.0
    side = 1
    for i in range(1, len(path)):
        seg = math.hypot(path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1])
        travelled += seg
        if travelled >= leaf_every:
            travelled = 0.0
            tangent = math.atan2(path[i][1] - path[i - 1][1], path[i][0] - path[i - 1][0])
            ang = tangent + side * math.radians(rnd.uniform(40, 75))
            length = rnd.uniform(46, 78)
            color = rnd.choice([GREEN, GREEN_L, (90, 122, 58)])
            leaf(d, path[i][0], path[i][1], length, length * 0.5, ang, color, GREEN_D, rib=(190, 210, 120))
            side = -side


def main() -> int:
    if not FONT.exists():
        print("missing", FONT)
        return 1
    rnd = random.Random(20261019)
    out = layer()
    out.alpha_composite(draw_plaque(rnd))
    # text rows: (parts, baseline)
    row1 = text_runs([("A", 280), ("DVENTURE", 206)], 900, 350, 6)
    carve(out, row1, 350, 350 - 280 * 0.72, 350)
    row3 = text_runs([("T", 330), ("OTO", 270), ("Y", 330)], 900, 752, 8)
    carve(out, row3, 752, 752 - 330 * 0.72, 752)
    row2 = text_runs([("OF", 74)], 900, 452, 10)
    carve(out, row2, 452, 452 - 74 * 0.72, 452)
    # wings beside "OF"
    wing(out, 836, 424, -1)
    wing(out, 964, 424, 1)
    # gems: top and bottom centre, and a row on the bottom bar
    gem(out, 900, 84, 32, TEAL, TEAL_L)
    gem(out, 900, 842, 34, TEAL, TEAL_L)
    gem(out, 360, 786, 24, VIOLET, VIOLET_L)
    gem(out, 1440, 786, 24, VIOLET, VIOLET_L)
    gem(out, 600, 794, 20, TEAL, TEAL_L)
    gem(out, 1200, 794, 20, TEAL, TEAL_L)
    # moss along the top and bottom edges (the arena is overgrown)
    moss = ImageDraw.Draw(out)
    mr = random.Random(11)
    for edge_y, spread in ((98, (140, 700)), (98, (1100, 1660)), (822, (150, 560)), (822, (1240, 1650))):
        for _ in range(26):
            x = mr.uniform(*spread)
            y = edge_y + mr.uniform(-6, 14) * (1 if edge_y < 400 else -1)
            r = mr.uniform(9, 20)
            tone = mr.choice([GREEN, GREEN_L, (90, 122, 58), GREEN_D])
            moss.ellipse((sc(x - r), sc(y - r * 0.6), sc(x + r), sc(y + r * 0.6)), fill=tone + (255,), outline=GREEN_D + (255,), width=sc(1.5))
    # vines at both ends and over the top corners
    vine(out, [(150, 100), (110, 190), (150, 280), (96, 380), (140, 480), (90, 590), (130, 690), (86, 790)], rnd)
    vine(out, [(70, 800), (150, 760), (240, 800), (330, 770)], rnd, 13.0, 30.0)
    vine(out, [(1660, 104), (1700, 200), (1650, 300), (1706, 410), (1656, 520), (1710, 640), (1660, 740), (1712, 800)], rnd)
    vine(out, [(1730, 800), (1650, 770), (1560, 806), (1480, 774)], rnd, 13.0, 30.0)
    vine(out, [(150, 100), (240, 70), (330, 100), (420, 74)], rnd, 12.0, 30.0)
    vine(out, [(1660, 104), (1570, 72), (1480, 102), (1390, 76)], rnd, 12.0, 30.0)
    # dusk lighting: a touch cooler, a soft violet rim glow and a ground shadow
    body = out.resize((W, H), Image.LANCZOS)
    alpha = body.getchannel("A")
    cool = ImageChops.multiply(body.convert("RGB"), Image.new("RGB", body.size, (236, 232, 252)))
    result = Image.new("RGBA", body.size, (0, 0, 0, 0))
    glow = Image.new("RGBA", body.size, VIOLET + (0,))
    glow.putalpha(alpha.filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.35)))
    shadow = Image.new("RGBA", body.size, INK + (0,))
    shadow.putalpha(ImageChops.offset(alpha, 0, 14).filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.55)))
    result.alpha_composite(shadow)
    result.alpha_composite(glow)
    cool_rgba = cool.convert("RGBA")
    cool_rgba.putalpha(alpha)
    result.alpha_composite(cool_rgba)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    result.save(OUT)
    print("wrote", OUT, result.size, OUT.stat().st_size, "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
