@tool
extends Control
const EditorBackdrop := preload("res://presentation/ui/editor_backdrop.gd")
const MenuIcons := preload("res://presentation/ui/menu_icons.gd")
## The HERO tab of the TAB menu (menu_hero.tscn): Totoy, his level and EXP, the points to spend, the three stats with their
## pips and "+" buttons, and Respec. In the boss fight only Totoy and a note show. It sits behind the menu's own drawing
## (show_behind_parent: the menu draws the selection corners on top). Open the scene in the editor to move or restyle
## anything; this script only fills in the numbers.
##
## Heads-up: the clickable areas (rows, "+" buttons, Respec) are row_rect / plus_rect / respec_rect in character_menu.gd; if
## you move one here, change those too.

const BUTTON: String = "res://art/ui_kit/button_normal.png"
const BUTTON_LOCKED: String = "res://art/ui_kit/button_locked.png"
const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")
const TEAL: Color = Color("6aa89a")
const LINE: Color = Color("444b49")

var atlas: Texture2D = null
var frames: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorBackdrop.add(self, 0)


## data: {figure (atlas frame), title ("LEVEL 3" or "BOSS FIGHT"), exp: {fraction, text} or {} to hide the bar, points,
## points_color, rows: [{value, cap, can_add}] or [] to hide them, selected (-1 none, 0-2 a stat row, 3 Respec),
## respec: {enabled, note} or {} to hide it, note (shown instead of the rows when they are hidden)}
func apply(data: Dictionary) -> void:
	$FigureBox/Figure.texture = MenuIcons.icon(atlas, frames, String(data.get("figure", "")))
	$Title.text = String(data.get("title", "")).to_upper()
	var bar: Dictionary = data.get("exp", {})
	for node: String in ["ExpFrame", "ExpFill", "ExpText"]:
		get_node(node).visible = not bar.is_empty()
	if not bar.is_empty():
		var fill: NinePatchRect = $ExpFill
		fill.size.x = maxf(3.0, roundf(($ExpFrame.size.x - 4.0) * clampf(float(bar.get("fraction", 0.0)), 0.0, 1.0)))
		$ExpText.text = String(bar.get("text", "")).to_upper()
	$Points.text = String(data.get("points", "")).to_upper()
	$Points.add_theme_color_override("font_color", data.get("points_color", TEAL))
	var rows: Array = data.get("rows", [])
	var selected: int = int(data.get("selected", -1))
	for i: int in 3:
		var row: Control = get_node("Row%d" % i)
		row.visible = i < rows.size()
		if not row.visible:
			continue
		var value: Dictionary = rows[i]
		row.get_node("Fill").visible = selected == i
		var cap: int = int(value.get("cap", 10))
		for p: int in 10:
			var pip: ColorRect = row.get_node("Pips/Pip%d" % p)
			pip.visible = p < cap
			pip.color = TEAL if p < int(value.get("value", 0)) else LINE
		var can_add: bool = bool(value.get("can_add", false))
		var plus: NinePatchRect = row.get_node("Plus")
		plus.texture = load(BUTTON if can_add else BUTTON_LOCKED)
		plus.get_node("Sign").add_theme_color_override("font_color", CREAM if can_add else STONE)
	$LineBottom.visible = not rows.is_empty()
	var respec: Dictionary = data.get("respec", {})
	$Respec.visible = not respec.is_empty()
	$RespecNote.visible = not respec.is_empty()
	if not respec.is_empty():
		var enabled: bool = bool(respec.get("enabled", false))
		$Respec.texture = load(BUTTON if enabled else BUTTON_LOCKED)
		$Respec/Name.add_theme_color_override("font_color", CREAM if enabled else STONE)
		$RespecNote.text = String(respec.get("note", "")).to_upper()
	$Note.visible = rows.is_empty()
	$Note.text = String(data.get("note", "")).to_upper()
