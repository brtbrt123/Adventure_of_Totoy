"""Run an agent CLI (claude -p or codex exec) headless inside a task worktree, with a timeout.

No permission-skipping flags are ever added here. The prompt goes in through stdin. Codex's Windows
sandbox sometimes fails to start its shell (helper_unknown_error); that exact failure is retried.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

FORBIDDEN_FLAGS = ("--dangerously-skip-permissions", "--dangerously-bypass-approvals-and-sandbox",
                   "danger-full-access", "bypassPermissions")


@dataclass
class AgentResult:
    output: str
    returncode: int
    timed_out: bool
    seconds: float
    attempts: int
    sandbox_failed: bool


def _kill_tree(process: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(process.pid)], capture_output=True)
    else:
        process.kill()


def build_command(agent_cfg: dict[str, Any], role: str, model: str, cwd: Path, output_file: Path) -> list[str]:
    args_key = "builder_args" if role == "builder" else "reviewer_args"
    values = {"model": model, "cwd": str(cwd), "output_file": str(output_file)}
    args = [str(a).format(**values) for a in agent_cfg[args_key]]
    # Some models need extra CLI flags to work on this machine (see "model_args" in config.json).
    args += [str(a).format(**values) for a in agent_cfg.get("model_args", {}).get(model, [])]
    for flag in FORBIDDEN_FLAGS:
        if any(flag in a for a in args):
            raise ValueError(f"refusing to run: the agent command contains the forbidden flag {flag}")
    exe = agent_cfg["executable"]
    resolved = shutil.which(exe) or exe
    return [resolved, *args]


def run_agent(agent_cfg: dict[str, Any], role: str, model: str, prompt: str, cwd: Path, timeout: int) -> AgentResult:
    attempts_allowed = max(1, int(agent_cfg.get("retry_attempts", 1)))
    retry_patterns = [re.compile(p) for p in agent_cfg.get("retry_on", [])]
    started = time.time()
    last = AgentResult("", -1, False, 0.0, 0, False)
    for attempt in range(1, attempts_allowed + 1):
        with tempfile.TemporaryDirectory() as tmp:
            output_file = Path(tmp) / "last_message.txt"
            command = build_command(agent_cfg, role, model, cwd, output_file)
            process = subprocess.Popen(
                command, cwd=str(cwd), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace",
            )
            timed_out = False
            try:
                out, _ = process.communicate(prompt, timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                _kill_tree(process)
                out, _ = process.communicate()
            text = out or ""
            if agent_cfg.get("uses_output_file") and output_file.exists():
                final = output_file.read_text(encoding="utf-8", errors="replace")
            else:
                final = text
            sandbox_failed = any(p.search(text) for p in retry_patterns)
            last = AgentResult(final, process.returncode if not timed_out else -1, timed_out, time.time() - started,
                               attempt, sandbox_failed)
            if sandbox_failed and not timed_out and attempt < attempts_allowed:
                time.sleep(2)
                continue
            return last
    return last
