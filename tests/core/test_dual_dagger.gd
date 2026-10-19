extends "res://tests/test_case.gd"
## The Dual Dagger: weapon swap (Q), the fast 4-hit combo, the lightning strike finisher and Lightning Form (right
## click) with its blink.

const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const Obstacle := preload("res://core/obstacle.gd")

const BOSS_AT: Vector2 = Vector2(400.0, 240.0)


## A pinned boss (it neither walks nor attacks) in an open field, the player `offset` from it, facing it, full Edge.
func _core(offset: Vector2 = Vector2(-30.0, 0.0), boss_at: Vector2 = BOSS_AT, clear_props: bool = true) -> GameCore:
	var core: GameCore = GameCore.new()
	if clear_props:
		core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = boss_at
	core.player.position = boss_at + offset
	core.player.facing = -offset.normalized()
	core.player.edge = 100.0
	return core


func _dagger_core(offset: Vector2 = Vector2(-30.0, 0.0), boss_at: Vector2 = BOSS_AT, clear_props: bool = true) -> GameCore:
	var core: GameCore = _core(offset, boss_at, clear_props)
	core.player.weapon_id = Tuning.WEAPON_DUAL_DAGGER
	return core


func _frame(swap: bool = false, active: bool = false, attack: bool = false, move: Vector2 = Vector2.ZERO) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_swap_pressed = swap
	frame.weapon_active_pressed = active
	frame.attack_pressed = attack
	frame.move = move
	return frame


func _swap(core: GameCore) -> void:
	core.step(_frame(true))


func _count(core: GameCore, type: StringName) -> int:
	return event_types(core).count(type)


## Step with idle input for `ticks` ticks and return every event of `type` seen.
func _collect(core: GameCore, ticks: int, type: StringName, frame: InputFrame = null) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for i: int in ticks:
		core.step(frame if frame != null else InputFrame.new())
		for event: GameEvent in core.last_events:
			if event.type == type:
				found.append(event)
	return found


func _swing_total(weapon: StringName, swing: int, mult: float = 1.0) -> int:
	var phases: Array[int] = Weapons.swing_phases(weapon, swing)
	return PlayerState.scaled_ticks(phases[0], mult) + PlayerState.scaled_ticks(phases[1], mult) + PlayerState.scaled_ticks(phases[2], mult)


# --- swap ---

func test_the_player_starts_with_the_katana_and_swap_toggles_weapons() -> void:
	var core: GameCore = _core()
	assert_eq(core.snapshot().player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "starts with the katana")
	assert_eq(core.snapshot().player.combo_max, Tuning.COMBO_MAX)
	_swap(core)
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	var swapped: GameEvent = find_event(core, GameEvent.WEAPON_SWAPPED)
	assert_true(swapped != null, "weapon_swapped emitted")
	if swapped != null:
		assert_eq(swapped.data["weapon_id"], Tuning.WEAPON_DUAL_DAGGER)
		assert_eq(swapped.data["previous_weapon_id"], Tuning.WEAPON_BLACK_KATANA)
		assert_eq(swapped.data["entity_id"], core.player.id)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	assert_eq(snap.player.combo_max, Tuning.DAGGER_COMBO_MAX)
	assert_eq(snap.player.state, PlayerState.STATE_IDLE, "a free action")
	run(core, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	_swap(core)
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "and back")


func test_swap_lockout_blocks_a_second_swap_for_the_lockout_ticks() -> void:
	var core: GameCore = _core()
	_swap(core)
	assert_eq(core.snapshot().hud.weapon_swap_lockout_ticks, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	assert_eq(core.snapshot().hud.weapon_swap_lockout_max, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	for i: int in Tuning.WEAPON_SWAP_LOCKOUT_TICKS - 1:
		_swap(core)
		assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER, "locked out %d ticks after the swap" % (i + 1))
		assert_eq(_count(core, GameEvent.WEAPON_SWAPPED), 0, "no event for a refused swap")
	_swap(core)
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "allowed exactly WEAPON_SWAP_LOCKOUT_TICKS later")


func test_swap_works_while_walking_but_not_mid_swing_skill_dash_parry_or_death() -> void:
	var walking: GameCore = _core(Vector2(-100.0, 0.0))
	walking.step(input(Vector2.UP))
	walking.step(_frame(true, false, false, Vector2.UP))
	assert_eq(walking.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER, "walking: allowed")
	for setup: String in ["attack", "recovery", "dash", "parry", "skill", "dead"]:
		var core: GameCore = _core(Vector2(-100.0, 0.0))
		match setup:
			"attack":
				core.step(input(Vector2.ZERO, false, false, true))
			"recovery":
				core.step(input(Vector2.ZERO, false, false, true))
				run(core, Tuning.SWING_WINDUP_TICKS[0] + Tuning.SWING_ACTIVE_TICKS[0])
				assert_eq(core.player.state, PlayerState.STATE_ATTACK_RECOVERY)
			"dash":
				core.step(input(Vector2.UP, true))
			"parry":
				core.step(input(Vector2.ZERO, false, true))
			"skill":
				var frame: InputFrame = InputFrame.new()
				frame.skill_pressed = 2
				frame.move = Vector2.UP
				core.step(frame)
			"dead":
				var events: Array[GameEvent] = []
				core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
		var state_before: StringName = core.player.state
		_swap(core)
		assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "no swap during " + setup)
		assert_eq(_count(core, GameEvent.WEAPON_SWAPPED), 0, "no event during " + setup)
		if setup != "dead":
			assert_true(String(core.player.state).begins_with(String(state_before).get_slice("_", 0)), "and the action goes on: " + setup)


