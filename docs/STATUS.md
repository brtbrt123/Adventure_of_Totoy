# STATUS (handoff note)

Last updated: 2026-10-15 · Branch: `stage1/setup` · Stage 1 of the plan in `PROJECT_BRIEF.md`

## Done

- Git repo, folder layout, `.gitignore`, `.gitattributes` (LF for text files, binary PNGs).
- `AGENTS.md` (self-contained shared rules, roles, fixed decisions, commands), `CLAUDE.md` (`@AGENTS.md`).
- `docs/GAME_DESIGN.md` (the owner's design draft, unchanged), `docs/architecture.md` (first draft of the core/presentation interface), `docs/ROUTING.md`, `docs/HARNESS.md`, `docs/decisions/0001-stage1-setup-choices.md`, empty `harness/` skeleton.
- `project.godot`: 320x180 base, window 1280x720, stretch `viewport` + `integer`, nearest filter, pixel snapping, `gl_compatibility`.
- `art/palette.json`: **Totoy 36** (on branch `agent/palette/totoy36`, approved 2026-10-15; replaces DB16, see `docs/decisions/0002-totoy36-palette.md`). Gold and red are reserved for combat cues; the validator rejects them in tiles. Existing placeholder art was remapped; Codex has not yet redrawn the terrain with the new palette. The obsolete DB16 branches `agent/tile/terrain-redo` and `agent/tile/grass-polish` were deleted at the human's request. Current Codex result: branch `agent/tile/terrain-v2` (18 tile variants on Totoy 36, built by Codex `gpt-6.1-sol` from the human's references), merged with the palette branch; waiting for the human's review. Not merged anywhere.
- Art tools in `tools/art/`: build (PNGs, atlases, `tileset.tres`), validator, contact-sheet preview. Placeholder art: `grass`, `dirt`, `stone`, `water` tiles and `totoy_idle_down` (16x24).

## Combat core slice (branch `agent/logic/combat-core`, 2026-10-15)

`core/` now holds a headless, deterministic combat slice: the player (sword, dash with i-frames, gold parry with perfect/early quality, Edge) against the Mossbound Colossus (gold slam, red sweep, red shards, posture break with a 120-tick counter window, phase 2 at half health), with victory/defeat. Interface and usage: `docs/architecture.md`. All numbers: `core/tuning.gd`. Run the 26 core tests with `& $godot --headless --path . --script res://tests/run_tests.gd`. Decisions: `docs/decisions/0003-core-test-runner-and-preload.md`.

