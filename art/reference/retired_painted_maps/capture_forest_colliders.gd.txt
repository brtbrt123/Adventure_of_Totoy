extends SceneTree
## Draws the colliders and points of the forest route (core/forest_layout.gd) and the Stag glade
## (core/glade_layout.gd) over their converted ground paintings at the game scales (forest 0.6, glade 0.7), shown 3x,
## for checking that every circle sits on its painted prop and every point is in the open:
##   godot_console --headless --path . --script res://tests/capture_forest_colliders.gd
## Saves docs/previews/forest_colliders_overlay.png and docs/previews/glade_colliders_overlay.png.
## Colours: forest-edge circles blue, props orange, the root gate red; entry trigger green, exit trigger cyan (the
## forest's exit is behind the root gate at the top), the end of the forest's dead-end trail a magenta ring; spawns as circles of their body radius (mossling lime, boar pale tan, glowmoth
## lilac, the Stag violet), the player start white; interactables: yellow square on the prop's feet, a line to the
## yellow-ringed stand point; checkpoints pink crosses; the glade's fight area a thin white rectangle.
const ForestLayout := preload("res://core/forest_layout.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const Obstacle := preload("res://core/obstacle.gd")
const SCALE: int = 3
const BLUE: Color = Color(0.3, 0.6, 1.0)
const ORANGE: Color = Color(1.0, 0.55, 0.1)
const RED: Color = Color(1.0, 0.2, 0.25)
const GREEN: Color = Color(0.2, 1.0, 0.3)
const CYAN: Color = Color(0.2, 1.0, 1.0)
const MAGENTA: Color = Color(1.0, 0.3, 1.0)
const YELLOW: Color = Color(1.0, 1.0, 0.2)
const PINK: Color = Color(1.0, 0.55, 0.75)
const SPAWN_COLOURS: Dictionary = {"mossling": Color(0.7, 1.0, 0.2), "thornback_boar": Color(1.0, 0.9, 0.7),
	"glowmoth": Color(0.8, 0.6, 1.0)}


func _init() -> void:
	var ok: bool = _forest() and _glade()
	quit(0 if ok else 1)


func _forest() -> bool:
	var img: Image = _ground("res://presentation/forest/forest_route_ground.png")
	if img == null:
		return false
	var boundary: int = ForestLayout.boundary_centres().size()
	var list: Array[Obstacle] = ForestLayout.build()
	for i: int in list.size():
		var o: Obstacle = list[i]
		var colour: Color = BLUE if i < boundary else ORANGE
		if ForestLayout.is_gate(o):
			colour = RED
		_circle(img, o.center, o.radius, colour)
		_dot(img, o.center, colour)
	_rect(img, ForestLayout.ENTRY_RECT, GREEN)
	_rect(img, ForestLayout.EXIT_RECT, CYAN)
	_circle(img, ForestLayout.DEAD_END, 6.0, MAGENTA)
	_circle(img, ForestLayout.ENTRY_POINT, 6.0, Color.WHITE)
	_circle(img, ForestLayout.EXIT_POINT, 6.0, CYAN)
	for row: Array in ForestLayout.SPAWNS:
		var kind: String = row[0]
		_circle(img, Vector2(row[1], row[2]), ForestLayout.SPAWN_RADIUS[kind], SPAWN_COLOURS[kind])
		_dot(img, Vector2(row[1], row[2]), SPAWN_COLOURS[kind])
	_interactables(img, ForestLayout.INTERACTABLES)
	for p: Vector2 in ForestLayout.CHECKPOINTS:
		_cross(img, p, PINK)
	return _save(img, "res://docs/previews/forest_colliders_overlay.png", list.size(), boundary)


func _glade() -> bool:
	var img: Image = _ground("res://presentation/forest/stag_glade_ground.png")
	if img == null:
		return false
	var boundary: int = GladeLayout.boundary_centres().size()
	var list: Array[Obstacle] = GladeLayout.build()
	for i: int in list.size():
		var o: Obstacle = list[i]
		var colour: Color = BLUE if i < boundary else ORANGE
		_circle(img, o.center, o.radius, colour)
		_dot(img, o.center, colour)
	_rect(img, GladeLayout.ENTRY_RECT, GREEN)
	_rect(img, GladeLayout.EXIT_RECT, CYAN)
	_rect(img, GladeLayout.FIGHT_AREA, Color(1, 1, 1, 1))
	_circle(img, GladeLayout.PLAYER_START, 6.0, Color.WHITE)
	_circle(img, GladeLayout.EXIT_POINT, 6.0, CYAN)
	_circle(img, GladeLayout.STAG_START, GladeLayout.STAG_RADIUS, Color(0.75, 0.4, 1.0))
	_dot(img, GladeLayout.STAG_START, Color(0.75, 0.4, 1.0))
	_interactables(img, GladeLayout.INTERACTABLES)
	for p: Vector2 in GladeLayout.CHECKPOINTS:
		_cross(img, p, PINK)
	return _save(img, "res://docs/previews/glade_colliders_overlay.png", list.size(), boundary)


func _ground(path: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		printerr("cannot load " + path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	return img


func _save(img: Image, path: String, count: int, boundary: int) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/previews"))
	var err: Error = img.save_png(ProjectSettings.globalize_path(path))
	print("COLLIDERS %d circles (%d forest edge), saved %s (%s)" % [count, boundary, path, error_string(err)])
	return err == OK


func _interactables(img: Image, rows: Array) -> void:
	for row: Array in rows:
		var feet: Vector2 = Vector2(row[2], row[3])
		var stand: Vector2 = Vector2(row[4], row[5])
		_rect(img, Rect2(feet - Vector2(3, 3), Vector2(6, 6)), YELLOW)
		_line(img, feet, stand, YELLOW)
		_circle(img, stand, 6.0, YELLOW)


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


func _cross(img: Image, centre: Vector2, c: Color) -> void:
	var p: Vector2 = centre * SCALE
	for d: int in range(-6, 7):
		_plot(img, int(p.x) + d, int(p.y) + d, c)
		_plot(img, int(p.x) + d, int(p.y) - d, c)


func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps: int = maxi(1, int(a.distance_to(b) * SCALE))
	for k: int in steps + 1:
		var p: Vector2 = a.lerp(b, float(k) / float(steps)) * SCALE
		_plot(img, int(p.x), int(p.y), c)


func _rect(img: Image, r: Rect2, c: Color) -> void:
	var x0: int = int(r.position.x * SCALE)
	var y0: int = int(r.position.y * SCALE)
	var x1: int = int(r.end.x * SCALE) - 1
	var y1: int = int(r.end.y * SCALE) - 1
	for x: int in range(x0, x1 + 1):
		_plot(img, x, y0, c)
		_plot(img, x, y1, c)
	for y: int in range(y0, y1 + 1):
		_plot(img, x0, y, c)
		_plot(img, x1, y, c)
