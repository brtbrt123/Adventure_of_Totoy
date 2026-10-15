extends "res://tests/test_case.gd"
## After the fight ends the simulation is frozen but result_ticks keeps counting (end animations).


func test_result_ticks_count_after_defeat_while_the_simulation_stays_frozen() -> void:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SLAM, Vector2(64.0, 88.0))
	core.player.hp = 5
	run_to_tick(core, hit_tick)
	assert_eq(core.result, GameCore.RESULT_DEFEAT, "the player died")
	assert_eq(core.snapshot().result_ticks, 0, "no ticks have passed since the result yet")
	var frozen_tick: int = core.tick
	var frozen_boss: Vector2 = core.boss.position
	run(core, 30)
	assert_eq(core.tick, frozen_tick, "the simulation tick is frozen")
	assert_eq(core.boss.position, frozen_boss, "the boss does not move after the result")
	assert_eq(core.snapshot().result_ticks, 30, "result_ticks keeps counting")


func test_result_ticks_are_zero_while_playing() -> void:
	var core: GameCore = GameCore.new()
	run(core, 20)
	assert_eq(core.snapshot().result_ticks, 0)
