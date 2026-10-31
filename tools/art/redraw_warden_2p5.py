"""Redraws the Runebound Warden natively at 2.5x from its 48x48 design (owner request 2026-10-31).

The Warden was designed at 48x48 (art/reference/warden_cleave_range_v4/: body/<state>/*.png, fx/<family>/*.png, manifest.json) and
enlarged 2.5x for the game. Until now the body was stretched with nearest neighbour (uneven 2- and 3-pixel blocks baked into art/src)
and the effects were stretched at draw time. This tool redraws both at their game size so every pixel is one game pixel:

    AdvMAME3x then Scale2x (the EPX family: pixel-art upscalers that round diagonals into clean edges and only reuse the art's own
    colours) gives a 6x image; a majority vote over each 2.4x2.4 window brings it to exactly 2.5x. Transparency must win clearly, so
    thin dark outlines survive. Every output pixel is a palette colour or fully transparent.

It rewrites the Warden EFFECT grids that exist in art/src (fx_warden_*.txt): effect anchors are the design anchor x 2.5. The body
poses come from the detailed design instead (tools/art/rig_warden_v2.py, owner request 2026-10-31). Canvases are trimmed to the art (multiples of 8) to keep the atlas small.

    python tools/art/redraw_warden_2p5.py            # rewrite the grids, then validate/build/preview as usual
    python tools/art/redraw_warden_2p5.py --check    # only report what would change

The function redraw() is also used by tests/test_warden_art.py to check the atlas pixel for pixel.
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/reference/warden_cleave_range_v4"
SCALE = 2.5
BODY_ANCHOR = (20, 44)  # the 48x48 design's feet


def _palette() -> dict[tuple[int, int, int], str]:
    colours = json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))["colors"]
    return {tuple(bytes.fromhex(c["hex"][1:])): c["symbol"] for c in colours}


def _grid(path: Path, symbols: dict) -> list[list[str]]:
    im = Image.open(path).convert("RGBA")
    return [["." if im.getpixel((x, y))[3] == 0 else symbols[im.getpixel((x, y))[:3]] for x in range(im.width)] for y in range(im.height)]


def _scale2x(g: list[list[str]]) -> list[list[str]]:
    h, w = len(g), len(g[0])
    out = [[""] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            p = g[y][x]
            a = g[y - 1][x] if y > 0 else p
            b = g[y][x + 1] if x < w - 1 else p
            c = g[y][x - 1] if x > 0 else p
            d = g[y + 1][x] if y < h - 1 else p
            out[2 * y][2 * x] = c if (c == a and c != d and a != b) else p
            out[2 * y][2 * x + 1] = a if (a == b and a != c and b != d) else p
            out[2 * y + 1][2 * x] = c if (d == c and d != b and c != a) else p
            out[2 * y + 1][2 * x + 1] = b if (b == d and b != a and d != c) else p
    return out


def _scale3x(g: list[list[str]]) -> list[list[str]]:
    h, w = len(g), len(g[0])
    out = [[""] * (w * 3) for _ in range(h * 3)]

    def at(y: int, x: int) -> str:
        return g[min(h - 1, max(0, y))][min(w - 1, max(0, x))]

    for y in range(h):
        for x in range(w):
            A, B, C = at(y - 1, x - 1), at(y - 1, x), at(y - 1, x + 1)
            D, E, F = at(y, x - 1), at(y, x), at(y, x + 1)
            G, H, I = at(y + 1, x - 1), at(y + 1, x), at(y + 1, x + 1)
            if B != H and D != F:
                cells = [D if D == B else E,
                         B if (D == B and E != C) or (B == F and E != A) else E,
                         F if B == F else E,
                         D if (D == B and E != G) or (D == H and E != A) else E,
                         E,
                         F if (B == F and E != I) or (H == F and E != C) else E,
                         D if D == H else E,
                         H if (D == H and E != I) or (H == F and E != G) else E,
                         F if H == F else E]
            else:
                cells = [E] * 9
            for i, v in enumerate(cells):
                out[3 * y + i // 3][3 * x + i % 3] = v
    return out


def _vote(g: list[list[str]], factor: float, w_out: int, h_out: int) -> list[list[str]]:
    out = []
    for oy in range(h_out):
        y0 = int(oy * factor)
        y1 = max(y0 + 1, int((oy + 1) * factor))
        row = []
        for ox in range(w_out):
            x0 = int(ox * factor)
            x1 = max(x0 + 1, int((ox + 1) * factor))
            votes: Counter = Counter()
            for yy in range(y0, min(y1, len(g))):
                line = g[yy]
                for xx in range(x0, min(x1, len(line))):
                    votes[line[xx]] += 1
            ranked = votes.most_common()
            pick = ranked[0][0]
            if pick == "." and len(ranked) > 1 and ranked[0][1] < ranked[1][1] * 1.6:
                pick = ranked[1][0]  # transparency must win clearly, so thin outlines survive
            row.append(pick)
        out.append(row)
    return out


def redraw(path: Path, anchor: tuple[int, int], symbols: dict | None = None) -> tuple[list[str], tuple[int, int]]:
    """The 2.5x redraw of one design PNG: (grid rows, anchor), trimmed to the art in multiples of 8 (feet kept inside)."""
    symbols = symbols or _palette()
    g = _grid(path, symbols)
    six = _scale2x(_scale3x(g))
    w, h = int(len(g[0]) * SCALE), int(len(g) * SCALE)
    big = _vote(six, 6 / SCALE, w, h)
    ax, ay = int(anchor[0] * SCALE + 0.5), int(anchor[1] * SCALE + 0.5)
    filled = [(x, y) for y in range(h) for x in range(w) if big[y][x] != "."]
    if filled:
        left = min(min(x for x, _ in filled), ax)
        top = min(min(y for _, y in filled), ay)
        right = max(max(x for x, _ in filled) + 1, ax + 1)
        bottom = max(max(y for _, y in filled) + 1, ay + 1)
    else:
        left, top, right, bottom = 0, 0, w, h
    width = (right - left + 7) // 8 * 8
    height = (bottom - top + 7) // 8 * 8
    rows = []
    for y in range(top, top + height):
        rows.append("".join(big[y][x] if 0 <= y < h and 0 <= x < w else "." for x in range(left, left + width)))
    return rows, (ax - left, ay - top)


def sources() -> dict[str, tuple[Path, tuple[int, int]]]:
    """Every Warden grid in art/src mapped to its design PNG and design anchor."""
    manifest = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    out: dict[str, tuple[Path, tuple[int, int]]] = {}
    # The body (warden_*.txt) is no longer redrawn here: since the detailed design it comes from tools/art/rig_warden_v2.py.
    for grid in sorted((ROOT / "art/src").glob("fx_warden_*.txt")):
        stem = grid.stem
        family = stem[len("fx_warden_"):].rsplit("_", 1)[0]
        out[stem] = (SOURCE / "fx" / family / f"{stem}.png", tuple(manifest["fx_assets"][stem]["anchor"]))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="only report")
    args = parser.parse_args()
    symbols = _palette()
    changed = 0
    for stem, (png, anchor) in sources().items():
        rows, (ax, ay) = redraw(png, anchor, symbols)
        text = f"# kind: sprite\n# anchor: {ax},{ay}\n" + "\n".join(rows) + "\n"
        target = ROOT / "art/src" / f"{stem}.txt"
        if target.read_text(encoding="utf-8") != text:
            changed += 1
            if not args.check:
                target.write_text(text, encoding="utf-8", newline="\n")
    print(f"Warden grids: {len(sources())} total, {changed} {'would change' if args.check else 'rewritten'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
