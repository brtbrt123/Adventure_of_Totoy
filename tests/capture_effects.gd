extends SceneTree
## Optional windowed capture of real core states, without advancing during capture.
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
var arena: Arena

func _init() -> void:
	call_deferred("_run")

func _step(frame: InputFrame) -> void:
	arena.core.step(frame)
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	arena._update_hud()
	arena.queue_redraw()

func _save(path: String) -> bool:
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		printerr("CAPTURE FAIL: ", error_string(error))
	return error == OK

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE FAIL: windowed renderer required")
		quit(1)
		return
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.core.boss.next_attack_override = &"red_shards"
	arena.core.boss.cooldown = 1
	var beam: bool = false
	for i: int in range(120):
		_step(InputFrame.new())
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if tell.attack == &"red_shards" and arena.snapshot.tick == tell.hit_tick + 1:
				beam = true
		if beam:
			break
	if not beam or not await _save("res://art/build/arena_beam.png"):
		quit(1)
		return
	arena._restart()
	arena.core.boss.cooldown = 10000
	arena.core.player.position = Vector2(180, 100)
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	_step(attack)
	for i: int in range(20):
		if arena.snapshot.player.state == &"attack_active" and arena.snapshot.player.state_ticks == 2:
			if await _save("res://art/build/arena_slash.png"):
				print("EFFECTS CAPTURE OK")
				quit(0)
			else:
				quit(1)
			return
		_step(InputFrame.new())
	printerr("CAPTURE FAIL: sword active state missing")
	quit(1)
