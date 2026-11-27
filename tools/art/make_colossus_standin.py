"""The Colossus's STAND-IN body for the road fight (docs/PLAN_colossus_step3.md, part 3a; owner approved the plan on 2026-11-27).

One still picture: the golem cut from the approved concept (art/reference/rootcrown_v1/colossus_concept_1.png), 116 px tall,
snapped to Totoy 36 without gold and red, hard alpha. It stands in until the real body frames of step 4; presentation moves it per
state (presentation/explore/colossus_view.gd). Writes art/src/colossus_idle_right_1.txt; then run validate, build and preview.

    python tools/art/make_colossus_standin.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_colossus_step3_preview as preview  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "src" / "colossus_idle_right_1.txt"
HEIGHT = 116  # the owner's choice B
CANVAS = (144, 120)  # multiples of 8; padding on the top, left and right only
FEET_ABOVE_BOTTOM = 2  # the fists and roots reach 2 px below the ground point, as in the approved mock-ups


def main() -> int:
    palette = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
    symbols = {tuple(int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)): c["symbol"] for c in palette["colors"]}
    image = preview.stand_in(preview.cut_golem(), HEIGHT)
    width, height = CANVAS
    assert image.width <= width and image.height <= height, image.size
    left = (width - image.width) // 2
    top = height - image.height
    pixels = image.load()
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            sx, sy = x - left, y - top
            inside = 0 <= sx < image.width and 0 <= sy < image.height
            r, g, b, a = pixels[sx, sy] if inside else (0, 0, 0, 0)
            row.append(symbols[(r, g, b)] if a else ".")
        rows.append("".join(row))
    reserved = set(palette["reserved"])
    assert not any(ch in reserved for row in rows for ch in row), "gold or red in the stand-in"
    anchor = (left + image.width // 2, height - FEET_ABOVE_BOTTOM)
    header = ["# kind: sprite", f"# anchor: {anchor[0]},{anchor[1]}",
              "# STAND-IN until step 4: the approved concept's golem, cut and snapped by tools/art/make_colossus_standin.py (do not hand-edit)"]
    OUT.write_text("\n".join(header + rows) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {width}x{height}, art {image.width}x{image.height}, anchor {anchor}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
