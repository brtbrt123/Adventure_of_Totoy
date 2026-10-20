"""Import the approved Chain Scythe + Reaper's Coil art into in-game sprite sources (art/src/*.txt).

Reference: art/reference/chain_scythe/ (approved v1.1: concept poses, weapon layers, effects, medallions), drawn by
tools/art/make_chain_scythe_art.py. This script reuses that script's routines (scythe, chain, fist_over grips, arcs,
chain effects, medallions) and the dagger importer's bodies (tools/art/import_dagger_sprites.py: the leaning hero2_*
bodies with the katana removed and the measured hand points carried through the lean warp), and generalises the
approved key poses to every hero frame the game animates, the way import_dagger_sprites.py did for the dual dagger.

Writes (deterministic: fixed seeds, sorted iteration; running twice gives identical files):
  art/src/totoy_scythe_<state>_right_<n>.txt   scythe-armed hero, one per hero2_* frame (idle 4, walk 6, dash 4,
                                               parry 6, hurt 4, victory 6, attack1..3 x 6) with the same numbering
  art/src/totoy_scythe_coil_<phase>_<n>.txt    Reaper's Coil poses: windup 2, whip 3, pull 3, spin 8, recover 2
  art/src/fx_scythe_*.txt, art/src/fx_chain_*.txt   swing arcs, spin ring halves, chain whip / links / hook / pull /
                                               dust / scuff / stagger / stars / land, flying scythe
  art/src/ui_weapon_chain_scythe_1.txt, art/src/ui_aspect_reapers_coil_1.txt
  art/build/chain_scythe_sprites_manifest.json name -> frames, sizes, anchors, body sources, hand / chain points
  docs/previews/chain_scythe_import_*.png/.gif review sheets at 4x (viewing only, not game art)

Bodies: exactly the in-game hero2_* bodies (leaning; idle and victory upright), katana removed. The Reaper's Coil
poses borrow hero2 bodies (see COIL): the pull leans back (-14) and the spin leans forward (8) with the same custom
leans as the approved concept. Anchors are the feet point of the hero2 frame the body comes from (the canvas only
grows where the scythe reaches past it; the anchor moves with it, so the feet line up). Gold (x, y) and red (z, A)
are never used.

Run from the project root, then validate, build and preview:
  python tools/art/import_chain_scythe_sprites.py
  python tools/art/validate_art.py; python tools/art/build_art.py; python tools/art/preview_art.py
Options: --no-previews (skip the review sheets and GIFs).
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
import import_dagger_sprites as D  # noqa: E402  (bodies, hand points, katana removal; no side effects on import)
import make_chain_scythe_art as C  # noqa: E402  (the approved scythe/chain/fx drawing; no side effects on import)
import make_dual_dagger_art as M  # noqa: E402  (grid helpers)
import make_hero_lean_sheet as L  # noqa: E402  (the lean warp)

ROOT = artlib.ROOT
SRC = artlib.SRC_DIR
BUILD = artlib.BUILD_DIR
PREVIEWS = ROOT / "docs" / "previews"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)
GENERATOR = "tools/art/import_chain_scythe_sprites.py"
VID = "totoy_scythe"

Grid = list
blank, put, get, copy, paste = M.blank, M.put, M.get, M.copy, M.paste

# Work cell: every frame is composed with the feet at (FX, FY), then cropped.
CW, CH, FX, FY = 176, 128, 80, 100


# ---------------------------------------------------------------------------------------------- frame specs
# Points are FEET-RELATIVE game pixels (x right, y down; the feet anchor is (0, 0)). Hands come from the body:
# "hand0" / "hand1" are the two fists of the hero2 frame (import_dagger_sprites.HANDS order carried through the lean),
# "pommel" / "head" are the scythe ends, ("hand0", dx, dy) etc. are offsets from those points.
#   scythe: grip=(i, j) two-handed (haft through hand j then hand i, head beyond hand i) | grip=(i,) + angle (deg,
#           0 = right, 90 = down) one hand; fwd / back = haft beyond the head-side / pommel-side hand; side = blade
#           direction (+1 clockwise on screen from the pommel->head direction); blade = blade length.
#   layer:  where the scythe draws ("front" over the body, "back" behind it); chains carry their own layer.
#   fists:  hands redrawn closed over the weapon (make_chain_scythe_art.fist_over, the approved grips).
#   origin: Reaper's Coil frames where the runtime chain leaves the hand (the chain to the target is drawn at runtime
#           from fx_chain_link_* / fx_chain_whip_*); written to the manifest as "chain_origin".
#   orbit:  spin frames: the scythe on its chain at this angle (deg) of the spin circle.
def S(**kw) -> dict:
    return kw


# The approved concept poses (art/reference/chain_scythe/concept_v1, cell feet (32,56)) in feet-relative points.
READY = S(scythe=dict(grip=(1,), angle=-80, fwd=25, back=9, side=1, blade=14), layer="front",
          chains=[(["pommel", (-1, -1), (-6, -4), "hand0"], "front"), (["hand0", (-8, -7), (-9, -2), (-12, 0)], "front")],
          fists=[0, 1])
WALK = S(scythe=dict(grip=(1,), angle=-148, fwd=24, back=7, side=-1, blade=12), layer="back",
         chains=[(["pommel", (17, -3), (13, 0), (7, 0)], "back")], fists=[1])
SWING1 = S(scythe=dict(grip=(1, 0), fwd=7, back=8, side=1, blade=14), layer="front",
           chains=[(["pommel", (-15, -12), (-21, -8), (-27, -11)], "back")], fists=[0, 1])
SWING2 = S(scythe=dict(grip=(0, 1), fwd=10, back=6, side=-1, blade=14), layer="front",
           chains=[(["pommel", (17, -5), (23, -4), (28, -1)], "back")], fists=[0, 1])
SWING3 = S(scythe=dict(grip=(0,), angle=24, fwd=12, back=16, side=-1, blade=13), layer="front",
           chains=[(["pommel", (-19, -18), (-22, -25), (-19, -31)], "back")], fists=[0, 1])
WINDUP = S(scythe=dict(grip=(0,), angle=172, fwd=21, back=6, side=1, blade=13), layer="front",
           chains=[(["pommel", (6, -7), "hand1"], "front"), (["hand1", (15, -5), (13, -1)], "front")], fists=[0, 1])
RECOVERY = S(scythe=dict(grip=(0, 1), fwd=10, back=6, side=-1, blade=13), layer="front",
             chains=[(["pommel", (17, -9), (15, -4), (18, -1)], "back")], fists=[0, 1])
SPIN_POSE = L.P(lean=8, stride=1.15, hip_fwd=1, drop=1)
PULL_POSE = L.P(lean=-14, stride=1.25, hip_fwd=-2, drop=2)
# the haul: the approved pull lean (-14) between a lighter (-9) and a deeper (-19) lean on the same body
PULL_POSES = [L.P(lean=-9, stride=1.2, hip_fwd=-1, drop=1), PULL_POSE, L.P(lean=-19, stride=1.3, hip_fwd=-2.5, drop=2)]


def sc(base: dict, **over) -> dict:
    """A copy of a spec with scythe fields overridden (scythe=... keys) and/or top-level keys replaced."""
    out = {k: v for k, v in base.items()}
    sk = {k[3:]: v for k, v in over.items() if k.startswith("sc_")}
    if sk:
        out["scythe"] = {**base["scythe"], **sk}
    out.update({k: v for k, v in over.items() if not k.startswith("sc_")})
    return out


def trail(dx0: int, flutter: int) -> list:
    """A chain fluttering behind the pommel (dash)."""
    return [(["pommel", ("pommel", -5, 3 + flutter), ("pommel", -11, 2 - flutter), ("pommel", -17 + dx0, 4 + flutter)], "back")]


def on_ground() -> list:
    return [(["pommel", ("pommel", -4, 0), ("pommel", -9, 0), ("pommel", -13, -1)], "back")]


# Hero frames: (state, n) -> spec. Swing phases: 1-2 windup, 3-4 active, 5-6 recovery.
HERO: dict[tuple[str, int], dict] = {}
for n in range(1, 5):
    HERO[("idle", n)] = READY
for n, a in zip(range(1, 7), (-146, -148, -150, -149, -147, -150)):
    HERO[("walk", n)] = sc(WALK, sc_angle=a, phase=n)
# dash: the scythe trails behind in the rear fist, blade up, the chain fluttering behind the pommel
for n, (a, f) in enumerate(((176, 0), (178, 1), (178, -1), (165, 0)), start=1):
    HERO[("dash", n)] = S(scythe=dict(grip=(0,), angle=a, fwd=20, back=5, side=1, blade=12), layer="back",
                          chains=trail(0, f), fists=[0], phase=n)
# parry: the haft raised as a staff guard in front, the blade hooked forward over it
for n, a in zip(range(1, 6), (-70, -72, -74, -60, -68)):
    HERO[("parry", n)] = S(scythe=dict(grip=(0,), angle=a, fwd=16, back=14, side=1, blade=12), layer="front",
                           chains=[(["pommel", ("pommel", -4, 1), ("pommel", -9, 1), ("pommel", -12, 0)], "back")],
                           fists=[0, 1])
HERO[("parry", 6)] = READY
# hurt: the scythe stays in the lead fist and tips back with the recoil
HERO[("hurt", 1)] = READY
HERO[("hurt", 2)] = sc(READY, sc_angle=-102, sc_fwd=20, chains=[(["pommel", ("pommel", -4, 4), ("hand0", 2, 4), "hand0"], "front")])
HERO[("hurt", 3)] = sc(READY, sc_angle=-118, sc_fwd=20, chains=[(["pommel", ("pommel", -3, 5), ("hand0", 3, 5), "hand0"], "front")])
HERO[("hurt", 4)] = READY
# victory: swing the scythe up, hold it high overhead (3), then plant it upright, pommel on the ground
HERO[("victory", 1)] = S(scythe=dict(grip=(1,), angle=-60, fwd=20, back=9, side=1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", -4, 3), ("hand0", 1, 4), "hand0"], "front")], fists=[0, 1])
HERO[("victory", 2)] = S(scythe=dict(grip=(1,), angle=-75, fwd=21, back=9, side=1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", -4, 3), ("hand0", 1, 4), "hand0"], "front")], fists=[0, 1])
HERO[("victory", 3)] = S(scythe=dict(grip=(0,), angle=-95, fwd=13, back=13, side=1, blade=14), layer="front",
                         chains=[(["pommel", ("pommel", -3, 4), ("pommel", -6, 9), ("pommel", -4, 13)], "back")], fists=[0])
for n in (4, 5, 6):
    HERO[("victory", n)] = S(scythe=dict(grip=(1,), angle=-86, fwd=26, back=13, side=1, blade=14), layer="front",
                             chains=on_ground(), fists=[1])
# swing 1: wide horizontal sweep. Windup: the blade cocked low behind; active: it comes round in front (3) and out to
# the right (4, the approved key pose); recovery: follow-through low in front (5), then the approved recovery (6).
HERO[("attack1", 1)] = S(scythe=dict(grip=(0, 1), fwd=12, back=4, side=-1, blade=13), layer="back",
                         chains=[(["pommel", ("pommel", 4, 4), ("pommel", 7, 9), ("pommel", 12, 11)], "back")], fists=[0, 1])
HERO[("attack1", 2)] = S(scythe=dict(grip=(0, 1), fwd=14, back=4, side=-1, blade=14), layer="back",
                         chains=[(["pommel", ("pommel", 4, 4), ("pommel", 8, 8), ("pommel", 13, 9)], "back")], fists=[0, 1])
HERO[("attack1", 3)] = S(scythe=dict(grip=(1, 0), fwd=8, back=10, side=1, blade=10), layer="front",
                         chains=[(["pommel", ("pommel", -5, 2), ("pommel", -10, -1), ("pommel", -15, 1)], "back")], fists=[0, 1])
HERO[("attack1", 4)] = SWING1
HERO[("attack1", 5)] = S(scythe=dict(grip=(1, 0), fwd=8, back=8, side=1, blade=12), layer="front",
                         chains=[(["pommel", ("pommel", -5, 3), ("pommel", -10, 4), ("pommel", -14, 2)], "back")], fists=[0, 1])
HERO[("attack1", 6)] = RECOVERY
# swing 2: reverse rising arc. Windup: the head low in front with the blade up; active: it rises (3) over the top to
# the back (4, approved); recovery: the blade hangs behind (5), then the recovery pose.
HERO[("attack2", 1)] = S(scythe=dict(grip=(1,), angle=20, fwd=10, back=14, side=-1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", -4, 3), ("pommel", -9, 4), ("pommel", -13, 3)], "back")], fists=[0, 1])
HERO[("attack2", 2)] = S(scythe=dict(grip=(1,), angle=25, fwd=10, back=14, side=-1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", -4, 3), ("pommel", -9, 5), ("pommel", -13, 5)], "back")], fists=[0, 1])
HERO[("attack2", 3)] = S(scythe=dict(grip=(0, 1), fwd=10, back=6, side=-1, blade=14), layer="front",
                         chains=[(["pommel", ("pommel", -4, 4), ("pommel", -8, 8), ("pommel", -13, 9)], "back")], fists=[0, 1])
HERO[("attack2", 4)] = SWING2
HERO[("attack2", 5)] = S(scythe=dict(grip=(1, 0), fwd=12, back=8, side=-1, blade=13), layer="back",
                         chains=[(["pommel", ("pommel", 4, 4), ("pommel", 8, 8), ("pommel", 12, 9)], "back")], fists=[0, 1])
HERO[("attack2", 6)] = RECOVERY
# swing 3: overhead to low. Windup: raised high, the blade hanging behind the head; active: it comes over (3) and
# down to the ground in front (4, approved); recovery: the head rests low in front (5), then the recovery pose.
HERO[("attack3", 1)] = S(scythe=dict(grip=(0,), angle=-145, fwd=16, back=10, side=-1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", 3, 5), ("pommel", 2, 11), ("pommel", 5, 15)], "back")], fists=[0, 1])
HERO[("attack3", 2)] = S(scythe=dict(grip=(0,), angle=-160, fwd=16, back=10, side=-1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", 3, 5), ("pommel", 1, 11), ("pommel", 4, 16)], "back")], fists=[0, 1])
HERO[("attack3", 3)] = S(scythe=dict(grip=(0,), angle=-5, fwd=12, back=14, side=-1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", -4, -4), ("pommel", -6, -10), ("pommel", -3, -15)], "back")], fists=[0, 1])
HERO[("attack3", 4)] = SWING3
HERO[("attack3", 5)] = S(scythe=dict(grip=(0,), angle=20, fwd=12, back=16, side=-1, blade=13), layer="front",
                         chains=[(["pommel", ("pommel", -4, -3), ("pommel", -8, -1), ("pommel", -12, 0)], "back")], fists=[0, 1])
HERO[("attack3", 6)] = RECOVERY

HERO_STATES: list[tuple[str, int]] = [("idle", 4), ("walk", 6), ("dash", 4), ("parry", 6), ("hurt", 4), ("victory", 6),
                                      ("attack1", 6), ("attack2", 6), ("attack3", 6)]

# Reaper's Coil poses: (phase, n) -> (hero2 body source frame, custom lean or None, spec)
SPIN_N = 8
COIL: dict[tuple[str, int], tuple[str, "L.Pose | None", dict]] = {
    ("windup", 1): ("hero2_attack1_right_1", None, WINDUP),
    ("windup", 2): ("hero2_attack1_right_2", None, sc(WINDUP, sc_angle=168, sc_fwd=22, phase=2)),
    # whip (the hook phase): the chain flies out of the lead fist; the scythe and the long chain are runtime effects
    ("whip", 1): ("hero2_attack2_right_3", None, S(scythe=None, chains=[(["hand0", ("hand0", -1, 5), ("hand0", -3, 9)], "front")],
                                                   fists=[0], origin="hand0", fist_dir={0: (1.0, 0.0)})),
    ("whip", 2): ("hero2_attack1_right_3", None, S(scythe=None, chains=[(["hand1", ("hand1", -2, 5), ("hand1", -4, 9)], "front")],
                                                   fists=[1], origin="hand1", fist_dir={1: (1.0, 0.0)})),
    ("whip", 3): ("hero2_attack1_right_4", None, S(scythe=None, chains=[(["hand1", ("hand1", -2, 6), ("hand1", -5, 10)], "front")],
                                                   fists=[1], origin="hand1", fist_dir={1: (1.0, 0.0)})),
    # pull (the drag): leaning back, both fists on the taut chain, a slack loop hanging from the rear fist; one haul
    # cycle on the approved pull body: approved lean (1), heaved further back (2), easing forward to re-grip (3)
    ("pull", 1): ("hero2_parry_right_1", PULL_POSE, S(scythe=None, chains=[(["hand0", "hand1", ("hand1", -5, 9), ("hand1", -2, 12), ("hand1", 0, 8)], "front")],
                                                      fists=[0, 1], origin="hand0")),
    ("pull", 2): ("hero2_parry_right_1", PULL_POSES[2], S(scythe=None, chains=[(["hand0", "hand1", ("hand1", -4, 9), ("hand1", -1, 12), ("hand1", 1, 9)], "front")],
                                                      fists=[0, 1], origin="hand0", phase=2)),
    ("pull", 3): ("hero2_parry_right_1", PULL_POSES[0], S(scythe=None, chains=[(["hand0", "hand1", ("hand1", -5, 8), ("hand1", -3, 12), ("hand1", 0, 9)], "front")],
                                                      fists=[0, 1], origin="hand0", phase=3)),
    ("recover", 1): ("hero2_attack1_right_5", None, HERO[("attack1", 5)]),
    ("recover", 2): ("hero2_attack1_right_6", None, RECOVERY),
}
# spin: the raised fist whirls the scythe on its chain once round (frame k at 45 deg steps; 0 deg = in front of the
# hero to the right, 90 = toward the camera, 180 = behind to the left, 270 = behind the body), the slack end hanging.
for k in range(1, SPIN_N + 1):
    COIL[("spin", k)] = ("hero2_victory_right_3", SPIN_POSE,
                         S(scythe=None, orbit=(k - 1) * 360 / SPIN_N, chains=[(["hand0", ("hand0", 3, 4), ("hand0", 2, 9)], "front")],
                           fists=[0], phase=k))
COIL_ORDER = [("windup", 2), ("whip", 3), ("pull", 3), ("spin", SPIN_N), ("recover", 2)]
# spin geometry: the pommel circles on an ellipse around the hero (seen from the side-top), centre 11 px above the
# feet; the blade reaches about 36 px out (the fx_scythe_spin ring).
ORBIT_C, ORBIT_RX, ORBIT_RY = (0, -11), 26, 8


# ---------------------------------------------------------------------------------------------- frame build
def make_body(src: str, pose: "L.Pose | None") -> tuple[Grid, tuple[int, int], list[tuple[int, int]]]:
    """(katana-free leaning body, feet anchor, hand points) of a hero2 frame, optionally with a custom lean."""
    state, n = src[len("hero2_"):].rsplit("_right_", 1)
    if pose is None:
        lf = L.build_frame(state, int(n))
    else:
        lf = L.build_frame(f"cs_{state}", int(n), src, pose)
    body = D.strip_katana([r[:] for r in lf.grid], src)
    hands = [(h[0], h[1]) for h in D.lean_hands(src, lf)]
    return body, lf.anchor, hands


def resolve(p, named: dict) -> tuple[float, float]:
    if isinstance(p, str):
        return named[p]
    if len(p) == 3:
        b = named[p[0]]
        return (b[0] + p[1], min(b[1] + p[2], FY))  # a chain never sinks below the ground row
    return (FX + p[0], FY + min(p[1], 0))  # feet-relative


def compose(src: str, pose: "L.Pose | None", spec: dict) -> dict:
    body0, (ax, ay), hands0 = make_body(src, pose)
    ox, oy = FX - ax, FY - ay
    body = blank(CW, CH)
    paste(body, body0, ox, oy)
    hands = [(x + ox, y + oy) for x, y in hands0]
    back, front = blank(CW, CH), blank(CW, CH)
    geo = None
    spec_sc = spec.get("scythe")
    if spec_sc:
        geo = C.scythe_geometry(spec_sc, hands)
    named = {"hand0": hands[0], "hand1": hands[1]}
    if geo:
        named["pommel"], named["head"] = geo
    orbit = spec.get("orbit")
    if orbit is not None:
        th = math.radians(orbit)
        pm = (FX + ORBIT_C[0] + math.cos(th) * ORBIT_RX, FY + ORBIT_C[1] + math.sin(th) * ORBIT_RY)
        named["pommel"] = pm
        behind = math.sin(th) < -1e-6
        lay = back if behind else front
        C.draw_chain(lay, [hands[0], ((hands[0][0] + pm[0]) / 2, (hands[0][1] + pm[1]) / 2 + 2), pm], phase=spec.get("phase", 1))
        rot = round(((orbit + 90) % 360) / 45) % 8  # head radially outward, the blade leading (as in the combo GIF)
        paste(lay, C.flying_scythe(rot), C.rnd(pm[0]) - 16, C.rnd(pm[1]) - 16)
    for ctrl, lay in spec.get("chains", []):
        pts = [resolve(c, named) for c in ctrl]
        C.draw_chain(back if lay == "back" else front, pts, phase=spec.get("phase", 1))
    if geo:
        C.draw_scythe(front if spec.get("layer", "front") == "front" else back, geo[0], geo[1], spec_sc["side"], spec_sc["blade"])
    for i in spec.get("fists", []):
        along = None
        if geo and i in spec_sc.get("grip", ()):
            along = (geo[1][0] - geo[0][0], geo[1][1] - geo[0][1])
        elif orbit is not None and i == 0:
            along = (named["pommel"][0] - hands[0][0], named["pommel"][1] - hands[0][1])
        elif i in spec.get("fist_dir", {}):
            along = spec["fist_dir"][i]  # the runtime chain leaves this fist toward the target (facing right)
        else:
            for ctrl, _ in spec.get("chains", []):
                if f"hand{i}" in ctrl:
                    along = C.weapon_dir_at([resolve(c, named) for c in ctrl], hands[i])
                    break
        C.fist_over(front, body, hands[i], along)
    full = copy(back)
    paste(full, body, 0, 0)
    paste(full, front, 0, 0)
    origin = named[spec["origin"]] if spec.get("origin") else None
    return {"grid": full, "body": body, "body0": body0, "orig_size": (len(body0[0]), len(body0)), "orig_anchor": (ax, ay),
            "hands": hands, "geo": geo, "origin": origin, "source": src, "custom_lean": pose is not None}


def crop_frame(f: dict) -> tuple[Grid, tuple[int, int], tuple[int, int]]:
    """Crop to the union of the hero2 canvas and every opaque pixel, sides rounded up to multiples of 8 (growing
    toward the side that already grew, like import_dagger_sprites.crop_canvas). Returns (grid, anchor, offset)."""
    (w, h), (ax, ay) = f["orig_size"], f["orig_anchor"]
    x0, y0 = FX - ax, FY - ay
    x1, y1 = x0 + w, y0 + h
    ox0, oy0 = x0, y0
    g = f["grid"]
    for y, row in enumerate(g):
        for x, c in enumerate(row):
            if c != T:
                x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x + 1), max(y1, y + 1)
    cw, ch = x1 - x0, y1 - y0
    cw8, ch8 = -(-cw // 8) * 8, -(-ch // 8) * 8
    x0 = x0 - (cw8 - cw) if x0 < ox0 else x0
    y0 = y0 - (ch8 - ch) if y0 < oy0 else y0
    assert x0 >= 0 and y0 >= 0 and x0 + cw8 <= CW and y0 + ch8 <= CH, ("work cell too small", f["source"])
    out = [[g[y][x] for x in range(x0, x0 + cw8)] for y in range(y0, y0 + ch8)]
    return out, (FX - x0, FY - y0), (x0, y0)


# ---------------------------------------------------------------------------------------------- effects
SPIN_FX = (48, 45, 36, 11, 0, 180, 540, 5.5)  # the approved ring at rx 36 (the core spin radius), same thickness


def land_frame(k: int) -> Grid:
    """32x24, anchor (16,18) = where the thrown hook lands when it misses: 1 the blade bites the ground (small cream
    clink + a dirt kick), 2 a dirt poof with a teal glint, 3 the poof spreads and thins, 4 settling motes."""
    rng = random.Random(780 + k)
    g = blank(32, 24)
    cx, cy = 16, 18
    if k == 1:
        C.star(g, cx, cy - 3, 3, "1", "p", "u", 1)
        for x in range(-4, 5):
            if abs(x) > 1:
                put(g, cx + x, cy, "c" if abs(x) < 3 else "b")
        C.outline_layer(g, "k")
        return g
    r = {2: 4.0, 3: 6.0, 4: 7.0}[k]
    for i in range(7 if k < 4 else 5):
        a = math.pi + i * math.pi / 6 + rng.uniform(-0.15, 0.15)
        px, py = cx + math.cos(a) * r * 1.4, cy + math.sin(a) * r * 0.7
        rr = {2: 2.2, 3: 2.0, 4: 1.2}[k] + rng.uniform(0, 0.6)
        for yy in range(-3, 4):
            for xx in range(-3, 4):
                if (xx / (rr * 1.2)) ** 2 + (yy / rr) ** 2 <= 1 and (k < 4 or (xx + yy + i) % 2 == 0):
                    put(g, C.rnd(px + xx), C.rnd(py + yy), "d" if yy < 0 else "c")
    for y in range(24):
        for x in range(32):
            if g[y][x] != T and get(g, x, y + 1) == T and y >= cy - 1:
                g[y][x] = "b"
    if k < 4:
        C.outline_layer(g, "9")
    if k == 2:
        C.star(g, cx, cy - 5, 2, "1", "u", "u", 0)
    elif k == 3:
        put(g, cx - 1, cy - 8, "7"), put(g, cx + 3, cy - 6, "u")
    else:
        for _ in range(3):
            put(g, rng.randint(cx - 9, cx + 9), rng.randint(cy - 9, cy - 3), rng.choice("ut7"))
    return g


def build_effects() -> list[tuple[str, Grid, tuple[int, int], str]]:
    fx = C.build_fx()
    out: list[tuple[str, Grid, tuple[int, int], str]] = []
    for s in (1, 2, 3):
        for ph in range(4):
            out.append((f"fx_scythe_arc_{s}_{ph + 1}", fx["arcs"][s][ph], C.ARC_ANCHOR, f"swing {s} arc, phase {C.PHASES[ph]}"))
    for ph in (1, 2, 3, 4):
        b, f = C.arc_frame(SPIN_FX, ph, 9100 + ph, spans=C.SPIN_SPANS, split=True)
        out.append((f"fx_scythe_spin_back_{ph}", b, C.SPIN_ANCHOR, f"spin ring rx 36, back half, phase {C.PHASES[ph - 1]}"))
        out.append((f"fx_scythe_spin_front_{ph}", f, C.SPIN_ANCHOR, f"spin ring rx 36, front half, phase {C.PHASES[ph - 1]}"))
    for k, g in enumerate(fx["whip"], 1):
        out.append((f"fx_chain_whip_{k}", g, (0, 16), "chain whip, anchor = hand, hook point (120,16)"))
    for k, g in enumerate(fx["segments"], 1):
        out.append((f"fx_chain_link_{k}", g, (0, 4), "chain segment (0,4) to (31,4)"))
    for k, g in enumerate(fx["flying"], 1):
        out.append((f"fx_scythe_flying_{k}", g, (16, 16), f"flying scythe, rotation {(k - 1) * 45} deg, anchor = pommel ring"))
    for k, g in enumerate(fx["hook"], 1):
        out.append((f"fx_chain_hook_{k}", g, (16, 16), "hook clink, anchor = hook point"))
    for k, g in enumerate(fx["pull"], 1):
        out.append((f"fx_chain_pull_{k}", g, (12, 44), "pull streaks, anchor = dragged target's feet"))
    for k, g in enumerate(fx["dust"], 1):
        out.append((f"fx_chain_dust_{k}", g, (8, 14), "drag dust, anchor = target's leading foot"))
    for k, g in enumerate(fx["scuff"], 1):
        out.append((f"fx_chain_scuff_{k}", g, (16, 8), "drag scuff decal, anchor = centre"))
    for k, g in enumerate(fx["stagger"], 1):
        out.append((f"fx_chain_stagger_{k}", g, (16, 16), "stagger burst, anchor = target chest"))
    for k, g in enumerate(fx["dizzy"], 1):
        out.append((f"fx_chain_stars_{k}", g, (16, 12), "dizzy stars, anchor = above the target's head"))
    for k in range(1, 5):
        out.append((f"fx_chain_land_{k}", land_frame(k), (16, 18), "hook lands on the ground (miss), anchor = landing point"))
    return out


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


ANCHOR_MEANING = [
    ("totoy_scythe_coil_spin", "feet (same world point as hero2_victory_right_3); the scythe circles the hero on its chain"),
    ("totoy_scythe_coil", "feet (same world point as the hero2 frame in body_sources); chain_origin = the fist the runtime chain leaves from"),
    ("totoy_scythe_", "feet (same world point as the matching hero2_* frame; place by anchor, mirror around it for left)"),
    ("fx_scythe_arc", "hero's feet (40,56); draw over the hero"),
    ("fx_scythe_spin", "hero's feet (48,56); back half before the hero, front half after"),
    ("fx_scythe_flying", "pommel ring where the chain attaches (cell centre); rotation (n-1)*45 deg clockwise, 1 = head up"),
    ("fx_chain_whip", "throwing hand (0,16); the hook point is (120,16)"),
    ("fx_chain_link", "segment start (0,4); it ends at (31,4): rotate/stretch between two points, tile end to end"),
    ("fx_chain_hook", "hook point on the target (centre)"),
    ("fx_chain_pull", "dragged target's feet (12,44); it moves toward -x, streaks trail to +x (mirror for the other side)"),
    ("fx_chain_dust", "target's leading foot on the ground (8,14); puffs trail to +x"),
    ("fx_chain_scuff", "decal centre on the ground"),
    ("fx_chain_stagger", "target's chest (centre)"),
    ("fx_chain_stars", "just above the staggered target's head (16,12)"),
    ("fx_chain_land", "landing point on the ground (16,18) when the hook misses"),
    ("ui_", "icon centre"),
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-previews", action="store_true")
    args = ap.parse_args()

    manifest: dict[str, dict] = {}
    written: dict[str, tuple[Grid, tuple[int, int]]] = {}
    frames: dict[str, dict] = {}

    def emit(name: str, g: Grid, anchor: tuple[int, int], note: str, group: str, extra: dict | None = None) -> None:
        write_sprite(name, g, anchor, note)
        written[name] = (g, anchor)
        base = name.rsplit("_", 1)[0]
        e = manifest.setdefault(base, {"group": group, "frames": 0, "size": [len(g[0]), len(g)], "anchors": [], "frame_sizes": []})
        e["frames"] += 1
        e["anchors"].append(list(anchor))
        e["frame_sizes"].append([len(g[0]), len(g)])
        for k, v in (extra or {}).items():
            e.setdefault(k, []).append(v)

    def emit_hero(name: str, src: str, pose, spec: dict, group: str) -> None:
        f = compose(src, pose, spec)
        g, anchor, (x0, y0) = crop_frame(f)
        hands = [[x - x0 - anchor[0], y - y0 - anchor[1]] for x, y in f["hands"]]
        extra = {"body_sources": src + (" (custom lean)" if pose is not None else ""), "hands": hands}
        if f["origin"] is not None:
            extra["chain_origin"] = [C.rnd(f["origin"][0]) - x0, C.rnd(f["origin"][1]) - y0]
        emit(name, g, anchor, f"body from {src}{' with a custom lean' if pose is not None else ''}, katana removed, chain scythe", group, extra)
        f.update({"crop": (x0, y0), "anchor": anchor, "out": g})
        if f["origin"] is not None:
            f["origin_rel"] = (C.rnd(f["origin"][0]) - FX, C.rnd(f["origin"][1]) - FY)
        frames[name] = f

    # 1. the scythe-armed hero (same numbering as hero2_*) and 2. the Reaper's Coil poses
    for state, count in HERO_STATES:
        for n in range(1, count + 1):
            emit_hero(f"{VID}_{state}_right_{n}", f"hero2_{state}_right_{n}", None, HERO[(state, n)], "hero_scythe")
    for phase, count in COIL_ORDER:
        for n in range(1, count + 1):
            src, pose, spec = COIL[(phase, n)]
            emit_hero(f"{VID}_coil_{phase}_{n}", src, pose, spec, "hero_scythe_coil")

    # 3. effects
    for name, g, anchor, note in build_effects():
        emit(name, g, anchor, note, "fx_chain_scythe")

    # 4. UI
    emit("ui_weapon_chain_scythe_1", C.weapon_medallion(), (24, 24), "from skill_medallions_v1 weapon medallion", "ui")
    emit("ui_aspect_reapers_coil_1", C.skill_medallion(), (12, 12), "from skill_medallions_v1 skill medallion", "ui")

    # 5. manifest
    for e in manifest.values():
        for key in ("anchors", "frame_sizes"):
            if len({tuple(a) for a in e[key]}) == 1:
                e[{"anchors": "anchor", "frame_sizes": "size"}[key]] = e[key][0]
        if "body_sources" in e and len(set(e["body_sources"])) == 1 and e["frames"] > 1:
            e["body_source"] = e["body_sources"][0]
    data = {
        "generator": GENERATOR,
        "note": "Sprite groups: name -> frame count (frames are <name>_1..N), canvas size, anchor per frame and its meaning. "
                "Hero frames (totoy_scythe_*) are right-facing; mirror around the anchor for left. Their numbering is exactly "
                "hero2_*'s, so the katana frame hero2_<state>_right_<n> becomes totoy_scythe_<state>_right_<n>. 'hands' and "
                "'chain_origin' are relative to the anchor (feet) in game pixels, x right, y down; 'chain_origin' is where the "
                "runtime chain (fx_chain_link_* / fx_chain_whip_*) leaves the fist on the Reaper's Coil whip and pull frames. "
                "Reference and approval: art/reference/chain_scythe/README.md.",
        "sprites": {k: manifest[k] for k in sorted(manifest)},
    }
    for base, e in data["sprites"].items():
        e["anchor_meaning"] = next(m for p, m in ANCHOR_MEANING if base.startswith(p))
        if "chain_origin" in e:  # relative to the anchor, like hands
            e["chain_origin"] = [[o[0] - a[0], o[1] - a[1]] for o, a in zip(e["chain_origin"], e["anchors"])]
    (BUILD / "chain_scythe_sprites_manifest.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8", newline="\n")

    report = check_feet(frames)
    if not args.no_previews:
        make_previews(frames, written)
    print(f"wrote {len(written)} sprite sources and art/build/chain_scythe_sprites_manifest.json")
    print(report)
    return 0


def check_feet(frames: dict[str, dict]) -> str:
    """Feet check, old (hero2 source) vs new: the body's bottom three rows must sit at the same place relative to the
    anchor, pixel for pixel wherever the weapon does not cover them; also reports the lowest weapon pixel."""
    lines, bad = [], 0
    for name, f in frames.items():
        body0, (ax, ay) = f["body0"], f["orig_anchor"]
        g, (nax, nay) = f["out"], f["anchor"]
        rows = [y for y in range(len(body0)) if any(c != T for c in body0[y])]
        diff = covered = 0
        for y in rows[-3:]:
            for x, c in enumerate(body0[y]):
                if c == T:
                    continue
                X, Y = x - ax + nax, y - ay + nay
                if get(g, X, Y) != c:
                    if f["grid"][Y + f["crop"][1]][X + f["crop"][0]] != f["body"][Y + f["crop"][1]][X + f["crop"][0]]:
                        covered += 1  # a weapon pixel drawn over the foot
                    else:
                        diff += 1
        low = max((y for y, row in enumerate(g) for c in row if c != T), default=0) - nay
        bad += diff > 0
        lines.append(f"  {name}: feet rows {'OK' if diff == 0 else f'{diff} px differ'}"
                     f"{f', {covered} px covered by the weapon' if covered else ''}; lowest pixel {low:+d} vs anchor row")
    return f"feet check ({len(frames)} hero frames, {bad} with differences):\n" + "\n".join(lines)


# ---------------------------------------------------------------------------------------------- previews
BG = (40, 40, 52)
GRASS = PAL.by_symbol["4"]


def to_image(g: Grid) -> Image.Image:
    return M.to_image(g)


def place_sheet(rows: list[tuple[str, list[tuple[str, Image.Image, tuple[int, int]]]]], zoom: int, bg: tuple,
                cw: int, ch: int, foot: tuple[int, int]) -> Image.Image:
    """Labelled rows of cells; every image is placed by its anchor at the cell's foot point."""
    lab = 12
    cols = max(len(r) for _, r in rows)
    out = Image.new("RGB", (cols * cw * zoom, sum(ch * zoom + 2 * lab for _ in rows)), bg)
    d = ImageDraw.Draw(out)
    y = 0
    for title, cells in rows:
        d.text((4, y), title, fill=(235, 235, 235))
        for i, (label, im, anchor) in enumerate(cells):
            X = i * cw * zoom
            big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
            ox, oy = X + (foot[0] - anchor[0]) * zoom, y + 2 * lab + (foot[1] - anchor[1]) * zoom
            out.paste(big, (ox, oy), big)
            d.text((X + 2, y + lab), label, fill=(200, 200, 200))
            d.line([(X, y + 2 * lab + ch * zoom - 1), (X + cw * zoom, y + 2 * lab + ch * zoom - 1)], fill=(70, 70, 86))
        y += ch * zoom + 2 * lab
    return out


