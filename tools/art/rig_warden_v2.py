"""Builds every Runebound Warden body pose from one detailed design (owner request 2026-10-31: "new detailed art", native size).

Source: art/reference/warden_v2_detailed/b_native_totoy36.png (103x118, SpriteCook generation snapped to Totoy 36; manifest beside it).
The sprite is cut into parts (head, far arm, near arm with the hooked root blade, two legs, torso with the stone chestplate) by fixed
polygons, and each animation frame poses those parts: a body offset (bob, crouch, lean), rotations about the joints, and the rune
state (lit while guarded, brighter while charging the Spore Ring or flashing on a guard hit, dark while exposed or dying). Rotations
are sharp pixel-art rotations (each part is enlarged 4x, rotated, and brought back by a majority vote), so no blur and no new colours.

It writes art/src/warden_<state>_right_<n>.txt (the frame names, counts and order presentation/explore/mob_view.gd plays) and
presentation/explore/warden_attachments.json (per frame: the chest stone and the blade hook, in the attachment units the effects use:
pixels from the feet / 2.5). Deterministic: the same source gives the same files.

    python tools/art/rig_warden_v2.py           # write the grids and attachments, then validate/build/preview as usual
    python tools/art/rig_warden_v2.py --sheet   # also write a labelled contact sheet of every pose to art/reference/warden_v2_detailed/
"""
from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/reference/warden_v2_detailed/b_native_totoy36.png"
FEET = (47, 117)  # where the Warden stands in the source sprite
MARGIN = 64  # working space around the sprite for raised arms and falls
RUNE_BOX = (46, 39, 64, 60)  # the rune on the chestplate (x0, y0, x1, y1)
RUNE_CENTRE = (54, 48)
HOOK = (98, 114)  # the blade's hooked tip

# part -> (polygon in source pixels, pivot)
PARTS: dict[str, tuple[list[tuple[int, int]], tuple[int, int]]] = {
    "head": ([(35, 0), (61, 0), (61, 33), (35, 33)], (48, 31)),
    "near_arm": ([(62, 27), (81, 27), (87, 55), (103, 77), (103, 118), (86, 118), (71, 86), (64, 71), (60, 62)], (65, 38)),
    "far_arm": ([(0, 17), (41, 15), (41, 42), (28, 56), (28, 99), (0, 99)], (31, 31)),
    "leg_far": ([(0, 99), (28, 99), (28, 64), (48, 64), (48, 118), (0, 118)], (36, 67)),
    "leg_near": ([(48, 64), (67, 64), (74, 85), (88, 118), (48, 118)], (59, 67)),
}
DRAW_ORDER = ["far_arm", "leg_far", "leg_near", "torso", "head", "near_arm"]
UPPER = {"torso", "head", "near_arm", "far_arm"}  # parts the body offset moves

# The rune's colours (Totoy 36 symbols) and what they become in each rune state.
RUNE_DARK = {"p": "g", "o": "f", "n": "f", "u": "e", "t": "e", "m": "f"}
RUNE_BRIGHT = {"t": "u", "u": "o", "n": "o", "o": "p", "m": "n"}


def F(**kw) -> dict:
    """One frame: body (dx, dy), per-part angles in degrees (positive = clockwise on screen), leg shifts, rune state, dissolve."""
    return {"body": kw.get("body", (0, 0)), "angles": kw.get("angles", {}), "legs": kw.get("legs", {}), "rune": kw.get("rune", "lit"),
            "dissolve": kw.get("dissolve", 0.0)}