**What this does not tell us:** nobody has played it. There is no scene, input mapping or drawing yet (that is `presentation/`, Codex's area), so whether the parry window, boss timings and damage feel fair or fun is unknown. The numbers in `tuning.gd` are first guesses. Only the logic is tested (including: warning area equals hit area, aim locked at commit, determinism).

## Playable arena (branch `agent/ui/arena-slice`, 2026-10-15)

Codex (`gpt-6.1-sol`) wrote `presentation/arena/` (scene, input bindings, telegraph drawing, HUD, effects, silent sound hooks) and a placeholder 48x48 Colossus sprite; `project.godot` now runs `res://presentation/arena/arena.tscn` at 60 physics ticks per second. **Codex's sandbox shell failed again mid-task, so it could not run anything; Claude Code ran every check afterwards**: art validate/build/preview, Python tests, Godot import, `run_tests.gd`, `smoke_project.gd`, the new `tests/smoke_arena.gd`, a 120-frame headless run of the main scene, and the windowed `tests/capture_arena.gd`, which wrote `art/build/arena_preview.png`. All exit 0. Presentation holds no game rules (it reads `Tuning` only to draw F1 debug circles).

**To play:** open the project in the Godot editor and press F5, or run `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path .` from the project folder. Controls: WASD/arrows move, J/Z attack, K/X parry, Space/L dash, R restart, F1 debug overlay; gamepad: left stick, west/south/east buttons for attack/parry/dash.

**Not done / not judged:** nobody has played it, so fight feel, readability of the warnings and the look are unjudged. Only `totoy_idle_down` and `mossbound_colossus_idle` frames exist, so other states use an idle fallback with tints and log one warning per missing frame name. No sound yet. Interface gaps Codex reported: no unconditional slam-impact event (the shake on slam is inferred), collision radii for debug drawing are read from `core/tuning.gd`, and the counter-window maximum comes from the `counter_window_opened` event.

## Verified (run on this machine, earlier stages)

- `python tools/art/validate_art.py` passes on the placeholder art (5 sources, 7 PNGs).
- `python tools/art/build_art.py` and `python tools/art/preview_art.py` run; `art/build/contact_sheet.png` was viewed and renders correctly.
- `python -m unittest discover -s tests` runs 11 tests, all pass, including: bad tile size, off-palette symbol, ragged rows, missing kind, seam mismatch, bad sprite size, partial transparency and off-palette PNG pixels all **fail** validation as intended.

- Godot 4.7.2 (extracted from the zip to `C:\Tools\Godot\`, PATH untouched; the `.exe` named folder in Downloads was empty). `--headless --import --quit` exits 0 with no errors. `tests/smoke_project.gd` prints `SMOKE OK`: it checks the display and filter settings, that `tileset.tres` loads with 16x16 tiles and 4 tiles, and that `sprites.png` and `sprites.json` load.

## Not verified

- (Fixed on the arena branch: the project now has a main scene, so `godot_console --headless --path . --quit-after 120` runs it. On branches without the arena, `--quit` alone still fails with "no main scene defined".)
- Tiles were not rendered in a running Godot window, so seam-free display with camera movement is unchecked.
- Codex: `codex-cli 0.162.1` is installed and logged in (ChatGPT). Its headless flags and model names are recorded in `docs/ROUTING.md`, but **no Codex run has been tested yet**, including whether Codex follows `AGENTS.md` and whether the listed models work with `codex exec -m`.
- Whether the art looks good: the human must judge the contact sheet. The seam check is a heuristic.

## Codex test run (2026-10-15): failed, environment problem

A light-tier task (`gpt-6-luna`, `--sandbox workspace-write`, worktree `..\Adventure_of_Totoy_worktrees\grass-polish`, branch `agent/tile/grass-polish`) changed nothing. Codex could not start any shell: `Failed to create unified exec process: helper_unknown_error: setup refresh had errors`. `codex doctor` shows `sandbox backend: elevated`, `sandbox provisioning: failed`. So the Windows sandbox for Codex is not set up on this machine; the model, login and prompt were not the problem. Not fixed, because re-provisioning is a system-level change and the bypass flags were ruled out. The worktree is clean and still exists (not deleted). Also seen: `failed to refresh available models: request timed out` (network, minor).

**Resolved the same day.** Cause: the Codex *desktop app* was running and held `node_repl.exe` open (Windows error 32 in `~/.codex/.sandbox/sandbox.<date>.log`), so the sandbox setup refresh failed. After fully quitting the desktop app (tray icon too), `codex sandbox cmd /c echo ok` worked and the task ran. **Rule for headless runs and the Stage 2 harness: quit the Codex desktop app first**, or the sandbox may fail again. Re-test run: `gpt-6-luna`, `workspace-write`, branch `agent/tile/grass-polish` (commit `ae1c462`): changed 3 pixels of `grass.txt` (gold flecks), regenerated `art/build/`, stayed in its folders, ran validate/build/preview, did not commit. Claude Code reran validate and tests (pass) and confirmed the rebuild is identical. Not merged; waiting for the human's look at the contact sheet.

## Open questions for the human

1. Add `C:\Tools\Godot` to PATH (as `godot` / `godot_console`)? Not done; the docs use the full path.
2. Art mood: the design says cozy and readable (Stardew-like feeling). Is DB16 acceptable for that, or do you want a warmer custom palette?
3. Is `tools/` and `harness/` being owned by Claude Code acceptable (not in the brief's routing table)?
4. Test framework: plain headless GDScript scripts (recommended, no addon) or GUT / GdUnit4 (compatibility with 4.7.2 not checked)?
5. Headless permission setup for `claude -p` / `codex exec` needs your decision before Stage 2 (planned for Codex: `--sandbox workspace-write` scoped to the task worktree, no bypass flags).
6. Name the game's first-slice ordering: the design says the combat slice (Colossus) comes first; confirm that is the next real work after Stage 1.

## Recommended next steps

1. Human reviews `art/build/contact_sheet.png` and the palette.
2. Codex builds a playable `presentation/` arena for the combat slice (scene, input mapping, drawing telegraphs from the snapshot, HUD, placeholder boss sprite), so the human can playtest and tune `core/tuning.gd`. Needs a boss placeholder sprite and Totoy states in `art/`.
3. Stage 2 (router and worktrees) after Codex is installed.
