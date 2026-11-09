extends "res://tests/test_case.gd"
## Rootcrown (data/scenes/rootcrown_layered_props.json, docs/FINAL_SCENE_chapter1.md): the chapter's final map, a plateau at the
## top of a stair behind the Stag Glade's root arch, crowned by the dark forest beacon. It is not on the story path yet (the
## arch still leads to the arena until the Colossus lives here; debug key Y jumps in). Checked: it is registered and valid, the
## stair leads up to the checkpoint and the fight floor, the fight floor is open, its one exit goes back down to an open spot
## under the glade's arch, and the beacon lights once `cleared_rootcrown` is set without moving or changing its body.

const SceneDefs := preload("res://core/scene_defs.gd")
const PropScene := preload("res://core/prop_scene.gd")
const Collision := preload("res://core/collision.gd")
const Obstacle := preload("res://core/obstacle.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")

const SCENE: StringName = SceneDefs.ROOTCROWN_LAYERED
const HERO: float = 6.0  # Tuning.PLAYER_RADIUS
const CLEARED: StringName = &"cleared_rootcrown"
## docs/previews/rootcrown_v1/layout.json: where the Colossus starts and the floor its fight needs open.
const BOSS_START: Vector2 = Vector2(322, 168)
const FIGHT_FLOOR: Rect2 = Rect2(190, 132, 264, 120)


func _flood(flags: Array = []) -> LayoutFlood:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var flood: LayoutFlood = LayoutFlood.new(def["size"], SceneDefs.build_obstacles(SCENE, false, [], flags), HERO)
	flood.flood(def["entries"][&"glade_side"])
	return flood


func _beacon(placements: Array[Dictionary]) -> Dictionary:
	for p: Dictionary in placements:
		if p["id"] == &"beacon":
			return p
	return {}


func _circles(obstacles: Array[Obstacle]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for o: Obstacle in obstacles:
		out.append(Vector3(o.center.x, o.center.y, o.radius))
	return out


func test_the_map_is_a_registered_valid_layered_scene() -> void:
	assert_true(SceneDefs.LAYERED.has(SCENE) and SceneDefs.ALL.has(SCENE), "registered")
	var data: Dictionary = SceneDefs.layered_data(SCENE)
	assert_eq(PropScene.validate(data, PropScene.load_defs()), PackedStringArray(), "the data is valid")
	var def: Dictionary = SceneDefs.get_def(SCENE)
	assert_eq(def["name"], "ROOTCROWN", "its title")
	assert_eq(def["size"], Vector2(640, 360), "the floor painting's size")
	assert_eq(def["default_entry"], &"glade_side", "the hero arrives up the stair")
	assert_eq(def["npcs"].size() + def["objects"].size() + def["encounters"].size(), 0, "nobody and nothing to use yet: the Colossus comes later")


func test_its_one_exit_goes_down_the_stair_to_an_open_spot_under_the_glade_arch() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	assert_eq(def["exits"].size(), 1, "one way in and out: the stair")
	var exit: Dictionary = def["exits"][0]
	assert_eq([exit["target_scene"], exit["target_entry"]], [SceneDefs.GLADE_LAYERED, &"rootcrown_side"], "down to the glade, under its root arch")
	assert_false(exit.has("requires_flag"), "the way back is never closed")
	var glade: Dictionary = SceneDefs.get_def(SceneDefs.GLADE_LAYERED)
	var arrival: Vector2 = glade["entries"][&"rootcrown_side"]
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SceneDefs.GLADE_LAYERED)
	assert_true(Collision.fits(obstacles, arrival, HERO), "the glade's arrival spot is free")
	var flood: LayoutFlood = LayoutFlood.new(glade["size"], obstacles, HERO)
	flood.flood(glade["entries"][&"entrance"])
	assert_true(flood.reaches(arrival), "and joined to the rest of the glade")


func test_the_stair_leads_up_to_the_checkpoint_and_the_boss_and_back_down() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var flood: LayoutFlood = _flood()
	assert_true(flood.reaches(def["checkpoints"][0]["position"]), "the checkpoint at the top of the stair")
	assert_true(flood.reaches(BOSS_START), "where the Colossus starts")
	assert_true(flood.reaches(Rect2(def["exits"][0]["rect"]).get_center() + Vector2(0, -6)), "and the way back down")


func test_the_fight_floor_is_open() -> void:
	for flags: Array in [[], [CLEARED]]:
		var flood: LayoutFlood = _flood(flags)
		var closed: Array[Vector2] = []
		var y: float = FIGHT_FLOOR.position.y
		while y <= FIGHT_FLOOR.end.y:
			var x: float = FIGHT_FLOOR.position.x
			while x <= FIGHT_FLOOR.end.x:
				if not flood.reaches(Vector2(x, y)):
					closed.append(Vector2(x, y))
				x += 8.0
			y += 8.0
		assert_eq(closed, [] as Array[Vector2], "no prop or edge on the fight floor (flags %s)" % [flags])


func test_the_beacon_lights_once_the_guardian_falls() -> void:
	var data: Dictionary = SceneDefs.layered_data(SCENE)
	var defs: Dictionary = PropScene.load_defs()
	var dark: Dictionary = _beacon(PropScene.placements(data, defs, {}))
	var lit: Dictionary = _beacon(PropScene.placements(data, defs, {"flags": [CLEARED]}))
	assert_eq([dark["type"], dark["state"]], [&"rootcrown_tower_dark", &"off"], "dark while the guardian stands")
	assert_eq([lit["type"], lit["state"]], [&"rootcrown_tower_lit", &"on"], "lit once it falls")
	assert_eq([lit["feet"], lit["size"], lit["anchor"]], [dark["feet"], dark["size"], dark["anchor"]], "one canvas and one anchor: lighting it does not move it")
	assert_true(dark["solid"] and lit["solid"], "a solid body in both states")
	assert_eq(_circles(SceneDefs.build_obstacles(SCENE, false, [], [CLEARED])), _circles(SceneDefs.build_obstacles(SCENE)), "and the same colliders")
