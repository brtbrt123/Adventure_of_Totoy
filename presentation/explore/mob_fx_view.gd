extends RefCounted
## The live part of the mobs' attacks in the Star Staff's style (owner 2026-11-02, phase 4 of "redo all effects ... except the
## golem"): what their frames (tools/art/make_mob_fx_art.py, and the Warden's reviewed ones) and the creature particles cannot
## do. It takes the same bursts creature_effects.gd emits (slam, crash, kick, roots, roar, chant, release, heal, reveal, mist,
## pop, orb_trail and the Warden's chips, stomp, crash, roots) and adds stones that are thrown up and bounce, dust kicked out in
## rings, rings on the ground, light for the road's lamps and a shake for the heavy blows.
## Two particle sets: earth (dust, stones, lit by the scene) and glow (sparks, motes, emissive). Particles live on the ground
## plane (fx_particles.gd: x, gy = the ground line under them, z = height). Owned by creature_effects.gd. Pure presentation.
const FxParticles := preload("res://presentation/common/fx_particles.gd")
const EMISSIVE_ALPHA: float = preload("res://presentation/common/ambient_fireflies.gd").EMISSIVE_ALPHA

const DUST: Array = ["d", "c"]
const STONE_DUST: Array = ["i", "h"]
const GLOW: Array = ["1", "p", "u", "t", "k"]
const LEAF: Array = ["6", "5", "4"]
const SPARK: Array = ["1", "p", "j", "i"]
const EARTH_RING: Array = ["d", "c", "b", "9", "8"]
const TEAL_LIGHT: Vector3 = Vector3(0.45, 0.95, 0.9)
const WARM_LIGHT: Vector3 = Vector3(1.0, 0.8, 0.55)

var earth: FxParticles = FxParticles.new(71)
var glow: FxParticles = FxParticles.new(73)
## Rings on the ground: {at, tick, life, rx0, rx1, colours, emissive}.
var rings: Array[Dictionary] = []
## Short lights: {at, tick, life, radius, strength, colour}.
var lights: Array[Dictionary] = []
var _shake: int = 0
var _last_tick: int = -1


func clear() -> void:
	earth.clear()
	glow.clear()
	rings.clear()
	lights.clear()
	_shake = 0


## A burst creature_effects.gd started: `kind` as it names them, `at` where, `extra` its own data (dir, size, ...).
func burst(kind: String, at: Vector2, tick: int, extra: Dictionary = {}) -> void:
	var rng: RandomNumberGenerator = earth.rng
	var dir: Vector2 = extra.get("dir", Vector2.ZERO)
	match kind:
		"slam":  # the stag's slam: stones thrown up from the cone, dust rolling out, the ground rings
			for i: int in 8:
				var a: float = rng.randf_range(0.0, TAU)
				var p: Dictionary = earth.add(&"rock", at.x + cos(a) * 6.0, at.y + sin(a) * 2.5, 1.0,
					Vector3(cos(a) * rng.randf_range(0.6, 1.6) + dir.x * 0.6, sin(a) * 0.4, rng.randf_range(1.6, 2.8)), rng.randi_range(30, 44))
				p["shape"] = rng.randi_range(0, 7)
			earth.ring(&"dust", at.x, at.y, 10.0, 10, Vector2(0.03, 0.08), Vector2i(16, 26), DUST, 0.7, Vector2(1.5, 3.8))
			rings.append({"at": at, "tick": tick, "life": 14, "rx0": 6.0, "rx1": 34.0, "colours": EARTH_RING, "emissive": false})
			lights.append({"at": at, "tick": tick, "life": 10, "radius": 70.0, "strength": 0.7, "colour": WARM_LIGHT})
			_shake = maxi(_shake, 5)
		"crash", "stomp":  # a boar or the Warden hitting the ground: dust out to the sides, a few stones, a ring for the Warden
			var heavy: bool = kind == "stomp" or bool(extra.get("warden", false))
			earth.ring(&"dust", at.x, at.y, 6.0 if heavy else 3.0, 8 if heavy else 5, Vector2(0.03, 0.08), Vector2i(14, 22), STONE_DUST if heavy else DUST, 0.6, Vector2(1.4, 3.4))
			for i: int in (4 if heavy else 3):
				var a: float = rng.randf_range(PI, TAU)
				var p: Dictionary = earth.add(&"rock", at.x, at.y, 2.0, Vector3(cos(a) * rng.randf_range(0.5, 1.4), sin(a) * 0.3, rng.randf_range(1.2, 2.2)), rng.randi_range(26, 38))
				p["shape"] = rng.randi_range(0, 7)
			if heavy:
				rings.append({"at": at, "tick": tick, "life": 12, "rx0": 5.0, "rx1": 26.0, "colours": EARTH_RING, "emissive": false})
			_shake = maxi(_shake, 4 if heavy else 2)
		"kick":  # the stag's charge kicking up the ground behind it
			earth.spray(&"dust", at.x, at.y, 0.0, 3, dir if dir.length() > 0.01 else Vector2.LEFT, 0.6, Vector2(0.4, 1.0), Vector2(0.03, 0.07), Vector2i(12, 18), DUST, Vector2(1.2, 2.8))
		"roots", "roar":
			earth.ring(&"dust", at.x, at.y, 4.0, 6, Vector2(0.03, 0.07), Vector2i(14, 20), DUST, 0.5, Vector2(1.2, 2.8))
			if kind == "roots":
				glow.burst(&"mote", at.x, at.y, 6.0, 4, Vector2(0.2, 0.5), Vector2(0.3, 0.6), Vector2i(16, 24), LEAF)
			else:
				rings.append({"at": at, "tick": tick, "life": 14, "rx0": 6.0, "rx1": 30.0, "colours": EARTH_RING, "emissive": false})
				_shake = maxi(_shake, 3)
		"chant", "heal", "reveal":
			glow.burst(&"mote", at.x, at.y + 8.0, 8.0, 3 if kind == "chant" else 6, Vector2(0.2, 0.6), Vector2(0.3, 0.7), Vector2i(16, 26), GLOW)
			if kind != "chant":
				lights.append({"at": at, "tick": tick, "life": 12, "radius": 40.0, "strength": 0.6, "colour": TEAL_LIGHT})
		"release":
			glow.burst(&"spark", at.x, at.y + 10.0, 10.0, 12, Vector2(0.8, 2.0), Vector2(0.4, 1.4), Vector2i(10, 18), GLOW)
			lights.append({"at": at, "tick": tick, "life": 14, "radius": 60.0, "strength": 1.0, "colour": TEAL_LIGHT})
		"pop":
			glow.burst(&"spark", at.x, at.y + 8.0, 8.0, 8, Vector2(0.6, 1.6), Vector2(0.3, 1.2), Vector2i(8, 14), GLOW)
			lights.append({"at": at, "tick": tick, "life": 8, "radius": 36.0, "strength": 0.8, "colour": TEAL_LIGHT})
		"orb_trail":
			glow.add(&"mote", at.x, at.y + 8.0, 8.0, Vector3(0, 0, 0.2), rng.randi_range(8, 12), GLOW)
		"mist":
			earth.add(&"wisp", at.x + rng.randf_range(-6.0, 6.0), at.y, 2.0, Vector3(0, 0, 0.4), rng.randi_range(14, 20), ["g", "h", "i"])
		"chips":  # a blow on the Warden's guard: stone chips and sparks off its chest
			var feet: float = at.y + 20.0
			earth.burst(&"shard", at.x, feet, 20.0, 5, Vector2(0.6, 1.6), Vector2(1.0, 2.2), Vector2i(20, 30), ["j", "i", "h", "g"])
			glow.burst(&"spark", at.x, feet, 20.0, 8, Vector2(1.0, 2.4), Vector2(0.4, 1.6), Vector2i(8, 14), SPARK)


