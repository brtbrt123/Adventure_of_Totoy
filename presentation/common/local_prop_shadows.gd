extends RefCounted
## Presentation-only: shear the existing guarded silhouette mask away from the nearest local light.
const Light := preload("res://presentation/common/environment_light.gd")
static func plan(at: Vector2, lights: PackedVector4Array, count: int) -> Dictionary:
	var nearest: float = INF
	var away: Vector2 = Vector2.ZERO
	for i: int in count:
		var lamp: Vector4 = lights[i]
		if lamp.w >= 0.0: continue # ground footprint of each practical
		var delta: Vector2 = at - Vector2(lamp.x,lamp.y)
		var distance: float = delta.length()
		if distance < 8.0 or distance > lamp.z * 1.4 or distance >= nearest: continue
		nearest = distance
		away = delta.normalized()
	if nearest == INF: return {}
	# Original mask: u=x+height*.30, v=height*.25. Reproject its height component only,
	# retaining each root's ground x and the feet anchor. This is a soft parallel-ray approximation.
	var slope: float = 0.42
	var depth: float = away.y*slope/0.25
	# A finite soft source keeps a thin footprint even for a nearly horizontal ray.
	if absf(depth) < 0.12: depth = -0.12 if depth < 0.0 else 0.12
	return {"x":Vector2.RIGHT,"y":Vector2((away.x*slope-0.30)/0.25,depth),"at":at.round()}
static func draw(canvas: CanvasItem, props: Array[Dictionary], placements: Array[Dictionary], atlas: Texture2D, offset: Vector2) -> void:
	var lights: Dictionary = Light.lamp_plan(placements)
	for prop: Dictionary in props:
		if prop["kind"] != &"prop" or float(prop.get("shadow_radius",0)) <= 0: continue
		var frame: Dictionary = prop.get("cast_frame",{})
		if frame.is_empty(): continue
		var projection: Dictionary = plan(prop.get("shadow_at",prop["at"]),lights["points"],int(lights["count"]))
		if projection.is_empty(): continue
		canvas.draw_set_transform_matrix(Transform2D(projection["x"],projection["y"],projection["at"]+offset))
		canvas.draw_texture_rect_region(atlas,Rect2(Vector2(-frame["ax"],-frame["ay"]),Vector2(frame["w"],frame["h"])),Rect2(frame["x"],frame["y"],frame["w"],frame["h"]),Color(0,0,0,Light.PROP_SHADOW_ALPHA))
	canvas.draw_set_transform(offset)
