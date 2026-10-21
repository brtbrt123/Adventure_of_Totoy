"""Labelled sheets comparing the forest route and the Stag glade at the scale options (the human's review, 2026-10-22:
at 1.0 the hero looks tiny next to the painted trees, stones and props; the village moved to 0.7 for the same reason).

Reads the 1x camera crops made by the windowed
  godot --path . --script res://tests/capture_forest_review.gd -- --scales
(docs/previews/scale_options/<scene>_sNNN_crop_<name>.png: the same spots at every scale, hero and creatures at their
pixel size, arena shadow and ambient tint) and writes docs/previews/forest_scale_options.png (rows: current 1.0, 0.7,
0.6, 0.5; columns: the first clearing with the signpost, the second clearing with the lantern pedestals) and
glade_scale_options.png (the stone ring with the spring), every crop shown 4x, with the measured sizes per row.

Measured on the 1.0 ground (presentation/forest/*_ground.png), in px, scaled by S for the options; the hero
(hero2_idle_right_1) is 34 px tall at every scale (the village is right at 0.7 with the hero 34 px and door/hero 1.15):
signpost 77 tall, middle tree trunk 72 wide (at the hero's head height above its roots), lantern pedestal 82 tall,
chest 51 tall, standing stone 60 tall. The Stag's share of the glade fight area (FIGHT_AREA scaled with the scene,
Stag radius 20 not scaled) is measured by tests/core/test_glade_layout_scaled.gd fight_share().
Run from the project root:  python tools/art/make_forest_scale_sheet.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CROPS = ROOT / "docs" / "previews" / "scale_options"
OUT = ROOT / "docs" / "previews"
SCALES = [1.0, 0.7, 0.6, 0.5]
ZOOM = 4
VIEW = (320, 180)
HERO = 34
# measured at 1.0 (see the docstring)
SIGNPOST, TRUNK, PEDESTAL, CHEST, STONE = 77, 72, 82, 51, 60
# tests/core/test_glade_layout_scaled.gd fight_share() (and test_glade_layout.gd at 1.0)
STAG_SHARE = {1.0: 82.6, 0.7: 68.9, 0.6: 59.5, 0.5: 30.2}
BG, INK, DIM = (28, 24, 36), (244, 236, 214), (190, 184, 170)


def _ratio(name: str, size: float) -> str:
    return f"{name} {size:.0f} px = {size / HERO:.2f} x hero"


def _label(scene: str, s: float) -> tuple[str, str]:
    w, h = round(800 * s), round(480 * s)
    head = f"{'current 1.0' if s == 1.0 else f'scale {s:.1f}'}: world {w}x{h} ({w / VIEW[0]:.2f} x {h / VIEW[1]:.2f} screens), hero {HERO} px"
    if scene == "forest":
        body = " | ".join([_ratio("signpost", SIGNPOST * s), _ratio("trunk width", TRUNK * s),
                           _ratio("pedestal", PEDESTAL * s), _ratio("chest", CHEST * s)])
    else:
        body = " | ".join([_ratio("standing stone", STONE * s), _ratio("trunk width", TRUNK * s),
                           f"Stag (r 20) reaches {STAG_SHARE[s]:.1f} % of the fight area (rule at 1.0: 80 %)"])
    return head, body


def sheet(scene: str, crops: list[str], titles: list[str]) -> int:
    font = ImageFont.load_default(size=30)
    small = ImageFont.load_default(size=24)
    cw, ch = VIEW[0] * ZOOM, VIEW[1] * ZOOM
    gap, title_h, label_h = 16, 50, 84 if len(crops) > 1 else 144
    width = len(crops) * cw + (len(crops) + 1) * gap
    height = title_h + len(SCALES) * (label_h + ch + gap) + gap
    out = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(out)
    draw.text((gap, 10), f"{scene}: " + "   |   ".join(titles) + "   (1x game pixels shown 4x)", fill=INK, font=font)
    y = title_h
    for s in SCALES:
        head, body = _label(scene, s)
        draw.text((gap, y + 6), head, fill=INK, font=font)
        # the measurements, wrapped to the sheet width at the " | " separators
        line, lines = "", []
        for part in body.split(" | "):
            trial = part if not line else line + " | " + part
            if line and draw.textlength(trial, font=small) > width - 2 * gap:
                lines.append(line)
                trial = part
            line = trial
        lines.append(line)
        for k, text in enumerate(lines):
            draw.text((gap, y + 44 + k * 30), text, fill=DIM, font=small)
        y += label_h
        for k, name in enumerate(crops):
            path = CROPS / f"{scene}_s{round(s * 100):03d}_crop_{name}.png"
            if not path.exists():
                print("missing", path)
                return 1
            img = Image.open(path).convert("RGB").resize((cw, ch), Image.NEAREST)
            out.paste(img, (gap + k * (cw + gap), y))
        y += ch + gap
    path = OUT / f"{scene}_scale_options.png"
    out.save(path)
    print("wrote", path, out.size)
    return 0


def main() -> int:
    return max(sheet("forest", ["sign", "pedestals"], ["first clearing, signpost", "second clearing, lantern pedestals"]),
               sheet("glade", ["ring"], ["the stone ring with the spring"]))


if __name__ == "__main__":
    sys.exit(main())
