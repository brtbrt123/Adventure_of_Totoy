extends "res://presentation/arena/hud.gd"
## Title screen: NEW GAME (chapter 1 from the village), CONTINUE (the saved scene and checkpoint), BOSS FIGHT (the
## Colossus arena directly, for testing), CONTROLS, CREDITS, QUIT. (The saved record is kept and can be shown with record_text(),
## but the menu no longer displays it.) Presentation only: it reads
## the save profile through the core's save store and starts the arena; it holds no game rules. It reuses the
## HUD's 3x5 bitmap lettering and draws on the 320x180 canvas.
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const SaveStore := preload("res://core/save_store.gd")

const ARENA_SCENE: String = "res://presentation/arena/arena.tscn"
const EXPLORE_SCENE: String = "res://presentation/explore/explore_scene.tscn"
## Read by presentation/explore/explore_scene.gd: where the chapter starts ({scene, entry, checkpoint, gate_open}).
const EXPLORE_START_META: StringName = &"totoy_explore_start"
## While this meta is set on the Engine, the arena saves progress (smoke tests that load the arena directly do
## not set it and never touch the player's save).
const PERSIST_META: StringName = &"totoy_persist"

const MENU_TOP: int = 103  # y of the first menu line, in game pixels
const MENU_STEP: int = 12
const MENU_SIZE: int = 13  # menu item font size (Cinzel capitals)
const PAGE_SIZE: int = 10  # body text on the controls and credits pages
const FALLBACK_TITLE_SIZE: int = 15  # the plain-lettering title used when the logo image is missing
const PIXEL_TEXT_SHADER: String = "res://presentation/menu/pixel_text.gdshader"
const TitleText := preload("res://presentation/menu/title_text.gd")
## The lettering is drawn into a 320x180 layer and shown as hard palette pixels (pixel_text.gdshader) over the
## smooth painting and logo.
var text_viewport: SubViewport
var text_layer: Node2D
var text_display: Sprite2D
## The logo at game resolution (title_logo_pixel.png, palette-bound, to match the pixel lettering); the smooth
## 1800 px drawing (title_logo.png) is the fallback.
const LOGO_PIXEL_PATH: String = "res://presentation/menu/title_logo_pixel.png"
const LOGO_PATH: String = "res://presentation/menu/title_logo.png"
const LOGO_WIDTH: float = 190.0  # game pixels (the logo is 1800 px wide, drawn smooth)
var logo_sprite: Sprite2D
var logo_pixel: bool = false
const ITEMS: Array[String] = ["NEW GAME", "CONTINUE", "BOSS FIGHT", "CONTROLS", "CREDITS", "QUIT"]
const SCREEN_TITLE: StringName = &"title"
const SCREEN_CONTROLS: StringName = &"controls"
const SCREEN_CREDITS: StringName = &"credits"

const CONTROL_LINES: Array[String] = [
	"WASD:MOVE",
	"LEFT CLICK:ATTACK (COMBO)",
	"RIGHT CLICK:WEAPON ACTIVE",
	"SHIFT:DASH",
	"SPACE:PARRY GOLD ATTACKS",
	"Z X C:ASPECTS IN SLOTS 1-3",
	"E:INTERACT / TALK",
	"TAB:MENU (WEAPONS, ASPECTS)",
	"R:RESTART THE FIGHT",
	"H/F1:DEBUG  1-4:JUMP  G:GATE",
	"ESC:BACK / TITLE",
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
	"FONTS (SIL OFL 1.1): CINZEL, PIXELIFY SANS",
	"BY THEIR PROJECT AUTHORS",
	"LICENCES: PRESENTATION/AUDIO, /FONTS",
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
	var logo_path: String = LOGO_PIXEL_PATH if ResourceLoader.exists(LOGO_PIXEL_PATH) else LOGO_PATH
	if ResourceLoader.exists(logo_path):
		var logo: Texture2D = load(logo_path) as Texture2D
		logo_pixel = logo_path == LOGO_PIXEL_PATH
		logo_sprite = Sprite2D.new()
		logo_sprite.texture = logo
		logo_sprite.centered = false
		logo_sprite.scale = Vector2.ONE * (LOGO_WIDTH / logo.get_width())
		logo_sprite.position = Vector2(floorf((320.0 - LOGO_WIDTH) * 0.5), 2.0)
		logo_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if logo_pixel else CanvasItem.TEXTURE_FILTER_LINEAR
		logo_sprite.show_behind_parent = true
		add_child(logo_sprite)
	_add_text_layer()
	profile = SaveStore.load_profile()
	queue_redraw()


## The menu lettering: drawn at game resolution in its own transparent viewport, then cut to hard pixels in the
## Totoy palette, so the text looks like pixel art while the painting behind it stays smooth.
func _add_text_layer() -> void:
	var palette_vectors: PackedVector3Array = PackedVector3Array()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))
	var reserved: Array = (data as Dictionary).get("reserved", [])
	for entry: Dictionary in (data as Dictionary).get("colors", []):
		if not reserved.has(entry["symbol"]):
			var tone: Color = Color.html(entry["hex"])
			palette_vectors.append(Vector3(tone.r, tone.g, tone.b))
	var count: int = palette_vectors.size()
	while palette_vectors.size() < 36:
		palette_vectors.append(palette_vectors[count - 1])
	text_viewport = SubViewport.new()
	text_viewport.size = Vector2i(320, 180)
	text_viewport.transparent_bg = true
	text_viewport.disable_3d = true
	text_viewport.gui_disable_input = true
	text_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	text_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	text_layer = TitleText.new()
	text_layer.view = self
	text_layer.colors = colors
	text_viewport.add_child(text_layer)
	add_child(text_viewport)
	text_display = Sprite2D.new()
	text_display.texture = text_viewport.get_texture()
	text_display.centered = false
	text_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PIXEL_TEXT_SHADER):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = load(PIXEL_TEXT_SHADER) as Shader
		material.set_shader_parameter("palette", palette_vectors)
		material.set_shader_parameter("palette_size", count)
		text_display.material = material
	add_child(text_display)


