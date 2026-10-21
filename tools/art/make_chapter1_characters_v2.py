"""Chapter 1 characters v2: NPC sprites, interactables, portraits and the dialogue UI, converted from the two target
images the human supplied (review only: nothing is wired in, nothing is written to art/src or art/build).

Sources (both in art/reference/):
  chapter1_cast_target.png            the cast sheet: Mira, Tovan, Edda (3 poses each), the villagers (Elder, Child,
                                      Worker) and the interactables (Training Dummy, Old Chest, Healing Herbs, Lantern)
  chapter1_dialogue_scene_target.png  the village scene with the dialogue box: Mira's painted portrait and the frame look

Pipeline for every cut-out (all Pillow, no numpy, deterministic):
  1. crop a generous box around the figure; the flat dark panel and the drop shadow are flood-filled from the crop
     border (a pixel is background when it is close to the measured panel colour, or a darker teal-tinted shadow);
     small loose blobs are dropped, so the cut-out has hard alpha;
  2. Lanczos downscale with premultiplied alpha by ONE scale for every character (SCALE source px per game px, so the
     relative sizes of the cast sheet are kept: the hero is about 34 px there and here);
  3. a nearest-colour snap in Lab with lightness weighting to Totoy 36 without the reserved gold/red (x, y, z, A);
  4. cleanup: lone pixels whose neighbours agree take the neighbours' colour; a 1 px ink outline on the silhouette
     edge where the edge pixel is lighter than the ink (like tools/art/import_reference.py).

Animation is built from the 3 poses with small procedural edits (rows shifted for breathing and bob, the leg block
split and shifted for the walk, eye pixels closed for the blink); see build_npcs().

Usage (from the project root):
  python tools/art/make_chapter1_characters_v2.py                     everything into art/reference/chapter1_characters_v2/
  python tools/art/make_chapter1_characters_v2.py --portrait NAME PATH convert one painted portrait (PNG/JPG; the
        portrait window or a square bust on a flat dark background) into portrait_<NAME>_neutral at 64x64 (plus 80
        and 96 previews) and add it to portraits_v2.png/.json (re-runs the portrait atlas only)
  python tools/art/make_chapter1_characters_v2.py --dev DIR            debug cut-outs into DIR
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from import_reference import srgb_to_lab  # noqa: E402

ROOT = artlib.ROOT
REF = ROOT / "art" / "reference"
CAST = REF / "chapter1_cast_target.png"
SCENE = REF / "chapter1_dialogue_scene_target.png"
OUT = REF / "chapter1_characters_v2"
PAL = artlib.load_palette()
T = "."
FORBIDDEN = set(PAL.reserved)
PIXEL_FONT = ROOT / "presentation" / "fonts" / "PixelifySans.ttf"
NAME_FONT = ROOT / "presentation" / "fonts" / "Cinzel.ttf"
SCALE = 2.5  # source px per game px for every cut-out from the cast sheet

Grid = list  # list[list[str]]


# ---------------------------------------------------------------------------------------------------------------- utils

def rgb(c: str) -> tuple[int, int, int]:
    return PAL.by_symbol[c]


def blank(w: int, h: int, c: str = T) -> Grid:
    return [[c] * w for _ in range(h)]


def copy(g: Grid) -> Grid:
    return [r[:] for r in g]


def mirror(g: Grid) -> Grid:
    return [r[::-1] for r in g]


def to_image(g: Grid) -> Image.Image:
    h, w = len(g), len(g[0])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(h):
        for x in range(w):
            c = g[y][x]
            if c != T:
                assert c not in FORBIDDEN, f"reserved colour {c} used"
                px[x, y] = rgb(c) + (255,)
    return im


def paste(dst: Grid, src: Grid, ox: int, oy: int) -> None:
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c != T and 0 <= y + oy < len(dst) and 0 <= x + ox < len(dst[0]):
                dst[y + oy][x + ox] = c


def bbox(g: Grid) -> tuple[int, int, int, int] | None:
    ys = [y for y, r in enumerate(g) if any(c != T for c in r)]
    xs = [x for x in range(len(g[0])) if any(r[x] != T for r in g)]
    if not ys:
        return None
    return xs[0], ys[0], xs[-1] + 1, ys[-1] + 1


def trim(g: Grid) -> Grid:
    b = bbox(g)
    if b is None:
        return g
    x0, y0, x1, y1 = b
    return [r[x0:x1] for r in g[y0:y1]]


LAB = {s: srgb_to_lab(c) for s, c in PAL.by_symbol.items()}


def lightness(c: str) -> float:
    return LAB[c][0]


class Snapper:
    """Nearest palette colour in Lab, lightness weighted, reserved colours excluded (and `exclude`)."""

    def __init__(self, lightness_weight: float = 1.6, exclude: str = "") -> None:
        self.w = lightness_weight
        self.choices = [(s, LAB[s]) for s in PAL.by_symbol if s not in FORBIDDEN and s not in exclude]
        self.cache: dict[tuple[int, int, int], str] = {}

    def __call__(self, c: tuple[int, int, int]) -> str:
        hit = self.cache.get(c)
        if hit is None:
            lab = srgb_to_lab(c)
            hit = min(self.choices, key=lambda k: (k[1][0] - lab[0]) ** 2 * self.w + (k[1][1] - lab[1]) ** 2 + (k[1][2] - lab[2]) ** 2)[0]
            self.cache[c] = hit
        return hit


# --------------------------------------------------------------------------------------------------- cut-out pipeline

def border_bg(img: Image.Image) -> tuple[int, int, int]:
    px = img.load()
    w, h = img.size
    pts = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)] + [px[0, y] for y in range(h)] + [px[w - 1, y] for y in range(h)]
    return tuple(sorted(p[i] for p in pts)[len(pts) // 2] for i in range(3))  # type: ignore[return-value]


def is_bg(p: tuple[int, int, int], bg: tuple[int, int, int]) -> bool:
    r, g, b = p
    if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) <= 24:
        return True
    lum = (r + g + b) / 3
    # the drop shadow and the panel's darker corners: the panel's teal tint, darker
    if g - r >= 4 and b - r >= 2 and lum <= sum(bg) / 3 + 6 and lum >= 9 and max(g - r, b - r) <= 22:
        return True
    return False


def glow_step(p: tuple[int, int, int], prev: tuple[int, int, int], tol: int) -> bool:
    """Region growing through a soft light halo: small steps from the previous halo pixel, never into ink."""
    if max(p) < 26 or sum(p) / 3 > 150:
        return False
    r, g, b = p
    if r < 50 and g - r >= 18 and b - r >= 16 and (r + g + b) / 3 < 90:
        return True  # the cyan halo around Edda's staff flame
    return abs(p[0] - prev[0]) + abs(p[1] - prev[1]) + abs(p[2] - prev[2]) <= tol


def cutout(src: Image.Image, box: tuple[int, int, int, int], glow: int = 0, min_blob: int = 40,
           erase: list[tuple[int, int, int, int]] | None = None) -> tuple[Image.Image, Image.Image]:
    """Crop and return (rgb, hard mask): background flood-filled from the crop border. glow > 0 also grows through
    a soft halo (step tolerance = glow) such as the lantern light or Edda's staff flame."""
    img = src.crop(box).convert("RGB")
    px = img.load()
    w, h = img.size
    bg = border_bg(img)
    for ex in erase or []:  # rectangles (crop coords) that are background no matter what (neighbours, labels)
        for y in range(ex[1], ex[3]):
            for x in range(ex[0], ex[2]):
                px[x, y] = bg
    seen = bytearray(w * h)
    stack = [(x, y, bg) for x in range(w) for y in (0, h - 1)] + [(x, y, bg) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y, prev = stack.pop()
        i = y * w + x
        p = px[x, y]
        if seen[i] or not (is_bg(p, bg) or (glow and glow_step(p, prev, glow))):
            continue
        seen[i] = 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                stack.append((nx, ny, p))
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            if not seen[y * w + x]:
                mp[x, y] = 255
    # drop loose specks (JPEG fringe), then small blobs
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    mp = mask.load()
    seen2 = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            if seen2[sy * w + sx] or mp[sx, sy] == 0:
                continue
            blob, st = [], [(sx, sy)]
            seen2[sy * w + sx] = 1
            while st:
                x, y = st.pop()
                blob.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen2[ny * w + nx] and mp[nx, ny]:
                            seen2[ny * w + nx] = 1
                            st.append((nx, ny))
            if len(blob) < min_blob:
                for x, y in blob:
                    mp[x, y] = 0
    return img, mask


def downscale(img: Image.Image, mask: Image.Image, scale: float, size: tuple[int, int] | None = None,
              resample: int = Image.LANCZOS) -> tuple[Image.Image, Image.Image]:
    w, h = size or (max(1, round(img.width / scale)), max(1, round(img.height / scale)))
    rgba = img.convert("RGBA")
    rgba.putalpha(mask)
    # premultiplied: RGBa
    pre = rgba.convert("RGBa").resize((w, h), resample)
    small = pre.convert("RGBA")
    a = small.getchannel("A")
    return small.convert("RGB"), a


def snap_grid(small: Image.Image, alpha: Image.Image, snapper: Snapper, threshold: int = 110) -> Grid:
    w, h = small.size
    sp, ap = small.load(), alpha.load()
    g = blank(w, h)
    for y in range(h):
        for x in range(w):
            if ap[x, y] >= threshold:
                g[y][x] = snapper(sp[x, y])
    return g


def neighbours(g: Grid, x: int, y: int, diag: bool = True) -> list[str]:
    h, w = len(g), len(g[0])
    out = []
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if (dx or dy) and (diag or not (dx and dy)):
                nx, ny = x + dx, y + dy
                out.append(g[ny][nx] if 0 <= nx < w and 0 <= ny < h else T)
    return out


def cleanup(g: Grid, keep: str = "", passes: int = 1, agree: int = 5) -> Grid:
    """Lone opaque pixels whose 8 neighbours mostly agree take that colour (keeps symbols in `keep`)."""
    h, w = len(g), len(g[0])
    for _ in range(passes):
        out = copy(g)
        for y in range(h):
            for x in range(w):
                c = g[y][x]
                if c == T or c in keep:
                    continue
                nb = neighbours(g, x, y)
                if nb.count(c) <= 1:
                    counts: dict[str, int] = {}
                    for n in nb:
                        if n != T:
                            counts[n] = counts.get(n, 0) + 1
                    if counts:
                        best, n = max(counts.items(), key=lambda kv: (kv[1], -lightness(kv[0])))
                        if n >= agree:
                            out[y][x] = best
        g = out
    return g


def reduce_colours(g: Grid, min_share: float = 0.02, keep: str = "") -> Grid:
    """Remap rarely used colours to the nearest (Lab) frequent one: fewer colours per sprite, less speckle."""
    counts: dict[str, int] = {}
    for row in g:
        for c in row:
            if c != T:
                counts[c] = counts.get(c, 0) + 1
    total = sum(counts.values()) or 1
    common = [c for c, n in counts.items() if n / total >= min_share or c in keep or c == "0"]
    remap = {}
    for c in counts:
        if c not in common:
            l = LAB[c]
            remap[c] = min(common, key=lambda k: (LAB[k][0] - l[0]) ** 2 * 1.5 + (LAB[k][1] - l[1]) ** 2 + (LAB[k][2] - l[2]) ** 2)
    return [[remap.get(c, c) for c in row] for row in g]


def smooth(g: Grid, keep: str = "") -> Grid:
    """A pixel that matches at most one of its 4 direct neighbours, while 3 of them agree on another colour,
    takes that colour (kills checker noise and 1 px streaks; keeps ink and the `keep` colours)."""
    h, w = len(g), len(g[0])
    out = copy(g)
    for y in range(h):
        for x in range(w):
            c = g[y][x]
            if c == T or c == "0" or c in keep:
                continue
            nb = [n for n in neighbours(g, x, y, diag=False)]
            if nb.count(c) >= 2 or T in nb:
                continue
            counts: dict[str, int] = {}
            for n in nb:
                counts[n] = counts.get(n, 0) + 1
            best, n = max(counts.items(), key=lambda kv: kv[1])
            if n >= 3 and best != "0" and abs(lightness(best) - lightness(c)) < 30:
                out[y][x] = best
    return out


def despeckle(g: Grid) -> Grid:
    h, w = len(g), len(g[0])
    out = copy(g)
    for y in range(h):
        for x in range(w):
            if g[y][x] != T and sum(1 for n in neighbours(g, x, y) if n != T) <= 1:
                out[y][x] = T
    return out


def fill_pinholes(g: Grid) -> Grid:
    """Transparent pixels enclosed on 4 sides get the darkest neighbour (no holes inside the figure)."""
    h, w = len(g), len(g[0])
    out = copy(g)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if g[y][x] == T:
                nb = [g[y - 1][x], g[y + 1][x], g[y][x - 1], g[y][x + 1]]
                if all(n != T for n in nb):
                    out[y][x] = min(nb, key=lightness)
    return out


def outline(g: Grid, ink: str = "0", margin: float = 12.0) -> Grid:
    """1 px ink on the silhouette edge (inside), where the edge pixel is lighter than the ink."""
    h, w = len(g), len(g[0])
    out = copy(g)
    li = lightness(ink)
    for y in range(h):
        for x in range(w):
            c = g[y][x]
            if c == T:
                continue
            if any(n == T for n in neighbours(g, x, y, diag=False)) and lightness(c) > li + margin:
                out[y][x] = ink
    return out


def pad(g: Grid, w: int, h: int, ax: int, ay: int, fx: int, fy: int) -> Grid:
    """Place g into a w x h cell so that g's point (fx, fy) lands on (ax, ay)."""
    cell = blank(w, h)
    paste(cell, g, ax - fx, ay - fy)
    return cell


def feet(g: Grid) -> tuple[int, int]:
    """(x, y) of the ground point: centre of the opaque pixels in the lowest 3 rows, one row under the soles."""
    b = bbox(g)
    assert b is not None
    _, _, _, y1 = b
    xs = [x for y in range(max(0, y1 - 3), y1) for x, c in enumerate(g[y]) if c != T]
    return round(sum(xs) / len(xs)), y1


def prepare(img: Image.Image, contrast: float = 1.25, color: float = 1.35, sharpen: int = 150) -> Image.Image:
    """Sharpen the soft source a little and lift contrast and saturation, so the palette snap keeps the hues
    (without it the sage coats and teal scarves fall into the brown and stone ramps)."""
    if sharpen:
        img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=sharpen, threshold=2))
    img = ImageEnhance.Contrast(img).enhance(contrast)
    return ImageEnhance.Color(img).enhance(color)


