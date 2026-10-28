extends "res://tests/test_case.gd"
## Stat points and Sprint in exploration (core/explore_core.gd, Tuning stat constants, docs/PROGRESSION_PLAN.md option B): 2 points a level,
## three modest stats with caps, effects on health, damage, dash cooldown and walking speed, spending and the free respec in the village, the
## save keeping the spent points, Sprint usable once it is owned, socketed and unlocked (Edge refills on the road), nothing else.

const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const Aspects := preload("res://core/aspects.gd")


func _frame(spend: StringName = &"", respec: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.spend_stat = spend
	f.respec_stats = respec
	return f


func _hero(level_exp: int, scene: StringName = SceneDefs.VILLAGE_LAYERED) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(scene)
	core.set_story_flags([&"debug_all_unlocked"] as Array[StringName])
	core.set_exp(level_exp)
	return core


func _types(core: ExploreCore) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: GameEvent in core.last_events:
		out.append(e.type)
	return out


func test_points_come_two_per_level_from_level_two() -> void:
	var core: ExploreCore = _hero(0)
	assert_eq([core.stat_points_total(), core.stat_points_unspent()], [0, 0], "level 1 has none")
	core.set_exp(30)
	assert_eq([core.level(), core.stat_points_total()], [2, 2])
	core.set_exp(280)
	assert_eq([core.level(), core.stat_points_total()], [5, 8], "level 5, where Chapter 1 ends: 8 points")
	core.set_exp(99999)
	assert_eq([core.level(), core.stat_points_total()], [10, 18])
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_eq([snap.stat_points_unspent, snap.stats, snap.stat_caps], [18, {&"vitality": 0, &"might": 0, &"agility": 0}, {&"vitality": 10, &"might": 10, &"agility": 10}])


func test_each_stat_does_its_one_thing() -> void:
	var core: ExploreCore = _hero(280)  # level 5, 8 points, base health 100 + 4 x 5
	assert_eq(core.hero_max_hp(), 120)
	assert_true(is_equal_approx(core.damage_mult(), 1.0))
	core.set_stats({&"vitality": 3, &"might": 3, &"agility": 2})
	assert_eq(core.hero_max_hp(), 120 + 18, "Vitality: +6 health a point")
	assert_true(is_equal_approx(core.damage_mult(), 1.09), "Might: +3 % damage a point")
	assert_eq(core.player.dash_cooldown_bonus, 4, "Agility: -2 ticks of dash cooldown a point")
	assert_true(is_equal_approx(core.player.move_speed_mult(), 1.01), "and +0.5 % walking speed")
	var dash: InputFrame = InputFrame.new()
	dash.dash_pressed = true
	dash.move = Vector2.RIGHT
	core.step(dash)
	assert_eq(core.player.dash_cooldown, Tuning.DASH_COOLDOWN_TICKS - 4, "the dash comes back sooner")
	assert_eq(core.snapshot().hero.max_hp, 138)
	# the dash part of Agility stops at 6 points
	core.set_exp(99999)
	core.set_stats({&"agility": 9})
	assert_eq(core.player.dash_cooldown_bonus, 12, "no more than 6 points shorten the dash")


func test_spending_a_point_is_an_intent_with_limits() -> void:
	var core: ExploreCore = _hero(30)  # level 2: 2 points
	core.step(_frame(&"vitality"))
	var ev: GameEvent = core.last_events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.STAT_SPENT)[0]
	assert_true(ev.data["stat"] == &"vitality" and ev.data["value"] == 1 and ev.data["unspent"] == 1 and ev.data["max_hp"] == 105 + 6, str(ev.data))
	assert_eq(core.player.hp, 105 + 6, "a point of Vitality is health at once")
	core.step(_frame(&"might"))
	assert_eq(core.stat_points_unspent(), 0)
	core.step(_frame(&"might"))
	assert_false(_types(core).has(GameEvent.STAT_SPENT), "no point left: nothing")
	assert_eq(core.stats[&"might"], 1)
	core.step(_frame(&"luck"))
	assert_false(_types(core).has(GameEvent.STAT_SPENT), "an unknown stat is refused")
	var capped: ExploreCore = _hero(99999)
	for i: int in 12:
		capped.step(_frame(&"agility"))
	assert_eq(capped.stats[&"agility"], 10, "a stat stops at its cap")
	assert_eq(capped.stat_points_unspent(), 8)


