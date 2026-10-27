# Codex batch (2026-10-27): four jobs in order

Branch `agent/game/chapter1-dev`. Read `AGENTS.md` first. Stay in `presentation/` and `art/`. Claude's core work for all of these is committed and pushed (latest `4b51cb8`). Preserve the owner's uncommitted `docs/CHAPTER1_PLAN.md` edit. Never merge to main. Run the focused smoke tests after each job and the full harness once at the end. Report what you ran, what passed, and what you could not judge (look, sound, feel are the owner's).

## Job 1: install the moved training yard (do this first)

`docs/CODEX_TASK_training_yard_move.md`. The core and shared data already moved the post (painted village feet (390,212), layered (380,180)). You install `docs/previews/village_ground_without_old_dummy.png` as the painted ground, remove the old painted `training_dummy` depth occluder (and its expectation in `tests/smoke_depth_occluders.gd`), draw the post at the new spot in the painted village, and retake the review captures. Until this is done the painted village looks wrong.

## Job 2: the receipt popup for the first sword

Core now emits `item_received` {scene, reward_id, kind, item_id, name, quantity, source} at the end of Tovan's first conversation (`docs/architecture.md` "The first sword and item receipts"). Hook it to `Explore.show_reward`, mapping `item_id` to an icon in presentation (`black_katana` to the existing sword icon). Show it only on the event, never at load. Test: Tovan's first conversation (finished and skipped) shows one popup; a second talk, a reload and a scene change show none; an older save that met Tovan shows none. Keep the current debug jumps working: a debug jump into a village with a fresh profile starts UNARMED now, so set the flag (`core.set_flag(&"received_first_sword")`) in jumps that should be armed, or tell the owner.

## Job 3: wire in the owner's sounds

`docs/CODEX_TASK_sounds.md`. The sounds are in `data/audio/owner_sounds/` (and the dialogue blip in `data/audio/cc0/`). Copy what you use into `presentation/audio/`, record them honestly in `presentation/audio/sources.json` and the README (not CC0; ElevenLabs licence and the YouTube file's source are unconfirmed, say so), and follow the event table. Check the 20 s ambience loop for a click at the seam. Do not play `electric_shock.mp3` for more than about 2 seconds without asking.

## Job 4: small review findings (only if time is left)

From Claude's reviews: `toggle_gate()` in `explore_scene.gd` saves twice (the queued `gate_changed` saves again); `ambient_fireflies.gd` indexes `regions[index % regions.size()]` and would divide by zero for a scene with no regions; `smoke_forest_layered.gd` still has the `tree_middle` "unavailable" exception (the pose is (248,88), see `docs/CODEX_TASK_forest_layered.md` "Final capture for the middle tree").

## Not in this batch

- Installing the unarmed hero art. `art/reference/hero_unarmed_v1/` is review-only until the owner approves it; the core already exposes `snapshot.armed`, so when the owner approves, a later task swaps the art by that flag.
- Switching the normal chapter routes to the layered scenes (the owner decides after playtesting).
