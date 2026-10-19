extends RefCounted
## Player simulation (Black Katana or Dual Dagger). No rendering. Positions in pixels, times in ticks.

const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Weapons := preload("res://core/weapons.gd")

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
var weapon_id: StringName = Tuning.WEAPON_BLACK_KATANA  # the equipped weapon (black_katana or dual_dagger)
var buff_ticks: int = 0  # weapon buff / form ticks left (0 = not active); always the equipped weapon's (no swap while it runs)
## Ticks until each weapon's active can be used again, per weapon id. They all count down, equipped or not.
var active_cooldowns: Dictionary[StringName, int] = {}
## The equipped weapon's active cooldown (reads and writes its entry in active_cooldowns).
var buff_cooldown: int:
	get:
		return active_cooldowns.get(weapon_id, 0)
	set(value):
		active_cooldowns[weapon_id] = value
var swap_lockout: int = 0  # ticks until the next weapon swap is allowed
var blink_requested: bool = false  # set when a swing starts during Lightning Form; the core reads and clears it
var blink_count: int = 0  # blinks since the current Lightning Form started (picks the side from LIGHTNING_BLINK_ORDER)
var last_blink_direction: int = -1  # direction index (0-7) of the latest blink, -1 before the first
var last_blink_tick: int = -1
var last_blink_from: Vector2 = Vector2.ZERO
var last_blink_to: Vector2 = Vector2.ZERO
var swing_speed_mult: float = 1.0  # locked at the start of each swing
var swing_damage_mult: float = 1.0  # locked at the start of each swing
var skill_id: StringName = &""  # the skill in progress during skill_* states, empty otherwise
var skill_cooldowns: Array[int] = [0, 0, 0]  # ticks left per skill 1-3
var retaliate_ticks: int = 0  # Breaking Edge is usable while this is above zero (set by a successful parry)
var skill_dir: Vector2 = Vector2.RIGHT  # direction fixed when the skill was pressed
var skill_motion: bool = false  # true on a tick in which a skill moved the player (Gale Cut's dash)
var pending_release: StringName = &""  # set on the tick a skill enters skill_active; the core reads and clears it
var combo_index: int = 1  # swing in progress (or the last swing during the chain grace window); 1 otherwise

var _dash_dir: Vector2 = Vector2.RIGHT
var _combo_queued: bool = false
var _combo_grace: int = 0  # ticks left in which a press after a finished swing still continues the chain
var _hurt_invuln: int = 0
var _dash_invuln: int = 0  # dash i-frames run on their own counter, so a short dash can keep a forgiving window
var _blink_invuln: int = 0  # Lightning blink i-frames
var _facing_locked: bool = false  # a blink swing keeps facing the boss through its windup and active ticks


func step(input: InputFrame, tick: int, events: Array[GameEvent]) -> void:
	if state == STATE_DEAD:
		return
	state_ticks += 1
	skill_motion = false
	if _hurt_invuln > 0:
		_hurt_invuln -= 1
	if _dash_invuln > 0:
		_dash_invuln -= 1
	if _blink_invuln > 0:
		_blink_invuln -= 1
	if swap_lockout > 0:
		swap_lockout -= 1
	for weapon: StringName in active_cooldowns.keys():
		if active_cooldowns[weapon] > 0:
			active_cooldowns[weapon] -= 1
	if buff_ticks > 0:
		buff_ticks -= 1
		if buff_ticks == 0:
			_emit_buff_end(tick, events, &"expired")
	if input.weapon_swap_pressed:
		_try_weapon_swap(tick, events)
	if input.weapon_active_pressed:
		_try_weapon_active(tick, events)
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
	var locked: bool = _facing_locked and (state == STATE_ATTACK_WINDUP or state == STATE_ATTACK_ACTIVE)
	if locked:
		pass
	elif input.aim.length_squared() > 0.0001:
		facing = input.aim.normalized()
	elif move.length_squared() > 0.0001:
		facing = move.normalized()
	var speed: float = Tuning.PLAYER_SPEED * move_speed_mult()

	match state:
		STATE_IDLE, STATE_WALK:
			if _try_actions(input, move, tick, events, true):
				return
			position += move * speed
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
			position += move * speed * Tuning.PARRY_RECOVERY_MOVE_FACTOR
			if state_ticks >= Tuning.PARRY_WHIFF_RECOVERY_TICKS:
				_set_state(STATE_IDLE)
		STATE_ATTACK_WINDUP:
			position += move * speed * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= _swing_ticks(0):
				_set_state(STATE_ATTACK_ACTIVE)
		STATE_ATTACK_ACTIVE:
			position += move * speed * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= _swing_ticks(1):
				_set_state(STATE_ATTACK_RECOVERY)
		STATE_SKILL_WINDUP:
			match skill_id:
				SKILL_BREAKING_EDGE:
					position += skill_dir * (Tuning.BREAKING_EDGE_STEP / Tuning.BREAKING_EDGE_WINDUP_TICKS)
				SKILL_MOON_CLEAVE:
					position += move * speed * Tuning.MOON_CLEAVE_WINDUP_MOVE_FACTOR
			if state_ticks >= _skill_ticks("windup"):
				_set_state(STATE_SKILL_ACTIVE)
				pending_release = skill_id
		STATE_SKILL_ACTIVE:
			if skill_id == SKILL_GALE_CUT:
				position += skill_dir * Tuning.GALE_CUT_SPEED
				skill_motion = true
			if state_ticks >= _skill_ticks("active"):
				_set_state(STATE_SKILL_RECOVERY)
		STATE_SKILL_RECOVERY:
			if state_ticks >= _skill_ticks("recovery"):
				_set_state(STATE_IDLE)
		STATE_ATTACK_RECOVERY:
			if _try_actions(input, move, tick, events, false):
				return
			var recovery: int = _swing_ticks(2)
			if input.attack_pressed and state_ticks >= recovery - Tuning.COMBO_BUFFER_TICKS:
				_combo_queued = true
			position += move * speed * Tuning.ATTACK_MOVE_FACTOR
			if state_ticks >= recovery:
				if _combo_queued:
					_start_swing(combo_index + 1 if combo_index < combo_max() else 1)
				else:
					_finish_combo_swing()


