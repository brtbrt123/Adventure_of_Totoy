# Layered migration presentation retirement — 2026-10-27

Codex completed the presentation/test side of docs/CODEX_TASK_layered_migration.md. Owner authorized the work after reviewing the handoff. No core/data/tools/harness edits, no merge.

- Title New Game already used SceneDefs.START_SCENE/START_ENTRY; kept it. Legacy saved-ID fixtures in smoke_title intentionally remain, asserting Continue migrates into layered maps.
- Corrected route/checkpoint expectations in the three failing suites. Migrated active renderer tests and capture helpers to official layered identities and actual scene entries/NPC geometry. The walking bot now checks the layered north-return coordinate and completes seven transitions through the real fade path.
- Debug F2/1 village, F3/2 forest, F4/3 glade, F5/4 arena; F7/5 village, F8/6 glade, F10/8 forest remain aliases. No debug destination selects a painted scene.
- Removed painted ground/actor-object/occluder branches and old lighting/ambient identities from the exploration renderer and helpers. Current layered art, prop masks and the boss arena remain active.
- Archived converted painted grounds, painted occluder atlases/manifests and obsolete capture scripts in art/reference/retired_painted_maps. Original reference paintings are preserved. Historical scripts use .gd.txt so they do not keep obsolete core layouts as Godot dependencies.
- Kept DepthOccluders and its arena data. Python/Godot occluder regressions cover the arena; layered gate state/depth and traversal coverage lives in the layered suites. No obsolete rendering test was relabeled as proof of layered behavior.

## Claude follow-up

The active presentation GDScript audit finds no painted village/forest/glade literals or SceneDefs.VILLAGE/FOREST/GLADE constants. Active non-core scene tests no longer instantiate painted scenes. Two string-only saved-scene fixtures in smoke_title are intentionally retained to test legacy migration. tests/core and core itself were not changed; remove retired SceneDefs.IDS/layout branches and adjust their tests as Claude-owned work, preserving SaveProfile legacy migration. Old converter tooling belongs to Claude; retire/update it as appropriate (historical resource paths may refer to former runtime ground locations). Do not remove the boss arena or its occluder renderer.

## Verification

Focused route, title/Continue, bot, first-sword receipt, tutorial, night lighting and arena occluder checks pass. Python occluder reproducibility tests pass. Godot editor import passes. Final full harness passes all suites: Python, import, core and every smoke. Log: art/build/arena_layered_migration_final.log (ignored). A new debug-binding check initially ran before input registration; moving it after scene initialization fixed the test, and the fresh full harness is green. Technical checks cannot judge fun, route pacing, combat room or tutorial feel; owner should play New Game/Continue, both gate directions, training, sword handover and the arena transition. Cross-review remains for Claude.
