extends SceneTree
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
var arena: Arena
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _step(frame: InputFrame) -> void:
	arena.core.step(frame)
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()

func _save(name_key: String) -> void:
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if name_key == "arena_flash":
		var torso: Vector2i = Vector2i(arena.snapshot.player.position.round()) + Vector2i(0, -15)
		var pure_white: bool = image.get_pixelv(torso) == Color.WHITE
		failed = failed or not pure_white
		print("PLAYER FLASH PIXEL ", "OK" if pure_white else "FAIL")
	var error: Error = image.save_png("res://art/build/" + name_key + ".png")
	failed = failed or error != OK
	print(name_key, " ", error_string(error))

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.core.boss.cooldown = 10000
	await _save("arena_hud")
	await _save("arena_hero2_idle")
	await _save("arena_bossbar")
	var frame: InputFrame = InputFrame.new()
	frame.attack_pressed = true
	frame.aim = Vector2.RIGHT
	_step(frame)
	for i: int in range(20):
		if arena.snapshot.player.state == &"attack_windup" and arena.snapshot.player.state_ticks == 4:
			await _save("arena_hero2_draw")
		if arena.snapshot.player.state == &"attack_active" and arena.snapshot.player.state_ticks == 1:
			await _save("arena_hero2_slash")
		_step(InputFrame.new())
	arena._restart()
	arena.core.player.position = arena.core.boss.position - Vector2(30, 0)
	arena.core.boss.next_attack_override = &"red_sweep"
	arena.core.boss.cooldown = 1
	var damage: bool = false
	for i: int in range(100):
		_step(InputFrame.new())
		for event: GameEvent in arena.core.last_events:
			if event.type == &"damage_taken" and int(event.data["entity_id"]) == arena.snapshot.player.id:
				damage = true
		if damage:
			await _save("arena_flash")
			break
	failed = failed or not damage
	arena._restart()
	arena.core.player.position = arena.core.boss.position - Vector2(30, 0)
	arena.core.boss.next_attack_override = &"gold_slam"
	arena.core.boss.cooldown = 1
	var opened: bool = false
	for i: int in range(120):
		var guard: InputFrame = InputFrame.new()
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if arena.snapshot.tick == tell.hit_tick - 2:
				guard.parry_pressed = true
		_step(guard)
		if arena.snapshot.hud.counter_window_ticks_left > 0:
			for j: int in range(12):
				_step(InputFrame.new())
			await _save("arena_bossbar")
			opened = true
			break
	failed = failed or not opened
	print("HERO PROFILE CAPTURE ", "FAIL" if failed else "OK")
	quit(1 if failed else 0)
