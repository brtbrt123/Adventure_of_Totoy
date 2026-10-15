# Routing plan (documentation only; implemented in Stage 2)

Tasks get a label. An explicit label from the human always wins. Otherwise infer it from keywords.

| Label | Builder | Reviewer | Owned paths |
|---|---|---|---|
| `logic`, `arch`, `refactor`, `save`, `state` | Claude Code | Codex | `core/`, `docs/` |
| `sprite`, `tile`, `tileset`, `animation`, `palette` | Codex | Claude Code | `art/`, `presentation/` |
| `ui`, `hud`, `menu`, `effects`, `shader` | Codex | Claude Code | `presentation/` |
| `bugfix` in `core/` | Claude Code | Codex | `core/` |
| `bugfix` in `presentation/` or `art/` | Codex | Claude Code | `presentation/`, `art/` |
| `tests` | Codex | Claude Code | `tests/` |
| `design-doc`, `balance` | the human decides (Claude Code may draft) | the human | `docs/` |

Note (added in Stage 1): `tools/` (art pipeline code) and `harness/` are infrastructure owned by Claude Code. They are not in the brief's table; the human should confirm or change this.

## Algorithm (pseudocode)

```python
def pick_label(task):
    if task.label:                       # 1. explicit label always wins
        return task.label
    scores = keyword_scores(task.text)   # 2. keyword match per label
    add_path_hints(scores, task.text)    # 3. mentions of core/, art/, etc. add weight
    best = max(scores, key=scores.get)
    if scores[best] == 0:                # 4. nothing matched: ask the human, never guess
        return ask_human(task)
    return best

def run(task):
    label = pick_label(task)
    builder, reviewer, owned = RULES[label]
    branch = create_worktree(task)       # isolated branch and folder per task
    feedback = None
    for attempt in range(1, MAX_ROUNDS + 1):      # MAX_ROUNDS = 3
        run_agent(builder, task, feedback, cwd=branch)
        if touched_outside(branch, owned):        # ownership check
            feedback = "You edited files outside your area. Revert them."
            continue
        checks = run_checks(label, branch)        # validator, tests, lint
        if not checks.ok:
            feedback = checks.errors              # errors go back to the builder
            continue
        review = run_agent(reviewer, review_prompt(task), cwd=branch)
        if review.verdict == "pass":
            log(task, label, builder, reviewer, attempt, "pass")
            return open_pr(branch)                # the human merges
        feedback = review.comments
    log(task, label, builder, reviewer, MAX_ROUNDS, "fail")
    escalate_to_human(task, branch, feedback)     # stop, never loop forever
```

## Checks by label

- `sprite` / `tile`: build script, validator (size, palette, transparency, seams), contact sheet render.
- `logic` / `arch`: Godot headless tests (console build) and syntax check.
- `ui`: project loads without errors, plus a screenshot if available.

## Guardrails

Retry cap of 3, task timeout, folder ownership enforced by a check (not by trusting prompts), palette enforced by the validator, no automatic merging, every run logged.

## Later upgrade

Replace keyword matching with a cheap classifier call, keeping keyword scoring as a fallback. Only do this if the logs show the keywords misroute.

## Verify before implementing

The headless flags for `claude -p` and `codex exec` (output format, permissions, working directory) change between versions. Check each CLI's `--help` on this machine. Do not rely on memory. (On this machine `claude` 2.1.296 is installed; `codex` was **not found** during the Stage 1 pre-flight.)
