"""Import the character sheets Gemini generated (hero and golem) as palette-bound, anchored sprites.

Each sheet is an equal-cell grid on a (nearly) flat magenta background. This tool keys the magenta out by
colour distance, cuts the grid, shrinks every frame with the SAME scale per sheet family (so the hero is
about HERO_HEIGHT px and the golem about GOLEM_HEIGHT px tall), snaps to the Totoy 36 palette, adds a 1px
ink outline and writes `art/src/<visual_id>_<state>[_right]_<n>.txt` with an `# anchor:` at the feet.

Visual ids are `hero2` (right-facing side view, left is mirrored at runtime) and `golem2` (one direction).
The hero2 frames are written UPRIGHT to art/reference/hero_lean/upright/ and then leaned into art/src by
tools/art/make_hero_lean_sheet.py (the lean step runs automatically at the end when a hero sheet was imported).
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
from import_reference import Quantizer, despeckle, outline, shrink, srgb_to_lab, to_grid, trim, write_sprite

REF_DIR = artlib.ROOT / "art" / "reference"
HERO_UPRIGHT_DIR = REF_DIR / "hero_lean" / "upright"  # upright hero2 frames, input of make_hero_lean_sheet.py

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



# Effects, UI and props: one family scale per sheet, chosen so the largest frame is `target` game pixels.
# (stem, id prefix, columns, rows, frame count, mode, target px, per-frame labels or None)
# modes: fx = centred on the cell centre (anchor = origin of the effect), prop = anchor at the bottom
# centre, ui = no anchor; `beam` keeps the full cell width so segments tile; reserved gold/red allowed
# for fx and warning icons only.
EXTRA: list[tuple[str, str, int, int, int, str, int, list[str] | None]] = [
    ("Slam_Shockwave", "fx_slam", 3, 2, 6, "fx", 96, None),
    ("Stomp_Ring", "fx_stomp", 3, 2, 6, "fx", 96, None),
    ("Sweep_Arc", "fx_sweep", 3, 2, 6, "fx", 80, None),
    ("Dust_and_Debris", "fx_dust", 3, 2, 6, "fx", 48, None),
    ("Charge_Trail", "fx_charge", 3, 2, 6, "fx", 64, None),
    ("Ground_Cracks", "fx_cracks", 3, 2, 6, "fx", 48, None),
    ("Laser_Start", "fx_beam_start", 2, 2, 4, "fx", 32, None),
    ("Laser_Body", "fx_beam_body", 2, 2, 4, "beam", 96, None),
    ("Lazer_End", "fx_beam_end", 2, 2, 4, "fx", 40, None),
    ("Hit_Spark", "fx_hit", 3, 2, 6, "fx", 24, None),
    ("Counter_Hit", "fx_counter", 3, 2, 6, "fx", 40, None),
    ("Parry_Clash", "fx_parry", 3, 2, 6, "fx", 40, None),
    ("Sword_Slash_Small", "fx_slash_small", 3, 2, 6, "fx", 32, None),
    ("Sword_Slash_Big", "fx_slash_big", 3, 2, 6, "fx", 48, None),
    ("Dash_Lines", "fx_dash", 3, 2, 6, "fx", 40, None),
    ("Heal_and_Flash", "fx", 4, 2, 8, "fx", 32, ["flash"] * 4 + ["heal"] * 4),
    ("Gold_Warning_Icon", "ui_warning_gold", 2, 1, 2, "icon_fx", 16, None),
    ("Red_Warning_Icon", "ui_warning_red", 2, 1, 2, "icon_fx", 16, None),
    ("Edge_Dash_Parry_Icon", "ui_icon", 3, 1, 3, "ui", 24, ["edge", "dash", "parry"]),
    ("Player_Profile_Frame", "ui_profile", 1, 1, 1, "ui", 200, None),
    ("Boss_Bar_Frame", "ui_boss", 1, 1, 1, "ui", 200, None),
    ("Nature_Prop", "prop_nature", 4, 2, 8, "prop", 40, None),
    ("Ruins_Prop", "prop_ruins", 3, 2, 6, "prop", 48, None),
    ("Small_Props", "prop_small", 4, 2, 8, "prop", 24, None),
    ("Arena_Walls_Prop", "prop_wall", 4, 3, 12, "prop", 40, None),
]


def import_extra(spec: tuple[str, str, int, int, int, str, int, list[str] | None], out: Path, palette: artlib.Palette) -> int:
    stem, prefix, cols, rows, count, mode, target, labels = spec
    image = Image.open(REF_DIR / f"{stem}.png").convert("RGB")
    mask = figure_mask(image)
    cw, ch = image.width / cols, image.height / rows
    boxes = [
        (round((i % cols) * cw), round((i // cols) * ch), round((i % cols + 1) * cw), round((i // cols + 1) * ch)) for i in range(count)
    ]
    biggest = 1
    for box in boxes:
        bb = mask.crop(box).getbbox()
        if bb:
            biggest = max(biggest, bb[2] - bb[0], bb[3] - bb[1])
    scale = biggest / target
    quant = Quantizer(palette, True)
    if mode in ("fx", "icon_fx", "beam"):
        quant.choices = [(sym, srgb_to_lab(rgb)) for sym, rgb in palette.by_symbol.items()]  # red and gold allowed
    else:
        quant = Quantizer(palette, False)
    for old in out.glob(f"{prefix}_*.txt"):
        if labels is None:
            old.unlink()
    counters: dict[str, int] = {}
    written = 0
    for i, box in enumerate(boxes):
        cmask = mask.crop(box)
        if cmask.getbbox() is None:
            print(f"  warning: {stem} cell {i + 1} is empty, skipped")
            continue
        small_pre, small_a = shrink(image.crop(box), cmask, scale)
        grid = to_grid(small_pre, small_a, quant, palette, threshold=60 if mode in ("fx", "beam") else 100)
        if mode in ("prop", "icon_fx", "ui"):
            drop_fragments(grid, palette.transparent, 4)
        if mode == "beam":
            top = [y for y, row in enumerate(grid) if any(c != palette.transparent for c in row)]
            trimmed, ox, oy = grid[top[0] : top[-1] + 1], 0, top[0]
        else:
            trimmed, ox, oy = trim(grid, palette.transparent)
        if not trimmed or not trimmed[0]:
            continue
        anchor: tuple[int, int] | None = None
        if mode in ("fx", "icon_fx"):
            anchor = (round(cw / 2 / scale - ox), round(ch / 2 / scale - oy))
            # keep the true origin even when the effect sits off-centre in its cell: pad the sprite to include it
            h0, w0 = len(trimmed), len(trimmed[0])
            top, left = max(0, -anchor[1]), max(0, -anchor[0])
            bottom, right = max(0, anchor[1] - h0 + 1), max(0, anchor[0] - w0 + 1)
            if top or left or bottom or right:
                t = palette.transparent
                trimmed = [[t] * (w0 + left + right) for _ in range(top)] + [[t] * left + row + [t] * right for row in trimmed] + [[t] * (w0 + left + right) for _ in range(bottom)]
                anchor = (anchor[0] + left, anchor[1] + top)
        elif mode == "prop":
            anchor = (feet_x(trimmed, palette.transparent), len(trimmed))
        label = labels[i] if labels else None
        key = f"{prefix}_{label}" if label else prefix
        counters[key] = counters.get(key, 0) + 1
        name = f"{key}_{counters[key]}" if count > 1 or label else key
        write_sprite(out / f"{name}.txt", trimmed, anchor, f"imported from {stem}.png (Gemini), scale {scale:.2f}", palette.transparent)
        written += 1
    return written


# Tile sheets are 4x4 grids of 16 tiles, no gaps. Each entry: sheet stem -> [(name prefix, first cell, count)].
# Cells run left to right, top to bottom. The two Transition sheets in art/reference are the same picture.
TILE_SHEETS: dict[str, list[tuple[str, int, int]]] = {
    "Grass": [("grass", 0, 16)],
    "Dirt": [("dirt", 0, 16)],
    "Stone": [("stone", 0, 16)],
    "Water": [("water", 0, 16)],
    "Damaged_Ground": [("cracked", 0, 8), ("mossstone", 8, 8)],  # prompt T05: 8 cracked, 8 mossy stone
    "Transition": [("edge_dirt", 0, 8), ("edge_water", 8, 8)],  # prompt T06: 8 grass-to-dirt, 8 grass-to-water edges
}


def import_tiles(stem: str, out: Path, palette: artlib.Palette) -> int:
    """Cut a 4x4 tile sheet into 16x16 tiles (area average, palette snap, no outline)."""
    image = Image.open(REF_DIR / f"{stem}.png").convert("RGB")
    quant = Quantizer(palette, False)
    cell = image.width / 4
    written = 0
    for prefix, first, count in TILE_SHEETS[stem]:
        for old in out.glob(f"{prefix}_*.txt"):
            old.unlink()
        for n in range(count):
            i = first + n
            c, r = i % 4, i // 4
            box = (round(c * cell), round(r * cell), round((c + 1) * cell), round((r + 1) * cell))
            small = image.crop(box).resize((16, 16), Image.BOX)
            rows = ["".join(quant.symbol(small.getpixel((x, y))) for x in range(16)) for y in range(16)]
            lines = ["# kind: tile", f"# imported from {stem}.png (Gemini), cell {i + 1}"] + rows
            (out / f"{prefix}_{n + 1}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
            written += 1
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", default="", help="comma separated sheet stems, default all")
    parser.add_argument("--replace", action="store_true", help="delete old hero2_*/golem2_* sources of the chosen sheets first")
    parser.add_argument("--out", type=Path, default=artlib.SRC_DIR)
    args = parser.parse_args()

    palette = artlib.load_palette()
    stems = [s for s in args.only.split(",") if s] or list(SHEETS)
    only_given = bool(args.only)
    extra_stems = {spec[0] for spec in EXTRA}
    stems = [s for s in stems if s not in extra_stems]
    unknown = [s for s in stems if s not in SHEETS]
    if unknown:
        print(f"unknown sheets: {unknown}", file=sys.stderr)
        return 2
    total = 0
    hero_sheets = 0
    for stem in stems:
        visual_id, state, _c, _r, _n, direction = SHEETS[stem]
        # The hero is imported UPRIGHT into art/reference/hero_lean/upright/; the lean step below writes art/src.
        dest = HERO_UPRIGHT_DIR if (visual_id == "hero2" and args.out == artlib.SRC_DIR) else args.out
        dest.mkdir(parents=True, exist_ok=True)
        if args.replace:
            for old in dest.glob(f"{visual_id}_{state}{direction}_*.txt"):
                old.unlink()
        names = import_sheet(stem, dest, palette)
        total += len(names)
        hero_sheets += visual_id == "hero2" and dest == HERO_UPRIGHT_DIR
        print(f"{stem}: {len(names)} frames")
    if hero_sheets:
        # Pipeline step: lean the upright hero into the in-game hero2_* frames (approved 2026-10-20).
        import make_hero_lean_sheet
        lean = {st: [make_hero_lean_sheet.build_frame(st, n) for n in range(1, c + 1)] for st, c in make_hero_lean_sheet.STATES}
        print(f"lean step: {make_hero_lean_sheet.install(lean)} hero2_* frames written to art/src "
              "(then run tools/art/import_dagger_sprites.py for the dagger set)")
    wanted = {x for x in args.only.split(",") if x}
    for spec in EXTRA:
        if not wanted or spec[0] in wanted:
            n = import_extra(spec, args.out, palette)
            total += n
            print(f"{spec[0]}: {n} frames")
    if not args.only:
        for stem in TILE_SHEETS:
            print(f"{stem}: {import_tiles(stem, args.out, palette)} tiles")
    print(f"wrote {total} frames to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
