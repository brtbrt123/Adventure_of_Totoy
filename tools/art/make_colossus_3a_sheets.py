"""Sheets for the owner from presentation/review/colossus_3a/capture_3a.gd (part 3a of docs/PLAN_colossus_step3.md):
the real fight in Rootcrown, and the storyboard of the proposed victory cutscene (mostly mock-ups, labelled).

    & "C:\\Tools\\Godot\\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_3a/capture_3a.gd
    python tools/art/make_colossus_3a_sheets.py

Writes presentation/review/colossus_3a/ (the sheets and the single captures).
"""
from __future__ import annotations

import math
import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "presentation" / "review" / "colossus_3a"
CAPTURES = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Adventure of Totoy" / "colossus_3a"
CELL = (768, 432)

FIGHT = [
    ("fight_01_asleep", "Asleep", "Half sunk into the hill, dim. It wakes when Totoy is 180 px away."),
    ("fight_02_rising", "Rising (1.5 s)", "It cannot be hurt yet. The climb closes behind Totoy."),
    ("fight_03_gold_slam", "1 Gold Slam", "Gold: parry. The glowing edge is the night-warning fix."),
    ("fight_04_red_sweep", "2 Sweep", "Gold (as you asked on 2026-10-16): parry."),
    ("fight_05_red_shards", "3 Red Shards", "Red: dodge. Three lanes from its chest."),
    ("fight_06_red_stomp", "4 Red Stomp", "Red: hug it or get far."),
    ("fight_07_gold_combo", "5 Gold Combo (phase 2)", "Three blows, 0.43 s apart."),
    ("fight_08_red_charge", "6 Red Charge (phase 2)", "Red: dash across the lane."),
    ("fight_09_posture_broken", "Posture broken", "The counter window: x4 damage. Panel top right."),
    ("fight_10_behind", "Totoy behind it", "Pale outline over the body."),
    ("fight_11_after_the_fall", "After its fall (today)", "Toast, beacon lit, climb open. The cutscene would go here."),
]

STORY = [
    ("story_1_last_blow", "1  The last blow  (0 to 0.6 s)", "REAL capture of a blow landing (white flash); the killing one would freeze."),
    ("story_2_it_breaks", "2  It breaks apart  (0.6 to 3 s)", "MOCK: blue light bursts from its cracks; it falls into stone and moss."),
    ("story_3_the_song_goes_home", "3  The song goes home  (3 to 5.5 s)", "MOCK: the song rises from the rubble; the camera follows it up the hill."),
    ("story_4_the_beacon_lights", "4  The beacon lights  (5.5 to 8 s)", "REAL renderer: the whole tower, lit. Caption (yours to write), then play goes on."),
]


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


def screen(name: str) -> Image.Image:
    shot = Image.open(CAPTURES / f"{name}.png").convert("RGB")
    return shot.resize((384, 216), Image.Resampling.NEAREST).resize(CELL, Image.Resampling.NEAREST)


def caption(image: Image.Image, text: str) -> Image.Image:
    """A mock caption bar on a storyboard panel (placeholder words, the owner writes the real ones)."""
    out = image.copy()
    draw = ImageDraw.Draw(out)
    draw.rectangle((0, CELL[1] - 64, CELL[0], CELL[1]), fill=(20, 18, 26))
    draw.text((CELL[0] // 2, CELL[1] - 32), text, font=font(26), fill=(244, 236, 214), anchor="mm")
    return out


def sheet(file: str, title: str, subtitle: str, columns: int, cells: list[tuple[str, str, str]], captions: dict[str, str] | None = None) -> None:
    gap, head, top = 12, 70, 96
    rows = math.ceil(len(cells) / columns)
    image = Image.new("RGB", (columns * CELL[0] + (columns + 1) * gap, top + rows * (CELL[1] + head + gap) + gap), (22, 20, 28))
    draw = ImageDraw.Draw(image)
    draw.text((gap, 10), title, font=font(34), fill=(244, 236, 214))
    draw.text((gap, 56), subtitle, font=font(22), fill=(167, 205, 224))
    for i, (name, heading, note) in enumerate(cells):
        x = gap + (i % columns) * (CELL[0] + gap)
        y = top + (i // columns) * (CELL[1] + head + gap)
        draw.text((x, y + 2), heading, font=font(26), fill=(244, 236, 214))
        draw.text((x, y + 38), note, font=font(21), fill=(198, 191, 170))
        cell = screen(name)
        if captions and name in captions:
            cell = caption(cell, captions[name])
        image.paste(cell, (x, y + head))
    image.save(OUT / file)
    print("wrote", OUT / file)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, _, _ in FIGHT + STORY:
        shutil.copyfile(CAPTURES / f"{name}.png", OUT / f"{name}.png")
    sheet("colossus_3a_fight.png", "Part 3a in the game: the Colossus fight in Rootcrown",
          "Real captures: real core, renderer, HUD and night light. The boss is the stand-in body (one still picture, moved per state).",
          3, FIGHT)
    sheet("colossus_3a_victory_storyboard.png", "Victory cutscene: storyboard (about 8 s, skippable)",
          "Panels 2 and 3 are MOCK-UPS drawn over the real scene; the HUD hides from panel 2; the caption words are yours to write.",
          2, STORY, {"story_4_the_beacon_lights": "The forest beacon burns again.  (placeholder)"})
    return 0


if __name__ == "__main__":
    sys.exit(main())
