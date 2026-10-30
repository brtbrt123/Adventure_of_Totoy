extends "res://tests/test_case.gd"
## The layered forest route (data/scenes/forest_layered_props.json + data/props/prop_defs.json through core/prop_scene.gd,
## scene id SceneDefs.FOREST_LAYERED): valid data with every forest prop type classified, the two states of the
## pedestal and of the root gate on ONE canvas and anchor (the sprites swap in place), the lantern puzzle (E on a
## pedestal lights it, lighting both opens the gate, the snapshot and the placements show it, a saved open gate comes back
## open with both lit), a closed gate that stops the hero and an open one that lets him through, every spot free and
## reachable, the hero never enters a solid prop, entrance -> exit by a bot, determinism.

const Obstacle := preload("res://core/obstacle.gd")
const PropScene := preload("res://core/prop_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const Collision := preload("res://core/collision.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")

const HERO: float = 6.0  # Tuning.PLAYER_RADIUS
const SCENE: StringName = SceneDefs.FOREST_LAYERED
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
const SOLID_TYPES: Array[String] = ["forest_sign", "forest_pedestal", "forest_pedestal_lit", "forest_lantern_post",
	"forest_gate_closed", "forest_gate_open", "forest_tree_middle", "forest_tree_left", "forest_tree_right",
	"forest_standing_stone", "forest_rock_root", "forest_log_1", "forest_log_2", "forest_stump", "forest_chest",
	"forest_thorns_1", "forest_thorns_2", "forest_rocks"]
const DECOR_TYPES: Array[String] = ["forest_bush_1", "forest_bush_2", "forest_fern_1", "forest_fern_2", "forest_fern_small",
	"forest_flowers", "forest_mushrooms"]

var _scene: Dictionary = SceneDefs.layered_data(SCENE)
var _defs: Dictionary = PropScene.load_defs()


func _frame(move: Vector2, dash: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move = move.normalized()
	f.dash_pressed = dash
	return f


func _press() -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.interact_pressed = true
	return f


func _placement(id: StringName, states: Dictionary = {}) -> Dictionary:
	for p: Dictionary in PropScene.placements(_scene, _defs, states):
		if p["id"] == id:
			return p
	return {}


func _object(id: StringName) -> Dictionary:
	for o: Dictionary in SceneDefs.get_def(SCENE)["objects"]:
		if o["id"] == id:
			return o
	return {}


func _light(core: ExploreCore, id: StringName) -> void:
	core.place_at(_object(id)["stand"])
	core.step(InputFrame.new())
	core.step(_press())


func test_the_data_is_valid_and_every_type_is_classified() -> void:
	assert_eq(PropScene.validate(_scene, _defs), PackedStringArray(), "the scene and the defs validate")
	var forest: Array[String] = []
	for type_id: Variant in _defs["props"]:
		if String(type_id).begins_with("forest_"):
			forest.append(String(type_id))
	forest.sort()
	var expected: Array[String] = SOLID_TYPES + DECOR_TYPES
	expected.sort()
	assert_eq(forest, expected, "exactly the 25 forest types, each classified")
	for type_id: String in SOLID_TYPES:
		var def: Dictionary = _defs["props"][type_id]
		assert_true(bool(def["solid"]) and not def["colliders"].is_empty(), "%s is solid with colliders" % type_id)
		assert_true(bool(def.get("locked", false)) and str(def.get("note", "")) != "", "%s is hand-tuned and locked with a note" % type_id)
	for type_id: String in DECOR_TYPES:
		assert_false(bool(_defs["props"][type_id]["solid"]), "%s is walk-through decor" % type_id)
	assert_eq(SceneDefs.get_def(SCENE)["size"], Vector2(480, 288), "the forest's size")
	assert_true(SceneDefs.is_known(SCENE) and not (SCENE in SceneDefs.IDS), "known, but not in the painted IDS (the painted forest is the retired twin)")


func test_the_two_states_stand_in_one_place() -> void:
	for pair: Array in [["forest_pedestal", "forest_pedestal_lit"], ["forest_gate_closed", "forest_gate_open"]]:
		var a: Dictionary = _defs["props"][pair[0]]
		var b: Dictionary = _defs["props"][pair[1]]
		assert_eq([a["w"], a["h"], a["anchor"]], [b["w"], b["h"], b["anchor"]], "%s and %s share w, h and anchor" % pair)
	assert_eq(_defs["props"]["forest_pedestal"]["colliders"], _defs["props"]["forest_pedestal_lit"]["colliders"], "the pedestal's colliders do not move when it lights")
	# the open gate keeps the closed gate's trunks and drops only the doorway row
	var closed: Array = _defs["props"]["forest_gate_closed"]["colliders"]
	for circle: Array in _defs["props"]["forest_gate_open"]["colliders"]:
		assert_true(closed.has(circle), "open gate trunk %s is also in the closed gate" % str(circle))
	assert_true(closed.size() > _defs["props"]["forest_gate_open"]["colliders"].size(), "the closed gate has more circles (the doorway)")


func test_placements_show_the_state() -> void:
	var off: Dictionary = _placement(&"root_gate")
	assert_eq(off["type"], &"forest_gate_closed", "closed by default")
	assert_eq(off["state"], &"off")
	var on: Dictionary = _placement(&"root_gate", {"gate_open": true})
	assert_eq(on["type"], &"forest_gate_open", "open when the gate is open")
	assert_eq(on["state"], &"on")
	assert_eq([on["feet"], on["anchor"], on["size"]], [off["feet"], off["anchor"], off["size"]], "same feet, anchor and size in both states")
	var west: Dictionary = _placement(&"pedestal_west", {"lit": [&"pedestal_west"]})
	var east: Dictionary = _placement(&"pedestal_east", {"lit": [&"pedestal_west"]})
	assert_eq(west["type"], &"forest_pedestal_lit", "the lit pedestal shows lit")
	assert_eq(east["type"], &"forest_pedestal", "the other one stays unlit")
	assert_false(_placement(&"tree_left").has("state"), "props without a state carry none")
	assert_eq(_placement(&"pedestal_west", {"lit": ["pedestal_west"]})["state"], &"on", "String ids work too")


func test_validate_rejects_a_bad_state_row() -> void:
	var bad: Dictionary = _scene.duplicate(true)
	bad["props"][3]["when"] = "moon"
	assert_true(PropScene.validate(bad, _defs).size() > 0, "an unknown state is reported")
	var mismatched: Dictionary = _scene.duplicate(true)
	for row: Dictionary in mismatched["props"]:
		if row["id"] == "signpost":
			row["when"] = "gate_open"
			row["on_type"] = "forest_gate_open"
	assert_true(PropScene.validate(mismatched, _defs).size() > 0, "a state that changes the size is reported")
	var stranger: Dictionary = _scene.duplicate(true)
	for row: Dictionary in stranger["props"]:
		if row["id"] == "pedestal_west":
			row["when"] = "lit:nobody"
	assert_true(PropScene.validate(stranger, _defs).size() > 0, "a switch the scene does not have is reported")


func test_the_scene_def_has_the_puzzle_and_the_route() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	assert_eq(def["puzzle"]["switches"], [&"pedestal_west", &"pedestal_east"], "two switches")
	assert_eq(def["name"], "FOREST ROUTE")
	var kinds: Dictionary = {}
	for o: Dictionary in def["objects"]:
		kinds[String(o["id"])] = String(o["kind"])
	assert_eq(kinds, {"signpost": "sign", "pedestal_west": "lantern_switch", "pedestal_east": "lantern_switch", "root_gate": "door", "chest": "chest"}, "the painted forest's five interactions")
	var keys: Array = []
	for key: Variant in def["entries"]:
		keys.append(String(key))
	keys.sort()
	assert_eq(keys, ["north", "village_side"], "the painted forest's entries")
	var targets: Array = []
	for e: Dictionary in def["exits"]:
		targets.append("%s>%s/%s" % [e["id"], e["target_scene"], e["target_entry"]])
	assert_eq(targets, ["to_village>woodland_layered/east", "to_glade>root_hollow_layered/forest_side"], "west back to the woodland, north into Root Hollow")
	assert_eq(SceneDefs.scene_of_checkpoint(&"forest_layered_puzzle"), SCENE, "the checkpoints belong to the scene")


func test_lighting_both_pedestals_opens_the_gate() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE)
	assert_eq(core.snapshot().lit_switches, [] as Array[StringName], "nothing lit at the start")
	assert_false(core.snapshot().gate_open, "gate closed")
	var closed: int = core.obstacles.size()
	_light(core, &"pedestal_west")
	var events: Array[StringName] = []
	for e: GameEvent in core.last_events:
		events.append(e.type)
	assert_true(events.has(GameEvent.SWITCH_LIT), "E on a pedestal emits switch_lit")
	assert_eq(core.snapshot().lit_switches, [&"pedestal_west"] as Array[StringName], "the west pedestal is lit")
	assert_false(core.snapshot().gate_open, "one pedestal does not open the gate")
	assert_eq(core.obstacles.size(), closed, "the colliders do not change with one pedestal")
	# a second press on the same pedestal does nothing
	core.step(_press())
	assert_eq(core.snapshot().lit_switches.size(), 1, "a lit pedestal stays lit once")
	_light(core, &"pedestal_east")
	var last: GameEvent = null
	for e: GameEvent in core.last_events:
		if e.type == GameEvent.SWITCH_LIT:
			last = e
	assert_true(last != null and bool(last.data["all_lit"]), "the second light reports all_lit")
	assert_true(core.snapshot().gate_open, "both lit: the gate is open")
	assert_eq(core.snapshot().lit_switches.size(), 2, "both lit in the snapshot")
	assert_true(core.obstacles.size() < closed, "the doorway row is gone from the colliders")
	core.step(InputFrame.new())
	var changed: bool = false
	for e: GameEvent in core.last_events:
		changed = changed or e.type == GameEvent.GATE_CHANGED
	assert_true(changed, "gate_changed follows on the next step")


func test_a_saved_open_gate_comes_back_open_and_lit() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE, &"", true)
	assert_true(core.snapshot().gate_open)
	assert_eq(core.snapshot().lit_switches.size(), 2, "an open gate means both pedestals are lit")
	var cp: ExploreCore = ExploreCore.at_checkpoint(SCENE, &"forest_layered_puzzle", true) as ExploreCore
	assert_eq(cp.snapshot().lit_switches.size(), 2, "also when continued at a checkpoint")
	core.set_gate_open(false)
	assert_eq(core.snapshot().lit_switches.size(), 0, "closing the gate (debug) unlights them")
	core.set_gate_open(true)
	assert_eq(core.snapshot().lit_switches.size(), 2, "opening it (debug) lights them")


