extends "res://tests/test_case.gd"
## Tovan's first sword (core/explore_core.gd, core/dialogue_book.gd grants, data/dialogue/chapter1.json): the hero starts unarmed
## and cannot fight, the handover at the end of Tovan's first conversation (finished or skipped) sets `received_first_sword` and emits
## `item_received` once, never again (talking again, a reload, a new scene), a save from before the handover is treated as armed, and
## the explore snapshot carries the real combo index and swing speed.

const DialogueBook := preload("res://core/dialogue_book.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const Snapshots := preload("res://core/snapshots.gd")


func _frame(interact: bool = false, skip: bool = false, attack: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.interact_pressed = interact
	f.skip_pressed = skip
	f.attack_pressed = attack
	f.attack_held = attack
	f.aim = Vector2.UP
	return f


func _event(core: ExploreCore, type: StringName) -> GameEvent:
	for e: GameEvent in core.last_events:
		if e.type == type:
			return e
	return null


func _count(events: Array[GameEvent], type: StringName) -> int:
	var n: int = 0
	for e: GameEvent in events:
		if e.type == type:
			n += 1
	return n


func _at(core: ExploreCore, npc: StringName) -> void:
	for row: Dictionary in core.def["npcs"]:
		if row["id"] != npc:
			continue
		for offset: Vector2 in [Vector2(0, 14), Vector2(-14, 0), Vector2(14, 0), Vector2(0, -14), Vector2(0, 12)]:
			core.place_at(row["position"] + offset)
			core.step(_frame())
			if core.interact_target.get("id", &"") == npc:
				return
	assert_true(false, "the hero can stand in range of %s" % npc)


func _post_stand(core: ExploreCore) -> Vector2:
	for object: Dictionary in core.def["objects"]:
		if object["kind"] == &"dummy":
			return object["stand"]
	return Vector2.ZERO


## Talks to Tovan from the start of his first conversation to its end; returns every event raised on the way.
func _first_talk(core: ExploreCore, skip: bool) -> Array[GameEvent]:
	var seen: Array[GameEvent] = []
	_at(core, &"tovan")
	core.step(_frame(true))
	seen.append_array(core.last_events)
	for i: int in 30:
		if not core.is_talking():
			break
		core.step(_frame(not skip, skip))
		seen.append_array(core.last_events)
	return seen


func test_the_hero_starts_unarmed_and_cannot_fight() -> void:
	for scene: StringName in [SceneDefs.VILLAGE_LAYERED, SceneDefs.VILLAGE_LAYERED]:
		var core: ExploreCore = ExploreCore.new(scene)
		assert_false(core.snapshot().armed, "%s: unarmed at the start" % scene)
		core.place_at(_post_stand(core))
		core.step(_frame())
		core.step(_frame(false, false, true))
		assert_eq(core.snapshot().hero.state, &"idle", "%s: no swing without a sword" % scene)
		assert_false(core.training.is_on(core.story_flags, core.player.position), "the yard is shut")
		assert_eq(core.snapshot().training["hint"], &"")


func test_tovans_first_conversation_hands_over_the_sword_once() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	var events: Array[GameEvent] = _first_talk(core, false)
	assert_eq(_count(events, &"item_received"), 1, "one receipt")
	var got: GameEvent = null
	for e: GameEvent in events:
		if e.type == &"item_received":
			got = e
	assert_true(got != null and got.data["reward_id"] == &"first_sword" and got.data["kind"] == &"weapon" and got.data["item_id"] == &"black_katana" and got.data["quantity"] == 1 and got.data["name"] == "Black Katana" and got.data["source"] == &"tovan", "the receipt says what it is: %s" % str(got.data if got else {}))
	assert_true(core.snapshot().armed and core.has_flag(&"received_first_sword") and core.has_flag(&"met_tovan"))
	# it comes after the conversation ended and the flag was announced
	var order: Array[StringName] = []
	for e: GameEvent in events:
		if e.type in [&"dialogue_ended", &"flag_set", &"item_received"]:
			order.append(e.type)
	assert_eq(order.back(), &"item_received", "the receipt is the last of the handover")
	assert_true(order.find(&"dialogue_ended") < order.find(&"item_received"))
	# talking again and again never gives it twice
	for i: int in 3:
		core.step(_frame(true))
		for j: int in 20:
			if not core.is_talking():
				break
			core.step(_frame(true))
			assert_eq(_count(core.last_events, &"item_received"), 0, "no second receipt")


func test_skipping_the_conversation_still_hands_it_over() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	var events: Array[GameEvent] = _first_talk(core, true)
	assert_eq(_count(events, &"item_received"), 1)
	assert_true(core.snapshot().armed, "skip counts as heard and received")


func test_a_new_core_from_the_save_does_not_receive_again() -> void:
	var first: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	_first_talk(first, false)
	var saved: Array[StringName] = first.story_flags.duplicate()
	var again: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)  # another scene of the chapter
	again.set_story_flags(saved)
	for i: int in 5:
		again.step(_frame())
		assert_eq(_count(again.last_events, &"item_received"), 0, "loading a save raises no receipt")
	assert_true(again.snapshot().armed)
	_at(again, &"tovan")
	again.step(_frame(true))
	assert_false(again.snapshot().dialogue["dialogue_id"] == &"tovan_intro", "the handover is not played twice")


func test_an_older_save_that_met_tovan_is_armed_without_a_receipt() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	core.set_story_flags([&"met_tovan", &"lesson_dash"] as Array[StringName])
	assert_true(core.snapshot().armed and core.has_flag(&"received_first_sword"), "migrated: the tutorial is not trapped")
	core.step(_frame())
	assert_eq(_count(core.last_events, &"item_received"), 0, "no popup for a sword he already had")
	core.place_at(_post_stand(core))
	core.step(_frame())
	assert_true(core.training.is_on(core.story_flags, core.player.position), "the post works for him")
	var fresh: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	fresh.set_story_flags([&"met_mira"] as Array[StringName])
	assert_false(fresh.snapshot().armed, "meeting Mira is not a sword")


func test_other_npcs_give_nothing() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	for npc: StringName in [&"mira", &"edda", &"elder", &"child", &"worker"]:
		_at(core, npc)
		core.step(_frame(true))
		for i: int in 20:
			if not core.is_talking():
				break
			core.step(_frame(true))
			assert_eq(_count(core.last_events, &"item_received"), 0, "%s gives nothing" % npc)
	assert_false(core.snapshot().armed)


func test_the_post_wakes_after_the_handover_and_a_new_game_unarms() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	_first_talk(core, false)
	core.place_at(_post_stand(core))
	core.step(_frame())
	assert_true(core.snapshot().training["active"], "the yard is open after the handover")
	core.step(_frame(false, false, true))
	assert_true(String(core.snapshot().hero.state).begins_with("attack"), "he swings")
	var fresh: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)  # NEW GAME: no flags
	assert_false(fresh.snapshot().armed)


