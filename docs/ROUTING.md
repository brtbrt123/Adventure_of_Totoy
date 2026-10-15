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

## Model tiers and escalation

Each agent has an ordered ladder of models, cheapest first. A task starts on the lowest tier that suits its difficulty. If that tier fails (checks fail or the reviewer says `fail`), the next attempt runs on the next tier up, with the failure feedback. The ladder is the same idea for both agents.

| Tier | Use for | Claude Code model | Codex model |
|---|---|---|---|
| `light` | small, well-defined work: rename, doc edit, one tile variant, simple UI label, small bugfix, adding a test for existing code | `claude-haiku-5-5` | **to be set in Stage 2**: cheapest suitable model listed by `codex --help` / its model list |
| `standard` | normal feature work: a new entity, a HUD screen, a sprite set, a typical bugfix | `claude-sonnet-5-5` | **to be set in Stage 2** |
| `heavy` | design-heavy or risky work: combat rules and timing, boss logic, the core/presentation interface, save system, hard bugs, multi-frame animation that keeps failing | `claude-opus-5-5` (top tier `claude-fable-5-1` if you want a fourth rung) | **to be set in Stage 2**: the most capable model |

Codex model names are deliberately not filled in: they change between versions and `codex` is not installed on this machine yet. Stage 2 must read the real list from the installed CLI and put the names in `harness/config.json`. Claude model IDs above come from the current model list; confirm them with `claude --help` / `/model` when implementing.

How a tier is chosen and escalated:

1. **Starting tier:** an explicit `--tier light|standard|heavy` from the human wins. Otherwise a default per label from `config.json` (see below), bumped up one tier if the task text mentions risky keywords (`combat`, `parry`, `boss`, `save`, `interface`, `refactor`) or touches many files.
2. **Escalation:** round 1 runs on the starting tier. On a failure (a failed check, a reviewer `fail`, or a timeout) round 2 runs on the next tier up, and round 3 on the next again, or the top tier if already there. An ownership violation only triggers a retry on the same tier, not an escalation. The 3-round cap and the human escalation after round 3 do not change.
3. **Same task, same agent:** escalation never switches agents (Claude Code stays Claude Code, Codex stays Codex). Ownership rules still apply on every tier.
4. **Timeouts:** a run that hits its timeout counts as a failure and escalates the same way.
5. **Reviewer tier:** reviewers start at `standard`, or `heavy` for `logic`/`arch`/`save` tasks. A reviewer's output that is not valid JSON is retried once on the next tier up.
6. **Logging:** each run records the tier used per round, so the logs show which labels really need `heavy` and the defaults can be tuned.
7. **Limits:** both tools have usage limits. `heavy` runs can be capped per day in `config.json`; when the cap is hit the harness stops and reports instead of silently downgrading.

Suggested default starting tiers (a starting point, tune from the logs):

| Label | Default tier |
|---|---|
| `design-doc`, `balance` (drafting) | `light` |
| `tile`, `sprite`, `palette`, `tests`, `ui`, `hud`, `menu` | `light` |
| `tileset`, `effects`, `shader`, `bugfix` | `standard` |
| `animation` | `standard` |
| `logic`, `state`, `save`, `refactor` | `standard` |
| `arch` | `heavy` |

Example `config.json` shape (Stage 2 builds it):

```json
{
  "tiers": ["light", "standard", "heavy"],
  "models": {
    "claude": {"light": "claude-haiku-5-5", "standard": "claude-sonnet-5-5", "heavy": "claude-opus-5-5"},
    "codex":  {"light": "<set from codex model list>", "standard": "<...>", "heavy": "<...>"}
  },
  "default_tier": {"tile": "light", "sprite": "light", "logic": "standard", "arch": "heavy"},
  "escalate_on": ["check_failed", "review_failed", "timeout"],
  "max_heavy_runs_per_day": null
}
```

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
    tier = start_tier(task, label)       # --tier wins, else default per label (+1 if risky)
    branch = create_worktree(task)       # isolated branch and folder per task
    feedback = None
    for attempt in range(1, MAX_ROUNDS + 1):      # MAX_ROUNDS = 3
        model = MODELS[builder][tier]
        run_agent(builder, task, feedback, cwd=branch, model=model)
        if touched_outside(branch, owned):        # ownership check: retry, no escalation
            feedback = "You edited files outside your area. Revert them."
            continue
        checks = run_checks(label, branch)        # validator, tests, lint
        if not checks.ok:
            feedback = checks.errors              # errors go back to the builder
            tier = next_tier(tier)                # escalate: lower model could not do it
            continue
        review = run_agent(reviewer, review_prompt(task), cwd=branch,
                           model=MODELS[reviewer][review_tier(label)])
        if review.verdict == "pass":
            log(task, label, builder, reviewer, attempt, tier, "pass")
            return open_pr(branch)                # the human merges
        feedback = review.comments
        tier = next_tier(tier)                    # escalate (stays on top tier if already there)
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
