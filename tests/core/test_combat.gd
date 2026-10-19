extends "res://tests/test_case.gd"
## The combat language: gold can be parried, red must be dodged.

const FAR_FROM_BOSS: Vector2 = Tuning.PLAYER_START
const IN_SWEEP_RANGE: Vector2 = Tuning.BOSS_START + Vector2(-40.0, 0.0)


func test_boss_starts_its_first_attack_after_the_delay() -> void:
	var core: GameCore = GameCore.new()
	run(core, Tuning.BOSS_FIRST_ATTACK_DELAY_TICKS - 1)
	assert_eq(core.boss.state, BossState.STATE_IDLE, "still idle one tick before")
	core.step(input())
	assert_eq(core.boss.state, BossState.STATE_ATTACK, "attacking on the delay tick")
	assert_true(event_types(core).has(GameEvent.ATTACK_TELEGRAPHED), "attack_telegraphed event")
	assert_false(core.boss.telegraphs.is_empty(), "telegraph exists")


func test_unparried_slam_hurts() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SLAM, FAR_FROM_BOSS)
	run_to_tick(core, hit_tick)
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP - Tuning.SLAM_DAMAGE, "slam damage")
	assert_false(event_types(core).has(GameEvent.PARRY_SUCCEEDED), "no parry")


func test_perfect_parry_breaks_posture() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SLAM, FAR_FROM_BOSS)
	run_to_tick(core, hit_tick - 2)
	core.step(input(Vector2.ZERO, false, true))  # press 2 ticks before impact... tick hit_tick - 1
	run_to_tick(core, hit_tick - 1)
	core.step(input())  # the impact tick
	assert_eq(core.tick, hit_tick)
	var parry: GameEvent = find_event(core, GameEvent.PARRY_SUCCEEDED)
	assert_true(parry != null, "parry_succeeded")
	if parry != null:
		assert_eq(parry.data["quality"], &"perfect", "quality")
	assert_eq(core.boss.state, BossState.STATE_BROKEN, "boss posture broken")
	assert_true(event_types(core).has(GameEvent.POSTURE_BROKEN), "posture_broken event")
	assert_true(event_types(core).has(GameEvent.COUNTER_WINDOW_OPENED), "counter_window_opened event")
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "no damage taken")
	assert_true(core.boss.telegraphs.is_empty(), "a broken boss drops its attack")
	assert_near(core.player.edge, Tuning.EDGE_PER_PARRY, 0.001, "a parry builds Edge")


func test_early_deflection_gives_partial_posture() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SLAM, FAR_FROM_BOSS)
	var press_tick: int = hit_tick - (Tuning.PARRY_PERFECT_TICKS + 3)  # inside the window, outside the perfect part
	run_to_tick(core, press_tick - 1)
	core.step(input(Vector2.ZERO, false, true))
	assert_eq(core.tick, press_tick)
	run_to_tick(core, hit_tick - 1)
	core.step(input())
	var parry: GameEvent = find_event(core, GameEvent.PARRY_SUCCEEDED)
	assert_true(parry != null, "parry_succeeded")
	if parry != null:
		assert_eq(parry.data["quality"], &"early", "quality")
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "no damage taken")
	assert_near(core.boss.posture, Tuning.PARRY_EARLY_POSTURE, 0.5, "partial posture")
	assert_true(core.boss.state != BossState.STATE_BROKEN, "not broken by an early deflection")


func test_parry_too_early_whiffs_and_the_slam_lands() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SLAM, FAR_FROM_BOSS)
	var press_tick: int = hit_tick - (Tuning.PARRY_ACTIVE_TICKS + 8)
	run_to_tick(core, press_tick - 1)
	core.step(input(Vector2.ZERO, false, true))
	var whiffed: bool = false
	while core.tick < hit_tick:
		core.step(input())
		if event_types(core).has(GameEvent.PARRY_FAILED):
			whiffed = true
	assert_true(whiffed, "parry_failed event when the window passes with nothing to parry")
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP - Tuning.SLAM_DAMAGE, "the slam landed")


func test_perfect_parry_cancels_a_gold_sweep() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SWEEP, IN_SWEEP_RANGE)
	run_to_tick(core, hit_tick - 3)
	core.step(input(Vector2.ZERO, false, true))
	run_to_tick(core, hit_tick)
	assert_true(event_types(core).has(GameEvent.PARRY_SUCCEEDED), "gold sweep is parryable")
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "parried sweep does no damage")
	assert_eq(core.boss.state, BossState.STATE_BROKEN, "perfect sweep parry breaks posture")


