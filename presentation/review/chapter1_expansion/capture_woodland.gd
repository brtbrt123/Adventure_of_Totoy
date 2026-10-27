extends SceneTree
const Preview := preload("res://presentation/review/chapter1_expansion/woodland_preview.gd")
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("WOODLAND CAPTURE requires windowed rendering")
		quit(1)
		return
	root.content_scale_size = Vector2i(640, 400)
	root.size = Vector2i(1280, 800)
	var view: Preview = Preview.new()
	root.add_child(view)
	await process_frame
	await _save("woodland_full")
	view.annotations = true
	view.queue_redraw()
	await _save("woodland_spaces")
	view.annotations = false
	view.queue_redraw()
	root.content_scale_size = Vector2i(320, 180)
	root.size = Vector2i(1280, 720)
	var camera: Camera2D = Camera2D.new()
	view.add_child(camera)
	for point: Vector2 in [Vector2(170, 260), Vector2(470, 260), Vector2(320, 125)]:
		camera.position = point
		await _save("woodland_view_%d_%d" % [int(point.x), int(point.y)])
	print("WOODLAND CAPTURE OK")
	quit(0)
func _save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://presentation/review/chapter1_expansion/" + label + ".png")
	if error != OK:
		printerr("WOODLAND CAPTURE FAIL: ", error)
		quit(1)
