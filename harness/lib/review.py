"""Reviewer output: JSON the harness can parse. Invalid output is retried once, then counts as a fail."""
from __future__ import annotations

import json
from typing import Any


def extract_json(text: str) -> dict[str, Any] | None:
    """Return the last JSON object found in text (agents often wrap it in prose or code fences)."""
    decoder = json.JSONDecoder()
    found: dict[str, Any] | None = None
    index = text.find("{")
    while index != -1:
        try:
            value, end = decoder.raw_decode(text, index)
            if isinstance(value, dict):
                found = value
            index = text.find("{", end)
        except json.JSONDecodeError:
            index = text.find("{", index + 1)
    return found


def parse_review(text: str) -> dict[str, Any] | None:
    data = extract_json(text)
    if data is None or data.get("verdict") not in ("pass", "fail"):
        return None
    comments = data.get("comments", [])
    cannot = data.get("cannot_judge", [])
    if not isinstance(comments, list) or not isinstance(cannot, list):
        return None
    return {"verdict": data["verdict"], "comments": comments, "cannot_judge": cannot}


def format_comments(review: dict[str, Any]) -> str:
    lines = []
    for item in review.get("comments", []):
        if isinstance(item, dict):
            lines.append(f"- [{item.get('severity', '?')}] {item.get('file', '?')}:{item.get('line', '?')} {item.get('issue', '')}")
        else:
            lines.append(f"- {item}")
    return "\n".join(lines) or "(the reviewer gave no comments)"