func test_the_respec_is_free_but_only_in_the_village() -> void:
	var core: ExploreCore = _hero(280)
	core.set_stats({&"vitality": 4, &"might": 4})
	core.step(_frame(&"", true))
	assert_true(_types(core).has(GameEvent.STATS_RESET))
	assert_eq([core.stats[&"vitality"], core.stats[&"might"], core.stat_points_unspent()], [0, 0, 8])
	assert_true(core.player.hp <= core.hero_max_hp())
	var forest: ExploreCore = _hero(280, SceneDefs.FOREST_LAYERED)
	forest.set_stats({&"vitality": 4})
	forest.step(_frame(&"", true))
	assert_false(_types(forest).has(GameEvent.STATS_RESET))
	assert_eq(forest.stats[&"vitality"], 4, "no respec on the road")
	core.step(_frame(&"", true))
	assert_false(_types(core).has(GameEvent.STATS_RESET), "nothing to take back")


func test_loading_clamps_spent_points_to_what_the_level_allows() -> void:
	var core: ExploreCore = _hero(30)  # 2 points
	core.set_stats({&"vitality": 9, &"might": 9, &"agility": 9})
	assert_eq(core.stat_points_spent(), 2, "a damaged save cannot hand out points")
	core.set_stats({&"vitality": 99})
	assert_eq(core.stats[&"vitality"], 2)
	core.set_stats({"might": 1})
	assert_eq(core.stats[&"might"], 1, "string keys from the file work")
	assert_eq(core.player.hp, core.hero_max_hp(), "he starts the scene at full health")


func test_the_save_keeps_the_spent_points() -> void:
	var p: SaveProfile = SaveProfile.new()
	assert_eq(p.stats, {})
	p.stats = {&"vitality": 3, &"might": 1}
	var back: SaveProfile = SaveProfile.from_json(p.to_json()) as SaveProfile
	assert_eq(back.stats, {&"vitality": 3, &"might": 1})
	assert_eq(back.to_json(), p.to_json(), "stable output")
	back.reset_progress()
	assert_eq(back.stats, {}, "NEW GAME gives the points back")
	var messy: SaveProfile = SaveProfile.from_json("{\"version\": 1, \"stats\": {\"vitality\": 99, \"might\": -2, \"agility\": \"x\", \"luck\": 5}}") as SaveProfile
	assert_eq(messy.stats, {&"vitality": 10}, "capped, bad entries dropped")
	assert_eq((SaveProfile.from_json("{\"version\": 1}") as SaveProfile).stats, {}, "an older save has none")


## A hero in the woodland who owns Sprint, has it in socket 1 and has finished Edda's lesson.
func _runner(owned: bool = true, socketed: bool = true, lesson: bool = true) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SceneDefs.WOODLAND_LAYERED)
	var flags: Array[StringName] = []
	if owned:
		flags.append(&"aspect_owned_sprint")
	if lesson:
		flags.append(&"lesson_aspect")
	core.set_story_flags(flags)
	var slots: Array[StringName] = []
	if socketed:
		slots.append_array([Aspects.SPRINT, Aspects.GALE_CUT, Aspects.MOON_CLEAVE])
	else:
		slots.append_array(Aspects.DEFAULT_EQUIPPED)
	core.set_loadout(Tuning.WEAPON_BLACK_KATANA, slots)
	return core


func _press_skill(core: ExploreCore, slot: int) -> void:
	var f: InputFrame = InputFrame.new()
	f.skill_pressed = slot
	core.step(f)


