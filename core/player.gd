extends RefCounted
## Player simulation (Black Katana, Dual Dagger or Chain Scythe). No rendering. Positions in pixels, times in ticks.

const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Weapons := preload("res://core/weapons.gd")
const Aspects := preload("res://core/aspects.gd")

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
## The automatic Lightning Barrage (Dual Dagger active): the core moves the player and lands the slashes.
const STATE_LIGHTNING_BARRAGE: StringName = &"lightning_barrage"
## Reaper's Coil (Chain Scythe active): the core runs the hook, drag, spin or pull; no movement, no actions.
const STATE_REAPER_COIL: StringName = &"reaper_coil"
const STATE_DEAD: StringName = &"dead"

## Reaper's Coil phases (snapshot.player.reaper_coil_phase).
const COIL_HOOK: StringName = &"hook"
const COIL_DRAG: StringName = &"drag"
const COIL_SPIN: StringName = &"spin"
const COIL_PULL: StringName = &"pull"
const COIL_RECOVERY: StringName = &"recovery"

## The aspects (skills). skill_pressed 1, 2, 3 (test bindings Z, X, C) trigger the aspect in that slot of
## equipped_aspects; the ids are core/aspects.gd's.
const SKILL_BREAKING_EDGE: StringName = Aspects.BREAKING_EDGE
const SKILL_GALE_CUT: StringName = Aspects.GALE_CUT
const SKILL_MOON_CLEAVE: StringName = Aspects.MOON_CLEAVE
const SKILL_SPIRIT_LANTERN: StringName = Aspects.SPIRIT_LANTERN
const SKILL_PHANTOM_CUT: StringName = Aspects.PHANTOM_CUT
## The default slotting (before 2026-10-21 the only one).
const SKILL_IDS: Array[StringName] = Aspects.DEFAULT_EQUIPPED

var id: int = 1
var position: Vector2 = Tuning.PLAYER_START
var facing: Vector2 = Vector2.RIGHT
var hp: int = Tuning.PLAYER_MAX_HP
var state: StringName = STATE_IDLE
var state_ticks: int = 0
var dash_cooldown: int = 0
var edge: float = 0.0
var attack_hit_done: bool = false  # one hit per swing: set when a swing connects, cleared when the next swing starts
var weapon_id: StringName = Tuning.WEAPON_BLACK_KATANA  # the equipped weapon (black_katana, dual_dagger or chain_scythe)
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
var last_blink_direction: int = -1  # direction index (0-7) of the latest blink, -1 before the first
var last_blink_tick: int = -1
var last_blink_from: Vector2 = Vector2.ZERO
var last_blink_to: Vector2 = Vector2.ZERO
## Set by the core before each step: Lightning Form (only the barrage) can be activated only while the boss is alive.
var barrage_target_alive: bool = true
var barrage_requested: bool = false  # set when an active with a barrage starts; the core reads and clears it
var barrage_running: bool = false
var barrage_slash: int = 0  # slashes of the running barrage started so far (1-8 once the first one blinked)
var barrage_slash_tick: int = -1  # tick the latest barrage slash started
var barrage_sides: Array[int] = []  # directions already used by the running barrage
var coil_requested: bool = false  # set when Reaper's Coil is activated; the core reads and clears it
var coil_running: bool = false
var coil_phase: StringName = &""  # one of the COIL_* phases while it runs
var coil_phase_tick: int = 0  # ticks since the phase began (the core advances it)
var coil_dir: Vector2 = Vector2.RIGHT  # the chain's direction, fixed on the press (aim, else facing)
var coil_from: Vector2 = Vector2.ZERO  # where the chain starts (the player's position)
var coil_target: Vector2 = Vector2.ZERO  # the chain's end: hook tip, the held boss edge, or the pull anchor
var coil_hooked: bool = false  # true once the hook caught the boss
var coil_spin_hit: int = 0  # spin hits done (0-2)
var coil_drag_from: Vector2 = Vector2.ZERO  # where the boss was when it was hooked
var swing_speed_mult: float = 1.0  # locked at the start of each swing
var swing_damage_mult: float = 1.0  # locked at the start of each swing
var skill_id: StringName = &""  # the skill in progress during skill_* states, empty otherwise
## The aspects in slots 1-3 (skill_pressed N uses equipped_aspects[N - 1]). Always SKILL_COUNT different known ids.
var equipped_aspects: Array[StringName] = Aspects.DEFAULT_EQUIPPED.duplicate()
## Ticks until each aspect can be used again, per aspect id (slotted or not, they all count down).
var aspect_cooldowns: Dictionary[StringName, int] = {}
## Read-only view: ticks left of the aspect in each slot 1-3 (index 0 = slot 1).
var skill_cooldowns: Array[int]:
	get:
		var view: Array[int] = []
		for aspect: StringName in equipped_aspects:
			view.append(aspect_cooldowns.get(aspect, 0))
		return view
