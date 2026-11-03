extends RefCounted
## The live part of the aspects in the Star Staff's style (owner 2026-11-02, phase 3 of "redo all effects ... except the golem"):
## what their frames (tools/art/make_aspect_fx_art.py) cannot do.
##   Spirit Lantern  dust and motes when it is set down, its pool of light on the road while it burns, motes rising across the
##                   pool and a flash at each pulse, motes when it goes out.
##   Phantom Cut     lilac motes rising off him while it runs and a lilac light; a ring and motes when it starts; lilac sparks
##                   where an echo lands.
##   Echo Step       teal motes and a ring where the echo is placed; a streak of motes along the recall and a flash at both
##                   ends; motes where it fades.
##   Stone Ward      stone dust and teal motes as it rises; teal sparks where it blocks; at the release, stones thrown out,
##                   dust round the ring and a big teal light.
##   Sprint          dust kicked up at his feet and wind motes streaming off him while he runs; a burst of dust as it starts.
##   Skills          gold sparks off Breaking Edge, wind streaks off Gale Cut, lilac motes off Moon Cleave.
## Particles live on the ground plane (fx_particles.gd: x, gy = the ground line under them, z = height). Owned by hero_fx.gd,
## which calls it from the core's events and steps it with the hero each tick. Pure presentation.
const FxParticles := preload("res://presentation/common/fx_particles.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")

const LILAC: Array = ["1", "p", "v", "l", "k"]
const TEAL: Array = ["1", "p", "u", "t", "k"]
const WIND: Array = ["1", "p", "o", "n", "m"]
const GOLD: Array = ["1", "x", "x", "y", "A"]
const DUST: Array = ["j", "i"]
const STONE: Array = ["i", "h", "g", "f"]
const LILAC_LIGHT: Vector3 = Vector3(0.7, 0.55, 1.0)
const TEAL_LIGHT: Vector3 = Vector3(0.45, 0.95, 0.9)
const CHEST: float = 14.0

var particles: FxParticles = FxParticles.new(59)
## Rings of light on the ground: {at, tick, life, rx0, rx1, colours}.
var rings: Array[Dictionary] = []
## Short lights: {at, tick, life, radius, strength, colour}.
var lights: Array[Dictionary] = []
## The lanterns burning now (their pools light the road): position by the event's lantern id or position.
var lanterns: Dictionary = {}
var _last_tick: int = -1
var _hero_at: Vector2 = Vector2.ZERO
var _phantom: bool = false


func clear() -> void:
	particles.clear()
	rings.clear()
	lights.clear()
	lanterns.clear()
	_phantom = false


