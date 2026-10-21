extends "res://tests/test_case.gd"
## InputFrame.weapon_equip (2026-10-21): the character menu equips a weapon by id. Same rules as the old Q swap: idle or
## walk only, never while an active runs, after the swap lockout; the current weapon and unknown ids are no-ops.

const Weapons := preload("res://core/weapons.gd")

const BOSS_AT: Vector2 = Vector2(400.0, 240.0)


## A pinned boss far away in an open field, full Edge.
func _core() -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = BOSS_AT
	core.player.position = BOSS_AT + Vector2(-100.0, 0.0)
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	return core


func _equip(weapon: StringName, move: Vector2 = Vector2.ZERO) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_equip = weapon
	frame.move = move
	return frame


func _swapped(core: GameCore) -> int:
	return event_types(core).count(GameEvent.WEAPON_SWAPPED)


func test_equip_picks_exactly_the_requested_weapon() -> void:
	var core: GameCore = _core()
	core.step(_equip(Tuning.WEAPON_CHAIN_SCYTHE))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_CHAIN_SCYTHE, "katana -> scythe directly (no cycle)")
	var event: GameEvent = find_event(core, GameEvent.WEAPON_SWAPPED)
	assert_true(event != null, "weapon_swapped emitted")
	if event != null:
		assert_eq(event.data["weapon_id"], Tuning.WEAPON_CHAIN_SCYTHE)
		assert_eq(event.data["previous_weapon_id"], Tuning.WEAPON_BLACK_KATANA)
		assert_eq(event.data["entity_id"], core.player.id)
	assert_eq(core.snapshot().player.weapon_id, Tuning.WEAPON_CHAIN_SCYTHE)
	assert_eq(core.snapshot().player.combo_max, Tuning.SCYTHE_COMBO_MAX)
	assert_eq(core.player.swap_lockout, Tuning.WEAPON_SWAP_LOCKOUT_TICKS, "the lockout starts")
	run(core, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	core.step(_equip(Tuning.WEAPON_DUAL_DAGGER))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	run(core, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	core.step(_equip(Tuning.WEAPON_BLACK_KATANA))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA)


func test_equipping_the_current_weapon_is_a_no_op() -> void:
	var core: GameCore = _core()
	core.step(_equip(Tuning.WEAPON_BLACK_KATANA))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA)
	assert_eq(_swapped(core), 0, "no event")
	assert_eq(core.player.swap_lockout, 0, "no lockout")
	core.step(_equip(Tuning.WEAPON_DUAL_DAGGER))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER, "and a real equip right after still works")


func test_an_unknown_or_empty_id_is_refused() -> void:
	var core: GameCore = _core()
	for weapon: StringName in [&"bow", &"BLACK_KATANA", &""]:
		core.step(_equip(weapon))
		assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "refused: " + String(weapon))
		assert_eq(_swapped(core), 0)
		assert_eq(core.player.swap_lockout, 0)


func test_there_is_no_swap_lockout_so_the_menu_can_equip_repeatedly() -> void:
	assert_eq(Tuning.WEAPON_SWAP_LOCKOUT_TICKS, 0, "the menu is paused, so there is no lockout")
	var core: GameCore = _core()
	core.step(_equip(Tuning.WEAPON_DUAL_DAGGER))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	core.step(_equip(Tuning.WEAPON_CHAIN_SCYTHE))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_CHAIN_SCYTHE, "a second equip works on the very next tick")
	core.step(_equip(Tuning.WEAPON_BLACK_KATANA))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "and a third")


func test_equip_works_while_walking_but_not_when_busy() -> void:
	var walking: GameCore = _core()
	walking.step(input(Vector2.UP))
	walking.step(_equip(Tuning.WEAPON_CHAIN_SCYTHE, Vector2.UP))
	assert_eq(walking.player.weapon_id, Tuning.WEAPON_CHAIN_SCYTHE, "walking: allowed")
	for setup: String in ["attack", "dash", "parry", "skill", "dead", "buff"]:
		var core: GameCore = _core()
		match setup:
			"attack":
				core.step(input(Vector2.ZERO, false, false, true))
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
			"buff":
				var active: InputFrame = InputFrame.new()
				active.weapon_active_pressed = true
				core.step(active)
				assert_true(core.player.is_buff_active())
		var state_before: StringName = core.player.state
		var hp_before: int = core.player.hp
		var edge_before: float = core.player.edge
		core.step(_equip(Tuning.WEAPON_DUAL_DAGGER))
		assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "no equip during " + setup)
		assert_eq(_swapped(core), 0, "no event during " + setup)
		assert_eq(core.player.swap_lockout, 0, "no lockout from a refused equip: " + setup)
		assert_eq(core.player.hp, hp_before, "nothing else changes: " + setup)
		assert_near(core.player.edge, edge_before, 0.0001, "Edge unchanged: " + setup)
		if setup != "dead" and setup != "buff":
			assert_true(String(core.player.state).begins_with(String(state_before).get_slice("_", 0)), "the action goes on: " + setup)


func test_equip_is_refused_during_the_barrage_and_the_coil() -> void:
	for weapon: StringName in [Tuning.WEAPON_DUAL_DAGGER, Tuning.WEAPON_CHAIN_SCYTHE]:
		var core: GameCore = _core()
		core.player.weapon_id = weapon
		core.player.position = BOSS_AT + Vector2(-60.0, 0.0)
		var active: InputFrame = InputFrame.new()
		active.weapon_active_pressed = true
		active.aim = Vector2.RIGHT
		core.step(active)
		assert_true(core.player.is_buff_active(), "the active runs: " + String(weapon))
		var guard: int = 0
		while core.player.is_buff_active() and guard < 300:
			core.step(_equip(Tuning.WEAPON_BLACK_KATANA))
			if core.player.is_buff_active():
				assert_eq(core.player.weapon_id, weapon, "no equip while the active runs (%s, tick %d)" % [weapon, core.tick])
			guard += 1
		run(core, 30)
		core.step(_equip(Tuning.WEAPON_BLACK_KATANA))
		assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "allowed once it is over: " + String(weapon))


func test_each_weapon_keeps_its_own_active_cooldown_across_equips() -> void:
	var core: GameCore = _core()
	core.step(_equip(Tuning.WEAPON_DUAL_DAGGER))
	run(core, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	core.player.position = BOSS_AT + Vector2(-60.0, 0.0)
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	core.step(active)
	var guard: int = 0
	while core.player.is_buff_active() and guard < 300:
		core.step(InputFrame.new())
		guard += 1
	var dagger_left: int = int(core.player.active_cooldowns.get(Tuning.WEAPON_DUAL_DAGGER, 0))
	assert_true(dagger_left > 0, "the dagger's cooldown runs")
	run(core, Tuning.WEAPON_SWAP_LOCKOUT_TICKS)
	core.step(_equip(Tuning.WEAPON_CHAIN_SCYTHE))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_CHAIN_SCYTHE)
	assert_eq(int(core.player.active_cooldowns.get(Tuning.WEAPON_CHAIN_SCYTHE, 0)), 0, "the scythe's own cooldown is untouched")
	run(core, 30)
	var expected: int = dagger_left - Tuning.WEAPON_SWAP_LOCKOUT_TICKS - 1 - 30
	assert_eq(int(core.player.active_cooldowns.get(Tuning.WEAPON_DUAL_DAGGER, 0)), expected, "the dagger's cooldown kept counting down while put away")
	core.step(_equip(Tuning.WEAPON_DUAL_DAGGER))
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	assert_eq(core.snapshot().hud.weapon_buff_cooldown_ticks, expected - 1, "equipping it back shows the same cooldown, not a reset")
