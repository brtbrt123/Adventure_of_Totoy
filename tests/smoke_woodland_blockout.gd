extends SceneTree
const Preview := preload("res://presentation/review/chapter1_expansion/woodland_preview.gd")
var failures: int = 0
func _init() -> void:
	call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		printerr("WOODLAND FAIL: ", message)
		failures += 1
func _run() -> void:
	var view: Preview = Preview.new()
	root.add_child(view)
	await process_frame
	expect(int(view.data["size"][0]) == 640 and int(view.data["size"][1]) == 400, "approved blockout scale")
	expect(view.data["terrain"].size() == 25, "terrain fills the world")
	for row: Array in view.data["terrain"]:
		expect(row.size() == 40, "terrain row covers width")
		for key: String in row:
			expect(view.tiles.has(key), "tile exists: " + key)
	expect(view.items.size() >= 20, "separate depth-sorted forest props exist")
	expect(view.data["encounters"].size() == 3, "two fights and optional camp reserved")
	for zone: Dictionary in view.data["encounters"]:
		var r: Array = zone["rect"]
		var floor_rect: Rect2 = Rect2(r[0], r[1], r[2], r[3])
		expect(floor_rect.size.x >= 144 and floor_rect.size.y >= 96, "encounter minimum space")
		for item: Dictionary in view.items:
			expect(not floor_rect.intersects(item["rect"]), "visible prop obstructs mob floor: " + String(item["id"]))
	expect(view.frames.has("hero2_idle_right_1"), "hero marker uses the existing native-scale frame")
	view.queue_free()
	await process_frame
	print("WOODLAND BLOCKOUT OK" if failures == 0 else "WOODLAND BLOCKOUT FAILED")
	quit(0 if failures == 0 else 1)