## Ticks since the parry press, or -1 when not parrying. 0 on the tick of the press.
func parry_ticks_since_press() -> int:
	return state_ticks if state == STATE_PARRY else -1


func is_invulnerable() -> bool:
	if state == STATE_DEAD:
		return false
	return _dash_invuln > 0 or _hurt_invuln > 0 or _blink_invuln > 0


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
		if buff_ticks > 0:
			buff_ticks = 0
			_emit_buff_end(tick, events, &"death")
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
		var chaining: bool = _combo_grace > 0 and combo_index < combo_max()
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
	skill_dir = _skill_direction(input)
	facing = skill_dir
	attack_hit_done = false
	pending_release = &""
	retaliate_ticks = 0
	reset_combo()
	_set_state(STATE_SKILL_WINDUP)
	events.append(GameEvent.new(GameEvent.SKILL_STARTED, tick, {"entity_id": id, "skill_id": chosen}))
	return true


## Where a skill goes: the way the player is moving, else the aim, else the way they already face.
func _skill_direction(input: InputFrame) -> Vector2:
	var move: Vector2 = input.move.limit_length(1.0)
	if move.length_squared() > 0.0001:
		return move.normalized()
	if input.aim.length_squared() > 0.0001:
		return input.aim.normalized()
	return facing


func _skill_ticks(phase: String) -> int:
	match skill_id:
		SKILL_BREAKING_EDGE:
			return {"windup": Tuning.BREAKING_EDGE_WINDUP_TICKS, "active": Tuning.BREAKING_EDGE_ACTIVE_TICKS, "recovery": Tuning.BREAKING_EDGE_RECOVERY_TICKS}[phase]
		SKILL_GALE_CUT:
			return {"windup": Tuning.GALE_CUT_WINDUP_TICKS, "active": Tuning.GALE_CUT_ACTIVE_TICKS, "recovery": Tuning.GALE_CUT_RECOVERY_TICKS}[phase]
		_:
			return {"windup": Tuning.MOON_CLEAVE_WINDUP_TICKS, "active": Tuning.MOON_CLEAVE_ACTIVE_TICKS, "recovery": Tuning.MOON_CLEAVE_RECOVERY_TICKS}[phase]


## Hit parameters of a skill (used by the core's hit resolution). The ids are the SKILL_* constants.
static func skill_profile(skill: StringName) -> Dictionary:
	match skill:
		SKILL_BREAKING_EDGE:
			return {"damage": Tuning.BREAKING_EDGE_DAMAGE, "posture": Tuning.BREAKING_EDGE_POSTURE, "edge_gain": Tuning.BREAKING_EDGE_EDGE_GAIN}
		SKILL_GALE_CUT:
			return {"damage": Tuning.GALE_CUT_DAMAGE, "posture": Tuning.GALE_CUT_POSTURE, "edge_gain": Tuning.GALE_CUT_EDGE_GAIN}
		_:
			return {"damage": Tuning.MOON_CLEAVE_DAMAGE, "posture": Tuning.MOON_CLEAVE_POSTURE, "edge_gain": Tuning.MOON_CLEAVE_EDGE_GAIN}