func test_swap_is_refused_while_a_buff_or_form_runs() -> void:
	var katana: GameCore = _core()
	katana.step(_frame(false, true))
	assert_true(katana.player.is_buff_active())
	_swap(katana)
	assert_eq(katana.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "not while the katana buff runs")
	var dagger: GameCore = _dagger_core()
	dagger.step(_frame(false, true))
	assert_true(dagger.player.is_lightning_form())
	_swap(dagger)
	assert_eq(dagger.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER, "not while Lightning Form runs")
	run(dagger, Tuning.LIGHTNING_FORM_DURATION_TICKS)
	assert_false(dagger.player.is_buff_active())
	_swap(dagger)
	assert_eq(dagger.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "allowed once the form is over")


func test_swap_resets_the_combo() -> void:
	var core: GameCore = _core()
	core.step(input(Vector2.ZERO, false, false, true))
	run(core, _swing_total(Tuning.WEAPON_BLACK_KATANA, 1))
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_eq(core.player.combo_index, 1)
	assert_true(core.player._combo_grace > 0, "inside the chain grace window")
	_swap(core)
	core.step(input(Vector2.ZERO, false, false, true))
	assert_eq(core.player.combo_index, 1, "after a swap the next press starts at swing 1")


func test_each_weapon_keeps_its_own_active_cooldown() -> void:
	var core: GameCore = _core()
	core.step(_frame(false, true))  # katana buff: its cooldown starts
	var since: int = 1
	run(core, Tuning.BLACK_KATANA_BUFF_DURATION_TICKS)
	since += Tuning.BLACK_KATANA_BUFF_DURATION_TICKS
	assert_false(core.player.is_buff_active())
	_swap(core)
	since += 1
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.hud.weapon_buff_cooldown_ticks, 0, "the dagger's cooldown is its own: ready")
	assert_eq(snap.hud.weapon_buff_cooldown_max, Tuning.LIGHTNING_FORM_COOLDOWN_TICKS)
	assert_eq(snap.hud.weapon_buff_duration, Tuning.LIGHTNING_FORM_DURATION_TICKS)
	assert_near(snap.hud.weapon_buff_edge_cost, Tuning.LIGHTNING_FORM_EDGE_COST, 0.0001)
	assert_eq(snap.hud.weapon_cooldowns[Tuning.WEAPON_BLACK_KATANA], Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS - since + 1, "the katana's keeps counting while it is put away")
	core.player.edge = 100.0
	core.step(_frame(false, true))  # Lightning Form
	since += 1
	assert_true(core.player.is_lightning_form())
	assert_eq(core.player.buff_cooldown, Tuning.LIGHTNING_FORM_COOLDOWN_TICKS)
	run(core, Tuning.LIGHTNING_FORM_DURATION_TICKS)
	since += Tuning.LIGHTNING_FORM_DURATION_TICKS
	_swap(core)
	since += 1
	snap = core.snapshot()
	assert_eq(snap.player.weapon_id, Tuning.WEAPON_BLACK_KATANA)
	assert_eq(snap.hud.weapon_buff_cooldown_ticks, Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS - since + 1, "swapping back did not reset the katana cooldown")
	assert_eq(snap.hud.weapon_buff_cooldown_max, Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS)
	assert_eq(snap.hud.weapon_cooldowns[Tuning.WEAPON_DUAL_DAGGER], Tuning.LIGHTNING_FORM_COOLDOWN_TICKS - Tuning.LIGHTNING_FORM_DURATION_TICKS - 1)
	core.player.edge = 100.0
	core.step(_frame(false, true))
	assert_false(core.player.is_buff_active(), "the katana is still on cooldown")
	# Swapping repeatedly never readies an active early.
	var dagger_cd: int = core.player.active_cooldowns[Tuning.WEAPON_DUAL_DAGGER]
	run(core, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	_swap(core)
	assert_eq(core.player.buff_cooldown, dagger_cd - Tuning.WEAPON_SWAP_LOCKOUT_TICKS - 1)


func test_skills_work_with_the_dagger() -> void:
	var core: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 2
	frame.move = Vector2.RIGHT
	core.step(frame)
	assert_eq(core.player.skill_id, PlayerState.SKILL_GALE_CUT, "Gale Cut starts with the dagger equipped")
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)


