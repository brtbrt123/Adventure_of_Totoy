extends "res://tests/test_case.gd"
## The layered village (data/scenes/village_layered_props.json + data/props/prop_defs.json through core/prop_scene.gd,
## scene id SceneDefs.VILLAGE_LAYERED): valid data with every prop type deliberately classified (solid or decor, all
## hand-tuned and locked, no second anvil or bench on the forge), the same cast and spots as the painted Lanternfen
## (six NPCs, chest / door / dummy interactions, the arrival, the return and the east exit, the checkpoint), every
## spot free and reachable, the hero never enters a solid prop from eight directions (walking or dashing), the rune
## gate's passage stays open, entrance -> exit by a bot, determinism.

const Obstacle := preload("res://core/obstacle.gd")
const PropScene := preload("res://core/prop_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const Collision := preload("res://core/collision.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")
const PropsLayer := preload("res://presentation/common/props_layer.gd")

const HERO: float = 6.0  # Tuning.PLAYER_RADIUS
const SCENE: StringName = SceneDefs.VILLAGE_LAYERED
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
## The deliberate classification: solid vs walk-through decor (the extractor marks everything solid).
const SOLID_TYPES: Array[String] = ["village_gate", "village_cottage", "village_forge", "village_big_tree", "village_east_tree",
	"village_shrine", "village_standing_stone", "village_lamp_post", "village_dummy", "village_shelf", "village_barrel_a",
	"village_barrel_b", "village_barrel_c", "village_barrel_tipped", "village_crate_a", "village_crate_b", "village_pile",
	"village_rocks", "village_stump", "village_slab", "village_slab_tilted", "village_rubble", "village_chest"]
const DECOR_TYPES: Array[String] = ["village_bush_1", "village_bush_2", "village_fern_1", "village_fern_2",
	"village_mushrooms", "village_mushrooms_small", "village_bucket", "village_rope"]

var _scene: Dictionary = SceneDefs.layered_data(SCENE)
var _defs: Dictionary = PropScene.load_defs()


func _frame(move: Vector2, dash: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move = move.normalized()
	f.dash_pressed = dash
	return f


func _placement(id: String) -> Dictionary:
	for p: Dictionary in PropScene.placements(_scene, _defs):
		if String(p["id"]) == id:
			return p
	return {}


func test_the_data_is_valid_and_every_type_is_classified() -> void:
	assert_eq(PropScene.validate(_scene, _defs).size(), 0, "no problems: %s" % str(PropScene.validate(_scene, _defs)))
	var types: Dictionary = _defs["props"]
	for t: String in SOLID_TYPES:
		assert_true(types.has(t) and bool(types[t]["solid"]) and types[t]["colliders"].size() >= 1, "%s is solid with colliders" % t)
	for t: String in DECOR_TYPES:
		assert_true(types.has(t) and not bool(types[t]["solid"]) and types[t]["colliders"].is_empty(), "%s is decor" % t)
	var village_types: int = 0
	for t: String in types:
		if t.begins_with("village_"):
			village_types += 1
			assert_true(bool(types[t].get("locked", false)), "%s is hand-tuned and locked" % t)
			assert_true(String(types[t].get("note", "")).length() > 3, "%s has a note saying what its colliders are" % t)
	assert_eq(village_types, SOLID_TYPES.size() + DECOR_TYPES.size(), "every village type is classified in this test")
	assert_false(types.has("village_anvil") or types.has("village_bench"), "the forge sprite already holds the anvil and the bench")
	var glade_types: int = 0
	for t: String in types:
		if t.begins_with("glade_"):
			glade_types += 1
	assert_eq(glade_types, 20, "the 20 glade types were not overwritten or lost (the forest's are checked in test_forest_layered)")
	var forges: int = 0
	var used: Dictionary = {}
	for p: Dictionary in PropScene.placements(_scene, _defs):
		used[String(p["type"])] = true
		if String(p["type"]) == "village_forge":
			forges += 1
	assert_eq(forges, 1, "exactly one forge")
	for t: String in ["village_gate", "village_cottage", "village_forge", "village_big_tree", "village_east_tree", "village_shrine",
			"village_standing_stone", "village_lamp_post", "village_dummy", "village_chest"]:
		assert_true(used.has(t), "%s is placed" % t)


func test_the_renderer_takes_the_placements_as_they_are() -> void:
	var frames: Dictionary = {}
	var x: int = 0
	for type_id: String in _defs["props"]:
		var def: Dictionary = _defs["props"][type_id]
		frames[type_id] = {"x": x, "y": 0, "w": int(def["w"]), "h": int(def["h"])}
		x += int(def["w"])
	var drawn: Array[Dictionary] = PropsLayer.drawables(PropScene.placements(_scene, _defs), frames)
	assert_eq(drawn.size(), _scene["props"].size(), "every placement becomes a drawable")
	for item: Dictionary in drawn:
		var p: Dictionary = _placement(String(item["id"]))
		var rect: Rect2 = item["rect"]
		var landed: Vector2 = Vector2(rect.position.x + (rect.size.x - p["anchor"].x if p["flip"] else p["anchor"].x), rect.position.y + p["anchor"].y)
		assert_eq(landed, p["feet"].round(), "%s: the anchor lands on the feet" % item["id"])


func test_the_cast_and_spots_match_the_painted_village() -> void:
	var painted: Dictionary = SceneDefs.get_def(SceneDefs.VILLAGE)
	var layered: Dictionary = SceneDefs.get_def(SCENE)
	assert_eq(layered["id"], SCENE)
	assert_true(SceneDefs.is_known(SCENE), "known to the scene table")
	assert_false(SCENE in SceneDefs.IDS, "not in the painted chapter's IDS (the switch is the human's)")
	assert_eq(layered["size"], Vector2(571, 336), "the ground's size is the painted village's")
	assert_eq(layered["name"], painted["name"], "same display name")
	# sort Strings, not StringNames (Godot orders StringNames by address: the order changes with what else is loaded)
	var painted_ids: Array = []
	for n: Dictionary in painted["npcs"]:
		painted_ids.append(String(n["id"]))
	var ids: Array = []
	for n: Dictionary in layered["npcs"]:
		ids.append(String(n["id"]))
		for pn: Dictionary in painted["npcs"]:
			if pn["id"] == n["id"]:
				assert_eq(n["visual"], pn["visual"], "%s keeps its sprite" % n["id"])
	painted_ids.sort()
	ids.sort()
	assert_eq(ids, painted_ids, "the same six people")
	var painted_objects: Array = []
	for o: Dictionary in painted["objects"]:
		painted_objects.append(String(o["id"]) + ":" + String(o["kind"]))
	var objects: Array = []
	for o: Dictionary in layered["objects"]:
		objects.append(String(o["id"]) + ":" + String(o["kind"]))
	painted_objects.sort()
	objects.sort()
	assert_eq(objects, painted_objects, "the same chest, door and training dummy interactions")
	var keys: Array = []
	for key: Variant in layered["entries"]:
		keys.append(String(key))
	keys.sort()
	assert_eq(keys, ["arrival", "return"], "the same entries")
	assert_eq(layered["default_entry"], &"arrival")
	assert_eq(layered["exits"].size(), 1, "one exit")
	assert_eq(layered["exits"][0]["target_scene"], painted["exits"][0]["target_scene"], "the east exit leads to the same scene")
	assert_eq(layered["exits"][0]["target_entry"], painted["exits"][0]["target_entry"], "and the same entry")
	assert_true(SceneDefs.get_def(layered["exits"][0]["target_scene"])["entries"].has(layered["exits"][0]["target_entry"]), "that entry exists")
	assert_eq(SceneDefs.scene_of_checkpoint(&"village_layered_gate"), SCENE, "the checkpoint belongs to the scene")
	assert_true(layered["entries"][&"return"].x > 500.0, "the return entry is by the east road")
	assert_true(layered["entries"][&"arrival"].x < 140.0, "the arrival is just inside the west gate")


func test_every_spot_is_free_and_reachable() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var props_only: Array[Obstacle] = PropScene.build(_scene, _defs)
	var grid: LayoutFlood = LayoutFlood.new(def["size"], obstacles, HERO)
	grid.flood(def["entries"][&"arrival"])
	for key: StringName in def["entries"]:
		assert_true(Collision.fits(obstacles, def["entries"][key], HERO), "entry %s is free" % key)
		assert_true(grid.reaches(def["entries"][key]), "entry %s is reachable from the arrival" % key)
	for c: Dictionary in def["checkpoints"]:
		assert_true(Collision.fits(obstacles, c["position"], HERO) and grid.reaches(c["position"]), "checkpoint %s is free and reachable" % c["id"])
	for n: Dictionary in def["npcs"]:
		assert_true(Collision.fits(props_only, n["position"], 5.0), "%s stands on free ground (no prop under them)" % n["id"])
		var reachable: bool = false
		for dir: Vector2 in DIRECTIONS:
			if grid.reaches(n["position"] + dir.normalized() * 14.0):
				reachable = true
		assert_true(reachable, "%s can be walked up to" % n["id"])
	for o: Dictionary in def["objects"]:
		assert_true(Collision.fits(obstacles, o["stand"], HERO), "%s: the use spot is free" % o["id"])
		assert_true(grid.reaches(o["stand"]), "%s: the use spot is reachable" % o["id"])
		assert_true((o["stand"] as Vector2).y > (o["position"] as Vector2).y + 8.0, "%s: used from in front (south of it)" % o["id"])
		var core: ExploreCore = ExploreCore.new(SCENE)
		core.place_at(o["stand"])
		core.step(InputFrame.new())
		assert_eq(core.interact_target.get("id", &""), o["id"], "%s: standing on the use spot targets it" % o["id"])
	# the door and the chest are solid props: the hero cannot walk onto them
	assert_false(Collision.fits(obstacles, _placement("chest")["feet"], HERO), "the chest is solid")
	var door: Vector2 = Vector2(0, 0)
	for o: Dictionary in def["objects"]:
		if o["id"] == &"edda_door":
			door = o["position"]
	assert_false(Collision.fits(obstacles, door, HERO), "the cottage door is solid, as in the painted village")
	for n: Dictionary in def["npcs"]:
		var near: ExploreCore = ExploreCore.new(SCENE)
		var placed: bool = false
		for dir: Vector2 in DIRECTIONS:
			var at: Vector2 = n["position"] + dir.normalized() * 14.0
			if Collision.fits(obstacles, at, HERO):
				near.place_at(at)
				near.step(InputFrame.new())
				placed = true
				break
		assert_true(placed, "%s: a spot to talk from" % n["id"])
		assert_eq(near.interact_target.get("id", &""), n["id"], "%s is the interact target when the hero stands next to them" % n["id"])


func test_the_hero_cannot_enter_a_solid_prop_walking_or_dashing_and_reaches_every_base() -> void:
	for p: Dictionary in PropScene.placements(_scene, _defs):
		if not bool(p["solid"]):
			continue
		var circles: Array[Vector3] = PropScene.prop_colliders({"props": [{"id": "x", "type": String(p["type"]), "x": p["feet"].x, "y": p["feet"].y, "flip": p["flip"]}]}, _defs)
		var closest: float = INF
		var tried: int = 0
		for dash: bool in [false, true]:
			for circle: Vector3 in circles:
				for dir: Vector2 in DIRECTIONS:
					var centre: Vector2 = Vector2(circle.x, circle.y)
					var core: ExploreCore = ExploreCore.new(SCENE)
					var start: Vector2 = centre - dir.normalized() * (circle.z + 34.0)
					if not Collision.fits(core.obstacles, start, HERO):
						continue
					tried += 1
					core.place_at(start)
					for i: int in 70:
						core.step(_frame(dir, dash and i == 12))
						core.exiting = false
						var feet: Vector2 = core.player.position
						assert_true(Collision.fits(core.obstacles, feet, HERO), "%s: the hero is inside a collider at %s (dash %s, %s)" % [p["id"], str(feet), str(dash), str(dir)])
						closest = minf(closest, feet.distance_to(centre) - circle.z)
		assert_true(tried >= 2, "%s: approached from at least two sides (%d)" % [p["id"], tried])
		assert_true(closest <= HERO + 6.0, "%s: the hero gets to its base from some side (%.1f px from a circle's edge)" % [p["id"], closest])


func test_decor_is_walkable() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	for p: Dictionary in PropScene.placements(_scene, _defs):
		if bool(p["solid"]):
			continue
		assert_true(Collision.fits(obstacles, p["feet"], HERO), "%s: the hero can stand on the decor prop's anchor" % p["id"])


func test_the_rune_gate_passage_is_open_and_the_pillars_are_solid() -> void:
	var gate: Vector2 = _placement("gate")["feet"]
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var gap_x: float = gate.x + 26.0  # between the left pillar (dx -14..13) and the door leaf + right pillar (dx 40..77)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN]:
		var pos: Vector2 = Vector2(gap_x, gate.y + (28.0 if dir == Vector2.UP else -28.0))
		var crossed: bool = false
		for i: int in 120:
			pos = Collision.move_resolved(obstacles, pos, pos + dir * 1.0, HERO)
			if (dir == Vector2.UP and pos.y < gate.y - 24.0) or (dir == Vector2.DOWN and pos.y > gate.y + 24.0):
				crossed = true
				break
		assert_true(crossed, "the hero walks %s through the gate's opening (ended at %s)" % [str(dir), str(pos)])
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.place_at(Vector2(gap_x, gate.y + 30.0))
	for i: int in 40:
		core.step(_frame(Vector2.UP, i == 2))
		core.exiting = false
	assert_true(core.player.position.y < gate.y - 12.0, "a dash north goes through the opening (at %s)" % str(core.player.position))
	# the left pillar and the door leaf / right pillar stop him from the south
	for foot_x: float in [0.0, 58.0]:
		var p: Vector2 = Vector2(gate.x + foot_x, gate.y + 24.0)
		for i: int in 80:
			p = Collision.move_resolved(obstacles, p, p + Vector2.UP, HERO)
		assert_true(p.y > gate.y - 22.0, "the gate's solid part at dx %.0f stops the hero from the south (y %.1f)" % [foot_x, p.y])
	# the clear width of the passage is a comfortable multiple of the hero (12 px) at its narrowest row
	var widest_gap: float = 0.0
	var y: float = gate.y - 12.0
	while y <= gate.y + 12.0:
		var run: float = 0.0
		var best: float = 0.0
		var x: float = gate.x - 10.0
		while x <= gate.x + 90.0:
			if Collision.fits(obstacles, Vector2(x, y), HERO):
				run += 1.0
				best = maxf(best, run)
			else:
				run = 0.0
			x += 1.0
		widest_gap = maxf(widest_gap, best)
		y += 4.0
	assert_true(widest_gap >= 14.0, "a hero-wide strip is free in the gate rows (%.0f px)" % widest_gap)


func test_the_bot_walks_arrival_to_the_exit_and_back() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE)
	var rect: Rect2 = core.def["exits"][0]["rect"]
	var bot: ExploreBot = ExploreBot.new()
	assert_true(bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, rect), "a path exists from the arrival to the east exit")
	for i: int in 4000:
		core.step(bot.next_input(core.player.position))
		if core.exiting:
			break
	assert_true(core.exiting and core.pending_exit.get("exit_id", &"") == &"to_forest", "the hero reaches the exit (at %s)" % str(core.player.position))
	var back: ExploreCore = ExploreCore.new(SCENE, &"return")
	var gate: Dictionary = SceneDefs.checkpoint(SCENE, &"village_layered_gate")
	var bot2: ExploreBot = ExploreBot.new()
	assert_true(bot2.plan(back.size, back.obstacles, back.player.position, gate["position"]), "the way back from the forest to the gate checkpoint")
	for i: int in 4000:
		back.step(bot2.next_input(back.player.position))
		if bot2.done():
			break
	assert_true(back.player.position.distance_to(gate["position"]) < 12.0, "and the hero gets there (at %s)" % str(back.player.position))


func test_walking_is_deterministic_and_never_inside_a_collider() -> void:
	var runs: Array = []
	for r: int in 2:
		var core: ExploreCore = ExploreCore.new(SCENE)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5
		var dir: Vector2 = Vector2.RIGHT
		var trace: PackedVector2Array = PackedVector2Array()
		for i: int in 3000:
			if i % 25 == 0:
				dir = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			core.step(_frame(dir, i % 61 == 0))
			core.exiting = false
			assert_true(Collision.fits(core.obstacles, core.player.position, HERO), "inside a collider at %s (tick %d)" % [str(core.player.position), i])
			trace.append(core.player.position)
		runs.append(trace)
	assert_eq(runs[0], runs[1], "same inputs, same walk")
	var a: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var b: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	assert_eq(a.size(), b.size())
	for i: int in a.size():
		assert_true(a[i].center == b[i].center and a[i].radius == b[i].radius, "same collider %d" % i)
