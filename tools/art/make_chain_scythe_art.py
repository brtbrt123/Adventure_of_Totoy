"""Generate the Chain Scythe ("Reaper's Coil") reference art (art/reference/chain_scythe/).

Review stage only: nothing here is imported into art/src or wired into the game.

Everything is drawn procedurally, pixel by pixel, in the Totoy 36 palette (hard alpha, no gold or red):
  * Totoy's bodies are the in-game LEANING hero frames, rebuilt exactly like the dagger set does it
    (tools/art/import_dagger_sprites.py: make_hero_lean_sheet warp of the upright frames, katana removed);
    two poses use their own lean (the pull leans back, the charged spin leans in);
  * the scythe: long dark haft (stone_2 with teal ferrules), curved blade in spectral teal (teal_1/teal_2) with a
    cream cutting edge on the concave side, ink outline; a chain of alternating links (face-on 2 px / edge-on 1 px)
    hangs from the pommel ring;
  * effects use the "spectral" ramp: deep blue-black water_1 shadows, teal_1, teal_2, grass_6 (green glint),
    water_6 (pale) and cream. Gold x,y and red z,A are reserved for combat cues and never used.

Outputs (atlases at 1x game pixels; preview files are scaled copies for viewing):
  concept_v1.png/.json         10 armed poses, 64x64 cells, feet anchor (32,56)
  weapon_layers_v1.png/.json   per pose: unarmed body, back layer (behind the body), front layer (in front)
  scythe_fx_v1.png/.json       arcs (3 swings x 4 phases, spin ring back/front x 4), chain whip (extend x 6, link
                               segments x 4, hook + clink x 5), pull streaks x 4, dust trail x 4, stagger burst x 6,
                               dizzy stars x 4, ground scuff decals x 4
  skill_medallions_v1.png/.json  24px skill medallion + 48px weapon medallion (rings from the existing UI icons)
  preview_contact_dark.png, preview_contact_grass.png, skill_sequence.gif, combo_sequence.gif (+ strips)
Run from the project root (deterministic, fixed seeds):
  python tools/art/make_chain_scythe_art.py
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import make_dual_dagger_art as M  # noqa: E402  (grid helpers; no side effects on import)
import import_dagger_sprites as D  # noqa: E402  (leaned, katana-free bodies + hand points; no side effects)
import make_hero_lean_sheet as L  # noqa: E402  (the lean warp; no side effects)

ROOT = artlib.ROOT
OUT = ROOT / "art" / "reference" / "chain_scythe"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)
GENERATOR = "tools/art/make_chain_scythe_art.py (procedural, Pillow only, deterministic seeds)"

Grid = list
blank, put, get, copy, paste = M.blank, M.put, M.get, M.copy, M.paste
line_pts, outline_layer = M.line_pts, M.outline_layer

CW, CH, AX, AY = 64, 64, 32, 56  # pose cell and feet anchor, same as the dual dagger concept


def to_image(g: Grid) -> Image.Image:
    for row in g:
        for c in row:
            assert c not in FORBIDDEN, f"reserved colour {c}"
    return M.to_image(g)


def rnd(v: float) -> int:
    return math.floor(v + 0.5)


# ------------------------------------------------------------------------------------------------- bodies
def hero_body(state: str, n: int, pose: "L.Pose | None" = None) -> tuple[Grid, list[tuple[int, int]]]:
    """The leaning, katana-free hero body of hero2_<state>_right_<n> in a 64x64 cell (feet at AX, AY), plus its two
    hand points in cell pixels. pose=None: the in-game lean (POSES); otherwise a custom lean of that upright frame."""
    src = f"hero2_{state}_right_{n}"
    if pose is None:
        f = D.build_dagger_frame(state, src, n, D.phase_of(state, n))
        body, hands, (ax, ay) = f["body"], [(h[0], h[1]) for h in f["hands"]], f["orig_anchor"]
    else:
        lf = L.build_frame(f"cs_{state}", n, src, pose)
        body = D.strip_katana([r[:] for r in lf.grid], src)
        hands = [(h[0], h[1]) for h in D.lean_hands(src, lf)]
        ax, ay = lf.anchor
    cell = blank(CW, CH)
    ox, oy = AX - ax, AY - ay
    paste(cell, body, ox, oy)
    return cell, [(x + ox, y + oy) for x, y in hands]


# ------------------------------------------------------------------------------------------------- weapon
HAFT, FERRULE, RING = "h", "t", "j"
BLADE_EDGE, BLADE_MID, BLADE_BACK, BLADE_TIP = "1", "u", "t", "p"


def catmull(pts: list[tuple[float, float]], per: int = 12) -> list[tuple[float, float]]:
    """Smooth path through control points (Catmull-Rom, endpoints doubled)."""
    if len(pts) < 3:
        return list(pts)
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for s in range(per):
            t = s / per
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    out.append(pts[-1])
    return out


def pixel_path(pts: list[tuple[float, float]]) -> list[tuple[int, int]]:
    """Rasterise a polyline into an 8-connected pixel path without repeats or doubled corners."""
    cells: list[tuple[int, int]] = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        for p in line_pts(ax, ay, bx, by):
            if not cells or cells[-1] != p:
                cells.append(p)
    # drop L-corners (a pixel whose neighbours before and after touch diagonally)
    out: list[tuple[int, int]] = []
    for i, p in enumerate(cells):
        if out and 0 < i < len(cells) - 1:
            a, b = out[-1], cells[i + 1]
            if abs(a[0] - b[0]) == 1 and abs(a[1] - b[1]) == 1:
                continue
        if p not in out[-2:]:
            out.append(p)
    return out


def chain_pixels(path: list[tuple[int, int]], phase: int = 0) -> dict[tuple[int, int], str]:
    """Alternating links along a pixel path: a face-on link (2 px across, pale steel with a cream glint) then an
    edge-on link (1 px, teal), then a dark joint. Period 4 px, so straight 32 px segments tile end to end."""
    out: dict[tuple[int, int], str] = {}
    for i, (x, y) in enumerate(path):
        k = (i + phase) % 4
        a = path[min(i + 1, len(path) - 1)]
        b = path[max(i - 1, 0)]
        dx, dy = a[0] - b[0], a[1] - b[1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        if k == 0:
            out[(x, y)] = "j"
            q = (x + rnd(nx), y + rnd(ny))
            if q not in out and q not in path:
                out[q] = "u"
        elif k == 1:
            out[(x, y)] = "1"
            q = (x + rnd(nx), y + rnd(ny))
            if q not in out and q not in path:
                out[q] = "t"
        elif k == 2:
            out[(x, y)] = "u"
        else:
            out[(x, y)] = "t"
    return out


def draw_chain(g: Grid, ctrl: list[tuple[float, float]], phase: int = 0, rim: str = "0") -> list[tuple[int, int]]:
    layer = blank(len(g[0]), len(g))
    path = pixel_path(catmull(ctrl))
    for (x, y), c in chain_pixels(path, phase).items():
        put(layer, x, y, c)
    if rim:
        outline_layer(layer, rim)
    paste(g, layer, 0, 0)
    return path


def blade_pixels(head: tuple[float, float], u: tuple[float, float], side: int, length: float, curl: float,
                 width: float = 1.7) -> dict[tuple[int, int], str]:
    """Scythe blade from the head of the haft: leaves perpendicular to the haft and curls back toward the pommel.
    The concave (inner) side is the cutting edge (cream), the convex spine is teal_1, the body teal_2."""
    base = math.atan2(u[1], u[0]) + side * math.pi / 2
    x, y = head
    pri = {BLADE_BACK: 1, BLADE_MID: 2, BLADE_TIP: 3, BLADE_EDGE: 4}
    out: dict[tuple[int, int], str] = {}
    steps = int(length * 6)
    for i in range(steps + 1):
        s = i / steps
        a = base + side * math.radians(curl) * s ** 1.3
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = math.cos(a + side * math.pi / 2), math.sin(a + side * math.pi / 2)  # toward the concave side
        w = width * (1 - s) ** 0.75 + 0.35
        o = -w
        while o <= w + 1e-6:
            if s > 0.9:
                c = BLADE_TIP
            elif o > w - 0.85:
                c = BLADE_EDGE
            elif o < -w + 0.85 and w > 1.0:
                c = BLADE_BACK
            else:
                c = BLADE_MID
            p = (rnd(x + nx * o), rnd(y + ny * o))
            if pri[c] > pri.get(out.get(p, ""), 0):
                out[p] = c
            o += 0.35
        x += dx * length / steps
        y += dy * length / steps
    return out


def draw_scythe(g: Grid, pommel: tuple[float, float], head: tuple[float, float], side: int, blade: float = 11,
                curl: float = 80, grips: list[tuple[int, int]] | None = None, width: float = 1.25) -> None:
    """Haft from pommel to head (1 px, stone_2 with teal ferrules at both ends and a pale pommel ring), then the
    blade; 1px ink outline around the weapon; the fists (grips) stay visible over it."""
    layer = blank(len(g[0]), len(g))
    ux, uy = head[0] - pommel[0], head[1] - pommel[1]
    ln = math.hypot(ux, uy) or 1.0
    u = (ux / ln, uy / ln)
    for p, c in blade_pixels(head, u, side, blade, curl, width).items():
        put(layer, p[0], p[1], c)
    haft = line_pts(*pommel, *head)
    for i, (x, y) in enumerate(haft):
        if get(layer, x, y) != T:
            continue
        c = HAFT
        if i >= len(haft) - 3:
            c = FERRULE
        elif i in (1, 2):
            c = FERRULE
        put(layer, x, y, c)
    put(layer, rnd(pommel[0]), rnd(pommel[1]), RING)
    # a back spike opposite the blade (the scythe's heel), 2 px
    hx, hy = rnd(head[0] - side * -u[1] * 1.0), rnd(head[1] - side * u[0] * 1.0)
    if get(layer, hx, hy) == T:
        put(layer, hx, hy, "t")
    keep = set(grips or [])
    outline_layer(layer, "0", keep=keep)
    for x, y in keep:
        put(layer, x, y, T)
    paste(g, layer, 0, 0)


# ------------------------------------------------------------------------------------------------- poses
P = L.P
# Every pose is built FROM THE HANDS (hero_body() hand points, checked on 8x sheets), so the haft always runs through
# the fist(s):
#   scythe = dict(grip=(i, j) two-handed: the haft runs through hand j and hand i, head beyond hand i;
#                 grip=(i,) with angle (deg, 0 = right, 90 = down): one hand, head in that direction;
#                 fwd / back = haft length beyond the head-side hand / behind the pommel-side hand,
#                 side = which way the blade leaves the head (+1 clockwise on screen), blade = blade length)
#   chains = control-point lists; "pommel", "hand0", "hand1" are replaced by those points
#   fists  = hands whose fist is redrawn OVER the haft/chain (taken from the body pixels around the hand point), so the
#            fingers close over the weapon; a hand behind the haft (layer "back") is covered by the body anyway.
POSES: list[dict] = [
    dict(name="ready", body=("idle", 1, None), layer="front",
         scythe=dict(grip=(1,), angle=-80, fwd=25, back=9, side=1, blade=14),
         chains=[(["pommel", (31, 55), (26, 52), "hand0"], "front"), (["hand0", (24, 49), (23, 54), (20, 56)], "front")],
         fists=[0, 1], desc="idle / ready: scythe upright in the lead fist, blade over the head; the chain loops up into the other fist"),
    dict(name="walk_carry", body=("walk", 2, None), layer="back",
         scythe=dict(grip=(1,), angle=-148, fwd=24, back=7, side=-1, blade=12),
         chains=[(["pommel", (49, 53), (45, 56), (39, 56)], "back")],
         fists=[1], desc="walk: haft gripped low in the lead fist, trailed up over the back with the blade hanging behind"),
    dict(name="swing_1", body=("attack1", 4, None), layer="front",
         scythe=dict(grip=(1, 0), fwd=7, back=8, side=1, blade=14),
         chains=[(["pommel", (17, 44), (11, 48), (5, 45)], "back")],
         fists=[0, 1], desc="combo 1: wide horizontal sweep, two-handed grip"),
    dict(name="swing_2", body=("attack2", 4, None), layer="front",
         scythe=dict(grip=(0, 1), fwd=10, back=6, side=-1, blade=14),
         chains=[(["pommel", (49, 51), (55, 52), (60, 55)], "back")],
         fists=[0, 1], desc="combo 2: reverse (backhand) rising arc, two-handed grip"),
    dict(name="swing_3", body=("attack3", 4, None), layer="front",
         scythe=dict(grip=(0,), angle=24, fwd=12, back=16, side=-1, blade=13),
         chains=[(["pommel", (13, 38), (10, 31), (13, 25)], "back")],
         fists=[0, 1], desc="combo 3: overhead-to-low slam, both fists together on the haft, blade skims the ground"),
    dict(name="spin", body=("victory", 3, P(lean=8, stride=1.15, hip_fwd=1, drop=1)), layer="front",
         scythe=dict(free=((47, 19), (60, 26)), side=1, blade=11),
         chains=[(["hand0", (41, 13), "pommel"], "front"), (["hand0", (28, 33), (27, 38)], "front")],
         fists=[0], desc="charged: the raised fist whirls the scythe on its chain in a full circle overhead"),
    dict(name="windup", body=("attack1", 1, None), layer="front",
         scythe=dict(grip=(0,), angle=172, fwd=21, back=6, side=1, blade=13),
         chains=[(["pommel", (38, 49), "hand1"], "front"), (["hand1", (47, 51), (45, 55)], "front")],
         fists=[0, 1], desc="skill wind-up: haft drawn back in the rear fist, chain gathered in the lead fist"),
    dict(name="whip", body=("attack2", 3, None), layer="front", scythe=None,
         chains=[(["hand0", (56, 34), (60, 33), (64, 30)], "front"), (["hand0", (51, 43), (49, 47)], "front")],
         fists=[0], desc="skill: whip-out, the chain flies forward out of the lead fist (the scythe is far ahead, see the fx sheet)"),
    dict(name="pull", body=("parry", 1, P(lean=-14, stride=1.25, hip_fwd=-2, drop=2)), layer="front", scythe=None,
         chains=[([(64, 40), "hand0", "hand1", (38, 50), (41, 53), (43, 49)], "front")],
         fists=[0, 1], desc="skill: drag, leaning back, the taut chain runs through both fists, slack loop below"),
    dict(name="recovery", body=("attack1", 6, None), layer="front",
         scythe=dict(grip=(0, 1), fwd=10, back=6, side=-1, blade=13),
         chains=[(["pommel", (49, 47), (47, 52), (50, 55)], "back")],
         fists=[0, 1], desc="recovery: scythe lowered across the hips in both fists, blade trailing behind"),
]
SKIN = set("qrs")


def scythe_geometry(spec: dict, hands: list[tuple[int, int]]) -> tuple[tuple[float, float], tuple[float, float]]:
    """(pommel, head) from the grip: the haft passes exactly through the gripping hand point(s)."""
    if "free" in spec:
        return spec["free"]
    g = spec["grip"]
    if len(g) == 2:
        hi, hj = hands[g[0]], hands[g[1]]
        dx, dy = hi[0] - hj[0], hi[1] - hj[1]
        ln = math.hypot(dx, dy) or 1.0
        u = (dx / ln, dy / ln)
        return (hj[0] - u[0] * spec["back"], hj[1] - u[1] * spec["back"]), (hi[0] + u[0] * spec["fwd"], hi[1] + u[1] * spec["fwd"])
    h = hands[g[0]]
    a = math.radians(spec["angle"])
    u = (math.cos(a), math.sin(a))
    return (h[0] - u[0] * spec["back"], h[1] - u[1] * spec["back"]), (h[0] + u[0] * spec["fwd"], h[1] + u[1] * spec["fwd"])


def fist_over(layer: Grid, body: Grid, hand: tuple[int, int], along: tuple[float, float] | None = None) -> None:
    """Redraw the fist closed AROUND the weapon, on top of it: a 3-across x 2-along block of skin centred on the hand
    point (lit knuckles on top, shaded underside), ink outline only where nothing else is drawn, so the haft or chain
    visibly enters and leaves the fist. along = the weapon direction at the hand (default: horizontal)."""
    hx, hy = hand
    ux, uy = along or (1.0, 0.0)
    a = round(math.atan2(uy, ux) / (math.pi / 4)) % 8
    steps = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    u = steps[a]
    n = steps[(a + 2) % 8]
    if n[1] > 0 or (n[1] == 0 and n[0] > 0):  # n points up (or left): knuckles lit on the upper side
        n = (-n[0], -n[1])
    fist = blank(len(layer[0]), len(layer))
    for k, along_k in enumerate((0, 1)):
        for j, across in enumerate((1, 0, -1)):  # +n (upper) .. -n (lower)
            x, y = hx + n[0] * across + u[0] * along_k, hy + n[1] * across + u[1] * along_k
            c = ("s", "r", "q")[j] if k == 0 else ("r", "r", "q")[j]
            put(fist, x, y, c)
    ink = []
    for y in range(len(fist)):
        for x in range(len(fist[0])):
            if fist[y][x] == T and get(layer, x, y) == T and get(body, x, y) in (T, "0", "8"):
                if any(get(fist, x + dx, y + dy) != T for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    ink.append((x, y))
    paste(layer, fist, 0, 0)
    for x, y in ink:
        put(layer, x, y, "0")


def weapon_dir_at(pts: list[tuple[float, float]], hand: tuple[int, int]) -> tuple[float, float]:
    """Direction of a polyline at the point nearest to the hand."""
    best = min(range(len(pts) - 1), key=lambda i: math.hypot((pts[i][0] + pts[i + 1][0]) / 2 - hand[0], (pts[i][1] + pts[i + 1][1]) / 2 - hand[1]))
    (ax, ay), (bx, by) = pts[best], pts[best + 1]
    return (bx - ax, by - ay)


def build_pose(p: dict, body_hands: tuple[Grid, list] | None = None) -> dict:
    body, hands = body_hands or hero_body(*p["body"])
    back, front = blank(CW, CH), blank(CW, CH)
    geo = None
    if p["scythe"]:
        geo = scythe_geometry(p["scythe"], hands)
    named = {"hand0": hands[0], "hand1": hands[1], "pommel": geo[0] if geo else hands[0]}
    for ctrl, lay in p["chains"]:
        pts = [named[c] if isinstance(c, str) else c for c in ctrl]
        draw_chain(back if lay == "back" else front, pts, phase=1)
    if geo:
        target = front if p["layer"] == "front" else back
        draw_scythe(target, geo[0], geo[1], p["scythe"]["side"], p["scythe"]["blade"])
    for i in p["fists"]:
        along = None
        if geo and i in p["scythe"].get("grip", ()):
            along = (geo[1][0] - geo[0][0], geo[1][1] - geo[0][1])
        else:
            for ctrl, _ in p["chains"]:
                if f"hand{i}" in ctrl:
                    along = weapon_dir_at([named[c] if isinstance(c, str) else c for c in ctrl], hands[i])
                    break
        fist_over(front, body, hands[i], along)
    full = copy(back)
    paste(full, body, 0, 0)
    paste(full, front, 0, 0)
    return {"name": p["name"], "body": body, "back": back, "front": front, "full": full, "hands": hands, "geo": geo}


# ------------------------------------------------------------------------------------------------- arcs
AW, AH = 96, 64  # arc cell; the anchor is the hero's feet
ARC_ANCHOR = (40, 56)
SPIN_ANCHOR = (48, 56)
# swing -> (centre x, centre y, rx, ry, tilt deg, start deg, end deg, thickness); angles on the ellipse, screen y down
# (90 = the bottom / front of the hero, 270 = top). The arc is drawn from start to end (direction of travel).
# Reach: every arc ends about 30-34 px in front of the feet (the scythe head plus blade), the spin ring has rx 34.
ARCS = {
    1: (41, 42, 33, 11, -5, 196, -18, 7.0),     # wide horizontal sweep: from behind, around the front, out to the right
    2: (41, 36, 30, 16, -18, 25, -160, 6.0),    # reverse rising arc: front-low, over the top, to the back
    3: (46, 38, 24, 19, 0, -118, 72, 7.0),      # overhead-to-low: from above the head down to the ground in front
}
SPIN = (48, 45, 34, 11, 0, 180, 540, 5.5)        # full circle at waist height (ry small: seen from above-side)
ARC_SPANS = {1: (0.0, 0.55), 2: (0.0, 1.0), 3: (0.35, 1.0), 4: (0.6, 1.0)}
SPIN_SPANS = {1: (0.0, 0.45), 2: (0.0, 1.0), 3: (0.3, 1.0), 4: (0.55, 1.0)}


def ellipse_pt(cx, cy, rx, ry, tilt, th):
    ct, st = math.cos(tilt), math.sin(tilt)
    ex, ey = rx * math.cos(th), ry * math.sin(th)
    nx, ny = math.cos(th) / rx, math.sin(th) / ry  # outward normal (unrotated)
    nl = math.hypot(nx, ny) or 1.0
    nx, ny = nx / nl, ny / nl
    return (cx + ex * ct - ey * st, cy + ex * st + ey * ct), (nx * ct - ny * st, nx * st + ny * ct)


def arc_frame(spec, phase: int, seed: int, w: int = AW, h: int = AH, spans=ARC_SPANS, split: bool = False):
    """A wide scythe crescent along an ellipse. Thickest just behind the leading end, pointed at both ends.
    Across the width: cream cutting edge outside, pale, teal_2, teal_1, water_1 (deep blue-black) inside.
    Phases: 1 lead (first half drawn, thin), 2 peak (full crescent), 3 follow (rear part gone, no cream),
    4 fragments (broken ghost pieces). split=True returns (back, front) by whether a pixel is above the centre
    (behind the hero) or below it (in front), for the spin ring."""
    rng = random.Random(seed)
    cx, cy, rx, ry, tilt, a0, a1, thick = spec
    tilt = math.radians(tilt)
    s0, s1 = spans[phase]
    back, front = blank(w, h), blank(w, h)
    pri = {"k": 1, "t": 2, "u": 3, "7": 4, "p": 5, "1": 6}
    steps = 420
    for i in range(steps + 1):
        f = s0 + (s1 - s0) * i / steps  # position along the full sweep 0..1
        th = math.radians(a0 + (a1 - a0) * f)
        g = (f - s0) / max(1e-6, s1 - s0)  # position inside the visible span (0 tail .. 1 head)
        if phase == 1:
            wd = thick * 0.65 * (g ** 1.4) * min(1.0, (1 - g) * 6 + 0.25)
        elif phase == 2:
            gg = g ** 0.75
            wd = thick * math.sin(math.pi * gg) ** 0.7 * (0.5 + 0.5 * g)
        elif phase == 3:
            wd = thick * 0.6 * math.sin(math.pi * g) ** 0.8
        else:
            wd = thick * 0.45 * math.sin(math.pi * g) ** 0.8
        if wd < 0.3:
            continue
        (px, py), (nx, ny) = ellipse_pt(cx, cy, rx, ry, tilt, th)
        o = 0.0
        while o <= wd:
            q = o / max(wd, 1e-6)
            if phase == 2:
                c = "1" if o < 0.9 else ("p" if q < 0.32 else ("u" if q < 0.6 else ("t" if q < 0.85 else "k")))
            elif phase == 1:
                c = "1" if o < 0.9 else ("u" if q < 0.6 else "t")
            elif phase == 3:
                c = "u" if o < 0.9 else ("t" if q < 0.6 else "k")
            else:
                c = "t" if q < 0.5 else "k"
            x, y = rnd(px - nx * o), rnd(py - ny * o)
            tgt = back if (split and math.sin(th) < 0) else front
            if pri[c] > pri.get(get(tgt, x, y), 0):
                put(tgt, x, y, c)
            o += 0.4
    if phase == 4:  # break into ghostly pieces along the sweep
        for tgt in (back, front):
            for y in range(h):
                for x in range(w):
                    if tgt[y][x] != T:
                        ang = math.atan2(y - cy, x - cx)
                        if int((ang + 4) * 7) % 3 == 0:
                            tgt[y][x] = T
    # spectral motes trailing behind the edge
    nm = {1: 3, 2: 8, 3: 6, 4: 7}[phase]
    for _ in range(nm):
        f = rng.uniform(s0, s0 + (s1 - s0) * 0.85)
        th = math.radians(a0 + (a1 - a0) * f)
        (px, py), (nx, ny) = ellipse_pt(cx, cy, rx, ry, tilt, th)
        d = rng.uniform(1.5, 4.0)
        x, y = rnd(px + nx * d), rnd(py + ny * d)
        tgt = back if (split and math.sin(th) < 0) else front
        if get(tgt, x, y) == T:
            put(tgt, x, y, rng.choice("17u" if phase < 4 else "ut"))
    for tgt in (back, front):
        outline_layer(tgt, "k" if phase < 4 else "0")
    if split:
        return back, front
    return front


# ------------------------------------------------------------------------------------------------- chain fx
SEG_W, SEG_H = 32, 8


def chain_segment(k: int) -> Grid:
    """32x8 chain piece from (0,4) to (31,4); period 4 px so the taut ones tile end to end. 1, 2: taut (two link
    phases, alternate them for a shimmer); 3: slight wave; 4: spectral (glowing teal rim, for the skill)."""
    g = blank(SEG_W, SEG_H)
    if k in (1, 2, 4):
        path = [(x, 4) for x in range(SEG_W)]
    else:
        path = pixel_path([(x, 4 + 1.4 * math.sin(2 * math.pi * x / SEG_W)) for x in range(SEG_W)])
    layer = blank(SEG_W, SEG_H)
    for (x, y), c in chain_pixels(path, 0 if k != 2 else 2).items():
        put(layer, x, y, c)
    outline_layer(layer, "0")
    if k == 4:
        glow = blank(SEG_W, SEG_H)
        for y in range(SEG_H):
            for x in range(SEG_W):
                if layer[y][x] == T and any(get(layer, x + dx, y + dy) == "0" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    if (x + y) % 2 == 0 or y in (1, 7):
                        glow[y][x] = "u" if (x // 2) % 3 else "7"
        paste(g, glow, 0, 0)
    paste(g, layer, 0, 0)
    return g


def flying_scythe(k: int, n: int = 8, size: int = 32) -> Grid:
    """The scythe in flight at the end of the chain, rotation k of n (clockwise). Anchor = the pommel ring, where the
    chain attaches, at the cell centre."""
    g = blank(size, size)
    c = size // 2
    a = 2 * math.pi * k / n - math.pi / 2
    head = (c + math.cos(a) * 9, c + math.sin(a) * 9)
    draw_scythe(g, (c, c), head, 1, 9, width=1.15)
    return g


def whip_frame(k: int) -> Grid:
    """128x32: the chain thrown from the hand at (0,16) toward a target 120 px ahead. Frames 1-4: the chain
    unreels with a travelling wave and the scythe tumbling at its tip; 5: full reach, the blade turns to hook;
    6: snapped taut (the catch)."""
    W_, H_ = 128, 32
    g = blank(W_, H_)
    frac = [0.22, 0.46, 0.7, 0.9, 1.0, 1.0][k - 1]
    reach = 4 + frac * 112
    amp = [3.0, 4.0, 3.5, 2.5, 1.5, 0.0][k - 1]
    pts = []
    for i in range(41):
        s = i / 40
        x = s * reach
        y = 16 - 3 * math.sin(math.pi * s) * (1 - frac) + amp * math.sin(2 * math.pi * (s * 1.6 - k * 0.35)) * s
        pts.append((x, y))
    path = pixel_path(pts)
    layer = blank(W_, H_)
    for (x, y), c in chain_pixels(path, k).items():
        put(layer, x, y, c)
    outline_layer(layer, "0")
    tip = path[-1]
    if k <= 4:
        sc = flying_scythe([1, 3, 5, 7][k - 1])
    else:  # hooking: blade forward and down, the curve wrapping toward the hand
        sc = blank(32, 32)
        draw_scythe(sc, (16, 16), (25, 12 if k == 5 else 14), 1, 9, width=1.15)
    paste(g, sc, tip[0] - 16, tip[1] - 16)
    paste(g, layer, 0, 0)
    if k <= 4:  # speed ticks behind the tumbling head
        for d in (6, 9):
            for oy in (-3, 3):
                x, y = tip[0] - d, tip[1] + oy
                if get(g, x, y) == T:
                    put(g, x, y, "u" if d == 6 else "t")
    return g


def star(g: Grid, cx: int, cy: int, r: int, core: str = "1", arm: str = "p", diag: str = "u", diag_r: int = -1) -> None:
    for d in range(-r, r + 1):
        put(g, cx + d, cy, core if abs(d) <= r // 2 else arm)
        put(g, cx, cy + d, core if abs(d) <= r // 2 else arm)
    dr = (r // 2) if diag_r < 0 else diag_r
    for d in range(1, dr + 1):
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            put(g, cx + sx * d, cy + sy * d, diag)


def ring(g: Grid, cx: float, cy: float, r: float, sym: str, broken: float = 0.0, rng: random.Random | None = None, ry: float | None = None) -> None:
    ry = r if ry is None else ry
    n = max(12, int(r * 8))
    for i in range(n):
        a = 2 * math.pi * i / n
        if broken and rng and rng.random() < broken:
            continue
        put(g, rnd(cx + math.cos(a) * r), rnd(cy + math.sin(a) * ry), sym)


def hook_frame(k: int) -> Grid:
    """32x32 clink at the hook point (16,16): 1 bite (small cream star), 2 clink flash (big star + ring),
    3 ring opens, 4 sparks fly, 5 fading motes."""
    rng = random.Random(610 + k)
    g = blank(32, 32)
    c = 16
    if k == 1:
        star(g, c, c, 3)
        outline_layer(g, "k")
    elif k == 2:
        ring(g, c, c, 8, "u")
        star(g, c, c, 7, "1", "p", "u", 3)
        for y in range(-1, 2):
            for x in range(-1, 2):
                put(g, c + x, c + y, "1")
        outline_layer(g, "k")
    elif k == 3:
        ring(g, c, c, 11, "t", 0.2, rng)
        ring(g, c, c, 10, "u", 0.15, rng)
        star(g, c, c, 4, "p", "u", "t", 2)
        outline_layer(g, "k")
    elif k == 4:
        for i in range(7):
            a = rng.uniform(0, 2 * math.pi)
            r0, r1 = rng.uniform(5, 8), rng.uniform(10, 14)
            for x, y in line_pts(c + math.cos(a) * r0, c + math.sin(a) * r0, c + math.cos(a) * r1, c + math.sin(a) * r1):
                put(g, x, y, "p" if math.hypot(x - c, y - c) > r1 - 2 else "u")
        ring(g, c, c, 13, "t", 0.55, rng)
    else:
        for i in range(8):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(9, 14)
            put(g, rnd(c + math.cos(a) * r), rnd(c + math.sin(a) * r), rng.choice("u7t"))
    return g


# ------------------------------------------------------------------------------------------------- pull / stagger
def pull_streaks(k: int) -> Grid:
    """64x48, anchor (12,44) = the dragged golem's feet. The golem slides toward -x (toward Totoy, who faces
    right); streaks trail behind it to the right. 1 snap (dense, long, cream), 2 drag, 3 thinning, 4 last wisps."""
    rng = random.Random(700 + k)
    g = blank(64, 48)
    n = [14, 12, 8, 5][k - 1]
    for _ in range(n):
        y = rng.randint(6, 43)
        x0 = rng.randint(14, 30)
        ln = rng.randint(10, 30) * [1.2, 1.0, 0.8, 0.5][k - 1]
        x1 = min(63, rnd(x0 + ln))
        for x in range(x0, x1 + 1):
            u_ = (x - x0) / max(1, x1 - x0)
            c = ("1" if k == 1 else "p") if u_ < 0.25 else ("u" if u_ < 0.6 else "t")
            put(g, x, y, c)
    outline_layer(g, "k")
    return g


def dust_trail(k: int) -> Grid:
    """64x16, anchor (8,14) = the golem's front foot on the ground; dirt puffs kicked up behind it (to the right)."""
    rng = random.Random(720 + k)
    g = blank(64, 16)
    n = [5, 8, 8, 6][k - 1]
    for i in range(n):
        x = 8 + i * (52 / n) + rng.uniform(-2, 2)
        r = [1.6, 2.6, 3.2, 3.0][k - 1] * (1 - i / (n + 2)) + rng.uniform(0, 0.8)
        y = 14 - r * 0.6 - [0, 0.5, 1.5, 2.5][k - 1]
        for yy in range(-4, 5):
            for xx in range(-5, 6):
                if (xx / (r * 1.3)) ** 2 + (yy / r) ** 2 <= 1:
                    top = yy < -r * 0.3
                    c = "d" if top else "c"
                    if k == 4 and (xx + yy + i) % 2:
                        continue
                    put(g, rnd(x + xx), rnd(y + yy), c)
    for y in range(16):
        for x in range(64):
            if g[y][x] != T and get(g, x, y + 1) == T and y >= 12:
                g[y][x] = "b"
    outline_layer(g, "9" if k < 4 else "b")
    return g


