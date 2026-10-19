"""Export the Lightning Form cut-in art (presentation/cutin/lightning_*), the Dual Dagger sibling of the Black Form cut-in.

Built from the approved dual dagger concept (art/reference/dual_dagger/concept_v1.png, 64x64 cells at 1x game
pixels). Everything is drawn at 1x in the Totoy 36 palette with hard alpha, then scaled up with integer
nearest-neighbour, so every file stays crisp pixel art. Gold (x, y) and red (z, A) are never used.

Outputs (same structure as tools/art/export_black_form_cutin.py, so a sibling of black_form_cutin.gd can play it):
  lightning_pose_<name>.png       lit pose with the two daggers and a pale-blue / cream / lilac lightning rim (x12)
  lightning_pose_<name>_sil.png   the same pose as an ink silhouette with a lightning outline (the impact frame)
                                  name: crouch (concept "charge"), ready (concept "ready_2"),
                                        burst (concept "burst")
  lightning_aura.png              12 crackle frames (6x2 atlas, x8) that play behind the figure like black_form_aura
  lightning_bolt_<1..4>.png       800x450 backdrop: a big diagonal bolt (lead, strike, afterglow, fragments) (x4)
  lightning_flash_<1..3>.png      800x450 full-width pop: white flash with speed lines, then speed lines fading (x4)
  lightning_cutin.json            sizes, anchors, atlas frames and suggested timings
  lightning_cutin_preview.gif     about 1 s at 30 fps on the dark cut-in background (viewing only)
  lightning_cutin_contact.png     every preview frame at 320x180 (game scale) plus the raw assets (viewing only)
The canvas is the 800x450 cut-in canvas of black_form_cutin.gd (drawn at 0.4 on the 320x180 game canvas).
Pillow only, fixed seeds (re-running gives identical files). Run from the project root:
  python tools/art/export_lightning_cutin.py
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
OUT = ROOT / "presentation" / "cutin"
CONCEPT = ROOT / "art" / "reference" / "dual_dagger" / "concept_v1.png"
FONT = ROOT / "presentation" / "fonts" / "PixelifySans.ttf"
PAL = artlib.load_palette()
FORBIDDEN = set(PAL.reserved)

POSE_SCALE = 12       # pose and aura pixels -> cut-in canvas units
AURA_SCALE = 8        # aura pixels -> canvas units (the atlas stays the size of black_form_aura.png)
FX_SCALE = 4          # bolt and flash pixels -> cut-in canvas units
W, H = 800, 450       # cut-in canvas (black_form_cutin.gd)
FW, FH = W // FX_SCALE, (H + FX_SCALE - 1) // FX_SCALE  # 200 x 113 fx grid
PAD = 7               # 1x pixels of room around a pose for the rim and crackle
ANCHOR = (32, 56)     # concept cell anchor (feet)
# name: (concept column, concept row, crackle count, seed)
POSES = {"crouch": (5, 0, 5, 11), "ready": (1, 0, 8, 12), "burst": (7, 0, 14, 13)}


def col(sym: str) -> tuple[int, int, int, int]:
    assert sym not in FORBIDDEN, f"reserved colour {sym}"
    return PAL.by_symbol[sym] + (255,)


# ------------------------------------------------------------------------------------------------ mask helpers
def solid(mask: Image.Image, sym: str) -> Image.Image:
    img = Image.new("RGBA", mask.size, col(sym)[:3] + (0,))
    img.putalpha(mask.point(lambda v: 255 if v else 0))
    return img


def dilate(mask: Image.Image, n: int = 1, diamond: bool = True) -> Image.Image:
    """n steps of dilation; diamond (4-neighbour) keeps outlines pixel-clean."""
    for _ in range(n):
        if diamond:
            out = mask.copy()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                out = ImageChops.lighter(out, ImageChops.offset(mask, dx, dy))
            mask = out
        else:
            mask = mask.filter(ImageFilter.MaxFilter(3))
    return mask


def minus(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.subtract(a, b)


def alpha_mask(img: Image.Image) -> Image.Image:
    return img.getchannel("A").point(lambda v: 255 if v > 127 else 0)


def up(img: Image.Image, k: int) -> Image.Image:
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def jagged(rng: random.Random, a: tuple[float, float], b: tuple[float, float], rough: float, depth: int) -> list[tuple[float, float]]:
    """Midpoint-displacement lightning path from a to b."""
    pts = [a, b]
    for d in range(depth):
        new = [pts[0]]
        for p, q in zip(pts, pts[1:]):
            mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
            dx, dy = q[0] - p[0], q[1] - p[1]
            ln = math.hypot(dx, dy) or 1.0
            off = rng.uniform(-1, 1) * rough * ln
            new += [(mx - dy / ln * off, my + dx / ln * off), q]
        pts = new
    return pts


def draw_path(mask: Image.Image, pts: list[tuple[float, float]], width: int = 1) -> None:
    d = ImageDraw.Draw(mask)
    ip = [(round(x), round(y)) for x, y in pts]
    d.line(ip, fill=255, width=width)
    if width > 1:
        r = width // 2
        for x, y in ip:  # round joints so thick bolts have no notches
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)


def bolt_layers(core: Image.Image, halo_syms: list[str], core_sym: str = "p") -> Image.Image:
    """Core line plus rings of the given colours around it (inner first)."""
    out = Image.new("RGBA", core.size, (0, 0, 0, 0))
    rings = []
    m = core
    for sym in halo_syms:
        big = dilate(m, 1)
        rings.append((minus(big, m), sym))
        m = big
    for ring, sym in reversed(rings):
        out.alpha_composite(solid(ring, sym))
    out.alpha_composite(solid(core, core_sym))
    return out


# ------------------------------------------------------------------------------------------------------ poses
concept = Image.open(CONCEPT).convert("RGBA")


def concept_cell(c: int, r: int) -> Image.Image:
    return concept.crop((c * 64, r * 64, c * 64 + 64, r * 64 + 64))


RAMPS = ["234567", "89abcd", "efghij", "klmnop", "qrs", "tu"]
LIGHTER = {r[i]: r[i + 1] for r in RAMPS for i in range(len(r) - 1)}


def rim_light(body: Image.Image) -> Image.Image:
    """Lights the body from the bolt behind and above: pixels just inside his dark outline on the top and left go one
    step lighter in their own ramp (the outline itself stays, so the silhouette and the daggers keep reading)."""
    out = body.copy()
    a = alpha_mask(body)
    inner = minus(a, ImageChops.darker(ImageChops.offset(a, 1, 0), ImageChops.offset(a, 0, 1)))  # top/left edge
    src = body.load()
    px = out.load()
    am = a.load()
    em = inner.load()
    sym_of = {v: k for k, v in PAL.by_symbol.items()}
    for y in range(1, body.height):
        for x in range(1, body.width):
            if not am[x, y] or em[x, y]:
                continue
            if not (em[x - 1, y] or em[x, y - 1]):
                continue
            sym = sym_of.get(src[x, y][:3])
            if sym in LIGHTER:
                px[x, y] = col(LIGHTER[sym])
    return out


def crackle(rng: random.Random, body: Image.Image, count: int) -> tuple[Image.Image, Image.Image]:
    """Short sparks jumping off the outline. Returns (core mask, lilac tip mask)."""
    a = alpha_mask(body)
    edge = minus(dilate(a, 1), a)
    pts = [(x, y) for y in range(edge.height) for x in range(edge.width) if edge.getpixel((x, y))]
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    core = Image.new("L", body.size, 0)
    tips = Image.new("L", body.size, 0)
    for _ in range(count):
        x, y = rng.choice(pts)
        ang = math.atan2(y - cy, x - cx) + rng.uniform(-0.7, 0.7)
        ln = rng.uniform(3.0, 6.5) * (1.0 + count / 20.0)
        end = (x + math.cos(ang) * ln, y + math.sin(ang) * ln)
        path = jagged(rng, (x, y), end, 0.35, 2)
        draw_path(core, path)
        if rng.random() < 0.6:  # a fork
            k = len(path) // 2
            fang = ang + rng.choice((-1, 1)) * rng.uniform(0.6, 1.1)
            fend = (path[k][0] + math.cos(fang) * ln * 0.5, path[k][1] + math.sin(fang) * ln * 0.5)
            draw_path(core, jagged(rng, path[k], fend, 0.3, 1))
        ex, ey = round(end[0]), round(end[1])
        if 0 <= ex < tips.width and 0 <= ey < tips.height:
            tips.putpixel((ex, ey), 255)
    core = minus(core, a)
    return core, minus(tips, a)


def make_pose(name: str) -> tuple[Image.Image, Image.Image, dict]:
    c, r, n_crackle, seed = POSES[name]
    rng = random.Random(seed)
    cell = concept_cell(c, r)
    bb = cell.getchannel("A").getbbox()
    x0, y0, x1, y1 = bb
    body = Image.new("RGBA", (x1 - x0 + 2 * PAD, y1 - y0 + 2 * PAD), (0, 0, 0, 0))
    body.alpha_composite(cell.crop(bb), (PAD, PAD))
    a = alpha_mask(body)
    # lit pose: dark k contour, then n, then the pale p rim right on the body, crackle on top
    # lit pose: a 1px dark gap keeps his outline, then the pale rim fading out through blue
    d1, d2, d3 = dilate(a, 1), dilate(a, 2), dilate(a, 3)
    r1 = minus(d1, a)
    lit = Image.new("RGBA", body.size, (0, 0, 0, 0))
    lit.alpha_composite(solid(minus(dilate(d3, 1, diamond=False), d3), "l"))
    lit.alpha_composite(solid(minus(d3, d2), "n"))
    lit.alpha_composite(solid(minus(d2, d1), "p"))
    lit.alpha_composite(solid(r1, "k"))
    spark, tips = crackle(rng, body, n_crackle)
    spark, tips = minus(spark, d1), minus(tips, d1)
    lit.alpha_composite(solid(minus(dilate(spark, 1), d2), "n"))
    lit.alpha_composite(rim_light(body))
    lit.alpha_composite(solid(spark, "p"))
    lit.alpha_composite(solid(tips, "v"))
    # impact silhouette: ink body, cream line, blue jagged outline with bigger sparks
    rng2 = random.Random(seed + 100)
    s_spark, s_tips = crackle(rng2, body, n_crackle + 6)
    sil = Image.new("RGBA", body.size, (0, 0, 0, 0))
    sil.alpha_composite(solid(minus(dilate(a, 2), dilate(a, 1)), "n"))
    sil.alpha_composite(solid(minus(dilate(s_spark, 1), a), "n"))
    sil.alpha_composite(solid(r1, "1"))
    sil.alpha_composite(solid(a, "0"))
    sil.alpha_composite(solid(s_spark, "p"))
    sil.alpha_composite(solid(s_tips, "v"))
    k = POSE_SCALE
    feet_x = (ANCHOR[0] - x0) / (x1 - x0)
    meta = {"w": body.width * k, "h": body.height * k, "pad": PAD * k, "inner_w": (x1 - x0) * k,
            "inner_h": (y1 - y0) * k, "feet_x": round(feet_x, 3),
            "source": f"concept_v1.png cell ({c},{r})"}
    return up(lit, k), up(sil, k), meta


# ------------------------------------------------------------------------------------------------- aura atlas
def make_aura_frame(i: int) -> Image.Image:
    """A column of crackling arcs rising from the feet (1x, 48x56), bottom-centred like black_form_aura."""
    rng = random.Random(500 + i)
    w, h = 48, 56
    core = Image.new("L", (w, h), 0)
    tips = Image.new("L", (w, h), 0)
    for j in range(4 + i % 3):
        sx = w / 2 + rng.uniform(-9, 9)
        side = -1 if sx < w / 2 else 1
        ex = w / 2 + side * rng.uniform(8, 21)
        ey = rng.uniform(4, 30)
        path = jagged(rng, (sx, h - 2), (ex, ey), 0.28, 3)
        draw_path(core, path)
        if rng.random() < 0.7:
            k = rng.randrange(2, len(path) - 2)
            fe = (path[k][0] + side * rng.uniform(3, 7), path[k][1] - rng.uniform(2, 7))
            draw_path(core, jagged(rng, path[k], fe, 0.3, 1))
        tips.putpixel((min(w - 1, max(0, round(ex))), min(h - 1, max(0, round(ey)))), 255)
    img = bolt_layers(core, ["n", "k"])
    img.alpha_composite(solid(tips, "v"))
    return up(img, AURA_SCALE)


# ------------------------------------------------------------------------------------------- backdrop bolts
def main_bolt_path(rng: random.Random) -> list[tuple[float, float]]:
    # from the top right down to the bottom left, steep like a real strike
    return jagged(rng, (FW * 0.78, -4), (FW * 0.30, FH + 4), 0.16, 5)


def branches(rng: random.Random, path: list[tuple[float, float]], n: int, scale: float) -> list[list[tuple[float, float]]]:
    out = []
    for _ in range(n):
        k = rng.randrange(3, len(path) - 3)
        px_, py_ = path[k]
        ang = math.atan2(path[k + 1][1] - py_, path[k + 1][0] - px_) + rng.choice((-1, 1)) * rng.uniform(0.5, 1.1)
        ln = rng.uniform(14, 34) * scale
        out.append(jagged(rng, (px_, py_), (px_ + math.cos(ang) * ln, py_ + math.sin(ang) * ln), 0.3, 3))
    return out


def make_bolt(phase: int) -> Image.Image:
    rng = random.Random(77)  # same bolt shape for all phases
    path = main_bolt_path(rng)
    brs = branches(rng, path, 7, 1.0)
    crk = random.Random(900 + phase)
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    if phase == 1:  # lead: thin stroke reaching two thirds of the way down, faint branches
        lead = path[: int(len(path) * 0.7)]
        core = Image.new("L", (FW, FH), 0)
        draw_path(core, lead)
        for b in brs[:3]:
            if b[0] in lead:
                draw_path(core, b[: len(b) // 2])
        img = bolt_layers(core, ["n", "k"], "o")
    elif phase == 2:  # strike: thick white core, cream and blue halo, all branches
        core = Image.new("L", (FW, FH), 0)
        draw_path(core, path, 3)
        thin = Image.new("L", (FW, FH), 0)
        for b in brs:
            draw_path(thin, b)
        both = ImageChops.lighter(core, thin)
        img = bolt_layers(both, ["1", "o", "n", "l", "k"])
        img.alpha_composite(solid(core, "p"))
    elif phase == 3:  # afterglow: thinner, bluer, branches broken
        core = Image.new("L", (FW, FH), 0)
        draw_path(core, path, 2)
        for b in brs:
            draw_path(core, b[: max(2, len(b) * 2 // 3)])
        img = bolt_layers(core, ["n", "l", "k"], "o")
    else:  # fragments: pieces of the path drifting apart, lilac and blue
        core = Image.new("L", (FW, FH), 0)
        lilac = Image.new("L", (FW, FH), 0)
        for i in range(0, len(path) - 2, 3):
            if crk.random() < 0.55:
                dx, dy = crk.uniform(-3, 3), crk.uniform(-2, 2)
                seg = [(x + dx, y + dy) for x, y in path[i:i + 2]]
                draw_path(lilac if crk.random() < 0.35 else core, seg)
        img = bolt_layers(core, ["l", "k"], "n")
        img.alpha_composite(solid(lilac, "v"))
    return up(img, FX_SCALE).crop((0, 0, W, H))


# ---------------------------------------------------------------------------------------------- flash frames
SLOPE = -0.075  # the banner slope of black_form_cutin.gd


def speed_lines(rng: random.Random, n: int, syms: list[str], min_len: int, max_len: int, band: tuple[float, float] = (0.0, 1.0)) -> Image.Image:
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    for _ in range(n):
        y = rng.uniform(band[0], band[1]) * FH
        x = rng.uniform(-40, FW)
        ln = rng.uniform(min_len, max_len)
        thick = rng.random() < 0.3
        m = Image.new("L", (FW, FH), 0)
        d = ImageDraw.Draw(m)
        d.line((round(x), round(y), round(x + ln), round(y + SLOPE * ln)), fill=255)
        if thick:  # tapered: second row only along the middle half
            d.line((round(x + ln * 0.25), round(y + 1 + SLOPE * ln * 0.25), round(x + ln * 0.75), round(y + 1 + SLOPE * ln * 0.75)), fill=255)
        img.alpha_composite(solid(m, rng.choice(syms)))
    return img


def make_flash(phase: int) -> Image.Image:
    rng = random.Random(40 + phase)
    if phase == 1:  # full white pop with blue speed lines and a dark horizontal bolt
        img = Image.new("RGBA", (FW, FH), col("p"))
        img.alpha_composite(speed_lines(rng, 70, ["o", "o", "n", "1"], 20, 90))
        core = Image.new("L", (FW, FH), 0)
        draw_path(core, jagged(rng, (-4, FH * 0.55), (FW + 4, FH * 0.55 + SLOPE * FW), 0.08, 5), 2)
        img.alpha_composite(bolt_layers(core, ["n"], "k"))
    elif phase == 2:  # dense full-width speed lines and a thin horizontal bolt, no fill
        img = speed_lines(rng, 75, ["p", "p", "o", "1", "v", "n"], 30, 140)
        core = Image.new("L", (FW, FH), 0)
        draw_path(core, jagged(rng, (-4, FH * 0.42), (FW + 4, FH * 0.42 + SLOPE * FW), 0.07, 5))
        img.alpha_composite(bolt_layers(core, ["n", "k"]))
    else:  # thinning out
        img = speed_lines(rng, 40, ["o", "n", "v", "l"], 20, 80)
    return up(img, FX_SCALE).crop((0, 0, W, H))


# ---------------------------------------------------------------------------------------- preview (viewing)
BG = (6, 3, 16)
BAN_TOP = col("k")[:3]
BAN_BOT = (8, 10, 24)
CREAM = col("1")[:3]
PALE = col("p")[:3]
BLUE = col("n")[:3]
INK = col("0")[:3]
TOP0, BOT0, LEFT0, RIGHT_TOP, RIGHT_BOT, FIG_SCALE = 112.0, 352.0, -90.0, 640.0, 575.0, 0.63
FPS = 30
FIG_FIT = {"crouch": 1.0, "ready": 0.92, "burst": 0.8}  # preview only: keeps the tall burst pose on screen


def fig_mask(fig, x, y):
    m = Image.new("L", (W, H), 0)
    m.paste(fig.getchannel("A"), (x, y))
    return m

N_FRAMES = 32
# [pose, from, to] in seconds; cuts are where the pose changes
BEATS = [("crouch", 0.10, 0.37), ("ready", 0.37, 0.60), ("burst", 0.60, 1.10)]
CUTS = [0.37, 0.60]
SLAM = 0.66
EXIT = (0.88, 1.04)


def ramp(t, a, b):
    return min(1.0, max(0.0, (t - a) / (b - a)))


def ease_out(x):
    return 1 - (1 - min(1, max(0, x))) ** 3


def ease_in(x):
    return min(1, max(0, x)) ** 3


def ease_back(x):
    v = min(1, max(0, x))
    return 1 + 2.70158 * (v - 1) ** 3 + 1.70158 * (v - 1) ** 2


def banner_offset(t):
    # slams in from the left, then dashes out to the right (lightning leaves forward)
    return -760 * (1 - ease_back(ramp(t, 0.03, 0.17))) + 900 * ease_in(ramp(t, *EXIT))


def y_top(x, off):
    return TOP0 + SLOPE * (x - off)


def y_bot(x, off):
    return BOT0 + SLOPE * (x - off)


def banner_poly(off):
    l, rt, rb = LEFT0 + off, RIGHT_TOP + off, RIGHT_BOT + off
    return [(l, y_top(l, off)), (rt, y_top(rt, off)), (rb, y_bot(rb, off)), (l, y_bot(l, off))]


def poly_mask(poly):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return m


GRAD = Image.linear_gradient("L").resize((W, H))
BAN_BG = Image.composite(Image.new("RGBA", (W, H), BAN_BOT + (255,)), Image.new("RGBA", (W, H), BAN_TOP + (255,)), GRAD)


def with_opacity(img, o):
    if o >= 1:
        return img
    out = img.copy()
    out.putalpha(img.getchannel("A").point(lambda v: int(v * o)))
    return out


def render_preview(assets) -> list[Image.Image]:
    poses, aura, bolts, flashes = assets
    font = ImageFont.truetype(str(FONT), 64)
    frames = []
    for k in range(N_FRAMES):
        t = k / FPS
        frame = Image.new("RGBA", (W, H), BG + (255,))
        off = banner_offset(t)
        poly = banner_poly(off)
        pm = poly_mask(poly)
        rng = random.Random(3000 + k)
        shake = (0, 0)
        for cut in CUTS + [SLAM]:
            if cut <= t < cut + 0.1:
                shake = (rng.randint(-6, 6), rng.randint(-4, 4))
        beat = next((b for b in BEATS if b[1] <= t < b[2]), None)
        impact = False
        layer = BAN_BG.copy()
        # backdrop bolt on the banner during the burst; a lead flicker during the crouch
        bt = None
        if t >= 0.60:
            bt = [1, 2, 2, 3, 3, 4, 4][min(6, int((t - 0.60) * FPS))] if t < 0.60 + 7 / FPS else (3 if (k % 4) < 2 else 4)
        elif 0.2 <= t < 0.37 and k % 3 == 0:
            bt = 4
        strike_out = bt == 2  # the strike breaks out of the banner over the whole screen
        if bt and not strike_out:
            layer.alpha_composite(bolts[bt - 1], (int(off * 0.2), 0))
        layer.alpha_composite(speed_lines_layer(k, off))
        if beat:
            # crackle aura behind the figure
            fx = off + 330
            strength = ramp(t, 0.15, 0.3)
            if strength > 0:
                af = aura[(k // 2) % len(aura)]
                hgt = 250 if beat[0] != "burst" else 310
                af = af.resize((int(af.width * hgt / af.height), hgt), Image.NEAREST)
                if (k // 2) % 2:
                    af = af.transpose(Image.FLIP_LEFT_RIGHT)
                layer.alpha_composite(af, (int(fx - af.width / 2), int(y_bot(fx, off) - hgt)))
            impact = any(c <= t < c + 1 / FPS + 1e-6 for c in CUTS)
            img, meta = poses[beat[0]][1 if impact else 0], poses[beat[0]][2]
            local = t - beat[1]
            s = 1.12 if local < 0.07 else 1.0 + 0.10 * (1 - ease_out((local - 0.07) / 0.12)) + 0.05 * ramp(local, 0.07, 0.6)
            sc = FIG_SCALE * FIG_FIT[beat[0]] * s
            if impact:
                layer.paste(Image.new("RGBA", (W, H), PALE + (255,)), (0, 0))
                layer.alpha_composite(radial(k, (fx, 230)))
            iw = int(img.width * sc)
            ih = int(img.height * sc)
            fig = img.resize((iw, ih), Image.NEAREST)
            feet_x = fx + (24 * ease_out(local / 0.3) if beat[0] == "burst" else 0)
            px_ = feet_x - meta["pad"] * sc - meta["inner_w"] * sc * meta["feet_x"] + shake[0]
            py_ = y_bot(feet_x, off) - 4 - (ih - meta["pad"] * sc) + shake[1]
            if impact:  # the impact frame stays inside the banner
                layer.alpha_composite(fig, (int(px_), int(py_)))
            if any(c + 1 / FPS <= t < c + 2 / FPS + 1e-6 for c in CUTS):
                layer.alpha_composite(Image.new("RGBA", (W, H), PALE + (95,)))
        if bt and strike_out:
            frame.alpha_composite(bolts[1], (int(off * 0.2), 0))
        frame.paste(layer, (0, 0), pm)
        if beat and not impact:  # the lit figure breaks out of the banner's top edge (MLBB style)
            frame.alpha_composite(fig, (int(px_), int(py_)))
            if any(c + 1 / FPS <= t < c + 2 / FPS + 1e-6 for c in CUTS):
                veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                veil.paste(Image.new("RGBA", (W, H), PALE + (95,)), (0, 0), fig_mask(fig, int(px_), int(py_)))
                frame.alpha_composite(veil)
        # border
        bd = ImageDraw.Draw(frame)
        loop = poly + [poly[0]]
        bd.line(loop, fill=BLUE, width=10)
        bd.line(loop, fill=CREAM, width=4)
        # full-screen pops
        fi = None
        if t < 1 / FPS:
            fi = 1
        elif t < 3 / FPS:
            fi = 2
        elif t < 5 / FPS:
            fi = 3
        elif 0.60 <= t < 0.60 + 1 / FPS:
            fi = 2
        elif 0.60 + 1 / FPS <= t < 0.60 + 3 / FPS:
            fi = 3
        if fi:
            frame.alpha_composite(flashes[fi - 1])
        if t >= SLAM and off < 700:
            frame.alpha_composite(title(font, t, off, shake))
        if EXIT[0] <= t:
            frame.alpha_composite(exit_smear(k, off))
        frames.append(frame.convert("RGB"))
    return frames


def speed_lines_layer(k, off):
    rng = random.Random(300 + k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(22):
        y = rng.uniform(70, 380)
        x = rng.uniform(-100, 760) + off
        ln = rng.uniform(60, 260)
        c = rng.choice([PALE, CREAM, BLUE, col("v")[:3]])
        d.line((x, y, x + ln, y + SLOPE * ln), fill=c + (rng.randint(80, 170),), width=rng.choice([2, 2, 4]))
    return img


def radial(k, centre):
    rng = random.Random(900 + k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(36):
        a = rng.uniform(0, math.tau)
        r0, r1 = rng.uniform(90, 150), rng.uniform(300, 600)
        d.line((centre[0] + math.cos(a) * r0, centre[1] + math.sin(a) * r0, centre[0] + math.cos(a) * r1, centre[1] + math.sin(a) * r1), fill=BLUE + (255,), width=rng.choice([2, 4]))
    return img


def title(font, t, off, shake):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    label = "LIGHTNING FORM"
    tx = ramp(t, SLAM, SLAM + 0.08)
    size = int(52 * (1 + 0.25 * (1 - ease_out(tx))))
    f = font.font_variant(size=size)
    cx = off + 260 + shake[0]
    cy = y_bot(cx, off) + 18 + shake[1]
    d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), label, font=f, stroke_width=6)
    org = (cx - (bb[2] - bb[0]) / 2, cy - (bb[3] - bb[1]) / 2)
    d.text((org[0] + 4, org[1] + 5), label, font=f, fill=INK, stroke_width=6, stroke_fill=INK)
    d.text(org, label, font=f, fill=PALE, stroke_width=6, stroke_fill=col("l")[:3])
    d.text(org, label, font=f, fill=CREAM)
    return img.transform(img.size, Image.AFFINE, (1, 0.22, -0.22 * cy, 0, 1, 0), Image.NEAREST)


def exit_smear(k, off):
    rng = random.Random(k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lx = LEFT0 + off
    for _ in range(16):
        y = rng.uniform(100, 360)
        d.line((lx - rng.uniform(80, 360), y, lx + 20, y + SLOPE * 100), fill=rng.choice([PALE, BLUE, CREAM]) + (200,), width=rng.choice([2, 2, 4]))
    return img


def contact_sheet(frames, poses, bolts, flashes) -> Image.Image:
    cw, ch = 320, 180  # game scale
    cols = 6
    rows = math.ceil(len(frames) / cols)
    lab = 14
    small = ImageFont.truetype(str(FONT), 11)
    assets_h = 260
    sheet = Image.new("RGB", (cols * (cw + 6) + 6, rows * (ch + lab + 6) + 6 + assets_h), BG)
    d = ImageDraw.Draw(sheet)
    for i, fr in enumerate(frames):
        x = 6 + (i % cols) * (cw + 6)
        y = 6 + (i // cols) * (ch + lab + 6)
        d.text((x, y), f"f{i}  t={i / FPS:.2f}s", font=small, fill=(200, 200, 220))
        sheet.paste(fr.resize((cw, ch), Image.LANCZOS), (x, y + lab))
    # raw assets along the bottom, scaled to fit
    y0 = 6 + rows * (ch + lab + 6) + 4
    x = 6
    items = []
    for name, (lit, sil, _) in poses.items():
        items += [(f"pose_{name}", lit), (f"pose_{name}_sil", sil)]
    for i, b in enumerate(bolts):
        items.append((f"bolt_{i + 1}", b))
    for i, f in enumerate(flashes):
        items.append((f"flash_{i + 1}", f))
    hh = 108
    row_y = y0
    for name, img in items:
        s = hh / img.height
        th = img.resize((max(1, int(img.width * s)), hh), Image.BOX)
        if x + th.width > sheet.width - 6:
            x = 6
            row_y += hh + lab + 6
        d.text((x, row_y), name, font=small, fill=(200, 200, 220))
        tile = Image.new("RGBA", th.size, (30, 26, 44, 255))
        tile.alpha_composite(th.convert("RGBA"))
        sheet.paste(tile.convert("RGB"), (x, row_y + lab))
        x += th.width + 8
    return sheet.crop((0, 0, sheet.width, row_y + hh + lab + 8))


# ------------------------------------------------------------------------------------------------------- main
def check_hard(img: Image.Image, name: str) -> None:
    allowed = {PAL.by_symbol[s] for s in PAL.by_symbol if s not in FORBIDDEN}
    for _, (r, g, b, a) in img.getcolors(1 << 20):
        if a not in (0, 255):
            raise SystemExit(f"{name}: semi-transparent pixel")
        if a == 255 and (r, g, b) not in allowed:
            raise SystemExit(f"{name}: colour {(r, g, b)} is not an allowed palette colour")


def save(img: Image.Image, name: str, written: list) -> None:
    check_hard(img, name)
    img.save(OUT / name)
    written.append(name)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    meta: dict = {
        "generator": "tools/art/export_lightning_cutin.py (Pillow only, fixed seeds)",
        "canvas": [W, H],
        "palette": "Totoy 36, hard alpha; no gold x,y or red z,A",
        "pose_scale": POSE_SCALE, "aura_scale": AURA_SCALE, "fx_scale": FX_SCALE,
        "poses": {}, "aura": {}, "bolts": [], "flashes": [],
        "timing_s": {"note": "suggested, preview seconds at 30 fps; the game may scale them like black_form SPEED",
                     "flash_pop": [0.0, 0.167], "banner_in": [0.03, 0.17], "beats": BEATS, "cuts": CUTS,
                     "bolt_on_burst": [[1, 0.033], [2, 0.067], [3, 0.067], [4, 0.067], ["3/4 flicker", "until exit"]],
                     "title_slam": SLAM, "exit": list(EXIT), "end": EXIT[1]},
    }
    poses = {}
    for name in POSES:
        lit, sil, m = make_pose(name)
        save(lit, f"lightning_pose_{name}.png", written)
        save(sil, f"lightning_pose_{name}_sil.png", written)
        meta["poses"][name] = m
        poses[name] = (lit, sil, m)
    aura = [make_aura_frame(i) for i in range(12)]
    cw, chh = aura[0].size
    atlas = Image.new("RGBA", (cw * 6, chh * 2), (0, 0, 0, 0))
    frames = []
    for i, a in enumerate(aura):
        x0, y0 = (i % 6) * cw, (i // 6) * chh
        atlas.alpha_composite(a, (x0, y0))
        frames.append({"x": x0, "y": y0, "w": cw, "h": chh})
    save(atlas, "lightning_aura.png", written)
    meta["aura"] = {"cell_w": cw, "cell_h": chh, "frames": frames, "anchor": "bottom centre"}
    bolts = [make_bolt(p) for p in range(1, 5)]
    for i, b in enumerate(bolts):
        save(b, f"lightning_bolt_{i + 1}.png", written)
        meta["bolts"].append(f"lightning_bolt_{i + 1}.png")
    flashes = [make_flash(p) for p in range(1, 4)]
    for i, f in enumerate(flashes):
        save(f, f"lightning_flash_{i + 1}.png", written)
        meta["flashes"].append(f"lightning_flash_{i + 1}.png")
    (OUT / "lightning_cutin.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    written.append("lightning_cutin.json")
    preview = render_preview((poses, aura, bolts, flashes))
    gif = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in preview]
    gif[0].save(OUT / "lightning_cutin_preview.gif", save_all=True, append_images=gif[1:], duration=33, loop=0, disposal=1)
    written.append("lightning_cutin_preview.gif")
    contact_sheet(preview, poses, bolts, flashes).save(OUT / "lightning_cutin_contact.png")
    written.append("lightning_cutin_contact.png")
    for n in written:
        print(n)
    print("wrote", len(written), "files to", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
