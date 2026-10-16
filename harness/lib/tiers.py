"""Model tiers: a task starts on the cheapest suitable tier and escalates one tier per failed round."""
from __future__ import annotations

from typing import Any


class TierError(Exception):
    pass


def start_tier(label: str, text: str, explicit: str | None, cfg: dict[str, Any]) -> str:
    tiers: list[str] = cfg["tiers"]
    if explicit:
        if explicit not in tiers:
            raise TierError(f"unknown tier {explicit!r}. Known tiers: {', '.join(tiers)}")
        return explicit
    index = tiers.index(cfg["rules"][label]["tier"])
    lowered = text.lower()
    if any(word in lowered for word in cfg.get("risky_keywords", [])):
        index = min(index + 1, len(tiers) - 1)  # risky wording bumps the starting tier by one
    return tiers[index]


def next_tier(tier: str, cfg: dict[str, Any]) -> str:
    tiers: list[str] = cfg["tiers"]
    return tiers[min(tiers.index(tier) + 1, len(tiers) - 1)]


def review_tier(label: str, cfg: dict[str, Any]) -> str:
    table = cfg["review_tier"]
    return table.get(label, table["default"])


def model_for(agent: str, tier: str, cfg: dict[str, Any]) -> str:
    return cfg["models"][agent][tier]


def ladder(agent: str, start: str, rounds: int, cfg: dict[str, Any]) -> list[tuple[str, str]]:
    """The (tier, model) a task would use in each round if every round failed."""
    result = []
    tier = start
    for _ in range(rounds):
        result.append((tier, model_for(agent, tier, cfg)))
        tier = next_tier(tier, cfg)
    return result
