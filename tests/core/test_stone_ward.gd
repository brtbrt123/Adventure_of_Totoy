extends "res://tests/test_case.gd"
## Stone Ward (aspect, 2026-10-21): an instant guard state for STONE_WARD_DURATION_TICKS. Every hit is blocked and its
## damage stored (capped); when the ward ends it releases a shockwave that hits the boss within STONE_WARD_RADIUS.

const Aspects := preload("res://core/aspects.gd")

const BOSS_AT: Vector2 = Vector2(400.0, 240.0)


## Stone Ward in slot 1, full Edge.
func _equip_ward(core: GameCore) -> void:
	core.player.set_equipped_aspects([Aspects.STONE_WARD, Aspects.GALE_CUT, Aspects.MOON_CLEAVE])
	core.player.edge = 100.0


## Open field, a pinned boss at BOSS_AT, the player `dist` px to its left (centre to centre), facing it.
func _core(dist: float = 60.0) -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = BOSS_AT
	core.player.position = BOSS_AT + Vector2(-dist, 0.0)
	core.player.facing = Vector2.RIGHT
	_equip_ward(core)
	return core


func _raise(core: GameCore, move: Vector2 = Vector2.ZERO) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 1
	frame.move = move
	core.step(frame)


func _to(core: GameCore, target: int, frame: InputFrame = null) -> void:
	var f: InputFrame = frame if frame != null else InputFrame.new()
	while core.tick < target and core.result == GameCore.RESULT_PLAYING:
		core.step(f)


## The real arena, the boss starts `attack` aimed at `player_pos`; the ward goes up 10 ticks before the hit. Returns
## [core, blocked amounts, player damage events, release event or null].
func _ward_against(attack: StringName, player_pos: Vector2, between_combo: bool = false) -> Array:
	var core: GameCore = GameCore.new()
	_equip_ward(core)
	core.boss.phase = 2 if attack == BossState.ATTACK_COMBO or attack == BossState.ATTACK_CHARGE else 1
	var hit_tick: int = begin_attack(core, attack, player_pos)
	if between_combo:
		core.player.position = (core.boss.telegraphs[0].center + core.boss.telegraphs[1].center) * 0.5
	_to(core, hit_tick - 11)
	_raise(core)
	assert_eq(core.player.state, PlayerState.STATE_WARD, "the ward is up before " + String(attack))
	var blocked: Array[int] = []
	var hurt: int = 0
	var released: GameEvent = null
	var raised_tick: int = core.tick
	while core.tick < raised_tick + Tuning.STONE_WARD_DURATION_TICKS and core.result == GameCore.RESULT_PLAYING:
		core.step(InputFrame.new())
		for event: GameEvent in core.last_events:
			if event.type == GameEvent.WARD_BLOCKED:
				blocked.append(int(event.data["amount"]))
				assert_eq(event.data["source_id"], core.boss.id)
				assert_eq(event.data["stored"], mini(Tuning.STONE_WARD_STORE_CAP, _sum(blocked)))
				assert_eq(core.player.state, PlayerState.STATE_WARD, "no hurt state: " + String(attack))
				assert_eq(core.player._hurt_invuln, 0, "no hurt invulnerability: " + String(attack))
			if event.type == GameEvent.DAMAGE_TAKEN and event.data["entity_id"] == core.player.id:
				hurt += 1
			if event.type == GameEvent.ATTACK_HIT and event.data["target_id"] == core.player.id:
				hurt += 1
			if event.type == GameEvent.WARD_RELEASED:
				released = event
	return [core, blocked, hurt, released]


func _sum(values: Array[int]) -> int:
	var total: int = 0
	for value: int in values:
		total += value
	return total


