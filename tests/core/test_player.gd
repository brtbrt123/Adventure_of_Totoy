extends "res://tests/test_case.gd"


func test_walk_speed() -> void:
	var core: GameCore = GameCore.new()
	var start_x: float = core.player.position.x
	run(core, 10, input(Vector2.RIGHT))
	assert_near(core.player.position.x - start_x, 10.0 * Tuning.PLAYER_SPEED, 0.001, "10 ticks of walking")


func test_diagonal_walk_is_not_faster() -> void:
	var core: GameCore = GameCore.new()
	var start: Vector2 = core.player.position
	run(core, 10, input(Vector2(1.0, 1.0)))
	assert_near(core.player.position.distance_to(start), 10.0 * Tuning.PLAYER_SPEED, 0.001, "diagonal distance")


func test_dash_distance_and_cooldown() -> void:
	var core: GameCore = GameCore.new()
	var start_x: float = core.player.position.x
	core.step(input(Vector2.RIGHT, true))
	assert_true(event_types(core).has(GameEvent.DASH_STARTED), "dash_started event")
	assert_eq(core.player.state, PlayerState.STATE_DASH)
	run(core, Tuning.DASH_TICKS)
	assert_near(core.player.position.x - start_x, Tuning.DASH_TICKS * Tuning.DASH_SPEED, 0.001, "dash distance")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "dash ends")
	core.step(input(Vector2.RIGHT, true))
	assert_false(event_types(core).has(GameEvent.DASH_STARTED), "second dash blocked by cooldown")
	run(core, Tuning.DASH_COOLDOWN_TICKS)
	assert_eq(core.player.dash_cooldown, 0, "cooldown elapsed")
	core.step(input(Vector2.RIGHT, true))
	assert_true(event_types(core).has(GameEvent.DASH_STARTED), "dash available again")


func test_dash_ready_event_fires_once_cooldown_ends() -> void:
	var core: GameCore = GameCore.new()
	core.step(input(Vector2.RIGHT, true))
	var ready_seen: bool = false
	for i: int in Tuning.DASH_COOLDOWN_TICKS + 2:
		core.step(input())
		if event_types(core).has(GameEvent.DASH_READY):
			ready_seen = true
	assert_true(ready_seen, "dash_ready event")


func test_dash_invulnerability_window() -> void:
	var core: GameCore = GameCore.new()
	core.step(input(Vector2.RIGHT, true))
	assert_true(core.player.is_invulnerable(), "invulnerable at dash start")
	for i: int in Tuning.DASH_INVULN_TICKS - 1:
		core.step(input())
	assert_true(core.player.is_invulnerable(), "invulnerable on the last i-frame")
	core.step(input())
	assert_false(core.player.is_invulnerable(), "vulnerable once the i-frames are over")
	assert_true(Tuning.DASH_INVULN_TICKS >= Tuning.DASH_TICKS, "i-frames cover the whole dash")


func test_dash_is_short() -> void:
	var core: GameCore = GameCore.new()
	var start_x: float = core.player.position.x
	core.step(input(Vector2.RIGHT, true))
	run(core, Tuning.DASH_TICKS + 2)
	assert_true(core.player.position.x - start_x <= 32.0, "dash covers at most 32 px")


func test_player_stays_in_arena() -> void:
	var core: GameCore = GameCore.new()
	core.player.position = Vector2(-50.0, -50.0)
	core.step(input())
	assert_near(core.player.position.x, Tuning.ARENA_MARGIN, 0.001, "left wall")
	assert_near(core.player.position.y, Tuning.ARENA_MARGIN, 0.001, "top wall")
	core.player.position = Tuning.ARENA_SIZE + Vector2(50.0, 50.0)
	core.step(input())
	assert_near(core.player.position.x, Tuning.ARENA_SIZE.x - Tuning.ARENA_MARGIN, 0.001, "right wall")
	assert_near(core.player.position.y, Tuning.ARENA_SIZE.y - Tuning.ARENA_MARGIN, 0.001, "bottom wall")


func test_boss_is_solid() -> void:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000  # keep the boss passive for this test
	core.player.position = core.boss.position + Vector2(-30.0, 0.0)
	run(core, 30, input(Vector2.RIGHT))
	var gap: float = core.player.position.distance_to(core.boss.position)
	assert_true(gap >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.01, "player cannot walk into the boss, gap %s" % str(gap))


func test_attack_sequence_and_edge_gain() -> void:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000
	core.player.position = core.boss.position + Vector2(-30.0, 0.0)
	core.player.facing = Vector2.RIGHT
	var hp_before: int = core.boss.hp
	core.step(input(Vector2.ZERO, false, false, true))
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP)
	run(core, Tuning.ATTACK_WINDUP_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_ACTIVE, "active after the windup")
	assert_true(core.boss.hp < hp_before, "the sword hit the boss")
	assert_near(core.player.edge, Tuning.EDGE_PER_HIT, 0.001, "a normal hit builds Edge")
	run(core, Tuning.ATTACK_ACTIVE_TICKS + Tuning.ATTACK_RECOVERY_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "attack ends")


func test_normal_hit_is_weak_against_armored_boss() -> void:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000
	core.player.position = core.boss.position + Vector2(-30.0, 0.0)
	core.player.facing = Vector2.RIGHT
	core.step(input(Vector2.ZERO, false, false, true))
	run(core, Tuning.ATTACK_WINDUP_TICKS)
	var expected: int = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.ARMOR_DAMAGE_FACTOR))
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, expected, "armored damage")
	assert_near(core.boss.posture, Tuning.NORMAL_HIT_POSTURE, 0.1, "a normal hit adds a little posture")


func test_missed_parry_blocks_dash_and_attack_until_recovery_ends() -> void:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000
	core.step(input(Vector2.ZERO, false, true))
	assert_eq(core.player.state, PlayerState.STATE_PARRY, "parry press opens the window")
	for i: int in Tuning.PARRY_ACTIVE_TICKS:
		core.step(input())
		if event_types(core).has(GameEvent.PARRY_FAILED):
			break
	assert_true(event_types(core).has(GameEvent.PARRY_FAILED), "missed parry emits parry_failed")
	assert_eq(core.player.state, PlayerState.STATE_PARRY_RECOVERY, "missed parry starts recovery")

	var recovery_start_tick: int = core.tick
	for recovery_tick: int in range(1, Tuning.PARRY_WHIFF_RECOVERY_TICKS):
		var dash_pressed: bool = recovery_tick % 2 == 1
		core.step(input(Vector2.ZERO, dash_pressed, false, not dash_pressed))
		assert_false(event_types(core).has(GameEvent.DASH_STARTED), "dash blocked during parry recovery")
		assert_eq(core.player.state, PlayerState.STATE_PARRY_RECOVERY, "dash and attack cannot interrupt parry recovery")
	core.step(input())
	assert_eq(core.tick - recovery_start_tick, Tuning.PARRY_WHIFF_RECOVERY_TICKS, "full whiff recovery elapsed")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "recovery ends after the configured ticks")
	core.step(input(Vector2.RIGHT, true))
	assert_true(event_types(core).has(GameEvent.DASH_STARTED), "dash available after parry recovery")
	assert_eq(core.player.state, PlayerState.STATE_DASH, "dash starts after parry recovery")
