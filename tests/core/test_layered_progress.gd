extends "res://tests/test_case.gd"
## The layered scenes (SceneDefs.LAYERED) as part of the chapter's progress: their runtime ground lives in
## presentation/ (not in art/reference), is the scene's size and a palette image; a save in either scene writes and
## reads back (scene, checkpoint), CONTINUE puts the hero on the saved checkpoint, a checkpoint of another scene is
## dropped, reaching a checkpoint emits and records it, and every exit leads to a scene and entry that exist.

const SceneDefs := preload("res://core/scene_defs.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const ExploreCore := preload("res://core/explore_core.gd")

const GROUNDS: Dictionary = {
	&"village_layered": "res://presentation/village/village_layered_ground.png",
	&"glade_layered": "res://presentation/forest/glade_layered_ground.png",
	&"forest_layered": "res://presentation/forest/forest_layered_ground.png",
}
## Scenes whose converted ground Codex has not delivered yet (only the path is checked until then).
const PENDING_GROUNDS: Array[StringName] = [&"forest_layered"]


func test_the_runtime_grounds_are_in_presentation_and_fit_the_scene() -> void:
	for scene: StringName in SceneDefs.LAYERED:
		var data: Dictionary = SceneDefs.layered_data(scene)
		assert_eq(String(data["ground"]), GROUNDS[scene], "%s uses its runtime ground" % scene)
		assert_false(String(data["ground"]).begins_with("res://art/"), "%s does not load a ground from art/" % scene)
		if scene in PENDING_GROUNDS and not FileAccess.file_exists(String(data["ground"])):
			continue
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(String(data["ground"])))
		assert_true(image != null, "%s ground loads" % scene)
		if image == null:
			continue
		var size: Array = data["size"]
		assert_eq(Vector2(image.get_width(), image.get_height()), Vector2(float(size[0]), float(size[1])), "%s ground is the scene's size" % scene)


func test_a_save_in_a_layered_scene_round_trips() -> void:
	for scene: StringName in SceneDefs.LAYERED:
		var checkpoint: StringName = SceneDefs.get_def(scene)["checkpoints"][0]["id"]
		var profile: Object = SaveProfile.new()
		profile.record_scene(scene, checkpoint)
		assert_eq(profile.scene_id, scene, "%s is recorded" % scene)
		assert_eq(profile.checkpoint_id, checkpoint, "with its checkpoint")
		assert_true(profile.has_progress(), "there is something to continue")
		var loaded: Object = SaveProfile.from_json(profile.to_json())
		assert_eq(loaded.scene_id, scene, "%s survives the JSON round trip" % scene)
		assert_eq(loaded.checkpoint_id, checkpoint, "and so does its checkpoint")


func test_a_checkpoint_of_another_scene_is_dropped() -> void:
	var profile: Object = SaveProfile.new()
	profile.record_scene(SceneDefs.VILLAGE_LAYERED, &"glade_layered_entrance")
	assert_eq(profile.scene_id, SceneDefs.VILLAGE_LAYERED, "the scene is kept")
	assert_eq(profile.checkpoint_id, &"", "a glade checkpoint is not a village checkpoint")


func test_continue_puts_the_hero_on_the_saved_checkpoint() -> void:
	for scene: StringName in SceneDefs.LAYERED:
		var checkpoint: Dictionary = SceneDefs.get_def(scene)["checkpoints"][0]
		var core: ExploreCore = ExploreCore.at_checkpoint(scene, checkpoint["id"]) as ExploreCore
		assert_eq(core.scene_id, scene, "%s loads" % scene)
		assert_eq(core.last_checkpoint, checkpoint["id"], "the checkpoint counts as recorded")
		assert_true(core.player.position.distance_to(checkpoint["position"]) <= ExploreCore.CHECKPOINT_RADIUS, "the hero stands on it (at %s)" % str(core.player.position))
		core.step(InputFrame.new())
		for event: GameEvent in core.last_events:
			assert_false(event.type == GameEvent.CHECKPOINT, "a continued checkpoint is not announced again")


func test_reaching_a_checkpoint_emits_and_records_it() -> void:
	for scene: StringName in SceneDefs.LAYERED:
		var checkpoint: Dictionary = SceneDefs.get_def(scene)["checkpoints"][0]
		var core: ExploreCore = ExploreCore.new(scene) as ExploreCore
		core.place_at(checkpoint["position"])  # the glade's spawn is a few steps short of its checkpoint
		var seen: Array[StringName] = []
		for i: int in 3:
			core.step(InputFrame.new())
			for event: GameEvent in core.last_events:
				if event.type == GameEvent.CHECKPOINT:
					seen.append(event.data["checkpoint_id"])
		assert_eq(seen, [checkpoint["id"]], "%s: reaching the checkpoint announces it once" % scene)
		assert_eq(core.last_checkpoint, checkpoint["id"], "and recorded")


func test_every_exit_leads_to_a_real_scene_and_entry() -> void:
	for scene: StringName in SceneDefs.LAYERED:
		for exit: Dictionary in SceneDefs.get_def(scene)["exits"]:
			var target: StringName = exit["target_scene"]
			assert_true(SceneDefs.is_known(target), "%s/%s leads to a known scene (%s)" % [scene, exit["id"], target])
			if target != SceneDefs.ARENA:
				assert_true(SceneDefs.get_def(target)["entries"].has(exit["target_entry"]), "%s/%s: entry %s exists in %s" % [scene, exit["id"], exit["target_entry"], target])
