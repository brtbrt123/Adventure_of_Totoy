extends SceneTree
## Deterministic intro flow with a throwaway save; never touches the player's profile.
const Intro := preload("res://presentation/cutscene/intro.gd")
const Title := preload("res://presentation/menu/title.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Book := preload("res://core/cutscene_book.gd")
const SaveStore := preload("res://core/save_store.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const SAVE_PATH: String = "res://art/build/arena_intro_smoke_save.json"
var failures: Array[String] = []
var routes: Array[String] = []
var previous_save: String = ""
var previous_meta: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _clear_meta() -> void:
	for key: StringName in [Title.SKIP_INTRO_META, Explore.START_META, Explore.PERSIST_META]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)


func _new_title() -> Title:
	var title: Title = (load("res://presentation/menu/title.tscn") as PackedScene).instantiate() as Title
	root.add_child(title)
	title.set_process(false)
	title.change_scene = func(path: String) -> void: routes.append(path)
	return title


func _new_intro(value: Dictionary = {}) -> Intro:
	var intro: Intro = (load("res://presentation/cutscene/intro.tscn") as PackedScene).instantiate() as Intro
	intro.book = value
	intro.change_scene = func(path: String) -> void: routes.append(path)
	root.add_child(intro)
	intro.set_physics_process(false)
	return intro


func _settle(intro: Intro) -> void:
	for i: int in Intro.FADE_TICKS * 2:
		intro.advance()
		if intro.fade_phase == &"":
			break


func _run() -> void:
	previous_save = OS.get_environment(SaveStore.PATH_ENV)
	OS.set_environment(SaveStore.PATH_ENV, SAVE_PATH)
	for key: StringName in [Title.SKIP_INTRO_META, Explore.START_META, Explore.PERSIST_META]:
		if Engine.has_meta(key):
			previous_meta[key] = Engine.get_meta(key)
	_clear_meta()
	SaveStore.delete()
	_expect(Book.validate(Book.default_book()).is_empty(), "the intro book validates")
	_new_game_skip_and_continue()
	_auto_finish_and_repeat()
	_timing_and_cues()
	_skip_mid_transition()
	await _actual_village_handover()
	SaveStore.delete()
	OS.set_environment(SaveStore.PATH_ENV, previous_save)
	_clear_meta()
	for key: StringName in previous_meta:
		Engine.set_meta(key, previous_meta[key])
	if failures.is_empty():
		print("INTRO CUTSCENE SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("INTRO FAIL: " + message)
		quit(1)


func _new_game_skip_and_continue() -> void:
	var seed: SaveProfile = SaveProfile.new()
	seed.victories = 7
	seed.weapon_id = &"dual_dagger"
	seed.record_scene(&"forest_layered", &"forest_layered_puzzle")
	seed.story_flags.append(&"intro_seen")
	SaveStore.save(seed)
	var title: Title = _new_title()
	routes.clear()
	title.index = 0
	title.activate()
	_expect(routes == [Title.INTRO_SCENE], "real NEW GAME callback opens the intro")
	_expect(not Book.is_seen(Book.default_book(), Book.INTRO, SaveStore.load_profile().story_flags), "New Game clears the old intro flag")
	var intro: Intro = _new_intro()
	_expect(intro.beats.size() == 7 and intro.index == 0, "intro starts at beat one despite arrival meta already present")
	_expect(intro.panel != null and intro.panel.get_size() == Vector2(320, 180), "approved native panel loads")
	_expect(intro.audio.music.stream is AudioStreamWAV and FileAccess.file_exists(Intro.MUSIC_PATH), "intro has its own recorded theme")
	_expect(not intro.audio.ambience_active, "forest ambience is not active on the opening beat")
	routes.clear()
	intro.advance(false, true)
	_expect(Book.is_seen(intro.book, Book.INTRO, SaveStore.load_profile().story_flags), "skip saves intro_seen immediately")
	_expect(routes.is_empty(), "skip first fades before handing over")
	intro.finish(true)
	for i: int in Intro.EXIT_TICKS + 5:
		intro.advance(false, true)
	_expect(routes == [Intro.EXPLORE_SCENE] and intro.save_attempts == 1, "repeated skip saves and changes scene once")
	var start: Dictionary = Engine.get_meta(Explore.START_META, {})
	_expect(start.get("scene", &"") == &"village_layered" and start.get("entry", &"") == &"arrival", "skip prepares the village arrival")
	_expect(bool(start.get("intro_arrival", false)), "intro requests the presentation arrival walk")
	var saved: SaveProfile = SaveStore.load_profile()
	_expect(saved.victories == 7 and saved.weapon_id == &"dual_dagger", "intro preserves fight record and weapon loadout")
	intro.free()
	title.free()
	# Continue after village arrival resumes its checkpoint and never routes through Intro.
	saved.record_scene(&"village_layered", &"village_layered_gate")
	SaveStore.save(saved)
	_clear_meta()
	title = _new_title()
	routes.clear()
	title.index = 1
	title.activate()
	_expect(routes == [Title.EXPLORE_SCENE], "CONTINUE bypasses the intro")
	title.free()
	_clear_meta()


func _auto_finish_and_repeat() -> void:
	var title: Title = _new_title()
	routes.clear()
	title.new_game()
	_expect(routes == [Title.INTRO_SCENE], "subsequent New Game replays the intro")
	var intro: Intro = _new_intro()
	routes.clear()
	var visited: Dictionary = {}
	for i: int in 10000:
		visited[intro.index] = true
		intro.advance()
		if intro.handed_over:
			break
	_expect(visited.size() == 7 and intro.handed_over and not intro.skipped, "all seven beats finish automatically")
	_expect(routes == [Intro.EXPLORE_SCENE] and intro.save_attempts == 1, "natural completion saves/routes exactly once")
	_expect(Book.is_seen(intro.book, Book.INTRO, SaveStore.load_profile().story_flags), "natural completion saves intro_seen")
	_expect(intro.audio.played.get("root_gate_open", 0) == 0, "handover stops and clears cinematic audio")
	intro.free()
	title.free()
	_clear_meta()
	# Record the village as it does on entry, then use the real title a third time.
	var saved: SaveProfile = SaveStore.load_profile()
	saved.record_scene(&"village_layered", &"village_layered_gate")
	SaveStore.save(saved)
	title = _new_title()
	routes.clear()
	title.new_game()
	_expect(routes == [Title.INTRO_SCENE] and not Book.is_seen(Book.default_book(), Book.INTRO, SaveStore.load_profile().story_flags), "New Game after natural completion clears flag and plays again")
	title.free()
	_clear_meta()


func _timing_and_cues() -> void:
	var value: Dictionary = Book.default_book().duplicate(true)
	var list: Array = Book.beats(value, Book.INTRO)
	list[0]["hold"] = 60
	list[0]["sound"] = "aspect_bind"
	var intro: Intro = _new_intro(value)
	_expect(intro.audio.played.get("aspect_bind", 0) == 1 and not intro.audio.played.has("lantern_light"), "data sound overrides the presentation default")
	_settle(intro)
	intro.advance()
	_expect(not intro.complete() and intro.hold_ticks == 0, "hold has not started during typing")
	intro.advance(true)
	_expect(intro.complete() and intro.index == 0 and intro.hold_ticks == 0, "first press reveals the full text without advancing")
	for i: int in 59:
		intro.advance()
	_expect(intro.index == 0 and intro.fade_phase == &"" and intro.hold_ticks == 59, "full hold lasts after the text is complete")
	intro.advance()
	_expect(intro.fade_phase == &"out" and intro.index == 0, "hold expiry starts the outgoing fade")
	_settle(intro)
	_expect(intro.index == 1 and intro.fade_phase == &"" and not intro.complete(), "interbeat fades step even after prior text completes")
	intro.advance(true)
	intro.advance(true)
	_expect(intro.fade_phase == &"out", "second press advances immediately after reveal")
	_settle(intro)
	_expect(intro.index == 2, "manual progression enters the next beat")
	for beat: Dictionary in intro.beats:
		var path: String = Intro.PANEL_DIRECTORY + str(beat["art"]) + ".png"
		_expect(ResourceLoader.exists(path), "all approved panels exist: " + path)
		var lines: Array[String] = intro.wrapped_lines(" ".join(beat["lines"]))
		_expect(lines.size() <= 3, "current caption fits the 32px card: " + str(beat["id"]))
		for line: String in lines:
			_expect(Intro.ui_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Intro.CAPTION_SIZE).x <= Intro.CAPTION_WIDTH, "caption width fits: " + str(beat["id"]))
	var first_crop: Rect2 = intro.panel_region()
	intro.beat_ticks = 9999
	var last_crop: Rect2 = intro.panel_region()
	_expect(first_crop.size == Vector2(320, 180) and last_crop.size == first_crop.size, "motion keeps a 1:1 source pixel crop")
	_expect(first_crop.position == first_crop.position.round() and last_crop.position == last_crop.position.round(), "motion uses integer offsets")
	_expect(last_crop.position.y >= first_crop.position.y, "pan_down moves downward")
	_expect(not intro.audio.played.has("dialogue_blip"), "no per-character cue spam")
	intro.free()
	_clear_meta()


func _skip_mid_transition() -> void:
	var intro: Intro = _new_intro()
	_settle(intro)
	intro.advance(true)
	intro.advance(true)
	for i: int in 4:
		intro.advance()
	var before: float = intro.fade_alpha()
	# Simulate an independent save update after this scene was opened.
	var saved: SaveProfile = SaveStore.load_profile()
	saved.victories = 12
	saved.story_flags.append(&"met_mira")
	SaveStore.save(saved)
	intro.advance(false, true)
	_expect(intro.finished and intro.fade_alpha() >= before, "skip during fade does not flash the image back in")
	saved = SaveStore.load_profile()
	_expect(saved.victories == 12 and saved.story_flags.has(&"met_mira"), "finish loads fresh profile and preserves intervening changes")
	intro.free()
	_clear_meta()


func _actual_village_handover() -> void:
	var intro: Intro = _new_intro()
	intro.finish(true)
	for i: int in Intro.EXIT_TICKS:
		intro.advance()
	intro.free()
	var village: Explore = (load(Intro.EXPLORE_SCENE) as PackedScene).instantiate() as Explore
	root.add_child(village)
	village.set_physics_process(false)
	await process_frame
	_expect(village.snapshot.scene_id == &"village_layered" and village.fade_phase == &"in", "actual exploration receives village arrival and incoming fade")
	_expect(village.snapshot.story_flags.has(&"intro_seen"), "actual village snapshot receives saved intro_seen")
	_expect(SaveStore.load_profile().has_progress(), "village arrival records resumable progress")
	_expect(village.intro_arrival_ticks == 18 and not village.conversation.controls_open, "arrival walk waits for fade and defers controls card")
	var position_before: Vector2 = village.snapshot.hero.position
	for i: int in Explore.FADE_TICKS:
		village._physics_process(1.0 / 60.0)
	_expect(village.intro_arrival_ticks == 18 and village.snapshot.hero.position == position_before, "hero waits while the village fades in")
	for i: int in 18:
		village._physics_process(1.0 / 60.0)
	_expect(village.intro_arrival_ticks == 0 and village.snapshot.hero.position.y > position_before.y, "core movement carries Totoy down from the gate")
	_expect(village.conversation.controls_open, "controls open after the arrival walk")
	village.free()
