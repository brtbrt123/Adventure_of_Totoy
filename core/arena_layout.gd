extends RefCounted
## The layout of the ruins arena: where the solid props stand. Everything solid is a circle; the core resolves the
## player and the boss against them (game_core.gd) and presentation draws the same list (snapshot.obstacles).
## Purely cosmetic decoration (flowers, rubble, the broken wall along the edge) lives in presentation.
##
## The plaza (tools/art/make_arena_ground.py) spans about x 64..736, y 48..432, with the stone ring around the middle
## (x 232..568, y 134..346). Inside the ring there is nothing solid: the fight has room. The pillars mark the plaza's
## corners and edges, the statue stands at its north end and the altar at its south end.
const Obstacle := preload("res://core/obstacle.gd")
const Tuning := preload("res://core/tuning.gd")

## [sprite, feet x, feet y, sprite scale, collider radius, collider centre above the feet]
const PROPS: Array = [
	# pillars at the four corners of the plaza
	["prop_ruins_1", 124, 104, 1.0, 7.0, 4.0], ["prop_ruins_2", 676, 104, 1.0, 7.0, 4.0],
	["prop_ruins_2", 124, 404, 1.0, 7.0, 4.0], ["prop_ruins_1", 676, 404, 1.0, 7.0, 4.0],
	# along the long edges: two whole pillars at the south, two broken ones at the north
	["prop_ruins_3", 256, 88, 1.0, 7.0, 4.0], ["prop_ruins_3", 544, 88, 1.0, 7.0, 4.0],
	["prop_ruins_1", 256, 412, 1.0, 7.0, 4.0], ["prop_ruins_2", 544, 412, 1.0, 7.0, 4.0],
	# the guardian statue at the north end, with a chest on either side
	["prop_statue_1", 400, 92, 1.0, 11.0, 5.0],
	["prop_chest_1", 360, 96, 1.0, 6.0, 3.0], ["prop_chest_1", 440, 96, 1.0, 6.0, 3.0],
	# a tree in each corner of the grass, outside the plaza
	["prop_nature_5", 40, 116, 2.0, 8.0, 6.0], ["prop_nature_4", 762, 112, 2.0, 8.0, 6.0],
	["prop_nature_6", 44, 452, 2.0, 8.0, 6.0], ["prop_nature_4", 758, 450, 2.0, 8.0, 6.0],
]
## The broken altar at the south end of the plaza: one sprite, three colliders along its base.
const ALTAR: Array = ["prop_ruins_5", 400, 428, 2.0]
const ALTAR_COLLIDERS: Array = [[-26.0, 12.0, 7.0], [0.0, 12.0, 7.0], [26.0, 12.0, 7.0]]  # x offset, radius, height above the feet
## Fallen columns lying near the west and east edges: one sprite, two colliders each.
const FALLEN: Array = [["prop_ruins_4", 96, 262, 1.0], ["prop_ruins_4", 706, 228, 1.0]]
const FALLEN_COLLIDERS: Array = [[-10.0, 8.0, 5.0], [10.0, 8.0, 5.0]]


## The solid props, built fresh (a fixed layout: every call returns the same list).
static func build() -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	for row: Array in PROPS:
		_add(list, StringName(row[0]), Vector2(row[1], row[2]), row[3], row[4], row[5])
	_add_wide(list, ALTAR, ALTAR_COLLIDERS)
	for fallen: Array in FALLEN:
		_add_wide(list, fallen, FALLEN_COLLIDERS)
	return list


## One sprite with several colliders along its base: the first collider carries the sprite, the others draw nothing.
static func _add_wide(list: Array[Obstacle], prop: Array, colliders: Array) -> void:
	var feet: Vector2 = Vector2(prop[1], prop[2])
	for i: int in colliders.size():
		var c: Array = colliders[i]
		_add(list, StringName(prop[0]) if i == 0 else &"", feet, prop[3], c[1], c[2], Vector2(c[0], 0.0))


static func _add(list: Array[Obstacle], visual: StringName, feet: Vector2, visual_scale: float, radius: float, height: float, shift: Vector2 = Vector2.ZERO) -> void:
	var o: Obstacle = Obstacle.new()
	o.id = list.size() + 1
	o.visual_id = visual
	o.feet = feet
	o.visual_scale = visual_scale
	o.radius = radius
	o.center = feet + shift + Vector2(0.0, -height)
	list.append(o)
