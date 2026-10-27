extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/layered_forest/review/playtest_fixes/"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var output: String = OUT
	if "--clean-approach" in OS.get_cmdline_user_args():
		output += "clean_approach_v1/"
	elif "--alignment" in OS.get_cmdline_user_args():
		output += "alignment/"
	elif "--narrow-final" in OS.get_cmdline_user_args():
		output += "narrow_final/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	for id: StringName in [&"forest_layered", &"glade_layered"]:
		Engine.set_meta(Explore.START_META, {"scene": id, "gate_open": false})
		var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
		scene.set_physics_process(false)
		root.add_child(scene)
		await process_frame
		scene.fade_phase = &""
		scene.core.place_at(Vector2(100, 130) if id == &"forest_layered" else Vector2(450, 185))
		scene.advance(Intent.new())
		scene.hud.visible = false
		root.content_scale_size = Vector2i(scene.snapshot.size)
		root.size = Vector2i(scene.snapshot.size) * 2
		scene.camera.enabled = false
		for debug: bool in [false, true]:
			scene.debug_enabled = debug
			scene.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var path: String = output + String(id) + ("_colliders" if debug else "") + ".png"
			if root.get_texture().get_image().save_png(path) != OK:
				printerr("FAIL capture " + path)
				quit(1)
				return
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	print("PLAYTEST COLLISION CAPTURES OK")
	quit()
