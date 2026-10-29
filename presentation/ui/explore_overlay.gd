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
			var node: CanvasItem = get_node_or_null(group) as CanvasItem  # a piece you deleted in the editor is simply skipped
			if node != null:
				node.visible = false


## A piece of the scene, or null when it was deleted in the editor (every piece is optional).
func _piece(path: String) -> Control:
	return get_node_or_null(path) as Control


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
	var banner: Control = _piece("LevelUp")
	if banner != null:
		banner.visible = not level_up.is_empty()
		if not level_up.is_empty() and banner.get_node_or_null("Sub") != null:
			banner.get_node("Sub").text = String(level_up.get("sub", "")).to_upper()
	var task: String = String(d.get("task", ""))
	var task_label: Label = _piece("Task") as Label
	if task_label != null:
		task_label.visible = not task.is_empty()
		task_label.text = task.to_upper()
	var gate: Array = d.get("gate", [])
	var gate_box: Control = _piece("Gate")
	if gate_box != null:
		gate_box.visible = not gate.is_empty()
		for i: int in range(2):
			var line: Label = gate_box.get_node_or_null("Line%d" % (i + 1)) as Label
			if line != null:
				line.text = String(gate[i]).to_upper() if i < gate.size() else ""
	_chips(d.get("chips", {}))
	var locked: Dictionary = d.get("locked", {})
	var locked_label: Label = _piece("LockedMsg") as Label
	if locked_label != null:
		locked_label.visible = not locked.is_empty()
		if not locked.is_empty():
			locked_label.text = String(locked.get("text", "")).to_upper()
			locked_label.position = Vector2(float(locked.get("x", 0.0)), float(locked.get("y", 0.0)))
	var tab: Dictionary = d.get("tab", {})
	var tab_label: Label = _piece("TabHint") as Label
	if tab_label != null:
		tab_label.visible = not tab.is_empty()
		if not tab.is_empty():
			tab_label.text = String(tab.get("text", "")).to_upper()
			tab_label.position = Vector2(float(tab.get("x", 0.0)), float(tab.get("y", 0.0)))
	_hint(d.get("hint", {}))
	_lesson(d.get("lesson", {}))
	_checklist(d.get("checklist", {}))


func _objective(text: String) -> void:
	var box: Control = _piece("Objective")
	if box == null:
		return
	box.visible = not text.is_empty()
	var label: Label = box.get_node_or_null("Text") as Label
	if text.is_empty() or label == null:
		return
	label.text = text.to_upper()
	box.size.x = clampf(_width(label, text) + 34.0, 120.0, 300.0)


func _toast(toast: Dictionary) -> void:
	var box: Control = _piece("Toast")
	if box == null:
		return
	box.visible = not toast.is_empty()
	var label: Label = box.get_node_or_null("Text") as Label
	if toast.is_empty() or label == null:
		return
	label.text = String(toast.get("text", "")).to_upper()
	var width: float = ceilf(_width(label, label.text)) + 58.0
	box.size.x = width
	box.position.x = 380.0 - width
	label.size.x = width
	box.modulate.a = float(toast.get("alpha", 1.0))


func _chips(chips: Dictionary) -> void:
	var box: Control = _piece("Chips")
	if box == null:
		return
	box.visible = not chips.is_empty()
	if chips.is_empty():
		return
	box.position = Vector2(float(chips.get("x", 0.0)), float(chips.get("y", 0.0)))
	var items: Array = chips.get("items", [])
	for i: int in range(3):
		var chip: NinePatchRect = box.get_node_or_null("Chip%d" % (i + 1)) as NinePatchRect
		if chip == null:
			continue
		var item: Dictionary = items[i] if i < items.size() else {}
		var unlocked: bool = bool(item.get("unlocked", false))
		chip.texture = load("res://art/ui_kit/button_normal.png" if unlocked else "res://art/ui_kit/button_locked.png")
		var lock: Control = chip.get_node_or_null("Lock") as Control
		if lock != null:
			lock.visible = not unlocked
		var key: Label = chip.get_node_or_null("Key") as Label
		if key != null:
			key.text = String(item.get("key", "")).to_upper()
			key.position.x = 4.0 if not unlocked else 0.0
			key.add_theme_color_override("font_color", Color("e0f0ec") if unlocked else Color("5a625e"))


func _hint(hint: Dictionary) -> void:
	var box: Control = _piece("Hint")
	if box == null:
		return
	box.visible = not hint.is_empty()
	var label: Label = box.get_node_or_null("Text") as Label
	if hint.is_empty() or label == null:
		return
	label.text = String(hint.get("text", "")).to_upper()
	var width: float = ceilf(_width(label, label.text)) + 12.0
	box.size.x = width
	label.size.x = width
	box.position = Vector2(float(hint.get("x", 0.0)), float(hint.get("y", 0.0)))


func _lesson(lesson: Dictionary) -> void:
	var box: Control = _piece("Lesson")
	if box == null:
		return
	box.visible = not lesson.is_empty()
	if lesson.is_empty():
		return
	for pair: Array in [["Title", "title"], ["Detail", "detail"]]:
		var label: Label = box.get_node_or_null(pair[0]) as Label
		if label != null:
			label.text = String(lesson.get(pair[1], "")).to_upper()
	var key: String = String(lesson.get("key", ""))
	var button: Control = box.get_node_or_null("KeyButton") as Control
	if button == null:
		return
	button.visible = not key.is_empty()
	var key_label: Label = button.get_node_or_null("Text") as Label
	if not key.is_empty() and key_label != null:
		key_label.text = key.to_upper()
		var width: float = ceilf(_width(key_label, key)) + 10.0
		button.size.x = width
		key_label.size.x = width
		button.position.x = 187.0 - width


func _checklist(checklist: Dictionary) -> void:
	var box: Control = _piece("Checklist")
	if box == null:
		return
	box.visible = not checklist.is_empty()
	if checklist.is_empty():
		return
	var names: Array = checklist.get("names", [])
	var done: Dictionary = checklist.get("done", {})
	var current: String = String(checklist.get("current", ""))
	for i: int in range(4):
		var item: Control = box.get_node_or_null("Item%d" % (i + 1)) as Control
		if item == null:
			continue
		var name: String = String(names[i]) if i < names.size() else ""
		var finished: bool = bool(done.get(name, false))
		var tone: Color = Color("6aa89a") if finished else (Color("f4ecd6") if name == current else Color("a7cde0"))
		var label: Label = item.get_node_or_null("Name") as Label
		if label != null:
			label.text = name.to_upper()
			label.add_theme_color_override("font_color", tone)
		var square: ColorRect = item.get_node_or_null("Box") as ColorRect
		if square != null:
			square.color = tone
		var hole: Control = item.get_node_or_null("Hole") as Control
		if hole != null:
			hole.visible = not finished
		var underline: Control = item.get_node_or_null("Underline") as Control
		if underline != null:
			underline.visible = name == current
