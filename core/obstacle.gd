extends RefCounted
## A solid, static circle in the arena (a pillar base, a tree trunk, a boulder). The core owns its position and
## radius; presentation draws `visual_id` from the same data. Foliage and other decoration are not solid.

var id: int = 0
## The art to draw (a sprite name such as prop_ruins_1), or empty for an extra collider of a larger prop.
var visual_id: StringName = &""
## Where the prop stands (its feet), the point presentation places the sprite by.
var feet: Vector2 = Vector2.ZERO
var visual_scale: float = 1.0
## The collision circle.
var center: Vector2 = Vector2.ZERO
var radius: float = 8.0
