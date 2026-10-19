"""Import the approved Dual Dagger + Lightning Form art into in-game sprite sources (art/src/*.txt).

Reference: art/reference/dual_dagger/ (approved concept, weapon layers, lightning layers, slash trails, medallions),
drawn by tools/art/make_dual_dagger_art.py. This script reuses that script's routines (katana removal, dagger
drawing style, lightning body, aura, cuts, sparks, chain bolts, medallions) and generalises them to every hero frame
the game animates.

Writes (all deterministic: fixed seeds, sorted iteration; running twice gives identical files):
  art/src/totoy_dagger_<state>_right_<n>.txt      dagger-armed hero, one per animated hero2_* frame (+ a 4th swing)
  art/src/totoy_lightning_<state>_right_<n>.txt   the same frames in Lightning Form (pale blue body, lightning rim)
  art/src/fx_lightning_*.txt                      aura, afterimages, cuts, sparks, chain, sky strike, ground, blink
  art/src/ui_weapon_dual_dagger_1.txt, art/src/ui_aspect_lightning_form_1.txt
  art/build/dagger_sprites_manifest.json          name -> frames, size, anchor (for the wiring task)
  docs/previews/dual_dagger_import_*.png          review sheets at 4x (viewing only, not game art)

Gold (x, y) and red (z, A) are never used. Anchors of the hero frames are the feet point of the matching
hero2_* frame (the canvas only grows when a dagger reaches past it; the anchor moves with it, so feet line up).

Run from the project root, then validate, build and preview:
  python tools/art/import_dagger_sprites.py
  python tools/art/validate_art.py; python tools/art/build_art.py; python tools/art/preview_art.py
Options: --no-previews (skip the review sheets).
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import make_dual_dagger_art as M  # noqa: E402  (no side effects on import)

ROOT = artlib.ROOT
SRC = artlib.SRC_DIR
BUILD = artlib.BUILD_DIR
PREVIEWS = ROOT / "docs" / "previews"
PAL = artlib.load_palette()
T = "."
SKIN = set("qrs")
INK = set("08")
STONE = set("efgh")
FORBIDDEN = set(PAL.reserved)
GENERATOR = "tools/art/import_dagger_sprites.py"

Grid = list  # list[list[str]]
blank, put, get, copy, paste = M.blank, M.put, M.get, M.copy, M.paste


# ---------------------------------------------------------------------------------------------- frame table
# Hero states the game animates (presentation/arena/animation.gd PLAYER + attack swings). Each dagger frame is built
# from the hero2_* frame of the same name; swing 4 is new and borrows bodies from other frames (see SWING4).
STATES: list[tuple[str, int]] = [("idle", 4), ("walk", 6), ("dash", 4), ("parry", 6), ("hurt", 4), ("victory", 6),
                                 ("attack1", 6), ("attack2", 6), ("attack3", 6)]
# Swing 4 (combo finisher, twin strike toward the sky bolt): windup = gather and raise both daggers, active = drive
# both down, recovery = settle. Frames 1-2 windup, 3-4 active, 5-6 recovery like the other swings.
SWING4: list[str] = ["hero2_parry_right_3", "hero2_victory_right_3", "hero2_attack3_right_3", "hero2_attack3_right_4",
                     "hero2_attack3_right_5", "hero2_attack1_right_6"]
LIGHTNING_STATES = ["idle", "walk", "dash", "parry", "hurt", "attack1", "attack2", "attack3", "attack4"]

# Hand points, measured by eye on 9x grids of the katana-stripped hero2_* frames (frame pixels, x right, y down):
# frame -> [(x, y, blade angle deg, layer, lead)]. Angle 0 = right (facing), 90 = down. Layer "f" = in front of
# the body, "b" = behind. lead = 1 marks the hand that strikes in an attack frame (longer blade in the active
# frames plus the speed arc). Relaxed poses hold both daggers in reverse grip, blades down.
# Swing 1 = front-hand thrust, swing 2 = rising cut with the other hand, swing 3 = overhead-to-low cut,
# swing 4 (keys "swing4:<n>") = twin finisher (both hands lead).
HANDS: dict[str, list[tuple[int, int, float, str, int]]] = {
    "hero2_idle_right_1": [(6, 22, 115, "f", 0), (17, 22, 55, "b", 0)],
    "hero2_idle_right_2": [(6, 22, 112, "f", 0), (17, 22, 58, "b", 0)],
    "hero2_idle_right_3": [(7, 22, 118, "f", 0), (18, 21, 52, "b", 0)],
    "hero2_idle_right_4": [(6, 22, 115, "f", 0), (17, 22, 55, "b", 0)],
    "hero2_walk_right_1": [(6, 21, 125, "f", 0), (19, 20, 45, "b", 0)],
    "hero2_walk_right_2": [(5, 20, 135, "f", 0), (18, 20, 50, "b", 0)],
    "hero2_walk_right_3": [(6, 21, 125, "f", 0), (19, 20, 45, "b", 0)],
    "hero2_walk_right_4": [(7, 21, 120, "f", 0), (20, 19, 40, "b", 0)],
    "hero2_walk_right_5": [(6, 21, 120, "f", 0), (18, 19, 45, "b", 0)],
    "hero2_walk_right_6": [(5, 20, 130, "f", 0), (18, 20, 50, "b", 0)],
    "hero2_dash_right_1": [(17, 13, 178, "f", 0), (39, 15, 15, "b", 0)],
    "hero2_dash_right_2": [(21, 10, 178, "f", 0), (45, 14, 10, "b", 0)],
    "hero2_dash_right_3": [(22, 10, 180, "f", 0), (44, 14, 8, "b", 0)],
    "hero2_dash_right_4": [(16, 18, 140, "f", 0), (40, 11, -25, "b", 0)],
    "hero2_parry_right_1": [(22, 16, -55, "f", 0), (21, 17, 35, "b", 0)],
    "hero2_parry_right_2": [(17, 15, -55, "f", 0), (16, 16, 35, "b", 0)],
    "hero2_parry_right_3": [(16, 14, -55, "f", 0), (15, 15, 35, "b", 0)],
    "hero2_parry_right_4": [(26, 11, -35, "f", 0), (25, 12, 30, "b", 0)],
    "hero2_parry_right_5": [(25, 16, -50, "f", 0), (24, 17, 35, "b", 0)],
    "hero2_parry_right_6": [(5, 20, 120, "f", 0), (18, 20, 50, "b", 0)],
    "hero2_hurt_right_1": [(6, 22, 115, "f", 0), (17, 22, 55, "b", 0)],
    "hero2_hurt_right_2": [(6, 22, 110, "f", 0), (21, 11, -15, "b", 0)],
    "hero2_hurt_right_3": [(6, 19, 150, "f", 0), (26, 7, -40, "b", 0)],
    "hero2_hurt_right_4": [(5, 22, 115, "f", 0), (17, 22, 55, "b", 0)],
    "hero2_victory_right_1": [(4, 15, 120, "f", 0), (10, 16, 10, "b", 0)],
    "hero2_victory_right_2": [(6, 17, 115, "f", 0), (11, 16, -40, "b", 0)],
    "hero2_victory_right_3": [(7, 9, -70, "f", 0), (17, 24, 60, "b", 0)],
    "hero2_victory_right_4": [(9, 14, 120, "f", 0), (17, 16, 90, "b", 0)],
    "hero2_victory_right_5": [(5, 14, 110, "f", 0), (12, 16, 90, "b", 0)],
    "hero2_victory_right_6": [(5, 13, 110, "f", 0), (12, 16, 90, "b", 0)],
    "hero2_attack1_right_1": [(13, 13, 170, "b", 0), (30, 15, 30, "f", 1)],
    "hero2_attack1_right_2": [(16, 10, 175, "b", 0), (33, 15, 25, "f", 1)],
    "hero2_attack1_right_3": [(15, 14, 150, "b", 0), (28, 13, 0, "f", 1)],
    "hero2_attack1_right_4": [(8, 16, 165, "b", 0), (29, 13, 0, "f", 1)],
    "hero2_attack1_right_5": [(19, 20, 115, "b", 0), (30, 20, 40, "f", 1)],
    "hero2_attack1_right_6": [(6, 21, 120, "f", 0), (19, 20, 45, "b", 1)],
    "hero2_attack2_right_1": [(15, 16, 150, "b", 1), (31, 16, 30, "f", 0)],
    "hero2_attack2_right_2": [(13, 17, 155, "b", 1), (30, 16, 20, "f", 0)],
    "hero2_attack2_right_3": [(25, 12, -40, "f", 1), (10, 16, 150, "b", 0)],
    "hero2_attack2_right_4": [(13, 6, -75, "f", 1), (21, 20, 40, "b", 0)],
    "hero2_attack2_right_5": [(17, 16, -35, "f", 1), (10, 15, 120, "b", 0)],
    "hero2_attack2_right_6": [(5, 19, 120, "f", 0), (17, 19, 50, "b", 1)],
    "hero2_attack3_right_1": [(16, 8, -150, "f", 1), (15, 9, -110, "b", 0)],
    "hero2_attack3_right_2": [(16, 6, -160, "f", 1), (15, 7, -115, "b", 0)],
    "hero2_attack3_right_3": [(22, 18, 35, "f", 1), (20, 16, 5, "b", 0)],
    "hero2_attack3_right_4": [(23, 18, 30, "f", 1), (21, 16, 0, "b", 0)],
    "hero2_attack3_right_5": [(23, 18, 25, "f", 1), (21, 15, -5, "b", 0)],
    "hero2_attack3_right_6": [(5, 20, 120, "f", 0), (17, 19, 50, "b", 1)],
    "swing4:1": [(16, 14, -60, "f", 1), (15, 15, -100, "b", 1)],
    "swing4:2": [(7, 9, -88, "f", 1), (17, 24, 60, "b", 1)],
    "swing4:3": [(22, 18, 55, "f", 1), (20, 16, 30, "b", 1)],
    "swing4:4": [(23, 18, 50, "f", 1), (21, 16, 20, "b", 1)],
    "swing4:5": [(23, 18, 40, "f", 0), (21, 15, 10, "b", 0)],
    "swing4:6": [(6, 21, 120, "f", 0), (19, 20, 45, "b", 0)],
}
# Katana hilt crumbs the automatic removal cannot tell from the body: frame -> [(x0, y0, x1, y1)] cleared (inclusive).
CRUMBS: dict[str, list[tuple[int, int, int, int]]] = {"hero2_victory_right_1": [(15, 12, 17, 20)]}

# Frames where both fists hold one katana grip (a crossed-dagger guard there), and states with arms at rest.
TWO_HANDED = {f"hero2_parry_right_{n}" for n in range(1, 6)}
RELAXED = {"idle", "walk", "hurt"}

def frame_names() -> list[tuple[str, str, int, str]]:
    """(dagger state, hero2 source frame, frame index, phase) for every dagger frame."""
    out = []
    for state, count in STATES:
        for n in range(1, count + 1):
            out.append((state, f"hero2_{state}_right_{n}", n, phase_of(state, n)))
    for n, src in enumerate(SWING4, start=1):
        out.append(("attack4", src, n, phase_of("attack4", n)))
    return out


def phase_of(state: str, n: int) -> str:
    if state.startswith("attack"):
        return ("windup", "windup", "active", "active", "recovery", "recovery")[n - 1]
    return "pose"


# ---------------------------------------------------------------------------------------------- katana removal
def strip_katana(src: Grid, name: str = "") -> Grid:
    """make_dual_dagger_art.strip_katana plus: drop the katana's hilt/scabbard crumbs (small stone-only islands
    that touched the blade) left on some frames (victory)."""
    g = M.strip_katana(src)
    h, w = len(g), len(g[0])
    blade = {(x, y) for y in range(h) for x in range(w) if src[y][x] in M.BLADE}
    seen: set[tuple[int, int]] = set()
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or g[y][x] in INK or g[y][x] == T:
                continue
            comp, stack = [], [(x, y)]
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        p = (cx + dx, cy + dy)
                        if p not in seen and 0 <= p[0] < w and 0 <= p[1] < h and g[p[1]][p[0]] not in INK and g[p[1]][p[0]] != T:
                            seen.add(p)
                            stack.append(p)
            stone_only = all(g[cy][cx] in STONE for cx, cy in comp)
            touches = any((cx + dx, cy + dy) in blade for cx, cy in comp for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if stone_only and touches and len(comp) <= 24:
                for cx, cy in comp:
                    g[cy][cx] = T
    for x0, y0, x1, y1 in CRUMBS.get(name, []):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                put(g, x, y, T)
    for _ in range(4):  # peel the ink that outlined what was removed
        rm = []
        for y in range(h):
            for x in range(w):
                if g[y][x] in INK:
                    n = sum(get(g, x + dx, y + dy) != T for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy)
                    if n <= 2:
                        rm.append((x, y))
        for x, y in rm:
            g[y][x] = T
    return g


# ---------------------------------------------------------------------------------------------- hand detection
def geodesic(g: Grid, start: tuple[int, int]) -> dict[tuple[int, int], int]:
    h, w = len(g), len(g[0])
    dist = {start: 0}
    queue = [start]
    i = 0
    while i < len(queue):
        x, y = queue[i]
        i += 1
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                p = (x + dx, y + dy)
                if p not in dist and 0 <= p[0] < w and 0 <= p[1] < h and g[p[1]][p[0]] != T:
                    dist[p] = dist[(x, y)] + 1
                    queue.append(p)
    return dist


def forearm_angle(g: Grid, dist: dict, hand: tuple[int, int]) -> float:
    """Direction elbow -> fist: centroid of body pixels 3..6 steps back along the arm, to the fist."""
    d0 = dist.get(hand, 0)
    back = [p for p, d in dist.items() if d0 - 6 <= d <= d0 - 3 and math.hypot(p[0] - hand[0], p[1] - hand[1]) <= 7]
    if not back:
        return 90.0
    cx = sum(p[0] for p in back) / len(back)
    cy = sum(p[1] for p in back) / len(back)
    return math.degrees(math.atan2(hand[1] - cy, hand[0] - cx))


def detect_hands(src: Grid, body: Grid, two_handed: bool = False) -> list[tuple[int, int, float, str]]:
    """Two hand points with blade angles. The katana grip gives one hand and its direction; the free hand is the
    skin extremity farthest (along the body) from the chest, away from the head and the grip hand."""
    h, w = len(body), len(body[0])
    skin = [(x, y) for y in range(h) for x in range(w) if body[y][x] in SKIN]
    ys = [y for y in range(h) if any(c != T for c in body[y])]
    top = ys[0]
    band = [p for p in skin if top + 9 <= p[1] <= top + 17] or skin
    cx = sum(p[0] for p in band) / len(band)
    cy = sum(p[1] for p in band) / len(band)
    chest = min(skin, key=lambda p: (math.hypot(p[0] - cx, p[1] - cy), p))
    dist = geodesic(body, chest)
    hands: list[tuple[int, int, float]] = []
    # grip: the blade pixel closest to a skin pixel; the blade direction runs from there to the farthest blade pixel
    blade = [(x, y) for y in range(h) for x in range(w) if src[y][x] in M.BLADE]
    if blade and skin:
        best = min(((math.hypot(b[0] - s[0], b[1] - s[1]), s, b) for b in blade for s in skin), key=lambda t: (t[0], t[1], t[2]))
        if best[0] <= 2.3:
            s, b = best[1], best[2]
            far = max(blade, key=lambda p: (math.hypot(p[0] - b[0], p[1] - b[1]), p))
            ka = math.degrees(math.atan2(far[1] - b[1], far[0] - b[0]))
            if two_handed:  # both fists on one katana grip: cross the daggers there (guard X)
                return [(s[0], s[1], ka, "front"), (s[0] - 1, s[1] + 1, ka + 95, "back")]
            hands.append((s[0], s[1], ka))
    # extremities: skin pixels that are geodesic local maxima, not the face
    cands = []
    for p in skin:
        d = dist.get(p)
        if d is None or d < 5:
            continue
        if any(dist.get((p[0] + dx, p[1] + dy), -1) > d and body[p[1] + dy][p[0] + dx] in SKIN
               for dx in (-1, 0, 1) for dy in (-1, 0, 1) if 0 <= p[0] + dx < w and 0 <= p[1] + dy < h):
            continue
        if p[1] < top + 10 and d < 12:
            continue  # face
        if p[1] > ys[-1] - 7:
            continue  # boots
        cands.append((d, p))
    cands.sort(key=lambda t: (-t[0], t[1]))
    for d, p in cands:
        if len(hands) >= 2:
            break
        if all(math.hypot(p[0] - hx, p[1] - hy) >= 5 for hx, hy, _ in hands):
            hands.append((p[0], p[1], forearm_angle(body, dist, p)))
    while len(hands) < 2:  # fallback: both daggers from the one hand found
        hx, hy, a = hands[0] if hands else (w // 2, h // 2, 90.0)
        hands.append((hx, hy, a + 70))
    # layer: the hand drawn more over the torso is the near hand -> front. Approximation: the hand with more body
    # pixels around it in a 5x5 box is in front of the torso; ties go to the forward hand.
    def crowd(p):
        return sum(body[y][x] != T for y in range(max(0, p[1] - 2), min(h, p[1] + 3)) for x in range(max(0, p[0] - 2), min(w, p[0] + 3)))
    a, b = hands[0], hands[1]
    front = a if (crowd(a), a[0]) >= (crowd(b), b[0]) else b
    return [(x, y, ang, "front" if (x, y, ang) == front else "back") for x, y, ang in hands]


# ---------------------------------------------------------------------------------------------- daggers
def rnd(v: float) -> int:
    """Round half up (Python's round() rounds half to even, which leaves gaps in straight blades)."""
    return math.floor(v + 0.5)


def draw_dagger(g: Grid, hx: int, hy: int, ang: float, length: int, curve: float) -> list[tuple[int, int]]:
    """make_dual_dagger_art.dagger_layer on any canvas: pommel past the fist, stone guard, pale steel blade with a
    blue edge glint and a cream tip, 1px ink outline. Returns the blade pixels (for the speed arc)."""
    layer = blank(len(g[0]), len(g))
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    put(layer, rnd(hx - dx * 1.4), rnd(hy - dy * 1.4), "e")
    gx, gy = rnd(hx + dx * 1.5), rnd(hy + dy * 1.5)
    put(layer, gx, gy, "g")
    put(layer, rnd(gx + nx), rnd(gy + ny), "h")
    put(layer, rnd(gx - nx), rnd(gy - ny), "f")
    seen: list[tuple[int, int]] = []
    for i in range(length):
        t = 2.5 + i
        u = i / max(1, length - 1)
        off = curve * u * u
        p = (rnd(hx + dx * t + nx * off), rnd(hy + dy * t + ny * off))
        if p not in seen:
            seen.append(p)
    for i, (x, y) in enumerate(seen):
        put(layer, x, y, "p" if i == len(seen) - 1 else "j")
    for x, y in seen[1:-1]:
        ex, ey = rnd(x + nx), rnd(y + ny)
        if get(layer, ex, ey) == T and (ex, ey) not in seen:
            put(layer, ex, ey, "o")
    M.outline_layer(layer, "0", keep={(hx, hy)})
    put(layer, hx, hy, T)
    paste(g, layer, 0, 0)
    return seen


def speed_arc(g: Grid, hx: int, hy: int, ang: float, radius: float, sweep: float) -> None:
    """A thin pale arc behind the blade tip: where the dagger came from this tick (reads as a fast cut)."""
    steps = 14
    pts = []
    for i in range(steps + 1):
        a = math.radians(ang - sweep * (i + 1) / steps)
        pts.append((round(hx + math.cos(a) * radius), round(hy + math.sin(a) * radius), i))
    for x, y, i in pts:
        if get(g, x, y) == T:
            put(g, x, y, "p" if i < 4 else ("o" if i < 9 else "n"))


# ---------------------------------------------------------------------------------------------- compose frames
MARGIN = 16


def build_dagger_frame(state: str, src_name: str, n: int, phase: str) -> dict:
    s = artlib.parse_sprite(SRC / f"{src_name}.txt")
    src = [list(r) for r in s.rows]
    body = strip_katana(src, src_name)
    table = HANDS.get(src_name if state != "attack4" else f"swing4:{n}")
    swing = int(state[-1]) if state.startswith("attack") else 0
    if table is not None:
        hands = [(x, y, a, "front" if lay == "f" else "back") for x, y, a, lay, _ in table]
        leads = [bool(t[4]) for t in table]
    else:  # a frame nobody measured: automatic detection, the forward hand leads
        hands = detect_hands(src, body, two_handed=src_name in TWO_HANDED)
        if state in RELAXED:  # arms at rest: reverse grip, both blades point down (never up along the body)
            hands = [(x, y, (-a if math.sin(math.radians(a)) < 0.25 else a), layer) for x, y, a, layer in hands]
        fwd = max(range(2), key=lambda i: (hands[i][0], -i))
        leads = [i == fwd for i in range(2)]
    h, w = len(body), len(body[0])
    W, H = w + 2 * MARGIN, h + 2 * MARGIN
    back, front, arcs = blank(W, H), blank(W, H), blank(W, H)
    for i, (hx, hy, ang, layer) in enumerate(hands):
        is_lead = bool(swing) and leads[i]
        length = 7 if (is_lead and phase == "active") else 6
        target = front if layer == "front" else back
        curve = 0.6 if math.cos(math.radians(ang)) >= 0 else -0.6
        draw_dagger(target, hx + MARGIN, hy + MARGIN, ang, length, curve)
        if is_lead and phase == "active":
            sweep = {1: 0.0, 2: -80.0, 3: 75.0, 4: 85.0}[swing]
            if n % 2 == 0:
                sweep *= 0.6
            if sweep:
                speed_arc(arcs, hx + MARGIN, hy + MARGIN, ang, length + 2.6, sweep)
            else:  # straight thrust: two speed streaks behind the hand along the blade axis
                a = math.radians(ang)
                for off in (-2, 2):
                    for t in range(-7, -2):
                        put(arcs, rnd(hx + MARGIN + math.cos(a) * t - math.sin(a) * off), rnd(hy + MARGIN + math.sin(a) * t + math.cos(a) * off), "o" if t > -5 else "n")
    big = blank(W, H)
    paste(big, arcs, 0, 0)
    paste(big, back, 0, 0)
    paste(big, body, MARGIN, MARGIN)
    paste(big, front, 0, 0)
    return {"state": state, "n": n, "phase": phase, "source": src_name, "grid": big, "body": body,
            "back": back, "front": front, "arcs": arcs, "orig_size": (w, h), "orig_anchor": s.anchor, "hands": hands}


def crop_canvas(grids: list[Grid], orig_size: tuple[int, int], orig_anchor: tuple[int, int]) -> tuple[int, int, int, int, tuple[int, int]]:
    """Canvas that contains the original canvas and every opaque pixel of grids (all MARGIN-padded), with width and
    height rounded up to multiples of 8. Returns (x0, y0, w, h, anchor) in padded coordinates/new pixels."""
    w, h = orig_size
    x0, y0, x1, y1 = MARGIN, MARGIN, MARGIN + w, MARGIN + h
    for g in grids:
        for y, row in enumerate(g):
            for x, c in enumerate(row):
                if c != T:
                    x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x + 1), max(y1, y + 1)
    cw, ch = x1 - x0, y1 - y0
    cw8, ch8 = -(-cw // 8) * 8, -(-ch // 8) * 8
    # grow toward the side that already grew (keeps the figure where it was), else to the right/bottom
    if x0 < MARGIN:
        x0 -= cw8 - cw
    if y0 < MARGIN:
        y0 -= ch8 - ch
    anchor = (orig_anchor[0] + MARGIN - x0, orig_anchor[1] + MARGIN - y0)
    return x0, y0, cw8, ch8, anchor


def crop(g: Grid, x0: int, y0: int, w: int, h: int) -> Grid:
    out = blank(w, h)
    for y in range(h):
        for x in range(w):
            out[y][x] = get(g, x + x0, y + y0)
    return out


def lightning_frame(f: dict, variant: int) -> Grid:
    """Lightning Form: the body in the lightning ramp with a bright rim and an inner bolt (make_dual_dagger_art
    .lightning_body), the daggers unchanged, the speed arcs brighter."""
    W, H = len(f["grid"][0]), len(f["grid"])
    body = blank(W, H)
    paste(body, M.lightning_body(f["body"], variant), MARGIN, MARGIN)
    out = blank(W, H)
    arcs = [[("p" if c in "on" else c) for c in row] for row in f["arcs"]]
    paste(out, arcs, 0, 0)
    paste(out, f["back"], 0, 0)
    paste(out, body, 0, 0)
    paste(out, f["front"], 0, 0)
    return out


# ---------------------------------------------------------------------------------------------- effects
def strike_frame(k: int) -> Grid:
    """Sky lightning strike, 32x160, anchor (16,152) = the strike point. Frames: 1 sky flash, 2 leader, 3-4 full
    bolt with impact, 5 burst + ring, 6 ring wide + fading bolt, 7 fragments, 8 embers."""
    W, H = 32, 160
    px, py = 16, 152
    g = blank(W, H)
    rng = random.Random(7300)  # the same bolt path for every frame so it reads as one strike
    pts = M.bolt_path(px + 3, 0, px, py - 2, rng, 7, 5)
    pts = [(min(W - 4, max(3, x)), y) for x, y in pts]
    branches = []
    for b in range(3):
        brng = random.Random(7400 + b)
        i = 6 + b * 9
        bx, by = pts[i]
        side = (-1, 1, -1)[b]
        branches.append(M.bolt_path(bx, by, bx + side * brng.uniform(6, 10), by + brng.uniform(10, 18), brng, 2.5, 3))
    frng = random.Random(7500 + k)

    def ring(r: float, ry: float, col: str, gap: int = 0) -> None:
        for i in range(48):
            if gap and i % gap == 0:
                continue
            a = 2 * math.pi * i / 48
            put(g, round(px + math.cos(a) * r), round(py + math.sin(a) * ry), col)

    if k == 1:  # sky flash at the top, a short leader
        for y in range(0, 8):
            for x in range(W):
                e = ((x + 0.5 - px) / 15.5) ** 2 + (y / 7.5) ** 2
                if e <= 1:
                    put(g, x, y, "p" if e < 0.35 else ("o" if e < 0.75 else "n"))
        M.draw_bolt(g, pts[:len(pts) // 5], "p", "o", 2, frng)
    elif k == 2:  # stepped leader halfway down
        M.draw_bolt(g, pts[:len(pts) // 2], "p", "o", 2, frng)
        M.draw_bolt(g, branches[0][:len(branches[0]) // 2], "o", "", 2)
    elif k in (3, 4):  # full bolt, thick core, branches, impact flash
        cells = M.draw_bolt(g, pts, "p", "o", 1, frng)
        if k == 3:
            for x, y in cells:
                if get(g, x + 1, y) in (T, "o"):
                    put(g, x + 1, y, "p")
        for br in branches:
            M.draw_bolt(g, br, "p" if k == 3 else "o", "", 2)
        r = 4 if k == 3 else 6
        for y in range(-r, r + 1):
            for x in range(-2 * r, 2 * r + 1):
                e = (x / (2 * r)) ** 2 + (y / r) ** 2
                if e <= 1:
                    put(g, px + x, py + y // 2, "p" if e < 0.45 else "o")
        M.outline_layer(g, "l")
    elif k == 5:  # bolt thins, burst with sparks and a ring
        M.draw_bolt(g, pts[len(pts) // 3:], "o", "n", 2, frng)
        ring(9, 4, "p")
        ring(10, 4.6, "o", 3)
        for b in range(7):
            a = b * 2 * math.pi / 7 + 0.3
            sp = M.bolt_path(px, py - 2, px + math.cos(a) * 11, py - 2 + math.sin(a) * 7, frng, 1.5, 2)
            M.draw_bolt(g, sp, "p", "", 2)
        for y in range(-2, 3):
            for x in range(-4, 5):
                if abs(x) / 4 + abs(y) / 2 <= 1:
                    put(g, px + x, py + y, "p")
        M.outline_layer(g, "l")
    elif k == 6:  # wide ring, fading bolt
        M.draw_bolt(g, pts[len(pts) * 2 // 3:], "n", "", 2)
        ring(13, 5.6, "o")
        ring(12, 5.0, "n", 4)
        for x in range(-3, 4):
            put(g, px + x, py, "o")
        M.outline_layer(g, "k")
    elif k == 7:  # fragments
        cells = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            cells += M.line_pts(ax, ay, bx, by)
        for i, (x, y) in enumerate(cells):
            if y > py - 50 and (i // 3) % 3 == 0:
                put(g, x, y, "m")
        ring(15, 6.4, "n", 2)
        for _ in range(8):
            a = frng.uniform(0, 2 * math.pi)
            put(g, round(px + math.cos(a) * frng.uniform(5, 12)), round(py - 3 + math.sin(a) * 5), frng.choice("ov"))
    else:  # embers
        ring(15, 6.4, "m", 3)
        for _ in range(6):
            a = frng.uniform(0, 2 * math.pi)
            put(g, round(px + math.cos(a) * frng.uniform(3, 10)), round(py - 4 + math.sin(a) * 4), frng.choice("nv"))
    return g


def ground_frame(k: int) -> Grid:
    """Scorch decal 32x16, anchor (16,8): dark burn with blue glowing cracks; 1 fresh, 4 nearly gone."""
    W, H = 32, 16
    g = blank(W, H)
    rng = random.Random(7600)
    cx, cy = 16, 8
    for y in range(H):
        for x in range(W):
            e = ((x + 0.5 - cx) / 13) ** 2 + ((y + 0.5 - cy) / 6) ** 2
            n = rng.random()
            if e < 1 and n > e * (0.55 + 0.25 * k) - 0.05 and (k < 4 or (x + y) % 2 == 0):
                put(g, x, y, "0" if e < 0.35 else ("8" if e < 0.7 else "e"))
    for b in range(5):  # cracks radiating from the centre
        crng = random.Random(7700 + b)
        a = b * 2 * math.pi / 5 + 0.4
        pts = M.bolt_path(cx, cy, cx + math.cos(a) * 12, cy + math.sin(a) * 5, crng, 1.5, 2)
        cells = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            cells += M.line_pts(ax, ay, bx, by)
        keep = {1: 1.0, 2: 0.75, 3: 0.45, 4: 0.2}[k]
        col = {1: "p", 2: "o", 3: "n", 4: "m"}[k]
        for i, (x, y) in enumerate(cells):
            if i <= keep * len(cells) and get(g, x, y) != T:
                put(g, x, y, col if i < len(cells) * 0.6 else "m")
    if k == 1:
        for y in range(-1, 2):
            for x in range(-2, 3):
                put(g, cx + x, cy + y, "p" if abs(x) + abs(y) < 2 else "o")
    return g


def blink_frame(k: int) -> Grid:
    """Blink burst 32x32, centre (16,16), anchor (16,30): 14 px under the burst = the hero's feet.
    1 pinch flash, 2 star burst, 3 spark ring, 4 thin ring with sparks, 5 last sparks."""
    S = 32
    g = blank(S, S)
    c = 16
    rng = random.Random(7800 + k)
    if k == 1:
        for d in range(-6, 7):
            put(g, c, c + d, "p")
        for d in range(-3, 4):
            put(g, c + d, c, "p")
        put(g, c + 1, c - 1, "o"), put(g, c - 1, c + 1, "o")
        M.outline_layer(g, "l")
        return g
    if k == 2:
        for b in range(8):
            a = b * math.pi / 4 + 0.2
            ln = 10 if b % 2 == 0 else 6
            M.draw_bolt(g, M.bolt_path(c, c, c + math.cos(a) * ln, c + math.sin(a) * ln, rng, 1.6, 2), "p", "o", 2, rng)
        for y in range(-2, 3):
            for x in range(-2, 3):
                if abs(x) + abs(y) <= 2:
                    put(g, c + x, c + y, "p")
        M.outline_layer(g, "l")
        return g
    r = {3: 9, 4: 12, 5: 13}[k]
    for i in range(40):
        if k == 5 and i % 3:
            continue
        a = 2 * math.pi * i / 40
        jit = rng.uniform(-1, 1) if k >= 4 else 0
        put(g, round(c + math.cos(a) * (r + jit)), round(c + math.sin(a) * (r + jit) * 0.9), "o" if k == 3 else ("n" if k == 4 else "m"))
    for b in range({3: 6, 4: 5, 5: 4}[k]):
        a = rng.uniform(0, 2 * math.pi)
        x, y = c + math.cos(a) * (r - 3), c + math.sin(a) * (r - 3)
        M.draw_bolt(g, M.bolt_path(x, y, x + math.cos(a) * 4, y + math.sin(a) * 4, rng, 1, 1), "p" if k < 5 else "o", "", 2)
        put(g, round(x + math.cos(a) * 5), round(y + math.sin(a) * 5), "v")
    if k == 3:
        M.outline_layer(g, "l")
    return g


# ---------------------------------------------------------------------------------------------- output
def write_sprite(name: str, g: Grid, anchor: tuple[int, int], note: str) -> None:
    h, w = len(g), len(g[0])
    assert w % 8 == 0 and h % 8 == 0 and max(w, h) <= 256, (name, w, h)
    for row in g:
        for c in row:
            assert c == T or (c in PAL.by_symbol and c not in FORBIDDEN), (name, c)
    lines = ["# kind: sprite", f"# anchor: {anchor[0]},{anchor[1]}", f"# generated by {GENERATOR} ({note})"]
    lines += ["".join(r) for r in g]
    (SRC / f"{name}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def to_image(g: Grid) -> Image.Image:
    return M.to_image(g)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-previews", action="store_true")
    args = ap.parse_args()

    manifest: dict[str, dict] = {}
    written: dict[str, tuple[Grid, tuple[int, int]]] = {}

    def emit(name: str, g: Grid, anchor: tuple[int, int], note: str, group: str, extra: dict | None = None) -> None:
        write_sprite(name, g, anchor, note)
        written[name] = (g, anchor)
        base = name.rsplit("_", 1)[0]
        e = manifest.setdefault(base, {"group": group, "frames": 0, "size": [len(g[0]), len(g)], "anchors": []})
        e["frames"] += 1
        e["anchors"].append(list(anchor))
        if extra:
            e.update(extra)

    # 1. dagger-armed hero + 2. lightning-body hero
    frames = [build_dagger_frame(*t) for t in frame_names()]
    variant = 0
    dagger_by_name: dict[str, tuple[Grid, tuple[int, int]]] = {}
    for f in frames:
        lg = lightning_frame(f, variant) if f["state"] in LIGHTNING_STATES else None
        x0, y0, w, h, anchor = crop_canvas([f["grid"]] + ([lg] if lg else []), f["orig_size"], f["orig_anchor"])
        name = f"totoy_dagger_{f['state']}_right_{f['n']}"
        g = crop(f["grid"], x0, y0, w, h)
        emit(name, g, anchor, f"body from {f['source']}, katana removed, twin daggers", "hero_dagger")
        dagger_by_name[name] = (g, anchor)
        if lg is not None:
            emit(f"totoy_lightning_{f['state']}_right_{f['n']}", crop(lg, x0, y0, w, h), anchor,
                 f"lightning body from {f['source']}", "hero_lightning")
            variant += 1

    # 3. aura, afterimages (64x64 cells, feet anchor 32,56 like fx_black_aura_*)
    ab, af = M.aura_frames(10)
    for i in range(10):
        emit(f"fx_lightning_aura_back_{i + 1}", ab[i], (M.AX, M.AY), "aura behind the hero", "fx_lightning")
        emit(f"fx_lightning_aura_front_{i + 1}", af[i], (M.AX, M.AY), "aura in front of the hero", "fx_lightning")
    by_state = {(f["state"], f["n"]): f for f in frames}
    for i, key in enumerate([("dash", 3), ("attack1", 4)]):
        f = by_state[key]
        cell = blank(M.CW, M.CH)
        ax, ay = f["orig_anchor"]
        paste(cell, lightning_frame(f, 0), M.AX - ax - MARGIN, M.AY - ay - MARGIN)
        for s in range(3):
            emit(f"fx_lightning_afterimage_{i * 3 + s + 1}", M.afterimage(cell, s), (M.AX, M.AY),
                 f"{'blink' if i == 0 else 'slash'} afterimage, fade step {s + 1}", "fx_lightning")
    # cuts: 8 directions x 4 phases, 64x64, anchor (32,32) = target point
    dirs = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
    for d, dn in enumerate(dirs):
        for ph in range(4):
            emit(f"fx_lightning_cut_{dn}_{ph + 1}", M.slash_frame(d * math.pi / 4, ph, 3000 + d * 10 + ph), (32, 32),
                 f"cut travelling {d * 45} deg, phase {['lead', 'peak', 'follow', 'fragments'][ph]}", "fx_lightning")
    for k in range(6):
        emit(f"fx_lightning_spark_{k + 1}", M.hit_spark(k), (16, 16), "hit spark", "fx_lightning")
    for k in range(4):
        emit(f"fx_lightning_chain_{k + 1}", M.chain_segment(k), (0, 8), "chain bolt segment (0,8) to (31,8)", "fx_lightning")
    for k in range(1, 9):
        emit(f"fx_lightning_strike_{k}", strike_frame(k), (16, 152), "sky strike, anchor = strike point", "fx_lightning")
    for k in range(1, 5):
        emit(f"fx_lightning_ground_{k}", ground_frame(k), (16, 8), "scorch decal", "fx_lightning")
    for k in range(1, 6):
        emit(f"fx_lightning_blink_{k}", blink_frame(k), (16, 30), "blink burst, anchor = feet", "fx_lightning")

    # 4. UI
    emit("ui_weapon_dual_dagger_1", M.weapon_medallion(), (24, 24), "from skill_medallions_v1 weapon medallion", "ui")
    emit("ui_aspect_lightning_form_1", M.skill_medallion(), (12, 12), "from skill_medallions_v1 skill medallion", "ui")

    # 5. manifest
    for e in manifest.values():
        if len({tuple(a) for a in e["anchors"]}) == 1:
            e["anchor"] = e["anchors"][0]
    data = {
        "generator": GENERATOR,
        "note": "Sprite groups: name -> frame count (frames are <name>_1..N), canvas size of frame 1, anchor per frame "
                "(feet for hero frames; see docs in art/reference/dual_dagger/README.md for every group's anchor meaning). "
                "Hero frames are right-facing; mirror around the anchor for left.",
        "sprites": {k: manifest[k] for k in sorted(manifest)},
    }
    meaning = [("totoy_", "feet (same world point as the matching hero2_* frame; place by anchor, mirror around it for left)"),
               ("fx_lightning_aura", "feet of the hero (32,56), like fx_black_aura_*"),
               ("fx_lightning_afterimage", "feet of the hero (32,56)"),
               ("fx_lightning_cut", "target point the cut passes through (cell centre); direction = travel, 0 deg east, clockwise"),
               ("fx_lightning_spark", "hit point (centre)"),
               ("fx_lightning_chain", "segment start (0,8); it ends at (31,8): rotate/stretch between two points or chain end to end"),
               ("fx_lightning_strike", "strike point on the ground (bottom centre); the bolt reaches 152 px above it"),
               ("fx_lightning_ground", "decal centre on the ground"),
               ("fx_lightning_blink", "hero's feet; the burst is centred 14 px above (chest height)"),
               ("ui_", "icon centre")]
    sources = {f"totoy_dagger_{f['state']}_right": [] for f in frames}
    for f in frames:
        sources[f"totoy_dagger_{f['state']}_right"].append(f["source"])
    for base, e in data["sprites"].items():
        e["anchor_meaning"] = next(m for p, m in meaning if base.startswith(p))
        src_key = base.replace("totoy_lightning_", "totoy_dagger_")
        if src_key in sources:
            e["body_sources"] = sources[src_key]
    for name, (g, a) in written.items():
        base = name.rsplit("_", 1)[0]
        data["sprites"][base].setdefault("frame_sizes", []).append([len(g[0]), len(g)])
    (BUILD / "dagger_sprites_manifest.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")

    if not args.no_previews:
        make_previews(frames, written)
    print(f"wrote {len(written)} sprite sources and art/build/dagger_sprites_manifest.json")
    return 0


# ---------------------------------------------------------------------------------------------- previews
BG = (40, 40, 52)
GRASS = PAL.by_symbol["4"]


def sheet(cells: list[tuple[str, Image.Image, tuple[int, int] | None]], cols: int, zoom: int, bg: tuple, cw: int, ch: int) -> Image.Image:
    rows = (len(cells) + cols - 1) // cols
    lab = 12
    out = Image.new("RGB", (cols * cw * zoom, rows * (ch * zoom + lab)), bg)
    d = ImageDraw.Draw(out)
    for i, (label, im, anchor) in enumerate(cells):
        X, Y = (i % cols) * cw * zoom, (i // cols) * (ch * zoom + lab)
        ox = (cw - im.width) // 2 if anchor is None else cw // 2 - anchor[0]
        oy = (ch - im.height) // 2 if anchor is None else ch - 6 - anchor[1]
        big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
        out.paste(big, (X + ox * zoom, Y + lab + oy * zoom), big)
        d.text((X + 2, Y), label, fill=(225, 225, 225))
    return out


def make_previews(frames: list[dict], written: dict) -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)

    def cells(prefix: str) -> list:
        return [(n.replace(prefix, ""), to_image(g), a) for n, (g, a) in written.items() if n.startswith(prefix)]

    for tag, bg in (("dark", BG), ("grass", GRASS)):
        sheet(cells("totoy_dagger_"), 8, 4, bg, 64, 56).save(PREVIEWS / f"dual_dagger_import_hero_{tag}.png")
    sheet(cells("totoy_lightning_"), 8, 4, BG, 64, 56).save(PREVIEWS / "dual_dagger_import_lightning_dark.png")
    fx = [(n.replace("fx_lightning_", ""), to_image(g), None) for n, (g, a) in written.items()
          if n.startswith("fx_lightning_") and not n.startswith("fx_lightning_strike")]
    sheet(fx + [(n, to_image(g), None) for n, (g, a) in written.items() if n.startswith("ui_")], 10, 3, BG, 64, 64).save(PREVIEWS / "dual_dagger_import_fx_dark.png")
    sheet([(n.replace("fx_lightning_", ""), to_image(g), None) for n, (g, a) in written.items() if n.startswith("fx_lightning_strike")],
          8, 3, GRASS, 32, 160).save(PREVIEWS / "dual_dagger_import_strike_grass.png")


if __name__ == "__main__":
    sys.exit(main())