func test_dash_i_frames_dodge_a_gold_sweep() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SWEEP, IN_SWEEP_RANGE)
	run_to_tick(core, hit_tick - 3)
	core.step(input(Vector2.LEFT, true))  # dash away, i-frames cover the danger window
	run_to_tick(core, core.boss.telegraphs[0].end_tick + 2)
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "no damage while dashing through the sweep")


func test_standing_still_in_a_gold_sweep_hurts_and_stepping_out_does_not() -> void:
	var hurt: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(hurt, BossState.ATTACK_SWEEP, IN_SWEEP_RANGE)
	run_to_tick(hurt, hit_tick)
	assert_eq(hurt.player.hp, Tuning.PLAYER_MAX_HP - Tuning.SWEEP_DAMAGE, "standing in the cone")
	var safe: GameCore = GameCore.new()
	hit_tick = begin_attack(safe, BossState.ATTACK_SWEEP, IN_SWEEP_RANGE)
	while safe.tick < hit_tick:
		safe.step(input(Vector2.LEFT))  # walk out of the 80px cone during the warning
	run_to_tick(safe, safe.boss.telegraphs[0].end_tick + 1)
	assert_eq(safe.player.hp, Tuning.PLAYER_MAX_HP, "walking out during the warning avoids the sweep")


func test_warning_matches_the_real_hit_area() -> void:
	# Fair tells: for every point on a grid, the sweep damages the player exactly when the telegraph
	# geometry (the one presentation draws) overlaps the player.
	var mismatches: int = 0
	for gx: int in range(-2, 11):
		for gy: int in range(-6, 7):
			var core: GameCore = GameCore.new()
			var pos: Vector2 = Tuning.BOSS_START + Vector2(-100.0 + gx * 14.0, gy * 14.0)
			var hit_tick: int = begin_attack(core, BossState.ATTACK_SWEEP, pos)
			var telegraph: Telegraph = core.boss.telegraphs[0]
			core.player.position = pos
			run_to_tick(core, hit_tick)
			var overlapped: bool = telegraph.overlaps_circle(core.player.position, Tuning.PLAYER_RADIUS)
			var damaged: bool = core.player.hp < Tuning.PLAYER_MAX_HP
			if overlapped != damaged:
				mismatches += 1
	assert_eq(mismatches, 0, "warning/hit mismatches")


func test_aim_is_locked_when_the_attack_commits() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SHARDS, IN_SWEEP_RANGE)
	var directions: Array[Vector2] = []
	for telegraph: Telegraph in core.boss.telegraphs:
		directions.append(telegraph.direction)
	assert_eq(directions.size(), 3, "three shards")
	while core.tick < hit_tick:
		core.step(input(Vector2.UP))  # the player runs around during the warning
	for i: int in directions.size():
		assert_eq(core.boss.telegraphs[i].direction, directions[i], "shard %d direction never changes" % i)


func test_broken_boss_cancels_its_attack_and_takes_counter_damage() -> void:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000
	core.player.position = core.boss.position + Vector2(-30.0, 0.0)
	core.player.facing = Vector2.RIGHT
	core.player.edge = 50.0
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	assert_eq(core.boss.state, BossState.STATE_BROKEN)
	core.step(input(Vector2.ZERO, false, false, true))
	run(core, Tuning.ATTACK_WINDUP_TICKS)
	var expected: int = roundi(Tuning.ATTACK_DAMAGE * Tuning.COUNTER_DAMAGE_MULT + 50.0 * Tuning.EDGE_COUNTER_BONUS)
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, expected, "counter damage")
	assert_near(core.player.edge, 0.0, 0.001, "the counter spends Edge")
	assert_true(expected > Tuning.ATTACK_DAMAGE * 3, "a counter is much stronger than a normal hit")


func test_counter_window_lasts_one_second_then_closes() -> void:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	run(core, Tuning.BOSS_BREAK_TICKS - 1)
	assert_eq(core.boss.state, BossState.STATE_BROKEN, "still broken one tick before the end")
	core.step(input())
	assert_true(event_types(core).has(GameEvent.COUNTER_WINDOW_CLOSED), "counter_window_closed event")
	assert_true(core.boss.state != BossState.STATE_BROKEN, "boss recovers")
	assert_near(core.boss.posture, 0.0, 0.001, "posture resets")
	assert_eq(Tuning.BOSS_BREAK_TICKS, 60, "harder boss has a one-second opening")


func test_phase_two_at_half_health() -> void:
	var core: GameCore = GameCore.new()
	var events: Array[GameEvent] = []
	core.boss.take_damage(Tuning.BOSS_MAX_HP / 2, 1, events, 1)
	assert_eq(core.boss.phase, 2)
	var seen: bool = false
	for event: GameEvent in events:
		if event.type == GameEvent.BOSS_PHASE_CHANGED:
			seen = true
	assert_true(seen, "boss_phase_changed event")