func test_sprint_works_on_the_road_once_it_is_owned_socketed_and_unlocked() -> void:
	var core: ExploreCore = _runner()
	assert_true(core.snapshot().aspect_slots[0]["unlocked"] and core.snapshot().aspect_slots[0]["usable"], "socket 1 opens with Edda's lesson")
	assert_false(core.snapshot().aspect_slots[1]["unlocked"], "socket 2 is still locked")
	assert_true(core.snapshot().unlocked["aspect_socket_1"])
	for i: int in 100:
		core.step(InputFrame.new())  # Edge fills on the road
	assert_true(core.player.edge >= Aspects.edge_cost(Aspects.SPRINT))
	_press_skill(core, 1)
	assert_true(_types(core).has(GameEvent.SPRINT_STARTED), "sprint_started")
	assert_true(core.player.sprint_ticks_left > 0)
	var start: Vector2 = core.player.position
	var walk: InputFrame = InputFrame.new()
	walk.move = Vector2.RIGHT
	for i: int in 30:
		core.step(walk)
	assert_true(core.player.position.x - start.x > 30.0 * Tuning.PLAYER_SPEED * 1.8, "he walks about twice as fast (%.1f px)" % (core.player.position.x - start.x))
	_press_skill(core, 1)
	assert_false(_types(core).has(GameEvent.SPRINT_STARTED), "not again while it runs or cools down")


func test_sprint_needs_all_three_conditions() -> void:
	for combo: Array in [[false, true, true], [true, false, true], [true, true, false]]:
		var core: ExploreCore = _runner(combo[0], combo[1], combo[2])
		for i: int in 100:
			core.step(InputFrame.new())
		_press_skill(core, 1)
		assert_false(_types(core).has(GameEvent.SPRINT_STARTED), "not owned / not socketed / lesson not done: %s" % str(combo))
		assert_eq(core.player.sprint_ticks_left, 0)


func test_the_other_aspects_stay_out_of_exploration() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.WOODLAND_LAYERED)
	core.set_story_flags([&"lesson_aspect", &"unlocked_aspect_slot_2", &"unlocked_aspect_slot_3"] as Array[StringName])
	var defaults: Array[StringName] = []
	defaults.append_array(Aspects.DEFAULT_EQUIPPED)
	core.set_loadout(Tuning.WEAPON_BLACK_KATANA, defaults)
	for i: int in 200:
		core.step(InputFrame.new())
	for slot: int in [1, 2, 3]:
		_press_skill(core, slot)
		assert_false(_types(core).has(GameEvent.SKILL_STARTED), "slot %d: Breaking Edge, Gale Cut and Moon Cleave need the boss" % slot)
	assert_false(core.snapshot().aspect_slots[0]["usable"])


func test_the_snapshot_lists_the_owned_aspects_and_the_loadout_is_checked() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	assert_eq(core.snapshot().owned_aspects, [] as Array[StringName], "a new hero owns none")
	core.set_story_flags([&"aspect_owned_sprint"] as Array[StringName])
	assert_eq(core.snapshot().owned_aspects, [Aspects.SPRINT] as Array[StringName])
	core.set_loadout(&"banana", [&"x", &"y", &"z"] as Array[StringName])
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "a bad weapon is ignored")
	assert_eq(core.player.equipped_aspects, Aspects.DEFAULT_EQUIPPED, "so is a bad loadout")
	core.set_loadout(Tuning.WEAPON_DUAL_DAGGER, [Aspects.SPRINT, Aspects.GALE_CUT, Aspects.MOON_CLEAVE] as Array[StringName])
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	assert_eq(core.snapshot().hero.equipped_aspects[0], Aspects.SPRINT)


func test_edge_only_refills_while_no_fight_is_on() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.WOODLAND_LAYERED)
	core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"] as Array[StringName])
	core.place_at(Vector2(150, 285))  # beside the Mosslings: they wake
	for i: int in 30:
		core.step(InputFrame.new())
	assert_true(core.mobs.is_engaged())
	var edge: float = core.player.edge
	core.player.hp = core.hero_max_hp()
	for i: int in 30:
		core.step(InputFrame.new())
		core.player.hp = core.hero_max_hp()
	assert_true(core.player.edge <= edge + 0.001, "no free Edge in a fight")
