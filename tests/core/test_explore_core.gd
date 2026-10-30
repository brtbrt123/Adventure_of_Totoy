extends "res://tests/test_case.gd"
## Exploration mode (core/explore_core.gd): movement, dash, collisions with the real layouts, world bounds,
## determinism, exits (once per entry), checkpoints, interact, NPC facing, the forest gate.

const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const Collision := preload("res://core/collision.gd")
const Obstacle := preload("res://core/obstacle.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")



## A core with every ability unlocked and the village road open (these tests are about movement, not about the village sequence).
func _new(scene_id: StringName, entry: StringName = &"", gate: bool = false) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(scene_id, entry, gate)
	core.set_story_flags([&"debug_all_unlocked"] as Array[StringName])
	return core

func _frame(move: Vector2 = Vector2.ZERO, dash: bool = false, interact: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move = move
	f.dash_pressed = dash
	f.interact_pressed = interact
	return f


func _types(core: ExploreCore) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: GameEvent in core.last_events:
		out.append(e.type)
	return out


func _event(core: ExploreCore, type: StringName) -> GameEvent:
	for e: GameEvent in core.last_events:
		if e.type == type:
			return e
	return null


## A core in the village with no colliders, the hero in the middle (pure movement rules).
func _open_core() -> ExploreCore:
	var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED)
	core.obstacles = [] as Array[Obstacle]
	core.place_at(Vector2(280, 170))
	return core


func test_walking_uses_the_arena_speed_and_states() -> void:
	var core: ExploreCore = _open_core()
	var start: Vector2 = core.player.position
	for i: int in 10:
		core.step(_frame(Vector2.RIGHT))
	assert_near(core.player.position.x - start.x, 10.0 * Tuning.PLAYER_SPEED, 0.001, "10 ticks of walking")
	assert_eq(core.snapshot().hero.state, &"walk")
	core.step(_frame())
	assert_eq(core.snapshot().hero.state, &"idle")
	core.step(_frame(Vector2.LEFT))
	assert_true(core.snapshot().hero.facing.x < 0.0, "facing follows the move")


func test_dash_matches_the_fight_rules() -> void:
	var core: ExploreCore = _open_core()
	var start: Vector2 = core.player.position
	core.step(_frame(Vector2.RIGHT, true))
	assert_true(_types(core).has(GameEvent.DASH_STARTED), "dash_started")
	assert_eq(core.player.state, PlayerState.STATE_DASH)
	for i: int in Tuning.DASH_TICKS:
		core.step(_frame(Vector2.RIGHT))
	assert_near(core.player.position.x - start.x, Tuning.DASH_SPEED * Tuning.DASH_TICKS, 0.001, "dash distance")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "back to idle after the dash")
	core.step(_frame(Vector2.RIGHT, true))
	assert_true(core.player.state != PlayerState.STATE_DASH, "the cooldown refuses a second dash")
	assert_eq(core.snapshot().dash_cooldown_ticks, Tuning.DASH_COOLDOWN_TICKS - Tuning.DASH_TICKS - 1, "the cooldown counts from the dash press")


func test_no_attacks_parries_or_skills_in_exploration() -> void:
	var core: ExploreCore = _open_core()
	var f: InputFrame = InputFrame.new()
	f.attack_pressed = true
	f.parry_pressed = true
	f.skill_pressed = 2
	f.weapon_active_pressed = true
	for i: int in 30:
		core.step(f)
		assert_true(core.player.state == PlayerState.STATE_IDLE, "only idle/walk/dash: got %s" % core.player.state)
	assert_true(core.player.edge <= Tuning.EXPLORE_EDGE_REGEN_PER_TICK * 60.0 * 10.0, "Edge only comes from the road regeneration here")


