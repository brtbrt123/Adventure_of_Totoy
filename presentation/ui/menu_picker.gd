@tool
extends Control
const EditorBackdrop := preload("res://presentation/ui/editor_backdrop.gd")
## The Aspect picker of the TAB menu (menu_picker.tscn): a carved list that opens over the stat list with the title, five
## rows (icon, name, Edge cost, key badge and tick) and a scroll bar. It sits above the menu's own drawing. Open the scene in
## the editor to move or restyle anything; this script only fills in the rows.
##
## Heads-up: hover and click areas are character_menu.gd's constants (PICKER, PICKER_ROW_TOP, PICKER_ROW_STEP,
## picker_row_rect()); if you move the panel or the rows here, change those too.

@export var atlas: Texture2D
var frames: Dictionary = {}
var _icons: Dictionary = {}

const ROWS: int = 5
const SELECTED: Color = Color("24365c")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorBackdrop.add(self, 0)


func _icon(frame: String) -> Texture2D:
	if not _icons.has(frame):
		var texture: AtlasTexture = null
		if atlas != null and frames.has(frame):
			var f: Dictionary = frames[frame]
			texture = AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(float(f["x"]) + 4.0, float(f["y"]) + 4.0, 16.0, 16.0)
		_icons[frame] = texture
	return _icons[frame]


## data: {title, title_color, show_back: bool, rows: Array of up to 5 {icon, name, cost, owned, selected, held (letter or "")},
##        bar: {thumb_y, thumb_h, up_on, down_on} or absent when the list fits}
func apply(data: Dictionary) -> void:
	$Title.text = String(data.get("title", "")).to_upper()
	$Title.add_theme_color_override("font_color", data.get("title_color", Color("f4ecd6")))
	$Back.visible = bool(data.get("show_back", true))
	var rows: Array = data.get("rows", [])
	var bar: Dictionary = data.get("bar", {})
	var has_bar: bool = not bar.is_empty()
	for i: int in range(ROWS):
		var node: Control = get_node("Row%d" % (i + 1))
		node.visible = i < rows.size()
		if i >= rows.size():
			continue
		var row: Dictionary = rows[i]
		var owned: bool = bool(row.get("owned", true))
		var selected: bool = bool(row.get("selected", false))
		node.size.x = 160.0 - (6.0 if has_bar else 0.0)
		node.get_node("Highlight").visible = selected
		node.get_node("Underline").visible = selected
		node.get_node("Highlight").size.x = node.size.x
		node.get_node("Underline").size.x = node.size.x
		node.get_node("Icon").texture = _icon(String(row.get("icon", "")))
		node.get_node("Dim").visible = not owned
		node.get_node("Lock").visible = not owned
		var name: Label = node.get_node("Name")
		name.text = String(row.get("name", "")).to_upper()
		name.add_theme_color_override("font_color", Color("f4ecd6") if selected and owned else Color("5a625e"))
		var cost: Label = node.get_node("Cost")
		cost.text = String(row.get("cost", "")).to_upper()
		cost.position.x = node.size.x - 26.0 - cost.size.x
		var held: String = String(row.get("held", ""))
		var show_held: bool = held != "" and owned
		node.get_node("Held").visible = show_held
		node.get_node("Held").position.x = node.size.x - 22.0
		node.get_node("Held/Letter").text = held
		node.get_node("Tick").visible = show_held
		node.get_node("Tick").position.x = node.size.x - 13.0
	$Bar.visible = has_bar
	if has_bar:
		$Bar/Thumb.position.y = float(bar.get("thumb_y", 0.0))
		$Bar/Thumb.size.y = float(bar.get("thumb_h", 4.0))
		var up: Color = Color("f4ecd6") if bool(bar.get("up_on", false)) else Color("2f3231")
		var down: Color = Color("f4ecd6") if bool(bar.get("down_on", false)) else Color("2f3231")
		for node_name: String in ["UpTip", "UpBase"]:
			$Bar.get_node(node_name).color = up
		for node_name: String in ["DownBase", "DownTip"]:
			$Bar.get_node(node_name).color = down
