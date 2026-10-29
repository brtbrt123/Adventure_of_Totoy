@tool
extends Control
## The road's on-screen messages as a Godot scene (explore_overlay.tscn): the objective bar, the scene-name ribbon, the
## level-up banner, the task-complete line, the story-gate message, the Dash / Attack / Parry chips, the TAB reminder, the
## "[E] TALK" hint and the two tutorial cards. In the editor every piece is shown with sample text so you can see and move
## it; in the game each piece shows only when explore_hud.gd gives it something to say. The scene sits behind the HUD's own
## drawing (show_behind_parent), so the scene-change fade still covers it.
##
## Heads-up: three pieces are positioned by the game, not the scene, because they follow something: the hint (above the NPC
## it is for), the chips and the TAB reminder (they move up when the fight bars are on screen). Their positions in the scene
## are only the default.

const GROUPS: Array[String] = ["Objective", "Toast", "LevelUp", "Task", "Gate", "Chips", "LockedMsg", "TabHint", "Hint", "Lesson", "Checklist"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		for group: String in GROUPS:
			get_node(group).visible = false


func _width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


## Every key is optional; a missing key hides that piece.
##   objective: String
##   toast: {text, alpha}
##   level_up: {sub}                       task: String            gate: Array of up to 2 lines
##   chips: {x, y, items: [{unlocked, key}] x3}      locked: {text, x, y}
##   tab: {text, x, y}                     hint: {text, x, y}
##   lesson: {title, detail, key (may be ""), y}     checklist: {names: [4], done: {name: bool}, current: String}
func apply(d: Dictionary) -> void:
	_objective(String(d.get("objective", "")))
	_toast(d.get("toast", {}))
	var level_up: Dictionary = d.get("level_up", {})
	$LevelUp.visible = not level_up.is_empty()
	if not level_up.is_empty():
		$LevelUp/Sub.text = String(level_up.get("sub", "")).to_upper()
	var task: String = String(d.get("task", ""))
	$Task.visible = not task.is_empty()
	$Task.text = task.to_upper()
	var gate: Array = d.get("gate", [])
	$Gate.visible = not gate.is_empty()
	for i: int in range(2):
		$Gate.get_node("Line%d" % (i + 1)).text = String(gate[i]).to_upper() if i < gate.size() else ""
	_chips(d.get("chips", {}))
	var locked: Dictionary = d.get("locked", {})
	$LockedMsg.visible = not locked.is_empty()
	if not locked.is_empty():
		$LockedMsg.text = String(locked.get("text", "")).to_upper()
		$LockedMsg.position = Vector2(float(locked.get("x", 0.0)), float(locked.get("y", 0.0)))
	var tab: Dictionary = d.get("tab", {})
	$TabHint.visible = not tab.is_empty()
	if not tab.is_empty():
		$TabHint.text = String(tab.get("text", "")).to_upper()
		$TabHint.position = Vector2(float(tab.get("x", 0.0)), float(tab.get("y", 0.0)))
	_hint(d.get("hint", {}))
	_lesson(d.get("lesson", {}))
	_checklist(d.get("checklist", {}))


func _objective(text: String) -> void:
	$Objective.visible = not text.is_empty()
	if text.is_empty():
		return
	var label: Label = $Objective/Text
	label.text = text.to_upper()
	$Objective.size.x = clampf(_width(label, text) + 34.0, 120.0, 300.0)


func _toast(toast: Dictionary) -> void:
	$Toast.visible = not toast.is_empty()
	if toast.is_empty():
		return
	var label: Label = $Toast/Text
	label.text = String(toast.get("text", "")).to_upper()
	var width: float = ceilf(_width(label, label.text)) + 58.0
	$Toast.size.x = width
	$Toast.position.x = 380.0 - width
	label.size.x = width
	$Toast.modulate.a = float(toast.get("alpha", 1.0))


func _chips(chips: Dictionary) -> void:
	$Chips.visible = not chips.is_empty()
	if chips.is_empty():
		return
	$Chips.position = Vector2(float(chips.get("x", 0.0)), float(chips.get("y", 0.0)))
	var items: Array = chips.get("items", [])
	for i: int in range(3):
		var chip: NinePatchRect = $Chips.get_node("Chip%d" % (i + 1))
		var item: Dictionary = items[i] if i < items.size() else {}
		var unlocked: bool = bool(item.get("unlocked", false))
		chip.texture = load("res://art/ui_kit/button_normal.png" if unlocked else "res://art/ui_kit/button_locked.png")
		chip.get_node("Lock").visible = not unlocked
		var key: Label = chip.get_node("Key")
		key.text = String(item.get("key", "")).to_upper()
		key.position.x = 4.0 if not unlocked else 0.0
		key.add_theme_color_override("font_color", Color("e0f0ec") if unlocked else Color("5a625e"))


func _hint(hint: Dictionary) -> void:
	$Hint.visible = not hint.is_empty()
	if hint.is_empty():
		return
	var label: Label = $Hint/Text
	label.text = String(hint.get("text", "")).to_upper()
	var width: float = ceilf(_width(label, label.text)) + 12.0
	$Hint.size.x = width
	label.size.x = width
	$Hint.position = Vector2(float(hint.get("x", 0.0)), float(hint.get("y", 0.0)))


func _lesson(lesson: Dictionary) -> void:
	$Lesson.visible = not lesson.is_empty()
	if lesson.is_empty():
		return
	$Lesson/Title.text = String(lesson.get("title", "")).to_upper()
	$Lesson/Detail.text = String(lesson.get("detail", "")).to_upper()
	var key: String = String(lesson.get("key", ""))
	$Lesson/KeyButton.visible = not key.is_empty()
	if not key.is_empty():
		var label: Label = $Lesson/KeyButton/Text
		label.text = key.to_upper()
		var width: float = ceilf(_width(label, key)) + 10.0
		$Lesson/KeyButton.size.x = width
		label.size.x = width
		$Lesson/KeyButton.position.x = 187.0 - width


func _checklist(checklist: Dictionary) -> void:
	$Checklist.visible = not checklist.is_empty()
	if checklist.is_empty():
		return
	var names: Array = checklist.get("names", [])
	var done: Dictionary = checklist.get("done", {})
	var current: String = String(checklist.get("current", ""))
	for i: int in range(4):
		var item: Control = $Checklist.get_node("Item%d" % (i + 1))
		var name: String = String(names[i]) if i < names.size() else ""
		var finished: bool = bool(done.get(name, false))
		var tone: Color = Color("6aa89a") if finished else (Color("f4ecd6") if name == current else Color("a7cde0"))
		var label: Label = item.get_node("Name")
		label.text = name.to_upper()
		label.add_theme_color_override("font_color", tone)
		item.get_node("Box").color = tone
		item.get_node("Hole").visible = not finished
		item.get_node("Underline").visible = name == current
