"""Generate the Chapter 1 CHARACTER reference art (art/reference/chapter1_characters/). Review only: nothing is wired in.

Everything is drawn procedurally, pixel by pixel, in the Totoy 36 palette with hard alpha. Gold (x, y) and red (z, A) are
reserved for combat cues and are never used (asserted on every pixel).

  1. NPC world sprites, right-facing side view like the hero (32x40 cells, feet anchor, left = mirrored at runtime):
     Mira, Tovan, Edda (idle 4, walk 6, talk 3) and three villagers (child, farmer, basket woman: idle 4, walk 6).
     A small rig: hand-drawn head and torso grids, procedural legs, arms, skirts and held props, one ink outline pass.
  2. Dialogue portraits, 64x64 busts with a 1 px ink outline: Totoy, Mira, Tovan, Edda with five expressions
     (neutral, happy, worried, serious, surprised) and a neutral portrait for each villager.
  3. Dialogue UI pieces at 1x for 320x180 in the shared pop-up frame style (presentation/arena/ui_panel.gd).

Outputs (atlases at 1x; previews scaled with nearest neighbour):
  npc_sprites_v1.png/.json, portraits_v1.png/.json, dialogue_ui_v1.png/.json,
  preview_contact_dark.png, preview_contact_grass.png, npc_<name>.gif (idle + walk + talk),
  portraits_contact_dark.png, portraits_contact_grass.png, dialogue_ui_4x.png, npc_lineup_game_scale_1x/4x.png,
  dialogue_mockup_1x.png, dialogue_mockup_4x.png, dialogue_mockup_choice_4x.png, dialogue_next_blink.gif
Dev helpers: --dev OUT.png (all NPC frames), --zoom OUT.png name[,name] [zoom] [state,...], --portraits OUT.png [zoom]
Run from the project root (deterministic):
  python tools/art/make_chapter1_characters_art.py
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
OUT = ROOT / "art" / "reference" / "chapter1_characters"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)  # gold and red: combat cues only
PIXEL_FONT = ROOT / "presentation" / "fonts" / "PixelifySans.ttf"
MENU_FONT = ROOT / "presentation" / "fonts" / "Cinzel.ttf"

Grid = list  # list[list[str]]

# one step darker along each ramp (used for the far limbs and for shading)
_RAMPS = ["234567", "89abcd", "efghij", "klmnop"]
DARKER: dict[str, str] = {"0": "0", "1": "j", "q": "9", "r": "q", "s": "r", "t": "f", "u": "t", "v": "l"}
for _r in _RAMPS:
    for _i, _c in enumerate(_r):
        DARKER[_c] = _r[_i - 1] if _i else "0"


# ----------------------------------------------------------------------------------------------- grid helpers
def blank(w: int, h: int) -> Grid:
    return [[T] * w for _ in range(h)]


def put(g: Grid, x: int, y: int, c: str) -> None:
    if 0 <= y < len(g) and 0 <= x < len(g[0]) and c != T:
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


def parse(rows: list[str], legend: dict[str, str]) -> Grid:
    w = max(len(r) for r in rows)
    g = []
    for r in rows:
        line = []
        for ch in r.ljust(w, T):
            c = legend.get(ch, ch)
            assert c == T or c in PAL.by_symbol, f"unknown symbol {ch!r}"
            line.append(c)
        g.append(line)
    return g


def to_image(g: Grid) -> Image.Image:
    im = Image.new("RGBA", (len(g[0]), len(g)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T:
                assert c not in FORBIDDEN, f"reserved colour {c}"
                px[x, y] = PAL.by_symbol[c] + (255,)
    return im


def outline(g: Grid, ink: str = "0", diagonal: bool = False) -> Grid:
    out = copy(g)
    h, w = len(g), len(g[0])
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)] + ([(1, 1), (1, -1), (-1, 1), (-1, -1)] if diagonal else [])
    for y in range(h):
        for x in range(w):
            if g[y][x] == T and any(get(g, x + dx, y + dy) != T for dx, dy in nb):
                out[y][x] = ink
    return out


def darken(g: Grid) -> Grid:
    return [[DARKER.get(c, c) if c != T else T for c in r] for r in g]


def ink_ring(dst: Grid, part: Grid, ox: int = 0, oy: int = 0) -> None:
    """Paste `part` and draw a 1 px ink line where it borders pixels already in `dst` (separates a near limb)."""
    h, w = len(part), len(part[0])
    for y in range(h):
        for x in range(w):
            if part[y][x] != T:
                continue
            if any(0 <= y + dy < h and 0 <= x + dx < w and part[y + dy][x + dx] != T for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                if get(dst, x + ox, y + oy) != T:
                    put(dst, x + ox, y + oy, "0")
    paste(dst, part, ox, oy)


def seg_pts(x0: float, y0: float, x1: float, y1: float) -> list[tuple[int, int]]:
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    pts: list[tuple[int, int]] = []
    for i in range(n + 1):
        t = i / n
        p = (int(math.floor(x0 + (x1 - x0) * t + 0.5)), int(math.floor(y0 + (y1 - y0) * t + 0.5)))
        if not pts or pts[-1] != p:
            pts.append(p)
    return pts


def limb(g: Grid, pts: list[tuple[float, float]], w: int, cols: list[str] | callable) -> None:
    """A thick polyline. `cols` is the left-to-right (or top-to-bottom when flat) shading across the width, or a
    function of the path fraction t returning such a list (sleeve then skin)."""
    total = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)) or 1.0
    run = 0.0
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        flat = abs(x1 - x0) > abs(y1 - y0) * 1.4
        L = math.dist(pts[i], pts[i + 1]) or 1.0
        for (px_, py_) in seg_pts(x0, y0, x1, y1):
            t = (run + math.dist((x0, y0), (px_, py_))) / total
            cc = cols(min(1.0, t)) if callable(cols) else cols
            for a in range(w):
                for b in range(w):
                    put(g, px_ - (w - 1) // 2 + a, py_ - (w - 1) // 2 + b, cc[b] if flat else cc[a])
        run += L


# ----------------------------------------------------------------------------------------------- NPC rig
CW, CH = 32, 40
SOLE = 35          # bottom row of the feet
ANCHOR_Y = SOLE + 1  # same convention as hero2_* (anchor = one row under the soles)

# walk: (near foot dx, lift), (far foot dx, lift), hip drop
WALK = [((4, 0), (-4, 0), 1), ((2, 0), (-3, 1), 0), ((0, 0), (1, 2), 0),
        ((-4, 0), (4, 0), 1), ((-3, 1), (2, 0), 0), ((1, 2), (0, 0), 0)]
IDLE_BOB = [0, 1, 1, 0]
IDLE_BLINK = [False, False, False, True]


class Pose:
    def __init__(self, state: str, n: int):
        self.state, self.n = state, n
        self.upper = 0          # upper body bob (breathing)
        self.drop = 0           # hip drop (walk)
        self.near = (0, 0)      # near foot (dx, lift)
        self.far = (0, 0)
        self.swing = 0.0        # near arm swing (+ = forward)
        self.blink = False
        self.mouth = False
        self.gesture = -1       # talk frame index or -1
        self.phase = 0.0        # walk phase 0..1 (skirts, props)
        if state == "idle":
            self.upper = IDLE_BOB[n]
            self.blink = IDLE_BLINK[n]
            self.near, self.far = (1, 0), (-1, 0)
        elif state == "walk":
            (self.near, self.far, self.drop) = WALK[n]
            self.swing = -self.near[0] * 0.7
            self.phase = n / 6
        elif state == "talk":
            self.near, self.far = (1, 0), (-1, 0)
            self.gesture = n
            self.mouth = n != 1
            self.upper = [0, 0, 1][n]


def leg(g: Grid, hip: tuple[int, int], foot: tuple[int, int], lift: int, w: int, cols: list[str], boot: list[str], toe: int = 1) -> None:
    hx, hy = hip
    fx = hx + foot[0]
    sole = SOLE - lift
    ank = sole - 2
    ky = (hy + ank) / 2
    kx = (hx + fx) / 2 + (1 + lift * 0.8 if lift else 0.4)
    limb(g, [(hx, hy), (kx, ky), (fx, ank)], w, cols)
    # boot: two rows, toe forward (right)
    left = fx - (w - 1) // 2
    for i in range(w):
        put(g, left + i, ank + 1, boot[1])
    for i in range(w + toe):
        put(g, left + i, sole, boot[1] if i < w + toe - 1 else boot[0])
    put(g, left, sole, boot[0])


class NPC:
    """A character spec; `frame(pose)` returns a CW x CH grid with the outline already applied."""
    name = ""
    hip = (15, 26)
    leg_w = 3
    pants = ["a", "a", "9"]
    boots = ["8", "9"]
    arm_w = 2
    arm_len = 8
    states = ("idle", "walk", "talk")
    far_dx = -1

    def torso(self, p: Pose) -> tuple[Grid, int, int]:  # grid and its origin relative to the hip
        raise NotImplementedError

    def head(self, p: Pose) -> tuple[Grid, int, int]:
        raise NotImplementedError

    def shoulder(self) -> tuple[int, int]:  # near shoulder relative to the hip
        return (1, -8)

    def sleeve(self, t: float) -> list[str]:
        return ["m", "m"]

    def hand_cols(self) -> list[str]:
        return ["s", "r"]

    def hand_target(self, p: Pose) -> tuple[float, float]:
        sx, sy = self.shoulder()
        if p.gesture >= 0:
            return [(5, 3), (6, 1), (5, 2)][p.gesture]
        s = p.swing
        return (s, self.arm_len - abs(s) * 0.25)

    def far_arm(self, p: Pose) -> bool:
        return True

    def legs(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        far = darken([[c] for c in self.pants])
        leg(g, (hx - 1, hy), p.far, p.far[1], self.leg_w, [r[0] for r in far], [DARKER[b] for b in self.boots])
        leg(g, (hx, hy), p.near, p.near[1], self.leg_w, self.pants, self.boots)

    def behind(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        pass

    def front(self, g: Grid, hx: int, hy: int, p: Pose, hand: tuple[int, int]) -> None:
        pass

    def over_torso(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        pass

    def arm_path(self, sx: int, sy: int, hx_: float, hy_: float) -> list[tuple[float, float]]:
        ex = sx + (hx_) * 0.45 - 1.0
        ey = sy + hy_ * 0.5
        if hy_ < 4:  # raised: the elbow drops below
            ex, ey = sx + hx_ * 0.3, sy + 4
        return [(sx, sy), (ex, ey), (sx + hx_, sy + hy_)]

    def frame(self, p: Pose) -> Grid:
        g = blank(CW, CH)
        hx, hy0 = self.hip
        hy = hy0 + p.drop
        uy = hy + p.upper  # upper body origin
        sx, sy = self.shoulder()
        sx, sy = hx + sx, uy + sy
        # far arm (behind the body), darker
        if self.far_arm(p):
            fa = blank(CW, CH)
            s = -p.swing if p.state == "walk" else 0
            tx, ty = s - 1, self.arm_len - abs(s) * 0.25
            limb(fa, self.arm_path(sx + self.far_dx, sy, tx, ty), self.arm_w, lambda t: [DARKER[c] for c in (self.sleeve(t) if t < 0.85 else self.hand_cols())])
            paste(g, fa, 0, 0)
        self.behind(g, hx, uy, p)
        self.legs(g, hx, hy, p)
        tg, tx_, ty_ = self.torso(p)
        paste(g, tg, hx + tx_, uy + ty_)
        self.over_torso(g, hx, uy, p)
        hg, hx_, hy_ = self.head(p)
        paste(g, hg, hx + hx_, uy + hy_)
        # near arm with its own ink ring over the body
        na = blank(CW, CH)
        tx, ty = self.hand_target(p)
        path = self.arm_path(sx, sy, tx, ty)
        limb(na, path, self.arm_w, lambda t: self.sleeve(t) if t < 0.85 else self.hand_cols())
        hand = (int(round(sx + tx)), int(round(sy + ty)))
        ink_ring(g, na)
        self.front(g, hx, uy, p, hand)
        return outline(g)


def legend(**kw: str) -> dict[str, str]:
    return kw


# ---------------------------------------------------------------- Mira, mapmaker
class Mira(NPC):
    name = "mira"
    hip = (15, 26)
    pants = ["b", "a", "9"]
    boots = ["8", "9"]
    L = legend(H="a", h="9", L="b", S="s", R="r", Q="q", E="0", C="m", K="n", c="l", U="u", u="t", B="9", D="d", d="c",
               G="a", g="9", M="1", m="j", W="c")
    HEAD = [
        "...hhhh...",
        "..hHLLHh..",
        ".hHLLHHHh.",
        "hHHHHHHHHh",
        "hHHHHHHhSS",
        "hHHHhHRSSS",
        "hHHhRRSESS",
        "hHHhQRSSSS",
        ".hHh.RSSS.",
        ".hHh.QRSR.",
        "..hh..QR..",
        "..h.......",
    ]

    def head(self, p: Pose) -> tuple[Grid, int, int]:
        rows = list(self.HEAD)
        if p.blink:
            rows[6] = rows[6][:7] + "R" + rows[6][8:]
        if p.mouth:
            rows[9] = rows[9][:8] + "Q" + rows[9][9:]
        return parse(rows, self.L), -4, -18

    TORSO = [
        "...UUU....",
        "..uUUUUU..",
        ".uUCKKUUu.",
        ".UKKCCCCc.",
        ".uKCCGCCc.",
        "..KCGCCCc.",
        "..KGCCCCc.",
        "..BBBBDdB.",
        "..KCCCCCc.",
        "..KCCCCCcc",
        "..ccccccc.",
    ]

    def torso(self, p: Pose) -> tuple[Grid, int, int]:
        return parse(self.TORSO, self.L), -4, -7

    SATCHEL = [
        "1M....",
        ".jM...",
        "..jM.M",
        "...jMj",
        "GGGGGg",
        "GWWWWg",
        "GWWdWg",
        ".gggg.",
    ]

    def behind(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        sway = 1 if p.state == "walk" and p.n in (1, 4) else 0
        paste(g, parse(self.SATCHEL, self.L), hx - 8, hy - 6 + sway)
        # scarf tail flutters behind
        tail = ["UU..", ".uUU", "..uU"] if p.state != "walk" else (["UUU.", ".uUUU", "...uU"] if p.n % 2 else ["UU..", ".uUUU", "..u.U"])
        paste(g, parse(tail, self.L), hx - 7, hy - 9)

    def shoulder(self) -> tuple[int, int]:
        return (0, -5)

    def sleeve(self, t: float) -> list[str]:
        return ["n", "l"] if t < 0.5 else ["m", "l"]

    def hand_cols(self) -> list[str]:
        return ["c", "k"]  # ink-stained gloves

    def hand_target(self, p: Pose) -> tuple[float, float]:
        if p.gesture >= 0:
            return [(6, 1), (7, -1), (6, 0)][p.gesture]
        return super().hand_target(p)

    arm_len = 7


# ---------------------------------------------------------------- Tovan, smith
class Tovan(NPC):
    name = "tovan"
    hip = (15, 25)
    leg_w = 4
    pants = ["g", "f", "f", "e"]
    boots = ["8", "9"]
    arm_w = 3
    arm_len = 8
    L = legend(H="9", h="8", S="r", s="s", R="q", B="9", b="8", E="0", F="f", M="i", m="h", N="j", P="b", p="a", Q="c",
               K="8", g="g", G="h", W="9")
    HEAD = [
        "..hhhhh....",
        ".hHHHHHHh..",
        "hHHHHHHHHh.",
        "hHHHHHHhSS.",
        "hHHRSS00SS.",
        "hHRRSSSESSS",
        ".hRRSSSSSS.",
        ".BBbRSBBBb.",
        ".bBBBBMBBb.",
        "..bBBBBBb..",
    ]

    def head(self, p: Pose) -> tuple[Grid, int, int]:
        rows = list(self.HEAD)
        if p.blink:
            rows[5] = rows[5][:7] + "S" + rows[5][8:]
        rows[8] = rows[8][:6] + ("E" if p.mouth else "B") + rows[8][7:]
        return parse(rows, self.L), -3, -17

    TORSO = [
        ".....RSSR.....",
        "...MNNSSRMm...",
        "..MNNMMMPPPm..",
        ".MNNMMMPQPPPm.",
        "MNNMMMMPQPPPpm",
        "MNMMMMMPQPPPpm",
        "MNMMMMMPQPPPp.",
        ".MMMMMMPQPPPp.",
        ".KKKKKKKKKKKK.",
        "..mmmMMPQPPPp.",
        "...mmmPQPPPPp.",
        ".....PPQPPFpp.",
        ".....ppppppp..",
    ]

    def torso(self, p: Pose) -> tuple[Grid, int, int]:
        return parse(self.TORSO, self.L), -6, -8

    HAMMER = ["0000.", "0NNG0", "0gGg0", "00K0.", ".0K0.", ".0K0.", "..0.."]

    def over_torso(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        sw = 0 if p.state != "walk" else [0, 1, 1, 0, -1, -1][p.n]
        paste(g, parse(self.HAMMER, self.L), hx + 2 + sw, hy - 1)

    far_dx = 1

    def shoulder(self) -> tuple[int, int]:
        return (-1, -5)

    def sleeve(self, t: float) -> list[str]:
        return ["j", "i", "h"] if t < 0.4 else ["s", "r", "q"]

    def hand_cols(self) -> list[str]:
        return ["r", "r", "q"]


# ---------------------------------------------------------------- Edda, Aspect keeper
class Edda(NPC):
    name = "edda"
    hip = (14, 25)
    arm_len = 7
    L = legend(H="j", h="i", L="1", S="s", R="r", Q="q", E="0", V="4", W="3", X="5", F="1", f="j", G="6", g="5", D="l", d="k",
               e="m", M="r")
    HEAD = [
        ".hh.......",
        "hHLh.hhh..",
        "hHHhHLLHh.",
        ".hHHLHHHHh",
        ".hHHHHHhSS",
        ".hHHHHRSSS",
        ".hHHRRSESS",
        ".hHhRQSSSS",
        "..hhRRSSS.",
        "....QRSMS.",
        ".....RRR..",
    ]

    def head(self, p: Pose) -> tuple[Grid, int, int]:
        rows = list(self.HEAD)
        if p.blink:
            rows[6] = rows[6][:7] + "Q" + rows[6][8:]
        if p.mouth:
            rows[9] = rows[9][:7] + "Q" + rows[9][8:]
        return parse(rows, self.L), -3, -17

    TORSO = [
        "...WVVW....",
        "..WVXXVVW..",
        ".WVXXXVVVW.",
        ".WVXVVVVVVW",
        "..WVVVVVVW.",
        "..FWVVVVWG.",
        "..f.WVVWgG.",
        "...F.WW....",
    ]

    def torso(self, p: Pose) -> tuple[Grid, int, int]:
        return parse(self.TORSO, self.L), -5, -8

    def shoulder(self) -> tuple[int, int]:
        return (1, -6)

    def sleeve(self, t: float) -> list[str]:
        return ["5", "4"] if t < 0.45 else ["v", "l"]

    def legs(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        # long dress: a bell from the hip to just above the soles; the feet peek out under the hem
        sway = 0 if p.state != "walk" else round(math.sin(p.phase * 2 * math.pi) * 1)
        for side, foot in ((-1, p.far), (1, p.near)):
            fx = hx + foot[0] - (1 if side < 0 else 0)
            put(g, fx, SOLE - foot[1], "8")
            put(g, fx + 1, SOLE - foot[1], "9")
            put(g, fx + 2, SOLE - foot[1], "9" if side > 0 else "8")
        top, bot = hy - 1, SOLE - 1
        for y in range(top, bot + 1):
            t = (y - top) / (bot - top)
            half_l = 3 + t * 2.4
            half_r = 3 + t * 2.6
            off = sway * t
            x0 = int(round(hx - half_l + off))
            x1 = int(round(hx + half_r + off))
            for x in range(x0, x1 + 1):
                c = "v"
                if x >= x1 - 1 or y == bot:
                    c = "l"
                put(g, x, y, c)
        # a fold line
        for y in range(top + 4, bot):
            put(g, hx + 1 + int(round(sway * (y - top) / (bot - top))), y, "l")

    def hand_target(self, p: Pose) -> tuple[float, float]:
        if p.gesture >= 0:
            return [(6, 1), (6, -1), (6, 0)][p.gesture]
        if p.state == "walk":
            return (6 + p.near[0] * 0.25, 3)
        return (6, 3)

    def far_arm(self, p: Pose) -> bool:
        return False

    def front(self, g: Grid, hx: int, hy: int, p: Pose, hand: tuple[int, int]) -> None:
        # walking staff held in the near hand; top knob with a teal Aspect fragment
        x, y = hand[0] + 1, hand[1]
        bottom = SOLE if p.state != "walk" else SOLE - (0 if p.n in (0, 1, 2, 3) else 1)
        top = y - 13
        for yy in range(top + 3, bottom + 1):
            if yy in (y, y + 1):
                continue
            put(g, x, yy, "b")
            put(g, x + 1, yy, "9")
        glow = p.gesture == 1 or (p.state == "idle" and p.n in (1, 2))
        knob = [".bb..", "b..b.", "b.uc.", ".bpub" if glow else ".buub", "..b9."]
        knob = [r for r in knob]
        kg = parse(knob, {"u": "u", "p": "p" if glow else "o", "c": "p" if glow else "u"})
        paste(g, kg, x - 1, top)
        if glow:
            put(g, x + 4, top + 1, "p")


# ---------------------------------------------------------------- Villager 1: child with a lantern
class Child(NPC):
    name = "villager_child"
    hip = (15, 30)
    leg_w = 2
    pants = ["9", "8"]
    boots = ["8", "9"]
    arm_len = 5
    states = ("idle", "walk")
    L = legend(H="a", h="9", L="b", S="s", R="r", Q="q", E="0", C="6", K="7", c="5", B="b", P="9", p="8", M="r")
    HEAD = [
        "....hH....",
        "..hHHHHh..",
        ".hHHLLHHh.",
        "hHHLLHHHHh",
        "hHHHHHHHSS",
        "hHHHhRSSSS",
        "hHHhRRSESS",
        ".hHhRRSESS",
        ".hhhQRRSS.",
        "....QRSMS.",
        ".....QRR..",
    ]

    def head(self, p: Pose) -> tuple[Grid, int, int]:
        rows = list(self.HEAD)
        if p.blink:
            rows[6] = rows[6][:7] + "S" + rows[6][8:]
            rows[7] = rows[7][:7] + "Q" + rows[7][8:]
        return parse(rows, self.L), -5, -16

    TORSO = [
        "..CCC..",
        ".KCCCc.",
        ".KCCCc.",
        ".KCCCc.",
        ".BBBBB.",
        ".KCCCcc",
        ".PPPPp.",
    ]

    def torso(self, p: Pose) -> tuple[Grid, int, int]:
        return parse(self.TORSO, self.L), -3, -5

    def shoulder(self) -> tuple[int, int]:
        return (0, -4)

    def sleeve(self, t: float) -> list[str]:
        return ["6", "5"] if t < 0.5 else ["s", "r"]

    def legs(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        f = (p.far[0] * 3 // 4, p.far[1])
        n = (p.near[0] * 3 // 4, p.near[1])
        leg(g, (hx - 1, hy), f, f[1], 2, ["q", "9"], ["8", "8"])
        leg(g, (hx, hy), n, n[1], 2, ["r", "q"], ["8", "9"])

    def hand_target(self, p: Pose) -> tuple[float, float]:
        if p.state == "walk":
            return (3 + p.near[0] * 0.2, 3)
        return (3, 3)

    def front(self, g: Grid, hx: int, hy: int, p: Pose, hand: tuple[int, int]) -> None:
        x, y = hand
        lit = ["1", "1", "7", "1", "7", "1"][p.n % 6]
        core = "d" if lit == "7" else "7"
        lantern = [
            ".f.",
            "f.f",
            "fff",
            "lcl",
            "cmc",
            "fff",
        ]
        swing = 0 if p.state != "walk" else [0, 1, 0, 0, 1, 0][p.n]
        lg = parse(lantern, {"f": "f", "l": lit, "c": core, "m": lit})
        paste(g, lg, x, y - 1 + swing)


# ---------------------------------------------------------------- Villager 2: older farmer with a wide hat
class Farmer(NPC):
    name = "villager_farmer"
    hip = (15, 26)
    pants = ["m", "l", "k"]
    boots = ["8", "9"]
    states = ("idle", "walk")
    arm_len = 8
    L = legend(H="c", h="b", L="d", D="9", S="s", R="r", Q="q", E="0", G="i", g="h", W="j", O="m", o="l", P="n", C="1", c="j",
               B="9")
    HEAD = [
        ".....hhhh.....",
        "....hHLLHh....",
        "...hHLLHHHh...",
        "..hHHHHHHHHh..",
        "DhhhhhhhhhhhhD",
        ".DDggRRRSSS...",
        "...gGRRSESS...",
        "...gGeRSSSSS..",
        "...ggRRSWWW...",
        "....gRRSSWS...",
        ".....RRSS.....",
    ]

    def head(self, p: Pose) -> tuple[Grid, int, int]:
        rows = list(self.HEAD)
        if p.blink:
            rows[6] = rows[6][:8] + "R" + rows[6][9:]
        return parse(rows, {**self.L, "e": "q"}), -7, -17

    TORSO = [
        "...CCC...",
        "..CCCCc..",
        ".CPOOOCc.",
        ".COOOOOc.",
        ".CPOOOOc.",
        ".OPOOOOo.",
        ".OPOOOOo.",
        ".oOOOOOo.",
    ]

    def torso(self, p: Pose) -> tuple[Grid, int, int]:
        return parse(self.TORSO, self.L), -4, -7

    def shoulder(self) -> tuple[int, int]:
        return (0, -5)

    def sleeve(self, t: float) -> list[str]:
        return ["1", "j"] if t < 0.7 else ["s", "r"]

    def far_arm(self, p: Pose) -> bool:
        return True

    def hand_target(self, p: Pose) -> tuple[float, float]:
        s = p.swing * 0.7
        return (s + 1, self.arm_len - abs(s) * 0.25)


# ---------------------------------------------------------------- Villager 3: woman with a basket
class BasketWoman(NPC):
    name = "villager_basket"
    hip = (15, 26)
    states = ("idle", "walk")
    arm_len = 6
    L = legend(H="v", h="l", L="v", K="a", S="s", R="r", Q="q", E="0", C="u", c="t", k="u", A="1", a="j", M="r")
    HEAD = [
        "...hhhh...",
        "..hHHLLh..",
        ".hHHLLHHh.",
        "hHHHHHHHHh",
        "hHHHHHhKKS",
        "hHHhKKSSSS",
        "hhHhRRSESS",
        "hh.hQRSSSS",
        ".h..hRSMS.",
        "....hQRR..",
    ]

    def head(self, p: Pose) -> tuple[Grid, int, int]:
        rows = list(self.HEAD)
        if p.blink:
            rows[6] = rows[6][:7] + "R" + rows[6][8:]
        return parse(rows, self.L), -4, -17

    TORSO = [
        "...kCC...",
        "..kCCCc..",
        ".kCCCAAc.",
        ".kCCAAAc.",
        ".kCCAAac.",
        ".kCCAAac.",
        "..cAAAAc.",
    ]

    def torso(self, p: Pose) -> tuple[Grid, int, int]:
        return parse(self.TORSO, self.L), -4, -6

    def shoulder(self) -> tuple[int, int]:
        return (0, -4)

    def sleeve(self, t: float) -> list[str]:
        return ["u", "t"] if t < 0.6 else ["s", "r"]

    def legs(self, g: Grid, hx: int, hy: int, p: Pose) -> None:
        sway = 0 if p.state != "walk" else round(math.sin(p.phase * 2 * math.pi) * 1)
        for side, foot in ((-1, p.far), (1, p.near)):
            fx = hx + foot[0] - (1 if side < 0 else 0)
            for i, c in enumerate("899" if side > 0 else "889"):
                put(g, fx + i, SOLE - foot[1], c)
        top, bot = hy, SOLE - 1
        for y in range(top, bot + 1):
            t = (y - top) / (bot - top)
            x0 = int(round(hx - 3 - t * 1.8 + sway * t))
            x1 = int(round(hx + 3 + t * 2.2 + sway * t))
            for x in range(x0, x1 + 1):
                c = "u"
                if x >= x1 - 1 or y == bot:
                    c = "t"
                put(g, x, y, c)
            # apron in front
            for x in range(x1 - 3, x1 - 1):
                if y < bot - 1:
                    put(g, x, y, "1" if x < x1 - 2 else "j")

    def far_arm(self, p: Pose) -> bool:
        return True

    def hand_target(self, p: Pose) -> tuple[float, float]:
        return (4, 5)

    BASKET = [
        ".5v6v5.",
        "b6v5n6b",
        "bcbcbcb",
        "9bcbcb9",
        ".99999.",
    ]

    def front(self, g: Grid, hx: int, hy: int, p: Pose, hand: tuple[int, int]) -> None:
        bob = 0 if p.state != "walk" else [1, 0, 0, 1, 0, 0][p.n]
        paste(g, parse(self.BASKET, {}), hand[0] - 2, hand[1] - 2 + bob)


NPCS: list[NPC] = [Mira(), Tovan(), Edda(), Child(), Farmer(), BasketWoman()]
FRAMES = {"idle": 4, "walk": 6, "talk": 3}
# suggested ticks per frame at 60 ticks/s (presentation decides)
TICKS = {"idle": [20, 12, 20, 6], "walk": [7] * 6, "talk": [9, 9, 9]}


def npc_frames(npc: NPC) -> dict[str, list[Grid]]:
    out: dict[str, list[Grid]] = {}
    for st in npc.states:
        out[st] = [npc.frame(Pose(st, i)) for i in range(FRAMES[st])]
    return out


# ----------------------------------------------------------------------------------------------- portraits
PS = 64  # portrait size
EXPRESSIONS = ("neutral", "happy", "worried", "serious", "surprised")


class Region:
    def __init__(self, name: str, ramp: str, z: int, group: str, ink: bool = True, band: int = 2, light: bool = True):
        self.name, self.ramp, self.z, self.group, self.ink, self.band, self.light = name, ramp, z, group, ink, band, light


class Portrait:
    """A region map painted with polygons; `render` shades every region with its 3-step ramp (light from the upper
    left: a highlight rim on the top/left edges, a shadow band on the bottom/right edges and under any piece that sits
    on top), inks the edge of every piece against what lies below it, then the features are drawn on top."""

    def __init__(self, size: int = PS):
        self.n = size
        self.reg: list[list[Region | None]] = [[None] * size for _ in range(size)]
        self.z = 0
        self.after: list[tuple[int, int, str]] = []

    def region(self, name: str, ramp: str, group: str | None = None, **kw) -> Region:
        self.z += 1
        return Region(name, ramp, self.z, group or name, **kw)

    def _mask(self, draw_fn) -> list[tuple[int, int]]:
        m = Image.new("L", (self.n, self.n), 0)
        draw_fn(ImageDraw.Draw(m))
        px = m.load()
        return [(x, y) for y in range(self.n) for x in range(self.n) if px[x, y]]

    def poly(self, pts: list[tuple[float, float]], r: Region) -> None:
        for x, y in self._mask(lambda d: d.polygon([tuple(p) for p in pts], fill=1)):
            self.reg[y][x] = r

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, r: Region) -> None:
        for x, y in self._mask(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=1)):
            self.reg[y][x] = r

    def line(self, pts: list[tuple[float, float]], w: int, r: Region) -> None:
        for x, y in self._mask(lambda d: d.line([tuple(p) for p in pts], fill=1, width=w)):
            self.reg[y][x] = r

    def px(self, x: int, y: int, c: str) -> None:
        self.after.append((x, y, c))

    def pxs(self, pts, c: str) -> None:
        for x, y in pts:
            self.px(x, y, c)

    def strand(self, pts: list[tuple[float, float]], c: str) -> None:
        for i in range(len(pts) - 1):
            for q in seg_pts(*pts[i], *pts[i + 1]):
                self.after.append((q[0], q[1], c))

    def _r(self, x: int, y: int) -> Region | None:
        if 0 <= x < self.n and 0 <= y < self.n:
            return self.reg[y][x]
        return None

    def render(self) -> Grid:
        g = blank(self.n, self.n)
        for y in range(self.n):
            for x in range(self.n):
                r = self.reg[y][x]
                if r is None:
                    continue
                dark, mid, light = r.ramp[0], r.ramp[1], r.ramp[2]
                c = mid
                cast = any((o := self._r(x + dx, y + dy)) is not None and o.z > r.z and o.group != r.group
                           for dx, dy in ((0, -1), (-1, -1), (0, -2), (-1, -2)))
                below = lambda o: o is None or (o is not r and o.z < r.z)  # noqa: E731
                edge_dark = any(below(self._r(x + dx, y + dy)) for dx, dy in
                                [(k, 0) for k in range(1, r.band + 1)] + [(0, k) for k in range(1, r.band + 1)] + [(1, 1)])
                edge_light = r.light and any(below(self._r(x + dx, y + dy)) for dx, dy in ((-1, 0), (0, -1)))
                if cast or edge_dark:
                    c = dark
                elif edge_light:
                    c = light
                g[y][x] = c
        # ink: the edge of each piece against what lies below it (or the background)
        out = copy(g)
        for y in range(self.n):
            for x in range(self.n):
                r = self.reg[y][x]
                if r is None or not r.ink:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    o = self._r(x + dx, y + dy)
                    inside = 0 <= x + dx < self.n and 0 <= y + dy < self.n
                    if (o is None and inside) or (o is not None and o.z < r.z and o.group != r.group):
                        out[y][x] = "0"
                        break
        for x, y, c in self.after:
            put(out, x, y, c) if c != T else (0 <= x < self.n and 0 <= y < self.n and out[y].__setitem__(x, T))
        return out


class Face:
    """Feature placement for the 3/4 right-facing head; expressions only move pixels around these points."""

    def __init__(self, ne=(27, 27), fe=(40, 27), mouth=(41, 39), skin="qrs", iris="9a", white="1", brow="0", lid="0"):
        self.ne, self.fe, self.mouth, self.skin, self.iris, self.white, self.brow, self.lid = ne, fe, mouth, skin, iris, white, brow, lid


def draw_eyes(P: Portrait, f: Face, expr: str, big: bool = False) -> None:
    """Near eye 6 px wide (iris 3x2 with pupil and catchlight), far eye 4 px wide; both look slightly to the right."""
    x, y = f.ne
    X, _ = f.fe
    D, I = f.iris[0], f.iris[1]
    w, L = f.white, f.lid
    sd, sm = f.skin[0], f.skin[1]
    if expr == "happy":
        P.pxs([(x, y + 2), (x + 1, y + 1), (x + 2, y + 1), (x + 3, y + 1), (x + 4, y + 1), (x + 5, y + 2), (x - 1, y + 1)], L)
        P.pxs([(x + 1, y + 2), (x + 4, y + 2)], sd)
        P.pxs([(X, y + 2), (X + 1, y + 1), (X + 2, y + 1), (X + 3, y + 2)], L)
        return
    wide = expr == "surprised" or big
    # near eye
    P.pxs([(x + 1, y + 1), (x + 5, y + 1), (x + 1, y + 2), (x + 5, y + 2)], w)
    P.pxs([(x + 2, y + 1), (x + 2, y + 2), (x + 3, y + 2), (x + 4, y + 2)], I)
    P.pxs([(x + 2, y + 1)], D)
    P.px(x + 3, y + 1, "0")
    P.px(x + 4, y + 1, "1")
    if wide:
        P.pxs([(x + 1, y), (x + 2, y), (x + 3, y), (x + 4, y), (x + 5, y)], w)
        P.pxs([(x + 1, y - 1), (x + 2, y - 1), (x + 3, y - 1), (x + 4, y - 1), (x + 5, y - 1), (x, y)], L)
        if expr == "surprised":
            P.pxs([(x + 2, y + 1), (x + 4, y + 2)], w)
            P.px(x + 3, y + 2, "0")
    else:
        P.pxs([(x + 1, y), (x + 2, y), (x + 3, y), (x + 4, y), (x + 5, y), (x, y + 1)], L)
        P.px(x + 6, y + 1, L)
    if expr == "serious":
        P.pxs([(x + 1, y), (x + 2, y), (x + 3, y), (x + 4, y), (x + 5, y)], sm)
        P.pxs([(x + 1, y + 1), (x + 2, y + 1), (x + 3, y + 1), (x + 4, y + 1), (x + 5, y + 1)], L)
    if expr == "worried":
        P.pxs([(x + 1, y), (x + 2, y)], sm)
        P.pxs([(x + 1, y + 1), (x + 2, y + 1)], L)
    P.pxs([(x + 2, y + 3), (x + 3, y + 3), (x + 4, y + 3)], sd)
    # far eye
    P.pxs([(X + 3, y + 1), (X + 3, y + 2)], w)
    P.pxs([(X, y + 1), (X, y + 2), (X + 1, y + 2), (X + 2, y + 2)], I)
    P.px(X, y + 1, D)
    P.px(X + 1, y + 1, "0")
    P.px(X + 2, y + 1, "1")
    if wide:
        P.pxs([(X, y), (X + 1, y), (X + 2, y), (X + 3, y)], w)
        P.pxs([(X, y - 1), (X + 1, y - 1), (X + 2, y - 1), (X + 3, y - 1)], L)
        if expr == "surprised":
            P.pxs([(X, y + 1), (X + 2, y + 2)], w)
            P.px(X + 1, y + 2, "0")
    else:
        P.pxs([(X, y), (X + 1, y), (X + 2, y), (X + 3, y)], L)
    if expr == "serious":
        P.pxs([(X, y), (X + 1, y), (X + 2, y), (X + 3, y)], sm)
        P.pxs([(X, y + 1), (X + 1, y + 1), (X + 2, y + 1), (X + 3, y + 1)], L)
    if expr == "worried":
        P.pxs([(X + 2, y), (X + 3, y)], sm)
        P.pxs([(X + 2, y + 1), (X + 3, y + 1)], L)
    P.pxs([(X + 1, y + 3), (X + 2, y + 3)], sd)


def draw_brows(P: Portrait, f: Face, expr: str, thick: int = 1, color: str | None = None, determined: bool = False) -> None:
    c = color or f.brow
    x, y = f.ne
    X, _ = f.fe
    by = y - 3 - (1 if expr == "surprised" else 0)
    # (left end dy, right end dy) for the near brow; the far brow mirrors the tilt toward the nose
    tilt = {"neutral": (-1, 1) if determined else (0, 0), "happy": (-1, -1), "worried": (1, -2), "serious": (-1, 2),
            "surprised": (-2, -2)}[expr]
    for i, xx in enumerate(range(x, x + 7)):
        t = i / 6
        dy = round(tilt[0] * (1 - t) + tilt[1] * t)
        if expr == "happy" and 0 < i < 6:
            dy -= 1
        for k in range(thick):
            P.px(xx, by + dy + k, c)
    for i, xx in enumerate(range(X, X + 5)):
        t = i / 4
        dy = round(tilt[1] * (1 - t) + tilt[0] * t)
        if expr == "happy" and 0 < i < 4:
            dy -= 1
        for k in range(thick):
            P.px(xx, by + dy + k, c)


def draw_mouth(P: Portrait, f: Face, expr: str, lip: str | None = None) -> None:
    mx, my = f.mouth
    d = f.skin[0]
    lip = lip or "q"
    if expr == "neutral":
        P.pxs([(mx - 2, my), (mx - 1, my), (mx, my), (mx + 1, my)], d)
        P.px(mx - 2, my, "0") if False else None
        P.pxs([(mx - 1, my + 1), (mx, my + 1)], f.skin[2])
    elif expr == "happy":
        P.pxs([(mx - 3, my - 1), (mx - 2, my), (mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my - 1)], "0")
        P.pxs([(mx - 2, my + 1), (mx - 1, my + 1), (mx, my + 1), (mx + 1, my + 1)], d)
    elif expr == "worried":
        P.pxs([(mx - 2, my + 1), (mx - 1, my), (mx, my), (mx + 1, my + 1)], d)
        P.px(mx - 1, my, "0")
    elif expr == "serious":
        P.pxs([(mx - 3, my), (mx - 2, my), (mx - 1, my), (mx, my), (mx + 1, my)], "0")
        P.px(mx + 2, my + 1, d)
    elif expr == "surprised":
        mx -= 1
        P.pxs([(mx - 1, my - 1), (mx, my - 1), (mx - 2, my), (mx + 1, my), (mx - 1, my + 1), (mx, my + 1)], d)
        P.pxs([(mx - 1, my), (mx, my)], "8")


# the shared head shape (3/4 view facing right) and helpers to move it
FACE = [(22, 18), (27, 13), (35, 11), (42, 13), (46, 18), (47, 25), (47, 29), (49, 33), (47, 35), (46, 38), (44, 42),
        (39, 45), (33, 46), (28, 44), (24, 40), (21, 33), (20, 25)]


def tr(pts, dx: float = 0, dy: float = 0, s: float = 1.0, cx: float = 34, cy: float = 30):
    return [((x - cx) * s + cx + dx, (y - cy) * s + cy + dy) for x, y in pts]


def nose(P: Portrait, f: Face, dx: int = 0, dy: int = 0) -> None:
    d = f.skin[0]
    P.pxs([(46 + dx, 30 + dy), (46 + dx, 31 + dy), (45 + dx, 33 + dy)], d)
    P.px(44 + dx, 34 + dy, d)


def blush(P: Portrait, pts, c: str) -> None:
    P.pxs(pts, c)


def sweat(P: Portrait, x: int, y: int) -> None:
    P.pxs([(x + 1, y), (x, y + 1), (x + 2, y + 1), (x, y + 2), (x + 2, y + 2), (x + 1, y + 3)], "0")
    P.pxs([(x + 1, y + 1), (x + 1, y + 2)], "o")


def base_head(P: Portrait, skin: str, s: float = 1.0, dx: float = 0, dy: float = 0, neck_w: tuple[int, int] = (26, 38)) -> dict:
    R = {}
    R["neck"] = P.region("neck", skin, "skin", ink=True)
    P.poly(tr([(neck_w[0], 38), (neck_w[1], 40), (neck_w[1], 54), (neck_w[0], 54)], dx, dy, s), R["neck"])
    return R


def head_skin(P: Portrait, skin: str, s: float = 1.0, dx: float = 0, dy: float = 0, ear=True) -> dict:
    R = {}
    R["face"] = P.region("face", skin, "skin")
    P.poly(tr(FACE, dx, dy, s), R["face"])
    if ear:
        R["ear"] = P.region("ear", skin, "ear", band=1)
        (ex, ey), = tr([(22, 31)], dx, dy, s)
        P.ellipse(ex, ey, 3 * s, 4 * s, R["ear"])
    return R


# ---------------------------------------------------------------- per-character portraits
def portrait_totoy(expr: str) -> Grid:
    P = Portrait()
    skin = "qrs"
    sh = P.region("shoulders", skin, "skin")
    P.poly([(2, 64), (5, 55), (13, 50), (24, 47), (40, 47), (51, 50), (59, 56), (62, 64)], sh)
    shirt = P.region("shirt", "9ab", "shirt")
    P.poly([(22, 48), (44, 48), (40, 58), (34, 64), (28, 64), (24, 56)], shirt)
    base_head(P, skin)
    vest = P.region("vest", "efg", "vest")
    P.poly([(12, 64), (13, 55), (19, 49), (26, 47), (29, 52), (33, 64)], vest)
    vest2 = P.region("vest2", "efg", "vest")
    P.poly([(37, 64), (40, 54), (42, 47), (47, 49), (53, 52), (54, 64)], vest2)
    strap = P.region("strap", "89a", "strap", band=1)
    P.line([(52, 48), (20, 64)], 4, strap)
    # back spikes behind the head
    hb = P.region("hairback", "89a", "hair")
    P.poly([(21, 34), (15, 32), (8, 33), (13, 27), (6, 22), (14, 20), (10, 12), (19, 14), (19, 6), (26, 10), (28, 2),
            (33, 8), (38, 1), (41, 8), (47, 4), (46, 11), (52, 10), (48, 16), (46, 19), (30, 16), (23, 20)], hb)
    H = head_skin(P, skin)
    band = P.region("band", "0ef", "band", band=1)
    P.poly([(19, 19), (46, 13), (48, 17), (21, 24)], band)
    tail = P.region("bandtail", "0ef", "band", band=1)
    P.poly([(20, 20), (12, 22), (5, 28), (8, 29), (14, 26), (21, 24)], tail)
    fr = P.region("fringe", "89a", "hair")
    P.poly([(25, 21), (27, 27), (29, 22), (32, 26), (33, 21), (37, 25), (38, 20), (41, 23), (42, 18)], fr)
    P.poly([(21, 23), (20, 31), (23, 29), (24, 22)], fr)
    f = Face(ne=(27, 27), fe=(40, 27), mouth=(41, 40), skin="qrs", iris="8a", white="j")
    draw_brows(P, f, expr, thick=2 if expr in ("serious", "neutral") else 1, determined=True)
    draw_eyes(P, f, expr)
    nose(P, f)
    draw_mouth(P, f, expr)
    # band knot highlight and hair strands
    P.pxs([(24, 20), (30, 18), (36, 17), (42, 16)], "g")
    P.pxs([(15, 21), (20, 12), (28, 6), (37, 6), (44, 9)], "a")
    if expr == "worried":
        sweat(P, 46, 20)
    if expr == "happy":
        blush(P, [(26, 33), (27, 33), (41, 33), (42, 33)], "q")
    # collarbone and chest line
    P.pxs([(30, 50), (31, 51), (35, 51), (36, 50)], "8")
    return P.render()


def portrait_mira(expr: str) -> Grid:
    P = Portrait()
    skin = "rs1"
    coat = P.region("coat", "lmn", "coat")
    P.poly([(3, 64), (6, 55), (14, 50), (24, 48), (40, 48), (50, 50), (58, 56), (61, 64)], coat)
    hb = P.region("hairback", "9ab", "hair")
    P.poly([(20, 16), (14, 26), (12, 40), (9, 52), (13, 58), (19, 52), (22, 40), (26, 24)], hb)
    base_head(P, skin)
    strap = P.region("strap", "9ab", "strap", band=1)
    P.line([(50, 49), (22, 64)], 4, strap)
    H = head_skin(P, skin)
    hair = P.region("hair", "9ab", "hair")
    P.poly([(19, 30), (18, 20), (22, 13), (30, 8), (39, 8), (45, 12), (49, 19), (47, 24), (44, 20), (42, 25), (39, 19),
            (36, 24), (33, 18), (29, 23), (26, 19), (24, 26), (22, 34)], hair)
    pencil = P.region("pencil", "bcd", "pencil", band=1)
    P.line([(15, 27), (26, 21)], 2, pencil)
    scarf = P.region("scarf", "tup", "scarf")
    P.poly([(21, 46), (26, 42), (36, 43), (44, 46), (45, 51), (38, 55), (27, 55), (20, 51)], scarf)
    tail = P.region("scarftail", "tup", "scarf2")
    P.poly([(36, 52), (43, 51), (44, 62), (40, 64), (36, 62)], tail)
    comp = P.region("compass", "bcd", "compass", band=1)
    P.ellipse(26, 60, 3, 3, comp)
    f = Face(ne=(27, 27), fe=(40, 27), mouth=(41, 39), skin="qrs", iris="t4", white="1")
    draw_brows(P, f, expr, color="9")
    draw_eyes(P, f, expr)
    nose(P, Face(skin="rs1"))
    draw_mouth(P, Face(mouth=(41, 39), skin="qs1"), expr)
    # freckles, pencil tip, hair strands, compass needle
    P.pxs([(26, 33), (28, 34), (30, 33), (39, 33), (41, 34)], "r")
    P.pxs([(14, 28), (15, 28)], "0")
    P.pxs([(24, 13), (31, 10), (38, 11), (44, 15), (15, 40), (13, 48)], "b")
    P.strand([(31, 10), (26, 14), (22, 21)], "9")
    P.strand([(40, 10), (36, 13), (34, 17)], "9")
    P.strand([(18, 30), (15, 42), (12, 51)], "9")
    P.pxs([(26, 59), (26, 60)], "t")
    if expr == "worried":
        sweat(P, 46, 19)
    if expr == "happy":
        blush(P, [(25, 32), (26, 32), (41, 32), (42, 32)], "r")
    return P.render()


def portrait_tovan(expr: str) -> Grid:
    P = Portrait()
    skin = "qrs"
    shirt = P.region("shirt", "hij", "shirt")
    P.poly([(0, 64), (1, 54), (10, 48), (22, 45), (42, 45), (54, 48), (63, 54), (64, 64)], shirt)
    base_head(P, skin, neck_w=(23, 41))
    apron = P.region("apron", "abc", "apron")
    P.poly([(22, 53), (45, 53), (47, 64), (20, 64)], apron)
    st = P.region("straps", "89a", "strap", band=1)
    P.line([(24, 53), (13, 48)], 3, st)
    P.line([(43, 53), (52, 48)], 3, st)
    H = head_skin(P, skin, s=1.04)
    hair = P.region("hair", "89a", "hair")
    P.poly([(20, 29), (19, 18), (24, 11), (33, 8), (42, 10), (47, 16), (47, 20), (41, 16), (30, 16), (24, 19), (23, 27)], hair)
    beard = P.region("beard", "89a", "beard")
    P.poly([(22, 31), (24, 39), (29, 45), (35, 48), (42, 46), (47, 40), (48, 36), (44, 36), (40, 38), (35, 37), (31, 37),
            (28, 33), (25, 29)], beard)
    mus = P.region("mustache", "89a", "beard2", band=1)
    P.poly([(37, 36), (42, 35), (46, 35), (46, 38), (42, 38), (38, 39)], mus)
    f = Face(ne=(27, 26), fe=(40, 26), mouth=(42, 41), skin="qrs", iris="80", white="j")
    draw_brows(P, f, expr, thick=2, color="8")
    draw_eyes(P, f, expr)
    nose(P, f)
    # mouth inside the beard
    mx, my = f.mouth
    if expr == "happy":
        P.pxs([(mx - 3, my - 1), (mx - 2, my), (mx - 1, my), (mx, my), (mx + 1, my), (mx + 2, my - 1)], "0")
        P.pxs([(mx - 1, my + 1), (mx, my + 1)], "1")
    elif expr == "surprised":
        P.pxs([(mx - 1, my), (mx, my), (mx - 1, my + 1), (mx, my + 1)], "0")
    elif expr == "worried":
        P.pxs([(mx - 2, my + 1), (mx - 1, my), (mx, my), (mx + 1, my + 1)], "0")
    else:
        P.pxs([(mx - 2, my), (mx - 1, my), (mx, my), (mx + 1, my)], "0")
    # soot smudges, hair texture, apron stitch
    P.pxs([(25, 32), (26, 33), (27, 32), (33, 12), (34, 13)], "g")
    P.pxs([(24, 15), (30, 11), (38, 11), (27, 41), (33, 45), (40, 44)], "a")
    P.pxs([(30, 56), (31, 56), (32, 56), (33, 56), (34, 56)], "9")
    if expr == "worried":
        sweat(P, 47, 19)
    return P.render()


def portrait_edda(expr: str) -> Grid:
    P = Portrait()
    skin = "rs1"
    shawl = P.region("shawl", "345", "shawl")
    P.poly([(0, 64), (3, 54), (12, 48), (24, 46), (40, 46), (52, 48), (61, 54), (64, 64)], shawl)
    bun = P.region("bun", "ij1", "hairb")
    P.ellipse(16, 15, 6, 5, bun)
    base_head(P, skin, neck_w=(27, 37))
    dress = P.region("dress", "lvv", "dress", band=1)
    P.poly([(26, 47), (40, 47), (37, 54), (29, 54)], dress)
    H = head_skin(P, skin, s=0.97, dy=1)
    hair = P.region("hair", "ij1", "hair")
    P.poly([(19, 32), (18, 20), (23, 13), (32, 9), (41, 10), (46, 15), (48, 22), (45, 19), (43, 21), (40, 17), (36, 17),
            (32, 16), (28, 19), (25, 23), (24, 28), (22, 34)], hair)
    cord = P.region("cord", "9ab", "cord", band=1, ink=False)
    P.line([(29, 47), (33, 55), (37, 47)], 1, cord)
    frag = P.region("fragment", "tup", "frag", band=1)
    P.poly([(33, 53), (36, 57), (33, 61), (30, 57)], frag)
    f = Face(ne=(27, 28), fe=(40, 28), mouth=(41, 40), skin="rs1", iris="tu", white="1", brow="i")
    draw_brows(P, f, expr, thick=1, color="h")
    draw_eyes(P, f, expr)
    nose(P, Face(skin="rs1"), dy=1)
    draw_mouth(P, Face(mouth=(41, 40), skin="qs1"), expr)
    # wrinkles, crow's feet, charms on the shawl (leaves and a feather), fragment glow
    P.pxs([(26, 31), (25, 30), (37, 36), (38, 37), (30, 21), (32, 21)], "r")
    P.pxs([(33, 56), (32, 57)], "p")
    for (lx, ly) in ((12, 55), (52, 56)):
        P.pxs([(lx, ly), (lx + 1, ly - 1), (lx + 1, ly), (lx + 2, ly - 1), (lx, ly + 1)], "6")
        P.pxs([(lx + 1, ly + 1), (lx + 2, ly)], "7")
        P.px(lx - 1, ly + 1, "0")
    P.pxs([(18, 58), (19, 57), (20, 56), (21, 55), (18, 59), (19, 58), (20, 57)], "1")
    P.pxs([(17, 60), (17, 59)], "0")
    # feather pin in the bun
    P.pxs([(9, 7), (10, 8), (11, 9), (12, 10), (10, 7), (11, 8), (12, 9)], "1")
    P.pxs([(8, 6), (13, 11)], "0")
    P.pxs([(27, 12), (35, 11), (42, 14)], "1")
    P.strand([(31, 11), (26, 15), (22, 22), (21, 28)], "i")
    P.strand([(38, 11), (32, 13), (28, 17)], "i")
    P.strand([(44, 15), (39, 13)], "i")
    P.pxs([(13, 13), (14, 12), (15, 12), (17, 12), (18, 13), (18, 15), (17, 16), (15, 16), (14, 15)], "i")
    P.pxs([(15, 14), (16, 14)], "1")
    if expr == "worried":
        sweat(P, 46, 20)
    if expr == "happy":
        blush(P, [(25, 33), (26, 33), (41, 33), (42, 33)], "r")
    return P.render()


def portrait_child(expr: str = "neutral") -> Grid:
    P = Portrait()
    skin = "rs1"
    tun = P.region("tunic", "567", "tunic")
    P.poly([(8, 64), (11, 57), (19, 53), (28, 52), (40, 52), (48, 54), (54, 58), (56, 64)], tun)
    base_head(P, skin, s=1.05, dy=4)
    H = head_skin(P, skin, s=1.08, dy=5)
    hair = P.region("hair", "9ab", "hair")
    P.poly([(17, 37), (15, 30), (12, 26), (17, 24), (14, 17), (21, 17), (21, 10), (28, 12), (31, 5), (35, 11), (41, 7),
            (42, 13), (49, 13), (47, 18), (50, 23), (45, 23), (44, 19), (40, 25), (36, 20), (33, 26), (29, 21), (26, 26),
            (24, 25), (22, 35)], hair)
    f = Face(ne=(26, 31), fe=(40, 31), mouth=(41, 44), skin="qs1", iris="9a", white="1")
    draw_brows(P, f, "happy" if expr == "neutral" else expr, color="9")
    draw_eyes(P, f, expr, big=True)
    nose(P, Face(skin="rs1"), dx=1, dy=4)
    draw_mouth(P, f, "happy" if expr == "neutral" else expr)
    P.pxs([(25, 37), (27, 38), (29, 37), (40, 37), (42, 38)], "r")
    P.pxs([(23, 15), (30, 10), (39, 12), (45, 16)], "b")
    # lantern glow from below: a warm rim on the chin
    P.pxs([(34, 50), (35, 50), (36, 50), (37, 49), (38, 49)], "1")
    return P.render()


def portrait_farmer(expr: str = "neutral") -> Grid:
    P = Portrait()
    skin = "qrs"
    shirt = P.region("shirt", "j11", "shirt")
    P.poly([(3, 64), (6, 55), (14, 50), (24, 47), (40, 47), (50, 50), (58, 56), (61, 64)], shirt)
    base_head(P, skin, dy=2)
    ov = P.region("overalls", "lmn", "ov")
    P.poly([(20, 58), (46, 58), (48, 64), (18, 64)], ov)
    st = P.region("straps", "lmn", "ovs", band=1)
    P.line([(22, 58), (17, 50)], 3, st)
    P.line([(44, 58), (49, 50)], 3, st)
    H = head_skin(P, skin, dy=3)
    side = P.region("sidehair", "hij", "hair")
    P.poly([(19, 22), (18, 34), (22, 36), (24, 24)], side)
    crown = P.region("crown", "bcd", "hat")
    P.poly([(19, 16), (22, 5), (31, 2), (41, 4), (45, 15)], crown)
    hband = P.region("hatband", "9ab", "hatband", band=1)
    P.poly([(19, 15), (45, 13), (45, 16), (19, 18)], hband)
    brim = P.region("brim", "bcd", "brim")
    P.ellipse(32, 18, 30, 5, brim)
    mus = P.region("mustache", "hij", "mus", band=1)
    P.poly([(36, 38), (42, 36), (48, 37), (47, 40), (41, 40), (37, 41)], mus)
    f = Face(ne=(27, 29), fe=(40, 29), mouth=(42, 43), skin="qrs", iris="9a", white="j")
    draw_brows(P, f, "neutral", thick=2, color="i")
    draw_eyes(P, f, "serious")
    nose(P, f, dy=3)
    P.pxs([(40, 43), (41, 43), (42, 43)], "q")
    P.pxs([(25, 33), (24, 32), (26, 36), (27, 37), (35, 38), (36, 39), (31, 24), (33, 24), (35, 24)], "q")
    P.pxs([(26, 6), (33, 4), (40, 7), (12, 18), (20, 20), (44, 20), (52, 18)], "d")
    P.pxs([(24, 61), (42, 61)], "1")
    return P.render()


def portrait_basket(expr: str = "neutral") -> Grid:
    P = Portrait()
    skin = "rs1"
    dress = P.region("dress", "tuu", "dress")
    P.poly([(4, 64), (7, 55), (15, 50), (24, 48), (40, 48), (50, 50), (57, 56), (60, 64)], dress)
    sb = P.region("scarfback", "lvv", "scarf")
    P.poly([(20, 14), (12, 28), (10, 44), (16, 50), (24, 46), (26, 26)], sb)
    base_head(P, skin)
    collar = P.region("collar", "j11", "collar", band=1)
    P.poly([(22, 49), (30, 52), (34, 58), (38, 52), (45, 49), (44, 54), (34, 62), (23, 54)], collar)
    H = head_skin(P, skin)
    fr = P.region("fringe", "9ab", "hair")
    P.poly([(22, 22), (30, 17), (40, 16), (46, 19), (43, 22), (38, 20), (32, 22), (26, 26), (23, 30)], fr)
    scarf = P.region("scarf", "lvv", "scarf2")
    P.poly([(18, 30), (17, 18), (22, 11), (31, 7), (41, 8), (47, 13), (49, 19), (44, 17), (37, 15), (29, 16), (23, 21),
            (21, 31)], scarf)
    knot = P.region("knot", "lvv", "knot", band=1)
    P.ellipse(15, 22, 4, 3, knot)
    P.poly([(12, 23), (5, 30), (9, 31), (15, 25)], knot)
    f = Face(ne=(27, 27), fe=(40, 27), mouth=(41, 39), skin="qrs", iris="9a", white="1")
    draw_brows(P, f, "happy", color="9")
    draw_eyes(P, f, "neutral")
    nose(P, Face(skin="rs1"))
    draw_mouth(P, Face(mouth=(41, 39), skin="qs1"), "happy")
    P.pxs([(25, 32), (26, 32), (41, 32), (42, 32)], "r")
    P.pxs([(24, 13), (32, 10), (40, 11), (13, 34), (12, 42)], "o")
    P.pxs([(21, 35), (21, 36)], "o")  # small earring
    return P.render()


PORTRAITS = {
    "totoy": (portrait_totoy, EXPRESSIONS),
    "mira": (portrait_mira, EXPRESSIONS),
    "tovan": (portrait_tovan, EXPRESSIONS),
    "edda": (portrait_edda, EXPRESSIONS),
    "villager_child": (portrait_child, ("neutral",)),
    "villager_farmer": (portrait_farmer, ("neutral",)),
    "villager_basket": (portrait_basket, ("neutral",)),
}


def all_portraits() -> dict[str, Grid]:
    out = {}
    for name, (fn, exprs) in PORTRAITS.items():
        for e in exprs:
            out[f"portrait_{name}_{e}"] = fn(e)
    return out


# ----------------------------------------------------------------------------------------------- dialogue UI
# The shared pop-up frame of presentation/arena/ui_panel.gd, re-drawn here as grids (same layers, same theme symbols).
THEME = {"accent": "v", "bevel_hi": "f", "bevel_lo": "8", "gem": "1", "plate": "k"}  # the "menu" theme (lilac)
GEM = ["..0..", ".0a0.", "0aga0", ".0a0.", "..0.."]


def rect(g: Grid, x: int, y: int, w: int, h: int, c: str) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(g, xx, yy, c)


def frame_rect(g: Grid, x: int, y: int, w: int, h: int, c: str) -> None:
    rect(g, x, y, w, 1, c)
    rect(g, x, y + h - 1, w, 1, c)
    rect(g, x, y, 1, h, c)
    rect(g, x + w - 1, y, 1, h, c)


def gem(g: Grid, cx: int, cy: int, t: dict = THEME) -> None:
    for j, row in enumerate(GEM):
        for i, ch in enumerate(row):
            if ch != ".":
                put(g, cx - 2 + i, cy - 2 + j, "0" if ch == "0" else (t["gem"] if ch == "g" else t["accent"]))


def panel(g: Grid, x: int, y: int, w: int, h: int, t: dict = THEME, fill: str = "0", gems: bool = True) -> None:
    rect(g, x, y, w, h, "0")
    frame_rect(g, x + 1, y + 1, w - 2, h - 2, t["accent"])
    rect(g, x + 3, y + 3, w - 6, h - 6, fill)
    rect(g, x + 3, y + 3, w - 6, 1, t["bevel_hi"])
    rect(g, x + 3, y + 3, 1, h - 6, t["bevel_hi"])
    rect(g, x + 3, y + h - 4, w - 6, 1, t["bevel_lo"])
    rect(g, x + w - 4, y + 3, 1, h - 6, t["bevel_lo"])
    if gems:
        for cx, cy in ((x + 1, y + 1), (x + w - 2, y + 1), (x + 1, y + h - 2), (x + w - 2, y + h - 2)):
            gem(g, cx, cy, t)


BOX_W, BOX_H = 232, 56
PLATE_W, PLATE_H = 72, 16
PFRAME = 72


def ui_box() -> Grid:
    g = blank(BOX_W, BOX_H)
    panel(g, 0, 0, BOX_W, BOX_H)
    # a quiet inner rule under the top bevel, like the description box of the character menu
    for xx in range(8, BOX_W - 8, 2):
        put(g, xx, 5, "e")
    return g


def ui_nameplate() -> Grid:
    g = blank(PLATE_W, PLATE_H)
    w, h = PLATE_W, PLATE_H
    rect(g, 2, 0, w - 4, h, "0")
    rect(g, 3, 1, w - 6, h - 2, THEME["accent"])
    rect(g, 4, 2, w - 8, h - 4, THEME["plate"])
    rect(g, 4, 2, w - 8, 1, "l")
    rect(g, 4, h - 3, w - 8, 1, "0")
    # notched ends (like ui_panel.banner) and a small gem on each end
    for k in range(3):
        for side in (2 + k, w - 3 - k):
            put(g, side, h // 2 - (2 - k) - 1, "0")
            put(g, side, h // 2 + (2 - k), "0")
    gem(g, 2, h // 2)
    gem(g, w - 3, h // 2)
    return g


def ui_portrait_frame() -> Grid:
    g = blank(PFRAME, PFRAME)
    panel(g, 0, 0, PFRAME, PFRAME, fill="e")
    # inner window 64x64 at (4,4): soft backdrop, a lighter disc behind the head
    rect(g, 4, 4, 64, 64, "e")
    m = Image.new("L", (64, 64), 0)
    ImageDraw.Draw(m).ellipse([10, 4, 58, 52], fill=1)
    mp = m.load()
    for y in range(64):
        for x in range(64):
            if mp[x, y]:
                put(g, 4 + x, 4 + y, "f")
    # repaint the 1 px frame layers over the window edges
    frame_rect(g, 3, 3, 66, 66, "0")
    return g


def ui_portrait_window() -> tuple[int, int, int, int]:
    return (4, 4, 64, 64)


def ui_next(n: int) -> Grid:
    g = blank(8, 8)
    dy = [0, 1, 1][n]
    c = ["1", "1", "i"][n]
    arrow = ["11111", ".111.", "..1.."]
    for j, r in enumerate(arrow):
        for i, ch in enumerate(r):
            if ch != ".":
                put(g, 1 + i, 2 + dy + j, c)
    if n == 0:
        put(g, 2, 2, "p")
    return outline(g)


def ui_choice() -> Grid:
    g = blank(8, 8)
    shape = ["u...", "uu..", "upu.", "uuuu", "upu.", "uu..", "u..."]
    shape = ["t...", "tu..", "tpu.", "tuuu", "tuu.", "tu..", "t..."]
    for j, r in enumerate(shape):
        for i, ch in enumerate(r):
            if ch != ".":
                put(g, 2 + i, j, {"t": "t", "u": "u", "p": "p"}[ch])
    return outline(g)


def ui_choice_bar() -> Grid:
    """Highlight under the selected choice line (stretchable, 8 px tall)."""
    g = blank(64, 8)
    rect(g, 0, 1, 64, 6, "k")
    rect(g, 0, 1, 64, 1, "l")
    rect(g, 0, 7, 64, 1, "0")
    for x in range(0, 64, 4):
        put(g, x, 6, "e")
    return g


def all_ui() -> dict[str, Grid]:
    d = {"ui_dialogue_box": ui_box(), "ui_dialogue_nameplate": ui_nameplate(), "ui_dialogue_portrait_frame": ui_portrait_frame()}
    for i in range(3):
        d[f"ui_dialogue_next_{i + 1}"] = ui_next(i)
    d["ui_dialogue_choice"] = ui_choice()
    d["ui_dialogue_choice_bar"] = ui_choice_bar()
    return d


UI_SLICE = {
    "ui_dialogue_box": {"nine_slice": [8, 8, 8, 8], "note": "stretch the middle; corners hold the gems"},
    "ui_dialogue_nameplate": {"nine_slice": [6, 6, 6, 6], "note": "stretch horizontally to fit the name"},
    "ui_dialogue_portrait_frame": {"window": list(ui_portrait_window()), "note": "64x64 portrait goes into the window"},
    "ui_dialogue_choice_bar": {"nine_slice": [0, 0, 0, 0], "note": "tile/stretch horizontally behind the selected choice"},
}


# ----------------------------------------------------------------------------------------------- atlases and previews
def save_atlas(items: list[tuple[str, Grid, dict]], cols: int, path: Path, meta: dict) -> dict:
    cw = max(len(g[0]) for _, g, _ in items)
    ch = max(len(g) for _, g, _ in items)
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    frames = {}
    for i, (name, g, extra) in enumerate(items):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.alpha_composite(to_image(g), (x, y))
        frames[name] = {"x": x, "y": y, "w": len(g[0]), "h": len(g), **extra}
    sheet.save(path)
    data = {**meta, "image": path.name, "frames": frames}
    path.with_suffix(".json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    return data


def font(path: Path, size: int, weight: int | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), size)
    if weight is not None:
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
    return f


def hard_text(im: Image.Image, xy: tuple[float, float], text: str, f: ImageFont.FreeTypeFont, rgb: tuple, shadow: tuple | None = None) -> None:
    """Text with hard alpha (threshold), the cap top at xy[1] (like Hud.lettering)."""
    cap_top = f.getbbox("H")[1]
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).text((round(xy[0]), round(xy[1] - cap_top)), text, font=f, fill=255)
    mask = mask.point(lambda v: 255 if v >= 112 else 0)
    if shadow is not None:
        sh = Image.new("L", im.size, 0)
        sh.paste(mask, (max(1, f.size // 9), max(1, f.size // 9)))
        im.paste(Image.new("RGBA", im.size, shadow + (255,)), (0, 0), sh)
    im.paste(Image.new("RGBA", im.size, rgb + (255,)), (0, 0), mask)


def rgb(c: str) -> tuple:
    return PAL.by_symbol[c]


def labelled_sheet(groups: list[tuple[str, list[tuple[str, Image.Image]]]], bg: tuple, zoom: int, cols: int) -> Image.Image:
    lab = font(PIXEL_FONT, 22)
    small = font(PIXEL_FONT, 13)
    blocks = []
    for title, ims in groups:
        cw = max(i.width for _, i in ims)
        ch = max(i.height for _, i in ims)
        n = len(ims)
        c = min(cols, n)
        r = (n + c - 1) // c
        cellw, cellh = max((cw + 2) * zoom, 80), (ch + 2) * zoom + 18
        block = Image.new("RGBA", (max(c * cellw, 900), r * cellh + 34), bg + (255,))
        hard_text(block, (6, 8), title, lab, rgb("1"))
        for i, (name, im) in enumerate(ims):
            x0, y0 = (i % c) * cellw, 34 + (i // c) * cellh
            big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
            block.alpha_composite(big, (x0 + zoom, y0))
            hard_text(block, (x0 + zoom, y0 + ch * zoom + zoom + 3), name, small, rgb("j"))
        blocks.append(block)
    W = max(b.width for b in blocks)
    H = sum(b.height + 10 for b in blocks)
    sheet = Image.new("RGBA", (W, H), bg + (255,))
    y = 0
    for b in blocks:
        sheet.alpha_composite(b, (0, y))
        y += b.height + 10
    return sheet


def shadow_under(im: Image.Image, fx: int, fy: int, w: int, c: str = "3") -> None:
    d = ImageDraw.Draw(im)
    d.ellipse([fx - w // 2, fy - 2, fx + w // 2, fy + 1], fill=rgb(c) + (255,))


def hero_frame(name: str) -> tuple[Image.Image, int, int]:
    s = artlib.parse_sprite(ROOT / "art" / "src" / f"{name}.txt")
    return artlib.render(s, PAL), s.anchor[0], s.anchor[1]


def village_bg(w: int = 320, h: int = 180) -> Image.Image:
    """Flat-colour stand-in for the village (no background art yet): grass, a dirt path, a cottage, two trees."""
    im = Image.new("RGBA", (w, h), rgb("4") + (255,))
    d = ImageDraw.Draw(im)
    for i in range(60):
        x, y = (i * 53) % w, (i * 37) % h
        d.rectangle([x, y, x + 1, y], fill=rgb("5") + (255,))
    d.rectangle([0, 92, w, 118], fill=rgb("c") + (255,))
    d.rectangle([0, 92, w, 93], fill=rgb("b") + (255,))
    d.rectangle([0, 117, w, 118], fill=rgb("b") + (255,))
    # cottage
    d.rectangle([196, 30, 268, 78], fill=rgb("d") + (255,))
    d.polygon([(188, 34), (232, 6), (276, 34)], fill=rgb("a") + (255,))
    d.rectangle([188, 32, 276, 36], fill=rgb("9") + (255,))
    d.rectangle([226, 52, 238, 78], fill=rgb("9") + (255,))
    d.rectangle([204, 46, 216, 56], fill=rgb("o") + (255,))
    d.rectangle([248, 46, 260, 56], fill=rgb("o") + (255,))
    d.rectangle([196, 76, 268, 80], fill=rgb("b") + (255,))
    for cx, cy, r in ((40, 40, 22), (96, 22, 16), (300, 60, 18)):
        d.rectangle([cx - 2, cy + r - 6, cx + 2, cy + r + 6], fill=rgb("9") + (255,))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgb("2") + (255,))
        d.ellipse([cx - r + 2, cy - r + 1, cx + r - 3, cy + r - 4], fill=rgb("3") + (255,))
        d.ellipse([cx - r + 5, cy - r + 4, cx + r - 9, cy + r - 12], fill=rgb("4") + (255,))
    return im


# dialogue layout at 320x180 (game pixels)
LAYOUT = {
    "portrait_frame": (8, 100),       # 72x72
    "box": (80, 116),                 # 232x56
    "nameplate": (88, 106),           # 72x16, overlaps the box top
    "text": (90, 128),                # first line cap top; 3 lines, 12 px apart, up to x = 300
    "line_step": 12,
    "next": (298, 160),               # 8x8, blinks while waiting for ENTER
    "choice": (94, 0),                # marker x; y follows the line
}


def mockup(lines: list[str], speaker: str, portrait: Grid, scale: int, choices: list[str] | None = None, sel: int = 0,
           next_frame: int = 0) -> Image.Image:
    base = village_bg()
    # the two speakers standing on the path: Totoy and Mira (Mira mirrored to face him)
    hero, hax, hay = hero_frame("hero2_idle_right_1")
    shadow_under(base, 120, 108, 14)
    base.alpha_composite(hero, (120 - hax, 108 - hay))
    mira = to_image(npc_frames(NPCS[0])["idle"][0]).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    mfx = 150
    shadow_under(base, mfx, 108, 12)
    base.alpha_composite(mira, (mfx - (CW - 1 - NPCS[0].hip[0]), 108 - ANCHOR_Y))
    ui = blank(320, 180)
    px_, py_ = LAYOUT["portrait_frame"]
    paste(ui, ui_portrait_frame(), px_, py_)
    paste(ui, portrait, px_ + 4, py_ + 4)
    bx, by = LAYOUT["box"]
    paste(ui, ui_box(), bx, by)
    nx, ny = LAYOUT["nameplate"]
    paste(ui, ui_nameplate(), nx, ny)
    tx, ty = LAYOUT["text"]
    step = LAYOUT["line_step"]
    if choices:
        for i, _ in enumerate(choices):
            yy = ty + (len(lines) + i) * step
            if i == sel:
                bar = ui_choice_bar()
                for xx in range(tx + 8, 302):
                    for j in range(8):
                        put(ui, xx, yy - 2 + j, bar[j][(xx - tx) % 64])
                paste(ui, ui_choice(), tx, yy - 1)
    else:
        ax, ay = LAYOUT["next"]
        paste(ui, ui_next(next_frame), ax, ay)
    base.alpha_composite(to_image(ui))
    im = base.resize((320 * scale, 180 * scale), Image.NEAREST)
    body = font(PIXEL_FONT, 9 * scale)
    name_f = font(MENU_FONT, 9 * scale, 900)
    nm = speaker.upper()
    wname = name_f.getlength(nm) / scale
    hard_text(im, ((nx + PLATE_W / 2 - wname / 2) * scale, (ny + 4) * scale), nm, name_f, rgb("1"))
    for i, line in enumerate(lines):
        hard_text(im, (tx * scale, (ty + i * step) * scale), line, body, rgb("1"))
    if choices:
        for i, c in enumerate(choices):
            hard_text(im, ((tx + 10) * scale, (ty + (len(lines) + i) * step) * scale), c, body, rgb("1" if i == sel else "i"))
    return im


# ----------------------------------------------------------------------------------------------- write everything
def write_all() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # 1. NPC atlas: one row per character, idle | walk | talk
    items = []
    npc_meta = {}
    all_frames = {}
    for npc in NPCS:
        fr = npc_frames(npc)
        all_frames[npc.name] = fr
        npc_meta[npc.name] = {"states": {st: {"frames": FRAMES[st], "ticks": TICKS[st]} for st in npc.states}}
        for st in npc.states:
            for i, g in enumerate(fr[st]):
                items.append((f"npc_{npc.name}_{st}_right_{i + 1}", g, {"ax": npc.hip[0], "ay": ANCHOR_Y}))
    npc_items_rows = []
    # place rows by character (13 columns max)
    cols = 13
    rows_items = []
    for npc in NPCS:
        row = [it for it in items if it[0].startswith(f"npc_{npc.name}_")]
        row += [None] * (cols - len(row))
        rows_items += row
    sheet = Image.new("RGBA", (cols * CW, len(NPCS) * CH), (0, 0, 0, 0))
    frames = {}
    for i, it in enumerate(rows_items):
        if it is None:
            continue
        name, g, extra = it
        x, y = (i % cols) * CW, (i // cols) * CH
        sheet.alpha_composite(to_image(g), (x, y))
        frames[name] = {"x": x, "y": y, "w": CW, "h": CH, **extra}
    sheet.save(OUT / "npc_sprites_v1.png")
    (OUT / "npc_sprites_v1.json").write_text(json.dumps({
        "version": 1,
        "note": "Review art, not wired in. Right-facing side view; left = mirror around the anchor (like hero2_*). Anchor = feet, one row under the soles. Ticks are suggestions at 60 ticks/s.",
        "cell": [CW, CH], "image": "npc_sprites_v1.png", "characters": npc_meta, "frames": frames}, indent=1), encoding="utf-8")

    # 2. portraits
    ports = all_portraits()
    pitems = [(n, g, {}) for n, g in ports.items()]
    save_atlas(pitems, 5, OUT / "portraits_v1.png", {
        "version": 1, "size": [PS, PS],
        "note": "64x64 busts facing right, hard alpha, 1 px ink outline; draw at 1x inside ui_dialogue_portrait_frame (window at 4,4).",
        "expressions": {k: list(v[1]) for k, v in PORTRAITS.items()}})

    # 3. dialogue UI
    ui = all_ui()
    uitems = [(n, g, UI_SLICE.get(n, {})) for n, g in ui.items()]
    sheet = Image.new("RGBA", (BOX_W + 8 + PFRAME, max(BOX_H + PLATE_H + 8 + 16, PFRAME)), (0, 0, 0, 0))
    pos = {"ui_dialogue_box": (0, 0), "ui_dialogue_nameplate": (0, BOX_H + 8), "ui_dialogue_portrait_frame": (BOX_W + 8, 0),
           "ui_dialogue_next_1": (PLATE_W + 8, BOX_H + 8), "ui_dialogue_next_2": (PLATE_W + 16, BOX_H + 8),
           "ui_dialogue_next_3": (PLATE_W + 24, BOX_H + 8), "ui_dialogue_choice": (PLATE_W + 40, BOX_H + 8),
           "ui_dialogue_choice_bar": (PLATE_W + 56, BOX_H + 8)}
    sheet = Image.new("RGBA", (BOX_W + 8 + PFRAME, BOX_H + 8 + PLATE_H), (0, 0, 0, 0))
    uframes = {}
    for n, g, extra in uitems:
        x, y = pos[n]
        sheet.alpha_composite(to_image(g), (x, y))
        uframes[n] = {"x": x, "y": y, "w": len(g[0]), "h": len(g), **extra}
    sheet.save(OUT / "dialogue_ui_v1.png")
    (OUT / "dialogue_ui_v1.json").write_text(json.dumps({
        "version": 1, "theme": THEME, "theme_note": "the 'menu' theme of presentation/arena/ui_panel.gd (lilac accent, cream gems)",
        "layout_320x180": LAYOUT, "image": "dialogue_ui_v1.png", "frames": uframes,
        "next_ticks": [18, 10, 10], "text": "Pixelify Sans size 9 (body, mixed case), Cinzel 900 size 9 (name), drawn at window resolution (decision 0004)"},
        indent=1), encoding="utf-8")

    # 4. contact sheets 4x, dark and grass
    groups = []
    for npc in NPCS:
        fr = all_frames[npc.name]
        groups.append((f"{npc.name}: " + ", ".join(f"{st} {FRAMES[st]}" for st in npc.states),
                       [(f"{st} {i + 1}", to_image(g)) for st in npc.states for i, g in enumerate(fr[st])]))
    for tag, bg in (("dark", rgb("0")), ("grass", rgb("4"))):
        labelled_sheet(groups, bg, 4, 13).convert("RGB").save(OUT / f"preview_contact_{tag}.png")
    pg = []
    for name, (fn, exprs) in PORTRAITS.items():
        pg.append((f"portrait_{name}", [(e, to_image(ports[f"portrait_{name}_{e}"])) for e in exprs]))
    for tag, bg in (("dark", rgb("0")), ("grass", rgb("4"))):
        labelled_sheet(pg, bg, 4, 5).convert("RGB").save(OUT / f"portraits_contact_{tag}.png")
    sh = lambda ns: [(n.replace("ui_dialogue_", ""), to_image(ui[n])) for n in ns]  # noqa: E731
    ug = [("dialogue box 232x56 (1x pieces shown at 4x)", sh(["ui_dialogue_box"])),
          ("portrait frame 72x72 (64x64 window at 4,4)", sh(["ui_dialogue_portrait_frame"])),
          ("name plate 72x16, choice bar 64x8", sh(["ui_dialogue_nameplate", "ui_dialogue_choice_bar"])),
          ("next arrow (3-frame blink) and choice marker, 8x8", sh(["ui_dialogue_next_1", "ui_dialogue_next_2", "ui_dialogue_next_3", "ui_dialogue_choice"]))]
    labelled_sheet(ug, rgb("e"), 4, 4).convert("RGB").save(OUT / "dialogue_ui_4x.png")

    # 5. GIFs: idle x3, walk x3, talk x4 on grass at 4x
    Z = 4
    for npc in NPCS:
        fr = all_frames[npc.name]
        seq = []
        for st, loops in (("idle", 3), ("walk", 3), ("talk", 4)):
            if st not in npc.states:
                continue
            for _ in range(loops):
                for i, g in enumerate(fr[st]):
                    seq.append((g, TICKS[st][i] * 1000 // 60, st))
        out = []
        durs = []
        tf = font(PIXEL_FONT, 14)
        for g, ms, st in seq:
            im = Image.new("RGBA", (CW + 16, CH + 4), rgb("4") + (255,))
            shadow_under(im, 8 + npc.hip[0], ANCHOR_Y, 12)
            im.alpha_composite(to_image(g), (8, 0))
            big = im.resize((im.width * Z, im.height * Z), Image.NEAREST)
            hard_text(big, (6, 6), st, tf, rgb("1"))
            out.append(big.convert("RGB"))
            durs.append(max(40, ms))
        out[0].save(OUT / f"npc_{npc.name}.gif", save_all=True, append_images=out[1:], duration=durs, loop=0, disposal=1)

    # 6. game-scale line-up: 320x180, everyone on the path next to Totoy, then 4x
    scene = village_bg()
    hero, hax, hay = hero_frame("hero2_idle_right_1")
    xs = [30, 72, 112, 150, 190, 232, 274]
    fy = 112
    shadow_under(scene, xs[0], fy, 14)
    scene.alpha_composite(hero, (xs[0] - hax, fy - hay))
    for x, npc in zip(xs[1:], NPCS):
        g = all_frames[npc.name]["idle"][0]
        shadow_under(scene, x, fy, 12)
        scene.alpha_composite(to_image(g), (x - npc.hip[0], fy - ANCHOR_Y))
    scene.convert("RGB").save(OUT / "npc_lineup_game_scale_1x.png")
    scene.resize((1280, 720), Image.NEAREST).convert("RGB").save(OUT / "npc_lineup_game_scale_4x.png")

    # 7. dialogue mockups
    lines = ["That key... it's one of the beacon keys.", "The forest beacon still answers, faintly.", "Come on. I'll mark the path for you."]
    m1 = mockup(lines, "Mira", ports["portrait_mira_neutral"], 1)
    m1.convert("RGB").save(OUT / "dialogue_mockup_1x.png")
    mockup(lines, "Mira", ports["portrait_mira_neutral"], 4).convert("RGB").save(OUT / "dialogue_mockup_4x.png")
    mockup(["You came back! Will you help me map the forest?"], "Mira", ports["portrait_mira_happy"], 4,
           choices=["I'll go now.", "Tell me about the beacons first."], sel=0).convert("RGB").save(OUT / "dialogue_mockup_choice_4x.png")
    frames_gif = [mockup(lines, "Mira", ports["portrait_mira_neutral"], 2, next_frame=i).convert("RGB") for i in range(3)]
    frames_gif[0].save(OUT / "dialogue_next_blink.gif", save_all=True, append_images=frames_gif[1:], duration=[300, 170, 170], loop=0)

    # 8. palette check over every output PNG (hard alpha, palette colours only, no reserved symbol)
    allowed = {PAL.by_symbol[c] for c in PAL.by_symbol if c not in FORBIDDEN}
    for name in ("npc_sprites_v1.png", "portraits_v1.png", "dialogue_ui_v1.png"):
        im = Image.open(OUT / name).convert("RGBA")
        for r, gg, b, a in im.get_flattened_data():
            assert a in (0, 255), f"{name}: partial alpha"
            assert a == 0 or (r, gg, b) in allowed, f"{name}: colour {(r, gg, b)} not allowed"
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*") if p.suffix in (".png", ".json", ".gif"))))


# ----------------------------------------------------------------------------------------------- dev preview
def dev_preview(path: Path, zoom: int = 6) -> None:
    rows = []
    for npc in NPCS:
        fr = npc_frames(npc)
        ims = [to_image(g) for st in npc.states for g in fr[st]]
        rows.append(ims)
    W = max(len(r) for r in rows) * (CW + 2)
    H = len(rows) * (CH + 2)
    im = Image.new("RGBA", (W, H), PAL.by_symbol["4"] + (255,))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            im.alpha_composite(f, (i * (CW + 2), j * (CH + 2)))
    im.resize((W * zoom, H * zoom), Image.NEAREST).save(path)


def main() -> None:
    if len(sys.argv) > 2 and sys.argv[1] == "--portraits":
        ps = all_portraits()
        names = list(ps)
        cols = 5
        z = int(sys.argv[3]) if len(sys.argv) > 3 else 4
        rows = (len(names) + cols - 1) // cols
        im = Image.new("RGBA", (cols * (PS + 4), rows * (PS + 4)), PAL.by_symbol["0"] + (255,))
        bg = Image.new("RGBA", (PS, PS), PAL.by_symbol["f"] + (255,))
        for i, n in enumerate(names):
            tile = bg.copy()
            tile.alpha_composite(to_image(ps[n]))
            im.paste(tile, ((i % cols) * (PS + 4), (i // cols) * (PS + 4)))
        im.resize((im.width * z, im.height * z), Image.NEAREST).save(sys.argv[2])
        return
    if len(sys.argv) > 2 and sys.argv[1] == "--dev":
        dev_preview(Path(sys.argv[2]))
        return
    if len(sys.argv) > 3 and sys.argv[1] == "--zoom":
        names = sys.argv[3].split(",")
        sts = sys.argv[5].split(",") if len(sys.argv) > 5 else None
        rows = []
        for npc in NPCS:
            if npc.name in names:
                fr = npc_frames(npc)
                rows.append([to_image(g) for st in npc.states for g in fr[st] if sts is None or st in sts])
        W = max(len(r) for r in rows) * (CW + 1)
        H = len(rows) * (CH + 1)
        im = Image.new("RGBA", (W, H), PAL.by_symbol["4"] + (255,))
        for j, r in enumerate(rows):
            for i, f in enumerate(r):
                im.alpha_composite(f, (i * (CW + 1), j * (CH + 1)))
        z = int(sys.argv[4]) if len(sys.argv) > 4 else 8
        im.resize((W * z, H * z), Image.NEAREST).save(sys.argv[2])
        return
    write_all()


if __name__ == "__main__":
    main()
