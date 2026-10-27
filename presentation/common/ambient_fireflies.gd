extends RefCounted
## Cosmetic world-space motes. No gameplay state or random generator is touched.
const EMISSIVE_ALPHA: float = 0.99

static func supports(scene: StringName) -> bool:
	return scene in [&"forest", &"glade", &"forest_layered", &"glade_layered"]


static func drawables(scene: StringName, tick: int, size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not supports(scene):
		return out
	var time: float = float(tick) / 60.0
	for index: int in range(22):
		var phase: float = float(index) * 2.399963
		var home: Vector2 = Vector2(24.0 + fmod(float(index * 137), size.x - 48.0), 42.0 + fmod(float(index * 79), size.y - 66.0))
		var base: Vector2 = home + Vector2(sin(time * 0.43 + phase) * 9.0, cos(time * 0.31 + phase) * 6.0)
		var pulse: float = pow(0.5 + 0.5 * sin(time * 1.4 + phase), 2.0)
		out.append({"kind": &"firefly", "id": StringName("firefly_%02d" % index), "at": base, "pixel": (base - Vector2(0, 9.0 + sin(time + phase) * 3.0)).round(), "pulse": pulse})
	return out


static func draw(canvas: CanvasItem, item: Dictionary) -> void:
	var pulse: float = item["pulse"]
	if pulse < 0.08:
		return
	var pixel: Vector2 = item["pixel"]
	canvas.draw_rect(Rect2(pixel - Vector2.ONE * 2.0, Vector2.ONE * 5.0), Color(0.58, 0.79, 0.66, pulse * 0.10))
	# The shader recognizes this alpha as an emissive visual pass; source art stays hard-alpha.
	canvas.draw_rect(Rect2(pixel, Vector2.ONE), Color(0.72, 0.90, 0.76, EMISSIVE_ALPHA) * Color(pulse, pulse, pulse, 1.0))