def convert(src: Image.Image, box: tuple[int, int, int, int], scale: float = SCALE, glow: int = 0,
            keep: str = "", threshold: int = 110, lw: float = 1.0, erase=None, ol: bool = True, clean_passes: int = 1,
            contrast: float = 1.25, color: float = 1.35) -> Grid:
    return convert_full(src, box, scale, glow, keep, threshold, lw, erase, ol, clean_passes, contrast, color)[0]


SKIN = set("qrs")


def is_skin(p: tuple[int, int, int]) -> bool:
    r, g, b = p
    return r > 110 and r > g + 12 and g > b and r - b > 35


def source_eyes(img: Image.Image, mask: Image.Image) -> list[tuple[float, float]]:
    """Eye pixels of the SOURCE face: dark pixels inside the face (skin on both sides within 3 px and skin below
    within 3 px), in the top third of the figure. Returned in source crop coordinates (pixel centres)."""
    b = mask.getbbox()
    if b is None:
        return []
    px, mp = img.load(), mask.load()
    x0, y0, x1, y1 = b
    head_h = (y1 - y0) // 3
    pts = []
    for y in range(y0, y0 + head_h):
        for x in range(x0 + 1, x1 - 1):
            p = px[x, y]
            if sum(p) / 3 > 75 or not mp[x, y]:
                continue
            left = any(is_skin(px[x - d, y]) for d in (1, 2, 3) if x - d >= 0)
            right = any(is_skin(px[x + d, y]) for d in (1, 2, 3) if x + d < img.width)
            below = any(is_skin(px[x, y + d]) for d in (1, 2, 3) if y + d < img.height)
            if left and right and below:
                pts.append((x + 0.5, y + 0.5))
    return pts


def convert_full(src: Image.Image, box: tuple[int, int, int, int], scale: float = SCALE, glow: int = 0,
                 keep: str = "", threshold: int = 110, lw: float = 1.0, erase=None, ol: bool = True,
                 clean_passes: int = 1, contrast: float = 1.25, color: float = 1.35,
                 eyes: bool = True) -> tuple[Grid, list[tuple[int, int]]]:
    """The cut-out pipeline. Returns the trimmed grid and the eye pixels (grid coords). The eyes are re-stamped
    from the source: the downscale averages the 1-2 px dark eyes of the cast sheet into the skin, so the pixels
    where the source has its eyes get the ink colour back (a derivation from the supplied art, not a redraw)."""
    img, mask = cutout(src, box, glow=glow, erase=erase)
    small, a = downscale(prepare(img, contrast, color), mask, scale)
    g = snap_grid(small, a, Snapper(lw), threshold)
    g = despeckle(g)
    g = fill_pinholes(g)
    g = reduce_colours(g, keep=keep)
    g = cleanup(g, keep=keep, passes=clean_passes)
    g = smooth(g, keep=keep)
    eye_px: list[tuple[int, int]] = []
    if eyes:
        sx, sy = img.width / len(g[0]), img.height / len(g)
        hits: dict[tuple[int, int], int] = {}
        for x, y in source_eyes(img, mask):
            k = (int(x / sx), int(y / sy))
            hits[k] = hits.get(k, 0) + 1
        # at most two eye pixels on one row: the two best supported, at least 2 px apart
        if hits:
            row = max(sorted({k[1] for k in hits}), key=lambda r: sum(n for k, n in hits.items() if k[1] == r))
            cand = sorted((k for k in hits if k[1] == row), key=lambda k: (-hits[k], k))
            for k in cand:
                if all(abs(k[0] - e[0]) >= 2 for e in eye_px) and len(eye_px) < 2 and g[k[1]][k[0]] in SKIN | set("9ab8"):
                    eye_px.append(k)
        for x, y in eye_px:
            g[y][x] = "0"
    if ol:
        g = outline(g)
    b = bbox(g)
    assert b is not None
    return trim(g), [(x - b[0], y - b[1]) for x, y in eye_px]


# --------------------------------------------------------------------------------------------------------- the cast

# crop boxes in chapter1_cast_target.png (x0, y0, x1, y1), measured on 4x zooms of the sheet. `erase` boxes are
# relative to the crop and blank out neighbours that reach into it.
POSES: dict[str, list[dict]] = {
    "mira": [
        {"box": (236, 42, 280, 124), "keep": "tu"},
        {"box": (280, 42, 326, 124), "keep": "tu"},
        {"box": (322, 42, 378, 124), "keep": "tu"},
    ],
    "tovan": [
        {"box": (378, 42, 434, 124)},
        {"box": (434, 42, 484, 124)},
        {"box": (484, 42, 546, 124)},
    ],
    "edda": [
        {"box": (546, 44, 592, 124), "keep": "ij"},
        {"box": (592, 44, 640, 124), "glow": 20, "keep": "ijtuop"},
        {"box": (640, 44, 694, 124), "glow": 20, "keep": "ijtuop"},
    ],
    "elder": [{"box": (20, 170, 68, 252), "keep": "ij1"}],
    "child": [{"box": (100, 180, 136, 252)}],
    "worker": [{"box": (172, 170, 224, 252)}],
}

OBJECTS: dict[str, dict] = {
    "dummy": {"box": (256, 166, 320, 252)},
    "chest_closed": {"box": (354, 186, 418, 248)},
    "chest_open": {"box": (418, 178, 490, 248)},
    "herbs": {"box": (504, 180, 574, 250), "keep": "1nop"},
    "lantern_hanging": {"box": (594, 176, 628, 250), "glow": 10, "keep": "1d"},
    "lantern_post": {"box": (626, 170, 676, 252), "glow": 10, "keep": "1d"},
}


# ------------------------------------------------------------------------------------------------- NPC animation
# Every frame is DERIVED from the converted cast poses (rows shifted, the leg block split and nudged, eye pixels
# closed, the staff fragment brightened). No part of a character is redrawn.

CELL_W, CELL_H = 32, 40
ANCHOR = (16, 37)  # feet: ax = centre of the soles, ay = one row under the soles (the hero uses the same rule)

# which cast pose drives which state, and the small rig numbers: `hip` = rows from the top of the figure where the
# legs start (walk split, breathing hinge), `legs` = x range around the feet centre that the walk moves,
# `hand` = columns right of the feet centre that rise on the talk gesture (None = no hand move)
RIG: dict[str, dict] = {
    "mira": {"idle": 0, "walk": 0, "talk": 2, "extra": {"compass": 1}, "hip": 19, "legs": (-6, 5), "hand": 4},
    "tovan": {"idle": 0, "walk": 0, "talk": 1, "extra": {"anvil": 2}, "hip": 19, "legs": (-7, 7), "hand": None},
    "edda": {"idle": 1, "walk": 1, "talk": 2, "extra": {"cane": 0}, "hip": 19, "legs": (-6, 3), "hand": None,
             "flame": True},
    "elder": {"idle": 0, "walk": 0, "hip": 17, "legs": (-6, 4)},
    "child": {"idle": 0, "walk": 0, "hip": 13, "legs": (-4, 4)},
    "worker": {"idle": 0, "walk": 0, "hip": 18, "legs": (-6, 4)},
}
TICKS = {"idle": [24, 14, 14, 8], "walk": [7, 7, 7, 7, 7, 7], "talk": [10, 8, 10]}
BRIGHTER = {"t": "u", "u": "o", "o": "p", "b": "c", "c": "d", "d": "1", "6": "7", "7": "1", "j": "1"}
DIMMER = {"p": "o", "o": "u", "u": "t", "1": "d", "d": "c", "c": "b", "7": "6"}


