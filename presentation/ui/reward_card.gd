extends Control
## The "RECEIVED" card (item and weapon receipts) as a Godot scene (reward_card.tscn). Open the scene in the editor to move,
## resize or restyle anything; this script only fills in the icon and words. reward_popup.gd decides when it is shown.

@export var atlas: Texture2D
var frames: Dictionary = {}
var _icons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _icon(frame: String) -> Texture2D:
	if not _icons.has(frame):
		var texture: AtlasTexture = null
		if atlas != null and frames.has(frame):
			var f: Dictionary = frames[frame]
			texture = AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"]))
		_icons[frame] = texture
	return _icons[frame]


## receipt: {icon (atlas frame), text, size (font size that fits the card)}
func apply(receipt: Dictionary) -> void:
	$Card/Icon.texture = _icon(String(receipt.get("icon", "")))
	$Card/Name.text = String(receipt.get("text", "")).to_upper()
	$Card/Name.add_theme_font_size_override("font_size", int(receipt.get("size", 9)))
