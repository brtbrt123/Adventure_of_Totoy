# Shared weapon paths, glow and particles

Owner approved the three weapon path previews and requested integration globally, including luminous trails and particles (2026-10-29).

## One implementation for every hero scene

Both `arena.gd` and `explore_scene.gd` extend `presentation/common/hero_fx.gd`. Their hero drawing calls **`draw_hero_back(actor, selected_pose, feet, left)`** immediately before drawing the body. This entry point draws the regular weapon path, Sprint and the rear buff aura. Future scenes that render Totoy must use this entry point too; do not implement a scene-specific trail renderer.

`presentation/common/weapon_paths.gd` selects the frame using the actual actor pose, state and equipped frame set. It supports three katana swings, four dagger swings (also the Lightning Form frame set) and three scythe swings. Paths appear in the active phase and dissolve in the first six recovery ticks. Windup, unarmed, hurt, dead, skill/cut-in and interrupted poses produce no regular path. No target or boss is required, so missed swings also have a trail.

The owner caught a reversed third katana cut in the first preview. Its raised-to-low blade motion crosses more than 180 degrees, so shortest-angle interpolation incorrectly swung underneath the hands. Its authored segment now explicitly travels clockwise over the head and down in front; the normal mirror handles left-facing attacks. A regression checks both the forward overhead arc and its low blade-tip endpoint. `katana_alignment_v2.gif` and the `*_third.png` runtime captures show the correction.

`weapon_path_glow.gd` is a child created by the shared base for both scenes. Its small additive shader samples only the standalone path texture, preserving source art transparency. It supplies the halo and square-pixel sparks. The path uses the existing environment shader's emissive-pass convention, so woodland night lighting does not swallow it. This does not add scene lights or affect gameplay.

Sparks emit from the bright cutting edge once per fresh simulation tick, not once per rendered frame; they expire in 9–13 ticks and are capped at 48. Clock resets clear them; pausing does not multiply them. Camera motion/shake and left-facing poses use the hero's world anchor. Palette colours remain violet/ice blue/teal. Asset PNGs retain Totoy 36 and hard alpha; halo blending is a runtime effect.

The old separate scythe arc draw in the arena and generic road-only practice crescent were removed from rendering, avoiding different/stacked trails across scenes. Practice audio and confirmed contacts, and existing skill/weapon-form effects, remain.

## Assets and reproduction

Approved source and conversion: `art/reference/weapon_paths_review_v1/`. `install.py` converts its 40 transparent effect frames into `art/src/fx_weapon_path_*.txt`, anchor (48,78), 128x96. Standard validate/build/preview regenerates runtime PNGs and atlas. The original hero and weapon sprites are reused. No additional generation credits.

## Regression checks

- `tests/smoke_weapon_paths.gd`: every combo stage, mirrored feet anchors, missing/expired/interrupted/unarmed cases; real core swings for all weapons in **both** scenes; particle emission and expiry.
- `tests/capture_weapon_paths.gd`: actual renderer submissions of the shared path, glow and particles in all **12** scene/weapon/facing cases. Uses an isolated fixture save. `-- --motion` adds full-combo crops under the ignored `art/build/arena_weapon_paths_motion/` folder.
- `-- --third` explicitly waits for the third combo swing in all 12 cases. Capture fixtures mark road encounters cleared so mob hits cannot interrupt the alignment check; this does not affect normal play.
- `art/reference/weapon_paths_review_v1/ingame/compose.py`: converts those runtime captures into the six-panel live GIF, slowed 2.4x for review. Runtime capture pixels remain at integer 3x.

Full-size captures and animated evidence are in `art/reference/weapon_paths_review_v1/ingame/`. Owner playtesting and Claude cross-review remain pending; screenshots cannot establish combat readability or feel.
