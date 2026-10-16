extends "res://tests/test_case.gd"
## The three-swing sword combo: chaining, input buffering, resets and one hit per swing.

const Snapshots := preload("res://core/snapshots.gd")


func _core_next_to_boss() -> GameCore:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000  # keep the boss passive
	core.player.position = core.boss.position + Vector2(-30.0, 0.0)
	core.player.facing = Vector2.RIGHT
	return core


func _press(core: GameCore) -> void:
	core.step(input(Vector2.ZERO, false, false, true))


func _swing_ticks(swing: int) -> int:
	return Tuning.SWING_WINDUP_TICKS[swing] + Tuning.SWING_ACTIVE_TICKS[swing] + Tuning.SWING_RECOVERY_TICKS[swing]


func _recovery_ticks(core: GameCore) -> int:
	return Tuning.SWING_RECOVERY_TICKS[core.player.combo_index - 1]


## Step with no input until the current swing is in recovery with `state_ticks == ticks`.
func _advance_recovery_to(core: GameCore, ticks: int) -> void:
	var guard: int = 0
	while not (core.player.state == PlayerState.STATE_ATTACK_RECOVERY and core.player.state_ticks == ticks):
		core.step(input())
		guard += 1
		if guard >= 200:
			assert_true(false, "never reached recovery tick %d" % ticks)
			return


## From the start of a swing: press on the first tick of the buffer window, then step to the end of the recovery.
func _chain_next(core: GameCore) -> void:
	_advance_recovery_to(core, _recovery_ticks(core) - Tuning.COMBO_BUFFER_TICKS - 1)
	_press(core)
	run(core, Tuning.COMBO_BUFFER_TICKS)  # the recovery ends on the last of these ticks


func _hit_count(core: GameCore, ticks: int) -> int:
	var hits: int = 0
	for i: int in ticks:
		core.step(input())
		for type: StringName in event_types(core):
			if type == GameEvent.ATTACK_HIT:
				hits += 1
	return hits


func test_repeated_presses_chain_one_two_three() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP)
	assert_eq(core.player.combo_index, 1, "first press starts swing 1")
	_chain_next(core)
	assert_eq(core.player.combo_index, 2, "buffered press chains to swing 2")
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP, "swing 2 starts without an idle gap")
	_chain_next(core)
	assert_eq(core.player.combo_index, 3, "and to swing 3")
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP)


func test_swing_timings_follow_tuning() -> void:
	for swing: int in Tuning.COMBO_MAX:
		var core: GameCore = _core_next_to_boss()
		core.player._start_swing(swing + 1)
		var label: String = "swing %d" % (swing + 1)
		run(core, Tuning.SWING_WINDUP_TICKS[swing] - 1)
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP, "still winding up, " + label)
		core.step(input())
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_ACTIVE, "active after the windup, " + label)
		run(core, Tuning.SWING_ACTIVE_TICKS[swing])
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_RECOVERY, "recovery after the active ticks, " + label)
		run(core, Tuning.SWING_RECOVERY_TICKS[swing])
		assert_eq(core.player.state, PlayerState.STATE_IDLE, "idle after the recovery, " + label)


func test_press_before_the_buffer_window_is_ignored() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	_press(core)  # during windup
	run(core, Tuning.SWING_WINDUP_TICKS[0])
	_press(core)  # during active
	_advance_recovery_to(core, _recovery_ticks(core) - Tuning.COMBO_BUFFER_TICKS - 2)
	_press(core)  # state_ticks becomes recovery - buffer - 1: one tick before the window
	assert_false(core.player._combo_queued, "nothing buffered")
	run(core, _recovery_ticks(core))
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "early presses did not queue a swing")


func test_press_on_the_first_and_the_last_tick_of_the_window_both_chain() -> void:
	var first: GameCore = _core_next_to_boss()
	_press(first)
	_chain_next(first)
	assert_eq(first.player.combo_index, 2, "first tick of the window")

	var last: GameCore = _core_next_to_boss()
	_press(last)
	_advance_recovery_to(last, _recovery_ticks(last) - 1)
	_press(last)  # state_ticks reaches the recovery length on this tick: the next swing starts at once
	assert_eq(last.player.combo_index, 2, "last tick of recovery")
	assert_eq(last.player.state, PlayerState.STATE_ATTACK_WINDUP)


func test_late_press_within_grace_continues_and_after_grace_restarts() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	run(core, _swing_ticks(0))
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	run(core, Tuning.COMBO_GRACE_TICKS - 2)
	_press(core)
	assert_eq(core.player.combo_index, 2, "a late press inside the grace window still chains")

	var slow: GameCore = _core_next_to_boss()
	_press(slow)
	run(slow, _swing_ticks(0))
	run(slow, Tuning.COMBO_GRACE_TICKS - 1)
	_press(slow)
	assert_eq(slow.player.combo_index, 1, "after the grace window the combo restarts at swing 1")
	assert_eq(slow.player.state, PlayerState.STATE_ATTACK_WINDUP)


