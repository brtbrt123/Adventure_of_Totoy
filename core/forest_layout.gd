extends RefCounted
## The layout of the forest route (chapter 1, scenes S2 + S3 merged into one 800x480 scene): where it is solid, where
## the player enters and leaves, where enemies stand, the interactables and the checkpoints. Static data only; no scene
## manager uses it yet.
##
## The ground (presentation/forest/forest_route_ground.png) is the owner's painting converted to the palette by
## tools/art/make_forest_ground_from_reference.py, so every prop is painted and these obstacles are colliders only
## (visual_id empty), placed on the painted props like core/arena_layout.gd. Check them on
## docs/previews/forest_colliders_overlay.png (tests/capture_forest_colliders.gd).
##
## The route: the trail comes in at the LEFT edge (the village side, ENTRY_RECT), crosses the first clearing (signpost,
## lantern post, mossy stone: the Mosslings), bends down through the second clearing (flagstones, a puddle on the grass
## island: the Boars and the Glowmoths) and climbs to the two lantern pedestals in front of the root gate. The EXIT is
## the painted path behind the root gate, north to the top edge (EXIT_RECT): the lantern puzzle gates it (the human's
## decision, 2026-10-22). The root gate (GATE_COLLIDERS, all with feet GATE_FEET) closes it: build() returns the closed
## gate, build_with_gate(true) leaves it out (the door opened). A short trail painted east past the second pedestal is a
## DEAD END in the undergrowth with the chest in the nook below it; the right edge is sealed (no trigger).
##
## Collider kinds: the forest edge (a chain of circles just outside OUTLINE, as in the arena: BOUNDARY_RADIUS, smaller
## where a corner juts into the walkable ground so no circle covers it (SceneBounds.fit_radius); openings on the world
## border get no circles), SOLIDS (props inside the walkable area) and the gate.
const Obstacle := preload("res://core/obstacle.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")

const SIZE: Vector2 = Vector2(800.0, 480.0)

## The walkable ground's outline, clockwise (screen coordinates). Edges on the world border are the openings.
const OUTLINE: Array[Vector2] = [
	# the left entrance (top side of the trail), under the fallen log and the stones, the signpost clearing
	Vector2(0, 238), Vector2(55, 232), Vector2(85, 212), Vector2(150, 206), Vector2(190, 198), Vector2(215, 188),
	Vector2(300, 194), Vector2(318, 222), Vector2(345, 236),
	# under the roots of the big middle tree, up past the first pedestal to the gate
	Vector2(370, 246), Vector2(420, 250), Vector2(470, 246), Vector2(498, 240), Vector2(520, 202), Vector2(545, 186),
	Vector2(575, 192),
	# the path behind the root gate, north to the top edge (closed by the gate)
	Vector2(598, 150), Vector2(604, 60), Vector2(612, 0), Vector2(684, 0), Vector2(680, 60), Vector2(676, 150),
	# down the roots right of the second pedestal, along the dead-end trail east (it ends in the undergrowth at x 760)
	Vector2(668, 205), Vector2(668, 285), Vector2(700, 296), Vector2(740, 302), Vector2(756, 312), Vector2(760, 328),
	Vector2(748, 344), Vector2(720, 345), Vector2(660, 342),
	# the bottom of the second clearing, along the big fallen root and the ferns
	Vector2(640, 344), Vector2(600, 358), Vector2(560, 382), Vector2(530, 400), Vector2(480, 410), Vector2(440, 418),
	Vector2(380, 410), Vector2(330, 398), Vector2(290, 400),
	# the grass below the first clearing, above the lower fallen log and its stones, back to the left entrance
	Vector2(262, 380), Vector2(235, 352), Vector2(200, 322), Vector2(160, 314), Vector2(60, 306), Vector2(0, 302),
]
const BOUNDARY_RADIUS: float = 36.0
const BOUNDARY_SPACING: float = 24.0

## [what it is, centre x, centre y, radius]: the props standing in or on the edge of the walkable ground.
const SOLIDS: Array = [
	["signpost", 248, 182, 7.0],
	["lantern post", 296, 190, 5.0],
	["mossy stone", 333, 200, 16.0],
	["lantern pedestal", 512, 236, 10.0],
	["lantern pedestal", 636, 274, 10.0],
	["chest", 688, 376, 14.0],
	["mossy rock", 741, 290, 15.0],
	# the undergrowth and roots where the dead-end trail stops (beyond the edge chain, so the end reads solid too)
	["undergrowth", 774, 326, 12.0], ["undergrowth", 790, 306, 12.0], ["undergrowth", 790, 346, 12.0],
	["stones", 180, 330, 12.0], ["stones", 215, 338, 10.0],
]

## The root gate: a row of circles along its base, closing the path north. Every gate collider has feet GATE_FEET.
const GATE_FEET: Vector2 = Vector2(628, 190)
const GATE_COLLIDERS: Array = [[585, 182, 10.0], [600, 182, 10.0], [615, 182, 10.0], [630, 182, 10.0],
	[645, 182, 10.0], [660, 182, 10.0], [675, 182, 10.0]]  # x, y, radius

## The left edge: entering from (and leaving to) the village. The player appears at ENTRY_POINT.
const ENTRY_RECT: Rect2 = Rect2(0, 240, 12, 58)
const ENTRY_POINT: Vector2 = Vector2(24, 268)
## The exit on to the Stag glade: where the path behind the root gate leaves the top edge (reachable only with the gate
## open). EXIT_POINT is a free spot inside the trigger.
const EXIT_RECT: Rect2 = Rect2(612, 0, 72, 16)
const EXIT_POINT: Vector2 = Vector2(646, 14)
## The end of the dead-end trail east (with the chest below it): the farthest spot the hero reaches there.
const DEAD_END: Vector2 = Vector2(740, 324)