# --- the dagger combo ---

func test_dagger_swing_timings_follow_tuning() -> void:
	for swing: int in Tuning.DAGGER_COMBO_MAX:
		var core: GameCore = _dagger_core()
		core.player._start_swing(swing + 1)
		var label: String = "dagger swing %d" % (swing + 1)
		run(core, Tuning.DAGGER_SWING_WINDUP_TICKS[swing] - 1)
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP, "still winding up, " + label)
		core.step(input())
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_ACTIVE, "active after the windup, " + label)
		run(core, Tuning.DAGGER_SWING_ACTIVE_TICKS[swing])
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_RECOVERY, "recovery after the active ticks, " + label)
		run(core, Tuning.DAGGER_SWING_RECOVERY_TICKS[swing])
		assert_eq(core.player.state, PlayerState.STATE_IDLE, "idle after the recovery, " + label)


func test_dagger_combo_chains_four_swings_then_starts_over() -> void:
	var core: GameCore = _dagger_core()
	var order: Array[int] = []
	for i: int in 120:
		core.step(input(Vector2.ZERO, false, false, true))  # mash
		if core.player.state == PlayerState.STATE_ATTACK_WINDUP and core.player.state_ticks == 0:
			order.append(core.player.combo_index)
	assert_true(order.size() >= 6, "several swings started, got %s" % str(order))
	if order.size() >= 6:
		assert_eq(order.slice(0, 6), [1, 2, 3, 4, 1, 2] as Array[int], "1-2-3-4 then a fresh combo")
	assert_eq(order.max(), Tuning.DAGGER_COMBO_MAX, "never past swing 4")
	var ends: GameCore = _dagger_core()
	ends.player._start_swing(4)
	run(ends, _swing_total(Tuning.WEAPON_DUAL_DAGGER, 4))
	assert_eq(ends.player.state, PlayerState.STATE_IDLE)
	assert_eq(ends.player.combo_index, 1, "no grace window after the 4th swing")
	var mid: GameCore = _dagger_core()
	mid.player._start_swing(3)
	run(mid, _swing_total(Tuning.WEAPON_DUAL_DAGGER, 3))
	mid.step(input(Vector2.ZERO, false, false, true))
	assert_eq(mid.player.combo_index, 4, "swing 3 still chains to 4 within the grace window")


func test_dagger_is_faster_and_shorter_than_the_katana() -> void:
	for swing: int in Tuning.DAGGER_COMBO_MAX:
		var katana_swing: int = mini(swing, Tuning.COMBO_MAX - 1) + 1
		assert_true(_swing_total(Tuning.WEAPON_DUAL_DAGGER, swing + 1) < _swing_total(Tuning.WEAPON_BLACK_KATANA, katana_swing), "dagger swing %d is faster" % (swing + 1))
		assert_true(Tuning.DAGGER_SWING_WINDUP_TICKS[swing] < Tuning.SWING_WINDUP_TICKS[katana_swing - 1], "and hits sooner")
		assert_true(Tuning.DAGGER_SWING_RANGE_MULT[swing] < Tuning.SWING_RANGE_MULT[0], "and reaches less")
	# The boss edge 22 px away: the katana (reach 26) hits, the dagger (19.5) whiffs.
	var katana: GameCore = _core(Vector2(-42.0, 0.0))
	katana.player._start_swing(1)
	assert_eq(_collect(katana, _swing_total(Tuning.WEAPON_BLACK_KATANA, 1), GameEvent.ATTACK_HIT).size(), 1, "katana reaches")
	var dagger: GameCore = _dagger_core(Vector2(-42.0, 0.0))
	dagger.player._start_swing(1)
	assert_eq(_collect(dagger, _swing_total(Tuning.WEAPON_DUAL_DAGGER, 1), GameEvent.ATTACK_HIT).size(), 0, "dagger does not")


func _hit_damage(core: GameCore, swing: int, weapon: StringName) -> int:
	core.player._start_swing(swing)
	var hits: Array[GameEvent] = _collect(core, _swing_total(weapon, swing), GameEvent.ATTACK_HIT)
	assert_eq(hits.size(), 1, "%s swing %d hits once" % [weapon, swing])
	return int(hits[0].data["damage"]) if hits.size() == 1 else -1