func test_combo_index_resets_when_the_chain_is_dropped() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	_chain_next(core)
	assert_eq(core.player.combo_index, 2)
	run(core, _swing_ticks(1) + Tuning.COMBO_GRACE_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_eq(core.player.combo_index, 1, "stopped chaining: back to swing 1")
	assert_eq(core.snapshot().player.combo_index, 1, "the snapshot says so too")


func test_third_swing_ends_the_combo() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	_chain_next(core)
	_chain_next(core)
	assert_eq(core.player.combo_index, 3)
	_chain_next(core)  # a buffered press after the finisher starts a fresh combo
	assert_eq(core.player.combo_index, 1, "swing 3 wraps to swing 1")
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP)

	var ends: GameCore = _core_next_to_boss()
	_press(ends)
	_chain_next(ends)
	_chain_next(ends)
	run(ends, _swing_ticks(2))
	assert_eq(ends.player.state, PlayerState.STATE_IDLE)
	assert_eq(ends.player.combo_index, 1, "no grace window after the finisher")
	_press(ends)
	assert_eq(ends.player.combo_index, 1, "a late press after the finisher starts at swing 1")


func test_damage_resets_the_combo_and_drops_the_buffered_press() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	_chain_next(core)
	_advance_recovery_to(core, _recovery_ticks(core) - Tuning.COMBO_BUFFER_TICKS - 1)
	_press(core)  # buffered
	assert_true(core.player._combo_queued, "the press is buffered")
	var events: Array[GameEvent] = []
	assert_true(core.player.take_damage(5, core.tick, events, core.boss.id), "the hit landed")
	assert_eq(core.player.combo_index, 1, "damage resets the combo")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "damage interrupts the swing")
	run(core, 30)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "the buffered press died with the swing")
	assert_eq(core.player.combo_index, 1)


func test_dash_resets_the_combo() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	_chain_next(core)
	_advance_recovery_to(core, 2)
	core.step(input(Vector2.LEFT, true))
	assert_eq(core.player.state, PlayerState.STATE_DASH, "dash cancels recovery")
	assert_eq(core.player.combo_index, 1, "dash resets the combo")
	run(core, Tuning.DASH_TICKS)
	_press(core)
	assert_eq(core.player.combo_index, 1, "the next attack after a dash starts at swing 1")


func test_parry_resets_the_combo() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	_chain_next(core)
	_advance_recovery_to(core, 2)
	core.step(input(Vector2.ZERO, false, true))
	assert_eq(core.player.state, PlayerState.STATE_PARRY)
	assert_eq(core.player.combo_index, 1, "parry resets the combo")


func test_successful_parry_resets_the_combo() -> void:
	var core: GameCore = _core_next_to_boss()
	core.player.combo_index = 2
	core.player.on_parry_success(Vector2.RIGHT)
	assert_eq(core.player.combo_index, 1, "a parried hit resets the combo")


func test_death_resets_the_combo() -> void:
	var core: GameCore = _core_next_to_boss()
	_press(core)
	_chain_next(core)
	assert_eq(core.player.combo_index, 2)
	var events: Array[GameEvent] = []
	core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
	assert_eq(core.player.state, PlayerState.STATE_DEAD)
	assert_eq(core.player.combo_index, 1, "dead: combo reset")
	assert_eq(core.snapshot().player.combo_index, 1)


func test_one_hit_per_swing() -> void:
	for swing: int in Tuning.COMBO_MAX:
		var core: GameCore = _core_next_to_boss()
		core.player._start_swing(swing + 1)
		var hits: int = _hit_count(core, _swing_ticks(swing))
		assert_eq(hits, 1, "swing %d connects exactly once although it is active for several ticks" % (swing + 1))
		var expected: int = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.SWING_DAMAGE_MULT[swing] * Tuning.ARMOR_DAMAGE_FACTOR))
		assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, expected, "swing %d damage" % (swing + 1))


func test_each_chained_swing_hits_once_and_reports_its_index() -> void:
	var core: GameCore = _core_next_to_boss()
	var indices: Array[int] = []
	var hp_before: int = core.boss.hp
	_press(core)
	for swing: int in Tuning.COMBO_MAX:
		var guard: int = 0
		while core.player.combo_index == swing + 1 and guard < 100:
			var window_open: bool = core.player.state == PlayerState.STATE_ATTACK_RECOVERY and core.player.state_ticks >= _recovery_ticks(core) - Tuning.COMBO_BUFFER_TICKS - 1
			if window_open and swing < Tuning.COMBO_MAX - 1:
				_press(core)
			else:
				core.step(input())
			for event: GameEvent in core.last_events:
				if event.type == GameEvent.ATTACK_HIT:
					indices.append(int(event.data["combo_index"]))
			guard += 1
	assert_eq(indices.size(), 3, "three swings, three hits")
	if indices.size() == 3:
		assert_eq(indices, [1, 2, 3] as Array[int], "each hit reports its swing")
	assert_true(core.boss.hp < hp_before, "the boss took damage")


func test_snapshot_exposes_combo_index_for_the_player_only() -> void:
	var core: GameCore = _core_next_to_boss()
	assert_eq(core.snapshot().player.combo_index, 1, "idle: 1")
	_press(core)
	_chain_next(core)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.combo_index, 2, "during swing 2")
	assert_eq(snap.entities[0].combo_index, 0, "the boss has no combo")
