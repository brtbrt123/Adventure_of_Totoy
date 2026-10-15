# Architecture: core / presentation interface

Status: **first draft**, written before any gameplay code. It will change once the combat vertical slice (Mossbound Colossus) shows what is really needed. Changes go through Claude Code (owner of `core/` and this file); Codex builds against it and reports gaps in task notes.

## Principles

1. `core/` has no rendering, UI or audio code and runs headless. `presentation/` has no game rules.
2. **The core decides, presentation draws.** Hits, damage, parry timing, posture and cooldowns are core results. Presentation never recomputes them.
3. **Fair tells (from the game design):** every attack's warning area is produced by the core as the *same geometry* that later applies damage. Presentation draws that geometry; it never invents its own.
4. Presentation sends *intents*, not key presses. Mapping keyboard/controller to intents lives in `presentation/`.
5. Communication goes one way per channel: input intents in, snapshot and events out. No layer calls into the other's internals.

## Time

The core runs on a **fixed tick of 60 Hz** (`TICK_DT = 1.0 / 60.0`), advanced by presentation (`core.step(input)` once per physics tick). Times in the interface are measured in ticks (`int`) so results are deterministic and testable; presentation converts to seconds for effects. Randomness uses a seeded RNG owned by the core.

## Channel 1: input intents (presentation to core)

One `InputFrame` per tick (a small typed `RefCounted` or `Resource` in `core/`):

| Field | Type | Meaning |
|---|---|---|
| `move` | `Vector2` | desired move direction, length 0..1 |
| `aim` | `Vector2` | aim direction (bow/staff), zero if none |
| `attack_pressed` / `attack_held` | `bool` | normal attack / draw / cast |
| `parry_pressed` | `bool` | parry (gold) |
| `dash_pressed` | `bool` | dash |
| `skill_pressed` | `int` | Aspect slot 1 or 2, else 0 |
| `interact_pressed` | `bool` | talk, open, checkpoint |

## Channel 2: read-only state snapshot (core to presentation)

`core.snapshot()` returns a `GameSnapshot`: an immutable view, rebuilt or copy-on-write each tick. Presentation must not mutate it or keep references to core objects.

- `tick: int`
- `player: EntitySnapshot`, `entities: Array[EntitySnapshot]`
- `telegraphs: Array[TelegraphSnapshot]` (active warnings)
- `hud: HudSnapshot` (health, focus meter, dash cooldown remaining, equipped weapon/Aspects, quest line)

`EntitySnapshot`: `id: int`, `visual_id: StringName` (maps to art, for example `&"totoy"`, `&"mossbound_colossus"`), `state: StringName` (for example `idle`, `walk`, `dash`, `parry`, `windup_gold`, `windup_red`, `posture_broken`, `dead`), `state_ticks: int`, `position: Vector2` (pixels), `facing: Vector2`, `hp: int`, `max_hp: int`, `posture: float`, `posture_max: float`, `invulnerable: bool`.

`TelegraphSnapshot`: `id: int`, `owner_id: int`, `kind: StringName` (`gold` for a parry-able heavy attack, `red` for a dodge-only attack), `shape: StringName` (`circle`, `cone`, `rect`, `line`), `geometry: PackedVector2Array` or shape parameters, `start_tick: int`, `hit_tick: int`, `end_tick: int`. The warning area equals the hit area.

**Art contract:** presentation picks a frame from `art/build/sprites.json` using `<visual_id>_<state>_<direction>[_<frame>]` (see `AGENTS.md` section 5). A missing frame falls back to a visible placeholder and logs a warning; it never crashes.

## Channel 3: events (core to presentation)

Signals on a single `GameEvents` emitter (or an array drained once per tick). Events are facts that already happened; presentation reacts with sound, particles, screen shake and UI. They carry no rules.

| Event | Payload |
|---|---|
| `attack_telegraphed` | telegraph id, kind, owner id |
| `attack_hit` | attacker id, target id, damage, kind, position |
| `parry_succeeded` | player id, attacker id, quality (`perfect`, `early`), position |
| `parry_failed` | player id, reason |
| `posture_broken` | entity id, window length in ticks |
| `counter_window_opened` / `counter_window_closed` | entity id |
| `dash_started` / `dash_ready` | entity id, direction |
| `damage_taken` | entity id, amount, source id |
| `entity_spawned` / `entity_died` | entity id, visual id |
| `boss_phase_changed` | entity id, phase |
| `aspect_dropped` / `artifact_dropped` | item id |
| `quest_updated` | quest id, step |
| `dialogue_requested` | speaker id, line id |

## Save system (later)

`core/` owns save/load. Saves are plain data (JSON or `Resource`) of core state only; no presentation state.

## Open questions (to resolve with the vertical slice)

- Do telegraph shapes need richer geometry (arcs, sweeps over time, multi-segment beams)?
- Do events need to be queued per tick for replay and tests, or are signals enough?
- Interpolation: does presentation smooth between ticks, or draw each tick as-is at 60 Hz?
- Dialogue and quest data format (owned by core, authored by the human).
