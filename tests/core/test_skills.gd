extends "res://tests/test_case.gd"
## The three sword skills (skill_pressed 1, 2, 3): Breaking Edge, Gale Cut, Moon Cleave.

const Snapshots := preload("res://core/snapshots.gd")


func _core(distance: float = 30.0) -> GameCore:
	var core: GameCore = GameCore.new()
	core.boss.cooldown = 100000  # keep the boss passive
	core.player.position = core.boss.position + Vector2(-distance, 0.0)
	core.player.facing = Vector2.RIGHT
	return core


func _skill(core: GameCore, slot: int, aim: Vector2 = Vector2.ZERO) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = slot
	frame.aim = aim
	core.step(frame)


## A successful parry just happened: Edge and the retaliation window are set the way the core sets them.
func _after_parry(core: GameCore, edge: float = 0.0) -> void:
	core.player.edge = edge
	core.player.on_parry_success(Vector2.ZERO)


func _hits(core: GameCore, ticks: int) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for i: int in ticks:
		core.step(input())
		for event: GameEvent in core.last_events:
			if event.type == GameEvent.ATTACK_HIT:
				found.append(event)
	return found


func _total_ticks(windup: int, active: int, recovery: int) -> int:
	return windup + active + recovery


# --- Breaking Edge (1) ---

func test_breaking_edge_needs_a_successful_parry() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_skill(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "no retaliation without a parry")
	assert_near(core.player.edge, 100.0, 0.001, "Edge untouched")


func test_breaking_edge_spends_edge_and_starts_after_a_parry() -> void:
	var core: GameCore = _core(60.0)
	_after_parry(core)
	assert_near(core.player.edge, Tuning.EDGE_PER_PARRY, 0.001, "the parry built Edge")
	assert_true(core.snapshot().hud.retaliate_ticks_left > 0, "the HUD can show the window")
	_skill(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP)
	assert_eq(core.player.skill_id, PlayerState.SKILL_BREAKING_EDGE)
	assert_near(core.player.edge, Tuning.EDGE_PER_PARRY - Tuning.BREAKING_EDGE_EDGE_COST, 0.001, "Edge spent")
	assert_true(event_types(core).has(GameEvent.SKILL_STARTED), "skill_started event")
	assert_eq(core.player.retaliate_ticks, 0, "the window is used up")


func test_breaking_edge_window_expires() -> void:
	var core: GameCore = _core()
	_after_parry(core, 50.0)
	run(core, Tuning.BREAKING_EDGE_WINDOW_TICKS)
	_skill(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "too late")


func test_breaking_edge_needs_enough_edge() -> void:
	var core: GameCore = _core()
	_after_parry(core)
	core.player.edge = Tuning.BREAKING_EDGE_EDGE_COST - 1.0
	_skill(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "not enough Edge")


func test_breaking_edge_steps_forward_and_hits_for_high_posture() -> void:
	var core: GameCore = _core(60.0)
	var start_x: float = core.player.position.x
	_after_parry(core, 50.0)
	_skill(core, 1)
	run(core, Tuning.BREAKING_EDGE_WINDUP_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_ACTIVE)
	assert_near(core.player.position.x - start_x, Tuning.BREAKING_EDGE_STEP, 0.01, "stepped forward during the windup")
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, maxi(1, roundi(Tuning.BREAKING_EDGE_DAMAGE * Tuning.ARMOR_DAMAGE_FACTOR)), "armored health damage")
	assert_near(core.boss.posture, Tuning.BREAKING_EDGE_POSTURE, 1.0, "high posture damage")
	assert_true(Tuning.BREAKING_EDGE_POSTURE > Tuning.GALE_CUT_POSTURE * 4.0, "much more posture than a quick cut")


func test_two_retaliations_break_the_boss() -> void:
	var core: GameCore = _core(60.0)
	for i: int in 2:
		_after_parry(core, 50.0)
		core.player.position = core.boss.position + Vector2(-60.0, 0.0)
		_skill(core, 1)
		run(core, _total_ticks(Tuning.BREAKING_EDGE_WINDUP_TICKS, Tuning.BREAKING_EDGE_ACTIVE_TICKS, Tuning.BREAKING_EDGE_RECOVERY_TICKS))
	assert_eq(core.boss.state, BossState.STATE_BROKEN, "two retaliations open a posture break")


func test_breaking_edge_on_a_broken_boss_is_a_counter() -> void:
	var core: GameCore = _core(60.0)
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	assert_eq(core.boss.state, BossState.STATE_BROKEN)
	var posture_before: float = core.boss.posture
	_after_parry(core, 50.0)
	_skill(core, 1)
	run(core, Tuning.BREAKING_EDGE_WINDUP_TICKS)
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, roundi(Tuning.BREAKING_EDGE_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "counter damage")
	assert_near(core.boss.posture, posture_before, 0.001, "no extra posture during a break")


# --- Gale Cut (2) ---

