extends SceneTree
## Review-only resolution comparison. Does not change project settings or saves.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Canvas := preload("res://presentation/review/ui_compact_v1/review_canvas.gd")
const OUT: String = "res://art/reference/ui_resolution_comparison/"
var scene: Explore
var view: Canvas

class ComparisonCanvas extends Canvas:
	func _draw() -> void:
		if state != null and not colors.is_empty(): hud()

func _init() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size = Vector2i(320, 180)
	root.size = Vector2i(1280, 720)
	if Engine.has_meta(Explore.PERSIST_META): Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"woodland_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.core.set_flag(&"debug_all_unlocked")
	scene.core.set_flag(&"received_first_sword")
	scene.core.set_exp(95)
	scene.core.set_inventory({&"herb": 2})
	scene.core.place_at(Vector2(406, 262))
	var found: bool = false
	for tick: int in 240:
		scene.advance(Explore.InputFrame.new())
		for mob: Dictionary in scene.snapshot.mobs:
			if mob.get("type") == &"boar" and mob.get("state") == &"windup":
				found = true
		if found: break
	if not found:
		printerr("No boar charge windup found")
		quit(1)
		return
	scene.fade_phase = &""
	scene.conversation.controls_open = false
	scene._choose_frames()
	scene._update_camera()
	scene._update_hud()
	scene.get_node("HUD").hide()
	scene.progression_view.hide()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	view = ComparisonCanvas.new()
	view.colors = scene.colors
	view.portrait_atlas = scene.sprites
	view.ui_frames = scene.frames
	view.state = scene.snapshot
	view.hero_key = scene.hero_frame
	view.mode = "combat"
	layer.add_child(view)
	for base: Vector2i in [Vector2i(320, 180), Vector2i(384, 216)]:
		root.content_scale_size = base
		root.size = base * 4
		# Keep identical world center, native sprite scale and frozen charge tick.
		view.position = Vector2((base.x - 320) / 2, base.y - 180)
		scene.queue_redraw()
		view.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var im: Image = root.get_texture().get_image()
		var name: String = "%dx%d" % [base.x, base.y]
		if im.get_size() != base * 4:
			printerr("Wrong render dimensions")
			quit(1)
			return
		im.save_png(OUT + name + "_4x.png")
		im.resize(base.x, base.y, Image.INTERPOLATE_NEAREST)
		im.save_png(OUT + name + "_native.png")
	print("RESOLUTION COMPARISON OK: identical snapshot tick ", scene.snapshot.tick)
	quit(0)
