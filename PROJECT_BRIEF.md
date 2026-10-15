# Project Brief: 16x16 Pixel Game (Claude Code + Codex)

Read this whole file before doing anything. It is the kickoff brief for this project.
Your job in this session is **Stage 1 only** (see "Your task now"). Do not build the router, CI, or Graphify yet.
Start with the environment pre-flight check in Appendix E, then follow Section 6 in order. The human is working with you in this session, so ask your questions in chat.

---

## 1. Goal

Build a 2D pixel-art game with 16x16 tiles, developed by two AI coding agents working under human supervision:

- **Claude Code (you):** game logic and architecture.
- **Codex:** visual presentation (UI, effects), sprites, tiles, and code review of your work.
- **The human (project owner):** game design decisions, playtesting, art approval, and every merge.

Neither agent can judge whether the game is fun or whether the art looks good. The human does that. Produce things the human can look at and react to.

## 2. Fixed decisions (do not change without asking)

| Topic | Decision |
|---|---|
| Engine | Godot 4.x. The human downloaded v4.7.2 stable (Windows). Verify against the installed version before relying on syntax or APIs. |
| Language | Typed GDScript. Always use static typing. Be careful not to mix Godot 3 and Godot 4 syntax. |
| OS | Windows. Prefer scripts that run on Windows (Python or PowerShell). Avoid bash-only commands. |
| Tile size | 16x16 |
| Rendering | Low base resolution (for example 320x180), nearest-neighbor filtering, integer scaling only. No smoothing, no fractional scaling. |
| Transparency | Fully transparent or fully opaque pixels only. No semi-transparent edges. |
| Palette | One fixed palette stored in `art/palette.json`. Every sprite and tile may only use these colors. Default proposal: DB16 (DawnBringer 16). Confirm the exact hex values with the human or a reliable source before writing them. Do not guess them from memory. |
| Version control | Git. One branch (and later one worktree) per task. Nothing merges automatically. |

Godot executables: the human has `Godot_v4.7.2-stable_win64.exe` (editor) and `..._console.exe` (prints logs to a terminal). Use the **console** build for any headless or scripted run, because the regular build does not reliably print output to a terminal on Windows. The human may rename them to `godot.exe` and `godot_console.exe` and add them to PATH. Check with `godot_console --version` before assuming.

## 3. Architecture rules

Split the code into two layers with a hard boundary:

- `core/` is **Claude Code's area**: game loop, state, rules, entities, save system. It must contain **no rendering and no UI code**.
- `presentation/` is **Codex's area**: rendering, UI, animations, effects. It reads game state and sends events. It does not hold game rules.

The two layers talk through a small, explicit interface (for example signals/events plus a read-only state snapshot). **Defining and documenting this interface is your first architecture task**, because Codex will build against it. Write it down in `docs/architecture.md` before any large implementation.

Ownership: each agent edits only its own folders. If a task needs a change in the other agent's area, say so in the task notes instead of editing it.

## 4. Planned project layout

```
pixel-game/
├── AGENTS.md              # shared rules for BOTH agents (source of truth)
├── CLAUDE.md              # points to AGENTS.md (see below)
├── PROJECT_BRIEF.md       # this file
├── docs/                  # also an Obsidian vault
│   ├── GAME_DESIGN.md     # rules, core loop, feel targets (human-owned)
│   ├── architecture.md    # core/presentation interface
│   ├── ROUTING.md         # routing plan (from Appendix B)
│   ├── HARNESS.md         # harness plan (from Appendix C)
│   ├── STATUS.md          # handoff note: what is done, what is next
│   └── decisions/         # short decision records
├── core/
├── presentation/
├── art/
│   ├── palette.json
│   ├── src/               # sprite sources as text grids
│   └── build/             # generated PNGs + atlas
├── tests/
├── harness/               # later: router, checks, prompts, logs
├── project.godot
├── .gitattributes
└── .gitignore
```

## 5. Art pipeline (Codex will use this)

Sprites are authored as **text grids**: each character maps to a palette entry, with `.` meaning transparent. This keeps art readable, diffable, and easy for an agent to edit.

Build these tools (Python, with Pillow):

