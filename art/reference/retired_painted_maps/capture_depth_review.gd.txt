extends SceneTree
## Windowed only (regular Godot exe): the depth occluders, the soft actor shadow and the colliders of the human's
## playtest (2026-10-22) in the real scenes. The exploration scene runs its own loop; for each shot the hero is put on
## a spot (behind or in front of a prop) or walked into a prop until the core stops him, then the window is saved as
## art/build/arena_depth_<label>.png (delete them after looking). The arena (presentation/arena/arena.tscn) is shot the
## same way with the hero behind a pillar and the altar. Prints the hero's feet and whether each spot is free.
##   Godot_v4.7.2-stable_win64.exe --path . --script res://tests/capture_depth_review.gd
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Arena := preload("res://presentation/arena/arena.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Collision := preload("res://core/collision.gd")
const InputFrameClass := preload("res://core/input_frame.gd")
const Tuning := preload("res://core/tuning.gd")

## [label, scene, hero feet, key held after placing (0 = none), frames held]
const SHOTS: Array = [
	["village_gate_behind", &"village", Vector2(115, 172), 0, 0],
	["village_gate_front", &"village", Vector2(120, 199), 0, 0],
	["village_tree_behind", &"village", Vector2(234, 142), 0, 0],
	["village_dummy_behind", &"village", Vector2(328, 137), 0, 0],
	["village_dummy_front", &"village", Vector2(328, 162), 0, 0],
	["village_east_tree_behind", &"village", Vector2(537, 158), 0, 0],
	["village_house_corner", &"village", Vector2(505, 160), KEY_W, 30],
	["village_lamp_behind", &"village", Vector2(198, 292), 0, 0],
	["village_pile_behind", &"village", Vector2(332, 254), 0, 0],
	["village_door_walk", &"village", Vector2(435, 175), KEY_W, 40],
	["glade_back_stone_behind", &"glade", Vector2(301, 133), 0, 0],
	["glade_left_stone_behind", &"glade", Vector2(226, 152), 0, 0],
	["glade_front_stone_behind", &"glade", Vector2(268, 218), 0, 0],
	["glade_pond_walk_north", &"glade", Vector2(300, 215), KEY_W, 50],
	["glade_pond_walk_east", &"glade", Vector2(240, 180), KEY_D, 50],
	["glade_stone_walk", &"glade", Vector2(268, 250), KEY_W, 40],
	["glade_arch", &"glade", Vector2(434, 100), 0, 0],
	["forest_gate_walk", &"forest", Vector2(372, 150), KEY_W, 60],
	["forest_pedestal_behind", &"forest", Vector2(382, 151), 0, 0],
	["forest_middle_tree_side", &"forest", Vector2(296, 156), KEY_W, 30],
	["forest_west_pedestal_side", &"forest", Vector2(330, 150), KEY_A, 30],
	["forest_signpost_side", &"forest", Vector2(170, 125), KEY_W, 30],
	["forest_pedestal_front", &"forest", Vector2(382, 182), 0, 0],
	["forest_gate_open_through", &"forest", Vector2(380, 80), 0, 0],
]
const ARENA_SHOTS: Array = [
	["arena_pillar_behind", Vector2(258, 384)],
	["arena_altar_behind", Vector2(392, 372)],
	["arena_pillar_front", Vector2(258, 420)],
	["arena_plaza_shadow", Vector2(312, 250)],
]

var scene: Node


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func key_event(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/build/arena_depth_" + label + ".png")


func run() -> void:
	Bindings.register()
	Engine.set_meta(Explore.START_META, {"scene": &"village", "entry": &"arrival"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	scene.change_scene = func(_path: String) -> void: pass
	root.add_child(scene)
	await frames(40)
	for shot: Array in SHOTS:
		var explore: Explore = scene as Explore
		var gate: bool = String(shot[0]).contains("gate_open")
		if explore.gate_open != gate:
			explore.toggle_gate()
		if explore.core.scene_id != shot[1]:
			explore.enter_scene(shot[1])
			explore.fade_phase = &""
		explore.toast_ticks = 0
		var at: Vector2 = shot[2]
		var free: bool = Collision.fits(explore.core.obstacles, at, Tuning.PLAYER_RADIUS)
		explore.core.place_at(at)
		explore.core.exiting = false
		await frames(2)
		if int(shot[3]) != 0:
			key_event(shot[3], true)
			await frames(int(shot[4]))
			key_event(shot[3], false)
		await frames(6)
		await save(shot[0])
		print("CAPTURE %s: %s placed %s (free %s) feet now %s" % [shot[0], shot[1], str(at), free, str(explore.snapshot.hero.position)])
	scene.queue_free()
	await frames(2)
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	arena.core.boss.cooldown = 100000
	for shot: Array in ARENA_SHOTS:
		var at: Vector2 = shot[1]
		arena.core.player.position = at
		arena.core.boss.position = Tuning.BOSS_START
		arena.core.step(InputFrameClass.new())
		arena.core.player.position = at
		arena.snapshot = arena.core.snapshot()
		arena._update_camera(true)
		arena.prepare_visuals()
		arena.particles.clear()
		arena.queue_redraw()
		for k: int in 3:
			await process_frame
		await save(shot[0])
		print("CAPTURE %s: arena feet %s (free %s)" % [shot[0], str(at), Collision.fits(arena.core.obstacles, at, Tuning.PLAYER_RADIUS)])
	print("DEPTH REVIEW done")
	quit(0)
