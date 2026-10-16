"""Shared helpers for the check scripts. A check exits 0 on success, non-zero on failure, and prints
plain-text errors that are fed back to the builder as they are."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

HARNESS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = HARNESS_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def kill_tree(process: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(process.pid)], capture_output=True)
    else:
        process.kill()


def run_limited(command: list[str], cwd: Path, timeout: int) -> tuple[int, str]:
    """Run a command with a hard time limit (kills the whole process tree on timeout). Returns (code, output)."""
    process = subprocess.Popen(command, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, encoding="utf-8", errors="replace")
    try:
        out, _ = process.communicate(timeout=timeout)
        return process.returncode, out or ""
    except subprocess.TimeoutExpired:
        kill_tree(process)
        out, _ = process.communicate()
        return -1, (out or "") + f"\nTIMEOUT: killed after {timeout} seconds"


def godot_path() -> str:
    explicit = os.environ.get("HARNESS_GODOT", "")
    if explicit:
        return explicit
    from harness.lib.config import load_config  # imported lazily so the path hack above has run

    return str(load_config().get("godot", ""))
