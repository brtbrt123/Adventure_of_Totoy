extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/hero_unarmed_dash_v2/runtime/"
var scene: Explore
var failed: bool = false
func _init() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	scene.toast_ticks = 0
	scene._update_hud()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	failed = failed or root.get_texture().get_image().save_png(OUT + name + ".png") != OK
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	root.size = Vector2i(1280, 720)
	scene.fade_phase = &""
	scene.dismiss_controls()
	scene.core.place_at(Vector2(400, 200))
	scene.advance(Intent.new())
	await capture("idle_before")
	var dash: Intent = Intent.new()
	dash.move = Vector2.RIGHT
	dash.dash_pressed = true
	scene.advance(dash)
	for i: int in 6:
		failed = failed or scene.snapshot.hero.state != &"dash" or scene.hero_frame != "totoy_unarmed_dash_right_%d" % (i + 1)
		await capture("dash_%d" % (i + 1))
		scene.advance(Intent.new())
	await capture("idle_after")
	print("DASH V2 RUNTIME OK" if not failed else "DASH V2 RUNTIME FAILED")
	quit(1 if failed else 0)
