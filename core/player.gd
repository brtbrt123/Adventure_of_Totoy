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
const STATE_SKILL_WINDUP: StringName = &"skill_windup"
const STATE_SKILL_ACTIVE: StringName = &"skill_active"
const STATE_SKILL_RECOVERY: StringName = &"skill_recovery"
const STATE_DEAD: StringName = &"dead"

## skill_pressed 1, 2, 3 select these (test bindings Z, X, C).
const SKILL_BREAKING_EDGE: StringName = &"breaking_edge"
const SKILL_GALE_CUT: StringName = &"gale_cut"
const SKILL_MOON_CLEAVE: StringName = &"moon_cleave"
const SKILL_IDS: Array[StringName] = [SKILL_BREAKING_EDGE, SKILL_GALE_CUT, SKILL_MOON_CLEAVE]

var id: int = 1
var position: Vector2 = Tuning.PLAYER_START
var facing: Vector2 = Vector2.RIGHT
var hp: int = Tuning.PLAYER_MAX_HP
var state: StringName = STATE_IDLE
var state_ticks: int = 0
var dash_cooldown: int = 0
var edge: float = 0.0
var attack_hit_done: bool = false  # one hit per swing: set when a swing connects, cleared when the next swing starts
var skill_id: StringName = &""  # the skill in progress during skill_* states, empty otherwise
var skill_cooldowns: Array[int] = [0, 0, 0]  # ticks left per skill 1-3
var retaliate_ticks: int = 0  # Breaking Edge is usable while this is above zero (set by a successful parry)
var combo_index: int = 1  # swing in progress (or the last swing during the chain grace window); 1 otherwise

var _dash_dir: Vector2 = Vector2.RIGHT
var _combo_queued: bool = false
var _skill_dir: Vector2 = Vector2.RIGHT
var _combo_grace: int = 0  # ticks left in which a press after a finished swing still continues the chain
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
	for i: int in skill_cooldowns.size():
		if skill_cooldowns[i] > 0:
			skill_cooldowns[i] -= 1
	if retaliate_ticks > 0:
		retaliate_ticks -= 1
	if dash_cooldown > 0:
		dash_cooldown -= 1
		if dash_cooldown == 0:
			events.append(GameEvent.new(GameEvent.DASH_READY, tick, {"entity_id": id}))
	if _combo_grace > 0:
		_combo_grace -= 1
		if _combo_grace == 0:
			combo_index = 1
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
			if state_ticks >= Tuning.SWING_WINDUP_TICKS[combo_index - 1]:
				_set_state(STATE_ATTACK_ACTIVE)
		STATE_ATTACK_ACTIVE:
			position += move * Tuning.PLAYER_SPEED * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= Tuning.SWING_ACTIVE_TICKS[combo_index - 1]:
				_set_state(STATE_ATTACK_RECOVERY)
		STATE_SKILL_WINDUP:
			match skill_id:
				SKILL_BREAKING_EDGE:
					position += _skill_dir * (Tuning.BREAKING_EDGE_STEP / Tuning.BREAKING_EDGE_WINDUP_TICKS)
				SKILL_GALE_CUT:
					position += _skill_dir * Tuning.GALE_CUT_SPEED
				SKILL_MOON_CLEAVE:
					position += move * Tuning.PLAYER_SPEED * Tuning.MOON_CLEAVE_WINDUP_MOVE_FACTOR
			if state_ticks >= _skill_ticks("windup"):
				_set_state(STATE_SKILL_ACTIVE)
		STATE_SKILL_ACTIVE:
			if state_ticks >= _skill_ticks("active"):
				_set_state(STATE_SKILL_RECOVERY)
		STATE_SKILL_RECOVERY:
			if state_ticks >= _skill_ticks("recovery"):
				_set_state(STATE_IDLE)
		STATE_ATTACK_RECOVERY:
			if _try_actions(input, move, tick, events, false):
				return
			var recovery: int = Tuning.SWING_RECOVERY_TICKS[combo_index - 1]
			if input.attack_pressed and state_ticks >= recovery - Tuning.COMBO_BUFFER_TICKS:
				_combo_queued = true
			position += move * Tuning.PLAYER_SPEED * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= recovery:
				if _combo_queued:
					_start_swing(combo_index + 1 if combo_index < Tuning.COMBO_MAX else 1)
				else:
					_finish_combo_swing()


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
	reset_combo()
	retaliate_ticks = 0
	_hurt_invuln = Tuning.PLAYER_HURT_INVULN_TICKS
	events.append(GameEvent.new(GameEvent.DAMAGE_TAKEN, tick, {"entity_id": id, "amount": amount, "source_id": source_id}))
	if hp == 0:
		state = STATE_DEAD
		state_ticks = 0
		skill_id = &""
		events.append(GameEvent.new(GameEvent.ENTITY_DIED, tick, {"entity_id": id, "visual_id": VISUAL_ID}))
	elif state != STATE_DASH:
		_set_state(STATE_IDLE)  # a hit interrupts attacks and parries
	return true


## A gold hit was parried: build Edge and take a short riposte step toward the attacker.
func on_parry_success(toward: Vector2) -> void:
	edge = minf(Tuning.EDGE_MAX, edge + Tuning.EDGE_PER_PARRY)
	reset_combo()
	retaliate_ticks = Tuning.BREAKING_EDGE_WINDOW_TICKS
	if toward.length_squared() > 0.0001:
		position += toward.normalized() * Tuning.RIPOSTE_STEP
	_set_state(STATE_IDLE)


