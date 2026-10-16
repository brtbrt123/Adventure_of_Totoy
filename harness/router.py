"""Model router and task runner for Adventure of Totoy.

  python harness/router.py run "<task text>" [--label X] [--tier light|standard|heavy] [--dry-run]
  python harness/router.py run --task harness/tasks/<file>.md
  python harness/router.py list [-n 10]
  python harness/router.py cleanup [--yes]

`--dry-run` prints the label, builder, reviewer, tiers and models, owned paths, branch and checks without
running any agent or touching git. Nothing here ever merges, and branches are never deleted.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # so `python harness/router.py` can import harness.*

from harness.lib import checkrun, engine, gitutil, labels, logbook, tasks, tiers  # noqa: E402
from harness.lib.config import REPO_ROOT, load_config  # noqa: E402

EXIT_OK, EXIT_FAILED, EXIT_USAGE, EXIT_HUMAN = 0, 1, 2, 3


def log_path_for(repo_root: Path) -> Path:
    return repo_root / "harness" / "logs" / "runs.jsonl"


def describe_plan(task: tasks.Task, choice: labels.LabelChoice, tier: str, cfg: dict[str, Any], repo_root: Path) -> list[str]:
    rule = cfg["rules"][choice.label]
    lines = [
        f"task:      {task.title}",
        f"label:     {choice.label} ({choice.source})",
    ]
    if choice.scores:
        top = sorted(choice.scores.items(), key=lambda kv: -kv[1])[:4]
        lines.append("scores:    " + ", ".join(f"{k}={v:g}" for k, v in top))
    if rule["builder"] == "human":
        lines.append("builder:   the human decides this label (design docs and balance); no agent is run")
        return lines
    lines += [
        f"builder:   {rule['builder']}",
        f"reviewer:  {rule['reviewer']} (review tier {tiers.review_tier(choice.label, cfg)}, "
        f"{tiers.model_for(rule['reviewer'], tiers.review_tier(choice.label, cfg), cfg)})",
        f"owned:     {', '.join(rule['owned'])}",
        f"start tier {tier} (default {rule['tier']}), escalation ladder if every round fails:",
    ]
    for number, (t, model) in enumerate(tiers.ladder(rule["builder"], tier, int(cfg["max_rounds"]), cfg), start=1):
        lines.append(f"  round {number}: {t} -> {model}")
    lines.append("checks:    " + ", ".join(checkrun.check_names_for(choice.label, cfg)))
    slug = gitutil.slugify(task.title)
    lines.append(f"branch:    agent/{choice.label}/{slug}")
    return lines


def cmd_run(args: argparse.Namespace, cfg: dict[str, Any], repo_root: Path) -> int:
    if args.task:
        task = tasks.from_file(Path(args.task))
    elif args.text:
        task = tasks.from_text(" ".join(args.text))
    else:
        print("give the task text or --task FILE", file=sys.stderr)
        return EXIT_USAGE
    try:
        choice = labels.pick_label(task.text, args.label or task.label, cfg)
        tier = tiers.start_tier(choice.label, task.text, args.tier or task.tier, cfg)
    except (labels.LabelError, tiers.TierError) as exc:
        print(f"cannot decide: {exc}", file=sys.stderr)
        return EXIT_USAGE
    if args.max_rounds:
        cfg["max_rounds"] = args.max_rounds
    for line in describe_plan(task, choice, tier, cfg, repo_root):
        print(line)
    if cfg["rules"][choice.label]["builder"] == "human":
        return EXIT_HUMAN
    if args.dry_run:
        print("\n(dry run: no agent was run and nothing was changed)")
        return EXIT_OK
    outcome = engine.run_task(task, choice.label, tier, cfg, repo_root, log_path_for(repo_root), args.base)
    if outcome.result == "pass":
        art = [p for p in ("art/",) if p in cfg["rules"][choice.label]["owned"]]
        if art:
            print(f"human gate: look at the contact sheet: {Path(outcome.worktree) / 'art' / 'build' / 'contact_sheet.png'}")
        print(f"human gate: review branch {outcome.branch} and merge it yourself when you approve")
        return EXIT_OK
    return EXIT_FAILED


def cmd_list(args: argparse.Namespace, cfg: dict[str, Any], repo_root: Path) -> int:
    runs = logbook.read_runs(log_path_for(repo_root))
    if not runs:
        print("no runs logged yet")
        return EXIT_OK
    for run in runs[-args.n:]:
        tiers_used = "/".join(r.get("tier", "?") for r in run.get("rounds", []))
        print(f"{run.get('timestamp', '?')}  {run.get('run_id', '?')}  {run.get('result', '?'):9}  "
              f"{run.get('label', '?'):20} {run.get('builder', '?')}->{run.get('reviewer', '?')}  "
              f"rounds={run.get('rounds_used', '?')} tiers={tiers_used}  {run.get('task', '')[:50]}")
    return EXIT_OK


def cmd_cleanup(args: argparse.Namespace, cfg: dict[str, Any], repo_root: Path) -> int:
    worktrees_dir = (gitutil.main_repo_root(repo_root) / cfg["worktrees_dir"]).resolve()
    finished = {Path(r["worktree"]).resolve(): r for r in logbook.read_runs(log_path_for(repo_root)) if r.get("worktree")}
    candidates = []
    for item in gitutil.list_worktrees(repo_root):
        path = Path(item["worktree"]).resolve()
        if path in finished and worktrees_dir in path.parents:
            candidates.append((path, item.get("branch", "?"), finished[path]["result"]))
    if not candidates:
        print("no finished harness worktrees to clean up")
        return EXIT_OK
    for path, branch, result in candidates:
        if not gitutil.worktree_is_clean(path):
            print(f"skipping {path}: it has uncommitted changes ({branch}, {result})")
            continue
        answer = "y" if args.yes else input(f"remove worktree {path} ({branch}, {result})? The branch stays. [y/N] ").strip().lower()
        if answer == "y":
            gitutil.git(["worktree", "remove", str(path)], repo_root)
            print(f"removed {path} (branch {branch} kept)")
    return EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run", help="route and run one task")
    run.add_argument("text", nargs="*", help="the task text")
    run.add_argument("--task", help="path of a task file")
    run.add_argument("--label")
    run.add_argument("--tier", help="light, standard or heavy (overrides the default)")
    run.add_argument("--dry-run", action="store_true")
    run.add_argument("--base", help="git ref to branch from (default: HEAD)")
    run.add_argument("--max-rounds", type=int)
    lst = sub.add_parser("list", help="show recent runs")
    lst.add_argument("-n", type=int, default=10)
    clean = sub.add_parser("cleanup", help="remove finished worktrees (asks first)")
    clean.add_argument("--yes", action="store_true", help="do not ask")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    cfg = load_config()
    handlers = {"run": cmd_run, "list": cmd_list, "cleanup": cmd_cleanup}
    return handlers[args.command](args, cfg, REPO_ROOT)


if __name__ == "__main__":
    sys.exit(main())
