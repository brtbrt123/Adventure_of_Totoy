extends Control
## The ASPECTS tab of the TAB menu as a Godot scene (menu_aspects.tscn), drawn behind the menu's own drawing
## (show_behind_parent; the menu still draws the selection brackets and the aspect picker on top). Open the scene in the
## editor to move or restyle anything; this script only fills in names and icons.
##
## Heads-up: the clickable socket areas are still character_menu.gd's aspects_tab_rect(); if you move a socket here,
## change that too.

@export var atlas: Texture2D
var frames: Dictionary = {}
var _icons: Dictionary = {}

const SOCKET_OPEN: String = "res://art/ui_kit/aspect_socket_open.png"
const SOCKET_LOCKED: String = "res://art/ui_kit/aspect_socket_locked.png"
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
			texture.region = Rect2(float(f["x"]) + 4.0, float(f["y"]) + 4.0, 16.0, 16.0)
		_icons[frame] = texture
	return _icons[frame]


## data: {sockets: [{open, icon}] x3, name, stats (empty hides the line), notice}
func apply(data: Dictionary) -> void:
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
	$Detail/Name.text = String(data.get("name", "")).to_upper()
	$Detail/Stats.text = String(data.get("stats", "")).to_upper()
	$Notice.text = String(data.get("notice", "")).to_upper()
