# Hollow Trial — approved art, editable visual scene

2026-10-31, `agent/codex/progression`. Owner approved the ground, then the20-prop sheet and instructed "start making the scene". No main merge. Existing unrelated dirty work, including Claude's in-progress trial core/data, is preserved.

Open `presentation/maps/hollow_trial_layered.tscn` in Godot. The512x352 ground is the approved file, byte-identical. There are32 separate y-sorted prop placements with editable positions,20 approved prop resources and2 smaller derived tree variants. Eight rune rocks frame the sides; the central altar and chest are separate objects. The original root-knot barrier is reused at the south entry. The bottom trees use nearest-neighbour45% copies so their canopies do not obscure the fight floor; the two lower ferns sit outside it too. The approved original images are unchanged.

## Lighting, shadows and editor controls

The scene reuses Root Hollow's night shader, nearest sprite sampling, moon-direction silhouette projection and nearest-practical local shadow approximation. Every prop's actual sprite alpha is its cast mask, so normal/mirrored casts use the same silhouette without adding40-44 padded shadow textures to the nearly-full atlas. Small contact shadows sit at solid bases. There are16 light entries for8 rune rocks,18 when the altar is lit, below the32-entry limit. No baked glow/shadow was added to source art.

`preview_lit`, `preview_chest_open` and `preview_sealed` are editor visual toggles. Prop/light-marker moves refresh their lighting and shadows in the editor. `sync_snapshot(trial, flags, tick)` is the future runtime visual interface: core state/flags select the altar, chest and barrier; supplied simulation tick controls rim-only fireflies. The authoring camera is disabled when a snapshot is supplied. The scene has **no** damage, wave progression, mob spawning, rewards, interactions or player-motion rules. Collider circles have physics layers/masks0 and are authoring/registration metadata only.

## Important integration boundary

**The current gameplay JSON still contains placeholder prop types. This new visual map is not yet substituted for those registered gameplay props.** Its ground path is installed, but playing the trial through the shared Explore renderer still uses Claude's current registered placeholder placements/art. Do not claim these scene captures show the final playable trial.

Claude must register the22 new types and proposed collider circles, bake/adopt the approved scene placements, and retain the map's custom rendering scripts. Handoff: `art/reference/hollow_trial_v1/CLAUDE_REGISTRATION_HANDOFF.md`, machine-readable `scene_registration.json` and `baked_scene_proposal.json`. Do not run a generator with `--reset` over the authored map: it would discard the custom scene renderer. After registration, Codex still needs to connect the visual scene to the shared gameplay renderer while preserving actor/prop sorting. Do not overlay a second map/prop layer over the existing renderer or replace colliders in presentation.

## Actual checks and captures

- `python -B art/reference/hollow_trial_v1/build_scene.py`: approved assets ->22 grids/prop scenes, ground copy, authored map and registration package. Refuses to overwrite an authored map whose hash differs from its previous generated hash.
- `python tools/art/validate_art.py`, `python tools/art/build_art.py`, `python tools/art/preview_art.py`: completed. Atlas1024x8136 (under8192), standard18 contact pages regenerated. No pipeline tooling changed.
- `python -B art/reference/hollow_trial_v1/audit_scene.py`: PASS. Approved ground hash;22 exact source/atlas RGBA and anchor matches;32 placements; scene-source hash; atlas limit.
- Godot4.7.2 import and `--headless --script res://presentation/review/hollow_trial/check_scene.gd`: PASS. Resource loading, all rim sprite bounds outside the fight rectangle, feet y-sort,22 baker anchor/collider comparisons, entry/object/spawn metadata,8/9 light sources, sealed/unsealed entry, lit altar, chest-open flag, tick source and stable shader reuse.
- `--script res://presentation/review/hollow_trial/capture_scene.gd`: real OpenGL snapshots of this visual scene, idle/sealed/lit/open. PNGs are512x352 native and1024x704 integer2x. They use supplied **visual-state fixtures**, not a trial playthrough, core win, physical collision or actual chest interaction. `*_VISUAL_STATE*` names make this explicit.
- Full harness `python -u harness/checks/run_tests.py --worktree . --timeout 300`: **PASS**, Python tests, import, core and every headless smoke; log `art/reference/hollow_trial_v1/scene_harness.log` ends `all test suites passed`. The standalone scene checks and real-renderer visual-state captures also pass. Three existing window-dependent capture smokes are excluded by the standard harness, as before.

The existing single static OpenGL texture leak is reported on capture shutdown (5460 bytes), with no capture script errors. Sandboxed focused runs also emit root-certificate/log-access errors; the full harness uses normal filesystem access and its isolated test-save path. Godot's import reordered the cursor settings in project.godot; that incidental reorder was undone, with no setting changes. Graphify query/update remain unavailable (`No module named graphify`), no installation attempted.

Cannot judge: whether the room looks right, crowding/fun, audio, combat-warning readability with real waves, final collider alignment, player walk-behind behaviour or the complete trial route/reward. New trial VFX/UI/audio, final gameplay integration and Claude cross-review are pending. Claude's OAuth session was expired at the last authorized review attempt; no reviewer PASS is claimed. The chest still gives Claude's documented herb placeholder until the owner chooses the Aspect.
