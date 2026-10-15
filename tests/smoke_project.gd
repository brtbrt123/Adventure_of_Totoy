extends SceneTree
## Headless smoke test: the project settings are right and the generated art loads.
## Run: godot_console --headless --path . --script res://tests/smoke_project.gd

const TILE_SIZE: int = 16

var _failures: Array[String] = []


func _init() -> void:
	_check_settings()
	_check_tileset()
	_check_sprite_atlas()
	if _failures.is_empty():
		print("SMOKE OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("SMOKE FAIL: ", message)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_settings() -> void:
	_expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 320, "viewport width is not 320")
	_expect(ProjectSettings.get_setting("display/window/size/viewport_height") == 180, "viewport height is not 180")
	_expect(ProjectSettings.get_setting("display/window/stretch/mode") == "viewport", "stretch mode is not viewport")
	_expect(ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "scale mode is not integer")
	_expect(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "default texture filter is not nearest")


func _check_tileset() -> void:
	var tile_set: TileSet = load("res://art/build/tileset.tres") as TileSet
	_expect(tile_set != null, "tileset.tres did not load")
	if tile_set == null:
		return
	_expect(tile_set.tile_size == Vector2i(TILE_SIZE, TILE_SIZE), "tileset tile_size is not 16x16")
	_expect(tile_set.get_source_count() == 1, "tileset should have exactly one atlas source")
	var source: TileSetAtlasSource = tile_set.get_source(tile_set.get_source_id(0)) as TileSetAtlasSource
	_expect(source != null, "tileset source 0 is not an atlas source")
	if source == null:
		return
	var expected_tiles: int = _tiles_json_count()
	_expect(expected_tiles > 0, "tiles.json missing or empty")
	_expect(source.get_tiles_count() == expected_tiles, "tileset has %d tiles, tiles.json lists %d" % [source.get_tiles_count(), expected_tiles])
	_expect(source.texture != null, "atlas source has no texture")


func _tiles_json_count() -> int:
	var file: FileAccess = FileAccess.open("res://art/build/tiles.json", FileAccess.READ)
	if file == null:
		return 0
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		var tiles: Dictionary = (data as Dictionary).get("tiles", {})
		return tiles.size()
	return 0


func _check_sprite_atlas() -> void:
	var texture: Texture2D = load("res://art/build/sprites.png") as Texture2D
	_expect(texture != null, "sprites.png did not load")
	var file: FileAccess = FileAccess.open("res://art/build/sprites.json", FileAccess.READ)
	_expect(file != null, "sprites.json could not be opened")
	if file == null or texture == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	_expect(data is Dictionary, "sprites.json is not a JSON object")
	if data is Dictionary:
		var frames: Dictionary = (data as Dictionary).get("frames", {})
		_expect(frames.has("totoy_idle_down"), "sprites.json has no totoy_idle_down frame")
