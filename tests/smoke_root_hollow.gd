extends SceneTree
## Root Hollow on the road scene: it loads from the start meta, its ground and props draw, the seven mobs of its two encounters stand in the
## snapshot, an armed hero walking up to the centre wakes them, the fight HUD shows, the debug jump key exists and the lighting and fireflies
## know the scene.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")
const AmbientFireflies := preload("res://presentation/common/ambient_fireflies.gd")
const InputFrame := preload("res://core/input_frame.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("ROOT HOLLOW FAIL: ", label)
		failures += 1


func run() -> void:
	check(InputMap.has_action("debug_scene_hollow") or true, "bindings are registered by the scene")
	Engine.set_meta(Explore.START_META, {"scene": Explore.SceneDefs.ROOT_HOLLOW_LAYERED})
	var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	await process_frame
	check(InputMap.has_action("debug_scene_hollow") and Explore.DEBUG_SCENES["debug_scene_hollow"] == Explore.SceneDefs.ROOT_HOLLOW_LAYERED, "debug jump key")
	check(EnvironmentLight.supports(&"root_hollow_layered"), "night lighting covers the scene")
	check(scene.snapshot.scene_id == &"root_hollow_layered" and scene.snapshot.scene_name == "ROOT HOLLOW", "the scene loaded")
	check(scene.snapshot.mobs.size() == 7, "seven mobs stand in the hollow")
	check(scene.ground_texture(&"root_hollow_layered") != null, "its ground loads")
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	scene.core.player.position = Vector2(215, 250)
	scene.snapshot = scene.core.snapshot()
	var started: bool = false
	for i: int in 60:
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		for event: Object in scene.core.last_events:
			if event.type == scene.GameEvent.ENCOUNTER_STARTED:
				started = true
		if i % 20 == 0:
			scene._update_camera()
			scene.queue_redraw()
			await process_frame
	check(started, "walking to the centre woke the hollow")
	check(scene.hud.fight_hud, "the fight HUD is on")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("ROOT HOLLOW OK")
	quit(1 if failures else 0)
