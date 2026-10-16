extends RefCounted
## Snapshot-only drawing plans. Built headless too, so smoke tests exercise geometry.
const Snapshots := preload("res://core/snapshots.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
static var beam_strips: Dictionary = {}
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
	var bright: Color = colors["x"] if t.kind == &"gold" else colors["z"]
	var dark: Color = colors["y"] if t.kind == &"gold" else colors["A"]
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

## Sword crescent and guard spark are already painted into the imported frames.
static func slash(_player: Snapshots.EntitySnapshot, _colors: Dictionary) -> Array[Dictionary]:
	return []

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

## Short cream core with sky spokes, triggered only by an attack_hit event.
static func hit_impact(at: Vector2, age: int, counter: bool, colors: Dictionary) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if age < 0 or age >= 3:
		return plan
	var radius: float = (6.0 if counter else 4.0) + age
	for i: int in range(8):
		var axis: Vector2 = Vector2.from_angle(TAU * i / 8.0)
		stroke(plan, PackedVector2Array([at + axis * (1 + age), at + axis * radius]), colors["1"] if i % 2 == 0 else colors["o"])
	if age == 0:
		disc(plan, at, 2.0, colors["p"])
	return plan

## Texture polygons are clipped to the snapshot's exact hit geometry, including
## the stomp's safe centre. UVs keep the imported effect centred on its anchor.
static func draw_imported_impact(canvas: Node2D, tell: Snapshots.TelegraphSnapshot, tick: int, frames: Dictionary, sprites: Texture2D) -> void:
	var age: int = tick - tell.hit_tick
	var pose: String = {&"gold_slam": "slam", &"gold_combo": "slam", &"red_sweep": "sweep", &"red_stomp": "stomp", &"red_charge": "charge", &"red_shards": "beam_body"}.get(tell.attack, "slam")
	var count: int = 4 if pose == "beam_body" else 6
	var key: String = "fx_%s_%d" % [pose, mini(count - 1, age / 2) + 1]
	if not frames.has(key):
		return
	var frame: Dictionary = frames[key]
	if tell.shape == &"line":
		if pose == "beam_body":
			draw_beam(canvas, tell, tick, frames, sprites)
		else:
			# Charge remains a lane effect; it is not a laser.
			var uv: PackedVector2Array = PackedVector2Array([Vector2(frame["x"], frame["y"]), Vector2(frame["x"] + frame["w"], frame["y"]), Vector2(frame["x"] + frame["w"], frame["y"] + frame["h"]), Vector2(frame["x"], frame["y"] + frame["h"])])
			for i: int in range(uv.size()):
				uv[i] /= sprites.get_size()
			canvas.draw_polygon(beam_body_polygon(tell), PackedColorArray([Color.WHITE]), uv, sprites)
		return
	if tell.shape == &"ring":
		for i: int in range(96):
			var a: Vector2 = Vector2.from_angle(TAU * i / 96.0)
			var b: Vector2 = Vector2.from_angle(TAU * (i + 1) / 96.0)
			_effect_polygon(canvas, sprites, PackedVector2Array([tell.center + a * tell.inner_size, tell.center + a * tell.size, tell.center + b * tell.size, tell.center + b * tell.inner_size]), tell, frame)
	else:
		var boundary: PackedVector2Array = TelegraphView.outline(tell)
		_effect_polygon(canvas, sprites, boundary.slice(0, boundary.size() - 1), tell, frame)

static func _effect_polygon(canvas: Node2D, sprites: Texture2D, polygon: PackedVector2Array, tell: Snapshots.TelegraphSnapshot, frame: Dictionary) -> void:
	var uv: PackedVector2Array = PackedVector2Array()
	var radius: float = maxf(1.0, tell.size)
	for point: Vector2 in polygon:
		var local: Vector2 = (point - tell.center).rotated(-tell.direction.angle() if tell.shape == &"cone" else 0.0)
		uv.append((Vector2(frame["x"] + frame["ax"], frame["y"] + frame["ay"]) + local / (radius * 2.0) * Vector2(frame["w"], frame["h"])) / sprites.get_size())
	canvas.draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, sprites)

