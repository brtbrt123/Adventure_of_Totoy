extends RefCounted
## Source-scene art coordinates and silhouette shadows; positions/solidity remain core-owned.
const Light := preload("res://presentation/common/environment_light.gd")
const LocalShadow := preload("res://presentation/common/local_prop_shadows.gd")
static func draw_ring(canvas: Node2D, at: Vector2, colours: Dictionary) -> void:
	# A worn course of flush flagstones around the altar: irregular, broken and in ground colours, so it reads as old paving and never as
	# a ring around the player (only real warnings may look like that). Decoration only: no collision, no telegraph.
	for i: int in 22:
		if i in [3, 4, 9, 15, 16, 20]:
			continue  # missing stones: the course is broken, not a closed shape
		var angle: float = TAU * (float(i) + _jitter(i, 1) * 0.35) / 22.0
		var radius: float = 37.0 + _jitter(i, 2) * 4.0
		var width: float = 0.07 + _jitter(i, 3) * 0.04
		var depth: float = 4.0 + _jitter(i, 4) * 3.0
		var stone: PackedVector2Array = []
		for pair: Vector2 in [Vector2(-width, radius), Vector2(width, radius), Vector2(width, radius + depth), Vector2(-width, radius + depth)]:
			stone.append((at + Vector2(cos(angle + pair.x) * pair.y, sin(angle + pair.x) * pair.y * 0.6)).round())
		canvas.draw_colored_polygon(stone, colours["9"] if i % 4 == 0 else colours["a"])
		canvas.draw_polyline(PackedVector2Array([stone[0], stone[1]]), colours["b"], 1.0, false)


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
