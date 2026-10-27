extends SceneTree
## Draws Lanternfen's colliders (core/village_layout.gd, the game's 0.7 layout: 571x336) over the village ground, 2x,
## for checking that every circle sits on its painted structure:
##   godot_console --headless --path . --script res://tests/capture_village_colliders.gd
## Saves docs/previews/village_colliders_overlay.png. Forest-edge circles are blue, props orange, the arrival and return
## spawns white (with the player radius), the gate cyan, the forest exit magenta (a bar across the road), the people's
## stand points green and the interactables (training dummy, chest, Edda's door) yellow.
const VillageLayout := preload("res://core/village_layout.gd")
const Obstacle := preload("res://core/obstacle.gd")
const Tuning := preload("res://core/tuning.gd")
const GROUND: String = "res://presentation/village/village_ground.png"
const OUT: String = "res://docs/previews/village_colliders_overlay.png"
const SCALE: int = 2
const INTERACTABLES: Array[StringName] = [&"chest", &"edda_door"]


func _init() -> void:
	var ground: Image = Image.load_from_file(ProjectSettings.globalize_path(GROUND))
	if ground == null or ground.is_empty():
		printerr("cannot load " + GROUND)
		quit(1)
		return
	ground.convert(Image.FORMAT_RGBA8)
	ground.resize(ground.get_width() * SCALE, ground.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var boundary: int = VillageLayout.boundary_circles().size()
	var list: Array[Obstacle] = VillageLayout.build()
	for i: int in list.size():
		var o: Obstacle = list[i]
		var colour: Color = Color(0.3, 0.6, 1.0) if i < boundary else Color(1.0, 0.55, 0.1)
		_circle(ground, o.center, o.radius, colour)
		_dot(ground, o.center, colour)
	# the walkable outline itself, thin and dark, so the circles can be judged against it
	var outline: PackedVector2Array = VillageLayout.boundary_scaled()
	for i: int in outline.size():
		_line(ground, outline[i], outline[(i + 1) % outline.size()], Color(0.1, 0.1, 0.5))
	for key: StringName in VillageLayout.STAND_POINTS:
		var p: Vector2 = VillageLayout.STAND_POINTS[key]
		var c: Color = Color(1.0, 0.95, 0.2) if INTERACTABLES.has(key) else Color(0.3, 1.0, 0.4)
		_circle(ground, p, Tuning.PLAYER_RADIUS, c)
		_dot(ground, p, c)
	_circle(ground, VillageLayout.ARRIVAL_SPAWN, Tuning.PLAYER_RADIUS, Color.WHITE)
	_dot(ground, VillageLayout.ARRIVAL_SPAWN, Color.WHITE)
	_circle(ground, VillageLayout.RETURN_SPAWN, Tuning.PLAYER_RADIUS, Color.WHITE)
	_dot(ground, VillageLayout.TRAINING_DUMMY, Color(1.0, 0.95, 0.2))
	_circle(ground, VillageLayout.GATE, 4.0, Color(0.2, 1.0, 1.0))
	_dot(ground, VillageLayout.GATE, Color(0.2, 1.0, 1.0))
	var e: Vector2 = VillageLayout.EXIT_FOREST
	var h: float = VillageLayout.EXIT_FOREST_HALF_WIDTH
	_line(ground, e + Vector2(0, -h), e + Vector2(0, h), Color(1.0, 0.2, 1.0))
	_line(ground, e + Vector2(-1, -h), e + Vector2(-1, h), Color(1.0, 0.2, 1.0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/previews"))
	var err: Error = ground.save_png(ProjectSettings.globalize_path(OUT))
	print("VILLAGE COLLIDERS %d circles (%d forest edge), saved %s (%s)" % [list.size(), boundary, OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _plot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _circle(img: Image, centre: Vector2, radius: float, c: Color) -> void:
	var steps: int = maxi(24, int(radius * SCALE * 7.0))
	for k: int in steps:
		var p: Vector2 = (centre + Vector2.RIGHT.rotated(TAU * k / steps) * radius) * SCALE
		_plot(img, int(p.x), int(p.y), c)


func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps: int = maxi(1, int(a.distance_to(b) * SCALE))
	for k: int in steps + 1:
		var p: Vector2 = a.lerp(b, float(k) / float(steps)) * SCALE
		_plot(img, int(p.x), int(p.y), c)


func _dot(img: Image, centre: Vector2, c: Color) -> void:
	var p: Vector2 = centre * SCALE
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			_plot(img, int(p.x) + dx, int(p.y) + dy, c)
