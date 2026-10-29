extends Control
## The boss-fight menu's STATUS tab as a Godot scene (menu_arena_status.tscn): the figure box, the weapon medallion and name, the
## three Aspect sockets and the stat list. Drawn behind the menu's own drawing (show_behind_parent): the menu still draws
## Totoy himself (a clipped sprite), his shadow, the selection brackets and the Aspect picker on top. Open the scene in the
## editor to move or restyle any piece; this script only fills in the words and icons.
##
## Heads-up: the clickable areas (weapon slot, sockets, stat rows) are still character_menu.gd's constants (WEAPON_SLOT,
## aspect_rect(), STAT_X0/STAT_X1/STAT_TOP/ROW_STEP, FIGURE); if you move a piece here, change those too.

const Hud := preload("res://presentation/arena/hud.gd")
const ROWS: int = 13
const ROW_STEP: float = 8.0
const STAT_X0: float = 204.0
const STAT_X1: float = 362.0
const STAT_TOP: float = 36.0
const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")
const SAND: Color = Color("c6bfaa")
const VIOLET: Color = Color("8a6fa8")

@export var atlas: Texture2D
var frames: Dictionary = {}
var _icons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _icon(frame: String, crop: Rect2 = Rect2()) -> Texture2D:
	var key: String = "%s/%s" % [frame, crop]
	if not _icons.has(key):
		var texture: AtlasTexture = null
		if atlas != null and frames.has(frame):
			var f: Dictionary = frames[frame]
			texture = AtlasTexture.new()
			texture.atlas = atlas
			var region: Rect2 = Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"]))
			if crop.size != Vector2.ZERO:
				region = Rect2(region.position + crop.position, crop.size)
			texture.region = region
		_icons[key] = texture
	return _icons[key]


## A label's text in the font the game picks for it (plain numbers use the number font, words the pixel font).
func _say(label: Label, text: String, color: Color) -> void:
	label.text = text.to_upper()
	var face: Font = Hud.text_face(text)
	label.add_theme_font_override("font", face)
	label.add_theme_color_override("font_color", color)
	# the same baseline the code-drawn list used, so the words and the numbers sit on one line
	var size: int = label.get_theme_font_size("font_size")
	label.position.y = Hud._cap_ratio(face) * size - face.get_ascent(size)


## data:
##   whole_medallion: atlas frame of a whole 48 px medallion (dagger, scythe), or "" for the kit medallion round `glyph`
##   weapon_name, sockets: Array of 3 {icon, key}
##   rows: Array of up to 13 {header: bool, name, value, lit: bool}
func apply(data: Dictionary) -> void:
	var whole: String = String(data.get("whole_medallion", ""))
	$Medallion.visible = whole.is_empty()
	$Glyph.visible = whole.is_empty()
	$WholeMedallion.visible = not whole.is_empty()
	if whole.is_empty():
		$Glyph.texture = _icon("ui_weapon_totoy_blade_1")
	else:
		$WholeMedallion.texture = _icon(whole)
	$WeaponName.text = String(data.get("weapon_name", "")).to_upper()
	var sockets: Array = data.get("sockets", [])
	for i: int in range(3):
		var socket: Control = get_node("Socket%d" % (i + 1))
		var value: Dictionary = sockets[i] if i < sockets.size() else {}
		socket.get_node("Icon").texture = _icon(String(value.get("icon", "")), Rect2(4, 4, 16, 16))
		socket.get_node("Key").text = String(value.get("key", ""))
	var rows: Array = data.get("rows", [])
	for i: int in range(ROWS):
		var node: Control = get_node("Row%d" % i)
		node.visible = i < rows.size()
		if i >= rows.size():
			continue
		var row: Dictionary = rows[i]
		var header: bool = bool(row.get("header", false))
		var lit: bool = bool(row.get("lit", false))
		var name: Label = node.get_node("Name")
		var value_label: Label = node.get_node("Value")
		node.get_node("Highlight").visible = lit and not header
		node.get_node("Underline").visible = lit and not header
		node.get_node("Arrow").visible = lit and not header
		node.get_node("Rule").visible = header
		value_label.visible = not header
		name.position.x = 0.0 + (5.0 if lit and not header else 0.0)
		if header:
			_say(name, String(row.get("name", "")), VIOLET)
			var font: Font = name.get_theme_font("font")
			var width: float = font.get_string_size(name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name.get_theme_font_size("font_size")).x
			node.get_node("Rule").position.x = width + 4.0
			node.get_node("Rule").size.x = maxf(0.0, STAT_X1 - STAT_X0 - width - 4.0)
		else:
			_say(name, String(row.get("name", "")), CREAM if lit else STONE)
			_say(value_label, String(row.get("value", "")), CREAM if lit else SAND)