func test_dagger_hits_less_than_the_katana() -> void:
	var katana_hit: int = _hit_damage(_core(), 1, Tuning.WEAPON_BLACK_KATANA)
	for swing: int in range(1, Tuning.DAGGER_COMBO_MAX + 1):
		var armored: int = _hit_damage(_dagger_core(), swing, Tuning.WEAPON_DUAL_DAGGER)
		assert_eq(armored, maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.DAGGER_SWING_DAMAGE_MULT[swing - 1] * Tuning.ARMOR_DAMAGE_FACTOR)), "armored dagger swing %d" % swing)
		assert_true(armored < katana_hit, "dagger swing %d (%d) < katana swing 1 (%d)" % [swing, armored, katana_hit])
		var broken: GameCore = _dagger_core()
		broken.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
		broken.player.edge = 0.0
		var counter: int = _hit_damage(broken, swing, Tuning.WEAPON_DUAL_DAGGER)
		assert_eq(counter, roundi(Tuning.ATTACK_DAMAGE * Tuning.DAGGER_SWING_DAMAGE_MULT[swing - 1] * Tuning.COUNTER_DAMAGE_MULT), "counter dagger swing %d" % swing)
		assert_true(counter < roundi(Tuning.ATTACK_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "less than a katana counter")


func test_dagger_hits_build_edge() -> void:
	var core: GameCore = _dagger_core()
	core.player.edge = 0.0
	_hit_damage(core, 1, Tuning.WEAPON_DUAL_DAGGER)
	assert_near(core.player.edge, Tuning.DAGGER_EDGE_PER_HIT, 0.0001)


# --- lightning strike ---

func test_only_a_connecting_fourth_swing_calls_the_lightning_strike() -> void:
	for swing: int in range(1, Tuning.DAGGER_COMBO_MAX + 1):
		var core: GameCore = _dagger_core()
		core.player._start_swing(swing)
		var strikes: Array[GameEvent] = []
		var hit_tick: int = -1
		for i: int in _swing_total(Tuning.WEAPON_DUAL_DAGGER, swing) + 10:
			core.step(input())
			var types: Array[StringName] = event_types(core)
			if types.has(GameEvent.ATTACK_HIT):
				hit_tick = core.tick
			if types.has(GameEvent.LIGHTNING_STRIKE):
				assert_true(types.find(GameEvent.ATTACK_HIT) < types.find(GameEvent.LIGHTNING_STRIKE), "the slash lands first")
				strikes.append(find_event(core, GameEvent.LIGHTNING_STRIKE))
		if swing < Tuning.DAGGER_COMBO_MAX:
			assert_eq(strikes.size(), 0, "no strike on swing %d" % swing)
			continue
		assert_eq(strikes.size(), 1, "exactly one strike on swing 4")
		if strikes.size() == 1:
			var strike: GameEvent = strikes[0]
			assert_eq(strike.tick, hit_tick, "on the tick the swing connects")
			assert_eq(strike.data["target_id"], core.boss.id)
			assert_eq(strike.data["combo_index"], 4)
			assert_eq(strike.data["position"], core.boss.position)
			var expected: int = maxi(1, roundi(Tuning.LIGHTNING_STRIKE_DAMAGE * Tuning.ARMOR_DAMAGE_FACTOR))
			assert_eq(strike.data["damage"], expected, "armored strike damage")
			var swing_damage: int = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.DAGGER_SWING_DAMAGE_MULT[3] * Tuning.ARMOR_DAMAGE_FACTOR))
			assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, swing_damage + expected, "the boss took the slash and the bolt")
			assert_near(core.boss.posture, Tuning.NORMAL_HIT_POSTURE + Tuning.LIGHTNING_STRIKE_POSTURE, 1.0, "and posture from both (less a little decay)")


func test_no_lightning_strike_when_the_fourth_swing_whiffs() -> void:
	var far: GameCore = _dagger_core(Vector2(-60.0, 0.0))
	far.player._start_swing(4)
	assert_eq(_collect(far, 40, GameEvent.LIGHTNING_STRIKE).size(), 0, "out of reach: no strike")
	assert_eq(far.boss.hp, Tuning.BOSS_MAX_HP)
	var away: GameCore = _dagger_core()
	away.player.facing = Vector2.LEFT  # the boss is behind
	away.player._start_swing(4)
	assert_eq(_collect(away, 40, GameEvent.LIGHTNING_STRIKE).size(), 0, "facing away: no strike")
	var katana: GameCore = _core()
	katana.player._start_swing(Tuning.COMBO_MAX)
	assert_eq(_collect(katana, 60, GameEvent.LIGHTNING_STRIKE).size(), 0, "the katana finisher calls no lightning")


func test_lightning_strike_on_a_counter_uses_the_counter_multiplier() -> void:
	var core: GameCore = _dagger_core()
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	core.player.edge = 0.0
	core.player._start_swing(4)
	var strikes: Array[GameEvent] = _collect(core, 40, GameEvent.LIGHTNING_STRIKE)
	assert_eq(strikes.size(), 1)
	if strikes.size() == 1:
		assert_eq(strikes[0].data["damage"], roundi(Tuning.LIGHTNING_STRIKE_DAMAGE * Tuning.COUNTER_DAMAGE_MULT))
		assert_eq(strikes[0].data["kind"], &"counter")


# --- Lightning Form ---

