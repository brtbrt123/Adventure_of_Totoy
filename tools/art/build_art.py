"""Build PNGs, atlases and Godot tileset data from the text-grid sources in art/src.

Outputs in art/build:
  tiles/<name>.png, sprites/<name>.png   individual images
  tiles.png + tiles.json + tileset.tres  16x16 tile atlas (1px extruded border, Godot TileSet)
  sprites.png + sprites.json             packed sprite atlas (1px extruded border)

Refuses to build if the sources do not validate.

Usage: python tools/art/build_art.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

import artlib

TILE_COLUMNS = 8
TILE_MARGIN = 1  # outer margin of the tile atlas
TILE_SEPARATION = 2  # gap between tiles: one extruded pixel on each side
EXTRUDE = 1
SPRITE_ATLAS_WIDTH = 256
RES_BUILD = "res://art/build"


def paste_extruded(atlas: Image.Image, image: Image.Image, x: int, y: int) -> None:
    """Paste image at (x, y) and copy its edge pixels one pixel outward on every side."""
    w, h = image.size
    atlas.paste(image, (x, y))
    atlas.paste(image.crop((0, 0, w, 1)), (x, y - 1))
    atlas.paste(image.crop((0, h - 1, w, h)), (x, y + h))
    atlas.paste(image.crop((0, 0, 1, h)), (x - 1, y))
    atlas.paste(image.crop((w - 1, 0, w, h)), (x + w, y))
    atlas.putpixel((x - 1, y - 1), image.getpixel((0, 0)))
    atlas.putpixel((x + w, y - 1), image.getpixel((w - 1, 0)))
    atlas.putpixel((x - 1, y + h), image.getpixel((0, h - 1)))
    atlas.putpixel((x + w, y + h), image.getpixel((w - 1, h - 1)))


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")


def build_tiles(tiles: dict[str, Image.Image], out: Path) -> None:
    names = sorted(tiles)
    columns = min(TILE_COLUMNS, len(names))
    rows = -(-len(names) // columns)
    pitch = artlib.TILE_SIZE + TILE_SEPARATION
    atlas = Image.new("RGBA", (columns * pitch, rows * pitch), (0, 0, 0, 0))
    entries: dict[str, dict[str, int]] = {}
    for index, name in enumerate(names):
        col, row = index % columns, index // columns
        x, y = TILE_MARGIN + col * pitch, TILE_MARGIN + row * pitch
        paste_extruded(atlas, tiles[name], x, y)
        entries[name] = {"col": col, "row": row, "x": x, "y": y}
    atlas.save(out / "tiles.png")
    write_json(out / "tiles.json", {
        "texture": f"{RES_BUILD}/tiles.png",
        "tile_size": artlib.TILE_SIZE,
        "margin": TILE_MARGIN,
        "separation": TILE_SEPARATION,
        "columns": columns,
        "rows": rows,
        "tiles": entries,
    })
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{RES_BUILD}/tiles.png" id="1_tiles"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_tiles"]',
        'texture = ExtResource("1_tiles")',
        f"margins = Vector2i({TILE_MARGIN}, {TILE_MARGIN})",
        f"separation = Vector2i({TILE_SEPARATION}, {TILE_SEPARATION})",
        f"texture_region_size = Vector2i({artlib.TILE_SIZE}, {artlib.TILE_SIZE})",
    ]
    lines += [f"{entries[name]['col']}:{entries[name]['row']}/0 = 0" for name in names]
    lines += [
        "",
        "[resource]",
        f"tile_size = Vector2i({artlib.TILE_SIZE}, {artlib.TILE_SIZE})",
        'sources/0 = SubResource("TileSetAtlasSource_tiles")',
        "",
    ]
    (out / "tileset.tres").write_text("\n".join(lines), encoding="utf-8", newline="\n")


def build_sprite_atlas(sprites: dict[str, Image.Image], out: Path, anchors: dict[str, tuple[int, int]] | None = None) -> None:
    anchors = anchors or {}
    order = sorted(sprites, key=lambda n: (-sprites[n].height, n))
    width = max([SPRITE_ATLAS_WIDTH] + [sprites[n].width + 2 * EXTRUDE for n in order])
    placements: dict[str, tuple[int, int]] = {}
    x = y = shelf = 0
    for name in order:
        cell_w, cell_h = sprites[name].width + 2 * EXTRUDE, sprites[name].height + 2 * EXTRUDE
        if x + cell_w > width:
            x, y, shelf = 0, y + shelf, 0
        placements[name] = (x + EXTRUDE, y + EXTRUDE)
        x += cell_w
        shelf = max(shelf, cell_h)
    atlas = Image.new("RGBA", (width, y + shelf), (0, 0, 0, 0))
    frames: dict[str, dict[str, int]] = {}
    for name in order:
        px, py = placements[name]
        paste_extruded(atlas, sprites[name], px, py)
        frames[name] = {"x": px, "y": py, "w": sprites[name].width, "h": sprites[name].height}
        if name in anchors:  # ground point of the sprite in its own pixels, used by presentation to place and mirror it
            frames[name]["ax"], frames[name]["ay"] = anchors[name]
    atlas.save(out / "sprites.png")
    write_json(out / "sprites.json", {
        "texture": f"{RES_BUILD}/sprites.png",
        "extrude": EXTRUDE,
        "size": {"w": atlas.width, "h": atlas.height},
        "frames": {name: frames[name] for name in sorted(frames)},
    })


def main() -> int:
    try:
        palette = artlib.load_palette()
    except artlib.PaletteError as exc:
        print(f"FAIL: {exc}")
        return 1
    sources, errors = artlib.collect(artlib.SRC_DIR, palette)
    if errors:
        print("FAIL: sources do not validate, nothing built")
        for line in errors:
            print(f"  - {line}")
        return 1

    out = artlib.BUILD_DIR
    for sub in ("tiles", "sprites"):
        folder = out / sub
        folder.mkdir(parents=True, exist_ok=True)
        for stale in folder.glob("*.png"):
            stale.unlink()
    tiles: dict[str, Image.Image] = {}
    sprites: dict[str, Image.Image] = {}
    anchors: dict[str, tuple[int, int]] = {}
    for source in sources:
        if source.anchor is not None:
            anchors[source.name] = source.anchor
        image = artlib.render(source, palette)
        group, folder = (tiles, "tiles") if source.kind == "tile" else (sprites, "sprites")
        image.save(out / folder / f"{source.name}.png")
        group[source.name] = image
    if tiles:
        build_tiles(tiles, out)
    if sprites:
        build_sprite_atlas(sprites, out, anchors)
    print(f"Built {len(tiles)} tile(s) and {len(sprites)} sprite(s) into {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
