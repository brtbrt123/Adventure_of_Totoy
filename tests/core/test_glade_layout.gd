extends "res://tests/test_case.gd"
## The Stag glade's layout at its game scale (core/glade_layout.gd, SCALE 0.7; other scales: test_glade_layout_scaled.gd):
## valid colliders, free and reachable points, a hero can walk from the entrance to the middle and out through the root
## arch, the five standing stones are solid (the human's playtest, 2026-10-22) and stop the hero at their painted edge,
## the spring and the slabs are gone (walkable), the Stag (radius GladeLayout.STAG_RADIUS = 20, the Colossus's
## Tuning.BOSS_RADIUS: the core's Stag does not exist yet) has the middle of the clearing to fight in and can circle it,
## charges get out of the ring, determinism.

const Obstacle := preload("res://core/obstacle.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const HERO: float = 6.0  # Tuning.PLAYER_RADIUS
## The Stag's share of FIGHT_AREA. The rule was 80 %; with all five standing stones solid (two circles on each base) it
## is 63.1 % at 0.7 (measured 2026-10-22 after the spring and the slabs were removed from the art; one circle per stone
## gave 69.8 % earlier, two solid stones 83.4 %). The guard is the measured value minus a small margin; the middle,
## the spring point and a loop round it stay reachable (tests below).
const STAG_SHARE_MIN: float = 0.62
## Straight Stag-size runs from the spring point that leave the ring (measured 5 of 16).
const CHARGES_OUT_MIN: int = 5


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
	assert_eq(GladeLayout.STANDING_STONES_1X.size(), 5, "five standing stones")
	assert_eq(GladeLayout.SOLIDS_1X.size(), 10, "two base circles per standing stone, nothing else in the ring")


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
		"spring (removed, walkable)": GladeLayout.SPRING}
	for k: int in GladeLayout.CHECKPOINTS.size():
		points["checkpoint %d" % k] = GladeLayout.CHECKPOINTS[k]
	for row: Array in GladeLayout.INTERACTABLES:
		points["stand at " + str(row[0])] = Vector2(row[4], row[5])
	for name: String in points:
		assert_true(SceneBounds.is_free(list, size, points[name], HERO), "%s is free for the hero %s" % [name, str(points[name])])
	assert_true(SceneBounds.is_free(list, size, GladeLayout.STAG_START, GladeLayout.STAG_RADIUS), "the Stag's start is free")
	assert_true(GladeLayout.STAG_START.distance_to(GladeLayout.PLAYER_START) > 400.0 * GladeLayout.SCALE, "the Stag starts across the glade from the player")
	assert_eq(GladeLayout.ENTRY_RECT.position.x, 0.0, "the entry trigger is on the left edge")
	assert_true(GladeLayout.EXIT_RECT.has_point(GladeLayout.EXIT_POINT), "the exit point is inside the arch trigger")
	assert_true(GladeLayout.EXIT_RECT.position.x > 560.0 * GladeLayout.SCALE and GladeLayout.EXIT_RECT.end.y < 160.0 * GladeLayout.SCALE, "the exit is the root arch at the top right")


func test_a_hero_walks_from_the_entrance_to_the_middle_and_the_exit() -> void:
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.SIZE, GladeLayout.build(), HERO)
	assert_true(grid.flood(GladeLayout.ENTRY_POINT) > 0, "the entrance is free")
	assert_true(grid.reaches(GladeLayout.CENTRE), "the middle is reachable")
	assert_true(grid.reaches(GladeLayout.EXIT_POINT), "the root arch is reachable")
	assert_true(grid.reaches(GladeLayout.STAG_START), "the Stag's start is reachable")
	for row: Array in GladeLayout.INTERACTABLES:
		assert_true(grid.reaches(Vector2(row[4], row[5])), "the hero can stand at the %s" % row[0])
	var outline: PackedVector2Array = PackedVector2Array(GladeLayout.outline_scaled())
	var outside: int = 0
	for p: Vector2 in grid.reached_points():
		if not Geometry2D.is_point_in_polygon(p, outline) and SceneBounds.fit_radius(GladeLayout.outline_scaled(), p, 100.0) > 6.0:
			outside += 1
	assert_eq(outside, 0, "reachable spots more than 6 px outside the outline")


