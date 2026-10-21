extends "res://tests/test_case.gd"
## Spirit Lantern (aspect, 2026-10-21): a skill action that places a lantern at the player's feet; it pulses every
## SPIRIT_LANTERN_PULSE_INTERVAL_TICKS for SPIRIT_LANTERN_DURATION_TICKS, healing the player and building Edge in its light.

const Aspects := preload("res://core/aspects.gd")
const Snapshots := preload("res://core/snapshots.gd")

const BOSS_AT: Vector2 = Vector2(600.0, 240.0)
const PLAYER_AT: Vector2 = Vector2(200.0, 240.0)


## A pinned boss far away in an open field, full Edge, the lantern in slot 2.
func _core() -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = BOSS_AT
	core.player.position = PLAYER_AT
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	var equip: InputFrame = InputFrame.new()
	equip.aspect_equip = Aspects.SPIRIT_LANTERN
	equip.aspect_equip_slot = 2
	core.step(equip)
	assert_eq(core.player.equipped_aspects[1], Aspects.SPIRIT_LANTERN)
	return core


## Step with idle input until core.tick == target, but never past the end of the fight (a finished fight no longer
## advances core.tick, so the shared run_to_tick would never return if a broken rule ended it early).
func _to(core: GameCore, target: int) -> void:
	while core.tick < target and core.result == GameCore.RESULT_PLAYING:
		core.step(InputFrame.new())


func _press(core: GameCore, slot: int = 2) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = slot
	core.step(frame)


## Press the lantern and step until it is placed. Returns the placement tick (-1 if it never was).
func _place(core: GameCore) -> int:
	_press(core)
	for i: int in Tuning.SPIRIT_LANTERN_WINDUP_TICKS + 2:
		if find_event(core, GameEvent.LANTERN_PLACED) != null:
			return core.tick
		core.step(InputFrame.new())
	return core.tick if find_event(core, GameEvent.LANTERN_PLACED) != null else -1


func _events_of(core: GameCore, type: StringName) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event: GameEvent in core.last_events:
		if event.type == type:
			found.append(event)
	return found


func test_the_press_runs_a_short_skill_and_places_the_lantern_at_the_feet() -> void:
	var core: GameCore = _core()
	_press(core)
	var press_tick: int = core.tick
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP)
	assert_eq(core.player.skill_id, Aspects.SPIRIT_LANTERN)
	assert_near(core.player.edge, 100.0 - Tuning.SPIRIT_LANTERN_EDGE_COST, 0.001, "Edge spent on the press")
	var started: GameEvent = find_event(core, GameEvent.SKILL_STARTED)
	assert_true(started != null and started.data["skill_id"] == Aspects.SPIRIT_LANTERN, "skill_started")
	assert_eq(int(core.player.aspect_cooldowns.get(Aspects.SPIRIT_LANTERN, 0)), 0, "no cooldown before the placement")
	run(core, Tuning.SPIRIT_LANTERN_WINDUP_TICKS - 1)
	assert_eq(core.lanterns.size(), 0, "nothing during the windup")
	core.step(InputFrame.new())
	assert_eq(core.tick, press_tick + Tuning.SPIRIT_LANTERN_WINDUP_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_ACTIVE)
	var placed: GameEvent = find_event(core, GameEvent.LANTERN_PLACED)
	assert_true(placed != null, "lantern_placed on the first active tick")
	assert_eq(core.lanterns.size(), 1)
	if placed != null:
		assert_eq(placed.data["position"], PLAYER_AT, "at the player's feet")
		assert_eq(placed.data["radius"], Tuning.SPIRIT_LANTERN_RADIUS)
		assert_eq(placed.data["duration"], Tuning.SPIRIT_LANTERN_DURATION_TICKS)
		assert_eq(placed.data["entity_id"], core.player.id)
	assert_true(find_event(core, GameEvent.SKILL_RELEASED) == null, "no attack object")
	assert_eq(core.skill_attacks.size(), 0)
	run(core, Tuning.SPIRIT_LANTERN_ACTIVE_TICKS + Tuning.SPIRIT_LANTERN_RECOVERY_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "recovery over")
	core.step(input(Vector2.RIGHT))
	assert_eq(core.player.state, PlayerState.STATE_WALK, "free to move; the lantern stays")
	assert_eq(core.lanterns[0].position, PLAYER_AT)
	assert_eq(Tuning.SPIRIT_LANTERN_RADIUS, 44.0, "the bigger radius the human asked for")


