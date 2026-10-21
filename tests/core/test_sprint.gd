extends "res://tests/test_case.gd"
## Sprint (aspect, 2026-10-21): a free-action buff. For SPRINT_DURATION_TICKS every move that uses the walking speed is
## SPRINT_MOVE_SPEED_MULT faster; dash and skill motions keep their own speeds.

const Aspects := preload("res://core/aspects.gd")
const Weapons := preload("res://core/weapons.gd")


## Open field, a pinned boss far away in the corner, full Edge, Sprint in slot 3.
func _core() -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = Vector2(740.0, 440.0)
	core.player.position = Vector2(80.0, 240.0)
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	var equip: InputFrame = InputFrame.new()
	equip.aspect_equip = Aspects.SPRINT
	equip.aspect_equip_slot = 3
	core.step(equip)
	assert_eq(core.player.equipped_aspects[2], Aspects.SPRINT)
	return core


func _press(core: GameCore, move: Vector2 = Vector2.ZERO) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 3
	frame.move = move
	core.step(frame)


func _to(core: GameCore, target: int) -> void:
	while core.tick < target and core.result == GameCore.RESULT_PLAYING:
		core.step(InputFrame.new())


func test_walking_is_doubled_for_exactly_the_duration() -> void:
	var core: GameCore = _core()
	var x0: float = core.player.position.x
	_press(core, Vector2.RIGHT)
	var start: int = core.tick
	var started: GameEvent = find_event(core, GameEvent.SPRINT_STARTED)
	assert_true(started != null, "sprint_started")
	if started != null:
		assert_eq(started.data["duration"], Tuning.SPRINT_DURATION_TICKS)
		assert_near(float(started.data["move_speed_mult"]), 2.0, 0.0001)
		assert_eq(started.data["entity_id"], core.player.id)
	assert_near(core.player.position.x - x0, Tuning.PLAYER_SPEED * 2.0, 0.0001, "the press tick already moves fast")
	assert_eq(core.player.state, PlayerState.STATE_WALK, "no state change")
	assert_true(find_event(core, GameEvent.SKILL_STARTED) == null, "not a skill action")
	var fast: int = 1
	var ended_tick: int = -1
	for i: int in Tuning.SPRINT_DURATION_TICKS + 5:
		var before: float = core.player.position.x
		core.step(input(Vector2.RIGHT))
		var moved: float = core.player.position.x - before
		if absf(moved - Tuning.PLAYER_SPEED * 2.0) < 0.0001:
			fast += 1
		else:
			assert_near(moved, Tuning.PLAYER_SPEED, 0.0001, "normal speed after it (tick %d)" % core.tick)
		if find_event(core, GameEvent.SPRINT_ENDED) != null:
			ended_tick = core.tick
			assert_eq(find_event(core, GameEvent.SPRINT_ENDED).data["reason"], &"expired")
	assert_eq(fast, Tuning.SPRINT_DURATION_TICKS, "exactly 180 fast ticks")
	assert_eq(ended_tick, start + Tuning.SPRINT_DURATION_TICKS, "sprint_ended on the tick after its last one")
	assert_eq(core.player.sprint_ticks_left, 0)
	assert_near(core.snapshot().player.move_speed_mult, 1.0, 0.0001)
	assert_eq(Tuning.SPRINT_DURATION_TICKS, 180)
	assert_near(Tuning.SPRINT_MOVE_SPEED_MULT, 2.0, 0.0001)


