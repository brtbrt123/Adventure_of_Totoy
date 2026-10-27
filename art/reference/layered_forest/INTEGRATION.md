# Layered forest integration — 2026-10-27

Owner-approved sources from 2026-10-27 are now imported. Runtime floor: `res://presentation/forest/forest_layered_ground.png` (480x288). The painted forest and chapter route remain intact. Debug: **8 / F10** enters `forest_layered`; **G / F6** toggles the gate; **7 / F9** toggles night lighting.

## Art import

All 25 cut-outs were already hard-alpha, palette-only, and free of reserved colors/magenta. Every original RGBA pixel is preserved in its trimmed atlas region; there is no palette-snap damage to a prop silhouette. Ground uses the existing village Lab snap/grade/cleanup at the full source bounds, then outputs hard opaque palette pixels. Sources copied from `data/props/cutouts_forest` to `props/`. Reproduce with `python art/reference/layered_forest/prepare_assets.py`.

Padding is top and right only, never below the base. Header x anchors round half pixels up; exact shared anchors remain in `import_manifest.json`. Runtime trims source padding and snaps once to the world pixel grid. Both states share their padded canvas and anchor.

| Type | Padded size | Header anchor | Shared anchor |
|---|---|---|---|
| forest_sign | 32x48 | [16, 48] | [15.5, 45] |
| forest_pedestal | 32x56 | [13, 56] | [13.0, 49] |
| forest_pedestal_lit | 32x56 | [13, 56] | [13.0, 49] |
| forest_lantern_post | 32x56 | [15, 56] | [14.5, 54] |
| forest_gate_closed | 128x88 | [61, 88] | [61.0, 87] |
| forest_gate_open | 128x88 | [61, 88] | [61.0, 87] |
| forest_tree_middle | 96x120 | [56, 120] | [55.5, 113] |
| forest_standing_stone | 56x64 | [24, 64] | [24.0, 61] |
| forest_rock_root | 64x48 | [30, 48] | [29.5, 47] |
| forest_tree_left | 120x104 | [59, 104] | [58.5, 103] |
| forest_tree_right | 128x104 | [75, 104] | [75.0, 104] |
| forest_log_1 | 88x48 | [54, 48] | [54.0, 42] |
| forest_log_2 | 72x40 | [37, 40] | [36.5, 40] |
| forest_stump | 72x40 | [29, 40] | [28.5, 40] |
| forest_chest | 48x32 | [26, 32] | [26.0, 32] |
| forest_thorns_1 | 64x48 | [33, 48] | [32.5, 44] |
| forest_thorns_2 | 56x40 | [27, 40] | [27.0, 38] |
| forest_bush_1 | 56x40 | [27, 40] | [27.0, 40] |
| forest_bush_2 | 56x40 | [26, 40] | [25.5, 38] |
| forest_fern_1 | 64x40 | [29, 40] | [28.5, 37] |
| forest_fern_small | 40x32 | [19, 32] | [19.0, 32] |
| forest_fern_2 | 48x40 | [22, 40] | [22.0, 38] |
| forest_flowers | 56x40 | [29, 40] | [29.0, 36] |
| forest_rocks | 48x32 | [19, 32] | [18.5, 31] |
| forest_mushrooms | 40x32 | [19, 32] | [18.5, 27] |

## Rendering and state

Placements resolve directly from `snapshot.gate_open` and `snapshot.lit_switches`. Scene entry, `switch_lit`, `gate_changed`, and debug toggle refresh props and lighting. `gate_changed` records progress and writes the gate when persistence is enabled. The smoke test verifies the autonomous puzzle event saves the open flag to a dedicated disk path, then verifies debug close/open and returning to the scene restore both lit props. No gameplay flags or collisions live in presentation.

25 prop metadata entries and 50 independent hard-alpha cast masks use the same selected upper-left moon projection (0.30,0.25). Small contact footprints follow actual lower silhouettes. Logs use depth strips along their lower edges. Shadows are drawn on the ground before actors/props. All 76 shared prop types now have complete shadow metadata; temporary forest exclusions in the two Python tests are removed.

Forest lights: two gate glints, one standing-stone rune, one warm lantern; each lit pedestal adds one teal fixture. Off/one lit/both lit = 8/10/12 shader entries, below the cap of 16. Mixed per-fixture colors preserve the warm post beside teal runes. Fixture sockets use original cut-out coordinates and shared anchors, including mirrored placements.

## Review of Claude 0afb389

**PASS with one low finding** for the implemented puzzle, state-pair geometry, colliders, save restoration and exit contract. **[P3] `data/scenes/forest_layered_props.json:268`**: the middle tree at feet (252,92) sits immediately against the upper boundary (`outline`, line 10). No reachable north-side review pose was found inside/near its silhouette. This prevents the requested real walking-behind capture for that tree; it does not block the puzzle/exit route. All remaining review poses use real core movement. The closed gate rear pose starts from the real `north` entry, because the closed gate deliberately isolates it.

**Task for Claude:** determine whether a reachable rear pose exists for `tree_middle` and provide its coordinate/path; otherwise adjust the shared boundary or placement with the owner, then rerun the forest reachability tests and ask Codex to capture that pose. Do not silently move the approved tree or weaken collision in presentation. No core/data/tools files were edited.

**Review-image status: PARTIAL** — 21 successful front/behind poses plus two full-map overviews; middle-tree rear pose is recorded as unavailable in `review/final/positions.json`. No fake hero pose is substituted. Final PNGs, the summary sheet and a moving firefly GIF are in `review/final/`.

## Claude low findings addressed

- Night ambience smoke uses `expect`/failure reporting and exits 1 instead of hanging on assert.
- Painted-glade rune locations moved from code into `local_lights.json`.
- Prop/actor cast-pass alpha values are named constants in EnvironmentLight and passed as shader uniforms; the shader matches each explicit tag.
- Light-plan overflow reports the dropped fixture count with `push_warning`.
- Cosmetic fireflies now use art-authored clearing regions from `ambient_regions.json`, rather than scattering across the entire map. Regions are visual only; canopy/prop sorting still applies.
- Culling uses the viewport canvas transform, without branching on the camera enabled flag. Camera scroll refreshes immediately after movement.

## What cannot be judged

Human judgment is still needed for visual quality, night brightness/comfort, prop scale and how walking feels. Combat cue readability is untested here because exploration has no combat telegraphs. No performance benchmark was taken. The source sign/gate proportions were accepted by the owner; this work preserves them.

## Verification

Art validate/build/preview completed; focused forest import, all-prop shadow, village import and renderer/puzzle smoke tests passed. Windowed AMD/OpenGL captures completed without script/shader errors. Full background regression result is recorded below when complete.

**Full regression: PASS.** `python -u harness/checks/run_tests.py --worktree .` completed in the background: Python tests, Godot import, core runner and every smoke suite (including `smoke_forest_layered`, `smoke_night_ambience`, `smoke_layered_scenes`) exited 0. `git diff --check` passed. Known middle-tree visual-review limitation is reported separately, not counted as a successful walking pose.
