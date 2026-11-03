extends "res://presentation/arena/hud.gd"
## Title screen: NEW GAME (chapter 1 from the village), CONTINUE (the saved scene and checkpoint), BOSS FIGHT (the
## Colossus arena directly, for testing), CONTROLS, CREDITS, QUIT. (The saved record is kept and can be shown with record_text(),
## but the menu no longer displays it.) Presentation only: it reads
## the save profile through the core's save store and starts the arena; it holds no game rules.
## The screen is the editable scene title.tscn: the painting (Background), the logo (Logo), the lettering (Labels inside
## TextViewport/Screens: the menu, the Controls page, the Credits page) and TextDisplay, which shows that lettering as hard
## palette pixels through pixel_text.gdshader. Open the scene in Godot to move or restyle anything. The words of the Controls and
## Credits pages come from CONTROL_LINES / CREDIT_LINES below; the click areas of the six menu lines are item_at(), whose numbers
## (MENU_TOP, MENU_STEP) must match the Item labels' positions in the scene.
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const SaveStore := preload("res://core/save_store.gd")
const CutsceneBook := preload("res://core/cutscene_book.gd")

const ARENA_SCENE: String = "res://presentation/arena/arena.tscn"
const INTRO_SCENE: String = "res://presentation/cutscene/intro.tscn"
const SKIP_INTRO_META: StringName = &"totoy_skip_intro"
const EXPLORE_SCENE: String = "res://presentation/explore/explore_scene.tscn"
## Read by presentation/explore/explore_scene.gd: where the chapter starts ({scene, entry, checkpoint, gate_open}).
const SceneDefs := preload("res://core/scene_defs.gd")
const EXPLORE_START_META: StringName = &"totoy_explore_start"
## While this meta is set on the Engine, the arena saves progress (smoke tests that load the arena directly do
## not set it and never touch the player's save).
const PERSIST_META: StringName = &"totoy_persist"

const MENU_TOP: int = 134  # y of the first menu line, in game pixels
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
	"INTRO MUSIC: ORIGINAL CODEX COMPOSITION",
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
	background_sprite = get_node_or_null("Background") as Sprite2D
	if background_sprite != null and background_sprite.texture != null:
		background = background_sprite.texture
		painted = true
	elif ResourceLoader.exists(BACKGROUND_PATH):
		background = load(BACKGROUND_PATH) as Texture2D
	logo_sprite = get_node_or_null("Logo") as Sprite2D
	if logo_sprite != null and logo_sprite.texture == null:
		logo_sprite = null  # no logo image: the plain-lettering title is shown instead
	if logo_sprite != null:
		logo_pixel = logo_sprite.texture.resource_path == LOGO_PIXEL_PATH
	text_viewport = $TextViewport
	text_layer = $TextViewport/TitleText
	text_layer.view = self
	text_layer.colors = colors
	text_display = $TextDisplay
	_set_pixel_palette()
	_fill_pages()
	profile = SaveStore.load_profile()
	queue_redraw()


## The lettering is cut to hard pixels in the Totoy palette (reserved gold and red excluded) by the shader on TextDisplay.
func _set_pixel_palette() -> void:
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
	var material: ShaderMaterial = text_display.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("palette", palette_vectors)
		material.set_shader_parameter("palette_size", count)


## Puts the page words (CONTROL_LINES, CONTROL_FOOTER, CREDIT_LINES) into the scene's labels; extra labels are hidden.
func _fill_pages() -> void:
	var controls: Node = text_viewport.get_node("Screens/Controls")
	for i: int in range(11):
		var key: Label = controls.get_node_or_null("Key%d" % (i + 1)) as Label
		var action: Label = controls.get_node_or_null("Action%d" % (i + 1)) as Label
		var line: String = CONTROL_LINES[i] if i < CONTROL_LINES.size() else ""
		var split: int = line.find(":")
		if key != null:
			key.visible = not line.is_empty()
			key.text = line.substr(0, split)
		if action != null:
			action.visible = not line.is_empty()
			action.text = line.substr(split + 1)
	for i: int in range(2):
		var footer: Label = controls.get_node_or_null("Footer%d" % (i + 1)) as Label
		if footer != null:
			footer.visible = i < CONTROL_FOOTER.size()
			footer.text = CONTROL_FOOTER[i] if i < CONTROL_FOOTER.size() else ""
	var credits: Node = text_viewport.get_node("Screens/Credits")
	for i: int in range(13):
		var label: Label = credits.get_node_or_null("Line%d" % (i + 1)) as Label
		if label != null:
			label.visible = i < CREDIT_LINES.size()
			label.text = CREDIT_LINES[i] if i < CREDIT_LINES.size() else ""


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