func test_cost_cooldown_and_no_refresh() -> void:
	var poor: GameCore = _core()
	poor.player.edge = Tuning.SPRINT_EDGE_COST - 1.0
	_press(poor)
	assert_eq(poor.player.sprint_ticks_left, 0, "not enough Edge")
	assert_true(find_event(poor, GameEvent.SPRINT_STARTED) == null)
	var core: GameCore = _core()
	_press(core)
	var start: int = core.tick
	assert_near(core.player.edge, 100.0 - Tuning.SPRINT_EDGE_COST, 0.001, "20 Edge on the press")
	assert_eq(int(core.player.aspect_cooldowns[Aspects.SPRINT]), Tuning.SPRINT_COOLDOWN_TICKS)
	run(core, 20)
	core.player.edge = 100.0
	core.player.aspect_cooldowns[Aspects.SPRINT] = 0  # isolate the no-refresh rule from the cooldown
	_press(core)
	assert_true(find_event(core, GameEvent.SPRINT_STARTED) == null, "no refresh while it runs")
	assert_eq(core.player.sprint_ticks_left, Tuning.SPRINT_DURATION_TICKS - 21)
	assert_near(core.player.edge, 100.0, 0.001, "nothing spent")
	var again: GameCore = _core()
	_press(again)
	var a: int = again.tick
	_to(again, a + Tuning.SPRINT_COOLDOWN_TICKS - 2)
	_press(again)
	assert_eq(again.player.sprint_ticks_left, 0, "still cooling down one tick early")
	_press(again)
	assert_eq(again.tick, a + Tuning.SPRINT_COOLDOWN_TICKS)
	assert_eq(again.player.sprint_ticks_left, Tuning.SPRINT_DURATION_TICKS, "ready again 720 ticks after the activation")
	assert_eq(Tuning.SPRINT_COOLDOWN_TICKS, 720)
	assert_near(Tuning.SPRINT_EDGE_COST, 20.0, 0.0001)
	assert_true(start > 0)


func test_the_slowed_swing_and_parry_recovery_movement_scale_too() -> void:
	var plain: GameCore = _core()
	var fast: GameCore = _core()
	_press(fast)
	plain.step(InputFrame.new())
	for core: GameCore in [plain, fast]:
		core.step(input(Vector2.RIGHT, false, false, true))  # the press starts the swing (no movement this tick)
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP)
	var x_plain: float = plain.player.position.x
	var x_fast: float = fast.player.position.x
	plain.step(input(Vector2.RIGHT))
	fast.step(input(Vector2.RIGHT))
	assert_eq(fast.player.state, PlayerState.STATE_ATTACK_WINDUP)
	assert_near(plain.player.position.x - x_plain, Tuning.PLAYER_SPEED * Tuning.ATTACK_MOVE_FACTOR, 0.0001)
	assert_near(fast.player.position.x - x_fast, Tuning.PLAYER_SPEED * Tuning.ATTACK_MOVE_FACTOR * 2.0, 0.0001, "windup movement x2")
	var parry: GameCore = _core()
	_press(parry)
	parry.step(input(Vector2.ZERO, false, true))
	_to(parry, parry.tick + Tuning.PARRY_ACTIVE_TICKS)
	assert_eq(parry.player.state, PlayerState.STATE_PARRY_RECOVERY)
	var x: float = parry.player.position.x
	parry.step(input(Vector2.RIGHT))
	assert_near(parry.player.position.x - x, Tuning.PLAYER_SPEED * Tuning.PARRY_RECOVERY_MOVE_FACTOR * 2.0, 0.0001, "parry recovery x2")


func test_the_dash_keeps_its_own_speed() -> void:
	var plain: GameCore = _core()
	var fast: GameCore = _core()
	_press(fast)
	plain.step(InputFrame.new())
	var a: float = plain.player.position.x
	var b: float = fast.player.position.x
	plain.step(input(Vector2.RIGHT, true))
	fast.step(input(Vector2.RIGHT, true))
	run(plain, Tuning.DASH_TICKS + 1, input(Vector2.RIGHT))
	run(fast, Tuning.DASH_TICKS + 1, input(Vector2.RIGHT))
	var dash_plain: float = plain.player.position.x - a
	var dash_fast: float = fast.player.position.x - b
	# Both ran the same ticks: the dash part is identical, only the walking tick after it differs (1 vs 2 px).
	assert_near(dash_fast - dash_plain, Tuning.PLAYER_SPEED, 0.0001, "only the walking tick after the dash is faster")
	assert_near(dash_plain, Tuning.DASH_SPEED * Tuning.DASH_TICKS + Tuning.PLAYER_SPEED, 0.0001)


