@tool
extends Control
const EditorBackdrop := preload("res://presentation/ui/editor_backdrop.gd")
const MenuIcons := preload("res://presentation/ui/menu_icons.gd")
## The GEAR tab of the TAB menu (menu_gear.tscn): the weapon socket with the weapon's name and numbers beside it, the three
## Aspect sockets (keys Z, X, C) and the two item slots (keys 1, 2). Choosing a weapon or an Aspect happens in the detail
## card (menu_card.tscn). It sits behind the menu's own drawing (show_behind_parent: the menu draws the selection corners on
## top). Open the scene in the editor to move or restyle anything; this script only fills in names, numbers and icons.
##
## Heads-up: the clickable areas are weapon_rect / socket_rect / item_rect in character_menu.gd; if you move a socket or a
## slot here, change those too.

const SOCKET_OPEN: String = "res://art/ui_kit/aspect_socket_open.png"
const SOCKET_LOCKED: String = "res://art/ui_kit/aspect_socket_locked.png"
const CREAM: Color = Color("f4ecd6")
const DIM: Color = Color("5a625e")

var atlas: Texture2D = null
var frames: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EditorBackdrop.add(self, 1)


## data: {weapon: {glyph (atlas frame in the kit medallion, the katana) or whole (a whole 48 px medallion), name, tag,
## lines: [3 short lines]}, sockets: [{locked, icon}] x3, items: [{icon, count}] x2 (count < 0: no number)}
func apply(data: Dictionary) -> void:
	var weapon: Dictionary = data.get("weapon", {})
	var whole: String = String(weapon.get("whole", ""))
	$Medallion.visible = whole.is_empty()
	$Medallion/Glyph.texture = MenuIcons.icon(atlas, frames, String(weapon.get("glyph", "")))
	$WholeMedallion.visible = not whole.is_empty()
	$WholeMedallion.texture = MenuIcons.icon(atlas, frames, whole)
	$WeaponName.text = String(weapon.get("name", "")).to_upper()
	$WeaponTag.text = String(weapon.get("tag", "")).to_upper()
	var lines: Array = weapon.get("lines", [])
	for i: int in 3:
		var label: Label = get_node("WeaponLine%d" % i)
		label.text = String(lines[i]).to_upper() if i < lines.size() else ""
	var sockets: Array = data.get("sockets", [])
	for i: int in 3:
		var socket: TextureRect = get_node("Socket%d" % i)
		var value: Dictionary = sockets[i] if i < sockets.size() else {"locked": true}
		var locked: bool = bool(value.get("locked", true))
		socket.texture = load(SOCKET_LOCKED if locked else SOCKET_OPEN)
		var icon: TextureRect = socket.get_node("Icon")
		icon.texture = null if locked else MenuIcons.icon(atlas, frames, String(value.get("icon", "")))
		socket.get_node("Key/Letter").add_theme_color_override("font_color", DIM if locked else CREAM)
	var items: Array = data.get("items", [])
	for i: int in 2:
		var slot: NinePatchRect = get_node("Item%d" % i)
		var value: Dictionary = items[i] if i < items.size() else {}
		slot.get_node("Icon").texture = MenuIcons.icon(atlas, frames, String(value.get("icon", "")))
		var count: int = int(value.get("count", -1))
		var number: Label = slot.get_node("Count")
		number.visible = count >= 0
		number.text = str(count)
		slot.get_node("Icon").modulate = Color(1, 1, 1, 0.45) if count == 0 else Color.WHITE
