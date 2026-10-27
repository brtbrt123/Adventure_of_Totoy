# Owner decision: layered maps are the official chapter maps

Confirmed by the owner on 2026-10-27: **"yes we will use the layared map"**, in reply to switching normal routes/saves to the layered village/forest/glade and then retiring the old playable maps. Keep original paintings as art references. The Colossus arena remains the existing arena; there is no replacement layered arena in this decision.

## Claude: core/shared-data migration required

Codex stays in presentation/art under the owner's batch instructions. The owner previously chose core tasks for Claude, so this file is the handoff; normal routes have NOT been silently switched by a presentation override.

1. Make `village_layered` the normal NEW GAME / START_SCENE entry. Connect village_layered -> forest_layered -> glade_layered -> arena and all return exits using shared scene data. Keep correct entries/checkpoints, forest puzzle/gate flags and transitions.
2. Migrate existing saves from painted village/forest/glade IDs and their checkpoints to the corresponding layered scene/default checkpoint. Use the new map's valid coordinates/entry; do not reuse painted coordinates or drop story flags, first sword, equipped Aspects, gate progress or boss records. Ensure legacy met_tovan saves migrate armed without replaying item_received.
3. Keep direct boss-fight mode armed. Decide debug key labels/aliases for official maps and update the core's known-scene/checkpoint tables, IDS/LAYERED collections and tests together.
4. Run walking/dashing routes, both gate states, NPC interactions, first sword/receipts, training, CONTINUE/new game and forest/glade/arena transitions. Test legacy saves before removing compatibility IDs.
5. After the above works, retire old playable village/forest/glade layouts and unused routes/tests; provide Codex the final list of painted presentation grounds/occluders/debug UI that can be removed safely. Keep original reference paintings. No automatic merge.

## Codex follow-up after core migration

Remove obsolete painted ground paths/rendering branches and the retired depth-occluder assets and fixtures after their references are gone. Update title/debug controls and capture the official route. Do not remove `presentation/common/depth_occluders.gd` wholesale: the arena still uses it. Do not install unarmed hero art without the owner's separate art approval; that was explicitly excluded from this batch.

## Current batch state

The painted-yard consistency repair was already completed before this new decision, keeping the current routes coherent while migration is pending. It does not commit us to maintaining painted maps afterward. Layered training feet are380,180; core/shared data already agree. First-sword receipt hook and owner audio are implemented in both scene variants. Fresh debug village visits currently retain the core's unarmed flag state; they do not fabricate a weapon reward. Until art approval, the display still uses the armed hero set as documented in the batch exclusions.
