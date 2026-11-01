"""Export the Disintegration cut-in art (presentation/cutin/staff_*) in the shared cut-in format.

Review stage: nothing here is wired into the game. The format is the approved one (tools/art/export_lightning_cutin.py,
"this will be our cutout art format"), the same as Reaper's Coil (tools/art/export_chain_scythe_cutin.py): pixel-art pose cut-outs
in the Totoy 36 palette with hard alpha, scaled up with integer nearest-neighbour; a 1px dark gap and a coloured rim with a ramp
falloff; ink impact silhouettes; a 12-frame aura atlas; four backdrop effect frames; three full-screen flash frames; a json with
sizes, anchors and timings; a preview GIF and a contact sheet. The mask helpers come from export_lightning_cutin.py.

Staff differences: a sapphire night-sky language (water_1 deep, water_2, water_4, water_5, water_6 pale, cream star core, a lilac
accent on the runes), star motes instead of ghost wisps, a magic circle turning under the feet in the aura, and a falling star
crashing into a ground circle as the backdrop strike. The banner leaves to the right (the star falls on).

Poses come from the staff concept (tools/art/import_staff_concept.py, art/reference/staff_v1/imported/hero_<n>.png):
  crouch = pose 5 (plants the staff, the circle forms), ready = pose 8 (raises the staff, calls the star),
  burst = pose 4 (swings the staff overhead and down: the star falls)

Outputs (presentation/cutin/):
  staff_pose_<name>.png / _sil.png   lit pose and ink impact silhouette (x12)
  staff_aura.png                     12 frames (6x2 atlas, x8): star motes rising, a magic circle turning at the feet, bottom-centred
  staff_strike_<1..4>.png            800x450 backdrop (x8): the star falling, the crash on the circle, the pillar, the embers
  staff_flash_<1..3>.png             800x450 full-width pop (x4): pale flash with dark falling streaks, then streaks fading
  staff_cutin.json                   sizes, anchors, atlas frames, file lists and suggested timings
  staff_cutin_preview.gif            about 1.2 s at 30 fps on the dark cut-in background (viewing only)
  staff_cutin_contact.png            every preview frame at 320x180 plus the raw assets (viewing only)
Pillow only, fixed seeds. Run from the project root after import_staff_concept.py:
  python tools/art/export_staff_cutin.py
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from export_lightning_cutin import (  # noqa: E402  shared cut-in format helpers
    FONT, FPS, H, RIGHT_TOP, SLOPE, FIG_SCALE, W, FW, FH, FX_SCALE, AURA_SCALE,
    alpha_mask, banner_poly, bolt_layers, check_hard, dilate, draw_path, ease_back, ease_in, ease_out, minus, poly_mask, ramp,
    rim_light, solid, up, y_bot,
)

ROOT = artlib.ROOT
OUT = ROOT / "presentation" / "cutin"
POSES_DIR = ROOT / "art" / "reference" / "staff_v1" / "imported"
PAL = artlib.load_palette()
FORBIDDEN = set(PAL.reserved)

POSE_SCALE = 12
STRIKE_SCALE = 8     # the falling star is drawn at 100x57 and scaled x8
PAD = 8
POSE_FILES = {"crouch": "hero_5.png", "ready": "hero_8.png", "burst": "hero_4.png"}
SEEDS = {"crouch": 41, "ready": 42, "burst": 43}
MOTES = {"crouch": 6, "ready": 9, "burst": 12}


def col(sym: str) -> tuple[int, int, int, int]:
    assert sym not in FORBIDDEN, f"reserved colour {sym}"
    return PAL.by_symbol[sym] + (255,)


def plus(mask: Image.Image, x: int, y: int, arm: int) -> None:
    for i in range(-arm, arm + 1):
        for px, py in ((x + i, y), (x, y + i)):
            if 0 <= px < mask.width and 0 <= py < mask.height:
                mask.putpixel((px, py), 255)


# ------------------------------------------------------------------------------------------------------ poses
def motes(rng: random.Random, body: Image.Image, count: int) -> tuple[Image.Image, Image.Image]:
    """Star motes drifting up off the outline: small pluses (arms) with a cream centre (cores)."""
    a = alpha_mask(body)
    edge = minus(dilate(a, 3), dilate(a, 1))
    pts = [(x, y) for y in range(edge.height) for x in range(edge.width) if edge.getpixel((x, y))]
    top = min(p[1] for p in pts)
    bot = max(p[1] for p in pts)
    pts = [p for p in pts if p[1] < top + (bot - top) * 0.8] or pts
    arms = Image.new("L", body.size, 0)
    cores = Image.new("L", body.size, 0)
    for i in range(count):
        x, y = rng.choice(pts)
        y -= rng.randint(0, 3)
        plus(arms, x, y, 1 if i % 3 else 2)
        cores.putpixel((x, max(0, y)), 255)
    return minus(arms, a), minus(cores, a)


def make_pose(name: str) -> tuple[Image.Image, Image.Image, dict]:
    rng = random.Random(SEEDS[name])
    src = Image.open(POSES_DIR / POSE_FILES[name]).convert("RGBA")
    meta_in = json.loads((POSES_DIR / "imported.json").read_text(encoding="utf-8"))["sets"]["hero"]
    feet_x = next(m["ax"] for m in meta_in if m["file"] == POSE_FILES[name])
    x0, y0, x1, y1 = src.getchannel("A").getbbox()
    body = Image.new("RGBA", (x1 - x0 + 2 * PAD, y1 - y0 + 2 * PAD), (0, 0, 0, 0))
    body.alpha_composite(src.crop((x0, y0, x1, y1)), (PAD, PAD))
    a = alpha_mask(body)
    d1, d2, d3 = dilate(a, 1), dilate(a, 2), dilate(a, 3)
    lit = Image.new("RGBA", body.size, (0, 0, 0, 0))
    lit.alpha_composite(solid(minus(dilate(d3, 1, diamond=False), d3), "l"))
    lit.alpha_composite(solid(minus(d3, d2), "n"))
    lit.alpha_composite(solid(minus(d2, d1), "p"))
    lit.alpha_composite(solid(minus(d1, a), "k"))  # the 1px deep gap keeps his own outline readable
    arms, cores = motes(rng, body, MOTES[name])
    arms, cores = minus(arms, d1), minus(cores, d1)
    lit.alpha_composite(solid(minus(dilate(arms, 1), d2), "l"))
    lit.alpha_composite(rim_light(body))
    lit.alpha_composite(solid(arms, "o"))
    lit.alpha_composite(solid(cores, "1"))
    sa, sc = motes(random.Random(SEEDS[name] + 100), body, MOTES[name] + 5)
    sil = Image.new("RGBA", body.size, (0, 0, 0, 0))
    sil.alpha_composite(solid(minus(dilate(a, 2), d1), "n"))
    sil.alpha_composite(solid(minus(dilate(sa, 1), a), "l"))
    sil.alpha_composite(solid(minus(d1, a), "1"))
    sil.alpha_composite(solid(a, "0"))
    sil.alpha_composite(solid(sa, "o"))
    sil.alpha_composite(solid(sc, "1"))
    k = POSE_SCALE
    meta = {"w": body.width * k, "h": body.height * k, "pad": PAD * k, "inner_w": (x1 - x0) * k,
            "inner_h": (y1 - y0) * k, "feet_x": round((feet_x - x0) / (x1 - x0), 3),
            "source": "art/reference/staff_v1/imported/" + POSE_FILES[name],
            "content": {"crouch": "plants the staff, the circle forms (concept pose 5)",
                        "ready": "raises the staff, calls the star (concept pose 8)",
                        "burst": "swings the staff overhead and down, the star falls (concept pose 4)"}[name]}
    return up(lit, k), up(sil, k), meta


# ------------------------------------------------------------------------------------------------- aura atlas
def ellipse_pts(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, step: float = 6) -> list[tuple[float, float]]:
    n = max(2, int((a1 - a0) / step))
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * rx, cy + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * ry)
            for i in range(n + 1)]


def make_aura_frame(i: int) -> Image.Image:
    """48x56 at 1x: star motes rising from the feet and a magic circle turning under them (x8, bottom-centred)."""
    rng = random.Random(900 + i)
    w, h = 48, 56
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, cy, rx, ry = w / 2, h - 7, 21, 5
    back = Image.new("L", (w, h), 0)
    front = Image.new("L", (w, h), 0)
    draw_path(back, ellipse_pts(cx, cy, rx, ry, 180, 360))
    draw_path(front, ellipse_pts(cx, cy, rx, ry, 0, 180))
    inner = Image.new("L", (w, h), 0)
    draw_path(inner, ellipse_pts(cx, cy, rx - 6, ry - 2, 0, 360))
    ticks = Image.new("L", (w, h), 0)
    for k in range(8):  # rune ticks turning around the ring
        ang = math.radians(i * 15 + k * 45)
        tx, ty = round(cx + math.cos(ang) * (rx - 3)), round(cy + math.sin(ang) * (ry - 1))
        ticks.putpixel((tx, ty), 255)
    img.alpha_composite(solid(back, "k"))
    img.alpha_composite(solid(inner, "l"))
    img.alpha_composite(solid(ticks, "v"))
    img.alpha_composite(bolt_layers(front, ["l"], "n"))
    arms = Image.new("L", (w, h), 0)
    cores = Image.new("L", (w, h), 0)
    for j in range(6):  # motes rising: each climbs with the frame number, wrapping
        sx = cx + rng.uniform(-17, 17)
        y = (h - 8) - ((rng.uniform(0, 44) + i * 3.7) % 44)
        x = round(sx + math.sin(y * 0.3 + j) * 1.5)
        plus(arms, x, round(y), 1 if (i + j) % 3 else 0)
        cores.putpixel((min(w - 1, max(0, x)), min(h - 1, max(0, round(y)))), 255)
    img.alpha_composite(solid(minus(arms, cores), "o"))
    img.alpha_composite(solid(cores, "1"))
    return up(img, AURA_SCALE)


# ------------------------------------------------------------------------------------------- backdrop strike
SWD, SHD = 100, 57
SKY = (SWD * 0.98, -6.0)      # where the star comes from (top right)
GROUND = (SWD * 0.63, SHD * 0.60)  # where it lands (the circle's centre, inside the banner)


def along(s: float) -> tuple[float, float]:
    return (SKY[0] + (GROUND[0] - SKY[0]) * s, SKY[1] + (GROUND[1] - SKY[1]) * s)


def ground_circle(img: Image.Image, bright: bool, rx: float = 14, ry: float = 4) -> None:
    cx, cy = GROUND
    outer = Image.new("L", (SWD, SHD), 0)
    draw_path(outer, ellipse_pts(cx, cy, rx, ry, 0, 360))
    inner = Image.new("L", (SWD, SHD), 0)
    draw_path(inner, ellipse_pts(cx, cy, rx * 0.7, ry * 0.7, 0, 360))
    star = Image.new("L", (SWD, SHD), 0)  # the six-pointed star inside, two triangles
    for rot in (90, 270):
        pts = [(cx + math.cos(math.radians(rot + k * 120)) * rx * 0.7, cy + math.sin(math.radians(rot + k * 120)) * ry * 0.7) for k in range(4)]
        draw_path(star, pts)
    img.alpha_composite(solid(star, "v" if bright else "k"))
    img.alpha_composite(bolt_layers(inner, ["k"], "l"))
    img.alpha_composite(bolt_layers(outer, ["l"] if bright else ["k"], "o" if bright else "l"))


def star_head(img: Image.Image, x: float, y: float, arm: int) -> None:
    core = Image.new("L", (SWD, SHD), 0)
    plus(core, round(x), round(y), arm)
    for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
        px, py = round(x) + dx, round(y) + dy
        if 0 <= px < SWD and 0 <= py < SHD:
            core.putpixel((px, py), 255)
    img.alpha_composite(bolt_layers(core, ["p", "o", "n"], "1"))


def trail(img: Image.Image, s0: float, s1: float) -> None:
    """The burning tail from s0 (thin, far) to s1 (the head): thicker and paler toward the head."""
    for width, sym_ring, sym in ((5, "l", "n"), (3, "n", "o"), (1, "o", "p")):
        m = Image.new("L", (SWD, SHD), 0)
        span = s1 - s0
        a = s0 + span * {5: 0.45, 3: 0.25, 1: 0.0}[width]
        draw_path(m, [along(a), along(s1)], width)
        img.alpha_composite(bolt_layers(m, [sym_ring], sym))
    core = Image.new("L", (SWD, SHD), 0)
    draw_path(core, [along(s0 + (s1 - s0) * 0.6), along(s1)])
    img.alpha_composite(solid(core, "1"))


def make_strike(phase: int) -> Image.Image:
    rng = random.Random(170 + phase)
    img = Image.new("RGBA", (SWD, SHD), (0, 0, 0, 0))
    if phase == 1:  # the star high up, a short tail; the circle waits, dim
        ground_circle(img, False)
        trail(img, 0.0, 0.42)
        star_head(img, *along(0.42), 2)
    elif phase == 2:  # the crash: the full tail into the bright circle
        ground_circle(img, True, 15, 4.5)
        trail(img, 0.15, 1.0)
        star_head(img, *along(1.0), 4)
    elif phase == 3:  # the pillar of light out of the circle, shards flying
        ground_circle(img, True, 16, 5)
        cx, cy = GROUND
        for width, top, halos in ((3, cy - 22, ["n", "l"]), (1, cy - 36, ["o", "n"])):  # a tapering pillar of light
            pillar = Image.new("L", (SWD, SHD), 0)
            draw_path(pillar, [(cx, cy - 1), (cx, top)], width)
            img.alpha_composite(bolt_layers(pillar, halos, "o" if width == 3 else "1"))
        for _ in range(16):
            ang = rng.uniform(math.pi * 1.05, math.pi * 1.95)
            r = rng.uniform(6, 16)
            plus_m = Image.new("L", (SWD, SHD), 0)
            plus(plus_m, round(cx + math.cos(ang) * r * 1.6), round(cy + math.sin(ang) * r), rng.choice((0, 1)))
            img.alpha_composite(solid(plus_m, rng.choice("op1")))
    else:  # the embers: motes drifting up over a fading ring
        cx, cy = GROUND
        ring = Image.new("L", (SWD, SHD), 0)
        draw_path(ring, ellipse_pts(cx, cy, 16, 5, 0, 360, 12)[::2])
        img.alpha_composite(solid(ring, "k"))
        for _ in range(22):
            m = Image.new("L", (SWD, SHD), 0)
            plus(m, round(cx + rng.uniform(-18, 18)), round(cy - rng.uniform(2, 34)), rng.choice((0, 0, 1)))
            img.alpha_composite(solid(m, rng.choice("lnop")))
    return up(img, STRIKE_SCALE).crop((0, 0, W, H))


# ---------------------------------------------------------------------------------------------- flash frames
FALL = 0.62  # the falling streaks' slope (down and to the left)


def streaks(rng: random.Random, n: int, syms: list[str], min_len: int, max_len: int) -> Image.Image:
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    for _ in range(n):
        x = rng.uniform(0, FW + 60)
        y = rng.uniform(-40, FH)
        ln = rng.uniform(min_len, max_len)
        m = Image.new("L", (FW, FH), 0)
        ImageDraw.Draw(m).line((round(x), round(y), round(x - ln), round(y + FALL * ln)), fill=255)
        img.alpha_composite(solid(m, rng.choice(syms)))
    return img


def make_flash(phase: int) -> Image.Image:
    rng = random.Random(160 + phase)
    if phase == 1:  # pale pop with blue streaks and dark falling stars across it
        img = Image.new("RGBA", (FW, FH), col("p"))
        img.alpha_composite(streaks(rng, 60, ["o", "n", "n"], 20, 80))
        sil = Image.new("L", (FW, FH), 0)
        for k in range(3):
            hx, hy = FW * (0.3 + 0.25 * k), FH * (0.35 + 0.2 * k)
            draw_path(sil, [(hx + 40, hy - 40 * FALL), (hx, hy)], 1 + k)
            plus(sil, round(hx), round(hy), 2 + k)
        img.alpha_composite(solid(dilate(sil, 1), "n"))
        img.alpha_composite(solid(sil, "0"))
    elif phase == 2:
        img = streaks(rng, 70, ["1", "p", "o", "n", "n", "l"], 30, 120)
    else:
        img = streaks(rng, 36, ["o", "n", "l", "k"], 20, 70)
    return up(img, FX_SCALE).crop((0, 0, W, H))


# ---------------------------------------------------------------------------------------- preview (viewing)
BG = (5, 6, 18)
BAN_TOP = (30, 46, 92)
BAN_BOT = (8, 10, 26)
CREAM = col("1")[:3]
PALE = col("p")[:3]
BLUE = col("n")[:3]
BLUE_D = col("l")[:3]
GLINT = col("o")[:3]
DEEP = col("k")[:3]
INK = col("0")[:3]
IMPACT = (232, 240, 250)
N_FRAMES = 36
FIG_FIT = {"crouch": 0.95, "ready": 0.82, "burst": 0.78}
BEATS = [("crouch", 0.10, 0.37), ("ready", 0.37, 0.62), ("burst", 0.62, 1.20)]
CUTS = [0.37, 0.62]
SLAM = 0.70
EXIT = (0.98, 1.16)
FIG_X = 300.0
GRAD = Image.linear_gradient("L").resize((W, H))
BAN_BG = Image.composite(Image.new("RGBA", (W, H), BAN_BOT + (255,)), Image.new("RGBA", (W, H), BAN_TOP + (255,)), GRAD)


def banner_offset(t: float) -> float:
    # slams in from the left, then leaves to the right (the star falls on)
    return -760 * (1 - ease_back(ramp(t, 0.03, 0.17))) + 900 * ease_in(ramp(t, *EXIT))


def strike_at(t: float, k: int) -> int:
    if t >= CUTS[1]:
        n = int((t - CUTS[1]) * FPS + 1e-6)
        return [1, 1, 2, 2, 3, 3, 4][n] if n < 7 else (3 if k % 6 == 0 else 4)
    if 0.2 <= t < CUTS[0] and k % 3 == 0:
        return 4
    return 0


def flash_at(t: float) -> int:
    if t < 1 / FPS:
        return 1
    if t < 3 / FPS:
        return 2
    if t < 5 / FPS:
        return 3
    if CUTS[1] + 2 / FPS <= t < CUTS[1] + 3 / FPS:  # the crash
        return 1
    if CUTS[1] + 3 / FPS <= t < CUTS[1] + 5 / FPS:
        return 3
    return 0


def sky_layer(k: int, off: float) -> Image.Image:
    """Faint falling streaks and stars behind the hero (the banner's night sky)."""
    rng = random.Random(400 + k // 2)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(16):
        x = rng.uniform(0, 900) + off * 0.5 - (k % 30) * 6
        y = rng.uniform(40, 360) + (k % 30) * 6 * FALL
        ln = rng.uniform(40, 160)
        d.line((x, y, x - ln, y + FALL * ln), fill=rng.choice([BLUE, GLINT, PALE]) + (rng.randint(70, 150),), width=rng.choice([2, 2, 4]))
    for _ in range(18):
        x, y = rng.uniform(0, W), rng.uniform(40, 380)
        d.rectangle((x, y, x + 3, y + 3), fill=rng.choice([CREAM, GLINT]) + (200,))
    return img


def radial(k: int, centre: tuple[float, float]) -> Image.Image:
    rng = random.Random(950 + k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(36):
        a = rng.uniform(0, math.tau)
        r0, r1 = rng.uniform(90, 150), rng.uniform(300, 600)
        d.line((centre[0] + math.cos(a) * r0, centre[1] + math.sin(a) * r0, centre[0] + math.cos(a) * r1, centre[1] + math.sin(a) * r1), fill=BLUE_D + (255,), width=rng.choice([2, 4]))
    return img


def title(font, small, t: float, off: float, shake) -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    label = "DISINTEGRATION"
    tx = ramp(t, SLAM, SLAM + 0.08)
    size = int(50 * (1 + 0.25 * (1 - ease_out(tx))))
    f = font.font_variant(size=size)
    cx = off + 270 + shake[0]
    cy = y_bot(off + 270, off) + 14 + shake[1]
    d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), label, font=f, stroke_width=6)
    org = (cx - (bb[2] - bb[0]) / 2, cy - (bb[3] - bb[1]) / 2)
    d.text((org[0] + 4, org[1] + 5), label, font=f, fill=INK, stroke_width=6, stroke_fill=INK)
    d.text(org, label, font=f, fill=BLUE, stroke_width=6, stroke_fill=DEEP)
    d.text(org, label, font=f, fill=CREAM)
    if t >= SLAM + 0.06:  # subtitle (the runtime would show the real circle size / damage here)
        sub = "MARK  -  CALL  -  STARFALL"
        sb = d.textbbox((0, 0), sub, font=small, stroke_width=3)
        so = (cx - (sb[2] - sb[0]) / 2 + 30, org[1] + (bb[3] - bb[1]) + 2)
        d.text(so, sub, font=small, fill=PALE, stroke_width=3, stroke_fill=INK)
    return img.transform(img.size, Image.AFFINE, (1, 0.22, -0.22 * cy, 0, 1, 0), Image.NEAREST)


def exit_smear(k: int, off: float) -> Image.Image:
    rng = random.Random(k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rx = off - 40
    for _ in range(16):
        y = rng.uniform(100, 360)
        d.line((rx + 20, y, rx - rng.uniform(80, 360), y - SLOPE * 100), fill=rng.choice([BLUE, PALE, GLINT]) + (200,), width=rng.choice([2, 2, 4]))
    return img


def render_preview(assets) -> list[Image.Image]:
    poses, aura, strikes, flashes = assets
    font = ImageFont.truetype(str(FONT), 64)
    small = ImageFont.truetype(str(FONT), 22)
    frames = []
    for k in range(N_FRAMES):
        t = k / FPS
        frame = Image.new("RGBA", (W, H), BG + (255,))
        off = banner_offset(t)
        poly = banner_poly(off)
        pm = poly_mask(poly)
        rng = random.Random(3000 + k)
        shake = (0, 0)
        for cut in CUTS + [CUTS[1] + 2 / FPS, SLAM]:
            if cut <= t < cut + 0.1:
                shake = (rng.randint(-6, 6), rng.randint(-4, 4))
        beat = next((b for b in BEATS if b[1] <= t < b[2]), None)
        impact = False
        layer = BAN_BG.copy()
        layer.alpha_composite(sky_layer(k, off))
        st = strike_at(t, k)
        strike_out = st == 2
        if st:  # the crash (2) shows inside the banner and, below, past its edge
            layer.alpha_composite(strikes[st - 1], (int(off * 0.2), 0))
        fig = None
        if beat:
            fx = off + FIG_X
            if ramp(t, 0.15, 0.3) > 0:
                af = aura[(k // 2) % len(aura)]
                hgt = 250 if beat[0] != "burst" else 290
                af = af.resize((int(af.width * hgt / af.height), hgt), Image.NEAREST)
                layer.alpha_composite(af, (int(fx - af.width / 2), int(y_bot(fx, off) - hgt + 20)))
            impact = any(c <= t < c + 1 / FPS + 1e-6 for c in CUTS)
            img, meta = poses[beat[0]][1 if impact else 0], poses[beat[0]][2]
            local = t - beat[1]
            s = 1.12 if local < 0.07 else 1.0 + 0.10 * (1 - ease_out((local - 0.07) / 0.12)) + 0.05 * ramp(local, 0.07, 0.6)
            sc = FIG_SCALE * FIG_FIT[beat[0]] * s
            if impact:
                layer.paste(Image.new("RGBA", (W, H), IMPACT + (255,)), (0, 0))
                layer.alpha_composite(radial(k, (fx, 230)))
            fig = img.resize((int(img.width * sc), int(img.height * sc)), Image.NEAREST)
            lift = 14 * math.sin(math.pi * ramp(local, 0.0, 0.25)) if beat[0] == "burst" else 0  # a small hop on the swing
            px_ = fx - meta["pad"] * sc - meta["inner_w"] * sc * meta["feet_x"] + shake[0]
            py_ = y_bot(fx, off) - 4 - (fig.height - meta["pad"] * sc) + shake[1] - lift
            if impact:
                layer.alpha_composite(fig, (int(px_), int(py_)))
            if any(c + 1 / FPS <= t < c + 2 / FPS + 1e-6 for c in CUTS):
                layer.alpha_composite(Image.new("RGBA", (W, H), IMPACT + (95,)))
        if st and strike_out:
            frame.alpha_composite(strikes[1], (int(off * 0.2), 0))
        frame.paste(layer, (0, 0), pm)
        if beat and not impact:
            frame.alpha_composite(fig, (int(px_), int(py_)))
            if any(c + 1 / FPS <= t < c + 2 / FPS + 1e-6 for c in CUTS):
                veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                m = Image.new("L", (W, H), 0)
                m.paste(fig.getchannel("A"), (int(px_), int(py_)))
                veil.paste(Image.new("RGBA", (W, H), IMPACT + (95,)), (0, 0), m)
                frame.alpha_composite(veil)
        bd = ImageDraw.Draw(frame)
        loop = poly + [poly[0]]
        bd.line(loop, fill=BLUE, width=10)
        bd.line(loop, fill=CREAM, width=4)
        fi = flash_at(t)
        if fi:
            frame.alpha_composite(flashes[fi - 1])
        if t >= SLAM and off < 700:
            frame.alpha_composite(title(font, small, t, off, shake))
        if EXIT[0] <= t:
            frame.alpha_composite(exit_smear(k, off))
        frames.append(frame.convert("RGB"))
    return frames


def contact_sheet(frames, poses, strikes, flashes, aura) -> Image.Image:
    cw, ch = 320, 180
    cols = 6
    rows = math.ceil(len(frames) / cols)
    lab = 14
    small = ImageFont.truetype(str(FONT), 11)
    sheet = Image.new("RGB", (cols * (cw + 6) + 6, rows * (ch + lab + 6) + 6 + 600), BG)
    d = ImageDraw.Draw(sheet)
    for i, fr in enumerate(frames):
        x = 6 + (i % cols) * (cw + 6)
        y = 6 + (i // cols) * (ch + lab + 6)
        d.text((x, y), f"f{i}  t={i / FPS:.2f}s", font=small, fill=(200, 210, 235))
        sheet.paste(fr.resize((cw, ch), Image.LANCZOS), (x, y + lab))
    row_y = 6 + rows * (ch + lab + 6) + 4
    x = 6
    items = []
    for name, (lit, sil, _) in poses.items():
        items += [(f"pose_{name}", lit), (f"pose_{name}_sil", sil)]
    items += [(f"strike_{i + 1}", s) for i, s in enumerate(strikes)]
    items += [(f"flash_{i + 1}", f) for i, f in enumerate(flashes)]
    items += [(f"aura_{i + 1}", a) for i, a in enumerate(aura[:6])]
    hh = 108
    for name, img in items:
        s = hh / img.height
        th = img.resize((max(1, int(img.width * s)), hh), Image.BOX)
        if x + th.width > sheet.width - 6:
            x = 6
            row_y += hh + lab + 6
        d.text((x, row_y), name, font=small, fill=(200, 210, 235))
        tile = Image.new("RGBA", th.size, (20, 26, 48, 255))
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
        "generator": "tools/art/export_staff_cutin.py (Pillow only, fixed seeds; shared format of export_lightning_cutin.py)",
        "status": "review stage; not wired into the game",
        "title": "DISINTEGRATION", "subtitle_suggestion": "circle size / damage from the core, like the other cut-ins",
        "canvas": [W, H],
        "palette": "Totoy 36, hard alpha; no gold x,y or red z,A",
        "pose_scale": POSE_SCALE, "aura_scale": AURA_SCALE, "fx_scale": FX_SCALE, "strike_scale": STRIKE_SCALE,
        "poses": {}, "aura": {}, "strikes": [], "flashes": [],
        "timing_s": {"note": "suggested, preview seconds at 30 fps; a sibling of black_form_cutin.gd may scale them by SPEED",
                     "flash_pop": [0.0, 0.167], "banner_in": [0.03, 0.17], "beats": BEATS, "cuts": CUTS,
                     "strike_on_burst": [[1, 0.067], [2, 0.067], [3, 0.1], ["3/4 flicker", "until exit"]],
                     "crash_flash": CUTS[1] + 2 / FPS,
                     "title_slam": SLAM, "exit": list(EXIT), "exit_direction": "right (the star falls on)", "end": EXIT[1]},
    }
    poses = {}
    for name in ("crouch", "ready", "burst"):
        lit, sil, m = make_pose(name)
        save(lit, f"staff_pose_{name}.png", written)
        save(sil, f"staff_pose_{name}_sil.png", written)
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
    save(atlas, "staff_aura.png", written)
    meta["aura"] = {"cell_w": cw, "cell_h": chh, "frames": frames, "anchor": "bottom centre"}
    strikes = [make_strike(p) for p in range(1, 5)]
    for i, s in enumerate(strikes):
        save(s, f"staff_strike_{i + 1}.png", written)
        meta["strikes"].append(f"staff_strike_{i + 1}.png")
    flashes = [make_flash(p) for p in range(1, 4)]
    for i, f in enumerate(flashes):
        save(f, f"staff_flash_{i + 1}.png", written)
        meta["flashes"].append(f"staff_flash_{i + 1}.png")
    (OUT / "staff_cutin.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    written.append("staff_cutin.json")
    preview = render_preview((poses, aura, strikes, flashes))
    gif = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in preview]
    gif[0].save(OUT / "staff_cutin_preview.gif", save_all=True, append_images=gif[1:], duration=33, loop=0, disposal=1)
    written.append("staff_cutin_preview.gif")
    contact_sheet(preview, poses, strikes, flashes, aura).save(OUT / "staff_cutin_contact.png")
    written.append("staff_cutin_contact.png")
    for n in written:
        print(n)
    print("wrote", len(written), "files to", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
