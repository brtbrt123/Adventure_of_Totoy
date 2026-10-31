extends "res://tests/test_case.gd"
## The Hollow Trial (data/scenes/hollow_trial_layered_props.json, core/trial.gd, docs/PLAN_hollow_trial.md): the dead-end room behind
## Root Hollow's upper exit. E at the altar seals the entry and starts three waves (warned at the rim before each group appears); surviving
## them sets cleared_hollow_trial, lights the altar, opens the entry and lets the chest on top of the altar give its reward once (E at the
## altar again). Falling resets the try.

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")
const PropScene := preload("res://core/prop_scene.gd")
const Trial := preload("res://core/trial.gd")

const SCENE: StringName = SceneDefs.HOLLOW_TRIAL_LAYERED
const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]


func _core(flags: Array[StringName] = ARMED) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.set_story_flags(flags)
	return core


func _events(core: ExploreCore, type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in core.last_events:
		if e.type == type:
			out.append(e)
	return out


func _step(core: ExploreCore, frame: InputFrame = InputFrame.new()) -> void:
	core.player.hp = 99999
	core.step(frame)


## Walks to the object's stand point and presses E there.
func _use(core: ExploreCore, object_id: StringName) -> void:
	for o: Dictionary in core.def["objects"]:
		if o["id"] == object_id:
			core.place_at(o["stand"])
	var press: InputFrame = InputFrame.new()
	press.interact_pressed = true
	_step(core, press)


## Steps until `type` is emitted (returns it) or `limit` ticks pass.
func _until(core: ExploreCore, type: StringName, limit: int) -> GameEvent:
	for i: int in limit:
		_step(core)
		var found: Array[GameEvent] = _events(core, type)
		if not found.is_empty():
			return found[0]
	return null


func _enc(core: ExploreCore) -> MobField.Encounter:
	return core.mobs.encounters[0]


func _kill_all(core: ExploreCore) -> void:
	var events: Array[GameEvent] = []
	for mob: Mob in _enc(core).mobs.duplicate():
		if mob.is_alive():
			core.mobs.hit_mob(core, _enc(core), mob, 99999.0, {}, events)


## Plays one whole wave: waits for every group, fells everything as it arrives, until the wave is cleared.
func _clear_wave(core: ExploreCore) -> GameEvent:
	for i: int in 2000:
		_step(core)
		_kill_all(core)
		var done: Array[GameEvent] = _events(core, GameEvent.TRIAL_WAVE_CLEARED)
		if not done.is_empty():
			return done[0]
	return null


func _start(core: ExploreCore) -> void:
	_use(core, &"altar")
	core.place_at(Vector2(256, 250))


func test_the_room_is_a_valid_layered_scene_of_the_chapter() -> void:
	assert_true(SceneDefs.LAYERED.has(SCENE) and SceneDefs.ALL.has(SCENE), "registered")
	var data: Dictionary = SceneDefs.layered_data(SCENE)
	assert_eq(PropScene.validate(data, PropScene.load_defs()), PackedStringArray(), "the data is valid")
	var def: Dictionary = SceneDefs.get_def(SCENE)
	assert_eq(def["exits"].size(), 1, "a dead end: one way in and out")
	assert_eq(def["exits"][0]["target_scene"], SceneDefs.ROOT_HOLLOW_LAYERED, "back to Root Hollow")
	assert_eq(def["trial"]["waves"].size(), 3, "three waves")
	var root: Dictionary = {}
	for e: Dictionary in SceneDefs.get_def(SceneDefs.ROOT_HOLLOW_LAYERED)["exits"]:
		if e["id"] == &"shortcut":
			root = e
	assert_eq(root["target_scene"], SCENE, "Root Hollow's upper-left exit leads here")
	assert_eq(root["requires_flag"], &"cleared_hollow_center", "once the hollow is cleared")


func test_the_altar_waits_for_an_armed_hero() -> void:
	var core: ExploreCore = _core([] as Array[StringName])
	_use(core, &"altar")
	assert_eq(core.trial.state, Trial.IDLE, "an unarmed hero cannot start it")
	assert_true(_events(core, GameEvent.TRIAL_STARTED).is_empty(), "no start")


func test_e_at_the_altar_seals_the_room_and_starts_the_first_wave() -> void:
	var core: ExploreCore = _core()
	var before: int = core.obstacles.size()
	_use(core, &"altar")
	assert_false(_events(core, GameEvent.TRIAL_STARTED).is_empty(), "the trial starts")
	assert_true(core.trial.sealed, "the entry is sealed")
	assert_true(core.obstacles.size() > before, "the entry roots close (more colliders)")
	assert_eq(core.snapshot().trial["state"], Trial.STARTING, "the snapshot says so")
	var wave: GameEvent = _until(core, GameEvent.TRIAL_WAVE_STARTED, 200)
	assert_true(wave != null and int(wave.data["wave"]) == 1, "wave 1 after the start time")
	var warned: GameEvent = _until(core, GameEvent.TRIAL_SPAWN_WARNED, 10)
	assert_true(warned != null, "the first group is warned before it appears")
	assert_eq((warned.data["types"] as Array).size(), 5, "four Mosslings and a Boar")
	for p: Variant in warned.data["positions"]:
		assert_true(Vector2(p).distance_to(core.player.position) >= 48.0, "never next to the hero")
	assert_eq(core.mobs.alive_in(&"hollow_trial"), 0, "nothing yet during the warning")
	for i: int in int(core.trial.cfg["warn_ticks"]) + 1:
		_step(core)
	assert_eq(core.mobs.alive_in(&"hollow_trial"), 5, "then they arrive, at the warned spots")
	assert_eq(_enc(core).max_attackers, 4, "four may attack at once in the trial")


func test_the_sealed_entry_holds_the_hero_in() -> void:
	var core: ExploreCore = _core()
	_start(core)
	var exit_rect: Rect2 = core.def["exits"][0]["rect"]
	core.place_at(exit_rect.get_center() + Vector2(0, -26))
	var told: GameEvent = null
	for i: int in 60:
		var frame: InputFrame = InputFrame.new()
		frame.move = Vector2.DOWN
		_step(core, frame)
		assert_true(_events(core, GameEvent.SCENE_EXIT).is_empty(), "no way out during the trial")
		if not _events(core, GameEvent.EXIT_BLOCKED).is_empty():
			told = _events(core, GameEvent.EXIT_BLOCKED)[0]
	assert_true(told == null or String(told.data["text"]).contains("roots"), "and it says why")
	# the rule itself, without the roots in the way (the closed roots alone already stop him above): still shut, with the message
	core.obstacles.clear()
	core.player.position = exit_rect.get_center() + Vector2(0, -12)
	_step(core)
	core.player.position = exit_rect.get_center()
	_step(core)
	assert_false(core.exiting, "the sealed exit does not fire")
	var said: Array[GameEvent] = _events(core, GameEvent.EXIT_BLOCKED)
	assert_true(not said.is_empty() and String(said[0].data["text"]).contains("roots"), "the roots hold, and the hero is told")


func test_three_waves_won_light_the_altar_open_the_room_and_the_chest_pays_once() -> void:
	var core: ExploreCore = _core()
	_start(core)
	var counts: Array[int] = []
	for n: int in 3:
		var spawned: int = 0
		for i: int in 3000:
			_step(core)
			for e: GameEvent in _events(core, GameEvent.TRIAL_SPAWN_WARNED):
				spawned += (e.data["types"] as Array).size()
			_kill_all(core)
			if not _events(core, GameEvent.TRIAL_WAVE_CLEARED).is_empty():
				break
		counts.append(spawned)
	assert_eq(counts, [5, 8, 9] as Array[int], "waves of 5, 6 + 2 late, 5 + 4 late")
	assert_eq(core.trial.state, Trial.WON, "won")
	assert_true(core.has_flag(&"cleared_hollow_trial"), "the trial's flag")
	assert_false(core.trial.sealed, "the entry opens")
	var lit: bool = false
	for p: Dictionary in PropScene.placements(SceneDefs.layered_data(SCENE), PropScene.load_defs(), {"flags": core.story_flags}):
		if p["id"] == &"trial_altar":
			lit = p["type"] == &"hollow_trial_altar_lit"
	assert_true(lit, "the altar shows its lit state")
	var herbs: int = int(core.inventory.get(&"herb", 0))
	_use(core, &"altar")
	assert_false(_events(core, GameEvent.CHEST_OPENED).is_empty(), "the chest opens")
	var after: int = int(core.inventory.get(&"herb", 0))
	assert_eq(after - herbs, 3, "and pays its (placeholder) reward")
	_use(core, &"altar")
	assert_true(_events(core, GameEvent.CHEST_OPENED).is_empty(), "only once")
	assert_eq(int(core.inventory.get(&"herb", 0)), after, "no second reward")
	assert_true(_events(core, GameEvent.TRIAL_STARTED).is_empty(), "a won trial does not start again")


func test_the_chest_on_the_altar_stays_shut_before_the_trial_is_won() -> void:
	var core: ExploreCore = _core()
	_use(core, &"altar")
	assert_false(_events(core, GameEvent.TRIAL_STARTED).is_empty(), "E at the altar starts the trial instead")
	assert_true(_events(core, GameEvent.CHEST_OPENED).is_empty(), "the chest on top stays shut")
	assert_false(core.has_flag(&"trial_chest_opened"), "no flag")


func test_falling_ends_the_try_and_the_altar_can_start_it_again() -> void:
	var core: ExploreCore = _core()
	_start(core)
	_until(core, GameEvent.TRIAL_WAVE_STARTED, 200)
	for i: int in 60:
		_step(core)
	assert_true(core.mobs.alive_in(&"hollow_trial") > 0, "mobs are in the room")
	core.player.hp = 0
	core.player.state = PlayerState.STATE_DEAD
	var failed: GameEvent = null
	for i: int in Tuning.HERO_DEFEAT_TICKS + 5:
		core.step(InputFrame.new())
		if not _events(core, GameEvent.TRIAL_FAILED).is_empty():
			failed = _events(core, GameEvent.TRIAL_FAILED)[0]
			break
	assert_true(failed != null and int(failed.data["wave"]) == 1, "the try fails in wave 1")
	assert_eq(core.trial.state, Trial.IDLE, "the altar waits again")
	assert_false(core.trial.sealed, "the entry opens")
	assert_eq(core.mobs.alive_in(&"hollow_trial"), 0, "the room is empty")
	assert_eq(_enc(core).mobs.size(), 0, "no trial mob is kept")
	_use(core, &"altar")
	assert_false(_events(core, GameEvent.TRIAL_STARTED).is_empty(), "and it can start again")


func test_trial_mobs_pay_exp_but_leave_no_kill_flags() -> void:
	var core: ExploreCore = _core()
	_start(core)
	_until(core, GameEvent.TRIAL_WAVE_STARTED, 200)
	for i: int in int(core.trial.cfg["warn_ticks"]) + 2:
		_step(core)
	var exp_before: int = core.exp_total
	_kill_all(core)
	assert_true(core.exp_total > exp_before, "EXP paid")
	for flag: StringName in core.story_flags:
		assert_false(String(flag).begins_with("killed_hollow_trial"), "no kill flag (%s)" % flag)
	assert_false(core.has_flag(&"cleared_hollow_trial"), "felling a wave does not clear the trial")


func test_a_won_trial_stays_won_after_continue() -> void:
	var flags: Array[StringName] = ARMED.duplicate()
	flags.append(&"cleared_hollow_trial")
	var core: ExploreCore = _core(flags)
	assert_eq(core.trial.state, Trial.WON, "won")
	assert_false(core.trial.sealed, "open")
	_use(core, &"altar")
	assert_true(_events(core, GameEvent.TRIAL_STARTED).is_empty(), "nothing to start")
	assert_false(_events(core, GameEvent.CHEST_OPENED).is_empty(), "E at the altar opens the unopened chest on top")


func test_the_same_play_spawns_the_same_way() -> void:
	var runs: Array[String] = []
	for n: int in 2:
		var core: ExploreCore = _core()
		_start(core)
		var text: String = ""
		for i: int in 400:
			_step(core)
			for e: GameEvent in _events(core, GameEvent.TRIAL_SPAWN_WARNED):
				text += "%d:%s;" % [core.tick, e.data["positions"]]
		runs.append(text)
	assert_eq(runs[0], runs[1], "deterministic")
	assert_true(runs[0] != "", "and something spawned")


# ---- the registered room (Codex's props, 2026-10-31) -------------------------------------------------------------------------------

const LayoutFlood := preload("res://tests/layout_flood.gd")
const HERO: float = 6.0


func _flood_room(tags: Array = [], flags: Array = []) -> LayoutFlood:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var flood: LayoutFlood = LayoutFlood.new(def["size"], SceneDefs.build_obstacles(SCENE, false, [], flags, tags), HERO)
	flood.flood(def["entries"][&"south"])
	return flood


func test_the_room_uses_codexs_registered_props() -> void:
	var defs: Dictionary = PropScene.load_defs()
	for type_id: String in ["hollow_trial_altar_dark", "hollow_trial_altar_lit", "hollow_trial_chest_closed", "hollow_trial_chest_open", "hollow_trial_tree_1"]:
		assert_true(defs["props"].has(type_id), "%s is in the catalogue" % type_id)
	var rows: Dictionary = {}
	for row: Dictionary in SceneDefs.layered_data(SCENE)["props"]:
		rows[row["id"]] = row
	assert_eq(rows["trial_altar"]["type"], "hollow_trial_altar_dark", "the real altar")
	assert_eq(rows["trial_chest"]["type"], "hollow_trial_chest_closed", "the real chest")
	assert_eq(Vector2(rows["trial_chest"]["x"], rows["trial_chest"]["y"]), Vector2(256, 181), "on top of the altar, drawn in front of it")
	assert_false(bool(defs["props"]["hollow_trial_chest_closed"]["solid"]), "the chest adds no collider: the altar holds the body")


func test_the_altar_spawn_points_and_way_out_are_reachable() -> void:
	var flood: LayoutFlood = _flood_room()
	var def: Dictionary = SceneDefs.get_def(SCENE)
	for o: Dictionary in def["objects"]:
		assert_true(flood.reaches(o["stand"]), "%s can be used" % o["id"])
	for p: Variant in def["trial"]["spawn_points"]:
		assert_true(flood.reaches(Vector2(float(p[0]), float(p[1]))), "spawn point %s is open floor" % [p])
	assert_true(flood.reaches(Rect2(def["exits"][0]["rect"]).get_center() + Vector2(0, -6)), "the way out is open when no trial runs")


func test_the_fight_floor_is_open_but_for_the_altar() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var flood: LayoutFlood = _flood_room()
	var r: Array = [112, 92, 288, 184]  # the fight floor of docs/previews/hollow_trial_v1/layout.json
	var total: int = 0
	var open: int = 0
	var y: float = float(r[1])
	while y <= float(r[1]) + float(r[3]):
		var x: float = float(r[0])
		while x <= float(r[0]) + float(r[2]):
			total += 1
			if flood.reaches(Vector2(x, y)) or Vector2(x, y).distance_to(Vector2(256, 170)) < 40.0:
				open += 1
			x += 8.0
		y += 8.0
	assert_true(float(open) / float(total) > 0.97, "the fight floor is clear apart from the altar (%d of %d samples)" % [open, total])


func test_the_sealed_roots_close_the_way_out() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var inside: Vector2 = Vector2(256, 300)
	var sealed: LayoutFlood = LayoutFlood.new(def["size"], SceneDefs.build_obstacles(SCENE, false, [], [], [&"sealed"]), HERO)
	sealed.flood(inside)
	assert_false(sealed.reaches(Vector2(256, 349)), "the closed roots seal the bottom opening")
	var open: LayoutFlood = LayoutFlood.new(def["size"], SceneDefs.build_obstacles(SCENE, false, [], [], []), HERO)
	open.flood(inside)
	assert_true(open.reaches(Vector2(256, 349)), "and the open roots let him through")
