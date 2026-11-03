@tool
extends Control
## The VICTORY / DEFEAT panel (result_panel.tscn): the carved panel, the ribbon title, "R TO RESTART", the saved TIME / BEST
## lines and the "ESC: TITLE" hint. hud.gd centres this whole node on the screen and sets its height from how many lines there
## are, so edit it as a standalone card with its top-left corner as the origin (the ribbon sits just above the top edge).

const Hud := preload("res://presentation/arena/hud.gd")
const MAX_LINES: int = 4
const LINE_TOP: float = 30.0
const LINE_STEP: float = 10.0
const WIDTH: float = 192.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## data: {victory: bool, lines: Array of String (up to 4), hint: String}. Returns the card's height.
func apply(data: Dictionary) -> float:
	var victory: bool = bool(data.get("victory", true))
	$Title.text = "VICTORY" if victory else "DEFEAT"
	var accent: Color = Color("6aa89a") if victory else Color("8f5f4c")
	var gem: Color = Color("e0f0ec") if victory else Color("e6bf9d")
	var soft: Color = Color("a7cde0") if victory else Color("c6bfaa")
	$Restart.add_theme_color_override("font_color", soft)
	var lines: Array = data.get("lines", [])
	$Rule.visible = not lines.is_empty()
	for i: int in range(MAX_LINES):
		var label: Label = get_node("Line%d" % (i + 1))
		label.visible = i < lines.size()
		if i < lines.size():
			label.text = String(lines[i]).to_upper()
			label.add_theme_font_override("font", Hud.text_face(label.text))
	var y: float = LINE_TOP + LINE_STEP * minf(lines.size(), MAX_LINES)
	var hint: String = String(data.get("hint", ""))
	$HintRule.visible = not hint.is_empty()
	$HintGem.visible = not hint.is_empty()
	$Hint.visible = not hint.is_empty()
	if not hint.is_empty():
		$HintRule.position.y = y
		$HintRule.color = accent
		$HintGem.position.y = y
		$HintGem.color = gem
		$Hint.position.y = y + 4.0
		$Hint.text = hint.to_upper()
		$Hint.add_theme_color_override("font_color", soft)
	var height: float = 44.0 + (lines.size() * LINE_STEP + 4.0 if not lines.is_empty() else 0.0) + (12.0 if not hint.is_empty() else 0.0)
	$Panel.size.y = height
	size.y = height
	return height
