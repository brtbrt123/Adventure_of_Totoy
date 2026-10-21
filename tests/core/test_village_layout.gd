extends "res://tests/test_case.gd"
## Lanternfen village (core/village_layout.gd) at the game's scale (SCALE 0.7, 571x336): layout validity, free stand
## points, a hero-size path from the gate to the forest exit (and to every stand point), a sealed forest edge,
## determinism. Other scales (1.0, 0.8, 0.6): test_village_layout_scaled.gd.

const Obstacle := preload("res://core/obstacle.gd")
const VillageLayout := preload("res://core/village_layout.gd")
## Flood-fill cell size in px.
const CELL: int = 2


func test_ids_unique_radii_positive_inside_the_village() -> void:
	var list: Array[Obstacle] = VillageLayout.build()
	assert_true(list.size() > 50, "the village has a forest edge and props (%d colliders)" % list.size())
	var ids: Dictionary = {}
	# boundary circles may sit just outside the map (the east road leaves it); props must be inside
	var outer: Rect2 = Rect2(Vector2(-48.0, -48.0), VillageLayout.VILLAGE_SIZE + Vector2(96.0, 96.0))
	var size: Rect2 = Rect2(Vector2.ZERO, VillageLayout.VILLAGE_SIZE)
	var boundary: int = VillageLayout.boundary_circles().size()
	for i: int in list.size():
		var o: Obstacle = list[i]
		assert_false(ids.has(o.id), "obstacle id %d is unique" % o.id)
		ids[o.id] = true
		assert_true(o.radius > 0.0, "obstacle %d has a positive radius" % o.id)
		assert_eq(o.visual_id, &"", "obstacle %d is a collider only (the ground paints the props)" % o.id)
		assert_true(outer.has_point(o.center), "obstacle %d at %s is near the village" % [o.id, str(o.center)])
		if i >= boundary:
			assert_true(size.has_point(o.center), "prop collider %d at %s is inside the village" % [o.id, str(o.center)])


func test_spawn_and_stand_points_are_free() -> void:
	var list: Array[Obstacle] = VillageLayout.build()
	var points: Dictionary = VillageLayout.STAND_POINTS.duplicate()
	points[&"arrival_spawn"] = VillageLayout.ARRIVAL_SPAWN
	points[&"return_spawn"] = VillageLayout.RETURN_SPAWN
	points[&"gate"] = VillageLayout.GATE
	points[&"exit_forest"] = VillageLayout.EXIT_FOREST
	for key: StringName in points:
		var p: Vector2 = points[key]
		assert_true(Rect2(Vector2.ZERO, VillageLayout.VILLAGE_SIZE).has_point(p), "%s %s is inside the village" % [key, str(p)])
		for o: Obstacle in list:
			if p.distance_to(o.center) < o.radius + Tuning.PLAYER_RADIUS:
				failures.append("%s at %s overlaps obstacle %d at %s (r %.1f)" % [key, str(p), o.id, str(o.center), o.radius])
				break


func test_exit_and_stand_points_reachable_from_the_gate() -> void:
	var grid: PackedByteArray = _walkable(VillageLayout.build())
	var reach: PackedByteArray = _flood(grid, VillageLayout.ARRIVAL_SPAWN)
	assert_true(_reached(reach, VillageLayout.GATE), "the gate opening is reachable from the arrival spawn")
	assert_true(_reached(reach, VillageLayout.EXIT_FOREST), "the forest exit is reachable from the arrival spawn")
	assert_true(_reached(reach, VillageLayout.RETURN_SPAWN), "the return spawn is reachable")
	for key: StringName in VillageLayout.STAND_POINTS:
		var p: Vector2 = VillageLayout.STAND_POINTS[key]
		assert_true(_reached(reach, p), "%s at %s is reachable from the arrival spawn" % [key, str(p)])
	# the training post is solid; Totoy reaches its front
	var front: Vector2 = VillageLayout.TRAINING_DUMMY + Vector2(0.0, roundf(14.0 * VillageLayout.SCALE))
	assert_true(_reached(reach, front), "the front of the training dummy %s is reachable" % str(front))