func test_the_ward_blocks_every_boss_attack_and_stores_its_damage() -> void:
	var start: Vector2 = Tuning.BOSS_START
	var cases: Array = [
		[BossState.ATTACK_SLAM, Tuning.PLAYER_START, false, [Tuning.SLAM_DAMAGE]],
		[BossState.ATTACK_SWEEP, start + Vector2(-50.0, 0.0), false, [Tuning.SWEEP_DAMAGE]],
		[BossState.ATTACK_SHARDS, start + Vector2(-100.0, 0.0), false, [Tuning.SHARDS_DAMAGE]],
		[BossState.ATTACK_STOMP, start + Vector2(-70.0, 0.0), false, [Tuning.STOMP_DAMAGE]],
		[BossState.ATTACK_COMBO, Tuning.PLAYER_START, true, [Tuning.COMBO_DAMAGE, Tuning.COMBO_DAMAGE]],
		[BossState.ATTACK_CHARGE, start + Vector2(-70.0, 0.0), false, [Tuning.CHARGE_DAMAGE]],
	]
	for case: Array in cases:
		var attack: StringName = case[0]
		var result: Array = _ward_against(attack, case[1], case[2])
		var core: GameCore = result[0]
		var blocked: Array[int] = result[1]
		var expected: Array[int] = []
		expected.assign(case[3])
		assert_eq(blocked, expected, "blocked hits of " + String(attack))
		assert_eq(result[2], 0, "no damage or hit on the player: " + String(attack))
		assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "full HP after " + String(attack))
		var released: GameEvent = result[3]
		assert_true(released != null, "released after " + String(attack))
		if released != null:
			assert_eq(released.data["stored"], mini(Tuning.STONE_WARD_STORE_CAP, _sum(expected)), "stored " + String(attack))
			assert_eq(released.data["reason"], &"expired")
	# Gold attacks are parryable, but the ward just blocks them: no parry, no posture, no retaliation window.
	var gold: Array = _ward_against(BossState.ATTACK_SLAM, Tuning.PLAYER_START)
	var g: GameCore = gold[0]
	assert_eq(g.player.retaliate_ticks, 0, "no Breaking Edge window")
	assert_near(g.player.edge, 100.0 - Tuning.STONE_WARD_EDGE_COST, 0.001, "no parry Edge")


func test_anything_that_calls_take_damage_is_blocked_and_the_store_is_capped() -> void:
	var core: GameCore = _core()
	core.player.combo_index = 1
	_raise(core)
	var events: Array[GameEvent] = []
	assert_false(core.player.take_damage(40, core.tick, events, 99), "not applied")
	assert_eq(core.player.ward_stored, 40)
	assert_false(core.player.take_damage(40, core.tick, events, 99))
	assert_eq(core.player.ward_stored, Tuning.STONE_WARD_STORE_CAP, "capped at 60")
	assert_eq(events.size(), 2)
	assert_eq(events[1].type, GameEvent.WARD_BLOCKED)
	assert_eq(events[1].data["amount"], 40)
	assert_eq(events[1].data["stored"], Tuning.STONE_WARD_STORE_CAP)
	assert_eq(events[1].data["source_id"], 99)
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP)
	assert_eq(core.player.state, PlayerState.STATE_WARD)
	assert_false(core.player.is_invulnerable(), "no hurt invulnerability")
	assert_eq(core.snapshot().player.ward_stored, Tuning.STONE_WARD_STORE_CAP)
	assert_eq(core.snapshot().hud.aspect_slots[0]["stored"], Tuning.STONE_WARD_STORE_CAP)


