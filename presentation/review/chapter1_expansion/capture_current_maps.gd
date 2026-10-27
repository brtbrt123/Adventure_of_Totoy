extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.remove_meta(Explore.PERSIST_META)
	for id: StringName in [&"village_layered", &"forest_layered", &"glade_layered"]:
		Engine.set_meta(Explore.START_META, {"scene": id})
		var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		scene.camera.enabled = false
		(scene.get_node("HUD") as CanvasLayer).hide()
		root.content_scale_size = Vector2i(scene.snapshot.size)
		root.size = Vector2i(scene.snapshot.size) * 2
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var error: Error = root.get_texture().get_image().save_png("res://presentation/review/chapter1_expansion/current_" + String(id) + ".png")
		if error != OK:
			quit(1)
			return
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	print("CURRENT MAP CAPTURES OK")
	quit(0)
