extends "res://tests/test_case.gd"
## The Black Katana active (right click): a timed attack speed and damage buff.

const Snapshots := preload("res://core/snapshots.gd")

const D: int = 480  # the placeholder buff duration; the tests read Tuning, this is only a readable alias


func _core(boss_at: Vector2 = Vector2(300.0, 20.0), player_at: Vector2 = Vector2(40.0, 88.0)) -> GameCore:
	var core: GameCore = GameCore.new()
	core.boss.state = BossState.STATE_RECOVER  # a pinned boss: it does not walk or attack
	core.boss._recover_ticks = 1000000
	core.boss.position = boss_at
	core.player.position = player_at
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	return core


var _elapsed: int = 0


## One tick that is counted in `_elapsed` (the ticks since the activation).
func _tick(core: GameCore, frame: InputFrame = null) -> void:
	core.step(frame if frame != null else input())
	_elapsed += 1


func _right_click(core: GameCore, extra: InputFrame = null) -> void:
	var frame: InputFrame = extra if extra != null else InputFrame.new()
	frame.weapon_active_pressed = true
	core.step(frame)


func _activate(core: GameCore) -> void:
	_right_click(core)
	assert_true(core.player.is_buff_active(), "the buff started")


func _count(core: GameCore, type: StringName) -> int:
	return event_types(core).count(type)


## Press attack and step until the swing is over; returns the ticks after the press that it took.
func _swing_length(core: GameCore) -> int:
	core.step(input(Vector2.ZERO, false, false, true))
	var ticks: int = 0
	while core.player.state.begins_with("attack_") and ticks < 200:
		core.step(input())
		ticks += 1
	return ticks


func _scaled_swing_total(mult: float) -> int:
	return PlayerState.scaled_ticks(Tuning.SWING_WINDUP_TICKS[0], mult) + PlayerState.scaled_ticks(Tuning.SWING_ACTIVE_TICKS[0], mult) + PlayerState.scaled_ticks(Tuning.SWING_RECOVERY_TICKS[0], mult)


# --- activation, cost, cooldown ---

func test_right_click_starts_the_buff_spends_edge_and_emits_an_event() -> void:
	var core: GameCore = _core()
	_right_click(core)
	assert_true(core.player.is_buff_active())
	assert_near(core.player.edge, 100.0 - Tuning.BLACK_KATANA_BUFF_EDGE_COST, 0.001, "Edge spent")
	var started: GameEvent = find_event(core, GameEvent.WEAPON_BUFF_STARTED)
	assert_true(started != null, "weapon_buff_started")
	if started != null:
		assert_eq(started.data["weapon_id"], Tuning.WEAPON_BLACK_KATANA)
		assert_eq(started.data["duration"], Tuning.BLACK_KATANA_BUFF_DURATION_TICKS)
		assert_near(float(started.data["attack_speed_mult"]), Tuning.BLACK_KATANA_ATTACK_SPEED_MULT, 0.0001)
		assert_near(float(started.data["damage_mult"]), Tuning.BLACK_KATANA_DAMAGE_MULT, 0.0001)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "a free action: no state change")


func test_activation_needs_edge_and_a_ready_cooldown() -> void:
	var poor: GameCore = _core()
	poor.player.edge = Tuning.BLACK_KATANA_BUFF_EDGE_COST - 1.0
	_right_click(poor)
	assert_false(poor.player.is_buff_active(), "not enough Edge")
	assert_eq(_count(poor, GameEvent.WEAPON_BUFF_STARTED), 0, "no event for a refused press")
	var core: GameCore = _core()
	_activate(core)
	run(core, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS)
	assert_false(core.player.is_buff_active(), "the buff ran out")
	core.player.edge = 100.0
	_right_click(core)
	assert_false(core.player.is_buff_active(), "the cooldown is still running")
	run(core, Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS)
	_right_click(core)
	assert_true(core.player.is_buff_active(), "available again after the cooldown")


