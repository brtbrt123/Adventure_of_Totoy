# Harness plan (documentation only; implemented in Stages 2 and 3)

The harness is everything around the agents that makes their work safe, checkable and repeatable. Stage 1 only created the instruction files, layout, git, palette, art pipeline and validator, and an empty `harness/` skeleton.

## Components

1. **Instructions layer:** `AGENTS.md` (shared rules), `CLAUDE.md` (points to it), `docs/GAME_DESIGN.md` (intent and feel targets).
2. **Isolation:** one git worktree and branch per task, plus folder ownership rules.
3. **Router:** `harness/router.py`, using the algorithm in `ROUTING.md`.
4. **Runner:** headless calls to `claude -p` and `codex exec` inside the task worktree, with timeouts.
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
- **Stage 2:** `router.py`, worktrees, run loop, logging, cross-review.
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

`harness/logs/runs.jsonl`, one line per run: timestamp, task id, label, builder, reviewer, rounds used, result (`pass`, `fail`, `escalated`), duration, which checks failed, and notes. (Logs are gitignored; the folder is kept.)

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
