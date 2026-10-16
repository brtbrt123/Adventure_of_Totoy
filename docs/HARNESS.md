# Harness (Stage 2 implemented; Stage 3 is still a plan)

The harness is everything around the agents that makes their work safe, checkable and repeatable. **Stage 2 is implemented** in `harness/` (router, runner, checks, review loop, worktrees, logs) and tested with stub agents. CI and Graphify (Stage 3) are not built.

## How to use it (Stage 2)

```powershell
python harness/router.py run "make three grass tile variants" --dry-run   # plan only: label, models, ladder, branch. Changes nothing.
python harness/router.py run "make three grass tile variants"              # really run it (spends agent tokens)
python harness/router.py run --label tile --tier light "..."               # force the label and/or the starting tier
python harness/router.py run --task harness/tasks/001-example.md           # task file: title, label, acceptance checklist, scope
python harness/router.py list                                              # recent runs from harness/logs/runs.jsonl
python harness/router.py cleanup                                           # remove finished worktrees (asks first; branches are kept)
python -m unittest discover -s tests                                       # includes the harness tests (stub agents, no tokens)
```

What a run does: picks the label (explicit wins; else keywords and path hints; a tie or no match stops and asks you), picks the builder, reviewer and starting tier from `harness/config.json`, creates a worktree and branch `agent/<label>/<slug>` outside the repo, runs the builder headless with a prompt built from `harness/prompts/builder.md`, then (in order) checks folder ownership, runs the label's checks, runs the reviewer (read-only, must answer JSON), and loops up to 3 rounds. A failed check, a reviewer `fail` or a timeout escalates to the next model tier; an ownership violation is retried on the same tier. On a pass it commits on the branch (trailers say who built and reviewed) and prints the human gates; it never merges and never deletes a branch. After 3 failed rounds it stops and prints the branch, worktree, last feedback and failed checks.

Facts learned while building it (verified on this machine, 2026-10-16):
- `claude -p` is called with `--model`, `--permission-mode acceptEdits` for builders and `plan` (read-only) for reviewers, an explicit `--allowedTools` list, and the prompt on stdin. `codex exec` is called with `-m`, `-s workspace-write` (builders) or `-s read-only` (reviewers), `-C <worktree>`, `-o <file>`, prompt on stdin. The runner refuses to run if any forbidden flag (`--dangerously-*`, `danger-full-access`, `bypassPermissions`) is in the command. Both real command lines were smoke-tested with a trivial prompt (a haiku and a gpt-6-luna reviewer both answered correctly).
- Codex's Windows sandbox sometimes fails to start its shell (`helper_unknown_error`), especially while the Codex desktop app is running. The runner retries that exact failure up to 4 times. Closing the desktop app helps. If a round changes nothing and the sandbox failed, the round is logged as `sandbox_failed` and does NOT escalate to a bigger model (it is an environment problem). In a real run Codex still wrote files in that state (through its file tool), and the harness checks then ran the work, which is why checks and reviews matter more than the builder's own report.
- The repository has no git remote, so the harness does not open pull requests; it leaves the branch. (If a remote and `gh` are set up later, opening a PR is a small addition.)
- Reviewers are told what they cannot judge (looks, feel); those notes are logged per round (`cannot_judge`).
- The checks run from this repo against the task worktree: `check_ownership.py`, `validate_art.py`, `build_art.py` (build + validate + contact sheet), `run_tests.py` (Python tests, Godot import, `run_tests.gd`, every `smoke_*.gd` except windowed capture scripts, each with a hard time limit that kills the process tree).

Limits: per-run timeout 15 min (`agent_timeout_seconds`), 3 rounds, optional `max_heavy_runs_per_day` (null = unlimited; when hit the harness stops instead of silently downgrading).

Not built (Stage 3 or later): GitHub CI, Graphify, opening PRs, a classifier replacing keyword routing, screenshots as a check, running several tasks in parallel.

## Original plan notes (kept for reference)

The sections below are the original Stage 1 plan and specification the implementation followed.

## Components

1. **Instructions layer:** `AGENTS.md` (shared rules), `CLAUDE.md` (points to it), `docs/GAME_DESIGN.md` (intent and feel targets).
2. **Isolation:** one git worktree and branch per task, plus folder ownership rules.
3. **Router:** `harness/router.py`, using the algorithm in `ROUTING.md`.
4. **Runner:** headless calls to `claude -p` and `codex exec` inside the task worktree, with timeouts. It picks the model from the task's tier and escalates to a higher model after a failed round (see `ROUTING.md`, "Model tiers and escalation"). Model names live in `harness/config.json`.
5. **Checks:** sprite validator, sprite build and atlas, Godot headless tests, lint, contact-sheet render.
6. **Review loop:** the other agent reviews the diff, max 3 rounds.
7. **Memory and context:** the Obsidian vault in `docs/`, and Graphify later.
8. **Logs:** one record per task (label, agents, rounds, result) in `harness/logs/`, used to tune routing.
9. **Human gates:** art approval on the contact sheet, playtesting, and merges.

