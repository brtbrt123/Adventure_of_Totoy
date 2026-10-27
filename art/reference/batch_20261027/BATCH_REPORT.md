# Batch report â€” 2026-10-27

## Completed in order

1. Installed the reproducible cleaned painted village ground, removed the old training_dummy occluder and rebuilt the village occluder atlas. Painted post is a y-sorted obj_dummy_1 / obj_dummy_hit_* at the core's new feet, with contact shadow/wobble; layered post remains its single shared placement. Art validate/build/preview, Godot import, smoke_village_tutorial and smoke_depth_occluders passed. Live captures of both villages are in job1/; the windowed forest --capture run also passed and now includes the middle-tree behind image in art/reference/layered_forest/review/final/; no scene/collider fixture overrides remain in capture_village_polish.
2. item_received now calls Explore.show_reward with presentation icon mapping. smoke_first_sword_receipt passed for both villages: finished/skipped handovers yield one popup; repeat talk, reload, scene change and legacy save yield none. Debug jumps keep core unarmed state with a fresh profile (no fake award). Unarmed art remains excluded and review-only.
3. Owner sound hooks, short shock/quiet hum, forest ambience and Kenney dialogue blip installed. Expanded smoke_owner_audio, smoke_dual_dagger_presentation and smoke_village_tutorial passed. First import attempt left incomplete audio resources; an explicit editor import retry exited0 and subsequent tests passed. Source/processed hashes/licences in presentation/audio/sources.json; exact event/file table in its README. Shock is1.85s with a200ms fade. Original ambience seam jump0.512 was crossfaded to a19.5s loop with0.0264 sample difference. Licence remains UNCONFIRMED for ElevenLabs owner recordings and UNKNOWN for the YouTube file; Kenney blip is CC0.
4. Deduplicated queued gate_changed saving when the immediate debug toggle already saved the same gate state, guarded missing/empty firefly regions, and removed tree_middle's unavailable exception in favor of the reachable248,88 pose. smoke_owner_audio(empty-region case) and smoke_forest_layered passed.

## Final validation

First full harness passed Python/import/core and every smoke except smoke_explore_scenes, which caught deferred-toggle-save timing. Fixed by preserving immediate debug saving and skipping the redundant queued save when profile.gate_open already matches. Focused exploration/forest smokes then passed. Final full harness passed Python suites, Godot import, all core tests and every smoke suite; log `art/build/arena_batch_full_regression_final.log` (ignored). Known Godot certificate-store warning persists.

## Owner decision during batch

The owner confirmed the layered maps will be official. Core/shared-data migration and old-map retirement handoff: `presentation/review/LAYERED_CHAPTER_MIGRATION.md`. Core routes/save compatibility still require Claude; no presentation override or premature asset deletion. Existing paintings remain references; arena remains active. No core/data/tools/harness or chapter-plan edits by Codex.

## Cannot judge

The dirt fill's visual fit, whether the yard feels roomy/fair, UI/hero visual quality, warning clarity during real play, perceived loop clicks, cue/music quality or mix, and whether training teaches well. Human playtest/listening and Claude cross-review remain necessary. Waveform/tests establish technical behavior only.

## Interface cross-review

PASS for the consumed first-sword and moved-yard contract: grants in ExploreCore._end_talk are flag-guarded, legacy migration is silent, actual combo snapshot values are now exposed, and the presentation receipt smoke covers finish/skip/repeat/reload/scene-change cases. No blocking interface finding. Human appearance, sound and feel remain unjudged; this does not replace Claude's review of the new presentation diff.

A concurrent edit to docs/architecture.md appeared during this batch and was left untouched and unstaged. docs/CHAPTER1_PLAN.md was never edited. Art validate/build/preview were run; runtime sprite-atlas PNG content did not change. Godot regenerated import metadata for large review contact sheets, retained with the generated outputs.
