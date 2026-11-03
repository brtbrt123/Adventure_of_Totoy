extends "res://tests/test_case.gd"
## Root Hollow (data/scenes/root_hollow_layered_props.json, scene id SceneDefs.ROOT_HOLLOW_LAYERED): the chapter's map between the forest route and the
## Stag glade. Valid data, the route in and out, entries and checkpoints that are free and far from every mob, a broad central clearing and an
## optional shrine clearing that are mostly open ground, every mob on free reachable ground, the south loop and the shrine fork reachable, a walk
## from the forest end to the glade end, and the way north to the Hollow Trial that stays shut until the hollow is cleared.

const Obstacle := preload("res://core/obstacle.gd")
const PropScene := preload("res://core/prop_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Collision := preload("res://core/collision.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")

const HERO: float = 6.0
const SCENE: StringName = SceneDefs.ROOT_HOLLOW_LAYERED
const CENTRE_BOX: Vector2 = Vector2(160, 100)
const SHARE: float = 0.85

var _scene: Dictionary = SceneDefs.layered_data(SCENE)
var _defs: Dictionary = PropScene.load_defs()
var _def: Dictionary = SceneDefs.get_def(SCENE)


func _encounter(id: StringName) -> Dictionary:
	for row: Dictionary in _scene["encounters"]:
		if StringName(row["id"]) == id:
			return row
	return {}


func _rect(row: Dictionary) -> Rect2:
	var r: Array = row["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _flood(from_entry: StringName, flags: Array = []) -> LayoutFlood:
	var flood: LayoutFlood = LayoutFlood.new(_def["size"], SceneDefs.build_obstacles(SCENE, false, [], flags), HERO)
	flood.flood(_def["entries"][from_entry])
	return flood


func _share(flood: LayoutFlood, rect: Rect2) -> float:
	var total: int = 0
	var free: int = 0
	var y: float = rect.position.y
	while y <= rect.end.y:
		var x: float = rect.position.x
		while x <= rect.end.x:
			total += 1
			if flood.reaches(Vector2(x, y)):
				free += 1
			x += 8.0
		y += 8.0
	return float(free) / float(total)


func test_the_scene_data_is_valid() -> void:
	assert_eq(PropScene.validate(_scene, _defs).size(), 0, "no problems in the data: %s" % str(PropScene.validate(_scene, _defs)))
	assert_eq(_def["size"], Vector2(640, 400))
	assert_eq(_def["default_entry"], &"forest_side")
	assert_true(SceneDefs.ALL.has(SCENE) and SceneDefs.LAYERED.has(SCENE))


func test_the_route_runs_forest_hollow_glade_with_a_village_shortcut() -> void:
	var targets: Dictionary = {}
	for exit: Dictionary in _def["exits"]:
		targets[exit["id"]] = "%s/%s" % [exit["target_scene"], exit["target_entry"]]
	assert_eq(targets["to_forest"], "forest_layered/north")
	assert_eq(targets["to_glade"], "glade_layered/entrance")
	assert_eq(targets["shortcut"], "hollow_trial_layered/south")
	for exit: Dictionary in _def["exits"]:
		assert_true(SceneDefs.get_def(exit["target_scene"])["entries"].has(exit["target_entry"]), "%s has its entry" % exit["id"])


func test_entries_and_checkpoints_are_free_and_far_from_every_mob() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var points: Dictionary = (_def["entries"] as Dictionary).duplicate()
	for c: Dictionary in _def["checkpoints"]:
		points[c["id"]] = c["position"]
	for key: StringName in points:
		var p: Vector2 = points[key]
		assert_true(Collision.fits(obstacles, p, HERO), "%s is free" % key)
		for row: Dictionary in _scene["encounters"]:
			for m: Dictionary in row["mobs"]:
				var wake: float = float(Tuning.MOBS[StringName(m["type"])]["aggro"])
				var d: float = p.distance_to(Vector2(float(m["x"]), float(m["y"])))
				assert_true(d > wake + 12.0, "%s keeps a %s's wake radius (%.0f) away: %.0f" % [key, m["type"], wake, d])


func test_every_end_reaches_every_other_and_the_loop_and_the_fork_are_open() -> void:
	var cleared: Array = [&"cleared_hollow_center"]
	for entry: StringName in [&"forest_side", &"glade_side"]:
		var flood: LayoutFlood = _flood(entry)
		assert_true(flood.reaches(_def["entries"][&"forest_side"]) and flood.reaches(_def["entries"][&"glade_side"]), "%s reaches both ends of the way" % entry)
		assert_true(flood.reaches(Vector2(470, 285)), "the south pocket is reachable from %s" % entry)
		assert_true(flood.reaches(Vector2(110, 100)), "the shrine is reachable from %s" % entry)
		assert_true(flood.reaches(Vector2(62, 45)), "the foot of the shortcut is reachable from %s" % entry)
		assert_false(flood.reaches(_def["entries"][&"shortcut"]), "the root-knot barrier seals the shortcut from %s while the hollow is alive" % entry)
	for entry: StringName in [&"forest_side", &"glade_side", &"shortcut"]:
		var open: LayoutFlood = _flood(entry, cleared)
		for other: StringName in [&"forest_side", &"glade_side", &"shortcut"]:
			assert_true(open.reaches(_def["entries"][other]), "once cleared, %s reaches %s" % [entry, other])
	var sealed: LayoutFlood = _flood(&"shortcut")
	assert_false(sealed.reaches(_def["entries"][&"forest_side"]), "and the village side cannot walk in while it is shut")


func test_the_barrier_is_two_states_of_one_prop_and_the_open_one_leaves_the_gap() -> void:
	var closed: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var open: Array[Obstacle] = SceneDefs.build_obstacles(SCENE, false, [], [&"cleared_hollow_center"])
	assert_true(open.size() < closed.size(), "opening removes the blocking row")
	assert_eq(closed.size() - open.size(), 5, "the closed row has 9 circles, the open one keeps 4 side roots")
	var types: Dictionary = _defs["props"]
	assert_eq(types["root_hollow_barrier_closed"]["anchor"], types["root_hollow_barrier_open"]["anchor"], "the same anchor")
	assert_eq([types["root_hollow_barrier_closed"]["w"], types["root_hollow_barrier_closed"]["h"]], [types["root_hollow_barrier_open"]["w"], types["root_hollow_barrier_open"]["h"]], "the same canvas")
	var states: Dictionary = {"gate_open": false, "lit": [], "flags": [&"cleared_hollow_center"]}
	var shown: Array = []
	for placement: Dictionary in PropScene.placements(_scene, _defs, states):
		shown.append(String(placement.get("type", "")))
	assert_true(shown.has("root_hollow_barrier_open") and not shown.has("root_hollow_barrier_closed"), "the open sprite replaces the closed one")


func test_the_core_opens_the_barrier_when_the_central_fight_is_cleared() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.set_story_flags([&"received_first_sword"] as Array[StringName])
	var before: int = core.obstacles.size()
	var events: Array[GameEvent] = []
	core._grant_flag(&"cleared_hollow_center", events)
	assert_eq(before - core.obstacles.size(), 5, "the colliders changed on the tick the flag was set")


func test_the_boar_lane_and_every_exit_stay_clear_of_the_new_props() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var lane_y: float = 206.0
	var x: float = 246.0
	while x <= 414.0:
		assert_true(Collision.fits(obstacles, Vector2(x, lane_y), HERO + 6.0), "the boar lane is free at %.0f,%.0f" % [x, lane_y])
		x += 6.0
	var opened: Array[Obstacle] = SceneDefs.build_obstacles(SCENE, false, [], [&"cleared_hollow_center"])
	for exit: Dictionary in _def["exits"]:
		var rect: Rect2 = exit["rect"]
		var centre: Vector2 = rect.get_center()
		var inward: Vector2 = (Vector2(320, 200) - centre).normalized()
		assert_true(Collision.fits(opened, centre + inward * 12.0, HERO), "%s opens onto free ground" % exit["id"])


func test_the_centre_and_the_shrine_are_mostly_open_ground() -> void:
	var flood: LayoutFlood = _flood(&"forest_side")
	for id: StringName in [&"hollow_center", &"hollow_shrine"]:
		var share: float = _share(flood, _rect(_encounter(id)))
		assert_true(share >= SHARE, "%s: %.0f %% of its rectangle is free ground" % [id, share * 100.0])
	var centre: Rect2 = _rect(_encounter(&"hollow_center"))
	var fits: bool = false
	var y: float = centre.position.y - 8.0
	while y + CENTRE_BOX.y <= centre.end.y + 8.0 and not fits:
		var x: float = centre.position.x - 8.0
		while x + CENTRE_BOX.x <= centre.end.x + 8.0 and not fits:
			var ok: bool = true
			var py: float = y
			while ok and py <= y + CENTRE_BOX.y:
				var px: float = x
				while ok and px <= x + CENTRE_BOX.x:
					ok = flood.reaches(Vector2(px, py))
					px += 8.0
				py += 8.0
			fits = ok
			x += 4.0
		y += 4.0
	assert_true(fits, "an obstacle-free %s box fits the central clearing" % str(CENTRE_BOX))


func test_every_mob_stands_on_free_ground_apart_from_the_others() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var flood: LayoutFlood = _flood(&"forest_side")
	var spots: Array[Vector2] = []
	for row: Dictionary in _scene["encounters"]:
		var rect: Rect2 = _rect(row).grow(24.0)
		for m: Dictionary in row["mobs"]:
			var at: Vector2 = Vector2(float(m["x"]), float(m["y"]))
			var radius: float = float(Tuning.MOBS[StringName(m["type"])]["radius"])
			assert_true(Collision.fits(obstacles, at, radius + 2.0), "%s mob at %s fits" % [row["id"], at])
			assert_true(flood.reaches(at), "%s mob at %s is reachable" % [row["id"], at])
			assert_true(rect.has_point(at), "%s mob at %s stands in its clearing" % [row["id"], at])
			for other: Vector2 in spots:
				assert_true(at.distance_to(other) >= 30.0, "mobs at %s and %s stand apart" % [at, other])
			spots.append(at)


func test_walking_from_the_forest_end_to_the_glade_end() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE, &"forest_side")
	core.set_story_flags([&"debug_all_unlocked"] as Array[StringName])
	var bot: ExploreBot = ExploreBot.new()
	var exit: Rect2 = Rect2()
	for e: Dictionary in _def["exits"]:
		if e["id"] == &"to_glade":
			exit = e["rect"]
	assert_true(bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, exit), "a path exists")
	for i: int in 3200:
		core.step(bot.next_input(core.player.position))
		if core.exiting:
			break
	assert_true(core.exiting and core.pending_exit["target_scene"] == SceneDefs.GLADE_LAYERED, "the hero walked out of the east end (unarmed: nothing woke)")


func test_the_way_to_the_trial_opens_when_the_hollow_is_cleared() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE, &"shortcut")
	core.set_story_flags([&"received_first_sword"] as Array[StringName])
	var rect: Rect2 = Rect2()
	for e: Dictionary in _def["exits"]:
		if e["id"] == &"shortcut":
			rect = e["rect"]
	core.player.position = Vector2(62, 22)
	core.step(InputFrame.new())
	core.player.position = rect.get_center()
	var blocked: bool = false
	core.step(InputFrame.new())
	for event: GameEvent in core.last_events:
		blocked = blocked or event.type == GameEvent.EXIT_BLOCKED
	assert_true(blocked and not core.exiting, "shut with a message while the hollow is alive")
	core.set_story_flags([&"received_first_sword", &"cleared_hollow_center"] as Array[StringName])
	core.player.position = Vector2(62, 22)
	core.step(InputFrame.new())
	core.player.position = rect.get_center()
	core.step(InputFrame.new())
	assert_true(core.exiting and core.pending_exit["target_scene"] == SceneDefs.HOLLOW_TRIAL_LAYERED, "open once cleared, into the trial room")
