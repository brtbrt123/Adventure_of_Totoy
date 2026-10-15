extends RefCounted
## Snapshot-only drawing plans. Built headless too, so smoke tests exercise geometry.
const Snapshots := preload("res://core/snapshots.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const AFTERGLOW_TICKS: int = 10

static func pixel_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		result.append(point.round())
	return result

static func stroke(plan: Array[Dictionary], points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	plan.append({"points": pixel_points(points), "color": color, "width": width, "fill": false})

static func fill(plan: Array[Dictionary], points: PackedVector2Array, color: Color) -> void:
	var polygon: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in pixel_points(points):
		if polygon.is_empty() or polygon[polygon.size() - 1] != point:
			polygon.append(point)
	if polygon.size() > 1 and polygon[0] == polygon[polygon.size() - 1]:
		polygon.resize(polygon.size() - 1)
	if polygon.size() >= 3:
		plan.append({"points": polygon, "color": color, "width": 1.0, "fill": true})

static func disc(plan: Array[Dictionary], at: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		points.append(at + Vector2.from_angle(TAU * i / 24.0) * radius)
	fill(plan, points, color)

static func red(t: Snapshots.TelegraphSnapshot, tick: int, colors: Dictionary) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if tick < t.hit_tick or tick > t.end_tick + AFTERGLOW_TICKS:
		return plan
	var live: bool = tick <= t.end_tick
	var fade: float = 1.0 if live else 1.0 - float(tick - t.end_tick) / AFTERGLOW_TICKS
	var flicker: float = 0.90 + 0.05 * float(posmod(tick + t.id, 3))
	var bright: Color = colors["z"]
	var dark: Color = colors["A"]
	var cream: Color = colors["1"]
	if t.attack == &"red_shards" and t.shape == &"line":
		var end: Vector2 = t.center + t.direction * t.size
		var axis: PackedVector2Array = PackedVector2Array([t.center, end])
		# Translucent, broad floor light is deliberately separate from the opaque hit capsule.
		stroke(plan, axis, Color(bright, 0.045 * fade), t.width + 20.0)
		stroke(plan, axis, Color(bright, 0.08 * fade), t.width + 10.0)
		disc(plan, t.center, 30.0, Color(bright, 0.05 * fade))
		disc(plan, t.center, 19.0, Color(bright, 0.08 * fade))
		if live:
			fill(plan, TelegraphView.outline(t), dark)
			stroke(plan, axis, bright, maxf(1.0, t.width - 2.0))
			stroke(plan, axis, Color(cream, flicker), minf(2.0, t.width))
			# Small muzzle flash; the surrounding translucent light is cosmetic.
			disc(plan, t.center, minf(3.0, t.width * 0.5), cream)
			stroke(plan, PackedVector2Array([t.center + Vector2(0,-7), t.center + Vector2(0,7)]), Color(bright, 0.55), 1.0)
	elif t.attack == &"red_sweep" and t.shape == &"cone":
		var outline: PackedVector2Array = TelegraphView.outline(t)
		fill(plan, outline, Color(bright, (0.24 * flicker if live else 0.10) * fade))
		disc(plan, t.center, 24.0, Color(bright, 0.065 * fade))
		if live:
			stroke(plan, outline, dark, 1.0)
			stroke(plan, outline.slice(1, outline.size() - 1), bright, 1.0)
			disc(plan, t.center, 3.0, cream)
	return plan

static func slash(player: Snapshots.EntitySnapshot, colors: Dictionary) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var at: Vector2 = player.position - Vector2(0, 7)
	var angle: float = player.facing.angle()
	var ticks: int = player.state_ticks
	if player.state == &"attack_windup":
		var glint: Vector2 = (at + Vector2.from_angle(angle - PI / 3.0) * (12.0 + mini(ticks, 4))).round()
		var span: float = 1.0 + floorf(mini(ticks, 4) / 2.0)
		stroke(plan, PackedVector2Array([glint - Vector2(span,0), glint + Vector2(span,0)]), colors["1"])
		stroke(plan, PackedVector2Array([glint - Vector2(0,span), glint + Vector2(0,span)]), colors["o"])
		return plan
	var recovery: bool = player.state == &"attack_recovery"
	if player.state != &"attack_active" and not recovery:
		return plan
	if recovery and ticks >= 4:
		return plan
	var progress: float = 1.0 if recovery else clampf(float(ticks + 1) / 3.0, 0.0, 1.0)
	var fade: float = 1.0 - float(ticks + 1) / 5.0 if recovery else 1.0
	var tip: float = angle - PI / 3.0 + 2.0 * PI / 3.0 * progress
	var start: float = angle - PI / 3.0 + (float(ticks) * 0.12 if recovery else 0.0)
	for layer: int in range(3):
		var radius: float = 22.0 - layer * 2.0
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in range(25):
			points.append(at + Vector2.from_angle(lerpf(start, tip, i / 24.0)) * radius)
		var color: Color = colors["1"] if layer == 0 else colors["p" if layer == 1 else "o"]
		stroke(plan, points, Color(color, fade))
	if not recovery:
		for i: int in range(3):
			var direction: Vector2 = Vector2.from_angle(tip - i * 0.24)
			stroke(plan, PackedVector2Array([at + direction * 25.0, at + direction * (28.0 - i)]), colors["o"])
	return plan

static func draw_plan(canvas: Node2D, plan: Array[Dictionary]) -> void:
	for command: Dictionary in plan:
		var points: PackedVector2Array = command["points"]
		var color: Color = command["color"]
		if bool(command["fill"]):
			canvas.draw_colored_polygon(points, color)
		else:
			canvas.draw_polyline(points, color, float(command["width"]), false)
