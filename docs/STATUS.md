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

## Boss patterns and boss animation (branch `agent/logic/boss-patterns`, 2026-10-15)

The human noticed the golem had no swing animation and asked for more attack patterns.
- **Core (Claude Code, `9d3f152`):** three new attacks: `red_stomp` (new `ring` telegraph shape; the inside is safe), `gold_combo` (two parryable slams; phase 2 only) and `red_charge` (a lane the boss body travels along; phase 2 only). Phase 1 picks from slam, sweep, shards, stomp; phase 2 from all six. Player attack windup 5 -> 7 ticks (room for a draw animation). 9 new tests, 36 total, mutation-checked. Interface: `docs/architecture.md`.
- **Presentation and art (Codex):** about 24 new Colossus frames (sweep: 3 windup + 4 strike frames and a recover; slam, shards, stomp, combo and charge with 3 windup and 2 strike frames each), a motion arc for the sweep, dust at slam impacts, the stomp ring warning with a marked safe zone and expanding shockwave, charge lane and dust trail, plus updated `animation.gd` and tests. Screenshots: `art/build/arena_sweep.png`, `arena_stomp.png`, `arena_combo.png`, `arena_charge.png` (also slam and shards).
- **Provenance, honestly:** Codex's shell failed at startup in all 4 attempts and the work was already in the worktree (written by a process I cannot identify; its final report says existing logs reported passing checks). Claude Code reran everything: validator, art build, Python tests, Godot import, `run_tests.gd` (36), `smoke_project`, `smoke_arena`, `smoke_animation`, `smoke_effects`, and a 120-frame headless run of the main scene. One small bug was found and fixed by Claude Code in a Codex-owned file under the human's earlier exception for small syntax fixes: a one-tab indentation error in `tests/smoke_effects.gd` (line 140). After that all pass.
- **Not judged:** motion quality (only stills reviewed; Codex itself flags the sweep strike as brief) and whether the new attacks feel fair. Phase-2 attacks were only exercised by forced scripted attacks, not by a real fight.

## Effects, controls and retuning (branch `agent/ui/effects-controls`, 2026-10-15)

After playing the animated arena the human asked for: red laser light and a sword swish, new controls (attack = left click, dash = Shift, parry = Space), a slower character and a shorter dash.
- **Tuning (`core/tuning.gd`, Claude Code):** `PLAYER_SPEED` 1.5 -> 1.0; dash 10 -> 6 ticks and 56 -> 30 px; dash i-frames now run on their own 8-tick counter (so the short dash keeps a forgiving window); `SWEEP_WINDUP_TICKS` 42 -> 54 so the red sweep can still be walked out of at the slower speed. The core tests caught both the sweep and the dash-timing consequences; 27 tests pass.
- **Presentation (Codex):** `input_bindings.gd` (new controls, mouse-aimed swing), `combat_effects.gd` (red laser beams with cream core, red body, flicker, muzzle flash, floor glow and afterglow; red sweep flash; sword glint/crescent/trail; hit sparks; counter shake), walk and dash animation cadence retimed, HUD hint updated, `tests/smoke_effects.gd`, `tests/capture_effects.gd`. Screenshots: `art/build/arena_beam.png`, `art/build/arena_slash.png`.
- **Provenance, honestly:** as before, Codex's sandbox shell failed at startup in all 4 attempts and the implementation was already in the worktree when its final attempt opened it (written by a process I cannot identify; the human may be running Codex too). Claude Code reran everything: validator, Python tests, `run_tests.gd` (27), `smoke_project`, `smoke_arena`, `smoke_animation`, `smoke_effects`: all pass. A stray `Godot/` folder (Godot settings and logs written into the worktree) was deleted and is now git-ignored.
- **Not judged:** how the effects feel in motion. In the swing screenshot the crescent is small and thin; the red beams read strongly. Nobody has verified the mouse aim by playing (only that the bindings exist).

## Animation (branch `agent/animation/arena-anim`, 2026-10-15)

The human played the arena and said it lacked animation. About 60 frame sources exist now (Totoy: idle, walk, dash, parry, attack windup/active/recovery, dead in down/up/right with left mirrored; Colossus: idle, windup and strike per attack, recover, posture_broken, dead), plus `presentation/arena/animation.gd` (frame table; frames chosen only from the snapshot) and `tests/smoke_animation.gd`. Convention: `AGENTS.md` section 5.

**How it was made, honestly:** Codex's sandbox shell kept failing (`helper_unknown_error`, caused by Codex's own `node_repl.exe` locking a file the sandbox setup validates; `--disable` flags and 6 retries did not fix it). Files appeared in the worktree at 9:13-9:35 PM from a process I cannot identify (the human may have run Codex in their own terminal). Nothing was run or reviewed by its author. **Claude Code verified it afterwards and, with the human's one-time permission, fixed a parse error in Codex's files** (the constant `Animation` shadowed Godot's native `Animation` class; renamed to `ArenaAnimation` in `arena.gd` and `tests/smoke_animation.gd`, nothing else changed). After that: validator, Python tests, `run_tests.gd` (26 tests), `smoke_project.gd`, `smoke_arena.gd`, `smoke_animation.gd` (all frames exist, no missing frame in a scripted fight), a 120-frame headless run (0 script errors) and the windowed capture all pass.

**Not judged:** whether the animation looks good or reads well in motion (only still frames were reviewed: consistent silhouettes and colors, no gold or red on the boss). Weak spots seen: windups differ only slightly from idle, and Totoy's `dead` frames look like standing poses, not a fall. Sound is still absent.

## Playable arena (branch `agent/ui/arena-slice`, 2026-10-15)

Codex (`gpt-6.1-sol`) wrote `presentation/arena/` (scene, input bindings, telegraph drawing, HUD, effects, silent sound hooks) and a placeholder 48x48 Colossus sprite; `project.godot` now runs `res://presentation/arena/arena.tscn` at 60 physics ticks per second. **Codex's sandbox shell failed again mid-task, so it could not run anything; Claude Code ran every check afterwards**: art validate/build/preview, Python tests, Godot import, `run_tests.gd`, `smoke_project.gd`, the new `tests/smoke_arena.gd`, a 120-frame headless run of the main scene, and the windowed `tests/capture_arena.gd`, which wrote `art/build/arena_preview.png`. All exit 0. Presentation holds no game rules (it reads `Tuning` only to draw F1 debug circles).

**To play:** open the project in the Godot editor and press F5, or run `C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path .` from the project folder. Controls (changed 2026-10-15 at the human's request): WASD/arrows move, **left mouse click attack (swings toward the cursor), Shift dash, Space parry**, R restart, F1 debug overlay; gamepad: left stick, west/south/east buttons for attack/parry/dash. (This line describes the older arena section; the current controls are these.)

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
