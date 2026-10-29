extends Control
## The boss-fight HUD's fixed pieces as a Godot scene (arena_strip.tscn): the weapon medallion and name plate, the HEALTH /
## EDGE / DASH bars, the running-Aspect icons and the three Aspect sockets with their keys and Edge costs. It sits behind the
## HUD's own drawing (show_behind_parent), so the cooldown rings, the seconds, the READY ring, the boss panel and the
## tooltip are drawn on top of it by hud.gd. Open the scene in the editor to move or restyle any piece; this script only fills
## in numbers and icons.
##
## Heads-up: the socket hover area and the rings are positioned from hud.gd's aspect_rects(), weapon_rect() and
## aspect_icon_rect(); if you move a socket or the medallion here, change those too.

@export var atlas: Texture2D
var frames: Dictionary = {}
var _icons: Dictionary = {}

const FILL_HEALTH_WIDTH: float = 114.0
const FILL_EDGE_WIDTH: float = 79.0
const FILL_DASH_WIDTH: float = 33.0


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


func _fraction(node: Control, fraction: float, full: float) -> void:
	var width: float = floorf(full * clampf(fraction, 0.0, 1.0))
	node.visible = width > 0.0
	node.size.x = width


## data:
##   whole_medallion: atlas frame of a whole 48 px medallion (dagger, scythe), or "" for the kit medallion round `glyph`
##   glyph: atlas frame of the katana's 32 px glyph;  plate: the weapon's short name
##   hp, max_hp, ghost: ints;  edge, dash: 0..1
##   status: Array (up to 3) of atlas frames of the Aspects running now
##   sockets: Array of 3 {icon (atlas frame), key, cost, cost_color}
func apply(data: Dictionary) -> void:
	var whole: String = String(data.get("whole_medallion", ""))
	$Medallion.visible = whole.is_empty()
	$Glyph.visible = whole.is_empty()
	$WholeMedallion.visible = not whole.is_empty()
	if whole.is_empty():
		$Glyph.texture = _icon(String(data.get("glyph", "")))
	else:
		$WholeMedallion.texture = _icon(whole)
	$NamePlate/Name.text = String(data.get("plate", "")).to_upper()
	var max_hp: float = maxf(1.0, float(data.get("max_hp", 1)))
	$HealthValue.text = "%d / %d" % [int(data.get("hp", 0)), int(max_hp)]
	_fraction($HealthBar/Fill, float(data.get("hp", 0)) / max_hp, FILL_HEALTH_WIDTH)
	_fraction($HealthBar/Ghost, float(data.get("ghost", data.get("hp", 0))) / max_hp, FILL_HEALTH_WIDTH)
	_fraction($EdgeBar/Fill, float(data.get("edge", 0.0)), FILL_EDGE_WIDTH)
	_fraction($DashBar/Fill, float(data.get("dash", 0.0)), FILL_DASH_WIDTH)
	var status: Array = data.get("status", [])
	for i: int in range(3):
		var slot: Control = get_node("Status%d" % (i + 1))
		slot.visible = i < status.size()
		if i < status.size():
			slot.get_node("Icon").texture = _icon(String(status[i]))
	var sockets: Array = data.get("sockets", [])
	for i: int in range(3):
		var socket: Control = get_node("Socket%d" % (i + 1))
		var value: Dictionary = sockets[i] if i < sockets.size() else {}
		socket.get_node("Icon").texture = _icon(String(value.get("icon", "")), Rect2(4, 4, 16, 16))
		socket.get_node("Key").text = String(value.get("key", ""))
		var cost: Label = socket.get_node("Cost")
		cost.text = String(value.get("cost", "")).to_upper()
		cost.add_theme_color_override("font_color", value.get("cost_color", Color.WHITE))
