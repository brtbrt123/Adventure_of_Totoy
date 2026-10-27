extends RefCounted
## Cool high moonlight and warm practical lamps. Sources are measured on the art.
const SHADER := preload("res://presentation/common/overhead_light.gdshader")
const SHADOW_PROJECTION: Vector2 = Vector2(0.30, 0.25)
const MAX_LIGHTS: int = 16
static var _sockets: Dictionary = {}


static func make_material(scene: StringName, size: Vector2, placements: Array[Dictionary] = []) -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("world_size", size)
	result.set_shader_parameter("shaft_slope", SHADOW_PROJECTION.x / SHADOW_PROJECTION.y)
	result.set_shader_parameter("strength", 1.0)
	result.set_shader_parameter("light_colour", Vector3(0.64, 0.77, 1.0) if scene == &"village_layered" else Vector3(0.60, 0.79, 1.0))
	var practicals: Dictionary = lamp_plan(placements)
	result.set_shader_parameter("lamp_count", practicals["count"])
	result.set_shader_parameter("lamps", practicals["points"])
	return result


## Positive energy = fixture halo; negative energy = elliptical pool on the floor.
static func lamp_plan(placements: Array[Dictionary]) -> Dictionary:
	if _sockets.is_empty():
		_sockets = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/common/local_lights.json"))
	var points: PackedVector4Array = PackedVector4Array()
	for placement: Dictionary in placements:
		var sockets: Array = _sockets.get(String(placement["type"]), [])
		var feet: Vector2 = placement["feet"]
		var anchor: Vector2 = placement["anchor"]
		for socket: Dictionary in sockets:
			if points.size() + 2 > MAX_LIGHTS:
				break
			var pixel: Vector2 = Vector2(socket["pixel"][0], socket["pixel"][1])
			var dx: float = anchor.x - pixel.x if placement.get("flip", false) else pixel.x - anchor.x
			var fixture: Vector2 = feet + Vector2(dx, pixel.y - anchor.y)
			points.append(Vector4(fixture.x, fixture.y, socket["halo_radius"], socket["energy"]))
			points.append(Vector4(fixture.x, feet.y + 3.0, socket["pool_radius"], -float(socket["pool_energy"])))
	var count: int = points.size()
	points.resize(MAX_LIGHTS)
	return {"points": points, "count": count}


## Projects the current animated actor silhouette onto the same ground plane.
## Both facings keep the key light fixed; the source anchor always lands on feet.
static func actor_transform(feet: Vector2, frame: Dictionary, flipped: bool) -> Transform2D:
	var ax: float = float(frame.get("ax", float(frame["w"]) * 0.5))
	var ay: float = float(frame.get("ay", float(frame["h"]) - 4.0))
	var direction: float = -1.0 if flipped else 1.0
	var origin: Vector2 = feet.round() + Vector2(-direction * ax + ay * SHADOW_PROJECTION.x, ay * SHADOW_PROJECTION.y)
	return Transform2D(Vector2(direction, 0), -SHADOW_PROJECTION, origin)
