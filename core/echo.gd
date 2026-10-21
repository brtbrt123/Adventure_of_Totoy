extends RefCounted
## An Echo Step anchor placed by the player: a world object owned by the core. It does not block movement. The player
## is pulled back to it ECHO_STEP_DELAY_TICKS after the placement (later if a barrage or coil still runs then).

const Tuning := preload("res://core/tuning.gd")

var id: int = 0
var owner_id: int = 0
var position: Vector2 = Vector2.ZERO  # the validated spot (in the arena, out of props) the player returns to
var placed_tick: int = 0


## The tick the recall is due (it happens on this tick unless a barrage or coil is still running).
func due_tick() -> int:
	return placed_tick + Tuning.ECHO_STEP_DELAY_TICKS
