"""Load harness/config.json and locate the repository."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

HARNESS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = HARNESS_DIR.parent
DEFAULT_CONFIG = HARNESS_DIR / "config.json"


def load_config(path: Path | None = None) -> dict[str, Any]:
    with open(path or DEFAULT_CONFIG, encoding="utf-8") as handle:
        return json.load(handle)
