extends RefCounted
## The combat vertical slice: one room, the player (sword) against the Mossbound Colossus.
## No rendering. Presentation calls step() once per 60 Hz tick, then reads snapshot() and last_events.
## Same seed + same inputs => same results (deterministic).

const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Telegraph := preload("res://core/telegraph.gd")
const Snapshots := preload("res://core/snapshots.gd")
const PlayerState := preload("res://core/player.gd")
const BossState := preload("res://core/boss.gd")
const SkillAttack := preload("res://core/skill_attack.gd")

const RESULT_PLAYING: StringName = &"playing"
const RESULT_VICTORY: StringName = &"victory"
const RESULT_DEFEAT: StringName = &"defeat"

signal event_emitted(event: GameEvent)

var tick: int = 0
var result: StringName = RESULT_PLAYING
## Ticks since the fight ended (0 while playing). The simulation is frozen after the result, but this keeps
## counting so presentation can play end animations (the hero's fall, a victory pose) from it.
var result_ticks: int = 0
var player: PlayerState = PlayerState.new()
var boss: BossState = BossState.new()
## Events produced by the most recent step(), in order.
var last_events: Array[GameEvent] = []

## Live skill attacks (melee arcs, dash lanes, travelling projectiles). A projectile outlives the player's state.
var skill_attacks: Array[SkillAttack] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_attack_id: int = 1


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func step(input: InputFrame) -> void:
	last_events = []
	if result != RESULT_PLAYING:
		result_ticks += 1
		return
	tick += 1
	var events: Array[GameEvent] = []
	var player_before: Vector2 = player.position
	player.step(input, tick, events)
	_resolve_player_attack(events)
	_spawn_released_skill(events)
	boss.step(tick, player.position, _rng, events)
	_resolve_telegraphs(events)
	_clamp_to_arena()
	_resolve_skill_attacks(player_before, events)
	_separate_from_boss()
	_check_result(events)
	last_events = events
	for event: GameEvent in events:
		event_emitted.emit(event)


func snapshot() -> Snapshots.GameSnapshot:
	var snap: Snapshots.GameSnapshot = Snapshots.GameSnapshot.new()
	snap.tick = tick
	snap.result = result
	snap.result_ticks = result_ticks
	snap.player = _player_snapshot()
	snap.entities.append(_boss_snapshot())
	for telegraph: Telegraph in boss.telegraphs:
		var t: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		t.id = telegraph.id
		t.owner_id = telegraph.owner_id
		t.attack = telegraph.attack
		t.kind = telegraph.kind
		t.shape = telegraph.shape
		t.center = telegraph.center
		t.direction = telegraph.direction
		t.size = telegraph.size
		t.inner_size = telegraph.inner_size
		t.half_angle = telegraph.half_angle
		t.width = telegraph.width
		t.start_tick = telegraph.start_tick
		t.hit_tick = telegraph.hit_tick
		t.end_tick = telegraph.end_tick
		snap.telegraphs.append(t)
	for attack: SkillAttack in skill_attacks:
		var a: Snapshots.SkillAttackSnapshot = Snapshots.SkillAttackSnapshot.new()
		a.id = attack.id
		a.owner_id = attack.owner_id
		a.skill_id = attack.skill_id
		a.shape = attack.shape
		a.position = attack.position
		a.direction = attack.direction
		a.start = attack.start
		a.end = attack.end
		a.width = attack.width
		a.size = attack.size
		a.half_angle = acos(clampf(attack.arc_dot, -1.0, 1.0)) if attack.shape == SkillAttack.SHAPE_ARC else 0.0
		a.start_tick = attack.start_tick
		a.end_tick = attack.end_tick
		a.ticks_left = maxi(0, attack.end_tick - tick)
		a.hit_target_ids = attack.hit_targets.duplicate()
		snap.skill_attacks.append(a)
	var hud: Snapshots.HudSnapshot = Snapshots.HudSnapshot.new()
	hud.player_hp = player.hp
	hud.player_max_hp = Tuning.PLAYER_MAX_HP
	hud.dash_cooldown_ticks = player.dash_cooldown
	hud.dash_cooldown_max = Tuning.DASH_COOLDOWN_TICKS
	hud.edge = player.edge
	hud.edge_max = Tuning.EDGE_MAX
	hud.boss_hp = boss.hp
	hud.boss_max_hp = Tuning.BOSS_MAX_HP
	hud.boss_posture = boss.posture
	hud.boss_posture_max = Tuning.BOSS_POSTURE_MAX
	hud.counter_window_ticks_left = boss.broken_ticks_left if boss.state == BossState.STATE_BROKEN else 0
	hud.skill_cooldown_ticks = player.skill_cooldowns.duplicate()
	hud.retaliate_ticks_left = player.retaliate_ticks
	var has_active: bool = player.weapon_id == Tuning.WEAPON_BLACK_KATANA
	hud.weapon_buff_duration = Tuning.BLACK_KATANA_BUFF_DURATION_TICKS if has_active else 0
	hud.weapon_buff_cooldown_ticks = player.buff_cooldown
	hud.weapon_buff_cooldown_max = Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS if has_active else 0
	hud.weapon_buff_edge_cost = Tuning.BLACK_KATANA_BUFF_EDGE_COST if has_active else 0.0
	snap.hud = hud
	return snap


