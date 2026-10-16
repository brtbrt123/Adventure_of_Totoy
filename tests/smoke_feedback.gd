extends SceneTree
const Arena := preload("res://presentation/arena/arena.gd")
const Effects := preload("res://presentation/arena/combat_effects.gd")
const Snapshots := preload("res://core/snapshots.gd")
var arena: Arena
var failures: Array[String] = []
var capture: bool = false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func save(label: String) -> void:
	if not capture:
		return
	arena.prepare_visuals()
	arena._update_hud()
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_feedback_" + label + ".png") == OK, "capture " + label)

func run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	if capture and DisplayServer.get_name() == "headless":
		printerr("FEEDBACK FAIL: capture requires a window")
		quit(1)
		return
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	var image: Image = arena.sprites.get_image()
	for n: int in range(1, 5):
		var frame: Dictionary = arena.frames["fx_beam_body_%d" % n]
		var strip: Rect2 = Effects.beam_strip(arena.sprites, frame)
		check(strip.size.x == 1.0 and strip.size.y > 1.0, "beam cross-section")
		for y: int in range(int(strip.position.y), int(strip.end.y)):
			check(image.get_pixel(int(strip.position.x), y).a == 1.0, "beam has transparent hole in frame %d" % n)
	var ground: Image = arena.ground_texture.get_image()
	for x: int in range(16, 320, 16):
		for y: int in range(176):
			check(ground.get_pixel(x - 1, y) == ground.get_pixel(x, y), "grass vertical seam")
	for y: int in range(16, 176, 16):
		for x: int in range(320):
			check(ground.get_pixel(x, y - 1) == ground.get_pixel(x, y), "grass horizontal seam")
	await save("layout")
	var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	tell.owner_id = arena.snapshot.entities[0].id
	tell.attack = &"red_shards"
	tell.kind = &"red"
	tell.shape = &"line"
	tell.center = Vector2(250, 115)
	tell.size = 178
	tell.width = 8
	tell.start_tick = 0
	tell.hit_tick = 60
	tell.end_tick = 68
	arena.snapshot.telegraphs.assign([tell])
	arena.snapshot.entities[0].state = &"attack"
	for direction: Vector2 in [Vector2.LEFT, Vector2(-1, -0.25).normalized()]:
		tell.direction = direction
		var polygon: PackedVector2Array = Effects.beam_body_polygon(tell)
		check(is_equal_approx(polygon[0].distance_to(polygon[3]), tell.width), "beam width")
		check(is_equal_approx(polygon[0].distance_to(polygon[1]), tell.size), "beam length")
		for n: int in range(4):
			arena.snapshot.tick = 60 + n * 2
			await save("laser_%s_%d" % ["left" if direction == Vector2.LEFT else "diagonal", n + 1])
	arena.queue_free()
	for message: String in failures:
		printerr("FEEDBACK FAIL: " + message)
	print("FEEDBACK SMOKE ", "OK" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
