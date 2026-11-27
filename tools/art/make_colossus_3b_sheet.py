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
    ("3b_02_snare_second_lane", "...he dodged: the second lane", "REAL warning (0.5 s, aimed where he went). PIXELFX: thorns burst."),
    ("3b_03_boulder_in_flight", "8 Boulder Toss (phase 2+)", "REAL warning (0.9 s). PIXELFX: the stone spins along the arc."),
    ("3b_04_boulder_ring", "...it lands: the ring of shock warns", "REAL ring warning (0.67 s; the crater is safe). PIXELFX: the landing."),
    ("3b_04b_ring_strikes", "...the ring strikes", "PIXELFX: dust rings roll out (squashed flat: side-view art)."),
    ("3b_05_grab_warning", "9 Heartroot Grab (phase 2+)", "REAL. Gold, 0.7 s. A parry cracks 60 posture (a perfect one breaks it)."),
    ("3b_06_grab_strike", "...the root-arm lashes", "PIXELFX: the vine-whip as a mossy root, turned to the lane."),
    ("3b_07_phase3_roar", "Phase 3 at a quarter of its health", "REAL. It roars; then every attack, the shortest pauses."),
]


def main() -> int:
    base.OUT.mkdir(parents=True, exist_ok=True)
    for name, _, _ in CELLS:
        shutil.copyfile(base.CAPTURES / f"{name}.png", base.OUT / f"{name}.png")
    base.sheet("colossus_3b_attacks.png", "Part 3b: three new attacks and phase 3",
               "Real captures. Where it says PIXELFX, the effect is a proposal: PixelFX in Totoy 36 with hard alpha, drawn on the real lanes; not in the game.",
               3, CELLS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
