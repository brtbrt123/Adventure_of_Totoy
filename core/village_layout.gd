extends RefCounted
## The layout of Lanternfen village (Chapter 1, scene S1): its size, where people stand, where the player arrives and
## leaves, and where it is solid. Static data only; nothing here draws.
##
## The ground (presentation/village/village_ground.png, 571x336) is the owner's painting
## art/reference/lanternfen_village_target.png converted to the palette by
## tools/art/make_village_ground_from_reference.py at --scale 0.7 (the human's choice on 2026-10-22: at the first size,
## 816x480, the characters looked tiny next to the painted buildings; see docs/previews/village_scale_options.png). Every
## building and prop is painted into it, so the obstacles below are colliders only (visual_id empty) placed on the
## painted things, the same scheme as core/arena_layout.gd. Check them on docs/previews/village_colliders_overlay.png
## (tests/capture_village_colliders.gd draws them on the ground).
##
## Coordinates: the *_1X tables are measured on the painting at scale 1.0 (816x480); the game uses SCALE (0.7). The plain
## constants (VILLAGE_SIZE, ARRIVAL_SPAWN, GATE, EXIT_FOREST, RETURN_SPAWN, STAND_POINTS, TRAINING_DUMMY) are the 0.7
## values rounded to whole pixels (tests/core/test_village_layout_scaled.gd checks they equal point_scaled(*_1X, SCALE)),
## and build() / boundary_circles() give the 0.7 colliders. build_scaled(s) and the *_scaled functions build any other
## scale (its ground: make_village_ground_from_reference.py --scale s). Every point, outline corner and collider radius
## scales; the player radius does not (it is the hero's, the same in every scene).
##
## Two kinds of colliders:
## - the forest edge: BOUNDARY_1X is the outline of the walkable clearing (the crossroads, the forge yard, the grass by
##   the house, the west lawn with the shrine and the barrels, the gate opening and the east road out of the village). A
##   chain of circles sits outside every edge, so the forest, the canopy, the low stone wall and the house body cannot be
##   entered. Where the outline turns inward (the gate opening) a full-size circle would bulge into the
##   walkable side, so such circles shrink to fit (see boundary_circles()).
## - SOLIDS_1X: the things standing inside the clearing (gate pillars and doors, forge, anvil, workbenches, barrels, the
##   house walls, the shrine, tree trunks, stone slabs, rubble, the training dummy, the lamp post).
## The village is about 1.8 camera views wide and 1.9 high (the camera shows 320x180).
const Obstacle := preload("res://core/obstacle.gd")

## The game's scale of the painting (1.0 = the 816x480 measuring size of the *_1X tables).
const SCALE: float = 0.7
const VILLAGE_SIZE: Vector2 = Vector2(571.0, 336.0)

## Where Totoy appears when he arrives: just inside the rune gate, facing the crossroads.
const ARRIVAL_SPAWN: Vector2 = Vector2(120.0, 199.0)
## The gate opening (between the left rune pillar and the closed door leaf): the way in from the mountain road.
const GATE: Vector2 = Vector2(117.0, 183.0)
## The east road leaves the village toward the forest (scene S2) at the right edge. EXIT_FOREST is the point at the
## edge; the road there is EXIT_FOREST_HALF_WIDTH px either side of it (a transition trigger later).
const EXIT_FOREST: Vector2 = Vector2(567.0, 218.0)
const EXIT_FOREST_HALF_WIDTH: float = 18.0
## Where Totoy appears when he comes back from the forest.
const RETURN_SPAWN: Vector2 = Vector2(546.0, 218.0)

