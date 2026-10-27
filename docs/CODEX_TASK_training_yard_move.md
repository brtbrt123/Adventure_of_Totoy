# Codex task: install the moved training yard (2026-10-27)

The owner accepted your proposed spot south of the forge. Claude moved the core and shared data (commit after `76168c5`): painted village post feet **(390,212)**, stand (390,226) (`VillageLayout.TRAINING_DUMMY`, `SOLIDS_1X`); layered village post feet **(380,180)**, stand (380,196) (`data/scenes/village_layered_props.json`, both the `dummy` placement and the `training_dummy` object). The old colliders are gone. Both villages are tested: the post is solid where it stands, nothing invisible is left at the old spot, a 44 px ring and the 96 px yard are free (99 % reachable), routes arrival -> post -> forest exit work (`tests/core/test_training_yard.gd`).

**Until you do the art below, the PAINTED village shows the old post at the old spot with no collider there, and nothing at the new spot.** The layered village is already correct (its post is a prop, so it moved with the data).

## Your tasks (presentation/ and art/ only)

1. **Install the ground without the old post.** `docs/previews/village_ground_without_old_dummy.png` is the exact output of `python tools/art/make_village_ground_from_reference.py --erase-old-dummy` (571x336, palette-checked, differs from the current ground only in the rectangle x 312-344, y 113-157: the old post and its shadow replaced by forge-yard dirt, 2x2 blocks taken from the surrounding dirt symbols with a fixed seed). Copy it to `presentation/village/village_ground.png` (keep the `.import`), or ask for another fill if the dirt patch looks wrong to the owner; the owner has not seen it. The default generator output (no flag) is unchanged and still equals the old ground.
2. **Remove the painted post's depth occluder.** `presentation/common/depth_occluders.json`, id `training_dummy` (polygon around x 315-341, y 115-153), and the matching expectation in `tests/smoke_depth_occluders.gd` (`_order(scene, &"village", &"training_dummy", ...)`), otherwise the hero is hidden behind nothing.
3. **Draw the post in the painted village.** Draw `obj_dummy_1` (and `obj_dummy_hit_*` on `training_post_hit`, plus your wobble) as a y-sorted object with its feet at (390,212), like the chest, with the contact shadow the layered `village_dummy` has. Do not draw a second post in the layered village (it is already a prop).
4. **Check both villages by eye and by test.** `smoke_village_tutorial.gd` walks to the post by `object["stand"]`, so it should pass unchanged; re-take the review captures (`art/reference/training_yard_relocation_v1/` and the tutorial cards) at the new spot, the roomier yard with the gold and red warnings, and make sure the warning shapes (cone 44 px, circle 40 px) do not cover the nearby barrels or the road in a way that confuses the lesson.
5. **Update `art/reference/training_yard_relocation_v1/village_layered_proposal.json`'s note** to say it is now live data, or delete the fixture override in `tests/capture_village_polish.gd`.

## Do not

- Edit `core/` or `data/`. If the post's spot or the yard size needs another change, say so here.
- Move the painted post by editing the PNG by hand: the generator is the source (`tools/art/make_village_ground_from_reference.py`), so the ground stays reproducible.

## Claude notes

- Not judged by Claude: how the dirt patch looks, whether the new spot feels roomy, the road's feel with a solid post nearby.
- `docs/CHAPTER1_PLAN.md` still says (328,148) in S1 notes; that file has an unrelated uncommitted edit of the owner's, so it was not touched.
