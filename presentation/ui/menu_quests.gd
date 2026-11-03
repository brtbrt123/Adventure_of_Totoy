@tool
extends Control
const EditorBackdrop := preload("res://presentation/ui/editor_backdrop.gd")
## The QUESTS tab of the TAB menu (menu_quests.tscn): the chapter's tasks done so far (a tick each) and the current one (a
## rune, highlighted). Later tasks stay hidden. The current task's details are in the detail card (menu_card.tscn). It sits
## behind the menu's own drawing (show_behind_parent). Open the scene in the editor to move or restyle anything; this script
## only fills in the text.

const CHECK: String = "res://art/ui_kit/icon_check.png"
const RUNE: String = "res://art/ui_kit/icon_rune.png"
const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")
## Rows in the scene (Row0..Row11): the whole chapter fits.
const ROWS: int = 12


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorBackdrop.add(self, 2)


## data: {heading, rows: [{text, now (the current task)}]}; the last ROWS rows show when there are more.
func apply(data: Dictionary) -> void:
	$Heading.text = String(data.get("heading", "")).to_upper()
	var rows: Array = data.get("rows", [])
	var first: int = maxi(0, rows.size() - ROWS)
	for i: int in ROWS:
		var row: Control = get_node("Row%d" % i)
		row.visible = first + i < rows.size()
		if not row.visible:
			continue
		var value: Dictionary = rows[first + i]
		var now: bool = bool(value.get("now", false))
		row.get_node("Fill").visible = now
		row.get_node("Icon").texture = load(RUNE if now else CHECK)
		var text: Label = row.get_node("Text")
		text.text = String(value.get("text", "")).to_upper()
		text.add_theme_color_override("font_color", CREAM if now else STONE)