func test_gale_cut_dashes_toward_the_aim_without_invulnerability() -> void:
	var core: GameCore = _core(120.0)
	var start: Vector2 = core.player.position
	_skill(core, 2, Vector2.UP)
	assert_eq(core.player.skill_id, PlayerState.SKILL_GALE_CUT)
	for i: int in Tuning.GALE_CUT_WINDUP_TICKS:
		assert_false(core.player.is_invulnerable(), "no i-frames during the dash")
		core.step(input())
	assert_true(core.player.position.y < start.y - 20.0, "moved up along the aim")
	assert_near(absf(core.player.position.x - start.x), 0.0, 0.5, "not sideways")
	assert_near(start.distance_to(core.player.position), Tuning.GALE_CUT_SPEED * Tuning.GALE_CUT_WINDUP_TICKS, 1.5, "dash distance")


func test_gale_cut_closes_the_gap_and_cuts() -> void:
	var core: GameCore = _core(70.0)  # too far for a normal swing
	_skill(core, 2, Vector2.RIGHT)
	run(core, Tuning.GALE_CUT_WINDUP_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_ACTIVE)
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, maxi(1, roundi(Tuning.GALE_CUT_DAMAGE * Tuning.ARMOR_DAMAGE_FACTOR)), "the cut landed")
	assert_near(core.player.edge, Tuning.GALE_CUT_EDGE_GAIN, 0.001, "a connecting cut builds Edge like a normal hit")
	assert_true(70.0 - Tuning.BOSS_RADIUS > Tuning.ATTACK_RANGE, "a normal swing from there would have missed")


func test_gale_cut_cooldown() -> void:
	var core: GameCore = _core(120.0)
	_skill(core, 2, Vector2.RIGHT)
	run(core, _total_ticks(Tuning.GALE_CUT_WINDUP_TICKS, Tuning.GALE_CUT_ACTIVE_TICKS, Tuning.GALE_CUT_RECOVERY_TICKS))
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_true(core.player.skill_cooldowns[1] > 0, "still cooling down")
	_skill(core, 2, Vector2.RIGHT)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "blocked by the cooldown")
	assert_true(core.snapshot().hud.skill_cooldown_ticks[1] > 0, "the HUD sees the cooldown")
	run(core, Tuning.GALE_CUT_COOLDOWN_TICKS)
	_skill(core, 2, Vector2.RIGHT)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP, "available again")


func test_gale_cut_can_be_interrupted_by_damage() -> void:
	var core: GameCore = _core(120.0)
	_skill(core, 2, Vector2.RIGHT)
	var events: Array[GameEvent] = []
	assert_true(core.player.take_damage(5, core.tick, events, core.boss.id), "no invulnerability: the hit lands")
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_eq(core.player.skill_id, &"", "skill_id cleared")


# --- Moon Cleave (3) ---

func test_moon_cleave_needs_edge_and_spends_it() -> void:
	var core: GameCore = _core()
	core.player.edge = Tuning.MOON_CLEAVE_EDGE_COST - 1.0
	_skill(core, 3)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "not enough Edge")
	core.player.edge = Tuning.MOON_CLEAVE_EDGE_COST
	_skill(core, 3)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP)
	assert_near(core.player.edge, 0.0, 0.001, "all the cost is spent")


func test_moon_cleave_holds_then_hits_wide() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_skill(core, 3)
	var hits: int = 0
	for i: int in Tuning.MOON_CLEAVE_WINDUP_TICKS - 1:
		core.step(input())
		hits += core.last_events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.ATTACK_HIT).size()
	assert_eq(hits, 0, "nothing lands during the hold")
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP)
	core.step(input())
	assert_eq(core.player.state, PlayerState.STATE_SKILL_ACTIVE)
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, maxi(1, roundi(Tuning.MOON_CLEAVE_DAMAGE * Tuning.ARMOR_DAMAGE_FACTOR)), "hit when the hold ends")


func test_moon_cleave_reaches_further_around_than_a_normal_swing() -> void:
	var side: Vector2 = Vector2.from_angle(deg_to_rad(100.0))  # about 100 degrees off the facing
	assert_true(Vector2.RIGHT.dot(side) < Tuning.ATTACK_ARC_DOT, "outside the normal swing arc")
	assert_true(Vector2.RIGHT.dot(side) > Tuning.MOON_CLEAVE_ARC_DOT, "inside the Moon Cleave arc")
	var core: GameCore = _core()
	core.player.edge = 100.0
	core.boss.position = core.player.position + side * 32.0
	_skill(core, 3)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	assert_true(core.boss.hp < Tuning.BOSS_MAX_HP, "the wide cleave caught the boss at its side")

	var behind: GameCore = _core()
	behind.player.edge = 100.0
	behind.boss.position = behind.player.position + Vector2.from_angle(deg_to_rad(150.0)) * 32.0
	_skill(behind, 3)
	run(behind, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	assert_eq(behind.boss.hp, Tuning.BOSS_MAX_HP, "but not behind the player")


func test_moon_cleave_is_the_biggest_hit_and_the_longest_commitment() -> void:
	assert_true(Tuning.MOON_CLEAVE_DAMAGE > Tuning.BREAKING_EDGE_DAMAGE and Tuning.BREAKING_EDGE_DAMAGE > Tuning.GALE_CUT_DAMAGE, "health damage order")
	assert_true(Tuning.MOON_CLEAVE_EDGE_COST > Tuning.BREAKING_EDGE_EDGE_COST, "highest Edge cost")
	assert_true(Tuning.MOON_CLEAVE_RECOVERY_TICKS > Tuning.BREAKING_EDGE_RECOVERY_TICKS and Tuning.MOON_CLEAVE_RECOVERY_TICKS > Tuning.GALE_CUT_RECOVERY_TICKS, "longest recovery")
	var core: GameCore = _core()
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	core.player.edge = 100.0
	_skill(core, 3)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, roundi(Tuning.MOON_CLEAVE_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "best during a posture break")


func test_moon_cleave_recovery_cannot_be_cancelled() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_skill(core, 3)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS + Tuning.MOON_CLEAVE_ACTIVE_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_RECOVERY)
	core.step(input(Vector2.ZERO, true, false, false))  # dash
	core.step(input(Vector2.ZERO, false, true, false))  # parry
	core.step(input(Vector2.ZERO, false, false, true))  # attack
	assert_eq(core.player.state, PlayerState.STATE_SKILL_RECOVERY, "committed")
	run(core, Tuning.MOON_CLEAVE_RECOVERY_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)


