"""Export the Black Form cut-in art (presentation/cutin/black_form_*) in the shared cut-in format.

The format is the one the human approved for the Lightning Form cut-in ("this will be our cutout art format",
tools/art/export_lightning_cutin.py): pixel-art pose cut-outs in the Totoy 36 palette with hard alpha, scaled up with
integer nearest-neighbour; a 1px dark gap and a coloured rim with a ramp falloff; ink impact silhouettes; a 12-frame
aura atlas; four backdrop effect frames; three full-screen flash frames; a json with sizes, anchors and timings; a
preview GIF and a contact sheet. The mask/drawing helpers are imported from export_lightning_cutin.py so both cut-ins
are built the same way (importing it writes nothing).

Black Form differences: the poses are the black-katana concept poses (art/reference/black_katana_form/concept_v1.png,
painted, isolated by connected blobs as before, then reduced to pixel art at 1/POSE_SCALE and snapped to the palette),
the colour language is ink / indigo / lilac with cream and pale highlights, the effects are dark smoke wisps and violet
katana slashes instead of lightning bolts, and the banner leaves to the left.

Outputs (presentation/cutin/):
  black_form_pose_<name>.png       lit pose: violet rim light, 1px ink gap, pale/lilac/indigo rim, smoke wisps (x6)
  black_form_pose_<name>_sil.png   the same pose as an ink silhouette with a cream line and a lilac outline (impact)
                                   name: crouch (concept "activation crouch"), ready ("empowered ready"),
                                         burst ("rising black slash")
  black_form_aura.png              12 dark-flame frames (6x2 atlas, x8), bottom-centred, loop behind the figure
  black_form_slash_<1..4>.png      800x450 backdrop: a big katana crescent (lead, strike, afterglow, fragments) (x4)
  black_form_flash_<1..3>.png      800x450 full-width pop: ink flash with a cream cut, then speed lines fading (x4)
  black_form_cutin.json            sizes, anchors, atlas frames, file lists and suggested timings
  black_form_cutin_preview.gif     about 1 s at 30 fps on the dark cut-in background (viewing only)
  black_form_cutin_contact.png     every preview frame at 320x180 (game scale) plus the raw assets (viewing only)
Pillow only, fixed seeds (re-running gives identical files). Run from the project root:
  python tools/art/export_black_form_cutin.py
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
from export_lightning_cutin import (  # noqa: E402  shared cut-in format helpers
    FONT, FPS, H, LEFT0, RIGHT_TOP, SLOPE, FIG_SCALE, W, FW, FH, FX_SCALE, AURA_SCALE,
    alpha_mask, banner_poly, check_hard, dilate, ease_back, ease_in, ease_out, minus, poly_mask, ramp,
    solid, up, y_bot,
)

ROOT = artlib.ROOT
OUT = ROOT / "presentation" / "cutin"
REF = ROOT / "art" / "reference" / "black_katana_form"
PAL = artlib.load_palette()
FORBIDDEN = set(PAL.reserved)

POSE_SCALE = 6        # pose pixels -> cut-in canvas units (the painted poses need more pixels than the 64px dagger frames)
RING = 2              # 1x pixels per rim ring, so the rim is as thick on screen as the lightning rim (12 canvas units)
PAD = 18              # 1x pixels of room around a pose for the rim and the wisps
# name: (sheet cell, 1x height, feet x as a fraction of the un-padded cut-out, wisp count, seed)
POSES = {"crouch": (0, 50, 0.47, 6, 21), "ready": (1, 64, 0.47, 8, 22), "burst": (4, 72, 0.42, 9, 23)}
# body colours the painted poses snap to (no greens, teal or bright blues: they would read as stray spots)
BODY_SYMS = "01" + "89abcd" + "efghij" + "kl" + "qrs" + "v"


def col(sym: str) -> tuple[int, int, int, int]:
    assert sym not in FORBIDDEN, f"reserved colour {sym}"
    return PAL.by_symbol[sym] + (255,)


# ------------------------------------------------------------------------------------- pose isolation (painted)
concept = Image.open(REF / "concept_v1.png").convert("RGBA")


def isolate_poses() -> dict[int, Image.Image]:
    """The six figures overlap their neighbours on the sheet, so each is isolated by connected blobs (the six
    biggest are the figures; small flecks join the nearest figure). Returns cell index -> RGBA crop."""
    S = 2
    small = concept.getchannel("A").resize((concept.width // S, concept.height // S), Image.BOX)
    m = small.point(lambda v: 255 if v > 12 else 0)
    w, h = m.size
    px = list(m.tobytes())
    lab = [0] * (w * h)
    comps = []  # (count, bbox)
    for start in range(w * h):
        if px[start] and not lab[start]:
            n = len(comps) + 1
            lab[start] = n
            st = [start]
            cnt = 0
            x0 = y0 = 10 ** 9
            x1 = y1 = -1
            while st:
                i = st.pop()
                cnt += 1
                y, x = divmod(i, w)
                x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
                for j in ((i + 1) if x + 1 < w else -1, (i - 1) if x > 0 else -1, (i + w) if y + 1 < h else -1, (i - w) if y > 0 else -1):
                    if j >= 0 and px[j] and not lab[j]:
                        lab[j] = n
                        st.append(j)
            comps.append((cnt, (x0, y0, x1, y1)))
    order = sorted(range(len(comps)), key=lambda c: -comps[c][0])
    cores = order[:6]

    def cell_of(c: int) -> int:
        x0, y0, x1, y1 = comps[c][1]
        cx, cy = (x0 + x1) / 2 * S, (y0 + y1) / 2 * S
        return int(cy // (concept.height / 2)) * 3 + int(cx // (concept.width / 3))

    def box_dist(a, b) -> float:
        dx = max(0, max(a[0], b[0]) - min(a[2], b[2]))
        dy = max(0, max(a[1], b[1]) - min(a[3], b[3]))
        return math.hypot(dx, dy)

    owner = {}
    for c in range(len(comps)):
        if c in cores:
            owner[c + 1] = c
            continue
        best, bd = None, 1e9
        for k in cores:
            dd = box_dist(comps[c][1], comps[k][1])
            if dd < bd:
                best, bd = k, dd
        if bd <= 24:  # 48 px at full size
            owner[c + 1] = best
    poses = {}
    for core in cores:
        keep = bytes(255 if (l and owner.get(l) == core) else 0 for l in lab)
        mask = Image.frombytes("L", (w, h), keep).resize(concept.size, Image.NEAREST).filter(ImageFilter.MaxFilter(3))
        img = concept.copy()
        img.putalpha(ImageChops.multiply(concept.getchannel("A"), mask))
        poses[cell_of(core)] = img.crop(mask.getbbox())
    return poses


# ------------------------------------------------------------------------------------- painted -> pixel art
BODY_COLS = [(s, PAL.by_symbol[s]) for s in BODY_SYMS]


def nearest_sym(rgb: tuple[int, int, int]) -> str:
    r, g, b = rgb
    return min(BODY_COLS, key=lambda c: (c[1][0] - r) ** 2 * 3 + (c[1][1] - g) ** 2 * 4 + (c[1][2] - b) ** 2 * 2)[0]


def components(mask: Image.Image) -> list[list[tuple[int, int]]]:
    w, h = mask.size
    on = mask.load()
    seen = set()
    out = []
    for y in range(h):
        for x in range(w):
            if on[x, y] and (x, y) not in seen:
                st, comp = [(x, y)], []
                seen.add((x, y))
                while st:
                    p = st.pop()
                    comp.append(p)
                    for q in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)):
                        if 0 <= q[0] < w and 0 <= q[1] < h and on[q] and q not in seen:
                            seen.add(q)
                            st.append(q)
                out.append(comp)
    return out


def strip_smoke(img: Image.Image) -> Image.Image:
    """Removes the painted smoke ribbons: they are wide near-black areas, while his own black outlines are thin, so an
    opening (erode, dilate) of the near-black-or-transparent mask finds the smoke and leaves the outlines. The cut-in
    draws its own wisps and slash instead. Returns the figure cropped to what is left."""
    r, g, b, a = img.split()
    brightest = ImageChops.lighter(ImageChops.lighter(r, g), b)
    opaque = a.point(lambda v: 255 if v >= 128 else 0)
    dark_or_clear = ImageChops.lighter(ImageChops.multiply(brightest.point(lambda v: 255 if v < 34 else 0), opaque),
                                       ImageChops.invert(opaque))
    wide = dark_or_clear.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))
    out = img.copy()
    out.putalpha(ImageChops.subtract(opaque, wide))
    return out.crop(out.getchannel("A").getbbox())


def pixelate(img: Image.Image, h1: int) -> Image.Image:
    """Area-average the painting down to h1 rows (premultiplied, so the dark edges do not grey out), cut the alpha hard
    at 45%, lift the near-black tones a little so the clothes keep their folds, snap to BODY_SYMS, keep the figure (the
    biggest piece) and fill the holes the smoke left with ink."""
    img = strip_smoke(img)
    k = img.height / h1
    w1 = max(1, round(img.width / k))
    a = img.getchannel("A")
    rgb = Image.composite(img.convert("RGB"), Image.new("RGB", img.size, (0, 0, 0)), a)
    small_rgb = rgb.resize((w1, h1), Image.BOX).load()
    small_a = a.resize((w1, h1), Image.BOX).load()
    out = Image.new("RGBA", (w1, h1), (0, 0, 0, 0))
    po = out.load()
    for y in range(h1):
        for x in range(w1):
            al = small_a[x, y]
            if al < 115:
                continue
            c = [min(255, v * 255 / al) for v in small_rgb[x, y]]
            lum = (c[0] * 3 + c[1] * 4 + c[2] * 2) / 9
            if lum < 70:  # gentle lift of the darks (clothes, smoke): 0..70 -> 0..84, keeps their hue
                gain = (84 * (lum / 70) ** 0.8) / max(lum, 1)
                c = [v * gain for v in c]
            po[x, y] = col(nearest_sym(tuple(int(v) for v in c)))
    m = alpha_mask(out)
    parts = components(m)
    biggest = max(len(c) for c in parts)
    for comp in parts:
        if len(comp) < max(12, biggest * 0.04):  # loose smoke flecks would each get their own rim
            for p in comp:
                po[p] = (0, 0, 0, 0)
    # the painted smoke leaves gaps between the limbs; close them (dilate, erode) and fill every enclosed hole with
    # ink, so the rim only runs around the outside
    m = alpha_mask(out)
    pad = 3
    big = Image.new("L", (w1 + 2 * pad, h1 + 2 * pad), 0)
    big.paste(m, (pad, pad))
    closed = big.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
    ImageDraw.floodfill(closed, (0, 0), 128)
    solid_mask = closed.point(lambda v: 0 if v == 128 else 255).crop((pad, pad, pad + w1, pad + h1))
    sm = solid_mask.load()
    for y in range(h1):
        for x in range(w1):
            if sm[x, y] and not po[x, y][3]:
                po[x, y] = col("0")
    return out


DARK = set("089ef")      # clothes, smoke, hair shadow: the violet rim light turns these lilac
RAMPS = ["89abcd", "efghij", "qrs"]
LIGHTER = {r[i]: r[i + 1] for r in RAMPS for i in range(len(r) - 1)}


def rim_light(body: Image.Image) -> Image.Image:
    """Violet light from behind and above: the body's top/left edge pixels go lilac on dark cloth and smoke, one step
    lighter on skin, hair and leather (the dark gap ring outside keeps the silhouette)."""
    out = body.copy()
    a = alpha_mask(body)
    edge = minus(a, ImageChops.darker(ImageChops.offset(a, 1, 0), ImageChops.offset(a, 0, 1)))
    sym_of = {v: k for k, v in PAL.by_symbol.items()}
    src, px, em = body.load(), out.load(), edge.load()
    for y in range(body.height):
        for x in range(body.width):
            if not em[x, y]:
                continue
            sym = sym_of.get(src[x, y][:3])
            if sym in DARK:
                px[x, y] = col("v")
            elif sym in LIGHTER:
                px[x, y] = col(LIGHTER[sym])
    return out


def wisps(rng: random.Random, body: Image.Image, count: int, start: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Thin smoke tendrils curling up and out from the edge of the `start` mask. Returns (wisp mask, pale tip mask)."""
    a = alpha_mask(body)
    edge = minus(dilate(start, 1), start)
    pts = [(x, y) for y in range(edge.height) for x in range(edge.width) if edge.getpixel((x, y))]
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    top_y, bot_y = min(p[1] for p in pts), max(p[1] for p in pts)
    upper = [p for p in pts if top_y + (bot_y - top_y) * 0.18 < p[1] < top_y + (bot_y - top_y) * 0.7] or pts
    smoke = Image.new("L", body.size, 0)
    tips = Image.new("L", body.size, 0)
    d = ImageDraw.Draw(smoke)
    for _ in range(count):
        x, y = rng.choice(upper)
        ang = math.atan2(y - cy, x - cx) * 0.55 - math.pi / 2 * 0.45 + rng.uniform(-0.35, 0.35)  # out and upward
        ln = rng.uniform(7.0, 13.0) * (1.0 + count / 30.0)
        curl = rng.choice((-1, 1)) * rng.uniform(0.6, 1.3)
        steps = 12
        last = (x, y)
        for s in range(1, steps + 1):
            f = s / steps
            a2 = ang + curl * f * f * 1.8
            p = (last[0] + math.cos(a2) * ln / steps, last[1] + math.sin(a2) * ln / steps)
            if not (3 <= p[0] < body.width - 3 and 3 <= p[1] < body.height - 3):
                break  # stop at the canvas margin (dilate wraps around)
            d.line((round(last[0]), round(last[1]), round(p[0]), round(p[1])), fill=255, width=2 if f < 0.3 else 1)
            last = p
        tx, ty = round(last[0]), round(last[1])
        if rng.random() < 0.6:
            tips.putpixel((tx, ty), 255)
    return minus(smoke, start), minus(tips, start)


