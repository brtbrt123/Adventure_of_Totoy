"""One JSON line per run in harness/logs/runs.jsonl (gitignored). Used to tune routing and enforce the daily cap."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def append_run(log_path: Path, record: dict[str, Any]) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    record = {"timestamp": datetime.now(timezone.utc).isoformat(timespec="seconds"), **record}
    with open(log_path, "a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def read_runs(log_path: Path) -> list[dict[str, Any]]:
    if not log_path.exists():
        return []
    runs = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            try:
                runs.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return runs


def heavy_rounds_today(log_path: Path) -> int:
    """Count the rounds that used the heavy tier today (UTC)."""
    today = datetime.now(timezone.utc).date().isoformat()
    total = 0
    for run in read_runs(log_path):
        if str(run.get("timestamp", ""))[:10] == today:
            total += sum(1 for r in run.get("rounds", []) if r.get("tier") == "heavy")
    return total