func test_the_closed_gate_stops_the_hero_and_the_open_gate_lets_him_through() -> void:
	var gate: Vector2 = _placement(&"root_gate")["feet"]
	for open: bool in [false, true]:
		var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE, open, [&"pedestal_west", &"pedestal_east"] if open else [])
		var crossed_at: Array[float] = []
		for x: float in [-30.0, -15.0, 0.0, 15.0, 30.0]:
			var pos: Vector2 = Vector2(gate.x + x, gate.y + 30.0)
			for i: int in 80:
				pos = Collision.move_resolved(obstacles, pos, pos + Vector2.UP, HERO)
			if pos.y < gate.y - 14.0:
				crossed_at.append(x)
		if open:
			assert_true(crossed_at.size() >= 3, "the open gate lets the hero through at %s" % str(crossed_at))
		else:
			assert_eq(crossed_at, [] as Array[float], "the closed gate stops the hero across its whole doorway")
	# the closed gate cannot be dashed through either
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.place_at(Vector2(gate.x, gate.y + 30.0))
	for i: int in 40:
		core.step(_frame(Vector2.UP, i == 2))
		core.exiting = false
	assert_true(core.player.position.y > gate.y - 8.0, "a dash into the closed gate stops (at %s)" % str(core.player.position))


func test_every_spot_is_free_and_reachable() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var grid: LayoutFlood = LayoutFlood.new(def["size"], obstacles, HERO)
	grid.flood(def["entries"][&"village_side"])
	assert_true(Collision.fits(obstacles, def["entries"][&"village_side"], HERO), "the village-side entry is free")
	assert_false(grid.reaches(def["entries"][&"north"]), "the north entry is behind the closed gate")
	for c: Dictionary in def["checkpoints"]:
		assert_true(Collision.fits(obstacles, c["position"], HERO) and grid.reaches(c["position"]), "checkpoint %s is free and reachable" % c["id"])
	for o: Dictionary in def["objects"]:
		assert_true(Collision.fits(obstacles, o["stand"], HERO) and grid.reaches(o["stand"]), "%s: the use spot is free and reachable with the gate closed" % o["id"])
		assert_true((o["stand"] as Vector2).y > (o["position"] as Vector2).y + 8.0, "%s: used from in front (south of it)" % o["id"])
		var core: ExploreCore = ExploreCore.new(SCENE)
		core.place_at(o["stand"])
		core.step(InputFrame.new())
		assert_eq(core.interact_target.get("id", &""), o["id"], "%s: standing on the use spot targets it" % o["id"])
	var open_obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE, true, [&"pedestal_west", &"pedestal_east"])
	var open_grid: LayoutFlood = LayoutFlood.new(def["size"], open_obstacles, HERO)
	open_grid.flood(def["entries"][&"village_side"])
	assert_true(open_grid.reaches(def["entries"][&"north"]), "with the gate open the north entry is reachable")
	assert_true(Collision.fits(open_obstacles, def["entries"][&"north"], HERO), "and free")
	assert_false(Collision.fits(obstacles, _placement(&"chest")["feet"], HERO), "the chest is solid")