def scuff_decal(k: int) -> Grid:
    """32x16 ground decal, anchor (16,8): two drag gouges along x with a dirt lip and a few spectral teal glints;
    1 fresh .. 4 nearly gone. Lay several end to end along the drag path."""
    rng = random.Random(740)
    g = blank(32, 16)
    for row, (y0, wob) in enumerate(((5, 0.6), (10, 0.8))):
        for x in range(1, 31):
            if k >= 3 and (x * 7 + row * 3) % [1, 1, 3, 2][k - 1] == 0:
                continue
            y = rnd(y0 + wob * math.sin(x * 0.45 + row))
            put(g, x, y, "8" if k < 3 else "9")
            if k < 4:
                put(g, x, y + 1, "9" if k < 3 else "a")
            if k == 1 and get(g, x, y - 1) == T:
                put(g, x, y - 1, "b")
    if k <= 2:
        for _ in range(4 if k == 1 else 2):
            x, y = rng.randint(3, 28), rng.choice((4, 9))
            put(g, x, y, "u" if k == 1 else "t")
    return g


def stagger_burst(k: int) -> Grid:
    """32x32, anchor (16,16) = the golem's chest: the stagger pop. 1 pinch, 2 big star + ring, 3 ring with rays,
    4 wide broken ring + small stars, 5 sparse stars, 6 motes."""
    rng = random.Random(760 + k)
    g = blank(32, 32)
    c = 16
    if k == 1:
        star(g, c, c, 4, "1", "p", "u", 2)
        outline_layer(g, "k")
    elif k == 2:
        ring(g, c, c, 9, "u")
        ring(g, c, c, 10, "t")
        star(g, c, c, 8, "1", "p", "u", 4)
        for y in range(-1, 2):
            for x in range(-1, 2):
                put(g, c + x, c + y, "1")
        outline_layer(g, "k")
    elif k == 3:
        ring(g, c, c, 12, "u", 0.1, rng)
        ring(g, c, c, 11, "t", 0.1, rng)
        for i in range(8):
            a = i * math.pi / 4 + 0.2
            for x, y in line_pts(c + math.cos(a) * 5, c + math.sin(a) * 5, c + math.cos(a) * 9, c + math.sin(a) * 9):
                put(g, x, y, "p" if i % 2 == 0 else "u")
        outline_layer(g, "k")
    elif k == 4:
        ring(g, c, c, 14, "t", 0.4, rng)
        for i in range(4):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(7, 11)
            star(g, rnd(c + math.cos(a) * r), rnd(c + math.sin(a) * r), 2, "1", "u", "u", 0)
    elif k == 5:
        for i in range(3):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(10, 13)
            star(g, rnd(c + math.cos(a) * r), rnd(c + math.sin(a) * r), 1, "p", "u", "u", 0)
    else:
        for _ in range(6):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(11, 15)
            put(g, rnd(c + math.cos(a) * r), rnd(c + math.sin(a) * r), rng.choice("ut7"))
    return g


