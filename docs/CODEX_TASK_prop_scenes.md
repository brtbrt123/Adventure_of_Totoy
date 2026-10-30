# Codex task: wire the prop scenes into the renderer (phase 1 of the Godot-editable plan, 2026-10-30)

Plan: `docs/GODOT_EDITABLE_PLAN.md`. Claude built the generator, the baker and the round-trip tests; **you wire the generated scenes into the renderer and build the props gallery.** Nothing in `core/` or `data/` changes for this task. Do not hand-edit `presentation/props/*.tscn` with scripts of your own: the owner edits them in Godot, and `python tools/godot/generate_prop_scenes.py` refreshes them (it keeps every position, offset and radius already in a scene).

## What exists

- **`presentation/props/<type>.tscn`, 100 scenes**: every prop type of the three catalogues (`prop_defs.json` 76 + woodland + Root Hollow). The root `Node2D` stands on the prop's FEET (the anchor, the middle of its base). Children:
  - `Sprite` (`Sprite2D`, `centered = false`, `offset = -anchor`): the art, an `AtlasTexture` region of `art/build/sprites/<type>.png` where `prop_art.json` has a `trim`.
  - `CastShadow`, `CastShadowFlipped` (`Sprite2D`, **hidden**, black modulate): the moon cast-shadow masks from `prop_art.json`; offset = -(atlas ax, ay) of the mask frame, so with the root on the feet they land where `PropsLayer.draw_shadow` puts them. They are hidden because the renderer draws them in its own shadow pass (black vertex colour tag); decide how the gallery shows them.
  - `Colliders` (`StaticBody2D`, no layers: it only displays the circles) with `Circle1..N` (`CollisionShape2D`, `CircleShape2D`): the same circles as `colliders` in the JSON. **The core does not read these**; it still reads `data/props/prop_defs*.json` (see "Baking").
  - `Light1..` (`Marker2D`, metadata `socket`): the light sockets of `local_lights.json`, position = socket pixel - anchor.
  - Root metadata: `w`, `h`, `base_width`, `solid`, `image`, `note`, `locked`, `state_pair`, `src_bbox`, `contact_shadow` (the contact-shadow rows of `prop_art.json`), `sort_strips` (log strips that sort separately), `flip_offset`.
- **`presentation/maps/glade_layered.tscn`**: the phase 0 spike, the glade as a scene (ground, walkable outline, entry, exits, checkpoint, Stag room, encounter with its mob marker, 21 props as instances of the prop scenes). It is **not used by the game yet** (phase 2).
- `tools/godot/`: `generate_prop_scenes.py`, `generate_map_scenes.py`, `bake_props.gd`, `bake_maps.gd`, `bake_lib.gd`, `tscn.py`; test `tests/test_godot_scenes.py`.

## What to do

1. **Draw props by instancing the scenes** in the explore scene (and anywhere `PropsLayer.drawables/draw` is used for props): one instance per placement from `PropScene.placements(...)` (type already resolved for states), `position = feet`, `y_sort_enabled` on the container so props and actors sort by feet.y as today (actors stand in front of a prop on a tie; `sort_strips` props split into strips with their own `at.y`, see `PropsLayer.drawables`).
2. **Flip.** Today a flipped prop mirrors around the feet x: `origin.x = feet.x - (size.x - anchor.x)`. In the scene: set `scale.x = -1` on the root, **or** (to keep the pixel rounding) set `Sprite.flip_h = true` and `Sprite.offset = root.get_meta("flip_offset")`. Colliders of a flipped prop mirror dx, the baker and the core already do that; if you scale the root, the displayed circles mirror too.
3. **Pixel exactness.** `PropsLayer` draws at `feet.round() - anchor`, then rounds the origin; half-pixel anchors (13.5) therefore land on whole pixels. A `Sprite2D` at `offset = -13.5` would sit on a half pixel. Round the sprite's global position in the instancer, or set `snap_2d_transforms_to_pixel`, and compare captures with today's.
4. **Shadows and lighting stay as they are**: contact shadow rows come from `contact_shadow` metadata, cast shadows from the two hidden sprites, light sockets from `Light*`, depth occluders stay per scene (`depth_occluders.json`, not per prop). Read them from the scene instead of `prop_art.json` / `local_lights.json` if that is simpler, but the JSON files stay as the generator's input for now. Capture-compare against the current captures (Root Hollow final, glade, village) before deleting the drawing path.
5. **State pairs** (`forest_gate_closed/open`, `forest_pedestal/lit`, `root_hollow_barrier_*`): the same two scenes as today; swap the instance when `PropScene.type_of` says so. They share size and anchor by validation.
6. **Props gallery** (`presentation/library/props_gallery.tscn` or similar): every `presentation/props/*.tscn` in a grid with its name, collider circles visible, and a toggle for shadows. Names and groups (village, forest, woodland, glade, root_hollow) come from the type prefix.
7. **Keep the plan/array APIs** your smoke tests use (`ward_echo_front_plan`, `lantern_drawables`, `PropsLayer.drawables`) until their tests are ported; port the tests together with the drawing change.

## Baking (so you know what the owner's edits do)

`godot --headless --path . --script res://tools/godot/bake_props.gd` writes `anchor`, `solid` and `colliders` of every type from its scene back into `data/props/prop_defs*.json` (only when a value changed; whole numbers are written as integers, `61.0` -> `61`, same value). Until the owner starts editing the scenes the JSON is still the source and the scenes are generated from it; the round trip is tested. If you change a collider or the art of a prop, do it in the JSON / `art/src` as before and run the generator; if the owner changed the scene, bake before regenerating.

## Must look identical

Same pixels as today on the village, woodland, forest, Root Hollow and glade captures: prop positions, sort order against actors, contact and cast shadows, light pools, mirrored props. Report anything that moves by a pixel.

## Run

```powershell
python tools/godot/generate_prop_scenes.py              # refresh (keeps editor values); --reset rebuilds from the JSON
python -m unittest tests.test_godot_scenes -v           # round trips (not while build_art.py runs)
```

Not judged by Claude: how it looks. The owner opens a prop scene in Godot and judges the sprite, the circles and the shadows.
