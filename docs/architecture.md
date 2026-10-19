# Architecture: core / presentation interface

Status: **draft 2**, implemented by the combat vertical slice in `core/` (one room, player with sword vs the Mossbound Colossus) and covered by headless tests. It will keep changing as the slice is playtested. Changes go through Claude Code (owner of `core/` and this file); Codex builds against it and reports gaps in task notes.

## Principles

1. `core/` has no rendering, UI or audio code and runs headless. `presentation/` has no game rules.
2. **The core decides, presentation draws.** Hits, damage, parry timing, posture and cooldowns are core results. Presentation never recomputes them.
3. **Fair tells (from the game design):** every attack's warning is produced by the core as the *same geometry* that later applies damage (`telegraph.gd`). Presentation draws that geometry; it never invents its own. A test checks warning area == hit area on a grid of positions, and another checks that aim never changes after an attack commits.
4. Presentation sends *intents*, not key presses. Mapping keyboard/controller to intents lives in `presentation/`.
5. Communication is one way per channel: input intents in; snapshot and events out. No layer calls into the other's internals.

## How to use the core

```gdscript
const GameCore := preload("res://core/game_core.gd")
const InputFrame := preload("res://core/input_frame.gd")

var core: GameCore = GameCore.new(seed_value)   # deterministic: same seed + same inputs = same fight

func _physics_process(_delta: float) -> void:   # project physics ticks must be 60 per second
	var frame: InputFrame = InputFrame.new()
	frame.move = Input.get_vector("left", "right", "up", "down")
	frame.parry_pressed = Input.is_action_just_pressed("parry")
	core.step(frame)                             # advance exactly one tick
	var snap := core.snapshot()                  # read-only view for drawing
	for event in core.last_events:               # facts from this tick, in order (also via core.event_emitted)
		pass
```

Core scripts are referenced with `preload` constants, not `class_name`, so they load in headless runs without the editor's class cache.

## Time

Fixed tick of **60 Hz** (`Tuning.TICK_DT`). One `step()` is one tick. All times in the interface are ticks (`int`) so results are deterministic and testable; presentation converts to seconds for effects. Randomness uses a seeded `RandomNumberGenerator` owned by the core. After `result` leaves `playing`, `step()` does nothing.

## Channel 1: input intents (presentation to core): `core/input_frame.gd`

One `InputFrame` per tick:

