# Claude handoff: Hollow Trial scene registration

Owner approved ground and prop sheet and asked Codex to build the scene. Visual source: `presentation/maps/hollow_trial_layered.tscn`. Report/captures: `presentation/review/hollow_trial/README.md`. Keep all unrelated dirty work. No merge to main.

## Ready now

`scene_registration.json` has22 type definitions (20 approved originals,2 small tree derivatives), exact padded art sizes/anchors, suggested circle colliders, all32 placements, state pairs, light sockets and art hashes. The22 prop scenes are in `presentation/props/hollow_trial_*.tscn`; editor collider circles and anchors bake back to that proposal in the scene smoke. Art source grids, generated atlas/native PNGs and approved ground path are installed. Altar64x48 anchor32,48 with44x20 proposed base; chest40x40 anchor20,40 with24x12 base. State pairs share canvas/anchor. Root entry barrier is the existing open/closed pair.

`baked_scene_proposal.json` is produced by the existing baker's pure `bake_map` function, written **only under art/reference**. It retains the512x352 outline, entry/exit, checkpoint, object/stand markers, managed encounter and your current trial configuration. It replaces visual placeholders with the approved art and adds four non-solid root details. It is not automatically written into data or registered by Codex.

Differences from placeholder positions: lower ferns use y312 (rather than282), so their sprite tops clear the fight floor; bottom trees keep their fixed layout slots but use45% derived art so their canopies also clear y276. Roots have non-solid rim placements. Every rim sprite rectangle now stays outside [112,92,288,184], verified by `check_scene.gd`; only the central altar/chest are exceptions by design.

## Claude-owned work

1. Register the new definitions in an appropriate data/props catalogue and expose it through PropScene.load_defs; include it in baker/generator catalogue lists. Review/tune proposed circle geometry against the actual native sprite bases. The circles are suggestions, not physical playtest approval.
2. Adopt/bake the authored map placements into `data/scenes/hollow_trial_layered_props.json`, preserving any newer core trial/wave/reward changes made since this proposal. Validate current entry/stand/spawn clearance against the new circles and add the normal tests. The shrine/chest interact points stay fixed.
3. Preserve the authored map's root script, FloorEffects/Overlay passes, prop/light metadata and authoring camera. Do not overwrite it with `generate_map_scenes.py --reset`; current generator round-trip tests use scratch outputs and are safe.
4. Tell Codex when definitions/placements are registered so the shared gameplay renderer can consume these exact visuals and keep actor/prop y-sort. The old renderer is deliberately still authoritative while its data names placeholders. Do not treat the authoring scene's layer0 collider nodes as a second collision system.

No core/data/tools/harness files were edited by Codex. Existing dirty trial/core work is preserved. Additional visual scene integration, wave FX/UI/audio, real gameplay captures and full-route playtest remain after this registration.
