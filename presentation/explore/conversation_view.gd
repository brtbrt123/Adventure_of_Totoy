extends "res://presentation/arena/hud.gd"
## Snapshot text only; reveal and consume presses here, conversation rules stay in core. The box itself is the editable
## scene presentation/ui/dialogue_box.tscn (open it in Godot to move or re-texture anything); this script types the text
## out and hands the scene the words.
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const DialogueBox := preload("res://presentation/ui/dialogue_box.tscn")
const TEXT_WIDTH: float = 280.0
const CHARACTERS_PER_SECOND: float = 38.0
var dialogue: Dictionary = {}
var reveal: float = 0.0
## The first-visit welcome card (explore_scene.gd sets it).
var controls_open: bool = false:
	set(value):
		controls_open = value
		_refresh()
var portrait_frames: Dictionary = {}
var portrait_sheet: Texture2D
var box: Control = null
var _line_key: String = ""
var blip: Callable = Callable()
var typed_nonspaces: int = 0


func _ready() -> void:
	portrait_sheet = load("res://art/reference/chapter1_characters_v2/portraits_v2.png") as Texture2D
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/reference/chapter1_characters_v2/portraits_v2.json")) as Dictionary
	portrait_frames = data.get("frames", {})
	box = DialogueBox.instantiate()
	box.portrait_sheet = portrait_sheet
	box.portrait_frames = portrait_frames
	add_child(box)
	_refresh()


func sync(value: Dictionary) -> void:
	var key: String = "%s/%s/%s" % [value.get("dialogue_id", ""), value.get("index", -1), value.get("text", "")]
	if key != _line_key:
		reveal = 0.0
		typed_nonspaces = 0
		_line_key = key
	dialogue = value.duplicate()
	_refresh()


func tick() -> void:
	var before: int = int(reveal)
	reveal = minf(reveal + CHARACTERS_PER_SECOND / 60.0, full_text().length())
	for i: int in range(before, int(reveal)):
		if not full_text().substr(i, 1).strip_edges().is_empty():
			typed_nonspaces += 1
			if typed_nonspaces % 3 == 0 and blip.is_valid():
				blip.call()
	_refresh()


func full_text() -> String:
	return String(dialogue.get("text", ""))


func complete() -> bool:
	return int(reveal) >= full_text().length()


func finish_typing() -> void:
	reveal = full_text().length()
	_refresh()


func wrapped_lines(text: String) -> Array[String]:
	var out: Array[String] = []
	var line: String = ""
	for word: String in text.split(" "):
		var next: String = word if line.is_empty() else line + " " + word
		if text_width(next, 1, ui_font(), 9) > TEXT_WIDTH and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = next
	out.append(line)
	return out


## Pushes the current words into the scene (the scene draws, this only says what).
func _refresh() -> void:
	if box == null:
		return
	box.show_controls(controls_open, "%s / %s: continue" % [Bindings.action_label("explore_interact"), Bindings.action_label("dialogue_next")] if controls_open else "")
	if controls_open or dialogue.is_empty():
		box.show_line({})
		return
	var lines: Array[String] = wrapped_lines(full_text())
	var shown: PackedStringArray = PackedStringArray()
	var remaining: int = int(reveal)
	for line: String in lines:
		shown.append(line.substr(0, maxi(0, remaining)))
		remaining -= line.length() + 1
	box.show_line({
		"speaker": String(dialogue.get("speaker", "")), "portrait": String(dialogue.get("portrait", "")),
		"shown_text": "\n".join(shown),
		"next_hint": "%s / %s: %s" % [Bindings.action_label("explore_interact"), Bindings.action_label("dialogue_next"), "Next" if complete() else "Reveal"],
		"skip_hint": "%s: skip" % Bindings.action_label("dialogue_skip"),
	})