1. **Build script:** converts grids in `art/src/` to PNGs, packs a spritesheet/atlas with a JSON of frame names and positions, and emits tileset data usable from Godot.
2. **Atlas padding:** extrude a 1px border around each tile in the atlas to prevent seams and bleeding when the camera moves.
3. **Validator:** exits non-zero with a clear message if any sprite has the wrong size, an off-palette color, partial transparency, or tile edges that do not match when repeated (for tiles meant to tile).
4. **Preview script:** renders all sprites and tiles onto one contact sheet, scaled up 8x with nearest-neighbor, so the human and agents can look at the result.

Start with a few placeholder tiles (grass, dirt, stone, water) and one very simple character (few colors, clear silhouette) to prove the pipeline works.

## 6. Your task now: Stage 1

Do these in order. Stop and report at the end.

0. **Pre-flight, then ask.** First run the environment check from Appendix E and report anything missing. Then **ask the human what kind of game this is** (top-down adventure, platformer, roguelike, other) if `docs/GAME_DESIGN.md` does not say. If they want to decide later, leave it as a clearly marked template.
1. Check the working directory is the project folder. If it is not a git repo, run `git init`.
2. Create the folder layout from section 4.
3. Write `AGENTS.md` with the shared rules from sections 2, 3 and 5, the ownership rules, how to run the project and tests, and the typed-GDScript requirement. It must be self-contained for Codex (see Appendix E) and include the roles of both agents from Appendix A. Make `CLAUDE.md` point to it (a one-line `@AGENTS.md` import, or a symlink if the platform allows, otherwise a short file that says to read `AGENTS.md`).
4. Create `docs/GAME_DESIGN.md` (template if the game type is unknown) and `docs/architecture.md` with the first draft of the core/presentation interface.
5. Create the Godot project settings (`project.godot`) for pixel art: base resolution, nearest-neighbor texture filter, integer scaling, a stretch mode that keeps pixels crisp.
6. Create `art/palette.json` and the build script, validator, and preview script from section 5, plus a few placeholder tiles and one simple character.
7. Add a `.gitignore` suitable for Godot and Python (`.godot/`, `__pycache__/`, build output if not committed, and so on).
8. Write `docs/ROUTING.md` from Appendix B and `docs/HARNESS.md` from Appendices C and F (documentation only, no code), create an empty `harness/` skeleton, and add a `.gitattributes` (see Appendix E).
9. Run the validator and preview script, and confirm they work. Make the first commit.
10. Write `docs/STATUS.md`, a short handoff note listing what is done, what you could not verify, open questions for the human, and the recommended next step. Future sessions (yours or Codex's) start with no memory, so this file is how they catch up. Commit it.

**Done when:**
- the validator passes on the placeholder art and fails on a deliberately bad test sprite
- the contact sheet renders
- `godot_console --headless --quit` (or the equivalent for the installed version) opens the project without errors
- `AGENTS.md`, `CLAUDE.md`, and the docs exist and agree with each other
- `docs/ROUTING.md`, `docs/HARNESS.md`, `docs/STATUS.md`, the empty `harness/` skeleton, and `.gitattributes` exist
- everything is committed on a branch, nothing merged to main by you

## 7. Not in scope yet

Do **not** build these now. They come in later stages:

- the model router and the worktree/review loop (Stage 2)
- GitHub CI and Graphify (Stage 3)
- real game features beyond what is needed to prove the setup

The full design for these is in Appendices A to F at the end of this file. Read them so your Stage 1 structure supports them. In Stage 1, the only thing to do with them is the documentation and empty skeleton in step 8.

## 8. Working rules

- Verify tool and CLI behavior on this machine before relying on memory (for example `--help` output, Godot version differences).
- Do not guess facts you can check. If something is ambiguous, ask the human.
- Keep changes small and committed in logical steps.
- Never merge to the main branch yourself.
- Report honestly: say what you ran, what passed, what you could not verify.
- At the end, give a short summary of what was created and any decisions the human still needs to make.

---

# Appendices (full plan, mostly for later stages)

## Appendix A: Agent roles and tasking

**Claude Code (builder for logic, reviewer for art/UI)**
- Builds: game loop, state, rules, entities, AI, save/load, the core/presentation interface, `docs/architecture.md`, refactors.
- Reviews Codex's diffs for: correct use of the core/presentation interface, naming, atlas and tileset data correctness, whether the Godot code can actually load and use the assets, and bugs in any scripts.
- Does not edit `presentation/` or `art/` unless the human overrides.
- Cannot judge: whether art looks good or the game feels good. Say so in reviews instead of pretending.

**Codex (builder for visuals, reviewer for logic)**
- Builds: sprite and tile sources (text grids), the sprite build pipeline outputs, animations, tilesets, UI (HUD, menus), visual effects, shaders, extra tests.
- Reviews Claude Code's diffs for: logic bugs, edge cases (collisions, turn order, economy math), missing tests, unclear code.
- Does not edit `core/` unless the human overrides.
- Known weak spots to plan for: consistent multi-frame characters and animation, seamless tiles on the first attempt. Expect several rounds and some hand fixing by the human.

**The human**
- Decides game design, approves art on the contact sheet, playtests, and merges.

**Cross-review:** whoever builds, the other agent reviews. A reviewer returns a clear `pass` or `fail` plus concrete comments.

## Appendix B: Model routing plan

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

**Algorithm (pseudocode, to be implemented in Stage 2):**

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

**Checks by label:**
- `sprite` / `tile`: build script, validator (size, palette, transparency, seams), contact sheet render.
- `logic` / `arch`: Godot headless tests (console build) and syntax check.
- `ui`: project loads without errors, plus a screenshot if available.

**Guardrails:** retry cap of 3, task timeout, folder ownership enforced by a check (not by trusting prompts), palette enforced by the validator, no automatic merging, every run logged.

**Later upgrade:** replace keyword matching with a cheap classifier call, keeping keyword scoring as a fallback. Only do this if the logs show the keywords misroute.

**Verify before implementing:** the headless flags for `claude -p` and `codex exec` (output format, permissions, working directory) change between versions. Check each CLI's `--help` on this machine. Do not rely on memory.

## Appendix C: Harness

The harness is everything around the agents that makes their work safe, checkable, and repeatable:

1. **Instructions layer:** `AGENTS.md` (shared rules), `CLAUDE.md` (points to it), `docs/GAME_DESIGN.md` (intent and feel targets).
2. **Isolation:** one git worktree and branch per task, plus folder ownership rules.
3. **Router:** `harness/router.py`, using the algorithm in Appendix B.
4. **Runner:** headless calls to `claude -p` and `codex exec` inside the task worktree, with timeouts.
5. **Checks:** sprite validator, sprite build and atlas, Godot headless tests, lint, contact-sheet render.
6. **Review loop:** the other agent reviews the diff, max 3 rounds.
7. **Memory and context:** the Obsidian vault in `docs/`, and Graphify later (Appendix D).
8. **Logs:** one record per task (label, agents, rounds, result) in `harness/logs/`, used to tune routing.
9. **Human gates:** art approval on the contact sheet, playtesting, and merges.

**Flow for one task:**

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

**Stages:**
- **Stage 1 (now):** instruction files, layout, git, palette, art pipeline and validator, docs. Useful on its own.
- **Stage 2:** `router.py`, worktrees, run loop, logging, cross-review.
- **Stage 3:** GitHub CI for PR checks, then Graphify.

## Appendix D: Knowledge tools (later)

- **Obsidian:** `docs/` is the vault. Keep it plain markdown (design notes, decisions, architecture) so both agents can read it directly. Do not commit personal Obsidian settings if they are machine-specific.
- **Graphify** (Stage 3, optional): a third-party tool that indexes a folder into a knowledge graph and can install hooks and instructions for Claude Code and Codex. Before adopting it: confirm it supports GDScript (its documented language list may not), verify the exact repository and package you install, review what it writes to `CLAUDE.md`, `AGENTS.md` and settings files, and exclude generated art and build output. Only add it once the codebase is large enough that agents get lost in it.

## Appendix E: Assumptions, gaps, and things to check first

**Pre-flight (step 0 of Stage 1): check the environment** and report what you find: `git --version`, `python --version`, `pip show pillow`, `node --version`, `claude --version`, `codex --version`, `godot_console --version`. If something is missing, tell the human what and why. Do not install global tools without asking.

**Codex cannot see this file.** Codex reads `AGENTS.md`, not `CLAUDE.md` or `PROJECT_BRIEF.md`. So the `AGENTS.md` you write must be self-contained for Codex: the fixed decisions, folder ownership, art rules, how to run the build, validator and preview scripts, and what Codex is expected to do and not do. Do not leave anything Codex needs only in this brief.

**No test framework is chosen yet.** Appendix B mentions Godot headless tests, but nothing is picked. Evaluate options (for example GUT, GdUnit4, or plain headless scripts), check compatibility with the installed Godot version, and ask the human before adding any addon.

**Windows details.**
- Add a `.gitattributes` to keep line endings consistent (LF for `.gd`, `.tscn`, `.tres`, `.json`, `.md`, `.py`).
- Prefer Python or PowerShell for scripts. Avoid bash-only syntax and hard-coded forward-slash assumptions.
- Keep the project path free of spaces.

**Headless agent permissions (matters in Stage 2, decide with the human).** Non-interactive runs need some permission setup. Do not use flags that skip all permission checks without the human's explicit approval. Scope runs to the task's worktree and review what each CLI's current permission and sandbox options actually do before using them.

**Unknowns only the human can answer:**
- game type and genre
- art mood and style (cheerful, dark, minimalist, and so on) and confirmation of the palette
- target platform (Windows only, or also web or mobile)
- whether they are working solo

**Knowledge caveat.** Godot 4.7.2 and the current Claude Code and Codex CLIs may be newer than what you remember. Check the official docs and `--help` output instead of relying on memory.

## Appendix F: Harness specification details (for Stage 2)

This is the concrete spec behind Appendix C. Do not implement it in Stage 1. Copy it into `docs/HARNESS.md` so Stage 2 starts from a written spec.

**Folder layout inside `harness/`:**

```
harness/
├── router.py            # entry point
├── config.json          # RULES, KEYWORDS, MAX_ROUNDS, timeouts, agent commands
├── checks/
│   ├── build_art.py     # builds sprites and atlas
│   ├── validate_art.py  # size, palette, transparency, seams
│   ├── run_tests.py     # Godot headless tests (console build)
│   └── check_ownership.py   # fails if files outside the owned paths changed
├── prompts/
│   ├── builder.md       # template for the builder agent
│   └── reviewer.md      # template for the reviewer agent
├── tasks/               # one file per task
└── logs/
    └── runs.jsonl       # one JSON line per run
```

**Task file** (`harness/tasks/<id>-<slug>.md`): title, label (optional), description, acceptance criteria (a checklist), and files or folders in scope.

**Router commands:**
- `python harness/router.py run "<task text>" [--label X]`
- `python harness/router.py run --task harness/tasks/<file>.md`
- `--dry-run`: print the chosen label, builder, reviewer and owned paths without running any agent. Build this first, since it tests the routing for free.
- `list` shows recent runs from the log. `cleanup` removes finished worktrees, and asks before deleting anything.

**Prompt templates:**
- `builder.md` includes the task, a pointer to `AGENTS.md`, the owned paths, the acceptance criteria, and feedback from the previous round if any.
- `reviewer.md` includes the task, the diff, a review checklist for the label, and the required output format below. It must tell the reviewer to say what it cannot judge (for example whether art looks good).

**Review output format** (the reviewer must return JSON the harness can parse):

```json
{
  "verdict": "pass",
  "comments": [{"file": "core/x.gd", "line": 12, "issue": "...", "severity": "high"}],
  "cannot_judge": ["visual quality of the tiles"]
}
```

If the output is not valid JSON, retry the review once, then treat it as a fail and escalate to the human.

**Check interface:** each check is a script that exits 0 on success and non-zero on failure, and prints plain-text errors that are fed back to the builder as-is.

**Run log** (`harness/logs/runs.jsonl`, one line per run): timestamp, task id, label, builder, reviewer, rounds used, result (`pass`, `fail`, `escalated`), duration, which checks failed, and notes.

**Git conventions:** branch name `agent/<label>/<slug>`. Put worktrees outside the repo (for example a sibling folder like `../pixel-game-worktrees/`) so they do not nest inside it. After a pass, open a PR with the `gh` CLI if it is installed. Otherwise leave the branch and print a summary. Never merge, and never delete branches or worktrees without asking.

**Limits:** a per-agent-run timeout (configurable, start around 15 minutes), the 3-round cap, and an optional maximum number of runs per day, since both tools have usage limits. When a limit is hit, stop and report.

**Escalation output:** when the harness stops without a pass, print the branch name, the last feedback, the failed checks, and the path of the log entry.

**Testing the harness itself:** use stub agents (small scripts that mimic `claude -p` and `codex exec` output) so the routing, retry, ownership and logging logic can be tested without spending tokens or needing real agent runs.

**Safety:** keep secrets (`.env`, keys) in `.gitignore` and out of prompts. Agents run only inside their task worktree. Do not enable any permission-skipping flags without the human's explicit approval (see Appendix E).

**Human gates printed by the harness:** after an art task, the path to the contact sheet. After any task, the branch or PR link.
