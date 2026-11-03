extends RefCounted
## Shared helpers for the walkable scenes (core/prop_scene.gd, core/arena_layout.gd): the forest-edge chain
## of circles along a walkable outline and a walkability test, the same construction as core/arena_layout.gd
## (boundary_centres) so every scene uses one collider model. Static functions only; no state.
const Obstacle := preload("res://core/obstacle.gd")


## The centres of the edge circles for a clockwise outline (screen coordinates, y down): along every edge, `radius`
## out from it every <= `spacing` px, plus one on the outer bisector of each corner so the chain has no gap there.
## Edges that lie on the world border (both ends on the same border line) get no circles: they are the scene's
## openings (entrances and exits), closed by the world bounds instead.
static func boundary_centres(outline: Array[Vector2], radius: float, spacing: float, size: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var count: int = outline.size()
	for i: int in count:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % count]
		var prev: Vector2 = outline[(i - 1 + count) % count]
		var normal: Vector2 = _outward(a, b)
		if _on_border(a, b, size):
			continue
		if _on_border(prev, a, size):
			out.append(a + normal * radius)  # the side of an opening: straight out from the edge's start
		else:
			var corner: Vector2 = (_outward(prev, a) + normal).normalized()
			out.append(a + corner * radius)
		var steps: int = maxi(1, ceili(a.distance_to(b) / spacing))
		for s: int in range(1, steps):
			out.append(a.lerp(b, float(s) / float(steps)) + normal * radius)
		if _on_border(b, outline[(i + 2) % count], size):
			out.append(b + normal * radius)  # the other side of an opening: straight out from the edge's end
	return out


## The radius of the edge circle at `centre`: `radius`, or less when the outline is nearer (beside a corner that
## juts into the walkable ground the full circle would reach across the next edge), so no edge circle ever covers
## walkable ground.
static func fit_radius(outline: Array[Vector2], centre: Vector2, radius: float) -> float:
	var best: float = radius
	var count: int = outline.size()
	for i: int in count:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % count]
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(centre, a, b)
		best = minf(best, centre.distance_to(p))
	return best


## Both ends on the same world border line (x = 0, x = size.x, y = 0 or y = size.y).
static func _on_border(a: Vector2, b: Vector2, size: Vector2) -> bool:
	return (is_zero_approx(a.x) and is_zero_approx(b.x)) or (is_equal_approx(a.x, size.x) and is_equal_approx(b.x, size.x)) \
		or (is_zero_approx(a.y) and is_zero_approx(b.y)) or (is_equal_approx(a.y, size.y) and is_equal_approx(b.y, size.y))


## The outer normal of a clockwise edge in screen coordinates (y down).
static func _outward(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = (b - a).normalized()
	return Vector2(d.y, -d.x)


## Appends one collider (visual_id empty: the ground painting draws every structure).
static func add(list: Array[Obstacle], centre: Vector2, radius: float, feet: Vector2) -> void:
	var o: Obstacle = Obstacle.new()
	o.id = list.size() + 1
	o.visual_id = &""
	o.feet = feet
	o.visual_scale = 1.0
	o.radius = radius
	o.center = centre
	list.append(o)


## True when a circle of `radius` at `point` is inside the world and touches no collider.
static func is_free(obstacles: Array[Obstacle], size: Vector2, point: Vector2, radius: float) -> bool:
	if point.x < radius or point.y < radius or point.x > size.x - radius or point.y > size.y - radius:
		return false
	for o: Obstacle in obstacles:
		if point.distance_to(o.center) < o.radius + radius:
			return false
	return true