def dizzy_stars(k: int) -> Grid:
    """32x16 loop, anchor (16,12) = just above the staggered golem's head: three small stars circling."""
    g = blank(32, 16)
    for i in range(3):
        a = 2 * math.pi * (i / 3 + k / 4)
        x, y = rnd(16 + math.cos(a) * 11), rnd(8 + math.sin(a) * 3.5)
        front = math.sin(a) > 0
        star(g, x, y, 2 if front else 1, "1" if front else "u", "p" if front else "t", "u", 0)
    outline_layer(g, "k")
    return g


# ------------------------------------------------------------------------------------------------- medallions
def skill_medallion() -> Grid:
    """24px: the chain coiled in a loop with the hooked blade biting in from the top right."""
    g, n = M.ring_from("ui_aspect_gale_cut_1", 8.6)
    tmp = blank(n, n)
    pts = []
    for i in range(30):
        a = math.radians(150 + i * 10.5)
        r = 6.2 - i * 0.07
        pts.append((11.5 + math.cos(a) * r, 12.5 + math.sin(a) * r))
    path = pixel_path(pts)
    for (x, y), c in chain_pixels(path, 1).items():
        if math.hypot(x - 11.5, y - 11.5) < 8.2:
            put(tmp, x, y, c)
    blade = blade_pixels((15.0, 5.0), (-0.6, 0.8), -1, 10, 85, 1.5)
    for (x, y), c in blade.items():
        if math.hypot(x - 11.5, y - 11.5) < 8.6:
            put(tmp, x, y, c)
    paste(g, tmp, 0, 0)
    for x, y, c in [(6, 6, "7"), (17, 17, "u")]:
        put(g, x, y, c)
    return g