func test_moon_cleave_interrupted_by_damage_loses_the_edge() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_skill(core, 3)
	run(core, 5)
	var events: Array[GameEvent] = []
	core.player.take_damage(10, core.tick, events, core.boss.id)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_near(core.player.edge, 100.0 - Tuning.MOON_CLEAVE_EDGE_COST, 0.001, "the Edge is not refunded")
	run(core, 40)
	assert_eq(core.boss.hp, Tuning.BOSS_MAX_HP, "the interrupted cleave never landed")


# --- shared rules ---

func test_each_skill_hits_once_and_reports_its_id() -> void:
	var cases: Array = [
		[1, PlayerState.SKILL_BREAKING_EDGE, Tuning.BREAKING_EDGE_WINDUP_TICKS + Tuning.BREAKING_EDGE_ACTIVE_TICKS + Tuning.BREAKING_EDGE_RECOVERY_TICKS],
		[2, PlayerState.SKILL_GALE_CUT, Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS + Tuning.GALE_CUT_RECOVERY_TICKS],
		[3, PlayerState.SKILL_MOON_CLEAVE, Tuning.MOON_CLEAVE_WINDUP_TICKS + Tuning.MOON_CLEAVE_ACTIVE_TICKS + Tuning.MOON_CLEAVE_RECOVERY_TICKS],
	]
	for case: Array in cases:
		var core: GameCore = _core(60.0 if case[0] != 3 else 30.0)
		core.player.edge = 100.0
		if case[0] == 1:
			_after_parry(core, 100.0)
		core.player.skill_cooldowns = [0, 0, 0]
		_skill(core, case[0], Vector2.RIGHT)
		var hits: Array[GameEvent] = _hits(core, case[2])
		assert_eq(hits.size(), 1, "skill %d connects once" % case[0])
		if hits.size() == 1:
			assert_eq(hits[0].data["skill_id"], case[1], "the hit names the skill")


func test_unknown_slots_do_nothing() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	for slot: int in [0, 4, -1]:
		_skill(core, slot)
		assert_eq(core.player.state, PlayerState.STATE_IDLE, "slot %d" % slot)


func test_skills_cancel_the_recovery_of_a_normal_swing_and_reset_the_combo() -> void:
	var core: GameCore = _core(120.0)
	core.step(input(Vector2.ZERO, false, false, true))
	var guard: int = 0
	while core.player.state != PlayerState.STATE_ATTACK_RECOVERY and guard < 50:
		core.step(input())
		guard += 1
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_RECOVERY)
	_skill(core, 2, Vector2.RIGHT)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP, "a skill cancels the swing's recovery")
	assert_eq(core.player.combo_index, 1, "and resets the combo")


func test_skill_cannot_start_during_a_parry_or_when_dead() -> void:
	var core: GameCore = _core(120.0)
	core.player.edge = 100.0
	core.step(input(Vector2.ZERO, false, true))
	assert_eq(core.player.state, PlayerState.STATE_PARRY)
	_skill(core, 3)
	assert_eq(core.player.state, PlayerState.STATE_PARRY, "the parry window is not cancelled by a skill")
	var dead: GameCore = _core()
	dead.player.edge = 100.0
	var events: Array[GameEvent] = []
	dead.player.take_damage(Tuning.PLAYER_MAX_HP, dead.tick, events, dead.boss.id)
	_skill(dead, 3)
	assert_eq(dead.player.state, PlayerState.STATE_DEAD)


func test_snapshot_exposes_the_skill_in_progress() -> void:
	var core: GameCore = _core(120.0)
	assert_eq(core.snapshot().player.skill_id, &"", "no skill while idle")
	_skill(core, 2, Vector2.RIGHT)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.state, PlayerState.STATE_SKILL_WINDUP)
	assert_eq(snap.player.skill_id, PlayerState.SKILL_GALE_CUT)
	assert_eq(snap.entities[0].skill_id, &"", "the boss has none")