func test_entries_and_checkpoints_are_free_spots_outside_the_exits() -> void:
	for scene_id: StringName in SceneDefs.ALL:
		var def: Dictionary = SceneDefs.get_def(scene_id)
		for gate: bool in [false, true]:
			var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(scene_id, gate)
			var points: Dictionary = (def["entries"] as Dictionary).duplicate()
			for c: Dictionary in def["checkpoints"]:
				points[c["id"]] = c["position"]
			for key: StringName in points:
				var p: Vector2 = points[key]
				var m: float = float(def["margin"])
				assert_true(Collision.fits(obstacles, p, Tuning.PLAYER_RADIUS), "%s %s is inside a collider" % [scene_id, key])
				assert_true(p.x >= m and p.y >= m and p.x <= def["size"].x - m and p.y <= def["size"].y - m, "%s %s is outside the world" % [scene_id, key])
				for exit: Dictionary in def["exits"]:
					var r: Rect2 = exit["rect"]
					assert_true(p.clamp(r.position, r.end).distance_to(p) > Tuning.PLAYER_RADIUS, "%s %s touches exit %s" % [scene_id, key, exit["id"]])
			var core: ExploreCore = _new(scene_id, &"", gate)
			assert_eq(core.player.position, def["entries"][def["default_entry"]], "%s spawns exactly on its default entry" % scene_id)


func test_the_scene_graph_is_consistent() -> void:
	var targeted: Dictionary = {}
	for scene_id: StringName in SceneDefs.ALL:
		var def: Dictionary = SceneDefs.get_def(scene_id)
		assert_eq(def["id"], scene_id)
		assert_true(def["entries"].has(def["default_entry"]), "%s default entry exists" % scene_id)
		var ids: Dictionary = {}
		for exit: Dictionary in def["exits"]:
			assert_false(ids.has(exit["id"]), "exit ids are unique")
			ids[exit["id"]] = true
			assert_true(SceneDefs.is_known(exit["target_scene"]), "%s -> unknown scene %s" % [exit["id"], exit["target_scene"]])
			var target: Dictionary = SceneDefs.get_def(exit["target_scene"])
			assert_true(target["entries"].has(exit["target_entry"]), "%s -> %s has no entry %s" % [exit["id"], exit["target_scene"], exit["target_entry"]])
			targeted[exit["target_scene"]] = true
	for scene_id: StringName in [SceneDefs.WOODLAND_LAYERED, SceneDefs.FOREST_LAYERED, SceneDefs.ROOT_HOLLOW_LAYERED, SceneDefs.GLADE_LAYERED, SceneDefs.ARENA, SceneDefs.VILLAGE_LAYERED]:
		assert_true(targeted.has(scene_id), "%s is reachable from another scene" % scene_id)
	# the graph of the brief
	assert_eq(_exit(SceneDefs.VILLAGE_LAYERED, &"to_forest")["target_scene"], SceneDefs.WOODLAND_LAYERED)
	assert_eq(_exit(SceneDefs.WOODLAND_LAYERED, &"to_village")["target_entry"], &"return")
	assert_eq(_exit(SceneDefs.WOODLAND_LAYERED, &"to_forest")["target_scene"], SceneDefs.FOREST_LAYERED)
	assert_eq(_exit(SceneDefs.FOREST_LAYERED, &"to_village")["target_scene"], SceneDefs.WOODLAND_LAYERED)
	assert_eq(_exit(SceneDefs.FOREST_LAYERED, &"to_village")["target_entry"], &"east")
	assert_eq(_exit(SceneDefs.FOREST_LAYERED, &"to_glade")["target_scene"], SceneDefs.ROOT_HOLLOW_LAYERED, "the root gate leads into Root Hollow")
	assert_eq(_exit(SceneDefs.FOREST_LAYERED, &"to_glade")["target_entry"], &"forest_side")
	assert_eq(_exit(SceneDefs.ROOT_HOLLOW_LAYERED, &"to_glade")["target_entry"], &"entrance")
	assert_eq(_exit(SceneDefs.GLADE_LAYERED, &"to_forest")["target_scene"], SceneDefs.ROOT_HOLLOW_LAYERED, "the glade leads back into Root Hollow")
	assert_eq(_exit(SceneDefs.GLADE_LAYERED, &"to_forest")["target_entry"], &"glade_side")
	assert_eq(_exit(SceneDefs.GLADE_LAYERED, &"to_arena")["target_scene"], SceneDefs.ARENA)
	# every two-way pair: the return entry is next to the exit it came through
	var north: Vector2 = SceneDefs.get_def(SceneDefs.FOREST_LAYERED)["entries"][&"north"]
	assert_true(north.distance_to(_exit(SceneDefs.FOREST_LAYERED, &"to_glade")["rect"].get_center()) < 40.0, "the north entry is just below the forest exit")
	var east: Vector2 = SceneDefs.get_def(SceneDefs.WOODLAND_LAYERED)["entries"][&"east"]
	assert_true(east.distance_to(_exit(SceneDefs.WOODLAND_LAYERED, &"to_forest")["rect"].get_center()) < 30.0, "the east entry is beside the exit to the forest")


