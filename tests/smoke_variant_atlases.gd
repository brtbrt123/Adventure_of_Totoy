extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_variant_atlases.gd
## The gold / white / dark copies of the sprite atlas are built by tools/art/build_art.py (they used to be recoloured
## pixel by pixel in the arena's _ready). This checks them pixel for pixel against the old runtime recolour
## (Arena.recolour_atlas, the same code the arena still uses as a fallback): every pixel has the same alpha, and every
## visible pixel the same colour (the colour of fully transparent pixels is not compared: Godot's import rewrites it
## around edges and it is never drawn). Also checks the arena loads the built copies.
const Arena := preload("res://presentation/arena/arena.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _palette() -> Dictionary:
	var colors: Dictionary = {}
	var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json")) as Dictionary
	for entry: Dictionary in palette.get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	return colors


## Number of pixels that differ (alpha anywhere, RGB where visible).
func _differences(expected: Image, actual: Image) -> int:
	if actual.get_format() != Image.FORMAT_RGBA8:
		actual.convert(Image.FORMAT_RGBA8)
	var a: PackedByteArray = expected.get_data()
	var b: PackedByteArray = actual.get_data()
	if a == b:
		return 0
	if a.size() != b.size():
		return -1
	var bad: int = 0
	for i: int in range(0, a.size(), 4):
		if a[i + 3] != b[i + 3]:
			bad += 1
		elif a[i + 3] != 0 and (a[i] != b[i] or a[i + 1] != b[i + 1] or a[i + 2] != b[i + 2]):
			bad += 1
	return bad


func _run() -> void:
	var colors: Dictionary = _palette()
	var frames: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json")) as Dictionary)["frames"]
	var sprites: Texture2D = load("res://art/build/sprites.png") as Texture2D
	var source: Image = sprites.get_image()
	for pair: Array in [[&"gold", Arena.GOLD_ATLAS], [&"white", Arena.WHITE_ATLAS], [&"dark", Arena.DARK_ATLAS]]:
		var built: Texture2D = load(pair[1]) as Texture2D
		check(built != null, "missing %s (run tools/art/build_art.py, then the Godot import)" % pair[1])
		if built == null:
			continue
		check(built.get_size() == sprites.get_size(), "%s is %s, the atlas %s (stale build)" % [pair[1], built.get_size(), sprites.get_size()])
		var expected: Image = Arena.recolour_atlas(source, pair[0], frames, colors)
		var bad: int = _differences(expected, built.get_image())
		check(bad == 0, "%s differs from the runtime recolour in %d pixel(s)" % [pair[1], bad])
	# the rules really change something (a guard against comparing the atlas with itself)
	check(_differences(source.duplicate() as Image, (load(Arena.GOLD_ATLAS) as Texture2D).get_image()) > 0, "the gold atlas equals the plain atlas")
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	var arena: Arena = packed.instantiate() as Arena
	root.add_child(arena)
	check(arena.gold_sprites.resource_path == Arena.GOLD_ATLAS and arena.white_sprites.resource_path == Arena.WHITE_ATLAS and arena.empowered_sprites.resource_path == Arena.DARK_ATLAS, "the arena does not load the built atlas copies")
	arena.queue_free()
	if failures.is_empty():
		print("VARIANT ATLASES OK")
		quit(0)
	else:
		for failure: String in failures:
			printerr("VARIANT ATLASES FAIL: " + failure)
		quit(1)
