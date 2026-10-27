extends SceneTree
const Fireflies := preload("res://presentation/common/ambient_fireflies.gd")
const Light := preload("res://presentation/common/environment_light.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/layered_forest/review/"

func _init() -> void:
	call_deferred("run")

func run() -> void:
	assert(Fireflies.drawables(&"village_layered", 0, Vector2(571,336)).is_empty())
	for id: StringName in [&"forest", &"glade", &"glade_layered"]:
		var a: Array[Dictionary] = Fireflies.drawables(id, 0, Vector2(560,336))
		var b: Array[Dictionary] = Fireflies.drawables(id, 120, Vector2(560,336))
		assert(a.size() == 22 and a == Fireflies.drawables(id, 0, Vector2(560,336)))
		assert(a[0]["pixel"] != b[0]["pixel"] and a[0]["pulse"] != b[0]["pulse"])
		for mote: Dictionary in b:
			assert(Rect2(Vector2.ZERO,Vector2(560,336)).has_point(mote["pixel"]))
			assert(mote["pulse"] >= 0.0 and mote["pulse"] <= 1.0)
		Engine.set_meta(Explore.START_META, {"scene": id})
		var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
		scene.set_physics_process(false)
		root.add_child(scene)
		await process_frame
		scene.fade_phase = &""
		scene.toast_ticks = 0
		assert(scene.material is ShaderMaterial)
		if id != &"forest":
			assert((scene.material as ShaderMaterial).get_shader_parameter("lamp_count") > 0)
		if "--capture" in OS.get_cmdline_user_args():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
			root.content_scale_size = Vector2i(scene.snapshot.size)
			root.size = Vector2i(scene.snapshot.size) * 2
			scene.camera.enabled = false
			for frame: int in range(18):
				scene.snapshot.tick = frame * 12
				scene.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(OUT + "%s_%02d.png" % [id,frame]) == OK)
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	print("NIGHT AMBIENCE OK: motion, pulse, bounds, scene scope, rune lights and renderer")
	quit()
