extends "res://tests/test_case.gd"
## The Stag glade layout at other scales (core/glade_layout.gd build_scaled / *_scaled; the game's SCALE 0.7 is checked
## by test_glade_layout.gd): at 1.0 (the first 800x480 version), 0.6 and 0.5 (the options on
## docs/previews/glade_scale_options.png) with the hero radius and STAG_RADIUS NOT scaled: valid colliders, free points,
## a hero walks from the entrance to the middle and out through the arch, nothing outside the outline is reachable. The
## Stag's share of the fight area (FIGHT_AREA_1X scaled with the scene) is measured by fight_share() and must stay at
## least MIN_SHARE[scale] (a regression guard of the measured values with the five standing stones solid and the spring
## and slabs removed, 2026-10-22; see test_glade_layout.gd). Also: the plain constants and build() are
## exactly the SCALE values.

const Obstacle := preload("res://core/obstacle.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const SCALES: Array[float] = [1.0, 0.6, 0.5]
const HERO: float = 6.0  # Tuning.PLAYER_RADIUS, the same at every scale
## The measured shares with the five standing stones solid (2026-10-22; 1.0: 78.7 %, 0.7: 63.1 %, 0.6: 34.2 %,
## 0.5: 25.5 %), rounded down to whole percent (0.7 minus a margin: 0.62).
const MIN_SHARE: Dictionary = {1.0: 0.78, 0.7: 0.62, 0.6: 0.34, 0.5: 0.25}


func test_the_constants_are_the_scaled_layout() -> void:
	var s: float = GladeLayout.SCALE
	assert_eq(s, 0.7, "the game's glade scale (the human's choice, 2026-10-22)")
	var a: Array[Obstacle] = GladeLayout.build()
	var b: Array[Obstacle] = GladeLayout.build_scaled(s)
	assert_eq(a.size(), b.size(), "same count")
	for i: int in mini(a.size(), b.size()):
		assert_true(a[i].center == b[i].center and a[i].radius == b[i].radius, "collider %d" % i)
	assert_eq(GladeLayout.SIZE, GladeLayout.size_scaled(s), "SIZE")
	assert_eq(GladeLayout.size_scaled(0.7), Vector2(560, 336), "560x336")
	assert_eq(GladeLayout.ENTRY_RECT, GladeLayout.rect_scaled(GladeLayout.ENTRY_RECT_1X, s), "ENTRY_RECT")
	assert_eq(GladeLayout.ENTRY_POINT, GladeLayout.point_scaled(GladeLayout.ENTRY_POINT_1X, s), "ENTRY_POINT")
	assert_eq(GladeLayout.EXIT_RECT, GladeLayout.rect_scaled(GladeLayout.EXIT_RECT_1X, s), "EXIT_RECT")
	assert_eq(GladeLayout.EXIT_POINT, GladeLayout.point_scaled(GladeLayout.EXIT_POINT_1X, s), "EXIT_POINT")
	assert_eq(GladeLayout.STAG_START, GladeLayout.point_scaled(GladeLayout.STAG_START_1X, s), "STAG_START")
	assert_eq(GladeLayout.CENTRE, GladeLayout.point_scaled(GladeLayout.CENTRE_1X, s), "CENTRE")
	assert_eq(GladeLayout.SPRING, GladeLayout.point_scaled(GladeLayout.SPRING_1X, s), "SPRING")
	assert_eq(GladeLayout.FIGHT_AREA, GladeLayout.rect_scaled(GladeLayout.FIGHT_AREA_1X, s), "FIGHT_AREA")
	assert_eq(GladeLayout.CHECKPOINTS[0], GladeLayout.point_scaled(GladeLayout.CHECKPOINTS_1X[0], s), "CHECKPOINTS")
	var items: Array = GladeLayout.interactables_scaled(s)
	for i: int in items.size():
		var row: Array = GladeLayout.INTERACTABLES[i]
		assert_true(row[0] == items[i][0] and Vector2(row[2], row[3]) == items[i][2] and Vector2(row[4], row[5]) == items[i][3], "INTERACTABLES %d" % i)
	var share: float = fight_share(s)
	print("glade scale %.1f (the game's): the Stag (radius %.0f) reaches %.1f %% of the fight area" % [s, GladeLayout.STAG_RADIUS, share * 100.0])
	assert_true(share >= MIN_SHARE[s], "the game scale's measured share (%.1f %%)" % (share * 100.0))


func test_points_and_paths_at_every_scale() -> void:
	for s: float in SCALES:
		var list: Array[Obstacle] = GladeLayout.build_scaled(s)
		var size: Vector2 = GladeLayout.size_scaled(s)
		var entry: Vector2 = GladeLayout.point_scaled(GladeLayout.ENTRY_POINT_1X, s)
		var exit: Vector2 = GladeLayout.point_scaled(GladeLayout.EXIT_POINT_1X, s)
		var centre: Vector2 = GladeLayout.point_scaled(GladeLayout.CENTRE_1X, s)
		var stag: Vector2 = GladeLayout.point_scaled(GladeLayout.STAG_START_1X, s)
		for p: Vector2 in [entry, exit, centre, GladeLayout.point_scaled(GladeLayout.CHECKPOINTS_1X[0], s)]:
			assert_true(SceneBounds.is_free(list, size, p, HERO), "%.1f: %s is free for the hero" % [s, str(p)])
		assert_true(GladeLayout.rect_scaled(GladeLayout.EXIT_RECT_1X, s).has_point(exit), "%.1f: the exit point is in the arch trigger" % s)
		assert_true(SceneBounds.is_free(list, size, stag, GladeLayout.STAG_RADIUS), "%.1f: the Stag's start is free" % s)
		var grid: LayoutFlood = LayoutFlood.new(size, list, HERO)
		assert_true(grid.flood(entry) > 0, "%.1f: the entrance is free" % s)
		assert_true(grid.reaches(centre), "%.1f: the middle is reachable" % s)
		assert_true(grid.reaches(exit), "%.1f: the arch is reachable" % s)
		assert_true(grid.reaches(stag), "%.1f: the Stag's start is reachable" % s)
		for row: Array in GladeLayout.interactables_scaled(s):
			assert_true(grid.reaches(row[3]), "%.1f: the hero can stand at the %s" % [s, row[0]])
		var outline: Array[Vector2] = GladeLayout.outline_scaled(s)
		var outside: int = 0
		for p: Vector2 in grid.reached_points():
			if not Geometry2D.is_point_in_polygon(p, PackedVector2Array(outline)) and SceneBounds.fit_radius(outline, p, 100.0) > 6.0:
				outside += 1
		assert_eq(outside, 0, "%.1f: reachable spots more than 6 px outside the outline" % s)


func test_the_stag_keeps_room_at_every_scale() -> void:
	for s: float in SCALES:
		var share: float = fight_share(s)
		print("glade scale %.1f: the Stag (radius %.0f) reaches %.1f %% of the %s fight area" % [s, GladeLayout.STAG_RADIUS, share * 100.0, str(GladeLayout.rect_scaled(GladeLayout.FIGHT_AREA_1X, s).size)])
		assert_true(share >= MIN_SHARE[s], "%.1f: the Stag's share of the fight area %.1f %%" % [s, share * 100.0])
		var grid: LayoutFlood = LayoutFlood.new(GladeLayout.size_scaled(s), GladeLayout.build_scaled(s), GladeLayout.STAG_RADIUS)
		grid.flood(GladeLayout.point_scaled(GladeLayout.STAG_START_1X, s))
		if s >= 0.7:
			assert_true(grid.reaches(GladeLayout.point_scaled(GladeLayout.CENTRE_1X, s)), "%.1f: the Stag reaches the middle" % s)


## The share of FIGHT_AREA (scaled) whose 4 px samples the Stag (STAG_RADIUS, not scaled) can reach from its start.
static func fight_share(s: float) -> float:
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.size_scaled(s), GladeLayout.build_scaled(s), GladeLayout.STAG_RADIUS)
	grid.flood(GladeLayout.point_scaled(GladeLayout.STAG_START_1X, s))
	var area: Rect2 = GladeLayout.rect_scaled(GladeLayout.FIGHT_AREA_1X, s)
	var total: int = 0
	var open: int = 0
	var y: float = area.position.y + 2.0
	while y < area.end.y:
		var x: float = area.position.x + 2.0
		while x < area.end.x:
			total += 1
			if grid.reaches(Vector2(x, y)):
				open += 1
			x += 4.0
		y += 4.0
	return float(open) / float(total)
