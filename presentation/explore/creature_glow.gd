extends Node2D
## The healing glow: a small additive, unshaded pass over the explore scene (the same idea as the shared weapon glow), so the Stag's green
## healing motes and "+" pulses shine instead of being dimmed by the night light. It only draws halos around particles creature_effects
## already placed; no rules, no state of its own.
const Particles := preload("res://presentation/explore/creature_particles.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
const WardenEffects := preload("res://presentation/explore/warden_effects.gd")
const GLOW_KINDS: Array[String] = ["heal", "mist"]
const GREEN: Color = Color8(160, 177, 89)  # grass_5
const LIGHT: Color = Color8(194, 203, 124)  # grass_6
var halos: int = 0  # halos drawn last frame (tests and captures check the glow is really there)


func _init() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = additive


func _process(_delta: float) -> void:
	queue_redraw()


## The halos of the healing particles at `tick`: [{at, radius, colour}] (a soft outer ring and a brighter core, both additive).
static func halo_plan(bursts: Array[Dictionary], tick: int, heals: Array[Dictionary], mobs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mob: Dictionary in mobs:
		if mob["type"] != &"warden" or mob["state"] == &"dead" or not bool(mob.get("guarded", false)):
			continue
		var at: Vector2 = WardenEffects.chest_world(mob, MobView.frame(mob, [], tick))
		var pulse: float = 0.85 + 0.15 * sin(float(tick) * 0.06)
		out.append({"at":at.round(), "radius":9.0, "colour":Color(0.25,0.65,0.6,0.08*pulse)})
		out.append({"at":Vector2(mob["position"]).round(), "radius":15.0, "colour":Color(0.2,0.5,0.45,0.04*pulse)})
	for burst: Dictionary in bursts:
		if not GLOW_KINDS.has(String(burst["kind"])):
			continue
		for p: Dictionary in Particles.points(burst, tick):
			var at: Vector2 = Vector2(p["at"]).round() + Vector2(0.5, 0.5)
			var pulse: float = 0.75 + 0.25 * sin(float(tick + int(p["age"]) * 3) * 0.3)
			out.append({"at": at, "radius": 3.5, "colour": Color(GREEN, 0.16 * pulse)})
			out.append({"at": at, "radius": 1.5, "colour": Color(LIGHT, 0.35 * pulse)})
	for heal: Dictionary in heals:
		for mob: Dictionary in mobs:
			if int(mob["id"]) != int(heal["id"]) or mob["state"] == &"dead":
				continue
			var age: int = tick - int(heal["tick"])
			var at: Vector2 = (Vector2(mob["position"]) + Vector2(10, -72 - age / 2)).round() + Vector2(0.5, 0.5)
			out.append({"at": at, "radius": 5.0, "colour": Color(GREEN, 0.18)})
			out.append({"at": at, "radius": 2.5, "colour": Color(LIGHT, 0.3)})
	return out


func _draw() -> void:
	halos = 0
	var host: Node = get_parent()
	if host == null or host.get("snapshot") == null or host.get("creature_effects") == null:
		return
	var effects: RefCounted = host.get("creature_effects")
	var view: RefCounted = host.get("snapshot")
	draw_set_transform(host.call("shake_offset"))
	for halo: Dictionary in halo_plan(effects.bursts, int(view.tick), effects.heals, view.mobs):
		draw_circle(halo["at"], float(halo["radius"]), halo["colour"])
		halos += 1
