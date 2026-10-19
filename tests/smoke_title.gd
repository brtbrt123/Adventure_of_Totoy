extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_title.gd
## The title screen, its pages, and the arena's save hooks (using a throwaway save file).
const Arena := preload("res://presentation/arena/arena.gd")
const Title := preload("res://presentation/menu/title.gd")
const SaveStore := preload("res://core/save_store.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const GameEvent := preload("res://core/game_event.gd")

const SAVE_PATH: String = "user://smoke_title_save.json"

var failures: Array[String] = []
var changed_to: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _result_event(result: StringName) -> GameEvent:
	return GameEvent.new(GameEvent.GAME_RESULT, 0, {"result": result})


func _run() -> void:
	OS.set_environment(SaveStore.PATH_ENV, SAVE_PATH)
	SaveStore.delete(SAVE_PATH)
	if Engine.has_meta(Title.PERSIST_META):
		Engine.remove_meta(Title.PERSIST_META)
	_title_screen()
	await _arena_persistence()
	await _arena_without_persistence()
	SaveStore.delete(SAVE_PATH)
	OS.set_environment(SaveStore.PATH_ENV, "")
	if Engine.has_meta(Title.PERSIST_META):
		Engine.remove_meta(Title.PERSIST_META)
	if failures.is_empty():
		print("TITLE SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("TITLE FAIL: " + message)
		print("TITLE SMOKE FAILED")
		quit(1)


func _title_screen() -> void:
	var title: Title = (load("res://presentation/menu/title.tscn") as PackedScene).instantiate() as Title
	root.add_child(title)
	title.change_scene = func(path: String) -> void: changed_to.append(path)
	_expect(title.screen == Title.SCREEN_TITLE and title.index == 0, "starts on the menu with START selected")
	title.move_selection(-1)
	_expect(title.index == Title.ITEMS.size() - 1, "up from the first item wraps to the last")
	title.move_selection(1)
	_expect(title.index == 0, "down from the last wraps to the first")
	_expect(title.item_at(Vector2(160, Title.MENU_TOP + 4)) == 0 and title.item_at(Vector2(160, Title.MENU_TOP + Title.MENU_STEP + 4)) == 1 and title.item_at(Vector2(10, 10)) == -1, "mouse hit boxes line up with the menu rows")
	title.index = 1
	title.activate()
	_expect(title.screen == Title.SCREEN_CONTROLS, "CONTROLS opens the controls page")
	title.move_selection(1)
	_expect(title.index == 1, "the menu does not move while a page is open")
	title.back()
	_expect(title.screen == Title.SCREEN_TITLE, "back returns to the menu")
	title.index = 2
	title.activate()
	_expect(title.screen == Title.SCREEN_CREDITS, "CREDITS opens the credits page")
	title.activate()
	_expect(title.screen == Title.SCREEN_TITLE, "enter on a page goes back")
	title.index = 0
	title.activate()
	title.activate()  # a second press must not start twice
	_expect(changed_to == [Title.ARENA_SCENE], "START opens the arena exactly once: %s" % str(changed_to))
	_expect(Engine.has_meta(Title.PERSIST_META), "START turns saving on")
	Engine.remove_meta(Title.PERSIST_META)
	# every character on every page and menu line exists in the UI font (nothing falls back to a missing-glyph box)
	var strings: Array[String] = []
	strings.append_array(Title.ITEMS)
	strings.append_array(Title.CONTROL_LINES)
	strings.append_array(Title.CONTROL_FOOTER)
	strings.append_array(Title.CREDIT_LINES)
	strings.append_array(["ADVENTURE OF TOTOY", "GOLD CAN BE PARRIED. RED MUST BE DODGED.", "VICTORIES 0  DEFEATS 0  BEST 1:00.0", "SAVE RESET: NOT VALID JSON", "ESC OR ENTER: BACK", "> START", "NEW BEST!", "ESC: TITLE", "R TO RESTART", "TIME 1:23.4"])
	for line: String in strings:
		for character: String in line.to_upper():
			_expect(Title.ui_font().has_char(character.unicode_at(0)), "the UI font has no glyph for '%s' in \"%s\"" % [character, line])
	# the controls page covers every binding the game uses
	var controls: String = " ".join(Title.CONTROL_LINES).to_upper()
	for needle: String in ["WASD", "LEFT CLICK", "RIGHT CLICK", "SHIFT", "SPACE", "Z:", "X:", "C:", "R:", "ESC"]:
		_expect(controls.contains(needle), "controls page misses " + needle)
	# the credits name every creator in the audio source list and licence notes
	var credits: String = " ".join(Title.CREDIT_LINES).to_upper()
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/audio/sources.json")) as Dictionary
	for source: Dictionary in sources.get("sources", []):
		var creator: String = String(source["creator"]).to_upper()
		_expect(credits.contains(creator), "credits miss audio creator " + creator)
	for creator: String in ["StarNinjas", "artisticdude", "Kenney", "BMacZero", "MintoDog"]:
		_expect(credits.contains(creator.to_upper()), "credits miss " + creator)
	# the pixel font ships with its licence and is named in the credits (OFL requires the licence text to travel with it)
	_expect(credits.contains("PIXELIFY SANS") and credits.contains("OFL"), "credits miss the font")
	_expect(FileAccess.file_exists("res://presentation/fonts/PixelifySans.ttf"), "the pixel font file is missing")
	_expect(FileAccess.get_file_as_string("res://presentation/fonts/OFL-PixelifySans.txt").contains("SIL Open Font License"), "the font licence text is missing")
	_expect(Title.ui_font() is FontVariation and (Title.ui_font() as FontVariation).base_font is FontFile, "titles and names use the pixel font, not the fallback")
	_expect(Title.stat_font() == Title.ui_font(), "numbers use the pixel font too (the human's choice)")
	# nothing runs off the page: credit lines fit in 280 game pixels, control keys and actions in their columns
	for line: String in Title.CREDIT_LINES:
		_expect(Title.text_width(line) <= 280.0, "credit line too wide (%d px): %s" % [int(Title.text_width(line)), line])
	for line: String in Title.CONTROL_LINES:
		var colon: int = line.find(":")
		_expect(Title.text_width(line.substr(0, colon)) <= 52.0, "control key too wide: " + line)
		_expect(Title.text_width(line.substr(colon + 1)) <= 216.0, "control action too wide: " + line)
	for line: String in Title.CONTROL_FOOTER:
		_expect(Title.text_width(line) <= 280.0, "controls footer too wide: " + line)
	_expect(Title.text_width("ADVENTURE OF TOTOY", 3) <= 300.0, "the title fits the screen")
	# the background: the owner's painting, graded; a smooth sprite behind everything
	_expect(title.painted and title.background != null and title.background.get_size() == Vector2(1920, 1080), "the painted menu background loads at 1920x1080")
	_expect(title.background_sprite != null and title.background_sprite.show_behind_parent and absf(title.background_sprite.scale.x * 1920.0 - 320.0) < 0.01, "it fills the 320x180 canvas, behind everything")
	_expect(FileAccess.file_exists("res://art/reference/menu_background_source.jpg"), "the original painting is kept in art/reference")
	# the pixel-art fallback (composed from the game's own tiles) stays palette-bound with shadows baked in
	var fallback: Image = (load(Title.BACKGROUND_PATH) as Texture2D).get_image()
	_expect(fallback.get_size() == Vector2i(320, 180), "the pixel-art fallback is 320x180")
	var allowed: Dictionary = {}
	var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json")) as Dictionary
	var reserved: Array = palette.get("reserved", [])
	for entry: Dictionary in palette["colors"]:
		if not reserved.has(entry["symbol"]):
			allowed[Color.html(entry["hex"])] = true
	var stray: int = 0
	for y: int in 180:
		for x: int in 320:
			if not allowed.has(fallback.get_pixel(x, y)):
				stray += 1
	_expect(stray == 0, "%d fallback background pixels are outside the Totoy 36 palette (or use a reserved gold/red)" % stray)
	for feet: Vector2 in [Title.FEET_HERO, Title.FEET_GOLEM]:
		var under: float = 0.0
		var beside: float = 0.0
		for dx: int in range(-3, 4):
			under += fallback.get_pixel(int(feet.x) + dx, int(feet.y) + 1).get_luminance()
			beside += fallback.get_pixel(int(feet.x) + dx, int(feet.y) + 22).get_luminance()
		_expect(under < beside, "a shadow is baked under the feet in the fallback at %s" % str(feet))
	for n: int in range(1, 5):
		_expect(title.sprite_frames.has("hero2_idle_right_%d" % n) and title.sprite_frames.has("golem2_idle_%d" % n), "idle frame %d exists for the live menu characters" % n)
	title.time = 0.9
	title.queue_redraw()
	# time formatting and the record line
	_expect(Title.format_ticks(0) == "0:00.0", "0 ticks")
	_expect(Title.format_ticks(3600) == "1:00.0", "one minute")
	_expect(Title.format_ticks(3630) == "1:00.5", "a half second")
	_expect(Title.format_ticks(60 * 125 + 6) == "2:05.1", "two minutes five and a tenth")
	var p: SaveProfile = SaveProfile.new()
	p.victories = 2
	p.defeats = 5
	p.best_victory_ticks = 3630
	title.profile = p
	_expect(title.record_text() == "VICTORIES 2  DEFEATS 5  BEST 1:00.5", "record line: " + title.record_text())
	p.best_victory_ticks = 0
	_expect(title.record_text() == "VICTORIES 2  DEFEATS 5", "no best time before the first victory")
	title.queue_redraw()
	title.screen = Title.SCREEN_CONTROLS
	title.queue_redraw()
	title.screen = Title.SCREEN_CREDITS
	title.queue_redraw()
	title.queue_free()


func _arena_persistence() -> void:
	Engine.set_meta(Title.PERSIST_META, true)
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	arena.change_scene = func(path: String) -> void: changed_to.append(path)
	root.add_child(arena)
	await process_frame
	_expect(arena.persist, "the arena saves when started from the title")
	var profile: SaveProfile = SaveStore.load_profile(SAVE_PATH)
	_expect(profile.runs_started == 1, "starting a run is saved: %d" % profile.runs_started)
	arena.core.tick = 1234
	arena._on_event(_result_event(&"victory"))
	profile = SaveStore.load_profile(SAVE_PATH)
	_expect(profile.victories == 1 and profile.best_victory_ticks == 1234 and profile.last_result == &"victory", "a victory is saved with its time")
	_expect(arena.new_best and arena.hud.result_lines.has("NEW BEST!"), "the first victory is a new best")
	_expect(arena.hud.result_lines.has("TIME " + Title.format_ticks(1234)), "the result screen shows the time")
	_expect(arena.hud.result_hint == "ESC: TITLE", "the result screen offers the title")
	arena._restart()
	_expect(arena.hud.result_lines.is_empty(), "restart clears the result lines")
	profile = SaveStore.load_profile(SAVE_PATH)
	_expect(profile.runs_started == 2, "a restart counts as a new run")
	arena.core.tick = 2000
	arena._on_event(_result_event(&"victory"))
	profile = SaveStore.load_profile(SAVE_PATH)
	_expect(profile.best_victory_ticks == 1234 and profile.victories == 2, "a slower victory keeps the best time")
	_expect(not arena.new_best and arena.hud.result_lines.has("BEST " + Title.format_ticks(1234)), "and shows the best time")
	arena._restart()
	arena._on_event(_result_event(&"defeat"))
	profile = SaveStore.load_profile(SAVE_PATH)
	_expect(profile.defeats == 1 and profile.last_result == &"defeat", "a defeat is saved")
	_expect(arena.hud.result_lines.is_empty() and arena.hud.result_hint == "ESC: TITLE", "a defeat shows no time but still offers the title")
	arena.queue_free()
	await process_frame
	Engine.remove_meta(Title.PERSIST_META)


func _arena_without_persistence() -> void:
	SaveStore.delete(SAVE_PATH)
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	_expect(not arena.persist, "an arena started directly does not save")
	arena.core.tick = 500
	arena._on_event(_result_event(&"victory"))
	arena._restart()
	_expect(not FileAccess.file_exists(SAVE_PATH), "so a test run never writes a save file")
	_expect(arena.hud.result_hint == "", "and shows no title hint")
	arena.queue_free()
	await process_frame
