extends "res://tests/test_case.gd"
## The forest route's layout (core/forest_layout.gd): valid colliders, free and reachable points, the exit (behind the
## root gate) is out of reach until the lantern puzzle opens the gate, the east trail is a sealed dead end with the
## chest, determinism.

const Obstacle := preload("res://core/obstacle.gd")
const ForestLayout := preload("res://core/forest_layout.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const HERO: float = 6.0  # Tuning.PLAYER_RADIUS


func _flood(list: Array[Obstacle], radius: float = HERO) -> LayoutFlood:
	var grid: LayoutFlood = LayoutFlood.new(ForestLayout.SIZE, list, radius)
	grid.flood(ForestLayout.ENTRY_POINT)
	return grid


func test_the_colliders_are_valid() -> void:
	var list: Array[Obstacle] = ForestLayout.build()
	assert_true(list.size() > 60, "the forest has an edge chain and props (%d circles)" % list.size())
	var ids: Dictionary = {}
	for o: Obstacle in list:
		assert_false(ids.has(o.id), "unique id %d" % o.id)
		ids[o.id] = true
		assert_true(o.radius > 0.0, "collider %d has a positive radius" % o.id)
		assert_eq(o.visual_id, &"", "collider %d draws nothing (the painting does)" % o.id)
		assert_true(o.center.x > -o.radius and o.center.y > -o.radius and o.center.x < ForestLayout.SIZE.x + o.radius and o.center.y < ForestLayout.SIZE.y + o.radius, "collider %d touches the world" % o.id)


func test_build_is_deterministic() -> void:
	var a: Array[Obstacle] = ForestLayout.build()
	var b: Array[Obstacle] = ForestLayout.build()
	assert_eq(a.size(), b.size(), "same count")
	for i: int in mini(a.size(), b.size()):
		assert_true(a[i].id == b[i].id and a[i].center == b[i].center and a[i].radius == b[i].radius and a[i].feet == b[i].feet, "collider %d is the same on every build" % i)


func test_the_gate_is_a_separate_door() -> void:
	var closed: Array[Obstacle] = ForestLayout.build()
	var open: Array[Obstacle] = ForestLayout.build_with_gate(true)
	var gate: int = 0
	for o: Obstacle in closed:
		if ForestLayout.is_gate(o):
			gate += 1
	assert_eq(gate, ForestLayout.GATE_COLLIDERS.size(), "every gate collider is tagged by its feet")
	assert_eq(closed.size() - open.size(), gate, "opening the gate removes exactly its colliders")
	for o: Obstacle in open:
		assert_false(ForestLayout.is_gate(o), "no gate collider when open")


func test_every_point_is_inside_the_world_and_free() -> void:
	var list: Array[Obstacle] = ForestLayout.build()
	var size: Vector2 = ForestLayout.SIZE
	var points: Dictionary = {"entry": ForestLayout.ENTRY_POINT, "dead end": ForestLayout.DEAD_END}
	for k: int in ForestLayout.CHECKPOINTS.size():
		points["checkpoint %d" % k] = ForestLayout.CHECKPOINTS[k]
	for row: Array in ForestLayout.INTERACTABLES:
		points["stand at " + str(row[0])] = Vector2(row[4], row[5])
		var feet: Vector2 = Vector2(row[2], row[3])
		assert_true(Rect2(Vector2.ZERO, size).has_point(feet), "%s stands in the world" % row[0])
	for name: String in points:
		assert_true(SceneBounds.is_free(list, size, points[name], HERO), "%s is free for the hero %s" % [name, str(points[name])])
	for row: Array in ForestLayout.SPAWNS:
		var at: Vector2 = Vector2(row[1], row[2])
		assert_true(SceneBounds.is_free(list, size, at, ForestLayout.SPAWN_RADIUS[row[0]]), "%s spawn %s is free" % [row[0], str(at)])
	assert_true(SceneBounds.is_free(ForestLayout.build_with_gate(true), size, ForestLayout.EXIT_POINT, HERO), "the exit behind the gate is in the open")


func test_the_triggers_sit_on_their_edges() -> void:
	assert_eq(ForestLayout.ENTRY_RECT.position.x, 0.0, "the entry trigger is on the left edge")
	assert_eq(ForestLayout.EXIT_RECT.position.y, 0.0, "the exit is where the path behind the gate leaves the top edge")
	assert_true(ForestLayout.EXIT_RECT.position.x > 560.0, "the exit is behind the root gate at the top right")
	assert_true(ForestLayout.EXIT_RECT.has_point(ForestLayout.EXIT_POINT), "the exit point is inside its trigger")
	assert_false(ForestLayout.ENTRY_RECT.has_point(ForestLayout.ENTRY_POINT), "arriving does not stand in the trigger back")


func test_spawn_points_do_not_overlap() -> void:
	var rows: Array = ForestLayout.SPAWNS
	assert_eq(rows.size(), 7, "3 Mosslings, 2 Boars, 2 Glowmoths")
	for i: int in rows.size():
		for j: int in range(i + 1, rows.size()):
			var a: Vector2 = Vector2(rows[i][1], rows[i][2])
			var b: Vector2 = Vector2(rows[j][1], rows[j][2])
			var gap: float = ForestLayout.SPAWN_RADIUS[rows[i][0]] + ForestLayout.SPAWN_RADIUS[rows[j][0]] + 8.0
			assert_true(a.distance_to(b) >= gap, "spawns %d and %d keep apart" % [i, j])
		var at: Vector2 = Vector2(rows[i][1], rows[i][2])
		assert_true(at.distance_to(ForestLayout.ENTRY_POINT) > 100.0, "spawn %d is not on the entrance" % i)
		# the Mosslings wait in the first clearing, the Boars and Glowmoths in the second
		if rows[i][0] == "mossling":
			assert_true(at.x < 300.0, "mossling %d is in the first clearing" % i)
		else:
			assert_true(at.x >= 300.0, "%s %d is in the second clearing" % [rows[i][0], i])


func test_with_the_gate_closed_everything_but_the_exit_is_reachable() -> void:
	var grid: LayoutFlood = _flood(ForestLayout.build())
	assert_false(grid.reaches(ForestLayout.EXIT_POINT), "the exit is out of reach while the root gate is closed")
	assert_true(grid.reaches(ForestLayout.DEAD_END), "the end of the dead-end trail is reachable")
	for k: int in ForestLayout.CHECKPOINTS.size():
		assert_true(grid.reaches(ForestLayout.CHECKPOINTS[k]), "checkpoint %d is reachable" % k)
	for row: Array in ForestLayout.INTERACTABLES:
		assert_true(grid.reaches(Vector2(row[4], row[5])), "the hero can stand at the %s" % row[0])
	for row: Array in ForestLayout.SPAWNS:
		assert_true(grid.reaches(Vector2(row[1], row[2])), "the %s at %s is reachable" % [row[0], str(Vector2(row[1], row[2]))])


func test_with_the_gate_open_the_hero_walks_to_the_exit() -> void:
	assert_true(_flood(ForestLayout.build_with_gate(true)).reaches(ForestLayout.EXIT_POINT), "open: the hero walks through to the exit")


func test_the_right_edge_is_sealed() -> void:
	# the east trail is a dead end: even with the gate open nothing near the right edge is reachable
	var grid: LayoutFlood = _flood(ForestLayout.build_with_gate(true))
	var far: float = 0.0
	for p: Vector2 in grid.reached_points():
		if p.y > 150.0:  # below the exit path behind the gate
			far = maxf(far, p.x)
	assert_true(far < 770.0, "the dead-end trail stops short of the right edge (farthest x %.0f)" % far)


func test_the_walkable_ground_stays_inside_the_outline() -> void:
	# nothing leaks into the painted forest: every reachable spot (gate open, so the north path counts) is inside the
	# outline or within a few px of it (the gaps between edge circles are smaller than the hero)
	var grid: LayoutFlood = _flood(ForestLayout.build_with_gate(true))
	var outline: PackedVector2Array = PackedVector2Array(ForestLayout.OUTLINE)
	var outside: int = 0
	for p: Vector2 in grid.reached_points():
		if Geometry2D.is_point_in_polygon(p, outline):
			continue
		if SceneBounds.fit_radius(ForestLayout.OUTLINE, p, 100.0) > 6.0:
			outside += 1
	assert_eq(outside, 0, "reachable spots more than 6 px outside the outline")
	assert_true(grid.reached_points().size() > 3000, "the walkable ground is large (%d samples)" % grid.reached_points().size())
