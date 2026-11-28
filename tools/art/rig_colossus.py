"""The Mossbound Colossus's body poses (build step 4 of docs/FINAL_SCENE_chapter1.md; owner 2026-11-28: "OKAY LETS START", the rig
of the approved concept, "ALSO WE NEED AN ANIMATION WHEN HE IS APPEARING").

Source: the approved concept (art/reference/rootcrown_v1/colossus_concept_1.png), the same cut-out as the stand-in. It is split
into parts by fixed polygons (two arms, the head, two root legs, the body with its moss mantle) and every pose moves those parts at
the concept's own size (body offset, rotations about the shoulders, the head's nod, the root legs' steps, how deep it is sunk in
the ground), then shrinks the whole frame to the stand-in's size (116 px tall, the owner's choice B) and snaps it to Totoy 36
without gold and red, with hard alpha. Shrinking after posing keeps one pixel size and no rotation jaggies. The song in its chest
and cracks has four states (dark asleep, dim, lit, bright) by swapping the song's colours along their ramp. While it is sunk the
ground line gets a rim of broken earth, so it rises OUT of the ground instead of being cut off.

    python tools/art/rig_colossus.py --preview   # the 4a poses as PNGs in art/reference/colossus_body_v1/ (for the owner's review)
    python tools/art/rig_colossus.py --frames    # every frame (4b) as PNGs in art/reference/colossus_body_v1/frames/
    python tools/art/rig_colossus.py --install   # every frame into art/src (colossus_<set>_right_<n>.txt, generated: never hand-edit)
                                                 # and presentation/explore/colossus_frames.json; then validate, build, preview

Deterministic: the same source gives the same frames.
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
CONCEPT = ROOT / "art" / "reference" / "rootcrown_v1" / "colossus_concept_1.png"
CROP = (440, 10, 1345, 745)  # the golem's part of the concept (as the stand-in)
OUT = ROOT / "art" / "reference" / "colossus_body_v1"
HEIGHT = 116  # visible height at rest (the stand-in's, the owner's choice B)
FEET_ABOVE_BOTTOM = 2  # the fists and roots reach 2 px below the ground point (as the stand-in)

# Parts, in the cut-out's pixels (878x725). Pixels go to the first part whose polygon holds them; the rest is the body.
ARM_L = [(148, 250), (292, 252), (296, 330), (262, 362), (242, 420), (230, 560), (214, 600), (212, 760), (-40, 760), (-40, 552),
         (0, 420), (60, 330), (140, 236)]  # generous outside the silhouette: no sliver of the arm is left on the body
ARM_R = [(645, 252), (770, 226), (830, 300), (900, 360), (920, 430), (920, 760), (700, 760), (690, 560), (682, 470),
         (668, 404), (642, 334)]
HEAD = [(304, 116), (450, 116), (450, 280), (304, 280)]  # the stone face; the moss over it stays on the body
ROOTS_L = [(180, 466), (452, 466), (452, 725), (180, 725)]
ROOTS_R = [(452, 466), (720, 466), (720, 725), (452, 725)]
PIVOTS = {"arm_l": (225, 300), "arm_r": (705, 295), "head": (376, 282)}
SHOULDER = 45  # the body keeps the arm's pixels this close to the shoulder: a raised arm leaves its shoulder in place
NECK = (47, 50, 49)  # the shadow under the head where it was cut out (stone_1); above it the moss is mirrored down
HOLE_MOSS = 0.7  # the top part of the head's hole is moss (mirrored from above), the rest shadow
HOLE_KEEP = 300  # thin enclosed dark lines under 2x this many px (the mouth, the fists' cracks) are kept, not cut out
MARGIN = 420  # working space round the cut-out for raised arms
ROOT_REACH = 40  # the roots' top band is repeated this far up, hidden under the belly until the body lifts

# The song's colours (Totoy 36 symbols) in each light state; "lit" is the concept's own.
LIGHT = {
    "bright": {"o": "p", "n": "o", "u": "o", "t": "u", "m": "n"},
    "dim": {"p": "o", "o": "u", "n": "t", "u": "t", "m": "t", "l": "k"},
    "dark": {"p": "h", "o": "g", "n": "f", "u": "f", "t": "e", "m": "f", "l": "e", "k": "e"},
}
DIRT = ["8", "d", "c", "9", "8"]  # the rim of broken earth from its top down: dark edge, a lit crest (reads on the dirt floor), then the dark
# torn earth at the ground (the bottom row is always the last)
PEBBLES = ["e", "f"]  # dark clods on the crest, sparse


def F(**kw: object) -> dict:
    """One pose. Offsets are in final pixels; angles in degrees, positive = clockwise on screen (the left arm up and out, the
    right arm in and down). body moves everything above the roots (the arms too, plus their own arm_*_off); sink lowers the whole
    golem into the ground; clip drops what is below the ground; crumble (0..1) breaks it into a heap of rubble (the death).
    arm_*_len shortens an arm along its own length (a fist swinging toward the viewer). smear: ghosts of the right arm along its path
    ((angle, length, (dx, dy)), oldest first), drawn as a pale dither outside the body (the classic pixel-art motion smear)."""
    return {"body": kw.get("body", (0, 0)), "arm_l": kw.get("arm_l", 0.0), "arm_r": kw.get("arm_r", 0.0),
            "arm_l_off": kw.get("arm_l_off", (0, 0)), "arm_r_off": kw.get("arm_r_off", (0, 0)),
            "arm_l_len": kw.get("arm_l_len", 1.0), "arm_r_len": kw.get("arm_r_len", 1.0), "smear": kw.get("smear", ()),
            "head": kw.get("head", (0, 0)), "nod": kw.get("nod", 0.0), "roots_l": kw.get("roots_l", (0, 0)),
            "roots_r": kw.get("roots_r", (0, 0)), "light": kw.get("light", "lit"), "sink": kw.get("sink", 0),
            "clip": kw.get("clip", False), "crumble": kw.get("crumble", 0.0), "stumps": kw.get("stumps", True),
            "front": kw.get("front", ()), "note": kw.get("note", "")}


# The poses of the first review (step 4a): the key poses and the appearing. Names follow <state>_<n> of the later frame set.
POSES: dict[str, dict] = {
    "idle_1": F(note="idle: breathing"),
    "idle_2": F(body=(0, 1), arm_l=-1.0, arm_r=1.0, head=(0, 1), note="idle: breathing"),
    "slam_windup": F(body=(0, -3), arm_l=150.0, arm_r=-150.0, head=(0, -2), light="bright", note="Gold Slam: both fists overhead"),
    "slam_strike": F(body=(0, 5), arm_l=-22.0, arm_r=22.0, head=(0, 4), front=("arm_l", "arm_r"), note="Gold Slam: fists down in front"),
    "posture_broken": F(body=(0, 7), arm_l=-6.0, arm_r=6.0, head=(0, 6), nod=8.0, light="dim", note="posture broken: slumped, song dim"),
    "roar": F(body=(0, -2), arm_l=115.0, arm_r=-115.0, head=(0, -3), light="bright", note="roar: arms up and wide, song blazing"),
    # The appearing (alert): asleep as a mossy mound, the song wakes, a fist bursts out, then the other, it plants both and
    # pulls itself out of the ground, stands, and roars.
    "appear_1": F(sink=68, arm_l=-18.0, arm_r=18.0, head=(0, 6), light="dark", note="asleep: a mossy mound"),
    "appear_2": F(sink=66, arm_l=-18.0, arm_r=18.0, head=(0, 6), light="dim", note="the song wakes in the moss"),
    "appear_3": F(sink=56, arm_l=128.0, arm_r=18.0, head=(0, 5), light="dim", note="a fist bursts out"),
    "appear_4": F(sink=50, arm_l=80.0, arm_r=-128.0, head=(0, 5), light="lit", note="then the other"),
    "appear_5": F(sink=42, arm_l=34.0, arm_r=-34.0, head=(0, 4), light="lit", note="it plants both fists"),
    "appear_6": F(sink=30, arm_l=22.0, arm_r=-22.0, head=(0, 4), light="lit", note="and pulls itself up"),
    "appear_7": F(sink=18, arm_l=12.0, arm_r=-12.0, head=(0, 3), light="lit", note="roots tear free"),
    "appear_8": F(sink=7, arm_l=5.0, arm_r=-5.0, head=(0, 2), light="lit", note="almost out"),
    "appear_9": F(sink=0, light="lit", note="standing"),
    "appear_10": F(body=(0, -2), arm_l=115.0, arm_r=-115.0, head=(0, -3), light="bright", note="it roars"),
}


# ---- the whole frame set (step 4b) -------------------------------------------------------------------------------------------
# Frames are named colossus_<set>_right_<n> (the mob convention; it faces the viewer and is never mirrored). Attacks that move
# alike share a set: the Gold Combo plays the slam, the Song Flare the shards (its rings) and the roar (its gold blow), the Briar
# Ring rises during the roar, Boulder Toss and Root Snare recover as the slam does. Presentation picks frames from the snapshot only.
FRONT = ("arm_l", "arm_r")
SETS: dict[str, list[dict]] = {
    "sleep": [F(sink=68, arm_l=-18.0, arm_r=18.0, head=(0, 6), light="dark", note="asleep: a mossy mound"),
              F(sink=67, arm_l=-18.0, arm_r=18.0, head=(0, 6), light="dark", note="asleep: breathing")],
    "idle": [F(note="idle"), F(body=(0, 1), head=(0, 1), note="idle: breath in"),
             F(body=(0, 1), arm_l=-1.5, arm_r=1.5, head=(0, 1), note="idle"), F(arm_l=-0.5, arm_r=0.5, note="idle: breath out")],
    "walk": [F(body=(-1, -1), arm_l=8.0, arm_l_off=(0, -3), roots_r=(0, -2), note="walk: left fist lifts"),
             F(body=(-1, 0), arm_l=4.0, arm_l_off=(0, -1), roots_r=(0, -1), note="walk"),
             F(body=(0, 1), note="walk: plant"),
             F(body=(1, -1), arm_r=-8.0, arm_r_off=(0, -3), roots_l=(0, -2), note="walk: right fist lifts"),
             F(body=(1, 0), arm_r=-4.0, arm_r_off=(0, -1), roots_l=(0, -1), note="walk"),
             F(body=(0, 1), note="walk: plant")],
    "slam_windup": [F(body=(0, -1), arm_l=45.0, arm_r=-45.0, note="Gold Slam / Combo windup"),
                    F(body=(0, -2), arm_l=100.0, arm_r=-100.0, head=(0, -1), note="windup"),
                    F(body=(0, -3), arm_l=150.0, arm_r=-150.0, head=(0, -2), light="bright", note="windup: fists overhead")],
    "slam_strike": [F(body=(0, 1), arm_l=70.0, arm_r=-70.0, light="bright", note="the blow falls"),
                    F(body=(0, 5), arm_l=-22.0, arm_r=22.0, head=(0, 4), front=FRONT, note="the blow: fists down in front")],
    "slam_recover": [F(body=(0, 3), arm_l=-10.0, arm_r=10.0, head=(0, 2), front=FRONT, note="recover (Slam, Combo, Snare, Boulder)")],
    # the Sweep (reworked 2026-11-28, the owner's "Yes, rework it"): the right arm drawn back at chest height, then swung across the
    # chest to the far left (shortened as the fist passes in front of it), the body twisting with it, a smear on the fast frames
    "sweep_windup": [F(body=(2, -1), arm_l=5.0, arm_r=-80.0, head=(1, 0), note="Sweep windup: the right arm swings out"),
                     F(body=(3, -2), arm_l=10.0, arm_r=-108.0, head=(2, -1), light="bright", note="windup: drawn back, ready")],
    "sweep_strike": [F(body=(2, -1), arm_l=8.0, arm_r=-70.0, arm_r_len=0.9, head=(1, 0), light="bright", front=("arm_r",),
                       smear=((-108.0, 1.0, (0, 0)), (-90.0, 1.0, (0, 0))), note="the swing starts"),
                     F(body=(0, 0), arm_r=58.0, arm_r_len=0.5, arm_r_off=(-8, 0), front=("arm_r",),
                       smear=((-70.0, 0.9, (0, 0)), (-30.0, 0.75, (-3, 2)), (12.0, 0.6, (-6, 2))), note="the fist passes in front"),
                     F(body=(-3, 1), arm_l=-6.0, arm_r=98.0, arm_r_off=(-8, 8), head=(-2, 1), front=("arm_r",),
                       smear=((58.0, 0.5, (-8, 0)), (80.0, 0.75, (-8, 4))), note="across to the far left"),
                     F(body=(-4, 2), arm_l=-8.0, arm_r=104.0, arm_r_off=(-9, 11), head=(-3, 1), front=("arm_r",), note="follow-through")],
    "sweep_recover": [F(body=(-2, 1), arm_r=60.0, arm_r_off=(-4, -4), front=("arm_r",), note="recover: the arm comes back"),
                      F(body=(-1, 0), arm_r=18.0, front=("arm_r",), note="recover")],
    "shards_windup": [F(body=(0, -1), arm_l=30.0, arm_r=-30.0, head=(0, -1), light="bright", note="Shards / Song Flare windup: the chest opens"),
                      F(body=(0, -3), arm_l=55.0, arm_r=-55.0, head=(0, -3), light="bright", note="windup")],
    "shards_strike": [F(body=(0, -1), arm_l=80.0, arm_r=-80.0, head=(0, -2), light="bright", note="the song bursts out")],
    "shards_recover": [F(arm_l=20.0, arm_r=-20.0, note="recover")],
    "stomp_windup": [F(body=(0, -3), arm_l=25.0, arm_r=-25.0, head=(0, -2), roots_r=(0, -4), note="Stomp windup: it rears up"),
                     F(body=(0, -6), arm_l=40.0, arm_r=-40.0, head=(0, -3), roots_r=(0, -8), light="bright", note="windup")],
    "stomp_strike": [F(body=(0, 4), arm_l=15.0, arm_r=-15.0, head=(0, 3), note="the stomp")],
    "stomp_recover": [F(body=(0, 2), head=(0, 1), note="recover")],
    "charge_windup": [F(body=(0, 3), arm_l=25.0, arm_r=-25.0, head=(0, 3), note="Charge windup: it crouches"),
                      F(body=(0, 5), arm_l=40.0, arm_r=-40.0, head=(0, 5), light="bright", note="windup")],
    "charge_run": [F(body=(0, 3), arm_l=-15.0, arm_r=15.0, head=(0, 4), roots_l=(0, -2), front=FRONT, note="the charge"),
                   F(body=(0, 2), arm_l=-10.0, arm_r=10.0, head=(0, 3), roots_r=(0, -2), front=FRONT, note="the charge")],
    "charge_recover": [F(body=(0, 2), arm_l=-5.0, arm_r=5.0, head=(0, 1), note="recover")],
    "snare_windup": [F(body=(-2, -2), arm_l=110.0, head=(-1, -1), light="bright", note="Root Snare windup: a fist rises"),
                     F(body=(1, -1), arm_l=-25.0, arm_r=-110.0, head=(1, 0), light="bright", front=("arm_l",), note="the second lane: the other fist")],
    "snare_strike": [F(body=(-2, 4), arm_l=-25.0, head=(-1, 3), front=("arm_l",), note="the fist drives into the ground"),
                     F(body=(0, 5), arm_l=-25.0, arm_r=25.0, head=(0, 4), front=FRONT, note="and the other")],
    "boulder_windup": [F(body=(0, 6), arm_l=-30.0, arm_r=30.0, head=(0, 5), front=FRONT, note="Boulder Toss: it tears up a stone"),
                       F(body=(0, -3), arm_l=165.0, arm_r=-165.0, head=(0, -2), light="bright", note="lifts it overhead")],
    "boulder_strike": [F(body=(0, 2), arm_l=60.0, arm_r=-60.0, head=(0, 1), note="and throws")],
    "grab_windup": [F(body=(2, -1), arm_r=-60.0, head=(1, -1), light="bright", note="Heartroot Grab windup"),
                    F(body=(3, -2), arm_l=15.0, arm_r=-100.0, head=(2, -2), light="bright", note="windup")],
    "grab_strike": [F(body=(-2, 2), arm_r=30.0, head=(-1, 1), front=("arm_r",), note="it lunges")],
    "grab_recover": [F(body=(0, 1), arm_r=10.0, front=("arm_r",), note="recover")],
    "broken": [F(body=(0, 7), arm_l=-6.0, arm_r=6.0, head=(0, 6), nod=8.0, light="dim", note="posture broken"),
               F(body=(0, 7), arm_l=-6.0, arm_r=6.0, head=(0, 7), nod=8.0, light="dark", note="posture broken: the song flickers")],
    "stagger": [F(body=(-1, 3), arm_l=-4.0, arm_r=4.0, head=(0, 2), note="stagger (Reaper’s Coil)"),
                F(body=(1, 3), arm_l=-6.0, arm_r=6.0, head=(0, 3), note="stagger")],
    "roar": [F(body=(0, -2), arm_l=115.0, arm_r=-115.0, head=(0, -3), light="bright", note="roar (and the Song Flare gold blow)"),
             F(body=(0, -3), arm_l=125.0, arm_r=-125.0, head=(0, -4), light="bright", note="roar")],
    "death": [F(body=(0, -2), arm_l=60.0, arm_r=-60.0, head=(0, -3), light="bright", note="death: the last blow, the song flares"),
              F(body=(0, 3), arm_l=20.0, arm_r=-20.0, head=(0, 3), nod=-6.0, light="dim", note="it sags"),
              F(body=(0, 6), arm_l=-10.0, arm_l_off=(-6, 8), arm_r=25.0, arm_r_off=(5, 10), head=(-2, 6), nod=12.0, light="dark",
                clip=True, note="the arms break off"),
              F(body=(0, 14), arm_l=70.0, arm_l_off=(-4, 44), arm_r=-70.0, arm_r_off=(4, 44), head=(-4, 18), nod=30.0, light="dark",
                crumble=0.15, note="the arms fall, the head topples", stumps=False),
              F(body=(0, 30), arm_l=70.0, arm_l_off=(-4, 44), arm_r=-70.0, arm_r_off=(4, 44), head=(-10, 32), nod=50.0, light="dark",
                crumble=0.35, note="it breaks apart", stumps=False),
              F(body=(0, 44), arm_l=70.0, arm_l_off=(-4, 46), arm_r=-70.0, arm_r_off=(4, 46), head=(-12, 44), nod=70.0, light="dark",
                crumble=0.55, note="sinking into stone and moss", stumps=False),
              F(body=(0, 56), arm_l=70.0, arm_l_off=(-4, 48), arm_r=-70.0, arm_r_off=(4, 48), head=(-12, 54), nod=80.0, light="dark",
                crumble=0.8, note="rubble", stumps=False),
              F(body=(0, 60), arm_l=70.0, arm_l_off=(-4, 48), arm_r=-70.0, arm_r_off=(4, 48), head=(-12, 58), nod=80.0, light="dark",
                crumble=1.0, note="a heap of rubble", stumps=False)],
}
# The appearing (state alert, COLOSSUS_WAKE_TICKS proposed 150): key poses at ticks, two in-betweens between each pair.
APPEAR_KEYS = [(0, "appear_2"), (14, "appear_2"), (24, "appear_3"), (38, "appear_3"), (48, "appear_4"), (60, "appear_4"),
               (72, "appear_5"), (88, "appear_6"), (102, "appear_7"), (114, "appear_8"), (124, "appear_9"), (134, "appear_10"),
               (150, "appear_10")]


def lerp(a: dict, b: dict, f: float) -> dict:
    """A pose between two: numbers and number pairs mixed, the rest (light, front, notes) from the nearer one."""
    def mix(x: object, y: object) -> object:
        if isinstance(x, tuple) and all(isinstance(v, (int, float)) for v in x + tuple(y)):
            return tuple(round(xi + (yi - xi) * f) for xi, yi in zip(x, y))
        if isinstance(x, bool):
            return x if f < 0.5 else y
        if isinstance(x, (int, float)):
            return x + (y - x) * f if isinstance(x, float) or isinstance(y, float) else round(x + (y - x) * f)
        return x if f < 0.5 else y
    return {k: mix(a[k], b[k]) for k in a}


def appear_timeline() -> list[tuple[int, dict]]:
    """The appearing as (first tick, pose): each key, and two in-betweens on the way to the next (a held key gets none)."""
    out: list[tuple[int, dict]] = []
    for (t0, a), (t1, b) in zip(APPEAR_KEYS, APPEAR_KEYS[1:]):
        if not out or out[-1][1] is not POSES[a]:
            out.append((t0, POSES[a]))
        if a == b:
            continue
        for k in (1, 2):
            pose = lerp(POSES[a], POSES[b], k / 3.0)
            pose["note"] = POSES[b]["note"] + " (in-between)"
            out.append((t0 + round((t1 - t0) * (k / 3.0 - 1 / 6.0)), pose))
    last = APPEAR_KEYS[-1][1]
    if out[-1][1] is not POSES[last]:
        out.append((APPEAR_KEYS[-2][0], POSES[last]))
    return out


def frame_set() -> dict[str, dict]:
    """Every frame of step 4b by name, in order."""
    out: dict[str, dict] = {}
    for name, poses in SETS.items():
        for i, pose in enumerate(poses):
            out[f"colossus_{name}_right_{i + 1}"] = pose
    for i, (_, pose) in enumerate(appear_timeline()):
        out[f"colossus_appear_right_{i + 1}"] = pose
    return out


# Points the effects and lights hang on, in the cut-out's pixels, and the part that carries each.
ATTACH = {"fist_l": ("arm_l", (105, 628)), "fist_r": ("arm_r", (789, 632)), "chest": ("body", (432, 356))}


def attachments(layers: dict[str, Image.Image], pose: dict) -> dict[str, list[int]]:
    """Where the fists and the chest are in a posed frame, in final pixels from its feet (for 4c: the held stone, the song's light)."""
    w, h = layers["body"].size
    scale = scale_of(layers["body"])
    per = 1.0 / scale
    feet = (w // 2, h - round(FEET_ABOVE_BOTTOM / scale))
    out = {}
    for key, (part, (x, y)) in ATTACH.items():
        dx, dy = pose["body"]
        if part in ("arm_l", "arm_r"):
            px, py = PIVOTS[part]
            ux, uy = _axis(part)
            along = (x - px) * ux + (y - py) * uy
            x, y = x + (float(pose[part + "_len"]) - 1.0) * along * ux, y + (float(pose[part + "_len"]) - 1.0) * along * uy
            a = math.radians(float(pose[part]))
            x, y = px + (x - px) * math.cos(a) - (y - py) * math.sin(a), py + (x - px) * math.sin(a) + (y - py) * math.cos(a)
            dx, dy = dx + pose[part + "_off"][0], dy + pose[part + "_off"][1]
        out[key] = [round((x + dx * per - feet[0]) * scale), round((y + dy * per - feet[1]) * scale) + int(pose["sink"])]
    return out


# ---- the source ------------------------------------------------------------------------------------------------------------

def cut_golem() -> Image.Image:
    """The golem of the concept without its flat background: a flood fill from the border, then the large enclosed gaps (between
    the roots, under the arms). Small enclosed dark lines (the mouth, cracks in the fists) stay: the stand-in lost them."""
    image = Image.open(CONCEPT).convert("RGB").crop(CROP)
    width, height = image.size
    pixels = image.load()
    back = pixels[3, 3]

    def near(p: tuple[int, int, int], tolerance: int) -> bool:
        return max(abs(p[i] - back[i]) for i in range(3)) <= tolerance

    outside = bytearray(width * height)

    def flood(seeds: list[tuple[int, int]], tolerance: int) -> list[tuple[int, int]]:
        queue = deque(seeds)
        found: list[tuple[int, int]] = []
        seen = set(seeds)
        while queue:
            x, y = queue.popleft()
            if not near(pixels[x, y], tolerance):
                continue
            found.append((x, y))
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen and not outside[ny * width + nx]:
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        return found

    border = [(x, y) for x in range(width) for y in (0, height - 1)] + [(x, y) for y in range(height) for x in (0, width - 1)]
    for x, y in flood(border, 10):
        outside[y * width + x] = 1
    done: set[tuple[int, int]] = set()
    for y in range(0, height, 2):
        for x in range(0, width, 2):
            if outside[y * width + x] or (x, y) in done or not near(pixels[x, y], 5):
                continue
            region = flood([(x, y)], 7)
            done.update(region)
            if len(region) > 150 and not _is_line(region):
                for gx, gy in region:
                    outside[gy * width + gx] = 1
    alpha = Image.frombytes("L", image.size, bytes(0 if o else 255 for o in outside))
    cut = image.convert("RGBA")
    cut.putalpha(alpha)
    return cut.crop(alpha.getbbox())


def _is_line(region: list[tuple[int, int]]) -> bool:
    """A thin dark line (the mouth, a crack) rather than a gap: thin (22 px at most one way), short, under 2 x HOLE_KEEP px."""
    xs = [p[0] for p in region]
    ys = [p[1] for p in region]
    return len(region) < HOLE_KEEP * 2 and min(max(xs) - min(xs), max(ys) - min(ys)) <= 22 and max(ys) - min(ys) < 60


def split(cut: Image.Image) -> dict[str, Image.Image]:
    """The parts as full-size layers (same size as the cut-out, transparent elsewhere)."""
    masks: dict[str, Image.Image] = {}
    taken = Image.new("L", cut.size, 0)
    for name, polygon in (("arm_l", ARM_L), ("arm_r", ARM_R), ("head", HEAD), ("roots_l", ROOTS_L), ("roots_r", ROOTS_R)):
        mask = Image.new("L", cut.size, 0)
        ImageDraw.Draw(mask).polygon(polygon, fill=255)
        mask = Image.composite(Image.new("L", cut.size, 0), mask, taken)  # not already taken
        masks[name] = mask
        taken = Image.composite(Image.new("L", cut.size, 255), taken, mask)
    body_mask = Image.eval(taken, lambda v: 255 - v)
    shoulders_mask = Image.new("L", cut.size, 0)
    for arm in ("arm_l", "arm_r"):  # the shoulders stay with the body (their own layer: a death frame drops them with the arms)
        px, py = PIVOTS[arm]
        disc = Image.new("L", cut.size, 0)
        ImageDraw.Draw(disc).ellipse((px - SHOULDER, py - SHOULDER, px + SHOULDER, py + SHOULDER), fill=255)
        shoulders_mask = Image.composite(Image.new("L", cut.size, 255), shoulders_mask, Image.composite(disc, Image.new("L", cut.size, 0), masks[arm]))
    layers: dict[str, Image.Image] = {}
    alpha = cut.getchannel("A")
    for name, mask in list(masks.items()) + [("body", body_mask), ("shoulders", shoulders_mask)]:
        layer = cut.copy()
        layer.putalpha(Image.composite(alpha, Image.new("L", cut.size, 0), mask))
        layers[name] = layer
    _fill_head_hole(layers["body"], masks["head"], alpha)
    for roots in ("roots_l", "roots_r"):  # the roots reach up under the belly, so a lifted body shows roots and not a seam
        layer = layers[roots]
        top = layer.getbbox()[1]
        band = layer.crop((0, top, layer.width, top + ROOT_REACH))
        grown = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        grown.paste(band, (0, top - ROOT_REACH))
        grown.alpha_composite(layer)
        layers[roots] = grown
    return layers


def _fill_head_hole(body: Image.Image, head: Image.Image, alpha: Image.Image) -> None:
    """Behind the head, so a nod shows no hole: the moss above mirrored down over the top HOLE_MOSS, shadow below."""
    x0, y0, x1, y1 = head.getbbox()
    px = body.load()
    hm = head.load()
    al = alpha.load()
    split_y = y0 + round((y1 - y0) * HOLE_MOSS)
    for x in range(x0, x1):
        for y in range(y0, y1):
            if not hm[x, y] or not al[x, y]:
                continue
            src = y0 - 1 - (y - y0) % 40
            if y < split_y and src >= 0 and px[x, src][3]:
                px[x, y] = px[x, src]
            else:
                px[x, y] = (*NECK, 255)


# ---- posing ----------------------------------------------------------------------------------------------------------------

def scale_of(cut: Image.Image) -> float:
    return HEIGHT / cut.height


def compose(layers: dict[str, Image.Image], pose: dict, scale: float, only: str = "") -> Image.Image:
    """The pose at the concept's size on a canvas with MARGIN round the cut-out (the feet stay where they were). `only`: just that
    part (a smear's ghost arm)."""
    w, h = layers["body"].size
    canvas = Image.new("RGBA", (w + 2 * MARGIN, h + 2 * MARGIN), (0, 0, 0, 0))
    per = 1.0 / scale  # concept pixels per final pixel
    body = pose["body"]
    order = ["roots_l", "roots_r"]
    order += [a for a in ("arm_l", "arm_r") if a not in pose["front"]]
    order += (["shoulders"] if pose["stumps"] else []) + ["body", "head"]
    order += [a for a in ("arm_l", "arm_r") if a in pose["front"]]
    if only:
        order = [only]
    for name in order:
        layer = layers[name]
        big = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        big.paste(layer, (MARGIN, MARGIN))
        offset = (float(body[0]), float(body[1]))
        angle = 0.0
        pivot = None
        if name in ("arm_l", "arm_r"):
            angle = float(pose[name])
            pivot = PIVOTS[name]
            offset = (offset[0] + pose[name + "_off"][0], offset[1] + pose[name + "_off"][1])
        elif name == "head":
            offset = (offset[0] + pose["head"][0], offset[1] + pose["head"][1])
            angle = float(pose["nod"])
            pivot = PIVOTS["head"]
        elif name in ("roots_l", "roots_r"):
            offset = (float(pose[name][0]), float(pose[name][1]))
        if name in ("arm_l", "arm_r") and float(pose[name + "_len"]) != 1.0:
            big = _shorten(big, name, float(pose[name + "_len"]))
        if angle and pivot is not None:
            big = big.rotate(-angle, resample=Image.Resampling.NEAREST, center=(pivot[0] + MARGIN, pivot[1] + MARGIN))
        dx, dy = round(offset[0] * per), round(offset[1] * per)
        canvas.alpha_composite(big.transform(big.size, Image.Transform.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.Resampling.NEAREST))
    return canvas


def _axis(arm: str) -> tuple[float, float]:
    """The unit vector along an arm at rest, from its shoulder to its fist."""
    px, py = PIVOTS[arm]
    fx, fy = ATTACH["fist_l" if arm == "arm_l" else "fist_r"][1]
    length = math.hypot(fx - px, fy - py)
    return (fx - px) / length, (fy - py) / length


def _shorten(big: Image.Image, arm: str, factor: float) -> Image.Image:
    """The arm scaled to `factor` along its own length about its shoulder (before it is turned): foreshortening."""
    ux, uy = _axis(arm)
    k = 1.0 / factor - 1.0  # the inverse map: a point at distance d along the arm samples the source at d / factor
    m11, m12, m21, m22 = 1 + k * ux * ux, k * ux * uy, k * uy * ux, 1 + k * uy * uy
    px, py = PIVOTS[arm][0] + MARGIN, PIVOTS[arm][1] + MARGIN
    coeffs = (m11, m12, px - m11 * px - m12 * py, m21, m22, py - m21 * px - m22 * py)
    return big.transform(big.size, Image.Transform.AFFINE, coeffs, resample=Image.Resampling.NEAREST)


def palette() -> tuple[dict[tuple[int, int, int], str], dict[str, tuple[int, int, int]], set[str]]:
    data = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    reserved = set(data["reserved"])
    colours = {c["symbol"]: tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)) for c in data["colors"]}
    return {v: k for k, v in colours.items()}, colours, reserved