## An aspect's core event (lantern_*, phantom_*, echo_*, ward_*, sprint_*); `hero` is the hero now, `contact` where an echo lands.
func on_event(tick: int, event: GameEvent, hero: Snapshots.EntitySnapshot, contact: Vector2 = Vector2.ZERO) -> void:
	var rng: RandomNumberGenerator = particles.rng
	var data: Dictionary = event.data
	match event.type:
		&"lantern_placed":
			var at: Vector2 = data.get("position", hero.position)
			lanterns[_key(data, at)] = at
			particles.ring(&"dust", at.x, at.y, 3.0, 5, Vector2(0.03, 0.08), Vector2i(14, 20), DUST, 0.5, Vector2(1.2, 2.8))
			particles.burst(&"mote", at.x, at.y, 8.0, 8, Vector2(0.2, 0.6), Vector2(0.3, 0.7), Vector2i(18, 30), TEAL)
		&"lantern_pulse":
			var at: Vector2 = data.get("position", hero.position)
			lanterns[_key(data, at)] = at
			particles.ring(&"mote", at.x, at.y, 30.0, 12, Vector2(0.4, 0.9), Vector2i(18, 30), TEAL, 0.0)
			lights.append({"at": at, "tick": tick, "life": 12, "radius": 70.0, "strength": 1.0, "colour": TEAL_LIGHT})
		&"lantern_expired":
			var at: Vector2 = data.get("position", hero.position)
			lanterns.erase(_key(data, at))
			particles.burst(&"mote", at.x, at.y, 10.0, 10, Vector2(0.2, 0.7), Vector2(0.2, 0.6), Vector2i(16, 26), TEAL)
		&"phantom_cut_started":
			particles.ring(&"mote", hero.position.x, hero.position.y, 10.0, 14, Vector2(0.5, 1.0), Vector2i(18, 30), LILAC, 0.4)
			rings.append({"at": hero.position, "tick": tick, "life": 14, "rx0": 5.0, "rx1": 24.0, "colours": LILAC})
			lights.append({"at": hero.position - Vector2(0, CHEST), "tick": tick, "life": 14, "radius": 64.0, "strength": 1.1, "colour": LILAC_LIGHT})
		&"phantom_cut_ended":
			particles.burst(&"mote", hero.position.x, hero.position.y, CHEST, 8, Vector2(0.2, 0.6), Vector2(0.2, 0.5), Vector2i(14, 22), LILAC)
		&"phantom_echo":
			if contact != Vector2.ZERO:
				var feet: float = contact.y + 12.0
				particles.burst(&"spark", contact.x, feet, 12.0, 10, Vector2(0.8, 2.2), Vector2(0.5, 1.6), Vector2i(8, 16), LILAC)
				lights.append({"at": contact, "tick": tick, "life": 8, "radius": 40.0, "strength": 0.8, "colour": LILAC_LIGHT})
		&"echo_placed":
			var at: Vector2 = data.get("position", hero.position)
			particles.ring(&"mote", at.x, at.y, 8.0, 10, Vector2(0.4, 0.9), Vector2i(16, 26), TEAL, 0.2)
			rings.append({"at": at, "tick": tick, "life": 12, "rx0": 4.0, "rx1": 16.0, "colours": TEAL})
		&"echo_recall":
			var from: Vector2 = data.get("from", hero.position)
			var to: Vector2 = data.get("to", hero.position)
			var along: Vector2 = to - from
			for i: int in 16:
				var at: Vector2 = from + along * rng.randf()
				particles.add(&"streak", at.x, at.y, CHEST + rng.randf_range(-7.0, 7.0), Vector3(along.normalized().x * rng.randf_range(0.6, 1.4), along.normalized().y * 0.4, 0.0),
					rng.randi_range(6, 10), TEAL)
			for at: Vector2 in [from, to]:
				particles.burst(&"spark", at.x, at.y, CHEST, 6, Vector2(0.6, 1.6), Vector2(0.4, 1.2), Vector2i(8, 14), TEAL)
				lights.append({"at": at - Vector2(0, CHEST), "tick": tick, "life": 8, "radius": 48.0, "strength": 0.9, "colour": TEAL_LIGHT})
		&"echo_expired":
			var at: Vector2 = data.get("position", hero.position)
			particles.burst(&"mote", at.x, at.y, CHEST, 8, Vector2(0.2, 0.6), Vector2(0.2, 0.5), Vector2i(14, 22), TEAL)
		&"ward_raised":
			var front: Vector2 = hero.position + Vector2(-14.0 if hero.facing.x < -0.3 else 14.0, 0.0)
			particles.ring(&"dust", front.x, front.y, 4.0, 5, Vector2(0.03, 0.08), Vector2i(14, 22), DUST, 0.4, Vector2(1.2, 3.0))
			particles.burst(&"mote", front.x, front.y, 16.0, 8, Vector2(0.2, 0.6), Vector2(0.3, 0.7), Vector2i(16, 26), TEAL)
		&"ward_blocked":
			var front: Vector2 = hero.position + Vector2(-14.0 if hero.facing.x < -0.3 else 14.0, 0.0)
			particles.burst(&"spark", front.x, front.y, 16.0, 10, Vector2(0.8, 2.2), Vector2(0.5, 1.6), Vector2i(8, 16), TEAL)
			lights.append({"at": front - Vector2(0, 16), "tick": tick, "life": 8, "radius": 44.0, "strength": 0.9, "colour": TEAL_LIGHT})
		&"ward_released":
			var at: Vector2 = data.get("position", hero.position)
			var radius: float = float(data.get("radius", 48.0))
			for i: int in 10:  # stones thrown out from the ring
				var a: float = rng.randf_range(0.0, TAU)
				var p: Dictionary = particles.add(&"rock", at.x + cos(a) * radius * 0.4, at.y + sin(a) * radius * 0.16, 1.0,
					Vector3(cos(a) * rng.randf_range(0.8, 1.8), sin(a) * 0.5, rng.randf_range(1.4, 2.6)), rng.randi_range(30, 45))
				p["shape"] = rng.randi_range(0, 5)
			particles.ring(&"dust", at.x, at.y, radius * 0.6, 12, Vector2(0.03, 0.08), Vector2i(16, 26), DUST, 0.6, Vector2(1.5, 3.5))
			particles.burst(&"spark", at.x, at.y, 10.0, 16, Vector2(1.2, 3.0), Vector2(0.6, 1.8), Vector2i(10, 18), TEAL)
			lights.append({"at": at - Vector2(0, 10), "tick": tick, "life": 16, "radius": 110.0, "strength": 1.6, "colour": TEAL_LIGHT})
		&"sprint_started":
			var back: Vector2 = Vector2(1.0 if hero.facing.x < -0.3 else -1.0, 0.0)
			particles.spray(&"dust", hero.position.x, hero.position.y, 0.0, 6, back, 0.8, Vector2(0.5, 1.2), Vector2(0.03, 0.08), Vector2i(14, 22), DUST, Vector2(1.2, 3.4))
			rings.append({"at": hero.position, "tick": tick, "life": 10, "rx0": 4.0, "rx1": 14.0, "colours": WIND})


