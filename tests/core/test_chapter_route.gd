extends "res://tests/test_case.gd"
## The official chapter route (the layered maps, since 2026-10-27): a new game starts in village_layered, the exits chain
## village_layered -> forest_layered -> glade_layered -> arena and back, and a save from the painted maps resumes on the layered
## twin of its scene and checkpoint with every other field (flags, first sword, aspects, gate, record) intact.

const SceneDefs := preload("res://core/scene_defs.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const ExploreCore := preload("res://core/explore_core.gd")


func _exit_to(scene: StringName, target: StringName) -> Dictionary:
	for exit: Dictionary in SceneDefs.get_def(scene)["exits"]:
		if exit["target_scene"] == target:
			return exit
	return {}


func test_a_new_game_starts_in_the_layered_village() -> void:
	assert_eq(SceneDefs.START_SCENE, SceneDefs.VILLAGE_LAYERED)
	var core: ExploreCore = ExploreCore.new()
	assert_eq(core.scene_id, SceneDefs.VILLAGE_LAYERED)
	assert_eq(core.snapshot().hero.position, SceneDefs.get_def(SceneDefs.VILLAGE_LAYERED)["entries"][SceneDefs.START_ENTRY], "at the layered arrival")
	assert_false(core.snapshot().armed, "a new game is unarmed until Tovan hands over the sword")


func test_the_layered_exits_form_the_chapter_route() -> void:
	var chain: Array = [
		[SceneDefs.VILLAGE_LAYERED, SceneDefs.FOREST_LAYERED, &"village_side"],
		[SceneDefs.FOREST_LAYERED, SceneDefs.VILLAGE_LAYERED, &"return"],
		[SceneDefs.FOREST_LAYERED, SceneDefs.GLADE_LAYERED, &"entrance"],
		[SceneDefs.GLADE_LAYERED, SceneDefs.FOREST_LAYERED, &"north"],
		[SceneDefs.GLADE_LAYERED, SceneDefs.ARENA, &"start"],
	]
	for link: Array in chain:
		var exit: Dictionary = _exit_to(link[0], link[1])
		assert_false(exit.is_empty(), "%s leads to %s" % [link[0], link[1]])
		assert_eq(exit["target_entry"], link[2], "%s -> %s enters at %s" % [link[0], link[1], link[2]])
		assert_true(SceneDefs.get_def(link[1])["entries"].has(link[2]), "that entry exists")
	for scene: StringName in SceneDefs.LAYERED:
		for exit: Dictionary in SceneDefs.get_def(scene)["exits"]:
			assert_false(exit["target_scene"] in [SceneDefs.VILLAGE, SceneDefs.FOREST, SceneDefs.GLADE], "%s/%s never leads back to a painted map" % [scene, exit["id"]])


func test_walking_through_every_exit_hands_over_to_the_next_scene() -> void:
	for link: Array in [[SceneDefs.VILLAGE_LAYERED, SceneDefs.FOREST_LAYERED], [SceneDefs.FOREST_LAYERED, SceneDefs.VILLAGE_LAYERED], [SceneDefs.FOREST_LAYERED, SceneDefs.GLADE_LAYERED], [SceneDefs.GLADE_LAYERED, SceneDefs.FOREST_LAYERED], [SceneDefs.GLADE_LAYERED, SceneDefs.ARENA]]:
		var core: ExploreCore = ExploreCore.new(link[0], &"", true)  # gate open so the forest's north exit is reachable
		var exit: Dictionary = _exit_to(link[0], link[1])
		var goal: Vector2 = exit["rect"].get_center()
		var inward: Vector2 = (core.size * 0.5 - goal).normalized()
		core.place_at(goal + inward * 24.0)  # an exit fires only for a hero who walks into it
		var seen: bool = false
		for i: int in 120:
			var frame: InputFrame = InputFrame.new()
			frame.move = (goal - core.player.position).normalized()
			core.step(frame)
			for event: GameEvent in core.last_events:
				if event.type == GameEvent.SCENE_EXIT and event.data["target_scene"] == link[1]:
					seen = true
			if seen:
				break
		assert_true(seen, "%s -> %s announces the exit" % link)


func test_a_painted_save_resumes_on_the_layered_twin() -> void:
	for row: Array in [
		["village", "village_gate", &"village_layered", &"village_layered_gate"],
		["village", "", &"village_layered", &""],
		["forest", "forest_entrance", &"forest_layered", &"forest_layered_entrance"],
		["forest", "forest_puzzle", &"forest_layered", &"forest_layered_puzzle"],
		["glade", "glade_entrance", &"glade_layered", &"glade_layered_entrance"],
		["glade", "", &"glade_layered", &""],
		["arena", "ruins_gate", &"arena", &"ruins_gate"],
		["village_layered", "village_layered_gate", &"village_layered", &"village_layered_gate"],
	]:
		var text: String = JSON.stringify({"version": 1, "scene_id": row[0], "checkpoint_id": row[1]})
		var p: SaveProfile = SaveProfile.from_json(text) as SaveProfile
		assert_eq([p.scene_id, p.checkpoint_id], [row[2], row[3]], text)
		assert_true(SceneDefs.is_known(p.scene_id) and (p.checkpoint_id == &"" or not SceneDefs.checkpoint(p.scene_id, p.checkpoint_id).is_empty()), "a valid layered resume point: %s" % text)


func test_a_painted_checkpoint_of_another_scene_is_dropped_not_carried_over() -> void:
	var p: SaveProfile = SaveProfile.from_json("{\"version\": 1, \"scene_id\": \"forest\", \"checkpoint_id\": \"glade_entrance\"}") as SaveProfile
	assert_eq([p.scene_id, p.checkpoint_id], [SceneDefs.FOREST_LAYERED, &""], "the forest save keeps the forest and uses its default entry")


func test_a_painted_save_keeps_flags_gate_aspects_and_the_record() -> void:
	var saved: Dictionary = {
		"version": 1, "runs_started": 4, "victories": 2, "defeats": 1, "best_victory_ticks": 5400, "last_result": "victory",
		"weapon_id": "dual_dagger", "equipped_aspects": ["sprint", "gale_cut", "moon_cleave"],
		"scene_id": "forest", "checkpoint_id": "forest_puzzle", "gate_open": true,
		"story_flags": ["met_tovan", "lesson_dash", "met_mira"],
	}
	var p: SaveProfile = SaveProfile.from_dict(saved) as SaveProfile
	assert_eq([p.scene_id, p.checkpoint_id, p.gate_open], [SceneDefs.FOREST_LAYERED, &"forest_layered_puzzle", true])
	assert_eq([p.runs_started, p.victories, p.defeats, p.best_victory_ticks, p.last_result, p.weapon_id], [4, 2, 1, 5400, &"victory", &"dual_dagger"], "the boss record and loadout")
	assert_eq(p.equipped_aspects, [&"sprint", &"gale_cut", &"moon_cleave"] as Array[StringName])
	assert_eq(p.story_flags, [&"met_tovan", &"lesson_dash", &"met_mira"] as Array[StringName], "no flag dropped")
	# CONTINUE: the hero stands on the layered checkpoint (not on painted coordinates), gate open, armed without a receipt
	var core: ExploreCore = ExploreCore.at_checkpoint(p.scene_id, p.checkpoint_id, p.gate_open) as ExploreCore
	core.set_story_flags(p.story_flags)
	assert_eq(core.snapshot().hero.position, SceneDefs.checkpoint(SceneDefs.FOREST_LAYERED, &"forest_layered_puzzle")["position"])
	assert_true(core.snapshot().gate_open and core.snapshot().armed, "the gate stays open and a hero who met Tovan is armed")
	for i: int in 5:
		core.step(InputFrame.new())
		for event: GameEvent in core.last_events:
			assert_true(event.type != GameEvent.ITEM_RECEIVED, "no receipt replays")
	# the next save is written with the layered ids
	var again: SaveProfile = SaveProfile.from_json(p.to_json()) as SaveProfile
	assert_eq(again.to_json(), p.to_json(), "stable after the migration")
