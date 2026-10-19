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
const Obstacle := preload("res://core/obstacle.gd")
const ArenaLayout := preload("res://core/arena_layout.gd")
const Weapons := preload("res://core/weapons.gd")

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

## The solid props of the ruins (pillars, trees, boulders): the player and the boss cannot walk through them.
var obstacles: Array[Obstacle] = ArenaLayout.build()

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
	player.position = move_resolved(player_before, player.position, Tuning.PLAYER_RADIUS)
	_resolve_lightning_blink(events)
	_resolve_player_attack(events)
	_spawn_released_skill(events)
	var boss_before: Vector2 = boss.position
	boss.step(tick, player.position, _rng, events)
	boss.position = move_resolved(boss_before, boss.position, Tuning.BOSS_RADIUS)
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
		t.muzzle = telegraph.muzzle
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
	for obstacle: Obstacle in obstacles:
		var o: Snapshots.ObstacleSnapshot = Snapshots.ObstacleSnapshot.new()
		o.id = obstacle.id
		o.visual_id = obstacle.visual_id
		o.feet = obstacle.feet
		o.visual_scale = obstacle.visual_scale
		o.center = obstacle.center
		o.radius = obstacle.radius
		snap.obstacles.append(o)
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
	hud.weapon_buff_duration = Weapons.active_duration(player.weapon_id)
	hud.weapon_buff_cooldown_ticks = player.buff_cooldown
	hud.weapon_buff_cooldown_max = Weapons.active_cooldown(player.weapon_id)
	hud.weapon_buff_edge_cost = Weapons.active_edge_cost(player.weapon_id)
	for weapon: StringName in Weapons.IDS:
		hud.weapon_cooldowns[weapon] = player.active_cooldowns.get(weapon, 0)
	hud.weapon_swap_lockout_ticks = player.swap_lockout
	hud.weapon_swap_lockout_max = Tuning.WEAPON_SWAP_LOCKOUT_TICKS
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
	e.weapon_form = player.active_form()
	e.move_speed_mult = player.move_speed_mult()
	e.combo_max = player.combo_max()
	e.lightning_blink_index = player.last_blink_direction
	e.lightning_blink_tick = player.last_blink_tick
	e.lightning_blink_from = player.last_blink_from
	e.lightning_blink_to = player.last_blink_to
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


## The normal weapon swing (skills are resolved from their SkillAttack objects instead). Reach, damage and Edge gain come
## from the equipped weapon's tables (core/weapons.gd). The Dual Dagger's last swing also calls a lightning strike.
func _resolve_player_attack(events: Array[GameEvent]) -> void:
	if player.attack_hit_done or boss.state == BossState.STATE_DEAD or player.state != PlayerState.STATE_ATTACK_ACTIVE:
		return
	var weapon: StringName = player.weapon_id
	var swing: int = player.combo_index - 1
	var to_boss: Vector2 = boss.position - player.position
	var dist: float = to_boss.length()
	if dist - Tuning.BOSS_RADIUS > Tuning.ATTACK_RANGE * Weapons.range_mults(weapon)[swing]:
		return
	if dist > 0.0001 and player.facing.dot(to_boss / dist) < Tuning.ATTACK_ARC_DOT:
		return
	player.attack_hit_done = true
	var counter: bool = boss.state == BossState.STATE_BROKEN
	var base: float = Tuning.ATTACK_DAMAGE * Weapons.damage_mults(weapon)[swing] * player.swing_damage_mult
	var damage: int
	if counter:
		damage = roundi(base * Tuning.COUNTER_DAMAGE_MULT + player.edge * Tuning.EDGE_COUNTER_BONUS)
		player.edge = 0.0  # the counter spends all Edge
	else:
		damage = maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR))
		player.edge = minf(Tuning.EDGE_MAX, player.edge + Weapons.edge_per_hit(weapon))
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
		"attacker_id": player.id, "target_id": boss.id, "damage": damage,
		"kind": &"counter" if counter else &"normal", "position": boss.position, "combo_index": player.combo_index,
		"weapon_id": weapon,
	}))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(Tuning.NORMAL_HIT_POSTURE, tick, events)
	if Weapons.has_lightning_finisher(weapon) and player.combo_index == Weapons.combo_max(weapon):
		_lightning_strike(counter, events)


