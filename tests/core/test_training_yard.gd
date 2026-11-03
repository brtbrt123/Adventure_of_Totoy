extends "res://tests/test_case.gd"
## The village's training post (core/training_yard.gd, used by core/explore_core.gd): only a scene with a post has a yard, the
## hero fights only in it and only after Tovan, the four lessons (attack, dash, parry, dodge, in that order) set their flags and each ability unlocks when its lesson begins, practice hits
## cost nothing, nothing is random, and training_done follows the last lesson.

const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const TrainingYard := preload("res://core/training_yard.gd")

const Collision := preload("res://core/collision.gd")
const Obstacle := preload("res://core/obstacle.gd")
const ExploreBot := preload("res://tests/explore_bot.gd")
const SCENES: Array[StringName] = [SceneDefs.VILLAGE_LAYERED]


func _frame(move: Vector2 = Vector2.ZERO, attack: bool = false, parry: bool = false, dash: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move = move
	f.attack_pressed = attack
	f.attack_held = attack
	f.parry_pressed = parry
	f.dash_pressed = dash
	f.aim = Vector2.UP
	return f


func _types(core: ExploreCore) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: GameEvent in core.last_events:
		out.append(e.type)
	return out


func _stand(core: ExploreCore) -> Vector2:
	for object: Dictionary in core.def["objects"]:
		if object["kind"] == &"dummy":
			return object["stand"]
	return Vector2.ZERO


## A core with the hero at the post's stand point, idle; `flags` already set.
func _yard(scene: StringName = SceneDefs.VILLAGE_LAYERED, flags: Array[StringName] = [&"met_tovan"]) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(scene)
	core.set_story_flags(flags)
	core.place_at(_stand(core))
	core.step(_frame())
	return core


func _swing(core: ExploreCore) -> void:
	core.step(_frame(Vector2.ZERO, true))
	for i: int in 90:
		if core.player.state == PlayerState.STATE_IDLE:
			return
		core.step(_frame())


## Steps idle until the post winds up a warning (returns it, or null).
func _until_warning(core: ExploreCore, limit: int = 400) -> Telegraph:
	for i: int in limit:
		if core.training.telegraph != null:
			return core.training.telegraph
		core.step(_frame())
	return null


func _all_lessons() -> Array[StringName]:
	return [&"met_tovan", &"lesson_attack", &"lesson_dash", &"lesson_parry", &"lesson_dodge"] as Array[StringName]


## The flags of a hero who has done the attack and dash lessons (the post winds up from here).
func _past_dash() -> Array[StringName]:
	return [&"met_tovan", &"lesson_attack", &"lesson_dash"] as Array[StringName]


func test_only_scenes_with_a_post_have_a_yard() -> void:
	for scene: StringName in SCENES:
		assert_true(ExploreCore.new(scene).training != null, "%s has the post" % scene)
	for scene: StringName in [SceneDefs.FOREST_LAYERED, SceneDefs.GLADE_LAYERED, SceneDefs.ARENA, SceneDefs.FOREST_LAYERED, SceneDefs.GLADE_LAYERED]:
		var core: ExploreCore = ExploreCore.new(scene)
		assert_true(core.training == null and core.snapshot().training.is_empty(), "%s has none" % scene)


func test_the_post_sleeps_until_tovan_has_been_heard() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE_LAYERED, [] as Array[StringName])
	_swing(core)
	assert_eq(core.training.hits, 0, "no hit before Tovan")
	assert_eq(core.snapshot().hero.state, &"idle", "the attack input is ignored")
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_true(snap.training["awake"] == false and snap.training["active"] == false and snap.training["hint"] == &"")
	for i: int in 300:
		core.step(_frame())
	assert_true(core.training.telegraph == null, "the post does not wind up")


