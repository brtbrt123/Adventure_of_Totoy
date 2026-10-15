"""Validate art sources and built PNGs. Exits 1 with a clear message on any problem.

Usage: python tools/art/validate_art.py [--src DIR] [--build DIR] [--no-png]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import artlib


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", type=Path, default=artlib.SRC_DIR, help="folder of .txt sprite grids")
    parser.add_argument("--build", type=Path, default=artlib.BUILD_DIR, help="folder of built PNGs to check")
    parser.add_argument("--palette", type=Path, default=artlib.PALETTE_PATH)
    parser.add_argument("--no-png", action="store_true", help="skip checking built PNGs")
    args = parser.parse_args()

    try:
        palette = artlib.load_palette(args.palette)
    except artlib.PaletteError as exc:
        print(f"FAIL: {exc}")
        return 1

    sprites, errors = artlib.collect(args.src, palette)

    checked_png = 0
    if not args.no_png and args.build.is_dir():
        for png in sorted(args.build.rglob("*.png")):
            if png.name == "contact_sheet.png" or png.name.startswith("arena_"):
                continue  # contact sheet and in-game screenshots are previews, not game art
            checked_png += 1
            for message in artlib.check_png(png, palette):
                errors.append(f"{png.relative_to(args.build).as_posix()}: {message}")

    if errors:
        print(f"FAIL: {len(errors)} problem(s) found")
        for line in errors:
            print(f"  - {line}")
        return 1
    print(f"OK: {len(sprites)} sprite source(s) and {checked_png} built PNG(s) passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
