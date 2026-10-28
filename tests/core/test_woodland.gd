extends "res://tests/test_case.gd"
## The Woodland Approach (data/scenes/woodland_layered_props.json, scene id SceneDefs.WOODLAND_LAYERED): valid data, the route
## village <-> woodland <-> forest, entries and checkpoints that are free and far from every mob, prop bases that block the hero where the
## sprite stands (and decor that does not), both main clearings and the optional camp loop open and reachable from both ends, the
## encounters' spawn points free, and a walk from the west end to the east end.

const Obstacle := preload("res://core/obstacle.gd")
const PropScene := preload("res://core/prop_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Collision := preload("res://core/collision.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")

const HERO: float = 6.0
const SCENE: StringName = SceneDefs.WOODLAND_LAYERED
## What the owner's layout asks for (presentation/review/chapter1_expansion/LAYOUT.md): the free centre of a main encounter and of the optional one.
const MAIN_CENTRE: Vector2 = Vector2(180, 112)
const CAMP_CENTRE: Vector2 = Vector2(144, 96)
## "Approximately" for a main clearing: a box this big fits, and this share of the reserved rectangle is free ground.
const MAIN_BOX: Vector2 = Vector2(160, 100)
const MAIN_SHARE: float = 0.85
const SOLID_TYPES: Array[String] = ["woodland_tree_broad", "woodland_tree_slender", "woodland_brambles", "woodland_rocks", "woodland_log",
	"woodland_stump", "woodland_lantern", "woodland_sign", "woodland_fire_ring", "woodland_supplies"]
const DECOR_TYPES: Array[String] = ["woodland_bush", "woodland_bedroll"]

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


func _flood(from_entry: StringName) -> LayoutFlood:
	var flood: LayoutFlood = LayoutFlood.new(_def["size"], SceneDefs.build_obstacles(SCENE), HERO)
	flood.flood(_def["entries"][from_entry])
	return flood


## True when a `want`-sized box, anywhere within 16 px of `rect`, holds only reached (free, connected) samples.
func _box_fits(flood: LayoutFlood, rect: Rect2, want: Vector2) -> bool:
	var area: Rect2 = rect.grow(16.0)  # the box may sit a little off the drawn rectangle
	var y: float = area.position.y
	while y + want.y <= area.end.y + 0.01:
		var x: float = area.position.x
		while x + want.x <= area.end.x + 0.01:
			var ok: bool = true
			var py: float = y
			while ok and py <= y + want.y + 0.01:
				var px: float = x
				while ok and px <= x + want.x + 0.01:
					ok = flood.reaches(Vector2(px, py))
					px += 8.0
				py += 8.0
			if ok:
				return true
			x += 4.0
		y += 4.0
	return false


## The share of the 8 px samples of `rect` that a hero can stand on and walk to.
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
	assert_eq(PropScene.validate(_scene, _defs), PackedStringArray(), "no problem in the scene file")
	assert_true(SceneDefs.is_known(SCENE) and SCENE in SceneDefs.LAYERED)
	assert_eq(_def["size"], Vector2(640, 400))
	assert_eq(_def["name"], "WOODLAND APPROACH")
	assert_eq(String(_scene["ground"]), "res://presentation/forest/woodland_approach_ground.png")
	for type_id: String in SOLID_TYPES:
		var def: Dictionary = _defs["props"][type_id]
		assert_true(bool(def["solid"]) and not def["colliders"].is_empty(), "%s is solid with base colliders" % type_id)
		assert_true(bool(def.get("locked", false)), "%s is locked (hand-derived from the sprite base)" % type_id)
	for type_id: String in DECOR_TYPES:
		assert_false(bool(_defs["props"][type_id]["solid"]), "%s is walk-through decor" % type_id)


func test_every_placed_prop_type_exists() -> void:
	var placed: Dictionary = {}
	for p: Dictionary in PropScene.placements(_scene, _defs):
		placed[String(p["type"])] = true
		assert_true(float(p["size"].x) > 0.0, "%s has a size" % p["id"])
	for type_id: String in SOLID_TYPES + DECOR_TYPES:
		assert_true(placed.has(type_id) or type_id in ["woodland_brambles", "woodland_log", "woodland_stump"], "the approved layout uses %s" % type_id)


func test_the_route_leads_through_the_woodland() -> void:
	assert_eq(_def["default_entry"], &"west")
	assert_eq(_def["entries"].keys().size(), 2)
	var targets: Array = []
	for e: Dictionary in _def["exits"]:
		targets.append("%s>%s/%s" % [e["id"], e["target_scene"], e["target_entry"]])
	assert_eq(targets, ["to_village>village_layered/return", "to_forest>forest_layered/village_side"])
	assert_eq(SceneDefs.scene_of_checkpoint(&"woodland_layered_west"), SCENE)
	assert_eq(SceneDefs.scene_of_checkpoint(&"woodland_layered_east"), SCENE)


func test_entries_and_checkpoints_are_free_and_far_from_every_mob() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var field: MobField = MobField.for_scene(_def) as MobField
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
		for exit: Dictionary in _def["exits"]:
			var r: Rect2 = exit["rect"]
			if key in [&"west", &"east"]:
				continue  # an entry may sit beside its exit
			assert_true(p.clamp(r.position, r.end).distance_to(p) > HERO, "%s does not touch exit %s" % [key, exit["id"]])


func test_the_prop_bases_block_the_hero_where_the_sprite_stands() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	for p: Dictionary in PropScene.placements(_scene, _defs):
		var feet: Vector2 = p["feet"]
		if not bool(p["solid"]):
			continue
		if feet.x < 0 or feet.y < 0 or feet.x > 640 or feet.y > 400:
			continue
		var hit: bool = false
		for o: Obstacle in obstacles:
			if o.center.distance_to(feet) <= o.radius + 12.0:
				hit = true
		assert_true(hit, "%s (%s) has a collider at its feet" % [p["id"], p["type"]])


func test_both_main_clearings_and_the_camp_are_open_from_both_ends() -> void:
	for entry: StringName in [&"west", &"east"]:
		var flood: LayoutFlood = _flood(entry)
		for id: StringName in [&"mossling_clearing", &"boar_clearing"]:
			var share: float = _share(flood, _rect(_encounter(id)))
			assert_true(share >= MAIN_SHARE, "%s: %.0f %% of the reserved %s rectangle is free ground (from the %s end)" % [id, share * 100.0, str(MAIN_CENTRE), entry])
			assert_true(_box_fits(flood, _rect(_encounter(id)), MAIN_BOX), "%s: an obstacle-free %s box is reachable from the %s end" % [id, str(MAIN_BOX), entry])
		assert_true(_box_fits(flood, _rect(_encounter(&"camp_ambush")), CAMP_CENTRE), "the camp's %s centre is reachable from the %s end" % [str(CAMP_CENTRE), entry])
		assert_true(flood.reaches(_def["entries"][&"east" if entry == &"west" else &"west"]), "%s end reaches the other end" % entry)


func test_the_camp_loop_is_a_loop() -> void:
	# both ends of the top trail reach the camp and the loop closes: with the camp's trail cut, the main road still connects west to east
	var flood: LayoutFlood = _flood(&"west")
	var camp: Rect2 = _rect(_encounter(&"camp_ambush"))
	assert_true(flood.reaches(camp.get_center()), "the camp is reachable")
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var plug: Obstacle = Obstacle.new()
	plug.center = camp.get_center()
	plug.radius = 70.0
	obstacles.append(plug)
	var cut: LayoutFlood = LayoutFlood.new(_def["size"], obstacles, HERO)
	cut.flood(_def["entries"][&"west"])
	assert_true(cut.reaches(_def["entries"][&"east"]), "the main road still joins the two ends when the camp is blocked")
	# and the camp is reachable from the road on both sides of the island (two ways in)
	var south: Vector2 = Vector2(320, 256)
	assert_true(flood.reaches(south), "the road below the island is walkable")


func test_every_mob_stands_on_free_ground_apart_from_the_others() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var flood: LayoutFlood = _flood(&"west")
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


func test_walking_from_the_west_end_to_the_east_end() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE, &"west")
	core.set_story_flags([&"debug_all_unlocked"] as Array[StringName])
	var bot: ExploreBot = ExploreBot.new()
	var exit: Rect2 = _def["exits"][1]["rect"]
	assert_true(bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, exit), "a path exists")
	for i: int in 2400:
		core.step(bot.next_input(core.player.position))
		if core.exiting:
			break
	assert_true(core.exiting and core.pending_exit["target_scene"] == SceneDefs.FOREST_LAYERED, "the hero walked out of the east end (unarmed: nothing woke)")
