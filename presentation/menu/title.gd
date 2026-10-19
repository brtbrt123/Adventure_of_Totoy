extends "res://presentation/arena/hud.gd"
## Title screen: START, CONTROLS, CREDITS, QUIT, with the saved record underneath. Presentation only: it reads
## the save profile through the core's save store and starts the arena; it holds no game rules. It reuses the
## HUD's 3x5 bitmap lettering and draws on the 320x180 canvas.
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const SaveStore := preload("res://core/save_store.gd")

const ARENA_SCENE: String = "res://presentation/arena/arena.tscn"
## While this meta is set on the Engine, the arena saves progress (smoke tests that load the arena directly do
## not set it and never touch the player's save).
const PERSIST_META: StringName = &"totoy_persist"

const MENU_TOP: int = 103  # y of the first menu line, in game pixels
const MENU_STEP: int = 14
const MENU_SIZE: int = 12  # menu item font size (Cinzel capitals)
const PAGE_SIZE: int = 8  # body text on the controls and credits pages
const FALLBACK_TITLE_SIZE: int = 15  # the plain-lettering title used when the logo image is missing
const LOGO_PATH: String = "res://presentation/menu/title_logo.png"
const LOGO_WIDTH: float = 190.0  # game pixels (the logo is 1800 px wide, drawn smooth)
var logo_sprite: Sprite2D
const ITEMS: Array[String] = ["START", "CONTROLS", "CREDITS", "QUIT"]
const SCREEN_TITLE: StringName = &"title"
const SCREEN_CONTROLS: StringName = &"controls"
const SCREEN_CREDITS: StringName = &"credits"

const CONTROL_LINES: Array[String] = [
	"WASD:MOVE",
	"LEFT CLICK:ATTACK (3 HIT COMBO)",
	"RIGHT CLICK:BLACK KATANA BUFF",
	"SHIFT:DASH",
	"SPACE:PARRY GOLD ATTACKS",
	"Z:BREAKING EDGE AFTER A PARRY",
	"X:GALE CUT",
	"C:MOON CLEAVE",
	"R:RESTART",
	"F1:DEBUG",
	"ESC:BACK",
]
const CONTROL_FOOTER: Array[String] = [
	"GOLD ATTACKS CAN BE PARRIED.",
	"RED ATTACKS MUST BE DODGED.",
]
const CREDIT_LINES: Array[String] = [
	"GAME DESIGN AND ART DIRECTION: THE OWNER",
	"HERO REFERENCE ART: THE OWNER",
	"MENU PAINTING: SUPPLIED BY THE OWNER",
	"SPRITES AND TILES: GENERATED WITH GEMINI",
	"FROM THE OWNER'S DESIGNS",
	"BUILT WITH GODOT 4, CLAUDE CODE AND CODEX",
	"",
	"SOUND AND MUSIC (CC0):",
	"STARNINJAS, ARTISTICDUDE, KENNEY,",
	"BRIAN MACINTOSH (BMACZERO), MINTODOG",
	"FONTS (SIL OFL 1.1): CINZEL AND PIXELIFY SANS,",
	"BY THE CINZEL AND PIXELIFY SANS PROJECT AUTHORS",
	"LICENCES: PRESENTATION/AUDIO/LICENSES",
	"AND PRESENTATION/FONTS",
]

var screen: StringName = SCREEN_TITLE
var index: int = 0
var profile: Object = null
var started: bool = false
var background: Texture2D
## Seconds since the menu opened; drives the drifting mist and the fireflies.
var time: float = 0.0
## The owner's painted scene, graded to dusk by tools/art/grade_menu_background.py (1920x1080). It is shown by a
## smooth-filtered sprite behind everything. If it is missing the pixel-art arena (menu_background.png, composed
## from the game's own tiles by tools/art/make_menu_background.py) is drawn instead.
const PAINTED_PATH: String = "res://presentation/menu/menu_background.jpg"
const BACKGROUND_PATH: String = "res://presentation/menu/menu_background.png"
var painted: bool = false
var background_sprite: Sprite2D
const FIREFLIES: int = 14
## Replaced by tests so choosing START does not leave the scene they run in.
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)


