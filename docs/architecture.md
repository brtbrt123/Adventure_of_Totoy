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
| `skill_pressed` | `int` | skill slot 1, 2 or 3 pressed this tick, else 0. Test bindings: Z = 1 Breaking Edge, X = 2 Gale Cut, C = 3 Moon Cleave (the key mapping is presentation's job) |
| `interact_pressed` | `bool` | talk, open, checkpoint (unused so far) |

## Channel 2: read-only snapshot (core to presentation): `core/snapshots.gd`

`core.snapshot()` builds a new `Snapshots.GameSnapshot` each call; do not mutate it or keep references to core objects.

- `tick`, `result` (`playing`, `victory`, `defeat`)
- `player: EntitySnapshot`, `entities: Array[EntitySnapshot]` (the boss; more later)
- `telegraphs: Array[TelegraphSnapshot]`
- `skill_attacks: Array[SkillAttackSnapshot]` (live skill attacks, see "Sword skills")
- `hud: HudSnapshot`

`EntitySnapshot`: `id`, `visual_id` (`&"totoy"`, `&"mossbound_colossus"`), `state`, `state_ticks`, `position` (pixels), `facing`, `hp`, `max_hp`, `posture`, `posture_max`, `invulnerable`, `combo_index` (player only, see the sword combo below; `0` for the boss), `skill_id` (player only: `breaking_edge`, `gale_cut` or `moon_cleave` during the `skill_*` states, otherwise empty).

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

`TelegraphSnapshot`: `id`, `owner_id`, `attack` (`gold_slam`, `gold_combo`, `red_sweep`, `red_shards`, `red_stomp`, `red_charge`), `kind` (`gold` = parry it, `red` = dodge it), `shape` + parameters, `start_tick`, `hit_tick`, `end_tick`.
- `circle`: `center`, `size` = radius
- `cone`: `center` = origin, `direction`, `size` = radius, `half_angle` (radians)
- `line`: `center` = start, `direction`, `size` = length, `width`
- `ring`: `center`, `size` = outer radius, `inner_size` = inner radius; **the inside (closer than `inner_size`) is safe**, the band is dangerous, the outside is safe

Boss attacks: `gold_slam` (one parryable slam), `gold_combo` (two parryable slams, the second `COMBO_GAP_TICKS` after the first; a perfect parry on the first breaks posture and cancels the second; phase 2 only), `red_sweep` (legacy attack identifier; gold parryable cone), `red_shards` (three lines), `red_stomp` (ring), `red_charge` (a line; the boss body travels along it while it is dangerous, so the boss `position` in the snapshot moves from `hit_tick` to `end_tick`; phase 2 only). The attack frames presentation shows come from the telegraph `attack` name; a combo has two telegraphs with different `hit_tick`s.

The area is dangerous from `hit_tick` to `end_tick` inclusive; before that it is only a warning. Presentation draws the warning growing/filling toward `hit_tick` and may slow the visual for the final windup (the design's "final windup slows briefly").

`HudSnapshot`: `player_hp`, `player_max_hp`, `dash_cooldown_ticks`, `dash_cooldown_max`, `edge`, `edge_max`, `boss_hp`, `boss_max_hp`, `boss_posture`, `boss_posture_max`, `counter_window_ticks_left`, `skill_cooldown_ticks` (array of 3, ticks left per slot), `retaliate_ticks_left` (Breaking Edge is usable while this is above 0).

**Art contract:** presentation picks a frame from `art/build/sprites.json` using `<visual_id>_<state>_<direction>_<n>` for characters and `<visual_id>_<state>_<n>` for the boss (see `AGENTS.md` section 5 and `presentation/arena/animation.gd`). A missing frame falls back to a visible placeholder and logs a warning; it never crashes.

## Channel 3: events (core to presentation): `core/game_event.gd`

Each event is a `GameEvent` with `type: StringName`, `tick: int` and `data: Dictionary`. They are available in `core.last_events` after each `step()` and as the `event_emitted` signal. Events are facts that already happened; presentation reacts with sound, particles, screen shake and UI. They carry no rules.

| Type | `data` keys |
|---|---|
| `attack_telegraphed` | `telegraph_id`, `owner_id`, `kind`, `attack` |
| `attack_hit` | `attacker_id`, `target_id`, `damage`, `kind` (`normal`, `counter`, `gold`, `red`), `position`, and for the player's sword `combo_index` (1-3); a skill hit has `skill_id` and `attack_id` instead (no `combo_index`) |
| `parry_succeeded` | `player_id`, `attacker_id`, `telegraph_id`, `quality` (`perfect`, `early`), `position` |
| `parry_failed` | `entity_id`, `reason` (`whiff`) |
| `posture_broken` | `entity_id`, `window_ticks` |
| `counter_window_opened` / `counter_window_closed` | `entity_id` (+ `window_ticks` on open) |
| `dash_started` | `entity_id`, `direction` |
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