func _player_snapshot() -> Snapshots.EntitySnapshot:
	var e: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	e.id = player.id
	e.visual_id = PlayerState.VISUAL_ID
	e.state = player.state
	e.state_ticks = player.state_ticks
	e.position = player.position
	e.facing = player.facing
	e.hp = player.hp
	e.max_hp = Tuning.PLAYER_MAX_HP
	e.invulnerable = player.is_invulnerable()
	e.combo_index = player.combo_index
	e.skill_id = player.skill_id
	e.weapon_id = player.weapon_id
	e.weapon_buff_active = player.is_buff_active()
	e.weapon_buff_ticks_left = player.buff_ticks
	e.attack_speed_mult = player.swing_speed_mult if String(player.state).begins_with("attack_") else player.attack_speed_mult()
	return e


func _boss_snapshot() -> Snapshots.EntitySnapshot:
	var e: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	e.id = boss.id
	e.visual_id = BossState.VISUAL_ID
	e.state = boss.state
	e.state_ticks = boss.state_ticks
	e.position = boss.position
	e.facing = boss.facing
	e.hp = boss.hp
	e.max_hp = Tuning.BOSS_MAX_HP
	e.posture = boss.posture
	e.posture_max = Tuning.BOSS_POSTURE_MAX
	return e


## The normal sword swing (skills are resolved from their SkillAttack objects instead).
func _resolve_player_attack(events: Array[GameEvent]) -> void:
	if player.attack_hit_done or boss.state == BossState.STATE_DEAD or player.state != PlayerState.STATE_ATTACK_ACTIVE:
		return
	var swing: int = player.combo_index - 1
	var to_boss: Vector2 = boss.position - player.position
	var dist: float = to_boss.length()
	if dist - Tuning.BOSS_RADIUS > Tuning.ATTACK_RANGE * Tuning.SWING_RANGE_MULT[swing]:
		return
	if dist > 0.0001 and player.facing.dot(to_boss / dist) < Tuning.ATTACK_ARC_DOT:
		return
	player.attack_hit_done = true
	var counter: bool = boss.state == BossState.STATE_BROKEN
	var damage: int
	if counter:
		damage = roundi(Tuning.ATTACK_DAMAGE * Tuning.SWING_DAMAGE_MULT[swing] * player.swing_damage_mult * Tuning.COUNTER_DAMAGE_MULT + player.edge * Tuning.EDGE_COUNTER_BONUS)
		player.edge = 0.0  # the counter spends all Edge
	else:
		damage = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.SWING_DAMAGE_MULT[swing] * player.swing_damage_mult * Tuning.ARMOR_DAMAGE_FACTOR))
		player.edge = minf(Tuning.EDGE_MAX, player.edge + Tuning.EDGE_PER_HIT)
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
		"attacker_id": player.id, "target_id": boss.id, "damage": damage,
		"kind": &"counter" if counter else &"normal", "position": boss.position, "combo_index": player.combo_index,
	}))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(Tuning.NORMAL_HIT_POSTURE, tick, events)


