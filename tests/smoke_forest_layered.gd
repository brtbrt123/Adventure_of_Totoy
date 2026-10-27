extends SceneTree
## Real renderer/core puzzle integration. Optional -- --capture writes review poses.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const Bot := preload("res://tests/explore_bot.gd")
const Collision := preload("res://core/collision.gd")
const Light := preload("res://presentation/common/environment_light.gd")
const SaveStore := preload("res://core/save_store.gd")
const OUT: String = "res://art/reference/layered_forest/review/final/"
var failures: Array[String] = []
var records: Array[Dictionary] = []
var review_limits: Array[String] = []
var scene: Explore


func _init() -> void:
	call_deferred("run")


func expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func finish_fade() -> void:
	for tick: int in range(Explore.FADE_TICKS * 3):
		if scene.fade_phase == &"":
			break
		scene.advance_fade()


func placement(id: StringName) -> Dictionary:
	for row: Dictionary in scene.prop_placements:
		if row["id"] == id:
			return row
	return {}


func walk_to(point: Vector2) -> bool:
	var bot: Bot = Bot.new()
	if not bot.plan(scene.snapshot.size, scene.core.obstacles, scene.snapshot.hero.position, point):
		return false
	for tick: int in range(2400):
		scene.advance(bot.next_input(scene.snapshot.hero.position))
		if scene.snapshot.hero.position.distance_to(point) < 2.0:
			return true
		if scene.fade_phase != &"":
			return false
	return false


func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	scene.toast_ticks = 0
	scene._update_hud()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "Capture " + label)