func test_the_buff_cannot_be_refreshed_while_it_runs() -> void:
	var core: GameCore = _core()
	_activate(core)
	run(core, 100)
	core.player.buff_cooldown = 0  # even with a ready cooldown, a running buff is not refreshed
	var left: int = core.player.buff_ticks
	var edge: float = core.player.edge
	_right_click(core)
	assert_eq(core.player.buff_ticks, left - 1, "not refreshed: it just kept counting down")
	assert_near(core.player.edge, edge, 0.001, "no second cost")
	assert_eq(_count(core, GameEvent.WEAPON_BUFF_STARTED), 0)


func test_no_active_without_the_black_katana() -> void:
	var core: GameCore = _core()
	core.player.weapon_id = &"none"
	_right_click(core)
	assert_false(core.player.is_buff_active())
	assert_eq(core.snapshot().hud.weapon_buff_duration, 0, "the HUD sees a weapon without an active")


# --- duration and end event ---

func test_the_buff_lasts_exactly_its_duration_then_emits_the_end_event() -> void:
	var core: GameCore = _core()
	_activate(core)
	assert_eq(core.player.buff_ticks, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS)
	var ended_on: int = -1
	var active_ticks: int = 1  # the activation tick
	for i: int in Tuning.BLACK_KATANA_BUFF_DURATION_TICKS + 5:
		core.step(input())
		if _count(core, GameEvent.WEAPON_BUFF_ENDED) > 0:
			ended_on = i + 1
			var e: GameEvent = find_event(core, GameEvent.WEAPON_BUFF_ENDED)
			assert_eq(e.data["reason"], &"expired")
			assert_eq(e.data["weapon_id"], Tuning.WEAPON_BLACK_KATANA)
		elif core.player.is_buff_active():
			active_ticks += 1
	assert_eq(ended_on, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS, "ends on tick activation + duration")
	assert_eq(active_ticks, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS, "active for exactly the duration (counting the activation tick)")


func test_snapshot_exposes_weapon_buff_state_and_remaining_duration() -> void:
	var core: GameCore = _core()
	var before: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(before.player.weapon_id, Tuning.WEAPON_BLACK_KATANA)
	assert_false(before.player.weapon_buff_active)
	assert_eq(before.player.weapon_buff_ticks_left, 0)
	assert_near(before.player.attack_speed_mult, 1.0, 0.0001)
	assert_eq(before.hud.weapon_buff_duration, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS)
	assert_eq(before.hud.weapon_buff_cooldown_max, Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS)
	assert_near(before.hud.weapon_buff_edge_cost, Tuning.BLACK_KATANA_BUFF_EDGE_COST, 0.0001)
	_activate(core)
	run(core, 10)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_true(snap.player.weapon_buff_active)
	assert_eq(snap.player.weapon_buff_ticks_left, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS - 10)
	assert_near(snap.player.attack_speed_mult, Tuning.BLACK_KATANA_ATTACK_SPEED_MULT, 0.0001)
	assert_eq(snap.hud.weapon_buff_cooldown_ticks, Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS - 10)
	assert_eq(snap.entities[0].weapon_id, &"", "the boss has no weapon")


# --- the buff persists ---

func _expect_counting(core: GameCore, label: String) -> void:
	assert_eq(core.player.buff_ticks, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS - _elapsed, "still counting down after " + label)
	assert_true(core.player.is_buff_active(), "active after " + label)


func test_the_buff_lasts_through_movement_attacks_dashes_parries_skills_and_damage() -> void:
	var core: GameCore = _core()
	_activate(core)
	_elapsed = 0
	for i: int in 8:
		_tick(core, input(Vector2.RIGHT))
	_expect_counting(core, "movement")
	_tick(core, input(Vector2.ZERO, false, false, true))
	while core.player.state.begins_with("attack_"):
		_tick(core)
	_expect_counting(core, "an attack")
	_tick(core, input(Vector2.RIGHT, true))
	for i: int in Tuning.DASH_TICKS + 2:
		_tick(core)
	_expect_counting(core, "a dash")
	_tick(core, input(Vector2.ZERO, false, true))
	for i: int in Tuning.PARRY_ACTIVE_TICKS + Tuning.PARRY_WHIFF_RECOVERY_TICKS + 2:
		_tick(core)
	_expect_counting(core, "a parry")
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 2
	frame.move = Vector2.RIGHT
	_tick(core, frame)
	assert_eq(core.player.skill_id, PlayerState.SKILL_GALE_CUT, "the skill started")
	for i: int in Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS + Tuning.GALE_CUT_RECOVERY_TICKS:
		_tick(core)
	_expect_counting(core, "a skill")
	var events: Array[GameEvent] = []
	core.player.take_damage(5, core.tick, events, core.boss.id)
	_tick(core)
	_expect_counting(core, "taking damage")
	assert_eq(_count(core, GameEvent.WEAPON_BUFF_ENDED), 0, "never ended early")


