extends RefCounted
## The layout of the Stag glade (chapter 1, scene S4, the Thornback Stag mini-boss; 560x336 at SCALE 0.7): where it is
## solid, the entrance, the exit, the start points and the checkpoint. Static data only; no scene manager uses it yet.
##
## The ground (presentation/forest/stag_glade_ground.png, 560x336) is the owner's painting converted to the palette by
## tools/art/make_forest_ground_from_reference.py --scene glade at --scale 0.7 (the human's choice on 2026-10-22: at the
## first size, 800x480, the hero looked tiny next to the standing stones and trees; see
## docs/previews/glade_scale_options.png). Every prop is painted and these obstacles are colliders only (visual_id
## empty). Check them on docs/previews/glade_colliders_overlay.png (tests/capture_forest_colliders.gd).
##
## Coordinates (the village's scheme, core/village_layout.gd): the *_1X tables are measured on the painting at scale 1.0
## (800x480); the game uses SCALE. The plain constants (SIZE, ENTRY_RECT, ENTRY_POINT, EXIT_RECT, EXIT_POINT,
## STAG_START, PLAYER_START, CENTRE, SPRING, FIGHT_AREA, INTERACTABLES, CHECKPOINTS) are the SCALE values rounded to
## whole pixels (tests/core/test_glade_layout_scaled.gd checks them), build() gives the SCALE colliders, and
## build_scaled(s) / the *_scaled functions any other scale. Every point, outline corner, trigger, collider radius,
## spacing and the fight area scale; the hero's radius and STAG_RADIUS do not (characters keep their pixel size).
##
## The trail comes in at the bottom-left (ENTRY_RECT on the left edge); the round clearing holds the ring of standing
## stones; the root arch at the top right is the exit (EXIT_RECT, inside the arch).
## The human's decisions (2026-10-22): everything that stands up is SOLID ("why can I walk in this stone and water"),
## and the spring, the three lying slabs and the round rock were REMOVED from the ground art (a deliberate change from
## the painting: tools/art/make_forest_ground_from_reference.py paints them over with grass) so the Stag keeps the
## middle of the ring. Solid inside the ring: the five standing stones only (two small circles along each painted base,
## SOLIDS_1X); presentation draws their tops over actors standing behind them (presentation/common/depth_occluders.json).
## The flagstones, the bones and SPRING (the ring's middle, where the spring was: decor, walkable) stay walkable.
const Obstacle := preload("res://core/obstacle.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")

## The game's scale of the painting (the human's choice, 2026-10-22).
const SCALE: float = 0.7
const SIZE_1X: Vector2 = Vector2(800.0, 480.0)
## The scene size at SCALE (the ground PNG's size).
const SIZE: Vector2 = Vector2(560.0, 336.0)

## The walkable ground's outline at 1.0, clockwise (screen coordinates). Edges on the world border are the openings.
const OUTLINE_1X: Array[Vector2] = [
	# the entrance trail's top side, then up the left of the clearing (the hollow log, the stump, the skull's left)
	Vector2(0, 412), Vector2(40, 410), Vector2(110, 408), Vector2(175, 404), Vector2(205, 398), Vector2(180, 360),
	Vector2(150, 322), Vector2(128, 290), Vector2(120, 258), Vector2(130, 230), Vector2(150, 206),
	# the tree roots, the stump and the log along the top, the thorn vines
	Vector2(200, 198), Vector2(250, 188), Vector2(272, 168), Vector2(330, 160), Vector2(400, 163), Vector2(470, 166),
	Vector2(520, 172), Vector2(552, 178), Vector2(572, 164),
	# into the root arch (the exit) and out again
	Vector2(590, 148), Vector2(598, 104), Vector2(646, 104), Vector2(652, 150), Vector2(662, 186),
	# the right side (the antler, the mud patch), along the big root and the ferns at the bottom
	Vector2(652, 230), Vector2(656, 252), Vector2(650, 290), Vector2(620, 306), Vector2(590, 330), Vector2(560, 356),
	Vector2(530, 376), Vector2(500, 392), Vector2(440, 402), Vector2(360, 402), Vector2(300, 400), Vector2(250, 402),
	# down the entrance trail's lower side to the bottom edge
	Vector2(228, 420), Vector2(150, 446), Vector2(124, 480), Vector2(0, 480),
]
const BOUNDARY_RADIUS_1X: float = 36.0
const BOUNDARY_SPACING_1X: float = 24.0

## [what it is, centre x, centre y, radius] at 1.0: everything solid standing in the ring, the five standing stones, two
## circles along each painted base (radius 7.2 at 1.0 = 5.04 at 0.7; the front rune stone is wider, 8.6).
const SOLIDS_1X: Array = [
	["rune stone (back, 2)", 424, 207, 7.2], ["rune stone (back, 2)", 436, 207, 7.2],
	["rune stone (right)", 513, 233, 7.2], ["rune stone (right)", 524, 233, 7.2],
	["rune stone (left)", 317, 233, 7.2], ["rune stone (left)", 329, 234, 7.2],
	["standing stone", 300, 290, 7.2], ["standing stone", 310, 291, 7.2],
	["rune stone (front)", 373, 330, 8.6], ["rune stone (front)", 391, 330, 8.6],
]
## The five tall standing stones (the "2" stone at the back, right, left, the plain standing stone, front): [what, x, y]
## of the middle of each base at 1.0 (the depth occluders in presentation use the same bases).
const STANDING_STONES_1X: Array = [["rune stone (back, 2)", 430, 208], ["rune stone (right)", 518, 236],
	["rune stone (left)", 323, 236], ["standing stone", 305, 293], ["rune stone (front)", 382, 333]]