func test_victory_and_defeat() -> void:
	var win: GameCore = GameCore.new()
	win.boss.cooldown = 100000
	win.player.position = win.boss.position + Vector2(-30.0, 0.0)
	win.player.facing = Vector2.RIGHT
	win.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	win.boss.hp = 5
	win.step(input(Vector2.ZERO, false, false, true))
	run(win, Tuning.ATTACK_WINDUP_TICKS)
	assert_eq(win.result, GameCore.RESULT_VICTORY, "victory when the boss dies")
	assert_true(find_event(win, GameEvent.GAME_RESULT) != null, "game_result event")
	var before: int = win.tick
	win.step(input())
	assert_eq(win.tick, before, "the simulation stops after the result")

	var lose: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(lose, BossState.ATTACK_SLAM, FAR_FROM_BOSS)
	lose.player.hp = 10
	run_to_tick(lose, hit_tick)
	assert_eq(lose.result, GameCore.RESULT_DEFEAT, "defeat when the player dies")
	assert_eq(lose.player.state, PlayerState.STATE_DEAD)


func test_hurt_invulnerability_prevents_double_hits() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SHARDS, IN_SWEEP_RANGE)
	run_to_tick(core, core.boss.telegraphs[0].end_tick + 1)
	assert_true(core.player.hp >= Tuning.PLAYER_MAX_HP - Tuning.SHARDS_DAMAGE, "overlapping shards do not stack damage at once")
	assert_true(hit_tick > 0)


func test_same_seed_and_inputs_give_the_same_fight() -> void:
	var a: GameCore = GameCore.new(7)
	var b: GameCore = GameCore.new(7)
	for i: int in 900:
		var move: Vector2 = Vector2(sin(i * 0.05), cos(i * 0.031))
		var frame: InputFrame = input(move, i % 90 == 0, i % 130 == 5, i % 47 == 3)
		a.step(frame)
		b.step(frame)
	assert_eq(a.player.position, b.player.position, "player position")
	assert_eq(a.player.hp, b.player.hp, "player hp")
	assert_eq(a.boss.position, b.boss.position, "boss position")
	assert_eq(a.boss.hp, b.boss.hp, "boss hp")
	assert_eq(a.boss.state, b.boss.state, "boss state")
	assert_eq(a.tick, b.tick)


func test_snapshot_exposes_telegraph_geometry() -> void:
	var core: GameCore = GameCore.new()
	begin_attack(core, BossState.ATTACK_SWEEP, IN_SWEEP_RANGE)
	var snap: GameCore.Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.telegraphs.size(), 1)
	assert_eq(snap.telegraphs[0].kind, Telegraph.KIND_GOLD)
	assert_eq(snap.telegraphs[0].shape, Telegraph.SHAPE_CONE)
	assert_eq(snap.telegraphs[0].hit_tick, core.boss.telegraphs[0].hit_tick)
	assert_eq(snap.entities[0].visual_id, &"mossbound_colossus")
	assert_eq(snap.player.visual_id, &"totoy")
	assert_eq(snap.hud.boss_max_hp, Tuning.BOSS_MAX_HP)


func test_early_sweep_deflect_and_red_shards_stays_unparryable() -> void:
	var sweep: GameCore = GameCore.new()
	var hit: int = begin_attack(sweep, BossState.ATTACK_SWEEP, IN_SWEEP_RANGE)
	run_to_tick(sweep, hit - Tuning.PARRY_PERFECT_TICKS - 2)
	sweep.step(input(Vector2.ZERO, false, true))
	run_to_tick(sweep, hit)
	assert_eq(sweep.player.hp, Tuning.PLAYER_MAX_HP, "early sweep deflect prevents damage")
	assert_true(event_types(sweep).has(GameEvent.PARRY_SUCCEEDED), "early sweep parry event")
	assert_true(sweep.boss.posture > 0.0 and sweep.boss.state != BossState.STATE_BROKEN, "early deflect gives partial posture")
	var shards: GameCore = GameCore.new()
	hit = begin_attack(shards, BossState.ATTACK_SHARDS, IN_SWEEP_RANGE)
	run_to_tick(shards, hit - 3)
	shards.step(input(Vector2.ZERO, false, true))
	run_to_tick(shards, hit)
	assert_false(event_types(shards).has(GameEvent.PARRY_SUCCEEDED), "red beam remains dodge-only")
	assert_true(shards.player.hp < Tuning.PLAYER_MAX_HP, "beam hits through parry")
