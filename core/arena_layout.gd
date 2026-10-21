extends RefCounted
## The layout of the ruins arena: where it is solid. Everything solid is a circle; the core resolves the player and
## the boss against them (game_core.gd) and presentation receives the same list (snapshot.obstacles).
##
## Since 2026-10-21 the ground (presentation/arena/arena_ground.png) is the owner's target painting converted to the
## palette (tools/art/make_arena_ground_from_reference.py): every structure is painted into it, so these obstacles are
## colliders only (visual_id empty) placed on the painted structures. Check them on
## docs/previews/arena_colliders_overlay.png (tests/capture_arena_colliders.gd draws the circles on the ground).
##
## Two kinds of colliders:
## - the forest edge: BOUNDARY is the outline of the walkable clearing (the plaza inside its ruined walls, the gaps in
##   the west and east walls and the dirt path out to the east). A chain of overlapping circles of BOUNDARY_RADIUS sits
##   just outside every edge, so the dense forest and the walls on the outline cannot be entered. The arena size, the
##   ARENA_MARGIN clamp and the camera are unchanged.
## - SOLIDS: the props standing inside the clearing (the statue shrine and its chests, pillars, fallen columns, rubble
##   piles, the broken south walls) and the altar (ALTAR, one prop with several colliders along its base).
## The rune ring and the raised platform in the middle are walkable (nothing solid between x 150 and 650 for y 120..360
## except the props listed below near the plaza's edges).
const Obstacle := preload("res://core/obstacle.gd")
const Tuning := preload("res://core/tuning.gd")

## The walkable clearing's outline, clockwise (screen coordinates): the circles go on the outer side of each edge.
const BOUNDARY: Array[Vector2] = [
	Vector2(110, 88), Vector2(246, 88), Vector2(262, 76), Vector2(372, 74), Vector2(430, 74), Vector2(546, 76),
	Vector2(556, 88), Vector2(694, 88), Vector2(694, 200), Vector2(744, 206), Vector2(744, 276), Vector2(694, 280),
	Vector2(694, 418), Vector2(108, 418), Vector2(108, 276), Vector2(76, 270), Vector2(76, 200), Vector2(110, 192),
]
const BOUNDARY_RADIUS: float = 36.0
## Distance between neighbouring boundary circles along an edge (well under the radius: the edge stays smooth).
const BOUNDARY_SPACING: float = 24.0

## [what it is, centre x, centre y, radius]
const SOLIDS: Array = [
	# the statue shrine at the north end and the chest on either side of it
	["statue", 396, 80, 16.0], ["statue", 396, 60, 14.0],
	["chest", 361, 83, 7.0], ["chest", 438, 83, 7.0],
	# north-west: the lantern pillar and two fallen column blocks
	["pillar", 131, 101, 7.0],
	["fallen column", 158, 101, 8.0], ["fallen column", 175, 98, 8.0],
	["fallen column", 147, 131, 6.0], ["fallen column", 160, 128, 6.0],
	["rubble", 135, 153, 6.0],
	# north-east: the fallen column below the wall, the mossy pillar, the broken pillar stub
	["fallen column", 630, 95, 7.0], ["fallen column", 645, 100, 7.0],
	["pillar", 667, 96, 7.0],
	["pillar", 671, 150, 7.0],
	# east: the fallen column across the wall gap beside the dirt path
	["fallen column", 674, 221, 8.0], ["fallen column", 690, 221, 8.0], ["fallen column", 704, 222, 7.0],
	# west: the fallen column piece in the wall gap
	["fallen column", 88, 245, 7.0], ["fallen column", 103, 252, 6.0],
	# south-west: a fallen block, the rubble pile, the pillar, the broken wall and the pillar beside the altar
	["fallen column", 122, 337, 7.0], ["fallen column", 138, 343, 7.0],
	["rubble", 134, 360, 9.0], ["rubble", 158, 366, 10.0], ["rubble", 183, 358, 10.0], ["rubble", 200, 372, 8.0],
	["pillar", 130, 395, 7.0],
	["wall", 162, 396, 10.0], ["wall", 185, 398, 10.0], ["wall", 208, 398, 10.0], ["wall", 230, 400, 9.0],
	["pillar", 258, 397, 7.0],
	# south-east: the pillar beside the altar, the broken wall, the rubble pile, the pillar and the standing slab
	["pillar", 540, 397, 7.0],
	["wall", 572, 398, 10.0], ["wall", 595, 398, 10.0], ["wall", 618, 398, 10.0], ["wall", 640, 398, 9.0],
	["rubble", 622, 362, 9.0], ["rubble", 645, 365, 9.0],
	["pillar", 672, 388, 7.0], ["slab", 671, 351, 9.0],
]
## The stone altar (bench) at the south end: one prop, colliders along its base. [feet x, feet y]
const ALTAR: Array = [398, 412]
const ALTAR_COLLIDERS: Array = [[-31.0, 10.0, 15.0], [-10.0, 11.0, 15.0], [10.0, 11.0, 15.0], [31.0, 10.0, 15.0]]  # x offset, radius, height above the feet


## The solid colliders, built fresh (a fixed layout: every call returns the same list).
static func build() -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	for centre: Vector2 in boundary_centres():
		_add(list, centre, BOUNDARY_RADIUS, centre)
	for row: Array in SOLIDS:
		var at: Vector2 = Vector2(row[1], row[2])
		_add(list, at, float(row[3]), at)
	var feet: Vector2 = Vector2(ALTAR[0], ALTAR[1])
	for c: Array in ALTAR_COLLIDERS:
		_add(list, feet + Vector2(float(c[0]), -float(c[2])), float(c[1]), feet)
	return list


## The centres of the forest-edge circles: along every edge of BOUNDARY, BOUNDARY_RADIUS out from it, plus one on the
## outer bisector of each corner so the chain has no gap there.
static func boundary_centres() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var count: int = BOUNDARY.size()
	for i: int in count:
		var a: Vector2 = BOUNDARY[i]
		var b: Vector2 = BOUNDARY[(i + 1) % count]
		var prev: Vector2 = BOUNDARY[(i - 1 + count) % count]
		var normal: Vector2 = _outward(a, b)
		var corner: Vector2 = (_outward(prev, a) + normal).normalized()
		out.append(a + corner * BOUNDARY_RADIUS)
		var steps: int = maxi(1, ceili(a.distance_to(b) / BOUNDARY_SPACING))
		for s: int in range(1, steps):
			out.append(a.lerp(b, float(s) / float(steps)) + normal * BOUNDARY_RADIUS)
	return out


## The outer normal of a clockwise edge in screen coordinates (y down).
static func _outward(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = (b - a).normalized()
	return Vector2(d.y, -d.x)


static func _add(list: Array[Obstacle], centre: Vector2, radius: float, feet: Vector2) -> void:
	var o: Obstacle = Obstacle.new()
	o.id = list.size() + 1
	o.visual_id = &""  # the ground painting draws every structure
	o.feet = feet
	o.visual_scale = 1.0
	o.radius = radius
	o.center = centre
	list.append(o)
