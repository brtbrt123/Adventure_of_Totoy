extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Frame := preload("res://core/input_frame.gd")
const OUT: String = "res://presentation/review/root_hollow_final/"
func _init() -> void:
	OS.set_environment("TOTOY_SAVE_PATH","res://art/build/arena_hollow_final_save.json")
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1152,648)
	var cases: Array[Array] = [["full",Vector2(320,200)],["central",Vector2(330,206)],["charge_lane",Vector2(300,206)],["shrine",Vector2(108,100)],["gold_lunge",Vector2(112,110)],["pocket",Vector2(466,284)],["west_trail",Vector2(180,295)],["east_trail",Vector2(548,125)],["barrier_closed",Vector2(64,22)],["barrier_open",Vector2(64,22)],["ancient_behind",Vector2(320,85)],["ancient_front",Vector2(320,126)],["rootwall_behind",Vector2(43,36)],["rootwall_front",Vector2(25,65)]]
	for entry: Array in cases:
		var full: bool = entry[0] == "full"
		root.content_scale_size = Vector2i(640,400) if full else Vector2i(384,216)
		root.size = Vector2i(1280,800) if full else Vector2i(1152,648)
		Engine.set_meta(Explore.START_META,{"scene":&"root_hollow_layered"})
		var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		scene.conversation.controls_open = false
		if entry[0] == "barrier_open":
			scene.core.set_flag(&"cleared_hollow_center")
			scene.snapshot = scene.core.snapshot()
			scene._on_event(scene.GameEvent.new(scene.GameEvent.FLAG_SET,scene.snapshot.tick,{"flag":&"cleared_hollow_center"}))
		var barrier_type: StringName = &""
		for prop: Dictionary in scene.prop_placements:
			if prop["id"] == &"hollow_barrier": barrier_type = prop["type"]
		assert(barrier_type == (&"root_hollow_barrier_open" if entry[0] == "barrier_open" else &"root_hollow_barrier_closed"))
		scene.core.player.position = entry[1]
		scene.snapshot = scene.core.snapshot()
		if entry[0] in ["charge_lane","gold_lunge"]:
			var flags: Array[StringName] = [&"received_first_sword",&"debug_all_unlocked"]
			scene.core.set_story_flags(flags)
			for tick: int in 180:
				scene.advance(Frame.new())
				scene.fade_phase = &""
				var wanted: bool = entry[0] == "charge_lane" and not scene.snapshot.telegraphs.is_empty()
				for tell: Explore.Snapshots.TelegraphSnapshot in scene.snapshot.telegraphs:
					if entry[0] == "gold_lunge" and tell.kind == &"gold": wanted = true
				if wanted: break
		scene._update_hud()
		scene._update_camera()
		if full:
			scene.camera.position = Vector2(320,200)
			scene.camera.force_update_scroll()
		if full or "barrier" in entry[0] or "_behind" in entry[0] or "_front" in entry[0]:
			scene.get_node("HUD").hide()
		scene.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+String(entry[0])+".png")
		if "barrier" in entry[0]:
			var detail: Image = root.get_texture().get_image().get_region(Rect2i(48,0,288,216))
			detail.resize(576,432,Image.INTERPOLATE_NEAREST)
			detail.save_png(OUT+String(entry[0])+"_detail.png")
		print("ROOT HOLLOW LIVE CAPTURE ",entry[0]," barrier=",barrier_type)
		scene.queue_free()
		await process_frame
	quit()
