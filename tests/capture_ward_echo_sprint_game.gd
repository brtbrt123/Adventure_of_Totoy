extends SceneTree
## Windowed only (regular Godot exe): plays the real arena like a player, with real key events through the input map
## and the arena's own _physics_process (nothing is stepped by hand): TAB opens the character menu, the arrows and ENTER
## slot Sprint (Z), Echo Step (X) and Stone Ward (C) through the scrolling aspect picker, TAB closes it, then Z / X / C
## are pressed in the fight. Saves art/build/arena_game_*.png for a visual check (delete them afterwards) and prints
## what happened. Not a harness test (the boss AI runs freely).
## Godot_v4.7.2-stable_win64.exe --path . --script res://tests/capture_ward_echo_sprint_game.gd
const Arena := preload("res://presentation/arena/arena.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")

var arena: Arena
var log_lines: Array[String] = []


func _init() -> void:
	call_deferred("run")


func note(text: String) -> void:
	log_lines.append(text)
	print("GAME: " + text)


func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func key_event(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


## A tap: down for one physics frame, then up.
func tap(code: Key) -> void:
	key_event(code, true)
	await frames(2)
	key_event(code, false)
	await frames(2)


func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/build/arena_game_" + label + ".png")


func slots() -> String:
	return str(arena.snapshot.player.equipped_aspects)


## In the open picker: arrows down `count` times, ENTER, then ESC (back to STATS).
func pick(count: int, label: String) -> void:
	for i: int in range(count):
		await tap(KEY_DOWN)
	await save("picker_" + label)
	await tap(KEY_ENTER)
	note("picker %s: selection %d scroll %d feedback %s -> slots %s" % [label, arena.character_menu.picker_selection, arena.character_menu.picker_scroll, str(arena.character_menu.picker_feedback), slots()])
	await tap(KEY_ESCAPE)


func run() -> void:
	Bindings.register()
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	await frames(10)
	arena.core.player.edge = 100.0  # a fresh fight has no Edge; the aspects cost 20-30
	var menu: Object = arena.character_menu
	await tap(KEY_TAB)
	note("menu open: %s" % menu.is_open)
	await tap(KEY_ENTER)  # first ENTER selects the weapon slot
	await tap(KEY_DOWN)
	await tap(KEY_LEFT)
	note("stats selection: %s" % menu.stats_selection)
	await tap(KEY_ENTER)
	note("picker open on slot %d" % menu.picker_slot)
	await pick(5, "z_sprint")  # breaking_edge (0) -> sprint (5)
	await tap(KEY_RIGHT)
	await tap(KEY_ENTER)
	note("picker open on slot %d" % menu.picker_slot)
	await pick(5, "x_echo")  # gale_cut (1) -> echo_step (6)
	await tap(KEY_RIGHT)
	await tap(KEY_ENTER)
	note("picker open on slot %d" % menu.picker_slot)
	await pick(5, "c_ward")  # moon_cleave (2) -> stone_ward (7)
	await save("menu_stats_new_three")
	await tap(KEY_TAB)
	note("menu closed: %s, slots %s" % [not menu.is_open, slots()])
	await frames(5)
	arena.core.player.edge = 100.0
	# Sprint: hold right, tap Z
	key_event(KEY_D, true)
	await frames(10)
	await tap(KEY_Z)
	note("sprint ticks left %d, move mult %.1f" % [arena.snapshot.player.sprint_ticks_left, arena.snapshot.player.move_speed_mult])
	await frames(20)
	await save("sprint_run")
	key_event(KEY_D, false)
	key_event(KEY_A, true)
	await frames(16)
	await save("sprint_turn")
	key_event(KEY_A, false)
	await frames(150)
	await save("sprint_over")
	# Echo Step: tap X, walk away, wait for the recall
	arena.core.player.edge = 100.0
	await tap(KEY_X)
	note("echoes %d" % arena.snapshot.echoes.size())
	await frames(14)
	await save("echo_placed")
	key_event(KEY_W, true)
	await frames(40)
	key_event(KEY_W, false)
	await save("echo_anchor")
	while not arena.snapshot.echoes.is_empty() and arena.snapshot.echoes[0].ticks_left > 14:
		await physics_frame
	await save("echo_countdown")
	var before: Vector2 = arena.snapshot.player.position
	while not arena.snapshot.echoes.is_empty():
		await physics_frame
	note("recall: %s -> %s, camera focus %s, i-frames %d" % [before, arena.snapshot.player.position, arena.camera_focus, arena.snapshot.player.echo_invuln_ticks])
	await save("echo_recall")
	await frames(4)
	await save("echo_arrive")
	# Stone Ward: walk to the boss, tap C, watch it block and release
	arena.core.player.edge = 100.0
	var boss: Vector2 = arena.snapshot.entities[0].position
	for i: int in range(240):
		var to_boss: Vector2 = boss - arena.snapshot.player.position
		if to_boss.length() < 46.0:
			break
		key_event(KEY_D, to_boss.x > 4.0)
		key_event(KEY_A, to_boss.x < -4.0)
		key_event(KEY_S, to_boss.y > 4.0)
		key_event(KEY_W, to_boss.y < -4.0)
		await physics_frame
		boss = arena.snapshot.entities[0].position
	for code: Key in [KEY_D, KEY_A, KEY_S, KEY_W]:
		key_event(code, false)
	await frames(2)
	await tap(KEY_C)
	note("ward state %s ticks %d" % [arena.snapshot.player.state, arena.snapshot.player.ward_ticks_left])
	await frames(14)
	await save("ward_raised")
	await frames(20)
	await save("ward_hold")
	var released: bool = false
	for i: int in range(40):
		await physics_frame
		for event: Object in arena.core.last_events:
			if event.type == &"ward_released":
				released = true
				note("ward released: %s" % str(event.data))
		if released:
			break
	await frames(5)
	await save("ward_shockwave")
	await frames(30)
	await save("ward_cracks")
	note("missing frames: %s" % str(arena.missing_frames.keys()))
	quit(0)
