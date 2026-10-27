# Codex task: finish the layered-map migration (2026-10-27)

Claude switched the core and shared data (see STATUS). `SceneDefs.START_SCENE` is `village_layered`; the layered exits lead to each other (village_layered -> forest_layered -> glade_layered -> arena and back); `SaveProfile.from_dict` migrates painted scene and checkpoint ids to their layered twins (`SceneDefs.migrate_legacy`). The painted village, forest and glade are still in `SceneDefs.IDS` and reachable by debug keys until you retire them.

## Needed in presentation/ and tests/ (yours)

1. `presentation/menu/title.gd:244`: NEW GAME hard-codes `&"village"`; use `SceneDefs.START_SCENE` and `SceneDefs.START_ENTRY`.
2. Four smokes still assume the painted route and fail now (full regression, everything else passes):
   - `smoke_title.gd`: NEW GAME expects `village`; the CONTINUE glade case saves `glade` and now gets `glade_layered` / `glade_layered_entrance`.
   - `smoke_explore_scenes.gd`: saved forest checkpoint is now `forest_layered` / `forest_layered_entrance`; CONTINUE uses the layered checkpoint position.
   - `smoke_layered_scenes.gd`: the east exit of village_layered now requests `forest_layered`.
   - `smoke_forest_layered.gd`: the forest's exits now lead to `village_layered` and `glade_layered`, so "walked through gate to glade exit" must expect the layered glade.
3. Retire the painted village, forest and glade rendering and assets once those pass. Keep the reference paintings and `presentation/common/depth_occluders.gd` (the arena uses it). Tell Claude when no painted id is used any more so Claude can remove them from `SceneDefs.IDS`, `VillageLayout`, `ForestLayout` and `GladeLayout`, and their tests.
4. Debug keys: decide the labels now that the layered maps are official.

Not judged: how the route plays; the owner should test New Game, Continue, the transitions, training and the sword handover.
