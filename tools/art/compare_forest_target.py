"""Side by side: the owner's forest route / Stag glade paintings and the scenes as captured in the review mock.

Reads art/reference/forest_route_target.png and stag_glade_target.png, and docs/previews/forest_full_v1.png and
glade_full_v1.png (made by the windowed tests/capture_forest_review.gd), and writes docs/previews/forest_vs_target.png
and glade_vs_target.png: target on the left, game on the right, both at twice the scene's game size (forest 960x576,
glade 1120x672; the target trimmed like tools/art/make_forest_ground_from_reference.py and resized smoothly, the game
view is the 2x stitch itself, so its pixels stay hard). Run from the project root:  python tools/art/compare_forest_target.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_forest_ground_from_reference import SCENES  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PREVIEWS = ROOT / "docs" / "previews"
GAP, LABEL = 12, 22


def compare(name: str, full: str, out: str) -> int:
    scene = SCENES[name]
    game_path = PREVIEWS / full
    for path in (scene.source, game_path):
        if not path.exists():
            print("missing", path)
            return 1
    game = Image.open(game_path).convert("RGB")
    W, H = game.size
    target = Image.open(scene.source).convert("RGB").crop(scene.trim).resize((W, H), Image.LANCZOS)
    sheet = Image.new("RGB", (W * 2 + GAP, H + LABEL), (28, 24, 36))
    sheet.paste(target, (0, LABEL))
    sheet.paste(game, (W + GAP, LABEL))
    draw = ImageDraw.Draw(sheet)
    draw.text((6, 5), f"target: art/reference/{scene.source.name}", fill=(244, 236, 214))
    draw.text((W + GAP + 6, 5), f"game mock: 9 camera views stitched (docs/previews/{full})", fill=(244, 236, 214))
    sheet.save(PREVIEWS / out)
    print("wrote", PREVIEWS / out, sheet.size)
    return 0


def main() -> int:
    return max(compare("forest", "forest_full_v1.png", "forest_vs_target.png"),
               compare("glade", "glade_full_v1.png", "glade_vs_target.png"))


if __name__ == "__main__":
    sys.exit(main())
