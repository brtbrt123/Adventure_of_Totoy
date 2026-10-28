extends "res://tests/test_case.gd"
## The story cutscenes as data (core/cutscene_book.gd, data/cutscenes/intro.json): the real book is valid, the intro is the New Game
## cutscene with a flag that fits the save, the checks catch every kind of broken data, and the flag makes it play once per new game.

const CutsceneBook := preload("res://core/cutscene_book.gd")
const SaveProfile := preload("res://core/save_profile.gd")


func _broken(change: Callable) -> String:
	var book: Dictionary = CutsceneBook.default_book().duplicate(true)
	change.call(book["cutscenes"]["intro"])
	return "\n".join(CutsceneBook.validate(book))


func test_the_real_book_is_valid_and_has_the_intro() -> void:
	var book: Dictionary = CutsceneBook.default_book()
	assert_eq(CutsceneBook.validate(book), [] as Array[String], "the shipped intro is valid")
	var beats: Array = CutsceneBook.beats(book, CutsceneBook.INTRO)
	assert_true(beats.size() >= 5 and beats.size() <= CutsceneBook.MAX_BEATS, "a short intro (%d beats)" % beats.size())
	assert_eq(CutsceneBook.flag_of(book, CutsceneBook.INTRO), &"intro_seen")
	assert_true(bool(CutsceneBook.cutscene(book, CutsceneBook.INTRO)["skippable"]), "the player may skip it")
	assert_true(CutsceneBook.all_lines(book, CutsceneBook.INTRO).size() <= CutsceneBook.MAX_LINES_TOTAL)
	assert_eq(CutsceneBook.cutscene(book, &"nope"), {}, "an unknown id is empty")
	assert_eq(CutsceneBook.beats(book, &"nope"), [])


func test_the_intro_tells_how_he_came_to_the_village() -> void:
	var text: String = " ".join(CutsceneBook.all_lines(CutsceneBook.default_book(), CutsceneBook.INTRO)).to_lower()
	for word: String in ["beacon", "heartloom", "totoy", "key", "lanternfen"]:
		assert_true(text.contains(word), "the story mentions %s" % word)


func test_the_flag_fits_the_save_and_plays_the_intro_once() -> void:
	var book: Dictionary = CutsceneBook.default_book()
	var flags: Array[StringName] = []
	assert_false(CutsceneBook.is_seen(book, CutsceneBook.INTRO, flags), "a new game has not seen it")
	flags.append(CutsceneBook.flag_of(book, CutsceneBook.INTRO))
	assert_true(CutsceneBook.is_seen(book, CutsceneBook.INTRO, flags))
	var profile: SaveProfile = SaveProfile.new()
	profile.story_flags = flags
	var back: SaveProfile = SaveProfile.from_json(profile.to_json()) as SaveProfile
	assert_true(CutsceneBook.is_seen(book, CutsceneBook.INTRO, back.story_flags), "the flag survives the save")
	back.reset_progress()
	assert_false(CutsceneBook.is_seen(book, CutsceneBook.INTRO, back.story_flags), "NEW GAME clears it, so the intro plays again")
	assert_false(CutsceneBook.is_seen(book, &"nope", flags), "an unknown cutscene is never 'seen'")


func test_the_checks_catch_broken_data() -> void:
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"] = []).contains("needs 1-"), "no beats")
	assert_true(_broken(func(c: Dictionary) -> void: c["flag"] = "Bad Flag").contains("flag"), "a flag that cannot be saved")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["effect"] = "spin").contains("effect"), "an unknown effect")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["hold"] = 5).contains("hold"), "too short a hold")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["hold"] = 99999).contains("hold"), "too long a hold")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["lines"] = []).contains("needs 1-"), "a beat without lines")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["lines"] = ["a", "b", "c", "d"]).contains("needs 1-"), "too many lines in a beat")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["lines"] = ["x".repeat(111)]).contains("limit"), "a line that is too long")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["lines"] = ["  "]).contains("empty line"), "a blank line")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][0]["art"] = "").contains("art"), "no art id")
	assert_true(_broken(func(c: Dictionary) -> void: c["beats"][1]["id"] = c["beats"][0]["id"]).contains("duplicated"), "a duplicated beat id")
	assert_true(_broken(func(c: Dictionary) -> void:
		for i: int in 10:
			c["beats"].append({"id": "extra%d" % i, "art": "a", "effect": "fade_in", "hold": 120, "lines": ["x"]})).contains("needs 1-"), "too many beats")
	assert_true("\n".join(CutsceneBook.validate({})).contains("version"), "an empty book")
	assert_true("\n".join(CutsceneBook.validate({"version": 1, "cutscenes": {"other": {}}})).contains("intro cutscene is missing"), "no intro")
