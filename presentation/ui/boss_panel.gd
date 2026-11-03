@tool
extends Control
## The boss's name and health panel (boss_panel.tscn): the carved plate art, the name, the health bar with its ghost, the
## posture bar and the COUNTER prompt. hud.gd moves this whole node to follow the boss's head (or parks it top right when he is
## off screen), so edit it as a small standalone panel: everything is relative to its top-left corner.

const HP_WIDTH: float = 88.0
const POSTURE_WIDTH: float = 64.0
const COUNTER_WIDTH: float = 88.0

@export var atlas: Texture2D
var frames: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fill(node: Control, value: float, maximum: float, full: float) -> void:
	var width: float = floorf(full * clampf(value / maxf(maximum, 1.0), 0.0, 1.0))
	node.visible = width > 0.0
	node.size.x = width


## data: {hp, hp_max, ghost, posture, posture_max, broken: bool, counter_ticks, counter_max}
func apply(data: Dictionary) -> void:
	if atlas != null and frames.has("ui_boss"):
		var f: Dictionary = frames["ui_boss"]
		var art: AtlasTexture = AtlasTexture.new()
		art.atlas = atlas
		art.region = Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"]))
		$Art.texture = art
	var hp_max: float = float(data.get("hp_max", 1))
	_fill($Health/Fill, float(data.get("hp", 0)), hp_max, HP_WIDTH)
	_fill($Health/Ghost, float(data.get("ghost", data.get("hp", 0))), hp_max, HP_WIDTH)
	$Health/Top.size.x = $Health/Fill.size.x
	$Health/Top.visible = $Health/Fill.visible
	$Health/Bottom.size.x = $Health/Fill.size.x
	$Health/Bottom.visible = $Health/Fill.visible
	_fill($Posture/Fill, float(data.get("posture", 0)), float(data.get("posture_max", 1)), POSTURE_WIDTH)
	$Posture/Fill.color = Color("e0f0ec") if bool(data.get("broken", false)) else Color("8a6fa8")
	var counter: bool = float(data.get("counter_ticks", 0)) > 0.0
	$Counter.visible = counter
	if counter:
		_fill($Counter/Fill, float(data.get("counter_ticks", 0)), float(data.get("counter_max", 1)), COUNTER_WIDTH)
	size.y = 47.0 if counter else 33.0
