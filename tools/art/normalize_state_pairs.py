#!/usr/bin/env python3
"""Puts the two states of one prop (a pedestal unlit / lit, a gate closed / open) on ONE canvas with ONE anchor.

The image generator draws every state separately, so the two cut-outs are close but not pixel-identical and differ by a
few pixels in size and anchor. The scene shows a state by swapping the type (core/prop_scene.gd placements with a
state), so both must stand at the same place: this tool aligns the variant on the base (bottom rows together, best overlap of
the opaque pixels over a few pixels of horizontal search), pads both onto the union canvas (transparent pixels only on the top, left and right:
the bottom row is the ground line and stays where it is), and writes the same w, h, anchor and base_width into both defs
entries. Colliders are NOT touched (they are per type and hand-tuned: a closed gate is solid across the doorway, an open
one only at its trunks). The pixels are copied, never resampled or recoloured.

  python tools/art/normalize_state_pairs.py --dir data/props/cutouts_forest --pair forest_pedestal:forest_pedestal_lit
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def opaque(image: Image.Image) -> set[tuple[int, int]]:
    px = image.load()
    return {(x, y) for y in range(image.height) for x in range(image.width) if px[x, y][3] > 0}


def best_offset(base: Image.Image, variant: Image.Image, search: int, free_y: bool) -> tuple[int, int, float]:
    """(dx, dy) that moves `variant` onto `base` with the best overlap of the opaque pixels (intersection over union).
    Unless `free_y`, the bottom rows stay together (the ground line), so only dx is searched."""
    a = opaque(base)
    b = opaque(variant)
    bottom = base.height - variant.height
    best = (0, bottom, -1.0)
    for dy in ([bottom] if not free_y else range(bottom - search, bottom + search + 1)):
        for dx in range(-search, search + 1):
            moved = {(x + dx, y + dy) for x, y in b}
            union = len(a | moved)
            score = len(a & moved) / union if union else 0.0
            if score > best[2]:
                best = (dx, dy, score)
    return best


def normalize(defs_path: Path, folder: Path, base_name: str, variant_name: str, search: int, free_y: bool) -> dict:
    document = json.loads(defs_path.read_text(encoding="utf-8"))
    props = document["props"]
    base_entry = props[base_name]
    variant_entry = props[variant_name]
    base = Image.open(folder / base_entry["image"]).convert("RGBA")
    variant = Image.open(folder / variant_entry["image"]).convert("RGBA")
    # both cut-outs end on their ground line: the bottom rows stay together, only the horizontal offset is searched
    dx, dy, score = best_offset(base, variant, search, free_y)
    # the variant's top-left corner on the base's grid
    vx = dx
    vy = dy
    left = min(0, vx)
    top = min(0, vy)
    right = max(base.width, vx + variant.width)
    bottom = max(base.height, vy + variant.height)
    width = right - left
    height = bottom - top
    out_base = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out_base.paste(base, (-left, -top))
    out_variant = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out_variant.paste(variant, (vx - left, vy - top))
    anchor = [base_entry["anchor"][0] - left, base_entry["anchor"][1] - top]
    out_base.save(folder / base_entry["image"])
    out_variant.save(folder / variant_entry["image"])
    for entry in (base_entry, variant_entry):
        entry["w"] = width
        entry["h"] = height
        entry["anchor"] = anchor
        entry["base_width"] = base_entry["base_width"]
        entry["state_pair"] = [base_name, variant_name]
    defs_path.write_text(json.dumps(document, indent=1) + "\n", encoding="utf-8")
    return {"base": base_name, "variant": variant_name, "canvas": [width, height], "anchor": anchor,
            "variant_offset": [vx - left, vy - top], "overlap": round(score, 3)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--defs", default=str(ROOT / "data/props/prop_defs.json"))
    parser.add_argument("--dir", required=True, help="folder with the cut-outs (the defs' 'image' names)")
    parser.add_argument("--pair", action="append", required=True, help="base:variant (repeatable)")
    parser.add_argument("--search", type=int, default=8, help="alignment search radius in pixels")
    parser.add_argument("--free-y", action="store_true", help="also search vertically (default: bottom rows stay together)")
    args = parser.parse_args()
    for pair in args.pair:
        base_name, variant_name = pair.split(":")
        report = normalize(Path(args.defs), Path(args.dir), base_name, variant_name, args.search, args.free_y)
        print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
