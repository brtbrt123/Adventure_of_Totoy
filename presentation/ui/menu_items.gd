extends Control
## The ITEMS tab of the TAB menu as a Godot scene (menu_items.tscn): the 6x3 slot grid and the detail card on the right.
## Drawn behind the menu's own drawing (show_behind_parent; the menu still draws the selection brackets on top). Open the
## scene in the editor to move or restyle anything; this script only fills in icons and words.
##
## Heads-up: the clickable slot areas are still character_menu.gd's inventory_rect() (GRID_ORIGIN, GRID_STEP, SLOT_SIZE);
## if you move or resize the slots here, change those too.

@export var atlas: Texture2D
var frames: Dictionary = {}
var _icons: Dictionary = {}

const SLOT_COUNT: int = 18


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


## data.slots: 18 x {kind: "weapon" | "aspect" | "empty", frame, crop (Rect2 or empty), owned, held (a letter or ""), equipped}
## data.card: {kind: "weapon" | "aspect" | "empty" | "locked", katana (kit medallion + glyph), medallion (atlas frame of a whole 48 px
## medallion), aspect (atlas frame), name, status, status_color, line1, line2, line_color}
func apply(data: Dictionary) -> void:
	var slots: Array = data.get("slots", [])
	for i: int in range(SLOT_COUNT):
		var node: Control = get_node("Slot%d" % i)
		var value: Dictionary = slots[i] if i < slots.size() else {}
		var kind: String = String(value.get("kind", "empty"))
		var weapon: TextureRect = node.get_node("WeaponIcon")
		var aspect: TextureRect = node.get_node("AspectIcon")
		weapon.visible = kind == "weapon"
		aspect.visible = kind == "aspect"
		if kind == "weapon":
			weapon.texture = _icon(String(value.get("frame", "")), value.get("crop", Rect2()))
		elif kind == "aspect":
			aspect.texture = _icon(String(value.get("frame", "")))
		var locked: bool = kind == "aspect" and not bool(value.get("owned", true))
		node.get_node("Dim").visible = locked
		node.get_node("Lock").visible = locked
		var held: String = String(value.get("held", ""))
		node.get_node("Held").visible = kind == "aspect" and held != ""
		node.get_node("Held/Letter").text = held
		node.get_node("Equipped").visible = bool(value.get("equipped", false))
	var card: Dictionary = data.get("card", {})
	var kind_card: String = String(card.get("kind", "empty"))
	var weapon_card: bool = kind_card == "weapon"
	var aspect_card: bool = kind_card == "aspect"
	$Card/KitMedallion.visible = weapon_card and bool(card.get("katana", false))
	$Card/Glyph.visible = $Card/KitMedallion.visible
	$Card/Medallion.visible = weapon_card and not bool(card.get("katana", false))
	$Card/Socket.visible = aspect_card
	if weapon_card:
		$Card/Glyph.texture = _icon("ui_weapon_totoy_blade_1")
		$Card/Medallion.texture = _icon(String(card.get("medallion", "")))
	elif aspect_card:
		$Card/Socket/Icon.texture = _icon(String(card.get("aspect", "")), Rect2(4, 4, 16, 16))
	var detailed: bool = weapon_card or aspect_card
	$Card/Name.visible = detailed
	$Card/Status.visible = detailed
	$Card/Divider.visible = detailed
	$Card/Line1.visible = detailed
	$Card/Line2.visible = detailed
	$Card/Empty.visible = not detailed
	$Card/Empty.text = "LOCKED" if kind_card == "locked" else "EMPTY"
	if detailed:
		$Card/Name.text = String(card.get("name", "")).to_upper()
		$Card/Status.text = String(card.get("status", "")).to_upper()
		$Card/Status.add_theme_color_override("font_color", card.get("status_color", Color.WHITE))
		$Card/Line1.text = String(card.get("line1", "")).to_upper()
		$Card/Line2.text = String(card.get("line2", "")).to_upper()
		for label: Label in [$Card/Line1, $Card/Line2]:
			label.add_theme_color_override("font_color", card.get("line_color", Color.WHITE))
