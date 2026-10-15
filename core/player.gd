extends RefCounted
## Player simulation (sword). No rendering. Positions in pixels, times in ticks.

const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")

const VISUAL_ID: StringName = &"totoy"
const STATE_IDLE: StringName = &"idle"
const STATE_WALK: StringName = &"walk"
const STATE_DASH: StringName = &"dash"
const STATE_PARRY: StringName = &"parry"
const STATE_PARRY_RECOVERY: StringName = &"parry_recovery"
const STATE_ATTACK_WINDUP: StringName = &"attack_windup"
const STATE_ATTACK_ACTIVE: StringName = &"attack_active"
const STATE_ATTACK_RECOVERY: StringName = &"attack_recovery"
const STATE_DEAD: StringName = &"dead"

var id: int = 1
var position: Vector2 = Tuning.PLAYER_START
var facing: Vector2 = Vector2.RIGHT
var hp: int = Tuning.PLAYER_MAX_HP
var state: StringName = STATE_IDLE
var state_ticks: int = 0
var dash_cooldown: int = 0
var edge: float = 0.0
var attack_hit_done: bool = false

var _dash_dir: Vector2 = Vector2.RIGHT
var _hurt_invuln: int = 0
var _dash_invuln: int = 0  # dash i-frames run on their own counter, so a short dash can keep a forgiving window


func step(input: InputFrame, tick: int, events: Array[GameEvent]) -> void:
	if state == STATE_DEAD:
		return
	state_ticks += 1
	if _hurt_invuln > 0:
		_hurt_invuln -= 1
	if _dash_invuln > 0:
		_dash_invuln -= 1
	if dash_cooldown > 0:
		dash_cooldown -= 1
		if dash_cooldown == 0:
			events.append(GameEvent.new(GameEvent.DASH_READY, tick, {"entity_id": id}))
	var move: Vector2 = input.move.limit_length(1.0)
	if input.aim.length_squared() > 0.0001:
		facing = input.aim.normalized()
	elif move.length_squared() > 0.0001:
		facing = move.normalized()

	match state:
		STATE_IDLE, STATE_WALK:
			if _try_actions(input, move, tick, events, true):
				return
			position += move * Tuning.PLAYER_SPEED
			_set_state(STATE_WALK if move.length_squared() > 0.0001 else STATE_IDLE)
		STATE_DASH:
			position += _dash_dir * Tuning.DASH_SPEED
			if state_ticks >= Tuning.DASH_TICKS:
				_set_state(STATE_IDLE)
		STATE_PARRY:
			if input.dash_pressed and dash_cooldown == 0:
				_start_dash(move, tick, events)
			elif state_ticks >= Tuning.PARRY_ACTIVE_TICKS:
				events.append(GameEvent.new(GameEvent.PARRY_FAILED, tick, {"entity_id": id, "reason": &"whiff"}))
				_set_state(STATE_PARRY_RECOVERY)
		STATE_PARRY_RECOVERY:
			position += move * Tuning.PLAYER_SPEED * Tuning.PARRY_RECOVERY_MOVE_FACTOR
			if state_ticks >= Tuning.PARRY_WHIFF_RECOVERY_TICKS:
				_set_state(STATE_IDLE)
		STATE_ATTACK_WINDUP:
			position += move * Tuning.PLAYER_SPEED * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= Tuning.ATTACK_WINDUP_TICKS:
				_set_state(STATE_ATTACK_ACTIVE)
		STATE_ATTACK_ACTIVE:
			position += move * Tuning.PLAYER_SPEED * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= Tuning.ATTACK_ACTIVE_TICKS:
				_set_state(STATE_ATTACK_RECOVERY)
		STATE_ATTACK_RECOVERY:
			if _try_actions(input, move, tick, events, false):
				return
			position += move * Tuning.PLAYER_SPEED * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= Tuning.ATTACK_RECOVERY_TICKS:
				_set_state(STATE_IDLE)


## Ticks since the parry press, or -1 when not parrying. 0 on the tick of the press.
func parry_ticks_since_press() -> int:
	return state_ticks if state == STATE_PARRY else -1


func is_invulnerable() -> bool:
	if state == STATE_DEAD:
		return false
	return _dash_invuln > 0 or _hurt_invuln > 0


## Returns true when the damage was applied (false while invulnerable or dead).
func take_damage(amount: int, tick: int, events: Array[GameEvent], source_id: int) -> bool:
	if state == STATE_DEAD or is_invulnerable():
		return false
	hp = maxi(0, hp - amount)
	_hurt_invuln = Tuning.PLAYER_HURT_INVULN_TICKS
	events.append(GameEvent.new(GameEvent.DAMAGE_TAKEN, tick, {"entity_id": id, "amount": amount, "source_id": source_id}))
	if hp == 0:
		state = STATE_DEAD
		state_ticks = 0
		events.append(GameEvent.new(GameEvent.ENTITY_DIED, tick, {"entity_id": id, "visual_id": VISUAL_ID}))
	elif state != STATE_DASH:
		_set_state(STATE_IDLE)  # a hit interrupts attacks and parries
	return true


## A gold hit was parried: build Edge and take a short riposte step toward the attacker.
func on_parry_success(toward: Vector2) -> void:
	edge = minf(Tuning.EDGE_MAX, edge + Tuning.EDGE_PER_PARRY)
	if toward.length_squared() > 0.0001:
		position += toward.normalized() * Tuning.RIPOSTE_STEP
	_set_state(STATE_IDLE)


func _try_actions(input: InputFrame, move: Vector2, tick: int, events: Array[GameEvent], allow_attack: bool) -> bool:
	if input.dash_pressed and dash_cooldown == 0:
		_start_dash(move, tick, events)
		return true
	if input.parry_pressed:
		_set_state(STATE_PARRY)
		return true
	if allow_attack and input.attack_pressed:
		attack_hit_done = false
		_set_state(STATE_ATTACK_WINDUP)
		return true
	return false


func _start_dash(move: Vector2, tick: int, events: Array[GameEvent]) -> void:
	_dash_dir = move.normalized() if move.length_squared() > 0.0001 else facing
	dash_cooldown = Tuning.DASH_COOLDOWN_TICKS
	_dash_invuln = Tuning.DASH_INVULN_TICKS
	_set_state(STATE_DASH)
	events.append(GameEvent.new(GameEvent.DASH_STARTED, tick, {"entity_id": id, "direction": _dash_dir}))


func _set_state(new_state: StringName) -> void:
	if state != new_state:
		state = new_state
		state_ticks = 0