def make_pose(name: str, painted: Image.Image) -> tuple[Image.Image, Image.Image, dict]:
    cell, h1, feet_x, n_wisps, seed = POSES[name]
    px = pixelate(painted, h1)
    bb = alpha_mask(px).getbbox()
    px = px.crop(bb)
    body = Image.new("RGBA", (px.width + 2 * PAD, px.height + 2 * PAD), (0, 0, 0, 0))
    body.alpha_composite(px, (PAD, PAD))
    a = alpha_mask(body)
    rng = random.Random(seed)
    d1 = dilate(a, 1)                      # the 1px ink gap keeps his outline
    halo = d1
    r1 = dilate(halo, RING)                # lilac rim
    r2 = dilate(r1, RING)                  # indigo
    r3 = dilate(r2, 1, diamond=False)      # ink falloff, so the rim reads on the violet banner
    lit_from = minus(r1, ImageChops.darker(ImageChops.offset(r1, 0, 1), ImageChops.offset(r1, 1, 0)))  # top/left
    lit = Image.new("RGBA", body.size, (0, 0, 0, 0))
    lit.alpha_composite(solid(minus(r3, r2), "0"))
    lit.alpha_composite(solid(minus(r2, r1), "k"))
    lit.alpha_composite(solid(minus(r1, halo), "v"))
    lit.alpha_composite(solid(minus(lit_from, halo), "p"))           # pale catch-light on the top/left of the rim
    lit.alpha_composite(solid(minus(halo, a), "0"))                  # gap ring and the wisps' bodies: ink
    lit.alpha_composite(rim_light(body))
    smoke, tips = wisps(rng, body, n_wisps, r1)   # tendrils leave the lilac rim: ink core, lilac edge, cream mote
    lit.alpha_composite(solid(minus(dilate(smoke, 1), r1), "v"))
    lit.alpha_composite(solid(smoke, "0"))
    lit.alpha_composite(solid(tips, "1"))
    # impact silhouette: ink body, cream line, lilac outline with more tendrils
    rng2 = random.Random(seed + 100)
    s_line = dilate(d1, RING)
    s_smoke, s_tips = wisps(rng2, body, n_wisps + 6, s_line)
    sil = Image.new("RGBA", body.size, (0, 0, 0, 0))
    sil.alpha_composite(solid(minus(s_line, d1), "v"))
    sil.alpha_composite(solid(minus(dilate(s_smoke, 1), s_line), "v"))
    sil.alpha_composite(solid(s_smoke, "0"))
    sil.alpha_composite(solid(minus(d1, a), "1"))
    sil.alpha_composite(solid(a, "0"))
    sil.alpha_composite(solid(minus(s_tips, d1), "1"))
    k = POSE_SCALE
    meta = {"w": body.width * k, "h": body.height * k, "pad": PAD * k, "inner_w": px.width * k,
            "inner_h": px.height * k, "feet_x": feet_x, "source": f"concept_v1.png sheet cell {cell}"}
    return up(lit, k), up(sil, k), meta


