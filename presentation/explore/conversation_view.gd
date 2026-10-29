extends "res://presentation/arena/hud.gd"
## Snapshot text only; reveal and consume presses here, conversation rules stay in core.
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const PANEL: Rect2 = Rect2(6, 146, 372, 66)
const TEXT_WIDTH: float = 280.0
const CHARACTERS_PER_SECOND: float = 38.0
var dialogue: Dictionary = {}
var reveal: float = 0.0
var controls_open: bool = false
var portrait_frames: Dictionary = {}
var portrait_sheet: Texture2D
var _line_key: String = ""
var blip: Callable = Callable()
var typed_nonspaces: int = 0


func _ready() -> void:
	portrait_sheet = load("res://art/reference/chapter1_characters_v2/portraits_v2.png") as Texture2D
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/reference/chapter1_characters_v2/portraits_v2.json")) as Dictionary
	portrait_frames = data.get("frames", {})


func sync(value: Dictionary) -> void:
	var key: String = "%s/%s/%s" % [value.get("dialogue_id", ""), value.get("index", -1), value.get("text", "")]
	if key != _line_key:
		reveal = 0.0
		typed_nonspaces = 0
		_line_key = key
	dialogue = value.duplicate()
	queue_redraw()


func tick() -> void:
	var before: int = int(reveal)
	reveal = minf(reveal + CHARACTERS_PER_SECOND / 60.0, full_text().length())
	for i: int in range(before, int(reveal)):
		if not full_text().substr(i, 1).strip_edges().is_empty():
			typed_nonspaces += 1
			if typed_nonspaces % 3 == 0 and blip.is_valid():
				blip.call()
	queue_redraw()


func full_text() -> String:
	return String(dialogue.get("text", ""))


func complete() -> bool:
	return int(reveal) >= full_text().length()


func finish_typing() -> void:
	reveal = full_text().length()
	queue_redraw()


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


func _draw() -> void:
	if colors.is_empty():
		return
	if controls_open:
		draw_rect(Rect2(0, 0, 384, 216), Color(colors["0"], 0.55))
		UiPanel.draw_panel(self, Rect2(74, 62, 236, 92), &"info", colors)
		lettering(Vector2(94, 80), "Welcome to Lanternfen", colors["1"], 1, menu_font(), 11)
		lettering(Vector2(94, 105), "You made it home.", colors["p"], 1, ui_font(), 9)
		lettering(Vector2(94, 117), "A familiar light still burns in the quiet.", colors["p"], 1, ui_font(), 9)
		lettering(Vector2(94, 135), "%s / %s: continue" % [Bindings.action_label("explore_interact"), Bindings.action_label("dialogue_next")], colors["u"])
		return
	if dialogue.is_empty():
		return
	UiPanel.draw_panel(self, PANEL, &"info", colors)
	# the portrait (88 px art shown at 44) in a carved frame; the speaker's ribbon sits on the panel's top edge
	var frame: Rect2 = Rect2(16, 154, 52, 52)
	Kit.nine(self, "slot_frame", frame)
	var portrait: String = "portrait_%s_neutral" % String(dialogue.get("portrait", ""))
	if portrait_frames.has(portrait):
		var data: Dictionary = portrait_frames[portrait]
		draw_texture_rect_region(portrait_sheet, Rect2(frame.position + Vector2(4, 4), Vector2(44, 44)), Rect2(data["x"], data["y"], data["w"], data["h"]))
	var speaker: String = String(dialogue.get("speaker", ""))
	var ribbon_w: float = ceilf(text_width(speaker, 1, menu_font(), 10)) + 56.0
	Kit.ribbon(self, Rect2(78, 138, ribbon_w, 16))
	lettering(Vector2(78 + (ribbon_w - text_width(speaker, 1, menu_font(), 10)) * 0.5, 141), speaker, colors["1"], 1, menu_font(), 10)
	var lines: Array[String] = wrapped_lines(full_text())
	var remaining: int = int(reveal)
	for i: int in lines.size():
		var shown: String = lines[i].substr(0, maxi(0, remaining))
		# Draw case-preserving dialogue with the same real font as the HUD.
		draw_string(ui_font(), Vector2(80, 169 + i * 11), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, colors["1"])
		remaining -= lines[i].length() + 1
	var next: String = "Next" if complete() else "Reveal"
	lettering(Vector2(80, 195), "%s / %s: %s" % [Bindings.action_label("explore_interact"), Bindings.action_label("dialogue_next"), next], colors["p"])
	lettering(Vector2(300, 195), "%s: skip" % Bindings.action_label("dialogue_skip"), colors["o"])
