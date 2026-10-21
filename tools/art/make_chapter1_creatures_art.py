"""Generate the Chapter 1 creature reference art (art/reference/chapter1_creatures/).

Review art only: nothing here is imported into art/src or wired into the game.

Everything is drawn procedurally, pixel by pixel, in the Totoy 36 palette (hard alpha). Gold x,y and red z,A are
reserved for combat cues (telegraphs, parry diamonds) and never appear in a creature, effect or UI pixel; the colour
language is greens and browns (moss, bark, hide), bone/stone (antlers, tusks, spines), teal glow (Aspect fragments,
spirit light) and lilac (Aspect corruption).

How a frame is built: every creature is a small rig of geometric primitives (ellipses, capsules, polygons) placed by
per-frame pose parameters. Each part is rasterised to a mask, shaded with a 5-step palette ramp from an up-left light
(the shade of a pixel follows the direction of the nearest edges, so any shape gets a rounded bevel), drawn back to
front with a dark contour where it overlaps another part, and finally the whole silhouette gets a 1 px ink outline,
like the Mossbound Colossus. Moss texture flecks are hashed in the part's own coordinates, so they move with the body.

Creatures (all single direction, side view facing right; left is mirrored at runtime around the anchor):
  creature_mossling_*        32x24 cells, anchor (13,22)
  creature_thornback_boar_*  48x32 cells, anchor (22,30)
  creature_glowmoth_*        16x24 cells, anchor (8,23) (ground point under the hovering moth)
  creature_glowmoth_orb_*    16x16 cells, anchor (8,8)  (projectile centre)
  creature_thornback_stag_*  80x64 cells, anchor (36,62)
Effects fx_ch1_* and UI ui_enemy_bar_* / ui_aggro_* are listed in their JSON files.

Run from the project root (deterministic, fixed seeds; Pillow only):
  python tools/art/make_chapter1_creatures_art.py
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
OUT = ROOT / "art" / "reference" / "chapter1_creatures"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)
GENERATOR = "tools/art/make_chapter1_creatures_art.py (procedural, Pillow only, deterministic)"
TICK_MS = 1000.0 / 60.0

Grid = list  # list[list[str]]


# ================================================================================================ grid helpers
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


def mirror(g: Grid) -> Grid:
    return [list(reversed(r)) for r in g]


def to_image(g: Grid) -> Image.Image:
    im = Image.new("RGBA", (len(g[0]), len(g)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T:
                assert c not in FORBIDDEN, f"reserved colour {c}"
                px[x, y] = PAL.by_symbol[c] + (255,)
    return im


def hsh(*v: int) -> int:
    h = 2166136261
    for n in v:
        h = ((h ^ (n & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    return h ^ (h >> 15)


def line_pts(x0: float, y0: float, x1: float, y1: float) -> list[tuple[int, int]]:
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


def outline(g: Grid, ink: str = "0", diag: bool = False) -> None:
    h, w = len(g), len(g[0])
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (-1, 1), (1, -1), (-1, -1)] if diag else [])
    add = []
    for y in range(h):
        for x in range(w):
            if g[y][x] != T:
                continue
            for dx, dy in nb:
                if get(g, x + dx, y + dy) not in (T, ink):
                    add.append((x, y))
                    break
    for x, y in add:
        g[y][x] = ink


RAMPS = ["234567", "89abcd", "efghij", "klmnop", "qrs", "tu"]
LIGHTER = {}
DARKER = {}
for _r in RAMPS:
    for _i, _c in enumerate(_r):
        LIGHTER[_c] = _r[min(_i + 1, len(_r) - 1)]
        DARKER[_c] = _r[max(_i - 1, 0)]
LIGHTER.update({"v": "i", "u": "o", "t": "u", "1": "1", "0": "0"})
DARKER.update({"v": "v", "u": "t", "t": "t", "1": "j", "0": "0", "p": "o"})


def recolour(g: Grid, table: dict, steps: int = 1, keep: str = "0") -> Grid:
    out = copy(g)
    for row in out:
        for x, c in enumerate(row):
            if c != T and c not in keep:
                for _ in range(steps):
                    c = table.get(c, c)
                row[x] = c
    return out


def bbox(g: Grid) -> tuple[int, int, int, int] | None:
    xs = [x for row in g for x, c in enumerate(row) if c != T]
    ys = [y for y, row in enumerate(g) if any(c != T for c in row)]
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


# ================================================================================================ geometry
class Xf:
    """2D affine transform x' = a x + b y + tx, y' = c x + d y + ty."""

    def __init__(self, a: float = 1, b: float = 0, c: float = 0, d: float = 1, tx: float = 0, ty: float = 0) -> None:
        self.a, self.b, self.c, self.d, self.tx, self.ty = a, b, c, d, tx, ty

    @staticmethod
    def rot(deg: float, px: float = 0, py: float = 0) -> "Xf":
        r = math.radians(deg)
        co, si = math.cos(r), math.sin(r)
        return Xf(co, -si, si, co, px - co * px + si * py, py - si * px - co * py)

    @staticmethod
    def move(dx: float, dy: float) -> "Xf":
        return Xf(tx=dx, ty=dy)

    def __mul__(self, o: "Xf") -> "Xf":  # (self * o)(p) = self(o(p))
        return Xf(self.a * o.a + self.b * o.c, self.a * o.b + self.b * o.d,
                  self.c * o.a + self.d * o.c, self.c * o.b + self.d * o.d,
                  self.a * o.tx + self.b * o.ty + self.tx, self.c * o.tx + self.d * o.ty + self.ty)

    def pt(self, x: float, y: float) -> tuple[float, float]:
        return self.a * x + self.b * y + self.tx, self.c * x + self.d * y + self.ty

    @property
    def ang(self) -> float:
        return math.degrees(math.atan2(self.c, self.a))


ID = Xf()


class Pic:
    """A frame under construction: parts are drawn back to front with shading and internal contours."""

    DISK = [(dx, dy) for dy in range(-3, 4) for dx in range(-3, 4) if 0 < dx * dx + dy * dy <= 10]
    LIGHT = (-0.55, -0.83)

    def __init__(self, w: int, h: int) -> None:
        self.w, self.h = w, h
        self.g = blank(w, h)
        self.owner = [[-1] * w for _ in range(h)]
        self.groups: list[str] = []
        self.post: list[tuple[int, int, str]] = []  # glow pixels laid on after the ink outline

    # ---- masks
    def ellipse(self, cx: float, cy: float, rx: float, ry: float, ang: float = 0.0, xf: Xf = ID) -> set:
        cx, cy = xf.pt(cx, cy)
        ang = math.radians(ang + xf.ang)
        co, si = math.cos(ang), math.sin(ang)
        m = set()
        R = max(rx, ry) + 1
        for y in range(int(cy - R) - 1, int(cy + R) + 2):
            for x in range(int(cx - R) - 1, int(cx + R) + 2):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                u, v = dx * co + dy * si, -dx * si + dy * co
                if (u / rx) ** 2 + (v / ry) ** 2 <= 1.0 and 0 <= x < self.w and 0 <= y < self.h:
                    m.add((x, y))
        return m

    def capsule(self, pts: list, radii: list, xf: Xf = ID) -> set:
        P = [xf.pt(*p) for p in pts]
        m = set()
        for i in range(len(P) - 1):
            (x0, y0), (x1, y1) = P[i], P[i + 1]
            r0, r1 = radii[i], radii[i + 1]
            R = max(r0, r1) + 1
            for y in range(int(min(y0, y1) - R) - 1, int(max(y0, y1) + R) + 2):
                for x in range(int(min(x0, x1) - R) - 1, int(max(x0, x1) + R) + 2):
                    px, py = x + 0.5, y + 0.5
                    vx, vy = x1 - x0, y1 - y0
                    L2 = vx * vx + vy * vy
                    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - x0) * vx + (py - y0) * vy) / L2))
                    d = math.hypot(px - (x0 + vx * t), py - (y0 + vy * t))
                    if d <= r0 + (r1 - r0) * t and 0 <= x < self.w and 0 <= y < self.h:
                        m.add((x, y))
        return m

    def poly(self, pts: list, xf: Xf = ID) -> set:
        P = [xf.pt(*p) for p in pts]
        xs = [p[0] for p in P]
        ys = [p[1] for p in P]
        m = set()
        for y in range(max(0, int(min(ys)) - 1), min(self.h, int(max(ys)) + 2)):
            for x in range(max(0, int(min(xs)) - 1), min(self.w, int(max(xs)) + 2)):
                px, py = x + 0.5, y + 0.5
                inside = False
                j = len(P) - 1
                for i in range(len(P)):
                    xi, yi = P[i]
                    xj, yj = P[j]
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                        inside = not inside
                    j = i
                if inside:
                    m.add((x, y))
        return m

    # ---- drawing
    def add(self, mask: set, ramp: str, group: str = "", contour: str | None = "auto", amb: float = 0.35,
            tex: tuple | None = None, flat: bool = False, hi: bool = True) -> set:
        """Draw a shaded part. ramp: 5 symbols dark->light. contour: symbol for the edge against earlier parts of
        other groups ('auto' = ramp[0], None = no contour)."""
        if not mask:
            return mask
        pid = len(self.groups)
        self.groups.append(group or f"_{pid}")
        ys = [p[1] for p in mask]
        cy = (min(ys) + max(ys) + 1) / 2
        hh = max(1.0, (max(ys) - min(ys) + 1) / 2)
        lx, ly = self.LIGHT
        cols = {}
        for (x, y) in mask:
            if flat:
                cols[(x, y)] = ramp[2]
                continue
            vx = vy = 0.0
            for dx, dy in self.DISK:
                if (x + dx, y + dy) not in mask:
                    d2 = dx * dx + dy * dy
                    vx += dx / d2
                    vy += dy / d2
            n = math.hypot(vx, vy)
            s = 0.0 if n == 0 else (vx * lx + vy * ly) / max(n, 1.4) * min(1.0, n / 1.2)
            s -= amb * ((y + 0.5 - cy) / hh)
            if s > 0.72 and hi:
                i = 4
            elif s > 0.22:
                i = 3
            elif s > -0.32:
                i = 2
            elif s > -0.72:
                i = 1
            else:
                i = 0
            if tex is not None:
                seed, ox, oy, dens = tex
                k = hsh(x - round(ox), y - round(oy), seed) % 100
                if k < dens and i > 0:
                    i -= 1
                elif k > 100 - dens * 0.6 and i < 3:
                    i += 1
            cols[(x, y)] = ramp[i]
        cc = ramp[0] if contour == "auto" else contour
        for (x, y), c in cols.items():
            if cc is not None:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (x + dx, y + dy)
                    if q in mask or not (0 <= q[0] < self.w and 0 <= q[1] < self.h):
                        continue
                    o = self.owner[q[1]][q[0]]
                    if o >= 0 and self.groups[o] != self.groups[pid]:
                        c = cc
                        break
            self.g[y][x] = c
            self.owner[y][x] = pid
        return mask

    def fill(self, mask: set, c: str) -> None:
        for x, y in mask:
            self.g[y][x] = c

    def dot(self, x: float, y: float, c: str, xf: Xf = ID) -> None:
        X, Y = xf.pt(x, y)
        put(self.g, int(math.floor(X)), int(math.floor(Y)), c)

    def line(self, x0: float, y0: float, x1: float, y1: float, c: str, xf: Xf = ID) -> list:
        a = xf.pt(x0, y0)
        b = xf.pt(x1, y1)
        pts = line_pts(a[0] - 0.5, a[1] - 0.5, b[0] - 0.5, b[1] - 0.5)
        for x, y in pts:
            put(self.g, x, y, c)
        return pts

    def done(self, ink: str = "0") -> Grid:
        outline(self.g, ink)
        for x, y, c in self.post:
            if get(self.g, x, y) == T:
                put(self.g, x, y, c)
        return self.g


def leaf_pts(bx: float, by: float, ang: float, length: float, width: float) -> list:
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux
    mx, my = bx + ux * length * 0.45, by + uy * length * 0.45
    return [(bx, by), (mx + px * width, my + py * width), (bx + ux * length, by + uy * length),
            (mx - px * width, my - py * width)]


def knee(hip: tuple, foot: tuple, bend: float) -> tuple:
    """Middle joint between hip and foot pushed sideways by bend (px, + = forward / right of the hip->foot line)."""
    mx, my = (hip[0] + foot[0]) / 2, (hip[1] + foot[1]) / 2
    dx, dy = foot[0] - hip[0], foot[1] - hip[1]
    L = math.hypot(dx, dy) or 1
    return mx + dy / L * bend, my - dx / L * bend


def ease(t: float) -> float:
    return t * t * (3 - 2 * t)


# ================================================================================================ MOSSLING
MOSS_W, MOSS_H, MOSS_A = 32, 24, (13, 22)
MOSS_BASE = dict(bx=13.0, by=15.6, rx=6.6, ry=5.7, tilt=0.0, eye="open", crest=0.0, flat=0.0,
                 feet=((10.4, 20.7), (15.2, 20.7)), arm=None, mouth=0, flash=0, jit=0)


def mossling(**kw) -> Grid:
    p = dict(MOSS_BASE, **kw)
    pic = Pic(MOSS_W, MOSS_H)
    bx, by, rx, ry, tilt = p["bx"] + p["jit"], p["by"], p["rx"], p["ry"], p["tilt"]
    body_xf = Xf.rot(tilt, bx, by)
    top = body_xf.pt(bx - 0.6, by - ry + 1.2)
    sway = p["crest"]
    flat = p["flat"]
    # back leaf (behind the body)
    a2 = -128 + sway * 0.6 - flat * 40
    pic.add(pic.poly(leaf_pts(top[0] - 0.5, top[1] + 0.5, a2, 5.2 - flat, 1.7)), "23456", group="leafb")
    # back foot
    f0, f1 = p["feet"]
    pic.add(pic.ellipse(f0[0], f0[1], 2.1, 1.4), "8899a", group="footb")
    # body: a bark-brown little imp under a hood of moss
    body = pic.add(pic.ellipse(bx, by, rx, ry, tilt), "89abc", group="body")
    # face hollow (under the hood edge)
    fx, fy = body_xf.pt(bx + rx * 0.40, by + 0.6)
    pic.add(pic.ellipse(fx, fy, 3.1, 2.5, tilt) & body, "88899", group="face", contour=None, hi=False, amb=0.0)
    # moss hood: the body above a ragged line, with drips hanging over the face and the flanks
    hood = set()
    for (x, y) in body:
        lx, ly = Xf.rot(-tilt, bx, by).pt(x + 0.5, y + 0.5)
        col = int(math.floor(lx - bx + 0.5))
        edge = by + ry * 0.22 + (hsh(col, 3) % 3) * 0.5
        if hsh(col, 11) % 4 == 0:
            edge += 2.0
        if col >= int(rx * 0.40) - 2 and col <= int(rx * 0.40) + 2:  # keep the eyes free
            edge = min(edge, by - 1.6 + (1.0 if col == int(rx * 0.40) else 0))
        if ly < edge:
            hood.add((x, y))
    pic.add(hood, "34567", group="hood", contour="3", tex=(7, bx, by, 18))
    for (x, y) in hood:  # the hood's lower rim is a darker moss line
        if (x, y + 1) in body and (x, y + 1) not in hood:
            pic.g[y][x] = "3"
    # front foot
    pic.add(pic.ellipse(f1[0], f1[1], 2.2, 1.45), "89abc", group="foot")
    ex, ey = int(round(fx - 1.6)), int(round(fy - 1.4))
    eye = p["eye"]
    E = "p"
    if eye == "open":
        for dx in (0, 3):
            put(pic.g, ex + dx, ey, E)
            put(pic.g, ex + dx, ey + 1, E)
    elif eye == "glow":  # gathering: eyes flare
        for dx in (0, 3):
            for dy in (0, 1):
                put(pic.g, ex + dx, ey + dy, "1")
            put(pic.g, ex + dx + 1, ey, "1")
            put(pic.g, ex + dx + 1, ey + 1, "o")
    elif eye == "slit":
        for dx in (0, 3):
            put(pic.g, ex + dx, ey + 1, E)
            put(pic.g, ex + dx + 1, ey + 1, E)
    elif eye == "closed":
        for dx in (0, 3):
            put(pic.g, ex + dx, ey + 1, "6")
            put(pic.g, ex + dx + 1, ey + 1, "6")
    elif eye == "x":
        for dx in (0, 3):
            put(pic.g, ex + dx, ey, "j")
            put(pic.g, ex + dx + 1, ey + 1, "j")
    elif eye == "dim":
        for dx in (0, 3):
            put(pic.g, ex + dx, ey + 1, "t")
    if p["mouth"]:
        mx, my = ex + 1, ey + 3
        for dx in range(3):
            put(pic.g, mx + dx, my, "0")
        if p["mouth"] > 1:
            for dx in range(3):
                put(pic.g, mx + dx, my + 1, "0")
            put(pic.g, mx, my, "j")
            put(pic.g, mx + 2, my, "j")
    # front leaf crest (on top)
    a1 = -72 + sway - flat * 92
    lp = leaf_pts(top[0], top[1] + 0.6, a1, 6.6 - flat * 1.5, 2.0)
    pic.add(pic.poly(lp), "34567", group="leaf")
    pic.line(lp[0][0] + 0.5, lp[0][1], (lp[0][0] + lp[2][0]) / 2 + 0.5, (lp[0][1] + lp[2][1]) / 2, "4")
    # twig arm
    if p["arm"] is not None:
        ang = math.radians(p["arm"])
        ax, ay = body_xf.pt(bx + rx * 0.55, by + ry * 0.45)
        pic.add(pic.capsule([(ax, ay), (ax + math.cos(ang) * 3.2, ay + math.sin(ang) * 3.2)], [0.8, 0.7]), "89abc",
                group="arm")
    g = pic.done()
    for k in range(p.get("dust", 0)):  # kicked-up dirt behind the braced back foot
        put(g, int(f0[0]) - 3 - k, 20 - (k % 2), "d" if k % 2 else "c")
    if p["flash"]:
        g = recolour(g, LIGHTER, p["flash"])
    return g


def mossling_frames() -> dict[str, list[Grid]]:
    F: dict[str, list[Grid]] = {}
    F["idle"] = [mossling(by=15.6 + d, ry=5.7 - d * 0.5, rx=6.6 + d * 0.25, crest=c)
                 for d, c in ((0, 0), (0.4, 5), (0.8, 9), (0.4, 5))]
    hop = [  # by, ry, rx, tilt, crest, feet lift
        (16.4, 4.9, 7.2, 0, -4, 0), (13.6, 6.3, 6.0, -6, 10, 1.5), (11.6, 6.0, 6.2, -3, 16, 3),
        (12.4, 5.9, 6.3, 4, 8, 2.5), (16.6, 4.8, 7.3, 2, -10, 0), (15.6, 5.6, 6.7, 0, 0, 0)]
    F["walk"] = []
    for i, (yy, ry, rx, t, c, lift) in enumerate(hop):
        fx = 1.0 if 1 <= i <= 3 else 0
        F["walk"].append(mossling(by=yy, ry=ry, rx=rx, tilt=t, crest=c,
                                  feet=((10.4 - fx, 20.7 - lift), (15.2 + fx * 0.5, 20.7 - lift))))
    F["attack_tell"] = [
        mossling(bx=12.4, by=16.2, ry=5.1, rx=7.0, tilt=-6, eye="slit", flat=0.45, crest=-6),
        mossling(bx=11.8, by=16.8, ry=4.6, rx=7.5, tilt=-10, eye="glow", flat=0.8, crest=-10, dust=1,
                 feet=((9.4, 20.7), (15.4, 20.7))),
        mossling(bx=11.4, by=17.3, ry=4.2, rx=7.9, tilt=-12, eye="glow", flat=1.0, crest=-14, dust=3,
                 feet=((8.8, 20.7), (15.6, 20.7))),
    ]
    F["attack_lunge"] = [
        mossling(bx=16.0, by=14.2, ry=4.7, rx=8.4, tilt=-10, eye="glow", flat=1.0, mouth=1, arm=-10,
                 feet=((8.6, 18.6), (11.4, 19.4))),
        mossling(bx=18.6, by=14.4, ry=4.3, rx=9.0, tilt=-4, eye="glow", flat=1.0, mouth=2, arm=0,
                 feet=((10.6, 17.8), (13.4, 18.6))),
        mossling(bx=18.2, by=16.2, ry=5.0, rx=7.8, tilt=8, eye="open", flat=0.6, mouth=1, arm=30,
                 feet=((15.0, 20.0), (19.0, 20.7))),
    ]
    F["attack_recover"] = [
        mossling(bx=16.4, by=17.2, ry=4.2, rx=8.0, tilt=10, eye="closed", flat=0.4, crest=14,
                 feet=((13.6, 20.7), (18.4, 20.7))),
        mossling(bx=15.0, by=16.2, ry=5.2, rx=7.0, tilt=-6, eye="x", crest=-12,
                 feet=((12.0, 20.7), (17.0, 20.7))),
        mossling(bx=14.0, by=15.6, ry=5.6, rx=6.7, tilt=2, eye="open", crest=6,
                 feet=((11.2, 20.7), (16.0, 20.7))),
    ]
    F["hurt"] = [
        mossling(bx=11.6, by=15.2, ry=5.9, rx=6.3, tilt=-14, eye="x", crest=-20, flat=0.3, flash=1,
                 feet=((9.4, 20.7), (14.4, 20.7))),
        mossling(bx=12.4, by=15.8, ry=5.5, rx=6.8, tilt=-6, eye="slit", crest=-8,
                 feet=((10.0, 20.7), (14.8, 20.7))),
    ]
    F["death"] = mossling_death()
    F["spawn"] = mossling_spawn()
    return F


def moss_clump(pic: Pic, cx: float, cy: float, rx: float, ry: float, seed: int, ramp: str = "23456") -> None:
    pic.add(pic.ellipse(cx, cy, rx, ry), ramp, group=f"clump{seed}", tex=(seed, cx, cy, 16))


def mossling_death() -> list[Grid]:
    out = [mossling(bx=11.8, by=15.6, ry=5.8, rx=6.4, tilt=-16, eye="x", crest=-24, flat=0.4, flash=1)]
    # 2: the body splits into clumps, the crest pops off
    pic = Pic(MOSS_W, MOSS_H)
    moss_clump(pic, 9.4, 15.6, 3.8, 3.6, 1)
    moss_clump(pic, 15.4, 14.4, 3.6, 3.4, 2)
    moss_clump(pic, 12.6, 19.2, 4.4, 2.6, 3, "89abc")
    pic.add(pic.ellipse(16.4, 15.0, 1.8, 1.6), "88899", group="face", contour=None, hi=False, amb=0)
    put(pic.g, 16, 14, "t")
    put(pic.g, 18, 14, "t")
    pic.add(pic.poly(leaf_pts(12.0, 8.6, -40, 5.6, 1.8)), "34567", group="leaf")
    pic.add(pic.poly(leaf_pts(8.0, 10.0, -150, 4.6, 1.5)), "23456", group="leafb")
    out.append(pic.done())
    # 3: clumps slump to the ground, leaves flutter up
    pic = Pic(MOSS_W, MOSS_H)
    moss_clump(pic, 8.4, 19.0, 3.8, 2.6, 1)
    moss_clump(pic, 16.6, 18.8, 3.6, 2.6, 2)
    moss_clump(pic, 12.4, 20.4, 4.8, 1.8, 3, "89abc")
    pic.add(pic.poly(leaf_pts(14.0, 6.0, -10, 5.2, 1.7)), "34567", group="leaf")
    pic.add(pic.poly(leaf_pts(6.0, 7.6, 160, 4.4, 1.4)), "23456", group="leafb")
    for x, y in ((11, 13), (19, 12), (5, 14)):
        put(pic.g, x, y, "5")
    out.append(pic.done())
    # 4: a soft moss pile, leaves drift down
    pic = Pic(MOSS_W, MOSS_H)
    moss_clump(pic, 12.6, 20.4, 7.0, 1.9, 4)
    moss_clump(pic, 10.4, 19.4, 3.0, 1.6, 5)
    pic.add(pic.poly(leaf_pts(15.0, 11.0, 20, 5.0, 1.7)), "34567", group="leaf")
    pic.add(pic.poly(leaf_pts(5.0, 14.6, 200, 4.2, 1.4)), "23456", group="leafb")
    put(pic.g, 20, 16, "5")
    out.append(pic.done())
    # 5: the pile with the crest leaf resting on top (hold, then remove the entity)
    pic = Pic(MOSS_W, MOSS_H)
    moss_clump(pic, 12.6, 20.6, 6.6, 1.6, 4)
    pic.add(pic.poly(leaf_pts(10.0, 18.4, -8, 5.4, 1.6)), "34567", group="leaf")
    out.append(pic.done())
    return out


def mossling_spawn() -> list[Grid]:
    out = []
    # 1: a moss mound with the leaf tip poking out
    pic = Pic(MOSS_W, MOSS_H)
    pic.add(pic.poly(leaf_pts(12.0, 19.6, -78, 4.0, 1.6)), "34567", group="leaf")
    moss_clump(pic, 13.0, 20.6, 5.6, 1.7, 9)
    out.append(pic.done())
    # 2: the mound bulges, eyes peek
    pic = Pic(MOSS_W, MOSS_H)
    pic.add(pic.poly(leaf_pts(12.4, 16.0, -76, 5.6, 1.9)), "34567", group="leaf")
    moss_clump(pic, 13.0, 19.4, 6.4, 3.0, 9)
    pic.add(pic.ellipse(16.4, 19.2, 2.6, 1.4), "88899", group="face", contour=None, hi=False, amb=0)
    put(pic.g, 15, 19, "p")
    put(pic.g, 18, 19, "p")
    out.append(pic.done())
    # 3: pops up stretched; 4: lands
    out.append(mossling(by=13.4, ry=6.6, rx=5.6, crest=14, feet=((10.8, 19.6), (15.0, 19.6))))
    out.append(mossling(by=16.6, ry=4.8, rx=7.3, crest=-8))
    return out


# ================================================================================================ THORNBACK BOAR
BOAR_W, BOAR_H, BOAR_A = 48, 32, (22, 30)
BOAR_GROUND = 29.4
BOAR_HIPS = {"bf": (-7.5, 3.0), "bn": (-5.0, 4.0), "ff": (6.0, 3.0), "fn": (8.5, 4.0)}  # rel. to body centre


def boar(bx: float = 21.0, by: float = 19.0, lean: float = 0.0, head: float = 0.0, spines: float = 0.0,
         sweep: float = 0.0, feet: dict | None = None, bends: dict | None = None, eye: str = "open",
         mouth: int = 0, flash: int = 0, tail: float = 0.0, quiver: int = 0, moss: float = 0.0,
         squash: float = 0.0, dust: int = 0, lower: float = 0.0, legs: bool = True) -> Grid:
    pic = Pic(BOAR_W, BOAR_H)
    bxf = Xf.rot(lean, bx, by)
    feet = feet or {}
    bends = bends or {}

    def hip(k: str) -> tuple:
        hx, hy = BOAR_HIPS[k]
        return bxf.pt(bx + hx, by + hy)

    def leg(k: str, ramp: str, hoof: str) -> None:
        if not legs:
            return
        h = hip(k)
        f = feet.get(k, (h[0], BOAR_GROUND))
        bend = bends.get(k, 1.0 if k[0] == "f" else -1.2)
        kx, ky = knee(h, (f[0], f[1]), bend)
        pic.add(pic.capsule([h, (kx, ky), (f[0], f[1] - 1.0)], [2.6, 1.7, 1.4]), ramp, group="leg" + k)
        pic.add(pic.ellipse(f[0] + 0.3, f[1] - 0.7, 1.7, 1.0), hoof, group="hoof" + k, contour=None)

    # far legs (darker), behind everything
    leg("bf", "88899", "eeeff")
    leg("ff", "88899", "eeeff")
    # body: rump + shoulder hump
    rx_s = 1.0 + squash
    body = pic.ellipse(bx - 4, by + 0.6 + lower, 9.2 * rx_s, 6.4 - squash * 3, 0, bxf) | \
        pic.ellipse(bx + 3.6, by - 0.6 + lower, 8.4 * rx_s, 7.6 - squash * 3, 0, bxf)
    # back line (top y per column) for spines and the moss mantle
    top: dict[int, int] = {}
    for x, y in body:
        top[x] = min(top.get(x, 99), y)
    # spines behind the body silhouette (their bases are hidden by the body)
    spine_px = []
    n = 9
    for i in range(n):
        t = i / (n - 1)
        lx = bx + 8.0 - t * 18.0
        X, _ = bxf.pt(lx, by)
        col = int(X)
        if col not in top:
            continue
        base = (col + 0.5, top[col] + 1.6)
        hump = 1.0 - abs(t - 0.32) * 0.9
        length = (2.6 + spines * 3.8) * (0.75 + hump * 0.45)
        ang = -90 - (1 - spines) * 62 - sweep * 40 + lean - (t - 0.35) * 48 * (0.4 + spines * 0.6)
        if quiver and i % 2 == quiver % 2:
            ang += 7
        a = math.radians(ang)
        tip = (base[0] + math.cos(a) * length, base[1] + math.sin(a) * length)
        spine_px.append((base, tip))
    for base, tip in spine_px:
        pts = line_pts(base[0] - 0.5, base[1] - 0.5, tip[0] - 0.5, tip[1] - 0.5)
        L = len(pts)
        for j, (x, y) in enumerate(pts):
            c = "9" if j < L * 0.4 else ("b" if j < L - 2 else ("i" if j < L - 1 else "j"))
            put(pic.g, x, y, c)
            if j < L * 0.55:
                put(pic.g, x + 1, y, "8" if j < L * 0.3 else "9")
        pic_owner = len(pic.groups)
    pic.groups.append("spines")
    for y in range(BOAR_H):
        for x in range(BOAR_W):
            if pic.g[y][x] != T and pic.owner[y][x] == -1:
                pic.owner[y][x] = pic_owner
    # tail
    tx, ty = bxf.pt(bx - 13.0, by - 1.5)
    tt = math.radians(-140 + tail)
    pic.add(pic.capsule([(tx + 1.5, ty + 1.0), (tx + math.cos(tt) * 2.5, ty + math.sin(tt) * 2.5)], [0.9, 0.8]),
            "89abc", group="tail")
    pic.add(body, "89abc", group="body", tex=(21, bx, by, 10))
    # bristle mane: darker line along the back
    for x, y in top.items():
        if (x, y) in body and bxf.pt(bx - 10, by)[0] < x < bxf.pt(bx + 9, by)[0]:
            pic.g[y][x] = "9"
    # moss mantle on the shoulders and rump
    mantle = set()
    for x, y in body:
        t = top[x]
        depth = 2.0 + (hsh(x, 5) % 3) * 0.6 + moss * 6
        if hsh(x, 17) % 5 == 0:
            depth += 1.5
        if y < t + depth and (x < bxf.pt(bx - 6, by)[0] or x > bxf.pt(bx - 2, by)[0] or moss > 0):
            mantle.add((x, y))
    pic.add(mantle, "34567", group="moss", contour="3", tex=(22, bx, by, 18))
    # near legs
    leg("bn", "89abc", "eeffg")
    leg("fn", "89abc", "eeffg")
    # head, rotated around the neck
    px_, py_ = bxf.pt(bx + 9.5, by - 1.0)
    hxf = Xf.rot(head + lean, px_, py_) * Xf.move(px_, py_)
    ear = leaf_pts(1.0, -2.6, -150 + (spines * 25), 4.6, 1.5)
    pic.add(pic.poly(ear, hxf), "89abc", group="ear")
    hd = pic.ellipse(3.2, 2.0, 5.0, 4.6, 0, hxf) | pic.capsule([(5.0, 3.0), (9.6, 4.8)], [3.0, 2.3], hxf)
    pic.add(hd, "89abc", group="head")
    pic.add(pic.ellipse(10.4, 4.9, 1.2, 2.1, 0, hxf), "qqqrs", group="nose", contour="a", hi=False)
    # eye and brow
    ex, ey = hxf.pt(4.6, 0.8)
    ex, ey = int(ex), int(ey)
    if eye == "open":
        put(pic.g, ex, ey, "0")
        put(pic.g, ex + 1, ey, "v")
    elif eye == "glow":
        put(pic.g, ex, ey, "v")
        put(pic.g, ex + 1, ey, "1")
        put(pic.g, ex + 1, ey - 1, "v")
    elif eye == "x":
        put(pic.g, ex, ey - 1, "0")
        put(pic.g, ex + 1, ey, "0")
        put(pic.g, ex, ey + 1, "0")
    elif eye == "closed":
        put(pic.g, ex, ey, "8")
        put(pic.g, ex + 1, ey, "8")
    elif eye == "dizzy":
        put(pic.g, ex, ey, "v")
        put(pic.g, ex + 1, ey - 1, "0")
        put(pic.g, ex + 1, ey + 1, "0")
    bx0, by0 = hxf.pt(3.0, -0.4)
    put(pic.g, int(bx0), int(by0), "8")
    put(pic.g, int(bx0) + 1, int(by0), "8")
    put(pic.g, int(bx0) + 2, int(by0) + 1, "8")
    # mouth line and tusk
    for x, y in pic.line(6.2, 6.0, 9.6, 6.2 + mouth, "8", hxf):
        pass
    t0 = hxf.pt(8.0, 6.6 + mouth * 0.5)
    t1 = hxf.pt(9.0, 4.0)
    t2 = hxf.pt(8.0, 2.8)
    for (x, y) in line_pts(t0[0] - 0.5, t0[1] - 0.5, t1[0] - 0.5, t1[1] - 0.5):
        put(pic.g, x, y, "j")
    put(pic.g, int(t2[0]), int(t2[1]), "1")
    put(pic.g, int(t0[0]), int(t0[1]), "i")
    g = pic.done()
    for k in range(dust):
        dx = int(feet.get("fn", hip("fn"))[0]) - 3 - k * 2
        put(g, dx, 28 - (k % 2), "c" if k % 2 == 0 else "d")
        put(g, dx - 1, 27 - (k % 3 == 2), "d")
    if flash:
        g = recolour(g, LIGHTER, flash)
    return g


def boar_frames() -> dict[str, list[Grid]]:
    F: dict[str, list[Grid]] = {}
    H = {k: (21.0 + v[0], BOAR_GROUND) for k, v in BOAR_HIPS.items()}

    def ft(**off) -> dict:
        out = {}
        for k, (x, y) in H.items():
            dx, dy = off.get(k, (0, 0))
            out[k] = (x + dx, y + dy)
        return out

    F["idle"] = [boar(by=19.0 + d, head=h, tail=tl, lower=0) for d, h, tl in
                 ((0, 0, 0), (0.3, 1.5, 10), (0.6, 3, 20), (0.3, 1.5, 10))]
    F["walk"] = []
    for i in range(6):
        ph = i / 6 * 2 * math.pi
        a, b = math.sin(ph), math.sin(ph + math.pi)
        la, lb = max(0.0, math.cos(ph)) * 1.8, max(0.0, math.cos(ph + math.pi)) * 1.8
        F["walk"].append(boar(by=19.0 - abs(math.sin(ph)) * 0.6, head=2 * math.sin(ph * 2), tail=10 * a,
                              feet=ft(fn=(a * 3, -la), bf=(a * 3, -la), ff=(b * 3, -lb), bn=(b * 3, -lb))))
    F["charge_tell"] = [
        boar(head=12, spines=0.45, lean=-3, eye="open", feet=ft(fn=(6.0, -3.0)), bends={"fn": 2.0}),
        boar(head=17, spines=0.85, lean=-2, by=19.6, eye="glow", feet=ft(fn=(-3.5, 0)), dust=2),
        boar(head=19, spines=1.0, lean=-3, by=19.6, eye="glow", feet=ft(fn=(6.0, -3.0)), bends={"fn": 2.0},
             quiver=1),
        boar(head=22, spines=1.0, lean=2, by=20.2, eye="glow", feet=ft(fn=(-3.5, 0), bn=(-1.5, 0)), quiver=2,
             dust=4),
    ]
    gallop = [  # lean, by, front feet dx, back feet dx, lifts
        (4, 18.4, dict(fn=(5, -1.5), ff=(3.5, -2.5), bn=(-5, -1), bf=(-6.5, -2))),
        (0, 17.4, dict(fn=(-1, -3), ff=(-2.5, -3.5), bn=(3, -3), bf=(1.5, -3.5))),
        (-3, 18.6, dict(fn=(2, 0), ff=(0.5, -1), bn=(1, -2), bf=(-1, -2.5))),
        (2, 18.8, dict(fn=(-3, -1), ff=(-4, -1.5), bn=(-3, 0), bf=(-4.5, -0.5))),
    ]
    F["charge_run"] = [boar(lean=ln, by=yy, head=24, spines=1.0, sweep=1.0, eye="glow", feet=ft(**fo), tail=-30)
                       for ln, yy, fo in gallop]
    F["crash_stun"] = [
        boar(lean=8, by=19.6, head=-14, spines=1.0, sweep=-0.6, eye="x", squash=0.12, mouth=1,
             feet=ft(fn=(-2, 0), ff=(-3, 0), bn=(2, -2), bf=(1, -2.5))),
        boar(lean=-6, by=20.6, head=26, spines=0.5, eye="dizzy", feet=ft(bn=(3, 0), bf=(2, 0))),
        boar(lean=-6, by=20.6, head=18, spines=0.4, eye="dizzy", feet=ft(bn=(3, 0), bf=(2, 0))),
    ]
    F["hurt"] = [
        boar(bx=19.8, lean=-6, head=-10, spines=0.9, eye="x", flash=1, feet=ft(fn=(-1, 0), ff=(-1, 0))),
        boar(bx=20.6, lean=-2, head=-3, spines=0.4, eye="closed"),
    ]
    F["death"] = [
        boar(bx=19.8, lean=-8, head=-12, spines=1.0, eye="x", flash=1),
        boar(by=22.0, lean=4, head=8, spines=0.4, eye="closed",
             feet=ft(fn=(-1, -0.5), ff=(-2, -0.5), bn=(2, 0), bf=(1, 0)), bends={"fn": 3.0, "ff": 3.0}),
        boar(by=24.8, lean=2, head=-6, spines=0.1, eye="closed", legs=False,
             feet=ft(fn=(-3, -1.5), ff=(-4, -1.5), bn=(3, -1.5), bf=(2, -1.5)),
             bends={"fn": 3.5, "ff": 3.5, "bn": -3, "bf": -3}),
        boar(by=25.4, lean=2, head=-6, spines=0.0, eye="closed", legs=False, moss=0.5,
             feet=ft(fn=(-3, -1.5), ff=(-4, -1.5), bn=(3, -1.5), bf=(2, -1.5)),
             bends={"fn": 3.5, "ff": 3.5, "bn": -3, "bf": -3}),
        boar_mound(),
    ]
    return F


def boar_mound() -> Grid:
    pic = Pic(BOAR_W, BOAR_H)
    pic.add(pic.ellipse(21, 27.6, 12.5, 3.8), "89abc", group="soil", tex=(31, 21, 27, 12))
    pic.add(pic.ellipse(20, 26.4, 10.0, 3.0), "34567", group="moss", contour="3", tex=(32, 21, 26, 18))
    for x0, h in ((14, 3), (18, 4), (22, 3), (26, 2)):
        for j in range(h):
            put(pic.g, x0 - j, 24 - j, "j" if j == h - 1 else "b")
    put(pic.g, 31, 26, "j")
    put(pic.g, 32, 25, "1")
    pic.add(pic.poly(leaf_pts(9, 26, -150, 3.5, 1.2)), "34567", group="leaf")
    return pic.done()


# ================================================================================================ GLOWMOTH
MOTH_W, MOTH_H, MOTH_A = 16, 24, (8, 23)
GLOW_RAMPS = ["ttttu", "tttuu", "ttuuo", "tuuop", "uoopp"]


def glowmoth(by: float = 10.0, bx: float = 8.0, flap: float = 0.0, abd: float = 90.0, glow: int = 1,
             tilt: float = 0.0, eye: str = "open", flash: int = 0, spark: int = 0, crumple: float = 0.0,
             legs: bool = True, spread: float = 1.0) -> Grid:
    """Seen three-quarter from the front (both wings spread, so it reads at 16 px), head and antennae turned to
    the right. flap: wing angle in degrees above the horizontal (+ = raised); abd: the lantern abdomen's angle
    (90 = hanging straight down, smaller = curled forward to aim)."""
    pic = Pic(MOTH_W, MOTH_H)
    bxf = Xf.rot(tilt, bx, by)
    fore = 1.0 - min(0.25, abs(flap) / 220) if crumple == 0 else 0.55
    fore *= spread

    def wing(side: int, ang: float, length: float, width: float, ramp: str, grp: str, dy: float) -> set:
        rx, ry = bxf.pt(bx + side * 0.6, by + dy)
        a = -ang if side > 0 else 180 + ang
        ar = math.radians(a)
        cx, cy = rx + math.cos(ar) * length * 0.5, ry + math.sin(ar) * length * 0.5
        return pic.add(pic.ellipse(cx, cy, length * 0.55, width, a), ramp, group=grp, contour=None)

    up = flap
    # hind wings (smaller, dark with a teal glow spot) below the fore wings
    hw = {}
    for side in (-1, 1):
        hw[side] = wing(side, up * 0.5 - 42, 4.6, 1.8, "effgh", f"hw{side}", 0.8)
    # fore wings: pale dusty, lilac eye-spots
    fw = {}
    for side in (-1, 1):
        fw[side] = wing(side, up + 14, 7.0 * fore, 2.3 * (0.75 + fore * 0.25), "fhij1", f"fw{side}", -0.8)
    for side in (-1, 1):  # teal dot on each hind wing
        ar = math.radians(-(up * 0.5 - 42) if side > 0 else 180 + up * 0.5 - 42)
        rx, ry = bxf.pt(bx + side * 0.6, by + 0.8)
        x, y = int(rx + math.cos(ar) * 3.0), int(ry + math.sin(ar) * 3.0)
        if (x, y) in hw[side] and get(pic.g, x, y) in "effgh":
            put(pic.g, x, y, "u" if glow >= 3 else "t")
    # abdomen lantern, then the fuzzy thorax and head on top of the wings
    a = math.radians(abd)
    jx, jy = bxf.pt(bx, by + 1.4)
    acx, acy = jx + math.cos(a) * 2.4, jy + math.sin(a) * 2.4
    pic.add(pic.ellipse(acx, acy, 2.6, 1.6, abd), GLOW_RAMPS[max(0, min(4, glow))], group="abd", contour="t")
    pic.add(pic.ellipse(bx, by, 1.3, 2.1, 0, bxf), "efvvi", group="body", contour="0")
    hx, hy = bxf.pt(bx + 0.6, by - 2.6)
    pic.add(pic.ellipse(hx, hy, 1.5, 1.3), "fvvii", group="head", contour="0")
    # eye-spots on the fore wings
    if crumple < 0.5:
        for side in (-1, 1):
            ang = math.radians(-(up + 14)) if side > 0 else math.radians(180 + up + 14)
            rx, ry = bxf.pt(bx + side * 0.6, by - 0.8)
            ex, ey = rx + math.cos(ang) * 7.0 * fore * 0.62, ry + math.sin(ang) * 7.0 * fore * 0.62
            if (int(ex), int(ey)) in fw[side]:
                put(pic.g, int(ex), int(ey), "v")
    # antennae (feathery), the right one in front
    if crumple < 0.8:
        pic.line(hx + 0.5, hy - 1.0, hx + 2.5, hy - 3.4, "h")
        put(pic.g, int(hx + 2.5) - 1, int(hy - 3.4), "h")
        pic.line(hx - 0.6, hy - 1.0, hx - 1.8, hy - 3.0, "g")
    if legs:
        put(pic.g, int(bx) - 1, int(by + 2.0), "0")
        put(pic.g, int(bx) + 1, int(by + 2.0), "0")
    put(pic.g, int(hx + 0.6), int(hy - 0.2), {"open": "p", "glow": "1", "closed": "f", "x": "j"}[eye])
    g = pic.done()
    if spark:
        cx, cy = int(acx), int(acy + 0.5)
        r = 2 + spark
        for dx, dy in ((r, 0), (-r, 0), (0, r), (0, -r)):
            if get(g, cx + dx, cy + dy) == T:
                put(g, cx + dx, cy + dy, "p" if spark >= 2 else "o")
        if spark >= 2:
            q = max(1, r - 2)
            for dx, dy in ((q, q), (-q, q), (q, -q), (-q, -q)):
                if get(g, cx + dx, cy + dy) == T:
                    put(g, cx + dx, cy + dy, "u")
    if flash:
        g = recolour(g, LIGHTER, flash)
    return g


def glowmoth_frames() -> dict[str, list[Grid]]:
    F: dict[str, list[Grid]] = {}
    cyc = [(55, 0), (28, -0.5), (0, -1.0), (-30, -0.5), (-12, 0.3), (25, 0.5)]
    F["flutter"] = [glowmoth(by=10.0 + dy, flap=fl, glow=1 + (i % 3 == 0)) for i, (fl, dy) in enumerate(cyc)]
    F["shot_tell"] = [
        glowmoth(by=9.6, flap=40, abd=75, glow=2, tilt=-3),
        glowmoth(by=9.2, flap=50, abd=58, glow=3, tilt=-5, spark=1, eye="glow", spread=1.1),
        glowmoth(by=9.0, flap=55, abd=45, glow=4, tilt=-6, spark=2, eye="glow", spread=1.15),
        glowmoth(by=9.0, flap=56, abd=40, glow=4, tilt=-6, spark=3, eye="glow", spread=1.15),
    ]
    F["shot_release"] = [  # extra (not requested): the recoil after the orb leaves, before fluttering again
        glowmoth(by=8.6, flap=-35, abd=110, glow=0, tilt=6),
        glowmoth(by=9.6, flap=10, abd=95, glow=1, tilt=2),
    ]
    F["hurt"] = [
        glowmoth(bx=7.0, by=9.4, flap=-40, abd=110, glow=3, tilt=-16, eye="x", flash=1),
        glowmoth(bx=7.6, by=10.0, flap=20, abd=100, glow=1, tilt=-6, eye="closed"),
    ]
    F["death"] = [
        glowmoth(bx=7.4, by=10.6, flap=-45, abd=110, glow=4, tilt=-20, eye="x", flash=1),
        glowmoth(bx=7.6, by=15.6, flap=-50, abd=130, glow=2, tilt=-50, eye="x", crumple=0.6, legs=False),
        moth_fallen(1),
        moth_fallen(2),
    ]
    return F


def moth_fallen(stage: int) -> Grid:
    pic = Pic(MOTH_W, MOTH_H)
    if stage == 1:
        pic.add(pic.ellipse(4.6, 21.4, 3.4, 1.3, -12), "fhij1", group="wl", contour=None)
        pic.add(pic.ellipse(11.4, 21.4, 3.4, 1.3, 12), "fhij1", group="wr", contour=None)
        pic.add(pic.ellipse(8.0, 21.6, 1.8, 1.4), "tttuu", group="abd", contour="t")
        pic.add(pic.ellipse(8.4, 20.2, 1.3, 1.3), "efvvi", group="body", contour="0")
        g = pic.done()
        for x, y, c in ((5, 16, "u"), (9, 14, "o"), (11, 17, "t")):
            put(g, x, y, c)
        return g
    g = blank(MOTH_W, MOTH_H)
    for x, y, c in ((4, 12, "t"), (8, 9, "u"), (11, 13, "t"), (7, 16, "u"), (5, 21, "h"), (10, 21, "g"),
                    (10, 6, "o")):
        put(g, x, y, c)
    return g


ORB = 16


def orb(phase: int) -> Grid:
    g = blank(ORB, ORB)
    c = 7.5
    r_out = [3.2, 3.6, 3.2, 2.9][phase]
    for y in range(ORB):
        for x in range(ORB):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if d <= 1.3:
                put(g, x, y, "1")
            elif d <= 2.2:
                put(g, x, y, "p")
            elif d <= r_out - 0.2:
                put(g, x, y, "o")
            elif d <= r_out + 0.7:
                put(g, x, y, "u")
    # two orbiting motes
    for k in range(2):
        a = math.radians(phase * 90 + k * 180 + 20)
        put(g, int(8 + math.cos(a) * 5.2), int(8 + math.sin(a) * 4.0), "o" if k == 0 else "u")
    outline(g, "t")
    del c
    return g


def orb_pop(k: int) -> Grid:
    g = blank(ORB, ORB)
    rr = [2.6, 4.0, 5.4, 6.6][k]
    for y in range(ORB):
        for x in range(ORB):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            ang = math.degrees(math.atan2(y + 0.5 - 8, x + 0.5 - 8)) % 360
            if k == 0 and d <= 2.0:
                put(g, x, y, "1")
            if abs(d - rr) < 0.7 and (k < 2 or (int(ang // 30) % 2 == 0)):
                put(g, x, y, ["p", "o", "u", "t"][k])
    if k <= 1:
        for x, y in ((8, 8 - 3 - k), (8, 8 + 2 + k), (8 - 3 - k, 8), (8 + 2 + k, 8)):
            put(g, x, y, "p")
    if k >= 2:
        for a in range(0, 360, 60):
            r = rr - 2
            put(g, int(8 + math.cos(math.radians(a + 30)) * r), int(8 + math.sin(math.radians(a + 30)) * r),
                "o" if k == 2 else "t")
    return g


# ================================================================================================ THORNBACK STAG
STAG_W, STAG_H, STAG_A = 96, 64, (36, 62)
STAG_DY = 3.5  # body sits this much lower than the pose tables say (shorter legs)
STAG_GROUND = 61.4
# antler polylines in head-local coordinates (origin = antler base on the skull, x forward, y up = negative)
ANTLER_BEAM = [(0, 0), (-3.0, -4.0), (-5.6, -8.4), (-6.6, -13.0), (-5.0, -17.6)]
ANTLER_TINES = [((-2.6, -3.6), (1.6, -8.4)), ((-5.4, -8.0), (-2.4, -13.4)), ((-6.6, -12.6), (-11.2, -15.4)),
                ((-5.0, -17.6), (-1.8, -20.6)), ((-5.0, -17.6), (-8.4, -21.0))]
FRAGMENT = [(-4.8, -9.6), (-2.2, -11.6), (-2.8, -15.4), (-5.4, -13.2)]  # teal Aspect shard on the front antler


def stag(bx: float = 34.0, by: float = 40.0, lean: float = 0.0, lean_pivot: tuple | None = None,
         neck: float = 0.0, head: float = 0.0, feet: dict | None = None, hocks: dict | None = None,
         eye: str = "glow", mouth: float = 0.0, glow: int = 1, rim: int = 0, flash: int = 0,
         corrupt: bool = True, roots: float = 0.0, root_seed: int = 0, stars: int = -1, freed: bool = False,
         kneel: float = 0.0, motes: int = 0, beacon: int = 0, bends: dict | None = None) -> Grid:
    """Side view facing right. Feet (world coordinates) are given per leg: ff/fn front far/near, bf/bn hind."""
    pic = Pic(STAG_W, STAG_H)
    by += STAG_DY
    pv = lean_pivot or (bx - 9, STAG_GROUND)
    bxf = Xf.rot(lean, *pv)
    feet = feet or {}
    hocks = hocks or {}
    bends = bends or {}
    hips = {"ff": (bx + 9.2, by + 2.5), "fn": (bx + 11.2, by + 3.5), "bf": (bx - 11.7, by + 1.5),
            "bn": (bx - 9.7, by + 2.5)}
    hip_w = {k: bxf.pt(*v) for k, v in hips.items()}
    default_feet = {"ff": (bx + 8.8, STAG_GROUND), "fn": (bx + 11.4, STAG_GROUND),
                    "bf": (bx - 10.8, STAG_GROUND), "bn": (bx - 8.4, STAG_GROUND)}
    HIDE, HIDE_FAR = "89abc", "8899a"

    def leg(k: str, ramp: str) -> None:
        h = hip_w[k]
        f = feet.get(k, default_feet[k])
        if k[0] == "f":
            kx, ky = knee(h, f, bends.get(k, 0.6))
            kx2, ky2 = (kx + f[0]) / 2, (ky + f[1]) / 2
            pts = [h, (kx, ky), (kx2, ky2), (f[0], f[1] - 0.8)]
            rr = [3.0, 1.5, 1.2, 1.1]
        else:
            hk = hocks.get(k, (f[0] - 2.4, f[1] - 7.0))
            st = knee(h, hk, bends.get(k, 2.2))
            pts = [h, st, hk, (f[0], f[1] - 0.8)]
            rr = [3.6, 2.0, 1.3, 1.1]
        pic.add(pic.capsule(pts, rr), ramp, group="leg" + k)
        pic.add(pic.ellipse(f[0] + 0.4, f[1] - 0.6, 1.5, 0.9), "0eeff", group="hoof" + k, contour=None)

    # ---- roots erupting behind the stag (phase two)
    if roots > 0:
        draw_roots(pic, roots, root_seed, behind=True)
    # ---- far legs
    if kneel < 0.99:
        leg("bf", HIDE_FAR)
        leg("ff", HIDE_FAR)
    # ---- neck and head transforms
    nb = bxf.pt(bx + 11.7, by - 3.5)  # neck base
    ntop_local = (bx + 16.2, by - 11.5)
    nxf = Xf.rot(lean + neck, *nb)
    nt = nxf.pt(*Xf.rot(lean, *pv).pt(*ntop_local)) if False else Xf.rot(neck, *nb).pt(*bxf.pt(*ntop_local))
    hxf = Xf.rot(lean + neck + head, *nt) * Xf.move(*nt)
    # ---- back antler (behind the head and neck)
    antler(pic, hxf, (-2.6, -2.4), "ffggh", back=True, glow=glow, rim=rim, freed=freed, beacon=beacon)
    # ---- body
    body = (pic.ellipse(bx, by, 14.6, 7.6, 0, bxf) | pic.ellipse(bx + 10.2, by - 0.6, 7.6, 8.4, 0, bxf) |
            pic.ellipse(bx - 10.2, by - 1.2, 7.6, 7.4, 0, bxf))
    # tail tuft
    tx, ty = bxf.pt(bx - 17.4, by - 5.0)
    pic.add(pic.capsule([(tx + 1.5, ty + 1.5), (tx - 1.2, ty - 1.0)], [1.3, 1.0]), "9abcd", group="tail")
    pic.add(body, HIDE, group="body", tex=(41, bx, by, 8))
    # neck
    neck_m = pic.capsule([nb, nt], [5.6, 3.6])
    pic.add(neck_m, HIDE, group="body")
    # moss mantle over the shoulders, back and the top of the neck, with hanging strands
    top: dict[int, int] = {}
    allm = body | neck_m
    for x, y in allm:
        top[x] = min(top.get(x, 99), y)
    mantle = set()
    rump_x = bxf.pt(bx - 13.5, by)[0]
    for x, y in allm:
        d = 2.6 + (hsh(x, 51) % 3) * 0.7
        if hsh(x, 52) % 4 == 0:
            d += 2.0
        if y < top[x] + d and x > rump_x:
            mantle.add((x, y))
    pic.add(mantle, "34567", group="moss", contour="3", tex=(53, bx, by, 18))
    for x in sorted(top):
        if x <= rump_x or (hsh(x, 54) % 3):
            continue
        ys = [y for (xx, y) in mantle if xx == x]
        if not ys:
            continue
        y0 = max(ys)
        for j in range(1 + hsh(x, 55) % 3):
            if (x, y0 + 1 + j) in allm:
                pic.g[y0 + 1 + j][x] = "3" if j == 0 else "2"
    # corruption veins (lilac) on the shoulder
    if corrupt:
        vx, vy = bxf.pt(bx + 7.0, by - 1.0)
        for i, (dx, dy) in enumerate(((0, 0), (1, 1), (2, 1), (3, 2), (2, 3), (4, 2), (5, 1), (1, 3), (0, 4))):
            if (int(vx) + dx, int(vy) + dy) in body:
                put(pic.g, int(vx) + dx, int(vy) + dy, "v" if i % 3 else "i" if glow >= 3 else "v")
    if freed:
        for x, y in list(mantle):
            if hsh(x, y, 61) % 23 == 0:
                put(pic.g, x, y, "1" if hsh(x, y) % 2 else "o")
    # ---- near legs
    if kneel < 0.99:
        leg("bn", HIDE)
        leg("fn", HIDE)
    # ---- head
    ear = leaf_pts(-1.0, -2.4, -158, 5.4, 1.7)
    pic.add(pic.poly(ear, hxf), "89abc", group="ear")
    skull = pic.ellipse(1.6, -0.4, 3.8, 3.3, 0, hxf) | pic.capsule([(2.6, 0.0), (8.6, 2.6 + mouth * 0.3)],
                                                                     [3.0, 1.9], hxf)
    pic.add(skull, HIDE, group="head")
    if mouth > 0:  # open jaw (roar)
        jaw = pic.capsule([(3.0, 2.2), (7.8, 3.4 + mouth)], [1.6, 1.2], hxf)
        pic.add(jaw, "89abc", group="jaw")
        for (x, y) in pic.line(4.0, 2.4 + mouth * 0.4, 8.2, 2.6 + mouth * 0.6, "0", hxf):
            pass
    nx_, ny_ = hxf.pt(9.4, 2.4)
    put(pic.g, int(nx_), int(ny_), "0")
    put(pic.g, int(nx_) - 1, int(ny_), "e")
    # light muzzle patch
    mx_, my_ = hxf.pt(7.0, 3.4 + mouth * 0.5)
    if get(pic.g, int(mx_), int(my_)) in HIDE:
        put(pic.g, int(mx_), int(my_), "d")
    ex, ey = hxf.pt(2.6, -1.2)
    ex, ey = int(ex), int(ey)
    if eye == "glow":
        put(pic.g, ex, ey, "v")
        put(pic.g, ex + 1, ey, "1" if glow >= 2 else "i")
    elif eye == "calm":
        put(pic.g, ex, ey, "0")
        put(pic.g, ex + 1, ey, "p")
    elif eye == "closed":
        put(pic.g, ex, ey, "8")
        put(pic.g, ex + 1, ey + 1, "8")
    elif eye == "x":
        put(pic.g, ex, ey - 1, "0")
        put(pic.g, ex + 1, ey, "0")
        put(pic.g, ex, ey + 1, "0")
    elif eye == "dizzy":
        put(pic.g, ex, ey, "v")
        put(pic.g, ex + 1, ey + 1, "0")
    # ---- front antler (with the fragment)
    antler(pic, hxf, (0.6, -3.2), "hhij1", back=False, glow=glow, rim=rim, freed=freed, beacon=beacon)
    # ---- roots in front
    if roots > 0:
        draw_roots(pic, roots, root_seed, behind=False)
    g = pic.done()
    # dizzy motes over the head (no gold: pale stone/cream)
    if stars >= 0:
        hx, hy = hxf.pt(0.0, -24.0)
        for k in range(3):
            a = math.radians(stars * 40 + k * 120)
            sx, sy = int(hx + math.cos(a) * 6), int(hy + math.sin(a) * 2)
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                put(g, sx + dx, sy + dy, "1" if (dx, dy) == (0, 0) else "i")
    if motes:
        rng = random.Random(motes * 7 + 3)
        for _ in range(4 + motes * 2):
            x = rng.randint(int(bx) - 12, int(bx) + 14)
            y = rng.randint(int(by) - 22 - motes * 2, int(by) - 4)
            if get(g, x, y) == T:
                put(g, x, y, "v" if rng.random() < 0.6 else "i")
    if flash:
        g = recolour(g, LIGHTER, flash)
    return g


def antler(pic: Pic, hxf: Xf, base: tuple, ramp: str, back: bool, glow: int, rim: int, freed: bool,
           beacon: int) -> None:
    bxo, byo = base
    sc = 0.78 if back else 0.86
    rot = Xf.rot(-12 if back else 0, bxo, byo)

    def P(x: float, y: float) -> tuple:
        return rot.pt(bxo + x * sc, byo + y * sc)

    beam = [P(*p) for p in ANTLER_BEAM]
    m = pic.capsule(beam, [1.7, 1.4, 1.2, 1.0, 0.8], hxf)
    for a, b in ANTLER_TINES:
        m |= pic.capsule([P(*a), P(*b)], [1.0, 0.65], hxf)
    grp = "antlerb" if back else "antler"
    pic.add(m, ramp, group=grp, contour="e" if back else "0", amb=0.0)
    # thorn vines wound around the beam: dark diagonal wraps with a 1 px thorn sticking out
    for i in range(1, 6):
        t = i / 9
        k = min(int(t * (len(beam) - 1)), len(beam) - 2)
        f = t * (len(beam) - 1) - k
        x = beam[k][0] + (beam[k + 1][0] - beam[k][0]) * f
        y = beam[k][1] + (beam[k + 1][1] - beam[k][1]) * f
        X, Y = hxf.pt(x, y)
        c = "3" if i % 3 == 0 else "9"
        put(pic.g, int(X), int(Y), c)
        put(pic.g, int(X) - 1, int(Y) + 1, c)
        if not back and i % 2 == 1:
            put(pic.g, int(X) + (1 if i % 4 == 1 else -2), int(Y) - 1, "8")
    # moss tufts at the forks
    for j, (fx, fy) in enumerate([ANTLER_TINES[0][0], ANTLER_TINES[2][0]]):
        X, Y = hxf.pt(*P(fx, fy))
        pic.add(pic.ellipse(X + 0.2, Y + 0.6, 1.8, 1.2), "34566", group=f"tuft{back}{j}", contour="2")
    # rim glow (charge tell): antler edge pixels turn teal
    if freed and not back:
        rim = 4
    if rim:
        for (x, y) in m:
            if any((x + dx, y + dy) not in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                if rim == 4:  # freed: a soft pale beacon rim on every other edge pixel
                    if (x + y + beacon) % 2 == 0:
                        pic.g[y][x] = "p" if beacon % 2 else "o"
                elif hsh(x, y, rim) % (3 if rim == 1 else 1) == 0:
                    pic.g[y][x] = "u" if rim < 3 else "o"
    if back:
        return
    # the Aspect fragment
    shard = pic.poly([P(*p) for p in FRAGMENT], hxf)
    if freed:
        ramp_s = ["oop11", "op111", "op111", "oop11"][beacon % 4]
    else:
        ramp_s = ["tttuu", "ttuuo", "tuuop", "uoopp"][max(0, min(3, glow))]
    pic.add(shard, ramp_s, group="shard", contour="t" if not freed else "u")
    cx = sum(x for x, _ in shard) / max(1, len(shard))
    cy = sum(y for _, y in shard) / max(1, len(shard))
    lvl = glow if not freed else 2 + (beacon % 2)
    if lvl >= 2:
        r = 3 + (lvl - 2)
        for dx, dy in ((r, 0), (-r, 0), (0, -r), (0, r)):
            X, Y = int(cx + dx), int(cy + dy)
            pic.post.append((X, Y, "p" if freed else "u"))
    if freed:  # soft beacon halo: a broken ring that breathes in and out
        r = 6.5 + [0, 1.0, 1.8, 1.0][beacon % 4]
        for k in range(16):
            a = math.radians(k * 22.5 + beacon * 11)
            X, Y = int(cx + 0.5 + math.cos(a) * r), int(cy + 0.5 + math.sin(a) * r)
            if (k + beacon) % 3 != 0:
                pic.post.append((X, Y, "p" if k % 2 else "o"))
        for dx, dy in ((2, 2), (-2, 2), (2, -2), (-2, -2)):
            pic.post.append((int(cx + dx), int(cy + dy), "o"))


ROOT_SPOTS = [(14, 0.8, -1), (22, 1.0, 1), (31, 0.7, -1), (49, 1.0, 1), (57, 0.8, -1), (64, 0.6, 1)]


def draw_roots(pic: Pic, amount: float, seed: int, behind: bool) -> None:
    """Gnarled roots bursting from the ground around the stag (in-sprite part of the phase-two roar)."""
    for i, (x0, scale, lean) in enumerate(ROOT_SPOTS):
        if (i % 2 == 0) != behind:
            continue
        h = amount * scale * (9 + (hsh(i, seed) % 4))
        if h < 1:
            continue
        sway = lean * (2.0 + (hsh(i, 7) % 3)) * min(1.0, amount)
        pts = [(x0, STAG_GROUND + 1), (x0 + sway * 0.4, STAG_GROUND - h * 0.5), (x0 + sway, STAG_GROUND - h)]
        m = pic.capsule(pts, [2.2, 1.4, 0.6])
        pic.add(m, "889ab" if behind else "89abc", group=f"root{i}")
        if h > 5:
            X, Y = pts[1]
            put(pic.g, int(X + lean * 2), int(Y), "8")
            put(pic.g, int(X + lean * 3), int(Y) - 1, "8")
            put(pic.g, int(X) - 1, int(Y + 2), "4")
            put(pic.g, int(X), int(Y + 2), "5")
    # ground clods
    for i, x0 in enumerate((18, 28, 46, 60)):
        if amount > 0.3 and (i % 2 == 0) == behind:
            put(pic.g, x0, int(STAG_GROUND - 1 - amount * 2), "b")
            put(pic.g, x0 + 1, int(STAG_GROUND - 2 - amount * 3), "a")


def stag_frames() -> dict[str, list[Grid]]:
    F: dict[str, list[Grid]] = {}
    G = STAG_GROUND

    def ft(bx: float = 34.0, **off) -> dict:
        base = {"ff": (bx + 8.8, G), "fn": (bx + 11.4, G), "bf": (bx - 10.8, G), "bn": (bx - 8.4, G)}
        for k, (dx, dy) in off.items():
            base[k] = (base[k][0] + dx, base[k][1] + dy)
        return base

    F["idle"] = [stag(by=40 + d, neck=n, head=h, glow=gl) for d, n, h, gl in
                 ((0, 0, 0, 1), (0.3, -1, 1, 1), (0.6, -2, 2, 2), (0.3, -1, 1, 1))]
    F["walk"] = []
    for i in range(6):
        ph = i / 6 * 2 * math.pi
        a, b = math.sin(ph), math.sin(ph + math.pi)
        la, lb = max(0.0, math.cos(ph)) * 2.6, max(0.0, math.cos(ph + math.pi)) * 2.6
        F["walk"].append(stag(by=40 - abs(math.sin(ph)) * 0.6, neck=2 * math.sin(ph), head=-1,
                              feet=ft(fn=(a * 4, -la), bf=(a * 4, -la), ff=(b * 4, -lb), bn=(b * 4, -lb)),
                              bends={"fn": 0.6 + la, "ff": 0.6 + lb}))
    # gold antler slam: rear up (raise 4), drive the antlers down (slam 3), recover 4
    piv = (24.0, G)
    F["slam_raise"] = [
        stag(lean=-6, lean_pivot=piv, neck=-8, head=-6, glow=2, feet=ft(fn=(1, -2), ff=(0, 0)), bends={"fn": 2}),
        stag(lean=-14, lean_pivot=piv, neck=-18, head=-14, glow=2,
             feet=ft(fn=(-1, -9), ff=(-3, -7)), bends={"fn": 4, "ff": 4}),
        stag(lean=-20, lean_pivot=piv, neck=-26, head=-22, glow=3,
             feet=ft(fn=(-2, -14), ff=(-4, -12)), bends={"fn": 5, "ff": 5}),
        stag(lean=-22, lean_pivot=piv, neck=-28, head=-26, glow=3,
             feet=ft(fn=(-2, -15), ff=(-4, -13)), bends={"fn": 5, "ff": 5}),
    ]
    F["slam_strike"] = [
        stag(lean=4, lean_pivot=piv, neck=42, head=32, glow=3, mouth=0, feet=ft(fn=(3, -3), ff=(1, -2)),
             bends={"fn": 2}),
        stag(lean=8, lean_pivot=piv, by=41.5, neck=75, head=55, glow=3, feet=ft(fn=(4, 0), ff=(2, 0), bn=(1, 0))),
        stag(lean=7, lean_pivot=piv, by=41.5, neck=75, head=55, glow=2, feet=ft(fn=(4, 0), ff=(2, 0), bn=(1, 0))),
    ]
    F["slam_recover"] = [
        stag(lean=5, lean_pivot=piv, by=41, neck=62, head=42, glow=1, feet=ft(fn=(3, 0), ff=(2, 0))),
        stag(lean=3, lean_pivot=piv, by=40.6, neck=34, head=20, glow=1, feet=ft(fn=(2, 0), ff=(1, 0))),
        stag(lean=1, by=40.2, neck=7, head=7, glow=1, feet=ft(fn=(1, 0))),
        stag(neck=2, head=2, glow=1),
    ]
    # red charge: head lowered, antlers forward and glowing (tell 5), run loop 4, crash 3
    F["charge_tell"] = [
        stag(lean=-2, neck=10, head=18, glow=1, rim=1),
        stag(lean=-3, by=40.6, neck=18, head=30, glow=2, rim=1, feet=ft(fn=(5, -4)), bends={"fn": 3}),
        stag(lean=-3, by=41.0, neck=22, head=38, glow=2, rim=2, feet=ft(fn=(-3, 0))),
        stag(lean=-4, by=41.2, neck=24, head=42, glow=3, rim=2, feet=ft(fn=(5, -4)), bends={"fn": 3}),
        stag(lean=-2, by=41.6, neck=26, head=44, glow=3, rim=3, feet=ft(fn=(-3, 0), bn=(-2, 0))),
    ]
    gallop = [
        (3, 39.4, dict(fn=(7, -2), ff=(5, -3), bn=(-6, -1), bf=(-8, -2)), {"fn": 1, "ff": 1}),
        (0, 38.0, dict(fn=(-2, -5), ff=(-4, -6), bn=(4, -4), bf=(2, -5)), {"fn": 4, "ff": 4}),
        (-3, 39.6, dict(fn=(3, 0), ff=(1, -1), bn=(1, -3), bf=(-1, -3.5)), {"fn": 1, "ff": 2}),
        (2, 40.0, dict(fn=(-4, -1), ff=(-6, -2), bn=(-4, 0), bf=(-6, -0.5)), {"fn": 2, "ff": 2}),
    ]
    F["charge_run"] = [stag(lean=ln, by=yy, neck=26, head=44, glow=3, rim=2, feet=ft(**fo), bends=bd)
                       for ln, yy, fo, bd in gallop]
    F["charge_crash"] = [
        stag(lean=6, by=40.5, neck=4, head=-6, glow=3, eye="x", feet=ft(fn=(-3, 0), ff=(-4, 0), bn=(2, -2))),
        stag(lean=-4, by=41.0, neck=18, head=26, glow=1, eye="dizzy", feet=ft(fn=(2, 0), bn=(3, 0)), stars=0),
        stag(lean=-3, by=40.6, neck=12, head=18, glow=1, eye="dizzy", feet=ft(fn=(2, 0), bn=(3, 0)), stars=1),
    ]
    # phase two: roar and roots erupting
    F["phase2_roar"] = [
        stag(lean=-3, neck=-4, head=-6, glow=2, mouth=0.5),
        stag(lean=-8, lean_pivot=piv, neck=-14, head=-22, glow=3, mouth=1.5, roots=0.15, root_seed=1),
        stag(lean=-10, lean_pivot=piv, neck=-18, head=-30, glow=3, mouth=2.5, roots=0.5, root_seed=2,
             feet=ft(fn=(0, -3)), bends={"fn": 3}),
        stag(lean=-10, lean_pivot=piv, neck=-18, head=-32, glow=3, mouth=2.8, roots=0.9, root_seed=3),
        stag(lean=-8, lean_pivot=piv, neck=-14, head=-26, glow=3, mouth=2.2, roots=1.0, root_seed=4),
        stag(lean=-2, neck=-2, head=-6, glow=3, mouth=0.6, roots=0.7, root_seed=5),
    ]
    F["hurt"] = [
        stag(bx=32.6, lean=-4, neck=-8, head=-10, eye="x", glow=2, flash=1),
        stag(bx=33.2, lean=-2, neck=-4, head=-4, eye="closed", glow=1),
        stag(bx=33.8, neck=-1, head=-1, glow=1),
    ]
    F["stagger"] = [
        stag(lean=3, by=42.0, neck=26, head=30, eye="dizzy", glow=0, stars=0,
             feet=ft(fn=(4, 0), ff=(-2, 0), bn=(-3, 0), bf=(2, 0))),
        stag(lean=4, by=42.4, neck=30, head=34, eye="dizzy", glow=0, stars=1,
             feet=ft(fn=(4, 0), ff=(-2, 0), bn=(-3, 0), bf=(2, 0))),
        stag(lean=3, by=42.6, neck=32, head=30, eye="dizzy", glow=0, stars=2,
             feet=ft(fn=(4, 0), ff=(-2, 0), bn=(-3, 0), bf=(2, 0))),
        stag(lean=2, by=42.2, neck=28, head=26, eye="dizzy", glow=0, stars=3,
             feet=ft(fn=(4, 0), ff=(-2, 0), bn=(-3, 0), bf=(2, 0))),
    ]
    kneel_feet = ft(fn=(2, 0), ff=(0, 0))
    F["death"] = [
        stag(bx=32.6, lean=-5, neck=-8, head=-12, eye="x", glow=3, flash=1),
        stag(bx=33.2, lean=3, by=41.4, neck=18, head=20, eye="dizzy", glow=2),
        # front knees buckle
        stag(lean=10, by=44.0, neck=16, head=16, eye="closed", glow=2,
             feet=ft(fn=(3, 0), ff=(1, 0)), bends={"fn": 6, "ff": 6}),
        stag_lying(neck=10, head=10, glow=2, motes=0),
        stag_lying(neck=24, head=0, glow=1, motes=1),
        stag_lying(neck=34, head=-8, glow=1, motes=2),
        stag_lying(neck=40, head=-14, glow=0, motes=3, corrupt=False),
        stag_lying(neck=40, head=-14, glow=0, motes=0, corrupt=False, eye="closed"),
    ]
    del kneel_feet
    F["freed"] = [stag(by=40 + d, neck=-6 + n, head=-6, glow=0, eye="calm", corrupt=False, freed=True, beacon=i)
                  for i, (d, n) in enumerate(((0, 0), (0.3, -1), (0.5, -1.5), (0.3, -1)))]
    return F


def stag_lying(neck: float, head: float, glow: int, motes: int, corrupt: bool = True, eye: str = "closed") -> Grid:
    """Lying down, legs folded under: body low, hooves tucked."""
    G = STAG_GROUND
    feet = {"ff": (45.0, G), "fn": (48.0, G), "bf": (21.0, G), "bn": (25.0, G)}
    hocks = {"bf": (15.0, G - 1.5), "bn": (18.0, G - 1.0)}
    return stag(by=51.5 - STAG_DY, neck=neck, head=head, glow=glow, motes=motes, corrupt=corrupt, eye=eye,
                feet=feet, hocks=hocks, bends={"fn": 5, "ff": 5, "bn": 3, "bf": 3})


# ================================================================================================ EFFECTS
def leaf_puff(k: int) -> Grid:
    """Mossling hit / death puff: leaves and moss bits burst out, then flutter down. 24x24, anchor (12,16)."""
    pic = Pic(24, 24)
    rng = random.Random(101)
    parts = [(i * 51 + rng.uniform(-12, 12), rng.uniform(0.7, 1.0), i % 2 == 0) for i in range(7)]
    if k == 0:
        pic.add(pic.ellipse(12, 15, 3.4, 2.8), "34567", group="core", contour=None)
    for i, (a, sp, leaf) in enumerate(parts):
        r = [3.5, 6.5, 8.5, 9.0, 9.4][k] * sp
        fall = [0, 0, 1.5, 4, 6.5][k]
        x = 12 + math.cos(math.radians(a)) * r
        y = 15 + math.sin(math.radians(a)) * r * 0.7 + fall
        if k == 4 and not leaf:
            continue
        if leaf:
            ang = a + k * 70
            pic.add(pic.poly(leaf_pts(x - 1.5, y, ang, 4.0, 1.4)), "34567" if i % 4 else "45677", group=f"l{i}")
        elif k < 3:
            pic.add(pic.ellipse(x, y, 1.2, 1.0), "23456", group=f"m{i}", contour=None)
        else:
            put(pic.g, int(x), int(y), "3")
    return pic.done("2") if k < 4 else pic.g


def boar_dust(k: int) -> Grid:
    """Dust trail kicked up behind the charging boar's hind feet. 32x16, anchor (28,14); trails to -x."""
    g = blank(32, 16)
    puffs = [(26, 12, 2.0, 0), (20, 11, 2.6, 1), (13, 10, 3.0, 2), (6, 9, 2.6, 3)]
    for px, py, r, age in puffs:
        a = age + k
        if a > 4:
            continue
        rr = r * (0.6 + a * 0.25)
        ramp = ["d", "c", "b", "b", "a"][a]
        for y in range(16):
            for x in range(32):
                d = math.hypot(x + 0.5 - px, (y + 0.5 - py) * 1.3)
                if d <= rr and (a < 3 or hsh(x, y, k) % 3):
                    put(g, x, y, ramp if d > rr * 0.5 else ("d" if a < 2 else ramp))
    return g


