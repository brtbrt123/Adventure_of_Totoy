"""The leaning hero (Totoy, katana set): the pipeline step that turns the upright imported frames into the in-game
hero2_* frames (approved by the human on 2026-10-20).

Reads the UPRIGHT frames art/reference/hero_lean/upright/hero2_<state>_right_<n>.txt (written there by
tools/art/import_gemini.py) and re-poses them: idle and victory are copied unchanged; walk, dash and the three katana
swings lean forward into the motion; parry braces slightly backward; hurt keeps its recoil. With --install the result
is written to art/src/hero2_<state>_right_<n>.txt (same names, frame counts and feet-anchor convention), so never
hand-edit those: change POSES / FIXES here and re-run. tools/art/import_dagger_sprites.py imports this module to lean
the dagger bodies the same way (DAGGER_POSES for the dagger-only swing 4) and to move its hand points with the warp.

Method (pose-aware warp, not a whole-frame shear):
  * Each frame is split into a body layer and a katana layer (katana = water_1/water_2 pixels plus their own ink
    outline). Body pixels hidden behind the blade are in-painted first so the body has no hole when the blade moves.
  * The body gets one continuous warp field around a hip pivot:
      - head (above the neck row): rigid whole-pixel translation that follows the neck, so the face never rotates;
      - torso (neck .. hip): rotation by the lean angle around the hip pivot, blended to 0 at the hip;
      - hips and legs: the hips slide forward (weight forward) and the stride widens around the hip while the feet
        rows stay put, and the knees bend (the hip drops) with the feet still on the ground row.
  * The katana layer moves rigidly with the hand that holds it (the warp at the grip).
  * Sampling is RotSprite style: the source symbol grid is enlarged 8x with Scale2x (edge-preserving, no new colours),
    each output pixel centre is mapped back through the inverse warp and picks one symbol. Palette symbols only, hard
    alpha, no blur. Afterwards pinholes are filled, orphan pixels removed, body colours exposed on the silhouette
    edge re-inked (the importer's outline rule) and 1px ink spurs dropped.
  * Per-frame parameters (angle, hip, pivot, stride, ...) live in POSES; hand fixes in FIXES.

Outputs: with --install, art/src/hero2_*.txt (48 frames). Review files under art/reference/hero_lean/ (skip them
with --no-review):
  hero_lean_sheet.png / .json          every frame at 1x in labelled rows by state (palette colours, hard alpha)
  grids/hero2lean_<state>_right_<n>.txt  the same frames as text grids (review copy; --install writes art/src)
  contact_old_vs_new_dark.png / _grass.png   4x review sheets, OLD (upright) left, NEW (leaning) right, per state
  game_scale_preview.png               320x180 game-resolution scene (old vs new), shown at 4x like the 1280x720 window
  preview_old_vs_new.gif               walk cycle, sword combo 1-2-3, dash; OLD vs NEW at 4x, half speed
  preview_old_vs_new_realtime.gif      the same at game speed (60 ticks/s, rounded to GIF 10 ms steps)

Deterministic (no randomness is used; SEED is kept for the record). Run from the project root:
  python tools/art/make_hero_lean_sheet.py --install      # then import_dagger_sprites.py, validate, build, preview
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

SEED = 20261020
ROOT = artlib.ROOT
SRC = artlib.SRC_DIR
OUT = ROOT / "art" / "reference" / "hero_lean"
UPRIGHT = OUT / "upright"  # the upright hero2_* frames as imported (tools/art/import_gemini.py writes them here)
PAL = artlib.load_palette()
T = "."
KATANA = set("kl")
SKIN = set("qrs")
INK = "0"
PAD = 16
UP = 8  # Scale2x three times

STATES: list[tuple[str, int]] = [("idle", 4), ("walk", 6), ("dash", 4), ("attack1", 6), ("attack2", 6),
                                 ("attack3", 6), ("parry", 6), ("hurt", 4), ("victory", 6)]
UNCHANGED = {"idle", "victory"}

Grid = list  # list[list[str]]


# ---------------------------------------------------------------------------------------------------- poses
@dataclass
class Pose:
    lean: float = 0.0        # degrees, + = top of the body goes forward (right)
    head: bool = True        # head rides rigidly on the neck (False: whole upper body rotates, e.g. dash sprint)
    stride: float = 1.0      # horizontal leg spread around the hip pivot at the feet rows
    hip_fwd: float = 0.0     # px the hips (and everything above) slide forward, feet planted
    drop: float = 0.0        # px the hips drop (knee bend), feet planted
    blend: int = 6           # rows over which the torso rotation fades in above the hip
    hip: int | None = None   # hip row override (source pixels)
    px: float | None = None  # pivot x override
    neck: int | None = None  # neck row override
    grip: tuple[int, int] | None = None  # katana grip override (source pixels)
    level: float = 1.0       # 1 = arms rotate with the torso; 0 = arms/blade ahead of the hip keep their height
                             # (horizontal thrusts stay horizontal while the torso still tips forward)


def P(**kw) -> Pose:
    return Pose(**kw)


# Walk: clear forward lean, longer stride, hips forward, slight knee bend.
WALK = dict(lean=21, stride=1.3, hip_fwd=1.5, drop=1)
POSES: dict[str, Pose] = {
    **{f"walk_{n}": P(**WALK) for n in range(1, 7)},
    # Passing frames (legs together): a wide stride only fattens the thighs into one block, so keep it narrow.
    "walk_3": P(**{**WALK, "stride": 1.1}),
    "walk_6": P(**{**WALK, "stride": 1.1}),
    # Dash 1-3 are already a horizontal sprint: tip a little further and stretch; 4 is the brake/recovery.
    "dash_1": P(lean=8, head=False, stride=1.15, hip_fwd=1, level=0),
    "dash_2": P(lean=8, head=False, stride=1.15, hip_fwd=1, level=0),
    "dash_3": P(lean=8, head=False, stride=1.15, hip_fwd=1, level=0),
    "dash_4": P(lean=24, stride=1.1, hip_fwd=2, drop=1, level=0.5),
    # Swing 1 (draw and horizontal thrust): windup coils forward, strike lunges, recovery stays committed.
    "attack1_1": P(lean=10, stride=1.15, hip_fwd=1, drop=1),
    "attack1_2": P(lean=12, stride=1.2, hip_fwd=1.5, drop=1, level=0),
    "attack1_3": P(lean=14, stride=1.25, hip_fwd=2, drop=1, level=0),
    "attack1_4": P(lean=18, stride=1.25, hip_fwd=2, drop=2, level=0),
    "attack1_5": P(lean=18, stride=1.2, hip_fwd=2, drop=1),
    "attack1_6": P(lean=10, stride=1.1, hip_fwd=1),
    # Swing 2 (rising cut): low coil, rising strike leaning into it, recovery.
    "attack2_1": P(lean=10, stride=1.15, hip_fwd=1, drop=1),
    "attack2_2": P(lean=12, stride=1.2, hip_fwd=1.5, drop=1),
    "attack2_3": P(lean=16, stride=1.25, hip_fwd=2, drop=1),
    "attack2_4": P(lean=14, stride=1.25, hip_fwd=2, drop=1),
    "attack2_5": P(lean=12, stride=1.2, hip_fwd=1.5, drop=1),
    "attack2_6": P(lean=10, stride=1.1, hip_fwd=1),
    # Swing 3 (overhead finisher): raised windup still tips forward, the slam folds deep over the front knee.
    "attack3_1": P(lean=12, stride=1.15, hip_fwd=1),
    "attack3_2": P(lean=14, stride=1.2, hip_fwd=1.5, drop=1),
    "attack3_3": P(lean=16, stride=1.25, hip_fwd=2, drop=1),
    "attack3_4": P(lean=18, stride=1.25, hip_fwd=2, drop=2),
    "attack3_5": P(lean=16, stride=1.2, hip_fwd=2, drop=1),
    "attack3_6": P(lean=10, stride=1.1, hip_fwd=1),
    # Parry: braced guard, weight a little back (negative lean), stance a touch wider.
    **{f"parry_{n}": P(lean=-5, stride=1.1, hip_fwd=-0.5) for n in range(1, 6)},
    "parry_6": P(lean=-3, stride=1.05),
    # Hurt: the recoil frames already throw the body; only the first gets a small backward snap.
    "hurt_1": P(lean=-5),
    "hurt_2": P(lean=0),
    "hurt_3": P(lean=0),
    "hurt_4": P(lean=-3),
}

# Bodies only the dagger set needs (tools/art/import_dagger_sprites.py): swing 4, the twin finisher, borrows upright
# frames (import_dagger_sprites.SWING4) and leans into the strike: gather and raise both daggers with the weight
# already forward, then fold deeper than the katana slam over the front knee as both blades drive down.
DAGGER_POSES: dict[str, Pose] = {
    "attack4_1": P(lean=8, stride=1.1, hip_fwd=1),                    # from parry_3 (guard), coiling forward
    "attack4_2": P(lean=6, stride=1.1, hip_fwd=1),                    # from victory_3 (both raised)
    "attack4_3": P(lean=18, stride=1.25, hip_fwd=2, drop=1),          # from attack3_3
    "attack4_4": P(lean=21, stride=1.3, hip_fwd=2.5, drop=2),         # from attack3_4, the deepest fold
    "attack4_5": P(lean=16, stride=1.2, hip_fwd=2, drop=1),           # from attack3_5
    "attack4_6": P(lean=10, stride=1.1, hip_fwd=1),                   # from attack1_6, settling
}


# ---------------------------------------------------------------------------------------------------- grids
def load(name: str) -> tuple[Grid, tuple[int, int]]:
    """An UPRIGHT source frame (art/reference/hero_lean/upright/hero2_*.txt), never the leaned art/src copy."""
    s = artlib.parse_sprite(UPRIGHT / f"{name}.txt")
    assert s.anchor is not None, name
    return [list(r) for r in s.rows], s.anchor


def blank(w: int, h: int) -> Grid:
    return [[T] * w for _ in range(h)]


def pad(g: Grid, n: int) -> Grid:
    w = len(g[0]) + 2 * n
    out = blank(w, len(g) + 2 * n)
    for y, row in enumerate(g):
        out[y + n][n:n + len(row)] = row
    return out


def opaque(g: Grid, x: int, y: int) -> bool:
    return 0 <= y < len(g) and 0 <= x < len(g[0]) and g[y][x] != T


def scale2x(g: Grid) -> Grid:
    h, w = len(g), len(g[0])
    out = blank(2 * w, 2 * h)
    for y in range(h):
        for x in range(w):
            e = g[y][x]
            b = g[y - 1][x] if y > 0 else e
            hh = g[y + 1][x] if y < h - 1 else e
            d = g[y][x - 1] if x > 0 else e
            f = g[y][x + 1] if x < w - 1 else e
            if b != hh and d != f:
                e0 = d if d == b else e
                e1 = f if b == f else e
                e2 = d if d == hh else e
                e3 = f if hh == f else e
            else:
                e0 = e1 = e2 = e3 = e
            out[2 * y][2 * x], out[2 * y][2 * x + 1] = e0, e1
            out[2 * y + 1][2 * x], out[2 * y + 1][2 * x + 1] = e2, e3
    return out


def upscale(g: Grid) -> Grid:
    return scale2x(scale2x(scale2x(g)))


# ---------------------------------------------------------------------------------------------------- segmentation
def katana_mask(g: Grid) -> set[tuple[int, int]]:
    """Blade pixels (k, l) plus ink pixels that only outline the blade (no other body colour 4-adjacent)."""
    h, w = len(g), len(g[0])
    blade = {(x, y) for y in range(h) for x in range(w) if g[y][x] in KATANA}
    mask = set(blade)
    for (x, y) in blade:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if (nx, ny) in mask or not opaque(g, nx, ny) or g[ny][nx] not in (INK, "8"):
                    continue
                body_touch = any(opaque(g, nx + ax, ny + ay) and g[ny + ay][nx + ax] not in KATANA | {INK, "8"}
                                 for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if not body_touch:
                    mask.add((nx, ny))
    return mask


def split_layers(g: Grid) -> tuple[Grid, Grid, set[tuple[int, int]]]:
    h, w = len(g), len(g[0])
    mask = katana_mask(g)
    body = [row[:] for row in g]
    kat = blank(w, h)
    for (x, y) in mask:
        kat[y][x] = g[y][x]
        body[y][x] = T
    # In-paint body behind the blade: a removed pixel with body on both opposite sides takes the body colour.
    for _ in range(3):
        fills = {}
        for (x, y) in mask:
            if body[y][x] != T:
                continue
            for (ax, ay) in ((1, 0), (0, 1), (1, 1), (1, -1)):
                a = body[y + ay][x + ax] if opaque(body, x + ax, y + ay) else T
                b = body[y - ay][x - ax] if opaque(body, x - ax, y - ay) else T
                if a != T and b != T:
                    fills[(x, y)] = a if a != INK else b
                    break
        if not fills:
            break
        for (x, y), c in fills.items():
            body[y][x] = c
    return body, kat, mask


def find_grip(g: Grid, mask: set[tuple[int, int]]) -> tuple[int, int] | None:
    """Blade pixel nearest to the skin (the hand holding the hilt)."""
    skin = [(x, y) for y in range(len(g)) for x in range(len(g[0])) if g[y][x] in SKIN]
    blade = sorted(p for p in mask if g[p[1]][p[0]] in KATANA)
    if not skin or not blade:
        return None
    return min(blade, key=lambda b: (min((b[0] - x) ** 2 + (b[1] - y) ** 2 for x, y in skin), b[1], b[0]))


# ---------------------------------------------------------------------------------------------------- warp
@dataclass
class Rig:
    hip: float
    px: float
    neck: float
    foot: float
    pose: Pose
    head_shift: tuple[int, int] = (0, 0)


def rig_for(g: Grid, body: Grid, anchor: tuple[int, int], pose: Pose) -> Rig:
    """Hip, pivot and neck from the frame's own pixels (source = padded coordinates); POSES may override."""
    ax, ay = anchor
    rows = [y for y in range(len(body)) if any(c != T for c in body[y])]
    top = rows[0]
    height = ay - top
    hip = pose.hip + PAD if pose.hip is not None else round(ay - 0.40 * height)
    if pose.px is not None:
        px = pose.px + PAD
    else:
        # Centre of the waist: median of the pants pixels (stone e/f) on the hip rows; arms and blade excluded.
        xs = sorted(x for y in (hip, hip + 1, hip + 2) for x in range(len(body[0])) if body[y][x] in ("e", "f"))
        px = xs[len(xs) // 2] + 0.5 if xs else float(ax)
    neck = pose.neck + PAD if pose.neck is not None else round(top + 0.31 * height)
    rig = Rig(hip=hip, px=px, neck=neck, foot=float(ay), pose=pose)
    if pose.head:
        # Integer shift of the head = where the torso warp moves the neck centre.
        nx = neck_centre(body, neck, px)
        X, Y = torso_fwd(rig, nx, neck + 0.5)
        rig.head_shift = (round(X - nx), round(Y - (neck + 0.5)))
    return rig


def neck_centre(body: Grid, neck: int, px: float) -> float:
    xs = [x for x in range(len(body[0])) if body[neck][x] != T]
    if not xs:
        return px
    # The neck run nearest the pivot (arms at that row can be far away).
    runs, run = [], [xs[0]]
    for x in xs[1:]:
        if x == run[-1] + 1:
            run.append(x)
        else:
            runs.append(run)
            run = [x]
    runs.append(run)
    best = min(runs, key=lambda r: abs((r[0] + r[-1]) / 2 - px))
    return (best[0] + best[-1] + 1) / 2


def torso_fwd(rig: Rig, x: float, y: float, fixed_w: float | None = None) -> tuple[float, float]:
    p = rig.pose
    w = fixed_w if fixed_w is not None else max(0.0, min(1.0, (rig.hip - y) / max(1, p.blend)))
    a = math.radians(p.lean) * w
    dx, dy = x - rig.px, y - rig.hip
    L = p.level
    X = rig.px + dx * (1 - L * (1 - math.cos(a))) - dy * math.sin(a)
    Y = rig.hip + L * dx * math.sin(a) + dy * math.cos(a)
    return X + p.hip_fwd, Y + p.drop


def legs_fwd(rig: Rig, x: float, y: float) -> tuple[float, float]:
    p = rig.pose
    t = max(0.0, min(1.0, (y - rig.hip) / max(1.0, rig.foot - rig.hip)))
    X = rig.px + (x - rig.px) * (1 + (p.stride - 1) * t) + p.hip_fwd * (1 - t)
    Y = y + p.drop * (1 - t)
    return X, Y


def body_fwd(rig: Rig, x: float, y: float) -> tuple[float, float]:
    if y >= rig.hip:
        return legs_fwd(rig, x, y)
    if rig.pose.head and y < rig.neck:
        return x + rig.head_shift[0], y + rig.head_shift[1]
    X, Y = torso_fwd(rig, x, y)
    if rig.pose.head and y < rig.neck + 2:
        # Blend the last two rows under the neck from the head shift into the torso rotation.
        k = (y - rig.neck) / 2
        X = (1 - k) * (x + rig.head_shift[0]) + k * X
        Y = (1 - k) * (y + rig.head_shift[1]) + k * Y
    return X, Y


def invert(fwd, ox: float, oy: float) -> tuple[float, float] | None:
    sx, sy = ox, oy
    for _ in range(30):
        X, Y = fwd(sx, sy)
        ex, ey = ox - X, oy - Y
        if abs(ex) < 1e-3 and abs(ey) < 1e-3:
            return sx, sy
        sx, sy = sx + ex, sy + ey
    X, Y = fwd(sx, sy)
    return (sx, sy) if abs(ox - X) < 0.35 and abs(oy - Y) < 0.35 else None


def resample(big: Grid, fwd, w: int, h: int) -> Grid:
    out = blank(w, h)
    bh, bw = len(big), len(big[0])
    for y in range(h):
        for x in range(w):
            s = invert(fwd, x + 0.5, y + 0.5)
            if s is None:
                continue
            ix, iy = int(math.floor(s[0] * UP)), int(math.floor(s[1] * UP))
            if 0 <= ix < bw and 0 <= iy < bh:
                out[y][x] = big[iy][ix]
    return out


# ---------------------------------------------------------------------------------------------------- cleanup
N8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
N4 = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def cleanup(g: Grid, keep: set[tuple[int, int]] | None = None) -> Grid:
    h, w = len(g), len(g[0])
    g = [row[:] for row in g]
    for _ in range(2):  # pinholes
        fills = {}
        for y in range(h):
            for x in range(w):
                if g[y][x] != T:
                    continue
                n4 = [g[y + dy][x + dx] for dx, dy in N4 if opaque(g, x + dx, y + dy)]
                if len(n4) >= 3 or (len(n4) == 2 and ((opaque(g, x - 1, y) and opaque(g, x + 1, y))
                                                      or (opaque(g, x, y - 1) and opaque(g, x, y + 1)))
                                    and sum(opaque(g, x + dx, y + dy) for dx, dy in N8) >= 6):
                    n8 = [g[y + dy][x + dx] for dx, dy in N8 if opaque(g, x + dx, y + dy)]
                    inner = [c for c in n8 if c not in (INK, "8")]
                    pool = inner if len(inner) >= 3 else n8
                    fills[(x, y)] = max(sorted(set(pool)), key=pool.count)
        for (x, y), c in fills.items():
            g[y][x] = c
    for y in range(h):  # orphans
        for x in range(w):
            if g[y][x] != T and not any(opaque(g, x + dx, y + dy) for dx, dy in N8):
                if keep is None or (x, y) not in keep:
                    g[y][x] = T
    return g


EDGE_OK = {INK, "8", "e", "k", "l"}  # colours the importer leaves on a silhouette edge (dark enough to read as line)


def smooth(g: Grid) -> Grid:
    """1-px roughness pass after the warp.
    * Outline breaks: the warp exposes body colours (skin, hair, pants) on the silhouette edge where the source had
      its 1px ink line. Re-ink them with the importer's own rule (import_reference.outline: an edge pixel lighter
      than the dark line colours becomes ink), so the outline is continuous again.
    * Ink spurs: a lone ink pixel hanging off the silhouette by one diagonal/side neighbour is dropped."""
    h, w = len(g), len(g[0])
    g = [row[:] for row in g]
    edge = [(x, y) for y in range(h) for x in range(w)
            if g[y][x] != T and g[y][x] not in EDGE_OK and any(not opaque(g, x + dx, y + dy) for dx, dy in N4)]
    for x, y in edge:
        g[y][x] = INK
    spurs = [(x, y) for y in range(h) for x in range(w)
             if g[y][x] == INK and sum(opaque(g, x + dx, y + dy) for dx, dy in N8) == 1]
    for x, y in spurs:
        g[y][x] = T
    return g


def composite(*layers: Grid) -> Grid:
    out = [row[:] for row in layers[0]]
    for layer in layers[1:]:
        for y, row in enumerate(layer):
            for x, c in enumerate(row):
                if c != T:
                    out[y][x] = c
    return out


# ---------------------------------------------------------------------------------------------------- frame build
@dataclass
class Frame:
    name: str
    source: str
    state: str
    n: int
    grid: Grid
    anchor: tuple[int, int]
    params: dict = field(default_factory=dict)
    rig: "Rig | None" = None
    offset: tuple[int, int] = (0, 0)  # padded source coordinates -> final frame pixels: subtract this

    def map_point(self, x: float, y: float) -> tuple[float, float]:
        """Where a point of the UPRIGHT source frame (pixel coordinates, centre = +0.5) lands in this frame."""
        if self.rig is None:
            return x, y
        X, Y = body_fwd(self.rig, x + PAD, y + PAD)
        return X - self.offset[0], Y - self.offset[1]

    def turn_at(self, x: float, y: float) -> float:
        """Degrees the warp turns the body at an upright source point (the torso lean there; 0 on head and legs)."""
        if self.rig is None:
            return 0.0
        r, p = self.rig, self.rig.pose
        sy = y + PAD
        if sy >= r.hip or (p.head and sy < r.neck):
            return 0.0
        return p.lean * p.level * max(0.0, min(1.0, (r.hip - sy) / max(1, p.blend)))


def crop_to(g: Grid, anchor: tuple[int, int], orig_w: int, orig_h: int, orig_anchor: tuple[int, int]) -> tuple[Grid, tuple[int, int]]:
    """Crop to content; size multiple of 8; keep the original bottom margin under the feet."""
    h, w = len(g), len(g[0])
    pts = [(x, y) for y in range(h) for x in range(w) if g[y][x] != T]
    x0 = min(x for x, _ in pts)
    x1 = max(x for x, _ in pts) + 1
    y0 = min(y for _, y in pts)
    bottom = anchor[1] + (orig_h - orig_anchor[1])
    y1 = max(bottom, max(y for _, y in pts) + 1)
    cw = max(orig_w if x1 - x0 <= orig_w else 0, -(-(x1 - x0) // 8) * 8)
    ch = -(-(y1 - y0) // 8) * 8
    # Keep the anchor at the same place as the source when the content fits that way.
    left = anchor[0] - orig_anchor[0]
    if left <= x0 and left + cw >= x1:
        x0 = left
    else:
        x0 = x0 - (cw - (x1 - x0)) // 2
    y0 = y1 - ch
    out = blank(cw, ch)
    for y in range(ch):
        for x in range(cw):
            sx, sy = x + x0, y + y0
            if 0 <= sx < w and 0 <= sy < h:
                out[y][x] = g[sy][sx]
    return out, (anchor[0] - x0, anchor[1] - y0)


def build_frame(state: str, n: int, src_name: str | None = None, pose: Pose | None = None) -> Frame:
    """Lean one frame. Default: hero2_<state>_right_<n> with POSES[<state>_<n>]. The dagger importer passes its own
    source and pose for bodies the katana set does not have (swing 4)."""
    src_name = src_name or f"hero2_{state}_right_{n}"
    g0, a0 = load(src_name)
    name = f"hero2lean_{state}_right_{n}"
    pose = pose or POSES.get(f"{state}_{n}")
    if pose is None or (state in UNCHANGED and src_name.startswith(f"hero2_{state}_")):
        return Frame(name, src_name, state, n, g0, a0, {"unchanged": True})
    g = pad(g0, PAD)
    anchor = (a0[0] + PAD, a0[1] + PAD)
    body, kat, mask = split_layers(g)
    rig = rig_for(g, body, anchor, pose)
    grip = (pose.grip[0] + PAD, pose.grip[1] + PAD) if pose.grip else find_grip(g, mask)
    h, w = len(g), len(g[0])

    body_big = upscale(body)
    out_body = resample(body_big, lambda x, y: body_fwd(rig, x, y), w, h)
    layers = [out_body]
    if mask:
        gx, gy = (grip[0] + 0.5, grip[1] + 0.5) if grip else (rig.px, rig.hip - 3)
        # Rigid move of the blade: the body warp's displacement and rotation at the grip.
        G = body_fwd(rig, gx, gy)
        if gy >= rig.hip:
            ang = 0.0
        elif rig.pose.head and gy < rig.neck:
            ang = 0.0
        else:
            ang = math.radians(pose.lean) * pose.level * max(0.0, min(1.0, (rig.hip - gy) / max(1, pose.blend)))
        kat_big = upscale(kat)
        floor_y = max(anchor[1] - 1, max(y for _, y in mask))  # the blade may not sink below the ground
        for k in (1.0, 0.75, 0.5, 0.25, 0.0, -0.25, -0.5):
            ca, sa = math.cos(ang * k), math.sin(ang * k)

            def kat_fwd(x: float, y: float, ca: float = ca, sa: float = sa) -> tuple[float, float]:
                dx, dy = x - gx, y - gy
                return G[0] + dx * ca - dy * sa, G[1] + dx * sa + dy * ca

            kl = resample(kat_big, kat_fwd, w, h)
            low = max((y for y in range(h) if any(c != T for c in kl[y])), default=0)
            if low <= floor_y:
                break
        layers.append(kl)
    out = cleanup(composite(*layers))
    nax, nay = legs_fwd(rig, anchor[0], anchor[1])
    new_anchor = (round(nax), anchor[1])
    pre_anchor = new_anchor
    out, new_anchor = crop_to(out, new_anchor, len(g0[0]), len(g0), a0)
    out = smooth(out)
    out = apply_fixes(name, out)
    params = asdict(pose)
    params.update({"hip_row": rig.hip - PAD, "pivot_x": round(rig.px - PAD, 1), "neck_row": rig.neck - PAD,
                   "head_shift": list(rig.head_shift), "grip": [grip[0] - PAD, grip[1] - PAD] if grip else None})
    offset = (pre_anchor[0] - new_anchor[0], pre_anchor[1] - new_anchor[1])
    return Frame(name, src_name, state, n, out, new_anchor, params, rig, offset)


# Hand fixes after the warp: name -> list of (x, y, symbol) in final frame pixels. Filled while reviewing.
FIXES: dict[str, list[tuple[int, int, str]]] = {}


def apply_fixes(name: str, g: Grid) -> Grid:
    for x, y, c in FIXES.get(name, []):
        if 0 <= y < len(g) and 0 <= x < len(g[0]):
            g[y][x] = c
    return g


# ---------------------------------------------------------------------------------------------------- images
def rgb(sym: str) -> tuple[int, int, int]:
    return PAL.by_symbol[sym]


def to_image(g: Grid) -> Image.Image:
    im = Image.new("RGBA", (len(g[0]), len(g)), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T:
                px[x, y] = rgb(c) + (255,)
    return im


def font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # very old Pillow
        return ImageFont.load_default()


def hard_text(img: Image.Image, xy: tuple[int, int], text: str, fill: tuple[int, int, int], size: int) -> None:
    """Text with hard alpha (thresholded), so sheets keep palette colours only."""
    layer = Image.new("L", img.size, 0)
    ImageDraw.Draw(layer).text(xy, text, fill=255, font=font(size))
    mask = layer.point(lambda v: 255 if v >= 110 else 0)
    img.paste(Image.new(img.mode, img.size, fill + ((255,) if img.mode == "RGBA" else ())), (0, 0), mask)


def grass_bg(w: int, h: int, scale: int) -> Image.Image:
    tile = artlib.render(artlib.parse_sprite(SRC / "grass_1.txt"), PAL).convert("RGB")
    bg = Image.new("RGB", (w // scale + 16, h // scale + 16))
    for y in range(0, bg.height, 16):
        for x in range(0, bg.width, 16):
            bg.paste(tile, (x, y))
    return bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST).crop((0, 0, w, h))


DARK = (42, 38, 51)
CREAM = rgb("1")
CELL_W, CELL_H, FOOT_Y, FOOT_X = 64, 48, 42, 24


def write_sheet(frames: dict[str, list[Frame]]) -> None:
    label_w = 48
    cols = max(len(v) for v in frames.values())
    sheet = Image.new("RGBA", (label_w + cols * CELL_W, len(frames) * CELL_H), (0, 0, 0, 0))
    meta = {"generator": "tools/art/make_hero_lean_sheet.py", "seed": SEED, "status": "approved 2026-10-20; installed as art/src/hero2_* by --install",
            "cell": [CELL_W, CELL_H], "label_width": label_w,
            "notes": "x,y,w,h = frame rect in hero_lean_sheet.png; ax,ay = feet anchor in frame pixels (same convention "
                     "as art/build/sprites.json). Right-facing; left = mirrored at runtime.",
            "frames": []}
    for r, (state, fl) in enumerate(frames.items()):
        hard_text(sheet, (2, r * CELL_H + 18), state, CREAM, 10)
        for c, f in enumerate(fl):
            im = to_image(f.grid)
            x = label_w + c * CELL_W + max(0, min(CELL_W - im.width, FOOT_X - f.anchor[0]))
            y = r * CELL_H + max(0, min(CELL_H - im.height, FOOT_Y - f.anchor[1]))
            sheet.alpha_composite(im, (x, y))
            meta["frames"].append({"name": f.name, "state": state, "n": f.n, "source": f.source,
                                   "x": x, "y": y, "w": im.width, "h": im.height,
                                   "ax": f.anchor[0], "ay": f.anchor[1],
                                   "lean": f.params})
    sheet.save(OUT / "hero_lean_sheet.png")
    (OUT / "hero_lean_sheet.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")


def write_grids(frames: dict[str, list[Frame]]) -> None:
    d = OUT / "grids"
    d.mkdir(parents=True, exist_ok=True)
    for fl in frames.values():
        for f in fl:
            note = "copied unchanged" if f.params.get("unchanged") else f"leaning re-pose, lean {f.params['lean']} deg"
            lines = ["# kind: sprite", f"# anchor: {f.anchor[0]},{f.anchor[1]}",
                     f"# generated by tools/art/make_hero_lean_sheet.py from {f.source} ({note}); review copy, the game uses art/src/{f.source}.txt"]
            lines += ["".join(r) for r in f.grid]
            (d / f"{f.name}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def place(canvas: Image.Image, f: Frame, foot: tuple[int, int], scale: int) -> None:
    im = to_image(f.grid)
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    canvas.alpha_composite(im, (foot[0] - f.anchor[0] * scale, foot[1] - f.anchor[1] * scale))


def contact(old: dict[str, list[Frame]], new: dict[str, list[Frame]], bg: str) -> Image.Image:
    S = 4
    cw, chh = CELL_W * S, CELL_H * S
    label_w, gap, head = 150, 48, 60
    cols = 6
    W = label_w + cols * cw * 2 + gap
    H = head + len(old) * chh
    img = (grass_bg(W, H, S) if bg == "grass" else Image.new("RGB", (W, H), DARK)).convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, head - 4), fill=DARK + (255,))
    hard_text(img, (label_w + 8, 14), "OLD  (upright import)", CREAM, 28)
    hard_text(img, (label_w + cols * cw + gap + 8, 14), "NEW  (leaning, in-game hero2)", CREAM, 28)
    sep_x = label_w + cols * cw + gap // 2
    d.rectangle((sep_x - 2, head, sep_x + 2, H), fill=CREAM + (255,))
    for r, state in enumerate(old):
        y0 = head + r * chh
        d.rectangle((0, y0, label_w - 10, y0 + chh - 6), fill=DARK + (255,))
        hard_text(img, (10, y0 + chh // 2 - 30), state, CREAM, 30)
        tag = "unchanged" if state in UNCHANGED else ""
        if tag:
            hard_text(img, (10, y0 + chh // 2 + 8), tag, CREAM, 18)
        for side, fl in ((0, old[state]), (1, new[state])):
            for c, f in enumerate(fl):
                x0 = label_w + side * (cols * cw + gap) + c * cw
                foot = (x0 + FOOT_X * S, y0 + FOOT_Y * S)
                d.line((x0 + 8, foot[1], x0 + cw - 8, foot[1]), fill=(120, 110, 90, 255), width=2)
                place(img, f, foot, S)
                hard_text(img, (x0 + 6, y0 + 4), str(f.n), CREAM, 16)
    return img.convert("RGB")


def game_scale(old: dict[str, list[Frame]], new: dict[str, list[Frame]]) -> Image.Image:
    """320x180 at 1x on grass (what the game renders), then 4x nearest like the 1280x720 window."""
    W, H = 320, 180
    img = grass_bg(W, H, 1).convert("RGBA")
    picks = [("walk", 2), ("walk", 5), ("dash", 2), ("attack1", 4), ("attack2", 3), ("attack3", 4), ("parry", 3)]
    hard_text(img, (4, 2), "OLD", CREAM, 10)
    hard_text(img, (4, 92), "NEW", CREAM, 10)
    for i, (st, n) in enumerate(picks):
        x = 22 + i * 44
        place(img, old[st][n - 1], (x, 70), 1)
        place(img, new[st][n - 1], (x, 160), 1)
    return img.convert("RGB").resize((W * 4, H * 4), Image.NEAREST)


def sequence() -> list[tuple[str, int, int, str]]:
    """(state, n, ticks, caption) using the game's cadence (animation.gd, core/tuning.gd)."""
    seq: list[tuple[str, int, int, str]] = []
    seq += [("idle", 1, 20, "idle")]
    for _ in range(2):
        seq += [("walk", n, 5, "walk") for n in range(1, 7)]
    seq += [("idle", 1, 20, "idle")]
    windup, active, recovery = [7, 6, 9], [3, 3, 4], [9, 9, 16]
    for s in range(3):
        name = f"attack{s + 1}"
        for k, ticks in enumerate((windup[s], active[s], recovery[s])):
            a = ticks // 2
            seq += [(name, k * 2 + 1, a, f"combo {s + 1}"), (name, k * 2 + 2, ticks - a, f"combo {s + 1}")]
    seq += [("idle", 1, 20, "idle")]
    for _ in range(2):
        seq += [("dash", 1, 1, "dash"), ("dash", 2, 1, "dash"), ("dash", 3, 1, "dash"), ("dash", 4, 3, "dash"),
                ("idle", 1, 16, "dash")]
    return seq


def gif(old: dict[str, list[Frame]], new: dict[str, list[Frame]], slow: float, path: Path) -> None:
    S = 4
    pw, ph = 96, 56
    W, H = pw * S * 2 + 8, ph * S + 40
    bg = grass_bg(W, H, S)
    frames, durations = [], []
    for st, n, ticks, cap in sequence():
        img = bg.copy().convert("RGBA")
        d = ImageDraw.Draw(img)
        d.rectangle((0, 0, W, 34), fill=DARK + (255,))
        d.rectangle((pw * S, 34, pw * S + 7, H), fill=DARK + (255,))
        speed = "0.5x speed" if slow > 1 else "game speed"
        hard_text(img, (10, 6), f"OLD   {cap}", CREAM, 22)
        hard_text(img, (pw * S + 18, 6), f"NEW   {cap}   ({speed})", CREAM, 22)
        for side, sets in ((0, old), (1, new)):
            foot = (side * (pw * S + 8) + 40 * S, 34 + 50 * S)
            place(img, sets[st][n - 1], foot, S)
        frames.append(img.convert("RGB"))
        durations.append(max(20, int(round(ticks * 1000 / 60 * slow / 10.0)) * 10))
    pal_frames = [f.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    pal_frames[0].save(path, save_all=True, append_images=pal_frames[1:], duration=durations, loop=0, disposal=1,
                       optimize=False)


# ---------------------------------------------------------------------------------------------------- main
def install(frames: dict[str, list[Frame]]) -> int:
    """Write the in-game katana frames art/src/hero2_<state>_right_<n>.txt (same names, counts, feet anchors)."""
    n = 0
    for fl in frames.values():
        for f in fl:
            note = ("upright, copied unchanged" if f.params.get("unchanged")
                    else f"leaning re-pose, lean {f.params['lean']} deg")
            lines = ["# kind: sprite", f"# anchor: {f.anchor[0]},{f.anchor[1]}",
                     f"# generated by tools/art/make_hero_lean_sheet.py --install from "
                     f"art/reference/hero_lean/upright/{f.source}.txt ({note}); do not hand-edit"]
            lines += ["".join(r) for r in f.grid]
            (SRC / f"{f.source}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
            n += 1
    return n


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--install", action="store_true",
                    help="also write the leaned frames into art/src as the in-game hero2_* katana frames")
    ap.add_argument("--no-review", action="store_true", help="skip the review sheets, grids and GIFs")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    old: dict[str, list[Frame]] = {}
    new: dict[str, list[Frame]] = {}
    for state, count in STATES:
        old[state] = []
        new[state] = []
        for n in range(1, count + 1):
            g, a = load(f"hero2_{state}_right_{n}")
            old[state].append(Frame(f"hero2_{state}_right_{n}", f"hero2_{state}_right_{n}", state, n, g, a))
            f = build_frame(state, n)
            bad = {c for row in f.grid for c in row if c != T and (c not in PAL.by_symbol or c in PAL.reserved)}
            assert not bad, (f.name, bad)
            assert len(f.grid[0]) % 8 == 0 and len(f.grid) % 8 == 0, f.name
            new[state].append(f)
    if args.install:
        print(f"installed {install(new)} hero2_* frames into {SRC.relative_to(ROOT)}")
    if args.no_review:
        return 0
    write_sheet(new)
    write_grids(new)
    contact(old, new, "dark").save(OUT / "contact_old_vs_new_dark.png")
    contact(old, new, "grass").save(OUT / "contact_old_vs_new_grass.png")
    game_scale(old, new).save(OUT / "game_scale_preview.png")
    gif(old, new, 2.0, OUT / "preview_old_vs_new.gif")
    gif(old, new, 1.0, OUT / "preview_old_vs_new_realtime.gif")
    total = sum(len(v) for v in new.values())
    print(f"wrote {total} review frames to {OUT.relative_to(ROOT)}")
    for fl in new.values():
        for f in fl:
            if not f.params.get("unchanged"):
                p = f.params
                print(f"  {f.name:28s} {len(f.grid[0])}x{len(f.grid)} anchor {f.anchor} hip {p['hip_row']} "
                      f"px {p['pivot_x']} neck {p['neck_row']} head {p['head_shift']} grip {p['grip']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
