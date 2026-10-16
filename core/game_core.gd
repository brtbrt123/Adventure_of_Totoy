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

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func step(input: InputFrame) -> void:
	last_events = []
	if result != RESULT_PLAYING:
		result_ticks += 1
		return
	tick += 1
	var events: Array[GameEvent] = []
	player.step(input, tick, events)
	_resolve_player_attack(events)
	boss.step(tick, player.position, _rng, events)
	_resolve_telegraphs(events)
	_keep_in_arena()
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


func _resolve_player_attack(events: Array[GameEvent]) -> void:
	if player.state != PlayerState.STATE_ATTACK_ACTIVE or player.attack_hit_done:
		return
	if boss.state == BossState.STATE_DEAD:
		return
	var to_boss: Vector2 = boss.position - player.position
	var dist: float = to_boss.length()
	var swing: int = player.combo_index - 1
	if dist - Tuning.BOSS_RADIUS > Tuning.ATTACK_RANGE * Tuning.SWING_RANGE_MULT[swing]:
		return
	if dist > 0.0001 and player.facing.dot(to_boss / dist) < Tuning.ATTACK_ARC_DOT:
		return
	player.attack_hit_done = true
	var counter: bool = boss.state == BossState.STATE_BROKEN
	var damage: int
	if counter:
		damage = roundi(Tuning.ATTACK_DAMAGE * Tuning.SWING_DAMAGE_MULT[swing] * Tuning.COUNTER_DAMAGE_MULT + player.edge * Tuning.EDGE_COUNTER_BONUS)
		player.edge = 0.0  # the counter spends all Edge
	else:
		damage = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.SWING_DAMAGE_MULT[swing] * Tuning.ARMOR_DAMAGE_FACTOR))
		player.edge = minf(Tuning.EDGE_MAX, player.edge + Tuning.EDGE_PER_HIT)
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
		"attacker_id": player.id, "target_id": boss.id, "damage": damage,
		"kind": &"counter" if counter else &"normal", "position": boss.position, "combo_index": player.combo_index,
	}))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(Tuning.NORMAL_HIT_POSTURE, tick, events)


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


func _keep_in_arena() -> void:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	player.position = player.position.clamp(low, high)
	boss.position = boss.position.clamp(low, high)
	# The boss is solid: push the player out of it.
	var min_dist: float = Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS
	var offset: Vector2 = player.position - boss.position
	if offset.length() < min_dist:
		var push_dir: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else Vector2.LEFT
		player.position = (boss.position + push_dir * min_dist).clamp(low, high)


func _check_result(events: Array[GameEvent]) -> void:
	if boss.state == BossState.STATE_DEAD:
		result = RESULT_VICTORY
	elif player.state == PlayerState.STATE_DEAD:
		result = RESULT_DEFEAT
	else:
		return
	events.append(GameEvent.new(GameEvent.GAME_RESULT, tick, {"result": result}))
