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

const MENU_TOP: int = 82  # y of the first menu line, in game pixels
const MENU_STEP: int = 16
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
	"ADVENTURE OF TOTOY",
	"GAME DESIGN AND ART DIRECTION: THE OWNER",
	"HERO REFERENCE ART: THE OWNER",
	"SPRITES AND TILES: GENERATED WITH GEMINI",
	"FROM THE OWNER'S DESIGNS",
	"BUILT WITH GODOT 4, CLAUDE CODE AND CODEX",
	"",
	"SOUND AND MUSIC (CC0):",
	"STARNINJAS, ARTISTICDUDE, KENNEY,",
	"BRIAN MACINTOSH (BMACZERO), MINTODOG",
	"FONT: PIXELIFY SANS (SIL OFL 1.1),",
	"THE PIXELIFY SANS PROJECT AUTHORS",
	"LICENCES: PRESENTATION/AUDIO/LICENSES",
	"AND PRESENTATION/FONTS",
]

var screen: StringName = SCREEN_TITLE
var index: int = 0
var profile: Object = null
var started: bool = false
var sprite_frames: Dictionary = {}
var sprite_texture: Texture2D
## Replaced by tests so choosing START does not leave the scene they run in.
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)


func _ready() -> void:
	Bindings.register()
	var palette: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))
	for entry: Dictionary in (palette as Dictionary).get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	var atlas: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))
	sprite_frames = (atlas as Dictionary).get("frames", {})
	sprite_texture = load("res://art/build/sprites.png") as Texture2D
	profile = SaveStore.load_profile()
	queue_redraw()


func _process(_delta: float) -> void:
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
	draw_rect(Rect2(0, 0, 320, 180), colors["2"])
	for stripe: int in range(0, 180, 4):
		draw_rect(Rect2(0, stripe, 320, 2), Color(0, 0, 0, 0.12))
	match screen:
		SCREEN_CONTROLS:
			_draw_page("CONTROLS", CONTROL_LINES, CONTROL_FOOTER)
		SCREEN_CREDITS:
			_draw_page("CREDITS", CREDIT_LINES, [])
		_:
			_draw_title()


func _draw_title() -> void:
	_draw_frame("hero2_idle_right_1", Vector2(70, 150))
	_draw_frame("golem2_idle_1", Vector2(250, 150))
	var title: String = "ADVENTURE OF TOTOY"
	centered(160, 22, title, colors["1"], colors["0"], 3)
	var tagline: String = "GOLD CAN BE PARRIED. RED MUST BE DODGED."
	centered(160, 50, tagline, colors["o"], colors["0"])
	for i: int in ITEMS.size():
		var selected: bool = i == index
		var y: float = MENU_TOP + i * MENU_STEP
		if selected:
			draw_rect(Rect2(100, y - 3, 120, MENU_STEP - 2), Color(colors["1"], 0.14))
			outlined(Vector2(104, y), ">", colors["1"], colors["0"], 2)
		centered(160, y, ITEMS[i], colors["1"] if selected else colors["p"], colors["0"], 2)
	var record: String = record_text()
	if record != "":
		centered(160, 158, record, colors["p"], colors["0"], 1, stat_font())
	var note: String = String(profile.load_note) if profile != null else ""
	if note != "":
		centered(160, 168, "SAVE RESET: " + note, colors["o"], colors["0"])


func _draw_page(heading: String, lines: Array[String], footer: Array[String]) -> void:
	centered(160, 8, heading, colors["1"], colors["0"], 3)
	var y: int = 36
	for line: String in lines:
		var split: int = line.find(":")
		if split > 0 and lines == CONTROL_LINES:
			outlined(Vector2(20, y), line.substr(0, split), colors["1"], colors["0"], 1, stat_font())
			outlined(Vector2(74, y), line.substr(split + 1), colors["p"], colors["0"])
		else:
			outlined(Vector2(20, y), line, colors["p"], colors["0"])
		y += 9
	y += 6
	for line: String in footer:
		outlined(Vector2(20, y), line, colors["o"], colors["0"])
		y += 9
	outlined(Vector2(20, 168), "ESC OR ENTER: BACK", colors["1"], colors["0"])


func _draw_frame(key: String, at: Vector2) -> void:
	if not sprite_frames.has(key) or sprite_texture == null:
		return
	var frame: Dictionary = sprite_frames[key]
	var anchor: Vector2 = Vector2(frame.get("ax", float(frame["w"]) / 2), frame.get("ay", float(frame["h"])))
	draw_texture_rect_region(sprite_texture, Rect2((at - anchor).round(), Vector2(frame["w"], frame["h"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
