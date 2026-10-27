"""Cut the props out of a prop sheet drawn on a flat magenta background (layered scenes, docs/LAYERED_SCENE_PILOT.md).

Input: a prop sheet PNG (every prop on its own, on #FF00FF, space between them).
Steps: key out the magenta (with the pink fringe of anti-aliased edges), find the props (connected parts, nearby parts
such as a glowing rune are merged), scale each to the world (default: sheet width -> --world-width px), snap it to the
Totoy 36 palette (no reserved gold/red), hard alpha, then work out the prop's base line and its colliders.

Output:
  <out>/<id>.png                 one cut-out per prop, tight to the opaque pixels (review art for Codex, NOT art/src)
  <out>/props_contact.png        every prop on a grey board, base line and colliders marked (for the human's eyes)
  <defs>                         data/props/prop_defs.json, the shared prop data (see docs/architecture.md "Layered
                                 scenes"): per prop id the size, the anchor (base middle, in sprite pixels), the base
                                 width and the colliders [dx, dy, r] relative to the anchor. Core reads it for the
                                 colliders; presentation reads it for the sprite placement. No sprites in core.
An existing entry with "locked": true is kept as it is (hand-tuned colliders survive a re-run). With --merge every
existing entry of the defs file is kept (several sheets, several scenes share data/props/prop_defs.json: the glade's
props are not lost when the village sheet is extracted); without it the file holds only this sheet's props and the
locked ones. --prefix puts a scene's name in front of the default ids (village_01, ...).

Run (project root):  python tools/art/extract_props.py --sheet art/reference/layered_pilot/glade_props_sheet.png
                         [--names a,b,c] [--out DIR] [--defs FILE] [--world-width 560]
Needs Pillow only.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
DEFAULT_OUT = ROOT / "art" / "reference" / "layered_pilot" / "props"
DEFAULT_DEFS = ROOT / "data" / "props" / "prop_defs.json"
KEY = (255, 0, 255)
MERGE_GAP = 4          # px at sheet size: parts closer than this are one prop (a rune glow, a detached leaf)
MIN_AREA = 40          # px at sheet size: smaller specks are dropped
MIN_SIDE = 4           # px at world size: smaller props are dropped
BAND_FRACTION = 0.15   # the base band: this share of the sprite height (2..8 px) above the lowest opaque row
DECOR_HEIGHT = 14      # props lower than this (px) are decor: walkable, no colliders
LIFT = 0.4             # collider centres sit this many radii above the base line
VERSION = 1


# --- keying ---

def is_key(px: tuple[int, int, int], tol: int) -> bool:
    r, g, b = px
    if (r - KEY[0]) ** 2 + (g - KEY[1]) ** 2 + (b - KEY[2]) ** 2 <= tol * tol:
        return True
    return r - g > 90 and b - g > 90 and abs(r - b) < 70


def is_fringe(px: tuple[int, int, int]) -> bool:
    r, g, b = px
    return r - g > 45 and b - g > 45 and abs(r - b) < 90


def opaque_mask(img: Image.Image, tol: int) -> list[list[bool]]:
    w, h = img.size
    px = img.load()
    mask = [[not is_key(px[x, y], tol) for x in range(w)] for y in range(h)]
    # one pass: a pinkish pixel next to the background is the anti-aliased fringe, not the prop
    out = [row[:] for row in mask]
    for y in range(h):
        for x in range(w):
            if not mask[y][x] or not is_fringe(px[x, y]):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or not mask[ny][nx]:
                    out[y][x] = False
                    break
    return out


# --- finding the props ---

def components(mask: list[list[bool]], gap: int = MERGE_GAP) -> list[list[tuple[int, int]]]:
    """Connected parts of the mask, with parts within `gap` px merged (a dilated flood, the pixels stay the prop's own)."""
    h, w = len(mask), len(mask[0])
    near: list[list[bool]] = [[False] * w for _ in range(h)]
    for y in range(h):
        row = mask[y]
        for x in range(w):
            if not row[x]:
                continue
            for yy in range(max(0, y - gap), min(h, y + gap + 1)):
                nrow = near[yy]
                for xx in range(max(0, x - gap), min(w, x + gap + 1)):
                    nrow[xx] = True
    seen = [[False] * w for _ in range(h)]
    found: list[list[tuple[int, int]]] = []
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or not near[y0][x0]:
                continue
            stack = [(x0, y0)]
            seen[y0][x0] = True
            pixels: list[tuple[int, int]] = []
            while stack:
                x, y = stack.pop()
                if mask[y][x]:
                    pixels.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and near[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if len(pixels) >= MIN_AREA:
                found.append(pixels)
    return found


def reading_order(parts: list[list[tuple[int, int]]], row_height: int) -> list[list[tuple[int, int]]]:
    def key(p: list[tuple[int, int]]) -> tuple[int, int]:
        xs = [q[0] for q in p]
        ys = [q[1] for q in p]
        return ((min(ys) + max(ys)) // 2 // row_height, (min(xs) + max(xs)) // 2)
    return sorted(parts, key=key)


# --- colour ---

def _lab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    def lin(c: int) -> float:
        v = c / 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = lin(rgb[0]), lin(rgb[1]), lin(rgb[2])
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


class Snapper:
    def __init__(self, palette: artlib.Palette) -> None:
        self.choices = [(_lab(rgb), rgb) for sym, rgb in palette.by_symbol.items() if sym not in palette.reserved]
        self.cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}

    def snap(self, rgb: tuple[int, int, int]) -> tuple[int, int, int]:
        hit = self.cache.get(rgb)
        if hit is None:
            lab = _lab(rgb)
            hit = min(self.choices, key=lambda c: sum((a - b) ** 2 for a, b in zip(c[0], lab)))[1]
            self.cache[rgb] = hit
        return hit


# --- one prop ---

def cut_out(sheet: Image.Image, pixels: list[tuple[int, int, int]] | list[tuple[int, int]], scale: float,
            snapper: Snapper) -> Image.Image | None:
    """The prop's pixels as an RGBA image at world scale: area-averaged (only the prop's own pixels count), alpha
    thresholded at one half, colours snapped to the palette. None when it ends up smaller than MIN_SIDE."""
    xs = [p[0] for p in pixels]
    ys = [p[1] for p in pixels]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    own = {(x, y) for x, y in pixels}
    w = max(1, round((x1 - x0) * scale))
    h = max(1, round((y1 - y0) * scale))
    src = sheet.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for oy in range(h):
        sy0, sy1 = y0 + oy / scale, y0 + (oy + 1) / scale
        for ox in range(w):
            sx0, sx1 = x0 + ox / scale, x0 + (ox + 1) / scale
            total = 0
            hit = 0
            r = g = b = 0
            for sy in range(int(math.floor(sy0)), max(int(math.floor(sy0)) + 1, int(math.ceil(sy1)))):
                for sx in range(int(math.floor(sx0)), max(int(math.floor(sx0)) + 1, int(math.ceil(sx1)))):
                    total += 1
                    if (sx, sy) in own:
                        c = src[sx, sy]
                        r += c[0]
                        g += c[1]
                        b += c[2]
                        hit += 1
            if hit * 2 >= total and hit > 0:
                rgb = snapper.snap((r // hit, g // hit, b // hit))
                dst[ox, oy] = (rgb[0], rgb[1], rgb[2], 255)
    box = out.getbbox()
    if box is None:
        return None
    out = out.crop(box)
    if out.size[0] < MIN_SIDE or out.size[1] < MIN_SIDE:
        return None
    return out


def base_info(img: Image.Image) -> dict:
    """The base line (the lowest opaque row), the anchor (the middle of the opaque pixels in the base band) and the
    colliders along the band: circles [dx, dy, r] relative to the anchor, none for decor (lower than DECOR_HEIGHT)."""
    w, h = img.size
    alpha = img.getchannel("A").load()
    band = max(2, min(8, round(h * BAND_FRACTION)))
    xs = [x for y in range(h - band, h) for x in range(w) if alpha[x, y]]
    x0, x1 = min(xs), max(xs) + 1
    base_width = x1 - x0
    anchor = [round((x0 + x1) / 2.0, 1), h]
    colliders: list[list[float]] = []
    solid = h >= DECOR_HEIGHT
    if solid:
        radius = min(8.0, max(3.0, round(base_width * 0.22, 1)))
        if base_width <= 2 * radius:
            centres = [(x0 + x1) / 2.0]
        else:
            count = math.ceil((base_width - 2 * radius) / (1.6 * radius)) + 1
            centres = [x0 + radius + (base_width - 2 * radius) * i / (count - 1) for i in range(count)]
        for cx in centres:
            colliders.append([round(cx - anchor[0], 1), round(-radius * LIFT, 1), radius])
    return {"w": w, "h": h, "anchor": anchor, "base_width": base_width, "solid": solid, "colliders": colliders}


# --- the whole sheet ---

def extract(sheet_path: Path, out_dir: Path, defs_path: Path, names: list[str] | None = None, world_width: float = 560.0,
            tol: int = 60, palette: artlib.Palette | None = None, merge: bool = False, prefix: str = "prop") -> dict:
    palette = palette or artlib.load_palette()
    sheet = Image.open(sheet_path).convert("RGB")
    scale = world_width / sheet.size[0]
    mask = opaque_mask(sheet, tol)
    parts = reading_order(components(mask), max(40, sheet.size[1] // 6))
    snapper = Snapper(palette)
    old: dict = {}
    if defs_path.exists():
        old = json.loads(defs_path.read_text(encoding="utf-8")).get("props", {})
    out_dir.mkdir(parents=True, exist_ok=True)
    props: dict[str, dict] = {}
    images: dict[str, Image.Image] = {}
    index = 0
    for part in parts:
        img = cut_out(sheet, part, scale, snapper)
        if img is None:
            continue
        index += 1
        name = names[index - 1] if names and index <= len(names) else f"{prefix}_{index:02d}"
        info = base_info(img)
        if old.get(name, {}).get("locked"):
            info = old[name]
        info["image"] = f"{name}.png"
        props[name] = info
        images[name] = img
        img.save(out_dir / f"{name}.png")
    for name, entry in old.items():
        if (merge or entry.get("locked")) and name not in props:
            props[name] = entry
    data = {"version": VERSION, "sheet": sheet_path.name, "scale": round(scale, 5), "props": props}
    defs_path.parent.mkdir(parents=True, exist_ok=True)
    defs_path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    contact_sheet(images, props, out_dir / "props_contact.png")
    return data


def contact_sheet(images: dict[str, Image.Image], props: dict[str, dict], path: Path, zoom: int = 3) -> None:
    if not images:
        return
    pad = 12
    cell_w = max(i.size[0] for i in images.values()) * zoom + pad
    cols = max(1, min(6, len(images)))
    cell_h = max(i.size[1] for i in images.values()) * zoom + pad + 14
    rows = math.ceil(len(images) / cols)
    board = Image.new("RGB", (cols * cell_w, rows * cell_h), (96, 96, 96))
    draw = ImageDraw.Draw(board)
    for n, (name, img) in enumerate(images.items()):
        ox = (n % cols) * cell_w + pad // 2
        oy = (n // cols) * cell_h + pad // 2 + 12
        big = img.resize((img.size[0] * zoom, img.size[1] * zoom), Image.NEAREST)
        board.paste(big, (ox, oy), big)
        info = props[name]
        ax, ay = ox + info["anchor"][0] * zoom, oy + info["anchor"][1] * zoom
        draw.line([(ox, ay), (ox + img.size[0] * zoom, ay)], fill=(0, 255, 255))
        for dx, dy, r in info["colliders"]:
            cx, cy = ax + dx * zoom, ay + dy * zoom
            draw.ellipse([cx - r * zoom, cy - r * zoom, cx + r * zoom, cy + r * zoom], outline=(255, 160, 0))
        draw.text((ox, oy - 12), name, fill=(255, 255, 255))
    board.save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--defs", type=Path, default=DEFAULT_DEFS)
    parser.add_argument("--names", default="", help="comma separated ids in reading order (top to bottom, left to right)")
    parser.add_argument("--world-width", type=float, default=560.0, help="the scene's width the sheet width maps to")
    parser.add_argument("--merge", action="store_true", help="keep every existing entry of the defs file (another sheet or scene)")
    parser.add_argument("--prefix", default="prop", help="default id prefix for unnamed props (e.g. village)")
    parser.add_argument("--tol", type=int, default=60, help="colour distance from #FF00FF counted as background")
    args = parser.parse_args()
    if not args.sheet.exists():
        print(f"missing sheet: {args.sheet}", file=sys.stderr)
        return 1
    names = [n for n in args.names.split(",") if n] or None
    data = extract(args.sheet, args.out, args.defs, names, args.world_width, args.tol, merge=args.merge, prefix=args.prefix)
    for name, info in data["props"].items():
        print(f"{name:14s} {info['w']:3d}x{info['h']:3d}  anchor {info['anchor']}  base {info['base_width']:3d}  "
              f"{'solid x%d' % len(info['colliders']) if info['solid'] else 'decor'}")
    print(f"{len(data['props'])} props -> {args.defs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
