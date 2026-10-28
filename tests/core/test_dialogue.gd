extends "res://tests/test_case.gd"
## Dialogue (core/dialogue_book.gd, data/dialogue/chapter1.json, the conversation in core/explore_core.gd) and the story
## flags in the save: the book is valid for every scene's NPCs, the NPC plays the dialogue its flags choose, the hero
## stops while talking, E shows the next line, skip ends it, a finished or skipped conversation sets its flags once,
## the flags survive the save, and the same inputs give the same conversation.

const DialogueBook := preload("res://core/dialogue_book.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const SaveProfile := preload("res://core/save_profile.gd")

var _book: Dictionary = DialogueBook.default_book()


func _frame(move: Vector2 = Vector2.ZERO, interact: bool = false, skip: bool = false, dash: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move = move
	f.interact_pressed = interact
	f.skip_pressed = skip
	f.dash_pressed = dash
	return f


func _types(core: ExploreCore) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: GameEvent in core.last_events:
		out.append(e.type)
	return out


## A core with the hero beside `npc` (idle, the NPC the nearest target): the first free spot around it.
func _beside(scene: StringName, npc: StringName) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(scene)
	for row: Dictionary in core.def["npcs"]:
		if row["id"] != npc:
			continue
		for offset: Vector2 in [Vector2(0, 14), Vector2(-14, 0), Vector2(14, 0), Vector2(0, -14), Vector2(0, 12)]:
			core.place_at(row["position"] + offset)
			core.step(_frame())
			if core.interact_target.get("id", &"") == npc:
				return core
	assert_true(false, "the hero can stand in range of %s" % npc)
	return core


func _talk_through(core: ExploreCore) -> int:
	var presses: int = 0
	while core.is_talking() and presses < 50:
		core.step(_frame(Vector2.ZERO, true))
		presses += 1
	return presses


func test_the_book_is_valid_for_every_scene() -> void:
	var npcs: Array[StringName] = []
	for scene: StringName in SceneDefs.ALL:
		for row: Dictionary in SceneDefs.get_def(scene)["npcs"]:
			if not npcs.has(row["id"]):
				npcs.append(row["id"])
	assert_true(npcs.size() > 0, "there are NPCs")
	var problems: Array[String] = DialogueBook.validate(_book, npcs)
	assert_eq(problems, [] as Array[String], "the book is valid: %s" % str(problems))


func test_validate_finds_the_problems_it_should() -> void:
	var broken: Dictionary = {
		"npcs": {"a": [{"when": {"flags": ["x"]}, "dialogue": "nope"}]},
		"dialogues": {"empty": {"speaker": "A", "lines": []}, "quiet": {"lines": [{"text": "hi"}]}, "long": {"speaker": "A", "lines": [{"text": "x".repeat(200)}]}},
	}
	var text: String = "\n".join(DialogueBook.validate(broken, [&"missing"]))
	for part: String in ["no lines", "no speaker", "characters", "unknown dialogue nope", "no fallback", "npc missing has no conversation"]:
		assert_true(text.contains(part), "reports: " + part)


func test_the_flags_choose_the_dialogue() -> void:
	assert_eq(DialogueBook.pick(_book, &"mira", [] as Array[StringName]), &"mira_intro")
	assert_eq(DialogueBook.pick(_book, &"mira", [&"met_mira"] as Array[StringName]), &"mira_again")
	assert_eq(DialogueBook.pick(_book, &"mira", [&"met_mira", &"met_edda"] as Array[StringName]), &"mira_after_edda", "the first entry that holds wins")
	assert_eq(DialogueBook.pick(_book, &"nobody", [] as Array[StringName]), &"", "an unknown NPC has no conversation")
	assert_true(DialogueBook.holds({"not": ["a"]}, [&"b"] as Array[StringName]))
	assert_false(DialogueBook.holds({"not": ["a"]}, [&"a"] as Array[StringName]))


func test_interact_on_an_npc_starts_the_conversation_and_stops_the_hero() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"mira")
	core.step(_frame(Vector2.ZERO, true))
	assert_true(core.is_talking(), "talking")
	assert_true(&"interact" in _types(core) and &"dialogue_started" in _types(core), "interact and dialogue_started")
	var view: Dictionary = core.snapshot().dialogue
	assert_eq(view["dialogue_id"], &"mira_intro")
	assert_eq(view["index"], 0)
	assert_eq(view["speaker"], "Mira")
	assert_eq(view["portrait"], "mira")
	assert_true(String(view["text"]).length() > 0, "the first line")
	var at: Vector2 = core.player.position
	for i: int in 20:
		core.step(_frame(Vector2.RIGHT, false, false, true))
	assert_eq(core.player.position, at, "walking and dashing are ignored while talking")
	assert_eq(core.snapshot().hero.state, &"idle")


func test_interact_shows_each_line_then_ends_and_sets_the_flags_once() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"mira")
	core.step(_frame(Vector2.ZERO, true))
	var count: int = int(core.snapshot().dialogue["count"])
	var seen: Array[String] = [String(core.snapshot().dialogue["text"])]
	for i: int in count - 1:
		core.step(_frame(Vector2.ZERO, true))
		assert_true(&"dialogue_advanced" in _types(core), "line %d is announced" % (i + 2))
		assert_eq(core.snapshot().dialogue["index"], i + 1)
		seen.append(String(core.snapshot().dialogue["text"]))
	assert_eq(seen.size(), count)
	assert_false(seen[0] == seen[1], "each press shows a different line")
	assert_false(core.has_flag(&"met_mira"), "no flag before the end")
	core.step(_frame(Vector2.ZERO, true))
	assert_false(core.is_talking(), "ended after the last line")
	assert_true(core.snapshot().dialogue.is_empty())
	var ended: GameEvent = null
	for e: GameEvent in core.last_events:
		if e.type == &"dialogue_ended":
			ended = e
	assert_true(ended != null and ended.data["skipped"] == false and ended.data["flags_set"] == [&"met_mira"], "dialogue_ended names the flags")
	assert_true(&"flag_set" in _types(core))
	assert_true(core.has_flag(&"met_mira"))
	assert_eq(core.snapshot().story_flags, [&"met_mira"] as Array[StringName])
	assert_false(&"dialogue_started" in _types(core), "the press that ends it does not start another")


