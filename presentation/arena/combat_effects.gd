extends RefCounted
## Snapshot-only drawing plans. Built headless too, so smoke tests exercise geometry.
const Snapshots := preload("res://core/snapshots.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
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
			var progress: float = clampf(float(tick - t.hit_tick + 1) / maxi(1, t.end_tick - t.hit_tick + 1), 0.0, 1.0)
			var tip: float = t.direction.angle() - t.half_angle + 2.0 * t.half_angle * progress
			for layer: int in range(3):
				var arc: PackedVector2Array = PackedVector2Array()
				for i: int in range(25):
					arc.append(t.center + Vector2.from_angle(lerpf(maxf(t.direction.angle() - t.half_angle, tip - t.half_angle), tip, i / 24.0)) * (t.size - layer * 2.0))
				stroke(plan, arc, cream if layer == 0 else colors["j"], 1.0)
	elif t.attack == &"red_stomp" and t.shape == &"ring":
		var progress: float = clampf(float(tick - t.hit_tick + 1) / maxi(1, t.end_tick - t.hit_tick + 1), 0.0, 1.0)
		var radius: float = lerpf(t.inner_size, t.size, progress)
		stroke(plan, TelegraphView.ring_points(t.center, radius), Color(cream, fade), 2.0)
		stroke(plan, TelegraphView.ring_points(t.center, maxf(t.inner_size, radius - 4.0)), Color(colors["j"], fade), 1.0)
	return plan

static func slash(player: Snapshots.EntitySnapshot, colors: Dictionary) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var at: Vector2 = player.position - Vector2(0, 7)
	var angle: float = player.facing.angle()
	var ticks: int = player.state_ticks
	if player.state == &"parry":
		var pose: int = ArenaAnimation.frame_index(ArenaAnimation.PLAYER["parry"], ticks)
		var origin: Vector2 = player.position - Vector2(8, 20)
		var grip: Vector2 = Vector2(10, 13) if pose == 1 else Vector2(7, 15)
		var tip_point: Vector2 = Vector2(14, 4) if pose == 1 else Vector2(13, 7)
		var glint: Vector2 = grip.lerp(tip_point, float(posmod(ticks, 7)) / 6.0)
		if ArenaAnimation.mirrored(player.facing):
			glint.x = 15.0 - glint.x
		glint = (origin + glint).round()
		stroke(plan, PackedVector2Array([glint - Vector2(1, 0), glint + Vector2(1, 0)]), colors["1"])
		if ticks < 3:
			stroke(plan, PackedVector2Array([glint - Vector2(0, 2), glint + Vector2(0, 2)]), colors["1"])
		return plan
	if player.state == &"attack_windup":
		# Shoulder hilt anchors the half-drawn blade.
		var side: float = -1.0 if ArenaAnimation.mirrored(player.facing) else 1.0
		var glint: Vector2 = player.position + Vector2(side * 6, -16)
		stroke(plan, PackedVector2Array([glint - Vector2(1,0), glint + Vector2(1,0)]), colors["h"])
		if ArenaAnimation.frame_index(ArenaAnimation.PLAYER["attack_windup"], ticks) == 2:
			stroke(plan, PackedVector2Array([glint, glint - Vector2(0, 4)]), colors["1"])
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
		# Two snapshot ticks of thin cream sell the blade leaving its sheath.
		if ticks < 2:
			var shoulder: Vector2 = player.position + Vector2(-5 if ArenaAnimation.mirrored(player.facing) else 5, -13)
			stroke(plan, PackedVector2Array([shoulder, at + player.facing * 24.0]), colors["1"])
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

## Recorded parry_succeeded events only; no inferred hit or timing rule.
static func parry_impact(at: Vector2, age: int, perfect: bool, colors: Dictionary) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var duration: int = 10 if perfect else 6
	if age < 0 or age >= duration:
		return plan
	var size: float = 1.5 if perfect else 0.85
	var radius: float = (3.0 + age * 1.6) * size
	stroke(plan, TelegraphView.ring_points(at, radius), colors["x"] if perfect else colors["y"])
	var count: int = 10 if perfect else 5
	for i: int in range(count):
		var direction: Vector2 = Vector2.from_angle(TAU * i / count + PI / 10.0)
		stroke(plan, PackedVector2Array([at + direction * radius, at + direction * (radius + (4.0 if age < 3 else 2.0) * size)]), colors["1"] if age < 2 else colors["x"])
	if age < 2:
		stroke(plan, PackedVector2Array([at - Vector2(0, 5) * size, at + Vector2(0, 5) * size]), colors["1"])
		stroke(plan, PackedVector2Array([at - Vector2(5, 0) * size, at + Vector2(5, 0) * size]), colors["1"])
	return plan
