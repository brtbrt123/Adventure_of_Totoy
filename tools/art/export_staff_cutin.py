"""Export the Disintegration cut-in art (presentation/cutin/staff_*) in the shared cut-in format.

Review stage: nothing here is wired into the game. The format is the approved one (tools/art/export_lightning_cutin.py,
"this will be our cutout art format"), the same as Reaper's Coil (tools/art/export_chain_scythe_cutin.py): pixel-art pose cut-outs
in the Totoy 36 palette with hard alpha, scaled up with integer nearest-neighbour; a 1px dark gap and a coloured rim with a ramp
falloff; ink impact silhouettes; a 12-frame aura atlas; four backdrop effect frames; three full-screen flash frames; a json with
sizes, anchors and timings; a preview GIF and a contact sheet. The mask helpers come from export_lightning_cutin.py.

Staff differences: a sapphire rim (water_1 deep, water_2, water_4, water_6 pale, cream), star motes instead of ghost wisps, the
staff's teal magic circle turning under the feet in the aura, and the ultimate itself as the backdrop strike, drawn with the same
code as the game-scale effects (tools/art/staff_fx.py, after the owner's meteor reference): the meteor appears over the circle while
he calls it, crashes on the cut to the burst (it breaks out over the banner's edge), the blast, then smoke over the cracked crater.
The banner leaves to the right.

Layout (owner 2026-11-01: "the cutout doesn't look properly aligned and organised"): one scale for every pose (FIG_K: the tallest
pose fits inside the banner with its punch-in), so the hero keeps his size from beat to beat and stays inside the banner; he stands
left of centre (FIG_X), the circle and the meteor fill the right of the banner.

Poses come from the staff concept (tools/art/import_staff_concept.py, art/reference/staff_v1/imported/hero_<n>.png):
  crouch = pose 5 (plants the staff, the circle forms), ready = pose 8 (raises the staff, calls the meteor),
  burst = pose 3 (points the staff at the target as the meteor falls)

Outputs (presentation/cutin/):
  staff_pose_<name>.png / _sil.png   lit pose and ink impact silhouette (x12)
  staff_aura.png                     12 frames (6x2 atlas, x8): the magic circle turning at the feet, motes rising, bottom-centred
  staff_strike_<1..4>.png            800x450 backdrop (x4): the meteor over the circle, the crash, the blast, smoke over the crater
  staff_flash_<1..3>.png             800x450 full-width pop (x4): pale flash with dark falling streaks, then streaks fading
  staff_cutin.json                   sizes, anchors, the pose fit and position, atlas frames, file lists and suggested timings
  staff_cutin_preview.gif            about 1.2 s at 30 fps on the dark cut-in background (viewing only)
  staff_cutin_contact.png            every preview frame at 320x180 plus the raw assets (viewing only)
Pillow and numpy, fixed seeds. Run from the project root after import_staff_concept.py:
  python tools/art/export_staff_cutin.py
"""
from __future__ import annotations

import json
import math
import random
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import staff_fx as SFX  # noqa: E402  the game-scale staff effects (the circle, the meteor, the blast)
from export_lightning_cutin import (  # noqa: E402  shared cut-in format helpers
    FONT, FPS, H, RIGHT_TOP, SLOPE, FIG_SCALE, W, FW, FH, FX_SCALE, AURA_SCALE,
    alpha_mask, banner_poly, check_hard, dilate, draw_path, ease_back, ease_in, ease_out, minus, poly_mask, ramp,
    rim_light, solid, up, y_bot,
)

ROOT = artlib.ROOT
OUT = ROOT / "presentation" / "cutin"
POSES_DIR = ROOT / "art" / "reference" / "staff_v1" / "imported"
PAL = artlib.load_palette()
FORBIDDEN = set(PAL.reserved)

POSE_SCALE = 12
STRIKE_SCALE = 4     # the strike is drawn at 200x113 and scaled x4: about the size of the hero's pixels in this cut-in
PAD = 8
POSE_FILES = {"crouch": "hero_5.png", "ready": "hero_8.png", "burst": "hero_3.png"}
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
                        "burst": "points the staff at the target as the meteor falls (concept pose 3)"}[name]}
    return up(lit, k), up(sil, k), meta