func test_skip_ends_the_conversation_and_still_sets_the_flags() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"edda")
	core.step(_frame(Vector2.ZERO, true))
	core.step(_frame(Vector2.ZERO, false, true))
	assert_false(core.is_talking())
	assert_true(core.has_flag(&"met_edda"), "skipping counts as heard")
	var ended: GameEvent = null
	for e: GameEvent in core.last_events:
		if e.type == &"dialogue_ended":
			ended = e
	assert_true(ended != null and ended.data["skipped"] == true)


func test_skip_does_nothing_when_nobody_talks() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"mira")
	core.step(_frame(Vector2.ZERO, false, true))
	assert_false(core.is_talking())
	assert_eq(core.last_events.size(), 0)


func test_the_second_talk_plays_the_follow_up_and_flags_are_never_set_twice() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"mira")
	core.step(_frame(Vector2.ZERO, true))
	_talk_through(core)
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().dialogue["dialogue_id"], &"mira_again")
	_talk_through(core)
	assert_eq(core.story_flags, [&"met_mira"] as Array[StringName], "met_mira once")
	assert_false(&"flag_set" in _types(core), "the follow-up sets nothing new")


func test_conversations_unlock_each_other_across_npcs() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"edda")
	core.step(_frame(Vector2.ZERO, true))
	_talk_through(core)
	for row: Dictionary in core.def["npcs"]:
		if row["id"] == &"mira":
			core.place_at(row["position"] + Vector2(0, 14))
	core.step(_frame())
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().dialogue["dialogue_id"], &"mira_after_edda", "Mira reacts to Edda's lesson")


func test_objects_and_scenes_without_npcs_start_no_conversation() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.FOREST_LAYERED)
	core.place_at(core.def["objects"][0]["stand"])
	core.step(_frame())
	core.step(_frame(Vector2.ZERO, true))
	assert_false(core.is_talking())
	var arena: ExploreCore = ExploreCore.new(SceneDefs.ARENA)
	arena.step(_frame(Vector2.ZERO, true))
	assert_false(arena.is_talking())


