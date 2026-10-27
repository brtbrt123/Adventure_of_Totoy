# Forest sources and night ambience — 2026-10-27

Status: forest source images generated for HUMAN REVIEW; not approved or installed in runtime. Existing painted forest, painted glade and layered glade now share the selected soft village moonlight. Village lighting values are unchanged.

## Human approval

2026-10-27: the owner approved the displayed night lighting, teal rune glow and moving fireflies ("yes i like that"). Preserve this appearance when integrating the layered forest. This approval records the displayed runtime look; the forest source-image approval status above is unchanged.

## Source images

- `forest_ground_only.png`: original generator output, 1619x971, intended conversion to 480x288 after approval. Ground only: left entrance, two clearings, top exit, east dead end; bottom exit removed in a second generation edit.
- `forest_props_sheet.png`: original generator output, 1536x1024, magenta extraction sheet. Includes dark unlit pedestals and teal-lit variant, closed/open root gates, trees, logs, foliage and small props. The two initially yellow-lit pedestals were corrected through image generation.
- References supplied to imagegen: `art/reference/forest_route_target.png` for route composition, `presentation/village/village_layered_ground.png` for ground texture, and `art/reference/layered_pilot/review/glade_full.png` for prop scale, camera and palette style. Neutral source painting deliberately leaves the night tint/glow to runtime.
- These generated originals are NOT palette-validated production assets. Art style/readability and approval belong to the human.

## Implemented presentation

- `presentation/common/ambient_fireflies.gd`: 22 deterministic cosmetic motes per forest/glade map, whole-pixel drift and pulse from snapshot ticks, world-space bases sorted with props/actors. No gameplay RNG, collision, damage, interaction or save changes. Pauses with scene simulation. Halos are runtime effects; no raster alpha edges changed.
- `environment_light.gd` now supports the painted forest/glade as well as layered scenes. Five layered glade rune sockets measured from teal source pixels; four visible painted rune positions are attached to their painted stones. Teal practical light and cool cores keep the clearing readable.
- Runtime review images and 3.6-second looping firefly GIFs live in `review/`. Capture with Godot console `--path . --script res://tests/smoke_night_ambience.gd -- --capture` (windowed); smoke without capture runs headless.
- Full-map capture disables the camera; prop culling then covers the complete scene. Normal gameplay retains the 320x180 camera view.
- Removed redundant layered ground overrides because Claude has fixed the authoritative shared scene paths.

## Next: Claude, after human source approval

1. Extract this sheet with the existing pipeline into this directory's `props/`; measure bases, then provide forest prop definitions/placements and a shared `forest_layered` scene. No core/data/tools files were edited by Codex.
2. Normalize the two pedestal states to ONE identical body/anchor/size, and the two root gate states to ONE outer frame/anchor/size. Generated variants are visually close, not pixel-identical. Reuse/copy matching geometry instead of moving colliders with the art.
3. The generated sign has one main board rather than the requested two arrow boards, and one of the three fern slots resembles a small bush. These are review findings, not approved substitutions; request a focused revision if the owner wants the exact original prop list.
4. Expose the authoritative pedestal-lit and gate-open visual states via PropScene placements or the documented snapshot contract. Codex will map lit sockets to that state; do not derive gameplay state from lights. Existing painted forest pedestals are intentionally not given invented lit states.
5. Codex then converts the approved ground to Totoy36 at 480x288, cleans source grids/padding/anchors, rebuilds/validates, wires layered rendering, adds the debug jump and captures depth/exit/interaction coverage. No production forest source assets have been wired before approval.

## Review limits

Technical smoke checks verify scope, deterministic motion, pulse, bounds, renderer load and rune light presence. They cannot judge aesthetic quality, comfort, whether the nighttime contrast is sufficient on the owner's monitor, or whether the game is fun. Claude must cross-review the presentation diff; the owner approves sources and final captures.

## Cross-review of Claude commit 8418f54

PASS, no actionable findings in the reviewed diff. `data/scenes/glade_layered_props.json:9` and `data/scenes/village_layered_props.json:9` now point to the correctly sized presentation grounds. `tests/run_tests.gd:23` rejects non-instantiable scripts; the new `tests/core/test_layered_progress.gd` covers saves, checkpoints and exit targets. Severity: none. This does not approve visual quality or gameplay feel.

## Validation

PASS: full background `python -u harness/checks/run_tests.py --worktree .` (Python unit tests, Godot import, core tests and every smoke suite), plus a final Godot import after the generated sources were saved. Windowed AMD/OpenGL captures completed without script or shader errors. The known sandbox root certificate-store warning remains unrelated. Existing art source grids and atlases were not changed, so no sprite rebuild was needed. `validate_art.py` also passes.
