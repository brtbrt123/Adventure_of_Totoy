@tool
extends Control
const EditorBackdrop := preload("res://presentation/ui/editor_backdrop.gd")
const MenuIcons := preload("res://presentation/ui/menu_icons.gd")
## The detail card on the right of the TAB menu (menu_card.tscn): it always describes what is selected. Two layouts:
##   info: an icon, the title and a short line under it; then either the stat list (HERO: Stat0..Stat4, a line, the text
##         under it) or a block of text (GEAR, QUESTS: Body, an optional Reward row, a line, Foot).
##   list: the title and a hint, three rows (ListRow0..2: icon, name, a short line, a key badge), a scroll bar when the list
##         is longer, a note, a line and the highlighted row's text (ListBody).
## It sits behind the menu's own drawing (show_behind_parent). Open the scene in the editor to move or restyle anything; this
## script only fills in the words and icons and moves Line and Foot between the two info layouts.
##
## Heads-up: the clickable list rows are list_row_rect in character_menu.gd; if you move the rows here, change that too.

const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")
const LILAC: Color = Color("8a6fa8")
## Line and Foot (y) in the stat layout and in the text layout.
const STATS_LINE_Y: float = 132.0
const STATS_FOOT_Y: float = 138.0
const TEXT_LINE_Y: float = 144.0
const TEXT_FOOT_Y: float = 149.0
## Title and Sub start here (x), further right when there is an icon.
const TEXT_X: float = 242.0
const ICON_TEXT_X: float = 264.0

var atlas: Texture2D = null
var frames: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorBackdrop.add(self, 1)


## data: {mode ("info" or "list"), icon (atlas frame or ""), icon_crop (Rect2), title, sub, sub_color,
##   info: stats ([[name, value, extra]], 5 at most), body, body_color, body_size, reward ([label, value] or []), foot, foot_color
##   list: rows ([{icon, crop, name, sub, sub_color, badge, selected}], 3 at most), scroll ({} or {thumb_y, thumb_h}), note, list_body}
func apply(data: Dictionary) -> void:
	var list: bool = String(data.get("mode", "info")) == "list"
	var icon: Texture2D = MenuIcons.icon(atlas, frames, String(data.get("icon", "")), data.get("icon_crop", Rect2()))
	$Icon.texture = icon
	$Icon.visible = icon != null and not list
	var text_x: float = ICON_TEXT_X if $Icon.visible else TEXT_X
	$Title.position.x = text_x
	$Sub.position.x = text_x
	$Title.text = String(data.get("title", "")).to_upper()
	$Sub.text = String(data.get("sub", "")).to_upper()
	$Sub.add_theme_color_override("font_color", data.get("sub_color", STONE))
	var stats: Array = [] if list else data.get("stats", [])
	for i: int in 5:
		var row: Control = get_node("Stat%d" % i)
		row.visible = i < stats.size()
		if row.visible:
			row.get_node("Name").text = String(stats[i][0]).to_upper()
			row.get_node("Value").text = String(stats[i][1]).to_upper()
			row.get_node("Extra").text = String(stats[i][2]).to_upper() if stats[i].size() > 2 else ""
	var body: Label = $Body
	body.visible = not list and stats.is_empty()
	body.text = String(data.get("body", "")).to_upper()
	body.add_theme_color_override("font_color", data.get("body_color", CREAM))
	body.add_theme_font_size_override("font_size", int(data.get("body_size", 6)))
	var reward: Array = [] if list else data.get("reward", [])
	$Reward.visible = not reward.is_empty()
	if not reward.is_empty():
		$Reward/Name.text = String(reward[0]).to_upper()
		$Reward/Value.text = String(reward[1]).to_upper()
	var foot: String = String(data.get("foot", ""))
	$Line.visible = not list and not foot.is_empty()
	$Line.position.y = STATS_LINE_Y if not stats.is_empty() else TEXT_LINE_Y
	$Foot.visible = not list and not foot.is_empty()
	$Foot.position.y = STATS_FOOT_Y if not stats.is_empty() else TEXT_FOOT_Y
	$Foot.text = foot.to_upper()
	$Foot.add_theme_color_override("font_color", data.get("foot_color", LILAC))
	var rows: Array = data.get("rows", []) if list else []
	for i: int in 3:
		var row: Control = get_node("ListRow%d" % i)
		row.visible = i < rows.size()
		if not row.visible:
			continue
		var value: Dictionary = rows[i]
		row.get_node("Fill").visible = bool(value.get("selected", false))
		row.get_node("Icon").texture = MenuIcons.icon(atlas, frames, String(value.get("icon", "")), value.get("crop", Rect2()))
		row.get_node("Name").text = String(value.get("name", "")).to_upper()
		var sub: Label = row.get_node("Sub")
		sub.text = String(value.get("sub", "")).to_upper()
		sub.add_theme_color_override("font_color", value.get("sub_color", STONE))
		var badge: String = String(value.get("badge", ""))
		row.get_node("Badge").visible = not badge.is_empty()
		row.get_node("Badge/Letter").text = badge
	var scroll: Dictionary = data.get("scroll", {}) if list else {}
	$Track.visible = not scroll.is_empty()
	$Track/Thumb.visible = not scroll.is_empty()
	if not scroll.is_empty():
		$Track/Thumb.position.y = float(scroll.get("thumb_y", 0.0))
		$Track/Thumb.size.y = float(scroll.get("thumb_h", $Track.size.y))
	var note: String = String(data.get("note", "")) if list else ""
	$Note.visible = not note.is_empty()
	$Note.text = note.to_upper()
	$ListLine.visible = list
	$ListBody.visible = list
	$ListBody.text = String(data.get("list_body", "")).to_upper()
