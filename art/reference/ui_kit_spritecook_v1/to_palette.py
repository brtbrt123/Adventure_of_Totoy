"""Turn a SpriteCook download into Totoy 36 pixel art (review only).

The source is cut into a grid of cells and every cell becomes one game pixel:
- a cell is opaque when at least half of its inner pixels have alpha >= 128,
  otherwise it is fully transparent (hard alpha, no partial edges);
- its colour is the most common Totoy 36 colour among its opaque inner pixels,
  each pixel first mapped to the nearest palette colour in CIELAB (strongly
  gold, violet or red pixels only to colours of their own family, see GUARDS).
"Inner" drops the outer 20% of each cell, where generated art smears across
the cell borders. The combat colours (gold x/y, red z/A) are never chosen.

Usage (from the project root; -P keeps the script and working folders off
sys.path, so nothing next to a download can be imported; -I would also hide the
per-user site-packages that hold numpy here):
  python -P art/reference/ui_kit_spritecook_v1/to_palette.py SRC OUT --size 48x48
  python -P art/reference/ui_kit_spritecook_v1/to_palette.py SRC OUT --cell 8
  python -P art/reference/ui_kit_spritecook_v1/to_palette.py SRC --estimate
Options: --crop x0,y0,x1,y1 (source pixels), --txt GRID.txt (art/src style grid),
--preview N (also write OUT with a _xN suffix, nearest-neighbour).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
_PAL = json.loads((ROOT / "art" / "palette.json").read_text(encoding="utf-8"))
RESERVED = set(_PAL["reserved"])
COLORS = [c for c in _PAL["colors"] if c["symbol"] not in RESERVED]
SYMBOLS = [c["symbol"] for c in COLORS]
RGB = np.array([[int(c["hex"][i:i + 2], 16) for i in (1, 3, 5)] for c in COLORS], dtype=np.uint8)


def to_lab(rgb: np.ndarray) -> np.ndarray:
    """sRGB (..., 3) uint8 -> CIELAB (..., 3) float32, D65."""
    c = rgb.astype(np.float32) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]], dtype=np.float32)
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0, 500.0 * (f[..., 0] - f[..., 1]), 200.0 * (f[..., 1] - f[..., 2])], axis=-1)


PAL_LAB = to_lab(RGB)


def _only(*symbols: str) -> np.ndarray:
    return np.array([s in symbols for s in SYMBOLS])


# Hue guards: strongly coloured pixels may only become colours of their own family, so the
# generator's gold glints stay bronze (Totoy 36 gold is reserved), violet stays lilac instead of
# drifting to blue, dark teal stays teal instead of turning stone grey, and any red becomes rust
# brown. (hue lo, hue hi, min saturation, min value)
GUARDS = [
    ((28, 66, 0.40, 0.40), _only("a", "b", "c", "d", "q", "r", "s", "1")),  # gold/amber -> bronze ramp
    ((165, 200, 0.40, 0.20), _only("t", "u", "o", "p")),                     # teal -> teal, pale water
    ((250, 325, 0.22, 0.12), _only("0", "v", "1")),                          # violet -> ink, lilac, cream
    ((335, 360, 0.45, 0.25), _only("8", "9", "a", "q", "r")),                # red -> rust
    ((0, 14, 0.45, 0.25), _only("8", "9", "a", "q", "r")),
]


def _hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    c = rgb.astype(np.float32) / 255.0
    mx, mn = c.max(-1), c.min(-1)
    d = np.where(mx - mn == 0, 1e-9, mx - mn)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    return h, np.where(mx == 0, 0, (mx - mn) / np.where(mx == 0, 1, mx)), mx


def nearest(rgb: np.ndarray) -> np.ndarray:
    """Palette index of the nearest Totoy 36 colour (CIELAB) for every pixel of (..., 3),
    restricted by the hue guards above."""
    flat = rgb.reshape(-1, 3)
    out = np.empty(len(flat), dtype=np.int16)
    for i in range(0, len(flat), 1 << 18):
        part = flat[i:i + (1 << 18)]
        dist = ((to_lab(part)[:, None, :] - PAL_LAB[None, :, :]) ** 2).sum(-1)
        h, s, v = _hsv(part)
        for (lo, hi, smin, vmin), allowed in GUARDS:
            hit = (h >= lo) & (h < hi) & (s >= smin) & (v >= vmin)
            dist[np.ix_(hit, ~allowed)] = np.inf
        out[i:i + len(part)] = dist.argmin(1)
    return out.reshape(rgb.shape[:-1])


def estimate_cell(img: Image.Image) -> float:
    """Guess source pixels per game pixel from where colours change.

    Counts, for every column and row boundary, how many pixels change colour
    there (counts, not jump sizes, so a few strong panel edges cannot dominate),
    then scores each period by how much of that change its grid lines catch,
    summed over both axes. Multiples of the true period score about as well as
    the period itself, so the smallest one within 85% of the best score wins;
    each axis needs at least 12 grid lines so a few lucky lines cannot win.
    Only a hint: the kit's sizes are chosen per component."""
    a = np.asarray(img.convert("RGBA"), dtype=np.int32)
    signals = []
    for ax in (1, 0):
        d = (np.abs(np.diff(a, axis=ax)).sum(-1) > 24).sum(1 - ax).astype(np.float64)
        signals.append(d / (d.mean() + 1e-9))
    scores: list[tuple[float, float]] = []
    for p10 in range(20, 330):  # periods 2.0 .. 32.9 px in 0.1 steps
        p = p10 / 10.0
        usable = [d for d in signals if len(d) / p >= 12]
        if not usable:
            break
        score = sum(max(d[np.round(np.arange(ph, len(d) - 1, p)).astype(int)].mean()
                        for ph in np.linspace(0, p, max(2, int(p * 2)), endpoint=False)) for d in usable) / len(usable)
        scores.append((p, score))
    if not scores:
        return 1.0
    top = max(s for _, s in scores)
    return next(p for p, s in scores if s >= 0.85 * top)