func test_attacking_outside_the_yard_does_nothing() -> void:
	var core: ExploreCore = _yard()
	core.place_at(_stand(core) + Vector2(TrainingYard.YARD_RADIUS + 40.0, 0))
	core.step(_frame())
	core.step(_frame(Vector2.ZERO, true))
	assert_eq(core.snapshot().hero.state, &"idle", "no swing outside the yard")


func test_three_swings_teach_the_attack_once_per_swing() -> void:
	for scene: StringName in SCENES:
		var core: ExploreCore = _yard(scene)
		_swing(core)
		assert_eq(core.training.hits, 1, "%s: one swing, one hit" % scene)
		assert_true(&"training_post_hit" in _types(core) or core.training.hits == 1)
		_swing(core)
		assert_false(core.has_flag(&"lesson_attack"), "two hits are not enough")
		var granted: bool = false
		_swing(core)
		granted = core.has_flag(&"lesson_attack")
		assert_true(granted, "%s: the third hit teaches the attack" % scene)
		assert_eq(core.training.hits, 3)


func test_a_missed_swing_does_not_count() -> void:
	var core: ExploreCore = _yard()
	core.place_at(_stand(core) + Vector2(0, 60))  # in the yard, out of reach
	core.step(_frame())
	_swing(core)
	assert_eq(core.training.hits, 0)


func test_the_dash_lesson_wants_the_ring_after_the_attack_lesson() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE_LAYERED, [&"met_tovan", &"lesson_attack"] as Array[StringName])
	assert_true(core.snapshot().training["ring"]["active"], "the ring shows while the dash lesson is the current one")
	var ring: Vector2 = core.training.ring_center()
	assert_true(Collision.fits(core.obstacles, ring, 6.0), "the ring stands on free ground")
	# a dash elsewhere in the yard teaches nothing
	core.place_at(_stand(core) + Vector2(60, 0))
	core.step(_frame())
	core.step(_frame(Vector2.RIGHT, false, false, true))
	for i: int in 12:
		core.step(_frame())
	assert_false(core.has_flag(&"lesson_dash"), "a dash that misses the ring teaches nothing")
	for i: int in Tuning.DASH_COOLDOWN_TICKS + 5:
		core.step(_frame())  # the dash is ready again
	# a dash through it does
	core.place_at(ring + Vector2(-14, 0))
	core.step(_frame())
	core.step(_frame(Vector2.RIGHT, false, false, true))
	for i: int in 10:
		core.step(_frame())
	assert_true(core.has_flag(&"lesson_dash"), "dash taught")
	assert_true(core.has_flag(&"unlocked_parry"), "the parry lesson begins: the parry unlocks")
	assert_false(core.snapshot().training["ring"]["active"])


func test_the_dash_is_locked_until_its_lesson_and_the_ring_waits_for_the_attack() -> void:
	var core: ExploreCore = _yard()
	assert_true(core.has_flag(&"unlocked_attack") and not core.has_flag(&"unlocked_dash"), "only the attack is unlocked after the sword")
	var at: Vector2 = core.player.position
	core.step(_frame(Vector2.RIGHT, false, false, true))
	core.step(_frame())
	assert_true(core.player.state != PlayerState.STATE_DASH and not core.has_flag(&"lesson_dash"), "the dash key does nothing yet")
	var walked: bool = core.player.position.distance_to(at) < Tuning.DASH_SPEED * Tuning.DASH_TICKS
	assert_true(walked, "he only walked")
	assert_false(core.snapshot().training["ring"]["active"], "no ring before the attack is learned")
	assert_false(core.snapshot().unlocked["dash"] or core.snapshot().unlocked["parry"])
	core.set_story_flags([&"met_tovan", &"lesson_attack"] as Array[StringName])
	assert_true(core.snapshot().unlocked["dash"] and not core.snapshot().unlocked["parry"], "the attack lesson is done: the dash lesson begins")
	core.set_story_flags(_past_dash())
	assert_true(core.snapshot().unlocked["parry"], "then the parry")


