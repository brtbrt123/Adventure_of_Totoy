extends SceneTree
## Run windowed: godot_console --path . --script res://tests/capture_boss_attacks.gd
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
var arena: Arena

func _init() -> void:
	call_deferred("_run")

func _save(path: String) -> bool:
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		printerr("BOSS CAPTURE FAIL: ", path, " ", error_string(error))
	return error == OK

func _capture_attack(attack: StringName, path: String, offset: int) -> bool:
	arena._restart()
	arena.core.boss.phase = 2
	arena.core.boss.position = Vector2(210, 100)
	arena.core.player.position = Vector2(120, 100)
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	for i: int in range(160):
		arena.core.step(InputFrame.new())
		arena.snapshot = arena.core.snapshot()
		arena._age_effects()
		arena.prepare_visuals()
		arena._update_hud()
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if tell.attack == attack and arena.snapshot.tick == tell.hit_tick + offset:
				if not arena.missing_frames.is_empty():
					printerr("BOSS CAPTURE FAIL: missing frames ", arena.missing_frames.keys())
					return false
				return await _save(path)
	printerr("BOSS CAPTURE FAIL: target tick missing for ", attack)
	return false

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("BOSS CAPTURE FAIL: windowed renderer required")
		quit(1)
		return
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	if packed == null:
		printerr("BOSS CAPTURE FAIL: arena cannot load")
		quit(1)
		return
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	# Strike smear, safe ring center, both gold warnings, and mid-rush dust.
	var captures: Array[Dictionary] = [
		{"attack": &"red_sweep", "path": "res://art/build/arena_sweep.png", "offset": 2},
		{"attack": &"red_stomp", "path": "res://art/build/arena_stomp.png", "offset": -8},
		{"attack": &"gold_combo", "path": "res://art/build/arena_combo.png", "offset": -8},
		{"attack": &"red_charge", "path": "res://art/build/arena_charge.png", "offset": 3},
	]
	for item: Dictionary in captures:
		if not await _capture_attack(item["attack"], item["path"], item["offset"]):
			arena.queue_free()
			quit(1)
			return
	arena.queue_free()
	print("BOSS CAPTURE OK")
	quit(0)