## Where the spring was (removed from the art on 2026-10-22): the ring's middle, decor and walkable.
const SPRING_1X: Vector2 = Vector2(439, 250)
const SPRING: Vector2 = Vector2(307, 175)
## The middle of the clearing (x 120..660, y 160..400 at 1.0) and the fight area around it (300x200 at 1.0, scaled with
## the scene) that the Stag must be free to use (tests: at least 80 % of it with STAG_RADIUS 20).
const CENTRE_1X: Vector2 = Vector2(390, 290)
const FIGHT_AREA_1X: Rect2 = Rect2(240, 182, 300, 200)
const CENTRE: Vector2 = Vector2(273, 203)
const FIGHT_AREA: Rect2 = Rect2(168, 127, 210, 140)

## The left edge at the bottom: entering from (and leaving to) the forest route. The player appears at ENTRY_POINT.
const ENTRY_RECT_1X: Rect2 = Rect2(0, 412, 12, 68)
const ENTRY_POINT_1X: Vector2 = Vector2(36, 446)
const ENTRY_RECT: Rect2 = Rect2(0, 288, 8, 48)
const ENTRY_POINT: Vector2 = Vector2(25, 312)
## The root arch at the top right: the way on to the Colossus ruins.
const EXIT_RECT_1X: Rect2 = Rect2(604, 104, 38, 20)
const EXIT_POINT_1X: Vector2 = Vector2(623, 116)
const EXIT_RECT: Rect2 = Rect2(423, 73, 26, 14)
const EXIT_POINT: Vector2 = Vector2(436, 81)

## The Stag starts near the stones on the far side of the ring from the entrance; the player at the entrance.
const STAG_START_1X: Vector2 = Vector2(585, 240)
const STAG_START: Vector2 = Vector2(410, 168)
const PLAYER_START: Vector2 = ENTRY_POINT
## The Stag's body radius assumed for the free-space checks: the core's Stag does not exist yet, so the Colossus's
## Tuning.BOSS_RADIUS (20). NOT scaled (the Stag keeps its pixel size). The Stag's idle art is about 49x54.
const STAG_RADIUS: float = 20.0

## [id, kind, feet x, feet y, stand x, stand y] at 1.0 and at SCALE.
const INTERACTABLES_1X: Array = [
	["spring", "decor", 439, 250, 445, 296],
]
const INTERACTABLES: Array = [
	["spring", "decor", 307, 175, 312, 207],
]
## The checkpoint at the glade entrance (docs/CHAPTER1_PLAN.md), at 1.0 and at SCALE.
const CHECKPOINTS_1X: Array[Vector2] = [Vector2(60, 440)]
const CHECKPOINTS: Array[Vector2] = [Vector2(42, 308)]


## The solid colliders at SCALE, built fresh (a fixed layout: every call returns the same list).
static func build() -> Array[Obstacle]:
	return build_scaled(SCALE)


static func boundary_centres(scale: float = SCALE) -> Array[Vector2]:
	return SceneBounds.boundary_centres(outline_scaled(scale), BOUNDARY_RADIUS_1X * scale, BOUNDARY_SPACING_1X * scale, size_scaled(scale))


## The colliders at `scale`: outline, radii, spacing and SOLIDS_1X scaled.
static func build_scaled(scale: float) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	var outline: Array[Vector2] = outline_scaled(scale)
	for centre: Vector2 in boundary_centres(scale):
		SceneBounds.add(list, centre, SceneBounds.fit_radius(outline, centre, BOUNDARY_RADIUS_1X * scale), centre)
	for row: Array in SOLIDS_1X:
		var at: Vector2 = Vector2(row[1], row[2]) * scale
		SceneBounds.add(list, at, float(row[3]) * scale, at)
	return list


## The scene size at `scale` (the ground PNG's size: round(800 s) x round(480 s)).
static func size_scaled(scale: float) -> Vector2:
	return Vector2(roundf(SIZE_1X.x * scale), roundf(SIZE_1X.y * scale))


## A point measured at 1.0 (a *_1X constant) at `scale`, rounded to whole pixels.
static func point_scaled(p_1x: Vector2, scale: float) -> Vector2:
	return (p_1x * scale).round()


## A rectangle measured at 1.0 (a trigger, FIGHT_AREA_1X) at `scale` (corners rounded).
static func rect_scaled(r_1x: Rect2, scale: float) -> Rect2:
	var a: Vector2 = (r_1x.position * scale).round()
	return Rect2(a, (r_1x.end * scale).round() - a)


## OUTLINE_1X at `scale` (not rounded: the colliders use it as is).
static func outline_scaled(scale: float = SCALE) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v: Vector2 in OUTLINE_1X:
		out.append(v * scale)
	return out


## INTERACTABLES_1X at `scale` as [id, kind, feet, stand].
static func interactables_scaled(scale: float) -> Array:
	var out: Array = []
	for row: Array in INTERACTABLES_1X:
		out.append([row[0], row[1], point_scaled(Vector2(row[2], row[3]), scale), point_scaled(Vector2(row[4], row[5]), scale)])
	return out
