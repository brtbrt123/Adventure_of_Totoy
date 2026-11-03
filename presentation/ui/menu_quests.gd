@tool
extends Control
const EditorBackdrop := preload("res://presentation/ui/editor_backdrop.gd")
## The QUESTS tab of the TAB menu as a Godot scene (menu_quests.tscn), drawn behind the menu's own drawing
## (show_behind_parent). Open the scene in the editor to move or restyle anything; this script only fills in the text.
## The objective wraps by itself inside its label, so resize the label to change where it breaks.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorBackdrop.add(self, 3)


## data: {objective, hint}
func apply(data: Dictionary) -> void:
	$Card/Objective.text = String(data.get("objective", "")).to_upper()
	$Card/Hint.text = String(data.get("hint", "")).to_upper()
