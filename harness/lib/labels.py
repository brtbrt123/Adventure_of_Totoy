"""Pick a task label. An explicit label always wins; otherwise keywords and path hints score the labels.
Nothing matched or a tie between unrelated labels means "ask the human" (never guess)."""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

PATH_HINT_WEIGHT = 1.5
BUGFIX_CORE_HINTS = ("core/", "core\\", "tuning", "boss.gd", "player.gd", "game_core")
BUGFIX_PRESENTATION_HINTS = ("presentation/", "presentation\\", "art/", "art\\", "hud", "sprite", "animation", "arena.gd")


class LabelError(Exception):
    """The label could not be decided without the human."""


@dataclass
class LabelChoice:
    label: str
    source: str  # "explicit" or "inferred"
    scores: dict[str, float] = field(default_factory=dict)


def _keyword_hits(text: str, keyword: str) -> int:
    pattern = r"(?<![a-z0-9])" + re.escape(keyword.lower()) + r"(?![a-z0-9])"
    return len(re.findall(pattern, text))


def score_labels(text: str, cfg: dict[str, Any]) -> dict[str, float]:
    lowered = text.lower()
    scores: dict[str, float] = {}
    for label, words in cfg["keywords"].items():
        total = float(sum(_keyword_hits(lowered, word) for word in words))
        if total:
            scores[label] = total
    for label, rule in cfg["rules"].items():
        for folder in rule.get("owned", []):
            if folder.lower() in lowered:
                scores[label] = scores.get(label, 0.0) + PATH_HINT_WEIGHT
    return scores


def resolve_bugfix(text: str) -> str:
    lowered = text.lower()
    core = any(hint in lowered for hint in BUGFIX_CORE_HINTS)
    presentation = any(hint in lowered for hint in BUGFIX_PRESENTATION_HINTS)
    if core and not presentation:
        return "bugfix-core"
    if presentation and not core:
        return "bugfix-presentation"
    raise LabelError(
        "bugfix: cannot tell whether this is core/ or presentation/art. "
        "Pass --label bugfix-core or --label bugfix-presentation."
    )


def pick_label(text: str, explicit: str | None, cfg: dict[str, Any]) -> LabelChoice:
    valid = set(cfg["rules"]) | {"bugfix"}
    if explicit:
        if explicit not in valid:
            raise LabelError(f"unknown label {explicit!r}. Known labels: {', '.join(sorted(valid))}")
        label = resolve_bugfix(text) if explicit == "bugfix" else explicit
        return LabelChoice(label, "explicit")
    scores = score_labels(text, cfg)
    if not scores:
        raise LabelError("no label matched this task. Pass --label (known: " + ", ".join(sorted(valid)) + ").")
    best = max(scores.values())
    leaders = sorted(label for label, value in scores.items() if value == best)
    if len(leaders) > 1:
        raise LabelError("ambiguous task, these labels tie: " + ", ".join(leaders) + ". Pass --label.")
    label = leaders[0]
    if label == "bugfix":
        label = resolve_bugfix(text)
    return LabelChoice(label, "inferred", scores)
