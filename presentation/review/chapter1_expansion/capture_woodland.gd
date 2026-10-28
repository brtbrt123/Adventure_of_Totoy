extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"woodland_layered"})
	var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	scene.get_node("HUD").hide()
	scene.camera.enabled = false
	root.content_scale_size = Vector2i(640,400)
	root.size = Vector2i(1280,800)
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://presentation/review/chapter1_expansion/woodland_full.png")
	print("WOODLAND CAPTURE OK" if error == OK else "WOODLAND CAPTURE FAIL")
	quit(0 if error == OK else 1)
