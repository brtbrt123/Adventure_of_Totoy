extends Control
## The TAB menu's frame as a Godot scene (menu_shell.tscn): the dim veil, the big carved panel, the four tabs, the name at
## the top right and the footer line. It sits behind the menu's own drawing (show_behind_parent), so the code-drawn
## tab contents appear on top of it. Open the scene in the editor to restyle it.
##
## Heads-up: the clickable areas of the tabs are still the constants in character_menu.gd (TAB_SPECS, tab_rect); if you move
## or resize a tab here, change those too.

const TAB_ON: String = "res://art/ui_kit/tab_on.png"
const TAB_OFF: String = "res://art/ui_kit/tab_off.png"
const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")

var _tab_on: Texture2D = null
var _tab_off: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_on = load(TAB_ON) as Texture2D
	_tab_off = load(TAB_OFF) as Texture2D


## Marks `selected` (0-based) as the open tab and sets the tab names.
func apply(selected: int, names: Array) -> void:
	for i: int in range(4):
		var tab: NinePatchRect = get_node_or_null("Tab%d" % i) as NinePatchRect
		if tab == null:
			continue
		tab.visible = i < names.size()
		if i < names.size():
			tab.texture = _tab_on if i == selected else _tab_off
			var label: Label = tab.get_node("Name")
			label.text = String(names[i]).to_upper()
			label.add_theme_color_override("font_color", CREAM if i == selected else STONE)
