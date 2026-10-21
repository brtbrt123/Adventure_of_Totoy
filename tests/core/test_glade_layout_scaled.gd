extends "res://tests/test_case.gd"
## The Stag glade layout at the scale options (core/glade_layout.gd build_scaled / *_scaled; the approved 1.0 layout is
## checked by test_glade_layout.gd): at 0.7, 0.6 and 0.5 (docs/previews/glade_scale_options.png) with the hero radius and
## STAG_RADIUS NOT scaled: valid colliders, free points, a hero walks from the entrance to the middle and out through
## the arch, nothing outside the outline is reachable. The Stag's share of the fight area (FIGHT_AREA scaled with the
## scene) is measured by fight_share() and must stay at least MIN_SHARE[scale] (the 1.0 rule is 80 %; the smaller
## options cannot keep it, the numbers are reported in docs/STATUS.md). build_scaled(1.0) is exactly build().

const Obstacle := preload("res://core/obstacle.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const SCALES: Array[float] = [0.7, 0.6, 0.5]
const HERO: float = 6.0  # Tuning.PLAYER_RADIUS, the same at every scale
## The measured share of the scaled fight area the Stag (radius 20) reaches (68.9 / 59.5 / 30.2 %), rounded down to
## whole percent: a guard against regressions, not the 80 % rule (which only the 1.0 layout meets).
const MIN_SHARE: Dictionary = {0.7: 0.68, 0.6: 0.59, 0.5: 0.30}


func test_scale_one_is_the_approved_layout() -> void:
	var a: Array[Obstacle] = GladeLayout.build()
	var b: Array[Obstacle] = GladeLayout.build_scaled(1.0)
	assert_eq(a.size(), b.size(), "same count")
	for i: int in mini(a.size(), b.size()):
		assert_true(a[i].center == b[i].center and a[i].radius == b[i].radius, "collider %d" % i)
	assert_eq(GladeLayout.rect_scaled(GladeLayout.FIGHT_AREA, 1.0), GladeLayout.FIGHT_AREA, "fight area")
	assert_near(fight_share(1.0), 0.826, 0.002, "the 1.0 share")


func test_points_and_paths_at_every_scale() -> void:
	for s: float in SCALES:
		var list: Array[Obstacle] = GladeLayout.build_scaled(s)
		var size: Vector2 = GladeLayout.size_scaled(s)
		var entry: Vector2 = GladeLayout.point_scaled(GladeLayout.ENTRY_POINT, s)
		var exit: Vector2 = GladeLayout.point_scaled(GladeLayout.EXIT_POINT, s)
		var centre: Vector2 = GladeLayout.point_scaled(GladeLayout.CENTRE, s)
		var stag: Vector2 = GladeLayout.point_scaled(GladeLayout.STAG_START, s)
		for p: Vector2 in [entry, exit, centre, GladeLayout.point_scaled(GladeLayout.CHECKPOINTS[0], s)]:
			assert_true(SceneBounds.is_free(list, size, p, HERO), "%.1f: %s is free for the hero" % [s, str(p)])
		assert_true(GladeLayout.rect_scaled(GladeLayout.EXIT_RECT, s).has_point(exit), "%.1f: the exit point is in the arch trigger" % s)
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
		print("glade scale %.1f: the Stag (radius %.0f) reaches %.1f %% of the %s fight area" % [s, GladeLayout.STAG_RADIUS, share * 100.0, str(GladeLayout.rect_scaled(GladeLayout.FIGHT_AREA, s).size)])
		assert_true(share >= MIN_SHARE[s], "%.1f: the Stag's share of the fight area %.1f %%" % [s, share * 100.0])
		var grid: LayoutFlood = LayoutFlood.new(GladeLayout.size_scaled(s), GladeLayout.build_scaled(s), GladeLayout.STAG_RADIUS)
		grid.flood(GladeLayout.point_scaled(GladeLayout.STAG_START, s))
		assert_true(grid.reaches(GladeLayout.point_scaled(GladeLayout.CENTRE, s)), "%.1f: the Stag reaches the middle" % s)


## The share of FIGHT_AREA (scaled) whose 4 px samples the Stag (STAG_RADIUS, not scaled) can reach from its start.
static func fight_share(s: float) -> float:
	var grid: LayoutFlood = LayoutFlood.new(GladeLayout.size_scaled(s), GladeLayout.build_scaled(s), GladeLayout.STAG_RADIUS)
	grid.flood(GladeLayout.point_scaled(GladeLayout.STAG_START, s))
	var area: Rect2 = GladeLayout.rect_scaled(GladeLayout.FIGHT_AREA, s)
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