def poses() -> dict[str, list[dict]]:
    p: dict[str, list[dict]] = {}
    p["idle"] = [F(body=(0, b)) for b in (0, 0, 1, 1, 1, 0)]
    p["wake"] = [F(body=(0, d), angles={"head": a, "near_arm": a / 2, "far_arm": -a / 2}) for d, a in ((6, 12), (4, 8), (2, 4), (0, 0))]
    walk = ((0, -2, 2, 0, 0, 0), (1, -1, 1, -2, 0, 0), (0, 0, 0, 0, -2, 1), (0, 2, -2, 0, 0, 0), (1, 1, -1, 0, 0, -2), (0, 0, 0, -2, 0, 0))
    p["walk"] = [F(body=(0, bob), angles={"far_arm": -swing * 2.5, "near_arm": swing * 1.5},
                   legs={"leg_far": (fx, lift_far), "leg_near": (-fx, lift_near)})
                 for bob, fx, swing, lift_far, lift_near, _ in [(w[0], w[1], w[2], w[3], w[4], w[5]) for w in walk]]
    p["cleave_tell"] = [F(body=(-l, 0), angles={"near_arm": a, "head": -2}) for a, l in ((-20, 1), (-45, 2), (-70, 2), (-90, 3), (-100, 3))]
    p["cleave_strike"] = [F(body=(l, d), angles={"near_arm": a, "head": 3}) for a, l, d in ((-40, 2, 0), (15, 4, 2), (30, 3, 2))]
    p["lash_tell"] = [F(body=(-l, 0), angles={"near_arm": a, "far_arm": -a / 3}) for a, l in ((12, 1), (24, 2), (34, 3), (40, 3), (42, 3))]
    p["lash_strike"] = [F(body=(l, 0), angles={"near_arm": a, "far_arm": 6}) for a, l in ((-55, 4), (-80, 6), (-75, 5))]
    p["ring_tell"] = [F(body=(0, d), angles={"far_arm": s, "near_arm": -s}, rune="bright") for d, s in ((1, 4), (2, 8), (3, 12), (4, 16), (4, 18))]
    p["ring_strike"] = [F(body=(0, d), angles={"far_arm": s, "near_arm": -s}, rune="bright") for d, s in ((7, 6), (3, 2), (1, 0))]
    p["recover"] = [F(body=(l, 0), angles={"near_arm": a}) for a, l in ((20, 2), (12, 1), (6, 1), (0, 0))]
    p["guard_hit"] = [F(body=(-3, 0), angles={"head": -4}, rune="bright"), F(body=(-1, 0), angles={"head": -2})]
    p["hurt"] = [F(body=(-3, 1), angles={"head": 8, "near_arm": 6}), F(body=(-1, 0), angles={"head": 3, "near_arm": 2})]
    p["exposed"] = [F(body=(-2, d), angles={"head": h, "near_arm": 14, "far_arm": -8}, rune="dark") for d, h in ((5, 12), (8, 18), (8, 20), (8, 18))]
    p["death"] = [F(body=(-1 * min(i, 4), d), angles={"head": 10 + i * 6, "near_arm": 10 + i * 5, "far_arm": -6 - i * 4},
                    legs={"leg_far": (0, min(i, 3)), "leg_near": (0, min(i, 3))}, rune="dark" if i >= 1 else "lit", dissolve=dv)
                  for i, (d, dv) in enumerate(((3, 0.0), (7, 0.0), (11, 0.08), (15, 0.18), (19, 0.32), (23, 0.5), (26, 0.68), (28, 0.84)))]
    return p


# ---- images as symbol grids ---------------------------------------------------------------------------------------------------

def _palette() -> tuple[dict[tuple[int, int, int], str], dict[str, tuple[int, int, int]]]:
    colours = json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))["colors"]
    to_symbol = {tuple(bytes.fromhex(c["hex"][1:])): c["symbol"] for c in colours}
    return to_symbol, {s: rgb for rgb, s in to_symbol.items()}


def _inside(poly: list[tuple[int, int]], x: float, y: float) -> bool:
    c = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def cut() -> tuple[dict[str, dict[tuple[int, int], str]], tuple[int, int]]:
    """The source split into parts: {part: {(x, y): symbol}} (every opaque pixel in exactly one part)."""
    to_symbol, _ = _palette()
    im = Image.open(SOURCE).convert("RGBA")
    parts: dict[str, dict[tuple[int, int], str]] = {name: {} for name in DRAW_ORDER}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if a < 128:
                continue
            symbol = to_symbol[(r, g, b)]
            owner = "torso"
            for name in ("head", "near_arm", "far_arm", "leg_far", "leg_near"):
                if _inside(PARTS[name][0], x + 0.5, y + 0.5):
                    owner = name
                    break
            parts[owner][(x, y)] = symbol
    return parts, im.size