# ------------------------------------------------------------------------------------------- aura (dark flames)
def flame_mask(rng: random.Random, w: int, h: int, i: int, m: int) -> tuple[Image.Image, Image.Image]:
    """Thin tongues of dark flame rising from the feet and swaying, on a canvas with a margin m.
    Returns (flame, centre streak)."""
    flame = Image.new("L", (w + 2 * m, h + 2 * m), 0)
    streak = Image.new("L", flame.size, 0)
    d, ds = ImageDraw.Draw(flame), ImageDraw.Draw(streak)
    phase = i / 12 * math.tau
    for j in range(6 + i % 3):
        bx = m + w / 2 + rng.uniform(-12, 12)
        side = -1 if bx < m + w / 2 else 1
        top = m + rng.uniform(3, 30)
        lean = side * rng.uniform(1, 7)
        width0 = rng.uniform(2.0, 4.2)
        sway = rng.uniform(1.0, 2.6)
        pts = []
        n = 20
        for s in range(n + 1):
            f = s / n
            y = (m + h - 1) - f * (m + h - 1 - top)
            x = bx + lean * f * f + math.sin(phase + j * 1.9 + f * 5.0) * sway * f
            r = width0 * (1 - f) ** 0.9 + 0.4
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
            pts.append((x, y))
        ds.line([(round(x), round(y)) for x, y in pts[2:13]], fill=255)

    flame = flame.point(lambda v: 255 if v > 127 else 0)
    return flame, ImageChops.multiply(streak, flame.filter(ImageFilter.MinFilter(3)))


