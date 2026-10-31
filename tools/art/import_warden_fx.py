"""Imports the Runebound Warden's attack effects Gemini drew (owner 2026-10-31: "improve the warden attack effects").

Sources: art/reference/warden_fx_gemini/Warden_*.jpg (cells of frames on a magenta background, lines between the cells; JPEG). For each
sheet this tool finds the cells (the dark separator lines, or a fixed grid), keys out the magenta and the pink smoke/glow fringe,
snaps every pixel to Totoy 36 (each effect only gets the colours it may use: gold only on the parryable Cleave, red only on the dodge
attacks), shrinks the sheet with ONE scale so a reference frame matches the effect's real hit size, and writes
art/src/fx_warden2_<effect>_<n>.txt with an `# anchor:` where the effect attaches in the game:

    cleave       anchor = the Warden's feet; the slash's outer rim sits on the 58 px hit edge (reach 46 + radius 12), pointing right
    lash         one root clump (8 frames); presentation plants five along the 150 px line; anchor = the clump's base (ground)
    lash_crack   the windup crack; anchor = its back end, at the feet; the last frame is the line's full 150 px
    ring         the shock ring around the feet; frame 4's outer edge is the 48 px hit radius; anchor = the centre
    ring_charge  the spores spiralling into the chest stone (frames 1-4, looped); anchor = the centre (the chest)
    guard_hit, guard_break   at the chest stone; anchor = the centre of the burst
    footstep     the footfall dust; anchor = the foot on the ground

Gemini does not hold the requested cell sizes or keep frames in place, so each frame is aligned by its own content where the sheet's
placement is unreliable (see ANCHORS). Deterministic: the same sources give the same grids.

    python tools/art/import_warden_fx.py            # then validate/build/preview as usual
    python tools/art/import_warden_fx.py --sheet    # also a contact sheet of every frame in art/reference/warden_fx_gemini/
"""
from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/reference/warden_fx_gemini"
PREFIX = "fx_warden2_"

BASE = set("012345678abcdefghijtuop")  # ink, cream, moss, bark/dirt, stone, rune teal
GOLD = BASE | {"x", "y"}
RED = BASE | {"z", "A"}

CLEAVE_RIM = 58.0  # px: the Cleave cone's size (core/tuning.gd warden_cleave reach 46 + the Warden's radius 12)

# effect -> (file, grid (cols, rows) or None to find the lines, frames to keep, reference frame, measure, game px, anchor, palette)
SHEETS: dict[str, tuple] = {
    "cleave": ("Warden_Cleave.jpg", None, None, 3, "h", 2 * CLEAVE_RIM * math.sin(0.9), "rim", GOLD),
    "lash": ("Warden_Lash.jpg", None, None, 4, "h", 28, "ground", RED),
    "lash_crack": ("Warden_LashCrack.jpg", None, 6, 5, "w", 150, "back", RED),
    "ring": ("Warden_Ring.jpg", None, None, 3, "w", 96, "cell", RED),
    "ring_charge": ("Warden_RingCharge.jpg", (3, 2), 4, 3, "w", 40, "cell", BASE),
    "guard_hit": ("Warden_GuardHit.jpg", None, None, 2, "w", 28, "box", BASE),
    "guard_break": ("Warden_GuardBreak.jpg", None, None, 3, "w", 44, "cell", BASE),
    "footstep": ("Warden_Footstep.jpg", None, None, 2, "w", 26, "foot", BASE),
}


def palette() -> dict[str, tuple[int, int, int]]:
    data = json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))
    return {c["symbol"]: tuple(bytes.fromhex(c["hex"][1:])) for c in data["colors"]}


def background(r: int, g: int, b: int) -> bool:
    """The magenta, and the pink smoke/glow Gemini blended into it (a soft edge the game cannot draw)."""
    return (r > 140 and b > 140 and g < 130) or (r - g > 55 and b - g > 55)


def dark(r: int, g: int, b: int) -> bool:
    return r + g + b < 140


