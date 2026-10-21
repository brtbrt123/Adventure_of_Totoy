extends "res://tests/test_case.gd"
## Equippable aspects (2026-10-21): the player owns Aspects.ALL and slots three of them into Z/X/C
## (InputFrame.aspect_equip + aspect_equip_slot). Cooldowns belong to the aspect, not to the slot.

const Aspects := preload("res://core/aspects.gd")
const SaveProfile := preload("res://core/save_profile.gd")

const BOSS_AT: Vector2 = Vector2(600.0, 240.0)


## A pinned boss far away in an open field, full Edge.
func _core() -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = BOSS_AT
	core.player.position = Vector2(200.0, 240.0)
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	return core


## Step with idle input until core.tick == target, but never past the end of the fight (a finished fight no longer
## advances core.tick, so the shared run_to_tick would never return if a broken rule ended it early).
func _to(core: GameCore, target: int) -> void:
	while core.tick < target and core.result == GameCore.RESULT_PLAYING:
		core.step(InputFrame.new())


func _equip_frame(aspect: StringName, slot: int, move: Vector2 = Vector2.ZERO) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.aspect_equip = aspect
	frame.aspect_equip_slot = slot
	frame.move = move
	return frame


func _equip(core: GameCore, aspect: StringName, slot: int) -> void:
	core.step(_equip_frame(aspect, slot))


func _press(core: GameCore, slot: int, move: Vector2 = Vector2.ZERO) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = slot
	frame.move = move
	core.step(frame)


func _equipped_events(core: GameCore) -> int:
	return event_types(core).count(GameEvent.ASPECT_EQUIPPED)


func test_the_default_slotting_is_the_old_fixed_set() -> void:
	var core: GameCore = _core()
	assert_eq(core.player.equipped_aspects, [Aspects.BREAKING_EDGE, Aspects.GALE_CUT, Aspects.MOON_CLEAVE] as Array[StringName])
	assert_eq(PlayerState.SKILL_IDS, core.player.equipped_aspects, "SKILL_IDS stays the default slotting")
	assert_eq(core.player.skill_cooldowns, [0, 0, 0] as Array[int])
	assert_eq(Aspects.ALL.size(), 5)
	var hud = core.snapshot().hud
	assert_eq(hud.equipped_aspects, core.player.equipped_aspects)
	assert_eq(hud.aspect_slots.size(), 3)
	assert_eq(hud.aspect_slots[1]["aspect_id"], Aspects.GALE_CUT)
	assert_eq(hud.aspect_slots[1]["edge_cost"], Tuning.GALE_CUT_EDGE_COST)
	assert_eq(hud.aspect_slots[1]["cooldown_max"], Tuning.GALE_CUT_COOLDOWN_TICKS)
	assert_eq(hud.aspect_slots[0]["needs_retaliation"], true)
	assert_eq(hud.aspect_cooldowns.size(), Aspects.ALL.size(), "every aspect is listed")
	_press(core, 2, Vector2.UP)
	assert_eq(core.player.skill_id, Aspects.GALE_CUT, "X is still Gale Cut")
	assert_eq(core.player.skill_cooldowns[1], Tuning.GALE_CUT_COOLDOWN_TICKS)
	assert_eq(core.snapshot().hud.skill_cooldown_ticks[1], Tuning.GALE_CUT_COOLDOWN_TICKS, "the old HUD array still works")
	assert_eq(core.snapshot().hud.aspect_slots[1]["running"], true)
	assert_eq(core.snapshot().player.equipped_aspects, core.player.equipped_aspects)


func test_equip_puts_the_aspect_into_the_slot() -> void:
	var core: GameCore = _core()
	_equip(core, Aspects.SPIRIT_LANTERN, 2)
	assert_eq(core.player.equipped_aspects, [Aspects.BREAKING_EDGE, Aspects.SPIRIT_LANTERN, Aspects.MOON_CLEAVE] as Array[StringName])
	var event: GameEvent = find_event(core, GameEvent.ASPECT_EQUIPPED)
	assert_true(event != null, "aspect_equipped emitted")
	if event != null:
		assert_eq(event.data["entity_id"], core.player.id)
		assert_eq(event.data["slot"], 2)
		assert_eq(event.data["aspect_id"], Aspects.SPIRIT_LANTERN)
		assert_eq(event.data["previous"], Aspects.GALE_CUT)
		assert_eq(event.data["swapped_slot"], 0, "it came from the pool")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "a free action")
	assert_eq(core.player.swap_lockout, 0, "no lockout")
	_equip(core, Aspects.PHANTOM_CUT, 3)
	assert_eq(core.player.equipped_aspects, [Aspects.BREAKING_EDGE, Aspects.SPIRIT_LANTERN, Aspects.PHANTOM_CUT] as Array[StringName], "and on the very next tick")


