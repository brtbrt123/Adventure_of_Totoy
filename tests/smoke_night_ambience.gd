extends SceneTree
const Fireflies := preload("res://presentation/common/ambient_fireflies.gd")
const Light := preload("res://presentation/common/environment_light.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/layered_forest/review/"

var failures: Array[String] = []


func expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func _init() -> void:
	call_deferred("run")

func run() -> void:
	expect(Fireflies.drawables(&"village_layered", 0, Vector2(571,336)).is_empty(), "Village has no forest motes")
	for id: StringName in [&"forest_layered", &"glade_layered", &"forest_layered"]:
		var a: Array[Dictionary] = Fireflies.drawables(id, 0, Vector2(560,336))
		var b: Array[Dictionary] = Fireflies.drawables(id, 120, Vector2(560,336))
		expect(a.size() == 22 and a == Fireflies.drawables(id, 0, Vector2(560,336)), "Mote count and deterministic replay")
		if a.is_empty() or b.is_empty():
			continue
		expect(a[0]["pixel"] != b[0]["pixel"] and a[0]["pulse"] != b[0]["pulse"], "Motes move and pulse")
		for mote: Dictionary in b:
			expect(Rect2(Vector2.ZERO,Vector2(560,336)).has_point(mote["pixel"]), "Mote stays inside world bounds")
			expect(mote["pulse"] >= 0.0 and mote["pulse"] <= 1.0, "Pulse stays in range")
		Engine.set_meta(Explore.START_META, {"scene": id})
		var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
		scene.set_physics_process(false)
		root.add_child(scene)
		await process_frame
		scene.fade_phase = &""
		scene.toast_ticks = 0
		expect(scene.material is ShaderMaterial, "Night shader is active")
		if id != &"forest_layered" and scene.material is ShaderMaterial:
			expect((scene.material as ShaderMaterial).get_shader_parameter("lamp_count") > 0, "Glade and layered forest fixtures are present")
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
				expect(root.get_texture().get_image().save_png(OUT + "%s_%02d.png" % [id,frame]) == OK, "Capture writes PNG")
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	if not failures.is_empty():
		for failure: String in failures:
			printerr("FAIL " + failure)
		quit(1)
		return
	print("NIGHT AMBIENCE OK: motion, pulse, bounds, scene scope, rune lights and renderer")
	quit()
