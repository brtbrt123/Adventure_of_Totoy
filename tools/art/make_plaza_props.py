"""Write two plaza props to art/src as text-grid sprites: a mossy guardian statue on a plinth and a wooden chest.

Simple shapes shaded with the stone, dirt and grass ramps (no reserved combat colours). They are ordinary sprite sources
once written: edit the .txt by hand, or change this script and rerun it.

Run from the project root:  python tools/art/make_plaza_props.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

SRC = artlib.SRC_DIR

Mask = list[list[bool]]


def blank(w: int, h: int) -> list[list[str]]:
    return [["."] * w for _ in range(h)]


def mask_of(w: int, h: int, inside) -> Mask:
    return [[bool(inside(x + 0.5, y + 0.5)) for x in range(w)] for y in range(h)]


def shade(grid: list[list[str]], mask: Mask, light: str, mid: str, dark: str, outline: str, x0: float, x1: float) -> None:
    """Fill a mask: a lit left third, a mid tone, a dark right third, and an outline on its border."""
    h, w = len(grid), len(grid[0])
    for y in range(h):
        for x in range(w):
            if not mask[y][x]:
                continue
            border = any(not (0 <= x + dx < w and 0 <= y + dy < h and mask[y + dy][x + dx]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if border:
                grid[y][x] = outline
                continue
            t = (x + 0.5 - x0) / max(1.0, x1 - x0)
            grid[y][x] = light if t < 0.33 else (mid if t < 0.7 else dark)


def statue() -> list[list[str]]:
    w, h = 32, 48
    g = blank(w, h)
    # the plinth: a top face and a front, one step wider at the foot
    plinth = mask_of(w, h, lambda x, y: (4 <= x <= 28 and 36 <= y <= 44) or (2 <= x <= 30 and 44 <= y <= 48))
    shade(g, plinth, "i", "h", "g", "e", 2, 30)
    for x in range(5, 28):
        g[37][x] = "j" if x < 16 else "i"  # the lit top edge
        g[41][x] = "f"  # a carved band
    # the figure: a robed guardian, hands resting on a sword
    robe = mask_of(w, h, lambda x, y: 12 <= y <= 37 and abs(x - 16) <= 5.5 + (y - 12) * 0.12)
    shoulders = mask_of(w, h, lambda x, y: ((x - 16) / 8.0) ** 2 + ((y - 14) / 3.2) ** 2 <= 1.0)
    head = mask_of(w, h, lambda x, y: math.hypot(x - 16, y - 8.5) <= 4.2)
    hood = mask_of(w, h, lambda x, y: math.hypot(x - 16, y - 8.0) <= 5.0 and y <= 11.5)
    body = [[robe[y][x] or shoulders[y][x] for x in range(w)] for y in range(h)]
    shade(g, body, "i", "h", "g", "e", 8, 24)
    shade(g, hood, "h", "g", "f", "e", 11, 21)
    face = [[head[y][x] and y >= 7 for x in range(w)] for y in range(h)]
    shade(g, face, "j", "i", "h", "e", 12, 20)
    for y in range(19, 36):  # robe folds
        g[y][13] = "h" if g[y][13] == "i" else g[y][13]
        g[y][19] = "g" if g[y][19] == "h" else g[y][19]
    # the sword, point down, hands on the pommel
    for y in range(20, 37):
        g[y][16] = "j"
        g[y][17] = "i"
    for x in range(13, 21):
        g[19][x] = "j" if x < 17 else "i"
    for x in range(14, 20):
        g[17][x] = "h"
        g[18][x] = "i" if x < 17 else "h"
    g[16][16], g[16][17] = "i", "h"
    # moss on the shoulders, the hood and the plinth
    for x, y in ((9, 13), (10, 13), (10, 12), (11, 12), (22, 13), (21, 12), (13, 5), (14, 4), (15, 4),
                 (5, 36), (6, 36), (7, 36), (6, 37), (25, 36), (26, 36), (27, 37), (26, 37), (3, 44), (4, 44), (29, 45), (28, 44),
                 (12, 33), (12, 34), (20, 30), (20, 31)):
        if g[y][x] != ".":
            g[y][x] = "4" if (x + y) % 2 else "3"
    for x, y in ((9, 12), (22, 12), (5, 35), (26, 35), (14, 3)):
        if 0 <= y < h and g[y][x] == ".":
            g[y][x] = "5"
    return g


def chest() -> list[list[str]]:
    w, h = 16, 16
    g = blank(w, h)
    lid = mask_of(w, h, lambda x, y: 1 <= x <= 15 and 3 <= y <= 8 and ((x - 8) / 7.2) ** 2 + ((y - 8.5) / 5.6) ** 2 <= 1.0 or (1 <= x <= 15 and 7 <= y <= 8.9))
    box = mask_of(w, h, lambda x, y: 1 <= x <= 15 and 8 <= y <= 15)
    shade(g, box, "c", "b", "9", "8", 1, 15)
    shade(g, lid, "d", "c", "b", "8", 1, 15)
    for x in range(2, 14):
        g[8][x] = "8"  # the seam under the lid
        g[13][x] = "9"
    for y in range(3, 15):  # iron bands
        for x in (3, 12):
            if g[y][x] not in (".", "8"):
                g[y][x] = "i" if x == 3 else "h"
    for x, y in ((7, 8), (8, 8), (7, 9), (8, 9), (7, 10), (8, 10)):
        g[y][x] = "j" if x == 7 else "i"  # the lock plate
    g[10][7] = "f"
    g[9][8] = "f"
    return g


def write(name: str, grid: list[list[str]], anchor: tuple[int, int], note: str) -> None:
    lines = ["# kind: sprite", f"# anchor: {anchor[0]},{anchor[1]}", f"# {note}"] + ["".join(r) for r in grid]
    (SRC / f"{name}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    write("prop_statue_1", statue(), (16, 47), "plaza guardian statue (tools/art/make_plaza_props.py)")
    write("prop_chest_1", chest(), (8, 15), "plaza chest (tools/art/make_plaza_props.py)")
    print("wrote prop_statue_1, prop_chest_1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
