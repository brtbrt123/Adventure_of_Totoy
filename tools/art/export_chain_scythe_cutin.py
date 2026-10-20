"""Export the Reaper's Coil cut-in art (presentation/cutin/chainscythe_*) in the shared cut-in format.

Review stage: nothing here is wired into the game. The format is the approved one (tools/art/export_lightning_cutin.py,
"this will be our cutout art format"): pixel-art pose cut-outs in the Totoy 36 palette with hard alpha, scaled up with
integer nearest-neighbour; a 1px dark gap and a coloured rim with a ramp falloff; ink impact silhouettes; a 12-frame
aura atlas; four backdrop effect frames; three full-screen flash frames; a json with sizes, anchors and timings; a
preview GIF and a contact sheet. The mask helpers are imported from export_lightning_cutin.py (importing it writes
nothing), the poses, chain and blade from make_chain_scythe_art.py.

Chain Scythe differences: spectral teal/green steel language (water_1 deep blue-black shadow, teal_1, teal_2, grass_6
glint, water_6 pale, cream edge), ghost wisps and chain links instead of lightning crackle, a giant chain whipping across
the screen and hooking with the scythe blade instead of a bolt, and the banner is dragged out to the left (the pull).

Outputs (presentation/cutin/):
  chainscythe_pose_<name>.png      lit pose: teal rim light, 1px deep gap, pale/teal rim, ghost wisps + loose links (x12)
  chainscythe_pose_<name>_sil.png  the same pose as an ink silhouette with a cream line and a teal outline (impact)
                                   name (format names): crouch = the skill wind-up, ready = the whip-out,
                                                        burst = the drag/pull
  chainscythe_aura.png             12 frames (6x2 atlas, x8): ghost wisps rising + a ring of chain circling, bottom-centred
  chainscythe_strike_<1..4>.png    800x450 backdrop: a giant chain whips across and the blade hooks (lead, strike,
                                   slack afterglow, scattering links) (x8)
  chainscythe_flash_<1..3>.png     800x450 full-width pop: pale flash with a dark chain, then speed lines fading (x4)
  chainscythe_cutin.json           sizes, anchors, atlas frames, file lists and suggested timings
  chainscythe_cutin_preview.gif    about 1.2 s at 30 fps on the dark cut-in background (viewing only)
  chainscythe_cutin_contact.png    every preview frame at 320x180 (game scale) plus the raw assets (viewing only)
Pillow only, fixed seeds (re-running gives identical files). Run from the project root:
  python tools/art/export_chain_scythe_cutin.py
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
    FONT, FPS, H, LEFT0, RIGHT_TOP, SLOPE, FIG_SCALE, W, FW, FH, FX_SCALE, AURA_SCALE,
    alpha_mask, banner_poly, check_hard, dilate, draw_path, ease_back, ease_in, ease_out, minus, poly_mask, ramp,
    solid, up, y_bot,
)
import make_chain_scythe_art as C  # noqa: E402  (no side effects on import)

ROOT = artlib.ROOT
OUT = ROOT / "presentation" / "cutin"
PAL = artlib.load_palette()
FORBIDDEN = set(PAL.reserved)
T = "."

POSE_SCALE = 12      # like Lightning: 1x pose pixels -> canvas units
STRIKE_SCALE = 8     # the giant chain is drawn at 100x57 and scaled x8 (links stay chunky)
PAD = 8
SEEDS = {"crouch": 31, "ready": 32, "burst": 33}
WISPS = {"crouch": 5, "ready": 7, "burst": 10}


def col(sym: str) -> tuple[int, int, int, int]:
    assert sym not in FORBIDDEN, f"reserved colour {sym}"
    return PAL.by_symbol[sym] + (255,)


def grid_img(g) -> Image.Image:
    return C.to_image(g)


# ------------------------------------------------------------------------------------------------------ poses
def pose_grids() -> dict[str, tuple[list, tuple[int, int]]]:
    """1x pose grids with their feet point. crouch = the concept wind-up cell; ready (whip-out) and burst (pull) are
    rebuilt on a wider canvas so the chain reaches the scythe (whip) or runs out of frame toward the golem (pull)."""
    spec = {p["name"]: p for p in C.POSES}
    out = {}
    out["crouch"] = (C.build_pose(spec["windup"])["full"], (C.AX, C.AY))
    # whip-out: the scythe tumbling at the end of the thrown chain
    body, hands = C.hero_body(*spec["whip"]["body"])
    g = C.blank(96, 64)
    C.paste(g, body, 0, 0)
    hx, hy = hands[0]
    tip = (86, 24)
    C.chain_between(g, (hx, hy), tip, 2.5, 1, waves=1.2)
    C.paste(g, C.flying_scythe(1), tip[0] - 16, tip[1] - 16)
    C.draw_chain(g, [(hx, hy), (51, 43), (49, 47)])  # the slack end hanging from the fist
    C.fist_over(g, body, (hx, hy), (tip[0] - hx, tip[1] - hy))  # the fist closes over the chain
    out["ready"] = (g, (C.AX, C.AY))
    # pull: leaning back, the taut chain runs out to the right and breaks into fading links
    body, hands = C.hero_body(*spec["pull"]["body"])
    g = C.blank(96, 64)
    lay = C.blank(96, 64)
    path = C.pixel_path([hands[1], hands[0], (95, 37)])  # through both fists
    for (x, y), c in C.chain_pixels(path, 1).items():
        if x < 78 or (x // 4) % 2 == 0 and x < 90:
            C.put(lay, x, y, c)
    C.outline_layer(lay, "0")
    C.draw_chain(lay, [hands[1], (36, 49), (39, 52), (41, 47)])
    for h in hands:  # both fists close over the taut chain
        C.fist_over(lay, body, h, (95 - h[0], 37 - h[1]))
    C.paste(g, body, 0, 0)
    C.paste(g, lay, 0, 0)
    out["burst"] = (g, (C.AX, C.AY))
    return out


RAMPS = ["234567", "89abcd", "efghij", "klmnop", "qrs", "tu"]
LIGHTER = {r[i]: r[i + 1] for r in RAMPS for i in range(len(r) - 1)}


def rim_light(body: Image.Image) -> Image.Image:
    """Pixels just inside the outline on the top/front edge go one step lighter in their own ramp."""
    out = body.copy()
    a = alpha_mask(body)
    inner = minus(a, ImageChops.darker(ImageChops.offset(a, 1, 0), ImageChops.offset(a, 0, 1)))
    src, px, am, em = body.load(), out.load(), a.load(), inner.load()
    sym_of = {v: k for k, v in PAL.by_symbol.items()}
    for y in range(1, body.height):
        for x in range(1, body.width):
            if not am[x, y] or em[x, y] or not (em[x - 1, y] or em[x, y - 1]):
                continue
            sym = sym_of.get(src[x, y][:3])
            if sym in LIGHTER:
                px[x, y] = col(LIGHTER[sym])
    return out


def wisps(rng: random.Random, body: Image.Image, count: int) -> tuple[Image.Image, Image.Image]:
    """Ghost wisps curling up and back off the outline (a bend, then a hook), with grass_6 tips."""
    a = alpha_mask(body)
    edge = minus(dilate(a, 1), a)
    pts = [(x, y) for y in range(edge.height) for x in range(edge.width) if edge.getpixel((x, y))]
    top = min(p[1] for p in pts)
    bot = max(p[1] for p in pts)
    pts = [p for p in pts if p[1] < top + (bot - top) * 0.75] or pts
    core = Image.new("L", body.size, 0)
    tips = Image.new("L", body.size, 0)
    for _ in range(count):
        x, y = rng.choice(pts)
        ln = rng.uniform(4, 8)
        side = rng.choice((-1, 1))
        path = []
        for i in range(9):
            s = i / 8
            path.append((x - s * ln * 0.6 + side * math.sin(s * math.pi * 1.4) * 1.6, y - s * ln))
        draw_path(core, path)
        ex, ey = round(path[-1][0]), round(path[-1][1])
        if 0 <= ex < tips.width and 0 <= ey < tips.height:
            tips.putpixel((ex, ey), 255)
    return minus(core, a), minus(tips, a)


def make_pose(name: str, grid, feet: tuple[int, int]) -> tuple[Image.Image, Image.Image, dict]:
    rng = random.Random(SEEDS[name])
    cell = grid_img(grid)
    x0, y0, x1, y1 = cell.getchannel("A").getbbox()
    body = Image.new("RGBA", (x1 - x0 + 2 * PAD, y1 - y0 + 2 * PAD), (0, 0, 0, 0))
    body.alpha_composite(cell.crop((x0, y0, x1, y1)), (PAD, PAD))
    a = alpha_mask(body)
    d1, d2, d3 = dilate(a, 1), dilate(a, 2), dilate(a, 3)
    lit = Image.new("RGBA", body.size, (0, 0, 0, 0))
    lit.alpha_composite(solid(minus(dilate(d3, 1, diamond=False), d3), "t"))
    lit.alpha_composite(solid(minus(d3, d2), "u"))
    lit.alpha_composite(solid(minus(d2, d1), "p"))
    lit.alpha_composite(solid(minus(d1, a), "k"))  # the 1px deep gap keeps his own outline readable
    wc, wt = wisps(rng, body, WISPS[name])
    wc, wt = minus(wc, d1), minus(wt, d1)
    lit.alpha_composite(solid(minus(dilate(wc, 1), d2), "t"))
    lit.alpha_composite(rim_light(body))
    lit.alpha_composite(solid(wc, "u"))
    lit.alpha_composite(solid(wt, "7"))
    rng2 = random.Random(SEEDS[name] + 100)
    sc, st = wisps(rng2, body, WISPS[name] + 5)
    sil = Image.new("RGBA", body.size, (0, 0, 0, 0))
    sil.alpha_composite(solid(minus(dilate(a, 2), d1), "u"))
    sil.alpha_composite(solid(minus(dilate(sc, 1), a), "t"))
    sil.alpha_composite(solid(minus(d1, a), "1"))
    sil.alpha_composite(solid(a, "0"))
    sil.alpha_composite(solid(sc, "u"))
    sil.alpha_composite(solid(st, "7"))
    k = POSE_SCALE
    meta = {"w": body.width * k, "h": body.height * k, "pad": PAD * k, "inner_w": (x1 - x0) * k,
            "inner_h": (y1 - y0) * k, "feet_x": round((feet[0] - x0) / (x1 - x0), 3),
            "content": {"crouch": "skill wind-up (concept 'windup')", "ready": "whip-out, scythe tumbling at the chain's end",
                        "burst": "drag/pull, taut chain running out of frame toward the golem"}[name]}
    return up(lit, k), up(sil, k), meta


# ------------------------------------------------------------------------------------------------- aura atlas
def make_aura_frame(i: int) -> Image.Image:
    """48x56 at 1x: ghost wisps rising from the feet and a ring of chain circling the figure (x8, bottom-centred)."""
    rng = random.Random(800 + i)
    w, h = 48, 56
    core = Image.new("L", (w, h), 0)
    tips = Image.new("L", (w, h), 0)
    for j in range(4 + i % 2):
        sx = w / 2 + rng.uniform(-12, 12)
        ln = rng.uniform(22, 44)
        ph = rng.uniform(0, math.tau) + i * 0.6
        path = [(sx + math.sin(ph + s * 3.2) * 2.5 * (0.4 + s), h - 2 - s * ln) for s in [k / 14 for k in range(15)]]
        draw_path(core, path)
        tx, ty = round(path[-1][0]), round(path[-1][1])
        if 0 <= tx < w and 0 <= ty < h:
            tips.putpixel((tx, ty), 255)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    m = core
    rings = []
    for sym in ("t", "k"):
        big = dilate(m, 1)
        rings.append((minus(big, m), sym))
        m = big
    for r, sym in reversed(rings):
        img.alpha_composite(solid(r, sym))
    img.alpha_composite(solid(core, "u"))
    img.alpha_composite(solid(tips, "7"))
    # the circling chain: the back half is drawn faintly (teal_1), the front half as real links
    g = C.blank(w, h)
    cx, cy, rx, ry = w / 2, h * 0.55, 20, 6
    a0 = i * 30
    pts = [(cx + math.cos(math.radians(a0 + d)) * rx, cy + math.sin(math.radians(a0 + d)) * ry) for d in range(0, 200, 10)]
    path = C.pixel_path(pts)
    lay = C.blank(w, h)
    for (x, y), c in C.chain_pixels(path, i).items():
        C.put(lay, x, y, c if y >= cy else "t")
    C.outline_layer(lay, "0")
    C.paste(g, lay, 0, 0)
    img.alpha_composite(C.to_image(g))
    return up(img, AURA_SCALE)


# ------------------------------------------------------------------------------------------- backdrop strike
SWD, SHD = 100, 57  # strike grid (x8 -> 800x456, cropped to 450)


def strike_path(phase: int) -> list[tuple[float, float]]:
    a, b = (-4, SHD * 0.92), (SWD * 0.66, SHD * 0.34)
    reach = {1: 0.7, 2: 1.0, 3: 1.0, 4: 1.0}[phase]
    amp = {1: 4.0, 2: 0.6, 3: 3.0, 4: 3.0}[phase]
    sag = {1: 0.0, 2: 0.0, 3: 6.0, 4: 8.0}[phase]
    pts = []
    for i in range(61):
        s = i / 60 * reach
        x = a[0] + (b[0] - a[0]) * s
        y = a[1] + (b[1] - a[1]) * s + amp * math.sin(s * 9 + phase) * s + sag * math.sin(math.pi * s)
        pts.append((x, y))
    return pts


def make_strike(phase: int) -> Image.Image:
    rng = random.Random(70 + phase)
    g = C.blank(SWD, SHD)
    path = C.pixel_path(strike_path(phase))
    links = C.chain_pixels(path, phase)
    lay = C.blank(SWD, SHD)
    for (x, y), c in links.items():
        if phase == 4 and (x // 3 + phase) % 3 == 0:
            continue
        C.put(lay, x + (rng.randint(-1, 1) if phase == 4 else 0), y + (rng.randint(-1, 1) if phase == 4 else 0),
              c if phase in (1, 2) else ("t" if c in "j1" else "k"))
    C.outline_layer(lay, "0")
    tip = path[-1]
    if phase == 2:  # halo along the taut chain, the giant blade hooking, the clink
        halo = C.blank(SWD, SHD)
        for i, (x, y) in enumerate(path):
            for dy in (-2, 2):
                if (i + dy) % 2 == 0:
                    C.put(halo, x, y + dy, "u" if i % 6 < 3 else "7")
        C.paste(g, halo, 0, 0)
    C.paste(g, lay, 0, 0)
    if phase in (1, 2, 3):
        sc = C.blank(SWD, SHD)
        if phase == 1:
            C.paste(sc, C.flying_scythe(2), tip[0] - 16, tip[1] - 16)
        else:
            head = (tip[0] + 12, tip[1] - 7)
            C.draw_scythe(sc, tip, head, 1, 27 if phase == 2 else 22, curl=88, width=3.6)
        C.paste(g, sc, 0, 0)
    if phase == 2:
        hx, hy = tip[0] + 16, tip[1] + 10
        C.ring(g, hx, hy, 9, "u")
        C.star(g, hx, hy, 8, "1", "p", "u", 4)
        for y in range(-1, 2):
            for x in range(-1, 2):
                C.put(g, hx + x, hy + y, "1")
    if phase == 4:
        for _ in range(14):
            x, y = rng.randrange(SWD), rng.randrange(SHD)
            if abs(y - (SHD * 0.92 + (SHD * 0.34 - SHD * 0.92) * (x / (SWD * 0.66)))) < 10:
                C.put(g, x, y, rng.choice("ut7"))
    return up(C.to_image(g), STRIKE_SCALE).crop((0, 0, W, H))


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
        if rng.random() < 0.3:
            d.line((round(x + ln * 0.25), round(y + 1 + SLOPE * ln * 0.25), round(x + ln * 0.75), round(y + 1 + SLOPE * ln * 0.75)), fill=255)
        img.alpha_composite(solid(m, rng.choice(syms)))
    return img


def flat_chain(y: float, phase: int, rim: str) -> Image.Image:
    g = C.blank(FW, FH)
    path = C.pixel_path([(-2, y + SLOPE * -2), (FW + 2, y + SLOPE * (FW + 2))])
    lay = C.blank(FW, FH)
    for (x, yy), c in C.chain_pixels(path, phase).items():
        C.put(lay, x, yy, c)
    C.outline_layer(lay, rim)
    C.paste(g, lay, 0, 0)
    return C.to_image(g)


def make_flash(phase: int) -> Image.Image:
    rng = random.Random(60 + phase)
    if phase == 1:  # pale pop with teal speed lines and a dark chain snapping across
        img = Image.new("RGBA", (FW, FH), col("p"))
        img.alpha_composite(speed_lines(rng, 70, ["u", "u", "t", "7"], 20, 90))
        sil = flat_chain(FH * 0.56, 0, "0")
        a = alpha_mask(sil)
        img.alpha_composite(solid(dilate(a, 1), "t"))
        img.alpha_composite(solid(a, "0"))
    elif phase == 2:  # dense full-width speed lines and the chain, no fill
        img = speed_lines(rng, 75, ["1", "p", "u", "u", "7", "t"], 30, 140)
        img.alpha_composite(flat_chain(FH * 0.44, 2, "k"))
    else:
        img = speed_lines(rng, 40, ["u", "t", "7", "k"], 20, 80)
    return up(img, FX_SCALE).crop((0, 0, W, H))


# ---------------------------------------------------------------------------------------- preview (viewing)
BG = (4, 10, 14)
BAN_TOP = (26, 64, 66)
BAN_BOT = (6, 14, 22)
CREAM = col("1")[:3]
PALE = col("p")[:3]
TEAL = col("u")[:3]
TEAL_D = col("t")[:3]
GLINT = col("7")[:3]
DEEP = col("k")[:3]
INK = col("0")[:3]
IMPACT = (226, 240, 232)
N_FRAMES = 36
FIG_FIT = {"crouch": 1.0, "ready": 0.78, "burst": 0.8}
BEATS = [("crouch", 0.10, 0.37), ("ready", 0.37, 0.62), ("burst", 0.62, 1.20)]
CUTS = [0.37, 0.62]
SLAM = 0.70
EXIT = (0.98, 1.16)
FIG_X = 300.0
GRAD = Image.linear_gradient("L").resize((W, H))
BAN_BG = Image.composite(Image.new("RGBA", (W, H), BAN_BOT + (255,)), Image.new("RGBA", (W, H), BAN_TOP + (255,)), GRAD)


def banner_offset(t: float) -> float:
    # slams in from the left, then is yanked back out to the left (the drag)
    return -760 * (1 - ease_back(ramp(t, 0.03, 0.17))) - 900 * ease_in(ramp(t, *EXIT))


def strike_at(t: float, k: int) -> int:
    if t >= CUTS[1]:
        n = int((t - CUTS[1]) * FPS + 1e-6)
        return [1, 2, 2, 3, 3, 4, 4][n] if n < 7 else (3 if k % 4 < 2 else 4)
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
    if CUTS[1] <= t < CUTS[1] + 1 / FPS:
        return 2
    if CUTS[1] + 1 / FPS <= t < CUTS[1] + 3 / FPS:
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
        c = rng.choice([TEAL, CREAM, PALE, GLINT])
        d.line((x, y, x + ln, y + SLOPE * ln), fill=c + (rng.randint(80, 170),), width=rng.choice([2, 2, 4]))
    return img


def radial(k: int, centre: tuple[float, float]) -> Image.Image:
    rng = random.Random(900 + k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(36):
        a = rng.uniform(0, math.tau)
        r0, r1 = rng.uniform(90, 150), rng.uniform(300, 600)
        d.line((centre[0] + math.cos(a) * r0, centre[1] + math.sin(a) * r0, centre[0] + math.cos(a) * r1, centre[1] + math.sin(a) * r1), fill=TEAL_D + (255,), width=rng.choice([2, 4]))
    return img


def title(font, small, t: float, off: float, shake) -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    label = "REAPER'S COIL"
    tx = ramp(t, SLAM, SLAM + 0.08)
    size = int(54 * (1 + 0.25 * (1 - ease_out(tx))))
    f = font.font_variant(size=size)
    cx = off + 270 + shake[0]
    cy = y_bot(off + 270, off) + 14 + shake[1]
    d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), label, font=f, stroke_width=6)
    org = (cx - (bb[2] - bb[0]) / 2, cy - (bb[3] - bb[1]) / 2)
    d.text((org[0] + 4, org[1] + 5), label, font=f, fill=INK, stroke_width=6, stroke_fill=INK)
    d.text(org, label, font=f, fill=TEAL, stroke_width=6, stroke_fill=DEEP)
    d.text(org, label, font=f, fill=CREAM)
    if t >= SLAM + 0.06:  # subtitle (the runtime would show the real hook range / stagger numbers here)
        sub = "HOOK  -  DRAG  -  STAGGER"
        sb = d.textbbox((0, 0), sub, font=small, stroke_width=3)
        so = (cx - (sb[2] - sb[0]) / 2 + 30, org[1] + (bb[3] - bb[1]) + 2)
        d.text(so, sub, font=small, fill=PALE, stroke_width=3, stroke_fill=INK)
    return img.transform(img.size, Image.AFFINE, (1, 0.22, -0.22 * cy, 0, 1, 0), Image.NEAREST)


def exit_smear(k: int, off: float) -> Image.Image:
    rng = random.Random(k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rx = RIGHT_TOP + off
    for _ in range(16):
        y = rng.uniform(100, 360)
        d.line((rx - 20, y, rx + rng.uniform(80, 360), y + SLOPE * 100), fill=rng.choice([TEAL, PALE, GLINT]) + (200,), width=rng.choice([2, 2, 4]))
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
        for cut in CUTS + [SLAM]:
            if cut <= t < cut + 0.1:
                shake = (rng.randint(-6, 6), rng.randint(-4, 4))
        beat = next((b for b in BEATS if b[1] <= t < b[2]), None)
        impact = False
        layer = BAN_BG.copy()
        st = strike_at(t, k)
        strike_out = st == 2
        if st and not strike_out:
            layer.alpha_composite(strikes[st - 1], (int(off * 0.2), 0))
        layer.alpha_composite(speed_lines_layer(k, off))
        fig = None
        if beat:
            fx = off + FIG_X
            if ramp(t, 0.15, 0.3) > 0:
                af = aura[(k // 2) % len(aura)]
                hgt = 250 if beat[0] != "burst" else 290
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
            feet_x = fx - (30 * ease_out(local / 0.3) if beat[0] == "burst" else 0)  # the pull: he skids back
            px_ = feet_x - meta["pad"] * sc - meta["inner_w"] * sc * meta["feet_x"] + shake[0]
            py_ = y_bot(feet_x, off) - 4 - (fig.height - meta["pad"] * sc) + shake[1]
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
        bd.line(loop, fill=TEAL, width=10)
        bd.line(loop, fill=CREAM, width=4)
        fi = flash_at(t)
        if fi:
            frame.alpha_composite(flashes[fi - 1])
        if t >= SLAM and off > -700:
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
        d.text((x, y), f"f{i}  t={i / FPS:.2f}s", font=small, fill=(200, 220, 215))
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
        d.text((x, row_y), name, font=small, fill=(200, 220, 215))
        tile = Image.new("RGBA", th.size, (20, 34, 40, 255))
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
        "generator": "tools/art/export_chain_scythe_cutin.py (Pillow only, fixed seeds; shared format of export_lightning_cutin.py)",
        "status": "review stage; not wired into the game",
        "title": "REAPER'S COIL", "subtitle_suggestion": "hook range / stagger time from the core, like the other cut-ins",
        "canvas": [W, H],
        "palette": "Totoy 36, hard alpha; no gold x,y or red z,A",
        "pose_scale": POSE_SCALE, "aura_scale": AURA_SCALE, "fx_scale": FX_SCALE, "strike_scale": STRIKE_SCALE,
        "poses": {}, "aura": {}, "strikes": [], "flashes": [],
        "timing_s": {"note": "suggested, preview seconds at 30 fps; a sibling of black_form_cutin.gd may scale them by SPEED",
                     "flash_pop": [0.0, 0.167], "banner_in": [0.03, 0.17], "beats": BEATS, "cuts": CUTS,
                     "strike_on_burst": [[1, 0.033], [2, 0.067], [3, 0.067], [4, 0.067], ["3/4 flicker", "until exit"]],
                     "title_slam": SLAM, "exit": list(EXIT), "exit_direction": "left (yanked back, like the drag)", "end": EXIT[1]},
    }
    poses = {}
    for name, (grid, feet) in pose_grids().items():
        lit, sil, m = make_pose(name, grid, feet)
        save(lit, f"chainscythe_pose_{name}.png", written)
        save(sil, f"chainscythe_pose_{name}_sil.png", written)
        meta["poses"][name] = m
        poses[name] = (lit, sil, m)
    poses = {k: poses[k] for k in ("crouch", "ready", "burst")}
    aura = [make_aura_frame(i) for i in range(12)]
    cw, chh = aura[0].size
    atlas = Image.new("RGBA", (cw * 6, chh * 2), (0, 0, 0, 0))
    frames = []
    for i, a in enumerate(aura):
        x0, y0 = (i % 6) * cw, (i // 6) * chh
        atlas.alpha_composite(a, (x0, y0))
        frames.append({"x": x0, "y": y0, "w": cw, "h": chh})
    save(atlas, "chainscythe_aura.png", written)
    meta["aura"] = {"cell_w": cw, "cell_h": chh, "frames": frames, "anchor": "bottom centre"}
    strikes = [make_strike(p) for p in range(1, 5)]
    for i, s in enumerate(strikes):
        save(s, f"chainscythe_strike_{i + 1}.png", written)
        meta["strikes"].append(f"chainscythe_strike_{i + 1}.png")
    flashes = [make_flash(p) for p in range(1, 4)]
    for i, f in enumerate(flashes):
        save(f, f"chainscythe_flash_{i + 1}.png", written)
        meta["flashes"].append(f"chainscythe_flash_{i + 1}.png")
    (OUT / "chainscythe_cutin.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    written.append("chainscythe_cutin.json")
    preview = render_preview((poses, aura, strikes, flashes))
    gif = [f.convert("P", palette=Image.ADAPTIVE, colors=255) for f in preview]
    gif[0].save(OUT / "chainscythe_cutin_preview.gif", save_all=True, append_images=gif[1:], duration=33, loop=0, disposal=1)
    written.append("chainscythe_cutin_preview.gif")
    contact_sheet(preview, poses, strikes, flashes, aura).save(OUT / "chainscythe_cutin_contact.png")
    written.append("chainscythe_cutin_contact.png")
    for n in written:
        print(n)
    print("wrote", len(written), "files to", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
