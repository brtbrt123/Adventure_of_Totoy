extends "res://tests/test_case.gd"
## The layered Stag glade (data/scenes/glade_layered_props.json + data/props/prop_defs.json through core/prop_scene.gd,
## scene id SceneDefs.GLADE_LAYERED): the data is valid and every prop type is deliberately classified (solid or decor,
## all hand-tuned and locked), the hero cannot enter any solid prop from eight directions, walking or dashing, and still
## reaches every base, the root arch's gap stays open while its two feet are solid, entrances/exits/checkpoints are free
## and the bot walks entrance -> forest exit / arena exit, the walk is deterministic, and a radius-20 Stag reaches at
## least 80 % of the central fight area (the rule of docs/LAYERED_SCENE_PILOT.md).

const Obstacle := preload("res://core/obstacle.gd")
const PropScene := preload("res://core/prop_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const Collision := preload("res://core/collision.gd")
const LayoutFlood := preload("res://tests/layout_flood.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")
const PropsLayer := preload("res://presentation/common/props_layer.gd")

const HERO: float = 6.0  # Tuning.PLAYER_RADIUS
const STAG_SHARE_MIN: float = 0.80
const SCENE: StringName = SceneDefs.GLADE_LAYERED
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
## The deliberate classification (the extractor marks everything solid): walk-through decor vs solid.
const SOLID_TYPES: Array[String] = ["glade_stone_1", "glade_stone_2", "glade_stone_3", "glade_stone_4", "glade_stone_5",
	"glade_rock_1", "glade_rock_2", "glade_rock_3", "glade_rocks_small", "glade_tree", "glade_stump", "glade_log", "glade_antler",
	"glade_thorns", "glade_bush_1", "glade_arch"]
const DECOR_TYPES: Array[String] = ["glade_bush_2", "glade_fern_1", "glade_fern_2", "glade_mushrooms"]

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
	var glade_types: int = 0
	for t: String in types:
		if t.begins_with("glade_"):
			glade_types += 1
	assert_eq(glade_types, SOLID_TYPES.size() + DECOR_TYPES.size(), "20 glade prop types, each classified in this test (village types share the file)")
	for t: String in SOLID_TYPES:
		assert_true(bool(types[t]["solid"]) and types[t]["colliders"].size() >= 2, "%s is solid with colliders" % t)
	for t: String in DECOR_TYPES:
		assert_true(not bool(types[t]["solid"]) and types[t]["colliders"].is_empty(), "%s is decor" % t)
	for t: String in types:
		if t.begins_with("glade_"):
			assert_true(bool(types[t].get("locked", false)), "%s is hand-tuned and locked (the extractor must not overwrite it)" % t)
	var used: Dictionary = {}
	for p: Dictionary in PropScene.placements(_scene, _defs):
		used[String(p["type"])] = true
	assert_eq(used.size(), glade_types - 1, "all retained glade types are placed; removed log stays available as an asset")
	assert_false(used.has("glade_log"), "owner removed the entrance log")
	assert_eq(PropScene.placements(_scene, _defs).size(), 21, "owner removed the log and cleared the approach: 21 props")


func test_placements_match_the_approved_arrangement_and_carry_shadows() -> void:
	var stone: Dictionary = _placement("glade_stone_1")
	assert_eq(stone["feet"], Vector2(170, 140), "the approved place of stone 1")
	assert_eq(stone["anchor"], Vector2(24, 54), "its anchor in the sprite")
	assert_near(float(stone["shadow_radius"]), 14.4, 0.01, "the shadow radius is passed on for the renderer")
	assert_eq(_placement("glade_arch")["feet"], Vector2(492, 62), "owner moved the arch to the upper-right exit")


func test_the_renderer_takes_the_placements_as_they_are() -> void:
	# presentation/common/props_layer.gd declares Array[Dictionary]: PropScene.placements must have that exact type
	var frames: Dictionary = {}
	var x: int = 0
	for type_id: String in _defs["props"]:
		var def: Dictionary = _defs["props"][type_id]
		frames[type_id] = {"x": x, "y": 0, "w": int(def["w"]), "h": int(def["h"])}
		x += int(def["w"])
	var drawn: Array[Dictionary] = PropsLayer.drawables(PropScene.placements(_scene, _defs), frames)
	assert_eq(drawn.size(), 21, "every placement becomes a drawable")
	for item: Dictionary in drawn:
		var p: Dictionary = _placement(String(item["id"]))
		assert_eq(item["at"], p["feet"], "%s is sorted by its feet" % item["id"])
		var rect: Rect2 = item["rect"]
		var landed: Vector2 = Vector2(rect.position.x + (rect.size.x - p["anchor"].x if p["flip"] else p["anchor"].x), rect.position.y + p["anchor"].y)
		assert_eq(landed, p["feet"], "%s: the anchor lands on the feet (mirrored: %s)" % [item["id"], str(p["flip"])])


func test_the_presentation_fixture_does_not_drift_from_the_authoritative_arrangement() -> void:
	# data/scenes/glade_layered_props.json is the one arrangement; presentation/forest/glade_props.json (Codex's
	# review fixture) must either be gone or say the same thing
	var fixture: Dictionary = PropScene.read_json("res://presentation/forest/glade_props.json")
	if fixture.is_empty():
		return
	var mine: Array[Dictionary] = PropScene.placements(_scene, _defs)
	var theirs: Array = fixture["props"]
	assert_eq(theirs.size(), mine.size(), "same number of props as the authoritative file")
	for i: int in mini(theirs.size(), mine.size()):
		var t: Dictionary = theirs[i]
		assert_eq(String(t["id"]), String(mine[i]["id"]), "prop %d: same id" % i)
		assert_eq(Vector2(float(t["x"]), float(t["y"])), mine[i]["feet"], "%s: same place" % mine[i]["id"])
		assert_eq(bool(t.get("flip", false)), mine[i]["flip"], "%s: same flip" % mine[i]["id"])


func test_scene_def_and_obstacles() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	assert_eq(def["id"], SCENE)
	assert_eq(def["size"], Vector2(560, 336), "the ground's size")
	assert_true(def["entries"].has(def["default_entry"]), "default entry exists")
	assert_true(SceneDefs.is_known(SCENE), "known to the scene table")
	assert_false(SCENE in SceneDefs.IDS, "not in the painted chapter's IDS (the switch is the human's)")
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	assert_true(obstacles.size() > 60, "edge chain and prop circles (%d)" % obstacles.size())
	var ids: Dictionary = {}
	for o: Obstacle in obstacles:
		assert_false(ids.has(o.id), "unique collider id")
		ids[o.id] = true
		assert_true(o.radius > 0.0 and o.visual_id == &"", "collider %d has a radius and draws nothing" % o.id)
	assert_eq(SceneDefs.scene_of_checkpoint(&"glade_layered_entrance"), SCENE, "the checkpoint belongs to the scene")
	for exit: Dictionary in def["exits"]:
		assert_true(SceneDefs.is_known(exit["target_scene"]), "exit %s leads to a known scene" % exit["id"])
		assert_true(SceneDefs.get_def(exit["target_scene"])["entries"].has(exit["target_entry"]), "exit %s: the target entry exists" % exit["id"])


func test_entry_checkpoint_exits_are_free() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var points: Dictionary = (def["entries"] as Dictionary).duplicate()
	for c: Dictionary in def["checkpoints"]:
		points[c["id"]] = c["position"]
	for key: StringName in points:
		var p: Vector2 = points[key]
		assert_true(Collision.fits(obstacles, p, HERO), "%s is a free spot" % key)
		for exit: Dictionary in def["exits"]:
			var r: Rect2 = exit["rect"]
			assert_true(p.clamp(r.position, r.end).distance_to(p) > HERO, "%s does not touch exit %s" % [key, exit["id"]])
	assert_eq(ExploreCore.new(SCENE).player.position, def["entries"][def["default_entry"]], "spawns on the entry")
	assert_eq(ExploreCore.at_checkpoint(SCENE, &"glade_layered_entrance").last_checkpoint, &"glade_layered_entrance", "continue from the checkpoint")


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
		assert_true(tried >= 4, "%s: approached from several sides (%d)" % [p["id"], tried])
		assert_true(closest <= HERO + 6.0, "%s: the hero gets to its base from some side (%.1f px from a circle's edge)" % [p["id"], closest])


func test_decor_is_walkable() -> void:
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	for p: Dictionary in PropScene.placements(_scene, _defs):
		if bool(p["solid"]):
			continue
		assert_true(Collision.fits(obstacles, p["feet"], HERO), "%s: the hero can stand on the decor prop's anchor" % p["id"])


func test_the_root_arch_keeps_its_gap_open_and_its_feet_solid() -> void:
	var arch: Vector2 = _placement("glade_arch")["feet"]
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	# through the gap (south to north), and back
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN]:
		var pos: Vector2 = arch + (Vector2(0, 26) if dir == Vector2.UP else Vector2(0, -26))
		var crossed: bool = false
		for i: int in 80:
			var next: Vector2 = Collision.move_resolved(obstacles, pos, pos + dir * 1.0, HERO)
			pos = next
			if (dir == Vector2.UP and pos.y < arch.y - 24.0) or (dir == Vector2.DOWN and pos.y > arch.y + 24.0):
				crossed = true
				break
		assert_true(crossed, "the hero walks %s through the arch's gap (ended at %s)" % [str(dir), str(pos)])
	# the dash through the gap
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.place_at(arch + Vector2(0, 30))
	for i: int in 40:
		core.step(_frame(Vector2.UP, i == 2))
		core.exiting = false
	assert_true(core.player.position.y < arch.y - 10.0, "a dash north goes through the gap (at %s)" % str(core.player.position))
	# the feet stop him
	for foot_x: float in [-30.0, 31.0]:
		var p: Vector2 = arch + Vector2(foot_x, 24)
		# The upper-right placement puts the outer approach beyond the scene boundary.
		if not Collision.fits(obstacles, p, HERO):
			continue
		for i: int in 60:
			p = Collision.move_resolved(obstacles, p, p + Vector2.UP, HERO)
		assert_true(p.y > arch.y - 6.0, "the arch's foot at dx %.0f stops the hero from the south (y %.1f)" % [foot_x, p.y])