func test_allowed_in_actions_refused_in_barrage_and_after_death() -> void:
	var mid: GameCore = _core()
	mid.step(input(Vector2.ZERO, false, false, true))
	_press(mid)
	assert_true(mid.player.sprint_ticks_left > 0, "works mid-swing")
	assert_true(String(mid.player.state).begins_with("attack_"), "and the swing goes on")
	var dash: GameCore = _core()
	dash.step(input(Vector2.UP, true))
	_press(dash, Vector2.UP)
	assert_true(dash.player.sprint_ticks_left > 0, "works mid-dash")
	var barrage: GameCore = _core()
	barrage.player.weapon_id = Tuning.WEAPON_DUAL_DAGGER
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	barrage.step(active)
	assert_eq(barrage.player.state, PlayerState.STATE_LIGHTNING_BARRAGE)
	barrage.player.edge = 100.0
	_press(barrage)
	assert_eq(barrage.player.sprint_ticks_left, 0, "refused during the barrage")
	var same_tick: GameCore = _core()
	same_tick.player.weapon_id = Tuning.WEAPON_CHAIN_SCYTHE
	var both: InputFrame = InputFrame.new()
	both.weapon_active_pressed = true
	both.skill_pressed = 3
	same_tick.step(both)
	assert_eq(same_tick.player.state, PlayerState.STATE_REAPER_COIL)
	assert_eq(same_tick.player.sprint_ticks_left, 0, "refused on the coil's activation tick")
	var dead: GameCore = _core()
	var events: Array[GameEvent] = []
	dead.player.take_damage(Tuning.PLAYER_MAX_HP, dead.tick, events, dead.boss.id)
	_press(dead)
	assert_eq(dead.player.sprint_ticks_left, 0, "nothing after death")


func test_death_ends_it() -> void:
	var core: GameCore = _core()
	_press(core)
	run(core, 10)
	var events: Array[GameEvent] = []
	core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
	var ended: GameEvent = null
	for event: GameEvent in events:
		if event.type == GameEvent.SPRINT_ENDED:
			ended = event
	assert_true(ended != null and ended.data["reason"] == &"death", "sprint_ended death")
	assert_eq(core.player.sprint_ticks_left, 0)
	var types: Array[StringName] = []
	for event: GameEvent in events:
		types.append(event.type)
	assert_true(types.find(GameEvent.SPRINT_ENDED) < types.find(GameEvent.ENTITY_DIED), "before entity_died")


func test_snapshot_and_hud_row() -> void:
	var core: GameCore = _core()
	var row: Dictionary = core.snapshot().hud.aspect_slots[2]
	assert_eq(row["aspect_id"], Aspects.SPRINT)
	assert_eq(row["kind"], Aspects.KIND_BUFF)
	assert_eq(row["name"], "Sprint")
	assert_eq(row["running"], false)
	assert_eq(row["duration"], Tuning.SPRINT_DURATION_TICKS)
	assert_eq(row["cooldown_max"], Tuning.SPRINT_COOLDOWN_TICKS)
	assert_eq(row["edge_cost"], Tuning.SPRINT_EDGE_COST)
	_press(core)
	run(core, 9)
	var snap = core.snapshot()
	row = snap.hud.aspect_slots[2]
	assert_eq(row["running"], true)
	assert_eq(row["ticks_left"], Tuning.SPRINT_DURATION_TICKS - 9)
	assert_eq(row["cooldown_ticks"], Tuning.SPRINT_COOLDOWN_TICKS - 9)
	assert_eq(snap.player.sprint_ticks_left, Tuning.SPRINT_DURATION_TICKS - 9)
	assert_near(snap.player.move_speed_mult, Tuning.SPRINT_MOVE_SPEED_MULT, 0.0001)
	assert_true(Aspects.is_free_action(Aspects.SPRINT))
