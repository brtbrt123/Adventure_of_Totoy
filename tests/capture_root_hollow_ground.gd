extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/root_hollow_v1/"
func _init() -> void:
	OS.set_environment("TOTOY_SAVE_PATH", "res://art/build/arena_hollow_review_save.json")
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1152,648)
	var cases: Array[Array] = [[&"root_hollow_layered",Vector2(330,206),"central"],[&"root_hollow_layered",Vector2(108,100),"shrine"],[&"root_hollow_layered",Vector2(466,284),"pocket"],[&"root_hollow_layered",Vector2(300,206),"combat"],[&"woodland_layered",Vector2(330,206),"woodland"],[&"forest_layered",Vector2(260,150),"forest"]]
	for entry: Array in cases:
		Engine.set_meta(Explore.START_META,{"scene": &"forest_layered" if entry[0] == &"root_hollow_layered" else entry[0]})
		var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		scene.fade_ticks = 0
		scene.conversation.controls_open = false
		if entry[0] == &"root_hollow_layered":
			scene.jump_to(Explore.DEBUG_SCENES["debug_scene_hollow"])
			for step: int in 40:
				scene.advance_fade()
			assert(scene.snapshot.scene_id == &"root_hollow_layered")
			scene.fade_phase = &""
		scene.prop_placements.clear() # ground-only approval; do not present borrowed props as finished art
		scene.core.player.position = entry[1]
		scene.snapshot = scene.core.snapshot()
		scene.conversation.controls_open = false
		if entry[2] == "combat":
			var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
			scene.core.set_story_flags(flags)
			for tick: int in 180:
				scene.advance(InputFrame.new())
				scene.fade_phase = &""
				if not scene.snapshot.telegraphs.is_empty():
					break
		scene._update_hud()
		scene._update_camera()
		scene.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png(OUT + "renderer_" + String(entry[2]) + ".png")
		var crop: Image = image.get_region(Rect2i(96,54,960,540))
		crop.resize(1280,720,Image.INTERPOLATE_NEAREST)
		crop.save_png(OUT + "gameplay_" + String(entry[2]) + "_4x.png")
		print("GROUND CAPTURE ",entry[2])
		scene.queue_free()
		await process_frame
	print("ROOT HOLLOW GROUND CAPTURES OK")
	quit()