def shrink(big: Image.Image, scale: float, feet: tuple[int, int]) -> tuple[list[list[str]], tuple[int, int]]:
    """The posed canvas shrunk to final pixels and snapped to Totoy 36 (symbols; "." = clear). Returns the grid and the feet."""
    _, colours, reserved = palette()
    usable = [(s, c) for s, c in colours.items() if s not in reserved]
    w = round(big.width * scale)
    h = round(big.height * scale)
    small = big.convert("RGBa").resize((w, h), Image.Resampling.BOX).convert("RGBA")
    pixels = small.load()
    cache: dict[tuple[int, int, int], str] = {}
    grid = [["."] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 128:
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = min(usable, key=lambda sc: 2 * (sc[1][0] - r) ** 2 + 4 * (sc[1][1] - g) ** 2 + 3 * (sc[1][2] - b) ** 2)[0]
            grid[y][x] = cache[key]
    return grid, (round(feet[0] * scale), round(feet[1] * scale))


def despeck(grid: list[list[str]], smallest: int = 10) -> None:
    """Clears drawn bits smaller than `smallest` pixels that touch nothing else (specks of the cut-out's edge)."""
    h = len(grid)
    w = len(grid[0])
    seen = [[False] * w for _ in range(h)]
    for sy in range(h):
        for sx in range(w):
            if grid[sy][sx] == "." or seen[sy][sx]:
                continue
            part = [(sx, sy)]
            seen[sy][sx] = True
            i = 0
            while i < len(part):
                x, y = part[i]
                i += 1
                for nx in (x - 1, x, x + 1):
                    for ny in (y - 1, y, y + 1):
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and grid[ny][nx] != ".":
                            seen[ny][nx] = True
                            part.append((nx, ny))
            if len(part) < smallest:
                for x, y in part:
                    grid[y][x] = "."


def light(grid: list[list[str]], state: str) -> None:
    swap = LIGHT.get(state, {})
    for row in grid:
        for i, ch in enumerate(row):
            row[i] = swap.get(ch, ch)


def bury(grid: list[list[str]], feet: tuple[int, int], sink: int, seed: int) -> None:
    """Lowers the golem `sink` rows into the ground (everything below the ground row goes) and heaps broken earth round it."""
    if sink <= 0:
        return
    h = len(grid)
    w = len(grid[0])
    ground = feet[1]
    for y in range(h - 1, -1, -1):  # move down
        for x in range(w):
            src = y - sink
            grid[y][x] = grid[src][x] if src >= 0 else "."
    for y in range(ground, h):
        for x in range(w):
            grid[y][x] = "."
    cols = [x for x in range(w) if any(grid[y][x] != "." for y in range(max(0, ground - 4), ground))]
    if not cols:
        return
    rng = random.Random(seed)
    left, right = min(cols) - 7, max(cols) + 7
    centre = (left + right) / 2.0
    half = max(1.0, (right - left) / 2.0)
    clump = 0
    for x in range(max(0, left), min(w, right + 1)):
        edge = 1.0 - abs(x - centre) / half
        if x % 3 == 0:
            clump = rng.randint(0, 2)
        top = 2 + round(min(1.0, edge * 2.5) * 3) + clump
        for d in range(top + 1):
            y = ground - d
            if 0 <= y < h:
                grid[y][x] = DIRT[-1] if d == 0 else DIRT[min(len(DIRT) - 2, top - d)]
        if rng.random() < 0.06 and ground - top >= 0:
            grid[ground - top][x] = rng.choice(PEBBLES)


def render(layers: dict[str, Image.Image], pose: dict, seed: int = 7) -> tuple[list[list[str]], tuple[int, int]]:
    scale = scale_of(layers["body"])
    big = compose(layers, pose, scale)
    w, h = layers["body"].size
    feet = (MARGIN + w // 2, MARGIN + h - round(FEET_ABOVE_BOTTOM / scale))
    grid, at = shrink(big, scale, feet)
    despeck(grid)
    light(grid, pose["light"])
    smear(layers, pose, scale, feet, grid)
    if pose["clip"] or pose["crumble"] > 0.0:
        for y in range(at[1] + 1, len(grid)):
            grid[y] = ["."] * len(grid[y])
    if pose["crumble"] > 0.0:
        crumble(grid, at, float(pose["crumble"]))
    bury(grid, at, int(pose["sink"]), seed)
    return grid, at


SMEAR = ["j", "1"]  # the smear's pale dither (stone_6, cream), outside the body only


def smear(layers: dict[str, Image.Image], pose: dict, scale: float, feet: tuple[int, int], grid: list[list[str]]) -> None:
    """Pale ghosts of the right arm where it just was: the newest dithered every other pixel, older ones sparser."""
    ghosts = list(pose["smear"])
    for age, (angle, length, off) in enumerate(reversed(ghosts)):
        ghost = dict(pose, arm_r=float(angle), arm_r_len=float(length), arm_r_off=tuple(off))
        mask, _ = shrink(compose(layers, ghost, scale, only="arm_r"), scale, feet)
        step = 2 + age  # every 2nd pixel for the newest ghost, every 3rd, 4th for older ones
        for y, row in enumerate(mask):
            for x, ch in enumerate(row):
                if ch != "." and grid[y][x] == "." and (x + 2 * y) % step == 0:
                    grid[y][x] = SMEAR[(x + y) % 2]


def _stone(x: int, y: int, size: int, seed: int) -> tuple[tuple[int, int], bool]:
    """Which irregular stone (a jittered-grid Voronoi cell about `size` px across) holds pixel (x, y), and whether the pixel is on
    its edge. The same stones every frame for the same seed."""
    gx, gy = x // size, y // size
    best: list[tuple[float, tuple[int, int]]] = []
    for cx in (gx - 1, gx, gx + 1):
        for cy in (gy - 1, gy, gy + 1):
            r = random.Random(cx * 92821 + cy * 68917 + seed)
            sx, sy = (cx + r.random()) * size, (cy + r.random()) * size
            best.append(((sx - x) ** 2 + (sy - y) ** 2, (cx, cy)))
    best.sort()
    return best[0][1], best[1][0] ** 0.5 - best[0][0] ** 0.5 < 1.0


def crumble(grid: list[list[str]], feet: tuple[int, int], amount: float) -> None:
    """Breaks the golem into rubble: stone-shaped chunks fall away, the high ones first (it crumbles from the top while it sinks
    into its own heap; the same chunks go first in every frame, so it only ever loses more), and a heap of outlined stones with
    moss on its crest grows at its feet, with a dark chip of the song in it. At 1.0 only the heap is left."""
    h = len(grid)
    w = len(grid[0])
    ground = feet[1]
    gone: dict[tuple[int, int], bool] = {}
    for y in range(h):
        for x in range(w):
            if grid[y][x] == ".":
                continue
            cell, _ = _stone(x - feet[0], y - feet[1], 6, 11)
            if cell not in gone:
                height = max(0.0, min(1.0, -cell[1] * 6 / float(HEIGHT)))
                chance = 1.0 if amount >= 1.0 else amount * (0.25 + 1.1 * height)
                gone[cell] = random.Random(cell[0] * 7919 + cell[1] * 104729).random() < chance
            if gone[cell]:
                grid[y][x] = "."
    rng = random.Random(4242)
    half = round(28 + 26 * amount)
    tall = 4 + 13 * amount
    shades: dict[tuple[int, int], str] = {}
    for x in range(feet[0] - half, feet[0] + half + 1):
        if not 0 <= x < w:
            continue
        e = max(0.0, 1.0 - ((x - feet[0]) / float(half)) ** 2)
        top = max(1, round(tall * e ** 0.6))
        for d in range(top + 1):
            y = ground - d
            if not 0 <= y < h:
                continue
            cell, edge = _stone(x - feet[0], y - feet[1], 5, 29)
            if cell not in shades:
                shades[cell] = rng.choice(["f", "g", "g", "h", "h", "i"])
            if d == top or edge:
                grid[y][x] = "0" if d == top or d > top - 3 else "e"
            elif d >= top - 2 and (cell[0] + cell[1]) % 3 == 0:
                grid[y][x] = "4" if (x + y) % 5 else "5"  # moss on the crest stones
            else:
                grid[y][x] = shades[cell]
    chip_y = ground - max(2, round(tall * 0.45))
    for x, y in ((feet[0] - 1, chip_y), (feet[0], chip_y), (feet[0], chip_y + 1)):
        if 0 <= x < w and 0 <= y < h:
            grid[y][x] = "t"  # the song's last chip, dark teal


def trim(grid: list[list[str]], feet: tuple[int, int]) -> tuple[list[str], tuple[int, int]]:
    """Cut to the drawn pixels, then pad the top, left and right to multiples of 8 (never below the feet + 2 rows)."""
    h = len(grid)
    w = len(grid[0])
    ys = [y for y in range(h) if any(ch != "." for ch in grid[y])]
    xs = [x for x in range(w) if any(grid[y][x] != "." for y in range(h))]
    top = min(ys)
    bottom = feet[1] + FEET_ABOVE_BOTTOM
    half = max(feet[0] - min(xs), max(xs) - feet[0] + 1)
    width = -(-2 * half // 8) * 8
    height = -(-(bottom - top) // 8) * 8
    left = feet[0] - width // 2
    top = bottom - height
    rows = []
    for y in range(top, bottom):
        rows.append("".join(grid[y][x] if 0 <= y < h and 0 <= x < w else "." for x in range(left, left + width)))
    return rows, (feet[0] - left, feet[1] - top)


def to_image(rows: list[str]) -> Image.Image:
    _, colours, _ = palette()
    image = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    px = image.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = (*colours[ch], 255)
    return image


def build(poses: dict[str, dict]) -> dict[str, tuple[list[str], tuple[int, int]]]:
    layers = split(cut_golem())
    out = {}
    for i, (name, pose) in enumerate(poses.items()):
        grid, feet = render(layers, pose, seed=frame_seed(name))
        out[name] = trim(grid, feet)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--preview", action="store_true", help="write the 4a poses as PNGs to art/reference/colossus_body_v1/")
    parser.add_argument("--frames", action="store_true", help="write every frame of 4b to art/reference/colossus_body_v1/frames/")
    parser.add_argument("--install", action="store_true", help="write every frame into art/src and presentation/explore/colossus_frames.json")
    parser.add_argument("--set", default="", help="with --to: write only this set family (for example sweep) as a review copy")
    parser.add_argument("--to", default="", help="the folder for --set, under art/reference/colossus_body_v1/")
    args = parser.parse_args()
    if args.set:
        return write_set(args.set, OUT / (args.to or args.set))
    if args.frames:
        return write_frames()
    if args.install:
        return install()
    frames = build(POSES)
    if args.preview:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / ".gdignore").write_text("", encoding="utf-8")
        meta = {}
        for name, (rows, feet) in frames.items():
            to_image(rows).save(OUT / f"{name}.png")
            meta[name] = {"w": len(rows[0]), "h": len(rows), "ax": feet[0], "ay": feet[1], "note": POSES[name]["note"]}
        (OUT / "poses.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    for name, (rows, feet) in frames.items():
        print(f"{name}: {len(rows[0])}x{len(rows)} feet {feet}")
    return 0


## The earth rim's random clumps (sunk frames only): seeds tied to the frame's name, the values the appearing and sleep were approved
## with (2026-11-28), so adding frames elsewhere never changes them.
SEED_BASE = {"sleep": 7, "appear": 68}


def frame_seed(name: str) -> int:
    set_name, n = name[len("colossus_"):].rsplit("_right_", 1)
    return SEED_BASE.get(set_name, 7) + int(n) - 1


def write_set(prefix: str, folder: Path) -> int:
    """Only the frames of one set family (colossus_<prefix>...), as PNGs with frames.json, into `folder` (a review copy)."""
    layers = split(cut_golem())
    folder.mkdir(parents=True, exist_ok=True)
    meta: dict[str, dict] = {}
    for i, (name, pose) in enumerate(frame_set().items()):
        if not name.startswith(f"colossus_{prefix}"):
            continue
        grid, feet = render(layers, pose, seed=frame_seed(name))
        rows, at = trim(grid, feet)
        to_image(rows).save(folder / f"{name}.png")
        meta[name] = {"w": len(rows[0]), "h": len(rows), "ax": at[0], "ay": at[1], "attach": attachments(layers, pose), "note": pose["note"]}
    (folder / "frames.json").write_text(json.dumps({"frames": meta}, indent=1) + "\n", encoding="utf-8")
    print(f"{len(meta)} {prefix} frames into {folder}")
    return 0


def write_frames() -> int:
    """Every frame of step 4b as a PNG with frames.json (size, feet, attachments, note; the appearing's first ticks)."""
    layers = split(cut_golem())
    folder = OUT / "frames"
    folder.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").write_text("", encoding="utf-8")
    meta: dict[str, dict] = {}
    for i, (name, pose) in enumerate(frame_set().items()):
        grid, feet = render(layers, pose, seed=frame_seed(name))
        rows, at = trim(grid, feet)
        to_image(rows).save(folder / f"{name}.png")
        meta[name] = {"w": len(rows[0]), "h": len(rows), "ax": at[0], "ay": at[1], "attach": attachments(layers, pose), "note": pose["note"]}
    timeline = [t for t, _ in appear_timeline()]
    (folder / "frames.json").write_text(json.dumps({"frames": meta, "appear_ticks": timeline}, indent=1) + "\n", encoding="utf-8")
    pixels = sum(m["w"] * m["h"] for m in meta.values())
    print(f"{len(meta)} frames, {pixels} px, appearing {len(timeline)} frames over ticks {timeline}")
    return 0


SRC = ROOT / "art" / "src"
RUNTIME = ROOT / "presentation" / "explore" / "colossus_frames.json"


def install() -> int:
    """Every frame into art/src as a text grid (anchor = its feet) and, for presentation, colossus_frames.json: each frame's fist and
    chest points (pixels from its feet) and the first tick of each appearing frame. Old colossus_*_right_* grids that are no longer
    in the set are removed (the stand-in colossus_idle_right_1 is replaced by the rigged idle)."""
    layers = split(cut_golem())
    _, colours, reserved = palette()
    names = frame_set()
    for old in SRC.glob("colossus_*_right_*.txt"):
        if old.stem not in names:
            old.unlink()
            print(f"removed {old.name}")
    attach: dict[str, dict] = {}
    for i, (name, pose) in enumerate(names.items()):
        grid, feet = render(layers, pose, seed=frame_seed(name))
        rows, at = trim(grid, feet)
        assert not any(ch in reserved for row in rows for ch in row), f"{name}: gold or red"
        header = ["# kind: sprite", f"# anchor: {at[0]},{at[1]}",
                  f"# generated by tools/art/rig_colossus.py --install from the approved concept ({pose['note']}); do not hand-edit"]
        (SRC / f"{name}.txt").write_text("\n".join(header + rows) + "\n", encoding="utf-8")
        attach[name] = attachments(layers, pose)
    data = {"about": "Generated by tools/art/rig_colossus.py --install. Per frame: the fists and the chest in pixels from its feet; "
                     "appear_ticks: the alert tick each colossus_appear_right_<n> begins.",
            "appear_ticks": [t for t, _ in appear_timeline()], "attach": attach}
    RUNTIME.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print(f"installed {len(names)} frames into art/src and {RUNTIME.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
