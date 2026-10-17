extends RefCounted
## Mossbound Colossus simulation. No rendering. Three attacks: a gold slam and sweep (parry them), and
## red shards (dodge them). Posture break opens a counter window. Phase 2 at half health.

const Tuning := preload("res://core/tuning.gd")
const GameEvent := preload("res://core/game_event.gd")
const Telegraph := preload("res://core/telegraph.gd")

const VISUAL_ID: StringName = &"mossbound_colossus"
const STATE_IDLE: StringName = &"idle"
const STATE_ATTACK: StringName = &"attack"  # from the first warning tick to the end of the danger window
const STATE_RECOVER: StringName = &"recover"
const STATE_BROKEN: StringName = &"posture_broken"
const STATE_DEAD: StringName = &"dead"

const ATTACK_SLAM: StringName = &"gold_slam"
const ATTACK_SWEEP: StringName = &"red_sweep"
const ATTACK_SHARDS: StringName = &"red_shards"
const ATTACK_STOMP: StringName = &"red_stomp"
const ATTACK_COMBO: StringName = &"gold_combo"
const ATTACK_CHARGE: StringName = &"red_charge"
const ATTACKS: Array[StringName] = [ATTACK_SLAM, ATTACK_SWEEP, ATTACK_SHARDS, ATTACK_STOMP, ATTACK_COMBO, ATTACK_CHARGE]
## Attacks the boss may pick on its own. Phase 2 adds the combo and the charge.
const PHASE1_POOL: Array[StringName] = [ATTACK_SLAM, ATTACK_SWEEP, ATTACK_SHARDS, ATTACK_STOMP]
const PHASE2_POOL: Array[StringName] = [ATTACK_SLAM, ATTACK_SWEEP, ATTACK_SHARDS, ATTACK_STOMP, ATTACK_COMBO, ATTACK_CHARGE]

var id: int = 2
var position: Vector2 = Tuning.BOSS_START
var facing: Vector2 = Vector2.LEFT
var hp: int = Tuning.BOSS_MAX_HP
var posture: float = 0.0
var phase: int = 1
var state: StringName = STATE_IDLE
var state_ticks: int = 0
var telegraphs: Array[Telegraph] = []
var cooldown: int = Tuning.BOSS_FIRST_ATTACK_DELAY_TICKS
var broken_ticks_left: int = 0
## Tests and scripted encounters can force the next attack (one of ATTACKS).
var next_attack_override: StringName = &""

var _last_attack: StringName = &""
var _charge: Telegraph = null  # the active charge line, while a charge is in progress
var _charge_from: Vector2 = Vector2.ZERO
var _attack_end_tick: int = 0
var _recover_ticks: int = 0
var _next_telegraph_id: int = 1


func step(tick: int, player_pos: Vector2, rng: RandomNumberGenerator, events: Array[GameEvent]) -> void:
	if state == STATE_DEAD:
		return
	state_ticks += 1
	match state:
		STATE_IDLE:
			_decay_posture()
			var to_player: Vector2 = player_pos - position
			if to_player.length_squared() > 0.0001:
				facing = to_player.normalized()
			if to_player.length() > Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS + 12.0:
				position += facing * Tuning.BOSS_SPEED
			cooldown -= 1
			if cooldown <= 0:
				_begin_attack(tick, player_pos, rng, events)
		STATE_ATTACK:
			_decay_posture()
			_step_charge(tick)
			if tick > _attack_end_tick:
				telegraphs.clear()
				_charge = null
				_set_state(STATE_RECOVER)
		STATE_RECOVER:
			_decay_posture()
			if state_ticks >= _recover_ticks:
				cooldown = Tuning.BOSS_COOLDOWN_PHASE2_TICKS if phase == 2 else Tuning.BOSS_COOLDOWN_PHASE1_TICKS
				_set_state(STATE_IDLE)
		STATE_BROKEN:
			broken_ticks_left -= 1
			if broken_ticks_left <= 0:
				posture = 0.0
				events.append(GameEvent.new(GameEvent.COUNTER_WINDOW_CLOSED, tick, {"entity_id": id}))
				_recover_ticks = Tuning.BOSS_BREAK_RECOVER_TICKS
				_set_state(STATE_RECOVER)


func add_posture(amount: float, tick: int, events: Array[GameEvent]) -> void:
	if state == STATE_BROKEN or state == STATE_DEAD:
		return
	posture = minf(Tuning.BOSS_POSTURE_MAX, posture + amount)
	if posture >= Tuning.BOSS_POSTURE_MAX:
		_break(tick, events)


