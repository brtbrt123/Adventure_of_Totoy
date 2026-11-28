"""The sheet for the owner from presentation/review/colossus_3c/capture_3c.gd (part 3c of docs/PLAN_colossus_step3.md): the real
Briar Ring and Song Flare in Rootcrown, with the PROPOSED effects drawn over some of them (labelled).

    & "C:\\Tools\\Godot\\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_3c/capture_3c.gd
    python tools/art/make_colossus_3c_sheet.py
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_colossus_3a_sheets as base  # noqa: E402

base.OUT = base.ROOT / "presentation" / "review" / "colossus_3c"
base.CAPTURES = base.CAPTURES.parent / "colossus_3c"


def screen(name: str):
    """A whole-map capture (1024x720) fitted into the cell without stretching; a screen capture as base does it."""
    if not name.endswith("_map"):
        return _screen(name)
    from PIL import Image
    shot = Image.open(base.CAPTURES / f"{name}.png").convert("RGB")
    scale = min(base.CELL[0] / shot.width, base.CELL[1] / shot.height)
    fitted = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.Resampling.LANCZOS)
    cell = Image.new("RGB", base.CELL, (12, 12, 16))
    cell.paste(fitted, ((base.CELL[0] - fitted.width) // 2, (base.CELL[1] - fitted.height) // 2))
    return cell


_screen = base.screen
base.screen = screen

CELLS = [
    ("3c_01_briar_warning", "10 Briar Ring: it warns (4.5 s)", "REAL. At 60 % and 25 %: outside the circle the floor will hurt."),
    ("3c_01b_briar_warning_map", "...the whole map", "REAL. Safe circle 170 px round the clearing's centre."),
    ("3c_02_briars_stand", "...the briars stand (10 s)", "IN THE GAME: the red edge and the wall of root thorns."),
    ("3c_02b_briars_stand_map", "...the whole map", "IN THE GAME. Outside: 8 damage every 0.8 s."),
    ("3c_03_flare_warning", "11 Song Flare (phase 3)", "REAL. Three red rings on their own beats, then a gold blow."),
    ("3c_04_flare_rings", "...the rings burst", "IN THE GAME: PixelFX shards in the song's blue on each real ring."),
    ("3c_05_flare_gold_blow", "...the gold blow (any parry breaks it)", "IN THE GAME: PixelFX mana-burst in the song's blue."),
]


def main() -> int:
    base.OUT.mkdir(parents=True, exist_ok=True)
    for name, _, _ in CELLS:
        shutil.copyfile(base.CAPTURES / f"{name}.png", base.OUT / f"{name}.png")
    base.sheet("colossus_3c_attacks.png", "Part 3c: the Briar Ring and the Song Flare",
               "Real captures from the game. The effects are PixelFX in Totoy 36 with hard alpha, wired 2026-11-28.",
               2, CELLS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