func test_the_post_does_not_wind_up_before_the_attack_and_dash_lessons() -> void:
	var core: ExploreCore = _yard()
	for i: int in 400:
		core.step(_frame())
	assert_true(core.training.telegraph == null, "no warning while the attack is still being learned")
	core.set_story_flags([&"met_tovan", &"lesson_attack"] as Array[StringName])
	for i: int in 400:
		core.step(_frame())
	assert_true(core.training.telegraph == null, "nor while the dash is")
	core.set_story_flags(_past_dash())
	assert_true(_until_warning(core) != null, "after both, it winds up")


func test_the_gold_warning_comes_first_and_a_timed_parry_teaches_it() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE_LAYERED, _past_dash())
	var t: Telegraph = _until_warning(core)
	assert_true(t != null and t.kind == Telegraph.KIND_GOLD, "the first warning is gold")
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_eq(snap.telegraphs.size(), 1, "presentation gets the fight's telegraph snapshot")
	assert_eq(snap.telegraphs[0].kind, &"gold")
	assert_eq(snap.telegraphs[0].hit_tick - snap.telegraphs[0].start_tick, TrainingYard.WARN_TICKS)
	var parried: bool = false
	for i: int in 120:
		core.step(_frame(Vector2.ZERO, false, core.tick == t.hit_tick - 5))
		parried = parried or &"parry_succeeded" in _types(core)
		if core.training.telegraph == null:
			break
	assert_true(parried, "parry_succeeded")
	assert_true(core.has_flag(&"lesson_parry"))
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "practice costs nothing")


func test_an_unparried_gold_hit_is_a_practice_hit_and_the_post_tries_again() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE_LAYERED, _past_dash())
	var t: Telegraph = _until_warning(core)
	var struck: bool = false
	for i: int in 120:
		core.step(_frame())
		struck = struck or &"training_hero_hit" in _types(core)
		if core.training.telegraph == null:
			break
	assert_true(struck, "training_hero_hit")
	assert_false(core.has_flag(&"lesson_parry"))
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "no damage")
	var again: Telegraph = _until_warning(core)
	assert_true(again != null and again.kind == Telegraph.KIND_GOLD and again.id != t.id, "a new gold warning")


func test_the_red_warning_needs_a_dash_and_comes_after_the_parry() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE_LAYERED, [&"met_tovan", &"lesson_attack", &"lesson_dash", &"lesson_parry"] as Array[StringName])
	var t: Telegraph = _until_warning(core)
	assert_true(t != null and t.kind == Telegraph.KIND_RED, "red once the parry is learned")
	# standing still is a practice hit and no credit
	var struck: bool = false
	for i: int in 120:
		core.step(_frame())
		struck = struck or &"training_hero_hit" in _types(core)
		if core.training.telegraph == null:
			break
	assert_true(struck)
	assert_false(core.has_flag(&"lesson_dodge"))
	# dashing away during the next warning teaches it
	var next: Telegraph = _until_warning(core)
	var dodged: bool = false
	for i: int in 120:
		core.step(_frame(Vector2.DOWN if core.tick == next.hit_tick - 3 else Vector2.ZERO, false, false, core.tick == next.hit_tick - 3))
		dodged = dodged or &"training_dodged" in _types(core)
		if core.training.telegraph == null:
			break
	assert_true(dodged, "training_dodged")
	assert_true(core.has_flag(&"lesson_dodge"))


func test_the_last_lesson_sets_training_done_and_the_post_rests() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE_LAYERED, [&"met_tovan", &"lesson_attack", &"lesson_dash", &"lesson_parry"] as Array[StringName])
	var next: Telegraph = _until_warning(core)
	for i: int in 120:
		core.step(_frame(Vector2.DOWN if core.tick == next.hit_tick - 3 else Vector2.ZERO, false, false, core.tick == next.hit_tick - 3))
		if core.training.telegraph == null:
			break
	assert_true(core.has_flag(&"lesson_dodge") and core.has_flag(&"training_done"), "all four taught: done")
	assert_true(core.snapshot().training["done"])
	for i: int in 400:
		core.step(_frame())
	assert_true(core.training.telegraph == null, "nothing more to teach: the post rests")
	assert_eq(core.snapshot().training["hint"], &"")


