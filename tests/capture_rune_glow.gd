extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1152,648)
	for entry: Array in [[&"forest_layered",Vector2(214,98),"forest"],[&"glade_layered",Vector2(255,95),"glade"]]:
		Engine.set_meta(Explore.START_META,{"scene":entry[0]})
		var scene: Explore=load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase=&""
		scene.conversation.controls_open=false
		scene.core.player.position=entry[1]
		scene.snapshot=scene.core.snapshot()
		scene._update_hud()
		scene._update_camera()
		scene.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://presentation/review/root_hollow_final/rune_glow_"+String(entry[2])+".png")
		print("RUNE GLOW CAPTURE ",entry[0])
		scene.queue_free()
		await process_frame
	quit()
