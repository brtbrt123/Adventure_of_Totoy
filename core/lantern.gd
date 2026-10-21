extends RefCounted
## A Spirit Lantern placed by the player: a world object owned by the core. It does not block movement. It pulses
## every SPIRIT_LANTERN_PULSE_INTERVAL_TICKS after its placement and expires right after its last pulse.

const Tuning := preload("res://core/tuning.gd")

var id: int = 0
var owner_id: int = 0
var position: Vector2 = Vector2.ZERO
var radius: float = Tuning.SPIRIT_LANTERN_RADIUS
var placed_tick: int = 0
var pulses_done: int = 0  # pulses so far (0-5)


## The tick of its last pulse, which is also its last tick.
func end_tick() -> int:
	return placed_tick + Tuning.SPIRIT_LANTERN_DURATION_TICKS


## The tick of pulse `k` (1-based).
func pulse_tick(k: int) -> int:
	return placed_tick + k * Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS


## True when a point (the player's centre) is in the light: distance to the lantern <= radius.
func covers(point: Vector2) -> bool:
	return point.distance_to(position) <= radius
