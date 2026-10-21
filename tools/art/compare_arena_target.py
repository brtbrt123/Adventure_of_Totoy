"""Side by side: the owner's target painting and the arena as captured in the game.

Reads art/reference/arena_target_look.png and docs/previews/arena_full_v2.png (made by the windowed
tests/capture_arena_review.gd) and writes docs/previews/arena_vs_target.png: target on the left, game on the right,
both at 800x480 (the game view is the 2x stitch reduced with nearest-neighbour, so its pixels stay hard).
Run from the project root:  python tools/art/compare_arena_target.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "art" / "reference" / "arena_target_look.png"
GAME = ROOT / "docs" / "previews" / "arena_full_v2.png"
OUT = ROOT / "docs" / "previews" / "arena_vs_target.png"
W, H, GAP, LABEL = 800, 480, 12, 22


def main() -> int:
    for path in (TARGET, GAME):
        if not path.exists():
            print("missing", path)
            return 1
    target = Image.open(TARGET).convert("RGB").crop((1, 5, 807, 488)).resize((W, H), Image.LANCZOS)
    game = Image.open(GAME).convert("RGB").resize((W, H), Image.NEAREST)
    sheet = Image.new("RGB", (W * 2 + GAP, H + LABEL), (28, 24, 36))
    sheet.paste(target, (0, LABEL))
    sheet.paste(game, (W + GAP, LABEL))
    draw = ImageDraw.Draw(sheet)
    draw.text((6, 5), "target: art/reference/arena_target_look.png", fill=(244, 236, 214))
    draw.text((W + GAP + 6, 5), "game: 9 camera views stitched (docs/previews/arena_full_v2.png)", fill=(244, 236, 214))
    sheet.save(OUT)
    print("wrote", OUT, sheet.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
