"""The worn slabs and grass at the Hollow Trial altar's foot (owner playtest 2026-10-31: "the altar looks like it was just put there";
then: a full stone platform is too big, "just add grass and some slabs").

Source: art/reference/hollow_trial_altar_base/altar_base_raw.png (a SpriteCook generation, gpt-image-2 low, made with the room's stone
style as the reference; manifest beside it). This snaps it to Totoy 36 (nearest colour, never the reserved combat colours), crops it to
the art, pads it to multiples of 8 and writes art/src/hollow_trial_altar_base.txt with its anchor: the point where the altar's feet
stand (the open dirt in the middle of the slabs). presentation/explore/trial_scene_art.gd draws it flat on the floor under the altar,
wherever the altar is placed.

    python tools/art/make_trial_altar_base.py      # then validate/build/preview as usual
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/reference/hollow_trial_altar_base/altar_base_raw.png"
TARGET = ROOT / "art/src/hollow_trial_altar_base.txt"
ALTAR_FEET = (99, 58)  # in the cropped art: the front of the open dirt between the slabs, where the altar stands


def palette() -> dict[str, tuple[int, int, int]]:
    data = json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))
    reserved = set(data.get("reserved", []))
    return {c["symbol"]: tuple(bytes.fromhex(c["hex"][1:])) for c in data["colors"] if c["symbol"] not in reserved}


def nearest(rgb: tuple[int, int, int], colours: dict[str, tuple[int, int, int]]) -> str:
    # weighted RGB distance (the eye is most sensitive to green), good enough for snapping a muted image to a 36-colour ramp palette
    return min(colours, key=lambda s: 2 * (rgb[0] - colours[s][0]) ** 2 + 4 * (rgb[1] - colours[s][1]) ** 2 + 3 * (rgb[2] - colours[s][2]) ** 2)


def build() -> tuple[list[str], tuple[int, int]]:
    colours = palette()
    im = Image.open(SOURCE).convert("RGBA")
    im = im.crop(im.getbbox())
    im = _clear_underlay(im)
    width = (im.width + 7) // 8 * 8
    height = (im.height + 7) // 8 * 8
    cache: dict[tuple[int, int, int], str] = {}
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            if x >= im.width or y >= im.height:
                row.append(".")
                continue
            r, g, b, a = im.getpixel((x, y))
            if a < 128:
                row.append(".")
                continue
            if (r, g, b) not in cache:
                cache[(r, g, b)] = nearest((r, g, b), colours)
            row.append(cache[(r, g, b)])
        rows.append("".join(row))
    return rows, ALTAR_FEET


def _underlay(rgb: tuple[int, int, int]) -> bool:
    """The generated dirt patch under the slabs is a neutral warm grey (and its dark rim); the slabs are blue-grey, the grass green."""
    r, g, b = rgb
    return b - r < 4 and not (g - r > 8 and g - b > 8) and r + g + b < 330


def _clear_underlay(im: Image.Image) -> Image.Image:
    """Clears that patch: underlay pixels reachable from the transparent outside without crossing a slab or a grass tuft (the open
    middle is reached through the gaps). Its hard edge read as a dark blob on the room's own painted floor, which now shows instead."""
    im = im.copy()
    px = im.load()
    w, h = im.size
    todo = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] < 128]
    seen = set(todo)
    while todo:
        x, y = todo.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny][3] >= 128 and _underlay(px[nx, ny][:3]):
                seen.add((nx, ny))
                px[nx, ny] = (0, 0, 0, 0)
                todo.append((nx, ny))
    return im


def main() -> int:
    rows, (ax, ay) = build()
    TARGET.write_text("# kind: sprite\n# anchor: %d,%d\n" % (ax, ay) + "\n".join(rows) + "\n", encoding="utf-8", newline="\n")
    print(f"hollow_trial_altar_base: {len(rows[0])}x{len(rows)}, anchor {ax},{ay}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
