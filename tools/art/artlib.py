"""Shared helpers for the art pipeline: palette, text-grid parsing, checks, rendering."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PATH = ROOT / "art" / "palette.json"
SRC_DIR = ROOT / "art" / "src"
BUILD_DIR = ROOT / "art" / "build"

TILE_SIZE = 16
SPRITE_STEP = 8  # sprite width/height must be a multiple of this
SPRITE_MAX = 256
VALID_KINDS = ("tile", "sprite")
VALID_KEYS = ("kind", "seamless")
HEADER_RE = re.compile(r"^#\s*([a-z_]+)\s*:\s*(.+?)\s*$")
HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")

RGB = tuple[int, int, int]


class PaletteError(Exception):
    pass


@dataclass
class Palette:
    transparent: str
    by_symbol: dict[str, RGB]
    rgb_set: set[RGB]


def load_palette(path: Path = PALETTE_PATH) -> Palette:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PaletteError(f"cannot read palette {path}: {exc}") from exc
    transparent = data.get("transparent")
    if not isinstance(transparent, str) or len(transparent) != 1:
        raise PaletteError("palette.json: 'transparent' must be a single character")
    by_symbol: dict[str, RGB] = {}
    for entry in data.get("colors", []):
        symbol, hex_value = entry.get("symbol"), entry.get("hex", "")
        if not isinstance(symbol, str) or len(symbol) != 1:
            raise PaletteError(f"palette.json: bad symbol {symbol!r}")
        if symbol == transparent or symbol in by_symbol:
            raise PaletteError(f"palette.json: duplicate or reserved symbol {symbol!r}")
        if not HEX_RE.match(hex_value):
            raise PaletteError(f"palette.json: bad hex {hex_value!r} for symbol {symbol!r}")
        by_symbol[symbol] = (int(hex_value[1:3], 16), int(hex_value[3:5], 16), int(hex_value[5:7], 16))
    if not by_symbol:
        raise PaletteError("palette.json: no colors defined")
    return Palette(transparent, by_symbol, set(by_symbol.values()))


@dataclass
class Sprite:
    name: str
    path: Path
    kind: str = ""
    seamless: bool = False
    rows: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def width(self) -> int:
        return len(self.rows[0]) if self.rows else 0

    @property
    def height(self) -> int:
        return len(self.rows)


def parse_sprite(path: Path) -> Sprite:
    """Parse one text-grid source file. Problems are collected in sprite.errors."""
    sprite = Sprite(name=path.stem, path=path)
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        sprite.errors.append(f"cannot read file: {exc}")
        return sprite
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.rstrip()
        if not line:
            continue
        if line.startswith("#"):
            match = HEADER_RE.match(line)
            if not match:
                continue  # plain comment
            key, value = match.group(1), match.group(2)
            if key not in VALID_KEYS:
                sprite.errors.append(f"line {number}: unknown header '{key}' (allowed: {', '.join(VALID_KEYS)})")
            elif key == "kind":
                sprite.kind = value
            elif key == "seamless":
                if value not in ("true", "false"):
                    sprite.errors.append(f"line {number}: 'seamless' must be true or false")
                sprite.seamless = value == "true"
            continue
        sprite.rows.append(line)
    return sprite


def check_sprite(sprite: Sprite, palette: Palette) -> list[str]:
    """Return every problem found in a parsed sprite (empty list = valid)."""
    errors = list(sprite.errors)
    if sprite.kind not in VALID_KINDS:
        errors.append(f"missing or invalid '# kind:' header (use one of: {', '.join(VALID_KINDS)})")
    if not sprite.rows:
        errors.append("no pixel rows found")
        return errors
    width = sprite.width
    ragged = [i + 1 for i, row in enumerate(sprite.rows) if len(row) != width]
    if ragged:
        errors.append(f"rows are not all {width} wide (first row has width {width}); bad pixel-row numbers: {ragged}")
    allowed = set(palette.by_symbol) | {palette.transparent}
    for y, row in enumerate(sprite.rows):
        for x, ch in enumerate(row):
            if ch not in allowed:
                errors.append(f"off-palette symbol {ch!r} at x={x}, y={y}")
    if errors:
        return errors  # size and seam checks need a clean rectangular grid
    if sprite.kind == "tile":
        if (width, sprite.height) != (TILE_SIZE, TILE_SIZE):
            errors.append(f"tile must be {TILE_SIZE}x{TILE_SIZE}, got {width}x{sprite.height}")
    elif sprite.kind == "sprite":
        if width % SPRITE_STEP or sprite.height % SPRITE_STEP or max(width, sprite.height) > SPRITE_MAX:
            errors.append(
                f"sprite size must be a multiple of {SPRITE_STEP} and at most {SPRITE_MAX}, got {width}x{sprite.height}"
            )
    if sprite.seamless:
        if sprite.kind != "tile":
            errors.append("'seamless: true' is only valid for tiles")
        elif not errors:
            errors.extend(seam_errors(sprite.rows))
    return errors


def seam_errors(rows: list[str]) -> list[str]:
    """Check that tiling the grid does not create a colour contact that never occurs inside it.

    Heuristic: every (unordered) pair of colours that touches across the wrapped edge must also touch
    somewhere inside the tile. This catches hard visible seams, not every possible mismatch.
    """
    height, width = len(rows), len(rows[0])
    inside: set[frozenset[str]] = set()
    for y in range(height):
        for x in range(width):
            if x + 1 < width:
                inside.add(frozenset((rows[y][x], rows[y][x + 1])))
            if y + 1 < height:
                inside.add(frozenset((rows[y][x], rows[y + 1][x])))
    errors: list[str] = []
    for y in range(height):
        a, b = rows[y][width - 1], rows[y][0]
        if frozenset((a, b)) not in inside:
            errors.append(f"seam mismatch at row y={y}: right edge {a!r} meets left edge {b!r}")
    for x in range(width):
        a, b = rows[height - 1][x], rows[0][x]
        if frozenset((a, b)) not in inside:
            errors.append(f"seam mismatch at column x={x}: bottom edge {a!r} meets top edge {b!r}")
    return errors


def check_png(path: Path, palette: Palette) -> list[str]:
    """Check a built PNG: only fully opaque palette colours or fully transparent pixels."""
    try:
        image = Image.open(path).convert("RGBA")
    except Exception as exc:  # noqa: BLE001 - any decode failure is a validation error
        return [f"cannot open PNG: {exc}"]
    partial = off_palette = 0
    first_partial = first_off = None
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.getpixel((x, y))
            if a == 0:
                continue
            if a != 255:
                partial += 1
                first_partial = first_partial or (x, y, a)
            elif (r, g, b) not in palette.rgb_set:
                off_palette += 1
                first_off = first_off or (x, y, (r, g, b))
    errors: list[str] = []
    if partial:
        errors.append(f"{partial} partially transparent pixel(s); first at x={first_partial[0]}, y={first_partial[1]} alpha={first_partial[2]}")
    if off_palette:
        errors.append(f"{off_palette} off-palette pixel(s); first at x={first_off[0]}, y={first_off[1]} rgb={first_off[2]}")
    return errors


def collect(src_dir: Path, palette: Palette) -> tuple[list[Sprite], list[str]]:
    """Parse and check every .txt grid in src_dir. Returns (sprites, error lines)."""
    sprites: list[Sprite] = []
    errors: list[str] = []
    seen: dict[str, Path] = {}
    for path in sorted(src_dir.glob("*.txt")):
        sprite = parse_sprite(path)
        if sprite.name in seen:
            errors.append(f"{path.name}: duplicate sprite name (also {seen[sprite.name].name})")
        seen[sprite.name] = path
        for message in check_sprite(sprite, palette):
            errors.append(f"{path.name}: {message}")
        sprites.append(sprite)
    if not sprites:
        errors.append(f"no .txt sprite sources found in {src_dir}")
    return sprites, errors


def render(sprite: Sprite, palette: Palette) -> Image.Image:
    """Render a valid sprite to an RGBA image."""
    image = Image.new("RGBA", (sprite.width, sprite.height), (0, 0, 0, 0))
    for y, row in enumerate(sprite.rows):
        for x, ch in enumerate(row):
            if ch != palette.transparent:
                r, g, b = palette.by_symbol[ch]
                image.putpixel((x, y), (r, g, b, 255))
    return image
