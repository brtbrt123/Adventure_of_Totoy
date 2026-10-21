extends SceneTree
## Draws the arena's solid colliders (core/arena_layout.gd) over the ground painting, 2x, for checking that every
## circle sits on its painted structure:
##   godot_console --headless --path . --script res://tests/capture_arena_colliders.gd
## Saves docs/previews/arena_colliders_overlay.png. Forest-edge circles are drawn blue, props orange, the altar red,
## the player and boss spawns (with their radii) white and violet.
const ArenaLayout := preload("res://core/arena_layout.gd")
const Obstacle := preload("res://core/obstacle.gd")
const Tuning := preload("res://core/tuning.gd")
const GROUND: String = "res://presentation/arena/arena_ground.png"
const OUT: String = "res://docs/previews/arena_colliders_overlay.png"
const SCALE: int = 2


func _init() -> void:
	var ground: Image = Image.load_from_file(ProjectSettings.globalize_path(GROUND))
	if ground == null or ground.is_empty():
		printerr("cannot load " + GROUND)
		quit(1)
		return
	ground.convert(Image.FORMAT_RGBA8)
	ground.resize(ground.get_width() * SCALE, ground.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var boundary: int = ArenaLayout.boundary_centres().size()
	var list: Array[Obstacle] = ArenaLayout.build()
	for i: int in list.size():
		var o: Obstacle = list[i]
		var colour: Color = Color(0.3, 0.6, 1.0)
		if i >= boundary:
			colour = Color(1.0, 0.55, 0.1)
		if o.feet == Vector2(ArenaLayout.ALTAR[0], ArenaLayout.ALTAR[1]):
			colour = Color(1.0, 0.2, 0.25)
		_circle(ground, o.center, o.radius, colour)
		_dot(ground, o.center, colour)
	_circle(ground, Tuning.PLAYER_START, Tuning.PLAYER_RADIUS, Color.WHITE)
	_circle(ground, Tuning.BOSS_START, Tuning.BOSS_RADIUS, Color(0.8, 0.5, 1.0))
	# the ARENA_MARGIN clamp
	var m: float = Tuning.ARENA_MARGIN
	var r: Rect2 = Rect2(Vector2(m, m), Tuning.ARENA_SIZE - Vector2(m, m) * 2.0)
	for x: int in range(int(r.position.x * SCALE), int(r.end.x * SCALE)):
		_plot(ground, x, int(r.position.y * SCALE), Color(1, 1, 1, 1))
		_plot(ground, x, int(r.end.y * SCALE), Color(1, 1, 1, 1))
	for y: int in range(int(r.position.y * SCALE), int(r.end.y * SCALE)):
		_plot(ground, int(r.position.x * SCALE), y, Color(1, 1, 1, 1))
		_plot(ground, int(r.end.x * SCALE), y, Color(1, 1, 1, 1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/previews"))
	var err: Error = ground.save_png(ProjectSettings.globalize_path(OUT))
	print("ARENA COLLIDERS %d circles (%d forest edge), saved %s (%s)" % [list.size(), boundary, OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _plot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _circle(img: Image, centre: Vector2, radius: float, c: Color) -> void:
	var steps: int = maxi(24, int(radius * SCALE * 7.0))
	for k: int in steps:
		var p: Vector2 = (centre + Vector2.RIGHT.rotated(TAU * k / steps) * radius) * SCALE
		_plot(img, int(p.x), int(p.y), c)


func _dot(img: Image, centre: Vector2, c: Color) -> void:
	var p: Vector2 = centre * SCALE
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			_plot(img, int(p.x) + dx, int(p.y) + dy, c)
