# Layered village presentation integration (2026-10-27)

Runtime grounds (Claude: update only the shared scene ground strings when convenient):

- village_layered: `res://presentation/village/village_layered_ground.png` (571x336).
- glade_layered: `res://presentation/forest/glade_layered_ground.png` (560x336).

The painted grounds are preserved. Explore uses these runtime paths until the shared data strings are updated. Source references remain as provenance; gameplay no longer loads a ground from art/reference. No core/data/tools/harness files were edited.

## Import geometry

All 31 cut-outs are copied pixel-exactly into grids with top/right padding only. There is no bottom padding and no rescaling. The forge already includes anvil and bench, so neither is imported separately. All pixels remain hard alpha and nonreserved Totoy36 colours.

Shared anchors are in the original unpadded coordinate system. The text-grid parser accepts integer anchors only, while several data anchors use x.5. Header anchors therefore round x to the nearest integer and add top padding to y. The exact shared anchors and padded anchors are recorded in import_manifest.json. Rendering crops the padding using presentation/common/prop_art.json, uses the unchanged shared anchor, then snaps the final draw origin to whole pixels. Max unavoidable horizontal snap is 0.5 px; no accumulating offset or collider movement. If exact half-pixel headers are desired, Claude needs to extend tools/art/artlib.py and the atlas format deliberately.

| Type | Cut-out | Padded | Shared anchor | Header anchor | Top pad |
|---|---|---|---|---|---|
| village_dummy | [28, 38] | [32, 40] | [13.5, 38] | [14, 40] | 2 |
| village_shelf | [33, 34] | [40, 40] | [15.5, 34] | [16, 40] | 6 |
| village_barrel_a | [23, 28] | [24, 32] | [11.5, 28] | [12, 32] | 4 |
| village_barrel_b | [23, 28] | [24, 32] | [11.5, 28] | [12, 32] | 4 |
| village_barrel_c | [24, 27] | [24, 32] | [12.5, 27] | [13, 32] | 5 |
| village_barrel_tipped | [35, 28] | [40, 32] | [11.5, 28] | [12, 32] | 4 |
| village_crate_a | [31, 31] | [32, 32] | [13.5, 31] | [14, 32] | 1 |
| village_crate_b | [30, 31] | [32, 32] | [13.0, 31] | [13, 32] | 1 |
| village_pile | [49, 32] | [56, 32] | [26.0, 32] | [26, 32] | 0 |
| village_rocks | [42, 30] | [48, 32] | [23.0, 30] | [23, 32] | 2 |
| village_stump | [39, 28] | [40, 32] | [21.5, 28] | [22, 32] | 4 |
| village_slab | [40, 25] | [40, 32] | [27.5, 25] | [28, 32] | 7 |
| village_slab_tilted | [35, 28] | [40, 32] | [20.5, 28] | [21, 32] | 4 |
| village_rubble | [40, 21] | [40, 24] | [23.0, 21] | [23, 24] | 3 |
| village_chest | [33, 28] | [40, 32] | [18.0, 28] | [18, 32] | 4 |
| village_bush_1 | [36, 30] | [40, 32] | [16.5, 30] | [17, 32] | 2 |
| village_bush_2 | [39, 30] | [40, 32] | [19.0, 30] | [19, 32] | 2 |
| village_fern_1 | [46, 31] | [48, 32] | [22.5, 31] | [23, 32] | 1 |
| village_fern_2 | [39, 25] | [40, 32] | [16.5, 25] | [17, 32] | 7 |
| village_mushrooms | [30, 23] | [32, 24] | [15.0, 23] | [15, 24] | 1 |
| village_bucket | [20, 26] | [24, 32] | [10.0, 26] | [10, 32] | 6 |
| village_rope | [33, 19] | [40, 24] | [19.0, 19] | [19, 24] | 5 |
| village_mushrooms_small | [25, 21] | [32, 24] | [11.0, 21] | [11, 24] | 3 |
| village_gate | [99, 99] | [104, 104] | [15.5, 99] | [16, 104] | 5 |
| village_cottage | [125, 109] | [128, 112] | [63.5, 109] | [64, 112] | 3 |
| village_east_tree | [112, 125] | [112, 128] | [55.0, 125] | [55, 128] | 3 |
| village_forge | [87, 87] | [88, 88] | [35.0, 87] | [35, 88] | 1 |
| village_big_tree | [126, 116] | [128, 120] | [58.0, 116] | [58, 120] | 4 |
| village_shrine | [60, 86] | [64, 88] | [31.0, 86] | [31, 88] | 2 |
| village_standing_stone | [49, 72] | [56, 72] | [24.5, 72] | [25, 72] | 0 |
| village_lamp_post | [40, 84] | [40, 88] | [7.5, 84] | [8, 88] | 4 |

