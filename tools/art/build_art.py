"""Build PNGs, atlases and Godot tileset data from the text-grid sources in art/src.

Outputs in art/build:
  tiles/<name>.png, sprites/<name>.png   individual images
  tiles.png + tiles.json + tileset.tres  16x16 tile atlas (1px extruded border, Godot TileSet)
  sprites.png + sprites.json             packed sprite atlas (1px extruded border)
  sprites_gold/white/dark.png            recoloured copies of the atlas the arena loads (see build_variant_atlases)

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
# Shelf-packed sprite atlas. 256 wide reached 256x8126 with the Chain Scythe set; widened to 512 (2026-10-21) for the
# Spirit Lantern / Phantom Cut set, and to 1024 (2026-10-21) for the Echo Step / Stone Ward / Sprint set (512 would be
# 512x8978), and to 2048 (2026-10-31) when the Runebound Warden was redrawn natively at 2.5x (1024 would pass 8192 tall).
# Everything reads frame rectangles from sprites.json, so the width is free to change.
SPRITE_ATLAS_WIDTH = 2048
SPRITE_ATLAS_MAX = 8192  # keep both sides at or under 8192 px (safe texture size for the gl_compatibility renderer)
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


# Recoloured copies of the sprite atlas that the arena used to make pixel by pixel in _ready (about 1 s with the
# 1024x4428 atlas). Same frame rectangles as sprites.png; the rules match presentation/arena/arena.gd exactly:
#   sprites_gold.png   every reserved red pixel turned gold (z -> x, A -> y): the gold-parryable sweep's impact art
#   sprites_white.png  every pixel white with its own alpha: the hit-flash silhouettes (not palette art: the validator
#                      skips it)
#   sprites_dark.png   the Black Form look: inside each hero2_* frame rectangle (not its extruded border) the stone and
#                      blue ramps darkened (e,f,k -> 0; g,l -> e; h,m -> k)
GOLD_SWAP = {"z": "x", "A": "y"}
DARK_SWAP = {"e": "0", "f": "0", "g": "e", "h": "k", "k": "0", "l": "e", "m": "k"}
DARK_PREFIX = "hero2_"
VARIANT_ATLASES = ("sprites_gold.png", "sprites_white.png", "sprites_dark.png")


def _swap_pixels(image: Image.Image, swap: dict[tuple[int, int, int, int], tuple[int, int, int, int]]) -> Image.Image:
    flat = getattr(image, "get_flattened_data", None)  # Pillow 12+; getdata is deprecated there
    data = list(flat() if flat is not None else image.getdata())
    out = Image.new("RGBA", image.size)
    out.putdata([swap.get(pixel, pixel) for pixel in data])
    return out


def build_variant_atlases(atlas: Image.Image, frames: dict[str, dict[str, int]], palette: "artlib.Palette", out: Path) -> None:
    rgba = {symbol: rgb + (255,) for symbol, rgb in palette.by_symbol.items()}
    gold = _swap_pixels(atlas, {rgba[a]: rgba[b] for a, b in GOLD_SWAP.items()})
    gold.save(out / VARIANT_ATLASES[0])
    white = Image.new("RGBA", atlas.size, (255, 255, 255, 255))
    white.putalpha(atlas.getchannel("A"))
    white.save(out / VARIANT_ATLASES[1])
    dark = atlas.copy()
    dark_swap = {rgba[a]: rgba[b] for a, b in DARK_SWAP.items()}
    for name, rect in frames.items():
        if not name.startswith(DARK_PREFIX):
            continue
        box = (rect["x"], rect["y"], rect["x"] + rect["w"], rect["y"] + rect["h"])
        dark.paste(_swap_pixels(atlas.crop(box), dark_swap), box[:2])
    dark.save(out / VARIANT_ATLASES[2])


def build_sprite_atlas(sprites: dict[str, Image.Image], out: Path, anchors: dict[str, tuple[int, int]] | None = None, palette: "artlib.Palette | None" = None) -> None:
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
    if y + shelf > SPRITE_ATLAS_MAX or width > SPRITE_ATLAS_MAX:
        raise SystemExit(f"FAIL: sprite atlas would be {width}x{y + shelf}, over {SPRITE_ATLAS_MAX} px; raise SPRITE_ATLAS_WIDTH in tools/art/build_art.py")
    atlas = Image.new("RGBA", (width, y + shelf), (0, 0, 0, 0))
    frames: dict[str, dict[str, int]] = {}
    for name in order:
        px, py = placements[name]
        paste_extruded(atlas, sprites[name], px, py)
        frames[name] = {"x": px, "y": py, "w": sprites[name].width, "h": sprites[name].height}
        if name in anchors:  # ground point of the sprite in its own pixels, used by presentation to place and mirror it
            frames[name]["ax"], frames[name]["ay"] = anchors[name]
    atlas.save(out / "sprites.png")
    build_variant_atlases(atlas, frames, palette or artlib.load_palette(), out)
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
        build_sprite_atlas(sprites, out, anchors, palette)
    print(f"Built {len(tiles)} tile(s) and {len(sprites)} sprite(s) into {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
