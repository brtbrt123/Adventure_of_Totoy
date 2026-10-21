extends SceneTree
## Windowed capture of the Black Form cut-in at its key moments: godot --path . --script res://tests/capture_cutin.gd
## Saves art/build/arena_cutin_<time>.png (window-sized screenshots).
const Arena := preload("res://presentation/arena/arena.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.core.boss.cooldown = 100000
	arena.core.player.position = Vector2(120, 112)
	arena.core.boss.position = Vector2(236, 100)
	arena.core.player.edge = 100.0
	Input.action_press("arena_weapon_active")
	await physics_frame
	await process_frame
	Input.action_release("arena_weapon_active")
	var wanted: Array[float] = [0.02, 0.12, 0.25, 0.38, 0.45, 0.61, 0.65, 0.75, 0.92]  # preview seconds
	var shot: int = 0
	for i: int in 200:
		await physics_frame
		await process_frame
		if not arena.cutin.active:
			break
		if shot < wanted.size() and arena.cutin.preview_time() >= wanted[shot]:
			root.get_texture().get_image().save_png("res://art/build/arena_cutin_%02d.png" % shot)
			shot += 1
	print("CUTIN captured ", shot, " frames; active=", arena.cutin.active, " buff=", arena.snapshot.player.weapon_buff_active)
	quit(0)