func test_the_hint_follows_the_lessons_in_order() -> void:
	var core: ExploreCore = _yard()
	assert_eq(core.snapshot().training["hint"], &"attack")
	core.set_story_flags([&"met_tovan", &"lesson_attack"] as Array[StringName])
	assert_eq(core.snapshot().training["hint"], &"dash")
	core.set_story_flags(_past_dash())
	assert_eq(core.snapshot().training["hint"], &"parry")
	core.set_story_flags([&"met_tovan", &"lesson_attack", &"lesson_dash", &"lesson_parry"] as Array[StringName])
	assert_eq(core.snapshot().training["hint"], &"dodge")
	core.set_story_flags(_all_lessons())
	assert_eq(core.snapshot().training["hint"], &"")
	assert_eq(core.snapshot().training["lessons"], {&"attack": true, &"dash": true, &"parry": true, &"dodge": true})


func test_each_lesson_pays_its_exp_once_and_the_objective_follows() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE_LAYERED, [&"met_mira", &"received_first_sword", &"met_tovan"] as Array[StringName])
	assert_eq(core.snapshot().objective["id"], &"attack")
	assert_eq(core.snapshot().objective["target"], &"training_dummy")
	_swing(core)
	_swing(core)
	_swing(core)
	assert_true(core.has_flag(&"lesson_attack"))
	assert_eq(core.exp_total, 10, "the attack lesson pays 10 EXP")
	assert_eq(core.snapshot().objective["id"], &"dash", "and the next task is the dash")
	var ring: Vector2 = core.training.ring_center()
	core.place_at(ring + Vector2(-14, 0))
	core.step(_frame())
	core.step(_frame(Vector2.RIGHT, false, false, true))
	for i: int in 10:
		core.step(_frame())
	assert_eq(core.exp_total, 20)
	for i: int in 60:
		core.step(_frame())
	assert_eq(core.exp_total, 20, "nothing pays twice")


func test_leaving_the_yard_drops_the_warning() -> void:
	var core: ExploreCore = _yard()
	_until_warning(core)
	core.place_at(_stand(core) + Vector2(TrainingYard.YARD_RADIUS + 40.0, 0))
	core.step(_frame())
	assert_true(core.training.telegraph == null and core.snapshot().telegraphs.is_empty())


func test_the_training_is_deterministic() -> void:
	var runs: Array[String] = []
	for n: int in 2:
		var core: ExploreCore = _yard()
		var log: Array[String] = []
		for i: int in 260:
			core.step(_frame(Vector2.ZERO, i % 40 == 5, i % 70 == 40, i == 100))
			log.append("%d|%s|%s|%s" % [core.player.position.round().x, core.player.state, str(core.training.hits), str(_types(core))])
		runs.append("\n".join(log))
	assert_eq(runs[0], runs[1])


func test_a_talk_still_freezes_the_hero_in_the_yard() -> void:
	var core: ExploreCore = _yard()
	core.set_story_flags([&"met_tovan"] as Array[StringName])
	for row: Dictionary in core.def["npcs"]:
		if row["id"] == &"tovan":
			core.place_at(row["position"] + Vector2(0, 14))
	core.step(_frame())
	core.step(_frame())
	var started: bool = false
	var f: InputFrame = _frame()
	f.interact_pressed = true
	core.step(f)
	started = core.is_talking()
	if started:
		var at: Vector2 = core.player.position
		core.step(_frame(Vector2.ZERO, true))
		assert_eq(core.player.position, at)
		assert_eq(core.snapshot().hero.state, &"idle", "no swing while talking")


# --- the post moved to open ground south of the forge (2026-10-27) ---

