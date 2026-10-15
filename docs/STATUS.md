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

## Not verified

- **Godot has never opened the project.** `C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe` is an empty *folder*, not a program. The real executables are inside `Godot_v4.7.2-stable_win64.exe.zip` (editor and `_console.exe`). Not extracted yet. So these are unchecked: `project.godot` syntax and settings (for example `window/stretch/scale_mode="integer"`, `config/features`), and that `art/build/tileset.tres` loads and tiles show correctly.
- `codex` CLI is not installed or not on PATH, so nothing about Codex was checked.
- Whether the art looks good: the human must judge the contact sheet. The seam check is a heuristic.

## Open questions for the human

1. May I extract the Godot zip to a folder outside the repo (for example `C:\Tools\Godot\`) and optionally add it to PATH as `godot` / `godot_console`?
2. Art mood: the design says cozy and readable (Stardew-like feeling). Is DB16 acceptable for that, or do you want a warmer custom palette?
3. Is `tools/` and `harness/` being owned by Claude Code acceptable (not in the brief's routing table)?
4. Test framework: plain headless GDScript scripts (recommended, no addon) or GUT / GdUnit4 (compatibility with 4.7.2 not checked)?
5. Codex: install it before Stage 2. Headless permission setup for `claude -p` / `codex exec` needs your decision.
6. Name the game's first-slice ordering: the design says the combat slice (Colossus) comes first; confirm that is the next real work after Stage 1.

## Recommended next steps

1. Extract Godot, run `godot_console --headless --path . --import --quit`, fix anything it reports, then commit.
2. Human reviews `art/build/contact_sheet.png` and the palette.
3. Claude Code builds the combat core slice against `docs/architecture.md` (core only, with headless tests), then revisits that doc.
4. Stage 2 (router and worktrees) after Codex is installed.