def cells(im: Image.Image, grid: tuple[int, int] | None) -> list[tuple[int, int, int, int]]:
    """Frame boxes, row by row. With no grid, the dark separator lines are found (rows may have different column counts)."""
    w, h = im.size
    px = im.load()
    inset = 14  # stay clear of the separator lines and the JPEG ringing beside them
    if grid is not None:
        cols, rows = grid
        return [(c * w // cols + inset, r * h // rows + inset, (c + 1) * w // cols - inset, (r + 1) * h // rows - inset)
                for r in range(rows) for c in range(cols)]

    def runs(flags: list[bool]) -> list[tuple[int, int]]:
        spans, start = [], None
        for i, f in enumerate(flags + [True]):
            if not f and start is None:
                start = i
            elif f and start is not None:
                spans.append((start, i))
                start = None
        return [s for s in spans if s[1] - s[0] > 60]

    row_sep = [sum(dark(*px[x, y]) for x in range(0, w, 2)) > 0.6 * (w // 2) for y in range(h)]
    out = []
    for y0, y1 in runs(row_sep):
        col_sep = [sum(dark(*px[x, y]) for y in range(y0, y1, 2)) > 0.6 * ((y1 - y0) // 2) for x in range(w)]
        for x0, x1 in runs(col_sep):
            out.append((x0 + inset, y0 + inset, x1 - inset, y1 - inset))
    return out


def content_box(im: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    """The art's bounding box inside a cell (rows/columns with a few non-background pixels, so JPEG specks do not count)."""
    px = im.load()
    x0, y0, x1, y1 = box
    cols = [x for x in range(x0, x1) if sum(not background(*px[x, y]) for y in range(y0, y1, 2)) >= 2]
    rows = [y for y in range(y0, y1) if sum(not background(*px[x, y]) for x in range(x0, x1, 2)) >= 2]
    return (min(cols), min(rows), max(cols) + 1, max(rows) + 1)


def shrink(im: Image.Image, box: tuple[int, int, int, int], scale: float, allowed: set[str],
           colours: dict[str, tuple[int, int, int]]) -> dict[tuple[int, int], str]:
    """The cell at `scale` game px per image px: every output pixel is the majority symbol of a 3x3 sample of its block (the
    background must win clearly, so thin outlines survive), each sample snapped to the nearest allowed colour."""
    px = im.load()
    x0, y0, x1, y1 = box
    out_w = int((x1 - x0) * scale)
    out_h = int((y1 - y0) * scale)
    step = 1.0 / scale
    choices = {s: colours[s] for s in allowed}
    cache: dict[tuple[int, int, int], str] = {}

    def symbol(r: int, g: int, b: int) -> str:
        if background(r, g, b):
            return "."
        key = (r >> 2, g >> 2, b >> 2)
        if key not in cache:
            cache[key] = min(choices, key=lambda s: 2 * (r - choices[s][0]) ** 2 + 4 * (g - choices[s][1]) ** 2 + 3 * (b - choices[s][2]) ** 2)
        return cache[key]

    out: dict[tuple[int, int], str] = {}
    for oy in range(out_h):
        for ox in range(out_w):
            votes: Counter = Counter()
            for sy in range(3):
                for sx in range(3):
                    x = min(x1 - 1, int(x0 + (ox + (sx + 0.5) / 3) * step))
                    y = min(y1 - 1, int(y0 + (oy + (sy + 0.5) / 3) * step))
                    votes[symbol(*px[x, y])] += 1
            ranked = votes.most_common()
            pick = ranked[0][0]
            if pick == "." and len(ranked) > 1 and ranked[0][1] < 6:
                pick = ranked[1][0]
            if pick != ".":
                out[(ox, oy)] = pick
    return out


def to_rows(canvas: dict[tuple[int, int], str], anchor: tuple[int, int]) -> tuple[list[str], tuple[int, int]]:
    """Trimmed rows (multiples of 8, the anchor kept inside) and the anchor within them."""
    xs = [x for x, _ in canvas] + [anchor[0]]
    ys = [y for _, y in canvas] + [anchor[1]]
    left, top = min(xs), min(ys)
    width = (max(xs) + 1 - left + 7) // 8 * 8
    height = (max(ys) + 1 - top + 7) // 8 * 8
    rows = ["".join(canvas.get((x, y), ".") for x in range(left, left + width)) for y in range(top, top + height)]
    return rows, (anchor[0] - left, anchor[1] - top)


def import_sheet(name: str, colours: dict[str, tuple[int, int, int]]) -> list[tuple[list[str], tuple[int, int]]]:
    file, grid, keep, ref, measure, target, anchor_mode, allowed = SHEETS[name]
    im = Image.open(SOURCE / file).convert("RGB")
    boxes = cells(im, grid)
    if keep is not None:
        boxes = boxes[:keep]
    ref_box = content_box(im, boxes[ref])
    size = (ref_box[3] - ref_box[1]) if measure == "h" else (ref_box[2] - ref_box[0])
    scale = target / size
    frames = []
    shrunk = [shrink(im, box, scale, allowed, colours) for box in boxes]
    ground = max(max(y for _, y in c) for c in shrunk if c)  # the lash clumps share one ground line
    for box, canvas in zip(boxes, shrunk):
        if not canvas:
            continue
        xs = [x for x, _ in canvas]
        ys = [y for _, y in canvas]
        cw, ch = int((box[2] - box[0]) * scale), int((box[3] - box[1]) * scale)
        if anchor_mode == "rim":  # the outer rim on the hit edge, the slash centred on the cone's axis
            anchor = (round(max(xs) - CLEAVE_RIM), round((min(ys) + max(ys)) / 2))
        elif anchor_mode == "ground":
            anchor = (cw // 2, ground)
        elif anchor_mode == "back":  # the crack's back end at the feet, on its own centre line
            anchor = (min(xs), round(sorted(ys)[len(ys) // 2]))
        elif anchor_mode == "cell":
            anchor = (cw // 2, ch // 2)
        elif anchor_mode == "box":
            anchor = (round((min(xs) + max(xs)) / 2), round((min(ys) + max(ys)) / 2))
        else:  # "foot": the bottom of the dust, its middle
            anchor = (round((min(xs) + max(xs)) / 2), max(ys))
        frames.append(to_rows(canvas, anchor))
    return frames


def contact_sheet(all_frames: dict[str, list[tuple[list[str], tuple[int, int]]]], colours: dict, path: Path) -> None:
    scale, pad = 4, 6
    rows_img = []
    for name, frames in all_frames.items():
        w = sum(len(r[0]) + pad for r, _ in frames) + pad
        h = max(len(r) for r, _ in frames) + pad * 2 + 10
        img = Image.new("RGB", (w, h), (74, 62, 52))
        d = ImageDraw.Draw(img)
        d.text((2, 0), name, fill=(240, 236, 214))
        x = pad
        for rows, (ax, ay) in frames:
            for y, row in enumerate(rows):
                for xx, s in enumerate(row):
                    if s != ".":
                        img.putpixel((x + xx, 10 + pad + y), colours[s])
            img.putpixel((x + ax, 10 + pad + ay), (255, 0, 255))  # the anchor
            x += len(rows[0]) + pad
        rows_img.append(img)
    width = max(i.width for i in rows_img)
    sheet = Image.new("RGB", (width, sum(i.height for i in rows_img)), (24, 22, 28))
    y = 0
    for i in rows_img:
        sheet.paste(i, (0, y))
        y += i.height
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sheet", action="store_true")
    args = parser.parse_args()
    colours = palette()
    for stale in (ROOT / "art/src").glob(PREFIX + "*.txt"):
        stale.unlink()
    all_frames = {}
    for name in SHEETS:
        frames = import_sheet(name, colours)
        all_frames[name] = frames
        for n, (rows, (ax, ay)) in enumerate(frames, start=1):
            text = f"# kind: sprite\n# anchor: {ax},{ay}\n" + "\n".join(rows) + "\n"
            (ROOT / "art/src" / f"{PREFIX}{name}_{n}.txt").write_text(text, encoding="utf-8", newline="\n")
        print(f"{name}: {len(frames)} frames, largest {max(len(r[0]) for r, _ in frames)}x{max(len(r) for r, _ in frames)}")
    if args.sheet:
        contact_sheet(all_frames, colours, SOURCE / "imported_contact_sheet.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