func _ready() -> void:
	Bindings.register()
	var palette: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))
	for entry: Dictionary in (palette as Dictionary).get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	if ResourceLoader.exists(PAINTED_PATH):
		background = load(PAINTED_PATH) as Texture2D
		painted = true
		background_sprite = Sprite2D.new()
		background_sprite.texture = background
		background_sprite.centered = false
		background_sprite.scale = Vector2(320.0, 180.0) / background.get_size()
		background_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background_sprite.show_behind_parent = true
		add_child(background_sprite)
	elif ResourceLoader.exists(BACKGROUND_PATH):
		background = load(BACKGROUND_PATH) as Texture2D
	if ResourceLoader.exists(LOGO_PATH):
		var logo: Texture2D = load(LOGO_PATH) as Texture2D
		logo_sprite = Sprite2D.new()
		logo_sprite.texture = logo
		logo_sprite.centered = false
		logo_sprite.scale = Vector2.ONE * (LOGO_WIDTH / logo.get_width())
		logo_sprite.position = Vector2((320.0 - LOGO_WIDTH) * 0.5, 2.0)
		logo_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		logo_sprite.show_behind_parent = true
		add_child(logo_sprite)
	profile = SaveStore.load_profile()
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	if logo_sprite != null:
		logo_sprite.visible = screen == SCREEN_TITLE
	queue_redraw()  # the background is alive: mist and fireflies
	if Input.is_action_just_pressed("menu_up"):
		move_selection(-1)
	if Input.is_action_just_pressed("menu_down"):
		move_selection(1)
	if Input.is_action_just_pressed("menu_accept"):
		activate()
	if Input.is_action_just_pressed("menu_back"):
		back()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and screen == SCREEN_TITLE:
		var hit: int = item_at(get_local_mouse_position())
		if hit >= 0:
			index = hit
			activate()


func move_selection(step: int) -> void:
	if screen != SCREEN_TITLE:
		return
	index = posmod(index + step, ITEMS.size())
	queue_redraw()


func activate() -> void:
	if screen != SCREEN_TITLE:
		back()
		return
	match ITEMS[index]:
		"START":
			start_game()
		"CONTROLS":
			screen = SCREEN_CONTROLS
		"CREDITS":
			screen = SCREEN_CREDITS
		"QUIT":
			get_tree().quit()
	queue_redraw()


func back() -> void:
	if screen != SCREEN_TITLE:
		screen = SCREEN_TITLE
		queue_redraw()


func start_game() -> void:
	if started:
		return
	started = true
	Engine.set_meta(PERSIST_META, true)
	change_scene.call(ARENA_SCENE)


## The menu line under a canvas point, or -1.
func item_at(point: Vector2) -> int:
	for i: int in ITEMS.size():
		if Rect2(100, MENU_TOP + i * MENU_STEP - 2, 120, MENU_STEP - 1).has_point(point):
			return i
	return -1


func record_text() -> String:
	if profile == null:
		return ""
	var text: String = "VICTORIES %d  DEFEATS %d" % [profile.victories, profile.defeats]
	if profile.best_victory_ticks > 0:
		text += "  BEST %s" % format_ticks(profile.best_victory_ticks)
	return text


func _draw() -> void:
	if colors.is_empty():
		return
	_draw_background()
	match screen:
		SCREEN_CONTROLS:
			_draw_page("CONTROLS", CONTROL_LINES, CONTROL_FOOTER)
		SCREEN_CREDITS:
			_draw_page("CREDITS", CREDIT_LINES, [])
		_:
			_draw_title()


