"""The run loop: worktree, builder, ownership check, checks, reviewer, escalation, log. Never merges."""
from __future__ import annotations

import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

from . import checkrun, gitutil, logbook, ownership, review, tiers
from .runner import run_agent
from .tasks import Task

PROMPTS_DIR = Path(__file__).resolve().parents[1] / "prompts"

CHECKLISTS = {
    "core": "- Does it follow docs/architecture.md (snapshot, events, input intents)? Is there any rendering or UI code in core/?\n"
            "- Logic bugs and edge cases (collisions, timing, turn order, math). Missing or weak tests.\n"
            "- Are all balance numbers in core/tuning.gd? Are names and comments clear?",
    "art": "- Palette symbols only, sizes valid, no reserved gold/red on tiles, transparency rules, seams.\n"
           "- Do atlas, sprites.json (anchors) and tileset data match the sources? Can Godot load them?\n"
           "- You cannot judge whether the art looks good; say so.",
    "presentation": "- Presentation must hold NO game rules: it may only read snapshots and events.\n"
                    "- Does it use the interface in docs/architecture.md correctly? Missing-frame fallbacks, crashes, typed GDScript.\n"
                    "- You cannot judge feel or looks; say so.",
    "tests": "- Do the tests actually fail when the behaviour breaks? Are they deterministic and fast?",
}


def checklist_for(label: str) -> str:
    if label in ("logic", "arch", "refactor", "save", "state", "bugfix-core"):
        return CHECKLISTS["core"]
    if label in ("sprite", "tile", "tileset", "animation", "palette"):
        return CHECKLISTS["art"]
    if label == "tests":
        return CHECKLISTS["tests"]
    return CHECKLISTS["presentation"]


@dataclass
class RunOutcome:
    result: str  # pass, fail, escalated, error
    branch: str = ""
    worktree: str = ""
    rounds: list[dict[str, Any]] = field(default_factory=list)
    message: str = ""
    commit: str = ""


def render(template_name: str, **values: str) -> str:
    return (PROMPTS_DIR / template_name).read_text(encoding="utf-8").format(**values)


def builder_prompt(task: Task, label: str, owned: list[str], feedback: str | None) -> str:
    feedback_block = f"FEEDBACK FROM THE PREVIOUS ROUND (fix this first):\n{feedback}\n" if feedback else ""
    return render(
        "builder.md", label=label, title=task.title, description=task.description or "(see the title)",
        acceptance="\n".join(f"- {a}" for a in task.acceptance) or "- (none given: make the task work and keep all checks passing)",
        scope="\n".join(f"- {s}" for s in task.scope) or "- (not specified)", owned=", ".join(owned), feedback_block=feedback_block,
    )


def reviewer_prompt(task: Task, label: str, owned: list[str], diff: str) -> str:
    return render(
        "reviewer.md", label=label, title=task.title, description=task.description or "(see the title)",
        acceptance="\n".join(f"- {a}" for a in task.acceptance) or "- (none given)", owned=", ".join(owned),
        checklist=checklist_for(label), diff=diff or "(no changes)",
    )