func test_form_costs_edge_lasts_its_duration_and_emits_events() -> void:
	var core: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	core.step(_frame(false, true))
	assert_true(core.player.is_lightning_form())
	assert_near(core.player.edge, 100.0 - Tuning.LIGHTNING_FORM_EDGE_COST, 0.001, "Edge spent")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "a free action")
	var started: GameEvent = find_event(core, GameEvent.WEAPON_BUFF_STARTED)
	assert_true(started != null)
	if started != null:
		assert_eq(started.data["weapon_id"], Tuning.WEAPON_DUAL_DAGGER)
		assert_eq(started.data["form"], Weapons.FORM_LIGHTNING)
		assert_eq(started.data["duration"], Tuning.LIGHTNING_FORM_DURATION_TICKS)
		assert_near(float(started.data["attack_speed_mult"]), Tuning.LIGHTNING_FORM_ATTACK_SPEED_MULT, 0.0001)
		assert_near(float(started.data["damage_mult"]), Tuning.LIGHTNING_FORM_DAMAGE_MULT, 0.0001)
		assert_near(float(started.data["move_speed_mult"]), Tuning.LIGHTNING_FORM_MOVE_SPEED_MULT, 0.0001)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.weapon_form, Weapons.FORM_LIGHTNING)
	assert_true(snap.player.weapon_buff_active)
	assert_eq(snap.player.weapon_buff_ticks_left, Tuning.LIGHTNING_FORM_DURATION_TICKS)
	assert_near(snap.player.attack_speed_mult, Tuning.LIGHTNING_FORM_ATTACK_SPEED_MULT, 0.0001)
	assert_near(snap.player.move_speed_mult, Tuning.LIGHTNING_FORM_MOVE_SPEED_MULT, 0.0001)
	var ended_on: int = -1
	for i: int in Tuning.LIGHTNING_FORM_DURATION_TICKS + 5:
		core.step(input())
		var ended: GameEvent = find_event(core, GameEvent.WEAPON_BUFF_ENDED)
		if ended != null:
			ended_on = i + 1
			assert_eq(ended.data["reason"], &"expired")
			assert_eq(ended.data["form"], Weapons.FORM_LIGHTNING)
	assert_eq(ended_on, Tuning.LIGHTNING_FORM_DURATION_TICKS, "ends on tick activation + duration")
	assert_eq(core.snapshot().player.weapon_form, &"")
	assert_near(core.snapshot().player.move_speed_mult, 1.0, 0.0001)


func test_form_needs_edge_and_its_cooldown_counts_from_activation() -> void:
	var poor: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	poor.player.edge = Tuning.LIGHTNING_FORM_EDGE_COST - 1.0
	poor.step(_frame(false, true))
	assert_false(poor.player.is_buff_active(), "not enough Edge")
	assert_eq(_count(poor, GameEvent.WEAPON_BUFF_STARTED), 0)
	var core: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	core.step(_frame(false, true))
	run(core, Tuning.LIGHTNING_FORM_COOLDOWN_TICKS - 2)
	core.player.edge = 100.0
	core.step(_frame(false, true))  # activation + 1499 ticks
	assert_false(core.player.is_buff_active(), "one tick short of the cooldown")
	core.step(_frame(false, true))  # activation + 1500 ticks
	assert_true(core.player.is_lightning_form(), "ready exactly LIGHTNING_FORM_COOLDOWN_TICKS after the activation")


func test_form_cannot_be_refreshed_and_death_ends_it() -> void:
	var core: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	core.step(_frame(false, true))
	run(core, 50)
	core.player.buff_cooldown = 0
	var left: int = core.player.buff_ticks
	var edge: float = core.player.edge
	core.step(_frame(false, true))
	assert_eq(core.player.buff_ticks, left - 1, "not refreshed")
	assert_near(core.player.edge, edge, 0.001, "no second cost")
	assert_eq(_count(core, GameEvent.WEAPON_BUFF_STARTED), 0)
	var events: Array[GameEvent] = []
	core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
	var ended: Array[GameEvent] = events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.WEAPON_BUFF_ENDED)
	assert_eq(ended.size(), 1, "weapon_buff_ended on death")
	if ended.size() == 1:
		assert_eq(ended[0].data["reason"], &"death")
		assert_eq(ended[0].data["form"], Weapons.FORM_LIGHTNING)
	assert_false(core.player.is_lightning_form())


func test_form_doubles_attack_speed_and_speeds_up_walking() -> void:
	var plain: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	plain.step(input(Vector2.ZERO, false, false, true))
	var normal: int = 0
	while plain.player.state.begins_with("attack_") and normal < 100:
		plain.step(input())
		normal += 1
	assert_eq(normal, _swing_total(Tuning.WEAPON_DUAL_DAGGER, 1))
	var fast: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	fast.step(_frame(false, true))
	fast.step(input(Vector2.ZERO, false, false, true))
	var formed: int = 0
	while fast.player.state.begins_with("attack_") and formed < 100:
		fast.step(input())
		formed += 1
	assert_eq(formed, _swing_total(Tuning.WEAPON_DUAL_DAGGER, 1, Tuning.LIGHTNING_FORM_ATTACK_SPEED_MULT), "every phase at x2")
	var walker: GameCore = _dagger_core(Vector2(-200.0, 0.0))
	walker.step(_frame(false, true))
	var start: Vector2 = walker.player.position
	run(walker, 10, input(Vector2.UP))
	assert_near(start.distance_to(walker.player.position), 10.0 * Tuning.PLAYER_SPEED * Tuning.LIGHTNING_FORM_MOVE_SPEED_MULT, 0.01, "walks x1.25")