func test_equipping_an_aspect_slotted_elsewhere_swaps_the_two_slots() -> void:
	var core: GameCore = _core()
	_equip(core, Aspects.MOON_CLEAVE, 1)
	assert_eq(core.player.equipped_aspects, [Aspects.MOON_CLEAVE, Aspects.GALE_CUT, Aspects.BREAKING_EDGE] as Array[StringName])
	var event: GameEvent = find_event(core, GameEvent.ASPECT_EQUIPPED)
	assert_true(event != null)
	if event != null:
		assert_eq(event.data["slot"], 1)
		assert_eq(event.data["aspect_id"], Aspects.MOON_CLEAVE)
		assert_eq(event.data["previous"], Aspects.BREAKING_EDGE)
		assert_eq(event.data["swapped_slot"], 3)
	assert_eq(_equipped_events(core), 1, "one event for the swap")


func test_the_same_aspect_in_its_own_slot_an_unknown_id_or_a_bad_slot_is_a_no_op() -> void:
	var core: GameCore = _core()
	var before: Array[StringName] = core.player.equipped_aspects.duplicate()
	for request: Array in [[Aspects.GALE_CUT, 2], [&"fire_ball", 1], [&"GALE_CUT", 1], [Aspects.SPIRIT_LANTERN, 0], [Aspects.SPIRIT_LANTERN, 4], [Aspects.SPIRIT_LANTERN, -1]]:
		_equip(core, request[0], request[1])
		assert_eq(core.player.equipped_aspects, before, "refused: %s into %d" % [request[0], request[1]])
		assert_eq(_equipped_events(core), 0, "no event: %s" % request[0])
	var empty: InputFrame = _equip_frame(&"", 1)
	core.step(empty)
	assert_eq(core.player.equipped_aspects, before, "an empty id is no request")


func test_equip_works_while_walking_but_not_when_busy() -> void:
	var walking: GameCore = _core()
	walking.step(input(Vector2.UP))
	walking.step(_equip_frame(Aspects.PHANTOM_CUT, 1, Vector2.UP))
	assert_eq(walking.player.equipped_aspects[0], Aspects.PHANTOM_CUT, "walking: allowed")
	for setup: String in ["attack", "dash", "parry", "skill", "dead", "katana_buff", "barrage", "coil"]:
		var core: GameCore = _core()
		match setup:
			"attack":
				core.step(input(Vector2.ZERO, false, false, true))
			"dash":
				core.step(input(Vector2.UP, true))
			"parry":
				core.step(input(Vector2.ZERO, false, true))
			"skill":
				_press(core, 2, Vector2.UP)
			"dead":
				var events: Array[GameEvent] = []
				core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
			"katana_buff", "barrage", "coil":
				if setup == "barrage":
					core.player.weapon_id = Tuning.WEAPON_DUAL_DAGGER
				elif setup == "coil":
					core.player.weapon_id = Tuning.WEAPON_CHAIN_SCYTHE
				var active: InputFrame = InputFrame.new()
				active.weapon_active_pressed = true
				active.aim = Vector2.RIGHT
				core.step(active)
				assert_true(core.player.is_buff_active(), "the active runs: " + setup)
		var before: Array[StringName] = core.player.equipped_aspects.duplicate()
		var state_before: StringName = core.player.state
		core.step(_equip_frame(Aspects.SPIRIT_LANTERN, 1))
		assert_eq(core.player.equipped_aspects, before, "no equip during " + setup)
		assert_eq(_equipped_events(core), 0, "no event during " + setup)
		if setup in ["attack", "dash", "parry", "skill"]:
			assert_true(String(core.player.state).begins_with(String(state_before).get_slice("_", 0)), "the action goes on: " + setup)


