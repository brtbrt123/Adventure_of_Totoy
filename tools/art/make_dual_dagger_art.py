"""Generate the Dual Dagger weapon and Lightning Form skill reference art (art/reference/dual_dagger/).

Everything is drawn procedurally, pixel by pixel, in the Totoy 36 palette (hard alpha, no gold or red):
  * hero poses are composed from the existing in-game hero frames (art/src/hero2_*), with the baked-in katana
    removed (its blue water_* pixels and the ink crumbs left around them), so Totoy stays the same character;
  * the two daggers are drawn per pose at hand points measured on those frames;
  * lightning (aura, bolts, slash arcs, hit sparks, chain segments) uses the pale blue / white / lilac ramp
    (water_1..6, cream, lilac); gold x,y and red z,A are reserved for combat cues and never used.

Outputs (atlases at 1x game pixels, previews scaled with nearest neighbour):
  concept_v1.png/.json             8 armed poses + the same 8 in lightning form
  weapon_layers_v1.png/.json       per pose: unarmed body, back (far-hand) dagger, front (near-hand) dagger
  lightning_form_layers_v1.png/.json  10 aura frames (back + front rows) and 8 lightning-body poses + afterimages
  slash_trails_v1.png/.json        8 directions x 4 frames of lightning slash, 6 hit sparks, 4 chain bolts
  skill_medallions_v1.png/.json    24px skill medallion + 48px weapon medallion (ring from the existing UI icons)
  preview_contact_dark.png, preview_contact_grass.png, lightning_form_sequence.gif, lightning_form_sequence_strip.png
Run from the project root (deterministic, fixed random seeds):
  python tools/art/make_dual_dagger_art.py
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
OUT = ROOT / "art" / "reference" / "dual_dagger"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)  # gold and red: combat cues only

Grid = list  # list[list[str]]


# ----------------------------------------------------------------------------------------------- grid helpers
def blank(w: int, h: int) -> Grid:
    return [[T] * w for _ in range(h)]


def put(g: Grid, x: int, y: int, c: str) -> None:
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        g[y][x] = c


def get(g: Grid, x: int, y: int) -> str:
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        return g[y][x]
    return T


def paste(dst: Grid, src: Grid, ox: int, oy: int) -> None:
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c != T:
                put(dst, x + ox, y + oy, c)


def copy(g: Grid) -> Grid:
    return [list(r) for r in g]


def to_image(g: Grid) -> Image.Image:
    im = Image.new("RGBA", (len(g[0]), len(g)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T:
                assert c not in FORBIDDEN, f"reserved colour {c}"
                px[x, y] = PAL.by_symbol[c] + (255,)
    return im


def line_pts(x0: float, y0: float, x1: float, y1: float) -> list[tuple[int, int]]:
    """Bresenham between rounded endpoints (pixel-perfect, no doubled corners)."""
    x0, y0, x1, y1 = round(x0), round(y0), round(x1), round(y1)
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return pts


def outline_layer(g: Grid, ink: str = "0", keep: set | None = None) -> None:
    """1px ink edge OUTSIDE opaque pixels (4-neighbour), skipping pixels listed in keep."""
    h, w = len(g), len(g[0])
    add = []
    for y in range(h):
        for x in range(w):
            if g[y][x] != T:
                continue
            if keep and (x, y) in keep:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if get(g, x + dx, y + dy) not in (T, ink):
                    add.append((x, y))
                    break
    for x, y in add:
        g[y][x] = ink


# ------------------------------------------------------------------------------------------- hero frames
BLADE = set("klmn")  # the katana is drawn in the water ramp on hero2 frames; the body never uses it


def load_frame(name: str) -> tuple[Grid, tuple[int, int]]:
    s = artlib.parse_sprite(ROOT / "art" / "src" / f"{name}.txt")
    return [list(r) for r in s.rows], s.anchor


def strip_katana(g: Grid) -> Grid:
    g = copy(g)
    h, w = len(g), len(g[0])

    def body(x: int, y: int) -> bool:
        return 0 <= x < w and 0 <= y < h and g[y][x] not in BLADE and g[y][x] not in (T, "0", "8")

    new = {}
    for y in range(h):
        for x in range(w):
            if g[y][x] not in BLADE:
                continue
            inside = False
            for dx, dy in ((1, 0), (0, 1)):
                a = any(body(x + dx * i, y + dy * i) for i in (1, 2))
                b = any(body(x - dx * i, y - dy * i) for i in (1, 2))
                inside = inside or (a and b)
            if inside:  # the blade crossed in front of the body: fill with the surrounding body colour
                cnt: dict[str, int] = {}
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        if body(x + dx, y + dy):
                            c = g[y + dy][x + dx]
                            cnt[c] = cnt.get(c, 0) + 1
                new[(x, y)] = max(cnt, key=cnt.get) if cnt else "e"
            else:
                new[(x, y)] = T
    for (x, y), c in new.items():
        g[y][x] = c
    for _ in range(4):  # peel the ink line that outlined the blade
        rm = []
        for y in range(h):
            for x in range(w):
                if g[y][x] in "08":
                    n = sum(get(g, x + dx, y + dy) != T for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy)
                    if n <= 2:
                        rm.append((x, y))
        for x, y in rm:
            g[y][x] = T
    return g


CW, CH, AX, AY = 64, 64, 32, 56  # every pose / aura cell: same canvas and feet anchor as fx_black_aura_*
DY = AY - 44  # hand points below were measured on a 64x48 canvas with feet at y=44

# pose -> (source frame, [(hand x, hand y, blade angle deg (0=right, 90=down), layer, curve)], description)
POSES: list[tuple[str, str, list[tuple[int, int, float, str, float]], str]] = [
    ("ready_1", "hero2_idle_right_1", [(26, 31, 115, "front", 0.6), (37, 31, 35, "back", 0.6)], "idle / ready, reverse-grip daggers low"),
    ("ready_2", "hero2_parry_right_1", [(43, 29, -20, "front", -0.6), (34, 30, 55, "back", 0.6)], "battle ready, lead dagger forward"),
    ("slash_1", "hero2_attack1_right_4", [(49, 26, -4, "front", -0.6), (26, 28, 150, "back", 0.6)], "combo 1: lead-hand horizontal cut"),
    ("slash_2", "hero2_attack2_right_4", [(31, 16, -105, "back", 0.7), (42, 29, 25, "front", 0.6)], "combo 2: rear-hand rising cut"),
    ("slash_3", "hero2_attack3_right_4", [(35, 37, 12, "front", 0.6), (37, 29, -35, "back", -0.6)], "combo 3: low twin sweep"),
    ("charge", "hero2_attack1_right_1", [(23, 31, 175, "back", 0.6), (44, 33, 18, "front", 0.6)], "lightning form: crouch / charge"),
    ("blink", "hero2_dash_right_3", [(56, 33, 2, "front", -0.5), (30, 29, 178, "back", 0.5)], "lightning form: blink-dash"),
    ("burst", "hero2_victory_right_3", [(26, 15, -100, "front", 0.7), (39, 32, 60, "back", 0.6)], "lightning form: burst"),
]


def pose_body(src: str) -> Grid:
    g, (ax, ay) = load_frame(src)
    g = strip_katana(g)
    cell = blank(CW, CH)
    paste(cell, g, AX - ax, AY - ay)
    return cell


def dagger_layer(hx: int, hy: int, ang: float, curve: float, length: int = 6) -> Grid:
    """A short twin-dagger blade: dark grip + pommel, small stone guard, pale steel blade, blue edge glint."""
    g = blank(CW, CH)
    hy += DY
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx  # normal (edge side)
    hand = (hx, hy)
    put(g, round(hx - dx * 1.4), round(hy - dy * 1.4), "e")  # pommel past the fist
    gx, gy = round(hx + dx * 1.5), round(hy + dy * 1.5)
    put(g, gx, gy, "g")  # guard
    put(g, round(gx + nx), round(gy + ny), "h")
    put(g, round(gx - nx), round(gy - ny), "f")
    pts = []
    for i in range(length):
        t = 2.5 + i
        u = i / max(1, length - 1)
        off = curve * u * u
        pts.append((round(hx + dx * t + nx * off), round(hy + dy * t + ny * off)))
    seen = []
    for p in pts:
        if p not in seen:
            seen.append(p)
    for i, (x, y) in enumerate(seen):
        put(g, x, y, "p" if i == len(seen) - 1 else "j")
    # blue edge glint: one continuous line along the cutting side (not the tip, not the base)
    for i, (x, y) in enumerate(seen[1:-1], start=1):
        ex, ey = round(x + nx), round(y + ny)
        if get(g, ex, ey) == T and (ex, ey) not in seen:
            put(g, ex, ey, "o")
    outline_layer(g, "0", keep={hand})
    put(g, hx, hy, T)  # the fist stays visible
    return g


def lightning_body(g: Grid, variant: int = 0) -> Grid:
    """Totoy as a body of lightning: his own shading mapped onto the water ramp, a bright rim and a bolt
    running through him (so hair, arms and legs still read)."""
    ramp = {"0": "l", "8": "l", "e": "l", "f": "m", "g": "m", "9": "m", "a": "m", "b": "n", "c": "n", "d": "o",
            "q": "m", "r": "n", "s": "o", "h": "n", "i": "o", "j": "p", "1": "p"}
    h, w = len(g), len(g[0])
    out = blank(w, h)
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T:
                out[y][x] = ramp.get(c, "n")
    for y, row in enumerate(g):  # rim: light comes from the top/front (p), back/bottom edges are paler blue (o)
        for x, c in enumerate(row):
            if c == T:
                continue
            up_or_front = get(g, x, y - 1) == T or get(g, x + 1, y) == T
            if up_or_front:
                out[y][x] = "p"
            elif get(g, x - 1, y) == T or get(g, x, y + 1) == T:
                out[y][x] = "o"
    ys = [y for y in range(h) if any(c != T for c in g[y])]
    if ys:  # an inner bolt from the head down through the body, clipped to the silhouette
        top, bot = ys[0], ys[-1]
        xs_top = [x for x in range(w) if g[top + 2][x] != T] or [w // 2]
        xs_mid = [x for x in range(w) if g[(top + bot) // 2][x] != T] or [w // 2]
        rng = random.Random(77 + variant)
        x0 = sum(xs_top) / len(xs_top)
        x1 = sum(xs_mid) / len(xs_mid)
        pts = bolt_path(x0, top + 3, x1 + rng.uniform(-2, 2), bot - 6, rng, 3, 3)
        cells = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            cells += line_pts(ax, ay, bx, by)
        for x, y in cells:
            if get(g, x, y) != T and out[y][x] not in ("p",):
                out[y][x] = "p" if (x + y) % 3 else "o"
    return out


def charged_body(g: Grid, variant: int = 0) -> Grid:
    """Normal colours, but the top/front edge of the silhouette picks up a sparse pale-blue rim (the charge phase)."""
    out = copy(g)
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T and (get(g, x, y - 1) == T or get(g, x + 1, y) == T) and (x + 2 * y + variant) % 3 == 0:
                out[y][x] = "o" if (x + y) % 2 else "n"
    return out


def afterimage(g: Grid, step: int) -> Grid:
    """Blink afterimage: lightning silhouette in dark blue with scanlines dropped as it fades."""
    out = blank(len(g[0]), len(g))
    for y, row in enumerate(g):
        if step and (y + step) % (4 - step) == 0:
            continue
        for x, c in enumerate(row):
            if c != T:
                out[y][x] = ("m" if step == 0 else "l") if c not in "op" else ("o" if step == 0 else "m")
    return out


# ------------------------------------------------------------------------------------------- lightning
def bolt_path(x0: float, y0: float, x1: float, y1: float, rng: random.Random, jitter: float, depth: int = 4) -> list[tuple[float, float]]:
    pts = [(x0, y0), (x1, y1)]
    j = jitter
    for _ in range(depth):
        nxt = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            mx, my = (ax + bx) / 2, (ay + by) / 2
            l = math.hypot(bx - ax, by - ay) or 1
            px, py = -(by - ay) / l, (bx - ax) / l
            o = rng.uniform(-j, j)
            nxt += [(mx + px * o, my + py * o), (bx, by)]
        pts = nxt
        j *= 0.55
    return pts


def draw_bolt(g: Grid, pts: list[tuple[float, float]], core: str = "p", glow: str = "o", glow_every: int = 2, rng: random.Random | None = None) -> list[tuple[int, int]]:
    cells: list[tuple[int, int]] = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        for p in line_pts(ax, ay, bx, by):
            if not cells or cells[-1] != p:
                cells.append(p)
    for i, (x, y) in enumerate(cells):
        if glow and i % glow_every == 0:
            for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
                if get(g, x + dx, y + dy) == T and (rng is None or rng.random() < 0.35):
                    put(g, x + dx, y + dy, glow)
    for x, y in cells:
        put(g, x, y, core)
    return cells


def aura_frames(n: int = 10) -> tuple[list[Grid], list[Grid]]:
    """Crackling bolts hugging the body. Back row draws behind the hero, front row in front (lower, sparser)."""
    backs, fronts = [], []
    cx, cy, rx, ry = AX, AY - 15, 12, 19
    for k in range(n):
        rng = random.Random(9100 + k)
        back, front = blank(CW, CH), blank(CW, CH)
        nb = 2 if k % 2 else 3
        for b in range(nb):
            a0 = (k * 47 + b * (360 / nb) + rng.uniform(-20, 20)) % 360
            a1 = a0 + rng.choice((-1, 1)) * rng.uniform(40, 75)
            r0, r1 = rng.uniform(0.95, 1.15), rng.uniform(0.95, 1.2)
            x0, y0 = cx + math.cos(math.radians(a0)) * rx * r0, cy + math.sin(math.radians(a0)) * ry * r0
            x1, y1 = cx + math.cos(math.radians(a1)) * rx * r1, cy + math.sin(math.radians(a1)) * ry * r1
            pts = bolt_path(x0, y0, x1, y1, rng, 5, 3)
            core = "p" if b % 2 == 0 else "o"
            draw_bolt(back, pts, core, "n" if core == "p" else "", 3, rng)
            if rng.random() < 0.5:  # a fork
                mx, my = pts[len(pts) // 2]
                fa = math.atan2(my - cy, mx - cx) + rng.uniform(-0.5, 0.5)
                draw_bolt(back, bolt_path(mx, my, mx + math.cos(fa) * 6, my + math.sin(fa) * 6, rng, 2, 2), "o", "", 2)
        for s in range(3):  # stray sparks
            a = rng.uniform(0, 360)
            r = rng.uniform(1.2, 1.45)
            x, y = round(cx + math.cos(math.radians(a)) * rx * r), round(cy + math.sin(math.radians(a)) * ry * r)
            put(back, x, y, "p")
            put(back, x + rng.choice((-1, 1)), y, "v")
        # front: one short bolt across the body plus ground crackle at the feet
        a0 = rng.uniform(100, 260)
        x0, y0 = cx + math.cos(math.radians(a0)) * rx, cy + math.sin(math.radians(a0)) * ry * 0.6
        x1, y1 = cx + rng.uniform(-3, 6), cy + rng.uniform(-6, 10)
        if k % 3 != 2:
            draw_bolt(front, bolt_path(x0, y0, x1, y1, rng, 3, 2), "p", "o", 3, rng)
        gx = AX + rng.randint(-10, 4)
        draw_bolt(front, bolt_path(gx, AY, gx + rng.randint(6, 10), AY - rng.randint(0, 2), rng, 2, 2), "o", "m", 2, rng)
        backs.append(back)
        fronts.append(front)
    return backs, fronts


SW = 64  # slash cell


def slash_frame(theta: float, phase: int, seed: int) -> Grid:
    """A straight-through lightning cut across the target at the cell centre, travelling along theta."""
    rng = random.Random(seed)
    g = blank(SW, SW)
    c = SW / 2
    L, sag = 26, 4.0
    dx, dy = math.cos(theta), math.sin(theta)
    nx, ny = -dy, dx
    span = {0: (-1.0, -0.15), 1: (-1.0, 1.0), 2: (-0.55, 1.0), 3: (-0.1, 1.0)}[phase]
    steps = 120
    body: dict[tuple[int, int], str] = {}
    for i in range(steps + 1):
        u = span[0] + (span[1] - span[0]) * i / steps
        bend = sag * (1 - u * u)
        x, y = c + dx * u * L + nx * bend, c + dy * u * L + ny * bend
        head = (u - span[0]) / (span[1] - span[0])  # 0 tail .. 1 head
        if phase == 0:
            w = 0.6 + 1.6 * head
        elif phase == 1:
            w = 2.4 * (1 - abs(u) ** 2) + 0.4
        elif phase == 2:
            w = 1.4 * (1 - abs(u) ** 2) + 0.2
        else:
            w = 0.8 * (1 - abs(u))
        for o in range(-3, 4):
            if abs(o) > w + 0.01:
                continue
            p = (round(x + nx * o * 0.9), round(y + ny * o * 0.9))
            # the outer (convex) side is the bright leading edge
            col = "p" if o >= w - 1 else ("o" if o >= 0 else "n")
            if phase == 3:
                col = "n" if o >= 0 else "m"
            if phase == 2 and o < 0:
                col = "m"
            prev = body.get(p)
            rank = "pon m l".replace(" ", "")
            if prev is None or rank.index(col) < rank.index(prev):
                body[p] = col
    if phase == 3:  # fragments: break the cut into pieces
        keys = sorted(body, key=lambda p: (p[0] - c) * dx + (p[1] - c) * dy)
        for idx, p in enumerate(keys):
            if (idx // 5) % 2:
                body.pop(p)
    for (x, y), col in body.items():
        put(g, x, y, col)
    if phase in (1, 2):  # a jagged white bolt riding the leading edge
        u0, u1 = max(span[0], -0.85), min(span[1], 0.85)
        edge = []
        for i in range(9):
            u = u0 + (u1 - u0) * i / 8
            bend = sag * (1 - u * u)
            w = (2.4 if phase == 1 else 1.4) * (1 - u * u)
            edge.append((c + dx * u * L + nx * (bend + w + 0.6), c + dy * u * L + ny * (bend + w + 0.6)))
        pts = [edge[0]]
        for a_, b_ in zip(edge, edge[1:]):
            pts += bolt_path(a_[0], a_[1], b_[0], b_[1], rng, 1.4, 1)[1:]
        draw_bolt(g, pts, "p", "", 2)
    # lightning fringe: little forked sparks peeling off the cut
    nsp = {0: 2, 1: 5, 2: 4, 3: 2}[phase]
    for _ in range(nsp):
        u = rng.uniform(max(span[0], -0.8), min(span[1], 0.8))
        bend = sag * (1 - u * u)
        x, y = c + dx * u * L + nx * bend, c + dy * u * L + ny * bend
        side = rng.choice((-1, 1)) if phase else 1
        ang = theta + math.pi + side * rng.uniform(0.35, 0.8)  # sparks trail behind the cut
        ln = rng.uniform(3, 7) if phase < 3 else rng.uniform(2, 4)
        pts = bolt_path(x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln, rng, 1.6, 2)
        draw_bolt(g, pts, "o" if phase < 2 else "n", "", 2)
        ex, ey = pts[-1]
        put(g, round(ex), round(ey), "p" if phase < 3 else "v")
    outline_layer(g, "k")  # thin dark-blue rim so the cut reads on light grass too
    return g


def hit_spark(k: int) -> Grid:
    rng = random.Random(500 + k)
    S = 32
    g = blank(S, S)
    c = S // 2
    if k == 0:
        for d in range(-3, 4):
            put(g, c + d, c, "p")
            put(g, c, c + d, "p")
        for d in (-1, 1):
            put(g, c + d, c + d, "o")
            put(g, c + d, c - d, "o")
        outline_layer(g, "l")
        return g
    radius = {1: 7, 2: 11, 3: 13, 4: 14, 5: 15}[k]
    nb = {1: 5, 2: 6, 3: 6, 4: 5, 5: 4}[k]
    for b in range(nb):
        a = b * 2 * math.pi / nb + rng.uniform(-0.3, 0.3) + k * 0.4
        r0 = {1: 1, 2: 2, 3: 5, 4: 8, 5: 11}[k]
        pts = bolt_path(c + math.cos(a) * r0, c + math.sin(a) * r0, c + math.cos(a) * radius, c + math.sin(a) * radius, rng, 2.5, 2)
        core = "p" if k <= 2 else ("o" if k <= 3 else "n")
        glow = "o" if k <= 2 else ("n" if k == 3 else "")
        if k == 5:
            pts = pts[len(pts) // 2:]
        draw_bolt(g, pts, core, glow, 2, rng)
        if k in (2, 3) and rng.random() < 0.6:
            mx, my = pts[len(pts) // 2]
            fa = a + rng.choice((-1, 1)) * 0.8
            draw_bolt(g, bolt_path(mx, my, mx + math.cos(fa) * 4, my + math.sin(fa) * 4, rng, 1, 1), "o", "", 2)
    if k <= 2:  # white core flash
        r = 2 if k == 1 else 3
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if abs(x) + abs(y) <= r:
                    put(g, c + x, c + y, "p" if abs(x) + abs(y) < r else "o")
    if k == 4:
        for _ in range(6):
            a = rng.uniform(0, 2 * math.pi)
            put(g, round(c + math.cos(a) * 9), round(c + math.sin(a) * 9), "v")
    outline_layer(g, "l" if k <= 3 else "k")
    return g


def chain_segment(k: int) -> Grid:
    """32x16 chain-lightning segment from (0,8) to (31,8); segments join end to end."""
    rng = random.Random(800 + k)
    g = blank(32, 16)
    pts = bolt_path(0, 8, 31, 8, rng, 5, 4)
    pts = [(min(31, max(0, x)), min(13, max(2, y))) for x, y in pts]
    pts[0], pts[-1] = (0, 8), (31, 8)
    draw_bolt(g, pts, "p", "o", 1, rng)
    if k % 2 == 0:
        mx, my = pts[len(pts) // 3]
        draw_bolt(g, bolt_path(mx, my, mx + 6, my + rng.choice((-5, 5)), rng, 1.5, 2), "o", "", 2)
    outline_layer(g, "l")
    for x in (0, 31):  # keep the joint row clean for tiling
        for y in range(16):
            if g[y][x] == "l" and y != 8:
                g[y][x] = T
    return g


# ------------------------------------------------------------------------------------------- medallions
def ring_from(name: str, inner_r: float) -> tuple[Grid, int]:
    s = artlib.parse_sprite(ROOT / "art" / "src" / f"{name}.txt")
    g = [list(r) for r in s.rows]
    n = len(g)
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            if math.hypot(x - c, y - c) < inner_r and g[y][x] != T:
                g[y][x] = "0"
    return g, n


def skill_medallion() -> Grid:
    g, n = ring_from("ui_aspect_gale_cut_1", 8.6)
    # a zig-zag lightning bolt with two crossed dagger glints
    bolt = [(14, 3), (9, 11), (13, 11), (8, 20)]
    tmp = blank(n, n)
    for (ax, ay), (bx, by) in zip(bolt, bolt[1:]):
        for x, y in line_pts(ax, ay, bx, by):
            put(tmp, x, y, "p")
            if get(tmp, x + 1, y) == T:
                put(tmp, x + 1, y, "o")
    for x, y in line_pts(5, 7, 8, 10):
        put(tmp, x, y, "j")
    for x, y in line_pts(18, 13, 15, 16):
        put(tmp, x, y, "j")
    put(tmp, 4, 6, "n")
    put(tmp, 19, 12, "n")
    put(tmp, 16, 6, "v")
    put(tmp, 6, 17, "v")
    paste(g, tmp, 0, 0)
    return g


def _medallion_dagger(n: int, p0: tuple[float, float], p1: tuple[float, float]) -> Grid:
    """A dagger rasterised in its own axis frame: pommel, wrapped grip, stone guard, tapering steel blade with
    a pale-blue cutting edge (+t side) and a darker back."""
    t = blank(n, n)
    L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    dx, dy = (p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L
    nx, ny = -dy, dx
    for y in range(n):
        for x in range(n):
            vx, vy = x + 0.5 - p0[0], y + 0.5 - p0[1]
            sa, ta = vx * dx + vy * dy, vx * nx + vy * ny
            if sa < 0 or sa > L:
                continue
            c = T
            if sa < 2.2:
                c = "h" if abs(ta) < 1.4 else T
            elif sa < 8:
                c = ("b" if int(sa) % 2 else "a") if abs(ta) < 1.3 else T
            elif sa < 9.6:
                c = ("i" if abs(ta) < 3 else "h") if abs(ta) < 4.2 else T
            else:
                hw = 2.3 * min(1.0, (L - sa) / 6.0) + 0.35
                if abs(ta) < hw:
                    if L - sa < 2:
                        c = "p"
                    elif ta > hw - 1.1:
                        c = "o"
                    elif ta < -(hw - 1.1):
                        c = "i"
                    else:
                        c = "j"
            if c != T:
                t[y][x] = c
    outline_layer(t, "0")
    return t


def weapon_medallion() -> Grid:
    g, n = ring_from("ui_weapon_sword_1", 19.5)
    paste(g, _medallion_dagger(n, (35.5, 37.5), (13, 12)), 0, 0)
    paste(g, _medallion_dagger(n, (12.5, 37.5), (35, 12)), 0, 0)
    for x, y, c in [(10, 14, "o"), (11, 15, "p"), (12, 14, "o"), (36, 30, "n"), (37, 29, "o"), (35, 14, "v")]:
        put(g, x, y, c)
    return g


# ------------------------------------------------------------------------------------------- atlas + json
def atlas(cells: list[Grid], cols: int, cw: int, ch: int) -> Image.Image:
    rows = (len(cells) + cols - 1) // cols
    im = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, g in enumerate(cells):
        im.alpha_composite(to_image(g), ((i % cols) * cw, (i // cols) * ch))
    return im


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")


def frame_entries(names: list[str], cols: int, cw: int, ch: int, anchor: tuple[int, int] | None, extra: list[dict] | None = None) -> list[dict]:
    out = []
    for i, n in enumerate(names):
        e = {"name": n, "cell": i, "rect": [(i % cols) * cw, (i // cols) * ch, cw, ch]}
        if anchor is not None:
            e["anchor"] = list(anchor)
        if extra:
            e.update(extra[i])
        out.append(e)
    return out


COMMON = {
    "generator": "tools/art/make_dual_dagger_art.py (procedural, Pillow only, deterministic seeds)",
    "palette": "Totoy 36, hard alpha; no reserved gold x,y or red z,A",
    "scale": "1x game pixels (nearest-neighbour; preview sheets are scaled copies)",
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    bodies = {p: pose_body(src) for p, src, _, _ in POSES}
    backs, fronts, armed, lightning = {}, {}, {}, {}
    for p, src, hands, _ in POSES:
        back, front = blank(CW, CH), blank(CW, CH)
        for hx, hy, ang, layer, curve in hands:
            paste(back if layer == "back" else front, dagger_layer(hx, hy, ang, curve), 0, 0)
        backs[p], fronts[p] = back, front
        g = copy(back)
        paste(g, bodies[p], 0, 0)
        paste(g, front, 0, 0)
        armed[p] = g
        lb = copy(back)
        paste(lb, lightning_body(bodies[p], len(lightning)), 0, 0)
        paste(lb, front, 0, 0)
        lightning[p] = lb
    names = [p for p, _, _, _ in POSES]

    # 1. concept: row 1 armed, row 2 lightning form
    concept = [armed[p] for p in names] + [lightning[p] for p in names]
    atlas(concept, 8, CW, CH).save(OUT / "concept_v1.png")
    write_json(OUT / "concept_v1.json", {
        **COMMON,
        "status": "Concept for human approval; not imported into gameplay",
        "reference": "art/src/hero2_* frames (katana removed) for identity; Black Katana form layout as the convention",
        "layout": "8 columns x 2 rows of 64x64 cells. Row 1: Totoy armed with the twin daggers. Row 2: the same poses in lightning form.",
        "poses": [{"pose": p, "source_frame": src, "description": d} for p, src, _, d in POSES],
        "frames": frame_entries([f"concept_{p}" for p in names] + [f"concept_lightning_{p}" for p in names], 8, CW, CH, (AX, AY)),
        "request": "Dual Dagger weapon; right-click active: Totoy turns into lightning and slashes the enemy from every direction. Damage, timing, cost, cooldown and hit count are owner/core decisions.",
    })

    # 2. weapon layers: rows body / back dagger / front dagger
    wl = [bodies[p] for p in names] + [backs[p] for p in names] + [fronts[p] for p in names]
    atlas(wl, 8, CW, CH).save(OUT / "weapon_layers_v1.png")
    hand_meta = []
    for p, src, hands, _ in POSES:
        hand_meta.append({"source_frame": src, "hands": [{"hand": [hx, hy + DY], "blade_angle_deg": ang, "layer": layer} for hx, hy, ang, layer, _ in hands]})
    wl_names = [f"hero2_unarmed_{p}" for p in names] + [f"wpn_dual_dagger_back_{p}" for p in names] + [f"wpn_dual_dagger_front_{p}" for p in names]
    write_json(OUT / "weapon_layers_v1.json", {
        **COMMON,
        "status": "Reference layers; not imported into gameplay",
        "layout": "8 columns x 3 rows of 64x64 cells, all sharing the feet anchor (32,56). Row 1: the hero body with the katana removed. Row 2: far-hand dagger (draw BEHIND the body). Row 3: near-hand dagger (draw IN FRONT).",
        "draw_order": ["wpn_dual_dagger_back_*", "hero2_unarmed_*", "wpn_dual_dagger_front_*"],
        "angle_convention": "0 deg = right (facing direction), 90 deg = down; mirror the whole stack for left",
        "frames": frame_entries(wl_names, 8, CW, CH, (AX, AY), [hand_meta[i % 8] | {"pose": names[i % 8]} for i in range(24)]),
        "note": "The current hero2_* frames have the katana baked in, so a dual-dagger runtime needs the unarmed body row (or the body frames re-imported without a weapon).",
    })

    # 3. lightning form layers
    ab, af = aura_frames(10)
    lf_bodies = [lightning_body(bodies[p], i) for i, p in enumerate(names)]
    charged = [charged_body(bodies[p], i) for i, p in enumerate(names)]
    after = [afterimage(lightning_body(bodies["blink"]), s) for s in range(3)] + [afterimage(lightning_body(bodies["slash_1"]), s) for s in range(3)]
    lf_cells = ab + af + lf_bodies + [blank(CW, CH)] * 2 + charged + [blank(CW, CH)] * 2 + after
    atlas(lf_cells, 10, CW, CH).save(OUT / "lightning_form_layers_v1.png")
    lf_names = ([f"fx_lightning_aura_back_{i + 1}" for i in range(10)] + [f"fx_lightning_aura_front_{i + 1}" for i in range(10)]
                + [f"hero2_lightning_{p}" for p in names] + ["(empty)", "(empty)"]
                + [f"hero2_charged_{p}" for p in names] + ["(empty)", "(empty)"]
                + [f"fx_lightning_afterimage_blink_{i + 1}" for i in range(3)] + [f"fx_lightning_afterimage_slash_{i + 1}" for i in range(3)])
    write_json(OUT / "lightning_form_layers_v1.json", {
        **COMMON,
        "status": "Reference layers; not imported into gameplay",
        "layout": "10 columns of 64x64 cells, feet anchor (32,56) like fx_black_aura_*. Row 1: aura back (behind hero), row 2: aura front, row 3: lightning-body poses (body only, add the dagger layers on top), row 4: charged poses (normal colours with pale rim light), row 5: afterimages (3 fading steps each for blink and slash_1).",
        "aura_loop": "10 frames, loop at about 60-70 ms per frame; back and front frames with the same number belong together",
        "frames": [f for f in frame_entries(lf_names, 10, CW, CH, (AX, AY)) if f["name"] != "(empty)"],
    })

    # 4. slash trails, hit sparks, chain bolts
    st_cells, st_names = [], []
    dirs = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
    for d, dn in enumerate(dirs):
        for ph in range(4):
            st_cells.append(slash_frame(d * math.pi / 4, ph, 3000 + d * 10 + ph))
            st_names.append(f"fx_lightning_slash_{dn}_{ph + 1}")
    slash_im = atlas(st_cells, 8, SW, SW)
    sparks = [hit_spark(k) for k in range(6)]
    chains = [chain_segment(k) for k in range(4)]
    spark_im = atlas(sparks, 6, 32, 32)
    chain_im = atlas(chains, 4, 32, 16)
    sheet = Image.new("RGBA", (8 * SW, slash_im.height + 32 + 16), (0, 0, 0, 0))
    sheet.alpha_composite(slash_im, (0, 0))
    sheet.alpha_composite(spark_im, (0, slash_im.height))
    sheet.alpha_composite(chain_im, (0, slash_im.height + 32))
    sheet.save(OUT / "slash_trails_v1.png")
    frames = []
    for i, n in enumerate(st_names):
        frames.append({"name": n, "rect": [(i % 8) * SW, (i // 8) * SW, SW, SW], "anchor": [SW // 2, SW // 2], "direction_deg": (i // 4) * 45, "phase": ["lead", "peak", "follow", "fragments"][i % 4]})
    for k in range(6):
        frames.append({"name": f"fx_lightning_hit_{k + 1}", "rect": [k * 32, slash_im.height, 32, 32], "anchor": [16, 16]})
    for k in range(4):
        frames.append({"name": f"fx_lightning_chain_{k + 1}", "rect": [k * 32, slash_im.height + 32, 32, 16], "anchor": [0, 8], "ends": [[0, 8], [31, 8]]})
    write_json(OUT / "slash_trails_v1.json", {
        **COMMON,
        "status": "Reference effects; not imported into gameplay",
        "layout": "Rows 1-4: 8 directions x 4 phases of a 64x64 lightning cut, anchor (32,32) = the point the cut passes through (the target). Each row holds two directions (4 frames each). Then 6 hit sparks (32x32, anchor 16,16) and 4 chain-lightning segments (32x16, enter at (0,8), leave at (31,8); rotate/stretch between two points).",
        "direction_convention": "direction_deg: travel direction of the cut, 0 = east (right), 90 = south (down, screen y), clockwise",
        "timing_suggestion": "lead/peak/follow/fragments at about 33/50/50/66 ms; hit spark 6 frames at about 40 ms",
        "frames": frames,
    })

    # 5. medallions
    sk, wp = skill_medallion(), weapon_medallion()
    med = Image.new("RGBA", (24 + 48, 48), (0, 0, 0, 0))
    med.alpha_composite(to_image(sk), (0, 12))
    med.alpha_composite(to_image(wp), (24, 0))
    med.save(OUT / "skill_medallions_v1.png")
    write_json(OUT / "skill_medallions_v1.json", {
        **COMMON,
        "status": "Reference icons; not imported into gameplay",
        "style": "Ring copied from the existing ui_aspect_gale_cut_1 (24px) and ui_weapon_sword_1 (48px) medallions; new interior drawn here",
        "frames": [
            {"name": "ui_aspect_lightning_form_1", "rect": [0, 12, 24, 24], "anchor": [12, 12], "use": "right-click skill icon"},
            {"name": "ui_weapon_dual_dagger_1", "rect": [24, 0, 48, 48], "use": "weapon slot medallion"},
        ],
    })

    # 6. previews
    make_previews(armed, lightning, ab, af, st_cells, sparks, chains, sk, wp, bodies, backs, fronts, after, charged, names)
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*") if p.suffix in (".png", ".json", ".gif"))))
    return 0


# ------------------------------------------------------------------------------------------- previews
BG_DARK = PAL.by_symbol["0"]
BG_GRASS = PAL.by_symbol["4"]


def labelled_sheet(groups: list[tuple[str, list[Image.Image]]], bg: tuple, zoom: int, cols: int) -> Image.Image:
    rows_out = []
    for title, ims in groups:
        cw = max(i.width for i in ims)
        ch = max(i.height for i in ims)
        n = len(ims)
        c = min(cols, n)
        r = (n + c - 1) // c
        block = Image.new("RGBA", (c * (cw + 2) * zoom, r * (ch + 2) * zoom + 14), bg + (255,))
        d = ImageDraw.Draw(block)
        d.text((4, 2), title, fill=(230, 230, 230, 255))
        for i, im in enumerate(ims):
            big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
            block.alpha_composite(big, ((i % c) * (cw + 2) * zoom, 14 + (i // c) * (ch + 2) * zoom))
        rows_out.append(block)
    W = max(b.width for b in rows_out)
    H = sum(b.height + 6 for b in rows_out)
    sheet = Image.new("RGBA", (W, H), bg + (255,))
    y = 0
    for b in rows_out:
        sheet.alpha_composite(b, (0, y))
        y += b.height + 6
    return sheet


def make_previews(armed, lightning, ab, af, st_cells, sparks, chains, sk, wp, bodies, backs, fronts, after, charged, names) -> None:
    aura_comp = []
    for i in range(len(ab)):
        g = copy(ab[i])
        paste(g, lightning[names[0]], 0, 0) if False else paste(g, lightning_body(bodies["ready_2"], i), 0, 0)
        paste(g, fronts["ready_2"], 0, 0)
        paste(g, af[i], 0, 0)
        aura_comp.append(to_image(g))
    groups = [
        ("Armed poses (ready 1-2, combo 1-3, charge, blink, burst)", [to_image(armed[p]) for p in names]),
        ("Lightning form poses", [to_image(lightning[p]) for p in names]),
        ("Charged (rim light) poses", [to_image(g) for g in charged]),
        ("Aura loop over lightning body (10 frames)", aura_comp),
        ("Lightning slash: 8 directions x lead/peak/follow/fragments", [to_image(g) for g in st_cells]),
        ("Hit sparks (6) and chain segments (4)", [to_image(g) for g in sparks] + [to_image(g) for g in chains]),
        ("Afterimages (blink, slash)", [to_image(g) for g in after]),
        ("Medallions: skill 24px, weapon 48px", [to_image(sk), to_image(wp)]),
    ]
    for tag, bg in (("dark", BG_DARK), ("grass", BG_GRASS)):
        labelled_sheet(groups, bg, 4, 8).convert("RGB").save(OUT / f"preview_contact_{tag}.png")
    make_sequence(armed, lightning, ab, af, st_cells, sparks, chains, bodies, backs, fronts, after, charged, names)


def mirror(g: Grid) -> Grid:
    return [list(reversed(r)) for r in g]


def make_sequence(armed, lightning, ab, af, st_cells, sparks, chains, bodies, backs, fronts, after, charged, names) -> None:
    """Totoy charges, bursts into lightning and blinks to 6 points around the golem, cutting through it each time."""
    W, H = 192, 120
    s = artlib.parse_sprite(ROOT / "art" / "src" / "golem2_idle_1.txt")
    golem = [list(r) for r in s.rows]
    gax, gay = s.anchor
    tx, ty = 128, 78  # golem feet
    tcx, tcy = tx, ty - 20  # golem centre (target of the cuts)
    grass = Image.new("RGBA", (W, H), BG_GRASS + (255,))
    gd = ImageDraw.Draw(grass)
    rng = random.Random(4)
    for _ in range(140):
        x, y = rng.randrange(W), rng.randrange(H)
        gd.point((x, y), fill=PAL.by_symbol[rng.choice("35")] + (255,))

    def frame(layers: list[tuple[Grid, int, int]], ms: int) -> tuple[Image.Image, int]:
        im = grass.copy()
        for g, x, y in layers:
            im.alpha_composite(to_image(g), (x, y))
        return im, ms

    golem_l = (golem, tx - gax, ty - gay)
    start = (52, 92)  # Totoy feet
    out: list[tuple[Image.Image, int]] = []

    def hero(g: Grid, fx: int, fy: int, flip: bool = False) -> tuple[Grid, int, int]:
        gg = mirror(g) if flip else g
        ax = (CW - 1 - AX) if flip else AX
        return gg, fx - ax, fy - AY

    for i in range(4):
        out.append(frame([golem_l, hero(armed["ready_1" if i < 2 else "ready_2"], *start)], 140))
    for i in range(5):  # charge with aura
        g = copy(ab[i])
        paste(g, charged[names.index("charge")], 0, 0)
        paste(g, fronts["charge"], 0, 0)
        if i >= 2:
            paste(g, backs["charge"], 0, 0)
        paste(g, af[i], 0, 0)
        out.append(frame([golem_l, hero(g, *start)], 70))
    g = copy(ab[5])
    paste(g, lightning["burst"], 0, 0)
    paste(g, af[5], 0, 0)
    out.append(frame([golem_l, hero(g, *start), (hit_spark(2), start[0] - 16, start[1] - 36)], 90))
    out.append(frame([golem_l, hero(after[0], *start)], 50))

    # six blink points around the target; the cut travels from the point through the target
    pts = [(-34, 10), (30, -22), (-8, -40), (36, 14), (-36, -26), (10, 26)]
    prev = start
    for n, (ox, oy) in enumerate(pts):
        fx, fy = tcx + ox, tcy + oy + 16
        theta = math.atan2(tcy - (fy - 16), tcx - fx)
        d8 = round(theta / (math.pi / 4)) % 8
        flip = fx > tcx
        pose = ["slash_1", "slash_3", "slash_2"][n % 3]
        # chain bolt from previous position to this one
        chain = blank(W, H)
        draw_bolt(chain, bolt_path(prev[0], prev[1] - 14, fx, fy - 14, random.Random(n), 6, 4), "p", "o", 2, random.Random(n))
        lb = copy(ab[n % 10])
        paste(lb, lightning[pose], 0, 0)
        cut = lambda ph: (st_cells[d8 * 4 + ph], tcx - SW // 2, tcy - SW // 2)  # noqa: E731
        out.append(frame([golem_l, (chain, 0, 0), hero(after[0], *prev)], 33))
        out.append(frame([golem_l, hero(lb, fx, fy, flip), cut(0)], 40))
        out.append(frame([golem_l, hero(lb, fx, fy, flip), cut(1), (sparks[1], tcx - 16, tcy - 16)], 50))
        out.append(frame([golem_l, hero(after[3], fx, fy, flip), cut(2), (sparks[2], tcx - 16, tcy - 16)], 45))
        out.append(frame([golem_l, cut(3), (sparks[3], tcx - 16, tcy - 16)], 40))
        prev = (fx, fy)
    # return and finish
    chain = blank(W, H)
    draw_bolt(chain, bolt_path(prev[0], prev[1] - 14, start[0], start[1] - 14, random.Random(99), 6, 4), "p", "o", 2, random.Random(99))
    out.append(frame([golem_l, (chain, 0, 0), (sparks[4], tcx - 16, tcy - 16)], 50))
    g = copy(ab[7])
    paste(g, lightning["burst"], 0, 0)
    paste(g, af[7], 0, 0)
    out.append(frame([golem_l, hero(g, *start), (sparks[5], tcx - 16, tcy - 16)], 90))
    for i in range(3):
        g = copy(ab[8 + (i % 2)]) if i == 0 else blank(CW, CH)
        paste(g, armed["ready_2"], 0, 0)
        out.append(frame([golem_l, hero(g, *start)], 160))
    Z = 4
    big = [im.convert("RGB").resize((W * Z, H * Z), Image.NEAREST) for im, _ in out]
    big[0].save(OUT / "lightning_form_sequence.gif", save_all=True, append_images=big[1:], duration=[ms for _, ms in out], loop=0, disposal=1)
    # strip: every key frame at 2x, 6 per row
    keys = list(range(0, len(out)))
    cols = 8
    Zs = 2
    strip = Image.new("RGB", (cols * W * Zs, ((len(keys) + cols - 1) // cols) * H * Zs), BG_DARK)
    for i, k in enumerate(keys):
        strip.paste(out[k][0].convert("RGB").resize((W * Zs, H * Zs), Image.NEAREST), ((i % cols) * W * Zs, (i // cols) * H * Zs))
    strip.save(OUT / "lightning_form_sequence_strip.png")


if __name__ == "__main__":
    sys.exit(main())
