extends RefCounted
## A walking bot for exploration tests (core tests and presentation smokes): plans a path on the layout flood grid
## (tests/layout_flood.gd) from the hero to a goal (a point, or any spot where the hero's body touches a rectangle),
## then gives one InputFrame per tick that walks along it. It only produces inputs; the core moves the hero.
const LayoutFlood := preload("res://tests/layout_flood.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Tuning := preload("res://core/tuning.gd")
const Obstacle := preload("res://core/obstacle.gd")

## The grid body is a little larger than the hero so the path keeps clear of the colliders.
const PAD: float = 1.0

var waypoints: Array[Vector2] = []
var _index: int = 0
var _last_position: Vector2 = Vector2.INF
var _stuck: int = 0


## Plans from `start` to the nearest reachable spot that satisfies the goal: `goal_rect` (the body touches it) when
## its size is not zero, else `goal_point` (within one grid step). Returns false when no path exists.
func plan(size: Vector2, obstacles: Array[Obstacle], start: Vector2, goal_point: Vector2, goal_rect: Rect2 = Rect2()) -> bool:
	var grid: LayoutFlood = LayoutFlood.new(size, obstacles, Tuning.PLAYER_RADIUS + PAD)
	var first: int = grid.cell_near(start)
	if first < 0:
		# the start may sit a hair closer to a collider than the padded grid allows: take the nearest free cell
		var best_d: float = INF
		for k: int in grid.free.size():
			if grid.free[k] == 1:
				@warning_ignore("integer_division")
				var d: float = grid.point(k % grid.cols, k / grid.cols).distance_to(start)
				if d < best_d:
					best_d = d
					first = k
		if first < 0 or best_d > 12.0:
			return false
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(grid.cols * grid.rows)
	parent.fill(-2)
	parent[first] = -1
	var queue: PackedInt32Array = PackedInt32Array([first])
	var head: int = 0
	var found: int = -1
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		var i: int = c % grid.cols
		@warning_ignore("integer_division")
		var j: int = c / grid.cols
		var p: Vector2 = grid.point(i, j)
		if _is_goal(p, goal_point, goal_rect):
			found = c
			break
		for n: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1), Vector2i(i + 1, j + 1), Vector2i(i - 1, j - 1), Vector2i(i + 1, j - 1), Vector2i(i - 1, j + 1)]:
			if n.x < 0 or n.y < 0 or n.x >= grid.cols or n.y >= grid.rows:
				continue
			var k: int = n.y * grid.cols + n.x
			if grid.free[k] == 0 or parent[k] != -2:
				continue
			# a diagonal step only when both side cells are free (no corner cutting)
			if n.x != i and n.y != j and (grid.free[j * grid.cols + n.x] == 0 or grid.free[n.y * grid.cols + i] == 0):
				continue
			parent[k] = c
			queue.append(k)
	if found < 0:
		return false
	var path: Array[Vector2] = []
	var c2: int = found
	while c2 >= 0:
		@warning_ignore("integer_division")
		path.push_front(grid.point(c2 % grid.cols, c2 / grid.cols))
		c2 = parent[c2]
	if goal_rect.size == Vector2.ZERO:
		path.append(goal_point)
	else:
		# finish by stepping into the rectangle (the world clamp stops the hero at the edge)
		var last: Vector2 = path[path.size() - 1]
		path.append(last.clamp(goal_rect.position, goal_rect.end))
	waypoints = path
	_index = 0
	_stuck = 0
	_last_position = Vector2.INF
	return true


func _is_goal(p: Vector2, goal_point: Vector2, goal_rect: Rect2) -> bool:
	if goal_rect.size != Vector2.ZERO:
		return p.clamp(goal_rect.position, goal_rect.end).distance_to(p) <= Tuning.PLAYER_RADIUS - 0.5
	return p.distance_to(goal_point) <= LayoutFlood.STEP


## The input for this tick for a hero at `position` (empty input when the path is done).
func next_input(position: Vector2) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	while _index < waypoints.size() and position.distance_to(waypoints[_index]) < 1.5:
		_index += 1
	if _index >= waypoints.size():
		return frame
	if _last_position != Vector2.INF and position.distance_to(_last_position) < 0.05:
		_stuck += 1
		if _stuck > 8 and _index < waypoints.size() - 1:
			_index += 1  # pressed against a wall corner: aim at the next waypoint
			_stuck = 0
	else:
		_stuck = 0
	_last_position = position
	frame.move = (waypoints[_index] - position).normalized()
	return frame


func done() -> bool:
	return _index >= waypoints.size()
