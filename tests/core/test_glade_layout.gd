extends "res://tests/test_case.gd"
## The Stag glade's layout (core/glade_layout.gd): valid colliders, free and reachable points, a hero can walk from the
## entrance to the middle and out through the root arch, the Stag (radius GladeLayout.STAG_RADIUS = 20, the Colossus's
## Tuning.BOSS_RADIUS: the core's Stag does not exist yet) has the middle of the clearing to fight in and the stone ring
## cannot trap it, determinism.

const Obstacle := preload("res://core/obstacle.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const HERO: float = 6.0  # Tuning.PLAYER_RADIUS


func test_the_colliders_are_valid() -> void:
	var list: Array[Obstacle] = GladeLayout.build()
	assert_true(list.size() > 40, "the glade has an edge chain and stones (%d circles)" % list.size())
	var ids: Dictionary = {}
	for o: Obstacle in list:
		assert_false(ids.has(o.id), "unique id %d" % o.id)
		ids[o.id] = true
		assert_true(o.radius > 0.0, "collider %d has a positive radius" % o.id)
		assert_eq(o.visual_id, &"", "collider %d draws nothing (the painting does)" % o.id)
		assert_true(o.center.x > -o.radius and o.center.y > -o.radius and o.center.x < GladeLayout.SIZE.x + o.radius and o.center.y < GladeLayout.SIZE.y + o.radius, "collider %d touches the world" % o.id)
	assert_eq(GladeLayout.SOLIDS.size(), 5, "only the five tall standing stones are solid inside the clearing")


func test_build_is_deterministic() -> void:
	var a: Array[Obstacle] = GladeLayout.build()
	var b: Array[Obstacle] = GladeLayout.build()
	assert_eq(a.size(), b.size(), "same count")
	for i: int in mini(a.size(), b.size()):
		assert_true(a[i].id == b[i].id and a[i].center == b[i].center and a[i].radius == b[i].radius, "collider %d is the same on every build" % i)


func test_every_point_is_inside_the_world_and_free() -> void:
	var list: Array[Obstacle] = GladeLayout.build()
	var size: Vector2 = GladeLayout.SIZE
	var points: Dictionary = {"entry": GladeLayout.ENTRY_POINT, "exit": GladeLayout.EXIT_POINT, "centre": GladeLayout.CENTRE,
		"spring": GladeLayout.SPRING}
	for k: int in GladeLayout.CHECKPOINTS.size():
		points["checkpoint %d" % k] = GladeLayout.CHECKPOINTS[k]
	for row: Array in GladeLayout.INTERACTABLES:
		points["stand at " + str(row[0])] = Vector2(row[4], row[5])
	for name: String in points:
		assert_true(SceneBounds.is_free(list, size, points[name], HERO), "%s is free for the hero %s" % [name, str(points[name])])
	assert_true(SceneBounds.is_free(list, size, GladeLayout.STAG_START, GladeLayout.STAG_RADIUS), "the Stag's start is free")
	assert_true(GladeLayout.STAG_START.distance_to(GladeLayout.PLAYER_START) > 400.0, "the Stag starts across the glade from the player")
	assert_eq(GladeLayout.ENTRY_RECT.position.x, 0.0, "the entry trigger is on the left edge")
	assert_true(GladeLayout.EXIT_RECT.has_point(GladeLayout.EXIT_POINT), "the exit point is inside the arch trigger")
	assert_true(GladeLayout.EXIT_RECT.position.x > 560.0 and GladeLayout.EXIT_RECT.end.y < 160.0, "the exit is the root arch at the top right")


func test_a_hero_walks_from_the_entrance_to_the_middle_and_the_exit() -> void:
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.SIZE, GladeLayout.build(), HERO)
	assert_true(grid.flood(GladeLayout.ENTRY_POINT) > 0, "the entrance is free")
	assert_true(grid.reaches(GladeLayout.CENTRE), "the middle is reachable")
	assert_true(grid.reaches(GladeLayout.EXIT_POINT), "the root arch is reachable")
	assert_true(grid.reaches(GladeLayout.STAG_START), "the Stag's start is reachable")
	for row: Array in GladeLayout.INTERACTABLES:
		assert_true(grid.reaches(Vector2(row[4], row[5])), "the hero can stand at the %s" % row[0])
	var outline: PackedVector2Array = PackedVector2Array(GladeLayout.OUTLINE)
	var outside: int = 0
	for p: Vector2 in grid.reached_points():
		if not Geometry2D.is_point_in_polygon(p, outline) and SceneBounds.fit_radius(GladeLayout.OUTLINE, p, 100.0) > 6.0:
			outside += 1
	assert_eq(outside, 0, "reachable spots more than 6 px outside the outline")


func test_the_stag_has_the_middle_to_fight_in() -> void:
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.SIZE, GladeLayout.build(), GladeLayout.STAG_RADIUS)
	assert_true(grid.flood(GladeLayout.STAG_START) > 0, "the Stag's start is free")
	var area: Rect2 = GladeLayout.FIGHT_AREA
	var total: int = 0
	var open: int = 0
	for p: Vector2 in _samples(area):
		total += 1
		if grid.reaches(p):
			open += 1
	var share: float = float(open) / float(total)
	assert_true(share >= 0.8, "the Stag can reach at least 80%% of the 300x200 fight area (%.1f%%)" % (share * 100.0))
	assert_true(grid.reaches(GladeLayout.CENTRE), "the Stag can reach the middle of the ring")
	assert_true(grid.reaches(GladeLayout.SPRING), "the spring does not block the Stag")


func test_the_stone_ring_has_gaps_wide_enough_for_the_stag() -> void:
	# sort the standing stones around the ring's middle; count the neighbour gaps the Stag passes through
	var stones: Array = GladeLayout.SOLIDS.duplicate()
	var middle: Vector2 = GladeLayout.SPRING
	stones.sort_custom(func(a: Array, b: Array) -> bool:
		return (Vector2(a[1], a[2]) - middle).angle() < (Vector2(b[1], b[2]) - middle).angle())
	var wide: int = 0
	for i: int in stones.size():
		var a: Array = stones[i]
		var b: Array = stones[(i + 1) % stones.size()]
		var gap: float = Vector2(a[1], a[2]).distance_to(Vector2(b[1], b[2])) - float(a[3]) - float(b[3])
		if gap > GladeLayout.STAG_RADIUS * 2.0 + 4.0:
			wide += 1
	assert_true(wide >= 3, "at least three gaps in the ring let the Stag through (%d)" % wide)


func test_charges_from_the_ring_get_out() -> void:
	# from the spring in the middle of the ring, a straight Stag-size run in 16 directions: most leave the ring
	# (100 px, past the stones at 45..90 px) before they meet a collider
	var list: Array[Obstacle] = GladeLayout.build()
	var out: int = 0
	for k: int in 16:
		var dir: Vector2 = Vector2.RIGHT.rotated(TAU * k / 16.0)
		var run: float = 0.0
		while run < 200.0 and SceneBounds.is_free(list, GladeLayout.SIZE, GladeLayout.SPRING + dir * (run + 2.0), GladeLayout.STAG_RADIUS):
			run += 2.0
		if run >= 100.0:
			out += 1
	assert_true(out >= 8, "at least 8 of 16 straight charges from the spring leave the ring (%d)" % out)


func _samples(area: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var y: float = area.position.y + 2.0
	while y < area.end.y:
		var x: float = area.position.x + 2.0
		while x < area.end.x:
			out.append(Vector2(x, y))
			x += 4.0
		y += 4.0
	return out