def weapon_medallion() -> Grid:
    """48px: the scythe on a diagonal (pommel bottom left, blade top right) with the chain looping under it."""
    g, n = M.ring_from("ui_weapon_sword_1", 19.5)
    tmp = blank(n, n)
    pts = [(13, 35), (9, 30), (11, 24), (17, 27), (16, 34), (10, 38)]
    lay = blank(n, n)
    for (x, y), c in chain_pixels(pixel_path(catmull(pts, 8)), 0).items():
        put(lay, x, y, c)
    outline_layer(lay, "0")
    paste(tmp, lay, 0, 0)
    sc = blank(n, n)
    draw_scythe(sc, (14, 35), (29, 14), 1, 14, curl=80, width=1.9)
    for x, y in line_pts(15, 35, 29, 15)[1:-3]:  # a 2 px haft at this size
        if get(sc, x + 1, y) in (T, '0'):
            put(sc, x + 1, y, 'g')
    paste(tmp, sc, 0, 0)
    for y in range(n):
        for x in range(n):
            if tmp[y][x] != T and math.hypot(x - 23.5, y - 23.5) < 19.5:
                g[y][x] = tmp[y][x]
    for x, y, c in [(35, 30, "7"), (9, 15, "u")]:
        put(g, x, y, c)
    return g


