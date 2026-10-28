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
	_expect(title.screen == Title.SCREEN_TITLE and title.index == 0, "starts on the menu with NEW GAME selected")
	_expect(Array(Title.ITEMS) == ["NEW GAME", "CONTINUE", "BOSS FIGHT", "CONTROLS", "CREDITS", "QUIT"], "the menu items")
	_expect(Title.MENU_TOP + (Title.ITEMS.size() - 1) * Title.MENU_STEP + Title.MENU_STEP <= 178, "the last menu line fits the screen")
	title.move_selection(-1)
	_expect(title.index == Title.ITEMS.size() - 1, "up from the first item wraps to the last")
	title.move_selection(1)
	_expect(title.index == 0, "down from the last wraps to the first")
	_expect(title.item_at(Vector2(160, Title.MENU_TOP + 4)) == 0 and title.item_at(Vector2(160, Title.MENU_TOP + Title.MENU_STEP + 4)) == 1 and title.item_at(Vector2(10, 10)) == -1, "mouse hit boxes line up with the menu rows")
	title.index = 3
	title.activate()
	_expect(title.screen == Title.SCREEN_CONTROLS, "CONTROLS opens the controls page")
	title.move_selection(1)
	_expect(title.index == 3, "the menu does not move while a page is open")
	title.back()
	_expect(title.screen == Title.SCREEN_TITLE, "back returns to the menu")
	title.index = 4
	title.activate()
	_expect(title.screen == Title.SCREEN_CREDITS, "CREDITS opens the credits page")
	title.activate()
	_expect(title.screen == Title.SCREEN_TITLE, "enter on a page goes back")
	# CONTINUE with nothing saved does nothing
	title.index = 1
	title.activate()
	_expect(changed_to.is_empty() and not title.started, "CONTINUE without a saved chapter does nothing")
	title.index = 2
	title.activate()
	title.activate()  # a second press must not start twice
	_expect(changed_to == [Title.ARENA_SCENE], "BOSS FIGHT opens the arena exactly once: %s" % str(changed_to))
	_expect(Engine.has_meta(Title.PERSIST_META), "BOSS FIGHT turns saving on")
	Engine.remove_meta(Title.PERSIST_META)
	# NEW GAME: the village, chapter progress cleared, the record kept
	var seeded: SaveProfile = SaveProfile.new()
	seeded.victories = 4
	seeded.record_scene(&"forest", &"forest_puzzle")
	seeded.gate_open = true
	SaveStore.save(seeded, SAVE_PATH)
	title.profile = SaveStore.load_profile(SAVE_PATH)
	title.started = false
	changed_to.clear()
	_expect(title.can_continue(), "a saved chapter can be continued")
	Engine.set_meta(Title.SKIP_INTRO_META,true)
	title.index = 0
	title.activate()
	Engine.remove_meta(Title.SKIP_INTRO_META)
	_expect(changed_to == [Title.EXPLORE_SCENE], "NEW GAME opens the exploration scene: %s" % str(changed_to))
	var start: Dictionary = Engine.get_meta(Title.EXPLORE_START_META, {})
	_expect(start.get("scene", &"") == &"village_layered" and start.get("entry", &"") == &"arrival" and not bool(start.get("gate_open", true)), "NEW GAME starts at the village arrival: %s" % str(start))
	var after_new: SaveProfile = SaveStore.load_profile(SAVE_PATH)
	_expect(after_new.victories == 4 and not after_new.has_progress() and not after_new.gate_open, "NEW GAME clears the chapter progress and keeps the record")
	# CONTINUE: the saved scene and checkpoint
	seeded.record_scene(&"glade", &"glade_entrance")
	SaveStore.save(seeded, SAVE_PATH)
	title.profile = SaveStore.load_profile(SAVE_PATH)
	title.started = false
	changed_to.clear()
	title.index = 1
	title.activate()
	start = Engine.get_meta(Title.EXPLORE_START_META, {})
	_expect(changed_to == [Title.EXPLORE_SCENE] and start.get("scene", &"") == &"glade_layered" and start.get("checkpoint", &"") == &"glade_layered_entrance" and bool(start.get("gate_open", false)), "CONTINUE resumes the glade checkpoint with the gate flag: %s" % str(start))
	seeded.record_scene(&"arena", &"ruins_gate")
	SaveStore.save(seeded, SAVE_PATH)
	title.profile = SaveStore.load_profile(SAVE_PATH)
	title.started = false
	changed_to.clear()
	title.activate()
	_expect(changed_to == [Title.ARENA_SCENE], "CONTINUE in the arena opens the fight")
	Engine.remove_meta(Title.PERSIST_META)
	if Engine.has_meta(Title.EXPLORE_START_META):
		Engine.remove_meta(Title.EXPLORE_START_META)
	SaveStore.delete(SAVE_PATH)
	title.profile = SaveProfile.new()
	# every character on every page and menu line exists in the UI font (nothing falls back to a missing-glyph box)
	var strings: Array[String] = []
	strings.append_array(Title.ITEMS)
	strings.append_array(Title.CONTROL_LINES)
	strings.append_array(Title.CONTROL_FOOTER)
	strings.append_array(Title.CREDIT_LINES)
	strings.append_array(["ADVENTURE OF TOTOY", "GOLD CAN BE PARRIED. RED MUST BE DODGED.", "VICTORIES 0  DEFEATS 0  BEST 1:00.0", "SAVE RESET: NOT VALID JSON", "ESC OR ENTER: BACK", "> NEW GAME", "LANTERNFEN", "FOREST ROUTE", "STAG GLADE", "COLOSSUS RUINS", "ROOT GATE OPEN", "ROOT GATE CLOSED", "NEW BEST!", "ESC: TITLE", "R TO RESTART", "TIME 1:23.4"])
	for line: String in strings:
		for character: String in line.to_upper():
			_expect(Title.menu_font().has_char(character.unicode_at(0)), "the menu font has no glyph for '%s' in \"%s\"" % [character, line])
	# the controls page covers every binding the game uses
	var controls: String = " ".join(Title.CONTROL_LINES).to_upper()
	for needle: String in ["WASD", "LEFT CLICK", "RIGHT CLICK", "SHIFT", "SPACE", "Z X C:", "E:INTERACT", "R:", "ESC", "TAB:", "F1"]:
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
	_expect(Title.menu_font() is FontVariation and (Title.menu_font() as FontVariation).base_font is FontFile, "the menu uses Cinzel, not the fallback")
	_expect(FileAccess.file_exists("res://presentation/fonts/Cinzel.ttf") and FileAccess.get_file_as_string("res://presentation/fonts/OFL-Cinzel.txt").contains("SIL Open Font License"), "Cinzel ships with its licence")
	_expect(credits.contains("CINZEL"), "credits name Cinzel")
	_expect(Title.ui_font() is FontVariation and (Title.ui_font() as FontVariation).base_font is FontFile, "the in-game HUD still uses the pixel font")
	# the logo: a smooth sprite centred at the top, only on the menu screen
	_expect(title.logo_sprite != null and absf(title.logo_sprite.texture.get_width() * title.logo_sprite.scale.x - Title.LOGO_WIDTH) < 0.01, "the title logo is shown at its width")
	_expect(title.logo_sprite != null and absf(title.logo_sprite.position.x * 2.0 + Title.LOGO_WIDTH - 320.0) < 0.01, "and centred")
	_expect(title.logo_sprite != null and title.logo_sprite.position.y + title.logo_sprite.texture.get_height() * title.logo_sprite.scale.y < Title.MENU_TOP - 2, "and it ends above the first menu line")
	# nothing runs off the page: credit lines fit, control keys and actions stay in their columns (menu font)
	var face: Font = Title.menu_font()
	for line: String in Title.CREDIT_LINES:
		_expect(Title.text_width(line, 1, face, Title.PAGE_SIZE) <= 285.0, "credit line too wide (%d px): %s" % [int(Title.text_width(line, 1, face, Title.PAGE_SIZE)), line])
	for line: String in Title.CONTROL_LINES:
		var colon: int = line.find(":")
		_expect(Title.text_width(line.substr(0, colon), 1, face, Title.PAGE_SIZE) <= 80.0, "control key too wide: " + line)
		_expect(Title.text_width(line.substr(colon + 1), 1, face, Title.PAGE_SIZE) <= 190.0, "control action too wide: " + line)
	for line: String in Title.CONTROL_FOOTER:
		_expect(Title.text_width(line, 1, face, Title.PAGE_SIZE) <= 285.0, "controls footer too wide: " + line)
	_expect(Title.text_width("ADVENTURE OF TOTOY", 1, face, Title.FALLBACK_TITLE_SIZE) <= 300.0, "the plain-lettering title fits the screen")
	var credits_end: int = 26 + Title.CREDIT_LINES.size() * 10
	_expect(credits_end <= 164, "the credits end above the back line (end y %d)" % credits_end)
	var controls_end: int = 26 + Title.CONTROL_LINES.size() * 10 + 4 + Title.CONTROL_FOOTER.size() * 10
	_expect(controls_end <= 164, "the controls page ends above the back line (end y %d)" % controls_end)
	for item: String in Title.ITEMS:
		_expect(Title.text_width(item, 1, face, Title.MENU_SIZE) <= 100.0, "menu item fits its plate: " + item)
	# the lettering is a 320x180 layer cut to hard palette pixels; the painting and logo stay smooth
	_expect(title.text_viewport != null and title.text_viewport.size == Vector2i(320, 180) and title.text_viewport.transparent_bg, "the menu lettering has its own transparent 320x180 layer")
	_expect(title.text_display != null and title.text_display.material is ShaderMaterial, "shown through the pixel text shader")
	if title.text_display != null and title.text_display.material is ShaderMaterial:
		var material: ShaderMaterial = title.text_display.material as ShaderMaterial
		_expect(material.shader != null and material.shader.code.contains("step(0.5"), "the shader cuts the edge to fully opaque or fully transparent pixels")
		_expect(int(material.get_shader_parameter("palette_size")) == 32, "it snaps to the 32 unreserved Totoy colours")
		_expect((material.get_shader_parameter("palette") as PackedVector3Array).size() == 36, "the palette array is full length")
		_expect(title.text_display.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "and it is drawn with nearest filtering")
	_expect(title.background_sprite != null and title.background_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "the painting is not pixelated")
	# the logo matches the pixel lettering: game resolution, palette-bound, hard alpha, nearest filtering
	_expect(title.logo_pixel and title.logo_sprite != null and title.logo_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "the logo is the pixel version, drawn with nearest filtering")
	if title.logo_pixel:
		var logo_image: Image = title.logo_sprite.texture.get_image()
		_expect(logo_image.get_width() == int(Title.LOGO_WIDTH) and title.logo_sprite.scale == Vector2.ONE, "the logo is 190 game pixels wide at scale 1")
		var logo_palette: Dictionary = {}
		var logo_reserved: Array = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))["reserved"]
		for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))["colors"]:
			if not logo_reserved.has(entry["symbol"]):
				logo_palette[Color.html(entry["hex"])] = true
		var logo_stray: int = 0
		var logo_soft: int = 0
		for y: int in logo_image.get_height():
			for x: int in logo_image.get_width():
				var pixel: Color = logo_image.get_pixel(x, y)
				if pixel.a > 0.0 and pixel.a < 1.0:
					logo_soft += 1
				if pixel.a > 0.0 and not logo_palette.has(Color(pixel.r, pixel.g, pixel.b, 1.0)):
					logo_stray += 1
		_expect(logo_stray == 0 and logo_soft == 0, "the pixel logo uses only palette colours (%d stray) and no soft alpha (%d)" % [logo_stray, logo_soft])
	_expect(title.has_method("draw_text_layer") and title.text_layer != null and title.text_layer.view == title, "the lettering layer draws what the title screen says")
	# the background: the owner's painting, graded; a smooth sprite behind everything
	_expect(title.painted and title.background != null and title.background.get_size() == Vector2(1920, 1080), "the painted menu background loads at 1920x1080")
	_expect(title.background_sprite != null and title.background_sprite.show_behind_parent and absf(title.background_sprite.scale.x * 1920.0 - 320.0) < 0.01, "it fills the 320x180 canvas, behind everything")
	_expect(FileAccess.file_exists("res://art/reference/menu_background_source.jpg"), "the original painting is kept in art/reference")
	# the pixel-art fallback (composed from the game's own tiles) stays palette-bound
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
	_expect(not title.has_method("_draw_frame"), "no characters are drawn on the menu")
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