# --- the blink ---

func _form_core(offset: Vector2 = Vector2(-100.0, 0.0), boss_at: Vector2 = BOSS_AT, clear_props: bool = true) -> GameCore:
	var core: GameCore = _dagger_core(offset, boss_at, clear_props)
	core.step(_frame(false, true))
	assert_true(core.player.is_lightning_form(), "the form started")
	return core


func test_a_swing_in_the_form_blinks_next_to_the_boss_and_connects() -> void:
	var core: GameCore = _form_core()
	var from: Vector2 = core.player.position
	core.step(_frame(false, false, true, Vector2.LEFT))
	var blink: GameEvent = find_event(core, GameEvent.LIGHTNING_BLINK)
	assert_true(blink != null, "lightning_blink emitted")
	if blink == null:
		return
	var expected: Vector2 = BOSS_AT + Weapons.blink_direction(Tuning.LIGHTNING_BLINK_ORDER[0]) * Tuning.LIGHTNING_BLINK_DISTANCE
	assert_eq(blink.data["from"], from)
	assert_eq(blink.data["to"], expected)
	assert_eq(blink.data["direction_index"], Tuning.LIGHTNING_BLINK_ORDER[0])
	assert_eq(blink.data["entity_id"], core.player.id)
	assert_eq(core.player.position, expected, "the player is there")
	var dist: float = core.player.position.distance_to(core.boss.position)
	assert_true(dist >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS, "outside the boss")
	assert_true(dist - Tuning.BOSS_RADIUS <= Tuning.ATTACK_RANGE * Tuning.DAGGER_SWING_RANGE_MULT[0], "within reach")
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.lightning_blink_index, Tuning.LIGHTNING_BLINK_ORDER[0])
	assert_eq(snap.player.lightning_blink_tick, core.tick)
	assert_eq(snap.player.lightning_blink_from, from)
	assert_eq(snap.player.lightning_blink_to, expected)
	assert_true(snap.player.facing.dot((core.boss.position - core.player.position).normalized()) > 0.99, "facing the boss")
	# Walking away during the swing does not turn the slash away from the boss.
	var hits: Array[GameEvent] = _collect(core, 12, GameEvent.ATTACK_HIT, input(Vector2.RIGHT))
	assert_eq(hits.size(), 1, "the blink swing connects")


func test_blink_gives_short_invulnerability() -> void:
	var core: GameCore = _form_core()
	assert_false(core.player.is_invulnerable())
	core.step(input(Vector2.ZERO, false, false, true))
	assert_true(find_event(core, GameEvent.LIGHTNING_BLINK) != null)
	var invulnerable: int = 1 if core.player.is_invulnerable() else 0
	assert_true(core.snapshot().player.invulnerable, "the snapshot shows it")
	for i: int in 20:
		core.step(input())
		if core.player.is_invulnerable():
			invulnerable += 1
	assert_eq(invulnerable, Tuning.LIGHTNING_BLINK_INVULN_TICKS, "invulnerable for the blink ticks, counting the blink tick")


func test_blinks_cycle_through_the_directions_deterministically() -> void:
	var core: GameCore = _form_core()
	var seen: Array[int] = []
	for i: int in 200:
		core.boss.hp = Tuning.BOSS_MAX_HP  # the mashing would finish the boss (and freeze the core) otherwise
		core.step(input(Vector2.ZERO, false, false, true))  # mash: every swing blinks
		var blink: GameEvent = find_event(core, GameEvent.LIGHTNING_BLINK)
		if blink != null:
			seen.append(int(blink.data["direction_index"]))
	assert_true(seen.size() >= 10, "many blinks, got %d" % seen.size())
	for i: int in seen.size():
		assert_eq(seen[i], Tuning.LIGHTNING_BLINK_ORDER[i % Tuning.LIGHTNING_BLINK_ORDER.size()], "blink %d" % (i + 1))
	# A fresh form starts the cycle over.
	run(core, Tuning.LIGHTNING_FORM_DURATION_TICKS)
	assert_false(core.player.is_buff_active())
	core.player.buff_cooldown = 0
	core.player.edge = 100.0
	core.player.position = BOSS_AT + Vector2(-100.0, 0.0)
	core.step(_frame(false, true))
	core.step(input(Vector2.ZERO, false, false, true))
	var first: GameEvent = find_event(core, GameEvent.LIGHTNING_BLINK)
	assert_true(first != null)
	if first != null:
		assert_eq(first.data["direction_index"], Tuning.LIGHTNING_BLINK_ORDER[0], "a new form starts at the first direction")


