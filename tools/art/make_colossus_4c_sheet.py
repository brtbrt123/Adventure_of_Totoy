"""The sheet and GIF for the owner from presentation/review/colossus_4c/capture_4c.gd (build step 4c, docs/PLAN_colossus_step4.md): the
rigged body wired into the game, REAL captures in Rootcrown at night, and the appearing as a GIF from the real frames.

    & "C:\\Tools\\Godot\\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_4c/capture_4c.gd
    python tools/art/make_colossus_4c_sheet.py
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_colossus_3a_sheets as base  # noqa: E402

base.OUT = base.ROOT / "presentation" / "review" / "colossus_4c"
base.CAPTURES = base.CAPTURES.parent / "colossus_4c"
GIF_SCALE = 2  # the window is 3x the 384x216 view: shrunk to the view's own pixels, then drawn 2x
TICK_MS = 1000.0 / 60.0
APPEAR_EVERY = 4  # capture_4c.gd's sequence step

CELLS = [
    ("4c_01_asleep", "Asleep: a mossy mound", "REAL. Only its face shows; the song is dark."),
    ("4c_02_appear_fist", "It appears: a fist bursts out", "REAL. Stone shards, a stomp and a shake where it breaks the floor."),
    ("4c_03_appear_other_fist", "...then the other", "REAL."),
    ("4c_04_appear_plant", "...it plants both fists", "REAL. Dust where they land."),
    ("4c_05_appear_rising", "...and pulls itself out", "REAL. Roots tearing free."),
    ("4c_06_appear_roar", "...and roars", "REAL. 2.5 s from waking; it cannot be hurt until now."),
    ("4c_07_slam_windup", "Gold Slam: fists overhead", "REAL. The camera keeps the raised fists in view where it can."),
    ("4c_08_slam_blow", "...the blow", "REAL."),
    ("4c_09_sweep", "Gold Sweep: the arm swings across", "REAL."),
    ("4c_10_boulder_held", "Boulder Toss: the stone held overhead", "REAL. Held between its fists."),
    ("4c_11_boulder_thrown", "...thrown onto the warned circle", "REAL. It lands when the warning strikes."),
    ("4c_12_flare_gathers", "Song Flare: the song gathers", "REAL. Before the gold blow."),
    ("4c_13_flare_gold_blow", "...the gold blow", "REAL."),
    ("4c_14_posture_broken", "Posture broken: slumped", "REAL. The song flickers in the counter window."),
    ("4c_15_death_breaks", "Its fall: it breaks apart", "REAL. The arms break off, the head topples."),
    ("4c_16_death_heap", "...into stone and moss", "REAL. The heap, then gone when the fall ends (40 ticks)."),
]


def appear_gif() -> None:
    folder = base.CAPTURES / "appear"
    shots = sorted(folder.glob("seq_*.png"))
    frames = []
    for shot in shots:
        image = Image.open(shot).convert("RGB")
        view = image.resize((image.width // 3, image.height // 3), Image.Resampling.NEAREST)
        frames.append(view.resize((view.width * GIF_SCALE, view.height * GIF_SCALE), Image.Resampling.NEAREST))
    images = [f.quantize(colors=255, method=Image.Quantize.MEDIANCUT) for f in frames]
    duration = round(APPEAR_EVERY * TICK_MS / 10.0) * 10
    images[0].save(base.OUT / "colossus_4c_appear.gif", save_all=True, append_images=images[1:], duration=duration, loop=0, disposal=1)
    print(f"colossus_4c_appear.gif: {len(images)} frames, {len(images) * duration / 1000:.1f} s")


def main() -> int:
    base.OUT.mkdir(parents=True, exist_ok=True)
    for name, _, _ in CELLS:
        shutil.copyfile(base.CAPTURES / f"{name}.png", base.OUT / f"{name}.png")
    base.sheet("colossus_4c_body.png", "Step 4c: the Colossus's body in the game",
               "Real captures from the game in Rootcrown at night (attacks forced for the pictures). The body is rigged from the approved "
               "concept; frames from tools/art/rig_colossus.py.", 4, CELLS)
    appear_gif()
    return 0


if __name__ == "__main__":
    sys.exit(main())
