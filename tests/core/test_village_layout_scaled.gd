extends "res://tests/test_case.gd"
## The Lanternfen village layout at other scales (core/village_layout.gd build_scaled / *_scaled; the game uses SCALE
## 0.7, checked by test_village_layout.gd): the same checks at 1.0 (the first 816x480 version), 0.8 and 0.6 (valid
## colliders, free points, a hero-size path from the gate to the exit and every stand point, a sealed forest edge) with
## the player radius NOT scaled, plus: the plain constants and build() are exactly the 0.7 values.

const Obstacle := preload("res://core/obstacle.gd")
const VillageLayout := preload("res://core/village_layout.gd")
## The other options rendered for the human (docs/previews/village_scale_options.png).
const SCALES: Array[float] = [1.0, 0.8, 0.6]
## Flood-fill cell size in px.
const CELL: int = 2
## Points outside the clearing at scale 1 (as in test_village_layout.gd), scaled with the village.
const OUTSIDE: Array[Vector2] = [
	Vector2(120, 80), Vector2(400, 20), Vector2(640, 120), Vector2(424, 80), Vector2(20, 300), Vector2(380, 478),
	Vector2(700, 470), Vector2(800, 120), Vector2(60, 450), Vector2(250, 120),
]


func test_the_constants_are_the_scaled_layout() -> void:
	var s: float = VillageLayout.SCALE
	assert_eq(s, 0.7, "the game's village scale (the human's choice, 2026-10-22)")
	var a: Array[Obstacle] = VillageLayout.build()
	var b: Array[Obstacle] = VillageLayout.build_scaled(s)
	assert_eq(a.size(), b.size(), "same number of colliders")
	for i: int in mini(a.size(), b.size()):
		assert_eq(a[i].center, b[i].center, "collider %d centre" % i)
		assert_eq(a[i].radius, b[i].radius, "collider %d radius" % i)
	assert_eq(VillageLayout.boundary_circles().size(), VillageLayout.boundary_circles(s).size(), "edge circles")
	assert_eq(VillageLayout.VILLAGE_SIZE, VillageLayout.village_size_scaled(s), "VILLAGE_SIZE")
	assert_eq(VillageLayout.ARRIVAL_SPAWN, VillageLayout.point_scaled(VillageLayout.ARRIVAL_SPAWN_1X, s), "ARRIVAL_SPAWN")
	assert_eq(VillageLayout.GATE, VillageLayout.point_scaled(VillageLayout.GATE_1X, s), "GATE")
	assert_eq(VillageLayout.EXIT_FOREST, VillageLayout.point_scaled(VillageLayout.EXIT_FOREST_1X, s), "EXIT_FOREST")
	assert_eq(VillageLayout.RETURN_SPAWN, VillageLayout.point_scaled(VillageLayout.RETURN_SPAWN_1X, s), "RETURN_SPAWN")
	assert_eq(VillageLayout.TRAINING_DUMMY, VillageLayout.point_scaled(VillageLayout.TRAINING_DUMMY_1X, s), "TRAINING_DUMMY")
	assert_eq(VillageLayout.EXIT_FOREST_HALF_WIDTH, roundf(VillageLayout.EXIT_FOREST_HALF_WIDTH_1X * s), "exit half width")
	var stand: Dictionary = VillageLayout.stand_points_scaled(s)
	assert_eq(stand.size(), VillageLayout.STAND_POINTS.size(), "same stand point ids")
	for key: StringName in VillageLayout.STAND_POINTS:
		assert_eq(VillageLayout.STAND_POINTS[key], stand.get(key), "stand point %s" % key)


func test_sizes_match_the_ground_files() -> void:
	# tools/art/make_village_ground_from_reference.py size_for(): round(816 * s) x round(480 * s)
	assert_eq(VillageLayout.village_size_scaled(1.0), Vector2(816, 480), "1.0")
	assert_eq(VillageLayout.village_size_scaled(0.8), Vector2(653, 384), "0.8")
	assert_eq(VillageLayout.village_size_scaled(0.7), Vector2(571, 336), "0.7")
	assert_eq(VillageLayout.village_size_scaled(0.6), Vector2(490, 288), "0.6")


