# Routing (implemented in Stage 2: `harness/router.py` and `harness/config.json`)

The rules, keywords, models, tiers and checks below live in `harness/config.json`; `docs/HARNESS.md` explains how to run it. Implementation notes: the labels `bugfix-core` and `bugfix-presentation` are the two halves of `bugfix` (the bare label is resolved from the file paths in the task text, or refused); two labels tying on score, or no match, stops and asks for `--label` instead of guessing; `design-doc` and `balance` run no agent (the human decides); the starting tier is bumped one step when the task text has risky words (`combat`, `parry`, `boss`, `save`, `interface`, `refactor`, `snapshot`).

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
| `light` | small, well-defined work: rename, doc edit, one tile variant, simple UI label, small bugfix, adding a test for existing code | `claude-haiku-5-5` | `gpt-6-luna` ("fast and affordable model for easier tasks") |
| `standard` | normal feature work: a new entity, a HUD screen, a sprite set, a typical bugfix | `claude-sonnet-5-5` | `gpt-6.1-sol` ("latest workhorse model for coding and everyday work") |
| `heavy` | design-heavy or risky work: combat rules and timing, boss logic, the core/presentation interface, save system, hard bugs, multi-frame animation that keeps failing | `claude-opus-5-5` (top tier `claude-fable-5-1` if you want a fourth rung) | `gpt-6-astra` ("frontier intelligence for the most demanding work") |

Where the names come from: the Codex names were read on 2026-10-15 from this machine's Codex model cache (`~/.codex/models_cache.json`, visible entries, installed `codex-cli 0.162.1`) and matched by their own descriptions. Older visible models exist (`gpt-6-sol`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`) but are unused. **No Codex run with a specific model has been tested yet**, so confirm the names work with `codex exec -m <model>` before relying on them; the cache can change when Codex updates. Claude model IDs come from the current model list; confirm them with `claude --help` when implementing. Codex also has per-model reasoning effort levels (each model has a default); Stage 2 may use effort as an extra escalation step.

### Verified headless flags (`codex exec --help`, codex-cli 0.162.1)

- `codex exec [OPTIONS] [PROMPT]`: non-interactive; prompt from argument or stdin (`-`).
- `-m, --model <MODEL>`, `-C, --cd <DIR>` (working root, use the task worktree), `-s, --sandbox read-only | workspace-write | danger-full-access`, `--json` (JSONL events), `-o, --output-last-message <FILE>` (final answer to a file, good for the review JSON), `--output-schema <FILE>` (JSON Schema for the final response, usable to force the reviewer format), `--ephemeral`, `--skip-git-repo-check`, `--add-dir`.
- `codex exec review` and `codex review` exist (built-in non-interactive review).
- Do **not** use `--dangerously-bypass-approvals-and-sandbox` (skips all checks) or `--approve-for-me` without the human's explicit approval. Planned: `--sandbox workspace-write --cd <worktree>`.
- Auth: `codex login status` reports "Logged in using ChatGPT" on this machine.

### Claude Code headless (`claude -p`)

Not re-checked in this pass; run `claude -p --help` before Stage 2 (see "Verify before implementing" below).

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
    "codex":  {"light": "gpt-6-luna", "standard": "gpt-6.1-sol", "heavy": "gpt-6-astra"}
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

The headless flags for `claude -p` and `codex exec` (output format, permissions, working directory) change between versions. Check each CLI's `--help` on this machine. Do not rely on memory. (On this machine `claude` 2.1.296 and `codex-cli` 0.162.1 are installed. `codex exec --help` was read; `claude -p --help` was not.)
