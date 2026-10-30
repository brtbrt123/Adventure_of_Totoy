# Plan: everything editable and viewable in the Godot editor (written 2026-10-30, for the next session)

Owner request: **convert all tiles, props, scenes (maps), animations, effects, UI, elements and components to Godot-native resources, so the owner can open, edit and view all of it in the editor.** UI was done piece by piece in the previous session; this plan covers the rest.

## Where we are (measured 2026-10-30)

| Area | State |
|---|---|
| **UI** (HUD strip, menus, dialogue, overlays, title, intro cutscene, boss/result panels) | Done as editable scenes: 34 `.tscn` files in `presentation/ui/`, `presentation/menu/`, `presentation/cutscene/`, `presentation/explore/`, `presentation/arena/` (every piece its own scene). Still code-drawn: the arena HUD rings and tooltip, the three weapon cut-ins (`black_form_cutin.gd`, `lightning_form_cutin.gd`, `reapers_coil_cutin.gd`, about 400 lines each, timed in code), selection brackets, the screen fade and flash outlines. Some nodes are positioned by scripts by design (hint above an NPC, chips, TAB reminder, title selection plate). |
| **Maps** (village, woodland, forest, Root Hollow, glade, arena) | **Not editable.** Data lives in `data/scenes/<id>_props.json` (outline, entries, exits, checkpoints, encounters, props) + `data/props/prop_defs.json` (76 prop types with colliders) + `presentation/common/prop_art.json`; `explore_scene.gd` and `props_layer.gd` draw everything with `draw_*` calls. |
| **Props** (76 types) | Drawn from the atlas by code, colliders as numbers in JSON. No prop scenes. |
| **Tiles** | `art/build/tileset.tres` exists (generated); the layered maps use one painted ground image each, so tiles matter mostly for the arena and tools. |
| **Characters, mobs, NPCs, boss** | Frames are chosen by code each tick (`presentation/arena/animation.gd`, `mob_view.gd`) and drawn from the atlas. **No `AnimatedSprite2D`, `AnimationPlayer`, `SpriteFrames` or `TileMap` is used anywhere.** |
| **Effects** (2143 fx frames, `hero_fx.gd` 1266 lines + `*_effects.gd`) | Plans built in code and drawn with `draw_texture_rect_region`. No effect scenes. |
| **Art pipeline** | 3130 text grids in `art/src` -> `art/build` (sprites.png/json atlas, per-sprite PNGs, tileset.tres). The Godot side only ever sees the atlas. |

## Target

