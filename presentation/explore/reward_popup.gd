extends "res://presentation/arena/hud.gd"
## Receipt display only. The caller queues confirmed core rewards, never grants inventory here. The card itself is the
## editable scene presentation/ui/reward_card.tscn (open it in Godot to move or restyle it); this script only queues,
## times and hands the scene the words.
const RewardCard := preload("res://presentation/ui/reward_card.tscn")
const DISPLAY_SECONDS: float = 3.4
## The name's room inside the card, in game pixels (the card's Name label width).
const NAME_WIDTH: float = 72.0
var pending: Array[Dictionary] = []
var receipt: Dictionary = {}
var seconds_left: float = 0.0
var blocked: bool = false
var atlas: Texture2D
var frames: Dictionary = {}
var card: Control = null


func _ready() -> void:
	card = RewardCard.instantiate()
	add_child(card)
	_refresh()


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
	_refresh()


func _refresh() -> void:
	if card == null or receipt.is_empty():
		return
	card.atlas = atlas
	card.frames = frames
	var text: String = String(receipt["name"])
	var quantity: int = int(receipt.get("quantity", 1))
	if quantity > 1:
		text += " x%d" % quantity
	# Long item names shrink, preserving the complete name within the fixed card.
	var size: int = 9
	while size > 6 and text_width(text, 1, ui_font(), size) > NAME_WIDTH:
		size -= 1
	card.apply({"icon": String(receipt.get("icon", "")), "text": text, "size": size})