## The player just entered skill_active: create the attack that belongs to the skill (once per cast).
func _spawn_released_skill(events: Array[GameEvent]) -> void:
	var skill: StringName = player.pending_release
	if skill == &"":
		return
	player.pending_release = &""
	var attack: SkillAttack = SkillAttack.new()
	attack.id = _next_attack_id
	_next_attack_id += 1
	attack.owner_id = player.id
	attack.skill_id = skill
	attack.direction = player.skill_dir
	attack.damage_mult = player.damage_mult()
	attack.start_tick = tick
	attack.position = player.position
	attack.start = player.position
	attack.end = player.position
	match skill:
		PlayerState.SKILL_BREAKING_EDGE:
			attack.shape = SkillAttack.SHAPE_ARC
			attack.size = Tuning.BREAKING_EDGE_RANGE
			attack.arc_dot = Tuning.BREAKING_EDGE_ARC_DOT
			attack.end_tick = tick + Tuning.BREAKING_EDGE_ACTIVE_TICKS - 1
		PlayerState.SKILL_GALE_CUT:
			attack.shape = SkillAttack.SHAPE_LANE
			attack.width = Tuning.GALE_CUT_LANE_WIDTH
			attack.end = player.position + player.skill_dir * Tuning.GALE_CUT_DISTANCE
			attack.end_tick = tick + Tuning.GALE_CUT_ACTIVE_TICKS
		_:
			attack.shape = SkillAttack.SHAPE_PROJECTILE
			attack.width = Tuning.MOON_CLEAVE_WIDTH
			attack.speed = Tuning.MOON_CLEAVE_SPEED
			attack.length = Tuning.MOON_CLEAVE_TRAVEL
			attack.start = player.position + player.skill_dir * Tuning.MOON_CLEAVE_SPAWN_OFFSET
			attack.position = attack.start
			attack.end = attack.start + player.skill_dir * Tuning.MOON_CLEAVE_TRAVEL
			attack.end_tick = tick + ceili(Tuning.MOON_CLEAVE_TRAVEL / Tuning.MOON_CLEAVE_SPEED)
	skill_attacks.append(attack)
	events.append(GameEvent.new(GameEvent.SKILL_RELEASED, tick, {
		"attack_id": attack.id, "entity_id": player.id, "skill_id": skill, "shape": attack.shape,
		"position": attack.position, "direction": attack.direction, "start": attack.start, "end": attack.end,
		"width": attack.width,
	}))


## Advance and test every live skill attack. `player_before` is where the player stood before this tick's
## movement: with the final position it is the segment actually travelled (walls and the solid boss included).
func _resolve_skill_attacks(player_before: Vector2, events: Array[GameEvent]) -> void:
	for attack: SkillAttack in skill_attacks.duplicate():
		var done: bool = false
		match attack.shape:
			SkillAttack.SHAPE_ARC:
				attack.position = player.position
				if _arc_touches_boss(attack):
					_skill_hit(attack, events)
				done = tick >= attack.end_tick
			SkillAttack.SHAPE_LANE:
				attack.position = player.position
				if SkillAttack.segment_touches_circle(player_before, player.position, boss.position, Tuning.BOSS_RADIUS + attack.width * 0.5):
					_skill_hit(attack, events)
				done = player.state != PlayerState.STATE_SKILL_ACTIVE
			_:
				var from: Vector2 = attack.position
				if tick > attack.start_tick:
					var step: float = minf(attack.speed, attack.length - attack.travelled)
					attack.position += attack.direction * step
					attack.travelled += step
				if SkillAttack.segment_touches_circle(from, attack.position, boss.position, Tuning.BOSS_RADIUS + attack.width * 0.5):
					_skill_hit(attack, events)
				done = attack.travelled >= attack.length
		if done:
			skill_attacks.erase(attack)


func _arc_touches_boss(attack: SkillAttack) -> bool:
	var to_boss: Vector2 = boss.position - attack.position
	var dist: float = to_boss.length()
	if dist - Tuning.BOSS_RADIUS > attack.size:
		return false
	return dist <= 0.0001 or attack.direction.dot(to_boss / dist) >= attack.arc_dot