func _exit(scene_id: StringName, exit_id: StringName) -> Dictionary:
	for exit: Dictionary in SceneDefs.get_def(scene_id)["exits"]:
		if exit["id"] == exit_id:
			return exit
	return {}


## Walks a fresh core from `entry` to the exit `exit_id` with the bot. Returns the core after the exit fired (or not).
func _walk_to_exit(scene_id: StringName, entry: StringName, exit_id: StringName, gate: bool, max_ticks: int = 3000) -> ExploreCore:
	var core: ExploreCore = _new(scene_id, entry, gate)
	var bot: ExploreBot = ExploreBot.new()
	var exit: Dictionary = _exit(scene_id, exit_id)
	if not bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, exit["rect"]):
		return core
	for i: int in max_ticks:
		core.step(bot.next_input(core.player.position))
		if core.exiting:
			break
	return core


func test_the_walking_bot_crosses_every_exit_through_the_real_layouts() -> void:
	var routes: Array = [
		[SceneDefs.VILLAGE_LAYERED, &"arrival", &"to_forest", false],
		[SceneDefs.WOODLAND_LAYERED, &"west", &"to_forest", false],
		[SceneDefs.WOODLAND_LAYERED, &"east", &"to_village", false],
		[SceneDefs.FOREST_LAYERED, &"village_side", &"to_village", false],
		[SceneDefs.FOREST_LAYERED, &"village_side", &"to_glade", true],
		[SceneDefs.GLADE_LAYERED, &"entrance", &"to_forest", false],
		[SceneDefs.GLADE_LAYERED, &"entrance", &"to_arena", false],
		[SceneDefs.FOREST_LAYERED, &"north", &"to_glade", false],
	]
	for route: Array in routes:
		var core: ExploreCore = _walk_to_exit(route[0], route[1], route[2], route[3])
		assert_true(core.exiting and core.pending_exit.get("exit_id", &"") == route[2], "%s from %s reaches %s (at %s)" % [route[0], route[1], route[2], core.player.position])


func test_the_closed_root_gate_blocks_the_forest_exit() -> void:
	var core: ExploreCore = _new(SceneDefs.FOREST_LAYERED, &"village_side", false)
	var bot: ExploreBot = ExploreBot.new()
	assert_false(bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, _exit(SceneDefs.FOREST_LAYERED, &"to_glade")["rect"]), "no path to the north exit while the gate is closed")
	core.set_gate_open(true)
	assert_true(bot.plan(core.size, core.obstacles, core.player.position, Vector2.ZERO, _exit(SceneDefs.FOREST_LAYERED, &"to_glade")["rect"]), "the open gate lets the hero through")
	core.step(_frame())
	var e: GameEvent = _event(core, GameEvent.GATE_CHANGED)
	assert_true(e != null and bool(e.data["gate_open"]), "gate_changed is emitted with the next step")
	assert_true(core.snapshot().gate_open)


func test_closing_the_gate_on_the_hero_pushes_him_out() -> void:
	var core: ExploreCore = _new(SceneDefs.FOREST_LAYERED, &"village_side", true)
	core.place_at(Vector2(377, 109))
	core.set_gate_open(false)
	assert_true(Collision.fits(core.obstacles, core.player.position, Tuning.PLAYER_RADIUS), "not left inside the gate")


func test_the_hero_never_enters_a_collider_or_leaves_the_world() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for scene_id: StringName in SceneDefs.ALL:
		for gate: bool in ([false, true] if scene_id == SceneDefs.FOREST_LAYERED else [false]):
			var core: ExploreCore = _new(scene_id, &"", gate)
			var move: Vector2 = Vector2.RIGHT
			var bad: int = 0
			for i: int in 2400:
				if i % 25 == 0:
					move = Vector2.RIGHT.rotated(rng.randf() * TAU)
				core.step(_frame(move, i % 37 == 0))
				var p: Vector2 = core.player.position
				if not Collision.fits(core.obstacles, p, Tuning.PLAYER_RADIUS) or p.x < core.margin - 0.001 or p.y < core.margin - 0.001 or p.x > core.size.x - core.margin + 0.001 or p.y > core.size.y - core.margin + 0.001:
					bad += 1
				if core.exiting:
					core = _new(scene_id, &"", gate)  # walked out: start again
			assert_eq(bad, 0, "%s (gate %s): ticks inside a collider or outside the world" % [scene_id, gate])