func test_the_bot_walks_entrance_to_both_exits() -> void:
	for exit_id: StringName in [&"to_forest", &"to_arena"]:
		var core: ExploreCore = ExploreCore.new(SCENE)
		var rect: Rect2 = Rect2()
		for exit: Dictionary in core.def["exits"]:
			if exit["id"] == exit_id:
				rect = exit["rect"]
		var from: Vector2 = core.player.position
		if exit_id == &"to_forest":
			core.place_at(Vector2(300, 200))  # from the middle of the clearing back to the entrance
		var bot: ExploreBot = ExploreBot.new()
		assert_true(bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, rect), "%s: a path exists (from %s)" % [exit_id, str(from)])
		for i: int in 4000:
			core.step(bot.next_input(core.player.position))
			if core.exiting:
				break
		assert_true(core.exiting and core.pending_exit.get("exit_id", &"") == exit_id, "%s: the hero reaches it (at %s)" % [exit_id, str(core.player.position)])
	var entrance: ExploreCore = ExploreCore.new(SCENE)
	var bot2: ExploreBot = ExploreBot.new()
	var fight: Dictionary = PropScene.fight_room(_scene)
	assert_true(bot2.plan(entrance.size, entrance.obstacles, entrance.player.position, (fight["area"] as Rect2).get_center()), "entrance -> the middle of the fight area")


