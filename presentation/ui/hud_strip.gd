extends Control
## The bottom-of-screen HUD (the road and the boss fight) as ONE Godot scene (hud_strip.tscn): the weapon medallion, the HEALTH / EDGE / DASH
## bars, the two item slots, the three Aspect sockets and the level pillar. Open the scene in the editor to move, resize or
## re-texture any piece; this script only fills them in from numbers. It draws nothing and holds no rules.
##
## Use: strip.apply({...}) once per frame with the keys listed at apply(). Icons come from the sprite atlas by frame name.

const PALETTE_PATH: String = "res://art/palette.json"

@export var atlas: Texture2D
## Frame name -> {x, y, w, h, ...} from art/build/sprites.json.
var frames: Dictionary = {}
var _icons: Dictionary = {}
var _ink: Color = Color.BLACK

@onready var weapon_glyph: TextureRect = $Medallion/WeaponGlyph
@onready var health_value: Label = $HealthValue
@onready var health_ghost: NinePatchRect = $HealthBar/Ghost
@onready var health_fill: NinePatchRect = $HealthBar/Fill
@onready var edge_label: Label = $EdgeLabel
@onready var edge_fill: NinePatchRect = $EdgeBar/Fill
@onready var dash_fill: NinePatchRect = $DashBar/Fill
@onready var pillar_fill: ColorRect = $LevelPillar/Fill
@onready var level_label: Label = $LevelPillar/Level
@onready var exp_label: Label = $LevelPillar/ExpLabel
@onready var down_label: Label = $Down
@onready var whole_medallion: TextureRect = $WholeMedallion
@onready var kit_medallion: TextureRect = $Medallion
@onready var name_plate: Control = $NamePlate


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## An atlas icon cut to `source` (default the whole frame), cached.
func icon(frame: String, source: Rect2 = Rect2()) -> Texture2D:
	var key: String = "%s/%s" % [frame, source]
	if not _icons.has(key):
		var texture: AtlasTexture = null
		if atlas != null and frames.has(frame):
			var f: Dictionary = frames[frame]
			texture = AtlasTexture.new()
			texture.atlas = atlas
			var region: Rect2 = Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"]))
			if source.size != Vector2.ZERO:
				region = Rect2(region.position + source.position, source.size)
			texture.region = region
		_icons[key] = texture
	return _icons[key]


## A bar fill shown as `fraction` (0..1) of its full width, kept to whole pixels. `full` is the width the scene gives it.
func _set_fraction(node: Control, fraction: float, full: float) -> void:
	var width: float = floorf(full * clampf(fraction, 0.0, 1.0))
	node.visible = width > 0.0
	node.size.x = width


## data keys (all optional; a missing key leaves that piece as it is):
##   armed: bool, weapon_glyph: String (atlas frame), whole_medallion: atlas frame of a whole 48 px medallion (dagger, scythe)
##   plate: the weapon's short name (boss fight)
##   status: Array (up to 3) of atlas frames of the Aspects running now (boss fight)
##   hp, max_hp, ghost: ints (ghost = the delayed segment)
##   edge: float 0..1, or -1 when the road does not know it yet
##   dash: float 0..1
##   items: Array of {unlocked, item, count}   (two slots; hidden when the key is absent)
##   aspects: Array of {unlocked, owned, usable, icon: String (atlas frame), key, cost, cost_color}   (three sockets)
##   level: int, exp: float 0..1, exp_label: String   (the pillar is hidden when "level" is absent)
##   defeated: bool
func apply(data: Dictionary) -> void:
	var whole: String = String(data.get("whole_medallion", ""))
	kit_medallion.visible = whole.is_empty()
	whole_medallion.visible = not whole.is_empty()
	if not whole.is_empty():
		whole_medallion.texture = icon(whole)
	name_plate.visible = data.has("plate")
	if data.has("plate"):
		name_plate.get_node("Name").text = String(data["plate"]).to_upper()
	if data.has("weapon_glyph"):
		weapon_glyph.texture = icon(String(data["weapon_glyph"]))
		weapon_glyph.visible = bool(data.get("armed", true))
	var status: Array = data.get("status", [])
	for i: int in range(3):
		var slot_node: Control = get_node("Status%d" % (i + 1))
		slot_node.visible = i < status.size()
		if i < status.size():
			slot_node.get_node("Icon").texture = icon(String(status[i]))
	if data.has("hp"):
		var max_hp: float = maxf(1.0, float(data.get("max_hp", 1)))
		health_value.text = "%d / %d" % [int(data["hp"]), int(max_hp)]
		var full: float = 114.0
		_set_fraction(health_fill, float(data["hp"]) / max_hp, full)
		_set_fraction(health_ghost, float(data.get("ghost", data["hp"])) / max_hp, full)
	if data.has("edge"):
		var edge: float = float(data["edge"])
		edge_label.text = "EDGE  --" if edge < 0.0 else "EDGE"
		edge_label.add_theme_color_override("font_color", Color("5a625e") if edge < 0.0 else Color("6aa89a"))
		_set_fraction(edge_fill, maxf(0.0, edge), 79.0)
	if data.has("dash"):
		_set_fraction(dash_fill, float(data["dash"]), 33.0)
	var items: Array = data.get("items", [])
	for i: int in range(2):
		var slot: Control = get_node("ItemSlot%d" % (i + 1))
		slot.visible = data.has("items")
		var value: Dictionary = items[i] if i < items.size() else {}
		var unlocked: bool = bool(value.get("unlocked", false))
		slot.get_node("Locked").visible = not unlocked
		slot.get_node("Count").visible = unlocked
		slot.get_node("Count").text = str(value.get("count", 0))
		var item: TextureRect = slot.get_node("Icon")
		item.visible = unlocked and String(value.get("item", "")) == "herb"
		item.texture = icon("hud_copper_herb")
		slot.get_node("Key/Letter").modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.45)
	var aspects: Array = data.get("aspects", [])
	for i: int in range(3):
		var socket: TextureRect = get_node("Socket%d" % (i + 1))
		var value: Dictionary = aspects[i] if i < aspects.size() else {}
		var open: bool = bool(value.get("unlocked", false)) and bool(value.get("owned", true))
		socket.texture = load("res://art/ui_kit/aspect_socket_open.png" if open else "res://art/ui_kit/aspect_socket_locked.png")
		var glyph: TextureRect = socket.get_node("Icon")
		glyph.visible = open
		glyph.texture = icon(String(value.get("icon", "")), Rect2(4, 4, 16, 16))
		glyph.modulate = Color.WHITE if bool(value.get("usable", false)) else Color(1, 1, 1, 0.45)
		socket.get_node("Key").modulate = Color.WHITE if open else Color(1, 1, 1, 0.45)
		if value.has("key"):
			socket.get_node("Key").text = String(value["key"])
		var cost: Label = socket.get_node("Cost")
		cost.visible = value.has("cost")
		if value.has("cost"):
			cost.text = String(value["cost"]).to_upper()
			cost.add_theme_color_override("font_color", value.get("cost_color", Color.WHITE))
	$LevelPillar.visible = data.has("level")
	if data.has("level"):
		level_label.text = str(int(data["level"]))
		exp_label.text = String(data.get("exp_label", "EXP"))
		var tube: float = 76.0
		var height: float = floorf(tube * clampf(float(data.get("exp", 0.0)), 0.0, 1.0))
		pillar_fill.size.y = height
		pillar_fill.position.y = 30.0 + tube - height
		pillar_fill.visible = height > 0.0
	down_label.visible = bool(data.get("defeated", false))
