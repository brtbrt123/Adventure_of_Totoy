extends "res://presentation/arena/hud.gd"
## Snapshot text only; reveal and consume presses here, conversation rules stay in core.
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const PANEL: Rect2 = Rect2(5, 111, 310, 65)
const TEXT_WIDTH: float = 238.0
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
		draw_rect(Rect2(0, 0, 320, 180), Color(colors["0"], 0.55))
		UiPanel.draw_panel(self, Rect2(42, 50, 236, 80), &"info", colors)
		lettering(Vector2(58, 62), "Welcome to Lanternfen", colors["1"], 1, menu_font(), 11)
		lettering(Vector2(58, 85), "You made it home.", colors["p"], 1, ui_font(), 9)
		lettering(Vector2(58, 97), "A familiar light still burns in the quiet.", colors["p"], 1, ui_font(), 9)
		lettering(Vector2(58, 115), "%s / %s: continue" % [Bindings.action_label("explore_interact"), Bindings.action_label("dialogue_next")], colors["u"])
		return
	if dialogue.is_empty():
		return
	UiPanel.draw_panel(self, PANEL, &"info", colors)
	draw_rect(Rect2(12, 121, 48, 48), colors["0"])
	var portrait: String = "portrait_%s_neutral" % String(dialogue.get("portrait", ""))
	if portrait_frames.has(portrait):
		var frame: Dictionary = portrait_frames[portrait]
		draw_texture_rect_region(portrait_sheet, Rect2(14, 123, 44, 44), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	lettering(Vector2(68, 118), String(dialogue.get("speaker", "")), colors["u"], 1, menu_font(), 10)
	var lines: Array[String] = wrapped_lines(full_text())
	var remaining: int = int(reveal)
	for i: int in lines.size():
		var shown: String = lines[i].substr(0, maxi(0, remaining))
		# Draw case-preserving dialogue with the same real font as the HUD.
		draw_string(ui_font(), Vector2(68, 138 + i * 10), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, colors["1"])
		remaining -= lines[i].length() + 1
	var next: String = "Next" if complete() else "Reveal"
	lettering(Vector2(68, 164), "%s / %s: %s" % [Bindings.action_label("explore_interact"), Bindings.action_label("dialogue_next"), next], colors["p"])
	lettering(Vector2(231, 164), "%s: skip" % Bindings.action_label("dialogue_skip"), colors["o"])