class Pose:
    """One converted cast pose placed in a 32x40 cell at the feet anchor, with its eye pixels."""

    def __init__(self, grid: Grid, eyes: list[tuple[int, int]]) -> None:
        fx, fy = feet(grid)
        ox, oy = ANCHOR[0] - fx, ANCHOR[1] - fy
        self.grid = pad(grid, CELL_W, CELL_H, ANCHOR[0], ANCHOR[1], fx, fy)
        self.eyes = [(x + ox, y + oy) for x, y in eyes]
        b = bbox(self.grid)
        assert b is not None
        self.top = b[1]

    def mouth(self) -> list[tuple[int, int]]:
        """One pixel under the gap between the eyes, two rows down (only used if it is skin)."""
        if not self.eyes:
            return []
        x = round(sum(e[0] for e in self.eyes) / len(self.eyes)) + (1 if len(self.eyes) == 1 else 0)
        y = self.eyes[0][1] + 2
        return [(x, y)] if self.grid[y][x] in SKIN else []


def shift_rows(g: Grid, y0: int, y1: int, dy: int, x0: int = 0, x1: int | None = None) -> Grid:
    """Move the block of rows [y0, y1) (columns [x0, x1)) by dy; uncovered pixels become transparent."""
    x1 = len(g[0]) if x1 is None else x1
    out = copy(g)
    block = [[g[y][x] for x in range(x0, x1)] for y in range(y0, y1)]
    for y in range(y0, y1):
        for x in range(x0, x1):
            out[y][x] = T
    for i, row in enumerate(block):
        ty = y0 + i + dy
        if 0 <= ty < len(g):
            for j, c in enumerate(row):
                if c != T:
                    out[ty][x0 + j] = c
    return out


def body_bob(g: Grid, hip: int, dy: int) -> Grid:
    """Upper body (everything above the hip row) moves dy; with dy=1 the hip row is covered (breathing in)."""
    if dy == 0:
        return copy(g)
    top = bbox(g)[1]  # type: ignore[index]
    out = shift_rows(g, top, hip, dy)
    if dy < 0:  # rising: fill the gap at the hip with the row under it
        for x in range(len(g[0])):
            if out[hip - 1][x] == T and g[hip][x] != T and g[hip - 1][x] != T:
                out[hip - 1][x] = g[hip][x]
    return out


def walk_legs(g: Grid, hip: int, legs: tuple[int, int], back: tuple[int, int], front: tuple[int, int]) -> Grid:
    """Split the leg block at the feet centre: the back (left) half moves by `back`, the front half by `front`."""
    cx = ANCHOR[0]
    x0, x1 = cx + legs[0], cx + legs[1] + 1
    out = copy(g)
    left = [[g[y][x] if x < cx else T for x in range(x0, x1)] for y in range(hip, CELL_H)]
    right = [[g[y][x] if x >= cx else T for x in range(x0, x1)] for y in range(hip, CELL_H)]
    for y in range(hip, CELL_H):
        for x in range(x0, x1):
            out[y][x] = T
    for part, (dx, dy) in ((left, back), (right, front)):
        for i, row in enumerate(part):
            for j, c in enumerate(row):
                ty, tx = hip + i + dy, x0 + j + dx
                if c != T and hip <= ty < CELL_H and 0 <= tx < CELL_W:
                    out[ty][tx] = c
    for x in range(x0, x1):  # close the 1 px gap a lifted leg leaves under the hip
        if out[hip][x] == T and g[hip][x] != T:
            out[hip][x] = g[hip][x]
    return out


def set_px(g: Grid, pts: list[tuple[int, int]], c: str) -> Grid:
    out = copy(g)
    for x, y in pts:
        if 0 <= y < len(g) and 0 <= x < len(g[0]) and out[y][x] != T:
            out[y][x] = c
    return out


def lid_colour(g: Grid, x: int, y: int) -> str:
    """The skin colour around an eye (for the blink)."""
    nb = [n for n in neighbours(g, x, y) if n in SKIN]
    return max(sorted(set(nb)), key=nb.count) if nb else "r"


def recolour(g: Grid, table: dict[str, str], y0: int = 0, y1: int | None = None, x0: int = 0) -> Grid:
    out = copy(g)
    for y in range(y0, len(g) if y1 is None else y1):
        for x in range(x0, len(g[0])):
            out[y][x] = table.get(g[y][x], g[y][x])
    return out


def load_poses(src: Image.Image) -> dict[str, list[Pose]]:
    poses: dict[str, list[Pose]] = {}
    for name, plist in POSES.items():
        poses[name] = []
        for p in plist:
            g, eyes = convert_full(src, p["box"], glow=p.get("glow", 0), erase=p.get("erase"), keep=p.get("keep", ""))
            poses[name].append(Pose(g, eyes))
    return poses


def build_npcs(poses: dict[str, list[Pose]]) -> dict[str, dict[str, list[Grid]]]:
    """name -> state -> frames (32x40 cells, anchor ANCHOR)."""
    out: dict[str, dict[str, list[Grid]]] = {}
    for name, rig in RIG.items():
        P = poses[name]
        idle = P[rig["idle"]]
        hip = idle.top + rig["hip"]
        st: dict[str, list[Grid]] = {}
        g = idle.grid
        breathe = body_bob(g, hip, 1)
        blink = copy(g)
        for x, y in idle.eyes:
            blink[y][x] = lid_colour(g, x, y)
        if rig.get("flame"):  # Edda's staff fragment glows on the breath
            breathe = recolour(breathe, BRIGHTER, 0, idle.top + 10, ANCHOR[0] + 3)
        st["idle"] = [g, breathe, breathe, blink]
        w = P[rig["walk"]].grid
        L = rig["legs"]
        st["walk"] = [despeckle(outline(f)) for f in (
            body_bob(walk_legs(w, hip, L, (-1, 0), (1, 0)), hip, 0),   # contact: front foot ahead
            body_bob(walk_legs(w, hip, L, (0, 0), (0, 0)), hip, 1),    # down
            body_bob(walk_legs(w, hip, L, (1, 0), (0, -1)), hip, -1),  # passing: front foot lifted, body up
            body_bob(walk_legs(w, hip, L, (1, 0), (-1, 0)), hip, 0),   # contact: back foot ahead
            body_bob(walk_legs(w, hip, L, (0, 0), (0, 0)), hip, 1),    # down
            body_bob(walk_legs(w, hip, L, (0, -1), (1, 0)), hip, -1),  # passing: back foot lifted
        )]
        if "talk" in rig:
            t = P[rig["talk"]]
            open_ = set_px(t.grid, t.mouth(), "8")
            if rig.get("hand") is not None:
                raised = shift_rows(open_, t.top + 8, hip, -1, ANCHOR[0] + rig["hand"], CELL_W)
            elif rig.get("flame"):
                raised = recolour(open_, BRIGHTER, 0, t.top + 12, ANCHOR[0] + 3)
            else:
                raised = body_bob(open_, hip, 1)
            st["talk"] = [t.grid, open_, outline(raised)]
        for label, i in rig.get("extra", {}).items():
            st[label] = [P[i].grid]
        out[name] = st
    return out


# --------------------------------------------------------------------------------------------------- interactables

def shift_cols(g: Grid, y0: int, y1: int, dx: int) -> Grid:
    out = copy(g)
    for y in range(y0, y1):
        row = g[y]
        out[y] = ([T] * dx + row[:len(row) - dx]) if dx > 0 else (row[-dx:] + [T] * (-dx))
    return out