func test_walking_straight_into_every_solid_prop_stops_at_its_edge() -> void:
	for scene_id: StringName in SceneDefs.ALL:
		var core: ExploreCore = _new(scene_id)
		for o: Obstacle in core.obstacles:
			if o.radius < 3.0:
				continue
			var from: Vector2 = o.center + Vector2(0, o.radius + Tuning.PLAYER_RADIUS + 10.0)
			if not Collision.fits(core.obstacles, from, Tuning.PLAYER_RADIUS) or from.y > core.size.y - core.margin:
				continue
			core.place_at(from)
			for i: int in 30:
				core.step(_frame(Vector2.UP))
			assert_true(core.player.position.distance_to(o.center) >= o.radius + Tuning.PLAYER_RADIUS - 0.01, "%s: walked into collider %d" % [scene_id, o.id])
			core.exiting = false


func test_exploration_is_deterministic() -> void:
	var runs: Array = []
	for r: int in 2:
		var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		var trace: Array[Vector2] = []
		for i: int in 900:
			core.step(_frame(Vector2.RIGHT.rotated(rng.randf() * TAU), rng.randf() < 0.03))
			trace.append(core.player.position)
		runs.append(trace)
	assert_eq(runs[0], runs[1], "same inputs, same path")


func test_an_exit_fires_once_and_then_the_hero_stops() -> void:
	var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED, &"return")
	var fired: int = 0
	for i: int in 120:
		core.step(_frame(Vector2.RIGHT))
		for e: GameEvent in core.last_events:
			if e.type == GameEvent.SCENE_EXIT:
				fired += 1
				assert_eq(e.data["target_scene"], SceneDefs.WOODLAND_LAYERED)
				assert_eq(e.data["target_entry"], &"west")
	assert_eq(fired, 1, "scene_exit once per entry")
	assert_true(core.exiting)
	var at: Vector2 = core.player.position
	core.step(_frame(Vector2.LEFT))
	core.step(_frame(Vector2.LEFT))
	assert_eq(core.player.position, at, "the hero no longer moves after the exit")
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_true(snap.exiting and snap.exit_target_scene == SceneDefs.WOODLAND_LAYERED and snap.exit_target_entry == &"west")


func test_an_exit_the_hero_stands_in_waits_until_he_left_it() -> void:
	var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED)
	core.place_at(Vector2(560, 172))
	core.step(_frame(Vector2.RIGHT))
	assert_false(core.exiting, "placed inside the trigger: not armed")
	for i: int in 20:
		core.step(_frame(Vector2.LEFT))
	assert_false(core.exiting)
	for i: int in 30:
		core.step(_frame(Vector2.RIGHT))
	assert_true(core.exiting, "after leaving and coming back it fires")


func test_checkpoints_are_recorded_once() -> void:
	var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED)
	core.step(_frame())
	var e: GameEvent = _event(core, GameEvent.CHECKPOINT)
	assert_true(e != null and e.data["checkpoint_id"] == &"village_layered_gate", "the arrival spot is the village gate checkpoint")
	assert_eq(core.last_checkpoint, &"village_layered_gate")
	core.step(_frame())
	assert_true(_event(core, GameEvent.CHECKPOINT) == null, "not again while it is the last one")
	var forest: ExploreCore = _new(SceneDefs.FOREST_LAYERED)
	var bot: ExploreBot = ExploreBot.new()
	assert_true(bot.plan(forest.size, forest.obstacles, forest.player.position, Vector2(332, 148)))
	var seen: Array[StringName] = []
	for i: int in 1500:
		forest.step(bot.next_input(forest.player.position))
		for ev: GameEvent in forest.last_events:
			if ev.type == GameEvent.CHECKPOINT:
				seen.append(ev.data["checkpoint_id"])
		if bot.done():
			break
	assert_eq(seen, [&"forest_layered_entrance", &"forest_layered_puzzle"] as Array[StringName], "both forest checkpoints, in order")
	assert_eq(forest.snapshot().last_checkpoint, &"forest_layered_puzzle")