var phantom_ticks_left: int = 0  # Phantom Cut ticks left (0 = not running); its swings queue echoes in the core
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
	if phantom_ticks_left > 0:
		phantom_ticks_left -= 1
		if phantom_ticks_left == 0:
			events.append(GameEvent.new(GameEvent.PHANTOM_CUT_ENDED, tick, {"entity_id": id, "reason": &"expired"}))
	if buff_ticks > 0:
		if barrage_running or coil_running:
			buff_ticks = maxi(1, buff_ticks - 1)  # Lightning Form / Reaper's Coil end with their skill, not by the timer
		else:
			buff_ticks -= 1
			if buff_ticks == 0:
				_emit_buff_end(tick, events, &"expired")
	if input.weapon_equip != &"":
		try_weapon_equip(input.weapon_equip, tick, events)
	if input.aspect_equip != &"":
		try_aspect_equip(input.aspect_equip, input.aspect_equip_slot, tick, events)
	if input.weapon_active_pressed:
		_try_weapon_active(tick, events, input)
	for aspect: StringName in aspect_cooldowns.keys():
		if aspect_cooldowns[aspect] > 0:
			aspect_cooldowns[aspect] -= 1
	if input.skill_pressed >= 1 and input.skill_pressed <= equipped_aspects.size() and Aspects.kind(equipped_aspects[input.skill_pressed - 1]) == Aspects.KIND_BUFF:
		_try_phantom_cut(tick, events)
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
	if barrage_requested or coil_requested:
		return  # the core starts the barrage / coil this tick; the rest of this input is not used
	var move: Vector2 = input.move.limit_length(1.0)
	if state == STATE_LIGHTNING_BARRAGE or state == STATE_REAPER_COIL:
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
		STATE_LIGHTNING_BARRAGE:
			pass  # scripted by the core (GameCore._resolve_lightning_barrage): no movement, no actions
		STATE_REAPER_COIL:
			pass  # scripted by the core (GameCore._resolve_reaper_coil): no movement, no actions
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
	return state == STATE_LIGHTNING_BARRAGE or state == STATE_REAPER_COIL or _dash_invuln > 0 or _hurt_invuln > 0 or _blink_invuln > 0


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
		die(tick, events)
	elif state != STATE_DASH:
		_set_state(STATE_IDLE)  # a hit interrupts attacks and parries
	return true


## The player dies: a running barrage and weapon buff/form end (reason death), then entity_died.
func die(tick: int, events: Array[GameEvent]) -> void:
	if state == STATE_DEAD:
		return
	hp = 0
	state = STATE_DEAD
	state_ticks = 0
	skill_id = &""
	if barrage_running:
		end_barrage(tick, events, &"death")
	if coil_running:
		end_reaper_coil(tick, events, &"death")
	if buff_ticks > 0:
		buff_ticks = 0
		_emit_buff_end(tick, events, &"death")
	if phantom_ticks_left > 0:
		phantom_ticks_left = 0
		events.append(GameEvent.new(GameEvent.PHANTOM_CUT_ENDED, tick, {"entity_id": id, "reason": &"death"}))
	events.append(GameEvent.new(GameEvent.ENTITY_DIED, tick, {"entity_id": id, "visual_id": VISUAL_ID}))