def run_task(task: Task, label: str, tier: str, cfg: dict[str, Any], repo_root: Path, log_path: Path,
             base_ref: str | None = None, say: Callable[[str], None] = print) -> RunOutcome:
    rule = cfg["rules"][label]
    builder, reviewer, owned = rule["builder"], rule["reviewer"], rule["owned"]
    max_rounds = int(cfg.get("max_rounds", 3))
    timeout = int(cfg.get("agent_timeout_seconds", 900))
    run_id = uuid.uuid4().hex[:8]
    started = time.time()
    slug = gitutil.slugify(task.title)
    base_ref = base_ref or cfg.get("base_branch", "HEAD")
    base_sha = gitutil.resolve_sha(repo_root, base_ref)
    branch = gitutil.unique_branch(repo_root, label, slug)
    worktrees_dir = (repo_root / cfg["worktrees_dir"]).resolve()
    worktree = gitutil.create_worktree(repo_root, worktrees_dir, branch, base_sha)
    say(f"[{run_id}] branch {branch}, worktree {worktree}")

    outcome = RunOutcome("escalated", branch, str(worktree))
    feedback: str | None = None
    current_tier = tier
    failed_checks: list[str] = []

    for attempt in range(1, max_rounds + 1):
        cap = cfg.get("max_heavy_runs_per_day")
        if current_tier == "heavy" and cap is not None and logbook.heavy_rounds_today(log_path) >= int(cap):
            outcome.message = f"daily cap of {cap} heavy rounds reached, stopping instead of downgrading"
            say(outcome.message)
            break
        model = tiers.model_for(builder, current_tier, cfg)
        say(f"[{run_id}] round {attempt}/{max_rounds}: {builder} builds on {current_tier} ({model})")
        round_info: dict[str, Any] = {"round": attempt, "tier": current_tier, "model": model, "builder": builder}
        result = run_agent(cfg["agents"][builder], "builder", model, builder_prompt(task, label, owned, feedback), worktree, timeout)
        round_info.update({"agent_seconds": round(result.seconds, 1), "agent_attempts": result.attempts,
                           "timed_out": result.timed_out, "sandbox_failed": result.sandbox_failed})
        outcome.rounds.append(round_info)

        if result.timed_out:
            feedback = f"The previous attempt timed out after {timeout} seconds. Work in smaller steps."
            round_info["outcome"] = "timeout"
            current_tier = tiers.next_tier(current_tier, cfg)
            continue
        changed = gitutil.changed_files(worktree, base_sha)
        round_info["changed_files"] = len(changed)
        bad = ownership.violations_for_label(changed, label, cfg)
        if bad:
            feedback = "You edited files outside your area. Revert them and keep to " + ", ".join(owned) + ":\n" + "\n".join(f"- {b}" for b in bad)
            round_info["outcome"] = "ownership"
            say(f"[{run_id}]   ownership violation: {bad}")
            continue  # same tier: not a capability problem
        if not changed:
            feedback = "No files were changed. Make the change the task asks for."
            round_info["outcome"] = "no_changes"
            current_tier = tiers.next_tier(current_tier, cfg)
            continue

        results = checkrun.run_checks(label, worktree, base_sha, repo_root, cfg)
        failed = [r for r in results if not r.ok]
        round_info["checks"] = {r.name: r.ok for r in results}
        if failed:
            failed_checks = [r.name for r in failed]
            feedback = checkrun.failure_text(results)
            round_info["outcome"] = "checks_failed"
            say(f"[{run_id}]   checks failed: {failed_checks}")
            current_tier = tiers.next_tier(current_tier, cfg)
            continue

        if reviewer == "human":
            round_info["outcome"] = "needs_human_review"
            outcome.result = "pass"
            outcome.message = "checks passed; this label is reviewed by the human"
            break
        rev_tier = tiers.review_tier(label, cfg)
        diff = gitutil.diff_text(worktree, base_sha, int(cfg.get("max_diff_chars", 60000)))
        verdict = None
        for review_try in range(2):  # invalid JSON is retried once, on the next tier up
            rev_model = tiers.model_for(reviewer, rev_tier, cfg)
            say(f"[{run_id}]   {reviewer} reviews on {rev_tier} ({rev_model})")
            rev = run_agent(cfg["agents"][reviewer], "reviewer", rev_model, reviewer_prompt(task, label, owned, diff), worktree, timeout)
            verdict = review.parse_review(rev.output)
            if verdict is not None:
                break
            rev_tier = tiers.next_tier(rev_tier, cfg)
        round_info["review_tier"] = rev_tier
        if verdict is None:
            feedback = "The reviewer returned output that is not valid JSON twice, so this counts as a fail."
            round_info["outcome"] = "review_unparseable"
            current_tier = tiers.next_tier(current_tier, cfg)
            continue
        round_info["verdict"] = verdict["verdict"]
        round_info["cannot_judge"] = verdict["cannot_judge"]
        if verdict["verdict"] == "pass":
            round_info["outcome"] = "pass"
            outcome.result = "pass"
            outcome.message = "reviewer passed"
            outcome.rounds[-1]["review_comments"] = verdict["comments"]
            break
        feedback = "The reviewer failed this round:\n" + review.format_comments(verdict)
        round_info["outcome"] = "review_failed"
        current_tier = tiers.next_tier(current_tier, cfg)

    if outcome.result == "pass":
        trailer = f"Harness-Run: {run_id}\nBuilt-By: {builder} ({outcome.rounds[-1]['model']})\nReviewed-By: {reviewer}"
        outcome.commit = gitutil.commit_all(worktree, f"{task.title}\n\n{trailer}")
        say(f"[{run_id}] PASS on round {len(outcome.rounds)}. Branch {branch} (commit {outcome.commit[:8]}). Nothing is merged: the human merges.")
    else:
        outcome.result = "escalated"
        outcome.message = outcome.message or "no pass after the maximum number of rounds"
        say(f"[{run_id}] ESCALATED to the human: {outcome.message}")
        say(f"  branch: {branch}\n  worktree: {worktree}\n  last feedback: {(feedback or '')[:500]}\n  failed checks: {failed_checks}\n  log: {log_path}")

    logbook.append_run(log_path, {
        "run_id": run_id, "task": task.title, "label": label, "builder": builder, "reviewer": reviewer,
        "branch": branch, "worktree": str(worktree), "result": outcome.result, "rounds": outcome.rounds,
        "rounds_used": len(outcome.rounds), "seconds": round(time.time() - started, 1), "failed_checks": failed_checks,
        "notes": outcome.message,
    })
    return outcome