func test_activation_works_during_other_states() -> void:
	for setup: String in ["walk", "attack", "dash", "skill"]:
		var core: GameCore = _core()
		match setup:
			"walk":
				core.step(input(Vector2.RIGHT))
			"attack":
				core.step(input(Vector2.ZERO, false, false, true))
			"dash":
				core.step(input(Vector2.RIGHT, true))
			"skill":
				var frame: InputFrame = InputFrame.new()
				frame.skill_pressed = 2
				frame.move = Vector2.RIGHT
				core.step(frame)
		var state_before: StringName = core.player.state
		_right_click(core, input(Vector2.RIGHT) if setup == "walk" else null)
		assert_true(core.player.is_buff_active(), "activates during " + setup)
		assert_eq(core.player.state, state_before, "and does not interrupt " + setup)


# --- attack speed ---

func test_attack_speed_shortens_every_swing_phase() -> void:
	var plain: GameCore = _core()
	var normal: int = _swing_length(plain)
	assert_eq(normal, _scaled_swing_total(1.0), "unbuffed swing length is the base length")
	var fast: GameCore = _core()
	_activate(fast)
	var buffed: int = _swing_length(fast)
	assert_eq(buffed, _scaled_swing_total(Tuning.BLACK_KATANA_ATTACK_SPEED_MULT), "buffed swing length is the scaled length")
	assert_true(buffed < normal, "faster")
	assert_true(PlayerState.scaled_ticks(Tuning.SWING_ACTIVE_TICKS[0], Tuning.BLACK_KATANA_ATTACK_SPEED_MULT) >= 1, "a phase never drops below one tick")
	assert_eq(PlayerState.scaled_ticks(1, 5.0), 1)


func test_the_speed_is_locked_for_the_swing_in_progress() -> void:
	var late: GameCore = _core()
	late.step(input(Vector2.ZERO, false, false, true))  # the swing starts without the buff
	run(late, 2)
	_right_click(late)  # buff arrives mid-windup
	var ticks: int = 3
	while late.player.state.begins_with("attack_") and ticks < 200:
		late.step(input())
		ticks += 1
	assert_eq(ticks, _scaled_swing_total(1.0), "that swing keeps its normal speed")
	assert_near(late.player.attack_speed_mult(), Tuning.BLACK_KATANA_ATTACK_SPEED_MULT, 0.0001, "but the buff is on for the next one")
	var expiring: GameCore = _core()
	_activate(expiring)
	expiring.step(input(Vector2.ZERO, false, false, true))  # a buffed swing
	assert_near(expiring.snapshot().player.attack_speed_mult, Tuning.BLACK_KATANA_ATTACK_SPEED_MULT, 0.0001)
	expiring.player.buff_ticks = 1  # the buff ends on the next tick, mid-swing
	var length: int = 0
	while expiring.player.state.begins_with("attack_") and length < 200:
		expiring.step(input())
		length += 1
		if expiring.player.state.begins_with("attack_"):
			assert_near(expiring.snapshot().player.attack_speed_mult, Tuning.BLACK_KATANA_ATTACK_SPEED_MULT, 0.0001, "the swing in progress reports its locked speed")
	assert_false(expiring.player.is_buff_active(), "the buff did expire")
	assert_eq(length, _scaled_swing_total(Tuning.BLACK_KATANA_ATTACK_SPEED_MULT), "yet the swing kept its buffed timing")
	assert_near(expiring.snapshot().player.attack_speed_mult, 1.0, 0.0001, "back to normal afterwards")


