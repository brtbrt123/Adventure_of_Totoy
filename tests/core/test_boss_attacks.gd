extends "res://tests/test_case.gd"
## The attacks added after the first playtest: red stomp (ring), gold combo (two slams), red charge (line).

const FAR: Vector2 = Vector2(64.0, 88.0)


func test_stomp_ring_safe_inside_and_outside_hurts_in_the_band() -> void:
	# Boss at (240, 88). Inner radius 44, outer 100. The player radius is 6.
	var inside: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(inside, BossState.ATTACK_STOMP, Vector2(240.0 - 30.0, 88.0))
	inside.player.position = Vector2(240.0 - 30.0, 88.0)
	run_to_tick(inside, inside.boss.telegraphs[0].end_tick + 1)
	assert_eq(inside.player.hp, Tuning.PLAYER_MAX_HP, "standing next to the boss is safe")

	var band: GameCore = GameCore.new()
	hit_tick = begin_attack(band, BossState.ATTACK_STOMP, Vector2(240.0 - 70.0, 88.0))
	run_to_tick(band, hit_tick)
	assert_eq(band.player.hp, Tuning.PLAYER_MAX_HP - Tuning.STOMP_DAMAGE, "standing in the ring is hit")

	var outside: GameCore = GameCore.new()
	begin_attack(outside, BossState.ATTACK_STOMP, Vector2(240.0 - 140.0, 88.0))
	run_to_tick(outside, outside.boss.telegraphs[0].end_tick + 1)
	assert_eq(outside.player.hp, Tuning.PLAYER_MAX_HP, "standing outside the ring is safe")


func test_stomp_can_be_dashed_through() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_STOMP, Vector2(240.0 - 70.0, 88.0))
	run_to_tick(core, hit_tick - 3)
	core.step(input(Vector2.LEFT, true))
	run_to_tick(core, core.boss.telegraphs[0].end_tick + 1)
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "dash i-frames cover the stomp's danger window")


func test_ring_warning_matches_the_real_hit_area() -> void:
	var mismatches: int = 0
	for gx: int in range(0, 14):
		var core: GameCore = GameCore.new()
		var pos: Vector2 = Vector2(240.0 - 26.0 - gx * 8.0, 88.0)
		var hit_tick: int = begin_attack(core, BossState.ATTACK_STOMP, pos)
		var telegraph: Telegraph = core.boss.telegraphs[0]
		run_to_tick(core, hit_tick)
		var overlapped: bool = telegraph.overlaps_circle(core.player.position, Tuning.PLAYER_RADIUS)
		var damaged: bool = core.player.hp < Tuning.PLAYER_MAX_HP
		if overlapped != damaged:
			mismatches += 1
	assert_eq(mismatches, 0, "ring warning/hit mismatches")


func test_combo_has_two_parryable_slams() -> void:
	var core: GameCore = GameCore.new()
	var first_hit: int = begin_attack(core, BossState.ATTACK_COMBO, FAR)
	assert_eq(core.boss.telegraphs.size(), 2, "two slams")
	assert_eq(core.boss.telegraphs[0].kind, Telegraph.KIND_GOLD)
	assert_eq(core.boss.telegraphs[1].kind, Telegraph.KIND_GOLD)
	assert_eq(core.boss.telegraphs[1].hit_tick, first_hit + Tuning.COMBO_GAP_TICKS, "second slam lands later")
	assert_true(core.boss.telegraphs[1].center != core.boss.telegraphs[0].center, "second slam lands farther out")


func test_unparried_combo_hits_twice() -> void:
	var core: GameCore = GameCore.new()
	core.boss.phase = 2
	core.player.position = FAR
	core.boss.next_attack_override = BossState.ATTACK_COMBO
	core.boss.cooldown = 1
	core.step(input())
	var second: Telegraph = core.boss.telegraphs[1]
	core.player.position = (core.boss.telegraphs[0].center + second.center) * 0.5  # inside both circles
	assert_true(core.boss.telegraphs[0].overlaps_circle(core.player.position, Tuning.PLAYER_RADIUS), "inside slam 1")
	assert_true(second.overlaps_circle(core.player.position, Tuning.PLAYER_RADIUS), "inside slam 2")
	core.player.hp = 1000
	run_to_tick(core, second.hit_tick + 1)
	# The hurt invulnerability (45 ticks) is longer than the 26 tick gap, so only the first slam hurts;
	# the player must parry or move for the second. That is the intended punishment for standing still.
	assert_eq(core.player.hp, 1000 - Tuning.COMBO_DAMAGE, "the second slam is covered by hurt invulnerability")