func test_a_running_phantom_cut_or_a_lantern_does_not_block_equipping() -> void:
	var core: GameCore = _core()
	_equip(core, Aspects.PHANTOM_CUT, 3)
	_press(core, 3)
	assert_true(core.player.phantom_ticks_left > 0, "Phantom Cut runs")
	_equip(core, Aspects.SPIRIT_LANTERN, 2)
	assert_eq(core.player.equipped_aspects[1], Aspects.SPIRIT_LANTERN, "allowed while Phantom Cut runs")
	_press(core, 2)
	run(core, Tuning.SPIRIT_LANTERN_WINDUP_TICKS + Tuning.SPIRIT_LANTERN_ACTIVE_TICKS + Tuning.SPIRIT_LANTERN_RECOVERY_TICKS)
	assert_eq(core.lanterns.size(), 1, "a lantern stands")
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	_equip(core, Aspects.GALE_CUT, 2)
	assert_eq(core.player.equipped_aspects[1], Aspects.GALE_CUT, "allowed while a lantern stands")
	assert_eq(core.lanterns.size(), 1, "un-slotting the lantern does not remove the placed one")
	assert_true(core.player.phantom_ticks_left > 0, "nor does it stop Phantom Cut")
	_equip(core, Aspects.BREAKING_EDGE, 3)
	assert_true(core.player.phantom_ticks_left > 0, "un-slotting Phantom Cut keeps the running buff")


