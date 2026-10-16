"""Task files: harness/tasks/<id>-<slug>.md

Format (all parts optional except the description):

    # Title of the task
    label: tile
    tier: light

    Free text description, as many lines as you like.

    ## Acceptance
    - [ ] a checklist item
    - [ ] another item

    ## Scope
    - art/src/grass_*.txt
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Task:
    title: str
    description: str
    label: str | None = None
    tier: str | None = None
    acceptance: list[str] = field(default_factory=list)
    scope: list[str] = field(default_factory=list)
    source: str = ""

    @property
    def text(self) -> str:
        return " ".join([self.title, self.description, " ".join(self.acceptance), " ".join(self.scope)])


def from_text(text: str) -> Task:
    first_line = text.strip().splitlines()[0] if text.strip() else "task"
    return Task(title=first_line[:80], description=text.strip())


def from_file(path: Path) -> Task:
    lines = path.read_text(encoding="utf-8").splitlines()
    title = path.stem
    label = tier = None
    description: list[str] = []
    acceptance: list[str] = []
    scope: list[str] = []
    section = "description"
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("# ") and title == path.stem:
            title = stripped[2:].strip()
            continue
        heading = re.match(r"^##\s+(.*)$", stripped)
        if heading:
            name = heading.group(1).strip().lower()
            section = name if name in ("acceptance", "scope") else "description"
            continue
        meta = re.match(r"^(label|tier):\s*(\S+)\s*$", stripped)
        if meta and section == "description":
            if meta.group(1) == "label":
                label = meta.group(2)
            else:
                tier = meta.group(2)
            continue
        if section == "acceptance" and stripped.startswith("-"):
            acceptance.append(re.sub(r"^-\s*(\[[ xX]\]\s*)?", "", stripped))
        elif section == "scope" and stripped.startswith("-"):
            scope.append(stripped[1:].strip())
        elif section == "description":
            description.append(line)
    return Task(title, "\n".join(description).strip(), label, tier, acceptance, scope, str(path))
