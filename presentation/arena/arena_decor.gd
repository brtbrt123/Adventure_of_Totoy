extends RefCounted
## Cosmetic decoration of the ruins arena drawn over the ground: a hand-placed list, nothing random, none of it solid
## (the solid colliders are core/arena_layout.gd). Anything that would stand on a collider or a spawn point is
## skipped, so decoration never hides a collision.
##
## Empty since 2026-10-21: the ground is now the owner's target painting converted to the palette
## (tools/art/make_arena_ground_from_reference.py), with the walls, pillars, rubble, bushes and flowers painted in.
## The old pieces (wall segments along the north edge, flower clusters, fallen stones, bushes) would have been drawn
## twice or floated off the painted structures. Add a piece here only for something the painting does not have.
const Tuning := preload("res://core/tuning.gd")

## [sprite, feet x, feet y, scale, mirrored]
const PIECES: Array = []


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
