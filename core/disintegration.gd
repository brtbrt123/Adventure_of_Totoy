extends RefCounted
## Disintegration, the Star Staff's active, as a timeline both cores share (GameCore against the boss, ExploreSkills against
## mobs). The core starts it on the activation tick with the target it picked: a magic circle forms under the target (FORM),
## charges (CHARGE: the hero's cast, rooted and invulnerable, ends here), the meteor falls (FALL) and lands on the impact tick,
## then the blast and smoke play out (AFTER). The circle follows the target until DISINTEGRATION_LOCK_TICKS before the impact,
## then stays where it is; a target that falls or leaves before that leaves the circle where it last stood. On the impact tick
## the core hits everything within DISINTEGRATION_RADIUS (plus its radius) of `center`. No rendering: presentation draws the
## circle, the meteor and the blast from the snapshot (player.disintegration_*) and the disintegration_* events.
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")

const PHASE_FORM: StringName = &"form"
const PHASE_CHARGE: StringName = &"charge"
const PHASE_FALL: StringName = &"fall"
const PHASE_AFTER: StringName = &"after"

var running: bool = false
var target_id: int = -1
var center: Vector2 = Vector2.ZERO
var start_tick: int = 0


func start(tick: int, target: int, at: Vector2) -> void:
	running = true
	target_id = target
	center = at
	start_tick = tick


func stop() -> void:
	running = false
	target_id = -1


## Ticks since the activation (0 on the activation tick).
func elapsed(tick: int) -> int:
	return tick - start_tick


func cast_end_tick() -> int:
	return start_tick + Tuning.DISINTEGRATION_FORM_TICKS + Tuning.DISINTEGRATION_CHARGE_TICKS


func impact_tick() -> int:
	return start_tick + Weapons.disintegration_impact_ticks()


func lock_tick() -> int:
	return impact_tick() - Tuning.DISINTEGRATION_LOCK_TICKS


func end_tick() -> int:
	return start_tick + Weapons.disintegration_total_ticks()


func phase(tick: int) -> StringName:
	if not running:
		return &""
	var t: int = elapsed(tick)
	if t < Tuning.DISINTEGRATION_FORM_TICKS:
		return PHASE_FORM
	if tick < cast_end_tick():
		return PHASE_CHARGE
	if tick < impact_tick():
		return PHASE_FALL
	return PHASE_AFTER


## Before the lock the circle stays under the target (`at` is where it stands now, or null once it is gone).
func follow(tick: int, at: Variant) -> void:
	if at is Vector2 and tick < lock_tick():
		center = at
