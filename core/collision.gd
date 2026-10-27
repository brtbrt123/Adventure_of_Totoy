extends RefCounted
## Circle-against-circles collision shared by the arena fight (core/game_core.gd) and exploration
## (core/explore_core.gd): the swept move that slides along solid props without tunnelling, the push-out, the "fits"
## test and the clamp into a rectangle with a ring search. Static functions only; the obstacles are passed in.
## (Extracted from game_core.gd on 2026-10-22 without changing a single rule: GameCore's methods now call these.)
const Tuning := preload("res://core/tuning.gd")
const Obstacle := preload("res://core/obstacle.gd")


## Moves a circle of `radius` from `before` towards `after` in steps of at most OBSTACLE_SWEEP_STEP pixels, pushing
## it out of every solid prop after each step: it slides along them and cannot tunnel, however fast it moves.
static func move_resolved(obstacles: Array[Obstacle], before: Vector2, after: Vector2, radius: float) -> Vector2:
	var delta: Vector2 = after - before
	var steps: int = maxi(1, ceili(delta.length() / Tuning.OBSTACLE_SWEEP_STEP))
	var step_delta: Vector2 = delta / steps
	var current: Vector2 = before
	for i: int in steps:
		current = push_out(obstacles, current + step_delta, radius)
	return current


## The nearest position at which a circle of `radius` at `point` touches no solid prop.
static func push_out(obstacles: Array[Obstacle], point: Vector2, radius: float) -> Vector2:
	var current: Vector2 = point
	for pass_index: int in 2:  # a second pass settles a circle squeezed between two props
		for obstacle: Obstacle in obstacles:
			var offset: Vector2 = current - obstacle.center
			var reach: float = obstacle.radius + radius
			var dist_sq: float = offset.length_squared()
			if dist_sq < reach * reach:
				var dist: float = sqrt(dist_sq)
				var dir: Vector2 = offset / dist if dist > 0.0001 else Vector2.DOWN
				current = obstacle.center + dir * reach
	return current


## True when a circle of `radius` at `point` overlaps no prop (0.001 px tolerance).
static func fits(obstacles: Array[Obstacle], point: Vector2, radius: float) -> bool:
	for obstacle: Obstacle in obstacles:
		if point.distance_to(obstacle.center) < obstacle.radius + radius - 0.001:
			return false
	return true


## `point` kept inside [low, high] and pushed out of the props. When a prop stands too close to the edge for the body
## to fit straight out of it, the nearest spot that fits is searched on small rings around it (2 px steps, 16
## directions), so nothing is left inside a prop.
static func clamp_point(obstacles: Array[Obstacle], point: Vector2, radius: float, low: Vector2, high: Vector2) -> Vector2:
	var spot: Vector2 = push_out(obstacles, point.clamp(low, high), radius).clamp(low, high)
	if fits(obstacles, spot, radius):
		return spot
	for ring: int in range(1, 17):
		for k: int in 16:
			var candidate: Vector2 = spot + Vector2.RIGHT.rotated(float(k) * TAU / 16.0) * (2.0 * ring)
			candidate = push_out(obstacles, candidate.clamp(low, high), radius).clamp(low, high)
			if fits(obstacles, candidate, radius):
				return candidate
	return spot