func test_the_snapshot_carries_the_real_combo_index_and_swing_speed() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	core.set_story_flags([&"received_first_sword"] as Array[StringName])
	core.place_at(_post_stand(core))
	core.step(_frame())
	assert_eq(core.snapshot().hero.combo_index, 1, "idle: 1")
	var best: int = 1
	for i: int in 120:
		core.step(_frame(false, false, true))
		var hero: Snapshots.EntitySnapshot = core.snapshot().hero
		assert_eq(hero.combo_index, core.player.combo_index, "tick %d: the snapshot is the player's combo" % i)
		if String(core.player.state).begins_with("attack_"):
			assert_eq(hero.attack_speed_mult, core.player.swing_speed_mult, "the locked swing speed")
		best = maxi(best, hero.combo_index)
	assert_true(best >= 2, "a held attack chains to swing %d at least" % 2)


func test_the_book_rejects_a_broken_grant() -> void:
	var broken: Dictionary = {
		"npcs": {"a": [{"dialogue": "d"}]},
		"dialogues": {"d": {"speaker": "A", "lines": [{"text": "x"}], "grants": [{"reward_id": "r", "kind": "armour", "item": "i", "name": "", "flag": "f", "quantity": 0}]}},
	}
	var text: String = "\n".join(DialogueBook.validate(broken, []))
	assert_true(text.contains("without name") and text.contains("weapon or item") and text.contains("quantity"), text)
	assert_eq(DialogueBook.validate(DialogueBook.default_book(), [&"mira", &"tovan", &"edda", &"elder", &"child", &"worker"]), [] as Array[String], "the real book is valid")
