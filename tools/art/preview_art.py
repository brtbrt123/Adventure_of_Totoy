"""Render all tiles and sprites onto one contact sheet (8x, nearest-neighbor) for human review.

Seamless tiles are also shown repeated 3x3 so seams are visible. A sheet taller than PAGE_HEIGHT is split into pages:
contact_sheet.png, contact_sheet_2.png, ... (whole rows only).

Usage: python tools/art/preview_art.py [--out PATH]
"""
from __future__ import annotations

import argparse
import random
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import artlib

SCALE = 8
REPEAT_SCALE = 4
MAX_WIDTH = 1280
PAD = 16
TITLE_H = 24
LABEL_H = 16
PAGE_HEIGHT = 32000  # contact_sheet.png, contact_sheet_2.png, ...: under 32768 px, so Godot imports each page unscaled
PAGE_RE = re.compile(r"^_\d+$")
BACKGROUND = (42, 42, 48)  # preview background only, not game art
TEXT = (230, 230, 230)

Cell = tuple[str, Image.Image]


def scaled(image: Image.Image, scale: int) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.NEAREST)


def repeated(image: Image.Image, times: int = 3) -> Image.Image:
    sheet = Image.new("RGBA", (image.width * times, image.height * times), (0, 0, 0, 0))
    for ty in range(times):
        for tx in range(times):
            sheet.paste(image, (tx * image.width, ty * image.height))
    return sheet


VARIANT_RE = re.compile(r"^(.*)_(\d+)$")
MIX_COLUMNS, MIX_ROWS, MIX_SEED = 8, 5, 1


def variant_mixes(tiles: list[artlib.Sprite], palette: artlib.Palette) -> list[Cell]:
    """For each terrain with 2+ numbered variants (grass_1, grass_2, ...), render a seeded random patch."""
    groups: dict[str, list[Image.Image]] = {}
    for tile in tiles:
        match = VARIANT_RE.match(tile.name)
        if match:
            groups.setdefault(match.group(1), []).append(artlib.render(tile, palette))
    cells: list[Cell] = []
    for terrain in sorted(groups):
        variants = groups[terrain]
        if len(variants) < 2:
            continue
        rng = random.Random(MIX_SEED)
        size = artlib.TILE_SIZE
        patch = Image.new("RGBA", (MIX_COLUMNS * size, MIX_ROWS * size), (0, 0, 0, 0))
        for ty in range(MIX_ROWS):
            for tx in range(MIX_COLUMNS):
                patch.paste(rng.choice(variants), (tx * size, ty * size))
        cells.append((f"{terrain}: {len(variants)} variants, random mix", scaled(patch, REPEAT_SCALE)))
    return cells


def place(sections: list[tuple[str, list[Cell]]]) -> tuple[list[tuple], int]:
    placed: list[tuple] = []
    y = PAD
    for title, cells in sections:
        placed.append(("title", PAD, y, title))
        y += TITLE_H
        x, row_h = PAD, 0
        for label, image in cells:
            if x > PAD and x + image.width > MAX_WIDTH:
                x, y, row_h = PAD, y + row_h + LABEL_H + PAD, 0
            placed.append(("cell", x, y, (label, image)))
            x += max(image.width, 96) + PAD
            row_h = max(row_h, image.height)
        y += row_h + LABEL_H + PAD
    return placed, y


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=artlib.BUILD_DIR / "contact_sheet.png")
    args = parser.parse_args()

    try:
        palette = artlib.load_palette()
    except artlib.PaletteError as exc:
        print(f"FAIL: {exc}")
        return 1
    sources, errors = artlib.collect(artlib.SRC_DIR, palette)
    if errors:
        print("FAIL: sources do not validate, no preview rendered")
        for line in errors:
            print(f"  - {line}")
        return 1

    tiles = [s for s in sources if s.kind == "tile"]
    sprites = [s for s in sources if s.kind == "sprite"]
    sections: list[tuple[str, list[Cell]]] = [
        (f"Tiles ({len(tiles)}) at {SCALE}x", [(f"{s.name}", scaled(artlib.render(s, palette), SCALE)) for s in tiles]),
        ("Seamless tiles repeated 3x3 (look for visible seams)", [
            (s.name, scaled(repeated(artlib.render(s, palette)), REPEAT_SCALE)) for s in tiles if s.seamless
        ]),
        ("Variant mixes (seeded random placement; look for obvious repeats)", variant_mixes(tiles, palette)),
        (f"Sprites ({len(sprites)}) at {SCALE}x", [
            (f"{s.name} {s.width}x{s.height}", scaled(artlib.render(s, palette), SCALE)) for s in sprites
        ]),
    ]
    sections = [(title, cells) for title, cells in sections if cells]
    placed, height = place(sections)
    # Split into pages of at most PAGE_HEIGHT px (whole rows only): one sheet had grown past Godot's Image pixel limit
    # (it imports everything under res://, including this preview) and past what most image viewers open.
    rows: list[list[tuple]] = []
    for item in placed:  # items come in rows (same y), top to bottom
        if rows and rows[-1][0][2] == item[2]:
            rows[-1].append(item)
        else:
            rows.append([item])
    pages: list[list[tuple]] = [[]]
    page_top = [0]
    for row in rows:
        y = row[0][2]
        bottom = max(y + (p[1].height + LABEL_H if kind == "cell" else TITLE_H) for kind, _, _, p in row)
        if bottom - page_top[-1] > PAGE_HEIGHT and pages[-1]:
            pages.append([])
            page_top.append(y - PAD)
        pages[-1].extend(row)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    for stale in sorted(args.out.parent.glob(f"{args.out.stem}_*{args.out.suffix}")):
        if PAGE_RE.match(stale.stem[len(args.out.stem):]):
            stale.unlink()
            Path(f"{stale}.import").unlink(missing_ok=True)
    outs = []
    for index, items in enumerate(pages):
        top = page_top[index]
        bottom = page_top[index + 1] if index + 1 < len(pages) else height
        sheet = Image.new("RGB", (MAX_WIDTH, bottom - top), BACKGROUND)
        draw = ImageDraw.Draw(sheet)
        for kind, x, y, payload in items:
            if kind == "title":
                draw.text((x, y - top), payload, fill=TEXT)
            else:
                label, image = payload
                sheet.paste(image, (x, y - top), image)
                draw.text((x, y - top + image.height + 2), label, fill=TEXT)
        out = args.out if index == 0 else args.out.with_name(f"{args.out.stem}_{index + 1}{args.out.suffix}")
        sheet.save(out)
        outs.append(f"{out.name} ({sheet.width}x{sheet.height})")
    print(f"Contact sheet written to {args.out.parent}: {', '.join(outs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
