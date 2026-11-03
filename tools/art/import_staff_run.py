"""Cuts the Star Staff's run cycle (art/reference/staff_v1/Staff_Run.png, image generation 2026-11-02) to game-scale frames.

Owner 2026-11-02: "use this as reference for more smooth animation" (a 12-frame run sheet), then "generate frames instead".
The sheet was generated with two references: the staff hero's idle frame (the design) and the katana hero's 6-frame run cycle
(art/src/hero2_walk_right_*, the approved forward lean), so its top row is that run cycle with the staff held low, the crescent
leading at knee height. The bottom row holds in-betweens (more upright than the top row, so interleaving them makes the lean
wobble; they are cut too, for review).

Each frame is matched to the katana run so the two weapons run alike on screen: the figure is scaled so the top row is as tall
as the katana run frames (31 px), the anchor's y is the row's ground line (the lowest foot of the row) and its x sits
HEAD_TO_FEET px behind the head (the katana run's head-to-anchor distance), so the body does not jitter with the stride.
Magenta and its pink fringe are keyed out, every pixel snapped to Totoy 36 without gold or red, the crystal's magenta centre
filled with cream. Output: art/reference/staff_v1/imported/run_<1..12>.png (top row 1-6, bottom row 7-12) and run.json
(anchors); tools/art/make_staff_sprites.py turns frames 1-6 into totoy_staff_walk_right_1..6.

    python tools/art/import_staff_run.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_warden_fx import cells, content_box, palette, shrink  # noqa: E402
from import_staff_concept import fill_holes, to_image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "art/reference/staff_v1/Staff_Run.png"
OUT = ROOT / "art/reference/staff_v1/imported"
TARGET_HEIGHT = 31  # px: the katana run frames (hero2_walk_right_*), head to feet
HEAD_TO_FEET = 7  # px: how far the katana run's head is ahead of its anchor
HEAD_ROWS = 8  # the head: the top rows of a frame


def main() -> int:
    colours = palette()
    allowed = set(colours) - {"x", "y", "z", "A"}
    im = Image.open(SHEET).convert("RGB")
    boxes = cells(im, (6, 2))
    content = [content_box(im, b) for b in boxes]
    heights = sorted(c[3] - c[1] for c in content[:6])
    scale = TARGET_HEIGHT / heights[len(heights) // 2]
    canvases = []
    for b in boxes:
        c = shrink(im, b, scale, allowed, colours)
        fill_holes(c, (int((b[2] - b[0]) * scale), int((b[3] - b[1]) * scale)))
        canvases.append(c)
    meta: dict = {"generator": "tools/art/import_staff_run.py", "source": "art/reference/staff_v1/Staff_Run.png", "scale": round(scale, 4), "frames": []}
    for row in (0, 1):
        ground = max(max(y for _, y in c) for c in canvases[row * 6:row * 6 + 6] if c)
        for i in range(6):
            n = row * 6 + i
            c = canvases[n]
            top = min(y for _, y in c)
            head = [x for (x, y) in c if y < top + HEAD_ROWS]
            ax = round(sum(head) / len(head)) - HEAD_TO_FEET
            img, (left, up) = to_image(c, colours)
            file = f"run_{n + 1}.png"
            img.save(OUT / file)
            meta["frames"].append({"file": file, "w": img.width, "h": img.height, "ax": ax - left, "ay": ground - up})
    (OUT / "run.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote 12 run frames (scale {scale:.3f}) to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