## Enemy stand points: [kind, x, y]. Mosslings in the first clearing, Boars and Glowmoths in the second.
const SPAWNS: Array = [
	["mossling", 170, 262], ["mossling", 232, 224], ["mossling", 252, 296],
	["thornback_boar", 395, 332], ["thornback_boar", 490, 345],
	["glowmoth", 440, 282], ["glowmoth", 585, 246],
]
## Body radius per enemy kind (for the free-spot checks; the core's enemy numbers do not exist yet).
const SPAWN_RADIUS: Dictionary = {"mossling": 8.0, "thornback_boar": 14.0, "glowmoth": 6.0}

## [id, kind, feet x, feet y, stand x, stand y]: the prop's ground point and a free spot in front of it where the
## player stands to use it. The pedestals are the lantern puzzle's switches; lighting both opens the root gate.
const INTERACTABLES: Array = [
	["signpost", "sign", 248, 186, 262, 210],
	["pedestal_west", "lantern_switch", 512, 242, 514, 262],
	["pedestal_east", "lantern_switch", 636, 280, 630, 302],
	["root_gate", "door", 628, 190, 596, 212],
	["chest", "chest", 688, 392, 688, 330],
]

## Checkpoints: the forest entrance and the foot of the lantern puzzle.
const CHECKPOINTS: Array[Vector2] = [Vector2(40, 268), Vector2(560, 300)]


## The solid colliders with the root gate closed (a fixed layout: every call returns the same list).
static func build() -> Array[Obstacle]:
	return build_scaled(1.0, false)


## The solid colliders; `gate_open` leaves the root gate's colliders out.
static func build_with_gate(gate_open: bool) -> Array[Obstacle]:
	return build_scaled(1.0, gate_open)


## True for the colliders of the root gate (the door the lantern puzzle opens) in a layout built at `scale`.
static func is_gate(o: Obstacle, scale: float = 1.0) -> bool:
	return o.feet == GATE_FEET * scale


static func boundary_centres(scale: float = 1.0) -> Array[Vector2]:
	return SceneBounds.boundary_centres(outline_scaled(scale), BOUNDARY_RADIUS * scale, BOUNDARY_SPACING * scale, size_scaled(scale))


# --- scale options (the human's review, 2026-10-22: at 1.0 the hero looks tiny next to the painted trees and props) ---
# tools/art/make_forest_ground_from_reference.py --scale S converts the painting at round(800 S) x round(480 S)
# (presentation/forest/forest_route_ground_sNNN.png). The tables above are measured at 1.0 (the approved, default
# layout); these functions give the same layout at S: every point, outline corner, trigger, collider radius and spacing
# is multiplied by S, points rounded to whole pixels. NOT scaled: the hero's radius and the creatures' body radii
# (SPAWN_RADIUS): characters keep their pixel size in every scene. build_scaled(1.0, ...) is exactly build().

## The colliders at `scale` (gate closed unless `gate_open`).
static func build_scaled(scale: float, gate_open: bool = false) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	var outline: Array[Vector2] = outline_scaled(scale)
	for centre: Vector2 in boundary_centres(scale):
		SceneBounds.add(list, centre, SceneBounds.fit_radius(outline, centre, BOUNDARY_RADIUS * scale), centre)
	for row: Array in SOLIDS:
		var at: Vector2 = Vector2(row[1], row[2]) * scale
		SceneBounds.add(list, at, float(row[3]) * scale, at)
	if not gate_open:
		for c: Array in GATE_COLLIDERS:
			SceneBounds.add(list, Vector2(c[0], c[1]) * scale, float(c[2]) * scale, GATE_FEET * scale)
	return list


## The scene size at `scale` (the ground PNG's size).
static func size_scaled(scale: float) -> Vector2:
	return Vector2(roundf(SIZE.x * scale), roundf(SIZE.y * scale))


## A point measured at 1.0 at `scale`, rounded to whole pixels.
static func point_scaled(p: Vector2, scale: float) -> Vector2:
	return (p * scale).round()


## A trigger rectangle measured at 1.0 at `scale` (corners rounded, so edge triggers stay on the edge).
static func rect_scaled(r: Rect2, scale: float) -> Rect2:
	var a: Vector2 = (r.position * scale).round()
	return Rect2(a, (r.end * scale).round() - a)


## OUTLINE at `scale` (not rounded: the colliders use it as is).
static func outline_scaled(scale: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v: Vector2 in OUTLINE:
		out.append(v * scale)
	return out


## SPAWNS at `scale` as [kind, position].
static func spawns_scaled(scale: float) -> Array:
	var out: Array = []
	for row: Array in SPAWNS:
		out.append([row[0], point_scaled(Vector2(row[1], row[2]), scale)])
	return out


## INTERACTABLES at `scale` as [id, kind, feet, stand].
static func interactables_scaled(scale: float) -> Array:
	var out: Array = []
	for row: Array in INTERACTABLES:
		out.append([row[0], row[1], point_scaled(Vector2(row[2], row[3]), scale), point_scaled(Vector2(row[4], row[5]), scale)])
	return out


## CHECKPOINTS at `scale`.
static func checkpoints_scaled(scale: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Vector2 in CHECKPOINTS:
		out.append(point_scaled(p, scale))
	return out
