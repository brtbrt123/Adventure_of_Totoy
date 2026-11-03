@tool
extends Control
## The first-visit "Welcome to Lanternfen" card as its own Godot scene (welcome_card.tscn), separate from the conversation
## box (dialogue_box.tscn) so each can be edited and debugged on its own. In the editor it is shown; in the game it stays
## hidden until conversation_view.gd opens it.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		visible = false


## Opens or closes the card; `hint` is its key line ("E / Enter: continue").
func show_card(open: bool, hint: String = "") -> void:
	visible = open
	var label: Label = get_node_or_null("Hint") as Label
	if label != null and open:
		label.text = hint