func test_timing_snapshot_and_hud_row() -> void:
	var core: GameCore = _core()
	_raise(core, Vector2.UP)
	var r: int = core.tick
	var raised: GameEvent = find_event(core, GameEvent.WARD_RAISED)
	assert_true(raised != null, "ward_raised")
	if raised != null:
		assert_eq(raised.data["duration"], Tuning.STONE_WARD_DURATION_TICKS)
		assert_eq(raised.data["facing"], Vector2.UP, "facing locked to the direction it was raised in")
	assert_eq(core.player.facing, Vector2.UP)
	var snap = core.snapshot()
	assert_eq(snap.player.state, &"ward")
	assert_eq(snap.player.ward_ticks_left, Tuning.STONE_WARD_DURATION_TICKS)
	assert_eq(snap.player.ward_stored, 0)
	assert_eq(snap.player.skill_id, &"", "not a skill_* state")
	var row: Dictionary = snap.hud.aspect_slots[0]
	assert_eq(row["aspect_id"], Aspects.STONE_WARD)
	assert_eq(row["name"], "Stone Ward")
	assert_eq(row["kind"], Aspects.KIND_SKILL)
	assert_eq(row["running"], true)
	assert_eq(row["ticks_left"], Tuning.STONE_WARD_DURATION_TICKS)
	assert_eq(row["duration"], Tuning.STONE_WARD_DURATION_TICKS)
	assert_eq(row["cooldown_ticks"], Tuning.STONE_WARD_COOLDOWN_TICKS)
	assert_near(core.player.edge, 100.0 - Tuning.STONE_WARD_EDGE_COST, 0.001, "30 Edge")
	_to(core, r + Tuning.STONE_WARD_DURATION_TICKS - 1)
	assert_eq(core.player.state, PlayerState.STATE_WARD, "still up on raise + 59")
	assert_eq(core.snapshot().player.ward_ticks_left, 1)
	assert_true(find_event(core, GameEvent.WARD_RELEASED) == null)
	core.step(InputFrame.new())
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "down on raise + 60")
	assert_true(find_event(core, GameEvent.WARD_RELEASED) != null, "released on raise + 60")
	assert_eq(core.snapshot().player.ward_ticks_left, 0)
	assert_eq(core.snapshot().hud.aspect_slots[0]["running"], false)
	var events: Array[GameEvent] = []
	assert_true(core.player.take_damage(10, core.tick, events, core.boss.id), "damage lands again once it is down")


func test_cost_and_cooldown_from_the_activation() -> void:
	var poor: GameCore = _core()
	poor.player.edge = Tuning.STONE_WARD_EDGE_COST - 1.0
	_raise(poor)
	assert_eq(poor.player.state, PlayerState.STATE_IDLE, "not enough Edge")
	var core: GameCore = _core()
	_raise(core)
	var r: int = core.tick
	_to(core, r + Tuning.STONE_WARD_COOLDOWN_TICKS - 2)
	core.player.edge = 100.0
	_raise(core)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "one tick early: refused")
	assert_true(find_event(core, GameEvent.WARD_RAISED) == null)
	core.player.edge = 100.0
	_raise(core)
	assert_eq(core.tick, r + Tuning.STONE_WARD_COOLDOWN_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_WARD, "ready 720 ticks after the activation")
	assert_eq(Tuning.STONE_WARD_COOLDOWN_TICKS, 720)
	assert_near(Tuning.STONE_WARD_EDGE_COST, 30.0, 0.0001)


## Raise, store `stored` with direct hits, run to the release. Returns the release tick's core.
func _release(dist: float, stored: int) -> GameCore:
	var core: GameCore = _core(dist)
	_raise(core)
	var r: int = core.tick
	var events: Array[GameEvent] = []
	if stored > 0:
		core.player.take_damage(stored, core.tick, events, core.boss.id)
	_to(core, r + Tuning.STONE_WARD_DURATION_TICKS)
	return core