1. **Maps are `.tscn` scenes** (`presentation/maps/<id>.tscn`) the owner opens in the editor: ground sprite, a `Polygon2D` walkable outline, `Marker2D` entries and checkpoints, exit `Area2D` rectangles, encounter nodes with mob spawn markers (type chosen in the Inspector), NPC and object markers, a y-sorted `Props` node of prop instances, light sockets and firefly regions.
2. **Props are `PackedScene`s** (`presentation/props/<type>.tscn`): `Sprite2D` at its feet anchor, shadow mask, depth occluder polygon, collision circles as visible `CollisionShape2D`s (editor only), two-state props (gate, pedestal, root-knot barrier) as one scene with two states.
3. **Characters, mobs, NPCs, boss** are scenes with `AnimatedSprite2D` + a `SpriteFrames` resource per set (frame order and durations editable); code only picks the animation name from the core state (the mapping stays in `animation.gd`/`mob_view.gd`, the frame data moves into the resources).
4. **Effects are scenes** (`presentation/effects/<name>.tscn`, `AnimatedSprite2D` or `AnimationPlayer`) spawned from the core events by name; `hero_fx.gd` keeps only the event-to-scene mapping and the spawn rules.
5. **Cut-ins** become scenes with an `AnimationPlayer` timeline; the core still freezes while they play.
6. **A library scene** (`presentation/library/library.tscn`, or one gallery scene per category) that shows everything at once: all props, all characters and their animations (click to play), all effects (click to spawn), all UI pieces, all maps. Open it and you see the whole game's assets.
7. **The art pipeline keeps working**: `build_art.py` additionally writes the Godot resources (per-sprite textures, `SpriteFrames`, prop scenes' textures), so new art lands in the editor automatically.

## The one hard rule: the core stays deterministic and headless

`core/` reads plain data, never nodes. So the maps need a **baker**: a headless Godot script (`tools/godot/bake_maps.gd`, run like the other test scripts) that reads each `presentation/maps/<id>.tscn` and **writes `data/scenes/<id>_props.json`** (+ the collider part of the prop definitions) exactly as the core reads it today. The first thing to prove, before any map is edited by hand: **converting each current JSON to a `.tscn` and baking it back gives byte-identical JSON** (a round-trip test, one per map), so nothing in the game changes. After that the `.tscn` is the source of truth and the JSON becomes a build output.

## Phases (each one ends green and pushed; the owner reviews in the editor after each)

0. **Decisions and inventory** (below) and a scratch spike: one prop and one map round-tripped.
1. **Props to scenes** + generator (`tools/godot/generate_prop_scenes.gd`) + a props gallery. Renderer draws props by instancing scenes (y-sort) instead of `props_layer.gd`; shadows and occluders keep their look (capture-compare against today's captures).
2. **Maps to scenes** with the baker and the round-trip tests; renderer loads the map scene; delete the duplicated drawing paths only after captures match.
3. **Characters, mobs, NPCs, boss to `SpriteFrames`/`AnimatedSprite2D`**, generated from `sprites.json` and the animation tables; characters gallery with every animation playable.
4. **Effects to scenes**: group the 2143 fx frames into effects (hit, parry, dash, aspects, lightning, scythe, ward/echo/sprint, mobs), one scene each, effects gallery; `hero_fx.gd` shrinks to the spawner.
5. **UI leftovers and cut-ins**: arena rings and tooltip, selection brackets, the three cut-ins as timeline scenes; UI gallery.
6. **Pipeline and docs**: `build_art.py` emits the resources, AGENTS.md/architecture.md/HARNESS.md updated, the library scene, a "how to edit X in Godot" guide for the owner, full harness green.

## Decisions made by the owner (2026-10-30)

1. **Maps:** the `.tscn` is the source of truth, the baker writes the JSON the core reads. **Yes.**
2. **Art source:** the text-grid pipeline stays, `build_art.py` also writes the Godot resources. **Yes.**
3. **Order:** props, maps, characters/mobs/NPCs/boss, effects, UI leftovers and cut-ins, pipeline and docs (the order above). **Yes.**
4. **Who does it: option B, the split stays.**
   - **Claude** (`tools/`, `core/`, `data/`, `harness/`, `docs/architecture.md`): the generators (`tools/godot/generate_prop_scenes.gd`, the SpriteFrames and effect-scene generators), the map baker (`tools/godot/bake_maps.gd`), the JSON-to-`.tscn` converters, the round-trip tests (current JSON -> scene -> baked JSON must be identical), the `build_art.py` additions that write Godot resources, and any `core/` or `data/` change. Claude does not edit `presentation/` or `art/` assets by hand in this migration.
   - **Codex** (`presentation/`, `art/`, UI, effects, presentation tests): takes the generated scenes and resources into the renderer (instance prop and map scenes instead of `props_layer.gd` and `draw_*` calls, play SpriteFrames by animation name, spawn effect scenes from events), builds the galleries and the library scene, keeps captures matching today's look, and ports the smoke tests that inspect plans and arrays.
   - Each phase is a hand-off: Claude pushes the generator, its output and the round-trip test, then writes the phase's Codex task note in `docs/` (what to wire, what must look identical); Codex wires it and reports; Claude cross-reviews the interface. Nothing merges to main.

## Decisions that were open (answered above)

1. **Source of truth for maps:** `.tscn` + baker (recommended) vs keeping the JSON as the source and only generating read-only `.tscn` for viewing. Recommended because "edit in Godot" is the goal.
2. **Art source:** keep the text-grid pipeline and generate Godot resources from it (recommended: nothing in the art workflow changes), or move to PNG-first.
3. **Order:** the plan above (props, maps, characters, effects, UI) or another order (for example maps first).
4. **Who does it:** this touches `presentation/` and `art/` (Codex's folders) as well as `tools/` and a baker (Claude's). Either the owner lifts the split for the migration and tells Codex to review, or Claude builds the generators and baker (`tools/`, `core/` tests) and Codex converts the presentation side. Say it explicitly; the previous session crossed the split on request and Codex has to review those diffs (see `docs/STATUS.md`).

## Risks

- Size: thousands of generated files and large `.tscn`/`.tres` diffs; generate deterministically so reruns are clean, and keep generated files under clear folders.
- Pixel exactness: nearest filtering, integer positions, same y-sort and shadow rules as today; every phase compares captures against the current ones.
- Concurrency: Codex edits the same presentation files; announce the migration, agree on folders, avoid merging old and new drawing paths for long.
- Tests: many smoke tests inspect plans and arrays (`ward_echo_front_plan`, `lantern_drawables`, `skill_effect`, ...); keep those APIs or port the tests together with each phase.
- `.tscn` merge conflicts when two sessions edit one map: one owner per map at a time.

## Starting prompt for the next session

> Read docs/GODOT_EDITABLE_PLAN.md and docs/STATUS.md first. Start phase 0: answer the four decisions with me, then build the spike (one prop scene and one map round-tripped through the baker with identical JSON). Report what you ran and what you could not verify. Do not merge to main.

## Where things stand at the end of 2026-10-30 (read this before the migration)

**Pushed on `agent/codex/progression`, nothing merged to main.** All tests green at the last full run (Python 85, core 515, every smoke that can run without a window).

- **Chapter 1 route is complete and playable:** village -> woodland -> forest -> **Root Hollow** -> glade -> arena, with the Hollow's village shortcut. Overview image: `art/reference/chapter1_map_overview.png`.
- **Root Hollow:** Claude registered the real props and colliders (`data/props/prop_defs_root_hollow.json`) and a flag-keyed barrier state (`"when": "flag:cleared_hollow_center"`); Codex added lighting, shadows and depth checks (`60d9729a`). The owner still has to judge the look in play.
- **Done this session:** every Aspect and the three weapon actives on the road (multi-target Lightning Form and Reaper's Coil, `core/explore_skills.gd`), shared hero effects (`presentation/common/hero_fx.gd`), forest mobs, the Thornback Stag, Root Hollow, UI as scenes (34 `.tscn`), the intro cutscene as a scene.
- **Open gameplay items (not part of the migration):** Glowmoth (art only, no core behaviour), Edda's binding scene and the Stag's freed pose, the Colossus entrance cutscene, the beacon ending on the restored arena ground (`art/reference/beacon_epilogue/`, not wired), credits, balance and a full playtest. Damage numbers against mobs, the Stag and the multi-target falloff are first guesses.
- **Owner's uncommitted scene edits** (edited in the Godot editor, not on the branch): `presentation/cutscene/intro.tscn`, `presentation/ui/dialogue_box.tscn`, `presentation/ui/explore_overlay.tscn`, `presentation/ui/pieces/hud/aspect_socket.tscn`, `presentation/ui/pieces/overlay/scene_ribbon.tscn`, `presentation/ui/welcome_card.tscn`. Ask before committing them; scripts must keep honouring those layouts (the intro, the toast ribbon and the reward card were fixed so they do; the pieces the game positions by design are listed in the answer given on 2026-10-30: the `E` hint, fight chips, TAB reminder, locked message, title selection plate).
- **Shared working copy:** Claude and Codex edit the same folder. A `build_art.py` run by one side can briefly delete files under `art/build/sprites/` while the other runs tests (it caused false Python failures once): do not run the Python tests while the other agent builds art. `docs/STATUS.md`, `docs/INDEX.md` and `docs/architecture.md` often carry the other agent's uncommitted edits: commit only your own hunk.
- **Role split stays** (owner decision 4B): Claude does generators, baker, round-trip tests, core/data; Codex wires presentation. Cross-reviews are in `art/reference/root_hollow_v1/CROSS_REVIEW.md` style.


## Progress (Claude, 2026-10-30)

- **Phase 0 done (spike).** Design: Python generators write the `.tscn` text (deterministic, keeps `22` vs `6.0` number spelling, keeps editor values), a headless Godot baker (`tools/godot/bake_lib.gd`, `bake_props.gd`, `bake_maps.gd`) reads the scenes through `PackedScene` and writes the JSON. Result: all five `data/scenes/*_props.json` come back **byte for byte** from their generated scenes; the three `prop_defs*.json` come back value for value (whole numbers return as integers). `presentation/maps/glade_layered.tscn` is the spike map (the other four: `python tools/godot/generate_map_scenes.py`, phase 2).
- **Phase 1 Claude side done.** `presentation/props/<type>.tscn` for all **100** types (the main catalogue has 76, woodland and Root Hollow add 24), generator `tools/godot/generate_prop_scenes.py`, round-trip tests in `tests/test_godot_scenes.py` (7). Codex wiring and the props gallery: `docs/CODEX_TASK_prop_scenes.md`.
- Rule kept: generators never overwrite a position, offset, size or radius found in an existing scene (`--reset` is the only way to drop editor values); tested.
- Not verified: how the scenes look in the editor (no window in this session), and that the renderer output stays pixel-identical (that is the wiring step).