func test_no_blink_out_of_range_or_without_the_form() -> void:
	var far: GameCore = _form_core(Vector2(-(Tuning.LIGHTNING_BLINK_RANGE + 5.0), 0.0))
	var at: Vector2 = far.player.position
	far.step(input(Vector2.ZERO, false, false, true))
	assert_eq(_count(far, GameEvent.LIGHTNING_BLINK), 0, "boss out of range")
	assert_true(far.player.position.distance_to(at) < 1.0, "the swing happens where the player stands")
	var plain: GameCore = _dagger_core(Vector2(-100.0, 0.0))
	plain.step(input(Vector2.ZERO, false, false, true))
	assert_eq(_count(plain, GameEvent.LIGHTNING_BLINK), 0, "no form, no blink")
	var dead_boss: GameCore = _form_core()
	dead_boss.boss.take_damage(Tuning.BOSS_MAX_HP, dead_boss.tick, [], dead_boss.player.id)
	dead_boss.step(input(Vector2.ZERO, false, false, true))
	assert_eq(_count(dead_boss, GameEvent.LIGHTNING_BLINK), 0)


## Every blink spot, for every slot of the cycle, with the boss next to walls, corners and props: inside the arena,
## outside the boss and every prop, within the swing's reach.
func test_blink_spots_respect_walls_props_and_the_boss() -> void:
	var low: float = Tuning.ARENA_MARGIN
	var high: Vector2 = Tuning.ARENA_SIZE - Vector2(low, low)
	var spots: Array[Vector2] = [
		Vector2(low + 4.0, 240.0), Vector2(high.x - 4.0, 240.0), Vector2(400.0, low + 4.0), Vector2(400.0, high.y - 4.0),
		Vector2(low, low), Vector2(high.x, high.y), Vector2(152.0, 100.0), Vector2(400.0, 120.0), Vector2(400.0, 395.0),
		Vector2(96.0, 230.0), Vector2(256.0, 112.0),
	]
	var reach: float = Tuning.BOSS_RADIUS + Tuning.ATTACK_RANGE * Tuning.DAGGER_SWING_RANGE_MULT[0]
	for boss_at: Vector2 in spots:
		for slot: int in Tuning.LIGHTNING_BLINK_ORDER.size():
			var core: GameCore = _form_core(Vector2.ZERO, boss_at, false)
			core.boss.position = core.push_out_of_obstacles(boss_at, Tuning.BOSS_RADIUS).clamp(Vector2(low, low), high)
			core.player.position = core.push_out_of_obstacles(core.boss.position + (Vector2(400.0, 240.0) - core.boss.position).normalized() * 70.0, Tuning.PLAYER_RADIUS)
			core.player.blink_count = slot
			core.step(input(Vector2.ZERO, false, false, true))
			var blink: GameEvent = find_event(core, GameEvent.LIGHTNING_BLINK)
			var label: String = "boss %s slot %d" % [str(boss_at), slot]
			assert_true(blink != null, "a free spot was found, " + label)
			if blink == null:
				continue
			var to: Vector2 = blink.data["to"]
			assert_true(to.x >= low and to.y >= low and to.x <= high.x and to.y <= high.y, "inside the arena, " + label)
			var dist: float = to.distance_to(core.boss.position)
			assert_true(dist >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.02, "not inside the boss (%.2f), %s" % [dist, label])
			assert_true(dist <= reach + 0.01, "within reach (%.2f), %s" % [dist, label])
			for obstacle: Obstacle in core.obstacles:
				assert_true(to.distance_to(obstacle.center) >= obstacle.radius + Tuning.PLAYER_RADIUS - 0.02, "not inside prop %d, %s" % [obstacle.id, label])
			assert_true(core.player.position.distance_to(to) < 0.01, "nothing moved the player off the spot, " + label)
			assert_eq(_collect(core, 10, GameEvent.ATTACK_HIT).size(), 1, "and the swing connects, " + label)


func test_a_blocked_direction_falls_back_to_the_nearest_free_one() -> void:
	var core: GameCore = _form_core(Vector2(100.0, 0.0), Vector2(Tuning.ARENA_MARGIN + 4.0, 240.0))
	core.player.blink_count = Tuning.LIGHTNING_BLINK_ORDER.find(4)  # direction 4 = left, into the wall
	core.step(input(Vector2.ZERO, false, false, true))
	var blink: GameEvent = find_event(core, GameEvent.LIGHTNING_BLINK)
	assert_true(blink != null)
	if blink != null:
		# 4 (left) is in the wall; its neighbours 5 and 3 are clamped back into the boss; 6 (up) is the next one tried.
		assert_eq(int(blink.data["direction_index"]), 6, "the nearest free direction")


