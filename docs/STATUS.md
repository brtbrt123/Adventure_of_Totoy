# STATUS (handoff note)

Last updated: 2026-10-15 · Branch: `stage1/setup` · Stage 1 of the plan in `PROJECT_BRIEF.md`

## Done

- Git repo, folder layout, `.gitignore`, `.gitattributes` (LF for text files, binary PNGs).
- `AGENTS.md` (self-contained shared rules, roles, fixed decisions, commands), `CLAUDE.md` (`@AGENTS.md`).
- `docs/GAME_DESIGN.md` (the owner's design draft, unchanged), `docs/architecture.md` (first draft of the core/presentation interface), `docs/ROUTING.md`, `docs/HARNESS.md`, `docs/decisions/0001-stage1-setup-choices.md`, empty `harness/` skeleton.
- `project.godot`: 320x180 base, window 1280x720, stretch `viewport` + `integer`, nearest filter, pixel snapping, `gl_compatibility`.
- `art/palette.json`: DB16, hex values read from the Lospec palette JSON.
- Art tools in `tools/art/`: build (PNGs, atlases, `tileset.tres`), validator, contact-sheet preview. Placeholder art: `grass`, `dirt`, `stone`, `water` tiles and `totoy_idle_down` (16x24).

## Verified (run on this machine)

- `python tools/art/validate_art.py` passes on the placeholder art (5 sources, 7 PNGs).
- `python tools/art/build_art.py` and `python tools/art/preview_art.py` run; `art/build/contact_sheet.png` was viewed and renders correctly.
- `python -m unittest discover -s tests` runs 11 tests, all pass, including: bad tile size, off-palette symbol, ragged rows, missing kind, seam mismatch, bad sprite size, partial transparency and off-palette PNG pixels all **fail** validation as intended.

- Godot 4.7.2 (extracted from the zip to `C:\Tools\Godot\`, PATH untouched; the `.exe` named folder in Downloads was empty). `--headless --import --quit` exits 0 with no errors. `tests/smoke_project.gd` prints `SMOKE OK`: it checks the display and filter settings, that `tileset.tres` loads with 16x16 tiles and 4 tiles, and that `sprites.png` and `sprites.json` load.

## Not verified

- `godot_console --headless --quit` alone fails with "no main scene defined" (there is no scene yet). The smoke script is the substitute check until a main scene exists.
- Tiles were not rendered in a running Godot window, so seam-free display with camera movement is unchecked.
- Codex: `codex-cli 0.162.1` is installed and logged in (ChatGPT). Its headless flags and model names are recorded in `docs/ROUTING.md`, but **no Codex run has been tested yet**, including whether Codex follows `AGENTS.md` and whether the listed models work with `codex exec -m`.
- Whether the art looks good: the human must judge the contact sheet. The seam check is a heuristic.

## Open questions for the human

1. Add `C:\Tools\Godot` to PATH (as `godot` / `godot_console`)? Not done; the docs use the full path.
2. Art mood: the design says cozy and readable (Stardew-like feeling). Is DB16 acceptable for that, or do you want a warmer custom palette?
3. Is `tools/` and `harness/` being owned by Claude Code acceptable (not in the brief's routing table)?
4. Test framework: plain headless GDScript scripts (recommended, no addon) or GUT / GdUnit4 (compatibility with 4.7.2 not checked)?
5. Headless permission setup for `claude -p` / `codex exec` needs your decision before Stage 2 (planned for Codex: `--sandbox workspace-write` scoped to the task worktree, no bypass flags).
6. Name the game's first-slice ordering: the design says the combat slice (Colossus) comes first; confirm that is the next real work after Stage 1.

## Recommended next steps

1. Human reviews `art/build/contact_sheet.png` and the palette.
2. Claude Code builds the combat core slice against `docs/architecture.md` (core only, with headless tests), then revisits that doc.
3. Stage 2 (router and worktrees) after Codex is installed.
