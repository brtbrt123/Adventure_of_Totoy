"""Black Form transformation cut-in, v3 (polish pass over v2).
Uses ONLY the real black-form art (concept_v1.png poses + aura_layers_v1.png wisps).
MLBB collab-style ultimate cut-in: a slanted glowing banner slams in from the left, three pose beats
(crouch -> rise -> burst) with hit-stop, flashes, speed lines and a light sweep, the title slams in,
then the banner leaves and the transformation lands on the in-scene hero.
Preview only: nothing here is in the game."""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

PROJECT = Path(r"C:\Users\Admin\Desktop\Projects\Adventure_of_Totoy")
OUT = Path(__file__).parent
W, H = 800, 450
FPS = 20
DURATION = 2.9
N = int(round(FPS * DURATION))
COLORS = 255

VIOLET = (154, 100, 255)
VIOLET_D = (70, 30, 140)
CREAM = (244, 236, 214)
INK = (14, 6, 30)

bg = Image.open(OUT / "bg.png").convert("RGBA").resize((W, H), Image.LANCZOS)
concept = Image.open(PROJECT / "art/reference/black_katana_form/concept_v1.png").convert("RGBA")
aura_sheet = Image.open(PROJECT / "art/reference/black_katana_form/aura_layers_v1.png").convert("RGBA")
font_path = str(PROJECT / "presentation/fonts/PixelifySans.ttf")
HERO = (300, 276)  # hero's feet in the 800x450 scene


def hero_mask():
    """The hero's pixels in the screenshot: non-grass pixels in his box, shadow excluded."""
    box = (270, 190, 345, 279)
    crop = bg.crop(box).convert("RGB")
    m = Image.new("L", crop.size, 0)
    src = crop.load()
    mp = m.load()
    for y in range(crop.height):
        for x in range(crop.width):
            r, g, b = src[x, y]
            if not (g > r + 6 and g > b + 6):
                mp[x, y] = 255
    m = m.filter(ImageFilter.ModeFilter(3))
    # keep only the biggest connected blob (the hero), dropping stray flower/dirt pixels
    best = None
    seen = set()
    mp = m.load()
    for y in range(m.height):
        for x in range(m.width):
            if mp[x, y] and (x, y) not in seen:
                blob, st = [], [(x, y)]
                seen.add((x, y))
                while st:
                    cx, cy = st.pop()
                    blob.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < m.width and 0 <= ny < m.height and mp[nx, ny] and (nx, ny) not in seen:
                            seen.add((nx, ny))
                            st.append((nx, ny))
                if best is None or len(blob) > len(best):
                    best = blob
    m = Image.new("L", m.size, 0)
    mp = m.load()
    for p in best:
        mp[p] = 255
    full = Image.new("L", (W, H), 0)
    full.paste(m, box[:2])
    return full


HERO_MASK = hero_mask()