## Drawing and checks

Explore gets every prop from PropScene.placements with the authoritative SceneDefs.layered_data and shared defs. NPCs and E interactions still come from ExploreSnapshot. Layered props do not add a second chest/door/dummy sprite. Actor and prop shadows are in a floor pass, then the sprites are sorted. Village tint and shadow strength match the painted village.

Debug: **5 / F7** layered village, **6 / F8** layered glade. Existing debug keys are retained. The main chapter route remains controlled by core scene data; this change does not switch the forest connections.

The glade log is rendered in 4-pixel-wide strips, each sorted at its own lowest opaque row, all at their original positions. This changes drawing only, not collider data or the approved sprite. Only one shadow is drawn for the whole log. The duplicate glade placement fixture is removed; review scripts now read shared data.

Latest review: `review/path_v2/depth_contact.png` and ten separate `*_behind.png` / `*_front.png` files. These are windowed captures from the real exploration scene; the test bot actually walks through core collision to each spot. Actual coordinates are in review/path_v2/capture_positions.json. Earlier review files are superseded. NPC interaction is the existing placeholder bubble, not a new dialogue system.

Validation: validate/build/preview; smoke_layered_scenes (load, 34 props, six NPCs, five front/behind walks, Mira, three interaction spots, east exit/fade, debug jumps, sloped log); smoke_props_layer (mirroring, ties, padding, sloped edge); test_village_sprite_import (pixel/anchor geometry and palette grounds). Full background regression passed Python, import, core and all smoke suites, and passed again after the shadow revision. The subsequent ground-only path edit passed palette/dimension checks, Godot import and the full windowed layered walking/interaction capture. Godot logs the existing system certificate-store warning in this sandbox; no script errors are accepted.

## Cross-review / remaining ownership

Claude village core/data review: PASS for the supplied interface and exercised village interactions, collider approaches and scene transition. No new blocking finding identified in core/prop_scene.gd, core/scene_defs.gd or data/scenes/village_layered_props.json. The prepared source-ground paths are a known handoff item (paths above), not an unreported runtime dependency. Core test results remain part of the full regression.

Cannot judge: human art approval of the converted game view, relative plant scale, collision feel in manual play, Stag fight fun or balance. Cross-review of these presentation changes still belongs to Claude. The human owns every merge.

## Human feedback: path fit and shadows

The human preferred a narrower path over a larger gate. The gate, anchors, placements and colliders stay unchanged. Built-in ImageGen edited the floor using the runtime floor and gate placement capture as references: narrow dirt neck through the opening (about x64..88, y100..140), mossy shoulders, a tapered join into the main road. Original edit saved as village_ground_gate_path_v2.png; normalized runtime output remains at the village ground path above. The original source is preserved.

Every one of the 51 glade/village prop types now has a short contact-shadow contour derived from its visible lower edge in prop_art.json. Gate feet remain disconnected across the passage; shadows mirror with sprites, and the diagonal log casts only once. All runtime actor shadows (hero/NPC/boss, shared routine) are smaller, lighter and closer to the feet. Contact shadow core alpha is at most .24, outer fringe at most .10. Tests verify separate gate feet, no shadow in the opening, disjoint core/fringe and shadows confined close to the base. The new contact shadows replace generic prop ellipses in layered scenes; shadows painted into the old flat grounds remain part of those paintings. No core/data changes are needed for this visual revision.

## Separate cast masks and upper light

The next human request added independent object-shaped shadow sprites and light from above. See ../shadow_layers/README.md and manifest.json: 51 unchanged object cut-outs have 102 separate normal/mirrored cast masks (fx_shadow_* text grids and PNGs), with a fixed upper-left key. The layered Explore renderer now draws those masks beneath the existing contact layer; mirrored objects keep the light direction. Actual hero/NPC animation frames also cast down-right. overhead_light.gdshader adds restrained warm village/cool glade light in world space, with whole-pixel coordinates and banded intensity. 7/F9 toggles the light; 5/F7 and 6/F8 remain the two layered review scenes. The latest walking captures are review/light_v3/; same-position off/on and separate-layer sheets are under ../shadow_layers/. No core/data changes.

## Final selected night look

The human rejected the later high-contrast moonlight experiment and chose the earlier soft moonlit village with warm lamps. The positive (+0.30,+0.25) projection, restrained cool exposure and subtle cast opacity are restored. Five measured fixtures give ten halo/pool shader entries; no local light is left behind when entering the glade. Canonical image: ../shadow_layers/night_selected_on.png; walking images: review/night_selected/. See ../shadow_layers/README.md for final parameters and verification; earlier lighting notes above are historical.