## The Dual Dagger finisher connected: a bolt from the sky hits the same boss (no telegraph, it always lands). It uses
## the swing's counter flag (a swing that just broke the posture does not turn the bolt into a counter).
func _lightning_strike(counter: bool, events: Array[GameEvent]) -> void:
	if boss.state == BossState.STATE_DEAD:
		return  # the swing itself finished the boss
	var base: float = Tuning.LIGHTNING_STRIKE_DAMAGE * player.swing_damage_mult
	var damage: int = roundi(base * Tuning.COUNTER_DAMAGE_MULT) if counter else maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR))
	events.append(GameEvent.new(GameEvent.LIGHTNING_STRIKE, tick, {
		"attacker_id": player.id, "target_id": boss.id, "position": boss.position, "damage": damage,
		"combo_index": player.combo_index, "kind": &"counter" if counter else &"normal",
	}))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(Tuning.LIGHTNING_STRIKE_POSTURE, tick, events)


## Lightning Form: a swing that started this tick blinks the player next to the boss first (if the boss is alive and
## within LIGHTNING_BLINK_RANGE). The side comes from LIGHTNING_BLINK_ORDER; if that spot is blocked (wall, prop, out of
## reach) the nearest free direction is used. No spot at all: no blink, the swing happens where the player stands.
func _resolve_lightning_blink(events: Array[GameEvent]) -> void:
	if not player.blink_requested:
		return
	player.blink_requested = false
	if not player.is_lightning_form() or player.state != PlayerState.STATE_ATTACK_WINDUP or boss.state == BossState.STATE_DEAD:
		return
	if player.position.distance_to(boss.position) > Tuning.LIGHTNING_BLINK_RANGE:
		return
	var order: Array[int] = Tuning.LIGHTNING_BLINK_ORDER
	var wanted: int = order[player.blink_count % order.size()]
	player.blink_count += 1
	var reach: float = Tuning.BOSS_RADIUS + Tuning.ATTACK_RANGE * Weapons.range_mults(player.weapon_id)[player.combo_index - 1]
	for offset: int in [0, 1, -1, 2, -2, 3, -3, 4]:
		var index: int = posmod(wanted + offset, 8)
		var spot: Vector2 = blink_spot(index)
		if _blink_spot_ok(spot, reach):
			var from: Vector2 = player.position
			player.apply_blink(spot, boss.position - spot, index, tick)
			events.append(GameEvent.new(GameEvent.LIGHTNING_BLINK, tick, {
				"entity_id": player.id, "from": from, "to": spot, "direction_index": index, "target_id": boss.id,
			}))
			return


## Where a blink in direction `index` (0-7) would land: next to the boss, kept in the arena and out of solid props.
func blink_spot(index: int) -> Vector2:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	var spot: Vector2 = (boss.position + Weapons.blink_direction(index) * Tuning.LIGHTNING_BLINK_DISTANCE).clamp(low, high)
	return push_out_of_obstacles(spot, Tuning.PLAYER_RADIUS).clamp(low, high)


## A blink spot must be inside the arena, outside the boss and every prop, and within the swing's reach of the boss.
func _blink_spot_ok(spot: Vector2, reach: float) -> bool:
	var dist: float = spot.distance_to(boss.position)
	if dist < Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS or dist > reach:
		return false
	for obstacle: Obstacle in obstacles:
		if spot.distance_to(obstacle.center) < obstacle.radius + Tuning.PLAYER_RADIUS - 0.001:
			return false
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	return spot == spot.clamp(low, high)


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
	player.position = push_out_of_obstacles(player.position.clamp(low, high), Tuning.PLAYER_RADIUS).clamp(low, high)
	boss.position = push_out_of_obstacles(boss.position.clamp(low, high), Tuning.BOSS_RADIUS).clamp(low, high)


## Moves a circle of `radius` from `before` towards `after` in steps of at most OBSTACLE_SWEEP_STEP pixels, pushing
## it out of every solid prop after each step: it slides along them and cannot tunnel, however fast it moves.
func move_resolved(before: Vector2, after: Vector2, radius: float) -> Vector2:
	var delta: Vector2 = after - before
	var steps: int = maxi(1, ceili(delta.length() / Tuning.OBSTACLE_SWEEP_STEP))
	var step_delta: Vector2 = delta / steps
	var current: Vector2 = before
	for i: int in steps:
		current = push_out_of_obstacles(current + step_delta, radius)
	return current


## The nearest position at which a circle of `radius` at `point` touches no solid prop.
func push_out_of_obstacles(point: Vector2, radius: float) -> Vector2:
	var current: Vector2 = point
	for pass_index: int in 2:  # a second pass settles a circle squeezed between two props
		for obstacle: Obstacle in obstacles:
			var offset: Vector2 = current - obstacle.center
			var reach: float = obstacle.radius + radius
			var dist_sq: float = offset.length_squared()
			if dist_sq < reach * reach:
				var dist: float = sqrt(dist_sq)
				var dir: Vector2 = offset / dist if dist > 0.0001 else Vector2.DOWN
				current = obstacle.center + dir * reach
	return current


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
