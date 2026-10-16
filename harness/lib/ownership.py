"""Folder ownership is enforced by this check, not by trusting the prompts."""
from __future__ import annotations

import re
from typing import Any


def normalize(path: str) -> str:
    path = path.replace("\\", "/")
    while path.startswith("./"):  # not lstrip("./"): that would also eat the dot of ".gitignore"
        path = path[2:]
    return path


def owned_violations(changed: list[str], owned: list[str], always_allowed: list[str] | None = None) -> list[str]:
    """Return the changed files that are neither inside an owned folder nor on the always-allowed list."""
    allowed_patterns = [re.compile(p) for p in (always_allowed or [])]
    owned_prefixes = [normalize(o) for o in owned]
    bad: list[str] = []
    for raw in changed:
        path = normalize(raw)
        if any(path.startswith(prefix) for prefix in owned_prefixes):
            continue
        if any(pattern.search(path) for pattern in allowed_patterns):
            continue
        bad.append(path)
    return sorted(set(bad))


def violations_for_label(changed: list[str], label: str, cfg: dict[str, Any]) -> list[str]:
    return owned_violations(changed, cfg["rules"][label]["owned"], cfg.get("always_allowed", []))