## The core starts the Lightning Barrage: whatever the player was doing stops; no movement or actions until it ends.
func start_barrage(tick: int, events: Array[GameEvent]) -> void:
	barrage_requested = false
	barrage_running = true
	barrage_slash = 0
	barrage_slash_tick = -1
	barrage_sides.clear()
	pending_release = &""
	attack_hit_done = true
	reset_combo()
	_set_state(STATE_LIGHTNING_BARRAGE)
	state_ticks = 0
	events.append(GameEvent.new(GameEvent.LIGHTNING_BARRAGE_STARTED, tick, {"entity_id": id, "slashes": Weapons.barrage_slashes()}))


## The barrage is over (complete, boss_dead or death). `slashes` in the event is how many slashes started. Lightning
## Form is only the barrage, so it ends here too (weapon_buff_ended: death on death, else expired).
func end_barrage(tick: int, events: Array[GameEvent], reason: StringName) -> void:
	if not barrage_running:
		return
	barrage_running = false
	events.append(GameEvent.new(GameEvent.LIGHTNING_BARRAGE_ENDED, tick, {"entity_id": id, "slashes": barrage_slash, "reason": reason}))
	if buff_ticks > 0:
		buff_ticks = 0
		_emit_buff_end(tick, events, &"death" if reason == &"death" else &"expired")
	if state == STATE_LIGHTNING_BARRAGE:
		_set_state(STATE_IDLE)


## The core starts Reaper's Coil: whatever the player was doing stops; the hook phase begins (the chain leaves from
## here in coil_dir). No movement or actions until it ends.
func start_reaper_coil(tick: int, events: Array[GameEvent]) -> void:
	coil_requested = false
	coil_running = true
	coil_phase = COIL_HOOK
	coil_phase_tick = 0
	coil_from = position
	coil_target = position
	coil_hooked = false
	coil_spin_hit = 0
	pending_release = &""
	attack_hit_done = true
	reset_combo()
	facing = coil_dir
	_set_state(STATE_REAPER_COIL)
	state_ticks = 0
	events.append(GameEvent.new(GameEvent.REAPER_COIL_STARTED, tick, {
		"entity_id": id, "direction": coil_dir, "from": position, "range": Tuning.REAPER_COIL_HOOK_RANGE,
	}))


## The core moves the coil to its next phase (phase tick 0 on this tick).
func set_coil_phase(phase: StringName) -> void:
	coil_phase = phase
	coil_phase_tick = 0


## Reaper's Coil is over: `complete` (after the spin), `missed` (after the pull), `boss_dead` or `death`. The form
## (weapon_form reaper_coil) is only the skill, so it ends here too (weapon_buff_ended: death on death, else expired).
func end_reaper_coil(tick: int, events: Array[GameEvent], reason: StringName) -> void:
	if not coil_running:
		return
	coil_running = false
	events.append(GameEvent.new(GameEvent.REAPER_COIL_ENDED, tick, {
		"entity_id": id, "reason": reason, "hooked": coil_hooked, "spin_hits": coil_spin_hit,
	}))
	coil_phase = &""
	coil_phase_tick = 0
	coil_spin_hit = 0
	if buff_ticks > 0:
		buff_ticks = 0
		_emit_buff_end(tick, events, &"death" if reason == &"death" else &"expired")
	if state == STATE_REAPER_COIL:
		_set_state(STATE_IDLE)


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


