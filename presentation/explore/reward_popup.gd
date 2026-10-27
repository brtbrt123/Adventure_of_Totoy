extends "res://presentation/arena/hud.gd"
## Receipt display only. The caller queues confirmed core rewards, never grants inventory here.
const CARD: Rect2 = Rect2(70, 44, 180, 43)
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
	var key: String = String(receipt.get("icon", ""))
	var icon: Rect2 = Rect2(78, 51, 28, 28)
	draw_rect(icon, colors["8"])
	if frames.has(key) and atlas != null:
		var frame: Dictionary = frames[key]
		draw_texture_rect_region(atlas, icon, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	var title: String = "Weapon received" if receipt.get("kind", &"item") == &"weapon" else "Item received"
	lettering(Vector2(113, 53), title, colors["u"], 1, menu_font(), 8)
	var name: String = String(receipt["name"])
	var quantity: int = int(receipt.get("quantity", 1))
	if quantity > 1:
		name += " x%d" % quantity
	# Long item names shrink, preserving the complete name within the fixed card.
	var size: int = 9
	while size > 6 and text_width(name, 1, ui_font(), size) > 127:
		size -= 1
	lettering(Vector2(113, 68), name, colors["1"], 1, ui_font(), size)
