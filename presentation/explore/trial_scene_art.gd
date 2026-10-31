extends RefCounted
## Source-scene art coordinates and silhouette shadows; positions/solidity remain core-owned.
const Light := preload("res://presentation/common/environment_light.gd")
const LocalShadow := preload("res://presentation/common/local_prop_shadows.gd")
static func draw_ring(canvas: Node2D, at: Vector2, colours: Dictionary) -> void:
	# Flush flagstone/rune course: decoration, never a telegraph or collision boundary.
	for i: int in 18:
		var angle: float = TAU*i/18.0
		var stone: PackedVector2Array = []
		for pair: Vector2 in [Vector2(-.10,35),Vector2(.10,35),Vector2(.10,42),Vector2(-.10,42)]:
			stone.append((at+Vector2(cos(angle+pair.x)*pair.y,sin(angle+pair.x)*pair.y*.6)).round())
		canvas.draw_colored_polygon(stone,colours["e"] if i%3==0 else colours["f"])
		canvas.draw_polyline(PackedVector2Array([stone[0],stone[1],stone[2]]),colours["g"],1.0,false)
		if i%3==0:
			var rune: Vector2 = at+Vector2(cos(angle)*38,sin(angle)*23)
			canvas.draw_rect(Rect2(rune.round(),Vector2(2,1)),colours["t"])

static func visual_placements(source: Array[Dictionary], frames: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in source:
		var item: Dictionary = p.duplicate()
		var name: String = String(p["type"])
		if name.begins_with("hollow_trial_") and not bool(p["solid"]) and frames.has(name):
			# Decorative source canvas may include transparent support height (the chest resting on the altar).
			# No physical shape or world position is changed.
			var f: Dictionary = frames[name]
			item["anchor"] = Vector2(f["ax"],f["ay"])
			item["size"] = Vector2(f["w"],f["h"])
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
