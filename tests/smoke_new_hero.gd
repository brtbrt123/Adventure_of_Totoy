extends SceneTree
const Arena := preload("res://presentation/arena/arena.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
var arena: Arena
var failures: Array[String] = []
var capture: bool = false

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func step(frame: InputFrame) -> void:
	arena.core.step(frame)
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()

func save(label: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_new_" + label + ".png") == OK, "capture " + label)

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	check(not capture or DisplayServer.get_name() != "headless", "capture needs window renderer")
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.core.boss.cooldown = 10000
	arena.core.player.position = Vector2(120, 110)
	step(InputFrame.new())
	await save("idle")
	arena.hud.prepare_portrait()
	var mask: Image = arena.hud.portrait_mask.get_image()
	check(mask.get_size() == Vector2i(44, 44), "portrait size")
	check(mask.get_pixel(0, 0).a == 0 and mask.get_pixel(22, 22).a == 1, "portrait circular clipping")
	for direction: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.RIGHT]:
		var move: InputFrame = InputFrame.new()
		move.move = direction
		for i: int in range(7):
			step(move)
		check(arena.facing_left == (direction != Vector2.RIGHT), "vertical movement changed facing")
		if direction == Vector2.LEFT:
			await save("walk_left")
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.LEFT
	step(attack)
	check(arena.facing_left, "attack aim did not turn left")
	# Every canvas uses its own feet point, including fractional world positions.
	for key: String in ArenaAnimation.all_names():
		if not key.begins_with("totoy_"):
			continue
		var frame: Dictionary = arena.frames[key]
		var at: Vector2 = Vector2(111.6, 109.2)
		var rect: Rect2 = ArenaAnimation.destination(at, frame, true)
		check(rect.position + Vector2(float(frame["w"]) - float(frame["ax"]), float(frame["ay"])) == at.round(), "mirrored foot does not meet rounded shadow: " + key)
	for i: int in range(9):
		step(InputFrame.new())
	check(arena.selected_frames[arena.snapshot.player.id] == "totoy_attack_active_right_2", "big slash fixture")
	await save("attack")
	for i: int in range(20):
		step(InputFrame.new())
	var dash: InputFrame = InputFrame.new()
	dash.dash_pressed = true
	dash.move = Vector2.LEFT
	step(dash)
	for i: int in range(4):
		step(InputFrame.new())
	check(arena.dash_ghosts.size() == 3, "three dash ghosts missing")
	var count: int = arena.dash_ghosts.size()
	arena.prepare_visuals()
	check(arena.dash_ghosts.size() == count, "same tick duplicates ghosts")
	await save("dash")
	for i: int in range(15):
		step(InputFrame.new())
	check(arena.dash_ghosts.is_empty(), "dash ghosts never expire")
	var parry: InputFrame = InputFrame.new()
	parry.parry_pressed = true
	step(parry)
	for i: int in range(10):
		step(InputFrame.new())
	check(arena.selected_frames[arena.snapshot.player.id] == "totoy_parry_right_3", "spark art fixture")
	await save("parry")
	arena.core.player.hp -= 25
	arena.core.boss.hp -= 30
	step(InputFrame.new())
	check(float(arena.hud.health_ghosts["player"]) > arena.snapshot.hud.player_hp, "player health ghost missing")
	check(float(arena.hud.health_ghosts["boss"]) > arena.snapshot.hud.boss_hp, "boss health ghost missing")
	await save("hud")
	for i: int in range(80):
		step(InputFrame.new())
	check(float(arena.hud.health_ghosts["player"]) == arena.snapshot.hud.player_hp, "health ghost did not drain")
	arena._restart()
	arena.core.player.hp = 1
	arena.core.boss.next_attack_override = &"gold_slam"
	arena.core.boss.cooldown = 1
	for i: int in range(100):
		step(InputFrame.new())
	check(arena.snapshot.player.state == &"dead" and arena.snapshot.result == &"defeat", "real death fixture")
	check(arena.missing_frames.is_empty(), "missing frame in hero sequence")
	# Core intentionally stops at the result. Document the interface limitation:
	# dead poses 2/3 are catalogued, but cannot advance from this frozen snapshot.
	var death_tick: int = arena.snapshot.tick
	step(InputFrame.new())
	check(arena.snapshot.tick == death_tick and arena.snapshot.player.state_ticks == 0, "terminal snapshot contract changed; revisit death animation")
	check(ArenaAnimation.frame_index(ArenaAnimation.PLAYER["dead"], 16) == 3 and ArenaAnimation.frame_index(ArenaAnimation.PLAYER["dead"], 100) == 3, "death cadence must hold final pose")
	await process_frame
	arena._restart()
	arena.core.boss.hp = 1
	arena.core.boss.cooldown = 10000
	arena.core.player.position = arena.core.boss.position - Vector2(30, 0)
	attack.aim = Vector2.RIGHT
	step(attack)
	for i: int in range(10):
		step(InputFrame.new())
	check(arena.snapshot.result == &"victory", "victory overlay fixture")
	await process_frame
	arena.queue_free()
	for message: String in failures:
		printerr("NEW HERO FAIL: " + message)
	print("NEW HERO SMOKE ", "OK" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
