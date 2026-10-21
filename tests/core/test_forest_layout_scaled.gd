extends "res://tests/test_case.gd"
## The forest route layout at the scale options (core/forest_layout.gd build_scaled / *_scaled; the approved 1.0 layout
## is checked by test_forest_layout.gd): at 0.7, 0.6 and 0.5 (docs/previews/forest_scale_options.png) the same rules hold
## with the hero radius NOT scaled: valid colliders, free points, the exit behind the closed root gate is out of reach
## while everything else is reachable, the open gate lets the hero through, the dead end stays sealed, nothing outside
## the outline is reachable. Also: build_scaled(1.0) is exactly build().

const Obstacle := preload("res://core/obstacle.gd")
const ForestLayout := preload("res://core/forest_layout.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const SCALES: Array[float] = [0.7, 0.6, 0.5]
const HERO: float = 6.0  # Tuning.PLAYER_RADIUS, the same at every scale


func test_scale_one_is_the_approved_layout() -> void:
	var a: Array[Obstacle] = ForestLayout.build()
	var b: Array[Obstacle] = ForestLayout.build_scaled(1.0)
	assert_eq(a.size(), b.size(), "same count")
	for i: int in mini(a.size(), b.size()):
		assert_true(a[i].center == b[i].center and a[i].radius == b[i].radius and a[i].feet == b[i].feet, "collider %d" % i)
	assert_eq(ForestLayout.size_scaled(1.0), ForestLayout.SIZE, "size")
	assert_eq(ForestLayout.rect_scaled(ForestLayout.EXIT_RECT, 1.0), ForestLayout.EXIT_RECT, "exit")


func test_sizes_match_the_ground_options() -> void:
	# tools/art/make_forest_ground_from_reference.py size_for(): round(800 s) x round(480 s)
	assert_eq(ForestLayout.size_scaled(0.7), Vector2(560, 336), "0.7")
	assert_eq(ForestLayout.size_scaled(0.6), Vector2(480, 288), "0.6")
	assert_eq(ForestLayout.size_scaled(0.5), Vector2(400, 240), "0.5")


func test_colliders_and_points_at_every_scale() -> void:
	for s: float in SCALES:
		var list: Array[Obstacle] = ForestLayout.build_scaled(s)
		var size: Vector2 = ForestLayout.size_scaled(s)
		var ids: Dictionary = {}
		for o: Obstacle in list:
			assert_false(ids.has(o.id), "%.1f: unique id %d" % [s, o.id])
			ids[o.id] = true
			assert_true(o.radius > 0.0, "%.1f: collider %d has a radius" % [s, o.id])
		var points: Dictionary = {"entry": ForestLayout.point_scaled(ForestLayout.ENTRY_POINT, s),
			"dead end": ForestLayout.point_scaled(ForestLayout.DEAD_END, s)}
		for p: Vector2 in ForestLayout.checkpoints_scaled(s):
			points["checkpoint %s" % str(p)] = p
		for row: Array in ForestLayout.interactables_scaled(s):
			points["stand at " + str(row[0])] = row[3]
		for name: String in points:
			assert_true(SceneBounds.is_free(list, size, points[name], HERO), "%.1f: %s %s is free" % [s, name, str(points[name])])
		for row: Array in ForestLayout.spawns_scaled(s):
			assert_true(SceneBounds.is_free(list, size, row[1], ForestLayout.SPAWN_RADIUS[row[0]]), "%.1f: %s spawn %s is free" % [s, row[0], str(row[1])])
		var open: Array[Obstacle] = ForestLayout.build_scaled(s, true)
		var exit: Vector2 = ForestLayout.point_scaled(ForestLayout.EXIT_POINT, s)
		assert_true(SceneBounds.is_free(open, size, exit, HERO), "%.1f: the exit point is free" % s)
		assert_true(ForestLayout.rect_scaled(ForestLayout.EXIT_RECT, s).has_point(exit), "%.1f: the exit point is in its trigger" % s)


func test_the_gate_gates_the_exit_at_every_scale() -> void:
	for s: float in SCALES:
		var size: Vector2 = ForestLayout.size_scaled(s)
		var exit: Vector2 = ForestLayout.point_scaled(ForestLayout.EXIT_POINT, s)
		var closed: LayoutFlood = LayoutFlood.new(size, ForestLayout.build_scaled(s), HERO)
		assert_true(closed.flood(ForestLayout.point_scaled(ForestLayout.ENTRY_POINT, s)) > 0, "%.1f: the entry is free" % s)
		assert_false(closed.reaches(exit), "%.1f: the exit is out of reach with the gate closed" % s)
		assert_true(closed.reaches(ForestLayout.point_scaled(ForestLayout.DEAD_END, s)), "%.1f: the dead end is reachable" % s)
		for row: Array in ForestLayout.interactables_scaled(s):
			assert_true(closed.reaches(row[3]), "%.1f: the hero can stand at the %s" % [s, row[0]])
		for row: Array in ForestLayout.spawns_scaled(s):
			assert_true(closed.reaches(row[1]), "%.1f: the %s at %s is reachable" % [s, row[0], str(row[1])])
		for p: Vector2 in ForestLayout.checkpoints_scaled(s):
			assert_true(closed.reaches(p), "%.1f: checkpoint %s is reachable" % [s, str(p)])
		var open: LayoutFlood = LayoutFlood.new(size, ForestLayout.build_scaled(s, true), HERO)
		open.flood(ForestLayout.point_scaled(ForestLayout.ENTRY_POINT, s))
		assert_true(open.reaches(exit), "%.1f: the open gate lets the hero through to the exit" % s)
		var outline: PackedVector2Array = PackedVector2Array(ForestLayout.outline_scaled(s))
		var outside: int = 0
		var far: float = 0.0
		for p: Vector2 in open.reached_points():
			if not Geometry2D.is_point_in_polygon(p, outline) and SceneBounds.fit_radius(ForestLayout.outline_scaled(s), p, 100.0) > 6.0:
				outside += 1
			if p.y > 150.0 * s:
				far = maxf(far, p.x)
		assert_eq(outside, 0, "%.1f: reachable spots more than 6 px outside the outline" % s)
		assert_true(far < 770.0 * s, "%.1f: the dead end stays sealed (farthest x %.0f)" % [s, far])
