extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const OUT: String = "res://art/build/arena_mob_idle_motion/"
func _init() -> void:
	OS.set_environment("TOTOY_SAVE_PATH","res://art/build/arena_mob_idle_capture_save.json")
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ignore: FileAccess = FileAccess.open(OUT+".gdignore",FileAccess.WRITE)
	ignore.store_string("Temporary renderer captures\n")
	ignore.close()
	root.size = Vector2i(1152,648)
	for type: String in ["mossling","boar"]:
		Engine.set_meta(Explore.START_META,{"scene":&"woodland_layered"})
		var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		scene.conversation.controls_open = false
		var target: Dictionary = {}
		for mob: Dictionary in scene.snapshot.mobs:
			if String(mob["type"]) == type:
				target = mob
				break
		assert(not target.is_empty())
		scene.core.player.position = target["position"] + Vector2(60,32)
		for frame: int in 72:
			for tick: int in 6:
				scene.advance(InputFrame.new())
				scene.fade_phase = &""
			scene._update_hud()
			scene._update_camera()
			scene.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var crop: Rect2i = Rect2i(Vector2i((Vector2(target["position"])-scene.view_origin-Vector2(40,52))*3),Vector2i(240,192))
			root.get_texture().get_image().get_region(crop).save_png(OUT+"arena_"+type+"_%03d.png"%frame)
		print("LIVE IDLE CAPTURE ",type," 72 frames / 7.2 seconds")
		scene.queue_free()
		await process_frame
	quit()
