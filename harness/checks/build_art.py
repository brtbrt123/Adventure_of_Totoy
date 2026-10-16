"""Build the art (PNGs, atlases, tileset), validate the built PNGs and render the contact sheet.

Usage: python harness/checks/build_art.py --worktree DIR
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import _common


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--worktree", type=Path, required=True)
    args = parser.parse_args()
    for script in ("build_art.py", "validate_art.py", "preview_art.py"):
        code, out = _common.run_limited([sys.executable, f"tools/art/{script}"], args.worktree, 300)
        print(f"$ tools/art/{script}\n{out.strip()}")
        if code != 0:
            return 1
    print(f"contact sheet: {args.worktree / 'art' / 'build' / 'contact_sheet.png'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
