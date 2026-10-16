"""Import the character sheets Gemini generated (hero and golem) as palette-bound, anchored sprites.

Each sheet is an equal-cell grid on a (nearly) flat magenta background. This tool keys the magenta out by
colour distance, cuts the grid, shrinks every frame with the SAME scale per sheet family (so the hero is
about HERO_HEIGHT px and the golem about GOLEM_HEIGHT px tall), snaps to the Totoy 36 palette, adds a 1px
ink outline and writes `art/src/<visual_id>_<state>[_right]_<n>.txt` with an `# anchor:` at the feet.

Visual ids are `hero2` (right-facing side view, left is mirrored at runtime) and `golem2` (one direction).
They are new names on purpose: the old `totoy_*` / `mossbound_colossus_*` frames stay until presentation
(Codex) has switched `presentation/arena/animation.gd` over to the new frames.

Usage:
  python tools/art/import_gemini.py [--only Hero_Walk,Golem_Idle] [--replace]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

import artlib
from import_reference import Quantizer, despeckle, outline, shrink, to_grid, trim, write_sprite

REF_DIR = artlib.ROOT / "art" / "reference"

HERO_HEIGHT = 32  # game pixels for a standing hero
GOLEM_HEIGHT = 48  # game pixels for a standing golem (the old placeholder boss was 44)
# source pixels per game pixel at a reference sheet height; scales with the image height
HERO_SCALE_AT_941 = 12.2
GOLEM_SCALE_AT_1440 = 11.8

# file stem -> (visual id, state, columns, rows, frame count, direction suffix)
SHEETS: dict[str, tuple[str, str, int, int, int, str]] = {
    "Hero_Idle": ("hero2", "idle", 2, 2, 4, "_right"),
    "Hero_Walk": ("hero2", "walk", 3, 2, 6, "_right"),
    "Hero_Hurt": ("hero2", "hurt", 2, 2, 4, "_right"),
    "Hero_Victory": ("hero2", "victory", 3, 2, 6, "_right"),
    "Hero_Dash": ("hero2", "dash", 2, 2, 4, "_right"),
    "Hero_Attact1": ("hero2", "attack1", 3, 2, 6, "_right"),
    "Hero_Attact2": ("hero2", "attack2", 3, 2, 6, "_right"),
    "Hero_Attact3": ("hero2", "attack3", 3, 2, 6, "_right"),
    "Hero_Parry": ("hero2", "parry", 3, 2, 6, "_right"),
    "Golem_Idle": ("golem2", "idle", 2, 2, 4, ""),
    "Golem_Walk": ("golem2", "walk", 3, 2, 6, ""),
    "Golem_Slam": ("golem2", "slam", 3, 2, 6, ""),
    "Golem_Swift": ("golem2", "sweep", 3, 2, 6, ""),  # the file is called Swift; the prompt was SWEEP
    "Golem_Stamp": ("golem2", "stomp", 3, 2, 6, ""),  # file Stamp = prompt STOMP
    "Golem_Charge": ("golem2", "charge", 3, 2, 6, ""),
    "Golem_Beam": ("golem2", "beam", 3, 2, 6, ""),
    "Golem_Staggered": ("golem2", "staggered", 2, 2, 4, ""),
    "Golem_Hurt": ("golem2", "hurt", 2, 2, 4, ""),
    "Golem_Roar": ("golem2", "roar", 3, 2, 6, ""),
    "Golem_Death": ("golem2", "death", 4, 2, 8, ""),
}


def is_magenta(r: int, g: int, b: int) -> bool:
    """Flat #FF00FF with JPEG-style noise (the sheets measure about (252, 2, 252))."""
    return r > 165 and b > 165 and g < 120 and abs(r - b) < 80 and (r + b) / 2 - g > 110


def figure_mask(image: Image.Image) -> Image.Image:
    px = image.load()
    mask = Image.new("L", image.size, 0)
    mp = mask.load()
    for y in range(image.height):
        for x in range(image.width):
            if not is_magenta(*px[x, y]):
                mp[x, y] = 255
    return mask


def scale_for(visual_id: str, image: Image.Image) -> float:
    if visual_id == "hero2":
        return HERO_SCALE_AT_941 * image.height / 941
    return GOLEM_SCALE_AT_1440 * image.height / 1440


def feet_x(grid: list[list[str]], transparent: str) -> int:
    """Centre of the lowest opaque rows: where the figure stands."""
    xs: list[int] = []
    for row in reversed(grid):
        xs = [x for x, c in enumerate(row) if c != transparent]
        if xs:
            break
    else:
        return 0
    h = len(grid)
    xs = []
    for y in range(max(0, h - 4), h):
        xs += [x for x, c in enumerate(grid[y]) if c != transparent]
    return round(sum(xs) / len(xs))


