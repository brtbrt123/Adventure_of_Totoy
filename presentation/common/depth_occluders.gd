extends RefCounted
## Depth occluders: the tall props of the painted grounds (gates, pillars, trunks, stones, pedestals, house walls, ...)
## drawn again over the actors standing behind them. The ground is one flat picture, so without them an actor whose
## feet are north of a prop's base was drawn over the whole prop and looked like he stood inside it.
##
## tools/art/make_depth_occluders.py cuts each occluder (a hand-authored polygon in presentation/common/depth_occluders.json,
## tight around the part of the prop that rises above its base) out of the scene's ground into an atlas with hard alpha:
## presentation/common/occluders/<scene>_occluders.png + .json (id, base_y, rect in the world, atlas position,
## hide_when). The scenes put every occluder into their y-sorted draw list with the sort key base_y - SORT_BIAS
## (drawables()), so an occluder covers every actor whose feet are north of its base line and stays under every actor
## on or south of it. Where nobody stands behind it, it redraws exactly the ground's own pixels (invisible).
## Used by presentation/explore/explore_scene.gd (village, forest, glade) and presentation/arena/arena.gd (arena).
## Presentation only: the colliders (core layouts) keep actors out of the props' bases; nothing here is a game rule.

const DIR: String = "res://presentation/common/occluders/"
## An actor is behind an occluder when its feet are more than this north of the base line (feet on the line: in front).
const SORT_BIAS: float = 0.5

static var _cache: Dictionary = {}


## The occluders of `scene_id`: {"texture": Texture2D, "items": [{id, base_y, rect: Rect2 (world), src: Rect2 (atlas),
## hide_when: StringName}]}, or {} when the scene has none (or its files are missing). Loaded once per scene.
static func scene_data(scene_id: StringName) -> Dictionary:
	if _cache.has(scene_id):
		return _cache[scene_id]
	var data: Dictionary = {}
	var path: String = DIR + String(scene_id) + "_occluders.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var texture: Texture2D = load(String(parsed.get("texture", ""))) as Texture2D
			if texture != null:
				var items: Array[Dictionary] = []
				for o: Dictionary in parsed.get("occluders", []):
					var r: Array = o["rect"]
					var a: Array = o["atlas"]
					var rect: Rect2 = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
					items.append({"id": StringName(o["id"]), "base_y": float(o["base_y"]), "rect": rect,
						"src": Rect2(float(a[0]), float(a[1]), rect.size.x, rect.size.y), "hide_when": StringName(o.get("hide_when", ""))})
				data = {"texture": texture, "items": items}
	_cache[scene_id] = data
	return data


## The occluders to put into a scene's y-sorted draw list this frame: those intersecting `view` whose hide_when flag is
## not set in `flags` (e.g. {&"gate_open": true} hides the forest's root gate while it is open). Each is
## {"kind": &"occluder", "occluder": item, "at": Vector2(rect centre x, base_y - SORT_BIAS)}: sort by at.y like actors.
static func drawables(scene_id: StringName, flags: Dictionary = {}, view: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Dictionary = scene_data(scene_id)
	if data.is_empty():
		return out
	for item: Dictionary in data["items"]:
		if item["hide_when"] != &"" and bool(flags.get(item["hide_when"], false)):
			continue
		var rect: Rect2 = item["rect"]
		if not view.intersects(rect):
			continue
		out.append({"kind": &"occluder", "occluder": item, "at": Vector2(rect.get_center().x, float(item["base_y"]) - SORT_BIAS)})
	return out


## Draws one occluder drawable (from drawables()) of `scene_id` on `canvas`; `modulate` must match the ground's (the
## arena draws its ground at 0.92).
static func draw(canvas: CanvasItem, scene_id: StringName, drawable: Dictionary, modulate: Color = Color.WHITE) -> void:
	var data: Dictionary = scene_data(scene_id)
	if data.is_empty():
		return
	var item: Dictionary = drawable["occluder"]
	canvas.draw_texture_rect_region(data["texture"], item["rect"], item["src"], modulate)


## True when an actor with feet at `feet_y` is drawn behind (under) an occluder whose base is `base_y`.
static func is_behind(feet_y: float, base_y: float) -> bool:
	return feet_y < base_y - SORT_BIAS