## The equipped weapon's active (right click): Black Katana buff or Dual Dagger Lightning Form. A timed buff (numbers
## per weapon in core/weapons.gd). It is a free action (no state change), costs Edge, has the weapon's own cooldown
## and cannot be refreshed while it is running. It lasts through movement, attacks, dashes, parries, skills and
## damage; it ends when it runs out or the player dies.
func _try_weapon_active(tick: int, events: Array[GameEvent]) -> bool:
	if not Weapons.has_active(weapon_id) or state == STATE_DEAD or buff_ticks > 0 or buff_cooldown > 0:
		return false
	var cost: float = Weapons.active_edge_cost(weapon_id)
	if edge < cost:
		return false
	edge -= cost
	buff_ticks = Weapons.active_duration(weapon_id)
	buff_cooldown = Weapons.active_cooldown(weapon_id)
	blink_count = 0
	events.append(GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, tick, {
		"entity_id": id, "weapon_id": weapon_id, "form": Weapons.active_form(weapon_id), "duration": buff_ticks,
		"attack_speed_mult": Weapons.active_attack_speed_mult(weapon_id), "damage_mult": Weapons.active_damage_mult(weapon_id),
		"move_speed_mult": Weapons.active_move_speed_mult(weapon_id),
	}))
	return true


## Q: swap to the next weapon. A free action from idle or walk only, never while a buff/form runs or during the
## swap lockout. The combo starts over; each weapon keeps its own active cooldown.
func _try_weapon_swap(tick: int, events: Array[GameEvent]) -> bool:
	if state != STATE_IDLE and state != STATE_WALK:
		return false
	if buff_ticks > 0 or swap_lockout > 0:
		return false
	var previous: StringName = weapon_id
	var target: StringName = Weapons.next(weapon_id)
	if target == previous:
		return false
	weapon_id = target
	swap_lockout = Tuning.WEAPON_SWAP_LOCKOUT_TICKS
	reset_combo()
	events.append(GameEvent.new(GameEvent.WEAPON_SWAPPED, tick, {"entity_id": id, "weapon_id": weapon_id, "previous_weapon_id": previous}))
	return true


func _emit_buff_end(tick: int, events: Array[GameEvent], reason: StringName) -> void:
	events.append(GameEvent.new(GameEvent.WEAPON_BUFF_ENDED, tick, {"entity_id": id, "weapon_id": weapon_id, "form": Weapons.active_form(weapon_id), "reason": reason}))


func is_buff_active() -> bool:
	return buff_ticks > 0


## True while the Dual Dagger's Lightning Form runs.
func is_lightning_form() -> bool:
	return buff_ticks > 0 and weapon_id == Tuning.WEAPON_DUAL_DAGGER


## The active form's id while it runs (black_katana_buff, lightning_form), else empty.
func active_form() -> StringName:
	return Weapons.active_form(weapon_id) if buff_ticks > 0 else &""


## Current attack speed multiplier (1.0 without the buff).
func attack_speed_mult() -> float:
	return Weapons.active_attack_speed_mult(weapon_id) if buff_ticks > 0 else 1.0


## Current damage multiplier (1.0 without the buff).
func damage_mult() -> float:
	return Weapons.active_damage_mult(weapon_id) if buff_ticks > 0 else 1.0


## Current walking speed multiplier (1.0 without the buff; Lightning Form is faster).
func move_speed_mult() -> float:
	return Weapons.active_move_speed_mult(weapon_id) if buff_ticks > 0 else 1.0


## Swings in the equipped weapon's combo (katana 3, dagger 4).
func combo_max() -> int:
	return Weapons.combo_max(weapon_id)


## The core found a blink spot for the swing that just started: move there, face the boss for this swing's windup and
## active ticks, and take the blink i-frames.
func apply_blink(to: Vector2, face: Vector2, direction_index: int, tick: int) -> void:
	last_blink_from = position
	last_blink_to = to
	last_blink_direction = direction_index
	last_blink_tick = tick
	position = to
	if face.length_squared() > 0.0001:
		facing = face.normalized()
	_facing_locked = true
	_blink_invuln = Tuning.LIGHTNING_BLINK_INVULN_TICKS


## A phase length in ticks at an attack speed: base / mult, rounded, at least 1.
static func scaled_ticks(base: int, mult: float) -> int:
	return maxi(1, roundi(float(base) / maxf(mult, 0.01)))


## Length of a phase of the swing in progress (0 windup, 1 active, 2 recovery) for the equipped weapon, using the
## speed locked at its start.
func _swing_ticks(phase: int) -> int:
	return scaled_ticks(Weapons.swing_phases(weapon_id, combo_index)[phase], swing_speed_mult)


func _start_swing(index: int) -> void:
	combo_index = index
	swing_speed_mult = attack_speed_mult()
	swing_damage_mult = damage_mult()
	attack_hit_done = false
	_combo_queued = false
	_combo_grace = 0
	_facing_locked = false
	blink_requested = is_lightning_form()
	_set_state(STATE_ATTACK_WINDUP)


## A swing ran out without a buffered press. After the finisher the combo is over; otherwise a late press
## still counts for COMBO_GRACE_TICKS.
func _finish_combo_swing() -> void:
	if combo_index >= combo_max():
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