## Starts the skill action in the slot chosen by input.skill_pressed (1-3) when it is allowed: off cooldown, enough
## Edge, and for Breaking Edge (in whatever slot) inside the retaliation window after a successful parry. A buff aspect
## (Phantom Cut) is not a skill action: it was handled as a free action earlier in step().
func _try_skill(input: InputFrame, tick: int, events: Array[GameEvent]) -> bool:
	var slot: int = input.skill_pressed
	if slot < 1 or slot > equipped_aspects.size():
		return false
	var chosen: StringName = equipped_aspects[slot - 1]
	if Aspects.kind(chosen) != Aspects.KIND_SKILL or aspect_cooldowns.get(chosen, 0) > 0:
		return false
	if Aspects.needs_retaliation(chosen) and retaliate_ticks <= 0:
		return false
	var cost: float = Aspects.edge_cost(chosen)
	if edge < cost:
		return false
	edge -= cost
	# The Spirit Lantern's cooldown starts when the lantern is placed (GameCore), the others' on the press.
	if chosen != SKILL_SPIRIT_LANTERN:
		aspect_cooldowns[chosen] = Aspects.cooldown(chosen)
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
		SKILL_SPIRIT_LANTERN:
			return {"windup": Tuning.SPIRIT_LANTERN_WINDUP_TICKS, "active": Tuning.SPIRIT_LANTERN_ACTIVE_TICKS, "recovery": Tuning.SPIRIT_LANTERN_RECOVERY_TICKS}[phase]
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


## The equipped weapon's active (right click): the Black Katana buff (a timed buff that lasts through movement,
## attacks, dashes, parries, skills and damage; it ends when it runs out or the player dies) or the Dual Dagger's
## Lightning Form, which is only the Lightning Barrage (it needs a living boss and ends with the barrage), or the Chain
## Scythe's Reaper's Coil (the same: a living boss, ends with the skill; aimed by input.aim, else the facing). Numbers
## per weapon in core/weapons.gd. Costs Edge, has the weapon's own cooldown, cannot be refreshed while it is running.
func _try_weapon_active(tick: int, events: Array[GameEvent], input: InputFrame) -> bool:
	if not Weapons.has_active(weapon_id) or state == STATE_DEAD or buff_ticks > 0 or buff_cooldown > 0:
		return false
	if Weapons.active_needs_target(weapon_id) and not barrage_target_alive:
		return false  # the barrage and the coil need a living boss
	var cost: float = Weapons.active_edge_cost(weapon_id)
	if edge < cost:
		return false
	edge -= cost
	buff_ticks = Weapons.active_duration(weapon_id)
	buff_cooldown = Weapons.active_cooldown(weapon_id)
	barrage_requested = Weapons.has_lightning_barrage(weapon_id)
	coil_requested = Weapons.has_reaper_coil(weapon_id)
	if coil_requested:
		coil_dir = input.aim.normalized() if input.aim.length_squared() > 0.0001 else facing.normalized()
	events.append(GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, tick, {
		"entity_id": id, "weapon_id": weapon_id, "form": Weapons.active_form(weapon_id), "duration": buff_ticks,
		"attack_speed_mult": Weapons.active_attack_speed_mult(weapon_id), "damage_mult": Weapons.active_damage_mult(weapon_id),
		"move_speed_mult": Weapons.active_move_speed_mult(weapon_id),
	}))
	return true


## Equip exactly `target` (InputFrame.weapon_equip, sent by the character menu). A free action from idle or walk only,
## never while a buff/form runs or during the swap lockout. Unknown ids and the weapon already equipped do nothing (no
## lockout, no event). The combo starts over; each weapon keeps its own active cooldown. Returns true if it equipped.
func try_weapon_equip(target: StringName, tick: int, events: Array[GameEvent]) -> bool:
	if not Weapons.is_known(target) or target == weapon_id:
		return false
	if state != STATE_IDLE and state != STATE_WALK:
		return false
	if buff_ticks > 0 or swap_lockout > 0:
		return false
	var previous: StringName = weapon_id
	weapon_id = target
	swap_lockout = Tuning.WEAPON_SWAP_LOCKOUT_TICKS
	reset_combo()
	events.append(GameEvent.new(GameEvent.WEAPON_SWAPPED, tick, {"entity_id": id, "weapon_id": weapon_id, "previous_weapon_id": previous}))
	return true


