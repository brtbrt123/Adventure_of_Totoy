extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const PropScene := preload("res://core/prop_scene.gd")
const Defs := preload("res://core/scene_defs.gd")
const Collision := preload("res://core/collision.gd")
const Obstacle := preload("res://core/obstacle.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/training_yard_relocation_v1/"
var scene: Explore
var failed: bool = false


func _init() -> void:
	call_deferred("run")


func clearance(obstacles: Array[Obstacle], base: Vector2) -> int:
	var count: int = 0
	for i: int in 32:
		var point: Vector2 = base - Vector2(0, 12) + Vector2.from_angle(TAU * i / 32.0) * 44
		if Collision.fits(obstacles, point, 6.0):
			count += 1
	return count


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	scene._update_hud()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(OUT + name + ".png") != OK:
		failed = true


func run() -> void:
	var fixture: Dictionary = PropScene.read_json(OUT + "village_layered_proposal.json")
	var defs: Dictionary = PropScene.load_defs()
	var obstacles: Array[Obstacle] = PropScene.build(fixture, defs)
	for npc: Dictionary in fixture["npcs"]:
		var obstacle: Obstacle = Obstacle.new()
		obstacle.center = Vector2(npc["position"][0], npc["position"][1])
		obstacle.radius = Defs.NPC_RADIUS
		obstacles.append(obstacle)
	var old: int = clearance(Defs.build_obstacles(&"village_layered"), Vector2(345, 118))
	var candidate: int = clearance(obstacles, Vector2(380, 180))
	var painted_at: Vector2 = Vector2.ZERO
	var painted_obstacles: Array[Obstacle] = Defs.build_obstacles(&"village")
	var nearest: float = INF
	for y: int in range(170, 241, 2):
		for x: int in range(340, 451, 2):
			var at: Vector2 = Vector2(x, y)
			if clearance(painted_obstacles, at) == 32 and at.distance_to(Vector2(390, 200)) < nearest:
				painted_at = at
				nearest = at.distance_to(Vector2(390, 200))
	var painted: int = clearance(painted_obstacles, painted_at)
	print("44px training ring: layered current %d/32, proposed %d/32; painted proposed %s: %d/32" % [old, candidate, str(painted_at), painted])
	if candidate < 30 or painted < 30 or not PropScene.validate(fixture, defs).is_empty():
		printerr("FAIL proposed yard clear space")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	root.size = Vector2i(1280, 720)
	scene.fade_phase = &""
	scene.dismiss_controls()
	# Fixture-only changes: official scene data and core source stay untouched.
	scene.core.def = PropScene.scene_def(fixture, &"village_layered", 6.0)
	scene.core.obstacles = obstacles
	scene.core.training.base = Vector2(380, 180)
	scene.core.set_flag(&"met_tovan")
	scene.core.set_flag(&"lesson_dash")
	scene.core.set_flag(&"lesson_attack")
	scene.core.place_at(Vector2(380, 204))
	scene.advance(Intent.new())
	scene.prop_placements = PropScene.placements(fixture, defs)
	scene._update_lighting()
	scene.toast_message = ""
	scene.toast_ticks = 0
	await capture("roomier_yard")
	# Receipt sample is a UI fixture, not a fabricated gameplay grant.
	scene.show_reward({"kind": &"weapon", "name": "Black Katana", "icon": "ui_weapon_sword_1", "quantity": 1})
	scene.reward_popup.advance(0.0)
	await capture("weapon_received")
	scene.reward_popup.advance(4.0)
	var swing: Intent = Intent.new()
	swing.attack_pressed = true
	swing.aim = Vector2.UP
	scene.advance(swing)
	for i: int in 40:
		scene.advance(Intent.new())
		if not scene.practice_view.slash_effect().is_empty():
			break
	await capture("swing_effect")
	for i: int in 250:
		scene.advance(Intent.new())
		if not scene.snapshot.telegraphs.is_empty() and scene.snapshot.tick == scene.snapshot.telegraphs[0].hit_tick - 5:
			var parry: Intent = Intent.new()
			parry.parry_pressed = true
			scene.advance(parry)
			break
	for i: int in 12:
		scene.advance(Intent.new())
		if scene.practice_effects.any(func(e: Dictionary) -> bool: return e["type"] == &"parry_succeeded"):
			break
	await capture("parry_effect")
	print("VILLAGE POLISH CAPTURES OK")
	quit(1 if failed else 0)
