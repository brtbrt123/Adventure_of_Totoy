"""Side by side: the owner's Lanternfen painting and the village as captured in the review mock.

Reads art/reference/lanternfen_village_target.png and docs/previews/village_full_v1.png (made by the windowed
tests/capture_village_review.gd) and writes docs/previews/village_vs_target.png: target on the left, game on the right,
both at the village size 571x336 (the game view is the 2x stitch reduced with nearest-neighbour, so its pixels stay hard).
Run from the project root:  python tools/art/compare_village_target.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "art" / "reference" / "lanternfen_village_target.png"
GAME = ROOT / "docs" / "previews" / "village_full_v1.png"
OUT = ROOT / "docs" / "previews" / "village_vs_target.png"
W, H, GAP, LABEL = 571, 336, 12, 22  # core/village_layout.gd VILLAGE_SIZE (scale 0.7)
TRIM = (5, 5, 828, 488)  # the painting without its grey frame (as in make_village_ground_from_reference.py)


def main() -> int:
    for path in (TARGET, GAME):
        if not path.exists():
            print("missing", path)
            return 1
    target = Image.open(TARGET).convert("RGB").crop(TRIM).resize((W, H), Image.LANCZOS)
    game = Image.open(GAME).convert("RGB").resize((W, H), Image.NEAREST)
    sheet = Image.new("RGB", (W * 2 + GAP, H + LABEL), (28, 24, 36))
    sheet.paste(target, (0, LABEL))
    sheet.paste(game, (W + GAP, LABEL))
    draw = ImageDraw.Draw(sheet)
    draw.text((6, 5), "target: art/reference/lanternfen_village_target.png", fill=(244, 236, 214))
    draw.text((W + GAP + 6, 5), "game mock: 9 camera views stitched (docs/previews/village_full_v1.png)", fill=(244, 236, 214))
    sheet.save(OUT)
    print("wrote", OUT, sheet.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
