"""Run the art validator (palette, sizes, transparency, seams) inside a task worktree.

Usage: python harness/checks/validate_art.py --worktree DIR
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
    code, out = _common.run_limited([sys.executable, "tools/art/validate_art.py"], args.worktree, 300)
    print(out.strip())
    return 0 if code == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
