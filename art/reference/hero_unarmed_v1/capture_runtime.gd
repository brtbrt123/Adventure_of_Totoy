extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/hero_unarmed_v1/runtime/"
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
	var result: Error = root.get_texture().get_image().save_png(OUT + String(scene.snapshot.scene_id) + "_" + name + ".png")
	failed = failed or result != OK
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	root.size = Vector2i(1280, 720)
	for id: StringName in [&"village_layered"]:
		Engine.set_meta(Explore.START_META, {"scene": id})
		scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		scene.dismiss_controls()
		scene.advance(Intent.new())
		await capture("arrival_unarmed")
		var move: Intent = Intent.new()
		move.move = Vector2.RIGHT
		for i: int in 8:
			scene.advance(move)
		await capture("walk_unarmed")
		move.dash_pressed = true
		scene.advance(move)
		await capture("dash_unarmed")
		for i: int in 40:
			scene.advance(Intent.new())
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
		await capture("sword_received_armed")
		failed = failed or not scene.snapshot.armed or not scene.hero_frame.begins_with("hero2_")
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	print("UNARMED RUNTIME CAPTURES OK" if not failed else "UNARMED CAPTURE FAILED")
	quit(1 if failed else 0)
