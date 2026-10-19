"""Write the plaza overlay tiles to art/src: the double stone ring and the central shield medallion.

Both are 16x16 tiles with transparent pixels, drawn OVER the plaza's stone floor tiles by make_arena_ground.py:
- plaza_ring_<col>_<row>: the top-left quarter of an elliptical double ring of light stone (centre at the quarter's
  bottom-right corner). The ground tool mirrors the quarter to make the whole ring, so it is exactly symmetric.
- plaza_emblem_<n>: a 64x64 round medallion with a shield and a sword, cut into 4x4 tiles (n = 1..16, row by row).

Palette symbols only (stone ramp, ink, teal, cream); no reserved combat colours. Deterministic. Once written, the tiles
are ordinary sources: edit the .txt files by hand if wanted, or change this script and rerun it.

Run from the project root:  python tools/art/make_plaza_tiles.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

SRC = artlib.SRC_DIR
T = 16
# the ring quarter: 11 x 7 tiles; the ring's centre is the quarter's bottom-right corner
QW, QH = 11 * T, 7 * T
OUTER = (168.0, 106.0)
INNER = (144.0, 88.0)
MARKS = 16  # stone blocks set between the two rings, evenly around the ellipse


def ring_distance(px: float, py: float, rx: float, ry: float) -> float:
    """Approximate signed distance (pixels) from a point to an ellipse centred at the origin."""
    r = math.hypot(px / rx, py / ry)
    if r == 0.0:
        return -min(rx, ry)
    gx, gy = px / (rx * rx * r), py / (ry * ry * r)
    return (r - 1.0) / max(1e-6, math.hypot(gx, gy))


def ring_quarter() -> list[list[str]]:
    grid = [["."] * QW for _ in range(QH)]
    for y in range(QH):
        for x in range(QW):
            px, py = x + 0.5 - QW, y + 0.5 - QH  # relative to the centre (negative: top-left quarter)
            for (rx, ry), core, half, block in ((OUTER, "j", 3.6, 14.0), (INNER, "i", 2.6, 12.0)):
                sd = ring_distance(px, py, rx, ry)
                d = abs(sd)
                if d <= half:
                    # the ring is a line of curved stone blocks: a dark joint every `block` px along it
                    along = math.atan2(py / ry, px / rx) * (rx + ry) / 2.0
                    if d > half - 1.0 or (along % block) < 1.0:
                        grid[y][x] = "e"  # the dark joint around the inlaid stone
                    elif sd < -0.3 and d > half - 2.0:
                        grid[y][x] = "h" if core == "j" else "g"  # the inner (shaded) edge of the block
                    elif d < 1.2 or sd > 0:
                        grid[y][x] = core
                    else:
                        grid[y][x] = "i" if core == "j" else "h"
    # marker blocks halfway between the rings
    mrx, mry = (OUTER[0] + INNER[0]) / 2, (OUTER[1] + INNER[1]) / 2
    for k in range(MARKS):
        ang = k * math.tau / MARKS
        cx, cy = math.cos(ang) * mrx, math.sin(ang) * mry
        if cx > 0.01 or cy > 0.01:
            continue  # only the top-left quarter (the axes belong to it as well; mirroring copies them)
        for y in range(QH):
            for x in range(QW):
                px, py = x + 0.5 - QW, y + 0.5 - QH
                dx, dy = abs(px - cx), abs(py - cy)
                if dx <= 4.0 and dy <= 3.5:
                    edge = dx > 3.0 or dy > 2.5
                    grid[y][x] = "e" if edge else ("j" if py - cy < 0 else "i")
    return grid


def emblem() -> list[list[str]]:
    n = 64
    c = n / 2
    grid = [["."] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            px, py = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(px, py)
            if r <= 31.0:
                if r > 30.0:
                    grid[y][x] = "e"
                elif r > 27.0:
                    grid[y][x] = "j" if py < 0 else "i"  # lit from above
                elif r > 26.0:
                    grid[y][x] = "e"
                else:
                    grid[y][x] = "h" if (x + y) % 7 else "g"  # worn carved field
    # the shield: flat top, straight sides, pointed bottom
    def in_shield(px: float, py: float, w: float, top: float, mid: float, bottom: float) -> bool:
        if py < top or py > bottom:
            return False
        if py <= mid:
            return abs(px) <= w
        t = (py - mid) / (bottom - mid)
        return abs(px) <= w * math.sqrt(max(0.0, 1.0 - t * t))
    for y in range(n):
        for x in range(n):
            px, py = x + 0.5 - c, y + 0.5 - c
            if in_shield(px, py, 15.0, -18.0, 2.0, 21.0):
                inner = in_shield(px, py, 13.0, -16.0, 2.0, 18.5)
                if not inner:
                    grid[y][x] = "e"
                elif in_shield(px, py, 11.0, -14.0, 2.0, 16.0):
                    grid[y][x] = "u" if px < 0 else "t"  # teal field, lighter left half
                else:
                    grid[y][x] = "i"  # the rim of the shield
    # the sword down the middle: blade, guard, grip, pommel
    for y in range(n):
        for x in range(n):
            px, py = x + 0.5 - c, y + 0.5 - c
            if -10.0 <= py <= 13.0 and abs(px) <= 1.5:
                grid[y][x] = "1" if px < 0 else "j"
            if 13.0 < py <= 14.0 and abs(px) <= 1.5:
                grid[y][x] = "j"
            if -15.0 <= py < -10.0 and abs(px) <= 1.0:
                grid[y][x] = "b"  # grip
            if -12.0 <= py <= -10.0 and abs(px) <= 6.0:
                grid[y][x] = "j" if py < -11.0 else "i"  # guard
            if -17.5 <= py < -15.0 and abs(px) <= 1.5:
                grid[y][x] = "j"  # pommel
    # outline the sword so it reads on the teal
    out = [row[:] for row in grid]
    for y in range(1, n - 1):
        for x in range(1, n - 1):
            if grid[y][x] in ("t", "u", "i") and in_shield(x + 0.5 - c, y + 0.5 - c, 11.0, -14.0, 2.0, 16.0):
                near = [grid[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if any(ch in ("1", "j", "b") for ch in near):
                    out[y][x] = "e"
    return out


def write_tile(name: str, rows: list[list[str]], note: str) -> None:
    lines = ["# kind: tile", f"# {note}"] + ["".join(r) for r in rows]
    (SRC / f"{name}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def cut(grid: list[list[str]], cx: int, cy: int) -> list[list[str]]:
    return [row[cx * T:(cx + 1) * T] for row in grid[cy * T:(cy + 1) * T]]


def main() -> int:
    for old in list(SRC.glob("plaza_ring_*.txt")) + list(SRC.glob("plaza_emblem_*.txt")):
        old.unlink()
    quarter = ring_quarter()
    written = 0
    for ty in range(QH // T):
        for tx in range(QW // T):
            tile = cut(quarter, tx, ty)
            if any(ch != "." for row in tile for ch in row):
                write_tile(f"plaza_ring_{tx}_{ty}", tile, "overlay tile, top-left quarter of the plaza ring, drawn over the floor (tools/art/make_plaza_tiles.py)")
                written += 1
    medal = emblem()
    for ty in range(4):
        for tx in range(4):
            write_tile(f"plaza_emblem_{ty * 4 + tx + 1}", cut(medal, tx, ty), "overlay tile, the plaza medallion, 4x4 tiles row by row (tools/art/make_plaza_tiles.py)")
            written += 1
    print(f"wrote {written} plaza tiles to {SRC}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