func test_the_hero_cannot_enter_a_solid_prop_walking_or_dashing() -> void:
	var states: Dictionary = {"gate_open": false, "lit": []}
	for p: Dictionary in PropScene.placements(_scene, _defs, states):
		if not bool(p["solid"]):
			continue
		var circles: Array[Vector3] = PropScene.prop_colliders({"props": [{"id": "x", "type": String(p["type"]), "x": p["feet"].x, "y": p["feet"].y, "flip": p["flip"]}]}, _defs)
		var tried: int = 0
		for dash: bool in [false, true]:
			for circle: Vector3 in circles:
				for dir: Vector2 in DIRECTIONS:
					var core: ExploreCore = ExploreCore.new(SCENE)
					var start: Vector2 = Vector2(circle.x, circle.y) - dir.normalized() * (circle.z + 34.0)
					if not Collision.fits(core.obstacles, start, HERO):
						continue
					tried += 1
					core.place_at(start)
					for i: int in 70:
						core.step(_frame(dir, dash and i == 12))
						core.exiting = false
						assert_true(Collision.fits(core.obstacles, core.player.position, HERO), "%s: the hero is inside a collider at %s (dash %s, %s)" % [p["id"], str(core.player.position), str(dash), str(dir)])
		assert_true(tried >= 1, "%s: approached from at least one side (%d)" % [p["id"], tried])