def drop_fragments(grid: list[list[str]], transparent: str, min_pixels: int = 10) -> None:
    """Remove detached opaque blobs smaller than min_pixels (thin blade tips that broke off, crumbs)."""
    h, w = len(grid), len(grid[0])
    seen = [[False] * w for _ in range(h)]
    for sy in range(h):
        for sx in range(w):
            if seen[sy][sx] or grid[sy][sx] == transparent:
                continue
            stack, blob = [(sx, sy)], []
            seen[sy][sx] = True
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and grid[ny][nx] != transparent:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(blob) < min_pixels:
                for x, y in blob:
                    grid[y][x] = transparent


def import_sheet(stem: str, out: Path, palette: artlib.Palette) -> list[str]:
    visual_id, state, cols, rows, count, direction = SHEETS[stem]
    image = Image.open(REF_DIR / f"{stem}.png").convert("RGB")
    mask = figure_mask(image)
    scale = scale_for(visual_id, image)
    cw, ch = image.width / cols, image.height / rows
    quant = Quantizer(palette, False)
    names: list[str] = []
    for i in range(count):
        c, r = i % cols, i // cols
        box = (round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch))
        cmask = mask.crop(box)
        if cmask.getbbox() is None:
            print(f"  warning: {stem} cell {i + 1} is empty, skipped")
            continue
        small_pre, small_a = shrink(image.crop(box), cmask, scale)
        grid = to_grid(small_pre, small_a, quant, palette, threshold=85)
        despeckle(grid, palette.transparent)
        drop_fragments(grid, palette.transparent)
        outline(grid, palette)
        trimmed, _ox, _oy = trim(grid, palette.transparent)
        if not trimmed or not trimmed[0]:
            continue
        anchor = (feet_x(trimmed, palette.transparent), len(trimmed))
        name = f"{visual_id}_{state}{direction}_{i + 1}"
        write_sprite(out / f"{name}.txt", trimmed, anchor, f"imported from {stem}.png (Gemini), scale {scale:.2f}", palette.transparent)
        names.append(name)
    return names


TILE_SHEETS = {"Grass": "grass", "Dirt": "dirt", "Stone": "stone", "Water": "water"}  # 4x4 grids of 16 tiles, no gaps


def import_tiles(stem: str, out: Path, palette: artlib.Palette) -> int:
    """Cut a 4x4 tile sheet into sixteen 16x16 tiles (area average, palette snap, no outline)."""
    prefix = TILE_SHEETS[stem]
    image = Image.open(REF_DIR / f"{stem}.png").convert("RGB")
    quant = Quantizer(palette, False)
    cell = image.width / 4
    for old in out.glob(f"{prefix}_*.txt"):
        old.unlink()
    for i in range(16):
        c, r = i % 4, i // 4
        box = (round(c * cell), round(r * cell), round((c + 1) * cell), round((r + 1) * cell))
        small = image.crop(box).resize((16, 16), Image.BOX)
        rows = ["".join(quant.symbol(small.getpixel((x, y))) for x in range(16)) for y in range(16)]
        lines = ["# kind: tile", f"# imported from {stem}.png (Gemini), cell {i + 1}"] + rows
        (out / f"{prefix}_{i + 1}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return 16


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", default="", help="comma separated sheet stems, default all")
    parser.add_argument("--replace", action="store_true", help="delete old hero2_*/golem2_* sources of the chosen sheets first")
    parser.add_argument("--out", type=Path, default=artlib.SRC_DIR)
    args = parser.parse_args()

    palette = artlib.load_palette()
    stems = [s for s in args.only.split(",") if s] or list(SHEETS)
    unknown = [s for s in stems if s not in SHEETS]
    if unknown:
        print(f"unknown sheets: {unknown}", file=sys.stderr)
        return 2
    total = 0
    for stem in stems:
        visual_id, state, _c, _r, _n, direction = SHEETS[stem]
        if args.replace:
            for old in args.out.glob(f"{visual_id}_{state}{direction}_*.txt"):
                old.unlink()
        names = import_sheet(stem, args.out, palette)
        total += len(names)
        print(f"{stem}: {len(names)} frames")
    if not args.only:
        for stem in TILE_SHEETS:
            print(f"{stem}: {import_tiles(stem, args.out, palette)} tiles")
    print(f"wrote {total} frames to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
