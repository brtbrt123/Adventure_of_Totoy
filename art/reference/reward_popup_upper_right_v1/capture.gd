extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	root.size = Vector2i(1280, 720)
	scene.fade_phase = &""
	scene.dismiss_controls()
	for npc: Dictionary in scene.snapshot.npcs:
		if npc["id"] == &"tovan":
			scene.core.place_at(npc["position"] + Vector2(0, 16))
	scene.advance(Intent.new())
	var talk: Intent = Intent.new()
	talk.interact_pressed = true
	scene.advance(talk)
	var skip: Intent = Intent.new()
	skip.skip_pressed = true
	scene.advance(skip)
	scene.reward_popup.advance(0)
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://art/reference/reward_popup_upper_right_v1/preview.png")
	print("UPPER RIGHT RECEIPT CAPTURE ", result)
	quit(0 if result == OK else 1)