func test_cooldowns_belong_to_the_aspect_and_survive_re_slotting() -> void:
	var core: GameCore = _core()
	_press(core, 2, Vector2.UP)  # Gale Cut from slot 2
	run(core, Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS + Tuning.GALE_CUT_RECOVERY_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	var left: int = int(core.player.aspect_cooldowns[Aspects.GALE_CUT])
	assert_true(left > 0, "Gale Cut cools down")
	_equip(core, Aspects.SPIRIT_LANTERN, 2)  # Gale Cut leaves the slots
	assert_eq(core.player.skill_cooldowns[1], 0, "the lantern in slot 2 is ready")
	run(core, 10)
	assert_eq(int(core.player.aspect_cooldowns[Aspects.GALE_CUT]), left - 11, "it kept counting while un-slotted")
	_equip(core, Aspects.GALE_CUT, 3)
	assert_eq(core.player.skill_cooldowns[2], left - 12, "back in slot 3 with the same cooldown, not a reset")
	assert_eq(core.snapshot().hud.skill_cooldown_ticks[2], left - 12)
	assert_eq(core.snapshot().hud.aspect_slots[2]["cooldown_ticks"], left - 12)
	core.player.edge = 100.0
	_press(core, 3, Vector2.UP)
	assert_false(String(core.player.state).begins_with("skill_"), "still cooling down in its new slot")
	_equip(core, Aspects.GALE_CUT, 1)  # swap slots 1 and 3 while it cools
	assert_eq(core.player.skill_cooldowns[0], left - 14, "a swap moves the cooldown with the aspect")
	_to(core, core.tick + left - 14)
	assert_eq(core.player.skill_cooldowns[0], 0, "ready on time")
	_press(core, 1, Vector2.UP)
	assert_eq(core.player.skill_id, Aspects.GALE_CUT, "and usable from slot 1")


func test_skill_pressed_triggers_the_aspect_in_that_slot() -> void:
	var core: GameCore = _core()
	_equip(core, Aspects.MOON_CLEAVE, 1)  # [moon, gale, breaking]
	_press(core, 1)
	assert_eq(core.player.skill_id, Aspects.MOON_CLEAVE, "Z now holds Moon Cleave")
	assert_near(core.player.edge, 100.0 - Tuning.MOON_CLEAVE_EDGE_COST, 0.001)
	var be: GameCore = _core()
	_equip(be, Aspects.BREAKING_EDGE, 3)  # [moon, gale, breaking]
	_press(be, 3)
	assert_eq(be.player.state, PlayerState.STATE_IDLE, "Breaking Edge still needs the retaliation window in slot 3")
	_press(be, 1)
	assert_eq(be.player.skill_id, Aspects.MOON_CLEAVE)
	var parried: GameCore = _core()
	_equip(parried, Aspects.BREAKING_EDGE, 3)
	parried.player.on_parry_success(Vector2.ZERO)
	_press(parried, 3)
	assert_eq(parried.player.skill_id, Aspects.BREAKING_EDGE, "after a parry it works from slot 3")


func test_the_snapshot_rows_follow_the_slots() -> void:
	var core: GameCore = _core()
	_equip(core, Aspects.PHANTOM_CUT, 1)
	_equip(core, Aspects.SPIRIT_LANTERN, 2)
	var rows: Array[Dictionary] = core.snapshot().hud.aspect_slots
	assert_eq(rows[0]["aspect_id"], Aspects.PHANTOM_CUT)
	assert_eq(rows[0]["kind"], Aspects.KIND_BUFF)
	assert_eq(rows[0]["edge_cost"], Tuning.PHANTOM_CUT_EDGE_COST)
	assert_eq(rows[0]["cooldown_max"], Tuning.PHANTOM_CUT_COOLDOWN_TICKS)
	assert_eq(rows[0]["duration"], Tuning.PHANTOM_CUT_DURATION_TICKS)
	assert_eq(rows[0]["name"], "Phantom Cut")
	assert_eq(rows[1]["aspect_id"], Aspects.SPIRIT_LANTERN)
	assert_eq(rows[1]["kind"], Aspects.KIND_SKILL)
	assert_eq(rows[1]["running"], false)
	_press(core, 1)
	rows = core.snapshot().hud.aspect_slots
	assert_eq(rows[0]["running"], true)
	assert_eq(rows[0]["ticks_left"], Tuning.PHANTOM_CUT_DURATION_TICKS)
	assert_eq(rows[0]["cooldown_ticks"], Tuning.PHANTOM_CUT_COOLDOWN_TICKS)
	assert_eq(core.snapshot().hud.phantom_ticks_left, Tuning.PHANTOM_CUT_DURATION_TICKS)
	_press(core, 2)
	run(core, Tuning.SPIRIT_LANTERN_WINDUP_TICKS)
	rows = core.snapshot().hud.aspect_slots
	assert_eq(rows[1]["running"], true, "the lantern stands")
	assert_eq(rows[1]["ticks_left"], Tuning.SPIRIT_LANTERN_DURATION_TICKS)
	assert_eq(rows[1]["cooldown_ticks"], Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS)


func test_the_save_keeps_the_equipped_aspects_and_the_fight_reads_them() -> void:
	var p: SaveProfile = SaveProfile.new()
	assert_eq(p.equipped_aspects, Aspects.DEFAULT_EQUIPPED, "a new profile has the default slots")
	p.equipped_aspects = [Aspects.PHANTOM_CUT, Aspects.GALE_CUT, Aspects.SPIRIT_LANTERN] as Array[StringName]
	p.weapon_id = Tuning.WEAPON_CHAIN_SCYTHE
	var back: SaveProfile = SaveProfile.from_json(p.to_json()) as SaveProfile
	assert_eq(back.load_note, "")
	assert_eq(back.equipped_aspects, p.equipped_aspects, "round trip")
	assert_eq(back.weapon_id, Tuning.WEAPON_CHAIN_SCYTHE)
	assert_eq(back.to_json(), p.to_json(), "stable output")
	var core: GameCore = _core()
	core.apply_profile(back)
	assert_eq(core.player.equipped_aspects, p.equipped_aspects, "the fight starts with the saved slots")
	assert_eq(core.player.weapon_id, Tuning.WEAPON_CHAIN_SCYTHE, "and the saved weapon")
	_press(core, 1)
	assert_true(core.player.phantom_ticks_left > 0, "Z is Phantom Cut")


func test_old_or_broken_saves_fall_back_to_the_default_slots() -> void:
	var old: SaveProfile = SaveProfile.from_json("{\"version\": 1, \"victories\": 2, \"weapon_id\": \"dual_dagger\"}") as SaveProfile
	assert_eq(old.load_note, "", "an old save still loads")
	assert_eq(old.victories, 2)
	assert_eq(old.equipped_aspects, Aspects.DEFAULT_EQUIPPED, "no field: the defaults")
	for bad: String in ["\"gale_cut\"", "[]", "[\"gale_cut\", \"gale_cut\", \"moon_cleave\"]", "[\"gale_cut\", \"moon_cleave\"]", "[\"gale_cut\", \"moon_cleave\", \"fire\"]", "[1, 2, 3]", "[\"gale_cut\", \"moon_cleave\", \"phantom_cut\", \"spirit_lantern\"]"]:
		var p: SaveProfile = SaveProfile.from_json("{\"version\": 1, \"equipped_aspects\": %s}" % bad) as SaveProfile
		assert_eq(p.load_note, "", "still readable: " + bad)
		assert_eq(p.equipped_aspects, Aspects.DEFAULT_EQUIPPED, "invalid list falls back: " + bad)
	var core: GameCore = _core()
	var broken: SaveProfile = SaveProfile.new()
	broken.equipped_aspects = [Aspects.GALE_CUT, Aspects.GALE_CUT, Aspects.GALE_CUT] as Array[StringName]
	broken.weapon_id = &"axe"
	core.apply_profile(broken)
	assert_eq(core.player.equipped_aspects, Aspects.DEFAULT_EQUIPPED, "the fight ignores an invalid loadout")
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "and an unknown weapon")
