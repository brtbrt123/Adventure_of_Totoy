extends SceneTree
## Live moved yard, without scene-data or collision overrides.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/batch_20261027/job1/"
var scene: Explore
var failed: bool = false


func _init() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	scene.toast_message = ""
	scene.toast_ticks = 0
	scene._update_hud()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(OUT + String(scene.snapshot.scene_id) + "_" + name + ".png") != OK:
		failed = true


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	for id: StringName in [&"village_layered"]:
		Engine.set_meta(Explore.START_META, {"scene": id})
		scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		root.size = Vector2i(1280, 720)
		scene.fade_phase = &""
		scene.dismiss_controls()
		scene.core.set_story_flags([&"seen_controls", &"received_first_sword", &"met_tovan", &"lesson_dash", &"lesson_attack"])
		var base: Vector2 = scene.core.training.base
		scene.core.place_at(base + Vector2(0, 24))
		scene.advance(Intent.new())
		await capture("yard")
		# Full map exposes both the old cleaned patch and the new post.
		scene.camera.enabled = false
		root.content_scale_size = Vector2i(scene.snapshot.size)
		root.size = Vector2i(scene.snapshot.size) * 2
		await capture("full_map")
		scene.camera.enabled = true
		root.content_scale_size = Vector2i(320, 180)
		root.size = Vector2i(1280, 720)
		for i: int in 250:
			scene.advance(Intent.new())
			if not scene.snapshot.telegraphs.is_empty() and scene.snapshot.tick == scene.snapshot.telegraphs[0].hit_tick - 10:
				break
		await capture("gold_warning")
		for i: int in 6:
			scene.advance(Intent.new())
		var parry: Intent = Intent.new()
		parry.parry_pressed = true
		scene.advance(parry)
		for i: int in 12:
			scene.advance(Intent.new())
			if scene.practice_effects.any(func(e: Dictionary) -> bool: return e["type"] == &"parry_succeeded"):
				break
		await capture("parry")
		for i: int in 250:
			scene.advance(Intent.new())
			if not scene.snapshot.telegraphs.is_empty() and scene.snapshot.telegraphs[0].kind == &"red" and scene.snapshot.tick == scene.snapshot.telegraphs[0].hit_tick - 10:
				break
		await capture("red_warning")
		var swing: Intent = Intent.new()
		swing.attack_pressed = true
		swing.aim = Vector2.UP
		scene.advance(swing)
		for i: int in 40:
			scene.advance(Intent.new())
			if int(scene.snapshot.training["since_hit"]) == 0:
				break
		await capture("post_hit")
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	print("LIVE VILLAGE YARD CAPTURES OK")
	quit(1 if failed else 0)