# ------------------------------------------------------------------------------------------------- atlas + json
def atlas(cells: list[Grid], cols: int, cw: int, ch: int) -> Image.Image:
    rows = (len(cells) + cols - 1) // cols
    im = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, g in enumerate(cells):
        im.alpha_composite(to_image(g), ((i % cols) * cw, (i // cols) * ch))
    return im


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")


COMMON = {
    "generator": GENERATOR,
    "palette": "Totoy 36, hard alpha; no reserved gold x,y or red z,A",
    "scale": "1x game pixels (nearest-neighbour; preview sheets are scaled copies)",
    "status": "Reference art for the human's approval; not imported into art/src, not wired into the game",
}


def pack(rows: list[list[tuple[str, Grid, tuple[int, int], dict]]], width: int) -> tuple[Image.Image, list[dict]]:
    """Rows of (name, grid, anchor, extra) packed left to right; returns the sheet and the frame entries."""
    placed, y = [], 0
    for row in rows:
        x, rh = 0, 0
        for name, g, anchor, extra in row:
            w, h = len(g[0]), len(g)
            if x + w > width:
                x, y = 0, y + rh
                rh = 0
            placed.append((name, g, x, y, anchor, extra))
            x += w
            rh = max(rh, h)
        y += rh
    im = Image.new("RGBA", (width, y), (0, 0, 0, 0))
    frames = []
    for name, g, x, yy, anchor, extra in placed:
        im.alpha_composite(to_image(g), (x, yy))
        frames.append({"name": name, "rect": [x, yy, len(g[0]), len(g)], "anchor": list(anchor), **extra})
    return im, frames


def check_hard(path: Path) -> None:
    errs = artlib.check_png(path, PAL)
    im = Image.open(path).convert("RGBA")
    bad = {PAL.by_symbol[s] for s in FORBIDDEN}
    if any(a == 255 and (r, g, b) in bad for _, (r, g, b, a) in im.getcolors(1 << 20)):
        errs.append("uses a reserved gold/red colour")
    if errs:
        raise SystemExit(f"{path.name}: {'; '.join(errs)}")


def build_fx() -> dict:
    """Every effect grid, by group."""
    fx: dict = {"arcs": {}, "spin_back": [], "spin_front": []}
    for s in (1, 2, 3):
        fx["arcs"][s] = [arc_frame(ARCS[s], ph, 9000 + s * 10 + ph) for ph in (1, 2, 3, 4)]
    for ph in (1, 2, 3, 4):
        b, f = arc_frame(SPIN, ph, 9100 + ph, spans=SPIN_SPANS, split=True)
        fx["spin_back"].append(b)
        fx["spin_front"].append(f)
    fx["whip"] = [whip_frame(k) for k in range(1, 7)]
    fx["segments"] = [chain_segment(k) for k in range(1, 5)]
    fx["flying"] = [flying_scythe(k) for k in range(8)]
    fx["hook"] = [hook_frame(k) for k in range(1, 6)]
    fx["pull"] = [pull_streaks(k) for k in range(1, 5)]
    fx["dust"] = [dust_trail(k) for k in range(1, 5)]
    fx["scuff"] = [scuff_decal(k) for k in range(1, 5)]
    fx["stagger"] = [stagger_burst(k) for k in range(1, 7)]
    fx["dizzy"] = [dizzy_stars(k) for k in range(4)]
    return fx


PHASES = ["lead", "peak", "follow", "fragments"]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    poses = [build_pose(p) for p in POSES]
    names = [p["name"] for p in poses]
    written: list[Path] = []

    # 1. concept
    atlas([p["full"] for p in poses], 10, CW, CH).save(OUT / "concept_v1.png")
    written.append(OUT / "concept_v1.png")
    write_json(OUT / "concept_v1.json", {
        **COMMON,
        "weapon": "Chain Scythe (suggested skill name: Reaper's Coil)",
        "layout": "10 columns x 1 row of 64x64 cells, feet anchor (32,56) in every cell. Right-facing; mirror around the anchor for left.",
        "poses": [{"pose": p["name"], "cell": i, "rect": [i * CW, 0, CW, CH], "anchor": [AX, AY],
                   "body_source": f"hero2_{p['body'][0]}_right_{p['body'][1]}" + (" (custom lean)" if p["body"][2] else " (in-game lean)"),
                   "description": p["desc"]} for i, p in enumerate(POSES)],
        "colours": {"haft": "h stone_4 with t teal_1 ferrules, j stone_6 pommel ring", "blade": "u teal_2 body, t teal_1 spine, 1 cream cutting edge (concave side), p water_6 tip",
                    "chain": "alternating links: j/1 face-on (2 px across) and u/t edge-on (1 px), ink outline 0", "effects": "1 cream, p water_6, 7 grass_6 glints, u teal_2, t teal_1, k water_1 deep blue-black shadow"},
        "request": "Chain Scythe: wide sweeping arcs, charged full-circle spin on the chain; right-click Reaper's Coil whips the chain out, hooks the golem, drags it to Totoy and staggers it. Damage, timing, cost, cooldown and stagger length are owner/core decisions.",
    })
    written.append(OUT / "concept_v1.json")

    # 2. weapon layers
    wl = [p["body"] for p in poses] + [p["back"] for p in poses] + [p["front"] for p in poses]
    atlas(wl, 10, CW, CH).save(OUT / "weapon_layers_v1.png")
    written.append(OUT / "weapon_layers_v1.png")
    frames = []
    for row, prefix in enumerate(["hero2_unarmed_cs_", "wpn_chain_scythe_back_", "wpn_chain_scythe_front_"]):
        for i, (p, spec) in enumerate(zip(poses, POSES)):
            e = {"name": prefix + p["name"], "rect": [i * CW, row * CH, CW, CH], "anchor": [AX, AY], "pose": p["name"],
                 "hands": [list(h) for h in p["hands"]]}
            if p["geo"]:
                pm, hd = p["geo"]
                e["scythe"] = {"pommel": [round(v, 1) for v in pm], "head": [round(v, 1) for v in hd], "blade_side": spec["scythe"]["side"],
                               "blade_len": spec["scythe"]["blade"], "grip_hands": list(spec["scythe"].get("grip", ())), "layer": spec["layer"]}
            e["chains"] = [{"points": [q if isinstance(q, str) else list(q) for q in ctrl], "layer": lay} for ctrl, lay in spec["chains"]]
            e["fists_over_weapon"] = spec["fists"]
            frames.append(e)
    write_json(OUT / "weapon_layers_v1.json", {
        **COMMON,
        "layout": "10 columns x 3 rows of 64x64 cells, all with the feet anchor (32,56). Row 1: the leaning hero body with the katana removed (same bodies as the dagger set). Row 2: scythe/chain parts BEHIND the body. Row 3: scythe/chain parts IN FRONT of the body.",
        "draw_order": ["wpn_chain_scythe_back_*", "hero2_unarmed_cs_*", "wpn_chain_scythe_front_*"],
        "point_convention": "cell pixels, x right, y down; hands = the two fists (index 0, 1) of the body; scythe = haft from pommel (chain ring) to head; blade_side +1 = the blade leaves the haft clockwise from the pommel-to-head direction (screen), -1 = counter-clockwise; chains start at the pommel or at hand0/hand1",
        "bodies": "built by tools/art/import_dagger_sprites.build_dagger_frame (leaned hero2 frames, katana removed); spin and pull use their own lean of the upright frame (make_hero_lean_sheet.build_frame with a custom Pose: spin lean 8, pull lean -14)",
        "frames": frames,
    })
    written.append(OUT / "weapon_layers_v1.json")

    # 3. effects
    fx = build_fx()
    rows = []
    arc_rows = []
    for s in (1, 2, 3):
        for ph in range(4):
            arc_rows.append((f"fx_scythe_arc_{s}_{ph + 1}", fx["arcs"][s][ph], ARC_ANCHOR, {"swing": s, "phase": PHASES[ph]}))
    for ph in range(4):
        arc_rows.append((f"fx_scythe_spin_back_{ph + 1}", fx["spin_back"][ph], SPIN_ANCHOR, {"phase": PHASES[ph], "layer": "behind the hero"}))
    for ph in range(4):
        arc_rows.append((f"fx_scythe_spin_front_{ph + 1}", fx["spin_front"][ph], SPIN_ANCHOR, {"phase": PHASES[ph], "layer": "in front of the hero"}))
    rows.append(arc_rows)
    rows.append([(f"fx_chain_whip_{k + 1}", g, (0, 16), {"hand": [0, 16], "target": [120, 16]}) for k, g in enumerate(fx["whip"])])
    rows.append([(f"fx_chain_scythe_fly_{k + 1}", g, (16, 16), {"rotation_deg": k * 45}) for k, g in enumerate(fx["flying"])]
                + [(f"fx_chain_hook_{k + 1}", g, (16, 16), {}) for k, g in enumerate(fx["hook"])]
                + [(f"fx_scythe_stagger_{k + 1}", g, (16, 16), {}) for k, g in enumerate(fx["stagger"])])
    rows.append([(f"fx_chain_link_{k + 1}", g, (0, 4), {"ends": [[0, 4], [31, 4]]}) for k, g in enumerate(fx["segments"])]
                + [(f"fx_scythe_dizzy_{k + 1}", g, (16, 12), {}) for k, g in enumerate(fx["dizzy"])]
                + [(f"fx_scythe_scuff_{k + 1}", g, (16, 8), {}) for k, g in enumerate(fx["scuff"])])
    rows.append([(f"fx_chain_pull_{k + 1}", g, (12, 44), {}) for k, g in enumerate(fx["pull"])]
                + [(f"fx_chain_dust_{k + 1}", g, (8, 14), {}) for k, g in enumerate(fx["dust"])])
    sheet, fx_frames = pack(rows, 768)
    sheet.save(OUT / "scythe_fx_v1.png")
    written.append(OUT / "scythe_fx_v1.png")
    write_json(OUT / "scythe_fx_v1.json", {
        **COMMON,
        "groups": {
            "fx_scythe_arc_<swing>_<1..4>": "96x64, anchor (40,56) = the hero's feet. Swing 1 wide horizontal sweep (from behind, around the front, out to the right), 2 reverse rising arc (front-low over the top to the back), 3 overhead-to-low slam. Phases lead/peak/follow/fragments, about 33/50/50/66 ms. Draw over the hero.",
            "fx_scythe_spin_back_/front_<1..4>": "96x64, anchor (48,56) = the hero's feet. The charged full-circle ring split into the half behind the hero (draw first) and the half in front (draw last); same phase numbers belong together. Loop 2 (peak) while the spin lasts, then 3, 4.",
            "fx_chain_whip_<1..6>": "128x32, anchor (0,16) = the throwing hand; the target hook point is (120,16). 1-4 the chain unreels with a wave and the scythe tumbling at its tip, 5 full reach with the blade turning to hook, 6 snapped taut. For other distances build it from fx_chain_link_* + fx_chain_scythe_fly_*.",
            "fx_chain_scythe_fly_<1..8>": "32x32, anchor (16,16) = the pommel ring where the chain attaches; 8 rotations, 45 deg apart, clockwise (1 = blade pointing up).",
            "fx_chain_link_<1..4>": "32x8, from (0,4) to (31,4); 1/2 taut (two link phases: alternate for a shimmer, both tile end to end, period 4 px), 3 slight wave, 4 spectral (glowing rim, during the skill). Rotate between two points.",
            "fx_chain_hook_<1..5>": "32x32, anchor (16,16) = the hook point on the target: bite, clink flash, ring, sparks, motes (about 40 ms each).",
            "fx_chain_pull_<1..4>": "64x48, anchor (12,44) = the dragged golem's feet; the golem moves toward -x (toward Totoy facing right), streaks trail to +x. Mirror for the other side.",
            "fx_chain_dust_<1..4>": "64x16, anchor (8,14) = the golem's leading foot on the ground; puffs trail to +x.",
            "fx_scythe_scuff_<1..4>": "32x16 ground decal, anchor (16,8); 1 fresh .. 4 nearly gone. Lay end to end along the drag path, older ones further back.",
            "fx_scythe_stagger_<1..6>": "32x32, anchor (16,16) = the golem's chest when it arrives: pinch, star, ring, broken ring, sparse stars, motes (about 45 ms each).",
            "fx_scythe_dizzy_<1..4>": "32x16 loop, anchor (16,12) = just above the staggered golem's head; about 90 ms per frame while the stagger lasts.",
        },
        "frames": fx_frames,
    })
    written.append(OUT / "scythe_fx_v1.json")

    # 4. medallions
    sk, wp = skill_medallion(), weapon_medallion()
    med = Image.new("RGBA", (24 + 48, 48), (0, 0, 0, 0))
    med.alpha_composite(to_image(sk), (0, 12))
    med.alpha_composite(to_image(wp), (24, 0))
    med.save(OUT / "skill_medallions_v1.png")
    written.append(OUT / "skill_medallions_v1.png")
    write_json(OUT / "skill_medallions_v1.json", {
        **COMMON,
        "style": "Ring copied from the existing ui_aspect_gale_cut_1 (24px) and ui_weapon_sword_1 (48px) medallions, like the dual dagger icons; new interior drawn here",
        "frames": [
            {"name": "ui_aspect_reapers_coil_1", "rect": [0, 12, 24, 24], "anchor": [12, 12], "use": "right-click skill icon (coiled chain + hooked blade)"},
            {"name": "ui_weapon_chain_scythe_1", "rect": [24, 0, 48, 48], "anchor": [24, 24], "use": "weapon slot medallion (scythe with its chain)"},
        ],
    })
    written.append(OUT / "skill_medallions_v1.json")
    for p in written:
        if p.suffix == ".png":
            check_hard(p)

    # 5. previews (viewing only)
    make_previews(poses, fx, sk, wp)
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*") if p.suffix in (".png", ".json", ".gif"))))
    return 0


# ------------------------------------------------------------------------------------------------- previews
BG_DARK = PAL.by_symbol["0"]
BG_GRASS = PAL.by_symbol["4"]


def on_cell(w: int, h: int, layers: list[tuple[Grid, int, int]]) -> Grid:
    g = blank(w, h)
    for lay, x, y in layers:
        paste(g, lay, x, y)
    return g


def tiled(seg: Grid, n: int = 3) -> Grid:
    g = blank(len(seg[0]) * n, len(seg))
    for i in range(n):
        paste(g, seg, i * len(seg[0]), 0)
    return g


def make_previews(poses: list[dict], fx: dict, sk: Grid, wp: Grid) -> None:
    by = {p["name"]: p for p in poses}
    ax, ay = ARC_ANCHOR
    swing_comp = []
    for s, pn in ((1, "swing_1"), (2, "swing_2"), (3, "swing_3")):
        for ph in range(4):
            swing_comp.append(to_image(on_cell(AW, AH, [(by[pn]["full"], ax - AX, ay - AY), (fx["arcs"][s][ph], 0, 0)])))
    sx, sy = SPIN_ANCHOR
    spin_body = copy(by["spin"]["body"])
    spin_comp = [to_image(on_cell(AW, AH, [(fx["spin_back"][ph], 0, 0), (spin_body, sx - AX, sy - AY), (fx["spin_front"][ph], 0, 0)])) for ph in range(4)]
    groups = [
        ("Armed poses: ready, walk carry, swing 1-3, charged spin, skill wind-up, whip-out, drag/pull, recovery", [to_image(p["full"]) for p in poses]),
        ("Bodies (leaning hero2, katana removed)", [to_image(p["body"]) for p in poses]),
        ("Back layer (behind the body)", [to_image(p["back"]) for p in poses]),
        ("Front layer (in front of the body)", [to_image(p["front"]) for p in poses]),
        ("Scythe arcs raw: swing 1, 2, 3 x lead/peak/follow/fragments", [to_image(g) for s in (1, 2, 3) for g in fx["arcs"][s]]),
        ("Arcs over the swing poses", swing_comp),
        ("Charged spin ring: back half, front half, composite over the spin body", [to_image(g) for g in fx["spin_back"]] + [to_image(g) for g in fx["spin_front"]] + spin_comp),
        ("Chain whip 1-6 (hand at left edge, target at x=120)", [to_image(g) for g in fx["whip"]]),
        ("Chain links 1-4 tiled x3 | flying scythe 8 rotations | hook clink 1-5", [to_image(tiled(g)) for g in fx["segments"]] + [to_image(g) for g in fx["flying"]] + [to_image(g) for g in fx["hook"]]),
        ("Pull streaks 1-4 | dust trail 1-4", [to_image(g) for g in fx["pull"]] + [to_image(g) for g in fx["dust"]]),
        ("Stagger burst 1-6 | dizzy stars 1-4 | ground scuffs 1-4", [to_image(g) for g in fx["stagger"]] + [to_image(g) for g in fx["dizzy"]] + [to_image(g) for g in fx["scuff"]]),
        ("Medallions: skill 24px, weapon 48px", [to_image(sk), to_image(wp)]),
    ]
    for tag, bg in (("dark", BG_DARK), ("grass", BG_GRASS)):
        M.labelled_sheet(groups, bg, 4, 10).convert("RGB").save(OUT / f"preview_contact_{tag}.png")
    make_skill_gif(by, fx)
    make_combo_gif(by, fx)


SW_, SH_ = 192, 120  # GIF scene at game pixels (shown at 4x)


def grass_scene() -> Image.Image:
    im = Image.new("RGBA", (SW_, SH_), BG_GRASS + (255,))
    d = ImageDraw.Draw(im)
    rng = random.Random(4)
    for _ in range(140):
        d.point((rng.randrange(SW_), rng.randrange(SH_)), fill=PAL.by_symbol[rng.choice("35")] + (255,))
    return im


def load_sprite(name: str) -> tuple[Grid, tuple[int, int]]:
    s = artlib.parse_sprite(ROOT / "art" / "src" / f"{name}.txt")
    return [list(r) for r in s.rows], s.anchor


def save_gif(frames: list[tuple[Image.Image, int]], name: str, strip_name: str) -> None:
    Z = 4
    big = [im.convert("RGB").resize((SW_ * Z, SH_ * Z), Image.NEAREST) for im, _ in frames]
    big[0].save(OUT / name, save_all=True, append_images=big[1:], duration=[ms for _, ms in frames], loop=0, disposal=1)
    cols, Zs = 8, 2
    strip = Image.new("RGB", (cols * SW_ * Zs, ((len(frames) + cols - 1) // cols) * SH_ * Zs), BG_DARK)
    for i, (im, _) in enumerate(frames):
        strip.paste(im.convert("RGB").resize((SW_ * Zs, SH_ * Zs), Image.NEAREST), ((i % cols) * SW_ * Zs, (i // cols) * SH_ * Zs))
    strip.save(OUT / strip_name)


def chain_between(g: Grid, a: tuple[float, float], b: tuple[float, float], amp: float, phase: int, sag: float = 0.0,
                  waves: float = 1.5, spectral: bool = False) -> list[tuple[int, int]]:
    """A chain from a to b on a scene grid with a travelling wave of amplitude amp and a sag."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    pts = []
    for i in range(41):
        s = i / 40
        off = amp * math.sin(2 * math.pi * (s * waves - phase * 0.3)) * math.sin(math.pi * s)
        pts.append((a[0] + dx * s + nx * off, a[1] + dy * s + ny * off + sag * math.sin(math.pi * s)))
    path = pixel_path(pts)
    layer = blank(len(g[0]), len(g))
    for (x, y), c in chain_pixels(path, phase).items():
        put(layer, x, y, c)
    outline_layer(layer, "0")
    if spectral:  # a sparse teal glow along the taut chain during the skill
        glow = blank(len(g[0]), len(g))
        for i, (x, y) in enumerate(path):
            if (i + phase) % 3 == 0:
                for ox, oy in ((0, -2), (0, 2)):
                    if get(layer, x + ox, y + oy) == T:
                        put(glow, x + ox, y + oy, "u" if (i // 3) % 2 else "7")
        paste(g, glow, 0, 0)
    paste(g, layer, 0, 0)
    return path


GOLEM_LEFT = {"idle": 21, "hurt": 24}  # golem feet x minus its leftmost pixel (golem2_idle_1 / golem2_hurt_1)


def fist_layer(p: dict, i: int, toward: tuple[float, float]) -> Grid:
    """A 64x64 layer with only hand i's fist, closed around a weapon running toward the given cell point."""
    g = blank(CW, CH)
    h = p["hands"][i]
    fist_over(g, p["body"], h, (toward[0] - h[0], toward[1] - h[1]))
    return g


def golem_flash(g: Grid) -> Grid:
    """The hit flash (one frame): the golem's light and mid pixels go cream/pale, its darks stay, so the form still reads."""
    light = set("4567cdhijlmnorstu1")
    return [[("1" if c in light and (x + y) % 3 else ("p" if c in light else c)) for x, c in enumerate(row)] for y, row in enumerate(g)]


def make_skill_gif(by: dict, fx: dict) -> None:
    """Reaper's Coil: wind-up, whip-out, the hook catches the golem (clink), Totoy drags it until it stands right in front
    of him (streaks, dust, scuffs), stagger burst on the golem, dizzy stars."""
    scene = grass_scene()
    hero_f = (40, 98)
    gy = 98
    gx0 = 152
    gx1 = hero_f[0] + 13 + GOLEM_LEFT["hurt"]  # arrival: the golem's front edge 13 px ahead of Totoy's feet (adjacent)
    golem_idle, (gax, gay) = load_sprite("golem2_idle_1")
    golem_hurt, (hax, hay) = load_sprite("golem2_hurt_1")
    out: list[tuple[Image.Image, int]] = []

    def hero_at(p: dict, part: str = "full") -> tuple[Grid, int, int]:
        return p[part], hero_f[0] - AX, hero_f[1] - AY

    def hand_of(p: dict, i: int = 0) -> tuple[int, int]:
        h = p["hands"][i]
        return hero_f[0] - AX + h[0], hero_f[1] - AY + h[1]

    def fist_at(p: dict, i: int, scene_pt: tuple[float, float]) -> tuple[Grid, int, int]:
        ox, oy = hero_f[0] - AX, hero_f[1] - AY
        return fist_layer(p, i, (scene_pt[0] - ox, scene_pt[1] - oy)), ox, oy

    def compose(layers: list[tuple[Grid, int, int]], ms: int) -> None:
        im = scene.copy()
        sg = blank(SW_, SH_)
        for g, x, y in layers:
            paste(sg, g, rnd(x), rnd(y))
        im.alpha_composite(to_image(sg))
        out.append((im, ms))

    def golem(x: float, hurt: bool = False, shake: int = 0, flash: bool = False) -> tuple[Grid, int, int]:
        g, a = (golem_hurt, (hax, hay)) if hurt else (golem_idle, (gax, gay))
        return (golem_flash(g) if flash else g), rnd(x) - a[0] + shake, gy - a[1]

    def hook_pt(x: float, hurt: bool = True) -> tuple[int, int]:
        """Where the blade bites: 7 px inside the golem's front edge, chest height."""
        return rnd(x) - GOLEM_LEFT["hurt" if hurt else "idle"] + 7, gy - 26

    for _ in range(3):
        compose([golem(gx0), hero_at(by["ready"])], 150)
    for _ in range(2):
        compose([golem(gx0), hero_at(by["windup"])], 110)
    # whip-out: the chain unreels from the lead fist with the scythe tumbling at the tip, straight at the golem
    whip = by["whip"]
    hand = hand_of(whip, 0)
    tgt = hook_pt(gx0, hurt=False)
    for k, frac in enumerate([0.2, 0.42, 0.64, 0.84]):
        g = blank(SW_, SH_)
        tip = (hand[0] + (tgt[0] - hand[0]) * frac, hand[1] + (tgt[1] - hand[1]) * frac - 6 * math.sin(math.pi * frac))
        chain_between(g, hand, tip, 3.5 * (1 - frac) + 1, k)
        compose([golem(gx0), hero_at(whip, "body"), (g, 0, 0), fist_at(whip, 0, tip),
                 (fx["flying"][(2 * k + 2) % 8], rnd(tip[0]) - 16, rnd(tip[1]) - 16)], 45)
    # the catch: the blade sinks into the golem's chest, clink flash ON the golem, the golem flinches
    hk = blank(32, 32)
    draw_scythe(hk, (9, 18), (17, 10), 1, 11, width=1.2)  # pommel (chain end) at (9,18); the blade curls into the golem

    def hooked(x: float, hurt: bool = True) -> list[tuple[Grid, int, int]]:
        hp = hook_pt(x, hurt)
        return [(hk, hp[0] - 15, hp[1] - 14)]

    def chain_end(x: float, hurt: bool = True) -> tuple[int, int]:
        hp = hook_pt(x, hurt)
        return hp[0] - 6, hp[1] + 4

    for k in range(4):
        hurt = k > 0
        g = blank(SW_, SH_)
        end = chain_end(gx0, hurt)
        chain_between(g, hand, end, 0, k, spectral=k > 0)
        hp = hook_pt(gx0, hurt)
        compose([golem(gx0, hurt=hurt, shake=(0, 2, 1, 0)[k], flash=k == 1), hero_at(whip, "body"), (g, 0, 0),
                 fist_at(whip, 0, end)] + hooked(gx0, hurt) + [(fx["hook"][min(4, k)], hp[0] - 16, hp[1] - 16)], (45, 60, 55, 50)[k])
    # drag: Totoy leans back and hauls hand over hand; the golem slides until it stands right in front of him
    pull = by["pull"]
    n = 9
    scuffs: list[tuple[int, int]] = []
    hand_p = hand_of(pull, 0)
    for k in range(n):
        f = k / (n - 1)
        e = f * f * (3 - 2 * f)
        x = gx0 + (gx1 - gx0) * e
        g = blank(SW_, SH_)
        end = chain_end(x)
        chain_between(g, hand_p, end, 0, k, spectral=True)
        layers = []
        if k % 2 == 0:
            scuffs.append((rnd(x) + 6, gy))
        for j, (sx, sy) in enumerate(scuffs):
            age = len(scuffs) - 1 - j
            layers.append((fx["scuff"][min(3, age // 2)], sx - 16, sy - 8))
        layers.append((fx["dust"][min(3, 1 + k // 3)], rnd(x) + 10 - 8, gy - 14))
        layers += [golem(x, hurt=True), (fx["pull"][0 if k < 2 else (1 if k < 5 else 2)], rnd(x) + 14 - 12, gy - 44)]
        layers += [hero_at(pull, "body"), (g, 0, 0), fist_at(pull, 0, end), fist_at(pull, 1, end)] + hooked(x)
        compose(layers, 45 if 2 <= k <= 6 else 60)
    # arrival right in front of Totoy: stagger burst on the golem's chest, the blade wrenched free, scythe back in hand
    x = gx1
    chest = (rnd(x) - 4, gy - 26)
    for k in range(6):
        layers = [(fx["scuff"][min(3, 1 + k // 2)], sx - 16, sy - 8) for sx, sy in scuffs]
        layers += [(fx["dust"][3], rnd(x) + 10 - 8, gy - 14)] if k < 2 else []
        layers.append(golem(x, hurt=True, shake=(3, -2, 2, -1, 1, 0)[k], flash=k == 0))
        if k < 2:
            g = blank(SW_, SH_)
            end = chain_end(x)
            chain_between(g, hand_p, end, 0, k, sag=2 + 2 * k)
            layers += [hero_at(pull, "body"), (g, 0, 0), fist_at(pull, 0, end), fist_at(pull, 1, end)] + hooked(x)
        else:
            layers.append(hero_at(by["recovery"]))
        layers.append((fx["stagger"][k], chest[0] - 16, chest[1] - 16))
        compose(layers, 55)
    for k in range(8):
        layers = [(fx["scuff"][3], sx - 16, sy - 8) for sx, sy in scuffs] if k < 4 else []
        layers += [golem(x, hurt=True), hero_at(by["ready" if k >= 2 else "recovery"]),
                   (fx["dizzy"][k % 4], rnd(x) - 2 - 16, gy - 50 - 12)]
        compose(layers, 110)
    save_gif(out, "skill_sequence.gif", "skill_sequence_strip.png")


def make_combo_gif(by: dict, fx: dict) -> None:
    """Three swings then the charged spin, with the golem standing INSIDE the reach (arcs reach about 34 px from the
    feet): every active frame lands on it with a clink/stagger flash, a white hit frame and a recoil."""
    scene = grass_scene()
    hero_f = (64, 98)
    golem_idle, (gax, gay) = load_sprite("golem2_idle_1")
    golem_hurt, (hax, hay) = load_sprite("golem2_hurt_1")
    gy = 98
    gx = hero_f[0] + 22 + GOLEM_LEFT["idle"]  # the golem's front edge 22 px ahead of the feet: inside the 34 px reach
    out: list[tuple[Image.Image, int]] = []

    def compose(layers: list[tuple[Grid, int, int]], ms: int) -> None:
        im = scene.copy()
        sg = blank(SW_, SH_)
        for g, x, y in layers:
            paste(sg, g, rnd(x), rnd(y))
        im.alpha_composite(to_image(sg))
        out.append((im, ms))

    def golem(state: str = "idle", push: int = 0) -> tuple[Grid, int, int]:
        """idle / hit (white flash, knocked back 3 px) / hurt (recoiling)."""
        if state == "idle":
            return golem_idle, gx - gax, gy - gay
        if state == "hit":
            return golem_flash(golem_hurt), gx - hax + 3 + push, gy - hay
        return golem_hurt, gx - hax + 2 + push, gy - hay

    def hero(p: dict, part: str = "full") -> tuple[Grid, int, int]:
        return p[part], hero_f[0] - AX, hero_f[1] - AY

    arc_at = lambda g: (g, hero_f[0] - ARC_ANCHOR[0], hero_f[1] - ARC_ANCHOR[1])  # noqa: E731
    front = gx - GOLEM_LEFT["idle"]
    hits = {1: (front + 5, gy - 14), 2: (front + 4, gy - 30), 3: (front + 4, gy - 10)}  # where each arc crosses the golem
    for _ in range(3):
        compose([golem(), hero(by["ready"])], 140)
    for s, pn in ((1, "swing_1"), (2, "swing_2"), (3, "swing_3")):
        compose([golem(), hero(by["walk_carry" if s == 1 else "recovery"])], 80)
        hx, hy = hits[s]
        for ph, ms in zip(range(4), (40, 60, 55, 60)):
            state = ("idle", "hit", "hurt", "hurt")[ph]
            extra = []
            if ph == 1:
                extra = [(fx["stagger"][1], hx - 16, hy - 16)]
            elif ph == 2:
                extra = [(fx["hook"][2], hx - 16, hy - 16)]
            elif ph == 3:
                extra = [(fx["stagger"][4], hx - 16, hy - 16)]
            compose([golem(state), hero(by[pn]), arc_at(fx["arcs"][s][ph])] + extra, ms)
    compose([golem("hurt"), hero(by["recovery"])], 140)
    # charge: wind-up with a pulsing teal rim, then the spin (the ring reaches the golem; it is hit each time the
    # scythe sweeps through its side)
    for k in range(3):
        body = copy(by["windup"]["full"])
        for y in range(CH):
            for x in range(CW):
                if body[y][x] != T and (get(body, x, y - 1) == T or get(body, x + 1, y) == T) and (x + 2 * y + k) % 3 == 0:
                    body[y][x] = "u" if (x + y) % 2 else "7"
        compose([golem(), (body, hero_f[0] - AX, hero_f[1] - AY)], 90)
    sp = by["spin"]
    ox, oy = hero_f[0] - AX, hero_f[1] - AY
    hand = (ox + sp["hands"][0][0], oy + sp["hands"][0][1])
    cx, cy, rx, ry = SPIN[0], SPIN[1], SPIN[2], SPIN[3]
    ring_seq = [1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 4]
    hit_age = 9
    for k, ph in enumerate(ring_seq):
        th = math.radians(200 + k * 80)
        sxp = hero_f[0] - SPIN_ANCHOR[0] + cx + math.cos(th) * (rx - 3)
        syp = hero_f[1] - SPIN_ANCHOR[1] + cy + math.sin(th) * (ry - 1)
        g = blank(SW_, SH_)
        whirling = k < 10
        hit_now = whirling and math.cos(th) > 0.75
        hit_age = 0 if hit_now else hit_age + 1
        state = "hit" if hit_age == 0 else ("hurt" if hit_age < 3 else "idle")
        layers = [golem(state), (fx["spin_back"][ph - 1], hero_f[0] - SPIN_ANCHOR[0], hero_f[1] - SPIN_ANCHOR[1])]
        if whirling:
            chain_between(g, hand, (sxp, syp), 0, k)
            rot = round(((200 + k * 80 + 90) % 360) / 45) % 8  # blade leads, tangent to the circle
            sc = (fx["flying"][rot], rnd(sxp) - 16, rnd(syp) - 16)
            fist = (fist_layer(sp, 0, (sxp - ox, syp - oy)), ox, oy)
            if math.sin(th) < 0:
                layers += [(g, 0, 0), sc, hero(sp, "body"), fist]
            else:
                layers += [hero(sp, "body"), (g, 0, 0), fist, sc]
        else:
            layers.append(hero(by["recovery"]))
        layers.append((fx["spin_front"][ph - 1], hero_f[0] - SPIN_ANCHOR[0], hero_f[1] - SPIN_ANCHOR[1]))
        if hit_age == 0:
            layers.append((fx["stagger"][1], rnd(sxp) + 4 - 16, rnd(syp) - 4 - 16))
        elif hit_age == 1:
            layers.append((fx["hook"][2], front + 4 - 16, gy - 16 - 16))
        compose(layers, 50)
    for _ in range(3):
        compose([golem(), hero(by["ready"])], 150)
    save_gif(out, "combo_sequence.gif", "combo_sequence_strip.png")


if __name__ == "__main__":
    sys.exit(main())
