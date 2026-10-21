extends SceneTree
## Windowed capture of the camera view at a few places in the arena: godot --path . --script res://tests/capture_arena_view.gd
## Saves art/build/arena_view_<n>.png (window-sized).
const Arena := preload("res://presentation/arena/arena.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	arena.core.boss.cooldown = 100000
	var spots: Array = [Vector2(312, 250), Vector2(90, 90), Vector2(700, 400), Vector2(400, 120), Vector2(400, 390), Vector2(700, 90), Vector2(90, 400)]
	for i: int in spots.size():
		arena.core.player.position = spots[i]
		arena.core.step(InputFrameClass.new())
		arena.snapshot = arena.core.snapshot()
		arena._update_camera(true)
		arena.prepare_visuals()
		arena._update_hud()
		arena.queue_redraw()
		for k: int in 3:
			await process_frame
		root.get_texture().get_image().save_png("res://art/build/arena_view_%d.png" % i)
	quit(0)

const InputFrameClass := preload("res://core/input_frame.gd")