# --- save profile ---

func test_save_profile_accepts_the_dagger_and_old_saves_still_load() -> void:
	var SaveProfile: GDScript = load("res://core/save_profile.gd")
	var dagger: Object = SaveProfile.from_json("{\"version\": 1, \"weapon_id\": \"dual_dagger\"}")
	assert_eq(dagger.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	var old: Object = SaveProfile.from_json("{\"version\": 1, \"victories\": 2}")
	assert_eq(old.weapon_id, Tuning.WEAPON_BLACK_KATANA, "a save without a weapon loads with the katana")
	assert_eq(old.victories, 2)
	assert_eq(old.load_note, "")


# --- determinism and a long soak ---

func _scripted_frame(core: GameCore, i: int) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	var to_boss: Vector2 = core.boss.position - core.player.position
	frame.move = to_boss.normalized() if to_boss.length() > 40.0 else Vector2.ZERO
	frame.aim = to_boss.normalized()
	frame.attack_pressed = i % 3 == 0 and i % 400 >= 60
	frame.weapon_swap_pressed = i % 400 >= 45 and i % 400 <= 55  # the lockout makes the first press count
	frame.weapon_active_pressed = i % 50 == 7
	frame.dash_pressed = i % 97 == 11
	frame.parry_pressed = i % 131 == 17
	frame.skill_pressed = 2 if i % 211 == 23 else 0
	return frame


func _trace(seed_value: int) -> Array[String]:
	var core: GameCore = GameCore.new(seed_value)
	var lines: Array[String] = []
	for i: int in 1500:
		core.player.edge = 100.0 if i % 300 == 0 else core.player.edge
		core.player.hp = Tuning.PLAYER_MAX_HP  # keep the fight going
		core.boss.hp = Tuning.BOSS_MAX_HP
		core.step(_scripted_frame(core, i))
		lines.append("%d %s %s %s %d %d %s %s" % [core.tick, str(core.player.position), core.player.state, core.player.weapon_id, core.player.hp, core.boss.hp, str(core.boss.position), str(event_types(core))])
	return lines


func test_two_identical_runs_give_identical_results() -> void:
	var a: Array[String] = _trace(7)
	var b: Array[String] = _trace(7)
	assert_eq(a.size(), b.size())
	var first_diff: int = -1
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			first_diff = i
			break
	assert_eq(first_diff, -1, "the runs diverged at step %d" % first_diff)
	var joined: String = "\n".join(a)
	assert_true(joined.contains(String(GameEvent.WEAPON_SWAPPED)) and joined.contains(String(GameEvent.LIGHTNING_BLINK)), "the run used the swap and the blink")


func test_long_soak_with_the_form_never_overlaps_props_or_leaves_the_arena() -> void:
	for seed_value: int in [3, 11]:
		var core: GameCore = GameCore.new(seed_value)
		core.player.weapon_id = Tuning.WEAPON_DUAL_DAGGER
		var blinks: int = 0
		var strikes: int = 0
		var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
		var high: Vector2 = Tuning.ARENA_SIZE - low
		var bad: int = 0
		for i: int in 3000:
			core.player.edge = 100.0
			core.player.hp = Tuning.PLAYER_MAX_HP
			core.boss.hp = Tuning.BOSS_MAX_HP
			if not core.player.is_buff_active():
				core.player.buff_cooldown = 0
			var frame: InputFrame = InputFrame.new()
			var to_boss: Vector2 = core.boss.position - core.player.position
			# Wander the arena half the time so blinks start from everywhere, chase the boss the other half.
			frame.move = to_boss.normalized() if i % 400 < 200 else Vector2.RIGHT.rotated(floorf(float(i) / 37.0))
			frame.aim = to_boss.normalized()
			frame.attack_pressed = i % 2 == 0
			frame.weapon_active_pressed = true
			core.step(frame)
			if core.result != GameCore.RESULT_PLAYING:
				break
			blinks += event_types(core).count(GameEvent.LIGHTNING_BLINK)
			strikes += event_types(core).count(GameEvent.LIGHTNING_STRIKE)
			var p: Vector2 = core.player.position
			if p.x < low.x - 0.01 or p.y < low.y - 0.01 or p.x > high.x + 0.01 or p.y > high.y + 0.01:
				bad += 1
			for obstacle: Obstacle in core.obstacles:
				if p.distance_to(obstacle.center) < obstacle.radius + Tuning.PLAYER_RADIUS - 0.05:
					bad += 1
			if p.distance_to(core.boss.position) < Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.05:
				bad += 1
		assert_eq(bad, 0, "seed %d: ticks with the player in a prop, in the boss or outside the arena" % seed_value)
		assert_true(blinks > 50, "seed %d: the form blinked often (%d)" % [seed_value, blinks])
		assert_true(strikes > 5, "seed %d: lightning strikes landed (%d)" % [seed_value, strikes])