func test_forest_edge_is_sealed() -> void:
	var reach: PackedByteArray = _flood(_walkable(VillageLayout.build()), VillageLayout.ARRIVAL_SPAWN)
	# deep forest, the mountain road behind the gate, the house body, the forge back, the canopy at the bottom (measured
	# at scale 1.0 on the painting, scaled like the layout)
	var outside_1x: Array[Vector2] = [
		Vector2(120, 80), Vector2(400, 20), Vector2(640, 120), Vector2(424, 80), Vector2(20, 300), Vector2(380, 478),
		Vector2(700, 470), Vector2(800, 120), Vector2(60, 450), Vector2(250, 120),
	]
	var outside: Array[Vector2] = [VillageLayout.TRAINING_DUMMY]
	for q: Vector2 in outside_1x:
		outside.append(VillageLayout.point_scaled(q, VillageLayout.SCALE))
	for p: Vector2 in outside:
		assert_false(_reached(reach, p), "%s outside the clearing is not reachable" % str(p))


func test_build_is_deterministic() -> void:
	var a: Array[Obstacle] = VillageLayout.build()
	var b: Array[Obstacle] = VillageLayout.build()
	assert_eq(a.size(), b.size(), "same number of colliders")
	for i: int in mini(a.size(), b.size()):
		assert_eq(a[i].id, b[i].id, "collider %d id" % i)
		assert_eq(a[i].center, b[i].center, "collider %d centre" % i)
		assert_eq(a[i].radius, b[i].radius, "collider %d radius" % i)


# --- helpers: a grid over the village, a cell is walkable when a hero-size circle at its centre touches nothing ---

func _cols() -> int:
	return int(VillageLayout.VILLAGE_SIZE.x) / CELL


func _rows() -> int:
	return int(VillageLayout.VILLAGE_SIZE.y) / CELL


func _walkable(list: Array[Obstacle]) -> PackedByteArray:
	var cols: int = _cols()
	var rows: int = _rows()
	var grid: PackedByteArray = PackedByteArray()
	grid.resize(cols * rows)
	grid.fill(1)
	for o: Obstacle in list:
		var reach: float = o.radius + Tuning.PLAYER_RADIUS
		var x0: int = maxi(0, int(floor((o.center.x - reach) / CELL)))
		var x1: int = mini(cols - 1, int(ceil((o.center.x + reach) / CELL)))
		var y0: int = maxi(0, int(floor((o.center.y - reach) / CELL)))
		var y1: int = mini(rows - 1, int(ceil((o.center.y + reach) / CELL)))
		for cy: int in range(y0, y1 + 1):
			for cx: int in range(x0, x1 + 1):
				var c: Vector2 = Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)
				if c.distance_to(o.center) < reach:
					grid[cy * cols + cx] = 0
	return grid


func _flood(grid: PackedByteArray, from: Vector2) -> PackedByteArray:
	var cols: int = _cols()
	var rows: int = _rows()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cols * rows)
	var start: int = int(from.y) / CELL * cols + int(from.x) / CELL
	if grid[start] == 0:
		failures.append("the flood start %s is blocked" % str(from))
		return seen
	var queue: PackedInt32Array = PackedInt32Array([start])
	seen[start] = 1
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x: int = i % cols
		var y: int = i / cols
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var n: int = ny * cols + nx
			if seen[n] == 0 and grid[n] == 1:
				seen[n] = 1
				queue.append(n)
	return seen


func _reached(seen: PackedByteArray, p: Vector2) -> bool:
	var x: int = clampi(int(p.x) / CELL, 0, _cols() - 1)
	var y: int = clampi(int(p.y) / CELL, 0, _rows() - 1)
	return seen[y * _cols() + x] == 1