## Stand points (feet) of the people and the interactables. Keys are stable ids for the story scripts.
const STAND_POINTS: Dictionary = {
	&"mira": Vector2(144.0, 206.0),  # by the gate, waiting for Totoy
	&"tovan": Vector2(316.0, 129.0),  # at the anvil, in front of the forge
	&"edda": Vector2(452.0, 165.0),  # beside her house door
	&"edda_door": Vector2(435.0, 164.0),  # in front of the house door (the door itself is solid: EDDA_DOOR)
	&"villager_elder": Vector2(172.0, 286.0),  # by the stone shrine
	&"villager_child": Vector2(253.0, 210.0),  # on the crossroads
	&"villager_worker": Vector2(337.0, 235.0),  # beside the crates and barrels
	&"chest": Vector2(112.0, 246.0),  # on the west lawn between the stone slab and the rubble
}

## The training post (its feet; it is solid, see SOLIDS_1X): Totoy tests the sword on it. Moved on 2026-10-27 from the forge yard (328,148)
## to the open ground south of the forge (the owner found the old spot cramped): the painted ground must have its old post erased and
## the post drawn here as an object (docs/CODEX_TASK_training_yard_move.md).
const TRAINING_DUMMY: Vector2 = Vector2(390.0, 212.0)
## Edda's house door (its threshold, the interaction's feet): solid since the human's playtest (2026-10-22, "why can I
## walk ... on the door"); the hero knocks from STAND_POINTS[&"edda_door"] in front of it.
const EDDA_DOOR: Vector2 = Vector2(435.0, 150.0)

# --- the same at scale 1.0 (816x480), where everything was measured on the painting ---
const VILLAGE_SIZE_1X: Vector2 = Vector2(816.0, 480.0)
const ARRIVAL_SPAWN_1X: Vector2 = Vector2(172.0, 284.0)
const GATE_1X: Vector2 = Vector2(167.0, 262.0)
const EXIT_FOREST_1X: Vector2 = Vector2(810.0, 312.0)
const EXIT_FOREST_HALF_WIDTH_1X: float = 26.0
const RETURN_SPAWN_1X: Vector2 = Vector2(780.0, 312.0)
const STAND_POINTS_1X: Dictionary = {
	&"mira": Vector2(206.0, 294.0),
	&"tovan": Vector2(452.0, 184.0),
	&"edda": Vector2(646.0, 236.0),
	&"edda_door": Vector2(621.0, 234.0),
	&"villager_elder": Vector2(246.0, 408.0),
	&"villager_child": Vector2(362.0, 300.0),
	&"villager_worker": Vector2(482.0, 336.0),
	&"chest": Vector2(160.0, 352.0),
}
const TRAINING_DUMMY_1X: Vector2 = Vector2(557.0, 303.0)
const EDDA_DOOR_1X: Vector2 = Vector2(621.0, 214.0)

## The walkable clearing's outline, clockwise (screen coordinates): the circles go on the outer side of each edge.
## It starts in the gate opening and runs along the gate wall, the middle tree, the forge yard, the house front (straight
## past the door: the doorway notch was closed on 2026-10-22, the door is solid), the east tree, out of the map along the
## east road, back along the south bushes, round the south path, the low stone wall at the south-west and up the west
## lawn.
const BOUNDARY_1X: Array[Vector2] = [
	Vector2(150, 240), Vector2(186, 236), Vector2(204, 250), Vector2(232, 246), Vector2(262, 238), Vector2(286, 228),
	Vector2(318, 212), Vector2(334, 188), Vector2(362, 162), Vector2(400, 156), Vector2(456, 152), Vector2(530, 152),
	Vector2(548, 168), Vector2(556, 214), Vector2(600, 218), Vector2(644, 224),
	Vector2(700, 224), Vector2(748, 202), Vector2(768, 210), Vector2(806, 238), Vector2(806, 276), Vector2(828, 276),
	Vector2(828, 350), Vector2(806, 352), Vector2(760, 364), Vector2(700, 406), Vector2(640, 410), Vector2(600, 414),
	Vector2(590, 452), Vector2(440, 458), Vector2(440, 470), Vector2(330, 470), Vector2(330, 456), Vector2(160, 456),
	Vector2(70, 392), Vector2(76, 340), Vector2(88, 300), Vector2(118, 284), Vector2(146, 264),
]
const BOUNDARY_RADIUS_1X: float = 20.0
## Distance between neighbouring boundary circles along an edge (well under the radius: the edge stays smooth).
const BOUNDARY_SPACING_1X: float = 12.0
## A boundary circle that has to shrink below this to stay out of the clearing is dropped.
const BOUNDARY_MIN_RADIUS: float = 3.0