func test_decor_is_walkable() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	for p: Dictionary in PropScene.placements(_scene, _defs):
		if bool(p["solid"]):
			continue
		assert_true(Collision.fits(obstacles, p["feet"], HERO), "%s: the hero can stand on the decor prop's anchor" % p["id"])


func test_the_bot_walks_entrance_to_the_gate_and_through_it_when_open() -> void:
	var closed: ExploreCore = ExploreCore.new(SCENE)
	var exit_rect: Rect2 = closed.def["exits"][1]["rect"]
	var shut: ExploreBot = ExploreBot.new()
	assert_false(shut.plan(closed.size, closed.obstacles, closed.player.position, Vector2.ZERO, exit_rect), "no path to the glade exit while the gate is closed")
	var core: ExploreCore = ExploreCore.new(SCENE, &"", true)
	var bot: ExploreBot = ExploreBot.new()
	assert_true(bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, exit_rect), "a path exists to the glade exit when the gate is open")
	for i: int in 4000:
		core.step(bot.next_input(core.player.position))
		if core.exiting:
			break
	assert_true(core.exiting and core.pending_exit.get("exit_id", &"") == &"to_glade", "the hero reaches the glade exit (at %s)" % str(core.player.position))
	var west: ExploreCore = ExploreCore.new(SCENE)
	var village_rect: Rect2 = west.def["exits"][0]["rect"]
	var walk: ExploreBot = ExploreBot.new()
	assert_true(walk.plan(west.size, west.obstacles, Vector2(40, 121), Vector2.ZERO, village_rect), "the way back to the village exit")


