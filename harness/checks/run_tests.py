"""Run the Python tests and every headless Godot suite inside a task worktree.

Order: python unittest, Godot import, tests/run_tests.gd, then every tests/smoke_*.gd (capture scripts that need a
window are skipped). Each Godot run has a hard time limit and the whole process tree is killed on timeout.

Usage: python harness/checks/run_tests.py --worktree DIR [--timeout 300]
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import _common

SUCCESS_MARKERS = ("0 failed", "OK")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--worktree", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    wt: Path = args.worktree
    # Godot suites must never touch the player's real save file.
    os.environ["TOTOY_SAVE_PATH"] = "user://harness_check_save.json"
    failures: list[str] = []

    code, out = _common.run_limited([sys.executable, "-m", "unittest", "discover", "-s", "tests"], wt, args.timeout)
    print(f"$ python -m unittest discover -s tests -> exit {code}")
    if code != 0:
        failures.append("python unit tests failed:\n" + out[-3000:])

    godot = _common.godot_path()
    if not godot or not Path(godot).exists():
        print(f"Godot not found at {godot!r}")
        failures.append(f"Godot executable not found at {godot!r}: cannot run the Godot checks")
    else:
        steps = [("import", ["--headless", "--path", ".", "--import", "--quit"])]
        steps.append(("run_tests.gd", ["--headless", "--path", ".", "--script", "res://tests/run_tests.gd"]))
        for script in sorted((wt / "tests").glob("smoke_*.gd")):
            if "capture" in script.name:
                continue
            steps.append((script.name, ["--headless", "--path", ".", "--script", f"res://tests/{script.name}"]))
        for name, godot_args in steps:
            code, out = _common.run_limited([godot, *godot_args], wt, args.timeout)
            error_lines = [ln for ln in out.splitlines() if "SCRIPT ERROR" in ln or "Parse Error" in ln]
            failed_lines = [ln for ln in out.splitlines() if ln.startswith("FAIL") or " FAIL" in ln]
            print(f"$ godot {name} -> exit {code}")
            if code != 0 or error_lines:
                tail = "\n".join((error_lines + failed_lines)[:15]) or out[-1500:]
                failures.append(f"godot {name} failed (exit {code}):\n{tail}")

    if failures:
        print("\nFAILURES:")
        for item in failures:
            print(item)
        return 1
    print("all test suites passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