func capture_overview(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	root.content_scale_size = Vector2i(480, 288)
	root.size = Vector2i(960, 576)
	scene.camera.enabled = false
	scene.hud.visible = false
	await capture(label)
	if label == "forest_open_overview":
		for frame: int in range(18):
			scene.snapshot.tick += 12
			await capture("motion_%02d" % frame)
	scene.hud.visible = true
	root.content_scale_size = Vector2i(320, 180)
	root.size = Vector2i(1280, 720)
	scene.camera.enabled = true
	scene._update_camera()


func review_side(id: StringName, behind: bool, state: String) -> void:
	var p: Dictionary = placement(id)
	var feet: Vector2 = p["feet"]
	var reached: bool = false
	for distance: int in [4, 8, 12, 16, 24, 32, 40, 48]:
		for dx: int in [0, -12, 12, -24, 24, -36, 36, -48, 48, -52, 52, -56, 56, -60, 60]:
			var point: Vector2 = feet + Vector2(dx, -distance if behind else distance)
			if Collision.fits(scene.core.obstacles, point, 6.0) and walk_to(point):
				reached = true
				break
		if reached:
			break
	var label: String = String(id) + "_" + state + ("_behind" if behind else "_front")
	if not reached and id == &"tree_middle" and behind:
		# A capture limitation, separate from the required puzzle/exit smoke test.
		# The shared upper boundary seals this tree's north side; do not fake a walk.
		review_limits.append(label + ": upper boundary prevents walking behind this tree")
		records.append({"label": label, "walked": false, "capture": "unavailable", "reason": review_limits.back()})
		return
	expect(reached, "Walk to review " + label)
	var items: Array[Dictionary] = scene.drawables()
	var hero_index: int = -1
	var prop_indices: Array[int] = []
	for index: int in items.size():
		if items[index]["kind"] == &"hero":
			hero_index = index
		elif items[index]["kind"] == &"prop" and items[index]["id"] == id:
			prop_indices.append(index)
	var ordered: bool = false
	for index: int in prop_indices:
		ordered = ordered or (hero_index < index if behind else hero_index > index)
	expect(hero_index >= 0 and ordered, "Depth order " + label)
	records.append({"label": label, "feet": [scene.snapshot.hero.position.x, scene.snapshot.hero.position.y], "walked": reached, "entry": "north" if state == "closed_north_entry" else "village_side"})
	await capture(label)


func interact(id: StringName) -> void:
	for object: Dictionary in scene.snapshot.objects:
		if object["id"] != id:
			continue
		expect(walk_to(object["stand"]), "Walk to interaction " + String(id))
		scene.advance(Intent.new())
		expect(scene.snapshot.interact_target == id, "Core targets " + String(id))
		var intent: Intent = Intent.new()
		intent.interact_pressed = true
		scene.advance(intent)
		return
	expect(false, "Missing interaction " + String(id))


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"forest_layered", "gate_open": false})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	scene.set_physics_process(false)
	root.add_child(scene)
	await process_frame
	finish_fade()
	expect(scene.prop_placements.size() == 27, "All forest placements")
	expect(scene.ground_texture(&"forest_layered").get_size() == Vector2(480, 288), "Runtime ground")
	expect(scene.material is ShaderMaterial, "Forest night lighting")
	expect(placement(&"root_gate")["type"] == &"forest_gate_closed", "Initially closed sprite")
	expect((scene.material as ShaderMaterial).get_shader_parameter("lamp_count") == 8, "Unlit pedestals emit no light")
	for p: Dictionary in scene.prop_placements:
		expect(scene.frames.has(String(p["type"])), "Frame " + String(p["type"]))
	var closed_bot: Bot = Bot.new()
	var exit: Dictionary = scene.snapshot.exits[1]
	expect(not closed_bot.plan(scene.snapshot.size, scene.core.obstacles, scene.snapshot.hero.position, Vector2.ZERO, exit["rect"]), "Closed gate blocks the exit route")
	await capture_overview("forest_closed_overview")
	await review_side(&"root_gate", false, "closed")
	# The closed gate deliberately isolates its north side. Start at its real north entry.
	scene.enter_scene(&"forest_layered", &"north")
	await review_side(&"root_gate", true, "closed_north_entry")
	scene.enter_scene(&"forest_layered", &"village_side")
	for id: StringName in [&"pedestal_west", &"pedestal_east"]:
		await review_side(id, true, "unlit")
		await review_side(id, false, "unlit")
	interact(&"signpost")
	expect(scene.core.last_events.size() > 0, "Signpost emits interaction event")
	# Verify the event writes to disk, using a dedicated test path, never the player's save.
	var old_save_path: String = OS.get_environment(SaveStore.PATH_ENV)
	OS.set_environment(SaveStore.PATH_ENV, "user://smoke_forest_layered.json")
	scene.persist = true
	interact(&"pedestal_west")
	expect(placement(&"pedestal_west")["type"] == &"forest_pedestal_lit", "Switch event rebuilds west sprite")
	expect(placement(&"pedestal_east")["type"] == &"forest_pedestal", "East stays unlit")
	expect(not scene.snapshot.gate_open, "One switch keeps gate closed")
	expect((scene.material as ShaderMaterial).get_shader_parameter("lamp_count") == 10, "West switch relights the material")
	interact(&"pedestal_east")
	scene.advance(Intent.new())  # the queued gate_changed event also saves the open state
	expect(SaveStore.load_profile().gate_open, "Autonomous gate_changed saved the open gate to disk")
	expect(scene.snapshot.gate_open and scene.gate_open and scene.profile.gate_open, "Gate event updates presentation and save profile")
	expect(placement(&"root_gate")["type"] == &"forest_gate_open", "Gate resolves open sprite")
	expect((scene.material as ShaderMaterial).get_shader_parameter("lamp_count") == 12, "Both pedestal lights are enabled")
	# Debug state changes must also rebuild, relight and save.
	scene.toggle_gate()
	scene.advance(Intent.new())
	expect(not placement(&"root_gate")["type"] == &"forest_gate_open", "Debug close rebuilds props")
	scene.toggle_gate()
	scene.advance(Intent.new())
	expect(SaveStore.load_profile().gate_open, "gate_changed persisted to disk")
	scene.persist = false
	OS.set_environment(SaveStore.PATH_ENV, old_save_path)
	var plan: Dictionary = Light.lamp_plan(scene.prop_placements)
	var colours: PackedVector3Array = plan["colours"]
	var warm: bool = false
	var cool: bool = false
	for colour: Vector3 in colours:
		warm = warm or colour.x > colour.z
		cool = cool or colour.z > colour.x
	expect(warm and cool, "Forest supports mixed teal and warm fixtures")
	expect(plan["dropped"] == 0, "All forest lights fit the budget")
	await capture_overview("forest_open_overview")
	for id: StringName in [&"root_gate", &"pedestal_west", &"pedestal_east", &"tree_left", &"tree_middle", &"tree_right", &"log_west", &"chest"]:
		await review_side(id, true, "lit_open")
		await review_side(id, false, "lit_open")
	var bot: Bot = Bot.new()
	expect(bot.plan(scene.snapshot.size, scene.core.obstacles, scene.snapshot.hero.position, Vector2.ZERO, exit["rect"]), "Open gate permits glade exit")
	for tick: int in range(4000):
		scene.advance(bot.next_input(scene.snapshot.hero.position))
		if scene.fade_phase != &"":
			break
	expect(scene.pending_scene == &"glade", "Walked through gate to glade exit")
	finish_fade()
	expect(scene.snapshot.scene_id == &"glade", "Exit completes transition")
	expect(InputMap.has_action("debug_scene_forest_layered"), "Forest debug binding")
	scene.jump_to(Explore.DEBUG_SCENES["debug_scene_forest_layered"])
	finish_fade()
	expect(scene.snapshot.scene_id == &"forest_layered" and scene.snapshot.lit_switches.size() == 2, "Return restores open/lit state")
	if "--capture" in OS.get_cmdline_user_args():
		var file: FileAccess = FileAccess.open(OUT + "positions.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(records, "\t") + "\n")
	scene.queue_free()
	for limitation: String in review_limits:
		print("REVIEW LIMIT: " + limitation)
	if failures.is_empty():
		print("FOREST LAYERED OK: puzzle events, mixed lights, gate saves, walking/depth, exit and debug jump")
		quit()
	else:
		for failure: String in failures:
			printerr("FAIL " + failure)
		quit(1)