func test_the_release_hits_inside_the_radius_and_misses_outside() -> void:
	var inside: GameCore = _release(Tuning.BOSS_RADIUS + Tuning.STONE_WARD_RADIUS, 20)
	var released: GameEvent = find_event(inside, GameEvent.WARD_RELEASED)
	var expected: int = maxi(1, roundi((Tuning.STONE_WARD_BASE_DAMAGE + 20.0 * Tuning.STONE_WARD_STORE_MULT) * Tuning.ARMOR_DAMAGE_FACTOR))
	assert_true(released != null)
	if released != null:
		assert_eq(released.data["hit"], true, "the boss circle touches the radius")
		assert_eq(released.data["damage"], expected)
		assert_eq(released.data["stored"], 20)
		assert_eq(released.data["radius"], Tuning.STONE_WARD_RADIUS)
		assert_eq(released.data["position"], inside.player.position)
	assert_eq(inside.boss.hp, Tuning.BOSS_MAX_HP - expected, "(8 + 20) x 0.25 = 7")
	var types: Array[StringName] = event_types(inside)
	assert_true(types.find(GameEvent.WARD_RELEASED) < types.find(GameEvent.ATTACK_HIT) and types.find(GameEvent.ATTACK_HIT) < types.find(GameEvent.DAMAGE_TAKEN), "event order")
	var hit: GameEvent = find_event(inside, GameEvent.ATTACK_HIT)
	if hit != null:
		assert_eq(hit.data["aspect_id"], Aspects.STONE_WARD)
		assert_eq(hit.data["ward_release"], true)
		assert_false(hit.data.has("combo_index"))
		assert_eq(hit.data["kind"], &"normal")
	assert_near(inside.player.edge, 100.0 - Tuning.STONE_WARD_EDGE_COST + Tuning.STONE_WARD_EDGE_GAIN, 0.001, "+10 Edge on a hit")
	assert_near(inside.boss.posture, Tuning.STONE_WARD_POSTURE + 20.0 * Tuning.STONE_WARD_POSTURE_PER_STORED, 0.1, "posture 12 + stored / 2")
	assert_eq(inside.player.ward_stored, 0, "the store is spent")
	var outside: GameCore = _release(Tuning.BOSS_RADIUS + Tuning.STONE_WARD_RADIUS + 0.5, 20)
	var miss: GameEvent = find_event(outside, GameEvent.WARD_RELEASED)
	assert_true(miss != null)
	if miss != null:
		assert_eq(miss.data["hit"], false, "half a pixel out")
		assert_eq(miss.data["damage"], 0)
	assert_eq(outside.boss.hp, Tuning.BOSS_MAX_HP)
	assert_true(find_event(outside, GameEvent.ATTACK_HIT) == null)
	assert_near(outside.player.edge, 100.0 - Tuning.STONE_WARD_EDGE_COST, 0.001, "no Edge on a miss")
	var empty: GameCore = _release(40.0, 0)
	assert_eq(empty.boss.hp, Tuning.BOSS_MAX_HP - roundi(Tuning.STONE_WARD_BASE_DAMAGE * Tuning.ARMOR_DAMAGE_FACTOR), "nothing stored: the base only")


func test_the_release_damage_follows_the_real_hit_rules() -> void:
	var full: GameCore = _release(40.0, 100)
	assert_eq(full.boss.hp, Tuning.BOSS_MAX_HP - roundi((Tuning.STONE_WARD_BASE_DAMAGE + Tuning.STONE_WARD_STORE_CAP) * Tuning.ARMOR_DAMAGE_FACTOR), "a capped store")
	var counter: GameCore = _core(40.0)
	_raise(counter)
	var r: int = counter.tick
	var events: Array[GameEvent] = []
	counter.player.take_damage(20, counter.tick, events, counter.boss.id)
	_to(counter, r + Tuning.STONE_WARD_DURATION_TICKS - 1)
	counter.boss.add_posture(Tuning.BOSS_POSTURE_MAX, counter.tick, events)
	assert_eq(counter.boss.state, BossState.STATE_BROKEN)
	var edge: float = counter.player.edge
	counter.step(InputFrame.new())
	var hit: GameEvent = find_event(counter, GameEvent.ATTACK_HIT)
	assert_true(hit != null and hit.data["kind"] == &"counter", "a counter")
	assert_eq(counter.boss.hp, Tuning.BOSS_MAX_HP - roundi((Tuning.STONE_WARD_BASE_DAMAGE + 20.0) * Tuning.COUNTER_DAMAGE_MULT), "x4")
	assert_near(counter.player.edge, edge, 0.001, "a counter release neither gains nor spends Edge")
	var buffed: GameCore = _core(40.0)
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	buffed.step(active)
	assert_true(buffed.player.is_buff_active(), "katana buff")
	buffed.player.edge = 100.0
	_raise(buffed)
	var rb: int = buffed.tick
	buffed.player.take_damage(20, buffed.tick, events, buffed.boss.id)
	_to(buffed, rb + Tuning.STONE_WARD_DURATION_TICKS)
	assert_eq(buffed.boss.hp, Tuning.BOSS_MAX_HP - roundi((Tuning.STONE_WARD_BASE_DAMAGE + 20.0) * Tuning.BLACK_KATANA_DAMAGE_MULT * Tuning.ARMOR_DAMAGE_FACTOR), "the damage multiplier applies")


