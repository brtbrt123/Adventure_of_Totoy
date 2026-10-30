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

## Decisions the owner must make first

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
