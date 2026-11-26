# Runebound Warden: design, interface and integration

The Warden is the Hollow Trial's hard mob (design and waves: [[PLAN_hollow_trial]], "The new mob"). This note is the one place for what the game uses: its look rules, the core interface presentation reads, the effects and sounds, and how the art got to where it is. Rewritten on 2026-11-26 when the project became Claude-only; it now also holds the facts from the two retired task notes about the Warden (they are in git history before that date).

## Look rules

- An old guardian of the Hollow: an upright knight of root, bark and mossy stone, one arm ending in a root-wrapped blade (the Lash comes from it). It must read as harder than a Boar and unlike every other mob.
- Totoy 36 only. Bark browns and mossy greens, a stone-grey chestplate, a **teal** rune in the chest (the Hollow rune stones' teal). **No gold or red in the body or its idle glow**: those are the combat cues.
- The rune is the gameplay: **lit** = guarded (hits do little), **dark** = exposed (full damage). It must read from a distance in one frame.
- Right-facing frames, mirrored at runtime. Frame names `warden_<state>_right_<n>`.

## Core interface (verified against `core/mob_field.gd` and `core/tuning.gd`, 2026-11-26)

- Numbers live in `Tuning.MOBS[&"warden"]`: level 3, HP 140, radius 12 (since the art was drawn 1.5x smaller), speed 0.5, guard 0.4 (a guarded hit does 40 %), herb drop 0.8.
- Mob view (`ExploreSnapshot.mobs`, from `MobField.mob_views`): `type` `warden`, `state` (`idle`, `alert`, `chase`, `windup`, `strike`, `recover`, `stagger`, `hurt`, `return`, `dead`), `state_ticks`, `exposed`, **`guarded`** (rune guard up; false when exposed or dead), **`attack`** (`warden_cleave`, `warden_lash` or `warden_ring` while one winds up or strikes, else empty) and `attack_id` (the attack in progress or next).
- A parried Cleave puts it in `stagger` (exposed, rune dark) for `Tuning.MOB_STAGGER_TICKS` = 90 ticks, then the guard returns.
- `attack_hit` on the Warden carries **`guarded: true`** when the guard reduced it; an exposed hit has `kind` `counter` and no `guarded` key.
- Attacks (windup / strike / recover ticks): **Rune Cleave**, gold cone, reach 46 + radius, half-angle 0.9 (40 / 6 / 44). **Root Lash**, red line 150 long and 20 wide, the Warden does not move (44 / 8 / 40). **Spore Ring**, red circle radius 48 centred on the Warden itself (56 / 5 / 44). An unparried Cleave chains into the Lash 12 ticks after its recovery starts; a parried Cleave ends the chain. Only one Warden winds up or strikes at a time (`solo_attack`).
- Presentation draws every hit area from the core telegraph (centre, direction, size, half-angle). It never holds a second copy of the hit geometry, and the core's reach is never changed to hide a drawing mismatch.
- A guard-hit recoil never replaces an attack pose: sparks only during windup and strike, the small recoil only in other poses.

## Frames, effects and sounds in the game

- Body: 60 frames in 14 sets (idle 6, wake 4, walk 6, cleave_tell 5, cleave_strike 3, lash_tell 5, lash_strike 3, ring_tell 5, ring_strike 3, recover 4, guard_hit 2, exposed 4, hurt 2, death 8), posed by `tools/art/rig_warden_v2.py` from the SpriteCook detailed design and drawn 1.5x smaller (79 px tall). Never hand-edit them; change the rig.
- Attack effects `fx_warden2_*` (44 frames) imported from the Gemini sheets by `tools/art/import_warden_fx.py`; older attached effects redrawn by `tools/art/redraw_warden_2p5.py`. Drawn by `presentation/explore/warden_effects.gd` and `creature_particles.gd`. `tests/test_warden_art.py` pins the attached effects to their reviewed reference.
- Editor view of everything: `presentation/library/warden_gallery.tscn`.
- Sounds in `presentation/audio/warden_*.wav` (wake, steps, cleave/lash/ring tell and strike, two guard hits, guard break, death), built by `presentation/audio/build_warden_audio.py`. Rules: the gold and red warnings stay audible over everything; Warden sounds sit below them; never more than two Warden voices at once (the second is quieter).

## How the art got here

| Step | Where | What |
|---|---|---|
| Design | `art/reference/warden_v1/` | seven-pose sheet, `DESIGN.md`, the prompt, native seeds |
| Animation V1 | `art/reference/warden_v1/animation_review/` | 60 body frames, 100 effects |
| Effects V2, V3 | `art/reference/warden_fx_astra_v2/`, `warden_fx_astra_v3/` | organic effects, then higher contrast (the owner found V2 too faint) |
| V4 | `art/reference/warden_cleave_range_v4/` | the Cleave sweep made to cover the whole core cone (V3 traced only the blade tip); `build_review.py` rebuilds it from the older folders, so keep them |
| 2.5x body | `art/reference/warden_size_2p5/` | the owner asked for a 2.5x body: 60 bodies at 120x120, feet (50, 110); integrated on 2026-10-31 (`presentation/review/warden/README.md`, captures and sound preview there) |
| Native redraw | `tools/art/redraw_warden_2p5.py` | all 135 frames redrawn at 2.5x instead of stretched |
| Detailed art | `art/reference/warden_v2_detailed/`, `tools/art/rig_warden_v2.py` | new SpriteCook design, posed by a part rig; then drawn 1.5x smaller and given bigger motion after the owner's playtest |

The STATUS entries of 2026-10-31 and 2026-11-01 have each step's checks.

## Open

- The look, sound and feel are the owner's call; no review of the 2026-10-31 integration by a second agent was ever done, and none is planned now that Claude works alone.
- The Warden is only met in the Hollow Trial; balance numbers are first guesses.
