@tool
extends Control
## The conversation box as a Godot scene (dialogue_box.tscn; the welcome card is its own scene, welcome_card.tscn). Open the scene in the editor
## to move, resize or re-texture anything; this script only fills in the words. It draws nothing and holds no rules:
## conversation_view.gd decides what is shown (the typed-out text, the speaker, the hints) and hands it to show_line().

@export var portrait_sheet: Texture2D
var portrait_frames: Dictionary = {}
var _portraits: Dictionary = {}

@onready var line_box: Control = $Dialogue
@onready var portrait: TextureRect = $Dialogue/Portrait
@onready var ribbon: NinePatchRect = $Dialogue/Ribbon
@onready var speaker: Label = $Dialogue/Ribbon/Speaker
@onready var text: Label = $Dialogue/Text
@onready var hint_next: Label = $Dialogue/HintNext
@onready var hint_skip: Label = $Dialogue/HintSkip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		# in the editor both parts are shown with a sample line, so you can see and move everything
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/reference/chapter1_characters_v2/portraits_v2.json"))
		portrait_frames = (data as Dictionary).get("frames", {}) if data is Dictionary else {}
		show_line({"speaker": "Tovan", "portrait": "tovan", "shown_text": "Hold out your hands, Totoy. This is a Black Katana,\nand it is yours. It was always yours.", "next_hint": "E / Enter: Next", "skip_hint": "Escape: skip"})
	else:
		# in the game they stay hidden until conversation_view.gd shows them
		line_box.visible = false


func _portrait_texture(key: String) -> Texture2D:
	if not _portraits.has(key):
		var texture: AtlasTexture = null
		if portrait_sheet != null and portrait_frames.has(key):
			var f: Dictionary = portrait_frames[key]
			texture = AtlasTexture.new()
			texture.atlas = portrait_sheet
			texture.region = Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"]))
		_portraits[key] = texture
	return _portraits[key]


## Hides the box (an empty `line`) or shows one conversation line.
## line: {speaker, portrait, shown_text (already typed-out, with line breaks), next_hint, skip_hint}
func show_line(line: Dictionary) -> void:
	line_box.visible = not line.is_empty()
	if line.is_empty():
		return
	portrait.texture = _portrait_texture("portrait_%s_neutral" % String(line.get("portrait", "")))
	var name: String = String(line.get("speaker", "")).to_upper()
	speaker.text = name
	var font: Font = speaker.get_theme_font("font")
	var width: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, speaker.get_theme_font_size("font_size")).x
	ribbon.size.x = ceilf(width) + 56.0
	speaker.position.x = 0.0
	speaker.size.x = ribbon.size.x
	text.text = String(line.get("shown_text", ""))
	hint_next.text = String(line.get("next_hint", ""))
	hint_skip.text = String(line.get("skip_hint", ""))

