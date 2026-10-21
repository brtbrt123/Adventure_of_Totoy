extends RefCounted
## A walkability grid for the painted scene layouts (core/forest_layout.gd, core/glade_layout.gd), used by their tests:
## the world sampled every STEP px; a sample is free when a body of `radius` there is inside the world and touches no
## collider (the same rule as core/scene_bounds.gd is_free). flood() marks every sample a body can walk to from a
## start in 4-neighbour steps (STEP px is far below every collider's size, so a step cannot skip a wall).
const Obstacle := preload("res://core/obstacle.gd")

const STEP: float = 4.0

var size: Vector2
var radius: float
var cols: int
var rows: int
var free: PackedByteArray
var reached: PackedByteArray


func _init(world: Vector2, obstacles: Array[Obstacle], body_radius: float) -> void:
	size = world
	radius = body_radius
	cols = int(world.x / STEP)
	rows = int(world.y / STEP)
	free = PackedByteArray()
	free.resize(cols * rows)
	free.fill(1)
	for j: int in rows:
		for i: int in cols:
			var p: Vector2 = point(i, j)
			if p.x < radius or p.y < radius or p.x > size.x - radius or p.y > size.y - radius:
				free[j * cols + i] = 0
	for o: Obstacle in obstacles:
		var reach: float = o.radius + radius
		var i0: int = maxi(0, int((o.center.x - reach) / STEP) - 1)
		var i1: int = mini(cols - 1, int((o.center.x + reach) / STEP) + 1)
		var j0: int = maxi(0, int((o.center.y - reach) / STEP) - 1)
		var j1: int = mini(rows - 1, int((o.center.y + reach) / STEP) + 1)
		for j: int in range(j0, j1 + 1):
			for i: int in range(i0, i1 + 1):
				if point(i, j).distance_to(o.center) < reach:
					free[j * cols + i] = 0
	reached = PackedByteArray()
	reached.resize(cols * rows)


## The world point of sample (i, j).
func point(i: int, j: int) -> Vector2:
	return Vector2((float(i) + 0.5) * STEP, (float(j) + 0.5) * STEP)


## The free sample nearest to `p` within 1.5 steps, or -1.
func cell_near(p: Vector2) -> int:
	var best: int = -1
	var best_d: float = STEP * 1.5
	var ci: int = int(p.x / STEP)
	var cj: int = int(p.y / STEP)
	for j: int in range(cj - 1, cj + 2):
		for i: int in range(ci - 1, ci + 2):
			if i < 0 or j < 0 or i >= cols or j >= rows or free[j * cols + i] == 0:
				continue
			var d: float = point(i, j).distance_to(p)
			if d <= best_d:
				best_d = d
				best = j * cols + i
	return best


## Marks every free sample connected to the one nearest `start`. Returns the number reached (0 if the start is blocked).
func flood(start: Vector2) -> int:
	reached.fill(0)
	var first: int = cell_near(start)
	if first < 0:
		return 0
	var queue: PackedInt32Array = PackedInt32Array([first])
	reached[first] = 1
	var head: int = 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		var i: int = c % cols
		@warning_ignore("integer_division")
		var j: int = c / cols
		for n: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			var k: int = n.y * cols + n.x
			if free[k] == 1 and reached[k] == 0:
				reached[k] = 1
				queue.append(k)
	return queue.size()


## After flood(): a body at `p` was reached (p itself free and next to a reached sample).
func reaches(p: Vector2) -> bool:
	var c: int = cell_near(p)
	return c >= 0 and reached[c] == 1


## After flood(): the reached samples' points.
func reached_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k: int in reached.size():
		if reached[k] == 1:
			@warning_ignore("integer_division")
			out.append(point(k % cols, k / cols))
	return out