func test_continue_at_a_checkpoint() -> void:
	var core: ExploreCore = ExploreCore.at_checkpoint(SceneDefs.FOREST_LAYERED, &"forest_layered_puzzle")
	assert_eq(core.player.position, Vector2(332, 148))
	assert_eq(core.last_checkpoint, &"forest_layered_puzzle")
	core.step(_frame())
	assert_true(_event(core, GameEvent.CHECKPOINT) == null, "a resumed checkpoint is not re-emitted")
	var unknown: ExploreCore = ExploreCore.at_checkpoint(SceneDefs.GLADE_LAYERED, &"no_such")
	assert_eq(unknown.player.position, SceneDefs.get_def(SceneDefs.GLADE_LAYERED)["entries"][&"entrance"], "unknown checkpoint: default entry")


func test_interact_names_the_nearest_npc_in_range() -> void:
	var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED)
	core.step(_frame(Vector2.ZERO, false, true))
	assert_true(_event(core, GameEvent.INTERACT) == null, "Mira is not in range at the gate spawn")
	var mira: Vector2 = SceneDefs.get_def(SceneDefs.VILLAGE_LAYERED)["npcs"][0]["position"]
	core.place_at(mira + Vector2(-16, 0))
	core.step(_frame())
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_eq(snap.interact_target, &"mira")
	assert_eq(snap.interact_kind, &"npc")
	core.step(_frame(Vector2.ZERO, false, true))
	var e: GameEvent = _event(core, GameEvent.INTERACT)
	assert_true(e != null and e.data["target_id"] == &"mira" and e.data["kind"] == &"npc", "interact event names Mira")
	# an object
	var forest: ExploreCore = _new(SceneDefs.FOREST_LAYERED)
	forest.place_at(Vector2(157, 126))
	forest.step(_frame(Vector2.ZERO, false, true))
	var sign_event: GameEvent = _event(forest, GameEvent.INTERACT)
	assert_true(sign_event != null and sign_event.data["target_id"] == &"signpost", "the signpost from its stand point")


func test_npcs_turn_toward_the_hero_when_near() -> void:
	var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED)
	var child: Vector2 = Vector2(253, 210)
	var facing: Dictionary = {}
	for npc: Dictionary in core.snapshot().npcs:
		facing[npc["id"]] = npc["facing_left"]
	assert_false(facing[&"child"], "the child faces right by default")
	core.place_at(child + Vector2(-20, 0))
	core.step(_frame())
	for npc: Dictionary in core.snapshot().npcs:
		if npc["id"] == &"child":
			assert_true(npc["facing_left"] and npc["near"], "the child turns left toward the hero")
	core.place_at(child + Vector2(20, 4))
	core.step(_frame())
	for npc: Dictionary in core.snapshot().npcs:
		if npc["id"] == &"child":
			assert_false(npc["facing_left"], "and right when he is on the right")


func test_npcs_and_the_village_chest_are_solid() -> void:
	var core: ExploreCore = _new(SceneDefs.VILLAGE_LAYERED)
	var mira: Vector2 = SceneDefs.get_def(SceneDefs.VILLAGE_LAYERED)["npcs"][0]["position"]
	core.place_at(mira + Vector2(-20, 0))
	for i: int in 40:
		core.step(_frame(Vector2.RIGHT))
	assert_true(core.player.position.distance_to(mira) >= SceneDefs.NPC_RADIUS + Tuning.PLAYER_RADIUS - 0.01, "Mira is not walked through")


func test_snapshot_lists_the_scene() -> void:
	var snap: ExploreCore.ExploreSnapshot = _new(SceneDefs.VILLAGE_LAYERED).snapshot()
	assert_eq(snap.scene_id, SceneDefs.VILLAGE_LAYERED)
	assert_eq(snap.size, Vector2(571, 336))
	assert_eq(snap.npcs.size(), 6)
	assert_eq(snap.objects.size(), 3)
	assert_eq(snap.hero.visual_id, &"totoy")
	assert_eq(snap.hero.weapon_id, Tuning.WEAPON_BLACK_KATANA)
	assert_true(snap.obstacles.size() > 50 and snap.exits.size() == 1 and snap.checkpoints.size() == 1)
	assert_eq(_new(SceneDefs.FOREST_LAYERED).snapshot().objects.size(), 5)
