extends RefCounted
## Separate prop sprites. Call draw_shadows before the sorted actor/prop pass.
## Placements follow PropScene.placements; this renderer holds no collision rules.
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const GLADE_TINT: Color = Color(0.88, 0.95, 0.94)
static var _art: Dictionary = {}


static func art_metadata() -> Dictionary:
	if _art.is_empty():
		_art = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/common/prop_art.json"))["props"]
	return _art


static func drawables(placements: Array[Dictionary], frames: Dictionary, view: Rect2 = Rect2(-10000, -10000, 20000, 20000), art_overrides: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for placement: Dictionary in placements:
		var name: String = String(placement["type"])
		if not frames.has(name):
			push_error("Missing prop sprite: " + name)
			continue
		var frame: Dictionary = frames[name]
		var feet: Vector2 = placement["feet"]
		var anchor: Vector2 = placement["anchor"]
		var size: Vector2 = Vector2(frame["w"], frame["h"])
		var source: Rect2 = Rect2(frame["x"], frame["y"], size.x, size.y)
		# Tool-only contract tests supply unpadded frames without atlas anchors.
		var metadata: Dictionary = art_overrides.get(name, art_metadata().get(name, {})) if frame.has("ax") else {}
		var cast_names: Dictionary = metadata.get("cast_shadow", {})
		var cast_name: String = String(cast_names.get("flipped" if bool(placement.get("flip", false)) else "normal", ""))
		var cast_frame: Dictionary = frames.get(cast_name, {})
		if metadata.has("trim"):
			var trim: Array = metadata["trim"]
			source.position += Vector2(trim[0], trim[1])
			size = Vector2(trim[2], trim[3])
			source.size = size
		var flip: bool = bool(placement.get("flip", false))
		var origin: Vector2 = feet.round() - anchor
		if flip:
			origin.x = feet.round().x - (size.x - anchor.x)
		if frame.has("ax"):
			origin = origin.round()  # shared half-pixel anchors snap to the world pixel grid
		var rect: Rect2 = Rect2(origin, size)
		var visible_rect: Rect2 = rect
		if not cast_frame.is_empty():
			var cast_origin: Vector2 = (feet - Vector2(cast_frame["ax"], cast_frame["ay"])).round()
			visible_rect = visible_rect.merge(Rect2(cast_origin, Vector2(cast_frame["w"], cast_frame["h"])))
		if not view.intersects(visible_rect):
			continue
		var base_size: Vector2 = placement.get("size", size)
		var shadow_radius: float = float(placement.get("shadow_radius", minf(22.0, base_size.x * 0.2)))
		var item: Dictionary = {"kind": &"prop", "id": placement["id"], "at": feet,
			"rect": rect, "src": source, "type": placement["type"],
			"flip": flip, "shadow_at": feet, "shadow_origin": origin,
			"shadow_plan": metadata.get("contact_shadow", {}), "cast_frame": cast_frame, "shadow_radius": shadow_radius}
		if metadata.has("sort_strips"):
			var first: bool = true
			for strip: Array in metadata["sort_strips"]:
				var part: Dictionary = item.duplicate()
				var x: float = float(strip[0])
				var width: float = float(strip[1])
				part["src"] = Rect2(source.position + Vector2(x, 0), Vector2(width, size.y))
				part["rect"] = Rect2(origin + Vector2(size.x - x - width if flip else x, 0), Vector2(width, size.y))
				part["at"] = Vector2(feet.x, feet.y + float(strip[2]) - anchor.y)
				part["strip"] = int(x)
				part["shadow_radius"] = shadow_radius if first else 0.0
				first = false
				result.append(part)
		else:
			result.append(item)
	return result


## Deterministic tie: props before actors at the same base row (actor stands in front).
static func sorted_with_actors(props: Array[Dictionary], actors: Array[Dictionary]) -> Array[Dictionary]:
	var items: Array[Dictionary] = props.duplicate()
	items.append_array(actors)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["at"].y != b["at"].y:
			return a["at"].y < b["at"].y
		if (a["kind"] == &"prop") != (b["kind"] == &"prop"):
			return a["kind"] == &"prop"
		if String(a["id"]) == String(b["id"]):
			return int(a.get("strip", 0)) < int(b.get("strip", 0))
		return String(a["id"]) < String(b["id"]))
	return items


static func draw_shadows(canvas: CanvasItem, props: Array[Dictionary], strength: float = 0.4, atlas: Texture2D = null) -> void:
	for item: Dictionary in props:
		draw_shadow(canvas, item, strength, atlas)


## Short contact shadows follow each visible base, including separated gate feet.
## Source-space rows never join across a doorway. Only the first log strip casts.
static func draw_shadow(canvas: CanvasItem, item: Dictionary, strength: float = 0.25, atlas: Texture2D = null) -> void:
	if float(item["shadow_radius"]) <= 0.0:
		return
	var cast_frame: Dictionary = item.get("cast_frame", {})
	if atlas != null and not cast_frame.is_empty():
		# Mirrored objects have their own mask: key light still comes from upper-left.
		var at: Vector2 = item.get("shadow_at", item["at"])
		var cast_origin: Vector2 = (at - Vector2(cast_frame["ax"], cast_frame["ay"])).round()
		# Black vertex colour tags this draw as the shader's separate shadow pass.
		canvas.draw_texture_rect_region(atlas, Rect2(cast_origin, Vector2(cast_frame["w"], cast_frame["h"])), Rect2(cast_frame["x"], cast_frame["y"], cast_frame["w"], cast_frame["h"]), Color(0, 0, 0, EnvironmentLight.PROP_SHADOW_ALPHA))
	var plan: Dictionary = item.get("shadow_plan", {})
	if plan.is_empty():
		ActorShadow.draw(canvas, item.get("shadow_at", item["at"]), item["shadow_radius"], strength)
		return
	var origin: Vector2 = item["shadow_origin"]
	var width: float = float(plan["size"][0])
	for key: String in ["edge", "core"]:
		var alpha: float = minf(0.24, strength) if key == "core" else minf(0.10, strength * 0.4)
		var colour: Color = Color(ActorShadow.INK, alpha)
		for row: Array in plan[key]:
			var x: float = width - float(row[0]) - float(row[2]) if item["flip"] else float(row[0])
			canvas.draw_rect(Rect2(origin + Vector2(x, row[1]), Vector2(row[2], 1)), colour)


static func draw(canvas: CanvasItem, item: Dictionary, atlas: Texture2D, tint: Color = GLADE_TINT) -> void:
	var rect: Rect2 = item["rect"]
	if item["flip"]:
		# Godot flips the texture for a negative width, keeping the draw origin.
		# Advancing the origin as well shifts the sprite away from its collider.
		rect.size.x = -rect.size.x
	canvas.draw_texture_rect_region(atlas, rect, item["src"], tint)
