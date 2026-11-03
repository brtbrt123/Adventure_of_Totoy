"""Build the one style-reference image uploaded to SpriteCook (review only).

SpriteCook bills every reference image on its newer models, so the four real
captures go up as one 2560x1440 collage, each at its native pixel size:
woodland view, layered village, the arena floor (the current HUD cut away, so
the rejected flat teal boxes do not steer the concept) and the dialogue
portraits (labels cropped off).

  python -P art/reference/ui_kit_spritecook_v1/style_reference.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent / "refs" / "style_collage.png"
INK = (0x1C, 0x18, 0x24, 255)
CELL = (1280, 720)


def load(rel: str) -> Image.Image:
    return Image.open(ROOT / rel).convert("RGBA")


def centred(img: Image.Image) -> Image.Image:
    cell = Image.new("RGBA", CELL, INK)
    cell.alpha_composite(img, ((CELL[0] - img.width) // 2, (CELL[1] - img.height) // 2))
    return cell


def portraits() -> Image.Image:
    sheet = load("art/reference/chapter1_characters_v2/contact_portraits_dark.png")
    rows = [(0, 34, 720, 210), (0, 278, 720, 454), (0, 522, 720, 698), (0, 766, 900, 942)]
    out = Image.new("RGBA", (900, sum(b[3] - b[1] for b in rows)), INK)
    y = 0
    for box in rows:
        out.alpha_composite(sheet.crop(box), (0, y))
        y += box[3] - box[1]
    return out


def main() -> None:
    cells = [
        load("presentation/review/chapter1_expansion/woodland_view_170_260.png"),
        centred(load("presentation/review/chapter1_expansion/current_village_layered.png")),
        centred(load("art/build/arena_hud2.png").crop((0, 0, 820, 520))),
        centred(portraits()),
    ]
    sheet = Image.new("RGBA", (CELL[0] * 2, CELL[1] * 2), INK)
    for i, cell in enumerate(cells):
        sheet.alpha_composite(cell, ((i % 2) * CELL[0], (i // 2) * CELL[1]))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(OUT)
    print(OUT.relative_to(ROOT), sheet.size)


if __name__ == "__main__":
    main()
