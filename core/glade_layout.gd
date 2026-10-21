extends RefCounted
## The layout of the Stag glade (chapter 1, scene S4, the Thornback Stag mini-boss): where it is solid, the entrance,
## the exit, the start points and the checkpoint. Static data only; no scene manager uses it yet.
##
## The ground (presentation/forest/stag_glade_ground.png) is the owner's painting converted to the palette by
## tools/art/make_forest_ground_from_reference.py; every prop is painted and these obstacles are colliders only
## (visual_id empty). Check them on docs/previews/glade_colliders_overlay.png (tests/capture_forest_colliders.gd).
##
## The trail comes in at the bottom-left (ENTRY_RECT on the left edge); the round clearing holds the ring of standing
## stones around the glowing spring; the root arch at the top right is the exit (EXIT_RECT, inside the arch). Only the
## five tall standing stones are solid; the lying slabs, the flagstones, the spring (shallow, decor) and the bones are
## walkable, so the middle stays open for the fight and the ring has wide gaps (no charge gets trapped in it).
const Obstacle := preload("res://core/obstacle.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")

const SIZE: Vector2 = Vector2(800.0, 480.0)

## The walkable ground's outline, clockwise (screen coordinates). Edges on the world border are the openings.
const OUTLINE: Array[Vector2] = [
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
const BOUNDARY_RADIUS: float = 36.0
const BOUNDARY_SPACING: float = 24.0

## [what it is, centre x, centre y, radius]: the tall standing stones of the ring, a circle on the middle of each
## painted base (about 0.6 of the base's half width, the arena's pillar convention: the stones are seen from the side).
const SOLIDS: Array = [
	["rune stone", 322, 233, 7.0],
	["rune stone", 432, 207, 8.0],
	["rune stone", 518, 231, 8.0],
	["standing stone", 305, 280, 7.0],
	["rune stone", 382, 328, 9.0],
]

## The spring in the ring: decor (walkable, shallow). Centre and radii of its painted ellipse.
const SPRING: Vector2 = Vector2(445, 252)
const SPRING_RADII: Vector2 = Vector2(62, 32)
## The middle of the clearing (x 120..660, y 160..400) and the 300x200 fight area around it that the Stag must be free to
## use (tests/core/test_glade_layout.gd: at least 80 % of it; 82.6 % with STAG_RADIUS 20).
const CENTRE: Vector2 = Vector2(390, 282)
const FIGHT_AREA: Rect2 = Rect2(240, 182, 300, 200)

## The left edge at the bottom: entering from (and leaving to) the forest route. The player appears at ENTRY_POINT.
const ENTRY_RECT: Rect2 = Rect2(0, 412, 12, 68)
const ENTRY_POINT: Vector2 = Vector2(36, 446)
## The root arch at the top right: the way on to the Colossus ruins.
const EXIT_RECT: Rect2 = Rect2(604, 104, 38, 20)
const EXIT_POINT: Vector2 = Vector2(623, 116)

## The Stag starts near the stones on the far side of the ring from the entrance; the player at the entrance.
const STAG_START: Vector2 = Vector2(585, 240)
const PLAYER_START: Vector2 = ENTRY_POINT
## The Stag's body radius assumed for the free-space checks: the core's Stag does not exist yet, so the Colossus's
## Tuning.BOSS_RADIUS (20). The Stag's idle art is about 49x54; a body of 22 would keep 79.7 % of FIGHT_AREA open
## instead of 82.6 % (tests/core/test_glade_layout.gd), so a bigger Stag wants smaller stone colliders or one stone less.
const STAG_RADIUS: float = 20.0

## [id, kind, feet x, feet y, stand x, stand y]
const INTERACTABLES: Array = [
	["spring", "decor", 445, 252, 445, 296],
]
## The checkpoint at the glade entrance (docs/CHAPTER1_PLAN.md).
const CHECKPOINTS: Array[Vector2] = [Vector2(60, 440)]


## The solid colliders, built fresh (a fixed layout: every call returns the same list).
static func build() -> Array[Obstacle]:
	return build_scaled(1.0)


static func boundary_centres(scale: float = 1.0) -> Array[Vector2]:
	return SceneBounds.boundary_centres(outline_scaled(scale), BOUNDARY_RADIUS * scale, BOUNDARY_SPACING * scale, size_scaled(scale))


# --- scale options (the human's review, 2026-10-22: at 1.0 the hero looks tiny next to the stones and trees) ---
# tools/art/make_forest_ground_from_reference.py --scene glade --scale S converts the painting at round(800 S) x
# round(480 S) (presentation/forest/stag_glade_ground_sNNN.png). The tables above are measured at 1.0 (the approved,
# default layout); these functions give the same layout at S: every point, outline corner, trigger, collider radius,
# spacing and FIGHT_AREA is multiplied by S, points rounded to whole pixels. NOT scaled: the hero's radius and
# STAG_RADIUS (characters keep their pixel size in every scene). build_scaled(1.0) is exactly build().

## The colliders at `scale`.
static func build_scaled(scale: float) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	var outline: Array[Vector2] = outline_scaled(scale)
	for centre: Vector2 in boundary_centres(scale):
		SceneBounds.add(list, centre, SceneBounds.fit_radius(outline, centre, BOUNDARY_RADIUS * scale), centre)
	for row: Array in SOLIDS:
		var at: Vector2 = Vector2(row[1], row[2]) * scale
		SceneBounds.add(list, at, float(row[3]) * scale, at)
	return list


## The scene size at `scale` (the ground PNG's size).
static func size_scaled(scale: float) -> Vector2:
	return Vector2(roundf(SIZE.x * scale), roundf(SIZE.y * scale))


## A point measured at 1.0 at `scale`, rounded to whole pixels.
static func point_scaled(p: Vector2, scale: float) -> Vector2:
	return (p * scale).round()


## A rectangle measured at 1.0 (a trigger, FIGHT_AREA) at `scale` (corners rounded).
static func rect_scaled(r: Rect2, scale: float) -> Rect2:
	var a: Vector2 = (r.position * scale).round()
	return Rect2(a, (r.end * scale).round() - a)


## OUTLINE at `scale` (not rounded: the colliders use it as is).
static func outline_scaled(scale: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v: Vector2 in OUTLINE:
		out.append(v * scale)
	return out


## INTERACTABLES at `scale` as [id, kind, feet, stand].
static func interactables_scaled(scale: float) -> Array:
	var out: Array = []
	for row: Array in INTERACTABLES:
		out.append([row[0], row[1], point_scaled(Vector2(row[2], row[3]), scale), point_scaled(Vector2(row[4], row[5]), scale)])
	return out
