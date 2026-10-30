extends SceneTree
## Static ART proposal only. Core/data colliders are untouched and do not match this pending layout.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const OUT: String = "res://art/reference/root_hollow_v1/"
func _init() -> void:
	OS.set_environment("TOTOY_SAVE_PATH","res://art/build/arena_hollow_review_save.json")
	call_deferred("run")
func run() -> void:
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"imported_prop_geometry.json"))["props"]
	# Preview-only metadata override; production catalogue remains collision-matched.
	Explore.PropsLayer.art_metadata().merge(JSON.parse_string(FileAccess.get_file_as_string(OUT+"pending_prop_art.json"))["props"],true)
	var defs: Dictionary = Explore.PropScene.load_defs()["props"]
	var proposals: Array = JSON.parse_string(FileAccess.get_file_as_string(OUT+"proposed_placements.json"))["props"]
	for entry: Array in [["full",Vector2(320,200)],["central",Vector2(330,206)],["shrine",Vector2(108,100)],["pocket",Vector2(466,284)]]:
		var full: bool = entry[0] == "full"
		root.content_scale_size = Vector2i(640,400) if full else Vector2i(384,216)
		root.size = Vector2i(1280,800) if full else Vector2i(1152,648)
		Engine.set_meta(Explore.START_META,{"scene":&"root_hollow_layered"})
		var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		scene.conversation.controls_open = false
		scene.core.player.position = entry[1]
		scene.snapshot = scene.core.snapshot()
		scene.prop_placements.clear()
		for row: Dictionary in proposals:
			var type: String = row["type"]
			var source: Dictionary = geometry[type] if geometry.has(type) else defs[type]
			var size: Array = source.get("size",[source.get("w",0),source.get("h",0)])
			var anchor: Array = source["anchor"]
			scene.prop_placements.append({"id":StringName(row["id"]),"type":StringName(type),"feet":Vector2(row["feet"][0],row["feet"][1]),"anchor":Vector2(anchor[0],anchor[1]),"size":Vector2(size[0],size[1]),"flip":row["flip"]})
		scene._update_lighting()
		scene._update_hud()
		scene._update_camera()
		if full:
			scene.camera.position = Vector2(320,200)
			scene.camera.force_update_scroll()
			scene.get_node("HUD").hide()
		scene.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"props_renderer_"+String(entry[0])+".png")
		print("PROP PREVIEW ",entry[0])
		scene.queue_free()
		await process_frame
	print("ROOT HOLLOW SEPARATE PROP RENDER OK; COLLISION REGISTRATION STILL PENDING")
	quit()
