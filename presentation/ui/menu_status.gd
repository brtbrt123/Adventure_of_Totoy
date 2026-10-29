extends Control
## The STATUS tab of the explore TAB menu (stat points, aspect sockets, respec) as a Godot scene (menu_status.tscn). It sits
## behind the menu's drawing (show_behind_parent): the menu still draws the selection brackets and the aspect picker on
## top. Open the scene in the editor to move or restyle any piece; this script only fills in the numbers and icons.
##
## Heads-up: the clickable areas (stat "+" buttons, sockets, respec) are still the constants in character_menu.gd
## (progression_plus_rect, progression_aspect_rect, respec_rect); if you move one here, change those too.

@export var atlas: Texture2D
var frames: Dictionary = {}
var _icons: Dictionary = {}

const SOCKET_OPEN: String = "res://art/ui_kit/aspect_socket_open.png"
const SOCKET_LOCKED: String = "res://art/ui_kit/aspect_socket_locked.png"
const BUTTON: String = "res://art/ui_kit/button_normal.png"
const BUTTON_LOCKED: String = "res://art/ui_kit/button_locked.png"
const DIM: Color = Color(1, 1, 1, 0.45)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _icon(frame: String) -> Texture2D:
	if not _icons.has(frame):
		var texture: AtlasTexture = null
		if atlas != null and frames.has(frame):
			var f: Dictionary = frames[frame]
			texture = AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(float(f["x"]) + 4.0, float(f["y"]) + 4.0, 16.0, 16.0)  # the icon's inner 16x16, its ring cropped away
		_icons[frame] = texture
	return _icons[frame]


## data: {unspent, level, hp, rows: [{value, cap, enabled}] x3, sockets: [{open, icon (atlas frame)}] x3, village: bool,
## notice: String}
func apply(data: Dictionary) -> void:
	$Unspent.text = "UNSPENT POINTS: %d" % int(data.get("unspent", 0))
	$LevelHp.text = "LV %d   HP %d" % [int(data.get("level", 1)), int(data.get("hp", 0))]
	var rows: Array = data.get("rows", [])
	for i: int in range(3):
		var row: Dictionary = rows[i] if i < rows.size() else {}
		var node: Control = get_node("Row%d" % (i + 1))
		node.get_node("Value").text = "%d / %d" % [int(row.get("value", 0)), int(row.get("cap", 0))]
		var plus: NinePatchRect = node.get_node("Plus")
		var enabled: bool = bool(row.get("enabled", false))
		plus.texture = load(BUTTON if enabled else BUTTON_LOCKED)
		plus.get_node("Sign").modulate = Color.WHITE if enabled else DIM
	var sockets: Array = data.get("sockets", [])
	for i: int in range(3):
		var socket: TextureRect = get_node("Socket%d" % (i + 1))
		var value: Dictionary = sockets[i] if i < sockets.size() else {}
		var open: bool = bool(value.get("open", false))
		socket.texture = load(SOCKET_OPEN if open else SOCKET_LOCKED)
		var icon: TextureRect = socket.get_node("Icon")
		icon.visible = open
		icon.texture = _icon(String(value.get("icon", "")))
		socket.get_node("Key").modulate = Color.WHITE if open else DIM
	var village: bool = bool(data.get("village", false))
	var respec: NinePatchRect = $Respec
	respec.texture = load(BUTTON if village else BUTTON_LOCKED)
	respec.get_node("Name").modulate = Color.WHITE if village else DIM
	$RespecNote.text = "FREE IN VILLAGE" if village else "VILLAGE ONLY"
	$Notice.text = String(data.get("notice", "")).to_upper()