def load_sprite(name: str) -> tuple[Grid, tuple[int, int]]:
    s = artlib.parse_sprite(SRC / f"{name}.txt")
    return [list(r) for r in s.rows], s.anchor


def make_previews(frames: dict[str, dict], written: dict) -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    rows = []
    for state, count in HERO_STATES:
        kat, scy = [], []
        for n in range(1, count + 1):
            g0, a0 = load_sprite(f"hero2_{state}_right_{n}")
            kat.append((f"hero2 {n}", to_image(g0), a0))
            g, a = written[f"{VID}_{state}_right_{n}"]
            scy.append((f"scythe {n}", to_image(g), a))
        rows.append((f"{state}: katana (hero2_{state}_right_N)", kat))
        rows.append((f"{state}: chain scythe ({VID}_{state}_right_N)", scy))
    coil_rows = []
    for phase, count in COIL_ORDER:
        kat, scy = [], []
        for n in range(1, count + 1):
            name = f"{VID}_coil_{phase}_{n}"
            src = frames[name]["source"]
            g0, a0 = load_sprite(src)
            kat.append((src.replace("hero2_", "").replace("_right_", " "), to_image(g0), a0))
            g, a = written[name]
            scy.append((f"{phase} {n}", to_image(g), a))
        coil_rows.append((f"coil {phase}: body source (katana) / Reaper's Coil frame", kat))
        coil_rows.append((f"coil {phase}: {VID}_coil_{phase}_N", scy))
    for tag, bg in (("dark", BG), ("grass", GRASS)):
        place_sheet(rows, 4, bg, 96, 72, (40, 60)).save(PREVIEWS / f"chain_scythe_import_hero_{tag}.png")
        place_sheet(coil_rows, 4, bg, 112, 72, (56, 60)).save(PREVIEWS / f"chain_scythe_import_coil_{tag}.png")
    # effects sheet (raw cells, centred) plus the arcs and the spin ring over the hero poses
    fx_names = [n for n in written if n.startswith(("fx_", "ui_"))]
    groups: dict[str, list] = {}
    for n in fx_names:
        groups.setdefault(n.rsplit("_", 1)[0] if not n.startswith("fx_scythe_arc") else "fx_scythe_arc", []).append(n)
    fx_rows = []
    for gname, names in groups.items():
        cells = []
        for n in names:
            g, a = written[n]
            cells.append((n.replace(gname + "_", "") if gname != "fx_scythe_arc" else n[len("fx_scythe_arc_"):], to_image(g), a))
        fx_rows.append((gname, cells))
    comp = []
    for s in (1, 2, 3):
        for n in range(1, 7):
            g, a = written[f"{VID}_attack{s}_right_{n}"]
            cell = blank(112, 72)
            paste(cell, g, 40 - a[0], 60 - a[1])
            if 3 <= n <= 6:
                paste(cell, written[f"fx_scythe_arc_{s}_{n - 2}"][0], 40 - C.ARC_ANCHOR[0], 60 - C.ARC_ANCHOR[1])
            comp.append((f"swing {s} f{n}", to_image(cell), (40, 60)))
    spin = []
    for k in range(1, SPIN_N + 1):
        g, a = written[f"{VID}_coil_spin_{k}"]
        cell = blank(112, 72)
        ph = 2
        paste(cell, written[f"fx_scythe_spin_back_{ph}"][0], 56 - C.SPIN_ANCHOR[0], 60 - C.SPIN_ANCHOR[1])
        paste(cell, g, 56 - a[0], 60 - a[1])
        paste(cell, written[f"fx_scythe_spin_front_{ph}"][0], 56 - C.SPIN_ANCHOR[0], 60 - C.SPIN_ANCHOR[1])
        spin.append((f"spin {k} + ring", to_image(cell), (56, 60)))
    for tag, bg in (("dark", BG), ("grass", GRASS)):
        place_sheet(fx_rows, 3, bg, 136, 72, (68, 60)).save(PREVIEWS / f"chain_scythe_import_fx_{tag}.png")
    place_sheet([("swings 1-3 with their arcs (arc phase n-2 on frames 3-6)", comp[:6]), ("", comp[6:12]), ("", comp[12:]),
                 ("coil spin 1-8 with the rx 36 ring (phase 2)", spin)], 4, GRASS, 112, 72, (56, 60)).save(PREVIEWS / "chain_scythe_import_arcs_grass.png")
    make_gif(frames, written)


