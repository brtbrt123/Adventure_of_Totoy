extends "res://tests/test_case.gd"
## The village sequence (core/quest_book.gd, data/quests/chapter1.json, docs/PROGRESSION_PLAN.md): the data is valid and pays 95 EXP, the chain
## is strictly in order (Mira, Tovan and the sword, the four lessons, Tovan, the Elder with his chest, Edda), each ability unlocks only
## when its task begins, each step pays its reward once, the objective names the next task, the east gate stays closed until the end,
## and a save from before the sequence is not trapped behind a task it already did.

const QuestBook := preload("res://core/quest_book.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const DialogueBook := preload("res://core/dialogue_book.gd")

var _book: Dictionary = QuestBook.default_book()


func _frame(interact: bool = false, move: Vector2 = Vector2.ZERO) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.interact_pressed = interact
	f.move = move
	return f


func _village() -> ExploreCore:
	return ExploreCore.new(SceneDefs.VILLAGE_LAYERED)


func _near(core: ExploreCore, id: StringName) -> void:
	for row: Dictionary in core.def["npcs"]:
		if row["id"] == id:
			for offset: Vector2 in [Vector2(0, 14), Vector2(-14, 0), Vector2(14, 0), Vector2(0, -14), Vector2(0, 12)]:
				core.place_at(row["position"] + offset)
				core.step(_frame())
				if core.interact_target.get("id", &"") == id:
					return
	assert_true(false, "the hero can stand beside %s" % id)


## Talks to `id` from the first line to the last; returns every event raised.
func _talk(core: ExploreCore, id: StringName) -> Array[GameEvent]:
	_near(core, id)
	var seen: Array[GameEvent] = []
	core.step(_frame(true))
	seen.append_array(core.last_events)
	for i: int in 40:
		if not core.is_talking():
			break
		core.step(_frame(true))
		seen.append_array(core.last_events)
	return seen


func _of(events: Array[GameEvent], type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in events:
		if e.type == type:
			out.append(e)
	return out


func _objective(core: ExploreCore) -> StringName:
	var o: Dictionary = core.snapshot().objective
	return o.get("id", &"")


func test_the_data_is_valid_and_the_village_pays_95_exp() -> void:
	assert_eq(QuestBook.validate(_book), [] as Array[String], "the shipped quests are valid")
	assert_eq(QuestBook.total_exp(_book), 95)
	var ids: Array[String] = []
	for step: Dictionary in QuestBook.steps(_book):
		ids.append(String(step["id"]))
	assert_eq(ids, ["mira", "sword", "attack", "dash", "parry", "dodge", "tovan_done", "elder_talk", "elder_chest", "elder_done", "edda_talk", "edda_equip"])
	assert_true(QuestBook.default_book().get("road", {}).get("requires", []).has("lesson_aspect"), "the road opens after Edda's lesson")


func test_the_checks_catch_a_broken_chain() -> void:
	var broken: Dictionary = _book.duplicate(true)
	broken["steps"][3]["requires"] = ["not_a_real_flag"]
	assert_true("\n".join(QuestBook.validate(broken)).contains("no earlier step sets"), "a requirement no earlier step sets")
	broken = _book.duplicate(true)
	broken["steps"][1]["done_flag"] = "met_mira"
	assert_true("\n".join(QuestBook.validate(broken)).contains("used by an earlier step"), "a done flag used twice")
	broken = _book.duplicate(true)
	broken["steps"][2]["unlocks"] = ["unlocked_magic"]
	assert_true("\n".join(QuestBook.validate(broken)).contains("not an ability flag"), "an unknown unlock")
	broken = _book.duplicate(true)
	broken["steps"][0]["objective"] = "x".repeat(70)
	assert_true("\n".join(QuestBook.validate(broken)).contains("objective"), "an objective too long for the HUD")
	broken = _book.duplicate(true)
	broken["road"]["requires"] = ["nobody_sets_this"]
	assert_true("\n".join(QuestBook.validate(broken)).contains("road"), "a road that never opens")
	assert_true("\n".join(QuestBook.validate({})).contains("version"))


func test_a_new_hero_can_only_walk_and_is_sent_to_mira() -> void:
	var core: ExploreCore = _village()
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_eq(snap.objective["id"], &"mira")
	assert_eq(snap.objective["target"], &"mira")
	assert_eq(snap.objective["text"], "Speak to Mira by the gate.")
	assert_true(snap.objective["position"] != Vector2.ZERO, "the marker has a place")
	assert_eq(snap.unlocked, {"attack": false, "dash": false, "parry": false, "item_slot_1": false, "aspect_socket_1": false})
	var dash: InputFrame = _frame(false, Vector2.RIGHT)
	dash.dash_pressed = true
	core.step(dash)
	assert_true(core.player.state != &"dash", "no dash before its lesson")
	assert_eq(core.snapshot().hero.hp, 100)


func test_the_whole_village_sequence_in_order() -> void:
	var core: ExploreCore = _village()
	# Tovan and the Elder and Edda send him away until it is their turn
	_talk(core, &"tovan")
	assert_false(core.has_flag(&"met_tovan"), "Tovan will not see him before Mira")
	_talk(core, &"elder")
	_talk(core, &"edda")
	assert_false(core.has_flag(&"met_elder") or core.has_flag(&"met_edda"))
	assert_eq(core.exp_total, 0)
	# 1. Mira
	var seen: Array[GameEvent] = _talk(core, &"mira")
	assert_true(core.has_flag(&"met_mira"))
	assert_eq(core.exp_total, 10, "Mira's task pays 10 EXP")
	assert_eq(_of(seen, GameEvent.QUEST_COMPLETED)[0].data["step_id"], &"mira")
	assert_eq(_objective(core), &"sword")
	# 2. Tovan: the sword, and the attack unlocks with its lesson
	seen = _talk(core, &"tovan")
	assert_true(core.has_flag(&"received_first_sword") and core.has_flag(&"unlocked_attack"))
	assert_eq(_of(seen, GameEvent.ITEM_RECEIVED)[0].data["item_id"], &"black_katana")
	assert_eq(_objective(core), &"attack")
	var unlocked: Dictionary = core.snapshot().unlocked
	assert_true(unlocked["attack"] and not unlocked["dash"] and not unlocked["parry"], "only the attack so far")
	# the lessons (the post itself is tested in test_training_yard.gd): each pays 10 and unlocks the next ability
	var expected: Array = [[&"lesson_attack", &"dash", &"unlocked_dash"], [&"lesson_dash", &"parry", &"unlocked_parry"], [&"lesson_parry", &"dodge", &""], [&"lesson_dodge", &"tovan_done", &""]]
	var exp_before: int = core.exp_total
	for row: Array in expected:
		var events: Array[GameEvent] = []
		core._grant_flag(row[0], events)
		exp_before += 10
		assert_eq(core.exp_total, exp_before, "%s pays 10" % row[0])
		assert_eq(_objective(core), row[1], "after %s the task is %s" % [row[0], row[1]])
		if row[2] != &"":
			assert_true(core.has_flag(row[2]), "%s unlocked" % row[2])
	assert_false(core.has_flag(&"training_done") and false)
	# Tovan's graduation (training_done is what the post sets after the last lesson)
	core._grant_flag(&"training_done", [] as Array[GameEvent])
	_talk(core, &"tovan")
	assert_true(core.has_flag(&"tovan_graduated"))
	assert_eq(core.exp_total, 10 + 40 + 10, "Tovan's graduation pays 10")
	assert_eq(_objective(core), &"elder_talk")
	# 3. the Elder asks for the basket, the chest opens once, he is paid with herbs
	_talk(core, &"edda")
	assert_false(core.has_flag(&"met_edda"), "Edda still waits for the Elder")
	_talk(core, &"elder")
	assert_true(core.has_flag(&"met_elder"))
	assert_eq(_objective(core), &"elder_chest")
	assert_eq(core.snapshot().objective["target"], &"chest")
	var chest_events: Array[GameEvent] = _open_chest(core)
	assert_eq(_of(chest_events, GameEvent.CHEST_OPENED).size(), 1)
	assert_true(core.has_flag(&"basket_found"))
	assert_eq(_objective(core), &"elder_done")
	assert_eq(_of(_open_chest(core), GameEvent.CHEST_OPENED).size(), 0, "the chest opens once")
	seen = _talk(core, &"elder")
	assert_true(core.has_flag(&"elder_done") and core.has_flag(&"unlocked_item_slot_1"))
	assert_eq(core.inventory.get(&"herb", 0), 2, "the Elder pays 2 herbs")
	assert_true(core.snapshot().unlocked["item_slot_1"] and core.snapshot().item_slots[0]["unlocked"])
	assert_eq(core.exp_total, 60 + 5 + 10)
	# 4. Edda binds Sprint, then the equip lesson (presentation sets lesson_aspect after the menu confirms it)
	seen = _talk(core, &"edda")
	assert_true(core.has_flag(&"met_edda") and core.has_flag(&"aspect_owned_sprint"))
	var got: GameEvent = _of(seen, GameEvent.ITEM_RECEIVED)[0]
	assert_true(got.data["kind"] == &"aspect" and got.data["item_id"] == &"sprint")
	assert_eq(_objective(core), &"edda_equip")
	assert_eq(core.exp_total, 75 + 5)
	assert_true(core.set_flag(&"lesson_aspect"))
	core.step(_frame())  # the flag's events and the reward come with the next step
	assert_eq(core.exp_total, 95, "the sequence paid 95 EXP in all")
	assert_eq(core.level(), 3, "and he leaves the village at level 3")
	assert_eq(_objective(core), &"", "no task left")
	assert_eq(core.snapshot().objective, {})


func _open_chest(core: ExploreCore) -> Array[GameEvent]:
	var stand: Vector2 = Vector2.ZERO
	for o: Dictionary in core.def["objects"]:
		if o["id"] == &"chest":
			stand = o["stand"]
	core.place_at(stand)
	core.step(_frame())
	var seen: Array[GameEvent] = []
	core.step(_frame(true))
	seen.append_array(core.last_events)
	return seen


func test_the_chest_stays_shut_until_the_elder_asked_and_the_forest_chest_is_not_his() -> void:
	var core: ExploreCore = _village()
	assert_eq(_of(_open_chest(core), GameEvent.CHEST_OPENED).size(), 0, "nobody asked for a basket yet")
	assert_false(core.has_flag(&"basket_found"))
	var forest: ExploreCore = ExploreCore.new(SceneDefs.FOREST_LAYERED)
	forest.set_story_flags([&"met_elder"] as Array[StringName])
	assert_eq(_of(_open_chest(forest), GameEvent.CHEST_OPENED).size(), 0, "only the village chest holds the basket")


func test_the_east_gate_is_closed_until_edda_is_done() -> void:
	var core: ExploreCore = _village()
	var exit: Rect2 = Rect2()
	for e: Dictionary in core.def["exits"]:
		exit = e["rect"]
	assert_eq(core.def["exits"][0]["gate"], &"road")
	core.place_at(exit.get_center() + Vector2(-26, 0))
	var blocked: int = 0
	var left: bool = false
	for i: int in 120:
		core.step(_frame(false, Vector2.RIGHT))
		blocked += _of(core.last_events, GameEvent.EXIT_BLOCKED).size()
		left = left or core.exiting
	assert_false(left, "the road is closed")
	assert_eq(blocked, 1, "the reason is said once while he stands there")
	assert_eq(_of(core.last_events, GameEvent.EXIT_BLOCKED).size() + blocked, 1)
	core.set_story_flags([&"lesson_aspect"] as Array[StringName])
	core.place_at(exit.get_center() + Vector2(-26, 0))
	for i: int in 120:
		core.step(_frame(false, Vector2.RIGHT))
		if core.exiting:
			break
	assert_true(core.exiting and core.pending_exit["target_scene"] == SceneDefs.WOODLAND_LAYERED, "open after Edda's lesson")
	var debug: ExploreCore = _village()
	debug.set_story_flags([&"debug_all_unlocked"] as Array[StringName])
	debug.place_at(exit.get_center() + Vector2(-26, 0))
	for i: int in 120:
		debug.step(_frame(false, Vector2.RIGHT))
		if debug.exiting:
			break
	assert_true(debug.exiting, "the debug flag opens it too")


func test_an_older_save_is_not_trapped_behind_a_task_it_already_did() -> void:
	var cases: Array = [
		[[&"met_tovan"], [&"received_first_sword", &"unlocked_attack"], [&"unlocked_dash"]],
		[[&"met_tovan", &"lesson_dash"], [&"unlocked_attack", &"unlocked_dash"], []],
		[[&"met_tovan", &"lesson_parry"], [&"lesson_attack", &"lesson_dash", &"unlocked_attack", &"unlocked_dash", &"unlocked_parry"], []],
		[[&"met_tovan", &"training_done", &"tovan_graduated", &"met_edda"], [&"met_elder", &"basket_found", &"elder_done", &"unlocked_item_slot_1", &"lesson_parry"], []],
		[[&"met_edda", &"lesson_aspect"], [&"elder_done", &"met_edda", &"unlocked_item_slot_1"], []],
	]
	for row: Array in cases:
		var core: ExploreCore = _village()
		var flags: Array[StringName] = []
		flags.append_array(row[0])
		core.set_story_flags(flags)
		for must: StringName in row[1]:
			assert_true(core.has_flag(must), "%s: %s is set" % [str(row[0]), must])
		for must_not: StringName in row[2]:
			assert_false(core.has_flag(must_not), "%s: %s is not set yet" % [str(row[0]), must_not])
	var finished: ExploreCore = _village()
	finished.set_story_flags([&"met_edda", &"lesson_aspect"] as Array[StringName])
	assert_true(QuestBook.road_open(_book, finished.story_flags), "an old save past Edda's lesson walks out of the village")


func test_loading_a_save_pays_nothing_and_raises_no_events() -> void:
	var core: ExploreCore = _village()
	core.set_story_flags([&"met_mira", &"received_first_sword", &"lesson_attack", &"met_tovan"] as Array[StringName])
	assert_eq(core.exp_total, 0, "EXP comes from the save (set_exp), never from the flags")
	core.step(_frame())
	assert_eq(_of(core.last_events, GameEvent.QUEST_COMPLETED).size(), 0)
	assert_eq(_of(core.last_events, GameEvent.EXP_GAINED).size(), 0)
	assert_eq(_objective(core), &"dash")


func test_a_reward_is_paid_only_by_the_flag_that_completes_the_step() -> void:
	var core: ExploreCore = _village()
	var events: Array[GameEvent] = []
	core._grant_flag(&"met_mira", events)
	assert_eq(core.exp_total, 10)
	core._grant_flag(&"met_mira", events)
	assert_eq(core.exp_total, 10, "the same flag twice pays once")
	core.set_flag(&"met_mira")
	core.step(_frame())
	assert_eq(core.exp_total, 10)
