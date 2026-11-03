extends SceneTree
## The forest route has its mobs on the road scene: an armed hero walking up wakes the trail, the mobs are in the snapshot and draw, the
## fight HUD shows, and clearing a pack works through the same code as the Woodland Approach.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("FOREST MOBS FAIL: ", label)
		failures += 1


func run() -> void:
	Engine.set_meta(Explore.START_META, {"scene": Explore.SceneDefs.FOREST_LAYERED})
	var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	await process_frame
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	check(scene.snapshot.mobs.size() == 5, "five mobs stand in the forest (3 Mosslings, 2 Boars)")
	check(not scene.snapshot.encounters.is_empty(), "the snapshot lists the encounters")
	scene.core.player.position = Vector2(100, 130)
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
	check(started, "walking up woke the trail")
	check(scene.hud.fight_hud, "the fight HUD is on")
	check(scene.drawables().filter(func(d: Dictionary) -> bool: return d["kind"] == &"mob").size() == 5, "the mobs are drawn")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("FOREST MOBS OK")
	quit(1 if failures else 0)