func test_set_flag_and_set_story_flags() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	assert_true(core.set_flag(&"stag_bound"))
	assert_false(core.set_flag(&"stag_bound"), "a flag is new once")
	core.step(_frame())
	assert_true(&"flag_set" in _types(core), "announced with the next step")
	core.set_story_flags([&"a", &"b", &"a"] as Array[StringName])
	assert_eq(core.story_flags, [&"a", &"b"] as Array[StringName], "restored without duplicates")
	assert_eq(core.snapshot().story_flags, [&"a", &"b"] as Array[StringName])


func test_a_restored_flag_changes_what_the_npc_says() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"tovan")
	core.set_story_flags([&"met_tovan"] as Array[StringName])
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().dialogue["dialogue_id"], &"tovan_again")


func test_the_layered_village_talks_the_same() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"tovan")
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().dialogue["dialogue_id"], &"tovan_intro")


func test_the_flags_survive_the_save() -> void:
	var profile: SaveProfile = SaveProfile.new()
	profile.story_flags = [&"met_mira", &"met_edda"] as Array[StringName]
	var back: SaveProfile = SaveProfile.from_json(profile.to_json())
	assert_eq(back.story_flags, [&"met_mira", &"met_edda"] as Array[StringName])
	back.reset_progress()
	assert_eq(back.story_flags.size(), 0, "a new game forgets the story")
	var old: SaveProfile = SaveProfile.from_dict({"version": 1, "runs_started": 2})
	assert_eq(old.story_flags.size(), 0, "an older save has no flags")


func test_a_damaged_save_cannot_poison_the_flags() -> void:
	var bad: Array = ["ok_flag", "ok_flag", "Has Space", "", 12, null, "x".repeat(41), "../up"]
	for i: int in 100:
		bad.append("f%d" % i)
	var profile: SaveProfile = SaveProfile.from_dict({"version": 1, "story_flags": bad})
	assert_true(profile.story_flags.has(&"ok_flag"))
	assert_eq(profile.story_flags.count(&"ok_flag"), 1, "no duplicates")
	for flag: StringName in profile.story_flags:
		assert_true(String(flag).length() <= 40 and String(flag) == String(flag).to_lower() and not String(flag).contains(" ") and not String(flag).contains("."), "only plain flags: " + flag)
	assert_true(profile.story_flags.size() <= SaveProfile.MAX_FLAGS, "capped")
	assert_eq(SaveProfile.from_dict({"version": 1, "story_flags": "nonsense"}).story_flags.size(), 0, "not a list")


func test_the_conversation_is_deterministic() -> void:
	var runs: Array[String] = []
	for n: int in 2:
		var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"edda")
		var log: Array[String] = []
		for i: int in 12:
			core.step(_frame(Vector2.RIGHT if i % 3 == 0 else Vector2.ZERO, i % 2 == 0, i == 9))
			log.append("%s|%s|%s" % [str(core.player.position), str(core.snapshot().dialogue.get("index", -1)), str(_types(core))])
		runs.append("\n".join(log))
	assert_eq(runs[0], runs[1])


func test_tovan_and_edda_follow_the_lessons() -> void:
	var core: ExploreCore = _beside(SceneDefs.VILLAGE_LAYERED, &"tovan")
	core.set_story_flags([&"met_tovan"] as Array[StringName])
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().dialogue["dialogue_id"], &"tovan_again", "lessons not done: the reminder")
	_talk_through(core)
	core.set_story_flags([&"met_tovan", &"training_done"] as Array[StringName])
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().dialogue["dialogue_id"], &"tovan_graduate")
	_talk_through(core)
	assert_true(core.has_flag(&"tovan_graduated"))
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().dialogue["dialogue_id"], &"tovan_after", "he does not graduate you twice")
	assert_eq(DialogueBook.pick(_book, &"edda", [&"met_edda", &"lesson_aspect"] as Array[StringName]), &"edda_aspect_done")
	assert_eq(DialogueBook.pick(_book, &"edda", [&"met_edda"] as Array[StringName]), &"edda_again")
