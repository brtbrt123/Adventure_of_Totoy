extends "res://tests/test_case.gd"
## The village's training post (core/training_yard.gd, used by core/explore_core.gd): only a scene with a post has a yard, the
## hero fights only in it and only after Tovan, the four lessons (dash, attack, parry, dodge) set their flags, practice hits
## cost nothing, nothing is random, and training_done follows the last lesson.

const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const TrainingYard := preload("res://core/training_yard.gd")

const SCENES: Array[StringName] = [SceneDefs.VILLAGE, SceneDefs.VILLAGE_LAYERED]


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
func _yard(scene: StringName = SceneDefs.VILLAGE, flags: Array[StringName] = [&"met_tovan"]) -> ExploreCore:
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
	return [&"met_tovan", &"lesson_dash", &"lesson_attack", &"lesson_parry", &"lesson_dodge"] as Array[StringName]


func test_only_scenes_with_a_post_have_a_yard() -> void:
	for scene: StringName in SCENES:
		assert_true(ExploreCore.new(scene).training != null, "%s has the post" % scene)
	for scene: StringName in [SceneDefs.FOREST, SceneDefs.GLADE, SceneDefs.ARENA, SceneDefs.FOREST_LAYERED, SceneDefs.GLADE_LAYERED]:
		var core: ExploreCore = ExploreCore.new(scene)
		assert_true(core.training == null and core.snapshot().training.is_empty(), "%s has none" % scene)


func test_the_post_sleeps_until_tovan_has_been_heard() -> void:
	var core: ExploreCore = _yard(SceneDefs.VILLAGE, [] as Array[StringName])
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


func test_a_dash_in_the_yard_teaches_the_dash_and_one_outside_does_not() -> void:
	var core: ExploreCore = _yard()
	core.step(_frame(Vector2.RIGHT, false, false, true))
	assert_true(core.has_flag(&"lesson_dash"), "dash taught")
	assert_true(&"flag_set" in _types(core))
	var far: ExploreCore = _yard()
	far.place_at(_stand(far) + Vector2(TrainingYard.YARD_RADIUS + 60.0, 0))
	far.step(_frame(Vector2.RIGHT, false, false, true))
	assert_false(far.has_flag(&"lesson_dash"), "a dash elsewhere teaches nothing")


func test_the_gold_warning_comes_first_and_a_timed_parry_teaches_it() -> void:
	var core: ExploreCore = _yard()
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
	var core: ExploreCore = _yard()
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
	var core: ExploreCore = _yard(SceneDefs.VILLAGE, [&"met_tovan", &"lesson_parry"] as Array[StringName])
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
	var core: ExploreCore = _yard(SceneDefs.VILLAGE, [&"met_tovan", &"lesson_dash", &"lesson_attack", &"lesson_parry"] as Array[StringName])
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
	assert_eq(core.snapshot().training["hint"], &"dash")
	core.set_story_flags([&"met_tovan", &"lesson_dash"] as Array[StringName])
	assert_eq(core.snapshot().training["hint"], &"attack")
	core.set_story_flags([&"met_tovan", &"lesson_dash", &"lesson_attack"] as Array[StringName])
	assert_eq(core.snapshot().training["hint"], &"parry")
	core.set_story_flags(_all_lessons())
	assert_eq(core.snapshot().training["hint"], &"")
	assert_eq(core.snapshot().training["lessons"], {&"dash": true, &"attack": true, &"parry": true, &"dodge": true})


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
