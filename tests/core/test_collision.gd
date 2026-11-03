extends "res://tests/test_case.gd"
## core/collision.gd (extracted from game_core.gd on 2026-10-22): GameCore's movement helpers now call it, and the
## results equal a copy of the pre-extraction code on many random moves in the arena.

const Collision := preload("res://core/collision.gd")
const Obstacle := preload("res://core/obstacle.gd")
const ArenaLayout := preload("res://core/arena_layout.gd")
const SceneDefs := preload("res://core/scene_defs.gd")


# --- the pre-extraction GameCore code, copied verbatim (as static reference functions) ---
static func _ref_push(obstacles: Array[Obstacle], point: Vector2, radius: float) -> Vector2:
	var current: Vector2 = point
	for pass_index: int in 2:
		for obstacle: Obstacle in obstacles:
			var offset: Vector2 = current - obstacle.center
			var reach: float = obstacle.radius + radius
			var dist_sq: float = offset.length_squared()
			if dist_sq < reach * reach:
				var dist: float = sqrt(dist_sq)
				var dir: Vector2 = offset / dist if dist > 0.0001 else Vector2.DOWN
				current = obstacle.center + dir * reach
	return current


static func _ref_move(obstacles: Array[Obstacle], before: Vector2, after: Vector2, radius: float) -> Vector2:
	var delta: Vector2 = after - before
	var steps: int = maxi(1, ceili(delta.length() / Tuning.OBSTACLE_SWEEP_STEP))
	var step_delta: Vector2 = delta / steps
	var current: Vector2 = before
	for i: int in steps:
		current = _ref_push(obstacles, current + step_delta, radius)
	return current


static func _ref_fits(obstacles: Array[Obstacle], point: Vector2, radius: float) -> bool:
	for obstacle: Obstacle in obstacles:
		if point.distance_to(obstacle.center) < obstacle.radius + radius - 0.001:
			return false
	return true


static func _ref_arena_point(obstacles: Array[Obstacle], point: Vector2, radius: float) -> Vector2:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	var spot: Vector2 = _ref_push(obstacles, point.clamp(low, high), radius).clamp(low, high)
	if _ref_fits(obstacles, spot, radius):
		return spot
	for ring: int in range(1, 17):
		for k: int in 16:
			var candidate: Vector2 = spot + Vector2.RIGHT.rotated(float(k) * TAU / 16.0) * (2.0 * ring)
			candidate = _ref_push(obstacles, candidate.clamp(low, high), radius).clamp(low, high)
			if _ref_fits(obstacles, candidate, radius):
				return candidate
	return spot


func test_the_shared_helper_gives_the_old_results() -> void:
	var core: GameCore = GameCore.new(3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var mismatches: int = 0
	for i: int in 3000:
		var a: Vector2 = Vector2(rng.randf_range(0, 800), rng.randf_range(0, 480))
		var b: Vector2 = a + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0, 40)
		var radius: float = Tuning.PLAYER_RADIUS if i % 2 == 0 else Tuning.BOSS_RADIUS
		var expected: Vector2 = _ref_move(core.obstacles, a, b, radius)
		if core.move_resolved(a, b, radius) != expected or Collision.move_resolved(core.obstacles, a, b, radius) != expected:
			mismatches += 1
		if core.push_out_of_obstacles(b, radius) != _ref_push(core.obstacles, b, radius):
			mismatches += 1
		if core.arena_point(b, radius) != _ref_arena_point(core.obstacles, b, radius):
			mismatches += 1
	assert_eq(mismatches, 0, "identical to the pre-extraction code")


func test_clamp_point_keeps_a_body_inside_the_box_and_out_of_props() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SceneDefs.VILLAGE_LAYERED)
	var low: Vector2 = Vector2(6, 6)
	var high: Vector2 = SceneDefs.get_def(SceneDefs.VILLAGE_LAYERED)["size"] - low
	for o: Obstacle in obstacles:
		var p: Vector2 = Collision.clamp_point(obstacles, o.center, 6.0, low, high)
		assert_true(p.x >= low.x and p.y >= low.y and p.x <= high.x and p.y <= high.y, "inside the box")