## Phantom Cut (a buff aspect in the pressed slot): a free action like the weapon active, no state change, allowed in
## any state but dead, the Lightning Barrage and Reaper's Coil. Needs Edge and its cooldown; cannot be refreshed while
## it runs. The cost is spent and the cooldown starts on the press. Returns true if it started.
func _try_phantom_cut(tick: int, events: Array[GameEvent]) -> bool:
	if state == STATE_DEAD or state == STATE_LIGHTNING_BARRAGE or state == STATE_REAPER_COIL or barrage_requested or coil_requested:
		return false
	if phantom_ticks_left > 0 or aspect_cooldowns.get(SKILL_PHANTOM_CUT, 0) > 0:
		return false
	var cost: float = Aspects.edge_cost(SKILL_PHANTOM_CUT)
	if edge < cost:
		return false
	edge -= cost
	aspect_cooldowns[SKILL_PHANTOM_CUT] = Aspects.cooldown(SKILL_PHANTOM_CUT)
	phantom_ticks_left = Tuning.PHANTOM_CUT_DURATION_TICKS
	events.append(GameEvent.new(GameEvent.PHANTOM_CUT_STARTED, tick, {"entity_id": id, "duration": phantom_ticks_left}))
	return true


## Equip aspect `aspect` into slot `slot` (1-3) (InputFrame.aspect_equip / aspect_equip_slot, sent by the character
## menu). If it already sits in another slot the two slots swap. Same rules as the weapon equip: idle or walk only,
## never while a weapon buff/form runs (a Phantom Cut buff or a lantern is no blocker); no lockout. Unknown ids, a bad
## slot, or the aspect already in that slot do nothing (no event). Cooldowns belong to the aspect, so they move with it.
func try_aspect_equip(aspect: StringName, slot: int, tick: int, events: Array[GameEvent]) -> bool:
	if not Aspects.is_known(aspect) or slot < 1 or slot > equipped_aspects.size():
		return false
	if state != STATE_IDLE and state != STATE_WALK:
		return false
	if buff_ticks > 0 or barrage_running or coil_running:
		return false
	var previous: StringName = equipped_aspects[slot - 1]
	if previous == aspect:
		return false
	var other: int = equipped_aspects.find(aspect)
	equipped_aspects[slot - 1] = aspect
	if other >= 0:
		equipped_aspects[other] = previous
	events.append(GameEvent.new(GameEvent.ASPECT_EQUIPPED, tick, {
		"entity_id": id, "slot": slot, "aspect_id": aspect, "previous": previous, "swapped_slot": other + 1 if other >= 0 else 0,
	}))
	return true


## Set the slots from a saved loadout (a fight's start). Ignored unless it is SKILL_COUNT different known aspects.
func set_equipped_aspects(aspects: Array) -> bool:
	if not Aspects.is_valid_loadout(aspects):
		return false
	equipped_aspects.clear()
	for value: Variant in aspects:
		equipped_aspects.append(StringName(value))
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


## Current walking speed multiplier (1.0 without the buff; the katana buff's own value while it runs).
func move_speed_mult() -> float:
	return Weapons.active_move_speed_mult(weapon_id) if buff_ticks > 0 else 1.0


## Swings in the equipped weapon's combo (katana 3, dagger 4).
func combo_max() -> int:
	return Weapons.combo_max(weapon_id)


## The core found a blink spot for a barrage slash: move there, face the boss and take the blink i-frames.
func apply_blink(to: Vector2, face: Vector2, direction_index: int, tick: int) -> void:
	last_blink_from = position
	last_blink_to = to
	last_blink_direction = direction_index
	last_blink_tick = tick
	position = to
	if face.length_squared() > 0.0001:
		facing = face.normalized()
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
