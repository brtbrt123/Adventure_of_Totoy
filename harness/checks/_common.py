"""Shared helpers for the check scripts. A check exits 0 on success, non-zero on failure, and prints plain-text errors."""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

# The console build prints to a terminal on Windows (the regular build does not reliably). Not on PATH.
DEFAULT_GODOT = r"C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"


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
    """The Godot console executable: HARNESS_GODOT if set, else the installed 4.7.2 console build."""
    return os.environ.get("HARNESS_GODOT", "") or DEFAULT_GODOT