func test_walking_is_deterministic() -> void:
	var runs: Array = []
	for r: int in 2:
		var core: ExploreCore = ExploreCore.new(SCENE)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		var trace: PackedVector2Array = PackedVector2Array()
		for i: int in 600:
			var dir: Vector2 = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			core.step(_frame(dir, i % 97 == 0))
			core.exiting = false
			trace.append(core.player.position)
		runs.append(trace)
	assert_eq(runs[0], runs[1], "same inputs, same walk")
	var a: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	var b: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	assert_eq(a.size(), b.size())
	for i: int in a.size():
		assert_true(a[i].center == b[i].center and a[i].radius == b[i].radius, "same collider %d" % i)


func test_random_walks_never_stand_in_a_collider() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var dir: Vector2 = Vector2.RIGHT
	for i: int in 3000:
		if i % 25 == 0:
			dir = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		core.step(_frame(dir, i % 61 == 0))
		core.exiting = false
		assert_true(Collision.fits(core.obstacles, core.player.position, HERO), "inside a collider at %s (tick %d)" % [str(core.player.position), i])


func test_the_stag_reaches_most_of_the_fight_area() -> void:
	var fight: Dictionary = PropScene.fight_room(_scene)
	var radius: float = fight["radius"]
	assert_eq(radius, 20.0, "the Stag keeps the Colossus's body size (Tuning.BOSS_RADIUS)")
	var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(SCENE)
	assert_true(Collision.fits(obstacles, fight["start"], radius), "the Stag's start is free for its body")
	var grid: LayoutFlood = LayoutFlood.new(PropScene.size(_scene), obstacles, radius)
	assert_true(grid.flood(fight["start"]) > 0, "the Stag's start connects to ground")
	var area: Rect2 = fight["area"]
	var total: int = 0
	var open: int = 0
	var y: float = area.position.y + 2.0
	while y < area.end.y:
		var x: float = area.position.x + 2.0
		while x < area.end.x:
			total += 1
			if grid.reaches(Vector2(x, y)):
				open += 1
			x += 4.0
		y += 4.0
	var share: float = float(open) / float(total)
	print("glade_layered: the Stag (radius %.0f) reaches %.1f %% of the fight area" % [radius, share * 100.0])
	assert_true(share >= STAG_SHARE_MIN, "the Stag reaches at least %.0f %% of the fight area (%.1f %%)" % [STAG_SHARE_MIN * 100.0, share * 100.0])
	var hero_grid: LayoutFlood = LayoutFlood.new(PropScene.size(_scene), obstacles, HERO)
	hero_grid.flood(SceneDefs.get_def(SCENE)["entries"][&"entrance"])
	assert_true(hero_grid.reaches(area.get_center()), "the hero reaches the middle of the fight area from the entrance")
