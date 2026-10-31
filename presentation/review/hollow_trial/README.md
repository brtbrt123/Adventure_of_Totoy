# Hollow Trial — scene and gameplay presentation

2026-10-31. Branch agent/codex/progression; no main merge. Owner approved the ground and20-prop sheet, then requested scene construction. Claude registered the22 types/32 placements during this work, including the newer owner decision that the chest sits on top of the altar.

Open presentation/maps/hollow_trial_layered.tscn in Godot. The512x352 approved ground is byte-identical. The map has32 separate y-sorted placements, editable prop/light-marker positions,20 approved designs and2 smaller derived tree variants. The bottom trees are45% nearest-neighbour copies so their canopies clear the fight floor and all spawn points. The lower ferns also clear the fight floor. The originals are unchanged.

The chest's approved pixels are preserved at their original coordinates in a40x64 canvas:24 transparent rows below the original40x40 image raise it onto the altar. Anchor20,64; world feet256,181 put it one row in front of the altar. Both states have identical canvas/anchor and no separate collider. The same altar E interaction starts the trial and opens the chest after winning. A flush flagstone/rune course decorates the altar base without adding any collision or damage geometry.

## Runtime wiring

The shared Explore renderer now draws the registered approved art, preserving its existing actor/prop feet sort. Root Hollow night exposure, eight teal rune-rock lights, lit-altar light, source-silhouette moon/local casts, contact shadows and rim-only fireflies are active. There are16 light entries normally and18 with the lit altar, below32. Each sprite's actual alpha is the shadow mask; mirrored casts retain the world light direction, without adding44 large mask textures to the nearly-full atlas.

Core trial/flag facts select dark/lit altar, closed/open chest and open/sealed entry. Existing gold/red combat warnings remain unchanged. Core trial events drive spawn-warning marks until arrive_tick, actual-arrival pulses, activation/clear pulses, wave/complete toasts and three altar progress segments. No mob, flag, hit area, wave timer or reward is invented in presentation. Existing aspect-bind, lesson-complete and root-opening recordings are reused quietly; custom trial audio remains future polish.

The authoring scene also exposes preview_lit, preview_chest_open and preview_sealed, with snapshot-driven state/tick support. These controls are visual only; collider nodes have physics layers/masks0. The shared Explore renderer continues to use core collision data, not these editor nodes. No duplicate scene layer is overlaid over gameplay.

## Tests actually run

- validate_art.py, build_art.py and preview_art.py completed; atlas1024x8136 remains below8192,18 contact pages regenerated.
- audit_scene.py passes: approved ground SHA,22 exact atlas RGBA/anchor matches,32 placements, generated map SHA. Chest re-canvasing changes transparent support height only.
- Godot4.7.2 import and check_scene.gd pass: assets, baker anchor/circle comparisons, feet sorting, no rim sprite rectangle over the fight floor, no tree rectangle over a spawn point, entry/object/spawn metadata, lighting counts, seal/altar/chest state swaps and stable shader reuse.
- check_gameplay.gd passes headless and OpenGL: loads the real registered room, walks from entry to altar using input, starts with E, observes warned spawns and the Warden/Boar wave, completes three waves, confirms win/altar/entry states, then opens the actual chest from the same stand.
- The automated gameplay test restores hero HP and delivers lethal hits through core's normal hit function to accelerate clears. It never fabricates snapshots, wave states, mob spawns, win flags or rewards. It is not a manual playthrough or balance test.
- Both full harness runs passed Python/import/core/all headless smokes. The final gameplay-wiring run is art/reference/hollow_trial_v1/runtime_harness.log (ends all test suites passed). The last HUD/ambience follow-up also passed the core-driven gameplay capture and the Explore/CONTINUE regression with normal isolated-save access. Its first sandboxed save/CONTINUE attempt failed on denied filesystem access; no save logic was changed.

Reproduce focused checks with Godot console --headless --path . --script res://presentation/review/hollow_trial/check_scene.gd and check_gameplay.gd. Use TOTOY_SAVE_PATH=user://hollow_trial_scene_check.json for gameplay tests. Windowed check_gameplay.gd saves game_*.png; capture_scene.gd saves full-map visual-state previews. Isolated test saves only, never the owner's save.

## Captures and remaining limits

idle_scene_2x.png and *_VISUAL_STATE_2x.png are full-map authoring renders. game_*.png are actual gameplay renderer captures with real core state. contrast_actual_wave2_2x.png renders the actual wave2 actor positions/poses through the full-room authoring view, without the HUD and actor-FX pass, to inspect full bodies against the terrain. These categories are not interchangeable.

Claude's registered non-solid chest definitions still have h40/anchor20,40. The rendered source is now h64/anchor20,64 as requested. Presentation reads actual source-frame anchors for decorative canvases and does not alter core feet, solidity or colliders. Please resync those four catalogue fields; scene_registration.json.catalogue_differences lists them. All other registered definitions/positions match the authored scene. Handoff: art/reference/hollow_trial_v1/CLAUDE_REGISTRATION_HANDOFF.md and baked_scene_proposal.json.

The chest still gives the documented3-herb placeholder until the owner chooses the Aspect. No new core/data/tools/harness or owner UI-scene edits were made. Existing unrelated dirty work remains untouched. Full trial sound design and extra victory-beam polish are not claimed. Claude cross-review is pending; its last authorized CLI attempt failed due expired OAuth, so no reviewer PASS is claimed.

Cannot judge art appeal, fun/balance, crowded-wave warning readability, final audio or manual route/walk-behind feel. Automated checks do not establish these. The existing single static OpenGL texture leak (5460 bytes) remains at capture shutdown; no capture script errors. Focused sandbox runs emit certificate/log permission errors; the full harness runs with ordinary test-save/log access. Graphify remains unavailable (No module named graphify). Godot's incidental project.godot cursor-setting reorder was undone; no project setting changed.
