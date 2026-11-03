extends RefCounted
## Source-scene art coordinates and silhouette shadows; positions/solidity remain core-owned.
const Light := preload("res://presentation/common/environment_light.gd")
const LocalShadow := preload("res://presentation/common/local_prop_shadows.gd")
const BASE_SPRITE: String = "hollow_trial_altar_base"  # tools/art/make_trial_altar_base.py


## Worn slabs and grass at the altar's foot (owner playtest 2026-10-31: "the ground where the altar is doesn't have anything", then
## "just add grass and some slabs", no platform): flat floor art under everything, placed by the altar's feet so it follows the altar
## when it is moved in the editor. Decoration only: walkable floor, no collision, no telegraph.
static func draw_altar_base(canvas: Node2D, at: Vector2, frames: Dictionary, atlas: Texture2D) -> void:
	if atlas == null or not frames.has(BASE_SPRITE):
		return
	var f: Dictionary = frames[BASE_SPRITE]
	canvas.draw_texture_rect_region(atlas, Rect2((at - Vector2(f["ax"], f["ay"])).round(), Vector2(f["w"], f["h"])), Rect2(f["x"], f["y"], f["w"], f["h"]))


## A fixed number in [-1, 1] per stone (no randomness: the course is the same every frame).
static func _jitter(i: int, k: int) -> float:
	var x: int = ((i + 1) * 73856093) ^ (k * 19349663)
	x = (x * 1103515245 + 12345) & 0x7fffffff
	return float(x % 2001) / 1000.0 - 1.0


## Where the altar stands now (its placement's feet), so everything drawn around it follows it when it is moved in the editor.
static func altar_at(placements: Array[Dictionary], fallback: Vector2 = Vector2(256, 180)) -> Vector2:
	for p: Dictionary in placements:
		if String(p["id"]) == "trial_altar":
			return p["feet"]
	return fallback

static func visual_placements(source: Array[Dictionary], frames: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in source:
		var item: Dictionary = p.duplicate()
		# The catalogue's anchors and sizes match the art (the chest's 40x64 canvas included), so nothing is overridden here.
		if String(p["id"]) == "trial_chest":
			item["shadow_radius"] = 0.0 # its support is the altar, not an additional body on the floor
		out.append(item)
	return out

static func draw_floor(canvas: Node2D, placements: Array[Dictionary], frames: Dictionary, atlas: Texture2D, offset: Vector2 = Vector2.ZERO) -> void:
	var lamps: Dictionary = Light.lamp_plan(placements)
	for p: Dictionary in placements:
		var name: String = String(p["type"])
		if not name.begins_with("hollow_trial_") or not frames.has(name):
			continue
		var f: Dictionary = frames[name]
		var at: Vector2 = p["feet"]
		var moon: Transform2D = Light.actor_transform(Vector2.ZERO,f,bool(p["flip"]))
		var rect: Rect2 = Rect2(Vector2.ZERO,Vector2(f["w"],f["h"]))
		var region: Rect2 = Rect2(f["x"],f["y"],f["w"],f["h"])
		canvas.draw_set_transform_matrix(Transform2D(0.0,at+offset)*moon)
		canvas.draw_texture_rect_region(atlas,rect,region,Color(0,0,0,Light.PROP_SHADOW_ALPHA))
		var local: Dictionary = LocalShadow.plan(at,lamps["points"],int(lamps["count"]),String(p["id"]),lamps["owners"])
		if not local.is_empty():
			canvas.draw_set_transform_matrix(Transform2D(local["x"],local["y"],local["at"]+offset)*moon)
			canvas.draw_texture_rect_region(atlas,rect,region,Color(0,0,0,Light.PROP_SHADOW_ALPHA))
	canvas.draw_set_transform(offset)