def font(size, weight=400):
    f = ImageFont.truetype(font_path, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def clamp01(x):
    return max(0.0, min(1.0, x))


def ramp(t, a, b):
    return clamp01((t - a) / (b - a))


def ease_out(x):
    x = clamp01(x)
    return 1 - (1 - x) ** 3


def ease_in(x):
    x = clamp01(x)
    return x ** 3


def ease_back(x):
    x = clamp01(x)
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def with_opacity(img, o):
    if o >= 0.999:
        return img
    out = img.copy()
    out.putalpha(img.getchannel("A").point(lambda v: int(v * o)))
    return out


# ---------------------------------------------------------------- pose isolation
# Label alpha-connected blobs (at half resolution). The six biggest blobs are the six figures; every
# small fragment (aura flecks) joins the nearest figure if it is close enough. A pose is its figure plus
# its own fragments, so the neighbour's slash arc or aura never bleeds into the cut-out.
def isolate_poses():
    S = 2
    small = concept.getchannel("A").resize((concept.width // S, concept.height // S), Image.BOX)
    m = small.point(lambda v: 255 if v > 12 else 0)
    w, h = m.size
    px = list(m.getdata())
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
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
                for j in ((i + 1) if x + 1 < w else -1, (i - 1) if x > 0 else -1, (i + w) if y + 1 < h else -1, (i - w) if y > 0 else -1):
                    if j >= 0 and px[j] and not lab[j]:
                        lab[j] = n
                        st.append(j)
            comps.append((cnt, (x0, y0, x1, y1)))
    order = sorted(range(len(comps)), key=lambda c: -comps[c][0])
    cores = order[:6]

    def cell_of(c):
        x0, y0, x1, y1 = comps[c][1]
        cx, cy = (x0 + x1) / 2 * S, (y0 + y1) / 2 * S
        return int(cy // (concept.height / 2)) * 3 + int(cx // (concept.width / 3))

    core_by_cell = {cell_of(c): c for c in cores}

    def box_dist(a, b):
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
    for cell, core in core_by_cell.items():
        keep = bytes(255 if (l and owner.get(l) == core) else 0 for l in lab)
        mask = Image.frombytes("L", (w, h), keep).resize(concept.size, Image.NEAREST)
        mask = mask.filter(ImageFilter.MaxFilter(3))
        x0, y0, x1, y1 = comps[core][1]
        # bbox of everything owned
        bb = mask.getbbox()
        img = concept.copy()
        img.putalpha(ImageChops.multiply(concept.getchannel("A"), mask))
        poses[cell] = img.crop(bb)
    return poses


ALL_POSES = isolate_poses()


def rim_light(img, color, radius=6, strength=1.6):
    a = img.getchannel("A")
    pad = radius * 3
    big = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0, 0))
    big.alpha_composite(img, (pad, pad))
    ab = big.getchannel("A")
    glow = Image.new("RGBA", big.size, color + (0,))
    glow.putalpha(ab.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: int(min(255, v * strength))))
    out = Image.alpha_composite(glow, big)
    return out, pad, big


# per pose: sheet index, feet anchor as fraction of the cut-out (x), scale
POSE_DEF = {"crouch": 0, "ready": 1, "burst": 4}
POSES = {}
POSES_RAW = {}  # same geometry, no rim glow (used for the impact-frame silhouette)
for name, idx in POSE_DEF.items():
    lit, pad, raw = rim_light(ALL_POSES[idx], VIOLET)
    POSES[name] = (lit, pad)
    POSES_RAW[name] = (raw, pad)
# feet x inside each cut-out (pixels in the un-padded cut-out); measured from the sheet
FEET_X = {"crouch": 0.47, "ready": 0.47, "burst": 0.42}
FIG_SCALE = 0.63

# ---------------------------------------------------------------- aura wisps
AURA = []
cw, ch = aura_sheet.width // 6, aura_sheet.height // 2
for row in range(2):
    for col in range(6):
        cell = aura_sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
        bb = cell.getchannel("A").getbbox()
        cell = cell.crop(bb)
        pad = 12
        big = Image.new("RGBA", (cell.width + 2 * pad, cell.height + 2 * pad), (0, 0, 0, 0))
        big.alpha_composite(cell, (pad, pad))
        glow = Image.new("RGBA", big.size, (150, 95, 235, 0))
        glow.putalpha(big.getchannel("A").filter(ImageFilter.GaussianBlur(7)).point(lambda v: min(255, int(v * 1.3))))
        AURA.append(Image.alpha_composite(glow, big))


def aura(index, height, flip=False, opacity=1.0):
    cell = AURA[index % len(AURA)]
    img = cell.resize((max(1, int(cell.width * height / cell.height)), height), Image.LANCZOS)
    if flip:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return with_opacity(img, opacity)


# ---------------------------------------------------------------- banner geometry
SLOPE = -0.075
TOP0, BOT0 = 112, 352
LEFT0, RIGHT_TOP, RIGHT_BOT = -90, 640, 575


def y_top(x, off):
    return TOP0 + SLOPE * (x - off)


def y_bot(x, off):
    return BOT0 + SLOPE * (x - off)


def banner_poly(off):
    l, rt, rb = LEFT0 + off, RIGHT_TOP + off, RIGHT_BOT + off
    return [(l, y_top(l, off)), (rt, y_top(rt, off)), (rb, y_bot(rb, off)), (l, y_bot(l, off))]


def breakout_poly(off):
    """Banner plus the space above it: the figure may rise above the top edge, never below the bottom."""
    l, rt, rb = LEFT0 + off, RIGHT_TOP + off, RIGHT_BOT + off
    return [(l, -50), (rt + 40, -50), (rt, y_top(rt, off)), (rb, y_bot(rb, off)), (l, y_bot(l, off))]


def poly_mask(poly, blur=0):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return m


GRAD = Image.linear_gradient("L").resize((W, H))
BAN_BG = Image.composite(Image.new("RGB", (W, H), (8, 3, 20)), Image.new("RGB", (W, H), (78, 34, 150)), GRAD).convert("RGBA")
_dots = Image.new("RGBA", (W, H), (0, 0, 0, 0))
_dd = ImageDraw.Draw(_dots)
for yy in range(0, H, 12):
    for xx in range(0 if (yy // 12) % 2 == 0 else 6, W, 12):
        r = 3.2 * (yy / H) - 0.3
        if r > 0.6:
            _dd.ellipse((xx - r, yy - r, xx + r, yy + r), fill=(130, 80, 220, 70))
BAN_BG = Image.alpha_composite(BAN_BG, _dots)


def banner_fill(t, k, off, chest, burst):
    img = BAN_BG.copy()
    d = ImageDraw.Draw(img, "RGBA")
    rr = random.Random(300 + k)
    # speed lines running along the banner, streaming left
    for _ in range(26):
        y = rr.uniform(70, 380)
        x = rr.uniform(-100, 760)
        ln = rr.uniform(60, 260)
        col = rr.choice([CREAM + (rr.randint(60, 150),), (190, 150, 255, rr.randint(70, 160))])
        d.line((x, y, x + ln, y + SLOPE * ln), fill=col, width=rr.choice([1, 1, 2, 3]))
    # radial burst lines from the chest on the burst beat
    if burst > 0:
        cx, cy = chest
        for _ in range(44):
            ang = rr.uniform(0, math.tau)
            r0 = rr.uniform(60, 120)
            r1 = r0 + rr.uniform(160, 420)
            d.line((cx + math.cos(ang) * r0, cy + math.sin(ang) * r0, cx + math.cos(ang) * r1, cy + math.sin(ang) * r1), fill=(235, 220, 255, int(rr.randint(60, 170) * burst)), width=rr.choice([1, 2, 3]))
    return img


def sweep(layer, t, t0, dur=0.25, width=70):
    """Diagonal light band crossing the cut-in once, screened onto everything already drawn."""
    p = ramp(t, t0, t0 + dur)
    if p <= 0 or p >= 1:
        return layer
    x = -200 + p * (W + 400)
    band = Image.new("L", (W, H), 0)
    ImageDraw.Draw(band).polygon([(x, -10), (x + width, -10), (x + width - 160, H + 10), (x - 160, H + 10)], fill=150)
    ImageDraw.Draw(band).polygon([(x + width + 14, -10), (x + width + 26, -10), (x + width - 134, H + 10), (x + width - 146, H + 10)], fill=110)
    band = ImageChops.multiply(band, layer.getchannel("A"))
    lit = Image.new("RGBA", (W, H), (255, 250, 240, 0))
    lit.putalpha(band)
    return Image.alpha_composite(layer, lit)


# ---------------------------------------------------------------- title
def make_title(size, glitch_seed=None):
    label = "BLACK FORM"
    f = font(size)
    pad = 20
    tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
    l, t_, r, b = tmp.textbbox((0, 0), label, font=f, stroke_width=6)
    tw, th = r - l + 2 * pad, b - t_ + 2 * pad
    base = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    org = (pad - l, pad - t_)
    # violet glow
    gl = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(gl).text(org, label, font=f, fill=VIOLET + (255,), stroke_width=8, stroke_fill=VIOLET + (255,))
    base.alpha_composite(gl.filter(ImageFilter.GaussianBlur(6)))
    # hard drop + outline
    d.text((org[0] + 4, org[1] + 5), label, font=f, fill=INK + (255,), stroke_width=6, stroke_fill=INK + (255,))
    d.text(org, label, font=f, fill=CREAM + (255,), stroke_width=6, stroke_fill=(40, 14, 84, 255))
    # faux-bold: one more 1px stroke in cream
    d.text(org, label, font=f, fill=CREAM + (255,), stroke_width=1, stroke_fill=CREAM + (255,))
    # violet shade on the lower half of the glyphs
    shade = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(shade).text(org, label, font=f, fill=(190, 160, 255, 255))
    lower = Image.new("L", (tw, th), 0)
    ImageDraw.Draw(lower).rectangle((0, org[1] + int((b - t_) * 0.62), tw, th), fill=255)
    shade.putalpha(ImageChops.multiply(shade.getchannel("A"), lower))
    base.alpha_composite(shade)
    if glitch_seed is not None:
        rr = random.Random(glitch_seed)
        split = Image.new("RGBA", (tw + 24, th), (0, 0, 0, 0))
        mask = base.getchannel("A")
        for col, dx in ((VIOLET, 0), ((255, 255, 255), 24)):
            c = Image.new("RGBA", (tw, th), col + (0,))
            c.putalpha(mask.point(lambda v: int(v * 0.75)))
            split.alpha_composite(c, (dx, 0))
        split.alpha_composite(base, (12, 0))
        # horizontal slice displacement
        out = Image.new("RGBA", split.size, (0, 0, 0, 0))
        y = 0
        while y < th:
            hgt = rr.randint(6, 16)
            dx = rr.choice([0, 0, 0, -6, 6, -10, 9])
            paste_any(out, split.crop((0, y, split.width, min(th, y + hgt))), (dx, y))
            y += hgt
        base = out
    # slant (top leans right)
    sh = 0.22
    bw, bh = base.size
    sl = base.transform((bw + int(sh * bh), bh), Image.AFFINE, (1, sh, -sh * bh, 0, 1, 0), Image.NEAREST)
    return sl


def make_sub():
    f = font(18)
    txt = "ATTACK SPEED UP  /  DAMAGE UP"
    tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
    l, t_, r, b = tmp.textbbox((0, 0), txt, font=f)
    img = Image.new("RGBA", (r - l + 40, b - t_ + 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(10, 0), (img.width, 0), (img.width - 10, img.height), (0, img.height)], fill=INK + (225,))
    d.line((10, 0, img.width, 0), fill=VIOLET + (255,), width=2)
    d.text((20 - l, 7 - t_), txt, font=f, fill=(210, 180, 255, 255))
    return img


SUB = make_sub()


# ---------------------------------------------------------------- frame
BEATS = [("crouch", 0.30, 0.80), ("ready", 0.80, 1.30), ("burst", 1.30, 2.45)]
CUTS = [0.80, 1.30]
SLAM = 1.42


def draw_figure(layer, name, t, a0, off, shake, raw=False):
    img, pad = (POSES_RAW if raw else POSES)[name]
    lt = t - a0
    # hit-stop: the beat lands big and holds for two frames, then settles and slowly pushes in
    if lt < 0.1:
        s = 1.10
    else:
        s = 1.0 + 0.10 * (1 - ease_out((lt - 0.1) / 0.14)) + 0.05 * ramp(lt, 0.1, 0.9)
    if name == "crouch":
        s *= 0.9 + 0.1 * ease_out(lt / 0.12)  # first appearance grows in
    sc = FIG_SCALE * s
    fig = img.resize((int(img.width * sc), int(img.height * sc)), Image.LANCZOS)
    inner_w = (img.width - 2 * pad) * sc
    feet_x = off + 330 + (18 * ease_out(lt / 0.5) if name == "burst" else 0)
    feet_y = y_bot(feet_x, off) - 4
    px = int(feet_x - pad * sc - inner_w * FEET_X[name] + shake[0])
    py = int(feet_y - (fig.height - pad * sc) + shake[1])
    paste_any(layer, fig, (px, py))
    # chest point for radial lines
    return (feet_x, feet_y - 0.55 * (img.height - 2 * pad) * sc)


def paste_any(dst, src, pos):
    """alpha_composite that accepts negative offsets."""
    x, y = int(pos[0]), int(pos[1])
    sx, sy = max(0, -x), max(0, -y)
    if sx >= src.width or sy >= src.height:
        return
    dst.alpha_composite(src.crop((sx, sy, src.width, src.height)), (x + sx, y + sy))


def draw_frame(t, k):
    rnd = random.Random(2000 + k)
    f = bg.copy()
    hx, hy = HERO

    # -------- scene dim + vignette while the cut-in is up
    dim = 0.62 * ramp(t, 0.02, 0.22) * (1 - ramp(t, 2.2, 2.55))
    if dim > 0:
        f = Image.alpha_composite(f, Image.new("RGBA", (W, H), (6, 3, 16, int(255 * dim))))
        v = Image.radial_gradient("L").resize((W, H)).point(lambda p: int(p * 1.4 * dim))
        vl = Image.new("RGBA", (W, H), (10, 4, 28, 0))
        vl.putalpha(v)
        f = Image.alpha_composite(f, vl)

    # -------- trigger glint on the hero (right-click)
    if t < 0.25:
        g = 1 - ramp(t, 0.0, 0.25)
        bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        bd = ImageDraw.Draw(bloom)
        r = 10 + 40 * ease_out(t / 0.25)
        bd.ellipse((hx - r, hy - 30 - r, hx + r, hy - 30 + r), outline=VIOLET + (int(230 * g),), width=3)
        bd.line((hx - 50 * g, hy - 30, hx + 50 * g, hy - 30), fill=CREAM + (int(255 * g),), width=2)
        bd.line((hx, hy - 30 - 50 * g, hx, hy - 30 + 50 * g), fill=CREAM + (int(255 * g),), width=2)
        f = Image.alpha_composite(f, bloom.filter(ImageFilter.GaussianBlur(1)))

    # -------- aftermath on the hero (hand-over)
    T_LAND = 2.30
    if t >= T_LAND - 0.05:
        age = t - T_LAND
        on = ramp(age, -0.05, 0.12)
        # the hero (cut out of the screenshot) tints dark violet and gets a violet rim;
        # the aura flames burn BEHIND him so he stays readable
        tint = ImageChops.multiply(f.convert("RGB"), Image.new("RGB", (W, H), (int(255 - 125 * on), int(255 - 150 * on), int(255 - 85 * on)))).convert("RGBA")
        hero_px = tint.copy()
        hero_px.putalpha(HERO_MASK)
        flick = int(t * 14)
        a1 = aura(flick, 84, flip=(flick % 2 == 0), opacity=0.85 * on)
        paste_any(f, a1, (hx - a1.width // 2, hy - a1.height + 8))
        # ring on the ground
        if age >= 0:
            ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            rd = ImageDraw.Draw(ring)
            for i, (delay, col, wdt) in enumerate(((0.0, VIOLET, 5), (0.08, CREAM, 2))):
                aa = age - delay
                if 0 <= aa < 0.55:
                    rad = 12 + 190 * ease_out(aa / 0.55)
                    al = int(240 * (1 - ramp(aa, 0.1, 0.55)))
                    rd.ellipse((hx - rad, hy - rad * 0.36, hx + rad, hy + rad * 0.36), outline=col + (al,), width=wdt)
            f = Image.alpha_composite(f, ring.filter(ImageFilter.GaussianBlur(0.8)))
            # wisps rising from the feet
            rr = random.Random(77)
            for i in range(5):
                st = rr.uniform(0.0, 0.3)
                life = 0.4
                side = -1 if i % 2 == 0 else 1
                wx = hx + side * rr.uniform(18, 30)
                idx, flp = rr.randint(0, 11), rr.random() < 0.5
                if age >= st:
                    p = ((age - st) % life) / life
                    w = aura(idx, int(50 + 20 * p), flip=flp, opacity=0.9 * (1 - p))
                    paste_any(f, w, (wx - w.width // 2, hy - 6 - w.height - 50 * ease_out(p)))
        rim = Image.new("RGBA", (W, H), VIOLET + (0,))
        rim.putalpha(HERO_MASK.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: int(v * on)))
        f = Image.alpha_composite(f, rim)
        f = Image.alpha_composite(f, hero_px)
        # white-violet flash right at the hero
        if 0 <= age < 0.22:
            fl = 1 - ramp(age, 0.0, 0.22)
            bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            bd = ImageDraw.Draw(bloom)
            cy = hy - 32
            r = 26 + 30 * ease_out(ramp(age, -0.05, 0.22))
            bd.ellipse((hx - r, cy - r, hx + r, cy + r), fill=(190, 150, 255, int(150 * fl)))
            soft = bloom.filter(ImageFilter.GaussianBlur(8))
            star = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            sd = ImageDraw.Draw(star)
            L = 40 + 90 * ease_out(ramp(age, -0.05, 0.15))
            th = max(1, int(5 * fl))
            sd.polygon([(hx - L, cy), (hx, cy - th), (hx + L, cy), (hx, cy + th)], fill=(255, 250, 240, int(255 * fl)))
            sd.polygon([(hx, cy - L * 0.7), (hx - th, cy), (hx, cy + L * 0.7), (hx + th, cy)], fill=(255, 250, 240, int(255 * fl)))
            rc = 12 * fl + 2
            sd.ellipse((hx - rc, cy - rc, hx + rc, cy + rc), fill=(255, 250, 240, int(255 * fl)))
            f = Image.alpha_composite(Image.alpha_composite(f, soft), star)

    # -------- the cut-in layer
    slide_in = ease_back(ramp(t, 0.06, 0.30))
    slide_out = ease_in(ramp(t, 2.08, 2.32))
    off = -760 * (1 - slide_in) - 820 * slide_out
    if off <= -740:
        return f.convert("RGB")
    shake = (0, 0)
    if SLAM <= t < SLAM + 0.15:
        amp = 7 * (1 - ramp(t, SLAM, SLAM + 0.15))
        shake = (rnd.uniform(-amp, amp), rnd.uniform(-amp, amp))
    for c in CUTS:
        if c <= t < c + 0.1:
            shake = (rnd.uniform(-4, 4), rnd.uniform(-3, 3))

    poly = banner_poly(off)
    bmask = poly_mask(poly)
    omask = poly_mask(breakout_poly(off))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # which beat
    beat = None
    for name, a0, a1 in BEATS:
        if a0 <= t < a1:
            beat = (name, a0)
    burst = ramp(t, 1.30, 1.36) if beat and beat[0] == "burst" else 0.0
    chest_guess = (off + 330, 230)

    fill = banner_fill(t, k, off, chest_guess, burst)
    layer.paste(fill, (0, 0), bmask)

    # aura flames behind the figure, rising
    if beat:
        fx = off + 330
        o = ramp(t, 0.36, 0.6)
        flick = int(t * 12)
        big = aura(flick, int(250 + 30 * ramp(t, 0.8, 1.4)), flip=(flick % 2 == 1), opacity=0.95 * o)
        bl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        paste_any(bl, big, (fx - big.width // 2, y_bot(fx, off) - big.height + 6))
        # small wisps drifting up the banner
        rr = random.Random(9)
        for i in range(10):
            st = rr.uniform(0, 0.6)
            p = ((t - 0.3 - st) % 0.6) / 0.6
            if t < 0.3 + st:
                continue
            wx = off + rr.uniform(80, 560)
            w = aura(rr.randint(0, 11), int(40 + 30 * rr.random()), flip=rr.random() < 0.5, opacity=0.8 * math.sin(math.pi * p))
            paste_any(bl, w, (wx - w.width // 2, y_bot(wx, off) - w.height - 150 * p))
        bl.putalpha(ImageChops.multiply(bl.getchannel("A"), omask))
        layer = Image.alpha_composite(layer, bl)

    # glowing border (under the figure so it can break the frame)
    edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(edge).line(poly + [poly[0]], fill=VIOLET + (255,), width=12)
    layer = Image.alpha_composite(layer, edge.filter(ImageFilter.GaussianBlur(7)))
    ed = ImageDraw.Draw(layer)
    ed.line(poly + [poly[0]], fill=CREAM + (255,), width=4)
    # inner accent line just under the top edge
    ed.line([(poly[0][0], poly[0][1] + 10), (poly[1][0] - 8, poly[1][1] + 10)], fill=VIOLET + (200,), width=2)

    # figure
    chest = chest_guess
    fl = None
    if beat:
        fl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        chest = draw_figure(fl, beat[0], t, beat[1], off, (0, 0))
        fl.putalpha(ImageChops.multiply(fl.getchannel("A"), omask))
        layer = Image.alpha_composite(layer, fl)

    # sparks
    sp = ImageDraw.Draw(layer)
    rr = random.Random(55)
    for i in range(30):
        st = rr.uniform(0, 1)
        p = ((t * 1.6 + st) % 1.0)
        x = off + rr.uniform(40, 600) - 80 * p
        y = y_bot(x, off) - 20 - 260 * p
        s = rr.choice([2, 2, 3, 4])
        if t > 0.3 and omask.getpixel((int(min(W - 1, max(0, x))), int(min(H - 1, max(0, y))))) and 0 <= x < W:
            sp.rectangle((x, y, x + s, y + s), fill=(CREAM if i % 3 == 0 else (200, 160, 255)) + (int(255 * (1 - p)),))

    # light sweeps
    layer = sweep(layer, t, 0.22, 0.22)
    layer = sweep(layer, t, 1.30, 0.22, 90)

    # beat flashes (bright, two frames)
    # frame 1 of a cut: white banner with the NEW pose as an ink silhouette (fighting-game impact frame);
    # frame 2: the full-colour pose under a fading white veil.
    flash = 0.0
    for c in CUTS:
        if c <= t < c + 0.1:
            flash = 1.0 if t < c + 0.049 else 0.4
    if flash >= 1.0 and fl is not None:
        imp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        imp.paste(Image.new("RGBA", (W, H), (248, 242, 255, 255)), (0, 0), bmask)
        idr = ImageDraw.Draw(imp)
        rr = random.Random(k * 7)
        cx, cy = chest
        for _ in range(36):
            ang = rr.uniform(0, math.tau)
            r0 = rr.uniform(90, 150)
            r1 = r0 + rr.uniform(150, 420)
            idr.line((cx + math.cos(ang) * r0, cy + math.sin(ang) * r0, cx + math.cos(ang) * r1, cy + math.sin(ang) * r1), fill=VIOLET + (rr.randint(120, 220),), width=rr.choice([1, 2, 3]))
        imp.putalpha(ImageChops.multiply(imp.getchannel("A"), bmask))
        rawl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        draw_figure(rawl, beat[0], t, beat[1], off, (0, 0), raw=True)
        sa = rawl.getchannel("A").point(lambda v: 255 if v > 128 else 0)
        sa = sa.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))  # drop the small aura flecks
        sa = ImageChops.multiply(sa, omask)
        sil = Image.new("RGBA", (W, H), INK + (0,))
        sil.putalpha(sa)
        # thin violet outline so the silhouette reads as a shape, not a hole
        ol = Image.new("RGBA", (W, H), VIOLET + (0,))
        ol.putalpha(sa.filter(ImageFilter.MaxFilter(5)))
        imp = Image.alpha_composite(imp, ol)
        imp = Image.alpha_composite(imp, sil)
        ImageDraw.Draw(imp).line(poly + [poly[0]], fill=INK + (255,), width=4)
        layer = imp
    elif flash > 0:
        cl = Image.new("RGBA", (W, H), (245, 238, 255, 0))
        cl.putalpha(ImageChops.multiply(layer.getchannel("A"), Image.new("L", (W, H), int(235 * flash))))
        layer = Image.alpha_composite(layer, cl)

    # title slam
    if t >= SLAM:
        tx = ramp(t, SLAM, SLAM + 0.12)
        size = int(round(56 * (1.0 + 0.45 * (1 - ease_out(tx)))))
        if SLAM + 0.10 <= t < SLAM + 0.15:
            size = 60  # overshoot punch on landing
        glitch = (SLAM + 0.10 <= t < SLAM + 0.20) or (1.85 <= t < 1.9)
        title = make_title(size, glitch_seed=k if glitch else None)
        TX = 250
        cxp, cyp = off + TX, y_bot(off + TX, off) + 22  # title hangs off the bottom edge, below the feet
        tl = (cxp - title.width / 2 + shake[0], cyp - title.height / 2 + shake[1])
        tlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        paste_any(tlay, title if tx >= 1 else with_opacity(title, 0.5 + 0.5 * tx), tl)
        layer = Image.alpha_composite(layer, tlay)
        so = ramp(t, SLAM + 0.12, SLAM + 0.3)
        if so > 0:
            sx = off + TX - SUB.width / 2 + 20 + 40 * (1 - ease_out(so))
            paste_any(layer, with_opacity(SUB, so), (sx, cyp + 30))

    # composite cut-in with shake
    if shake != (0, 0):
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        paste_any(sh, layer, (round(shake[0]), round(shake[1])))
        layer = sh
    f = Image.alpha_composite(f, layer)

    # whole-screen pop on the burst cut
    if 1.30 <= t < 1.349:  # outside the banner only, so the impact silhouette stays crisp
        pop = Image.new("RGBA", (W, H), (200, 170, 255, 0))
        pop.putalpha(ImageChops.invert(omask).point(lambda v: int(v * 0.2)))
        f = Image.alpha_composite(f, pop)
    # hand-over: a violet comet leaves the banner and strikes the hero
    cp = 0.0  # (comet removed: the hero is right under the banner)
    if 0 < cp < 1:
        hx2, hy2 = HERO[0], HERO[1] - 32
        sx0, sy0 = 120, 200
        e = ease_in(cp)
        x1, y1 = sx0 + (hx2 - sx0) * e, sy0 + (hy2 - sy0) * e
        e0 = ease_in(max(0.0, cp - 0.35))
        x0, y0 = sx0 + (hx2 - sx0) * e0, sy0 + (hy2 - sy0) * e0
        cm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(cm)
        cd.line((x0, y0, x1, y1), fill=VIOLET + (230,), width=9)
        cm = cm.filter(ImageFilter.GaussianBlur(4))
        cd = ImageDraw.Draw(cm)
        cd.line((x0, y0, x1, y1), fill=(255, 250, 240, 255), width=3)
        cd.ellipse((x1 - 5, y1 - 5, x1 + 5, y1 + 5), fill=(255, 250, 240, 255))
        f = Image.alpha_composite(f, cm)
    # exit smear
    if 0 < slide_out < 1:
        sm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sm)
        rr = random.Random(k)
        rx = RIGHT_TOP + off
        for _ in range(14):
            y = rr.uniform(100, 360)
            sd.line((rx - 20, y, rx + rr.uniform(80, 300) * (1 - slide_out), y + SLOPE * 100), fill=(200, 165, 255, rr.randint(90, 200)), width=rr.choice([1, 2, 3]))
        f = Image.alpha_composite(f, sm)
    return f.convert("RGB")


def main():
    only = [int(a) for a in sys.argv[1:]]
    if only:
        for kk in only:
            draw_frame(kk / FPS, kk).save(OUT / f"v3_f{kk:02d}.png")
        return 0
    frames = [draw_frame(k / FPS, k) for k in range(N)]
    keys = [2, 6, 10, 16, 17, 20, 26, 27, 30, 31, 38, 43, 45, 47, 57]
    cols = 5
    sheet = Image.new("RGB", (cols * 400, 3 * 225))
    for i, kk in enumerate(keys):
        fr = frames[min(kk, N - 1)].resize((400, 225), Image.LANCZOS)
        ImageDraw.Draw(fr).text((6, 4), f"f{kk} t={kk / FPS:.2f}", fill=(255, 255, 0))
        sheet.paste(fr, ((i % cols) * 400, (i // cols) * 225))
    sheet.save(OUT / "black_form_v3_keyframes.png")
    # one shared palette (built from a montage of sample frames) so unchanged pixels stay identical
    # between frames and the GIF encoder can store only the changed rectangle
    samples = frames[::2]
    mont = Image.new("RGB", (W, H * len(samples)))
    for i, fr in enumerate(samples):
        mont.paste(fr, (0, i * H))
    palimg = mont.quantize(colors=COLORS, method=Image.Quantize.FASTOCTREE)
    pal = [fr.quantize(palette=palimg, dither=Image.Dither.NONE) for fr in frames]
    gif = OUT / "black_form_v3_preview.gif"
    pal[0].save(gif, save_all=True, append_images=pal[1:], duration=int(1000 / FPS), loop=0, optimize=False, disposal=1)
    print("frames", len(frames), "gif bytes", gif.stat().st_size)


if __name__ == "__main__":
    sys.exit(main())
