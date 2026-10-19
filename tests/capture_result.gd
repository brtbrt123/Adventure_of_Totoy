extends SceneTree
## Windowed capture of the victory result screen: godot --path . --script res://tests/capture_result.gd
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	var events: Array[GameEvent] = []
	arena.core.boss.take_damage(99999, 1, events, 1)
	arena.core.step(InputFrame.new())
	arena.snapshot = arena.core.snapshot()
	arena._update_hud()
	arena.hud.result_lines = ["TIME 1:10.6", "NEW BEST!"]
	arena.hud.result_hint = "ESC: TITLE"
	arena.prepare_visuals()
	arena._update_hud()
	arena.queue_redraw()
	arena.hud.queue_redraw()
	for i: int in 3:
		await process_frame
	root.get_texture().get_image().save_png("res://art/build/arena_result_victory.png")
	quit(0)
