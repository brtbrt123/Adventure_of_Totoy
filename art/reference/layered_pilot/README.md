# Layered Stag glade: review candidate (2026-10-27)

Current integration (2026-10-27): shared core/data and tuned colliders are now supplied by Claude. Explore renders the layered glade via debug 6/F8, loads the runtime ground in presentation/forest/glade_layered_ground.png, and reads only the authoritative shared placements. The old presentation/forest/glade_props.json fixture is removed. The sloping log now draws in narrow depth strips. See ../layered_village/INTEGRATION.md for validation and remaining ground-path handoff; the historical candidate notes below describe the original review stage.


Generated with the built-in ImageGen tool, using `art/reference/stag_glade_target.png`
and `presentation/forest/stag_glade_ground.png` as style references. The owner requested
generation of both the floor and the assets. The owner approved this art and its look on 2026-10-27. No gameplay scene uses it yet; shared collider/scene data is still pending.

## Prompt set

- Ground: empty ground only, landscape 5:3, same classic 16-bit 3/4 top-down pixel
  style as the references; olive grass, moss, warm brown dirt, cool teal atmosphere;
  large readable clearing with a faint worn oval; entrance bottom-left, exit top-right;
  dark flat forest-floor edges. No standing objects, trees, bushes, stones, pond,
  gateway, characters, UI, text or frame. Named Totoy grass and dirt ramps, no combat colours.
- Props: same reference style, camera and material ramps; pure #FF00FF background,
  isolated complete objects in a 5-column/4-row sheet. Five teal-rune standing stones;
  three mossy rocks, tree, stump; fallen log, lilac thorn bush, bush, fern, root arch;
  antler, small rocks, mushrooms, second fern, second bush. Wide gutters, no floor,
  cast shadows, outside glows, labels or characters. Original scale request: adult
  50 px per 837-wide sheet, stones 80 px, tree 150 px, arch 100 px, bushes 30 px.
  Generated relative heights varied; this is a review candidate, not proof of scale accuracy.

## Files and conversion

Original images: `glade_ground_only.png`, `glade_props_sheet.png` (1619x971 each).
Ground: BOX reduction to 560x336, Lab palette snap using the existing extractor's
`Snapper`; no reserved symbols. Output `glade_ground_totoy36.png` stays here for review.

Props: existing `tools/art/extract_props.py`, `--world-width 400` (uniform factor
400/1619; the first 560-wide extraction made stones too large next to the hero).
The five stones are 50–57 px high; the existing hero is about 34 px. Tree is 84 px,
arch 62 px. Bushes, thorns and mushrooms are relatively large; the owner judges scale.
Extraction order and names are recorded in `prop_defs_review.json`. Anchors rounded
to whole pixels at the bottom base line. Each grid in `art/src/glade_*.txt` is padded
with transparency to multiples of 8; padding does not move its anchor.

`presentation/forest/glade_props.json` is the proposed visual arrangement, using
the documented shared row fields `id/type/x/y/flip` plus review shadow radii.
It is a review fixture, not a second live source of collision data. Renderer:
`presentation/common/props_layer.gd`. Shadows are drawn in a ground pass; sprites
are tinted with the glade's (0.88, 0.95, 0.94) ambient and sorted with actors by feet.
At equal feet y the actor is drawn in front. The renderer accepts `PropScene.placements`.

## Review and checks

`tests/capture_layered_glade.gd` uses Godot's actual renderer and the existing hero
walk frames in an isolated SubViewport: full layout and 40 front/behind shots.
It advances a scripted walking pose horizontally on both sides of every prop.
This checks visual sorting, not collision-resolved walking in the gameplay core.
Run windowed; images are in `review/`. `depth_contact_1..4.png` collect all pairs.

`tests/smoke_props_layer.gd`: asymmetric mirrored anchors, depth order, equal-row
ties, culling and preserving caller arrays. `tests/test_layered_glade_art.py`:
palette, hard alpha, 20 registered props, atlas anchors and pixels, ground dimensions.
Validate/build/preview were run in that order; generated art/build is part of this candidate.

## Tasks for Claude before gameplay integration

- Promote approved definitions and placements to the shared `data/props` and
  `data/scenes` format; keep one authoritative arrangement for core and rendering.
- Hand-tune colliders: the extractor currently makes every object solid (even the
  antler/mushrooms) and closes the arch's gap with a continuous base row. Use separate
  arch-foot colliders and deliberate decor rules. Do not use these defaults unchanged.
- Build a walkable outline with the two trail openings. Verify hero approach from
  eight directions and radius-20 Stag access to at least 80% of the fight area.
- Expose approved layered-scene snapshot data/scene entry, then Codex can wire it.

Cannot judge: owner's art/style approval, game feel, collision alignment in play,
Stag fight room/balance, or final motion quality from the still contact sheets.
