extends SceneTree
## Windowed review of the same scene/hero position with the overhead light off/on.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/shadow_layers/"


func _init() -> void:
	call_deferred("run")


func run() -> void:
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	scene.set_physics_process(false)
	root.add_child(scene)
	await process_frame
	scene.fade_phase = &""
	scene.toast_ticks = 0
	scene.core.place_at(Vector2(440, 140))
	scene.advance(InputFrame.new())
	for enabled: bool in [false, true]:
		scene.lighting_enabled = enabled
		scene._update_lighting()
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var name: String = "night_selected_on.png" if enabled else "night_selected_off.png"
		assert(root.get_texture().get_image().save_png(OUT + name) == OK)
	print("LIGHT COMPARISON OK: identical world/hero, overhead off/on")
	quit()