func take_damage(amount: int, tick: int, events: Array[GameEvent], source_id: int) -> void:
	if state == STATE_DEAD:
		return
	hp = maxi(0, hp - amount)
	events.append(GameEvent.new(GameEvent.DAMAGE_TAKEN, tick, {"entity_id": id, "amount": amount, "source_id": source_id}))
	if hp == 0:
		var was_broken: bool = state == STATE_BROKEN
		state = STATE_DEAD
		state_ticks = 0
		telegraphs.clear()
		if was_broken:
			events.append(GameEvent.new(GameEvent.COUNTER_WINDOW_CLOSED, tick, {"entity_id": id}))
		events.append(GameEvent.new(GameEvent.ENTITY_DIED, tick, {"entity_id": id, "visual_id": VISUAL_ID}))
	elif phase == 1 and float(hp) <= float(Tuning.BOSS_MAX_HP) * Tuning.BOSS_PHASE2_HP_FRACTION:
		phase = 2
		events.append(GameEvent.new(GameEvent.BOSS_PHASE_CHANGED, tick, {"entity_id": id, "phase": 2}))


func _break(tick: int, events: Array[GameEvent]) -> void:
	posture = Tuning.BOSS_POSTURE_MAX
	telegraphs.clear()  # a broken boss drops its current attack
	_charge = null
	broken_ticks_left = Tuning.BOSS_BREAK_TICKS
	_set_state(STATE_BROKEN)
	events.append(GameEvent.new(GameEvent.POSTURE_BROKEN, tick, {"entity_id": id, "window_ticks": Tuning.BOSS_BREAK_TICKS}))
	events.append(GameEvent.new(GameEvent.COUNTER_WINDOW_OPENED, tick, {"entity_id": id, "window_ticks": Tuning.BOSS_BREAK_TICKS}))


func _decay_posture() -> void:
	posture = maxf(0.0, posture - Tuning.BOSS_POSTURE_DECAY)


