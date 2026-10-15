extends RefCounted
## Geometry only. Line attacks are capsules: core uses distance to a SEGMENT,
## so their round end caps are part of the hit area, not decorative extensions.
const Snapshots := preload("res://core/snapshots.gd")

static func outline(t: Snapshots.TelegraphSnapshot) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	match t.shape:
		&"circle":
			for i: int in range(97):
				points.append(t.center + Vector2.from_angle(TAU * i / 96.0) * t.size)
		&"cone":
			points.append(t.center)
			for i: int in range(65):
				var angle: float = t.direction.angle() - t.half_angle + 2.0 * t.half_angle * i / 64.0
				points.append(t.center + Vector2.from_angle(angle) * t.size)
			points.append(t.center)
		&"line":
			var end: Vector2 = t.center + t.direction * t.size
			for i: int in range(33):
				points.append(end + Vector2.from_angle(t.direction.angle() - PI / 2.0 + PI * i / 32.0) * t.width * 0.5)
			for i: int in range(33):
				points.append(t.center + Vector2.from_angle(t.direction.angle() + PI / 2.0 + PI * i / 32.0) * t.width * 0.5)
			points.append(points[0])
	return points

static func draw_warning(canvas: Node2D, t: Snapshots.TelegraphSnapshot, tick: int, bright: Color, dark: Color, ink: Color) -> void:
	var points: PackedVector2Array = outline(t)
	if points.size() < 3:
		return
	var progress: float = clampf(float(tick - t.start_tick) / maxf(1.0, float(t.hit_tick - t.start_tick)), 0.0, 1.0)
	var dangerous: bool = tick >= t.hit_tick and tick <= t.end_tick
	canvas.draw_colored_polygon(points.slice(0, points.size() - 1), Color(bright, 0.55 if dangerous else 0.10 + 0.20 * progress))
	canvas.draw_polyline(points, ink, 3.0)
	canvas.draw_polyline(points, bright if dangerous else dark, 1.0)
	# Growing bright perimeter conveys time without changing the warned area.
	var count: int = clampi(int(progress * (points.size() - 1)) + 1, 2, points.size())
	canvas.draw_polyline(points.slice(0, count), bright, 1.0)

static func draw_marker(canvas: Node2D, t: Snapshots.TelegraphSnapshot, bright: Color, ink: Color) -> void:
	var marker: Vector2 = t.center + Vector2(0, -12)
	if t.shape == &"circle":
		marker.y -= t.size
	marker = marker.clamp(Vector2(8, 37), Vector2(312, 143))
	var icon: PackedVector2Array
	if t.kind == &"gold":
		icon = PackedVector2Array([marker + Vector2(0,-5), marker + Vector2(5,0), marker + Vector2(0,5), marker + Vector2(-5,0), marker + Vector2(0,-5)])
	else:
		icon = PackedVector2Array([marker + Vector2(0,-6), marker + Vector2(6,5), marker + Vector2(-6,5), marker + Vector2(0,-6)])
	canvas.draw_colored_polygon(icon.slice(0, icon.size() - 1), bright)
	canvas.draw_polyline(icon, ink, 1.0)
	if t.kind != &"gold":
		canvas.draw_line(marker + Vector2(0,-2), marker + Vector2(0,1), ink)
		canvas.draw_rect(Rect2(marker + Vector2(0,3), Vector2.ONE), ink)
