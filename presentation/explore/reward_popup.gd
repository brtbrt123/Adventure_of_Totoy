extends "res://presentation/arena/hud.gd"
## Receipt display only. The caller queues confirmed core rewards, never grants inventory here.
const CARD: Rect2 = Rect2(218, 6, 96, 26)
const DISPLAY_SECONDS: float = 3.4
var pending: Array[Dictionary] = []
var receipt: Dictionary = {}
var seconds_left: float = 0.0
var blocked: bool = false
var atlas: Texture2D
var frames: Dictionary = {}


func enqueue(value: Dictionary) -> void:
	if String(value.get("name", "")).is_empty():
		return
	pending.append(value.duplicate(true))


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	visible = not blocked and not receipt.is_empty()
	if blocked:
		return
	seconds_left = maxf(0.0, seconds_left - delta)
	if seconds_left <= 0.0:
		receipt.clear()
		if not pending.is_empty():
			receipt = pending.pop_front()
			seconds_left = DISPLAY_SECONDS
	visible = not receipt.is_empty()
	queue_redraw()


func _draw() -> void:
	if receipt.is_empty() or colors.is_empty():
		return
	UiPanel.draw_panel(self, CARD, &"info", colors)
	# Highlighted teal rails and separate inset wells follow the supplied reference.
	draw_line(CARD.position + Vector2(4, 2), CARD.position + Vector2(CARD.size.x - 5, 2), colors["u"])
	draw_line(CARD.position + Vector2(4, CARD.size.y - 3), CARD.end - Vector2(5, 3), colors["t"])
	var well: Rect2 = Rect2(CARD.position + Vector2(4, 4), Vector2(20, 18))
	draw_rect(well, colors["8"])
	UiPanel.outline(self, well, colors["f"])
	draw_line(well.position + Vector2(1, 1), well.position + Vector2(well.size.x - 2, 1), colors["b"])
	var label: Rect2 = Rect2(CARD.position + Vector2(27, 4), Vector2(CARD.size.x - 31, 18))
	for row: int in int(label.size.y):
		var shade: Color = colors["0"].lerp(colors["v"], 0.20 - 0.10 * float(row) / label.size.y)
		draw_rect(Rect2(label.position + Vector2(0, row), Vector2(label.size.x, 1)), shade)
	UiPanel.outline(self, label, colors["0"].lerp(colors["v"], 0.32))
	draw_line(CARD.position + Vector2(25, 4), CARD.position + Vector2(25, 22), colors["f"])
	# Small inset corner marks, kept inside the item-name compartment.
	for corner: Vector2 in [label.position + Vector2(2, 2), label.position + Vector2(label.size.x - 3, 2), label.end - Vector2(3, 3), label.position + Vector2(2, label.size.y - 3)]:
		draw_rect(Rect2(corner, Vector2.ONE), colors["v"].lerp(colors["0"], 0.45))
	var key: String = String(receipt.get("icon", ""))
	var icon: Rect2 = Rect2(well.position + Vector2(2, 1), Vector2(16, 16))
	if frames.has(key) and atlas != null:
		var frame: Dictionary = frames[key]
		draw_texture_rect_region(atlas, icon, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	var name: String = String(receipt["name"])
	var quantity: int = int(receipt.get("quantity", 1))
	if quantity > 1:
		name += " x%d" % quantity
	# Long item names shrink, preserving the complete name within the fixed card.
	var size: int = 8
	while size > 6 and text_width(name, 1, ui_font(), size) > label.size.x - 8:
		size -= 1
	centered(label.get_center().x, label.position.y + (label.size.y - float(size) * 5.0 / 9.0) * 0.5, name, colors["1"], colors["0"], 1, ui_font(), size)