func test_death_during_the_ward_releases_nothing() -> void:
	var core: GameCore = _core(40.0)
	_raise(core)
	var events: Array[GameEvent] = []
	core.player.take_damage(20, core.tick, events, core.boss.id)
	core.player.die(core.tick, events)
	assert_eq(core.player.ward_stored, 0)
	assert_false(core.player.ward_release_pending)
	var released: int = 0
	for event: GameEvent in events:
		if event.type == GameEvent.WARD_RELEASED:
			released += 1
	core.step(InputFrame.new())
	released += event_types(core).count(GameEvent.WARD_RELEASED)
	assert_eq(released, 0, "no shockwave")
	assert_eq(core.boss.hp, Tuning.BOSS_MAX_HP)
	assert_eq(core.result, GameCore.RESULT_DEFEAT)


func test_slow_movement_locked_facing_and_no_actions() -> void:
	var core: GameCore = _core(80.0)
	_raise(core)
	var x: float = core.player.position.x
	core.step(input(Vector2.LEFT))
	assert_near(x - core.player.position.x, Tuning.PLAYER_SPEED * Tuning.STONE_WARD_MOVE_FACTOR, 0.0001, "0.3 x walking speed")
	assert_eq(core.player.facing, Vector2.RIGHT, "facing stays locked")
	core.step(input(Vector2.LEFT, true))
	assert_eq(core.player.state, PlayerState.STATE_WARD, "dash blocked")
	assert_true(find_event(core, GameEvent.DASH_STARTED) == null)
	assert_eq(core.player.dash_cooldown, 0, "no dash cooldown spent")
	core.step(input(Vector2.ZERO, false, true, true))
	assert_eq(core.player.state, PlayerState.STATE_WARD, "attack and parry blocked")
	var skill: InputFrame = InputFrame.new()
	skill.skill_pressed = 3
	core.step(skill)
	assert_eq(core.player.state, PlayerState.STATE_WARD, "skills blocked")
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	core.step(active)
	assert_false(core.player.is_buff_active(), "no weapon active while the ward is up")
	var e: InputFrame = InputFrame.new()
	e.aspect_equip = Aspects.SPIRIT_LANTERN
	e.aspect_equip_slot = 2
	core.step(e)
	assert_eq(core.player.equipped_aspects[1], Aspects.GALE_CUT, "no equip while warding")


func test_raised_from_idle_walk_or_swing_recovery_only() -> void:
	var walking: GameCore = _core(80.0)
	walking.step(input(Vector2.UP))
	_raise(walking, Vector2.UP)
	assert_eq(walking.player.state, PlayerState.STATE_WARD, "from walk")
	var recovery: GameCore = _core(80.0)
	recovery.step(input(Vector2.ZERO, false, false, true))
	run(recovery, Tuning.SWING_WINDUP_TICKS[0] + Tuning.SWING_ACTIVE_TICKS[0])
	assert_eq(recovery.player.state, PlayerState.STATE_ATTACK_RECOVERY)
	_raise(recovery)
	assert_eq(recovery.player.state, PlayerState.STATE_WARD, "from a swing's recovery")
	for setup: String in ["windup", "dash", "parry"]:
		var core: GameCore = _core(80.0)
		match setup:
			"windup":
				core.step(input(Vector2.ZERO, false, false, true))
			"dash":
				core.step(input(Vector2.UP, true))
			"parry":
				core.step(input(Vector2.ZERO, false, true))
		_raise(core)
		assert_true(core.player.state != PlayerState.STATE_WARD, "not during " + setup)
		assert_near(core.player.edge, 100.0, 0.001, "nothing spent during " + setup)