def _rotate(pixels: dict[tuple[int, int], str], pivot: tuple[float, float], degrees: float) -> dict[tuple[int, int], str]:
    """A sharp pixel-art rotation: 4x sample grid, rotated nearest, majority vote back to 1x (no blur, no new colours)."""
    if abs(degrees) < 0.01 or not pixels:
        return dict(pixels)
    k = 4
    rad = math.radians(degrees)
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    xs = [x for x, _ in pixels]
    ys = [y for _, y in pixels]
    # bounds of the rotated part
    corners = [(min(xs), min(ys)), (max(xs) + 1, min(ys)), (min(xs), max(ys) + 1), (max(xs) + 1, max(ys) + 1)]
    rot = [(pivot[0] + (cx - pivot[0]) * cos_a - (cy - pivot[1]) * sin_a, pivot[1] + (cx - pivot[0]) * sin_a + (cy - pivot[1]) * cos_a) for cx, cy in corners]
    x0, x1 = math.floor(min(p[0] for p in rot)) - 1, math.ceil(max(p[0] for p in rot)) + 1
    y0, y1 = math.floor(min(p[1] for p in rot)) - 1, math.ceil(max(p[1] for p in rot)) + 1
    out: dict[tuple[int, int], str] = {}
    for oy in range(y0, y1):
        for ox in range(x0, x1):
            votes: Counter = Counter()
            for sy in range(k):
                for sx in range(k):
                    # sample point in the output pixel, rotated back into the source
                    px = ox + (sx + 0.5) / k - pivot[0]
                    py = oy + (sy + 0.5) / k - pivot[1]
                    src_x = pivot[0] + px * cos_a + py * sin_a
                    src_y = pivot[1] - px * sin_a + py * cos_a
                    votes[pixels.get((math.floor(src_x), math.floor(src_y)), ".")] += 1
            best = votes.most_common()
            pick = best[0][0]
            if pick == "." and len(best) > 1 and best[0][1] < 10:  # keep thin edges unless the pixel is mostly empty
                pick = best[1][0]
            if pick != ".":
                out[(ox, oy)] = pick
    return out


def _hash01(x: int, y: int, salt: int) -> float:
    h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    h = (h * 1103515245 + 12345) & 0x7FFFFFFF
    return (h % 10000) / 10000.0


def _point_after(part: str, frame: dict, point: tuple[float, float]) -> tuple[float, float]:
    """Where a source point of `part` ends up in this frame (for the attachments)."""
    x, y = point
    angle = frame["angles"].get(part, 0.0)
    if part in PARTS and abs(angle) > 0.01:
        px, py = PARTS[part][1]
        rad = math.radians(angle)
        x, y = px + (x - px) * math.cos(rad) - (y - py) * math.sin(rad), py + (x - px) * math.sin(rad) + (y - py) * math.cos(rad)
    if part in UPPER:
        x, y = x + frame["body"][0], y + frame["body"][1]
    return x, y


def render(parts: dict[str, dict[tuple[int, int], str]], frame: dict) -> dict[tuple[int, int], str]:
    canvas: dict[tuple[int, int], str] = {}
    for name in DRAW_ORDER:
        pixels = parts[name]
        angle = frame["angles"].get(name, 0.0)
        if name in PARTS:
            pixels = _rotate(pixels, PARTS[name][1], angle)
        dx, dy = frame["body"] if name in UPPER else (0, 0)
        if name in frame["legs"]:
            dx, dy = frame["legs"][name]
        for (x, y), s in pixels.items():
            if name == "torso" and RUNE_BOX[0] <= x < RUNE_BOX[2] and RUNE_BOX[1] <= y < RUNE_BOX[3]:
                if frame["rune"] == "dark":
                    s = RUNE_DARK.get(s, s)
                elif frame["rune"] == "bright":
                    s = RUNE_BRIGHT.get(s, s)
            canvas[(x + dx, y + dy)] = s
    if frame["dissolve"] > 0.0:
        # the body crumbles from the top down into moss and root fragments
        top = min(y for _, y in canvas)
        bottom = max(y for _, y in canvas)
        for (x, y) in list(canvas):
            height = (bottom - y) / max(1, bottom - top)
            if _hash01(x, y, 7) < frame["dissolve"] * (0.55 + 0.9 * height):
                del canvas[(x, y)]
    return canvas