def convert(img: Image.Image, size: tuple[int, int]) -> tuple[Image.Image, list[str]]:
    """Resample img to size game pixels; returns the image and its symbol grid."""
    src = np.asarray(img.convert("RGBA"), dtype=np.uint8)
    h, w = src.shape[:2]
    tw, th = size
    idx = nearest(src[..., :3])
    solid = src[..., 3] >= 128
    out = np.zeros((th, tw, 4), dtype=np.uint8)
    rows: list[str] = []
    for ty in range(th):
        y0, y1 = ty * h / th, (ty + 1) * h / th
        iy0, iy1 = int(y0 + 0.2 * (y1 - y0)), max(int(y0 + 0.2 * (y1 - y0)) + 1, int(np.ceil(y1 - 0.2 * (y1 - y0))))
        row = []
        for tx in range(tw):
            x0, x1 = tx * w / tw, (tx + 1) * w / tw
            ix0, ix1 = int(x0 + 0.2 * (x1 - x0)), max(int(x0 + 0.2 * (x1 - x0)) + 1, int(np.ceil(x1 - 0.2 * (x1 - x0))))
            cell_solid = solid[iy0:iy1, ix0:ix1]
            if cell_solid.mean() < 0.5:
                row.append(".")
                continue
            k = int(np.bincount(idx[iy0:iy1, ix0:ix1][cell_solid], minlength=len(SYMBOLS)).argmax())
            out[ty, tx, :3] = RGB[k]
            out[ty, tx, 3] = 255
            row.append(SYMBOLS[k])
        rows.append("".join(row))
    return Image.fromarray(out, "RGBA"), rows


def check(img: Image.Image) -> None:
    """Fail unless every pixel is transparent or an opaque, unreserved palette colour."""
    a = np.asarray(img.convert("RGBA"))
    alpha = a[..., 3]
    if not np.isin(alpha, (0, 255)).all():
        raise SystemExit("partial alpha left in output")
    allowed = {tuple(int(v) for v in c) for c in RGB}
    used = {tuple(int(v) for v in p) for p in a[alpha == 255][:, :3]}
    if not used <= allowed:
        raise SystemExit(f"colours outside Totoy 36 (or reserved): {sorted(used - allowed)[:5]}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src", type=Path)
    ap.add_argument("out", type=Path, nargs="?")
    ap.add_argument("--size", help="target WxH in game pixels")
    ap.add_argument("--cell", type=float, help="source pixels per game pixel")
    ap.add_argument("--crop", help="x0,y0,x1,y1 in source pixels")
    ap.add_argument("--estimate", action="store_true", help="only print the estimated cell size")
    ap.add_argument("--txt", type=Path, help="also write an art/src style text grid")
    ap.add_argument("--preview", type=int, default=0, help="also write an N-times nearest-neighbour copy")
    args = ap.parse_args()

    img = Image.open(args.src).convert("RGBA")
    if args.crop:
        img = img.crop(tuple(int(v) for v in args.crop.split(",")))
    if args.estimate or not (args.size or args.cell):
        print(f"{args.src.name}: {img.width}x{img.height}, estimated cell {estimate_cell(img):.1f} px")
        if not args.out:
            return
    if args.size:
        size = tuple(int(v) for v in args.size.lower().split("x"))
    else:
        cell = args.cell or estimate_cell(img)
        size = (max(1, round(img.width / cell)), max(1, round(img.height / cell)))
    out, rows = convert(img, size)
    check(out)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)
    if args.txt:
        args.txt.write_text("# kind: sprite\n" + "\n".join(rows) + "\n", encoding="utf-8")
    if args.preview > 1:
        out.resize((out.width * args.preview, out.height * args.preview), Image.NEAREST).save(
            args.out.with_name(f"{args.out.stem}_x{args.preview}{args.out.suffix}"))
    print(f"{args.out.name}: {size[0]}x{size[1]}, {len({s for r in rows for s in r} - {'.'})} colours")


if __name__ == "__main__":
    main()