# ------------------------------------------------------------------------------------------------- aura atlas
def make_aura_frame(i: int) -> Image.Image:
    """48x56 at 1x: the staff's magic circle turning under his feet (the one the ultimate draws, staff_fx.rune_circle) with rays
    rising off it and star motes climbing (x8, bottom-centred)."""
    rng = random.Random(900 + i)
    w, h = 48, 56
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ground, air = SFX.rune_circle(21, 1.0, 0.85, rot=i * 15, spikes=0.5, k=i, glyphs=10)
    img.alpha_composite(ground.img, (w // 2 - ground.ax, h - 8 - ground.ay))
    img.alpha_composite(air.img, (w // 2 - air.ax, h - 8 - air.ay))
    arms = Image.new("L", (w, h), 0)
    cores = Image.new("L", (w, h), 0)
    for j in range(6):  # motes rising: each climbs with the frame number, wrapping
        sx = w / 2 + rng.uniform(-17, 17)
        y = (h - 10) - ((rng.uniform(0, 42) + i * 3.7) % 42)
        x = round(sx + math.sin(y * 0.3 + j) * 1.5)
        plus(arms, x, round(y), 1 if (i + j) % 3 else 0)
        cores.putpixel((min(w - 1, max(0, x)), min(h - 1, max(0, round(y)))), 255)
    img.alpha_composite(solid(minus(arms, cores), "o"))
    img.alpha_composite(solid(cores, "1"))
    return up(img, AURA_SCALE)


# ------------------------------------------------------------------------------------------- backdrop strike
SWD, SHD = 200, 113
GROUND = (117, 66)  # where the meteor lands (the circle's centre), on the banner's floor right of the hero (grid px, x4 on the canvas)


def make_strike(phase: int) -> Image.Image:
    """The ultimate in the banner, drawn with the same code as the game-scale effects (staff_fx) at the strike grid:
    1 the meteor falling onto the charged circle, 2 the crash (also drawn past the banner's edge), 3 the blast, 4 smoke, rocks
    and the cracked crater (held until the banner leaves)."""
    img = Image.new("RGBA", (SWD, SHD), (0, 0, 0, 0))
    gx, gy = GROUND

    def put(spr, x, y):
        SFX._paste_clipped(img, spr, x, y)

    if phase in (1, 2):
        ground, air = SFX.rune_circle(30, 1.0, 1.0, rot=phase * 20, spikes=0.7 if phase == 1 else 1.4, k=phase, glyphs=12)
        put(ground, gx, gy)
        put(air, gx, gy)
    if phase == 1:  # the meteor coming down out of the sky (its flames run off the top of the banner)
        put(SFX.meteor(3, r=10, flame=58), gx, gy - 16)
    elif phase == 2:
        put(SFX.fire_ring(1, 5, 40), gx, gy)
        put(SFX.meteor(5, r=10, flame=58), gx, gy)
    elif phase == 3:
        put(SFX.crater(1.0, 1.0, rx=28), gx, gy)
        put(SFX.explosion(3, size=0.48), gx, gy)
    else:
        put(SFX.crater(0.5, 1.0, rx=28), gx, gy)
        put(SFX.explosion(9, size=0.48), gx, gy)
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
# One scale for every pose (owner 2026-11-01: the cut-in looked unorganised: the hero changed size between beats and his staff
# crossed the banner's edge). The tallest pose, with its 1.12 punch-in, fits inside the banner (240 px) with a margin.
BANNER_H = 240.0
_TALLEST = max(Image.open(POSES_DIR / f).height for f in POSE_FILES.values())
FIG_K = (BANNER_H - 18) / (_TALLEST * 1.12)  # canvas px per pose px
FIG_FIT = {name: round(FIG_K / (POSE_SCALE * FIG_SCALE), 4) for name in POSE_FILES}
BEATS = [("crouch", 0.10, 0.37), ("ready", 0.37, 0.62), ("burst", 0.62, 1.20)]
CUTS = [0.37, 0.62]
SLAM = 0.70
EXIT = (0.98, 1.16)
FIG_X = 240.0
GRAD = Image.linear_gradient("L").resize((W, H))
BAN_BG = Image.composite(Image.new("RGBA", (W, H), BAN_BOT + (255,)), Image.new("RGBA", (W, H), BAN_TOP + (255,)), GRAD)


def banner_offset(t: float) -> float:
    # slams in from the left, then leaves to the right (the star falls on)
    return -760 * (1 - ease_back(ramp(t, 0.03, 0.17))) + 900 * ease_in(ramp(t, *EXIT))


def strike_at(t: float, k: int) -> int:
    # the call (ready beat): the meteor appears over the circle; the cut to the burst: the crash, the blast, then the smoke holds
    if t >= CUTS[1]:
        n = int((t - CUTS[1]) * FPS + 1e-6)
        return [2, 2, 3, 3, 3][n] if n < 5 else 4
    if 0.47 <= t < CUTS[1]:
        return 1
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
        strike_out = st in (1, 2)  # the falling meteor and the crash break out over the banner's edge
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
            px_ = fx - meta["pad"] * sc - meta["inner_w"] * sc * meta["feet_x"] + shake[0]
            py_ = y_bot(fx, off) - 4 - (fig.height - meta["pad"] * sc) + shake[1]
            if impact:
                layer.alpha_composite(fig, (int(px_), int(py_)))
            if any(c + 1 / FPS <= t < c + 2 / FPS + 1e-6 for c in CUTS):
                layer.alpha_composite(Image.new("RGBA", (W, H), IMPACT + (95,)))
        if st and strike_out:
            frame.alpha_composite(strikes[st - 1], (int(off * 0.2), 0))
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
def save(img: Image.Image, name: str, written: list, fire: bool = False) -> None:
    """Hard alpha and palette colours only. The strike frames may use gold and red: the meteor's fire is the skill's hit effect
    (AGENTS.md lists hit effects among the combat cues those colours are kept for); everything else keeps them out."""
    if fire:
        allowed = set(PAL.by_symbol.values())
        for _, (r, g, b, a) in img.getcolors(1 << 20):
            if a not in (0, 255) or (a == 255 and (r, g, b) not in allowed):
                raise SystemExit(f"{name}: not hard-alpha Totoy 36")
    else:
        check_hard(img, name)
    retry(lambda: img.save(OUT / name))
    written.append(name)


def retry(write) -> None:
    """Windows: the Godot editor (or a viewer) may hold a file for a moment; try again for up to 30 s."""
    for attempt in range(30):
        try:
            write()
            return
        except OSError:
            if attempt == 29:
                raise
            time.sleep(1.0)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    meta: dict = {
        "generator": "tools/art/export_staff_cutin.py (Pillow only, fixed seeds; shared format of export_lightning_cutin.py)",
        "status": "review stage; not wired into the game",
        "title": "DISINTEGRATION", "subtitle_suggestion": "circle size / damage from the core, like the other cut-ins",
        "canvas": [W, H],
        "palette": "Totoy 36, hard alpha; gold x,y and red z,A only in the strike frames (the meteor's fire: a hit effect)",
        "fig_fit": FIG_FIT, "fig_x": FIG_X,
        "pose_scale": POSE_SCALE, "aura_scale": AURA_SCALE, "fx_scale": FX_SCALE, "strike_scale": STRIKE_SCALE,
        "poses": {}, "aura": {}, "strikes": [], "flashes": [],
        "timing_s": {"note": "suggested, preview seconds at 30 fps; a sibling of black_form_cutin.gd may scale them by SPEED",
                     "flash_pop": [0.0, 0.167], "banner_in": [0.03, 0.17], "beats": BEATS, "cuts": CUTS,
                     "strike": [[1, "0.47 until the burst cut"], [2, 0.067], [3, 0.1], [4, "until exit"]],
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
        save(s, f"staff_strike_{i + 1}.png", written, fire=True)
        meta["strikes"].append(f"staff_strike_{i + 1}.png")
    flashes = [make_flash(p) for p in range(1, 4)]
    for i, f in enumerate(flashes):
        save(f, f"staff_flash_{i + 1}.png", written)
        meta["flashes"].append(f"staff_flash_{i + 1}.png")
    (OUT / "staff_cutin.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    written.append("staff_cutin.json")
    preview = render_preview((poses, aura, strikes, flashes))
    gif = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in preview]
    retry(lambda: gif[0].save(OUT / "staff_cutin_preview.gif", save_all=True, append_images=gif[1:], duration=33, loop=0, disposal=1))
    written.append("staff_cutin_preview.gif")
    sheet = contact_sheet(preview, poses, strikes, flashes, aura)
    retry(lambda: sheet.save(OUT / "staff_cutin_contact.png"))
    written.append("staff_cutin_contact.png")
    for n in written:
        print(n)
    print("wrote", len(written), "files to", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