func _try_actions(input: InputFrame, move: Vector2, tick: int, events: Array[GameEvent], allow_attack: bool) -> bool:
	if input.dash_pressed and dash_cooldown == 0:
		_start_dash(move, tick, events)
		return true
	if input.parry_pressed:
		reset_combo()
		_set_state(STATE_PARRY)
		return true
	if _try_skill(input, tick, events):
		return true
	if allow_attack and input.attack_pressed:
		var chaining: bool = _combo_grace > 0 and combo_index < Tuning.COMBO_MAX
		_start_swing(combo_index + 1 if chaining else 1)
		return true
	return false


## Starts the skill chosen by input.skill_pressed (1-3) when it is allowed: off cooldown, enough Edge, and for
## Breaking Edge inside the retaliation window after a successful parry.
func _try_skill(input: InputFrame, tick: int, events: Array[GameEvent]) -> bool:
	var slot: int = input.skill_pressed
	if slot < 1 or slot > Tuning.SKILL_COUNT or skill_cooldowns[slot - 1] > 0:
		return false
	var chosen: StringName = SKILL_IDS[slot - 1]
	var cost: float = 0.0
	var cooldown: int = 0
	match chosen:
		SKILL_BREAKING_EDGE:
			if retaliate_ticks <= 0:
				return false
			cost = Tuning.BREAKING_EDGE_EDGE_COST
		SKILL_GALE_CUT:
			cost = Tuning.GALE_CUT_EDGE_COST
			cooldown = Tuning.GALE_CUT_COOLDOWN_TICKS
		SKILL_MOON_CLEAVE:
			cost = Tuning.MOON_CLEAVE_EDGE_COST
			cooldown = Tuning.MOON_CLEAVE_COOLDOWN_TICKS
	if edge < cost:
		return false
	edge -= cost
	skill_cooldowns[slot - 1] = cooldown
	skill_id = chosen
	_skill_dir = facing
	attack_hit_done = false
	retaliate_ticks = 0
	reset_combo()
	_set_state(STATE_SKILL_WINDUP)
	events.append(GameEvent.new(GameEvent.SKILL_STARTED, tick, {"entity_id": id, "skill_id": chosen}))
	return true


func _skill_ticks(phase: String) -> int:
	match skill_id:
		SKILL_BREAKING_EDGE:
			return {"windup": Tuning.BREAKING_EDGE_WINDUP_TICKS, "active": Tuning.BREAKING_EDGE_ACTIVE_TICKS, "recovery": Tuning.BREAKING_EDGE_RECOVERY_TICKS}[phase]
		SKILL_GALE_CUT:
			return {"windup": Tuning.GALE_CUT_WINDUP_TICKS, "active": Tuning.GALE_CUT_ACTIVE_TICKS, "recovery": Tuning.GALE_CUT_RECOVERY_TICKS}[phase]
		_:
			return {"windup": Tuning.MOON_CLEAVE_WINDUP_TICKS, "active": Tuning.MOON_CLEAVE_ACTIVE_TICKS, "recovery": Tuning.MOON_CLEAVE_RECOVERY_TICKS}[phase]


## Hit parameters of the skill in progress (used by the core's hit resolution).
func skill_profile() -> Dictionary:
	match skill_id:
		SKILL_BREAKING_EDGE:
			return {"range": Tuning.BREAKING_EDGE_RANGE, "arc_dot": Tuning.BREAKING_EDGE_ARC_DOT, "damage": Tuning.BREAKING_EDGE_DAMAGE, "posture": Tuning.BREAKING_EDGE_POSTURE, "edge_gain": Tuning.BREAKING_EDGE_EDGE_GAIN}
		SKILL_GALE_CUT:
			return {"range": Tuning.GALE_CUT_RANGE, "arc_dot": Tuning.GALE_CUT_ARC_DOT, "damage": Tuning.GALE_CUT_DAMAGE, "posture": Tuning.GALE_CUT_POSTURE, "edge_gain": Tuning.GALE_CUT_EDGE_GAIN}
		_:
			return {"range": Tuning.MOON_CLEAVE_RANGE, "arc_dot": Tuning.MOON_CLEAVE_ARC_DOT, "damage": Tuning.MOON_CLEAVE_DAMAGE, "posture": Tuning.MOON_CLEAVE_POSTURE, "edge_gain": Tuning.MOON_CLEAVE_EDGE_GAIN}


func _start_swing(index: int) -> void:
	combo_index = index
	attack_hit_done = false
	_combo_queued = false
	_combo_grace = 0
	_set_state(STATE_ATTACK_WINDUP)


## A swing ran out without a buffered press. After the finisher the combo is over; otherwise a late press
## still counts for COMBO_GRACE_TICKS.
func _finish_combo_swing() -> void:
	if combo_index >= Tuning.COMBO_MAX:
		reset_combo()
	else:
		_combo_grace = Tuning.COMBO_GRACE_TICKS
	_set_state(STATE_IDLE)


## Back to swing 1 with nothing buffered (damage, dash, parry, death, or the chain ran out).
func reset_combo() -> void:
	combo_index = 1
	_combo_queued = false
	_combo_grace = 0


func _start_dash(move: Vector2, tick: int, events: Array[GameEvent]) -> void:
	_dash_dir = move.normalized() if move.length_squared() > 0.0001 else facing
	dash_cooldown = Tuning.DASH_COOLDOWN_TICKS
	_dash_invuln = Tuning.DASH_INVULN_TICKS
	reset_combo()
	_set_state(STATE_DASH)
	events.append(GameEvent.new(GameEvent.DASH_STARTED, tick, {"entity_id": id, "direction": _dash_dir}))


func _set_state(new_state: StringName) -> void:
	if state != new_state:
		state = new_state
		state_ticks = 0
		if new_state != STATE_SKILL_WINDUP and new_state != STATE_SKILL_ACTIVE and new_state != STATE_SKILL_RECOVERY:
			skill_id = &""
