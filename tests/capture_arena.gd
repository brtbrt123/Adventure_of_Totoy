extends SceneTree
## Optional WINDOWED capture: godot_console --path . --script res://tests/capture_arena.gd
## Writes only inside this workspace, and exits nonzero if capture is unavailable.
const Arena := preload("res://presentation/arena/arena.gd")

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE FAIL: run without --headless")
		quit(1)
		return
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	var arena: Arena = packed.instantiate() as Arena
	root.add_child(arena)
	for index: int in range(300):
		await physics_frame
		await process_frame
		if not arena.snapshot.telegraphs.is_empty():
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var error: Error = image.save_png("res://art/build/arena_preview.png")
			if error == OK:
				print("ARENA CAPTURE OK: art/build/arena_preview.png")
			else:
				printerr("CAPTURE FAIL: ", error_string(error))
			quit(0 if error == OK else 1)
			return
	printerr("CAPTURE FAIL: no telegraph observed")
	quit(1)