## Use one opaque cross-section of the imported body: padded cells and changing
## start/end shapes can no longer punch gaps into the damaging lane.
static func beam_strip(sprites: Texture2D, frame: Dictionary) -> Rect2:
	var cache_key: String = "%d:%d:%d" % [sprites.get_instance_id(), frame["x"], frame["y"]]
	if beam_strips.has(cache_key):
		return beam_strips[cache_key]
	var image: Image = sprites.get_image()
	var x: int = int(frame["x"]) + int(frame["w"]) / 2
	var top: int = int(frame["y"])
	var bottom: int = top + int(frame["h"]) - 1
	while top < bottom and image.get_pixel(x, top).a == 0.0:
		top += 1
	while bottom > top and image.get_pixel(x, bottom).a == 0.0:
		bottom -= 1
	var strip: Rect2 = Rect2(x, top, 1, bottom - top + 1)
	beam_strips[cache_key] = strip
	return strip

static func beam_body_polygon(tell: Snapshots.TelegraphSnapshot) -> PackedVector2Array:
	var side: Vector2 = tell.direction.orthogonal() * tell.width * 0.5
	var end: Vector2 = tell.center + tell.direction * tell.size
	return PackedVector2Array([tell.center - side, end - side, end + side, tell.center + side])

static func draw_beam(canvas: Node2D, tell: Snapshots.TelegraphSnapshot, tick: int, frames: Dictionary, sprites: Texture2D) -> void:
	var age: int = maxi(0, tick - tell.hit_tick)
	var index: int = 1 + (age / 2) % 4
	var fade: float = 1.0 if tick <= tell.end_tick else clampf(1.0 - float(tick - tell.end_tick) / AFTERGLOW_TICKS, 0.0, 1.0)
	var tint: Color = Color(1, 1, 1, fade)
	var outline: PackedVector2Array = TelegraphView.outline(tell)
	canvas.draw_colored_polygon(outline.slice(0, outline.size() - 1), Color(Color("#e0463f"), fade))
	var region: Rect2 = beam_strip(sprites, frames["fx_beam_body_%d" % index])
	var uv: PackedVector2Array = PackedVector2Array([region.position, region.position + Vector2(region.size.x, 0), region.end, region.position + Vector2(0, region.size.y)])
	for i: int in range(uv.size()):
		uv[i] /= sprites.get_size()
	canvas.draw_polygon(beam_body_polygon(tell), PackedColorArray([tint]), uv, sprites)
	# End art overlays a continuous body, centred at its declared origin. Each
	# circle is wholly inside the snapshot capsule, so caps cannot enlarge damage.
	for part: String in ["start", "end"]:
		var frame: Dictionary = frames["fx_beam_%s_%d" % [part, index]]
		var origin: Vector2 = tell.center if part == "start" else tell.center + tell.direction * tell.size
		var polygon: PackedVector2Array = PackedVector2Array()
		var cap_uv: PackedVector2Array = PackedVector2Array()
		var extent: float = maxf(float(frame["w"]), float(frame["h"]))
		for i: int in range(48):
			var unit: Vector2 = Vector2.from_angle(TAU * i / 48.0)
			polygon.append(origin + unit.rotated(tell.direction.angle()) * tell.width * 0.5)
			var pixel: Vector2 = Vector2(frame["ax"], frame["ay"]) + unit * extent * 0.5
			pixel = pixel.clamp(Vector2.ZERO, Vector2(frame["w"] - 1, frame["h"] - 1))
			cap_uv.append((Vector2(frame["x"], frame["y"]) + pixel) / sprites.get_size())
		canvas.draw_polygon(polygon, PackedColorArray([tint]), cap_uv, sprites)