func _skill_hit(attack: SkillAttack, events: Array[GameEvent]) -> void:
	if attack.has_hit(boss.id) or boss.state == BossState.STATE_DEAD:
		return
	attack.hit_targets.append(boss.id)
	var profile: Dictionary = PlayerState.skill_profile(attack.skill_id)
	var counter: bool = boss.state == BossState.STATE_BROKEN
	var damage: int
	if counter:
		damage = roundi(profile["damage"] * attack.damage_mult * Tuning.COUNTER_DAMAGE_MULT)
	else:
		damage = maxi(1, roundi(profile["damage"] * attack.damage_mult * Tuning.ARMOR_DAMAGE_FACTOR))
		player.edge = minf(Tuning.EDGE_MAX, player.edge + profile["edge_gain"])
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
		"attacker_id": player.id, "target_id": boss.id, "damage": damage,
		"kind": &"counter" if counter else &"normal", "position": boss.position,
		"skill_id": attack.skill_id, "attack_id": attack.id,
	}))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(profile["posture"], tick, events)


func _resolve_telegraphs(events: Array[GameEvent]) -> void:
	if player.state == PlayerState.STATE_DEAD:
		return
	for telegraph: Telegraph in boss.telegraphs.duplicate():
		if telegraph.has_hit or not telegraph.is_dangerous_at(tick):
			continue
		if not telegraph.overlaps_circle(player.position, Tuning.PLAYER_RADIUS):
			continue
		var since: int = player.parry_ticks_since_press()
		if telegraph.kind == Telegraph.KIND_GOLD and since >= 0 and since < Tuning.PARRY_ACTIVE_TICKS:
			telegraph.has_hit = true
			var perfect: bool = since < Tuning.PARRY_PERFECT_TICKS
			events.append(GameEvent.new(GameEvent.PARRY_SUCCEEDED, tick, {
				"player_id": player.id, "attacker_id": telegraph.owner_id, "telegraph_id": telegraph.id,
				"quality": &"perfect" if perfect else &"early", "position": player.position,
			}))
			player.on_parry_success(boss.position - player.position)
			boss.add_posture(Tuning.BOSS_POSTURE_MAX if perfect else Tuning.PARRY_EARLY_POSTURE, tick, events)
			continue
		# Red attacks are never parried; gold attacks that were not parried hit like any other.
		if player.take_damage(telegraph.damage, tick, events, telegraph.owner_id):
			telegraph.has_hit = true
			events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
				"attacker_id": telegraph.owner_id, "target_id": player.id, "damage": telegraph.damage,
				"kind": telegraph.kind, "position": player.position,
			}))


func _clamp_to_arena() -> void:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	player.position = player.position.clamp(low, high)
	boss.position = boss.position.clamp(low, high)


## Gale Cut passes through the boss only while the dash itself runs (skill_active). Skill attacks are
## resolved before this, so the corridor is the path really travelled, walls included.
func _player_passes_through_boss() -> bool:
	return player.state == PlayerState.STATE_SKILL_ACTIVE and player.skill_id == PlayerState.SKILL_GALE_CUT


## The boss is solid: push the player out of it. The tick the dash ends (or is interrupted) the player may
## be inside the boss; they are moved to the nearest free spot and never left overlapping.
func _separate_from_boss() -> void:
	if _player_passes_through_boss():
		return
	var min_dist: float = Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS
	var offset: Vector2 = player.position - boss.position
	if offset.length() >= min_dist:
		return
	var push_dir: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else (player.skill_dir if player.skill_dir.length_squared() > 0.0001 else Vector2.LEFT)
	player.position = _free_spot(push_dir, min_dist)


## boss + dir * min_dist, kept inside the arena. If the wall pulls that back into the boss (the boss stands near
## a wall), try the other directions around the boss, nearest to `dir` first.
func _free_spot(dir: Vector2, min_dist: float) -> Vector2:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	var best: Vector2 = (boss.position + dir * min_dist).clamp(low, high)
	if best.distance_to(boss.position) >= min_dist - 0.01:
		return best
	var farthest: float = best.distance_to(boss.position)
	for step: int in range(1, 9):
		for sign: float in [1.0, -1.0]:
			var candidate: Vector2 = (boss.position + dir.rotated(sign * step * PI / 8.0) * min_dist).clamp(low, high)
			var d: float = candidate.distance_to(boss.position)
			if d >= min_dist - 0.01:
				return candidate
			if d > farthest:
				farthest = d
				best = candidate
	return best


func _check_result(events: Array[GameEvent]) -> void:
	if boss.state == BossState.STATE_DEAD:
		result = RESULT_VICTORY
	elif player.state == PlayerState.STATE_DEAD:
		result = RESULT_DEFEAT
	else:
		return
	events.append(GameEvent.new(GameEvent.GAME_RESULT, tick, {"result": result}))
