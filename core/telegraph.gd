extends RefCounted
## A warned attack. The SAME geometry is drawn by presentation as the warning and used by the core to
## apply damage, so the warning always matches the real hit area. Aim is fixed when the attack commits.

const KIND_GOLD: StringName = &"gold"  # committed heavy attack: can be parried
const KIND_RED: StringName = &"red"  # must be dodged: parry does nothing

const SHAPE_CIRCLE: StringName = &"circle"  # center, size = radius
const SHAPE_CONE: StringName = &"cone"  # center = origin, direction, size = radius, half_angle
const SHAPE_LINE: StringName = &"line"  # center = start, direction, size = length, width

var id: int = 0
var owner_id: int = 0
var attack: StringName = &""
var kind: StringName = KIND_RED
var shape: StringName = SHAPE_CIRCLE
var center: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var size: float = 0.0
var half_angle: float = 0.0
var width: float = 0.0
var damage: int = 0
var start_tick: int = 0
var hit_tick: int = 0  # first tick the area is dangerous
var end_tick: int = 0  # last tick the area is dangerous (== hit_tick for an instant hit)
var has_hit: bool = false


func is_dangerous_at(tick: int) -> bool:
	return tick >= hit_tick and tick <= end_tick


func overlaps_circle(point: Vector2, radius: float) -> bool:
	match shape:
		SHAPE_CIRCLE:
			return point.distance_to(center) <= size + radius
		SHAPE_CONE:
			var to_point: Vector2 = point - center
			var dist: float = to_point.length()
			if dist > size + radius:
				return false
			if dist <= radius:
				return true
			var angle: float = absf(direction.angle_to(to_point))
			return angle <= half_angle + asin(minf(radius / dist, 1.0))
		SHAPE_LINE:
			var end_point: Vector2 = center + direction * size
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, center, end_point)
			return point.distance_to(closest) <= width * 0.5 + radius
	return false
