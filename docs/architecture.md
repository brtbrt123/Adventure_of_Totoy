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
| `skill_pressed` | `int` | Aspect slot 1 or 2, else 0 (unused so far) |
| `interact_pressed` | `bool` | talk, open, checkpoint (unused so far) |

## Channel 2: read-only snapshot (core to presentation): `core/snapshots.gd`

`core.snapshot()` builds a new `Snapshots.GameSnapshot` each call; do not mutate it or keep references to core objects.

- `tick`, `result` (`playing`, `victory`, `defeat`)
- `player: EntitySnapshot`, `entities: Array[EntitySnapshot]` (the boss; more later)
- `telegraphs: Array[TelegraphSnapshot]`
- `hud: HudSnapshot`

`EntitySnapshot`: `id`, `visual_id` (`&"totoy"`, `&"mossbound_colossus"`), `state`, `state_ticks`, `position` (pixels), `facing`, `hp`, `max_hp`, `posture`, `posture_max`, `invulnerable`.

States: player `idle walk dash parry parry_recovery attack_windup attack_active attack_recovery dead`; boss `idle attack recover posture_broken dead`.

`TelegraphSnapshot`: `id`, `owner_id`, `attack` (`gold_slam`, `gold_combo`, `red_sweep`, `red_shards`, `red_stomp`, `red_charge`), `kind` (`gold` = parry it, `red` = dodge it), `shape` + parameters, `start_tick`, `hit_tick`, `end_tick`.
- `circle`: `center`, `size` = radius
- `cone`: `center` = origin, `direction`, `size` = radius, `half_angle` (radians)
- `line`: `center` = start, `direction`, `size` = length, `width`
- `ring`: `center`, `size` = outer radius, `inner_size` = inner radius; **the inside (closer than `inner_size`) is safe**, the band is dangerous, the outside is safe

Boss attacks: `gold_slam` (one parryable slam), `gold_combo` (two parryable slams, the second `COMBO_GAP_TICKS` after the first; a perfect parry on the first breaks posture and cancels the second; phase 2 only), `red_sweep` (cone), `red_shards` (three lines), `red_stomp` (ring), `red_charge` (a line; the boss body travels along it while it is dangerous, so the boss `position` in the snapshot moves from `hit_tick` to `end_tick`; phase 2 only). The attack frames presentation shows come from the telegraph `attack` name; a combo has two telegraphs with different `hit_tick`s.

The area is dangerous from `hit_tick` to `end_tick` inclusive; before that it is only a warning. Presentation draws the warning growing/filling toward `hit_tick` and may slow the visual for the final windup (the design's "final windup slows briefly").

`HudSnapshot`: `player_hp`, `player_max_hp`, `dash_cooldown_ticks`, `dash_cooldown_max`, `edge`, `edge_max`, `boss_hp`, `boss_max_hp`, `boss_posture`, `boss_posture_max`, `counter_window_ticks_left`.

**Art contract:** presentation picks a frame from `art/build/sprites.json` using `<visual_id>_<state>_<direction>_<n>` for characters and `<visual_id>_<state>_<n>` for the boss (see `AGENTS.md` section 5 and `presentation/arena/animation.gd`). A missing frame falls back to a visible placeholder and logs a warning; it never crashes.

## Channel 3: events (core to presentation): `core/game_event.gd`

Each event is a `GameEvent` with `type: StringName`, `tick: int` and `data: Dictionary`. They are available in `core.last_events` after each `step()` and as the `event_emitted` signal. Events are facts that already happened; presentation reacts with sound, particles, screen shake and UI. They carry no rules.

| Type | `data` keys |
|---|---|
| `attack_telegraphed` | `telegraph_id`, `owner_id`, `kind`, `attack` |
| `attack_hit` | `attacker_id`, `target_id`, `damage`, `kind` (`normal`, `counter`, `gold`, `red`), `position` |
| `parry_succeeded` | `player_id`, `attacker_id`, `telegraph_id`, `quality` (`perfect`, `early`), `position` |
| `parry_failed` | `entity_id`, `reason` (`whiff`) |
| `posture_broken` | `entity_id`, `window_ticks` |
| `counter_window_opened` / `counter_window_closed` | `entity_id` (+ `window_ticks` on open) |
| `dash_started` | `entity_id`, `direction` |
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