| Field | Type | Meaning |
|---|---|---|
| `move` | `Vector2` | desired move direction, length 0..1 |
| `aim` | `Vector2` | aim direction (bow/staff later), zero if none; otherwise facing follows `move` |
| `attack_pressed` / `attack_held` | `bool` | normal attack (sword) / draw / cast |
| `parry_pressed` | `bool` | gold parry |
| `dash_pressed` | `bool` | dash |
| `weapon_active_pressed` | `bool` | the equipped weapon's active this tick (right click; Black Katana buff or Dual Dagger Lightning Form, see "Weapon active" and "Dual Dagger") |
| `weapon_swap_pressed` | `bool` | swap Black Katana <-> Dual Dagger this tick (Q; see "Dual Dagger") |
| `skill_pressed` | `int` | skill slot 1, 2 or 3 pressed this tick, else 0. Test bindings: Z = 1 Breaking Edge, X = 2 Gale Cut, C = 3 Moon Cleave (the key mapping is presentation's job) |
| `interact_pressed` | `bool` | talk, open, checkpoint (unused so far) |

## Channel 2: read-only snapshot (core to presentation): `core/snapshots.gd`

`core.snapshot()` builds a new `Snapshots.GameSnapshot` each call; do not mutate it or keep references to core objects.

- `tick`, `result` (`playing`, `victory`, `defeat`)
- `player: EntitySnapshot`, `entities: Array[EntitySnapshot]` (the boss; more later)
- `telegraphs: Array[TelegraphSnapshot]`
- `skill_attacks: Array[SkillAttackSnapshot]` (live skill attacks, see "Sword skills")
- `obstacles: Array[ObstacleSnapshot]` (the solid props of the arena, the same list every tick)
- `hud: HudSnapshot`

### The arena: size, solid props, camera

- **Size.** `Tuning.ARENA_SIZE` is **800x480** (50x30 tiles). Bodies stay `Tuning.ARENA_MARGIN` (28 px) inside the edge. Spawns: `Tuning.PLAYER_START` (312, 250), `Tuning.BOSS_START` (488, 250); no prop overlaps them.
- **Solid props (core).** `core/arena_layout.gd` builds a fixed list of `core/obstacle.gd` circles (pillars, the statue, two chests, the altar, two fallen columns, four corner trees). `game_core.gd` resolves the player and the boss against them in small steps (no tunnelling, also for dashes, Gale Cut and the boss charge). A large prop is one sprite plus extra colliders with an empty `visual_id`. Nothing solid stands inside the stone ring in the middle (x 232..568, y 134..346).
- **`ObstacleSnapshot`:** `id`, `visual_id` (sprite name, empty for an extra collider), `feet` (where presentation places the sprite by its anchor), `visual_scale`, `center` and `radius` (the collision circle). Presentation draws the props only from this list; it must not add solid-looking things the core does not know about.
- **Ground and decoration (presentation).** The floor is `presentation/arena/arena_ground.png`, laid on the 16x16 grid from the tiles in `art/src` by `tools/art/make_arena_ground.py` (overlay tiles for the ring and the medallion come from `tools/art/make_plaza_tiles.py`). Non-solid decoration (wall pieces along the edge, flowers, rubble) is a short hand-placed list in `presentation/arena/arena_decor.gd`.
- **Camera (presentation).** The screen stays 320x180. `arena.gd` owns a `Camera2D` that follows the player (leaning 22% towards the boss), snapped to whole pixels and clamped so the view never leaves the arena. `view_origin` is the world position of the screen's top-left corner; the HUD is in screen space, so world positions given to it (the boss head for the boss panel) are converted with `world - view_origin`.

`EntitySnapshot`: `id`, `visual_id` (`&"totoy"`, `&"mossbound_colossus"`), `state`, `state_ticks`, `position` (pixels), `facing`, `hp`, `max_hp`, `posture`, `posture_max`, `invulnerable`, `combo_index` (player only, see the sword combo below; `0` for the boss), `skill_id` (player only: `breaking_edge`, `gale_cut` or `moon_cleave` during the `skill_*` states, otherwise empty), and for the player the weapon fields `weapon_id`, `weapon_buff_active`, `weapon_buff_ticks_left`, `attack_speed_mult` (see "Weapon active") and `combo_max`, `weapon_form`, `move_speed_mult`, `lightning_blink_index`, `lightning_blink_tick`, `lightning_blink_from`, `lightning_blink_to` (see "Dual Dagger").

States: player `idle walk dash parry parry_recovery attack_windup attack_active attack_recovery skill_windup skill_active skill_recovery dead`; boss `idle attack recover posture_broken dead`.

### Sword combo (player)

The sword is a three-swing combo: `combo_index` 1, 2, 3 = art `hero2_attack1`, `attack2`, `attack3`. The core owns all of it (progression, timing, hit resolution); presentation only reads `player.combo_index` together with `state` and `state_ticks`.
- **Meaning of `combo_index`:** during `attack_windup`, `attack_active` and `attack_recovery` it is the swing in progress (1-3). While idle it is `1`, except for a short chain-grace window (`COMBO_GRACE_TICKS`) right after swing 1 or 2 ended, when it still shows that swing. Pick the attack animation from `combo_index` whenever `state` starts with `attack_`.
- **Frames per swing (the art has six):** windup = frames 1-2, active = 3-4, recovery = 5-6. Each swing has its own tick counts (`SWING_WINDUP_TICKS`, `SWING_ACTIVE_TICKS`, `SWING_RECOVERY_TICKS` in `core/tuning.gd`, one entry per swing), so spread the frames over `state_ticks` of the current state, not over fixed tick counts.
- **Chaining:** an attack press during the last `COMBO_BUFFER_TICKS` of a swing's recovery is remembered; the next swing starts the tick recovery ends (the state goes `attack_recovery` -> `attack_windup` with no idle tick, `combo_index` + 1). Earlier presses are ignored. If nothing was buffered, a press within `COMBO_GRACE_TICKS` after the swing still continues the chain. After swing 3 the combo is over: the next press starts swing 1 (a buffered press at the end of swing 3 starts a new combo at 1).
- **Resets to 1:** the player takes damage, dashes, parries (the press, or a successful parry), dies, stops chaining (grace ran out) or finishes swing 3. A queued press is dropped with the reset.
- **Hits:** each swing hits at most once (the first active tick that has the boss in range and arc). Damage and reach scale per swing (`SWING_DAMAGE_MULT`, `SWING_RANGE_MULT`). The `attack_hit` event carries `combo_index`.

### Sword skills (player, test set)

Three skills for testing the Aspect system, selected by `skill_pressed` 1-3 (Z, X, C). Usable from `idle`, `walk` and the recovery of a normal swing (a skill cancels that recovery and resets the combo); not during a parry, dash, another skill or after death. Each runs `skill_windup` -> `skill_active` -> `skill_recovery` (read `snapshot.player.skill_id` for which). None grants invulnerability. Phase lengths and every number are in `core/tuning.gd` (`BREAKING_EDGE_*`, `GALE_CUT_*`, `MOON_CLEAVE_*`); spread frames over `state_ticks` of the current state.
- **Direction:** fixed when the skill is pressed: the **move input** if the player is moving, else `aim`, else the facing. The player's `facing` is set to it. (The mouse aim no longer beats the way the player is walking.)
- **Edge:** the cost is spent on the press and is not refunded if the skill is interrupted. Each skill has its own cooldown (`hud.skill_cooldown_ticks`).
- **Attack objects:** the tick a skill enters `skill_active`, the core creates one **skill attack** with an id and emits `skill_released`. It is listed in `snapshot.skill_attacks` while it lives. A cast hits each target at most once; the confirmed hit is an `attack_hit` event with `skill_id` and `attack_id`. Damage uses the normal-hit rules (armored factor; counter multiplier during a posture break; posture added only when not broken).
- **`SkillAttackSnapshot`:** `id`, `owner_id`, `skill_id`, `shape` (`arc`, `lane`, `projectile`), `position` (arc/lane: the player; projectile: its centre now), `direction`, `start` and `end` (lane/projectile endpoints; `end` is where it ends if nothing shortens it), `width`, `size` (arc reach), `half_angle` (arc, radians), `start_tick`, `end_tick`, `ticks_left`, `hit_target_ids`.
- **Breaking Edge (1), parry retaliation:** only while `hud.retaliate_ticks_left > 0` (set by a successful parry, cleared by damage or use) and with `BREAKING_EDGE_EDGE_COST` Edge. A 3-tick windup that is also the forward step (`BREAKING_EDGE_STEP`), then a short melee `arc` (one confirmed hit) with strong posture damage (two break the boss).
- **Gale Cut (2), dash corridor:** 35 Edge, 300-tick cooldown. A short windup (no movement), then during `skill_active` the player dashes `GALE_CUT_SPEED` px per tick for `GALE_CUT_ACTIVE_TICKS` ticks (about 120 px). During `skill_active` the player **passes through the boss** (no collision with enemies) but is still stopped by the arena walls. The `lane` attack damages whatever the **actually travelled** segment (previous position to the final position each tick, after the wall clamp) touches, widened by `GALE_CUT_LANE_WIDTH` (18 px) plus the target's radius, once per target. Normal enemy collision is back from the first `skill_recovery` tick (or the moment the dash is interrupted): if the player ends inside the boss they are moved to the nearest free spot (first on the side they were heading, then around the boss if a wall blocks it), so they never finish stuck in an enemy. The windup is still solid. The lane lives until the dash ends or is interrupted (damage ends it at once). The lingering blade trail is cosmetic: presentation draws it from the positions, it deals no damage.
- **Moon Cleave (3), sword-aura projectile:** `MOON_CLEAVE_EDGE_COST` Edge, a committed hold (`MOON_CLEAVE_WINDUP_TICKS`, slow movement). Damage only comes from the projectile. If the hold is interrupted nothing spawns (and the Edge is gone). On the first `skill_active` tick the `projectile` spawns `MOON_CLEAVE_SPAWN_OFFSET` px ahead, then travels `MOON_CLEAVE_TRAVEL` px at `MOON_CLEAVE_SPEED` px per tick, `MOON_CLEAVE_WIDTH` px wide, piercing (each target once). It then lives on its own: taking damage or dying after the release does not remove it. The recovery cannot be cancelled by dash, parry or attack.
- **Collision:** swept: each tick tests the whole segment moved (so a fast mover cannot tunnel) against the target circle widened by half the lane/projectile width.
- **Presentation to do (Codex):** a Gale Cut dash now moves the player during `skill_active` (before it moved during the windup), so the dash trail and effect timing must follow `skill_active` and `snapshot.skill_attacks`; draw the Moon Cleave projectile from `skill_attacks` (`position`, `direction`, `width`, `ticks_left`) and keep it after the player's state changes; use `skill_released` for release sounds and effects. `tests/smoke_skills_presentation.gd` sets no Edge before pressing X, which now costs 35.

### Weapon active: Black Katana buff (player)

The equipped weapon is `snapshot.player.weapon_id` (`black_katana` or `dual_dagger`; see "Dual Dagger" for the second weapon, the swap and Lightning Form, which reuse this plumbing). Its active is **right click**: input field `InputFrame.weapon_active_pressed` (true for the tick of the press; mapping the mouse button is presentation's job). The core owns everything else.

**Numbers** (`core/tuning.gd`, `BLACK_KATANA_*`, set by the human on 2026-10-19, not yet playtested): duration 600 ticks (10 s), cooldown 1800 ticks (30 s, counted from the activation), Edge cost 50, attack speed x1.5, damage x1.4. Nothing else in core hard-codes them; presentation must read them from `Tuning` or the snapshot. Open design questions: can it be re-pressed to refresh (not now), does the buff change skill speed (it does not now), should damage taken or a parry affect it (they do not now).

**Rules (as built):**
- Needs: weapon `black_katana`, not dead, enough Edge, cooldown ready, and **no buff running** (it cannot be refreshed). A refused press does nothing and emits no event.
- It is a **free action**: no state change, no animation lock, allowed in any state except `dead` (idle, walk, attack, dash, parry, skill). The cost is spent on the press.
- It **stays active through movement, attacks, dashes, parries, skills and damage**. It ends only when the duration runs out or the player dies. A new fight (`GameCore.new()`) starts without it.
- **Attack speed** applies to the normal sword swings: every phase length (windup, active, recovery) is `Player.scaled_ticks(base, mult)` = `round(base / mult)`, at least 1 tick. Skill timings are unchanged.
- **Damage** is multiplied on normal swings and skill hits (counter hits too). Both multipliers are **locked** when a swing starts and when a skill is released: a swing never changes speed halfway, and a projectile released under the buff keeps its damage even if the buff ends before it lands.
- The combo buffer, grace and resets are unchanged (the buffer window never extends past the shorter recovery).

**Snapshot:**
- `player.weapon_id`, `player.weapon_buff_active`, `player.weapon_buff_ticks_left` (0 when inactive), `player.attack_speed_mult` (the locked speed of the swing in progress during `attack_*` states; otherwise the current buff speed, 1.0 without the buff).
- `hud.weapon_buff_duration` (0 for a weapon without an active), `hud.weapon_buff_cooldown_ticks` / `hud.weapon_buff_cooldown_max`, `hud.weapon_buff_edge_cost`. (The boss entity has `weapon_id` empty.)

**Events:**
- `weapon_buff_started`: `entity_id`, `weapon_id`, `duration` (ticks), `attack_speed_mult`, `damage_mult`.
- `weapon_buff_ended`: `entity_id`, `weapon_id`, `reason` (`expired` or `death`).
The buff is active from the activation tick through the `duration`-th tick; `weapon_buff_ended` fires on the tick after the last active one.

**Presentation to do (Codex), none of it changes rules:**
1. Bind right mouse button to `weapon_active_pressed` in `input_bindings.gd`.
2. **Swing animation lengths must follow the speed.** Use `Player.scaled_ticks(Tuning.SWING_WINDUP_TICKS[i], snapshot.player.attack_speed_mult)` (and the same for ACTIVE and RECOVERY) instead of the raw `Tuning.SWING_*` numbers in `animation.gd`, using the swing's `combo_index`; otherwise frames stop early or hold at the end while the buff runs.
3. Show the empowered look (aura, empowered katana frames) while `player.weapon_buff_active`, with a fade-out cue from `weapon_buff_ticks_left`; one-shot cues on `weapon_buff_started` / `weapon_buff_ended`.
4. HUD: show the active's remaining duration and the cooldown (`hud.weapon_buff_*`), and the Edge cost, near the weapon icon.
5. Add a smoke test that every frame requested while the buff speeds up the swings exists.

### Dual Dagger: second weapon, swap, lightning finisher, Lightning Form (player)

Added 2026-10-19 (core only; numbers are first guesses, nobody has played it). Every number is in `core/tuning.gd` (`WEAPON_SWAP_*`, `DAGGER_*`, `LIGHTNING_*`). `core/weapons.gd` (`const Weapons := preload("res://core/weapons.gd")`) is the one place that picks a weapon's numbers by `weapon_id`; presentation should use it too instead of branching on the weapon: `Weapons.combo_max(w)`, `Weapons.swing_phases(w, combo_index)` -> `[windup, active, recovery]` base ticks, `Weapons.windup_ticks/active_ticks/recovery_ticks(w)`, `Weapons.active_duration/active_cooldown/active_edge_cost(w)`, `Weapons.active_form(w)`, `Weapons.blink_direction(index)`.

**Swap (Q).** `InputFrame.weapon_swap_pressed` toggles `black_katana` <-> `dual_dagger`. Allowed only in `idle` or `walk` (not during a swing, its recovery, a skill, dash, parry or after death), never while a weapon buff/form runs, and not within `WEAPON_SWAP_LOCKOUT_TICKS` (20) of the previous swap. It is a free action (no state change; an attack pressed the same tick already uses the new weapon). It resets the combo to 1. A refused press does nothing and emits nothing. The player always starts a fight with the Black Katana. Each weapon keeps **its own active cooldown**, and all of them keep counting down while put away, so swapping never resets or skips one.

**Dagger combo.** 4 swings (`combo_index` 1-4 while the dagger is equipped; `snapshot.player.combo_max` says 3 or 4). Same buffer/grace/reset rules as the katana combo; after swing 4 the combo is over. Per-swing tables `DAGGER_SWING_WINDUP_TICKS` [4,4,4,6], `DAGGER_SWING_ACTIVE_TICKS` [2,2,2,3], `DAGGER_SWING_RECOVERY_TICKS` [6,6,6,12] (12/12/12/21 ticks against the katana's 19/18/29), reach x0.75 of `ATTACK_RANGE`, damage `ATTACK_DAMAGE` x [0.6,0.6,0.6,0.9], Edge +`DAGGER_EDGE_PER_HIT` (20) per hit. Alternating hands is presentation only (odd/even `combo_index`). Skills Z/X/C work the same with both weapons. **Presentation reads the swing lengths through `Weapons.swing_phases(weapon_id, combo_index)`** (scaled with `Player.scaled_ticks(base, attack_speed_mult)`; done in `presentation/arena/animation.gd`).

**Lightning strike (dagger finisher).** When the 4th dagger swing **connects** (the same `attack_hit` as always, with `combo_index` 4 and now also `weapon_id`), a bolt from the sky also hits that boss on the same tick, right after the `attack_hit`. No telegraph, it always lands on the hit boss; a whiffed swing 4 calls nothing, and it happens at most once per swing. Damage `LIGHTNING_STRIKE_DAMAGE` (20) under the normal-hit rules (x`ARMOR_DAMAGE_FACTOR` = 5 on the armored boss; x`COUNTER_DAMAGE_MULT` = 80 if the swing was a counter), plus `LIGHTNING_STRIKE_POSTURE` (8) when not a counter; no Edge gain. Event `lightning_strike`; the boss also emits its usual `damage_taken`. **Presentation draws the bolt from the sky down onto `position`** on that event (the boss position at the strike), with flash/shake/sound. There is no separate `attack_hit` for the bolt; show its damage from the event.

**Lightning Form (dagger right click).** Same plumbing and rules as the katana buff (`weapon_active_pressed`, free action, Edge spent on the press, no refresh while running, cooldown counted from the activation, ends on timeout or death, `weapon_buff_started` / `weapon_buff_ended`). Numbers: cost `LIGHTNING_FORM_EDGE_COST` 60, duration `LIGHTNING_FORM_DURATION_TICKS` 360 (6 s), cooldown `LIGHTNING_FORM_COOLDOWN_TICKS` 1500 (25 s), attack speed x2.0 (every swing phase via `scaled_ticks`), damage x1.0, walking speed x1.25 (all `move` based movement). Active from the activation tick through the 360th; `weapon_buff_ended` fires on the tick after. Skills and dash work during the form. The 4th-hit lightning strike also works in the form.
- **Blink.** Every swing that **starts** during the form while the boss is alive and its centre is within `LIGHTNING_BLINK_RANGE` (150 px) of the player first teleports the player next to the boss, on the swing's first `attack_windup` tick (`state_ticks` 0). The spot is `boss.position + Weapons.blink_direction(d) * LIGHTNING_BLINK_DISTANCE` (30 px from the boss centre: outside the boss, inside the dagger reach), kept inside the arena and pushed out of props. `d` (0-7, `Vector2.RIGHT` rotated by d x 45 degrees, y down: 0 right, 2 down, 4 left, 6 up) cycles through `LIGHTNING_BLINK_ORDER` [0,3,6,1,4,7,2,5] (consecutive strikes come from far-apart sides); a fresh form starts at the first entry. If that spot is blocked (a wall clamps it into the boss or out of reach, or a prop), the nearest free direction is used (tries d, d+1, d-1, d+2, d-2, ...). The player is never left inside a prop, inside the boss or outside the arena. The player then **faces the boss for the swing's windup and active ticks** (move/aim input does not turn it away), so the normal hit resolution connects. Each blink gives `LIGHTNING_BLINK_INVULN_TICKS` (6) ticks of invulnerability, the blink tick included (`snapshot.player.invulnerable`). Out of range, boss dead, or no form: no blink, the swing happens where the player stands.

**Snapshot (new player fields):** `combo_max` (3 or 4), `weapon_form` (`black_katana_buff`, `lightning_form`, or empty when no active runs; use it, not `weapon_id`, to choose the empowered look), `move_speed_mult`, `lightning_blink_index` (direction 0-7 of the latest blink, -1 before any), `lightning_blink_tick` (equals `snapshot.tick` on the blink tick), `lightning_blink_from`, `lightning_blink_to`. The existing `weapon_buff_active`, `weapon_buff_ticks_left`, `attack_speed_mult` apply to the equipped weapon's buff/form. **HUD:** `weapon_buff_duration`, `weapon_buff_cooldown_ticks`, `weapon_buff_cooldown_max`, `weapon_buff_edge_cost` are now always the **equipped** weapon's (katana 600/1800/50, dagger 360/1500/60); new `weapon_cooldowns` (Dictionary weapon_id -> ticks left, every weapon), `weapon_swap_lockout_ticks`, `weapon_swap_lockout_max`.

**Events:** `weapon_swapped` (`entity_id`, `weapon_id` = the new weapon, `previous_weapon_id`); `lightning_strike` (`attacker_id`, `target_id`, `position`, `damage`, `combo_index` = 4, `kind` `normal`/`counter`); `lightning_blink` (`entity_id`, `from`, `to`, `direction_index` 0-7, `target_id`), emitted on the swing's first windup tick before any hit; `weapon_buff_started` gains `form` and `move_speed_mult`; `weapon_buff_ended` gains `form`.

**Timing summary for presentation (form running, x2 speed):** dagger swing phases become windup 2, active 1, recovery 3 ticks (swing 4: 3, 2, 6). Tick T: attack press -> `lightning_blink` (player already at `to`, i-frames T..T+5) -> active from T+2 (hit + for swing 4 `lightning_strike`) -> recovery. Draw the blink as a flash from `from` to `to` on the event tick; the player snapshot position already jumped.

**Presentation (implemented 2026-10-19, by Claude Code while Codex is out):** Q (and the gamepad right shoulder) is `arena_weapon_swap` -> `weapon_swap_pressed`. `animation.gd` picks the hero frame set from the snapshot: `hero2_*` for the katana, `totoy_dagger_*` for the dagger, `totoy_lightning_*` while `weapon_form` is `lightning_form` (it has no victory art, so victory uses the dagger frames); a phase that lasts a single tick (dagger swings at x2) shows its second, key frame. `weapon_buff_view.gd` chooses the aura by `weapon_form` (`fx_lightning_aura_back/front_1..10`, no detached slash; the Black Form darkening, black dash ghosts and slash are katana-only). `lightning_effects.gd` holds the effect timing; `arena.gd` draws, from the events only: on `lightning_blink` a departure burst and afterimages at `from`, a chain bolt (32 px segments end to end) from `from` to `to`, an arrival burst, a small shake and flash, and after the swing's windup a `fx_lightning_cut_<dir>` through the boss travelling from the blink side; on `lightning_strike` the 32x160 bolt anchored at `position` (scale 2 when the point is low on the screen so it starts above the top edge), a white flash, a big shake, a scorch decal and sparks; lightning sparks on every hit in the form; flickering afterimages on dashes in the form. `lightning_form_cutin.gd` (a sibling of the Black Form cut-in, same freeze of the world) plays on `weapon_buff_started` with `form` `lightning_form`; the Black Form cut-in plays only for the katana. The HUD shows the dagger medallion, a Lightning Form slot (icon, run/cooldown ring), `RMB 60E / LIGHTNING or FORM nS / CD`, and a `Q SWAP` hint that dims while a form runs, the hero is busy or the swap lockout runs. Tests: `tests/smoke_dual_dagger_presentation.gd` (with `-- --capture` in a window it saves `art/build/arena_dagger_*.png`).

**Save:** `SaveProfile` accepts `weapon_id` `dual_dagger` (old saves and saves without the field still load as `black_katana`). The fight does not read the profile's weapon yet.

### Save system (core)

`core/save_profile.gd` is the saved progress (`SaveProfile`): `runs_started`, `victories`, `defeats`, `best_victory_ticks` (0 = none yet), `last_result`, `weapon_id`, plus `load_note` (why a profile is fresh instead of loaded; empty otherwise). `record_run_started()` and `record_result(result, ticks)` (returns true on a new best victory time) are the only mutators. Serialisation is versioned JSON (`VERSION` 1); reading is forgiving: invalid JSON, a missing/invalid version or a newer version gives a fresh profile with a `load_note`, and bad field values are cleaned (negatives and non-numbers become 0, unknown results/weapons are dropped).

`core/save_store.gd` reads and writes the file (`user://totoy_save.json`; the environment variable `TOTOY_SAVE_PATH` redirects it, the test runner sets it so tests never touch a real save). `save()` writes a temp file, keeps the previous save as `.bak` until the new one is in place, then removes it; `load_profile()` always returns a profile (the file, else the `.bak`, else a fresh one with a note if a file existed but was unreadable). Nothing in a running fight depends on it.

**Presentation use (implemented):** the arena saves only when the game was started from the title screen (the title sets `Engine` meta `totoy_persist`): it records a started run on load and on every restart, and the result (with `core.tick` as the time) on the `game_result` event; the title screen shows the record. Saved progress is a profile only: there is no mid-fight save, and no quest or inventory data exists yet.

`TelegraphSnapshot`: `id`, `owner_id`, `muzzle` (where the attack leaves the boss), `attack` (`gold_slam`, `gold_combo`, `red_sweep`, `red_shards`, `red_stomp`, `red_charge`), `kind` (`gold` = parry it, `red` = dodge it), `shape` + parameters, `start_tick`, `hit_tick`, `end_tick`.
- `circle`: `center`, `size` = radius
- `cone`: `center` = origin, `direction`, `size` = radius, `half_angle` (radians)
- `line`: `center` = start, `direction`, `size` = length, `width`
- `ring`: `center`, `size` = outer radius, `inner_size` = inner radius; **the inside (closer than `inner_size`) is safe**, the band is dangerous, the outside is safe

Boss attacks: `gold_slam` (one parryable slam), `gold_combo` (two parryable slams, the second `COMBO_GAP_TICKS` after the first; a perfect parry on the first breaks posture and cancels the second; phase 2 only), `red_sweep` (legacy attack identifier; gold parryable cone), `red_shards` (three lines), `red_stomp` (ring), `red_charge` (a line; the boss body travels along it while it is dangerous, so the boss `position` in the snapshot moves from `hit_tick` to `end_tick`; phase 2 only). The attack frames presentation shows come from the telegraph `attack` name; a combo has two telegraphs with different `hit_tick`s.

**Beam muzzle (`red_shards`).** The three beam lines leave the boss's **chest core**, not its feet. `Tuning.SHARDS_ORIGIN_OFFSET` (an offset from the boss position, which is its feet) is the single authoritative muzzle: when the attack commits the core computes `muzzle = boss.position + offset`, aims the middle line from the muzzle at the player, and starts all three warning/damage lines there (`telegraph.center == telegraph.muzzle`). It is locked for the whole attack and exposed as `TelegraphSnapshot.muzzle`. Presentation must draw the warning and the beam from that same ray (`center`, `direction`, `size`, `width`) and the chest flash at `muzzle`; it must not re-derive the origin from art. For every other attack `muzzle` is the boss position at commit.

The area is dangerous from `hit_tick` to `end_tick` inclusive; before that it is only a warning. Presentation draws the warning growing/filling toward `hit_tick` and may slow the visual for the final windup (the design's "final windup slows briefly").

`HudSnapshot`: `player_hp`, `player_max_hp`, `dash_cooldown_ticks`, `dash_cooldown_max`, `edge`, `edge_max`, `boss_hp`, `boss_max_hp`, `boss_posture`, `boss_posture_max`, `counter_window_ticks_left`, `skill_cooldown_ticks` (array of 3, ticks left per slot), `retaliate_ticks_left` (Breaking Edge is usable while this is above 0), `weapon_buff_duration`, `weapon_buff_cooldown_ticks`, `weapon_buff_cooldown_max`, `weapon_buff_edge_cost` (all for the equipped weapon), `weapon_cooldowns` (weapon_id -> ticks), `weapon_swap_lockout_ticks`, `weapon_swap_lockout_max`.

**Art contract:** presentation picks a frame from `art/build/sprites.json` using `<visual_id>_<state>_<direction>_<n>` for characters and `<visual_id>_<state>_<n>` for the boss (see `AGENTS.md` section 5 and `presentation/arena/animation.gd`). A missing frame falls back to a visible placeholder and logs a warning; it never crashes.

## Channel 3: events (core to presentation): `core/game_event.gd`

Each event is a `GameEvent` with `type: StringName`, `tick: int` and `data: Dictionary`. They are available in `core.last_events` after each `step()` and as the `event_emitted` signal. Events are facts that already happened; presentation reacts with sound, particles, screen shake and UI. They carry no rules.

| Type | `data` keys |
|---|---|
| `attack_telegraphed` | `telegraph_id`, `owner_id`, `kind`, `attack` |
| `attack_hit` | `attacker_id`, `target_id`, `damage`, `kind` (`normal`, `counter`, `gold`, `red`), `position`, and for the player's normal swing `combo_index` (1-3 katana, 1-4 dagger) and `weapon_id`; a skill hit has `skill_id` and `attack_id` instead (no `combo_index`) |
| `parry_succeeded` | `player_id`, `attacker_id`, `telegraph_id`, `quality` (`perfect`, `early`), `position` |
| `parry_failed` | `entity_id`, `reason` (`whiff`) |
| `posture_broken` | `entity_id`, `window_ticks` |
| `counter_window_opened` / `counter_window_closed` | `entity_id` (+ `window_ticks` on open) |
| `dash_started` | `entity_id`, `direction` |
| `weapon_buff_started` | `entity_id`, `weapon_id`, `form` (`black_katana_buff`, `lightning_form`), `duration`, `attack_speed_mult`, `damage_mult`, `move_speed_mult` |
| `weapon_buff_ended` | `entity_id`, `weapon_id`, `form`, `reason` (`expired`, `death`) |
| `weapon_swapped` | `entity_id`, `weapon_id` (the new one), `previous_weapon_id` |
| `lightning_strike` | `attacker_id`, `target_id`, `position`, `damage`, `combo_index`, `kind` (`normal`, `counter`): the Dual Dagger finisher's bolt; draw it from the sky onto `position` |
| `lightning_blink` | `entity_id`, `from`, `to`, `direction_index` (0-7), `target_id`: Lightning Form teleport at a swing's start |
| `skill_started` | `entity_id`, `skill_id` (the press: the windup begins; Edge is spent) |
| `skill_released` | `attack_id`, `entity_id`, `skill_id`, `shape` (`arc`, `lane`, `projectile`), `position`, `direction`, `start`, `end`, `width` (the attack exists from this tick: the first `skill_active` tick; use it for effects and audio) |
| `dash_ready` | `entity_id` |
| `damage_taken` | `entity_id`, `amount`, `source_id` |
| `entity_died` | `entity_id`, `visual_id` |
| `boss_phase_changed` | `entity_id`, `phase` |
| `game_result` | `result` |

Planned, not yet implemented: `aspect_dropped`, `artifact_dropped`, `quest_updated`, `dialogue_requested`, `entity_spawned`.

## Tuning

Every gameplay number lives in `core/tuning.gd` (parry window, dash i-frames, boss timings, damage). The human tunes feel there after playtesting; tests read the same constants, so they follow the tuning.

## Save system (later)

`core/` owns save/load. Saves are plain data (JSON or `Resource`) of core state only; no presentation state.

## Open questions (to resolve with playtesting and the next slice)

- Do telegraph shapes need richer geometry (moving projectiles, sweeps over time, multi-segment beams)?
- Interpolation: does presentation smooth between ticks, or draw each tick as-is at 60 Hz?
- How generous should the parry window feel (design question): `PARRY_ACTIVE_TICKS` 14, `PARRY_PERFECT_TICKS` 6 are first guesses.
- Dialogue and quest data format (owned by core, authored by the human).
- Bow and staff need per-weapon intents (`attack_held` for draw, placed sigils); not designed yet.


### Boss difficulty playtest update (2026-10-16)

Human requested a harder boss and a parryable sweep. `red_sweep` retains its identifier for frame/test compatibility, but its telegraph `kind` is now `gold`; always use `kind` for warning colour and parry eligibility. Geometry and windup are unchanged. Both early and perfect parries work. Other red attacks remain dodge-only. Presentation recolours reserved red effect pixels to gold for this sweep without editing generated art.

Current tuning: boss HP 380, approach speed 0.5 px/tick, initial delay 60 ticks, phase cooldowns 40/24 ticks, posture-break opening 60 ticks. Recovery ticks: slam 26, sweep 24, shards 22, stomp 28, combo 30, charge 34. These replace the earlier longer pauses; windups, damage and player windows are unchanged. Perfect parry still instantly breaks posture. Human must playtest difficulty and feel.
