extends RefCounted
## One live skill attack owned by the core: a melee arc, a dash lane or a travelling projectile.
## It records which targets it already hit, so a cast hits each target at most once.

const SHAPE_ARC: StringName = &"arc"
const SHAPE_LANE: StringName = &"lane"
const SHAPE_PROJECTILE: StringName = &"projectile"

var id: int = 0
var owner_id: int = 0
var skill_id: StringName = &""
var shape: StringName = SHAPE_ARC
var position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var start: Vector2 = Vector2.ZERO
var end: Vector2 = Vector2.ZERO
var width: float = 0.0
var size: float = 0.0
var arc_dot: float = 0.0
var speed: float = 0.0
var travelled: float = 0.0
var length: float = 0.0
var start_tick: int = 0
var end_tick: int = 0
var hit_targets: Array[int] = []


func has_hit(target_id: int) -> bool:
	return hit_targets.has(target_id)


## True when the segment a-b passes within `reach` of `center`. Swept, so a fast mover cannot tunnel through.
static func segment_touches_circle(a: Vector2, b: Vector2, center: Vector2, reach: float) -> bool:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, a, b)
	return closest.distance_to(center) <= reach