SW, SH = 240, 120


def make_gif(frames: dict, written: dict) -> None:
    """The combo (swings 1-3 with arcs) and Reaper's Coil (windup, whip with the runtime chain, hook, drag, stagger,
    spin, recover) on grass at 4x. Timings and distances are illustrative only."""
    rng = random.Random(4)
    bgim = Image.new("RGBA", (SW, SH), GRASS + (255,))
    dr = ImageDraw.Draw(bgim)
    for _ in range(170):
        dr.point((rng.randrange(SW), rng.randrange(SH)), fill=PAL.by_symbol[rng.choice("35")] + (255,))
    golem_idle, ga = load_sprite("golem2_idle_1")
    golem_hurt, gh = load_sprite("golem2_hurt_1")
    hero_f = (70, 96)
    out: list[tuple[Image.Image, int]] = []

    def frame(layers: list[tuple[Grid, int, int]], ms: int) -> None:
        sg = blank(SW, SH)
        for g, x, y in layers:
            paste(sg, g, C.rnd(x), C.rnd(y))
        im = bgim.copy()
        im.alpha_composite(to_image(sg))
        out.append((im, ms))

    def hero(name: str, at: tuple[int, int] = hero_f) -> tuple[Grid, int, int]:
        g, a = written[name]
        return g, at[0] - a[0], at[1] - a[1]

    def fx(name: str, at: tuple[float, float]) -> tuple[Grid, int, int]:
        g, a = written[name]
        return g, C.rnd(at[0]) - a[0], C.rnd(at[1]) - a[1]

    def golem(x: float, hurt: bool = False, flash: bool = False) -> tuple[Grid, int, int]:
        g, a = (golem_hurt, gh) if hurt else (golem_idle, ga)
        return (C.golem_flash(g) if flash else g), C.rnd(x) - a[0], hero_f[1] - a[1]

    gx = hero_f[0] + 22 + C.GOLEM_LEFT["idle"]
    tick = 1000 // 60
    # combo: each frame held for its share of the swing (windup 2, active 2, recovery 2), about 60 ticks per swing
    for _ in range(3):
        frame([golem(gx), hero(f"{VID}_idle_right_1")], 120)
    for s in (1, 2, 3):
        for n in range(1, 7):
            layers = [golem(gx, hurt=n >= 4, flash=n == 4), hero(f"{VID}_attack{s}_right_{n}")]
            if n >= 3:
                layers.append(fx(f"fx_scythe_arc_{s}_{n - 2}", hero_f))
            if n == 4:
                layers.append(fx("fx_chain_stagger_2", (gx - C.GOLEM_LEFT["idle"] + 5, hero_f[1] - (14, 30, 10)[s - 1])))
            frame(layers, (5, 5, 3, 4, 6, 7)[n - 1] * tick)
    for n in range(1, 5):
        frame([golem(gx), hero(f"{VID}_idle_right_{n}")], 110)
    # Reaper's Coil
    gx0 = hero_f[0] + 96
    for n in (1, 2):
        frame([golem(gx0), hero(f"{VID}_coil_windup_{n}")], 110)

    def origin(name: str) -> tuple[float, float]:
        o = frames[name]["origin_rel"]
        return hero_f[0] + o[0], hero_f[1] + o[1]

    hook = (gx0 - C.GOLEM_LEFT["idle"] + 7, hero_f[1] - 26)
    for k, (n, frac) in enumerate(((1, 0.25), (2, 0.55), (3, 0.85), (3, 1.0))):
        name = f"{VID}_coil_whip_{n}"
        o = origin(name)
        tip = (o[0] + (hook[0] - o[0]) * frac, o[1] + (hook[1] - o[1]) * frac - 5 * math.sin(math.pi * frac))
        g = blank(SW, SH)
        C.chain_between(g, o, tip, 3.0 * (1 - frac) + 0.5, k)
        layers = [golem(gx0, hurt=frac >= 1, flash=frac >= 1), hero(name), (g, 0, 0)]
        layers.append(fx(f"fx_scythe_flying_{(2 * k + 3) % 8 + 1}", tip) if frac < 1 else fx("fx_chain_hook_2", hook))
        frame(layers, 50 if frac < 1 else 70)
    gx1 = hero_f[0] + 13 + C.GOLEM_LEFT["hurt"]
    for k in range(9):
        f = k / 8
        e = f * f * (3 - 2 * f)
        x = gx0 + (gx1 - gx0) * e
        name = f"{VID}_coil_pull_{k % 3 + 1}"
        o = origin(name)
        end = (C.rnd(x) - C.GOLEM_LEFT["hurt"] + 1, hero_f[1] - 22)
        g = blank(SW, SH)
        C.chain_between(g, o, end, 0, k, spectral=True)
        frame([fx(f"fx_chain_scuff_{min(4, 1 + k // 3)}", (x + 8, hero_f[1])), fx(f"fx_chain_dust_{min(4, 1 + k // 3)}", (x + 2, hero_f[1])),
               golem(x, hurt=True), fx(f"fx_chain_pull_{min(4, 1 + k // 3)}", (x, hero_f[1])), hero(name), (g, 0, 0)], 50)
    for k in range(1, 7):
        frame([golem(gx1, hurt=True, flash=k == 1), hero(f"{VID}_coil_recover_{1 if k < 3 else 2}"),
               fx(f"fx_chain_stagger_{k}", (gx1 - C.GOLEM_LEFT["hurt"] + 6, hero_f[1] - 26))], 55)
    # the automatic spin: two turns with the ring
    for k in range(2 * SPIN_N):
        ph = 1 if k == 0 else (2 if k < 2 * SPIN_N - 2 else 3)
        n = k % SPIN_N + 1
        hit = n == 1 and k > 0
        frame([golem(gx1, hurt=True, flash=hit), fx(f"fx_chain_stars_{k % 4 + 1}", (gx1 - 2, hero_f[1] - 50)),
               fx(f"fx_scythe_spin_back_{ph}", hero_f), hero(f"{VID}_coil_spin_{n}"), fx(f"fx_scythe_spin_front_{ph}", hero_f)], 45)
    for n in (1, 2):
        frame([golem(gx1, hurt=True), hero(f"{VID}_coil_recover_{n}")], 90)
    # a miss (no target): the hook lands on the ground
    for k in range(1, 5):
        frame([hero(f"{VID}_idle_right_1"), fx(f"fx_chain_land_{k}", (hero_f[0] + 60, hero_f[1] + 4))], 70)
    Z = 4
    big = [im.convert("RGB").resize((SW * Z, SH * Z), Image.NEAREST) for im, _ in out]
    big[0].save(PREVIEWS / "chain_scythe_import_sequence.gif", save_all=True, append_images=big[1:],
                duration=[max(20, ms // 10 * 10) for _, ms in out], loop=0, disposal=1)
    cols = 8
    strip = Image.new("RGB", (cols * SW * 2, ((len(out) + cols - 1) // cols) * SH * 2), BG)
    for i, (im, _) in enumerate(out):
        strip.paste(im.convert("RGB").resize((SW * 2, SH * 2), Image.NEAREST), ((i % cols) * SW * 2, (i // cols) * SH * 2))
    strip.save(PREVIEWS / "chain_scythe_import_sequence_strip.png")


if __name__ == "__main__":
    sys.exit(main())