func test_colliders_valid_at_every_scale() -> void:
	for s: float in SCALES:
		var list: Array[Obstacle] = VillageLayout.build_scaled(s)
		var size: Vector2 = VillageLayout.village_size_scaled(s)
		var outer: Rect2 = Rect2(Vector2(-48.0, -48.0), size + Vector2(96.0, 96.0))
		var inside: Rect2 = Rect2(Vector2.ZERO, size)
		var boundary: int = VillageLayout.boundary_circles(s).size()
		assert_true(list.size() > 50, "scale %.1f: forest edge and props (%d colliders)" % [s, list.size()])
		for i: int in list.size():
			var o: Obstacle = list[i]
			assert_true(o.radius > 0.0, "scale %.1f: obstacle %d has a positive radius" % [s, o.id])
			assert_true(outer.has_point(o.center), "scale %.1f: obstacle %d near the village" % [s, o.id])
			if i >= boundary:
				assert_true(inside.has_point(o.center), "scale %.1f: prop %d inside the village" % [s, o.id])


func test_points_free_at_every_scale() -> void:
	for s: float in SCALES:
		var list: Array[Obstacle] = VillageLayout.build_scaled(s)
		var size: Vector2 = VillageLayout.village_size_scaled(s)
		for key: StringName in _points(s):
			var p: Vector2 = _points(s)[key]
			assert_true(Rect2(Vector2.ZERO, size).has_point(p), "scale %.1f: %s inside the village" % [s, key])
			for o: Obstacle in list:
				if p.distance_to(o.center) < o.radius + Tuning.PLAYER_RADIUS:
					failures.append("scale %.1f: %s at %s overlaps obstacle %d at %s (r %.1f)" % [
						s, key, str(p), o.id, str(o.center), o.radius])
					break


func test_paths_and_sealed_edge_at_every_scale() -> void:
	for s: float in SCALES:
		var size: Vector2 = VillageLayout.village_size_scaled(s)
		var reach: PackedByteArray = _flood(_walkable(VillageLayout.build_scaled(s), size), size,
				VillageLayout.point_scaled(VillageLayout.ARRIVAL_SPAWN_1X, s))
		for key: StringName in _points(s):
			var p: Vector2 = _points(s)[key]
			assert_true(_reached(reach, size, p), "scale %.1f: %s at %s reachable from the arrival spawn" % [s, key, str(p)])
		var dummy: Vector2 = VillageLayout.point_scaled(VillageLayout.TRAINING_DUMMY_1X, s)
		var front: Vector2 = dummy + Vector2(0.0, 14.0 * s)
		assert_true(_reached(reach, size, front), "scale %.1f: the front of the dummy %s reachable" % [s, str(front)])
		var outside: Array[Vector2] = [dummy]
		for p: Vector2 in OUTSIDE:
			outside.append(p * s)
		for p: Vector2 in outside:
			assert_false(_reached(reach, size, p), "scale %.1f: %s outside the clearing not reachable" % [s, str(p)])


# --- helpers (as in test_village_layout.gd, with the village size passed in) ---

func _points(s: float) -> Dictionary:
	var points: Dictionary = VillageLayout.stand_points_scaled(s)
	points[&"arrival_spawn"] = VillageLayout.point_scaled(VillageLayout.ARRIVAL_SPAWN_1X, s)
	points[&"return_spawn"] = VillageLayout.point_scaled(VillageLayout.RETURN_SPAWN_1X, s)
	points[&"gate"] = VillageLayout.point_scaled(VillageLayout.GATE_1X, s)
	points[&"exit_forest"] = VillageLayout.point_scaled(VillageLayout.EXIT_FOREST_1X, s)
	return points


func _walkable(list: Array[Obstacle], size: Vector2) -> PackedByteArray:
	var cols: int = int(size.x) / CELL
	var rows: int = int(size.y) / CELL
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


func _flood(grid: PackedByteArray, size: Vector2, from: Vector2) -> PackedByteArray:
	var cols: int = int(size.x) / CELL
	var rows: int = int(size.y) / CELL
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


func _reached(seen: PackedByteArray, size: Vector2, p: Vector2) -> bool:
	var cols: int = int(size.x) / CELL
	var rows: int = int(size.y) / CELL
	var x: int = clampi(int(p.x) / CELL, 0, cols - 1)
	var y: int = clampi(int(p.y) / CELL, 0, rows - 1)
	return seen[y * cols + x] == 1
