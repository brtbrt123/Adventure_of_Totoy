"""Render the depth occluders' footprints over each scene's ground for review.

Reads presentation/common/occluders/<scene>_occluders.png + .json (or another folder with --occluders) and the ground,
and draws the ground ZOOM times larger with every occluder pixel filled with translucent magenta (so ground pixels that
slipped into a cut-out show as magenta grass / dirt), each occluder's base line in red and its id. With --before DIR the
image is two panels: the footprints from DIR on top ("before"), the current ones below ("after").
Writes docs/previews/occluder_footprints_<scene>.png (or --out DIR). Deterministic.
Run from the project root:  python tools/art/preview_occluder_footprints.py [--zoom 3] [--before DIR] [--out DIR] [--scene S]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402

ROOT = artlib.ROOT
OCC = ROOT / "presentation" / "common" / "occluders"
OUT = ROOT / "docs" / "previews"
SCENES = ("village", "forest", "glade", "arena")


def footprint(scene: str, folder: Path, zoom: int, label: str) -> Image.Image:
    manifest = json.loads((folder / f"{scene}_occluders.json").read_text(encoding="utf-8"))
    atlas = Image.open(folder / f"{scene}_occluders.png").convert("RGBA")
    ground = Image.open(ROOT / manifest["ground"].replace("res://", "")).convert("RGB")
    covered = Image.new("L", ground.size, 0)
    cpx = covered.load()
    apx = atlas.load()
    for occ in manifest["occluders"]:
        rx, ry, rw, rh = occ["rect"]
        ax, ay = occ["atlas"]
        for dy in range(rh):
            for dx in range(rw):
                if apx[ax + dx, ay + dy][3] == 255:
                    cpx[rx + dx, ry + dy] = 255
    tint = Image.new("RGB", ground.size, (255, 0, 255))
    shown = Image.composite(Image.blend(ground, tint, 0.45), ground, covered)
    shown = shown.resize((ground.width * zoom, ground.height * zoom), Image.NEAREST)
    d = ImageDraw.Draw(shown)
    for occ in manifest["occluders"]:
        rx, ry, rw, rh = occ["rect"]
        d.line([(rx * zoom, occ["base_y"] * zoom), ((rx + rw) * zoom, occ["base_y"] * zoom)], fill=(255, 40, 40), width=1)
        d.text((rx * zoom + 1, ry * zoom + 1), occ["id"], fill=(255, 255, 255))
    d.text((4, 4), f"{scene}: {label}", fill=(255, 255, 0))
    return shown


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--zoom", type=int, default=3)
    ap.add_argument("--before", type=Path, default=None, help="a folder with the earlier atlases: two panels")
    ap.add_argument("--out", type=Path, default=OUT)
    ap.add_argument("--scene", default="")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for scene in SCENES:
        if args.scene and scene != args.scene:
            continue
        after = footprint(scene, OCC, args.zoom, "after" if args.before else "occluder pixels in magenta")
        img = after
        if args.before is not None and (args.before / f"{scene}_occluders.json").exists():
            before = footprint(scene, args.before, args.zoom, "before")
            img = Image.new("RGB", (after.width, after.height * 2 + 8), (0, 0, 0))
            img.paste(before, (0, 0))
            img.paste(after, (0, after.height + 8))
        path = args.out / f"occluder_footprints_{scene}.png"
        img.save(path)
        print("wrote", path, img.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
