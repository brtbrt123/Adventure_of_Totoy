"""Run the check scripts for a label. A check exits 0 on success and non-zero on failure and prints plain-text
errors, which are fed back to the builder as they are."""
from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class CheckResult:
    name: str
    ok: bool
    output: str


def check_names_for(label: str, cfg: dict[str, Any]) -> list[str]:
    return ["default"] + list(cfg.get("label_checks", {}).get(label, []))


def _expand(command: list[str], values: dict[str, str]) -> list[str]:
    expanded = []
    for part in command:
        for key, value in values.items():
            part = part.replace("{" + key + "}", value)
        expanded.append(part)
    if expanded and expanded[0] == "python":
        expanded[0] = sys.executable
    return expanded


def run_checks(label: str, worktree: Path, base_sha: str, repo_root: Path, cfg: dict[str, Any]) -> list[CheckResult]:
    values = {
        "worktree": str(worktree),
        "base_sha": base_sha,
        "owned": ",".join(cfg["rules"][label]["owned"]),
        "godot": cfg.get("godot", ""),
        "repo": str(repo_root),
    }
    results: list[CheckResult] = []
    timeout = int(cfg.get("check_timeout_seconds", 600))
    env = dict(os.environ)
    env["HARNESS_GODOT"] = cfg.get("godot", "")
    for name in check_names_for(label, cfg):
        for command in cfg["checks"].get(name, []):
            expanded = _expand(command, values)
            script = Path(expanded[1]).name if len(expanded) > 1 else expanded[0]
            label_text = f"{name}: {script}"
            try:
                done = subprocess.run(expanded, cwd=str(repo_root), capture_output=True, text=True, encoding="utf-8",
                                      errors="replace", timeout=timeout, env=env)
                output = (done.stdout + done.stderr).strip()
                results.append(CheckResult(label_text, done.returncode == 0, output))
            except subprocess.TimeoutExpired:
                results.append(CheckResult(label_text, False, f"check timed out after {timeout} seconds"))
            except OSError as exc:
                results.append(CheckResult(label_text, False, f"could not start the check: {exc}"))
    return results


def failure_text(results: list[CheckResult]) -> str:
    parts = [f"CHECK FAILED: {r.name}\n{r.output}" for r in results if not r.ok]
    return "\n\n".join(parts)