def boar_crash(k: int) -> Grid:
    """Crash into an obstacle: impact flash, splinters, pebbles, dust. 40x32, anchor (20,30) = impact point
    at the boar's snout on the ground line."""
    g = blank(40, 32)
    cx, cy = 20, 22
    if k <= 1:
        r = 3 + k * 2
        for i in range(8):
            a = math.radians(i * 45)
            ln = r if i % 2 == 0 else r - 2
            for t in range(1, ln + 1):
                put(g, int(cx + math.cos(a) * t), int(cy + math.sin(a) * t), "1" if t < ln - 1 else "j")
        put(g, cx, cy, "1")
    rng = random.Random(77)
    for i in range(10):
        a = math.radians(rng.uniform(-170, -10))
        sp = rng.uniform(4, 9)
        t = k + 1
        x = cx + math.cos(a) * sp * t * 0.55
        y = cy + math.sin(a) * sp * t * 0.55 + 0.6 * t * t
        if y > 30 or k == 4 and i % 2:
            continue
        c = "b" if i % 3 else ("j" if i % 2 else "9")
        put(g, int(x), int(y), c)
        if i % 3 == 0:
            put(g, int(x) + 1, int(y), "a")
    if k >= 1:
        for px in (cx - 8, cx - 3, cx + 4, cx + 9):
            rr = 1.5 + k * 0.9
            for y in range(32):
                for x in range(40):
                    if math.hypot(x + 0.5 - px, (y + 0.5 - 28) * 1.4) <= rr and hsh(x, y, k) % (2 if k > 2 else 5):
                        put(g, x, y, "d" if k < 3 else "c")
    return g