## A skill was released (Breaking Edge, Gale Cut, Moon Cleave): its particles where it starts, along `facing`.
func skill(tick: int, skill_id: StringName, hero: Snapshots.EntitySnapshot) -> void:
	var at: Vector2 = hero.position
	var facing: Vector2 = hero.facing if hero.facing.length() > 0.01 else Vector2.RIGHT
	match skill_id:
		&"breaking_edge":
			particles.spray(&"spark", at.x + facing.x * 14.0, at.y + facing.y * 6.0, CHEST, 16, facing, 0.9, Vector2(1.2, 3.0), Vector2(0.6, 2.0), Vector2i(10, 18), GOLD)
			lights.append({"at": at + facing * 14.0 - Vector2(0, CHEST), "tick": tick, "life": 10, "radius": 56.0, "strength": 1.1, "colour": Vector3(1.0, 0.82, 0.4)})
		&"gale_cut":
			for i: int in 10:
				var side: Vector2 = Vector2(-facing.y, facing.x) * particles.rng.randf_range(-10.0, 10.0)
				particles.add(&"streak", at.x + side.x, at.y + side.y * 0.4, CHEST + particles.rng.randf_range(-6.0, 6.0),
					Vector3(facing.x * particles.rng.randf_range(1.8, 3.0), facing.y * 1.0, 0.0), particles.rng.randi_range(6, 10), WIND)
		&"moon_cleave":
			particles.spray(&"mote", at.x, at.y, CHEST, 12, facing, 0.6, Vector2(0.8, 1.8), Vector2(0.2, 0.6), Vector2i(16, 26), LILAC)
			lights.append({"at": at - Vector2(0, CHEST), "tick": tick, "life": 12, "radius": 60.0, "strength": 1.0, "colour": LILAC_LIGHT})


## One tick older (30 Hz particles); while Phantom Cut or Sprint runs, their particles keep coming off him.
func step(tick: int, hero: Snapshots.EntitySnapshot, moving: bool) -> void:
	if tick == _last_tick:
		return
	_last_tick = tick
	if tick % 2 == 0:
		particles.step()
	_hero_at = hero.position
	_phantom = hero.phantom_ticks_left > 0
	var rng: RandomNumberGenerator = particles.rng
	var at: Vector2 = hero.position
	if _phantom and tick % 3 == 0:
		particles.add(&"mote", at.x + rng.randf_range(-7.0, 7.0), at.y, rng.randf_range(2.0, 20.0), Vector3(0, 0, rng.randf_range(0.3, 0.7)), rng.randi_range(14, 22), LILAC)
	if hero.sprint_ticks_left > 0 and moving:
		var back: Vector2 = -hero.facing if hero.facing.length() > 0.01 else Vector2.LEFT
		if tick % 4 == 0:
			particles.add(&"dust", at.x + back.x * 4.0, at.y, 0.0, Vector3(back.x * 0.4, back.y * 0.15, 0.05), rng.randi_range(12, 18), DUST, Vector2(1.0, 2.6))
		if tick % 2 == 0:
			particles.add(&"streak", at.x, at.y, rng.randf_range(6.0, 24.0), Vector3(back.x * rng.randf_range(1.0, 2.0), back.y * 0.4, 0.0), rng.randi_range(5, 8), WIND)
	for i: int in range(rings.size() - 1, -1, -1):
		if tick - int(rings[i]["tick"]) >= int(rings[i]["life"]):
			rings.remove_at(i)
	for i: int in range(lights.size() - 1, -1, -1):
		if tick - int(lights[i]["tick"]) >= int(lights[i]["life"]):
			lights.remove_at(i)


## Under the characters: the rings of light and the dust.
func draw_ground(canvas: CanvasItem, colors: Dictionary, frames: Dictionary, sprites: Texture2D, tick: int, glow: float) -> void:
	for r: Dictionary in rings:
		var f: float = float(tick - int(r["tick"])) / float(r["life"])
		var rx: float = lerpf(float(r["rx0"]), float(r["rx1"]), 1.0 - pow(1.0 - f, 3.0))
		FxParticles.ground_ring(canvas, colors, Vector2(r["at"]).round(), rx, 1.0 - f, glow, r["colours"])
	particles.draw(canvas, colors, frames, sprites, glow, true)


## Over the characters: motes, sparks, streaks, stones.
func draw_air(canvas: CanvasItem, colors: Dictionary, frames: Dictionary, sprites: Texture2D, glow: float) -> void:
	particles.draw(canvas, colors, frames, sprites, glow, false)


## Lights for the road's lamps: each lantern's pool, Phantom Cut's glow while it runs, and the short flashes.
func lamps(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for at: Vector2 in lanterns.values():
		out.append({"point": Vector4(at.x, at.y, 56.0, -(0.55 + 0.1 * sin(float(tick) * 0.12))), "colour": TEAL_LIGHT, "core": TEAL_LIGHT})
	if _phantom:
		out.append({"point": Vector4(_hero_at.x, _hero_at.y - CHEST, 40.0, 0.5), "colour": LILAC_LIGHT, "core": LILAC_LIGHT})
	for l: Dictionary in lights:
		var f: float = float(tick - int(l["tick"])) / float(l["life"])
		var at: Vector2 = l["at"]
		out.append({"point": Vector4(at.x, at.y, float(l["radius"]), float(l["strength"]) * pow(1.0 - f, 1.5)), "colour": l["colour"], "core": l["colour"]})
	return out


func _key(data: Dictionary, at: Vector2) -> String:
	return str(data["lantern_id"]) if data.has("lantern_id") else str(at.round())
