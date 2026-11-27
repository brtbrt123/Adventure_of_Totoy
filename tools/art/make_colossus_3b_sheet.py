"""The sheet for the owner from presentation/review/colossus_3b/capture_3b.gd (part 3b of docs/PLAN_colossus_step3.md): the real
warnings of the three new attacks and phase 3, with the PROPOSED effects drawn over some of them (labelled mock).

    & "C:\\Tools\\Godot\\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_3b/capture_3b.gd
    python tools/art/make_colossus_3b_sheet.py
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_colossus_3a_sheets as base  # noqa: E402

base.OUT = base.ROOT / "presentation" / "review" / "colossus_3b"
base.CAPTURES = base.CAPTURES.parent / "colossus_3b"

CELLS = [
    ("3b_01_snare_warning", "7 Root Snare: the first lane", "REAL. Red, 0.8 s, all phases. Damage 18."),
    ("3b_02_snare_second_lane", "...he dodged: the second lane", "IN THE GAME: PixelFX thorns burst along the first lane."),
    ("3b_03_boulder_in_flight", "8 Boulder Toss (phase 2+)", "IN THE GAME: the PixelFX stone spins along its arc, its shadow grows."),
    ("3b_04_boulder_ring", "...it lands: the ring of shock warns", "IN THE GAME: the landing. The crater is safe from the ring."),
    ("3b_04b_ring_strikes", "...the ring strikes (your option B)", "IN THE GAME: 14 PixelFX stone shards over the ring's real band."),
    ("3b_05_grab_warning", "9 Heartroot Grab (phase 2+)", "REAL. Gold, 0.7 s. A parry cracks 60 posture (a perfect one breaks it)."),
    ("3b_06_grab_strike", "...the root-arm rears to lash", "IN THE GAME: PixelFX vine-whip as a pale root, turned to the lane."),
    ("3b_07_phase3_roar", "Phase 3 at a quarter of its health", "REAL. It roars; then every attack, the shortest pauses."),
]


def main() -> int:
    base.OUT.mkdir(parents=True, exist_ok=True)
    for name, _, _ in CELLS:
        shutil.copyfile(base.CAPTURES / f"{name}.png", base.OUT / f"{name}.png")
    base.sheet("colossus_3b_attacks.png", "Part 3b: three new attacks and phase 3",
               "Real captures from the game. The effects are PixelFX in Totoy 36 with hard alpha, wired 2026-11-27 and 28.",
               3, CELLS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