## Flow for one task

```
human: route "3 grass tile variants" --label tile
  -> router picks Codex (build) and Claude Code (review)
  -> worktree + branch created
  -> Codex builds sprite sources
  -> build + validator run (failure -> errors back to Codex, max 3 rounds)
  -> contact sheet rendered
  -> Claude Code reviews the diff
  -> PR opened + log written
  -> human looks at the contact sheet, approves, merges
```

## Stages

- **Stage 1 (done):** instruction files, layout, git, palette, art pipeline and validator, docs.
- **Stage 2 (done):** `router.py`, worktrees, run loop, logging, cross-review.
- **Stage 3:** GitHub CI for PR checks, then Graphify (optional).

## Knowledge tools

- **Obsidian:** `docs/` is the vault. Keep it plain markdown so both agents can read it. Do not commit machine-specific Obsidian settings.
- **Graphify** (Stage 3, optional): third-party tool that indexes a folder into a knowledge graph and can install hooks and instructions for Claude Code and Codex. Before adopting: confirm it supports GDScript, verify the exact repository and package, review what it writes to `CLAUDE.md`, `AGENTS.md` and settings files, and exclude generated art and build output. Only add it once the codebase is large enough that agents get lost in it.

## Specification (for Stage 2)

### Folder layout inside `harness/`

```
harness/
├── router.py            # entry point
├── config.json          # RULES, KEYWORDS, MAX_ROUNDS, timeouts, agent commands
├── checks/
│   ├── build_art.py     # builds sprites and atlas (wraps tools/art/build_art.py)
│   ├── validate_art.py  # size, palette, transparency, seams (wraps tools/art/validate_art.py)
│   ├── run_tests.py     # Godot headless tests (console build)
│   └── check_ownership.py   # fails if files outside the owned paths changed
├── prompts/
│   ├── builder.md       # template for the builder agent
│   └── reviewer.md      # template for the reviewer agent
├── tasks/               # one file per task
└── logs/
    └── runs.jsonl       # one JSON line per run
```

### Task file

`harness/tasks/<id>-<slug>.md`: title, label (optional), description, acceptance criteria (a checklist), and files or folders in scope.

### Router commands

- `python harness/router.py run "<task text>" [--label X]`
- `python harness/router.py run --task harness/tasks/<file>.md`
- `--dry-run`: print the chosen label, builder, reviewer and owned paths without running any agent. Build this first, since it tests the routing for free.
- `list` shows recent runs from the log. `cleanup` removes finished worktrees, and asks before deleting anything.

### Prompt templates

- `builder.md` includes the task, a pointer to `AGENTS.md`, the owned paths, the acceptance criteria, and feedback from the previous round if any.
- `reviewer.md` includes the task, the diff, a review checklist for the label, and the required output format below. It must tell the reviewer to say what it cannot judge (for example whether art looks good).

### Review output format

The reviewer must return JSON the harness can parse:

```json
{
  "verdict": "pass",
  "comments": [{"file": "core/x.gd", "line": 12, "issue": "...", "severity": "high"}],
  "cannot_judge": ["visual quality of the tiles"]
}
```

If the output is not valid JSON, retry the review once, then treat it as a fail and escalate to the human.

### Check interface

Each check is a script that exits 0 on success and non-zero on failure, and prints plain-text errors that are fed back to the builder as-is.

### Run log

`harness/logs/runs.jsonl`, one line per run: timestamp, task id, label, builder, reviewer, model and tier per round, rounds used, result (`pass`, `fail`, `escalated`), duration, which checks failed, and notes. (Logs are gitignored; the folder is kept.)

### Git conventions

Branch name `agent/<label>/<slug>`. Put worktrees outside the repo (for example a sibling folder like `../Adventure_of_Totoy_worktrees/`) so they do not nest inside it. After a pass, open a PR with the `gh` CLI if it is installed. Otherwise leave the branch and print a summary. Never merge, and never delete branches or worktrees without asking.

### Limits

A per-agent-run timeout (configurable, start around 15 minutes), the 3-round cap, and an optional maximum number of runs per day, since both tools have usage limits. When a limit is hit, stop and report.

### Escalation output

When the harness stops without a pass, print the branch name, the last feedback, the failed checks, and the path of the log entry.

### Testing the harness itself

Use stub agents (small scripts that mimic `claude -p` and `codex exec` output) so the routing, retry, ownership and logging logic can be tested without spending tokens or needing real agent runs.

### Safety

Keep secrets (`.env`, keys) in `.gitignore` and out of prompts. Agents run only inside their task worktree. Do not enable any permission-skipping flags without the human's explicit approval. Headless permission setup is a decision to make with the human before Stage 2: review what each CLI's current permission and sandbox options actually do.

### Human gates printed by the harness

After an art task, the path to the contact sheet. After any task, the branch or PR link.