## [what it is, centre x, centre y, radius]
const SOLIDS_1X: Array = [
	# the rune gate: the left pillar, the closed door leaf and the right pillar (the opening between them is the way in)
	["gate pillar", 144, 266, 10.0], ["gate door", 189, 252, 7.0], ["gate door", 203, 249, 7.0], ["gate pillar", 221, 246, 11.0],
	# the middle tree with the lantern, the bench under it and the stump
	["tree", 298, 214, 12.0], ["tree", 316, 214, 7.0],
	["bench", 342, 173, 10.0],
	["stump", 339, 238, 8.0],
	# the smithy: forge, anvil, workbench, the training post, the barrel and the shelf by the house
	["forge", 414, 140, 12.0], ["forge", 438, 140, 12.0], ["forge", 426, 120, 14.0],
	["anvil", 434, 166, 8.0],
	["workbench", 478, 140, 9.0], ["workbench", 498, 140, 9.0], ["workbench", 516, 138, 8.0],
	["training dummy", 557, 300, 5.0],
	["barrel", 526, 186, 12.0],
	["shelf", 574, 202, 11.0], ["shelf", 586, 205, 9.0],
	# Edda's house: the front wall right of the doorway and the side wall (the roof and body sit behind the boundary)
	["house", 660, 214, 11.0], ["house", 684, 214, 11.0], ["house", 706, 210, 11.0], ["house", 726, 200, 11.0],
	["house", 746, 192, 10.0],
	# the east tree with the lantern
	["tree", 790, 236, 13.0],
	# the two stone slabs on the grass below the house
	["slab", 662, 254, 9.0], ["slab", 680, 260, 10.0], ["slab", 698, 265, 9.0],
	["slab", 728, 240, 10.0], ["slab", 746, 247, 10.0], ["slab", 762, 254, 9.0],
	# the west lawn: two barrels, the red rubble, the tilted stone slab, the shrine and the lamp post
	["barrel", 127, 312, 10.0], ["barrel", 104, 332, 10.0],
	["rubble", 137, 363, 10.0],
	["slab", 176, 322, 8.0], ["slab", 191, 336, 8.0],
	["shrine", 200, 404, 11.0], ["shrine", 206, 422, 11.0],
	["lamp post", 286, 432, 5.0],
	# the south-east pile: rocks, barrels and the crate
	["rubble", 470, 385, 14.0], ["rubble", 470, 410, 12.0], ["barrels", 500, 395, 12.0], ["barrels", 522, 385, 12.0],
	["barrel", 546, 398, 10.0], ["crate", 530, 420, 14.0], ["barrel", 560, 432, 8.0], ["rubble", 575, 400, 12.0],
	["rubble", 598, 400, 10.0],
	# the standing stone pillar east of the pile
	["pillar", 725, 404, 10.0], ["pillar", 722, 384, 9.0],
]


## The solid colliders at SCALE, built fresh (a fixed layout: every call returns the same list).
static func build() -> Array[Obstacle]:
	return build_scaled(SCALE)


## The colliders of the village converted at `scale` (see the header): outline, circle radii and SOLIDS_1X scaled.
static func build_scaled(scale: float) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	for circle: Array in boundary_circles(scale):
		var at: Vector2 = circle[0]
		_add(list, at, float(circle[1]))
	for row: Array in SOLIDS_1X:
		_add(list, Vector2(row[1], row[2]) * scale, float(row[3]) * scale)
	return list


