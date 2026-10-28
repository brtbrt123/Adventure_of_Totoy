extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_explore_bot.gd
## A walking bot plays the chapter route through the real exploration scene: from the village arrival it walks (path
## planned on the layout flood grid, tests/explore_bot.gd) to the east road, crosses into the forest with the fade,
## finds the root gate closed (no path north), opens it with the debug flag, walks to the north exit into the glade and
## through the root arch into the arena (the Colossus fight is loaded). Then back: glade -> forest -> village.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")

var failures: Array[String] = []
var changed_to: Array[String] = []
var scene: Explore


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _exit_rect(scene_id: StringName, exit_id: StringName) -> Rect2:
	for exit: Dictionary in SceneDefs.get_def(scene_id)["exits"]:
		if exit["id"] == exit_id:
			return exit["rect"]
	return Rect2()


## Walks the bot to `exit_id` of the current scene; returns true when the scene changed to `target` (or, for the arena,
## when the fight scene was requested). The fade runs through scene.advance_fade like the real loop.
func walk_out(exit_id: StringName, target: StringName, max_ticks: int = 4000) -> bool:
	var from: StringName = scene.snapshot.scene_id
	var bot: ExploreBot = ExploreBot.new()
	if not bot.plan(scene.core.size, scene.core.obstacles, scene.snapshot.hero.position, Vector2.ZERO, _exit_rect(from, exit_id)):
		failures.append("no path from %s to %s" % [from, exit_id])
		return false
	var saw_fade: bool = false
	for i: int in max_ticks:
		if scene.fade_phase != &"":
			saw_fade = saw_fade or scene.fade_alpha() > 0.5
			scene.advance_fade()
		else:
			scene.advance(bot.next_input(scene.snapshot.hero.position))
		if target == SceneDefs.ARENA and changed_to.has(Explore.ARENA_SCENE):
			return saw_fade
		if scene.snapshot.scene_id == target and scene.fade_phase == &"":
			_expect(saw_fade, "the %s -> %s change fades" % [from, target])
			return true
	failures.append("%s: stuck at %s on the way to %s" % [from, scene.snapshot.hero.position, exit_id])
	return false


func _run() -> void:
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": SceneDefs.VILLAGE_LAYERED, "entry": &"arrival"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	scene.change_scene = func(path: String) -> void: changed_to.append(path)
	scene.set_physics_process(false)  # the bot drives every tick
	root.add_child(scene)
	await process_frame
	scene.core.set_flag(&"debug_all_unlocked")
	scene.advance(Explore.InputFrame.new())
	while scene.fade_phase != &"":
		scene.advance_fade()
	_expect(walk_out(&"to_forest", SceneDefs.WOODLAND_LAYERED), "village -> woodland")
	_expect(scene.snapshot.hero.position == SceneDefs.get_def(SceneDefs.WOODLAND_LAYERED)["entries"][&"west"], "woodland west entry")
	_expect(walk_out(&"to_forest", SceneDefs.FOREST_LAYERED), "woodland -> forest")
	_expect(scene.snapshot.hero.position == SceneDefs.get_def(SceneDefs.FOREST_LAYERED)["entries"][&"village_side"], "arrives at the forest's village-side entry")
	var blocked: ExploreBot = ExploreBot.new()
	_expect(not blocked.plan(scene.core.size, scene.core.obstacles, scene.snapshot.hero.position, Vector2.ZERO, _exit_rect(SceneDefs.FOREST_LAYERED, &"to_glade")), "the closed root gate blocks the north exit")
	scene.toggle_gate()
	_expect(walk_out(&"to_glade", SceneDefs.GLADE_LAYERED), "forest -> glade (gate open)")
	_expect(scene.snapshot.hero.position == SceneDefs.get_def(SceneDefs.GLADE_LAYERED)["entries"][&"entrance"], "arrives at the glade entrance")
	_expect(walk_out(&"to_forest", SceneDefs.FOREST_LAYERED), "glade -> forest (north)")
	_expect(scene.snapshot.hero.position == SceneDefs.get_def(SceneDefs.FOREST_LAYERED)["entries"][&"north"], "arrives below the forest's north exit")
	_expect(walk_out(&"to_village", SceneDefs.WOODLAND_LAYERED), "forest -> woodland")
	_expect(scene.snapshot.hero.position == SceneDefs.get_def(SceneDefs.WOODLAND_LAYERED)["entries"][&"east"], "woodland east entry")
	_expect(walk_out(&"to_village", SceneDefs.VILLAGE_LAYERED), "woodland -> village")
	_expect(scene.snapshot.hero.position == SceneDefs.get_def(SceneDefs.VILLAGE_LAYERED)["entries"][&"return"], "arrives at the village return spawn")
	_expect(walk_out(&"to_forest", SceneDefs.WOODLAND_LAYERED), "village -> woodland again")
	_expect(walk_out(&"to_forest", SceneDefs.FOREST_LAYERED), "woodland -> forest again")
	_expect(walk_out(&"to_glade", SceneDefs.GLADE_LAYERED), "forest -> glade again")
	_expect(walk_out(&"to_arena", SceneDefs.ARENA), "glade -> arena (the root arch)")
	_expect(changed_to == [Explore.ARENA_SCENE], "the Colossus fight is loaded once: %s" % str(changed_to))
	print("bot route: %d scene changes" % scene.transitions)
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("EXPLORE BOT SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("EXPLORE BOT FAIL: " + message)
		print("EXPLORE BOT SMOKE FAILED")
		quit(1)