func test_combo_still_chains_with_the_faster_swings() -> void:
	var core: GameCore = _core()
	_activate(core)
	var seen: Array[int] = []
	for i: int in 200:
		core.step(input(Vector2.ZERO, false, false, true))  # mash attack
		if core.player.state.begins_with("attack_") and not seen.has(core.player.combo_index):
			seen.append(core.player.combo_index)
	assert_true(seen.has(2) and seen.has(3), "swings 2 and 3 are reached by mashing, seen %s" % str(seen))


# --- damage ---

func test_damage_is_higher_for_normal_swings() -> void:
	var plain: GameCore = _core(Vector2(100.0, 88.0), Vector2(70.0, 88.0))
	plain.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])  # a broken boss shows the multiplier without armor rounding
	plain.player.edge = 0.0
	_swing_length(plain)
	var base_damage: int = Tuning.BOSS_MAX_HP - plain.boss.hp
	var buffed: GameCore = _core(Vector2(100.0, 88.0), Vector2(70.0, 88.0))
	buffed.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	_activate(buffed)
	buffed.player.edge = 0.0
	_swing_length(buffed)
	var buffed_damage: int = Tuning.BOSS_MAX_HP - buffed.boss.hp
	assert_eq(base_damage, roundi(Tuning.ATTACK_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "base counter damage")
	assert_eq(buffed_damage, roundi(Tuning.ATTACK_DAMAGE * Tuning.BLACK_KATANA_DAMAGE_MULT * Tuning.COUNTER_DAMAGE_MULT), "buffed counter damage")
	assert_true(buffed_damage > base_damage, "more damage")


func test_damage_is_higher_for_skills_and_locked_at_release() -> void:
	var gale: GameCore = _core(Vector2(120.0, 88.0))
	gale.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	_activate(gale)
	gale.player.edge = 100.0
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 2
	frame.move = Vector2.RIGHT
	gale.step(frame)
	run(gale, Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS)
	assert_eq(Tuning.BOSS_MAX_HP - gale.boss.hp, roundi(Tuning.GALE_CUT_DAMAGE * Tuning.BLACK_KATANA_DAMAGE_MULT * Tuning.COUNTER_DAMAGE_MULT), "Gale Cut with the buff")

	var moon: GameCore = _core(Vector2(130.0, 88.0))
	moon.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	_activate(moon)
	moon.player.edge = 100.0
	var press: InputFrame = InputFrame.new()
	press.skill_pressed = 3
	press.move = Vector2.RIGHT
	moon.step(press)
	run(moon, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	assert_eq(moon.skill_attacks.size(), 1, "the projectile is out")
	moon.player.buff_ticks = 1  # the buff ends before the projectile lands
	run(moon, 2)
	assert_false(moon.player.is_buff_active())
	run(moon, 40)
	assert_eq(Tuning.BOSS_MAX_HP - moon.boss.hp, roundi(Tuning.MOON_CLEAVE_DAMAGE * Tuning.BLACK_KATANA_DAMAGE_MULT * Tuning.COUNTER_DAMAGE_MULT), "the projectile keeps the damage it was released with")


func test_no_damage_bonus_after_the_buff_ends() -> void:
	var core: GameCore = _core(Vector2(100.0, 88.0), Vector2(70.0, 88.0))
	_activate(core)
	run(core, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS)
	assert_false(core.player.is_buff_active())
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, core.tick, [])  # break the boss now, so the counter shows the multiplier
	core.player.edge = 0.0
	_swing_length(core)
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, roundi(Tuning.ATTACK_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "normal damage again")


# --- death ---

func test_death_ends_the_buff_with_an_event() -> void:
	var core: GameCore = _core()
	_activate(core)
	var events: Array[GameEvent] = []
	core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
	var ended: Array[GameEvent] = events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.WEAPON_BUFF_ENDED)
	assert_eq(ended.size(), 1, "weapon_buff_ended on death")
	if ended.size() == 1:
		assert_eq(ended[0].data["reason"], &"death")
	assert_false(core.player.is_buff_active())
	assert_false(core.snapshot().player.weapon_buff_active)
	core.player.edge = 100.0
	core.player.buff_cooldown = 0
	_right_click(core)
	assert_false(core.player.is_buff_active(), "a dead player cannot buff")
