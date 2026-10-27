extends SceneTree
## Owner's playtest: remove two logs, block rock/root footprints and solid antlers.
const SceneDefs := preload("res://core/scene_defs.gd")
const PropScene := preload("res://core/prop_scene.gd")
const Collision := preload("res://core/collision.gd")
const Obstacle := preload("res://core/obstacle.gd")
var failures: Array[String] = []


func expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func _init() -> void:
	var defs: Dictionary = PropScene.load_defs()
	for id: StringName in [&"forest_layered", &"glade_layered"]:
		var data: Dictionary = SceneDefs.layered_data(id)
		for p: Dictionary in PropScene.placements(data, defs):
			expect(p["id"] != (&"log_south" if id == &"forest_layered" else &"glade_log"), "Removed log has no placement or generated collider")
	var forest: Array[Obstacle] = SceneDefs.build_obstacles(&"forest_layered")
	expect(Collision.fits(forest, Vector2(232, 192), 6.0), "Removed forest log leaves no invisible obstacle")
	expect(not Collision.fits(forest, Vector2(101, 145), 6.0), "Upper central rock blocks feet")
	expect(not Collision.fits(forest, Vector2(91, 156), 6.0), "Left rock blocks feet")
	expect(not Collision.fits(forest, Vector2(112, 153), 6.0), "Right rock blocks feet")
	# Sweep into each changed solid from eight directions at walk and dash distances.
	for type_id: String in ["forest_rocks", "forest_tree_left", "forest_tree_middle", "forest_tree_right", "glade_tree", "glade_antler"]:
		var fixture: Dictionary = {"props": [{"id": "p", "type": type_id, "x": 100, "y": 100}]}
		var circles: Array[Vector3] = PropScene.prop_colliders(fixture, defs)
		var obstacles: Array[Obstacle] = []
		for circle: Vector3 in circles:
			var obstacle: Obstacle = Obstacle.new()
			obstacle.center = Vector2(circle.x, circle.y)
			obstacle.radius = circle.z
			obstacles.append(obstacle)
		for circle: Vector3 in circles:
			var centre: Vector2 = Vector2(circle.x, circle.y)
			for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1,1).normalized(), Vector2(-1,1).normalized(), Vector2(1,-1).normalized(), Vector2(-1,-1).normalized()]:
				for speed: float in [1.5, 36.0]:
					var at: Vector2 = centre - direction * 80.0
					for tick: int in 80:
						at = Collision.move_resolved(obstacles, at, at + direction * speed, 6.0)
						expect(Collision.fits(obstacles, at, 6.0), "%s cannot be entered from %s at speed %s" % [type_id, direction, speed])
	var glade: Dictionary = SceneDefs.layered_data(&"glade_layered")
	var antler: Dictionary = {}
	for row: Dictionary in PropScene.placements(glade, defs):
		if row["id"] == &"glade_antler":
			antler = row
	expect(not antler.is_empty() and bool(antler["solid"]) and antler["feet"].x > 430.0, "Antlers are solid at the side of the clearing")
	var glade_obstacles: Array[Obstacle] = SceneDefs.build_obstacles(&"glade_layered")
	expect(not Collision.fits(glade_obstacles, Vector2(458, 165), 6.0), "Upper antler branches block feet too")
	for x: float in [400.0, 508.0]:
		var at: Vector2 = Vector2(x, 120)
		for tick: int in 100:
			at = Collision.move_resolved(glade_obstacles, at, at + Vector2.UP * 1.5, 6.0)
		expect(at.y > 60.0, "Arch-side rock blocks a direct bypass at x=%s" % x)
	if failures.is_empty():
		print("PLAYTEST COLLISIONS OK: removed logs, rock/root footprints, solid side antlers, swept movement")
		quit()
	else:
		for failure: String in failures:
			printerr("FAIL " + failure)
		quit(1)
