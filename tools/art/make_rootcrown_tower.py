"""Rootcrown v2: cut the beacon tower (dark and lit) out of its two Higgsfield pictures, at game scale, in the palette.

Inputs (art/reference/rootcrown_v2/, provenance in sources.json there):
  tower_dark_raw.png   the unlit tower on #FF00FF, made with tower_refs.png (existing forest props) as the only reference
  tower_lit_raw.png    an edit of the dark picture: the same tower with the beacon burning

Both are keyed with the prop extractor's magenta test, cut from ONE shared box at ONE scale so the two states line up
pixel for pixel (a state pair on one canvas), area-averaged from the prop's own pixels, alpha held at one half and
snapped to Totoy 36 without the reserved gold and red (tools/art/extract_props.py: opaque_mask, Snapper).

Outputs (review art for the owner, not art/src yet):
  art/reference/rootcrown_v2/tower_dark.png, tower_lit.png   the two cut-outs, same size; the anchor is printed
  art/reference/rootcrown_v2/tower_review_3x.png             both towers beside the forest props they were made from
  art/reference/rootcrown_v2/tower_cast.png, tower_cast_flipped.png   the moonlight cast shadow (as every fx_shadow_* is made)
  tower_cut.json also holds the contact shadow rows and the cast shadows' feet, like a prop scene's metadata

Run: python tools/art/make_rootcrown_tower.py [--height 144]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from extract_props import Snapper, opaque_mask, base_info  # noqa: E402
from make_village_walls import cast_shadow, contact_shadow  # noqa: E402  (the shadow makers every new prop uses)

ROOT = artlib.ROOT
HERE = ROOT / "art" / "reference" / "rootcrown_v2"
SPRITES = ROOT / "art" / "build" / "sprites"
TOL = 60


def mask_of(img: Image.Image) -> np.ndarray:
    m = np.array(opaque_mask(img, TOL), dtype=bool)
    # keep the biggest connected body: drop stray specks the generator left on the background
    h, w = m.shape
    seen = np.zeros_like(m)
    best: list[tuple[int, int]] = []
    for y0 in range(0, h, 2):
        for x0 in range(0, w, 2):
            if not m[y0, x0] or seen[y0, x0]:
                continue
            stack, part = [(y0, x0)], []
            seen[y0, x0] = True
            while stack:
                y, x = stack.pop()
                part.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(part) > len(best):
                best = part
    keep = np.zeros_like(m)
    ys, xs = zip(*best)
    keep[list(ys), list(xs)] = True
    # small detached bits close to the body (pebbles, a loose leaf) stay: anything within 12 px of it
    near = keep.copy()
    for _ in range(12):
        grown = near.copy()
        grown[1:] |= near[:-1]
        grown[:-1] |= near[1:]
        grown[:, 1:] |= near[:, :-1]
        grown[:, :-1] |= near[:, 1:]
        near = grown
    return m & near


def cut(img: Image.Image, mask: np.ndarray, box: tuple[int, int, int, int], size: tuple[int, int], snap: Snapper) -> Image.Image:
    x0, y0, x1, y1 = box
    rgb = np.asarray(img.convert("RGB"), dtype=np.float64)[y0:y1, x0:x1]
    m = mask[y0:y1, x0:x1].astype(np.float64)

    def box_resize(a: np.ndarray) -> np.ndarray:
        return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize(size, Image.Resampling.BOX), dtype=np.float64)

    cover = box_resize(m)
    sums = [box_resize(rgb[..., c] * m) for c in range(3)]
    w, h = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    px = out.load()
    for y in range(h):
        for x in range(w):
            if cover[y, x] >= 0.5:
                c = tuple(int(round(s[y, x] / cover[y, x])) for s in sums)
                r, g, b = snap.snap(c)
                px[x, y] = (r, g, b, 255)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--height", type=int, default=144, help="game height of the dark tower, roots included")
    a = ap.parse_args()
    dark_raw = Image.open(HERE / "tower_dark_raw.png").convert("RGB")
    lit_raw = Image.open(HERE / "tower_lit_raw.png").convert("RGB")
    md, ml = mask_of(dark_raw), mask_of(lit_raw)
    both = md | ml
    ys, xs = np.nonzero(both)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    dys = np.nonzero(md)[0]
    scale = a.height / (dys.max() + 1 - dys.min())
    size = (round((box[2] - box[0]) * scale), round((box[3] - box[1]) * scale))
    snap = Snapper(artlib.load_palette())
    dark = cut(dark_raw, md, box, size, snap)
    lit = cut(lit_raw, ml, box, size, snap)
    dark.save(HERE / "tower_dark.png")
    lit.save(HERE / "tower_lit.png")
    info = base_info(dark)
    casts = {}
    for name, flipped in (("tower_cast.png", False), ("tower_cast_flipped.png", True)):
        img, feet, _ = cast_shadow(dark, tuple(info["anchor"]), flipped)
        img.save(HERE / name)
        casts["flipped" if flipped else "normal"] = {"image": name, "feet": feet}
    (HERE / "tower_cut.json").write_text(json.dumps({"size": list(size), "scale": round(scale, 4), "source_box": list(box),
                                                       "anchor": info["anchor"], "base_width": info["base_width"],
                                                       "contact_shadow": contact_shadow(size[0], size[1]),
                                                       "cast_shadow": casts}, indent=1), encoding="utf-8")
    # review: the two towers beside the props they were made from, 3x on grey
    refs = ["forest_standing_stone", "glade_stone_2", "root_hollow_tree_rootwall", "forest_pedestal", "root_hollow_rune_stones"]
    items = [("tower dark", dark), ("tower lit", lit)] + [(n, Image.open(SPRITES / f"{n}.png").convert("RGBA")) for n in refs]
    items = [(n, im.crop(im.getbbox())) for n, im in items]
    Z, gap = 3, 18
    base = max(im.height for _, im in items) * Z
    width = sum(im.width * Z + gap for _, im in items) + gap
    sheet = Image.new("RGBA", (width, base + 2 * gap + 16), (96, 98, 104, 255))
    d = ImageDraw.Draw(sheet)
    x = gap
    for n, im in items:
        big = im.resize((im.width * Z, im.height * Z), Image.Resampling.NEAREST)
        sheet.alpha_composite(big, (x, gap + base - big.height))
        d.text((x, gap + base + 6), n, fill=(255, 255, 255, 255))
        x += big.width + gap
    sheet.save(HERE / "tower_review_3x.png")
    print(f"tower {size[0]}x{size[1]} at scale {scale:.4f}, anchor {info['anchor']}, base width {info['base_width']}")


if __name__ == "__main__":
    main()