## The dusk arena picture (made from the game's own tiles and props), drifting mist and fireflies. On the pages
## (controls, credits) the picture is dimmed so the lettering reads.
func _draw_background() -> void:
	if background == null:
		draw_rect(Rect2(0, 0, 320, 180), colors["2"])
	elif not painted:
		draw_texture_rect(background, Rect2(0, 0, 320, 180), false)
	# mist: thin pale bands that drift sideways at different speeds (pixel rows; only over the pixel-art fallback)
	var mist: Color = colors["p"]
	for band: int in (0 if painted else 6):
		var y: float = 58.0 + band * 21.0
		var speed: float = (6.0 + band * 2.5) * (1.0 if band % 2 == 0 else -1.0)
		for piece: int in 4:
			var x: float = fposmod(piece * 90.0 + time * speed + band * 37.0, 400.0) - 60.0
			var length: float = 40.0 + 24.0 * sin(time * 0.3 + band + piece)
			var alpha: float = 0.05 + 0.025 * sin(time * 0.5 + band * 1.7 + piece)
			draw_rect(Rect2(floorf(x), floorf(y + 2.0 * sin(time * 0.4 + piece)), length, 1.0), Color(mist, alpha))
			draw_rect(Rect2(floorf(x) + 6.0, floorf(y + 2.0 * sin(time * 0.4 + piece)) + 1.0, length * 0.6, 1.0), Color(mist, alpha * 0.7))
	# fireflies: tiny pale lights wandering over the arena, pulsing
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 77
	for i: int in FIREFLIES:
		var home: Vector2 = Vector2(rnd.randf_range(14.0, 306.0), rnd.randf_range(60.0, 172.0))
		var rate: Vector2 = Vector2(rnd.randf_range(0.25, 0.6), rnd.randf_range(0.2, 0.5))
		var phase: float = rnd.randf_range(0.0, TAU)
		var at: Vector2 = home + Vector2(sin(time * rate.x + phase) * 9.0, cos(time * rate.y + phase * 1.3) * 5.0)
		var pulse: float = 0.5 + 0.5 * sin(time * 1.6 + phase * 2.0)
		var dot: Vector2 = Vector2(floorf(at.x), floorf(at.y))
		draw_rect(Rect2(dot - Vector2(1, 0), Vector2(3, 1)), Color(colors["1"], 0.18 * pulse))
		draw_rect(Rect2(dot - Vector2(0, 1), Vector2(1, 3)), Color(colors["1"], 0.18 * pulse))
		draw_rect(Rect2(dot, Vector2(1, 1)), Color(colors["p"], 0.55 + 0.45 * pulse))
	if screen != SCREEN_TITLE:
		draw_rect(Rect2(0, 0, 320, 180), Color(colors["0"], 0.74))


func _draw_title() -> void:
	if logo_sprite == null:  # without the logo image the title is plain lettering
		centered(160, 30, "ADVENTURE OF TOTOY", colors["1"], colors["0"], 1, menu_font(), FALLBACK_TITLE_SIZE)
	var face: Font = menu_font()
	for i: int in ITEMS.size():
		var selected: bool = i == index
		var y: float = MENU_TOP + i * MENU_STEP
		if selected:
			# a soft violet plate behind the chosen item with a thin cream line under it
			draw_rect(Rect2(96, y - 3, 128, MENU_STEP - 1), Color(colors["v"], 0.30))
			draw_rect(Rect2(96, y - 3 + MENU_STEP - 2, 128, 1), Color(colors["1"], 0.55))
			outlined(Vector2(100, y), ">", colors["1"], colors["0"], 1, face, MENU_SIZE)
		centered(160, y, ITEMS[i], colors["1"] if selected else colors["j"], colors["0"], 1, face, MENU_SIZE)
	var record: String = record_text()
	if record != "":
		centered(160, 167, record, colors["j"], colors["0"], 1, face, 8)
	var note: String = String(profile.load_note) if profile != null else ""
	if note != "":
		centered(160, 175, "SAVE RESET: " + note, colors["o"], colors["0"], 1, face, 8)


func _draw_page(heading: String, lines: Array[String], footer: Array[String]) -> void:
	var face: Font = menu_font()
	centered(160, 4, heading, colors["1"], colors["0"], 1, face, 20)
	var y: int = 26
	for line: String in lines:
		var split: int = line.find(":")
		if split > 0 and lines == CONTROL_LINES:
			outlined(Vector2(20, y), line.substr(0, split), colors["1"], colors["0"], 1, face, PAGE_SIZE)
			outlined(Vector2(88, y), line.substr(split + 1), colors["j"], colors["0"], 1, face, PAGE_SIZE)
		else:
			outlined(Vector2(20, y), line, colors["j"], colors["0"], 1, face, PAGE_SIZE)
		y += 9
	y += 4
	for line: String in footer:
		outlined(Vector2(20, y), line, colors["o"], colors["0"], 1, face, PAGE_SIZE)
		y += 9
	outlined(Vector2(20, 168), "ESC OR ENTER: BACK", colors["1"], colors["0"], 1, face, PAGE_SIZE)