func test_exactly_five_pulses_at_the_right_ticks_then_it_expires() -> void:
	var core: GameCore = _core()
	var placed: int = _place(core)
	assert_true(placed > 0)
	var pulse_ticks: Array[int] = []
	var expired_tick: int = -1
	for i: int in Tuning.SPIRIT_LANTERN_DURATION_TICKS + 30:
		core.step(InputFrame.new())
		for event: GameEvent in _events_of(core, GameEvent.LANTERN_PULSE):
			pulse_ticks.append(core.tick)
			assert_eq(event.data["pulse_index"], pulse_ticks.size(), "pulse index")
		var expired: GameEvent = find_event(core, GameEvent.LANTERN_EXPIRED)
		if expired != null:
			expired_tick = core.tick
			assert_eq(expired.data["reason"], &"expired")
	var expected: Array[int] = []
	for k: int in range(1, Tuning.SPIRIT_LANTERN_PULSES + 1):
		expected.append(placed + k * Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	assert_eq(pulse_ticks, expected, "pulses at placement + 60, 120, ... 300")
	assert_eq(expired_tick, placed + Tuning.SPIRIT_LANTERN_DURATION_TICKS, "expires right after its last pulse")
	assert_eq(core.lanterns.size(), 0, "gone")
	assert_eq(core.snapshot().lanterns.size(), 0)
	assert_eq(Tuning.SPIRIT_LANTERN_PULSES * Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS, Tuning.SPIRIT_LANTERN_DURATION_TICKS)


func test_a_pulse_heals_and_builds_edge_up_to_the_caps() -> void:
	var core: GameCore = _core()
	var placed: int = _place(core)
	core.player.hp = 50
	core.player.edge = 10.0
	_to(core, placed + Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	var pulse: GameEvent = find_event(core, GameEvent.LANTERN_PULSE)
	assert_true(pulse != null)
	if pulse != null:
		assert_eq(pulse.data["player_inside"], true)
		assert_eq(pulse.data["healed"], Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE)
		assert_near(pulse.data["edge_gained"], Tuning.SPIRIT_LANTERN_EDGE_PER_PULSE, 0.001)
	assert_eq(core.player.hp, 50 + Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE)
	assert_near(core.player.edge, 10.0 + Tuning.SPIRIT_LANTERN_EDGE_PER_PULSE, 0.001)
	core.player.hp = Tuning.PLAYER_MAX_HP - 2
	core.player.edge = Tuning.EDGE_MAX - 3.0
	_to(core, placed + 2 * Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	pulse = find_event(core, GameEvent.LANTERN_PULSE)
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "never above max HP")
	assert_near(core.player.edge, Tuning.EDGE_MAX, 0.001, "never above max Edge")
	if pulse != null:
		assert_eq(pulse.data["healed"], 2, "reports what it really healed")
		assert_near(pulse.data["edge_gained"], 3.0, 0.001)
	_to(core, placed + 3 * Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	pulse = find_event(core, GameEvent.LANTERN_PULSE)
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP)
	if pulse != null:
		assert_eq(pulse.data["healed"], 0, "full: nothing")
		assert_eq(pulse.data["player_inside"], true)


func test_just_inside_heals_just_outside_does_not() -> void:
	for offset: float in [Tuning.SPIRIT_LANTERN_RADIUS - 0.1, Tuning.SPIRIT_LANTERN_RADIUS + 0.1, Tuning.SPIRIT_LANTERN_RADIUS, 30.0, 60.0]:
		var core: GameCore = _core()
		var placed: int = _place(core)
		run(core, Tuning.SPIRIT_LANTERN_ACTIVE_TICKS + Tuning.SPIRIT_LANTERN_RECOVERY_TICKS)
		core.player.position = PLAYER_AT + Vector2(0.0, offset).rotated(0.7)
		core.player.hp = 50
		core.player.edge = 0.0
		_to(core, placed + Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
		var inside: bool = offset <= Tuning.SPIRIT_LANTERN_RADIUS
		var pulse: GameEvent = find_event(core, GameEvent.LANTERN_PULSE)
		assert_true(pulse != null, "pulse at %.1f" % offset)
		if pulse != null:
			assert_eq(pulse.data["player_inside"], inside, "inside flag at %.1f px" % offset)
		assert_eq(core.player.hp, 50 + (Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE if inside else 0), "heal at %.1f px" % offset)
		assert_near(core.player.edge, Tuning.SPIRIT_LANTERN_EDGE_PER_PULSE if inside else 0.0, 0.001, "Edge at %.1f px" % offset)


func test_the_boss_is_never_affected() -> void:
	var core: GameCore = _core()
	core.boss.position = PLAYER_AT + Vector2(30.0, 0.0)  # inside the light
	core.boss.hp = 200
	var posture: float = core.boss.posture
	var placed: int = _place(core)
	_to(core, placed + Tuning.SPIRIT_LANTERN_DURATION_TICKS)
	assert_eq(core.boss.hp, 200, "no heal, no damage")
	assert_near(core.boss.posture, posture, 1.0, "no posture from the lantern")


func test_placing_again_replaces_the_old_lantern() -> void:
	var core: GameCore = _core()
	var first: int = _place(core)
	run(core, 40)
	core.player.position = PLAYER_AT + Vector2(100.0, 0.0)
	core.player.aspect_cooldowns[Aspects.SPIRIT_LANTERN] = 0  # skip the cooldown for this test
	core.player.edge = 100.0
	var second: int = _place(core)
	var expired: GameEvent = find_event(core, GameEvent.LANTERN_EXPIRED)
	assert_true(expired != null, "the old one goes")
	if expired != null:
		assert_eq(expired.data["reason"], &"replaced")
		assert_eq(expired.data["position"], PLAYER_AT)
	assert_eq(core.lanterns.size(), 1, "one lantern per player")
	assert_eq(core.lanterns[0].position, PLAYER_AT + Vector2(100.0, 0.0))
	assert_eq(core.lanterns[0].placed_tick, second)
	var types: Array[StringName] = event_types(core)
	assert_true(types.find(GameEvent.LANTERN_EXPIRED) < types.find(GameEvent.LANTERN_PLACED), "expired before placed")
	_to(core, first + Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	assert_true(find_event(core, GameEvent.LANTERN_PULSE) == null, "the old timeline is gone")
	_to(core, second + Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	assert_true(find_event(core, GameEvent.LANTERN_PULSE) != null, "the new one pulses on its own timeline")


func test_death_clears_the_lantern_and_a_restart_has_none() -> void:
	var core: GameCore = _core()
	var placed: int = _place(core)
	run(core, 30)
	var events: Array[GameEvent] = []
	core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
	core.step(InputFrame.new())
	var expired: GameEvent = find_event(core, GameEvent.LANTERN_EXPIRED)
	assert_true(expired != null, "removed on death")
	if expired != null:
		assert_eq(expired.data["reason"], &"death")
	assert_true(find_event(core, GameEvent.LANTERN_PULSE) == null, "no pulse on a dead player")
	assert_eq(core.lanterns.size(), 0)
	assert_eq(core.snapshot().lanterns.size(), 0)
	assert_eq(core.player.hp, 0, "no heal brings the player back")
	assert_eq(core.result, GameCore.RESULT_DEFEAT)
	run(core, Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)  # frozen after the result: steps only count result_ticks
	assert_true(core.tick < placed + Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	assert_eq(core.player.hp, 0)
	var fresh: GameCore = GameCore.new()
	assert_eq(fresh.lanterns.size(), 0, "restart: none")
	assert_eq(fresh.snapshot().lanterns.size(), 0)


func test_snapshot_fields() -> void:
	var core: GameCore = _core()
	var placed: int = _place(core)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.lanterns.size(), 1)
	var l: Snapshots.LanternSnapshot = snap.lanterns[0]
	assert_eq(l.id, core.lanterns[0].id)
	assert_eq(l.owner_id, core.player.id)
	assert_eq(l.position, PLAYER_AT)
	assert_eq(l.radius, Tuning.SPIRIT_LANTERN_RADIUS)
	assert_eq(l.placed_tick, placed)
	assert_eq(l.duration, Tuning.SPIRIT_LANTERN_DURATION_TICKS)
	assert_eq(l.ticks_left, Tuning.SPIRIT_LANTERN_DURATION_TICKS)
	assert_eq(l.pulse_index, 0)
	assert_eq(l.pulses, Tuning.SPIRIT_LANTERN_PULSES)
	assert_eq(l.next_pulse_in, Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)
	_to(core, placed + Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS + 5)
	l = core.snapshot().lanterns[0]
	assert_eq(l.pulse_index, 1)
	assert_eq(l.ticks_left, Tuning.SPIRIT_LANTERN_DURATION_TICKS - Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS - 5)
	assert_eq(l.next_pulse_in, Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS - 5)
	_to(core, placed + Tuning.SPIRIT_LANTERN_DURATION_TICKS - 1)
	l = core.snapshot().lanterns[0]
	assert_eq(l.pulse_index, Tuning.SPIRIT_LANTERN_PULSES - 1)
	assert_eq(l.ticks_left, 1)
	assert_eq(l.next_pulse_in, 1)


func test_the_lantern_does_not_block_movement() -> void:
	var core: GameCore = _core()
	_place(core)
	run(core, Tuning.SPIRIT_LANTERN_ACTIVE_TICKS + Tuning.SPIRIT_LANTERN_RECOVERY_TICKS)
	core.player.position = PLAYER_AT + Vector2(-20.0, 0.0)
	run(core, 40, input(Vector2.RIGHT))
	assert_near(core.player.position.x, PLAYER_AT.x + 20.0, 0.01, "walked straight through it")


func test_the_cooldown_counts_from_the_placement() -> void:
	var core: GameCore = _core()
	var placed: int = _place(core)
	assert_eq(int(core.player.aspect_cooldowns[Aspects.SPIRIT_LANTERN]), Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS, "starts on the placement tick")
	assert_eq(core.snapshot().hud.skill_cooldown_ticks[1], Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS)
	_to(core, placed + Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS - 2)
	core.player.edge = 100.0
	_press(core)
	assert_eq(core.tick, placed + Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS - 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "one tick early: refused")
	assert_near(core.player.edge, 100.0, 0.001, "no Edge spent")
	var again: GameCore = _core()
	var placed_again: int = _place(again)
	_to(again, placed_again + Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS - 1)
	again.player.edge = 100.0
	_press(again)
	assert_eq(again.tick, placed_again + Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS)
	assert_eq(again.player.skill_id, Aspects.SPIRIT_LANTERN, "ready exactly COOLDOWN ticks after the placement")
	assert_eq(Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS, 900)
	assert_eq(Tuning.SPIRIT_LANTERN_EDGE_COST, 30.0)


func test_the_cost_and_edge_rule() -> void:
	var core: GameCore = _core()
	core.player.edge = Tuning.SPIRIT_LANTERN_EDGE_COST - 1.0
	_press(core)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "not enough Edge")
	assert_true(find_event(core, GameEvent.SKILL_STARTED) == null)


func test_damage_in_the_windup_cancels_it_without_a_cooldown_and_without_a_refund() -> void:
	var core: GameCore = _core()
	_press(core)
	run(core, Tuning.SPIRIT_LANTERN_WINDUP_TICKS - 3)
	var events: Array[GameEvent] = []
	assert_true(core.player.take_damage(5, core.tick, events, core.boss.id), "the windup is not invulnerable")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "interrupted, like every skill")
	run(core, 20)
	assert_eq(core.lanterns.size(), 0, "no lantern")
	assert_near(core.player.edge, 100.0 - Tuning.SPIRIT_LANTERN_EDGE_COST, 0.001, "the Edge is gone (no refund, like every skill)")
	assert_eq(int(core.player.aspect_cooldowns.get(Aspects.SPIRIT_LANTERN, 0)), 0, "no cooldown spent: it can be tried again")
	core.player.edge = 100.0
	assert_true(_place(core) > 0, "and placed on the retry")