func _begin_attack(tick: int, player_pos: Vector2, rng: RandomNumberGenerator, events: Array[GameEvent]) -> void:
	var attack: StringName = next_attack_override
	next_attack_override = &""
	if attack == &"":
		var choices: Array[StringName] = []
		for candidate: StringName in (PHASE2_POOL if phase == 2 else PHASE1_POOL):
			if candidate != _last_attack:
				choices.append(candidate)
		attack = choices[rng.randi_range(0, choices.size() - 1)]
	_last_attack = attack
	var aim: Vector2 = (player_pos - position).normalized() if player_pos != position else facing
	facing = aim  # aim is locked here: no telegraph changes after this point
	var scale: float = Tuning.BOSS_PHASE2_WINDUP_FACTOR if phase == 2 else 1.0
	match attack:
		ATTACK_SLAM:
			var hit: int = tick + roundi(Tuning.SLAM_WINDUP_TICKS * scale)
			var slam: Telegraph = _make(attack, Telegraph.KIND_GOLD, Telegraph.SHAPE_CIRCLE, player_pos, aim, tick, hit, hit)
			slam.size = Tuning.SLAM_RADIUS
			slam.damage = Tuning.SLAM_DAMAGE
			_add(slam, events)
			_recover_ticks = Tuning.SLAM_RECOVER_TICKS
		ATTACK_SWEEP:
			var hit: int = tick + roundi(Tuning.SWEEP_WINDUP_TICKS * scale)
			var sweep: Telegraph = _make(attack, Telegraph.KIND_GOLD, Telegraph.SHAPE_CONE, position, aim, tick, hit, hit + Tuning.SWEEP_ACTIVE_TICKS)
			sweep.size = Tuning.SWEEP_RADIUS
			sweep.half_angle = deg_to_rad(Tuning.SWEEP_HALF_ANGLE_DEG)
			sweep.damage = Tuning.SWEEP_DAMAGE
			_add(sweep, events)
			_recover_ticks = Tuning.SWEEP_RECOVER_TICKS
		ATTACK_SHARDS:
			var hit: int = tick + roundi(Tuning.SHARDS_WINDUP_TICKS * scale)
			# Everything starts at the chest muzzle (locked now): the aim, the warning and the damage lines.
			var muzzle: Vector2 = position + Tuning.SHARDS_ORIGIN_OFFSET
			var beam_aim: Vector2 = (player_pos - muzzle).normalized() if player_pos != muzzle else aim
			for offset: float in [-Tuning.SHARDS_SPREAD_DEG, 0.0, Tuning.SHARDS_SPREAD_DEG]:
				var shard: Telegraph = _make(attack, Telegraph.KIND_RED, Telegraph.SHAPE_LINE, muzzle, beam_aim.rotated(deg_to_rad(offset)), tick, hit, hit + Tuning.SHARDS_ACTIVE_TICKS)
				shard.muzzle = muzzle
				shard.size = Tuning.SHARDS_LENGTH
				shard.width = Tuning.SHARDS_WIDTH
				shard.damage = Tuning.SHARDS_DAMAGE
				_add(shard, events)
			_recover_ticks = Tuning.SHARDS_RECOVER_TICKS
		ATTACK_STOMP:
			var hit: int = tick + roundi(Tuning.STOMP_WINDUP_TICKS * scale)
			var stomp: Telegraph = _make(attack, Telegraph.KIND_RED, Telegraph.SHAPE_RING, position, aim, tick, hit, hit + Tuning.STOMP_ACTIVE_TICKS)
			stomp.size = Tuning.STOMP_OUTER_RADIUS
			stomp.inner_size = Tuning.STOMP_INNER_RADIUS
			stomp.damage = Tuning.STOMP_DAMAGE
			_add(stomp, events)
			_recover_ticks = Tuning.STOMP_RECOVER_TICKS
		ATTACK_COMBO:
			var first_hit: int = tick + roundi(Tuning.COMBO_WINDUP_TICKS * scale)
			var second_hit: int = first_hit + Tuning.COMBO_GAP_TICKS
			var first_center: Vector2 = _clamp_to_arena(player_pos)
			var second_center: Vector2 = _clamp_to_arena(player_pos + aim * Tuning.COMBO_OFFSET)
			var first: Telegraph = _make(attack, Telegraph.KIND_GOLD, Telegraph.SHAPE_CIRCLE, first_center, aim, tick, first_hit, first_hit)
			var second: Telegraph = _make(attack, Telegraph.KIND_GOLD, Telegraph.SHAPE_CIRCLE, second_center, aim, tick, second_hit, second_hit)
			for slam: Telegraph in [first, second]:
				slam.size = Tuning.COMBO_RADIUS
				slam.damage = Tuning.COMBO_DAMAGE
				_add(slam, events)
			_recover_ticks = Tuning.COMBO_RECOVER_TICKS
		ATTACK_CHARGE:
			var hit: int = tick + roundi(Tuning.CHARGE_WINDUP_TICKS * scale)
			var charge: Telegraph = _make(attack, Telegraph.KIND_RED, Telegraph.SHAPE_LINE, position, aim, tick, hit, hit + Tuning.CHARGE_ACTIVE_TICKS - 1)
			charge.size = Tuning.CHARGE_LENGTH
			charge.width = Tuning.CHARGE_WIDTH
			charge.damage = Tuning.CHARGE_DAMAGE
			_add(charge, events)
			_charge = charge
			_charge_from = position
			_recover_ticks = Tuning.CHARGE_RECOVER_TICKS
	_attack_end_tick = 0
	for telegraph: Telegraph in telegraphs:
		_attack_end_tick = maxi(_attack_end_tick, telegraph.end_tick)
	_set_state(STATE_ATTACK)


## While a charge is dangerous, the boss body travels along the locked line (same geometry as the warning).
func _step_charge(tick: int) -> void:
	if _charge == null or tick < _charge.hit_tick or tick > _charge.end_tick:
		return
	var span: float = float(_charge.end_tick - _charge.hit_tick + 1)
	var progress: float = float(tick - _charge.hit_tick + 1) / span
	position = _charge_from + _charge.direction * _charge.size * progress


func _clamp_to_arena(point: Vector2) -> Vector2:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	return point.clamp(low, Tuning.ARENA_SIZE - low)


func _make(attack: StringName, kind: StringName, shape: StringName, center: Vector2, direction: Vector2, start: int, hit: int, end_tick: int) -> Telegraph:
	var telegraph: Telegraph = Telegraph.new()
	telegraph.id = _next_telegraph_id
	_next_telegraph_id += 1
	telegraph.owner_id = id
	telegraph.attack = attack
	telegraph.kind = kind
	telegraph.shape = shape
	telegraph.center = center
	telegraph.muzzle = position
	telegraph.direction = direction
	telegraph.start_tick = start
	telegraph.hit_tick = hit
	telegraph.end_tick = end_tick
	return telegraph


func _add(telegraph: Telegraph, events: Array[GameEvent]) -> void:
	telegraphs.append(telegraph)
	events.append(GameEvent.new(GameEvent.ATTACK_TELEGRAPHED, telegraph.start_tick, {
		"telegraph_id": telegraph.id, "owner_id": id, "kind": telegraph.kind, "attack": telegraph.attack,
	}))


func _set_state(new_state: StringName) -> void:
	if state != new_state:
		state = new_state
		state_ticks = 0
