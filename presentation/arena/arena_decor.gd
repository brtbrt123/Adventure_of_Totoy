extends RefCounted
## Cosmetic decoration of the ruins arena: a broken wall along the north edge, flowers and grass in the corners, a few
## fallen stones on the worn parts of the plaza and bushes along the south edge. A small, hand-placed set; nothing is
## random. None of it is solid (the solid props are core/arena_layout.gd, drawn from the snapshot). Anything that would
## stand on a solid prop or a spawn point is skipped, so decoration never hides a collision.
const Tuning := preload("res://core/tuning.gd")

## [sprite, feet x, feet y, scale, mirrored]
const PIECES: Array = [
	# the ruined wall along the north edge, with gaps where it has fallen
	["prop_wall_5", 20, 40, 1.0, false], ["prop_wall_1", 58, 27, 1.0, false], ["prop_wall_2", 150, 27, 1.0, true],
	["prop_wall_1", 300, 27, 1.0, false], ["prop_wall_2", 500, 27, 1.0, false], ["prop_wall_1", 640, 27, 1.0, true],
	["prop_wall_6", 780, 40, 1.0, false], ["prop_wall_4", 14, 74, 1.0, false], ["prop_wall_3", 786, 80, 1.0, true],
	# flower clusters and grass tufts in the corners
	["prop_small_1", 70, 70, 1.0, false], ["prop_small_3", 84, 76, 1.0, true], ["prop_small_2", 726, 66, 1.0, false],
	["prop_small_1", 82, 440, 1.0, true], ["prop_small_4", 96, 446, 1.0, false], ["prop_small_2", 70, 428, 1.0, false],
	["prop_small_2", 720, 442, 1.0, true], ["prop_small_3", 734, 432, 1.0, false],
	# fallen stones on the worn, cracked parts of the plaza
	["prop_small_6", 230, 330, 1.0, false], ["prop_small_6", 570, 150, 1.0, true], ["prop_small_6", 506, 376, 1.0, false],
	["prop_small_6", 296, 108, 1.0, true],
	# bushes along the south edge, outside the walls
	["prop_nature_2", 200, 476, 1.0, false], ["prop_nature_1", 600, 474, 1.0, true],
]


## The decoration as drawables: {"name": sprite, "at": feet, "scale": Vector2}. `obstacles` are the core's solid props.
static func build(obstacles: Array) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for piece: Array in PIECES:
		var at: Vector2 = Vector2(piece[1], piece[2])
		if _blocked(at, obstacles):
			continue
		var s: float = piece[3]
		items.append({"name": str(piece[0]), "at": at, "scale": Vector2(-s if bool(piece[4]) else s, s)})
	return items


static func _blocked(at: Vector2, obstacles: Array) -> bool:
	for spawn: Vector2 in [Tuning.PLAYER_START, Tuning.BOSS_START]:
		if at.distance_to(spawn) < 44.0:
			return true
	for o: Variant in obstacles:
		if at.distance_to(o.center) < o.radius + 6.0:
			return true
	return false