## One tick older (30 Hz particles).
func step(tick: int) -> void:
	if tick == _last_tick:
		return
	_last_tick = tick
	if tick % 2 == 0:
		earth.step()
		glow.step()
	for i: int in range(rings.size() - 1, -1, -1):
		if tick - int(rings[i]["tick"]) >= int(rings[i]["life"]):
			rings.remove_at(i)
	for i: int in range(lights.size() - 1, -1, -1):
		if tick - int(lights[i]["tick"]) >= int(lights[i]["life"]):
			lights.remove_at(i)


## The shake the heavy blows asked for since the last call (the scene shakes the view).
func take_shake() -> int:
	var out: int = _shake
	_shake = 0
	return out


## Under the characters: the rings on the ground and the dust.
func draw_ground(canvas: CanvasItem, colors: Dictionary, frames: Dictionary, atlas: Texture2D, tick: int) -> void:
	for r: Dictionary in rings:
		var f: float = float(tick - int(r["tick"])) / float(r["life"])
		var rx: float = lerpf(float(r["rx0"]), float(r["rx1"]), 1.0 - pow(1.0 - f, 3.0))
		FxParticles.ground_ring(canvas, colors, Vector2(r["at"]).round(), rx, 1.0 - f, EMISSIVE_ALPHA if bool(r["emissive"]) else 1.0, r["colours"])
	earth.draw(canvas, colors, frames, atlas, 1.0, true)
	glow.draw(canvas, colors, frames, atlas, EMISSIVE_ALPHA, true)


## Over the characters: stones in the air, chips, sparks, motes, wisps.
func draw_air(canvas: CanvasItem, colors: Dictionary, frames: Dictionary, atlas: Texture2D) -> void:
	earth.draw(canvas, colors, frames, atlas, 1.0, false)
	glow.draw(canvas, colors, frames, atlas, EMISSIVE_ALPHA, false)


## Lights for the road's lamps: the short flashes of slams, releases and pops.
func lamps(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in lights:
		var f: float = float(tick - int(l["tick"])) / float(l["life"])
		var at: Vector2 = l["at"]
		out.append({"point": Vector4(at.x, at.y, float(l["radius"]), float(l["strength"]) * pow(1.0 - f, 1.5)), "colour": l["colour"], "core": l["colour"]})
	return out