func test_walking_is_deterministic() -> void:
	var traces: Array = []
	for run: int in 2:
		var core: ExploreCore = ExploreCore.new(SCENE)
		var trace: Array[Vector2] = []
		for i: int in 600:
			core.step(_frame(DIRECTIONS[(i / 40) % 8], i % 97 == 5))
			core.exiting = false
			trace.append(core.player.position)
		traces.append(trace)
	assert_eq(traces[0], traces[1], "the same inputs give the same walk")


## The review capture "hero behind the middle tree" needs a pose the hero really reaches north of the tree's base while
## the tree covers him. The tree first stood at feet y 92, 12 px from the upper boundary: only a pose beside the trunk
## (281,90) was reachable and it showed the hero half behind leaf fringe. It stands at feet y 108 now (the trail starts
## at y 125, so nothing changes for the route) and the outline's top edge near it moved up 8-10 px (vertices 230,78 ->
## 230,70 and 300,84 -> 300,74: still the lit lawn, the dark undergrowth starts near y 55), which opens a pocket behind
## the trunk. BEHIND_POSE is in that pocket; the test walks the hero there with the walking bot and the real collision
## and measures how much of him the tree's pixels cover.
const BEHIND_POSE: Vector2 = Vector2(248, 88)


func test_the_middle_tree_has_a_reachable_behind_pose() -> void:
	var tree: Dictionary = _placement(&"tree_middle")
	var core: ExploreCore = ExploreCore.new(SCENE)
	var bot: ExploreBot = ExploreBot.new()
	assert_true(bot.plan(core.size, core.obstacles, core.player.position, BEHIND_POSE), "a path exists to the behind pose")
	for i: int in 3000:
		core.step(bot.next_input(core.player.position))
		if bot.done():
			break
	assert_true(core.player.position.distance_to(BEHIND_POSE) < 3.0, "the hero walks there (at %s)" % str(core.player.position))
	assert_true(core.player.position.y < (tree["feet"] as Vector2).y, "north of the tree's base: drawn behind it")
	var def: Dictionary = _defs["props"]["forest_tree_middle"]
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path("res://data/props/cutouts_forest/" + String(def["image"])))
	var origin: Vector2 = (tree["feet"] as Vector2) - (tree["anchor"] as Vector2)
	var hit: int = 0
	var total: int = 0
	for y: int in range(int(core.player.position.y) - 34, int(core.player.position.y)):
		for x: int in range(int(core.player.position.x) - 6, int(core.player.position.x) + 6):
			total += 1
			var sx: int = x - int(round(origin.x))
			var sy: int = y - int(round(origin.y))
			if sx >= 0 and sy >= 0 and sx < image.get_width() and sy < image.get_height() and image.get_pixel(sx, sy).a > 0.0:
				hit += 1
	assert_true(float(hit) / float(total) >= 0.9, "the tree covers at least 90 percent of the hero there (%.0f percent)" % (100.0 * hit / total))
