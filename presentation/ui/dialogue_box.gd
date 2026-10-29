extends Control
## The conversation box and the first-visit controls card as a Godot scene (dialogue_box.tscn). Open the scene in the editor
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
@onready var controls: Control = $Controls
@onready var controls_hint: Label = $Controls/Hint


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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


## The first-visit card: shown while `open`; `hint` is its key line.
func show_controls(open: bool, hint: String = "") -> void:
	controls.visible = open
	controls_hint.text = hint