def make_aura_frame(i: int) -> Image.Image:
    rng = random.Random(600 + i)
    w, h, m = 48, 56, 4
    flame, streak = flame_mask(rng, w, h, i, m)
    img = Image.new("RGBA", flame.size, (0, 0, 0, 0))
    img.alpha_composite(solid(minus(dilate(flame, 1), flame), "v"))   # lilac outline, ink body, indigo streak
    img.alpha_composite(solid(flame, "0"))
    img.alpha_composite(solid(streak, "k"))
    sparks = Image.new("L", flame.size, 0)
    for _ in range(4):
        sparks.putpixel((m + rng.randrange(6, w - 6), m + rng.randrange(1, h // 2)), 255)
    halo = dilate(flame, 2)
    img.alpha_composite(solid(minus(sparks, halo), rng.choice(["p", "1"])))
    return up(img.crop((m, m, m + w, m + h)), AURA_SCALE)

# --------------------------------------------------------------------------------------- backdrop slashes
def crescent(cx: float, cy: float, r: float, a0: float, a1: float, thick: float, taper: float = 1.0) -> list[tuple[float, float]]:
    """A katana-cut crescent along a circle arc: thickest in the middle, pointed at both ends."""
    n = 48
    outer, inner = [], []
    for s in range(n + 1):
        f = s / n
        a = a0 + (a1 - a0) * f
        t = thick * math.sin(math.pi * f) ** taper
        outer.append((cx + math.cos(a) * (r + t / 2), cy + math.sin(a) * (r + t / 2)))
        inner.append((cx + math.cos(a) * (r - t / 2), cy + math.sin(a) * (r - t / 2)))
    return outer + inner[::-1]


def circle_through(p1, p2, p3) -> tuple[float, float, float]:
    ax, ay = p1
    bx, by = p2
    cx, cy = p3
    d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
    uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
    return ux, uy, math.hypot(ax - ux, ay - uy)


# the big cut: a long rising arc from the bottom left to the top right (the burst pose swings the katana up)
_P = ((FW * 0.08, FH + 12.0), (FW * 0.5, FH * 0.5), (FW * 0.98, -12.0))
_CX, _CY, _R = circle_through(*_P)
SLASH = (_CX, _CY, _R, math.atan2(_P[0][1] - _CY, _P[0][0] - _CX), math.atan2(_P[2][1] - _CY, _P[2][0] - _CX))
SLASH_THICK = 26.0


def slash_shape(scale_thick: float, frac: tuple[float, float] = (0.0, 1.0), off_r: float = 0.0) -> Image.Image:
    cx, cy, r, a0, a1 = SLASH
    b0, b1 = a0 + (a1 - a0) * frac[0], a0 + (a1 - a0) * frac[1]
    m = Image.new("L", (FW, FH), 0)
    ImageDraw.Draw(m).polygon(crescent(cx, cy, r + off_r, b0, b1, SLASH_THICK * scale_thick, 0.8), fill=255)
    return m


def outer_edge(scale_thick: float, frac: tuple[float, float] = (0.0, 1.0)) -> Image.Image:
    """The bright leading edge on the outside of a crescent of the same size."""
    return slash_shape(0.12, frac, SLASH_THICK * scale_thick * 0.42)

def rings(core: Image.Image, syms: list[str], core_sym: str) -> Image.Image:
    out = Image.new("RGBA", core.size, (0, 0, 0, 0))
    m = core
    layers = []
    for sym in syms:
        big = dilate(m, 1)
        layers.append((minus(big, m), sym))
        m = big
    for ring, sym in reversed(layers):
        out.alpha_composite(solid(ring, sym))
    out.alpha_composite(solid(core, core_sym))
    return out


def graded(scale_thick: float, frac: tuple[float, float], bands: list[tuple[str, float, float]]) -> Image.Image:
    """A crescent shaded across its width: each band (colour, radial offset, thickness, as fractions of the full
    thickness) is a narrower crescent nested towards the outer, cutting edge."""
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    t = SLASH_THICK * scale_thick
    for sym, off, thick in bands:
        img.alpha_composite(solid(slash_shape(scale_thick * thick, frac, t * off), sym))
    return img


# ink body, indigo, lilac, pale, cream edge (outermost)
STRIKE_BANDS = [("0", 0.0, 1.0), ("k", 0.16, 0.66), ("v", 0.3, 0.38), ("p", 0.38, 0.2), ("1", 0.42, 0.11)]


def make_slash(phase: int) -> Image.Image:
    rng = random.Random(70 + phase)
    if phase == 1:  # lead: a thin pale line drawing the first two thirds of the arc
        core = slash_shape(0.12, (0.0, 0.68))
        img = rings(core, ["v", "k"], "p")
    elif phase == 2:  # strike: the black crescent shaded out to a cream cutting edge, two echo cuts inside it
        echo = ImageChops.lighter(slash_shape(0.3, (0.12, 0.9), -SLASH_THICK * 0.7), slash_shape(0.2, (0.22, 0.8), -SLASH_THICK * 1.1))
        img = rings(echo, ["v", "k"], "0")
        img.alpha_composite(rings(slash_shape(1.0), ["v", "k"], "0"))
        img.alpha_composite(graded(1.0, (0.0, 1.0), STRIKE_BANDS))
    elif phase == 3:  # afterglow: thinner, the bright edge gone
        img = rings(slash_shape(0.6, (0.06, 1.0)), ["v", "0"], "0")
        img.alpha_composite(graded(0.6, (0.06, 1.0), [("0", 0.0, 1.0), ("k", 0.2, 0.6), ("v", 0.38, 0.22)]))
    else:  # fragments: pieces of the cut drifting apart (ink with indigo or lilac), a few pale motes
        img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
        for i in range(14):
            if rng.random() < 0.7:
                a0 = i / 14
                shifted = Image.new("L", (FW, FH), 0)
                shifted.paste(slash_shape(0.2, (a0, a0 + 0.1), rng.uniform(-10, 10)), (rng.randint(-5, 5), rng.randint(-4, 4)))
                piece = shifted
                img.alpha_composite(rings(piece, ["0"], "v" if rng.random() < 0.5 else "k"))
        motes = Image.new("L", (FW, FH), 0)
        near = dilate(slash_shape(0.6), 5, diamond=False)
        for _ in range(40):
            x, y = rng.randrange(FW), rng.randrange(FH)
            if near.getpixel((x, y)):
                motes.putpixel((x, y), 255)
        img.alpha_composite(solid(motes, "p"))
    return up(img, FX_SCALE).crop((0, 0, W, H))

# ---------------------------------------------------------------------------------------------- flash frames
def speed_lines(rng: random.Random, n: int, syms: list[str], min_len: int, max_len: int) -> Image.Image:
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    for _ in range(n):
        y = rng.uniform(0, FH)
        x = rng.uniform(-40, FW)
        ln = rng.uniform(min_len, max_len)
        m = Image.new("L", (FW, FH), 0)
        d = ImageDraw.Draw(m)
        d.line((round(x), round(y), round(x + ln), round(y + SLOPE * ln)), fill=255)
        if rng.random() < 0.3:  # tapered: second row only along the middle half
            d.line((round(x + ln * 0.25), round(y + 1 + SLOPE * ln * 0.25), round(x + ln * 0.75), round(y + 1 + SLOPE * ln * 0.75)), fill=255)
        img.alpha_composite(solid(m, rng.choice(syms)))
    return img


def flat_cut(y: float, thick: float) -> Image.Image:
    """A horizontal katana cut across the whole width along the banner slope, pointed at both ends."""
    m = Image.new("L", (FW, FH), 0)
    pts_top, pts_bot = [], []
    for s in range(41):
        f = s / 40
        x = -6 + f * (FW + 12)
        t = thick * math.sin(math.pi * f) ** 0.7
        yy = y + SLOPE * x
        pts_top.append((x, yy - t / 2))
        pts_bot.append((x, yy + t / 2))
    ImageDraw.Draw(m).polygon(pts_top + pts_bot[::-1], fill=255)
    return m


def make_flash(phase: int) -> Image.Image:
    rng = random.Random(50 + phase)
    if phase == 1:  # an ink pop (the world goes black) with lilac speed lines and one cream cut through it
        img = Image.new("RGBA", (FW, FH), col("0"))
        img.alpha_composite(speed_lines(rng, 70, ["k", "k", "v", "l"], 20, 90))
        img.alpha_composite(rings(flat_cut(FH * 0.58, 5), ["p", "v"], "1"))
    elif phase == 2:  # dense full-width speed lines and a thin cut, no fill
        img = speed_lines(rng, 75, ["1", "p", "v", "v", "k", "0"], 30, 140)
        img.alpha_composite(rings(flat_cut(FH * 0.44, 2), ["v", "0"], "1"))
    else:  # thinning out
        img = speed_lines(rng, 40, ["v", "k", "p", "0"], 20, 80)
    return up(img, FX_SCALE).crop((0, 0, W, H))


# ---------------------------------------------------------------------------------------- preview (viewing)
BG = (8, 4, 16)
BAN_TOP = (52, 30, 88)
BAN_BOT = (10, 6, 22)
CREAM = col("1")[:3]
PALE = col("p")[:3]
LILAC = col("v")[:3]
INDIGO = col("k")[:3]
INK = col("0")[:3]
DEEP = (46, 24, 78)
IMPACT = (236, 228, 246)
N_FRAMES = 32
FIG_FIT = {"crouch": 1.0, "ready": 0.92, "burst": 0.84}
BEATS = [("crouch", 0.10, 0.37), ("ready", 0.37, 0.60), ("burst", 0.60, 1.10)]
CUTS = [0.37, 0.60]
SLAM = 0.66
EXIT = (0.88, 1.04)
FIG_X = 330.0


def banner_offset(t: float) -> float:
    # slams in from the left, then dashes back out to the left (the shadow withdraws)
    return -760 * (1 - ease_back(ramp(t, 0.03, 0.17))) - 900 * ease_in(ramp(t, *EXIT))


GRAD = Image.linear_gradient("L").resize((W, H))
BAN_BG = Image.composite(Image.new("RGBA", (W, H), BAN_BOT + (255,)), Image.new("RGBA", (W, H), BAN_TOP + (255,)), GRAD)


def slash_at(t: float, k: int) -> int:
    if t >= 0.60:
        n = int((t - 0.60) * FPS)
        return [1, 2, 2, 3, 3, 4, 4][n] if n < 7 else (3 if k % 4 < 2 else 4)
    if 0.2 <= t < 0.37 and k % 3 == 0:
        return 4
    return 0


def flash_at(t: float) -> int:
    if t < 1 / FPS:
        return 1
    if t < 3 / FPS:
        return 2
    if t < 5 / FPS:
        return 3
    if 0.60 <= t < 0.60 + 1 / FPS:
        return 2
    if 0.60 + 1 / FPS <= t < 0.60 + 3 / FPS:
        return 3
    return 0


def speed_lines_layer(k: int, off: float) -> Image.Image:
    rng = random.Random(300 + k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(22):
        y = rng.uniform(70, 380)
        x = rng.uniform(-100, 760) + off
        ln = rng.uniform(60, 260)
        c = rng.choice([LILAC, CREAM, PALE, INDIGO])
        d.line((x, y, x + ln, y + SLOPE * ln), fill=c + (rng.randint(80, 170),), width=rng.choice([2, 2, 4]))
    return img


def radial(k: int, centre: tuple[float, float]) -> Image.Image:
    rng = random.Random(900 + k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(36):
        a = rng.uniform(0, math.tau)
        r0, r1 = rng.uniform(90, 150), rng.uniform(300, 600)
        d.line((centre[0] + math.cos(a) * r0, centre[1] + math.sin(a) * r0, centre[0] + math.cos(a) * r1, centre[1] + math.sin(a) * r1), fill=LILAC + (255,), width=rng.choice([2, 4]))
    return img


def title(font, t: float, off: float, shake) -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    label = "BLACK FORM"
    tx = ramp(t, SLAM, SLAM + 0.08)
    size = int(56 * (1 + 0.25 * (1 - ease_out(tx))))
    f = font.font_variant(size=size)
    cx = off + 260 + shake[0]
    cy = y_bot(off + 260, off) + 18 + shake[1]
    d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), label, font=f, stroke_width=6)
    org = (cx - (bb[2] - bb[0]) / 2, cy - (bb[3] - bb[1]) / 2)
    d.text((org[0] + 4, org[1] + 5), label, font=f, fill=INK, stroke_width=6, stroke_fill=INK)
    d.text(org, label, font=f, fill=LILAC, stroke_width=6, stroke_fill=DEEP)
    d.text(org, label, font=f, fill=CREAM)
    return img.transform(img.size, Image.AFFINE, (1, 0.22, -0.22 * cy, 0, 1, 0), Image.NEAREST)


def exit_smear(k: int, off: float) -> Image.Image:
    rng = random.Random(k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rx = RIGHT_TOP + off
    for _ in range(16):
        y = rng.uniform(100, 360)
        d.line((rx - 20, y, rx + rng.uniform(80, 360), y + SLOPE * 100), fill=rng.choice([LILAC, PALE, INDIGO]) + (200,), width=rng.choice([2, 2, 4]))
    return img


def fig_mask(fig: Image.Image, x: int, y: int) -> Image.Image:
    m = Image.new("L", (W, H), 0)
    m.paste(fig.getchannel("A"), (x, y))
    return m


def render_preview(assets) -> list[Image.Image]:
    poses, aura, slashes, flashes = assets
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
        st = slash_at(t, k)
        strike_out = st == 2  # the strike breaks out of the banner over the whole screen
        if st and not strike_out:
            layer.alpha_composite(slashes[st - 1], (int(off * 0.2), 0))
        layer.alpha_composite(speed_lines_layer(k, off))
        fig = None
        if beat:
            fx = off + FIG_X
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
                layer.paste(Image.new("RGBA", (W, H), IMPACT + (255,)), (0, 0))
                layer.alpha_composite(radial(k, (fx, 230)))
            fig = img.resize((int(img.width * sc), int(img.height * sc)), Image.NEAREST)
            feet_x = fx + (24 * ease_out(local / 0.3) if beat[0] == "burst" else 0)
            px_ = feet_x - meta["pad"] * sc - meta["inner_w"] * sc * meta["feet_x"] + shake[0]
            py_ = y_bot(feet_x, off) - 4 - (fig.height - meta["pad"] * sc) + shake[1]
            if impact:  # the impact frame stays inside the banner
                layer.alpha_composite(fig, (int(px_), int(py_)))
            if any(c + 1 / FPS <= t < c + 2 / FPS + 1e-6 for c in CUTS):
                layer.alpha_composite(Image.new("RGBA", (W, H), IMPACT + (95,)))
        if st and strike_out:
            frame.alpha_composite(slashes[1], (int(off * 0.2), 0))
        frame.paste(layer, (0, 0), pm)
        if beat and not impact:  # the lit figure breaks out of the banner's top edge
            frame.alpha_composite(fig, (int(px_), int(py_)))
            if any(c + 1 / FPS <= t < c + 2 / FPS + 1e-6 for c in CUTS):
                veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                veil.paste(Image.new("RGBA", (W, H), IMPACT + (95,)), (0, 0), fig_mask(fig, int(px_), int(py_)))
                frame.alpha_composite(veil)
        bd = ImageDraw.Draw(frame)
        loop = poly + [poly[0]]
        bd.line(loop, fill=LILAC, width=10)
        bd.line(loop, fill=CREAM, width=4)
        fi = flash_at(t)
        if fi:
            frame.alpha_composite(flashes[fi - 1])
        if t >= SLAM and off > -700:
            frame.alpha_composite(title(font, t, off, shake))
        if EXIT[0] <= t:
            frame.alpha_composite(exit_smear(k, off))
        frames.append(frame.convert("RGB"))
    return frames


def contact_sheet(frames, poses, slashes, flashes) -> Image.Image:
    cw, ch = 320, 180  # game scale
    cols = 6
    rows = math.ceil(len(frames) / cols)
    lab = 14
    small = ImageFont.truetype(str(FONT), 11)
    sheet = Image.new("RGB", (cols * (cw + 6) + 6, rows * (ch + lab + 6) + 6 + 400), BG)
    d = ImageDraw.Draw(sheet)
    for i, fr in enumerate(frames):
        x = 6 + (i % cols) * (cw + 6)
        y = 6 + (i // cols) * (ch + lab + 6)
        d.text((x, y), f"f{i}  t={i / FPS:.2f}s", font=small, fill=(200, 200, 220))
        sheet.paste(fr.resize((cw, ch), Image.LANCZOS), (x, y + lab))
    row_y = 6 + rows * (ch + lab + 6) + 4
    x = 6
    items = []
    for name, (lit, sil, _) in poses.items():
        items += [(f"pose_{name}", lit), (f"pose_{name}_sil", sil)]
    items += [(f"slash_{i + 1}", s) for i, s in enumerate(slashes)]
    items += [(f"flash_{i + 1}", f) for i, f in enumerate(flashes)]
    hh = 108
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
def save(img: Image.Image, name: str, written: list) -> None:
    check_hard(img, name)
    img.save(OUT / name)
    written.append(name)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    meta: dict = {
        "generator": "tools/art/export_black_form_cutin.py (Pillow only, fixed seeds; shared format of export_lightning_cutin.py)",
        "canvas": [W, H],
        "palette": "Totoy 36, hard alpha; no gold x,y or red z,A",
        "pose_scale": POSE_SCALE, "aura_scale": AURA_SCALE, "fx_scale": FX_SCALE,
        "poses": {}, "aura": {}, "slashes": [], "flashes": [],
        "timing_s": {"note": "suggested, preview seconds at 30 fps; black_form_cutin.gd plays them at SPEED",
                     "flash_pop": [0.0, 0.167], "banner_in": [0.03, 0.17], "beats": BEATS, "cuts": CUTS,
                     "slash_on_burst": [[1, 0.033], [2, 0.067], [3, 0.067], [4, 0.067], ["3/4 flicker", "until exit"]],
                     "title_slam": SLAM, "exit": list(EXIT), "end": EXIT[1]},
    }
    painted = isolate_poses()
    poses = {}
    for name in POSES:
        lit, sil, m = make_pose(name, painted[POSES[name][0]])
        save(lit, f"black_form_pose_{name}.png", written)
        save(sil, f"black_form_pose_{name}_sil.png", written)
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
    save(atlas, "black_form_aura.png", written)
    meta["aura"] = {"cell_w": cw, "cell_h": chh, "frames": frames, "anchor": "bottom centre"}
    slashes = [make_slash(p) for p in range(1, 5)]
    for i, s in enumerate(slashes):
        save(s, f"black_form_slash_{i + 1}.png", written)
        meta["slashes"].append(f"black_form_slash_{i + 1}.png")
    flashes = [make_flash(p) for p in range(1, 4)]
    for i, f in enumerate(flashes):
        save(f, f"black_form_flash_{i + 1}.png", written)
        meta["flashes"].append(f"black_form_flash_{i + 1}.png")
    (OUT / "black_form_cutin.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    written.append("black_form_cutin.json")
    preview = render_preview((poses, aura, slashes, flashes))
    gif = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in preview]
    gif[0].save(OUT / "black_form_cutin_preview.gif", save_all=True, append_images=gif[1:], duration=33, loop=0, disposal=1)
    written.append("black_form_cutin_preview.gif")
    contact_sheet(preview, poses, slashes, flashes).save(OUT / "black_form_cutin_contact.png")
    written.append("black_form_cutin_contact.png")
    for n in written:
        print(n)
    print("wrote", len(written), "files to", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
