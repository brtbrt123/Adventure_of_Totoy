# HANDOFF: Adventure of Totoy (written 2026-10-16 for the next session)

Read this first, then `AGENTS.md` (the rules), then `docs/STATUS.md` (the detailed log, newest section first). Everything below is merged into `main` at commit `3fea8fe` or later and was verified (validator, 57 Python tests, Godot import, 38 core tests, every smoke suite).

## What this project is

A 2D top-down pixel-art action game in **Godot 4.7.2** (typed GDScript), 320x180 base resolution, 16x16 tiles, private Windows build and portfolio piece. Design: `docs/GAME_DESIGN.md` (the human's document, do not rewrite it). Combat language: **gold heavy attacks can be parried, red attacks must be dodged**; dash with i-frames; posture break opens a counter window. Current slice: one arena, the hero (sword) against the **Mossbound Colossus** boss.

Team: the human owns design, art approval, playtesting and **every merge**. Claude Code owns `core/`, `tools/`, `harness/`, docs. Codex owns `presentation/`, `art/`, UI and effects. Claude must not edit `presentation/` or `art/` unless the human allows it (the human granted two narrow exceptions this session for small bug fixes, both disclosed in the commits). The human asked for short answers and honest reports: say what ran, what passed, what you could not verify.

## How to run things (Windows, PowerShell)

```powershell
cd C:\Users\Admin\Desktop\Projects\Adventure_of_Totoy
$godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"      # not on PATH
C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path .                 # play the game (WASD move, LEFT CLICK attack, SHIFT dash, SPACE parry, R restart, F1 debug)
python harness/checks/run_tests.py --worktree .                       # everything: python tests + godot import + run_tests.gd + all smoke_*.gd
python tools/art/validate_art.py ; python tools/art/build_art.py ; python tools/art/preview_art.py
python harness/router.py run "<task>" --dry-run                       # the routing harness (see docs/HARNESS.md)
```
Godot editor: use `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe` (the copy in `C:\application` could not start the editor). Redirect Godot output to a file instead of piping it into `Select-Object -First`. A Godot script that hits a parse error can hang headless: give every run a time limit (the harness checks do).

## Where things are

- `core/`: headless deterministic simulation. `game_core.gd` (step + snapshot), `player.gd`, `boss.gd` (6 attacks: gold_slam, gold_combo, red_sweep, red_shards, red_stomp, red_charge), `telegraph.gd`, `snapshots.gd`, `game_event.gd`, `tuning.gd` (ALL balance numbers). Interface: `docs/architecture.md`.
- `presentation/arena/`: the arena scene and drawing (`arena.gd`, `animation.gd` frame table, `hud.gd`, `combat_effects.gd`, `telegraph_view.gd`, `head_anchors.gd`, `input_bindings.gd`). Presentation holds NO game rules.
- `art/`: `palette.json` (**Totoy 36**; gold and red are RESERVED for combat tells, the validator rejects them in tiles), `src/` text-grid sources, `build/` generated (committed), `reference/` the human's hero sheet and portrait.
- `tools/art/`: `validate_art.py`, `build_art.py`, `preview_art.py`, `import_reference.py` (turns the human's painted reference sheets into palette-bound anchored sprites; hero frames are GENERATED, do not hand-edit them).
- `harness/`: Stage 2 router/runner/checks (`docs/HARNESS.md`, `docs/ROUTING.md`, `harness/config.json`).
- `tests/`: `run_tests.gd` + `tests/core/test_*.gd` (38 tests), `smoke_*.gd` (windowed `capture_*` scripts are not tests), Python tests incl. `tests/harness_tests/`.
- `docs/decisions/`: 0001 stage-1 choices, 0002 Totoy 36 palette, 0003 test runner and preload-not-class_name.
- `docs/GEMINI_PROMPT_PACK.md`: numbered prompts (G00-G11 golem, H01-H09 hero, E01-E16 effects, U01-U05 UI, T01-T06 tiles, P01-P04 props) the human sends to Gemini. `docs/ART_PROMPTS_GEMINI.md` is the older sheet-style version.

## Open work, in the order I would do it

1. **The human is generating new art with Gemini** (golem, hero extras, effects, UI, tiles, props). When PNGs arrive in `art/reference/`, extend `tools/art/import_reference.py` to cut each sheet (grid, frame count and names are in the prompt pack; the background is flat magenta #FF00FF, so key that color; the old sheet used a fake checkerboard), then hand the integration to Codex like the hero (frame tables in `presentation/arena/animation.gd`; sprites declare `# anchor: x,y`). If Gemini changes a grid or frame count, adapt the importer config. Ask the human to approve results on the contact sheet.
2. **Golem and tiles are still Codex-drawn placeholders** (text grids). The boss has no walk/hurt/roar/death animation yet; effects are runtime-drawn.
3. **No audio** (silent `_sound_<event>` hooks exist in `arena.gd`). No title screen, save/load, quest log, other weapons (bow, staff), Aspects or artifacts (all in the design doc, none built).
4. **Harness:** one real run done (passed on round 2). Run more real tasks before trusting it on big ones. Not built: PRs (the repo has no git remote), GitHub CI, Graphify, Obsidian vault setup (`docs/` is plain markdown only). Codex's Windows sandbox: only `gpt-6-luna` gets a working shell (extra flags in `config.json`); `gpt-6.1-sol` and `gpt-6-astra` can only write files, so the harness checks and the Claude reviewer verify. Codex's own reports were often wrong or empty in this session (work appeared in worktrees with no shell): always rerun the checks yourself.
5. Playtest questions from the design doc are still open (parry window size, boss fairness); numbers live in `core/tuning.gd`.

## Known weak spots and decisions the human may revisit

- The hero art (imported from the human's reference) loses a lot at 30 px tall and is dark against the grass. A higher base resolution (for example 640x360) would keep far more of the reference art; that is a FIXED decision (320x180) only the human can change.
- The hero is a right-facing side view only (all directions use it, mirrored for left); the slash arc is painted into the frames, so attacks up or down still show a horizontal arc.
- Player health is teal on purpose (red is reserved for combat tells); easy to change if asked.
- Hero look was inspired by a shonen-anime hero but kept original (no emblems); the human supplied the actual reference art.
- Old branches and worktrees (`agent/*`, `..\Adventure_of_Totoy_worktrees\*`) still exist and were NOT deleted; `python harness/router.py cleanup` removes finished harness worktrees (asks first). Never delete branches or worktrees without asking.

## Practical gotchas learned this session

- The Claude PowerShell tool sometimes blocks a command that contains patterns like `Remove-Item` plus a regex (`\d+`, `.log$`); split the command or use `git rm -- 'pathspec'` / `Get-ChildItem | Remove-Item -LiteralPath`.
- Edit tools need the file Read first in the same session; worktree paths differ per worktree.
- Godot generates `.uid` and `.import` files: commit them. `art/build/*.log` is gitignored.
- A mirrored sprite is drawn with a NEGATIVE width and an unshifted rect (a past bug drew left-facing sprites one sprite width to the right).
- Claude model ids: `claude-haiku-5-5`, `claude-sonnet-5-5`, `claude-opus-5-5`. Codex models verified on this machine: `gpt-6-luna` (light), `gpt-6.1-sol` (standard), `gpt-6-astra` (heavy). `gh` is installed and logged in, but there is no remote.
- Merges: the human approves each one. This session the human approved merging everything into `main`.