const OLD_POST: Dictionary = {&"village_layered": Vector2(345, 118)}
const NEW_POST: Dictionary = {&"village_layered": Vector2(380, 180)}


func _object(scene: StringName) -> Dictionary:
	for object: Dictionary in SceneDefs.get_def(scene)["objects"]:
		if object["kind"] == &"dummy":
			return object
	return {}


func test_the_post_stands_on_the_new_spot_in_both_villages() -> void:
	for scene: StringName in SCENES:
		var object: Dictionary = _object(scene)
		assert_eq(object["position"], NEW_POST[scene], "%s: the post's feet" % scene)
		assert_eq(object["stand"], NEW_POST[scene] + Vector2(0, 16), "%s: the use spot in front" % scene)
		var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(scene)
		assert_false(Collision.fits(obstacles, NEW_POST[scene], 6.0), "%s: the post is solid where it stands" % scene)
		assert_true(Collision.fits(obstacles, OLD_POST[scene], 6.0), "%s: nothing invisible is left at the old spot" % scene)
		assert_true(Collision.fits(obstacles, object["stand"], 6.0), "%s: the hero can stand in front of it" % scene)


func test_the_new_yard_is_roomy_and_reachable() -> void:
	for scene: StringName in SCENES:
		var obstacles: Array[Obstacle] = SceneDefs.build_obstacles(scene)
		var post: Vector2 = NEW_POST[scene]
		var free: int = 0
		for i: int in 32:
			var at: Vector2 = post + Vector2.RIGHT.rotated(TAU * i / 32.0) * 44.0
			if Collision.fits(obstacles, at, 6.0):
				free += 1
		assert_eq(free, 32, "%s: all 32 samples on a 44 px ring round the post are free" % scene)
		# the hero walks there from the arrival and on to the east exit
		var core: ExploreCore = ExploreCore.new(scene)
		var bot: ExploreBot = ExploreBot.new()
		assert_true(bot.plan(core.size, core.obstacles, core.player.position, _object(scene)["stand"]), "%s: a route to the post's stand point" % scene)
		var exit_rect: Rect2 = Rect2()
		for exit: Dictionary in core.def["exits"]:
			exit_rect = exit["rect"]
		assert_true(ExploreBot.new().plan(core.size, core.obstacles, _object(scene)["stand"], Vector2.ZERO, exit_rect), "%s: and from the post to the forest exit" % scene)


func test_the_whole_yard_can_be_fought_in_without_blocking_the_roads() -> void:
	for scene: StringName in SCENES:
		var core: ExploreCore = ExploreCore.new(scene)
		var post: Vector2 = NEW_POST[scene]
		# every cell of the yard disc that is free is reachable from the stand point (no sealed pockets)
		var start: Vector2i = Vector2i(_object(scene)["stand"])
		var seen: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		var head: int = 0
		var free_cells: int = 0
		var step: int = 4
		for x: int in range(-100, 101, step):
			for y: int in range(-100, 101, step):
				var c: Vector2 = post + Vector2(x, y)
				if c.distance_to(post) <= TrainingYard.YARD_RADIUS and Collision.fits(core.obstacles, c, 6.0):
					free_cells += 1
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			for d: Vector2i in [Vector2i(step, 0), Vector2i(-step, 0), Vector2i(0, step), Vector2i(0, -step)]:
				var n: Vector2i = cell + d
				if seen.has(n) or Vector2(n).distance_to(post) > TrainingYard.YARD_RADIUS or not Collision.fits(core.obstacles, Vector2(n), 6.0):
					continue
				seen[n] = true
				queue.append(n)
		assert_true(float(seen.size()) / float(free_cells) >= 0.95, "%s: %d of %d free yard cells reachable" % [scene, seen.size(), free_cells])
		print("yard %s: %d free cells of the disc, %.0f %% reachable" % [scene, free_cells, 100.0 * seen.size() / free_cells])