func _process(delta: float) -> void:
	time += delta
	if text_layer != null:
		text_layer.queue_redraw()
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
		"NEW GAME":
			new_game()
		"CONTINUE":
			continue_game()
		"BOSS FIGHT":
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


## BOSS FIGHT: the Colossus arena directly (for testing; the fight saves its record as before).
func start_game() -> void:
	if started:
		return
	started = true
	Engine.set_meta(PERSIST_META, true)
	change_scene.call(ARENA_SCENE)


## NEW GAME: chapter 1 from the village arrival. The chapter progress in the save is cleared (the fight record and the
## loadout stay).
func new_game() -> void:
	if started:
		return
	started = true
	Engine.set_meta(PERSIST_META, true)
	if profile == null:
		profile = SaveStore.load_profile()
	profile.reset_progress()
	SaveStore.save(profile)
	Engine.set_meta(EXPLORE_START_META, {"scene": &"village", "entry": &"arrival", "checkpoint": &"", "gate_open": false})
	change_scene.call(EXPLORE_SCENE)


## True when the save has a chapter game to resume.
func can_continue() -> bool:
	return profile != null and profile.has_progress()


## CONTINUE: the saved scene at its last checkpoint (the arena: the Colossus fight). Nothing without progress.
func continue_game() -> void:
	if started or not can_continue():
		return
	started = true
	Engine.set_meta(PERSIST_META, true)
	if profile.scene_id == &"arena":
		change_scene.call(ARENA_SCENE)
		return
	Engine.set_meta(EXPLORE_START_META, {"scene": profile.scene_id, "entry": &"", "checkpoint": profile.checkpoint_id, "gate_open": profile.gate_open})
	change_scene.call(EXPLORE_SCENE)


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


## Called by the lettering layer (title_text.gd) to draw the current screen's text onto `canvas`.
func draw_text_layer(canvas: Object) -> void:
	match screen:
		SCREEN_CONTROLS:
			_draw_page(canvas, "CONTROLS", CONTROL_LINES, CONTROL_FOOTER)
		SCREEN_CREDITS:
			_draw_page(canvas, "CREDITS", CREDIT_LINES, [])
		_:
			_draw_title(canvas)


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


func _draw_title(canvas: Object) -> void:
	if logo_sprite == null:  # without the logo image the title is plain lettering
		canvas.centered(160, 30, "ADVENTURE OF TOTOY", colors["1"], colors["0"], 1, canvas.menu_font(), FALLBACK_TITLE_SIZE)
	var face: Font = canvas.menu_font()
	for i: int in ITEMS.size():
		var selected: bool = i == index
		var y: float = MENU_TOP + i * MENU_STEP
		if selected:
			# an opaque dark plate behind the chosen item with a cream line under it (the layer is hard pixels:
			# translucent fills would be cut away)
			canvas.draw_rect(Rect2(96, y - 3, 128, MENU_STEP - 1), colors["k"])
			canvas.draw_rect(Rect2(96, y - 3 + MENU_STEP - 2, 128, 1), colors["1"])
			canvas.outlined(Vector2(100, y), ">", colors["1"], colors["0"], 1, face, MENU_SIZE)
		var tone: Color = colors["1"] if selected else colors["p"]
		if ITEMS[i] == "CONTINUE" and not can_continue():
			tone = colors["h"]  # nothing saved to continue
		canvas.centered(160, y, ITEMS[i], tone, colors["0"], 1, face, MENU_SIZE)
	var note: String = String(profile.load_note) if profile != null else ""
	if note != "":
		canvas.centered(160, 175, "SAVE RESET: " + note, colors["o"], colors["0"], 1, face, 8)


func _draw_page(canvas: Object, heading: String, lines: Array[String], footer: Array[String]) -> void:
	var face: Font = canvas.menu_font()
	canvas.centered(160, 4, heading, colors["1"], colors["0"], 1, face, 20)
	var y: int = 26
	for line: String in lines:
		var split: int = line.find(":")
		if split > 0 and lines == CONTROL_LINES:
			canvas.outlined(Vector2(20, y), line.substr(0, split), colors["1"], colors["0"], 1, face, PAGE_SIZE)
			canvas.outlined(Vector2(104, y), line.substr(split + 1), colors["j"], colors["0"], 1, face, PAGE_SIZE)
		else:
			canvas.outlined(Vector2(20, y), line, colors["j"], colors["0"], 1, face, PAGE_SIZE)
		y += 10
	y += 4
	for line: String in footer:
		canvas.outlined(Vector2(20, y), line, colors["o"], colors["0"], 1, face, PAGE_SIZE)
		y += 10
	canvas.outlined(Vector2(20, 168), "ESC OR ENTER: BACK", colors["1"], colors["0"], 1, face, PAGE_SIZE)
