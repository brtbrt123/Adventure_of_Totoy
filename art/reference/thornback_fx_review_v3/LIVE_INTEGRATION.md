# Approved visuals installed — core implementation still required

2026-10-30. Owner: "wire them and tell me if claude need to do something".

## Wired

- Shared `presentation/explore/explore_scene.gd` synchronizes `creature_effects.gd` on entry and every new snapshot. Ground VFX are below actors/props; horn glows are drawn directly after their own body, before higher-sorted props. All exploration maps use this path; no boss-scene-only conditional.
- Existing Stag slam reads the actual cone size/angle/direction from core, with a cosmetic shock and rubble. Existing charge gets position-sampled hoof dust, pose-matched horn glow and real-crash bursts. Existing root attack gets the approved spirit-root animation at its committed warning centre. Cache is keyed by telegraph ID, so eight future warnings produce eight effects automatically.
- Approved Stag breathing/walk and Glowmoth idle/move/shot/hurt/death poses are registered. Future `stag_summon` selects the approved chant/release body and attached horn layers. Healing links require explicit core `regen_active` and moth `summoner_id`; green pulse only follows an actual HP increase.
- 344 approved native body/effect sprites imported into text grids; rebuilt standard atlas, variants, frame metadata and 17 contact-sheet pages. Effect padding is cropped while retaining the anchor inside the canvas; importer reconstructs original pixels at their original anchor and asserts exact equality. No tooling modification to enlarge the atlas; current sheet stays below the 8192 limit.

## Claude still needs to implement

**None of the new numerical/gameplay rules are simulated in presentation.** Current core still has old slam reach50, charge4.4/36ticks, one root site and no Glowmoth creature/summon/healing behavior. Required work and proposed interface: `docs/CLAUDE_TASK_thornback_balance_v3.md`.

Claude must implement reach125; charge6.6/24ticks; eight valid separately warned damage zones; chant spawning exactly five real Glowmoths; fixed total2%max-HP/second healing while any caster-owned summon survives; Glowmoth combat/projectiles and read-only projectile information for rendering. Proposed non-damaging cast-progress fields are `cast_start_tick` and `cast_release_tick` on the Stag mob view. No fake damage telegraph is needed or created for chanting.

## Checks

- Installed Godot version verified: 4.7.2 stable.
- Art validator -> builder -> preview: PASS. Initial build exceeded atlas height; transparent effect padding was compacted and rebuild passed.
- Import after rebuild: exit0, no GDScript parse/compile errors. Captures were re-run after atlas reimport to avoid stale texture/frame coordinates.
- `tests/smoke_stag_glade.gd`: PASS through real core slam/charge/roots, phase change, defeat and HUD.
- `tests/smoke_creature_effects.gd`: PASS. Eight distinct warning-aligned roots; same-tick stability and no snapshot mutation; recovery at committed sites; death/interruption/scene cleanup; pose lookup across both creature tables; enlarged core cone retained exactly; heal pulse only on real HP gain and no duplicate on pause.
- Importer's 344 pixel/anchor parity assertions: PASS.
- `tests/capture_creature_effects.gd` with the real OpenGL compatibility renderer: exit0. Six natural live captures plus two future-rule fixtures under `live/`, inspected at1152x648 (3x base). Fixture filenames explicitly say `NOT_CORE_GAMEPLAY`; their positions are not registered/collision-tested encounter placements.
- Full harness: **PASS**, exit0: `python -u harness/checks/run_tests.py --worktree .` (Python tests, Godot import, full core suite and every headless smoke). Initial sandbox run failed save-dependent tests due to blocked user-data writes; rerun with filesystem access and the harness's isolated test-save path passed all suites. Final log: `full_harness.log`.

Graphify query/update could not run: `No module named graphify`. Godot printed sandbox log/certificate/editor-settings access warnings, and the windowed capture printed a texture RID warning on renderer shutdown; captures completed and no script error occurred. No manual playthrough, new-rule runtime validation, safe-spawn/eruption collision certification or final art/play-feel approval is claimed. Claude cross-review is pending. No core/, data/, tools/ or harness/ changes by this task.

No generation credits or new external assets used. Original review GIFs remain available and the approved Glowmoth art was not repainted.
