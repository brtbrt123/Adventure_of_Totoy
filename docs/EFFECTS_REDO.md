# Effects redo in the Star Staff's style (2026-11-02)

The owner asked for every effect redone in the staff's look, except the golem: "redo all effects, aspects, attacks of mobs and hero". It was done in four phases, each committed and pushed. Nobody has play-tested it. Per-phase details are in [[STATUS]].

## The shared pieces (presentation only, no rules)
All live layers are owned by `presentation/common/hero_fx.gd` (shared by the road and the fight) except the mobs'. Particles live on a ground plane (x, ground y, height z), stepped at 30 Hz.

| Piece | File | Draws | Triggered by |
|---|---|---|---|
| Particles | `presentation/common/fx_particles.gd` | sparks, motes, embers, smoke, dust, stones, shards, streaks, ground rings | used by every layer below |
| Staff | `presentation/common/staff_view.gd` | the Star Staff's casts, blink, Disintegration | `staff_burst`, `disintegration_*` events |
| Hits, parries, dash | `presentation/common/impact_view.gd` | sparks, dust, ground rings, light | `on_hero_hit`, `on_hero_parry`, `dash_started` |
| Blade slash | `presentation/common/swing_arc.gd` | a crescent on the swing's real hit area (reach and arc from `core/weapons.gd`) | the hero's swing state, via `draw_hero_back` |
| Weapon forms | `presentation/common/form_view.gd` | Black Form embers and light, Lightning crackle and blink, Reaper's Coil dust and sparks | weapon buff and lightning/coil events |
| Aspects | `presentation/common/aspect_view.gd` | Lantern pool, Phantom Cut, Echo Step, Stone Ward, Sprint, the three skills | aspect events and `skill_released` |
| Mobs | `presentation/explore/mob_fx_view.gd` | stones, dust rings, chips, motes, shake | the bursts `creature_effects.gd` emits |

The old pose-traced trail frames (`fx_weapon_path_*`) and their code were removed; see [[WEAPON_PATHS]].

## Frames are drawn in code
`tools/art/staff_fx.py` is the toolkit (Totoy 36 colours, hard alpha, dithering). One generator per phase writes `art/src` at the old names, counts, sizes and anchors:
- `tools/art/make_hero_fx_art.py`: hit, counter, parry, flash, dash.
- `tools/art/make_form_fx_art.py`: the three weapon forms.
- `tools/art/make_aspect_fx_art.py`: the aspects.
- `tools/art/make_mob_fx_art.py`: the chapter 1 creatures. The Warden's attached effects are pinned to reviewed art by `tests/test_warden_art.py` and were left alone.

Run validate, build and preview after changing art, then `godot --headless --import`.

## Review captures (window only)
`presentation/review/hero_fx/capture_*.gd` play the real game and save frames; `tools/art/hero_fx_capture_gif.py` makes the GIFs in `art/reference/{hero_fx,form_fx,aspect_fx,mob_fx}_v1/ingame/`. `tools/art/attack_range_sheet.py` draws every swing's hit area.

## Image generators (accounts, as last seen)
- **Higgsfield** (MCP `mcp__88e42e...`): model `nano_banana_2_1`, 1.5 credits per image, about 30 credits left on 2026-11-02, 19.5 left on 2026-11-09. Used for the Star Staff's run frames (`art/reference/staff_v1/sources.json`), the village wall and fence (`art/reference/village_wall_fence_v1/`) and the Rootcrown concepts, floor and props (`art/reference/rootcrown_v1/sources.json`). Upload a reference with `media_upload`, then PUT the file with curl (Python's urllib gets 403), then `media_confirm`; one generation at a time (a second one at once gets 429).
- **SpriteCook** (plugin `spritecook`): free tier, 1 credit left on 2026-11-03. Not enough for a generation.
- Uploading a reference image sends it off the machine: ask the owner first.

## Not done
No play-test. Code-drawn art does not suit painted props (the village wall and fence attempt was rejected, see [[HANDOFF]]).