def build_objects(src: Image.Image) -> dict[str, tuple[Grid, tuple[int, int]]]:
    """obj name -> (grid in a cell with sides a multiple of 8, anchor = bottom centre)."""
    out: dict[str, tuple[Grid, tuple[int, int]]] = {}
    for name, p in OBJECTS.items():
        g = convert(src, p["box"], glow=p.get("glow", 0), erase=p.get("erase"), keep=p.get("keep", ""))
        h, w = len(g), len(g[0])
        cw, ch = -(-(w + 2) // 8) * 8, -(-(h + 2) // 8) * 8
        ax, ay = cw // 2, ch - 1
        cell = pad(g, cw, ch, ax, ay, w // 2, h)
        if name.startswith("lantern"):
            base = "lantern" if name == "lantern_hanging" else "lantern_post"
            frames = [cell, recolour(cell, BRIGHTER), cell, recolour(cell, DIMMER)]
            for i, f in enumerate(frames):
                out[f"obj_{base}_{i + 1}"] = (f, (ax, ay))
        elif name == "dummy":
            out["obj_dummy_1"] = (cell, (ax, ay))
            top = bbox(cell)[1]  # type: ignore[index]
            for i, dx in enumerate((1, -1)):  # hit wobble: the upper part leans 1 px back, then forward
                out[f"obj_dummy_hit_{i + 1}"] = (outline(shift_cols(cell, top, top + 14, dx)), (ax, ay))
        else:
            out[f"obj_{name}_1"] = (cell, (ax, ay))
    return out


# ----------------------------------------------------------------------------------------------------- portraits
# All portraits are SUPPLIED by the human as painted pixel art and converted here at their native 88x88:
#   mira                    the portrait window of chapter1_dialogue_scene_target.png (89x89 inside the teal line and its dark inner edge)
#   totoy tovan edda elder child worker   the six 88x88 panels of chapter1_portraits_target.png (a plot screenshot:
#                           panels magnified 216/88 = 2.4545x; the axes, ticks and titles are cropped away)
#   edda_staff              chapter1_portrait_edda_staff_target.png (one panel, 194x203 magnified, slightly stretched)
# The rectangles are the panel INTERIORS, measured on the black axis spines (spine + 1 .. spine - 1).

PORTRAIT = 88
PORTRAIT_CONTRAST = 1.35  # spreads the narrow painted skin range over the q/r/s ramp
PORTRAITS_SHEET = REF / "chapter1_portraits_target.png"
EDDA_STAFF = REF / "chapter1_portrait_edda_staff_target.png"
NO_GREEN = "567"  # the light grass greens: stray specks on skin for the characters that wear no green
PORTRAIT_SOURCES: dict[str, tuple[Path, tuple[int, int, int, int], dict]] = {
    "mira": (SCENE, (146, 287, 235, 376), {"exclude": NO_GREEN}),
    "totoy": (PORTRAITS_SHEET, (51, 20, 267, 236), {"step": 9, "far": 48, "teal": True, "exclude": NO_GREEN}),  # dark hair close to the panel
    "tovan": (PORTRAITS_SHEET, (303, 20, 519, 236), {"exclude": NO_GREEN}),
    "edda": (PORTRAITS_SHEET, (555, 20, 771, 236), {}),
    "elder": (PORTRAITS_SHEET, (51, 283, 267, 499), {"erase_top": 3}),
    "child": (PORTRAITS_SHEET, (303, 283, 519, 499), {"exclude": NO_GREEN}),
    "worker": (PORTRAITS_SHEET, (555, 283, 771, 499), {}),
    "edda_staff": (EDDA_STAFF, (12, 28, 206, 231), {"keep": "tuop", "halo": True}),
}


def portrait_outline(g: Grid, ink: str = "0") -> Grid:
    """Ink on the silhouette edge against the transparent background (the image border does not count)."""
    h, w = len(g), len(g[0])
    out = copy(g)
    li = lightness(ink)
    for y in range(h):
        for x in range(w):
            c = g[y][x]
            if c == T:
                continue
            edge = any(0 <= x + dx < w and 0 <= y + dy < h and g[y + dy][x + dx] == T for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge and lightness(c) > li + 12:
                out[y][x] = ink
    return out


def portrait_mask(img: Image.Image, erase_top: int = 0, step_tol: int = 9, far: int = 40, halo: bool = False, teal: bool = False) -> Image.Image:
    """Background of the portrait panel: flood from the top and side borders (not the bottom: the bust is cut
    there) over pixels close to the panel colour."""
    px = img.load()
    w, h = img.size
    top = [px[x, min(h - 1, erase_top + 1)] for x in range(w)] + [px[0, y] for y in range(h // 2)] + [px[w - 1, y] for y in range(h // 2)]
    bg = tuple(sorted(p[i] for p in top)[len(top) // 2] for i in range(3))
    seen = bytearray(w * h)
    stack = [(x, y, bg) for x in range(w) for y in range(0, erase_top + 1)] + [(x, y, bg) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y, prev = stack.pop()
        i = y * w + x
        if seen[i]:
            continue
        p = px[x, y]
        d = abs(p[0] - bg[0]) + abs(p[1] - bg[1]) + abs(p[2] - bg[2])
        step = abs(p[0] - prev[0]) + abs(p[1] - prev[1]) + abs(p[2] - prev[2])
        # the panel is not flat (a lighter glow, JPEG blocks): grow in small steps, never far from its colour
        cyan = halo and p[0] < 55 and p[1] - p[0] >= 18 and p[2] - p[0] >= 16 and sum(p) / 3 < 95
        if teal and p[1] - p[0] < 3 and y >= erase_top:
            continue  # the panel is teal-tinted, Totoy's dark hair is not
        if not (y < erase_top or d <= BG_TOL or (step <= step_tol and d <= far) or cyan):
            continue
        seen[i] = 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                stack.append((nx, ny, p))
    for cx, cy in ((0, 0), (w - 4, 0), (0, h - 4), (w - 4, h - 4)):  # the rounded teal corners of Mira's window
        for y in range(cy, cy + 4):
            for x in range(cx, cx + 4):
                r, g, b = px[x, y]
                if g - r > 25 and b - r > 25 and abs(x - cx - 1.5) + abs(y - cy - 1.5) >= 2:
                    seen[y * w + x] = 1
    m = Image.new("L", (w, h), 255)
    mp = m.load()
    for y in range(h):
        for x in range(w):
            if seen[y * w + x]:
                mp[x, y] = 0
    return m


BG_TOL = 16  # colour distance (sum of channels) to the panel colour; Totoy's dark hair starts at about 20


def convert_portrait(path: Path, rect: tuple[int, int, int, int] | None, size: int = PORTRAIT, keep: str = "",
                     erase_top: int = 0, step_tol: int = 9, far: int = 40, halo: bool = False, teal: bool = False, exclude: str = "") -> Grid:
    """A painted portrait (crop rect, or the whole image) -> size x size hard pixel art, transparent background."""
    img = Image.open(path).convert("RGB")
    if rect is not None:
        img = img.crop(rect)
    # back to the native pixel grid: an area average of each magnified source pixel
    small = img.resize((size, size), Image.BOX if img.width >= size * 2 else Image.LANCZOS)
    m = portrait_mask(small, round(erase_top), step_tol, far, halo, teal)
    small = prepare(small, contrast=PORTRAIT_CONTRAST, color=1.0, sharpen=60)
    g = blank(size, size)
    snap = Snapper(1.2, exclude=exclude)
    sp, mp = small.load(), m.load()
    for y in range(size):
        for x in range(size):
            if mp[x, y]:
                g[y][x] = snap(sp[x, y])
    g = cleanup(g, keep=keep + "0", passes=2, agree=4)
    g = smooth(g, keep=keep)
    # drop loose specks of panel noise that survived the flood
    g = despeckle(g)
    return portrait_outline(g)


def build_portraits() -> dict[str, Grid]:
    out = {}
    for name, (path, rect, opt) in PORTRAIT_SOURCES.items():
        out[name] = convert_portrait(path, rect, keep=opt.get("keep", ""), erase_top=opt.get("erase_top", 0),
                                     step_tol=opt.get("step", 9), far=opt.get("far", 40), halo=opt.get("halo", False), teal=opt.get("teal", False),
                                     exclude=opt.get("exclude", ""))
    return out


# ------------------------------------------------------------------------------------- portrait expressions
# Extra expressions are DERIVED from the supplied neutral portrait by moving or recolouring existing pixels of the
# brows, eyelids and mouth (nothing is redrawn): rects measured on 16x zooms of the converted 88x88 portraits.
# brow rects: (x0, y0, x1, y1, inner side "l"/"r"); eye and mouth rects: (x0, y0, x1, y1). The faces look right,
# so the LEFT brow's inner end is its right side.
FACES: dict[str, dict] = {
    "mira": {"brows": [(36, 26, 50, 30, "r"), (58, 26, 70, 30, "l")], "eyes": [(36, 31, 48, 38), (58, 31, 70, 38)],
             "mouth": (45, 52, 61, 54)},
    # Totoy's brows are hidden under his fringe and headband in the supplied portrait: eyes and mouth only
    "totoy": {"brows": [], "eyes": [(35, 51, 42, 56), (44, 51, 52, 56)], "mouth": (41, 63, 51, 67)},
    "tovan": {"brows": [(40, 33, 51, 36, "r"), (54, 33, 62, 37, "l")], "eyes": [(41, 36, 51, 39), (55, 36, 61, 39)],
              "mouth": (46, 45, 56, 48)},
    "edda": {"brows": [(39, 33, 47, 35, "r"), (52, 33, 59, 35, "l")], "eyes": [(39, 35, 48, 40), (52, 35, 59, 39)],
             "mouth": (41, 47, 51, 50)},
}
EXPRESSIONS = ["neutral", "happy", "worried", "serious"]
FACE_SKIN = set("qrs1d")


def _skin_fill(g: Grid, rect: tuple[int, int, int, int]) -> str:
    x0, y0, x1, y1 = rect[:4]
    counts: dict[str, int] = {}
    for y in range(max(0, y0 - 1), min(len(g), y1 + 1)):
        for x in range(x0, x1):
            c = g[y][x]
            if c in SKIN:
                counts[c] = counts.get(c, 0) + 1
    return max(counts.items(), key=lambda kv: kv[1])[0] if counts else "r"


def _features(g: Grid, rect: tuple[int, int, int, int], dark: float = 45.0, skin: set[str] = FACE_SKIN) -> list[tuple[int, int]]:
    """Pixels of a brow/eye/mouth inside rect: darker than the skin around them."""
    x0, y0, x1, y1 = rect[:4]
    return [(x, y) for y in range(y0, y1) for x in range(x0, x1) if g[y][x] != T and g[y][x] not in skin and lightness(g[y][x]) < dark + 30]


def brow_tilt(g: Grid, rect: tuple, d_inner: int, d_outer: int) -> Grid:
    """Move the brow pixels: the inner end by d_inner rows, the outer end by d_outer, linear in between. A pixel the
    brow leaves takes the colour of the pixel next to the brow on the side it moved away from (the eye socket when
    it rises, the forehead when it drops), so only colours already in that column are used."""
    x0, y0, x1, y1, inner = rect
    pts = _features(g, rect)
    if not pts:
        return g
    out = copy(g)
    span = max(1, x1 - 1 - x0)
    for x in range(x0, x1):
        ys = sorted(y for (px_, y) in pts if px_ == x)
        if not ys:
            continue
        t = (x - x0) / span if inner == "r" else (x1 - 1 - x) / span  # 0 = outer end, 1 = inner end
        dy = round(d_outer + (d_inner - d_outer) * t)
        if dy == 0:
            continue
        cols = {y: g[y][x] for y in ys}
        fill = g[min(len(g) - 1, ys[-1] + 1)][x] if dy < 0 else g[max(0, ys[0] - 1)][x]
        for y in ys:
            out[y][x] = fill
        for y, c in cols.items():
            if 0 <= y + dy < len(g):
                out[y + dy][x] = c
    return out


def squint(g: Grid, rect: tuple, rows: int) -> Grid:
    """Happy eyes: the lowest `rows` rows of each eye column become skin (the cheek pushes the lower lid up)."""
    out = copy(g)
    pts = set(_features(g, rect, dark=70))
    for x in range(rect[0], rect[2]):
        ys = sorted(y for (px_, y) in pts if px_ == x)
        if len(ys) > rows:
            cheek = g[min(len(g) - 1, ys[-1] + 1)][x]  # the pixel under the eye in this column
            if cheek == T or cheek not in FACE_SKIN:
                continue
            for y in ys[-rows:]:
                out[y][x] = cheek
    return out


def lids_down(g: Grid, rect: tuple, rows: int) -> Grid:
    """Serious/tired: the upper lid (the darkest top pixel of each eye column) extends `rows` rows down."""
    out = copy(g)
    pts = set(_features(g, rect, dark=70))
    for x in range(rect[0], rect[2]):
        ys = sorted(y for (px_, y) in pts if px_ == x)
        if len(ys) >= 3:
            lid = min((g[y][x] for y in ys[:2]), key=lightness)
            for y in ys[1:1 + rows]:
                out[y][x] = lid
    return out


def mouth_curve(g: Grid, rect: tuple, dy: int, flat: bool = False) -> Grid:
    """Smile (dy=-1: corners up), frown (dy=+1: corners down) or a flat line, from the existing mouth pixels."""
    pts = _features(g, rect, dark=40, skin=set("rs1d"))  # the lip line (q) is part of the mouth
    if not pts:
        return g
    out = copy(g)
    xs = [p[0] for p in pts]
    xl, xr = min(xs), max(xs)
    mid = round(sum(p[1] for p in pts) / len(pts))
    c = min((g[y][x] for x, y in pts), key=lightness)
    if flat:
        skin = "r" if "r" in _skin_fill(g, rect) + "r" else _skin_fill(g, rect)
        for x, y in pts:
            out[y][x] = skin
        for x in range(xl, xr + 1):
            out[mid][x] = c
        return out
    # the outer parts of the mouth line bend by dy (smile: up, frown: down); one extra pixel continues each corner
    skin = _skin_fill(g, rect)
    cx, half = (xl + xr) / 2, max(1.0, (xr - xl) / 2)
    vals = {p: g[p[1]][p[0]] for p in pts}
    for (x, y) in pts:
        if abs(x - cx) / half > 0.4:
            out[y][x] = skin
    for (x, y), col in vals.items():
        if abs(x - cx) / half > 0.4:
            out[y + dy][x] = col
    for x, sx in ((xl, -1), (xr, 1)):
        ys = [y for (px_, y) in pts if px_ == x]
        if ys:
            out[min(ys) + dy if dy < 0 else max(ys) + dy][x + sx] = c
    return out


def expression(base: Grid, name: str, expr: str) -> Grid:
    f = FACES[name]
    g = copy(base)
    if expr == "neutral":
        return g
    if expr == "happy":
        for e in f["eyes"]:
            g = squint(g, e, 2)
        for b in f["brows"]:
            g = brow_tilt(g, b, -1, -1)
        g = mouth_curve(g, f["mouth"], -1)
    elif expr == "worried":
        for b in f["brows"]:
            g = brow_tilt(g, b, -2, 0)
        g = mouth_curve(g, f["mouth"], 1)
    elif expr == "serious":
        for b in f["brows"]:
            g = brow_tilt(g, b, 2, 0)
        for e in f["eyes"]:
            g = lids_down(g, e, 2)
        g = mouth_curve(g, f["mouth"], 0, flat=True)
    return g


# ---------------------------------------------------------------------------------------------------- dialogue UI
# Rebuilt in the look of the dialogue scene target at game scale (the target is 723x410 for 320x180: x0.44):
# carved stone pillars with a glowing teal rune channel on both sides, a wooden beam top and bottom, a dark text
# inset, a separate portrait socket (dark frame + thin teal line, rounded corners), a stone name plate with a green
# pointer, an ENTER badge, a teal choice chevron, a blinking 'next' arrow and moss overlays for the corners.
# Portraits are 88x88 and are drawn at HALF scale (44 game px; 2 window px per portrait pixel at the default 4x
# window, decision 0004 canvas_items), which is the size the painted portrait has in the target.

BOX_W, BOX_H = 240, 68
PILLAR = 11
CAP = 12           # carved block at the top and bottom of each pillar (9-slice top/bottom margin)
SOCKET = 50        # portrait socket: 44x44 window + 3 px frame
WINDOW = 44
RUNES_L = ["..#/.#./#../.#./..#", "#.#/###/#.#/#.#/#.#", "#.#/##./#.#/#.#/#.#", ".##/#../.#./..#/##."]
RUNES_R = ["##./#.#/##./#../#..", "##./#.#/##./#.#/#.#", "#../.#./..#/.#./#..", "#../##./#.#/##./#.."]
SEED = 20261021


def rect(g: Grid, x: int, y: int, w: int, h: int, c: str) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= yy < len(g) and 0 <= xx < len(g[0]):
                g[yy][xx] = c


def glyph(g: Grid, x: int, y: int, spec: str, core: str = "o", glow: str = "t", hi: str = "p") -> None:
    rows = spec.split("/")
    pts = [(x + i, y + j) for j, r in enumerate(rows) for i, ch in enumerate(r) if ch == "#"]
    for px_, py in pts:  # glow first, strokes over it
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if g[py + dy][px_ + dx] in "0e":
                g[py + dy][px_ + dx] = glow
    for k, (px_, py) in enumerate(pts):
        g[py][px_] = hi if k == len(pts) // 2 else core


def pillar(h: int, runes: list[str], right: bool, slot: bool) -> Grid:
    """One stone pillar, PILLAR wide: ink, highlight, stone, a 5 px rune channel, shade, ink."""
    g = blank(PILLAR, h)
    for y in range(h):
        g[y] = list("0ih00000gf0")
    # carved caps top and bottom: a block a bit lighter, an X carving, a bevel
    for y0 in (0, h - CAP):
        rect(g, 0, y0, PILLAR, CAP, "h")
        rect(g, 1, y0 + 1, PILLAR - 2, 1, "j")
        rect(g, 1, y0 + 1, 1, CAP - 2, "i")
        rect(g, PILLAR - 2, y0 + 1, 1, CAP - 2, "g")
        rect(g, 1, y0 + CAP - 2, PILLAR - 2, 1, "g")
        for x in range(PILLAR):
            g[y0][x] = "0"
            g[y0 + CAP - 1][x] = "0"
        for y in range(y0, y0 + CAP):
            g[y][0] = "0"
            g[y][PILLAR - 1] = "0"
    # X carving on the top cap
    for i in range(6):
        g[3 + i][2 + i] = "f"
        g[3 + i][8 - i] = "f"
    g[2][2], g[2][8] = "i", "i"
    # the bottom cap carries a recessed slot (the 'next' arrow lives there on the right pillar)
    y0 = h - CAP
    if slot:
        rect(g, 3, y0 + 2, 5, 8, "0")
        rect(g, 3, y0 + 2, 5, 1, "e")
    else:
        glyph(g, 4, y0 + 3, "..#/.#./#../.#./..#".replace("..#/.#./#../.#./..#", ".#./#../.#./..#/.#."), core="u", glow="f", hi="o")
    # rune channel: dark with a lighter rim, one rune every `pitch` rows
    top, bot = CAP, h - CAP
    for y in range(top, bot):
        g[y][3] = "e"
        g[y][7] = "e"
    pitch = (bot - top) // len(runes)
    for i, r in enumerate(runes):
        glyph(g, 4, top + i * pitch + (pitch - 5) // 2, r)
    # chips and cracks in the stone (deterministic)
    for y in (top + 4, top + 17, top + 30):
        if y < bot:
            g[y][1] = "g"
            g[y + 1][2] = "f"
    return mirror(g) if right else g


def beam(w: int) -> Grid:
    """Wooden beam between the pillars: 6 rows, grain dashes, tiles horizontally."""
    g = blank(w, 6)
    rows = ["0", "b", "a", "a", "9", "0"]
    for y, c in enumerate(rows):
        for x in range(w):
            g[y][x] = c
    for x in range(w):
        if x % 13 in (2, 3, 4, 5):
            g[2][x] = "9"
        if x % 11 in (7, 8, 9):
            g[3][x] = "9"
        if x % 17 == 0:
            g[1][x] = "a"
    return g


def ui_box(w: int = BOX_W, h: int = BOX_H) -> Grid:
    g = blank(w, h)
    # dark text inset
    rect(g, PILLAR, 6, w - 2 * PILLAR, h - 12, "0")     # the target's text inset is near-black navy: ink
    rect(g, PILLAR + 1, 8, w - 2 * PILLAR - 2, 1, "e")  # faint inner rim
    rect(g, PILLAR + 1, h - 8, w - 2 * PILLAR - 2, 1, "e")
    rect(g, PILLAR, 6, 1, h - 12, "0")
    rect(g, w - PILLAR - 1, 6, 1, h - 12, "0")
    paste(g, beam(w - 2 * PILLAR + 2), PILLAR - 1, 1)
    paste(g, beam(w - 2 * PILLAR + 2), PILLAR - 1, h - 7)
    paste(g, pillar(h, RUNES_L, False, False), 0, 0)
    paste(g, pillar(h, RUNES_R, True, True), w - PILLAR, 0)
    return g


def ui_socket() -> Grid:
    """Portrait socket: ink ring, stone ring, teal line with cut corners, dark window (WINDOW x WINDOW at (3,3))."""
    s = SOCKET
    g = blank(s, s)
    rect(g, 0, 0, s, s, "0")
    rect(g, 1, 1, s - 2, s - 2, "f")
    rect(g, 1, 1, s - 2, 1, "g")
    rect(g, 2, 2, s - 4, s - 4, "u")
    rect(g, 3, 3, s - 6, s - 6, "0")
    for cx, cy in ((2, 2), (s - 3, 2), (2, s - 3), (s - 3, s - 3)):  # rounded teal corners
        g[cy][cx] = "f"
    for cx, cy in ((3, 3), (s - 4, 3), (3, s - 4), (s - 4, s - 4)):
        g[cy][cx] = "u"
    return g


def ui_nameplate(w: int = 56, h: int = 13) -> Grid:
    """Stone name plate (the name is drawn by the game), etched corners, a green pointer on the right end."""
    g = blank(w + 4, h)
    rect(g, 0, 0, w, h, "0")
    rect(g, 1, 1, w - 2, h - 2, "g")
    rect(g, 1, 1, w - 2, 1, "h")
    rect(g, 1, h - 2, w - 2, 1, "f")
    rect(g, 2, 2, w - 4, h - 4, "0")
    rect(g, 3, 3, w - 6, h - 6, "e")
    for i in range(3):  # etched corner diagonals
        g[3 + i][3 + 2 - i] = "f"
        g[3 + i][w - 4 - 2 + i] = "f"
        g[h - 4 - i][3 + 2 - i] = "f"
        g[h - 4 - i][w - 6 + i] = "f"
    cy = h // 2
    for i in range(4):  # pointer
        for y in range(cy - (3 - i), cy + (3 - i) + 1):
            g[y][w + i] = "4" if i else "3"
        g[cy - (3 - i)][w + i] = "5"
    g[cy][w + 3] = "6"
    return g


def ui_badge(w: int = 38, h: int = 11) -> Grid:
    """Key prompt badge, empty (icon and the word ENTER are separate)."""
    g = blank(w, h)
    rect(g, 1, 0, w - 2, h, "0")
    rect(g, 0, 1, w, h - 2, "0")
    rect(g, 2, 1, w - 4, h - 2, "v")
    rect(g, 1, 2, w - 2, h - 4, "v")
    rect(g, 2, 2, w - 4, h - 4, "0")
    rect(g, 3, 2, w - 6, 1, "k")
    return g


def ui_icon_gamepad() -> Grid:
    """Gamepad glyph for the badge: body, a d-pad cross on the left, two lilac buttons on the right."""
    return [list(r) for r in [
        "..0000000..",
        ".0jjjjjjj0.",
        "0jj0jjjjvj0",
        "0j000jjvjj0",
        "0jj0jjjjjj0",
        "0jjj000jjj0",
        ".000...000.",
    ]]


def ui_icon_key() -> Grid:
    return [list(r) for r in [
        "000000000",
        "0jjjjjjj0",
        "0jiiiiij0",
        "0jiiiiij0",
        "0jiiiiij0",
        "0hhhhhhh0",
        "000000000",
    ]]


def ui_choice_arrow(shift: int = 0) -> Grid:
    g = blank(6, 7)
    rows = ["t.....", "uu....", ".ou...", "..oo..", ".ou...", "uu....", "t....."]
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != "." and 0 <= x + shift < 6:
                g[y][x + shift] = c
    return g


def ui_next(n: int) -> Grid:
    """The 'next' triangle that sits in the right pillar's slot: bright, dim, bright shifted down 1."""
    g = blank(5, 8)
    rows = ["u....", "ou...", "oou..", "pooo.", "oou..", "ou...", "u...."]
    table = {1: {}, 2: {"p": "u", "o": "t", "u": "t"}, 3: {}}[n]
    dy = 1 if n == 3 else 0
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                g[y + dy][x] = table.get(c, c)
    return g


def moss(w: int, h: int, seed: int, anchor: str) -> Grid:
    """A moss clump (deterministic): overlapping round tufts along the edge it grows from, a few hanging strands,
    lit on top, dark underneath. anchor tl / tr: over a top corner and down the pillar; bl: up from a bottom corner."""
    import random
    rnd = random.Random(seed)
    g = blank(w, h)
    blobs: list[tuple[float, float, float]] = []
    if anchor in ("tl", "tr"):
        for i in range(9):  # mat along the top edge, thick at the corner
            t = i / 8
            blobs.append((t * w * 0.9, 2 + rnd.random() * 2, (1 - t) * h * 0.32 + 2 + rnd.random() * 1.5))
        for i in range(5):  # drape down the pillar side
            blobs.append((2 + rnd.random() * 3, 4 + i * (h - 6) / 5, 2.2 + rnd.random() * 1.6))
    else:
        for i in range(7):
            t = i / 6
            blobs.append((2 + rnd.random() * 3, h - 2 - t * (h - 4), 2 + (1 - t) * 2.5))
        for i in range(6):
            t = i / 5
            blobs.append((t * w * 0.85, h - 2 - rnd.random() * 2, (1 - t) * 4 + 1.5))
    for bx, by, r in blobs:
        for y in range(h):
            for x in range(w):
                if (x - bx) ** 2 + (y - by) ** 2 <= r * r:
                    g[y][x] = "4"
    if anchor in ("tl", "tr"):
        for _ in range(4):  # hanging strands
            x = rnd.randint(4, int(w * 0.6))
            y0 = max((y for y in range(h) if g[y][x] != T), default=0)
            for y in range(y0, min(h, y0 + rnd.randint(2, 5))):
                g[y][x] = "3"
    if anchor == "tr":
        g = mirror(g)
    out = copy(g)
    for y in range(h):
        for x in range(w):
            if g[y][x] == T:
                continue
            up = y > 0 and g[y - 1][x] != T
            down = y < h - 1 and g[y + 1][x] != T
            left = x > 0 and g[y][x - 1] != T
            if not down:
                out[y][x] = "2"
            elif not up:
                out[y][x] = "6" if (x + y) % 3 == 0 else "5"
            elif not left and anchor != "tr":
                out[y][x] = "5"
            elif ((x // 2) * 7 + (y // 2) * 5) % 9 == 0:
                out[y][x] = "3"
            elif ((x // 2) * 3 + y) % 11 == 0:
                out[y][x] = "5"
    return out


def all_ui() -> dict[str, tuple[Grid, dict]]:
    """name -> (grid, json extras)."""
    ui: dict[str, tuple[Grid, dict]] = {
        "ui_dlg_box": (ui_box(), {"nine_slice": {"left": PILLAR, "right": PILLAR, "top": CAP, "bottom": CAP},
                                   "axis_stretch": {"horizontal": "tile", "vertical": "tile_fit"},
                                   "note": "pillars and beams tile; keep the height CAP*2 + a multiple of 11 so the runes repeat whole"}),
        "ui_dlg_socket": (ui_socket(), {"window": [3, 3, WINDOW, WINDOW], "portrait_scale": 0.5}),
        "ui_dlg_nameplate": (ui_nameplate(), {"nine_slice": {"left": 6, "right": 9, "top": 4, "bottom": 4},
                                              "text_box": [3, 3, 50, 7]}),
        "ui_dlg_badge": (ui_badge(), {"nine_slice": {"left": 4, "right": 4, "top": 4, "bottom": 4},
                                      "icon_at": [2, 2], "text_at": [15, 3]}),
        "ui_dlg_icon_gamepad": (ui_icon_gamepad(), {}),
        "ui_dlg_icon_key": (ui_icon_key(), {}),
        "ui_dlg_choice_arrow_1": (ui_choice_arrow(0), {}),
        "ui_dlg_choice_arrow_2": (ui_choice_arrow(1), {}),
        "ui_dlg_next_1": (ui_next(1), {}),
        "ui_dlg_next_2": (ui_next(2), {}),
        "ui_dlg_next_3": (ui_next(3), {}),
        "ui_dlg_moss_tl": (moss(24, 22, SEED, "tl"), {}),
        "ui_dlg_moss_tr": (moss(24, 20, SEED + 1, "tr"), {}),
        "ui_dlg_moss_bl": (moss(26, 14, SEED + 2, "bl"), {}),
    }
    return ui


# layout at 320x180 (game px); the 9-slice box can be resized, everything else is placed relative to it
LAYOUT = {
    "box": [40, 110, BOX_W, BOX_H],
    "socket": [52, 119],                 # box + (12, 9); the portrait (88x88 at scale 0.5) goes at socket + (3, 3)
    "nameplate": [54, 104],              # over the top beam, above the socket; name centred in text_box
    "moss": {"ui_dlg_moss_tl": [36, 107], "ui_dlg_moss_tr": [259, 107], "ui_dlg_moss_bl": [36, 150]},
    "text": [110, 121],                  # first line's cap top; text area 156 x 44
    "text_width": 156,
    "line_step": 11,
    "choice_arrow_dx": -8,               # arrow left of the choice text
    "badge": [229, 169],                 # the ENTER badge, over the bottom beam
    "next": [272, 168],                  # inside the right pillar's slot: box + (W - PILLAR + 3, H - CAP + 2)
    "colours": {"text": "1", "name": "7", "choice_selected": "o", "choice_dim": "h", "badge_text": "j"},
    "fonts": {"text": "PixelifySans 9 game px (weight 400)", "name": "Cinzel 7 game px (weight 700)",
              "badge": "PixelifySans 6 game px"},
}
UI_TICKS = {"next": [24, 12, 12], "choice_arrow": [20, 20]}


# -------------------------------------------------------------------------------------------------------- output

EXTRA_DIR = OUT / "portraits_extra"  # portraits added later with --portrait NAME PATH (converted PNGs)
EXPR_CHARS = ["mira", "totoy", "tovan", "edda"]


def grid_from_image(im: Image.Image) -> Grid:
    inv = {v: k for k, v in PAL.by_symbol.items()}
    im = im.convert("RGBA")
    px = im.load()
    return [[inv[px[x, y][:3]] if px[x, y][3] else T for x in range(im.width)] for y in range(im.height)]


def all_portraits() -> dict[str, Grid]:
    base = build_portraits()
    out: dict[str, Grid] = {}
    for name in ["mira", "totoy", "tovan", "edda", "elder", "child", "worker"]:
        for e in (EXPRESSIONS if name in EXPR_CHARS else ["neutral"]):
            out[f"portrait_{name}_{e}"] = expression(base[name], name, e) if name in FACES else base[name]
    out["portrait_edda_staff"] = base["edda_staff"]
    if EXTRA_DIR.exists():
        for p in sorted(EXTRA_DIR.glob("portrait_*.png")):
            out[p.stem] = grid_from_image(Image.open(p))
    return out


def save_atlas(items: list[tuple[str, Grid, dict]], cols: int, path: Path, meta: dict) -> dict:
    cw = max(len(g[0]) for _, g, _ in items) + 2
    ch = max(len(g) for _, g, _ in items) + 2
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    frames = {}
    for i, (name, g, extra) in enumerate(items):
        x, y = (i % cols) * cw + 1, (i // cols) * ch + 1
        sheet.alpha_composite(to_image(g), (x, y))
        frames[name] = {"x": x, "y": y, "w": len(g[0]), "h": len(g), **extra}
    sheet.save(path)
    data = {**meta, "image": path.name, "frames": frames}
    path.with_suffix(".json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    return data


def font(path: Path, size: float, weight: int | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), max(1, round(size)))
    if weight is not None:
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
    return f


def hard_text(im: Image.Image, xy: tuple[float, float], text: str, f: ImageFont.FreeTypeFont, col: tuple,
              shadow: tuple | None = None, anchor_cap: bool = True) -> int:
    """Text with hard alpha (threshold), the cap top at xy[1]. Returns the width."""
    cap_top = f.getbbox("H")[1] if anchor_cap else 0
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).text((round(xy[0]), round(xy[1] - cap_top)), text, font=f, fill=255)
    mask = mask.point(lambda v: 255 if v >= 112 else 0)
    if shadow is not None:
        sh = Image.new("L", im.size, 0)
        off = max(1, f.size // 9)
        sh.paste(mask, (off, off))
        im.paste(Image.new("RGBA", im.size, shadow + (255,)), (0, 0), sh)
    im.paste(Image.new("RGBA", im.size, col + (255,)), (0, 0), mask)
    return round(f.getlength(text))


def labelled_sheet(groups: list[tuple[str, list[tuple[str, Image.Image]]]], bg: tuple, zoom: int, cols: int) -> Image.Image:
    lab = font(PIXEL_FONT, 22)
    small = font(PIXEL_FONT, 13)
    blocks = []
    for title, ims in groups:
        cw = max(i.width for _, i in ims)
        ch = max(i.height for _, i in ims)
        n = len(ims)
        c = min(cols, n)
        r = (n + c - 1) // c
        cellw, cellh = max((cw + 2) * zoom, 150), (ch + 2) * zoom + 20
        block = Image.new("RGBA", (max(c * cellw, 900), r * cellh + 34), bg + (255,))
        hard_text(block, (6, 8), title, lab, rgb("1"))
        for i, (name, im) in enumerate(ims):
            x0, y0 = (i % c) * cellw, 34 + (i // c) * cellh
            big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
            block.alpha_composite(big, (x0 + zoom, y0))
            hard_text(block, (x0 + zoom, y0 + ch * zoom + zoom + 3), name, small, rgb("j"))
        blocks.append(block)
    W = max(b.width for b in blocks)
    H = sum(b.height + 10 for b in blocks)
    sheet = Image.new("RGBA", (W, H), bg + (255,))
    y = 0
    for b in blocks:
        sheet.alpha_composite(b, (0, y))
        y += b.height + 10
    return sheet


def hero_frame() -> tuple[Image.Image, int, int]:
    s = artlib.parse_sprite(ROOT / "art" / "src" / "hero2_idle_right_1.txt")
    return artlib.render(s, PAL), s.anchor[0], s.anchor[1]  # type: ignore[index]


def village_bg(objs: dict, w: int = 320, h: int = 180) -> Image.Image:
    """Flat-colour dark village stand-in (NOT the painting): grass, a dirt path, a stone hut, trees, a rune gate,
    lantern posts. 3/4 view like the target."""
    im = Image.new("RGBA", (w, h), rgb("3") + (255,))
    d = ImageDraw.Draw(im)
    for i in range(90):
        x, y = (i * 53) % w, (i * 37) % h
        d.rectangle([x, y, x + 1, y], fill=rgb("4") + (255,))
    for i in range(40):
        x, y = (i * 71) % w, (i * 29) % h
        d.rectangle([x, y, x, y + 1], fill=rgb("2") + (255,))
    # path (a wide diagonal band of packed dirt)
    d.polygon([(70, 180), (150, 70), (215, 70), (250, 180)], fill=rgb("9") + (255,))
    d.polygon([(90, 180), (160, 78), (205, 78), (232, 180)], fill=rgb("a") + (255,))
    for i in range(25):
        x, y = 120 + (i * 37) % 100, 80 + (i * 23) % 90
        d.rectangle([x, y, x + 2, y + 1], fill=rgb("b") + (255,))
    # hut (stone walls, wooden roof, warm windows, dark door)
    d.rectangle([214, 22, 300, 72], fill=rgb("g") + (255,))
    for yy in range(24, 72, 6):
        d.line([(214, yy), (300, yy)], fill=rgb("f") + (255,))
    d.polygon([(206, 26), (232, 0), (296, 0), (308, 26)], fill=rgb("9") + (255,))
    d.polygon([(210, 24), (234, 2), (294, 2), (304, 24)], fill=rgb("a") + (255,))
    d.rectangle([248, 40, 266, 72], fill=rgb("8") + (255,))
    d.rectangle([224, 38, 236, 50], fill=rgb("d") + (255,))
    d.rectangle([278, 38, 290, 50], fill=rgb("d") + (255,))
    d.rectangle([229, 38, 230, 50], fill=rgb("9") + (255,))
    d.rectangle([283, 38, 284, 50], fill=rgb("9") + (255,))
    # rune gate (two stone posts and a lintel with teal runes)
    d.rectangle([40, 14, 52, 80], fill=rgb("f") + (255,))
    d.rectangle([84, 14, 96, 80], fill=rgb("f") + (255,))
    d.rectangle([36, 8, 100, 18], fill=rgb("g") + (255,))
    d.rectangle([41, 15, 42, 79], fill=rgb("h") + (255,))
    for yy in range(26, 76, 10):
        d.rectangle([45, yy, 47, yy + 4], fill=rgb("u") + (255,))
        d.rectangle([88, yy, 90, yy + 4], fill=rgb("u") + (255,))
    for xx in range(44, 96, 10):
        d.rectangle([xx, 11, xx + 3, 13], fill=rgb("t") + (255,))
    # trees (dark canopies) at the edges
    for cx, cy, r in ((14, 30, 26), (130, 14, 18), (316, 96, 22), (8, 120, 20)):
        d.rectangle([cx - 3, cy + r - 8, cx + 3, cy + r + 10], fill=rgb("8") + (255,))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgb("2") + (255,))
        d.ellipse([cx - r + 3, cy - r + 2, cx + r - 6, cy + r - 6], fill=rgb("3") + (255,))
    # props: barrels and two lantern posts
    for bx, by in ((196, 66), (204, 70)):
        d.ellipse([bx, by, bx + 10, by + 12], fill=rgb("9") + (255,))
        d.rectangle([bx + 1, by + 4, bx + 9, by + 5], fill=rgb("f") + (255,))
    for name, (fx, fy) in (("obj_lantern_post_1", (110, 70)), ("obj_lantern_post_1", (300, 120))):
        g, (ax, ay) = objs[name]
        im.alpha_composite(to_image(g), (fx - ax, fy - ay))
    return im


def mockup(speaker: str, portrait: Grid, lines: list[str], scale: int, ui: dict, objs: dict, npcs: dict,
           choices: list[str] | None = None, sel: int = 0, next_frame: int = 1, icon: str = "gamepad",
           npc_on_path: str = "mira") -> Image.Image:
    base = village_bg(objs)
    hero, hax, hay = hero_frame()
    base.alpha_composite(hero, (150 - hax, 98 - hay))
    if npc_on_path in npcs:
        f = to_image(npcs[npc_on_path]["idle"][0]).transpose(Image.FLIP_LEFT_RIGHT)  # faces Totoy
        base.alpha_composite(f, (186 - (CELL_W - ANCHOR[0]), 98 - ANCHOR[1]))
    L = LAYOUT
    bx, by = L["box"][:2]

    def put(name: str, x: int, y: int) -> None:
        base.alpha_composite(to_image(ui[name][0]), (x, y))

    for k in ("ui_dlg_moss_bl",):
        put(k, *L["moss"][k])
    put("ui_dlg_box", bx, by)
    for k in ("ui_dlg_moss_tl", "ui_dlg_moss_tr"):  # under the name plate, over the pillar caps
        put(k, *L["moss"][k])
    put("ui_dlg_socket", *L["socket"])
    put("ui_dlg_nameplate", *L["nameplate"])
    put("ui_dlg_badge", *L["badge"])
    icon_g = ui["ui_dlg_icon_gamepad" if icon == "gamepad" else "ui_dlg_icon_key"][0]
    base.alpha_composite(to_image(icon_g), (L["badge"][0] + 2, L["badge"][1] + 2))
    if not choices:
        put(f"ui_dlg_next_{next_frame}", *L["next"])
    im = base.resize((320 * scale, 180 * scale), Image.NEAREST)
    # portrait: 88x88 at half scale -> scale/2 window px per portrait pixel
    px0, py0 = (L["socket"][0] + 3) * scale, (L["socket"][1] + 3) * scale
    pim = to_image(portrait)
    if scale >= 2:
        pim = pim.resize((88 * scale // 2, 88 * scale // 2), Image.NEAREST)
    else:
        pim = pim.resize((44, 44), Image.NEAREST)  # 1x preview only: every second pixel
    im.alpha_composite(pim, (px0, py0))
    # text, drawn at window resolution like the game (decision 0004)
    body = font(PIXEL_FONT, 9 * scale)
    name_f = font(NAME_FONT, 7 * scale, 700)
    badge_f = font(PIXEL_FONT, 6 * scale)
    nx, ny = L["nameplate"]
    nw = round(name_f.getlength(speaker.upper()))
    hard_text(im, ((nx + 3 + 50 / 2) * scale - nw / 2, (ny + 3.5) * scale), speaker.upper(), name_f, rgb(L["colours"]["name"]))
    tx, ty = L["text"]
    step = L["line_step"]
    y = ty
    for ln in lines:
        hard_text(im, (tx * scale, y * scale), ln, body, rgb(L["colours"]["text"]), shadow=rgb("0"))
        y += step
    if choices:
        y += 2
        for i, c in enumerate(choices):
            col = rgb(L["colours"]["choice_selected"] if i == sel else L["colours"]["choice_dim"])
            if i == sel:
                arrow = to_image(ui["ui_dlg_choice_arrow_1"][0]).resize((6 * scale, 7 * scale), Image.NEAREST)
                im.alpha_composite(arrow, ((tx + L["choice_arrow_dx"]) * scale, round((y - 0.5) * scale)))
            hard_text(im, (tx * scale, y * scale), c, body, col, shadow=rgb("0"))
            y += step
    bxx, byy = L["badge"]
    hard_text(im, ((bxx + 15) * scale, (byy + 3) * scale), "ENTER", badge_f, rgb(L["colours"]["badge_text"]))
    return im


def wrap(text: str, width_px: int, f: ImageFont.FreeTypeFont, scale: int) -> list[str]:
    words, lines, cur = text.split(), [], ""
    for w_ in words:
        t = (cur + " " + w_).strip()
        if f.getlength(t) <= width_px * scale or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w_
    if cur:
        lines.append(cur)
    return lines


def to_gif(frames: list[Image.Image], durations: list[int], path: Path) -> None:
    pal_frames = [f.convert("RGB").quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    pal_frames[0].save(path, save_all=True, append_images=pal_frames[1:], duration=durations, loop=0, disposal=2)


def write_all() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    src = Image.open(CAST).convert("RGB")
    poses = load_poses(src)
    npcs = build_npcs(poses)
    objs = build_objects(src)
    ports = all_portraits()
    ui = all_ui()

    # 1. NPC + interactable atlas
    items: list[tuple[str, Grid, dict]] = []
    states_meta: dict[str, dict] = {}
    for name, st in npcs.items():
        states_meta[name] = {}
        for state, frames in st.items():
            states_meta[name][state] = {"frames": len(frames), "ticks": TICKS.get(state, [60])[:len(frames)] if state in TICKS else [60]}
            for i, f in enumerate(frames):
                items.append((f"npc_{name}_{state}_right_{i + 1}", f, {"ax": ANCHOR[0], "ay": ANCHOR[1]}))
    for name, (g, (ax, ay)) in objs.items():
        items.append((name, g, {"ax": ax, "ay": ay}))
    save_atlas(items, 14, OUT / "npc_sprites_v2.png", {
        "note": "Chapter 1 NPCs and interactables v2, converted from art/reference/chapter1_cast_target.png. Review only.",
        "cell": [CELL_W, CELL_H], "anchor_rule": "feet: ax = centre of the soles, ay = one row under the soles",
        "facing": "right (3/4); left = mirror around ax at runtime, like hero2_*",
        "ticks_per_second": 60, "states": states_meta,
        "objects": {"obj_lantern": {"frames": 4, "ticks": [12, 10, 12, 10]}, "obj_lantern_post": {"frames": 4, "ticks": [12, 10, 12, 10]},
                    "obj_dummy_hit": {"frames": 2, "ticks": [4, 4], "then": "obj_dummy_1"}},
    })

    # 2. portraits
    pitems = [(k, g, {}) for k, g in ports.items()]
    save_atlas(pitems, 8, OUT / "portraits_v2.png", {
        "note": "88x88 portraits converted from the supplied paintings; draw at scale 0.5 (44 game px) in the socket window.",
        "size": PORTRAIT, "display_scale": 0.5, "background": "transparent; the socket window is filled with ink (0)",
        "supplied": ["portrait_mira_neutral", "portrait_totoy_neutral", "portrait_tovan_neutral", "portrait_edda_neutral",
                     "portrait_elder_neutral", "portrait_child_neutral", "portrait_worker_neutral", "portrait_edda_staff"],
        "derived": [k for k in ports if k.split("_")[-1] in ("happy", "worried", "serious")],
    })

    # 3. UI
    uitems = [(k, g, extra) for k, (g, extra) in ui.items()]
    save_atlas(uitems, 4, OUT / "dialogue_ui_v2.png", {
        "note": "Dialogue UI v2 at 1x game pixels (320x180), in the look of chapter1_dialogue_scene_target.png.",
        "layout_320x180": LAYOUT, "ticks": UI_TICKS,
    })

    # 4. contact sheets (4x game scale; portraits at 2x = their 0.5 display scale at 4x)
    npc_groups = []
    for name, st in npcs.items():
        ims = [(f"{state} {i + 1}", to_image(f)) for state, frames in st.items() for i, f in enumerate(frames)]
        npc_groups.append((f"npc_{name}", ims))
    obj_group = [("interactables (obj_*)", [(k.replace("obj_", ""), to_image(g)) for k, (g, _) in objs.items()])]
    for bgname, bg in (("dark", rgb("0")), ("grass", rgb("4"))):
        labelled_sheet(npc_groups + obj_group, bg, 4, 14).save(OUT / f"contact_npcs_{bgname}.png")
        por_groups = []
        for who in ["mira", "totoy", "tovan", "edda", "elder", "child", "worker"]:
            ims = [(k.replace(f"portrait_{who}_", ""), to_image(g)) for k, g in ports.items() if k.startswith(f"portrait_{who}_")]
            por_groups.append((f"portrait_{who}", ims))
        extra = [(k, to_image(g)) for k, g in ports.items() if not any(k.startswith(f"portrait_{w}_") for w in
                 ["mira", "totoy", "tovan", "edda", "elder", "child", "worker"])]
        if extra:
            por_groups.append(("other", extra))
        labelled_sheet(por_groups, bg, 2, 5).save(OUT / f"contact_portraits_{bgname}.png")
    big = ("ui_dlg_box", "ui_dlg_socket")
    labelled_sheet([("dialogue box (9-slice) and portrait socket, 4x", [(k.replace("ui_dlg_", ""), to_image(ui[k][0])) for k in big]),
                    ("plate, badge, icons, arrows, moss, 4x", [(k.replace("ui_dlg_", ""), to_image(g)) for k, (g, _) in ui.items() if k not in big])],
                   (40, 40, 48), 4, 7).save(OUT / "dialogue_ui_4x.png")

    # 5. expression check: derived next to the supplied neutral at 4x game scale
    rows = []
    for who in EXPR_CHARS:
        rows.append((f"portrait_{who}: supplied neutral, then derived", [(e, to_image(ports[f"portrait_{who}_{e}"])) for e in EXPRESSIONS]))
    labelled_sheet(rows, rgb("0"), 4, 4).save(OUT / "expressions_check_4x.png")

    # 6. GIFs (4x, grass)
    def frame_img(g: Grid, z: int = 4, w: int = CELL_W, h: int = CELL_H) -> Image.Image:
        im = Image.new("RGBA", (w * z, h * z), rgb("4") + (255,))
        im.alpha_composite(to_image(g).resize((len(g[0]) * z, len(g) * z), Image.NEAREST), (0, 0))
        return im
    for name, st in npcs.items():
        fr, du = [], []
        for state, reps in (("idle", 3), ("walk", 3), ("talk", 4)):
            if state not in st:
                continue
            ticks = TICKS[state]
            for _ in range(reps):
                for i, f in enumerate(st[state]):
                    fr.append(frame_img(f))
                    du.append(round(ticks[i] * 1000 / 60))
        to_gif(fr, du, OUT / f"npc_{name}.gif")
    lant = [objs[f"obj_lantern_post_{i}"][0] for i in range(1, 5)] * 3
    to_gif([frame_img(g, 4, len(g[0]), len(g)) for g in lant], [200, 166, 200, 166] * 3, OUT / "obj_lantern_post.gif")
    nxt = [ui[f"ui_dlg_next_{i}"][0] for i in (1, 2, 3)] * 3
    to_gif([frame_img(g, 8, 5, 8) for g in nxt], [400, 200, 200] * 3, OUT / "dialogue_next_blink.gif")

    # 7. line-up: Totoy (hero2_idle_right_1, unchanged) and every NPC + the interactables at 1x
    lineup = Image.new("RGBA", (400, 64), rgb("4") + (255,))
    d = ImageDraw.Draw(lineup)
    d.rectangle([0, 44, 400, 64], fill=rgb("a") + (255,))
    hero, hax, hay = hero_frame()
    x = 18
    lineup.alpha_composite(hero, (x - hax, 50 - hay))
    x += 26
    for name, st in npcs.items():
        lineup.alpha_composite(to_image(st["idle"][0]), (x - ANCHOR[0], 50 - ANCHOR[1]))
        x += 24
    for k in ("obj_dummy_1", "obj_chest_closed_1", "obj_chest_open_1", "obj_herbs_1", "obj_lantern_1", "obj_lantern_post_1"):
        g, (ax, ay) = objs[k]
        x += len(g[0]) // 2
        lineup.alpha_composite(to_image(g), (x - ax, 51 - ay))
        x += len(g[0]) // 2 + 4
    lineup.save(OUT / "lineup_game_scale_1x.png")
    lineup.resize((1600, 256), Image.NEAREST).save(OUT / "lineup_game_scale_4x.png")

    # 8. dialogue mockups
    f4 = font(PIXEL_FONT, 9 * 4)
    tw = LAYOUT["text_width"]
    scenes = [
        ("mira", "Mira", "portrait_mira_neutral", "You came back! Will you help me map the Forest?",
         ["I'll go now.", "Tell me about the beacons first."], "gamepad", "mira"),
        ("totoy", "Totoy", "portrait_totoy_neutral", "The beacons went dark the night the moss came. I'll find out why.",
         None, "key", "mira"),
        ("tovan", "Tovan", "portrait_tovan_serious", "Bring me moss iron from the hollow and I'll put an edge back on that blade.",
         None, "gamepad", "tovan"),
        ("edda_staff", "Edda", "portrait_edda_staff", "Hold still. The Aspect binds to you, not to the steel. Feel it settle.",
         None, "key", "edda"),
    ]
    for tag, speaker, por, text, choices, icon, npc in scenes:
        lines = wrap(text, tw, f4, 4)
        im = mockup(speaker, ports[por], lines, 4, ui, objs, npcs, choices=choices, icon=icon, npc_on_path=npc)
        im.save(OUT / f"dialogue_mockup_{tag}_4x.png")
        if tag == "mira":
            lines1 = wrap(text, tw, font(PIXEL_FONT, 9), 1)
            mockup(speaker, ports[por], lines1, 1, ui, objs, npcs, choices=choices, icon=icon).save(OUT / "dialogue_mockup_mira_1x.png")
            mira4 = im
    # 9. target vs ours
    tgt = Image.open(SCENE).convert("RGBA")
    tgt_big = tgt.resize((1280, round(410 * 1280 / 723)), Image.LANCZOS).crop((0, 0, 1280, 720))
    comp = Image.new("RGBA", (2560 + 20, 760), (20, 20, 24, 255))
    comp.alpha_composite(tgt_big, (0, 40))
    comp.alpha_composite(mira4, (1300, 40))
    lab = font(PIXEL_FONT, 28)
    hard_text(comp, (10, 6), "TARGET (chapter1_dialogue_scene_target.png, scaled to 1280x720)", lab, rgb("1"))
    hard_text(comp, (1310, 6), "OURS v2 at 4x (flat stand-in village; box, socket, plate, badge, moss, portrait)", lab, rgb("1"))
    comp.save(OUT / "compare_target_vs_ours.png")
    # box close-up: the same game-pixel rectangle from both, at 4x of 320x180
    gx0, gy0, gx1, gy1 = 30, 96, 290, 180
    k = 723 / 320
    tbox = tgt.crop((round(gx0 * k), round(gy0 * 410 / 180), round(gx1 * k), 410)).resize(((gx1 - gx0) * 4, (gy1 - gy0) * 4), Image.LANCZOS)
    obox = mira4.crop((gx0 * 4, gy0 * 4, gx1 * 4, gy1 * 4))
    comp2 = Image.new("RGBA", (tbox.width, tbox.height * 2 + 90), (20, 20, 24, 255))
    hard_text(comp2, (10, 8), "TARGET box", lab, rgb("1"))
    comp2.alpha_composite(tbox, (0, 40))
    hard_text(comp2, (10, tbox.height + 52), "OURS box (4x)", lab, rgb("1"))
    comp2.alpha_composite(obox, (0, tbox.height + 86))
    comp2.save(OUT / "compare_box_closeup.png")
    # portraits: supplied painting (resampled to 88) next to the converted one, 4x
    pairs = []
    for name, (path, rct, _) in PORTRAIT_SOURCES.items():
        s_ = Image.open(path).convert("RGBA").crop(rct).resize((88, 88), Image.BOX)
        pairs.append((f"{name} supplied", s_))
        key = f"portrait_{name}_neutral" if name != "edda_staff" else "portrait_edda_staff"
        pairs.append((f"{name} ours", to_image(ports[key])))
    labelled_sheet([("portraits: supplied (resampled to 88) vs converted", pairs)], rgb("0"), 3, 4).save(OUT / "compare_portraits.png")
    # cast: source crop vs converted pose, 4x
    cast_pairs = []
    for name, plist in POSES.items():
        for i, p in enumerate(plist):
            img, mask = cutout(src, p["box"], glow=p.get("glow", 0), erase=p.get("erase"))
            cut = img.convert("RGBA")
            cut.putalpha(mask)
            cut = cut.crop(mask.getbbox())
            cut = cut.resize((round(cut.width / SCALE), round(cut.height / SCALE)), Image.LANCZOS)
            cast_pairs.append((f"{name}{i + 1} src", cut))
            cast_pairs.append((f"{name}{i + 1} ours", to_image(trim(poses[name][i].grid))))
    labelled_sheet([("cast poses: source (smooth downscale) vs converted hard pixel art", cast_pairs)], rgb("4"), 4, 6).save(OUT / "compare_cast.png")
    check_outputs()


def check_outputs() -> None:
    allowed = {rgb(s) for s in PAL.by_symbol if s not in FORBIDDEN}
    for name in ("npc_sprites_v2.png", "portraits_v2.png", "dialogue_ui_v2.png"):
        im = Image.open(OUT / name).convert("RGBA")
        for p in im.getdata() if not hasattr(im, "get_flattened_data") else im.get_flattened_data():
            assert p[3] in (0, 255), f"{name}: partial alpha"
            assert p[3] == 0 or p[:3] in allowed, f"{name}: colour {p[:3]} outside Totoy 36 or reserved"
    print("atlases checked: Totoy 36 only, no gold/red, hard alpha")


def find_panel(img: Image.Image) -> tuple[int, int, int, int] | None:
    """A plot screenshot (white figure, one image panel with axes): the rows and columns that are mostly non-white
    form the panel; one spine pixel is trimmed on every side. Returns None for a plain painting (no white margin)."""
    px = img.load()
    w, h = img.size
    dark = lambda c: sum(c[:3]) < 600  # noqa: E731
    cols = [x for x in range(w) if sum(dark(px[x, y]) for y in range(h)) > h * 0.6]
    rows = [y for y in range(h) if sum(dark(px[x, y]) for x in range(w)) > w * 0.6]
    if not cols or not rows or (cols[-1] - cols[0] > w - 4 and rows[-1] - rows[0] > h - 4):
        return None
    return cols[0] + 1, rows[0] + 1, cols[-1] - 1, rows[-1] - 1


def add_portrait(name: str, path: Path) -> None:
    """--portrait: convert a newly supplied painted portrait and rebuild the portrait atlas and sheets."""
    img = Image.open(path).convert("RGB")
    rct = find_panel(img)
    g = convert_portrait(path, rct)
    EXTRA_DIR.mkdir(parents=True, exist_ok=True)
    out = EXTRA_DIR / f"portrait_{name}_neutral.png"
    to_image(g).save(out)
    print("converted", path, "panel", rct, "->", out)
    write_all()


def dev(out: Path, zoom: int = 5) -> None:
    """Source crop (scaled to the same size) next to the converted sprite, for every pose and object."""
    out.mkdir(parents=True, exist_ok=True)
    src = Image.open(CAST).convert("RGB")
    items = [(f"{n}{i + 1}", p) for n, ps in POSES.items() for i, p in enumerate(ps)] + list(OBJECTS.items())
    pairs = []
    for name, p in items:
        img, mask = cutout(src, p["box"], glow=p.get("glow", 0), erase=p.get("erase"))
        cut = img.convert("RGBA")
        cut.putalpha(mask)
        cut = cut.crop(mask.getbbox())
        f = zoom / SCALE
        cut = cut.resize((round(cut.width * f), round(cut.height * f)), Image.LANCZOS)
        g = convert(src, p["box"], glow=p.get("glow", 0), erase=p.get("erase"), keep=p.get("keep", ""))
        s_ = to_image(g)
        pairs.append((name, cut, s_.resize((s_.width * zoom, s_.height * zoom), Image.NEAREST)))
    per_row = 6
    cw = max(c.width + s_.width for _, c, s_ in pairs) + 16
    chh = max(max(c.height, s_.height) for _, c, s_ in pairs) + 10
    rows = (len(pairs) + per_row - 1) // per_row
    sheet = Image.new("RGBA", (cw * per_row, chh * rows), (90, 120, 60, 255))
    for i, (name, c, s_) in enumerate(pairs):
        x, y = (i % per_row) * cw, (i // per_row) * chh
        sheet.alpha_composite(c, (x, y + chh - 10 - c.height))
        sheet.alpha_composite(s_, (x + c.width + 4, y + chh - 10 - s_.height))
    sheet.save(out / "dev_cast.png")
    for k in range(rows):
        sheet.crop((0, k * chh, sheet.width, (k + 1) * chh)).save(out / f"dev_row{k}.png")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dev", help="write debug cut-outs into this folder")
    ap.add_argument("--portrait", nargs=2, metavar=("NAME", "PATH"), help="convert a new painted portrait")
    args = ap.parse_args()
    if args.dev:
        dev(Path(args.dev))
        return 0
    if args.portrait:
        add_portrait(args.portrait[0], Path(args.portrait[1]))
        return 0
    write_all()
    return 0


if __name__ == "__main__":
    sys.exit(main())
