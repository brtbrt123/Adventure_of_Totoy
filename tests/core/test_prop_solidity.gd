extends "res://tests/test_case.gd"
## The collision audit of the human's playtest (2026-10-22: "why can I walk in this stone and water and on the door
## too"): every visibly solid painted object listed in FOOTPRINTS (its base on the ground painting, in game pixels, read
## off the zoomed grounds) must never hold the hero's feet. The real ExploreCore (the fight's Player, swept collision)
## walks the hero at each footprint from the four sides (and the diagonals) for two seconds, also dashing; the feet
## must stay outside the footprint, and from at least one side the hero must get within 12 px of it (the collider is on the
## painted object, not somewhere else). Also: interaction stand points stay in front of the solid door / gate.

const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const Collision := preload("res://core/collision.gd")
const VillageLayout := preload("res://core/village_layout.gd")
const ForestLayout := preload("res://core/forest_layout.gd")

## [scene, what, footprint (where the painted object meets the ground; feet inside it would stand in or on it),
## optional: the only directions to walk at it from]
const FOOTPRINTS: Array = [
	# the Stag glade: the five standing stones (the spring and the slabs were removed from the art on 2026-10-22)
	[&"glade", "rune stone (back)", Rect2(294, 140, 15, 6)],
	[&"glade", "rune stone (right)", Rect2(356, 160, 14, 6)],
	[&"glade", "rune stone (left)", Rect2(219, 161, 14, 6)],
	[&"glade", "standing stone", Rect2(206, 200, 13, 6)],
	[&"glade", "rune stone (front)", Rect2(258, 229, 18, 6)],
	# Lanternfen: the house door, the rune gate's door leaf and pillars, the training post, the shrine, the lamp post
	[&"village", "house door", Rect2(425, 138, 20, 12)],
	[&"village", "gate door leaf", Rect2(131, 166, 13, 8)],
	[&"village", "gate pillar (left)", Rect2(92, 182, 14, 8)],
	[&"village", "gate pillar (right)", Rect2(149, 164, 12, 8)],
	[&"village", "training post", Rect2(387, 205, 6, 7)],
	[&"village", "shrine", Rect2(136, 282, 14, 12)],
	[&"village", "lamp post", Rect2(198, 299, 4, 4)],
	# the forest route: the closed root gate across the path, both lantern pedestals, the signpost, the mossy stone
	# (only from the front: the path behind the gate is painted over by the gate's roots, the hero gets there only when
	# it is open)
	[&"forest", "root gate (closed)", Rect2(345, 96, 56, 10), [Vector2.UP, Vector2(1, -1), Vector2(-1, -1)]],
	[&"forest", "lantern pedestal (west)", Rect2(301, 138, 14, 8)],
	[&"forest", "lantern pedestal (east)", Rect2(374, 160, 14, 8)],
	[&"forest", "signpost", Rect2(147, 106, 5, 5)],
	[&"forest", "mossy stone (and the ferns at its foot)", Rect2(192, 110, 18, 16)],
]
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]


func _frame(move: Vector2, dash: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move = move.normalized()
	f.dash_pressed = dash
	return f


func test_the_hero_never_stands_in_a_solid_painted_object() -> void:
	for row: Array in FOOTPRINTS:
		var scene: StringName = row[0]
		var what: String = row[1]
		var rect: Rect2 = row[2]
		var core: ExploreCore = ExploreCore.new(scene)
		var centre: Vector2 = rect.get_center()
		var closest: float = INF
		var tried: int = 0
		var directions: Array = row[3] if row.size() > 3 else DIRECTIONS
		for dir: Vector2 in directions:
			var start: Vector2 = centre - dir.normalized() * (maxf(rect.size.x, rect.size.y) * 0.5 + 22.0)
			if not Collision.fits(core.obstacles, start, Tuning.PLAYER_RADIUS):
				continue
			tried += 1
			core.place_at(start)
			core.exiting = false
			var inside: int = 0
			for i: int in 120:
				core.step(_frame(dir, i == 30))
				core.exiting = false
				var feet: Vector2 = core.player.position
				if rect.has_point(feet):
					inside += 1
				closest = minf(closest, _distance(rect, feet))
			assert_eq(inside, 0, "%s: %s: ticks with the feet inside it, walking %s" % [scene, what, str(dir)])
		assert_true(tried >= 1, "%s: %s: approached from at least one side" % [scene, what])
		assert_true(closest <= 12.0, "%s: %s: the hero gets within 12 px of it from some side (%.1f): the collider sits on it" % [scene, what, closest])


func test_the_door_and_the_gate_are_used_from_in_front() -> void:
	var def: Dictionary = SceneDefs.get_def(SceneDefs.VILLAGE)
	var obstacles: Array = SceneDefs.build_obstacles(SceneDefs.VILLAGE)
	for o: Dictionary in def["objects"]:
		if o["id"] == &"edda_door":
			assert_eq(o["position"], VillageLayout.EDDA_DOOR, "the door's feet are its threshold")
			assert_true(Vector2(o["stand"]).y > VillageLayout.EDDA_DOOR.y + 8.0, "the knock spot is in front of (south of) the door")
			assert_true(Collision.fits(obstacles, o["stand"], Tuning.PLAYER_RADIUS), "the knock spot is free")
			assert_false(Collision.fits(obstacles, VillageLayout.EDDA_DOOR, Tuning.PLAYER_RADIUS), "the doorway is solid")
	for row: Array in ForestLayout.INTERACTABLES:
		if row[0] == "root_gate":
			assert_true(Vector2(row[4], row[5]).y > ForestLayout.GATE_FEET.y + 8.0, "the gate's look spot is in front of it")
	# the closed gate: walking north up the path stops in front of the painted gate's base (y about 106)
	var core: ExploreCore = ExploreCore.new(SceneDefs.FOREST, &"", false)
	for x: float in [350.0, 360.0, 372.0, 384.0, 396.0]:
		core.place_at(Vector2(x, 140))
		for i: int in 90:
			core.step(_frame(Vector2.UP))
		assert_true(core.player.position.y >= 112.0, "the closed root gate stops the hero in front of it at x %.0f (y %.1f)" % [x, core.player.position.y])


static func _distance(rect: Rect2, p: Vector2) -> float:
	var q: Vector2 = p.clamp(rect.position, rect.end)
	return q.distance_to(p)
