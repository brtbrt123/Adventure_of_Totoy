---
name: totoy-art-pipeline
description: Use when changing or adding art in Adventure of Totoy (art/src text grids, generated effect frames, prop or sprite art): the validate, build, preview, Godot import steps, the Windows file-lock and editor-import gotchas, and the rule to show the owner a picture first.
---

# Totoy art pipeline

Rules first (from the owner): show a picture (mock-up or in-game capture) and get a yes BEFORE changing how anything looks or placing new art in a map. Painted props need art in the painted style (`art/reference/layered_village/`), never code-drawn blocks. Palette is Totoy 36; gold and red are combat cues.

## Steps (project root, PowerShell or Git Bash)
1. Change `art/src/*.txt` (or run a generator: `tools/art/make_hero_fx_art.py`, `make_form_fx_art.py`, `make_aspect_fx_art.py`, `make_mob_fx_art.py`; toolkit `tools/art/staff_fx.py`). Never hand-edit generated `totoy_*`, `hero2_*` frames (see AGENTS.md section 5).
2. `python tools/art/validate_art.py`
3. `python tools/art/build_art.py`: if it fails with `Errno 22` or `Access is denied`, the Godot editor holds a file. Retry in a loop (4 s pause). A killed build leaves ~1300 built PNGs deleted: always rerun it to completion.
4. `python tools/art/preview_art.py` (contact sheets; the page count can shrink when frames are removed: delete the obsolete last sheet and its .import).
5. `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import --quit`, THEN restore the `art/build/contact_sheet_*.png.import` files the editor recreated: `git checkout HEAD -- <file>` (retry on locks).
6. Tests: core `--headless --path . --script res://tests/run_tests.gd` (577 expected), `python -m unittest discover -s tests` (94), smokes via `tests/smoke_*.gd`. Three smokes only pass with a window: smoke_capture_hero, smoke_gemini_capture, smoke_hero_capture.
7. Commit `art/src` and `art/build` together. Do not run Python tests while build_art.py runs.

## Gotchas
- Stale textures: if props draw wrong (dark discs, wrong sprites) after an atlas change/revert, run the Godot import again; the editor may need a click or restart.
- `tools/godot/generate_prop_scenes.py` reformats `presentation/props/hollow_trial_*.tscn`: `git checkout HEAD --` those after running it.
- Each prop needs: `data/props/prop_defs.json`, `presentation/common/prop_art.json` (contact + cast shadow), `art/reference/shadow_layers/manifest.json`, `presentation/props/<type>.tscn`, and tests that list village types.
- Image generators: Higgsfield (nano_banana_2_1, ~30 credits left 2026-11-02) and SpriteCook (free tier, 1 credit 2026-11-03). Uploading a reference sends it off the machine: ask the owner first. See docs/EFFECTS_REDO.md.
