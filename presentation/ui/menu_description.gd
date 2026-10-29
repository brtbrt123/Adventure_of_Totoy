extends Control
## The description box at the bottom of the TAB menu (ITEMS tab and the arena's STATUS tab) as a Godot scene
## (menu_description.tscn), drawn behind the menu's own drawing (show_behind_parent). Open the scene in the editor to move
## or restyle it; this script only fills in the text.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## entry: [title, tag, [line, line, line]] as in character_menu.gd's descriptions(); an empty title shows the centred hint.
func apply(entry: Array) -> void:
	var lines: Array = entry[2]
	var plain: bool = String(entry[0]).is_empty()
	$Title.visible = not plain
	$Tag.visible = not plain
	for i: int in range(3):
		get_node("Line%d" % (i + 1)).visible = not plain
	var hint_top: Label = get_node_or_null("HintTop") as Label  # optional: the scene may leave a hint out
	var hint_bottom: Label = get_node_or_null("HintBottom") as Label
	if hint_top != null:
		hint_top.visible = plain
	if hint_bottom != null:
		hint_bottom.visible = plain
	if plain:
		if hint_top != null:
			hint_top.text = String(lines[0]).to_upper()
		if hint_bottom != null:
			hint_bottom.text = String(lines[2]).to_upper()
		return
	$Title.text = String(entry[0]).to_upper()
	$Tag.text = String(entry[1]).to_upper()
	for i: int in range(3):
		get_node("Line%d" % (i + 1)).text = String(lines[i]).to_upper() if i < lines.size() else ""
