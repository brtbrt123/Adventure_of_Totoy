# Claude handoff: Hollow Trial final art metadata resync

2026-10-31. Your registration commit ebfcbf8e is now consumed by the shared gameplay renderer. Codex's scene/lighting/props/FX/UI wiring passes the full harness and a core-driven trial test. No core/data/tools/harness edits were made by Codex; no main merge. Keep all other dirty work.

## Only remaining catalogue change

Both hollow_trial_chest_closed and hollow_trial_chest_open now have40x64 canvases and anchor20,64. The approved40x40 pixels are unchanged at y0;24 transparent rows below them put the chest on the altar. The catalogue still says h40/anchor20,40. Please change h to64 and anchor to[20,64] in BOTH catalogue entries. w remains40, base_width0, solidfalse and colliders[] remain unchanged. Feet remain256,181; the altar holds the physical body and the single altar stand256,204 handles both interactions.

scene_registration.json.catalogue_differences lists exactly those four field differences. The two prop scenes/text grids/atlas entries have the new canvas/anchor already. Presentation uses actual source-frame anchors for non-solid decorative canvases without changing core feet, solidity or collision shapes; rendering and interactions work before this bookkeeping resync.

## What is done

- Approved ground at presentation/forest/hollow_trial_layered_ground.png, unchanged SHA.22 source/atlas assets,32 registered placements, editable source scene presentation/maps/hollow_trial_layered.tscn.
- Registered placements agree with the authored scene. Bottom small trees clear the fight floor and every spawn point; rim ferns/roots stay outside the fight rectangle. Central altar/chest are the intentional exceptions.
- Seven light-socket families merged into presentation/common/local_lights.json. Root Hollow night exposure, eight rune-rock sources plus lit altar, source-alpha moon/local shadows, contact shadows and rim fireflies in gameplay.
- Flush flagstone/rune ring, chest-on-altar states, entry seal from snapshot.trial.sealed, warning marks from trial_spawn_warned until arrive_tick, arrival marks from actual mob_alerted, core-driven wave/complete banners, three progress segments and alive/incoming objective chip. Quiet existing audio is reused; custom trial sound design remains pending.
- Same E at the actual altar starts the core trial, then opens the real chest after winning. The configured reward remains your3-herb placeholder until the owner picks the Aspect.

## Checks and review

Report and captures: presentation/review/hollow_trial/README.md. check_scene.gd verifies art/anchor/circle/baker metadata, clear floor/spawns, states, y-sort and light budgets. check_gameplay.gd walks from entry with inputs, starts with E, observes actual warned spawns, uses HP restoration and lethal hits through core to accelerate all three waves, then opens the chest with E. It does not fabricate snapshots, waves, wins or rewards; not a manual balance test.

The full runtime harness passes. The final HUD/ambience follow-up also passes the gameplay run and normal-access Explore/CONTINUE regression. No review PASS from Claude is claimed; please cross-review the new presentation scripts/interface and source/atlas data. The last authorized Claude CLI review failed expired OAuth, so Codex did not retry network/account use here.

baked_scene_proposal.json is a read-only baker export under art/reference, not an automatic data write. If you use it, preserve your latest trial configuration/reward edits. Do not reset-regenerate the authored map over its custom view, FloorEffects/Overlay, metadata and authoring camera. build_scene.py refuses to overwrite map/prop scene edits that differ from its recorded generation hashes.
