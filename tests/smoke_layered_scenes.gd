extends SceneTree
## Real Explore renderer + core-driven walking. Optional -- --capture saves ten village reviews.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const PropScene := preload("res://core/prop_scene.gd")
const PropsLayer := preload("res://presentation/common/props_layer.gd")
const InputFrame := preload("res://core/input_frame.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")
const Collision := preload("res://core/collision.gd")
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")
const OUT: String = "res://art/reference/layered_village/review/night_selected/"
var failures: Array[String] = []
var captures: Array[Dictionary] = []
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


func walk_to(point: Vector2) -> bool:
	var bot: ExploreBot = ExploreBot.new()
	if not bot.plan(scene.snapshot.size, scene.core.obstacles, scene.snapshot.hero.position, point):
		return false
	for tick: int in range(1800):
		scene.advance(bot.next_input(scene.snapshot.hero.position))
		if scene.snapshot.hero.position.distance_to(point) < 2.0:
			return true
		if scene.fade_phase != &"":
			return false
	return false


func index_of(items: Array[Dictionary], kind: StringName, id: StringName) -> int:
	for i: int in items.size():
		if items[i]["kind"] == kind and StringName(items[i]["id"]) == id:
			return i
	return -1


func review_side(id: StringName, behind: bool) -> void:
	var placement: Dictionary = {}
	for p: Dictionary in scene.prop_placements:
		if p["id"] == id:
			placement = p
	var feet: Vector2 = placement["feet"]
	var reached: bool = false
	for distance: int in [20, 30, 40, 50, 60]:
		for dx: int in [0, -12, 12, -24, 24]:
			var at: Vector2 = feet + Vector2(dx, -distance if behind else distance)
			if not Collision.fits(scene.core.obstacles, at, 7.0):
				continue
			if walk_to(at):
				reached = true
				break
		if reached:
			break
	var label: String = String(id) + ("_behind" if behind else "_front")
	expect(reached, "Walk to " + label)
	var items: Array[Dictionary] = scene.drawables()
	var prop: int = index_of(items, &"prop", id)
	var hero: int = index_of(items, &"hero", &"totoy")
	expect(prop >= 0 and hero >= 0 and ((hero < prop) if behind else (hero > prop)), "Depth: " + label)
	captures.append({"label": label, "feet": [scene.snapshot.hero.position.x, scene.snapshot.hero.position.y], "walked": reached})
	if "--capture" in OS.get_cmdline_user_args():
		scene.toast_ticks = 0
		scene.queue_redraw()
		scene._update_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "Save " + label)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	scene.set_physics_process(false)
	root.add_child(scene)
	await process_frame
	finish_fade()
	expect(scene.snapshot.scene_id == &"village_layered", "Loads via START_META")
	expect(scene.ground_texture(&"village_layered").get_size() == Vector2(571, 336), "Converted village ground")
	expect(scene.prop_placements.size() == 34, "All shared placements")
	expect(scene.snapshot.npcs.size() == 6, "Six NPCs")
	expect(scene.material is ShaderMaterial, "Overhead lighting material active")
	var light_material: ShaderMaterial = scene.material as ShaderMaterial
	expect(is_equal_approx(light_material.get_shader_parameter("shaft_slope"), EnvironmentLight.SHADOW_PROJECTION.x / EnvironmentLight.SHADOW_PROJECTION.y), "Light direction matches separate shadows")
	var moon_colour: Vector3 = light_material.get_shader_parameter("light_colour")
	expect(moon_colour.z > moon_colour.x + 0.2, "Night key light is cool moonlight")
	expect(light_material.get_shader_parameter("lamp_count") == 10, "Five visible fixtures plus their floor pools")
	var lamp_plan: Dictionary = EnvironmentLight.lamp_plan(scene.prop_placements)
	var lamp_points: PackedVector4Array = lamp_plan["points"]
	var found_post: bool = false
	for lamp: Vector4 in lamp_points:
		if Vector2(lamp.x, lamp.y).distance_to(Vector2(255, 217)) < 1.0 and lamp.w > 0:
			found_post = true
	expect(found_post, "Warm glow is attached to the actual hanging lamp")
	var actor_frame: Dictionary = {"w": 32, "h": 40, "ax": 12, "ay": 36}
	for flipped: bool in [false, true]:
		var projected: Transform2D = EnvironmentLight.actor_transform(Vector2(100, 80), actor_frame, flipped)
		expect((projected * Vector2(12, 36)).is_equal_approx(Vector2(100, 80)), "Actor shadow stays attached to feet in both facings")
		var head: Vector2 = projected * Vector2(12, 0)
		expect(head.x > 100 and head.y > 80, "Actor shadow falls down/right regardless of facing")
	scene.lighting_enabled = false
	scene._update_lighting()
	expect(scene.material == null, "Lighting toggle permits direct comparison")
	scene.lighting_enabled = true
	scene._update_lighting()
	var seen: Dictionary = {}
	for item: Dictionary in scene.drawables():
		if item["kind"] == &"object":
			expect(false, "No duplicate chest/door/dummy object sprite")
		if item["kind"] == &"prop":
			seen[item["id"]] = true
	# All frames exist even when off camera.
	for p: Dictionary in scene.prop_placements:
		expect(scene.frames.has(String(p["type"])), "Frame " + String(p["type"]))
	for p: Dictionary in scene.drawables():
		if p["kind"] == &"prop":
			expect(not Dictionary(p["cast_frame"]).is_empty(), "Separate shadow asset " + String(p["id"]))
	for id: StringName in [&"gate", &"forge", &"cottage", &"big_tree", &"east_tree"]:
		await review_side(id, true)
		await review_side(id, false)
	expect(walk_to(Vector2(104, 168)), "Walk to Mira")
	var input: InputFrame = InputFrame.new()
	input.interact_pressed = true
	scene.advance(input)
	expect(scene.bubbles.has(&"mira"), "E talks to Mira through core interaction")
	for object: Dictionary in scene.snapshot.objects:
		expect(walk_to(object["stand"]), "Walk to interaction " + String(object["id"]))
		scene.advance(InputFrame.new())
		expect(scene.snapshot.interact_target == object["id"], "Target interaction " + String(object["id"]))
	# Walk to the east exit through the real fade and scene transition.
	var bot: ExploreBot = ExploreBot.new()
	var exit: Dictionary = scene.snapshot.exits[0]
	expect(bot.plan(scene.snapshot.size, scene.core.obstacles, scene.snapshot.hero.position, Vector2.ZERO, exit["rect"]), "Plan east exit")
	for tick: int in range(2200):
		scene.advance(bot.next_input(scene.snapshot.hero.position))
		if scene.fade_phase != &"":
			break
	expect(scene.pending_scene == &"forest", "East exit requests forest")
	finish_fade()
	expect(scene.snapshot.scene_id == &"forest", "East exit loads forest")
	# New debug bindings use the existing fade path.
	for key: String in ["debug_scene_village_layered", "debug_scene_glade_layered"]:
		expect(InputMap.has_action(key), "Debug binding " + key)
		scene.jump_to(Explore.DEBUG_SCENES[key])
		finish_fade()
		expect(scene.snapshot.scene_id == Explore.DEBUG_SCENES[key], "Debug jump " + key)
	expect(scene.ground_texture(&"glade_layered").get_size() == Vector2(560, 336), "Runtime glade ground")
	expect((scene.material as ShaderMaterial).get_shader_parameter("lamp_count") == 10, "Five glade rune stones have their own teal glow")
	# Removed placements must vanish from rendering and collision together.
	for p: Dictionary in scene.prop_placements:
		expect(p["type"] != &"glade_log", "Owner removed the glade entrance log")
	if "--capture" in OS.get_cmdline_user_args():
		var file: FileAccess = FileAccess.open(OUT + "capture_positions.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(captures, "\t") + "\n")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("LAYERED SCENES OK: village props/NPCs/interactions/walking/depth/exit, debug jumps, glade log")
		quit(0)
	else:
		for failure: String in failures:
			printerr("FAIL: " + failure)
		quit(1)