## The village size at `scale`: the ground PNG's size (round(816 * scale) x round(480 * scale)).
static func village_size_scaled(scale: float) -> Vector2:
	return Vector2(roundf(VILLAGE_SIZE_1X.x * scale), roundf(VILLAGE_SIZE_1X.y * scale))


## A point measured at scale 1.0 (ARRIVAL_SPAWN_1X, GATE_1X, a STAND_POINTS_1X entry, ...) at `scale`, rounded to whole
## pixels (the plain constants are point_scaled(*_1X, SCALE)).
static func point_scaled(p_1x: Vector2, scale: float) -> Vector2:
	return (p_1x * scale).round()


## STAND_POINTS_1X at `scale`, rounded (same keys; equals STAND_POINTS at SCALE).
static func stand_points_scaled(scale: float) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in STAND_POINTS_1X:
		out[key] = point_scaled(STAND_POINTS_1X[key] as Vector2, scale)
	return out


## The walkable outline (BOUNDARY_1X) at `scale` (not rounded: the colliders use it as is).
static func boundary_scaled(scale: float = SCALE) -> PackedVector2Array:
	var outline: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in BOUNDARY_1X:
		outline.append(v * scale)
	return outline


## The forest-edge circles as [centre, radius]: along every edge of the outline, BOUNDARY_RADIUS_1X * scale out, plus one
## on the outer bisector of each corner (and a few nearer the corner where the outline turns inward). A circle that
## would reach into the clearing (near an inward turn) shrinks to its distance from the outline, or is dropped.
## With `scale` the outline, the radius, the spacing and the inward-turn steps are scaled (the minimum radius is not).
static func boundary_circles(scale: float = SCALE) -> Array:
	var outline: PackedVector2Array = boundary_scaled(scale)
	var radius: float = BOUNDARY_RADIUS_1X * scale
	var candidates: Array[Vector2] = []
	var count: int = outline.size()
	for i: int in count:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % count]
		var prev: Vector2 = outline[(i - 1 + count) % count]
		var normal: Vector2 = _outward(a, b)
		var corner: Vector2 = (_outward(prev, a) + normal).normalized()
		candidates.append(a + corner * radius)
		if _is_inward_turn(prev, a, b):
			for d: float in [4.0, 8.0, 13.0]:
				candidates.append(a + corner * d * scale)
		var steps: int = maxi(1, ceili(a.distance_to(b) / (BOUNDARY_SPACING_1X * scale)))
		for s: int in range(1, steps):
			candidates.append(a.lerp(b, float(s) / float(steps)) + normal * radius)
	var out: Array = []
	for c: Vector2 in candidates:
		if Geometry2D.is_point_in_polygon(c, outline):
			continue
		var r: float = minf(radius, _distance_to_outline(c, outline))
		if r >= BOUNDARY_MIN_RADIUS:
			out.append([c, snappedf(r, 0.5) if r < radius else r])
	return out


## The distance from `p` to the nearest edge of `outline`.
static func _distance_to_outline(p: Vector2, outline: PackedVector2Array) -> float:
	var best: float = INF
	var count: int = outline.size()
	for i: int in count:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i + 1) % count])
		best = minf(best, p.distance_to(q))
	return best


## True where the clockwise outline turns toward the clearing (the solid side is a narrow wedge there).
static func _is_inward_turn(prev: Vector2, a: Vector2, b: Vector2) -> bool:
	var u: Vector2 = a - prev
	var v: Vector2 = b - a
	return u.x * v.y - u.y * v.x < 0.0


## The outer normal of a clockwise edge in screen coordinates (y down).
static func _outward(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = (b - a).normalized()
	return Vector2(d.y, -d.x)


static func _add(list: Array[Obstacle], centre: Vector2, radius: float) -> void:
	var o: Obstacle = Obstacle.new()
	o.id = list.size() + 1
	o.visual_id = &""  # the ground painting draws every structure
	o.feet = centre
	o.visual_scale = 1.0
	o.radius = radius
	o.center = centre
	list.append(o)
