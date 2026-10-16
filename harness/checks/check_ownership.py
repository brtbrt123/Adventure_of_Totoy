"""Fail if files outside the owned folders changed in a task worktree.

Usage: python harness/checks/check_ownership.py --worktree DIR --base SHA --owned core/,docs/
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import _common  # noqa: F401  (puts the repo root on sys.path)
from harness.lib import gitutil, ownership
from harness.lib.config import load_config


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--worktree", type=Path, required=True)
    parser.add_argument("--base", required=True, help="commit the task branched from")
    parser.add_argument("--owned", required=True, help="comma-separated folders the agent may edit")
    args = parser.parse_args()
    changed = gitutil.changed_files(args.worktree, args.base)
    owned = [o for o in args.owned.split(",") if o]
    bad = ownership.owned_violations(changed, owned, load_config().get("always_allowed", []))
    if bad:
        print(f"OWNERSHIP VIOLATION: {len(bad)} file(s) outside {owned}:")
        for path in bad:
            print(f"  - {path}")
        return 1
    print(f"ok: {len(changed)} changed file(s), all inside {owned} or generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