## NEW GAME: the story intro, then village arrival. Explicit debug/test bypass goes straight to arrival.
## The chapter progress in the save is cleared (the fight record and the
## loadout stay).
func new_game() -> void:
	if started:
		return
	var bypass_intro: bool = "--skip-intro" in OS.get_cmdline_user_args() or bool(Engine.get_meta(SKIP_INTRO_META,false)) or Engine.has_meta(EXPLORE_START_META)
	started = true
	Engine.set_meta(PERSIST_META, true)
	if profile == null:
		profile = SaveStore.load_profile()
	profile.reset_progress()
	if bypass_intro:
		var flag: StringName = CutsceneBook.flag_of(CutsceneBook.default_book(),CutsceneBook.INTRO)
		if flag != &"" and not profile.story_flags.has(flag):profile.story_flags.append(flag)
	SaveStore.save(profile)
	Engine.set_meta(EXPLORE_START_META, {"scene": SceneDefs.START_SCENE, "entry": SceneDefs.START_ENTRY, "checkpoint": &"", "gate_open": false})
	change_scene.call(EXPLORE_SCENE if bypass_intro else INTRO_SCENE)


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
		if Rect2(132, MENU_TOP + i * MENU_STEP - 2, 120, MENU_STEP - 1).has_point(point):
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


## Called every frame by the lettering layer (title_text.gd): shows the current screen's labels and moves the selection plate.
func draw_text_layer(_canvas: Object) -> void:
	var screens: Node = text_viewport.get_node("Screens")
	screens.get_node("Title").visible = screen == SCREEN_TITLE
	screens.get_node("Controls").visible = screen == SCREEN_CONTROLS
	screens.get_node("Credits").visible = screen == SCREEN_CREDITS
	if screen != SCREEN_TITLE:
		return
	var menu: Node = screens.get_node("Title")
	for i: int in ITEMS.size():
		var label: Label = menu.get_node_or_null("Item%d" % (i + 1)) as Label
		if label == null:
			continue
		var selected: bool = i == index
		label.text = ITEMS[i]
		var tone: Color = colors["1"] if selected else colors["p"]
		if ITEMS[i] == "CONTINUE" and not can_continue():
			tone = colors["h"]  # nothing saved to continue
		label.add_theme_color_override("font_color", tone)
		if selected:
			# an opaque dark plate behind the chosen item with a cream line under it (the layer is hard pixels:
			# translucent fills would be cut away)
			var y: float = MENU_TOP + i * MENU_STEP
			menu.get_node("Plate").position = Vector2(128, y - 3)
			menu.get_node("PlateLine").position = Vector2(128, y - 3 + MENU_STEP - 2)
			var arrow: Control = menu.get_node("Arrow")
			arrow.position = Vector2(arrow.position.x, label.position.y)
	var note: String = String(profile.load_note) if profile != null else ""
	var note_label: Label = menu.get_node_or_null("SaveNote") as Label
	if note_label != null:
		note_label.text = ("SAVE RESET: " + note) if note != "" else ""
	var fallback: Control = menu.get_node_or_null("FallbackTitle") as Control
	if fallback != null:
		fallback.visible = logo_sprite == null


## The dusk arena picture (made from the game's own tiles and props), drifting mist and fireflies. On the pages
## (controls, credits) the picture is dimmed so the lettering reads.
func _draw_background() -> void:
	if background == null:
		draw_rect(Rect2(0, 0, 384, 216), colors["2"])
	elif not painted:
		draw_texture_rect(background, Rect2(0, 0, 384, 216), false)
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
		var home: Vector2 = Vector2(rnd.randf_range(14.0, 370.0), rnd.randf_range(70.0, 206.0))
		var rate: Vector2 = Vector2(rnd.randf_range(0.25, 0.6), rnd.randf_range(0.2, 0.5))
		var phase: float = rnd.randf_range(0.0, TAU)
		var at: Vector2 = home + Vector2(sin(time * rate.x + phase) * 9.0, cos(time * rate.y + phase * 1.3) * 5.0)
		var pulse: float = 0.5 + 0.5 * sin(time * 1.6 + phase * 2.0)
		var dot: Vector2 = Vector2(floorf(at.x), floorf(at.y))
		draw_rect(Rect2(dot - Vector2(1, 0), Vector2(3, 1)), Color(colors["1"], 0.18 * pulse))
		draw_rect(Rect2(dot - Vector2(0, 1), Vector2(1, 3)), Color(colors["1"], 0.18 * pulse))
		draw_rect(Rect2(dot, Vector2(1, 1)), Color(colors["p"], 0.55 + 0.45 * pulse))
	if screen != SCREEN_TITLE:
		draw_rect(Rect2(0, 0, 384, 216), Color(colors["0"], 0.74))