def to_grid(canvas: dict[tuple[int, int], str]) -> tuple[list[str], tuple[int, int]]:
    """Trimmed rows (multiples of 8, the feet kept inside) and the anchor (feet) within them."""
    fx, fy = FEET
    xs = [x for x, _ in canvas] + [fx]
    ys = [y for _, y in canvas] + [fy]
    left, top = min(xs), min(ys)
    width = (max(xs) + 1 - left + 7) // 8 * 8
    height = (max(ys) + 1 - top + 7) // 8 * 8
    rows = ["".join(canvas.get((x, y), ".") for x in range(left, left + width)) for y in range(top, top + height)]
    return rows, (fx - left, fy - top)


def build() -> dict[str, tuple[list[str], tuple[int, int], dict]]:
    parts, _ = cut()
    out: dict[str, tuple[list[str], tuple[int, int], dict]] = {}
    for state, frames in poses().items():
        for n, frame in enumerate(frames, start=1):
            rows, anchor = to_grid(render(parts, frame))
            chest = _point_after("torso", frame, RUNE_CENTRE)
            hook = _point_after("near_arm", frame, HOOK)
            attach = {"chest": [round((chest[0] - FEET[0]) / 2.5, 2), round((chest[1] - FEET[1]) / 2.5, 2)],
                      "hook": [round((hook[0] - FEET[0]) / 2.5, 2), round((hook[1] - FEET[1]) / 2.5, 2)]}
            out[f"warden_{state}_right_{n}"] = (rows, anchor, attach)
    return out


def sheet(frames: dict[str, tuple[list[str], tuple[int, int], dict]], path: Path) -> None:
    _, from_symbol = _palette()
    cell, scale, cols = 150, 3, 8
    names = list(frames)
    rows_n = (len(names) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell * scale, rows_n * (cell + 14) * scale), (24, 22, 28))
    d = ImageDraw.Draw(img)
    for i, name in enumerate(names):
        rows, (ax, ay), _ = frames[name]
        tile = Image.new("RGB", (cell, cell), (70, 74, 58))
        ox, oy = cell // 2 - ax, cell - 8 - ay
        for y, row in enumerate(rows):
            for x, s in enumerate(row):
                if s != "." and 0 <= ox + x < cell and 0 <= oy + y < cell:
                    tile.putpixel((ox + x, oy + y), from_symbol[s])
        cx, cy = (i % cols) * cell * scale, (i // cols) * (cell + 14) * scale
        img.paste(tile.resize((cell * scale, cell * scale), Image.NEAREST), (cx, cy + 14 * scale))
        d.text((cx + 6, cy + 8), name.replace("warden_", "").replace("_right", ""), fill=(240, 236, 214))
    img.save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sheet", action="store_true")
    args = parser.parse_args()
    frames = build()
    old = sorted(p.stem for p in (ROOT / "art/src").glob("warden_*.txt"))
    for stale in set(old) - set(frames):
        (ROOT / "art/src" / f"{stale}.txt").unlink()
    attachments = {}
    for name, (rows, (ax, ay), attach) in frames.items():
        (ROOT / "art/src" / f"{name}.txt").write_text(f"# kind: sprite\n# anchor: {ax},{ay}\n" + "\n".join(rows) + "\n", encoding="utf-8", newline="\n")
        attachments[name] = attach
    (ROOT / "presentation/explore/warden_attachments.json").write_text(json.dumps(attachments, indent=2) + "\n", encoding="utf-8", newline="\n")
    if args.sheet:
        sheet(frames, ROOT / "art/reference/warden_v2_detailed/poses_contact_sheet.png")
    print(f"Warden v2 poses: {len(frames)} frames written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
