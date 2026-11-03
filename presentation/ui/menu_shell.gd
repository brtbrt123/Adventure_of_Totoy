@tool
extends Control
## The TAB menu's frame as a Godot scene (menu_shell.tscn): the dim veil, the three tabs, the name at the top right, the big
## carved panel, the frame of the detail card on the right and the footer of keys. It sits behind the tab scenes and the
## menu's own drawing (show_behind_parent). Open the scene in the editor to restyle it.
##
## Heads-up: the clickable areas of the tabs are TAB_RECTS in character_menu.gd; if you move or resize a tab here, change
## those too. The footer copies its two hidden template labels (Footer/KeyTemplate, Footer/ActionTemplate) for every key, so
## restyle those to restyle the footer.

const TAB_ON: String = "res://art/ui_kit/tab_on.png"
const TAB_OFF: String = "res://art/ui_kit/tab_off.png"
const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")
## The gap between one key's action and the next key in the footer.
const PAIR_GAP: String = "      "

var _tab_on: Texture2D = null
var _tab_off: Texture2D = null
var _footer_shown: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_on = load(TAB_ON) as Texture2D
	_tab_off = load(TAB_OFF) as Texture2D


## Marks `selected` (0-based) as the open tab, sets the tab names and lists `footer` ([[key, what it does], ...]) centred
## under the panel.
func apply(selected: int, names: Array, footer: Array = []) -> void:
	for i: int in range(3):
		var tab: NinePatchRect = get_node_or_null("Tab%d" % i) as NinePatchRect
		if tab == null:
			continue
		tab.visible = i < names.size()
		if i < names.size():
			tab.texture = _tab_on if i == selected else _tab_off
			var label: Label = tab.get_node("Name")
			label.text = String(names[i]).to_upper()
			label.add_theme_color_override("font_color", CREAM if i == selected else STONE)
	if footer != _footer_shown:
		_footer_shown = footer.duplicate(true)
		_fill_footer(footer)


func _fill_footer(footer: Array) -> void:
	var row: HBoxContainer = $Footer
	var key_template: Label = $Footer/KeyTemplate
	var action_template: Label = $Footer/ActionTemplate
	for child: Node in row.get_children():
		if child != key_template and child != action_template:
			row.remove_child(child)
			child.queue_free()
	for i: int in footer.size():
		var key: Label = key_template.duplicate() as Label
		key.text = String(footer[i][0]).to_upper()
		key.visible = true
		row.add_child(key)
		var action: Label = action_template.duplicate() as Label
		action.text = String(footer[i][1]).to_upper() + (PAIR_GAP if i < footer.size() - 1 else "")
		action.visible = true
		row.add_child(action)
	row.reset_size()
	row.position.x = roundf((size.x - row.size.x) / 2.0)