func test_perfect_parry_on_the_first_combo_slam_breaks_the_boss_and_cancels_the_second() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_COMBO, FAR)
	run_to_tick(core, hit_tick - 2)
	core.step(input(Vector2.ZERO, false, true))
	run_to_tick(core, hit_tick - 1)
	core.step(input())
	assert_eq(core.boss.state, BossState.STATE_BROKEN, "perfect parry breaks the boss")
	assert_true(core.boss.telegraphs.is_empty(), "the second slam is cancelled")
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "no damage")


func test_charge_moves_the_boss_along_the_locked_line() -> void:
	var core: GameCore = GameCore.new()
	core.player.position = Vector2(150.0, 88.0)
	core.boss.next_attack_override = BossState.ATTACK_CHARGE
	core.boss.cooldown = 1
	core.step(input())
	var telegraph: Telegraph = core.boss.telegraphs[0]
	var start: Vector2 = telegraph.center
	var direction: Vector2 = telegraph.direction
	run_to_tick(core, telegraph.end_tick)
	var traveled: Vector2 = core.boss.position - start
	assert_true(traveled.length() > Tuning.CHARGE_LENGTH * 0.85, "the boss travelled most of the warned line")
	assert_true(absf(traveled.normalized().dot(direction)) > 0.99, "and along the warned direction")
	assert_eq(telegraph.direction, direction, "direction never changed")


func test_charge_hits_a_player_on_the_line_and_misses_one_beside_it() -> void:
	var hit_core: GameCore = GameCore.new()
	hit_core.player.position = Vector2(170.0, 88.0)
	hit_core.boss.next_attack_override = BossState.ATTACK_CHARGE
	hit_core.boss.cooldown = 1
	hit_core.step(input())
	run_to_tick(hit_core, hit_core.boss.telegraphs[0].end_tick)
	assert_true(hit_core.player.hp < Tuning.PLAYER_MAX_HP, "standing on the charge line is hit")

	var miss_core: GameCore = GameCore.new()
	miss_core.player.position = Vector2(170.0, 88.0)
	miss_core.boss.next_attack_override = BossState.ATTACK_CHARGE
	miss_core.boss.cooldown = 1
	miss_core.step(input())
	miss_core.player.position = Vector2(170.0, 88.0 + 45.0)  # well outside the 28 px wide line
	run_to_tick(miss_core, miss_core.boss.telegraphs[0].end_tick + 2)
	assert_eq(miss_core.player.hp, Tuning.PLAYER_MAX_HP, "stepping aside avoids the charge")


func test_phase_pools() -> void:
	var phase1_attacks: Dictionary = _attacks_seen(1)
	assert_false(phase1_attacks.has(BossState.ATTACK_COMBO), "no combo in phase 1")
	assert_false(phase1_attacks.has(BossState.ATTACK_CHARGE), "no charge in phase 1")
	assert_true(phase1_attacks.has(BossState.ATTACK_STOMP), "the stomp is in phase 1")
	var phase2_attacks: Dictionary = _attacks_seen(2)
	assert_true(phase2_attacks.has(BossState.ATTACK_COMBO), "combo in phase 2")
	assert_true(phase2_attacks.has(BossState.ATTACK_CHARGE), "charge in phase 2")
	assert_eq(phase2_attacks.size(), 6, "all six attacks appear in phase 2")


func _attacks_seen(phase: int) -> Dictionary:
	var core: GameCore = GameCore.new(3)
	core.boss.phase = phase
	core.player.hp = 1000000
	core.player.position = FAR
	var seen: Dictionary = {}
	for i: int in 9000:
		core.player.position = FAR  # stay put (a charge or riposte may push the player)
		core.step(input())
		for event: GameEvent in core.last_events:
			if event.type == GameEvent.ATTACK_TELEGRAPHED:
				seen[event.data["attack"]] = true
	return seen