func test_the_stag_has_the_middle_to_fight_in() -> void:
	var share: float = _share(GladeLayout.STAG_RADIUS)
	print("glade: the Stag (radius %.0f) reaches %.1f %% of the fight area" % [GladeLayout.STAG_RADIUS, share * 100.0])
	assert_true(share >= STAG_SHARE_MIN, "the Stag reaches at least %.0f %% of the fight area (%.1f %%)" % [STAG_SHARE_MIN * 100.0, share * 100.0])
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.SIZE, GladeLayout.build(), GladeLayout.STAG_RADIUS)
	assert_true(grid.flood(GladeLayout.STAG_START) > 0, "the Stag's start is free")
	assert_true(grid.reaches(GladeLayout.CENTRE), "the Stag can reach the middle of the ring")
	assert_true(grid.reaches(GladeLayout.SPRING), "the Stag can stand where the spring was")


func test_the_stag_can_circle_the_middle_of_the_ring() -> void:
	# a loop of 12 points 22 px round a point 20 px south of the spring point (the back stone's base keeps the Stag 25 px
	# away north): all reachable, so the Stag can chase round the middle of the ring
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.SIZE, GladeLayout.build(), GladeLayout.STAG_RADIUS)
	grid.flood(GladeLayout.STAG_START)
	for k: int in 12:
		var p: Vector2 = GladeLayout.SPRING + Vector2(0, 20) + Vector2.RIGHT.rotated(TAU * k / 12.0) * 22.0
		assert_true(grid.reaches(p), "the Stag reaches %s on the loop round the middle" % str(p))


func test_the_standing_stones_are_solid() -> void:
	var list: Array[Obstacle] = GladeLayout.build()
	for row: Array in GladeLayout.STANDING_STONES_1X:
		var base: Vector2 = Vector2(row[1], row[2]) * GladeLayout.SCALE + Vector2(0, -3)
		assert_false(SceneBounds.is_free(list, GladeLayout.SIZE, base, HERO), "the hero cannot stand on the %s's base %s" % [row[0], str(base)])
		# walking at the base from the west, the east and the south: stopped at its painted edge
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP]:
			var p: Vector2 = base - dir * 24.0
			if not SceneBounds.is_free(list, GladeLayout.SIZE, p, HERO):
				continue
			var moved: float = 0.0
			while moved < 30.0 and SceneBounds.is_free(list, GladeLayout.SIZE, p + dir, HERO):
				p += dir
				moved += 1.0
			assert_true(p.distance_to(base) >= 8.0, "%s from %s stops at its edge (%s)" % [row[0], str(-dir), str(p)])


func test_charges_from_the_middle_get_out() -> void:
	# from the spring point, a straight Stag-size run in 16 directions: some leave the ring (100 px at 1.0)
	var list: Array[Obstacle] = GladeLayout.build()
	var out: int = 0
	for k: int in 16:
		var dir: Vector2 = Vector2.RIGHT.rotated(TAU * k / 16.0)
		var run: float = 0.0
		while run < 200.0 and SceneBounds.is_free(list, GladeLayout.SIZE, GladeLayout.SPRING + dir * (run + 2.0), GladeLayout.STAG_RADIUS):
			run += 2.0
		if run >= 100.0 * GladeLayout.SCALE:
			out += 1
	print("glade: %d of 16 straight Stag charges from the middle leave the ring" % out)
	assert_true(out >= CHARGES_OUT_MIN, "at least %d of 16 straight charges leave the ring (%d)" % [CHARGES_OUT_MIN, out])


func _share(radius: float) -> float:
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.SIZE, GladeLayout.build(), radius)
	grid.flood(GladeLayout.STAG_START)
	var total: int = 0
	var open: int = 0
	for p: Vector2 in _samples(GladeLayout.FIGHT_AREA):
		total += 1
		if grid.reaches(p):
			open += 1
	return float(open) / float(total)


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
