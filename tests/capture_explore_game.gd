extends SceneTree
## Windowed only (regular Godot exe): plays the exploration scene in its own real loop (_physics_process, key events
## through the input map): the village arrival, walking up to Mira and pressing E, the forge yard, walking out along the
## east road into the forest (the fade), the forest's second clearing, F6 + F4 to the glade ring, F5 to the arena.
## Saves art/build/arena_explore_*.png for a visual check (delete them afterwards). Not a harness test.
## Godot_v4.7.2-stable_win64.exe --path . --script res://tests/capture_explore_game.gd
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")

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


func tap(code: Key) -> void:
	key_event(code, true)
	await frames(2)
	key_event(code, false)
	await frames(2)


func hold(code: Key, count: int) -> void:
	key_event(code, true)
	await frames(count)
	key_event(code, false)


func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/build/arena_explore_" + label + ".png")
	print("CAPTURE %s: scene %s hero %s fade %.2f hint '%s'" % [label, scene.snapshot.scene_id if scene is Explore else &"arena", scene.snapshot.hero.position if scene is Explore else Vector2.ZERO, scene.fade_alpha() if scene is Explore else 0.0, scene.hud.hint_text if scene is Explore else ""])


func run() -> void:
	Bindings.register()
	Engine.set_meta(Explore.START_META, {"scene": &"village", "entry": &"arrival"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	scene.change_scene = func(path: String) -> void:
		scene.queue_free()
		scene = load(path).instantiate()
		root.add_child(scene)
	root.add_child(scene)
	await frames(30)
	await hold(KEY_D, 8)
	await frames(4)
	await save("village_arrival")
	# up to Mira and E
	scene.core.place_at(Vector2(176, 210))
	await hold(KEY_A, 14)
	await frames(2)
	await save("near_mira_hint")
	await tap(KEY_E)
	await frames(6)
	await save("mira_bubble")
	# the forge yard
	scene.core.place_at(Vector2(300, 160))
	await hold(KEY_D, 20)
	await frames(2)
	await save("forge_yard")
	scene.debug_enabled = true
	await frames(2)
	await save("forge_yard_debug")
	scene.debug_enabled = false
	# out along the east road
	scene.core.place_at(Vector2(530, 218))
	key_event(KEY_D, true)
	for i: int in 60:
		await physics_frame
		if scene.fade_phase == &"out" and scene.fade_ticks >= 8:
			break
	await save("crossing_fade")
	key_event(KEY_D, false)
	await frames(40)
	await save("forest_arrival")
	# the second clearing
	scene.core.place_at(Vector2(250, 186))
	await hold(KEY_S, 6)
	await frames(2)
	await save("forest_second_clearing")
	scene.core.place_at(Vector2(345, 150))
	await hold(KEY_W, 4)
	await frames(2)
	await save("forest_gate_closed")
	await tap(KEY_F6)
	await frames(2)
	await save("forest_gate_open_debug_toast")
	await tap(KEY_F4)
	await frames(45)
	scene.core.place_at(Vector2(262, 236))
	await hold(KEY_W, 10)
	await frames(2)
	await save("glade_ring")
	scene.core.place_at(Vector2(436, 100))
	await hold(KEY_W, 4)
	await frames(2)
	await save("glade_arch")
	await tap(KEY_F5)
	await frames(60)
	await save("arena_entrance")
	quit(0)
