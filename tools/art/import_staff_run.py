"""Cuts the Star Staff's run cycle (art/reference/staff_v1/Staff_Run*.png, image generation 2026-11-02) to game-scale frames.

Owner 2026-11-02: "use this as reference for more smooth animation" (a 12-frame run sheet), then "generate frames instead" and
"try 12 frames". Two generated sheets:
  Staff_Run.png            made with the staff hero's idle frame (the design) and the katana hero's 6-frame run cycle
                           (art/src/hero2_walk_right_*, the approved forward lean) as references: its top row is that run cycle
                           with the staff held low, the crescent leading (run_1..6). Its bottom row is cut too (run_7..12) but
                           stands more upright than the top row, so it is not used.
  Staff_Run_Inbetween.png  made from the six in-game run frames (refs/staff_run_cycle_8x.png): its bottom row holds the six
                           in-between poses in order (the front foot landing, the knee coming through, the push-off, then the
                           same with the legs swapped), each between run frame k and k+1 (run_ib_1..6). Its top row repeats
                           the reference and is not used.
tools/art/make_staff_sprites.py interleaves them into the 12-frame run: run_1, run_ib_1, run_2, run_ib_2, ... run_6, run_ib_6.

Each frame is matched to the katana run so the two weapons run alike on screen: every sheet is scaled so its top row is as tall
as the katana run frames (31 px), the anchor's y is the row's ground line (the lowest foot of the row) and its x sits
HEAD_TO_FEET px behind the head (the katana run's head-to-anchor distance), so the body does not jitter with the stride.
Magenta and its pink fringe are keyed out, every pixel snapped to Totoy 36 without gold or red, the crystal's magenta centre
filled with cream. Output: art/reference/staff_v1/imported/run_<n>.png + run.json, run_ib_<k>.png + run_ib.json.

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
INBETWEEN_SHEET = ROOT / "art/reference/staff_v1/Staff_Run_Inbetween.png"
OUT = ROOT / "art/reference/staff_v1/imported"
TARGET_HEIGHT = 31  # px: the katana run frames (hero2_walk_right_*), head to feet
HEAD_TO_FEET = 7  # px: how far the katana run's head is ahead of its anchor
HEAD_ROWS = 8  # the head: the top rows of a frame


def cut(sheet: Path, colours: dict) -> list[tuple[Image.Image, int, int]]:
    """Every cell of a 6x2 sheet (row by row) as (image, ax, ay), at the scale that makes the top row TARGET_HEIGHT tall."""
    allowed = set(colours) - {"x", "y", "z", "A"}
    im = Image.open(sheet).convert("RGB")
    boxes = cells(im, (6, 2))
    content = [content_box(im, b) for b in boxes]
    heights = sorted(c[3] - c[1] for c in content[:6])
    scale = TARGET_HEIGHT / heights[len(heights) // 2]
    canvases = []
    for b in boxes:
        c = shrink(im, b, scale, allowed, colours)
        fill_holes(c, (int((b[2] - b[0]) * scale), int((b[3] - b[1]) * scale)))
        canvases.append(c)
    out = []
    for row in (0, 1):
        ground = max(max(y for _, y in c) for c in canvases[row * 6:row * 6 + 6] if c)
        for c in canvases[row * 6:row * 6 + 6]:
            top = min(y for _, y in c)
            head = [x for (x, y) in c if y < top + HEAD_ROWS]
            ax = round(sum(head) / len(head)) - HEAD_TO_FEET
            img, (left, up) = to_image(c, colours)
            out.append((img, ax - left, ground - up))
    return out


def save(frames: list[tuple[Image.Image, int, int]], prefix: str, source: Path, json_name: str) -> None:
    meta: dict = {"generator": "tools/art/import_staff_run.py", "source": str(source.relative_to(ROOT)).replace("\\", "/"), "frames": []}
    for n, (img, ax, ay) in enumerate(frames, start=1):
        file = f"{prefix}_{n}.png"
        img.save(OUT / file)
        meta["frames"].append({"file": file, "w": img.width, "h": img.height, "ax": ax, "ay": ay})
    (OUT / json_name).write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    colours = palette()
    save(cut(SHEET, colours), "run", SHEET, "run.json")
    save(cut(INBETWEEN_SHEET, colours)[6:], "run_ib", INBETWEEN_SHEET, "run_ib.json")  # the bottom row: the in-betweens
    print(f"wrote run_1..12 and run_ib_1..6 to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
