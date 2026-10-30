extends "res://tests/test_case.gd"
## The mobs of the forest route (the "encounters" of data/scenes/forest_layered_props.json, scene id SceneDefs.FOREST_LAYERED): a pack
## of Mosslings on the first trail and two Boars at the bend before the lantern puzzle. Valid rows, every mob on free ground that the hero
## can walk to and apart from the others, the way in and the north entry far outside every wake radius, both clearings mostly open ground,
## the pack waking when an armed hero walks up, and an unarmed hero walking past in peace.

const Obstacle := preload("res://core/obstacle.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Collision := preload("res://core/collision.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const HERO: float = 6.0
const SCENE: StringName = SceneDefs.FOREST_LAYERED
const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
const SHARE: float = 0.8

var _scene: Dictionary = SceneDefs.layered_data(SCENE)
var _def: Dictionary = SceneDefs.get_def(SCENE)


func _rect(row: Dictionary) -> Rect2:
	var r: Array = row["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _flood() -> LayoutFlood:
	var flood: LayoutFlood = LayoutFlood.new(_def["size"], SceneDefs.build_obstacles(SCENE), HERO)
	flood.flood(_def["entries"][&"village_side"])
	return flood


func test_the_forest_has_its_two_encounters_with_known_mobs() -> void:
	var rows: Array = _scene["encounters"]
	assert_eq(rows.size(), 2, "a trail and a bend")
	for row: Dictionary in rows:
		assert_true(not _rect(row).has_area() == false, "%s has a fight floor" % row["id"])
		assert_true(float(row["leash"]) > 0.0)
		assert_true((row["mobs"] as Array).size() >= 2, "%s has a pack" % row["id"])
		for m: Dictionary in row["mobs"]:
			assert_true(Tuning.MOBS.has(StringName(m["type"])), "%s: %s is a known mob" % [row["id"], m["type"]])
	var field: MobField = MobField.for_scene(_def) as MobField
	assert_true(field != null and field.encounters.size() == 2, "the field is built from the scene")


func test_every_mob_stands_on_free_ground_it_can_walk_to_and_apart_from_the_others() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var flood: LayoutFlood = _flood()
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


func test_the_way_in_and_the_north_entry_are_outside_every_wake_radius() -> void:
	var points: Dictionary = {"village_side": _def["entries"][&"village_side"], "north": _def["entries"][&"north"], "entrance checkpoint": SceneDefs.checkpoint(SCENE, &"forest_layered_entrance")["position"]}
	for key: String in points:
		var p: Vector2 = points[key]
		for row: Dictionary in _scene["encounters"]:
			for m: Dictionary in row["mobs"]:
				var wake: float = float(Tuning.MOBS[StringName(m["type"])]["aggro"])
				var d: float = p.distance_to(Vector2(float(m["x"]), float(m["y"])))
				assert_true(d > wake + 12.0, "%s keeps a %s's wake radius (%.0f) away: %.0f" % [key, m["type"], wake, d])


func test_both_clearings_are_mostly_open_ground() -> void:
	var flood: LayoutFlood = _flood()
	for row: Dictionary in _scene["encounters"]:
		var rect: Rect2 = _rect(row)
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
		var share: float = float(free) / float(total)
		assert_true(share >= SHARE, "%s: %.0f %% of its rectangle is free ground" % [row["id"], share * 100.0])


func test_an_armed_hero_walking_up_wakes_the_trail_and_an_unarmed_one_does_not() -> void:
	var armed: ExploreCore = ExploreCore.new(SCENE)
	armed.set_story_flags(ARMED)
	var unarmed: ExploreCore = ExploreCore.new(SCENE)
	var first: Dictionary = _scene["encounters"][0]["mobs"][0]
	var target: Vector2 = Vector2(float(first["x"]), float(first["y"])) + Vector2(-50, 0)
	armed.player.position = target
	unarmed.player.position = target
	var started: int = 0
	for i: int in 20:
		armed.step(InputFrame.new())
		unarmed.step(InputFrame.new())
		for e: GameEvent in armed.last_events:
			if e.type == GameEvent.ENCOUNTER_STARTED:
				started += 1
	assert_eq(started, 1, "the trail woke once")
	assert_false(unarmed.mobs.is_engaged(), "an unarmed hero wakes nothing")
