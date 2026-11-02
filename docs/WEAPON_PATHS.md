# The blades' basic attack slash

The blades' slash shows the swing's hit area: the swing's reach around the hero's feet, inside its arc, turned to his facing. It replaced the pose-traced trail frames on 2026-11-02.

- The owner asked: "change the attack that have a turn and sharp curve and make it just a crescent slash", then "check the basic attack range match effects on it".
- The old trails (approved 2026-10-29) followed the blade tip in each side-view pose. Several reached behind or above the hero, where nothing is hit, and none turned with him when he faced up or down.

## What the game hits, and what the slash draws

The hit test lives in the core (`core/weapons.gd`):
- A blade's swing hits a target whose edge is within `swing_reach(weapon, swing)` of the hero's feet.
- The target must also be inside the arc: `facing.dot(direction) >= swing_arc_dot(weapon)`.

| Weapon | Reach (px) | Arc |
|---|---|---|
| Katana | 26, 26, 32.5 (finisher) | 157° |
| Dual daggers | 19.5 for all four swings | 157° |
| Chain scythe | 33.8, 33.8, 36.4 | 203° |

`presentation/common/swing_arc.gd` draws a crescent on the ground from those same numbers:
- Its outer edge is the reach, around the feet. Its ends are the arc's ends, turned to the hero's facing vector (any direction, not only left and right).
- It sweeps from one end of the arc to the other. It starts two ticks before the active frames and reaches the far end on the last active tick.
- Odd swings sweep top to bottom on his right side (mirrored on the left); even swings sweep back up.
- It is white hot where the blade is. The body is in the blade's colour: lilac katana, steel daggers, teal scythe.
- It fades through the first 8 recovery ticks (12 for the finisher) by dithering.
- The finisher's crescent is thicker.
- It is drawn in the Star Staff's style: Totoy 36, hard alpha, ordered dithering, emissive, so night lighting does not swallow it.
- Sparks fly off its leading end while it sweeps (`impact_view.gd`).

## One entry point in every scene

- Both `arena.gd` and `explore_scene.gd` extend `presentation/common/hero_fx.gd`.
- Their hero drawing calls `draw_hero_back(actor, selected_pose, feet, left)` just before drawing the body. This draws the slash, Sprint and the rear buff aura, at the hero's sorted depth.
- Future scenes that render Totoy must use this entry point too.
- `hero_swing_plan()` exposes the plan for tests. The training post's `practice_view.slash_effect()` returns the same plan.

There is no slash in these cases:
- the windup (until its last two ticks), unarmed, hurt, dead, skill or interrupted poses;
- the Star Staff, which casts (`staff_view.gd`).

## Checks and the attack sheet

- `tests/smoke_swing_arcs.gd` checks every blade, every swing and five facings:
  - every pixel of the crescent lies inside the hit area;
  - its edge reaches the reach;
  - the arc is centred on the facing;
  - the sweep and fade timing is right;
  - a real swing shows it in both the fight and the road.
- `tools/art/attack_range_sheet.py` writes `art/reference/hero_fx_v1/attack_ranges.png`:
  - every swing with its hit area, read from `core/tuning.gd`;
  - the slash drawn with the same maths as `swing_arc.gd`.

Removed with this change, all still in the history:
- the old trail frames `fx_weapon_path_*`;
- `weapon_paths.gd`, `weapon_path_glow.gd` and its shader;
- their animation resource `fx_weapon.tres`;
- `tests/smoke_weapon_paths.gd` and `tests/capture_weapon_paths.gd`.

The review captures of the old trails stay in `art/reference/weapon_paths_review_v1/`.