def moth_trail(k: int) -> Grid:
    """Glowmoth shot trail: drawn behind the orb (orb centre at the anchor (24,4)); 4 shimmer frames. 32x8."""
    g = blank(32, 8)
    for i in range(12):
        x = 22 - i * 2 - (k % 2)
        y = 4 + int(round(math.sin((i + k) * 1.1) * 1.2))
        if hsh(i, k, 5) % 4 == 0 and i > 3:
            continue
        c = "p" if i < 2 else ("o" if i < 5 else ("u" if i < 8 else "t"))
        put(g, x, y, c)
        if i < 4:
            put(g, x - 1, y, "o" if i < 2 else "u")
    return g


def moth_shadow() -> Grid:
    g = blank(16, 8)
    for y in range(8):
        for x in range(16):
            if ((x + 0.5 - 8) / 4.2) ** 2 + ((y + 0.5 - 4) / 1.4) ** 2 <= 1:
                put(g, x, y, "2")
    return g


def root_spike(k: int) -> Grid:
    """Phase-two root spike erupting where the core's warning was. 24x40, anchor (12,36) = spike base on the
    ground. 1 crack, 2 burst, 3 full spike, 4 hold (thorns flare), 5 crumble, 6 rubble."""
    W, H = 24, 40
    pic = Pic(W, H)
    G = 36.0
    hts = [0, 9, 22, 22, 15, 0][k]
    if k == 0 or k == 5:  # ground crack / rubble decal
        g = pic.g
        for x, y, c in ((7, 36, "8"), (8, 35, "8"), (9, 36, "9"), (10, 35, "8"), (11, 36, "8"), (12, 35, "9"),
                        (13, 36, "8"), (14, 37, "8"), (15, 36, "8"), (16, 35, "9")):
            put(g, x, y, c)
        if k == 5:
            for x, y in ((6, 35), (9, 34), (14, 34), (17, 35), (12, 33)):
                put(g, x, y, "b")
                put(g, x + 1, y, "a")
            for x, y in ((8, 31), (15, 30)):
                put(g, x, y, "9")
        else:
            put(g, 11, 34, "c")
            put(g, 13, 33, "d")
        return g
    lean = 1.4
    pts = [(12, G + 1), (12 + lean * 0.4, G - hts * 0.5), (12 + lean, G - hts)]
    m = pic.capsule(pts, [3.4, 2.2, 0.6])
    pic.add(m, "89abc", group="root", tex=(91, 12, 30, 12))
    # thorns along the spike
    for i in range(3, int(hts) - 1, 4):
        y = int(G - i)
        side = 1 if (i // 4) % 2 else -1
        w = 3.4 - 2.8 * i / max(hts, 1)
        x = int(12 + lean * i / max(hts, 1) + side * (w + 0.5))
        put(pic.g, x, y, "9")
        put(pic.g, x + side, y - 1, "j" if k == 3 else "b")
    # moss collar
    if hts > 8:
        pic.add(pic.ellipse(12, G - 2.5, 4.2, 1.6), "34567", group="moss", contour="3")
    if k == 4:  # crumbling: chunks knocked off
        for (x, y) in list(m):
            if hsh(x, y, 4) % 4 == 0 and y < G - 4:
                pic.g[y][x] = T
    g = pic.done()
    if k == 1:  # burst dirt
        for x, y, c in ((5, 32, "b"), (19, 31, "b"), (7, 28, "a"), (17, 27, "c"), (12, 23, "d")):
            put(g, x, y, c)
    if k == 4:
        for x, y, c in ((6, 26, "b"), (18, 24, "a"), (8, 20, "9"), (16, 30, "b")):
            put(g, x, y, c)
    return g


def slam_rubble(k: int) -> Grid:
    """Antler-slam impact: shock line, rubble and dust thrown up. 48x24, anchor (24,22) = impact point."""
    g = blank(48, 24)
    cx, cy = 24, 21
    if k <= 2:  # ground shock line
        w = [6, 12, 18][k]
        for x in range(cx - w, cx + w + 1):
            put(g, x, cy, "j" if abs(x - cx) > w - 3 else "1")
            if k > 0 and abs(x - cx) < w - 2 and hsh(x, k) % 3 == 0:
                put(g, x, cy - 1, "i")
    rng = random.Random(55)
    for i in range(14):
        a = math.radians(rng.uniform(-165, -15))
        sp = rng.uniform(3, 8)
        t = k + 1
        x = cx + math.cos(a) * sp * t * 0.7
        y = cy + math.sin(a) * sp * t * 0.6 + 0.8 * t * t
        if y > 23:
            continue
        c = ["g", "h", "b", "a", "4"][i % 5]
        put(g, int(x), int(y), c)
        if i % 4 == 0:
            put(g, int(x) + 1, int(y), "f" if c in "gh" else "9")
            put(g, int(x), int(y) + 1, "e" if c in "gh" else "8")
    if k >= 1:
        for px in (cx - 12, cx - 5, cx + 5, cx + 12):
            rr = 1.8 + k * 1.0
            for y in range(24):
                for x in range(48):
                    if math.hypot(x + 0.5 - px, (y + 0.5 - 20) * 1.5) <= rr and hsh(x, y, k) % (2 if k > 2 else 6):
                        put(g, x, y, "d" if k < 3 else "c")
    return g


def purify_sparkle(k: int) -> Grid:
    """Purification after the Stag falls: an expanding soft ring and rising motes. 48x48, anchor (24,40);
    8 frames; draw centred on the fragment / stag."""
    g = blank(48, 48)
    cx, cy = 24, 30
    if k < 5:
        r = 3 + k * 4
        for i in range(36):
            a = math.radians(i * 10)
            if (i + k) % 3 == 0 and k > 1:
                continue
            put(g, int(cx + math.cos(a) * r), int(cy + math.sin(a) * r * 0.55), ["1", "p", "o", "u", "t"][k])
    if k < 2:
        for t in range(-3 - k, 4 + k):
            put(g, cx + t, cy, "p")
            put(g, cx, cy + t, "p")
        put(g, cx, cy, "1")
    rng = random.Random(9)
    for i in range(12):
        x = rng.randint(6, 42)
        y0 = rng.randint(24, 40)
        y = y0 - k * 3 - (i % 3)
        if y < 2 or (k > 5 and i % 2):
            continue
        c = "1" if (i + k) % 4 == 0 else ("p" if i % 2 else "o")
        put(g, x, y, c)
        if (i + k) % 4 == 0 and k < 6:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(g, x + dx, y + dy, "o")
    return g


# ================================================================================================ UI
def ui_bar_frame() -> Grid:
    """Generic enemy HP/posture bar frame, 32x8: ink border, stone bevel, teal end caps (like the boss frame);
    inner HP track x 3-28, y 2-3 (2 px), posture track x 6-25, y 5 (1 px)."""
    g = blank(32, 8)
    for y in range(1, 7):
        for x in range(1, 31):
            put(g, x, y, "f")
    for x in range(1, 31):
        put(g, x, 1, "g")
        put(g, x, 6, "e")
    for x in range(3, 29):  # HP track
        put(g, x, 2, "e")
        put(g, x, 3, "e")
    for x in range(6, 26):  # posture track
        put(g, x, 5, "e")
    for x in (1, 30):
        for y in range(2, 6):
            put(g, x, y, "t")
        put(g, x, 2, "u")
    outline(g, "0")
    # trim the 4 outer corners for a rounded look
    for x, y in ((0, 0), (31, 0), (0, 7), (31, 7)):
        put(g, x, y, T)
    for x, y in ((0, 1), (31, 1), (0, 6), (31, 6), (1, 0), (30, 0), (1, 7), (30, 7)):
        put(g, x, y, "0")
    return g


def ui_bar_fill(kind: str) -> Grid:
    """Fill strips (32x8 cells; fills sit at the same rows as the frame's tracks): hp (grass_6 with a pale top
    line, as the boss bar), hp_ghost (recent damage, stone_6), posture (lilac), posture_broken (water_6)."""
    g = blank(32, 8)
    if kind.startswith("hp"):
        top, body = ("1", "7") if kind == "hp" else ("j", "j")
        for x in range(3, 29):
            put(g, x, 2, top)
            put(g, x, 3, body)
    else:
        c = "v" if kind == "posture" else "p"
        for x in range(6, 26):
            put(g, x, 5, c)
    return g


def ui_bar_example(hp: float, ghost: float, posture: float, broken: bool = False) -> Grid:
    g = ui_bar_frame()
    for x in range(3, 29):
        f = (x - 3 + 0.5) / 26
        if f <= hp:
            put(g, x, 2, "1")
            put(g, x, 3, "7")
        elif f <= ghost:
            put(g, x, 2, "j")
            put(g, x, 3, "j")
    for x in range(6, 26):
        if (x - 6 + 0.5) / 20 <= posture:
            put(g, x, 5, "p" if broken else "v")
    return g


AGGRO_8 = [
    "..000...",
    "..0p0...",
    "..0p0...",
    "..0o0...",
    "..0o0...",
    "..000...",
    "..0p0...",
    "..000...",
]


def aggro_16(k: int) -> Grid:
    """'!' aggro mark, 16x16, anchor (8,15) = bottom centre (place above the creature's head).
    1 pop small, 2 overshoot tall, 3 settle, 4 settle with a lilac glint (loop 3-4 or hold 3)."""
    g = blank(16, 16)
    scale = [0.55, 1.15, 1.0, 1.0][k]
    h = int(round(10 * scale))
    w = 3 if k != 0 else 2
    x0 = 8 - (w // 2) - (0 if w == 3 else 0)
    top = 14 - h
    for y in range(top, top + h - 3 if h > 6 else top + h - 2):
        for x in range(x0, x0 + w):
            put(g, x, y, "p" if x == x0 else "o")
    dot_y = top + h - 2 if h > 6 else top + h - 1
    for x in range(x0, x0 + w):
        put(g, x, dot_y, "p" if x == x0 else "o")
        if w == 3:
            put(g, x, dot_y + 1, "o" if x == x0 else "u")
    if w == 3:
        put(g, x0 + 2, top, "u")
    outline(g, "0", diag=True)
    if k == 3:
        put(g, x0 - 2, top + 1, "v")
        put(g, x0 + w + 1, top + 2, "v")
    if k == 1:
        put(g, x0 - 3, top + 2, "p")
        put(g, x0 + w + 2, top + 2, "p")
    return g


# ================================================================================================ debug preview
def debug_sheet(frames: dict[str, list[Grid]], anchor: tuple[int, int], path: Path, zoom: int = 6) -> None:
    rows = list(frames.items())
    cw, ch = len(rows[0][1][0][0]), len(rows[0][1][0])
    ncol = max(len(v) for _, v in rows)
    W = (cw + 2) * ncol * zoom + 120
    H = (ch + 2) * len(rows) * zoom
    im = Image.new("RGBA", (W, H), PAL.by_symbol["4"] + (255,))
    d = ImageDraw.Draw(im)
    for r, (name, fr) in enumerate(rows):
        d.text((4, r * (ch + 2) * zoom + 4), name, fill=(255, 255, 255, 255))
        for c, g in enumerate(fr):
            x0 = 120 + c * (cw + 2) * zoom
            y0 = r * (ch + 2) * zoom
            d.rectangle([x0, y0, x0 + cw * zoom - 1, y0 + ch * zoom - 1], outline=(70, 90, 50, 255))
            im.alpha_composite(to_image(g).resize((cw * zoom, ch * zoom), Image.NEAREST), (x0, y0))
            ax, ay = anchor
            d.rectangle([x0 + ax * zoom, y0 + ay * zoom + zoom - 2, x0 + ax * zoom + zoom - 1,
                         y0 + ay * zoom + zoom - 1], fill=(255, 0, 255, 255))
    im.convert("RGB").save(path)


# ================================================================================================ deliverables
# state -> (ticks per frame at 60 ticks/s, loop, note); 0 = pick the frame from telegraph progress.
MOSS_STATES = {
    "idle": (12, True, "breathing bob, crest sways"),
    "walk": (5, True, "hop cycle: squash, take-off, air, air, land, settle (6 x 5 = 0.5 s per hop)"),
    "attack_tell": (0, False, "GOLD lunge tell: crouches, eyes flare, crest pins back, kicks dirt. Telegraph-"
                              "driven: frame = floor(progress x 3), hold frame 3 until the strike (~8 ticks each)"),
    "attack_lunge": (3, False, "active: stretched leap, mouth open; frames stay near the anchor, the core moves "
                               "the entity"),
    "attack_recover": (8, False, "lands, dazed shake (the punish window), settles"),
    "hurt": (4, False, "flash + recoil, then back"),
    "death": (6, False, "pops (with fx_ch1_leaf_puff), crumbles into moss and leaves; hold 5 then remove"),
    "spawn": (7, False, "emerges from a moss mound"),
}
BOAR_STATES = {
    "idle": (14, True, "breathing, tail flick, spines lie flat"),
    "walk": (6, True, "4-leg trot"),
    "charge_tell": (0, False, "RED charge tell: head down, paws the ground twice (dust), spines rise and quiver, "
                              "eye glows. Telegraph-driven over the windup (~10 ticks each)"),
    "charge_run": (3, True, "gallop loop, spines swept back; draw fx_ch1_boar_dust behind the hind feet"),
    "crash_stun": (10, False, "1 = impact (draw fx_ch1_boar_crash at the snout), 2-3 dazed: loop 2-3 while "
                              "stunned (the punish window)"),
    "hurt": (4, False, "flash + flinch"),
    "death": (8, False, "flinch, legs buckle, lies down, moss grows over it, a mossy mound remains"),
}
MOTH_STATES = {
    "flutter": (4, True, "wing-beat loop; bob it on its own while hovering"),
    "shot_tell": (0, False, "charge-a-shot tell: wings lift, the lantern abdomen curls forward and brightens "
                            "(sparkles). Telegraph-driven (~9 ticks each); the red warning ring is presentation's"),
    "shot_release": (5, False, "EXTRA: recoil after the orb leaves, then back to flutter"),
    "hurt": (4, False, "flash + tumble"),
    "death": (8, False, "flash, falls, heap on the ground, glowing motes; remove after 4"),
    "orb": (4, True, "projectile loop (16x16, anchor = centre); draw fx_ch1_moth_trail behind it"),
    "orb_pop": (3, False, "projectile hits or expires"),
}
STAG_STATES = {
    "idle": (14, True, "breathing; the antler fragment pulses"),
    "walk": (6, True, "stately walk"),
    "slam_raise": (0, False, "GOLD antler-slam windup: rears up, antlers back. Telegraph-driven, hold 4"),
    "slam_strike": (4, False, "drives the antlers into the ground (draw fx_ch1_stag_slam_rubble at the antler "
                              "tips from frame 2)"),
    "slam_recover": (8, False, "pulls the antlers free, stands"),
    "charge_tell": (0, False, "RED charge tell: head lowered, paws, antlers glow teal at the rim. "
                              "Telegraph-driven over 5 frames, hold 5"),
    "charge_run": (3, True, "gallop loop, antlers forward and glowing"),
    "charge_crash": (10, False, "1 = impact, 2-3 dazed (loop 2-3 while stunned)"),
    "phase2_roar": (8, False, "phase-two transition: rears, roars, roots burst from the ground around it; "
                              "spawn fx_ch1_root_spike where the core puts its spikes"),
    "hurt": (4, False, "flash + recoil"),
    "stagger": (10, True, "posture broken: head low, legs splayed, dizzy motes circle; loop"),
    "death": (9, False, "defeat (not a kill): stumbles, kneels, lies down; lilac corruption motes leave the body; "
                        "eyes close. Then play fx_ch1_purify_sparkle and switch to freed"),
    "freed": (14, True, "purified: calm eye, flowers in the moss, the front antler and fragment glow a soft "
                        "pale beacon colour, no lilac veins"),
}
FX_INFO = {
    "fx_ch1_leaf_puff": (24, 24, (12, 16), 4, "Mossling hit/death: leaves and moss burst out and flutter down"),
    "fx_ch1_boar_dust": (32, 16, (28, 14), 4, "dust trail behind the charging boar's hind feet (trails to -x); "
                                              "spawn one every ~6 ticks, each plays 1-4"),
    "fx_ch1_boar_crash": (40, 32, (20, 30), 4, "boar hits an obstacle: impact star (cream), splinters, pebbles, "
                                               "dust. Anchor = snout on the ground line"),
    "fx_ch1_moth_trail": (32, 8, (24, 4), 3, "glowmoth shot trail, drawn behind the orb; loop 1-4"),
    "fx_ch1_moth_shadow": (16, 8, (8, 4), 1, "optional ground shadow under the hovering glowmoth (grass_1)"),
    "fx_ch1_root_spike": (24, 40, (12, 36), 5, "Stag phase 2: crack, burst, spike, hold (thorns flare), "
                                               "crumble, rubble. The red warning is drawn by presentation"),
    "fx_ch1_stag_slam_rubble": (48, 24, (24, 22), 4, "antler-slam impact: shock line, rubble, dust"),
    "fx_ch1_purify_sparkle": (48, 48, (24, 40), 6, "purification ring and rising motes after the Stag's defeat"),
}


def creature_sets() -> list[dict]:
    return [
        dict(id="mossling", name="Mossling", cell=(MOSS_W, MOSS_H), anchor=MOSS_A, frames=mossling_frames(),
             states=MOSS_STATES),
        dict(id="thornback_boar", name="Thornback Boar", cell=(BOAR_W, BOAR_H), anchor=BOAR_A,
             frames=boar_frames(), states=BOAR_STATES),
        dict(id="glowmoth", name="Glowmoth", cell=(MOTH_W, MOTH_H), anchor=MOTH_A, frames=glowmoth_frames(),
             states=MOTH_STATES,
             extra=dict(cell=(ORB, ORB), anchor=(8, 8), frames={"orb": [orb(i) for i in range(4)],
                                                                  "orb_pop": [orb_pop(i) for i in range(4)]})),
        dict(id="thornback_stag", name="Thornback Stag", cell=(STAG_W, STAG_H), anchor=STAG_A,
             frames=stag_frames(), states=STAG_STATES),
    ]


def fx_sets() -> dict[str, list[Grid]]:
    return {
        "fx_ch1_leaf_puff": [leaf_puff(i) for i in range(5)],
        "fx_ch1_boar_dust": [boar_dust(i) for i in range(4)],
        "fx_ch1_boar_crash": [boar_crash(i) for i in range(5)],
        "fx_ch1_moth_trail": [moth_trail(i) for i in range(4)],
        "fx_ch1_moth_shadow": [moth_shadow()],
        "fx_ch1_root_spike": [root_spike(i) for i in range(6)],
        "fx_ch1_stag_slam_rubble": [slam_rubble(i) for i in range(5)],
        "fx_ch1_purify_sparkle": [purify_sparkle(i) for i in range(8)],
    }


def ui_sets() -> list[tuple[str, Grid, tuple[int, int], str]]:
    out = [("ui_enemy_bar_frame_1", ui_bar_frame(), (16, 8),
            "32x8 frame, anchor bottom-centre (place ~4 px above the head). HP track x3-28 y2-3, posture x6-25 y5")]
    for k, note in (("hp", "HP fill: crop to width; grass_6 with a cream top line (as the boss bar)"),
                    ("hp_ghost", "recent-damage trail (stone_6), drawn under the HP fill"),
                    ("posture", "posture fill (lilac, as the boss bar)"),
                    ("posture_broken", "posture fill while broken (water_6, as the boss bar)")):
        out.append((f"ui_enemy_bar_{k}_1", ui_bar_fill(k), (16, 8), note))
    out.append(("ui_aggro_mark_small_1", [list(r) for r in AGGRO_8], (4, 7), "8x8 '!' mark, anchor bottom"))
    for i in range(4):
        out.append((f"ui_aggro_mark_{i + 1}", aggro_16(i), (8, 15),
                    "16x16 '!' pop: 1 pop, 2 overshoot, 3 settle, 4 glint; ~4 ticks each, then hold 3"))
    return out


def pack_cells(groups: list[tuple[str, list[Grid], tuple[int, int]]], max_w: int = 1024,
               numbered: bool = True) -> tuple[Image.Image, dict]:
    """Rows of equal-size cells per group (wrapping at max_w). Returns the atlas and name -> rect."""
    placed = []
    y = 0
    W = 0
    for prefix, grids, anchor in groups:
        cw, ch = len(grids[0][0]), len(grids[0])
        per = max(1, max_w // cw)
        for i, g in enumerate(grids):
            x = (i % per) * cw
            yy = y + (i // per) * ch
            placed.append((f"{prefix}_{i + 1}" if numbered else prefix, g, x, yy, cw, ch, anchor))
            W = max(W, x + cw)
        y += ((len(grids) + per - 1) // per) * ch
    im = Image.new("RGBA", (W, y), (0, 0, 0, 0))
    rects = {}
    for name, g, x, yy, cw, ch, anchor in placed:
        im.alpha_composite(to_image(g), (x, yy))
        rects[name] = {"x": x, "y": yy, "w": cw, "h": ch, "ax": anchor[0], "ay": anchor[1]}
    return im, rects


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")


COMMON = {
    "generator": GENERATOR,
    "palette": "Totoy 36, hard alpha; no reserved gold x,y or red z,A anywhere",
    "scale": "1x game pixels (previews are nearest-neighbour copies)",
    "status": "Reference art for the human's approval; not imported into art/src, not wired into the game",
    "facing": "right; mirror around the anchor for left",
    "ticks": "60 ticks per second; ticks_per_frame are suggestions only (state lengths are core decisions)",
}


def check_hard(path: Path) -> None:
    errs = list(artlib.check_png(path, PAL))
    im = Image.open(path).convert("RGBA")
    reserved = {PAL.by_symbol[c] for c in FORBIDDEN}
    for _, (r, g, b, a) in im.getcolors(1 << 20):
        if a and (r, g, b) in reserved:
            errs.append("reserved colour")
            break
    if errs:
        raise SystemExit(f"{path.name}: {errs[:3]}")


# ---------------------------------------------------------------------------------------------- previews
BG = {"dark": PAL.by_symbol["0"], "grass": PAL.by_symbol["4"]}


def labelled_sheet(groups: list[tuple[str, list[Image.Image]]], bg: tuple, zoom: int, max_w: int) -> Image.Image:
    blocks = []
    for title, ims in groups:
        cw = max(i.width for i in ims)
        ch = max(i.height for i in ims)
        per = max(1, max_w // ((cw + 2) * zoom))
        c = min(per, len(ims))
        r = (len(ims) + c - 1) // c
        block = Image.new("RGBA", (c * (cw + 2) * zoom, r * (ch + 2) * zoom + 14), bg + (255,))
        d = ImageDraw.Draw(block)
        d.text((4, 2), title, fill=(230, 230, 230, 255))
        for i, im in enumerate(ims):
            x0, y0 = (i % c) * (cw + 2) * zoom, 14 + (i // c) * (ch + 2) * zoom
            d.rectangle([x0, y0, x0 + cw * zoom - 1, y0 + ch * zoom - 1],
                        outline=tuple(min(255, v + 18) for v in bg) + (255,))
            block.alpha_composite(im.resize((im.width * zoom, im.height * zoom), Image.NEAREST), (x0, y0))
        blocks.append(block)
    W = max(b.width for b in blocks)
    H = sum(b.height + 6 for b in blocks)
    sheet = Image.new("RGBA", (W, H), bg + (255,))
    y = 0
    for b in blocks:
        sheet.alpha_composite(b, (0, y))
        y += b.height + 6
    return sheet


def hero_and_golem() -> list[tuple[Grid, tuple[int, int]]]:
    out = []
    for name in ("hero2_idle_right_1", "golem2_idle_1"):
        sp = artlib.parse_sprite(ROOT / "art" / "src" / f"{name}.txt")
        out.append(([list(r) for r in sp.rows], sp.anchor))
    return out


def stamp(canvas: Grid, g: Grid, anchor: tuple[int, int], at: tuple[int, int], flip: bool = False) -> None:
    if flip:
        g = mirror(g)
        anchor = (len(g[0]) - 1 - anchor[0], anchor[1])
    paste(canvas, g, at[0] - anchor[0], at[1] - anchor[1])


def size_comparison(sets: list[dict]) -> Image.Image:
    (hero, ha), (golem, ga) = hero_and_golem()
    items = [("Totoy", hero, ha), ("Mossbound Colossus", golem, ga)]
    for cs in sets:
        key = "flutter" if cs["id"] == "glowmoth" else "idle"
        items.append((cs["name"], cs["frames"][key][0], cs["anchor"]))
    gap, x, xs = 14, 8, []
    for _, g, a in items:
        bb = bbox(g)
        xs.append(x - bb[0])
        x += (bb[2] - bb[0] + 1) + gap
    W, H, ground, zoom = x + 4, 80, 70, 4
    canvas = blank(W, H)
    for (_, g, a), x0 in zip(items, xs):
        paste(canvas, g, x0, ground - a[1])
    im = Image.new("RGBA", (W * zoom, H * zoom + 30), BG["grass"] + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([0, (ground + 1) * zoom, W * zoom, H * zoom + 30], fill=PAL.by_symbol["3"] + (255,))
    im.alpha_composite(to_image(canvas).resize((W * zoom, H * zoom), Image.NEAREST), (0, 0))
    for (name, g, a), x0 in zip(items, xs):
        bb = bbox(g)
        d.text(((x0 + bb[0]) * zoom, H * zoom + 4), name, fill=(240, 236, 214, 255))
        d.text(((x0 + bb[0]) * zoom, H * zoom + 16), f"{bb[2] - bb[0] + 1}x{bb[3] - bb[1] + 1} px",
               fill=(200, 200, 190, 255))
    return im


def save_gif(frames: list[tuple[Grid, int, str]], path: Path, zoom: int = 4) -> None:
    ims, durs = [], []
    for g, ms, label in frames:
        W, H = len(g[0]), len(g)
        im = Image.new("RGB", (W * zoom, H * zoom + 16), PAL.by_symbol["4"])
        d = ImageDraw.Draw(im)
        d.rectangle([0, H * zoom, W * zoom, H * zoom + 16], fill=PAL.by_symbol["0"])
        d.text((4, H * zoom + 3), label, fill=PAL.by_symbol["1"])
        big = to_image(g).resize((W * zoom, H * zoom), Image.NEAREST)
        im.paste(big, (0, 0), big)
        ims.append(im.convert("P", palette=Image.ADAPTIVE, colors=64))
        durs.append(ms)
    ims[0].save(path, save_all=True, append_images=ims[1:], duration=durs, loop=0, disposal=1)


def make_gifs(sets: list[dict], fx: dict) -> list[str]:
    (hero, ha), _ = hero_and_golem()
    A = {k: v[2] for k, v in FX_INFO.items()}
    made = []
    for cs in sets:
        cid = cs["id"]
        order = list(cs["frames"].items())
        size, at, hero_at = (64, 32), (24, 28), None
        fxs: dict = {}
        if cid == "thornback_boar":
            size, at = (88, 40), (40, 36)
            fxs = {"charge_run": lambda c, n: stamp(c, fx["fx_ch1_boar_dust"][n % 4], A["fx_ch1_boar_dust"], (30, 36)),
                   "crash_stun": lambda c, n: n < 5 and stamp(c, fx["fx_ch1_boar_crash"][n], A["fx_ch1_boar_crash"],
                                                              (60, 36))}
        elif cid == "mossling":
            fxs = {"death": lambda c, n: n < 5 and stamp(c, fx["fx_ch1_leaf_puff"][n], A["fx_ch1_leaf_puff"], (24, 22)),
                   "hurt": lambda c, n: n < 2 and stamp(c, fx["fx_ch1_leaf_puff"][n], A["fx_ch1_leaf_puff"], (26, 22))}
        elif cid == "glowmoth":
            size, at = (80, 32), (12, 30)
            fl = cs["frames"]["flutter"]
            order = [(k, v) for k, v in order if k != "shot_release"]
            i = [k for k, _ in order].index("shot_tell") + 1
            order.insert(i, ("shot_release", cs["frames"]["shot_release"] + [fl[k % 6] for k in range(10)]))

            def fly(c: Grid, n: int) -> None:
                x = 18 + n * 6
                if x < 64:
                    stamp(c, fx["fx_ch1_moth_trail"][n % 4], A["fx_ch1_moth_trail"], (x, 18))
                    stamp(c, orb(n % 4), (8, 8), (x, 18))
                elif (x - 64) // 6 < 4:
                    stamp(c, orb_pop((x - 64) // 6), (8, 8), (64, 18))
            fxs = {"shot_release": fly}

        else:
            size, at, hero_at = (168, 72), (52, 68), (148, 68)
            fxs = {"slam_strike": lambda c, n: 1 <= n <= 5 and stamp(c, fx["fx_ch1_stag_slam_rubble"][n - 1],
                                                                     A["fx_ch1_stag_slam_rubble"], (82, 68)),
                   "phase2_roar": lambda c, n: 1 <= n <= 6 and stamp(c, fx["fx_ch1_root_spike"][n - 1],
                                                                     A["fx_ch1_root_spike"], (118, 68)),
                   "freed": lambda c, n: n < 8 and stamp(c, fx["fx_ch1_purify_sparkle"][n],
                                                         A["fx_ch1_purify_sparkle"], (50, 46))}
        frames = []
        for state, fr in order:
            ticks, loop, _ = cs["states"].get(state, (8, False, ""))
            ticks = ticks or 10
            seq = list(range(len(fr))) * (2 if loop else 1) + ([] if loop else [len(fr) - 1] * 2)
            for n, i in enumerate(seq):
                c = blank(*size)
                if cid == "glowmoth":
                    stamp(c, moth_shadow(), (8, 4), (at[0], at[1] - 1))
                if hero_at:
                    stamp(c, hero, ha, hero_at, flip=True)
                stamp(c, fr[i], cs["anchor"], at)
                if state in fxs:
                    fxs[state](c, n)
                frames.append((c, max(20, int(round(ticks * TICK_MS))),
                               f"{cs['name']}: {state} {i + 1}/{len(fr)}"))
        path = OUT / f"creature_{cid}_states.gif"
        save_gif(frames, path)
        made.append(path.name)
    return made


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    sets = creature_sets()
    files = []
    for cs in sets:
        cid = cs["id"]
        groups = [(f"creature_{cid}_{st}", fr, cs["anchor"]) for st, fr in cs["frames"].items()]
        if "extra" in cs:
            groups += [(f"creature_{cid}_{st}", fr, cs["extra"]["anchor"]) for st, fr in cs["extra"]["frames"].items()]
        im, rects = pack_cells(groups, 1024)
        png = OUT / f"creature_{cid}_v1.png"
        im.save(png)
        check_hard(png)
        all_frames = dict(cs["frames"], **cs.get("extra", {}).get("frames", {}))
        states = {}
        for st, fr in all_frames.items():
            t, loop, note = cs["states"].get(st, (8, False, ""))
            states[st] = {"frames": len(fr), "ticks_per_frame": t if t else "telegraph", "loop": loop,
                          "names": f"creature_{cid}_{st}_1..{len(fr)}", "note": note}
        cell = {"w": cs["cell"][0], "h": cs["cell"][1], "anchor": list(cs["anchor"])}
        if "extra" in cs:
            cell["projectile"] = {"w": ORB, "h": ORB, "anchor": [8, 8]}
        write_json(OUT / f"creature_{cid}_v1.json", dict(COMMON, creature=cs["name"], id=cid, cell=cell,
                                                          states=states, frames=rects))
        files += [png.name, f"creature_{cid}_v1.json"]
    fx = fx_sets()
    im, rects = pack_cells([(k, v, FX_INFO[k][2]) for k, v in fx.items()], 512)
    im.save(OUT / "fx_ch1_v1.png")
    check_hard(OUT / "fx_ch1_v1.png")
    write_json(OUT / "fx_ch1_v1.json", dict(COMMON, groups={
        k: {"frames": len(fx[k]), "cell": [v[0], v[1]], "anchor": list(v[2]), "ticks_per_frame": v[3], "note": v[4]}
        for k, v in FX_INFO.items()}, frames=rects))
    ui = ui_sets()
    im, rects = pack_cells([(n, [g], a) for n, g, a, _ in ui], 64, numbered=False)
    im.save(OUT / "ui_ch1_v1.png")
    check_hard(OUT / "ui_ch1_v1.png")
    write_json(OUT / "ui_ch1_v1.json", dict(COMMON, notes={n: note for n, _, _, note in ui}, frames=rects))
    files += ["fx_ch1_v1.png", "fx_ch1_v1.json", "ui_ch1_v1.png", "ui_ch1_v1.json"]
    groups = []
    for cs in sets:
        for st, fr in list(cs["frames"].items()) + list(cs.get("extra", {}).get("frames", {}).items()):
            groups.append((f"creature_{cs['id']}_{st}  ({len(fr)} frames, {len(fr[0][0])}x{len(fr[0])})",
                           [to_image(g) for g in fr]))
    for k, v in fx.items():
        groups.append((f"{k}  ({len(v)} frames)", [to_image(g) for g in v]))
    groups.append(("ui_enemy_bar: frame, hp, hp_ghost, posture, posture_broken; examples 60/80/40 and broken",
                   [to_image(g) for _, g, _, _ in ui[:5]] +
                   [to_image(ui_bar_example(0.6, 0.8, 0.4)), to_image(ui_bar_example(0.15, 0.3, 1.0, True))]))
    groups.append(("ui_aggro_mark: small 8x8, then 16x16 pop 1-4", [to_image(g) for _, g, _, _ in ui[5:]]))
    for tag, bg in BG.items():
        labelled_sheet(groups, bg, 4, 3200).convert("RGB").save(OUT / f"preview_contact_{tag}.png")
    files += ["preview_contact_dark.png", "preview_contact_grass.png"]
    size_comparison(sets).convert("RGB").save(OUT / "size_comparison.png")
    files.append("size_comparison.png")
    files += make_gifs(sets, fx)
    print("wrote", len(files), "files to", OUT.relative_to(ROOT))
    return 0


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[1] == "--debug":
    DEBUG = {"mossling": (mossling_frames, MOSS_A), "boar": (boar_frames, BOAR_A), "stag": (stag_frames, STAG_A),
             "moth": (glowmoth_frames, MOTH_A)}
    fn, anc = DEBUG[sys.argv[2]]
    debug_sheet(fn(), anc, Path(sys.argv[3]))
    sys.exit(0)

if __name__ == "__main__":
    sys.exit(main())
