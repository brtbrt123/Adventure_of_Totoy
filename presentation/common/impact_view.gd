extends RefCounted
## The live part of the hero's combat effects in the Star Staff's style (owner 2026-11-02: "i like the effects of the staff
## skill, can you redo all effects ... except the golem"): hits, counters, parries and the dash. Their frames (fx_hit,
## fx_counter, fx_parry, fx_flash, fx_dash and the swing trails) are drawn by tools/art/make_hero_fx_art.py; this adds what a
## frame cannot: sparks thrown off the blow that fall and bounce on the ground, dust kicked up where it lands, a ring of light on
## the ground under heavy blows and parries, wind and dust behind a dash, and light for the road's lamps.
## Particles live on the ground plane (fx_particles.gd: x, gy = the ground line under them, z = height), so a spark from a blow
## at chest height falls to the target's feet. Owned by hero_fx.gd, which feeds it the scene's events; pure presentation.
const FxParticles := preload("res://presentation/common/fx_particles.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")

## A blade's sparks, bright to dark (the trail colours of tools/art/make_hero_fx_art.py).
const SPARKS: Dictionary = {
	Tuning.WEAPON_DUAL_DAGGER: ["1", "p", "o", "n", "m"],
	Tuning.WEAPON_CHAIN_SCYTHE: ["1", "p", "u", "t", "k"],
	Tuning.WEAPON_STAR_STAFF: ["1", "p", "o", "u", "t"],
}
const KATANA_SPARKS: Array = ["1", "p", "v", "l", "k"]
const GOLD: Array = ["1", "x", "x", "y", "A"]  # counters and parries (a combat cue)
const DUST: Array = ["j", "i"]
const WIND: Array = ["1", "p", "o", "n"]
## Light for the road's lamps (presentation/explore/explore_scene.gd moving lights), per spark colour set.
const STEEL_LIGHT: Vector3 = Vector3(0.75, 0.88, 1.0)
const GOLD_LIGHT: Vector3 = Vector3(1.0, 0.82, 0.4)
const GOLD_CORE: Vector3 = Vector3(1.05, 0.98, 0.85)

var particles: FxParticles = FxParticles.new(31)
## Rings of light on the ground: {at, tick, life, rx0, rx1, colours}.
var rings: Array[Dictionary] = []
## Short lights: {at, tick, life, radius, strength, colour, core}.
var lights: Array[Dictionary] = []
var _last_tick: int = -1
var _last_spark_tick: int = -1
var _dashing: bool = false


func clear() -> void:
	particles.clear()
	rings.clear()
	lights.clear()
	_dashing = false


## The hero's blow landed: `feet` is the target's ground point, `contact` where the blow met it, `facing` the hero's facing.
func hit(tick: int, feet: Vector2, contact: Vector2, weapon: StringName, counter: bool, finisher: bool, facing: Vector2) -> void:
	var colours: Array = GOLD if counter else SPARKS.get(weapon, KATANA_SPARKS)
	var z: float = maxf(0.0, feet.y - contact.y)
	var away: Vector2 = facing if facing.length() > 0.01 else Vector2.RIGHT
	var heavy: bool = counter or finisher
	# sparks thrown on past the target, arcing down to its feet and bouncing
	particles.spray(&"spark", contact.x, feet.y, z, 16 if counter else (12 if finisher else 7), away, 1.15 if heavy else 0.9,
		Vector2(1.2, 2.8 if heavy else 2.2), Vector2(0.6, 2.0), Vector2i(10, 20), colours)
	particles.burst(&"spark", contact.x, feet.y, z, 4 if heavy else 2, Vector2(0.4, 1.0), Vector2(0.8, 1.8), Vector2i(8, 14), colours)
	if heavy:  # shards that spin, fall and bounce, and motes left hanging in the air
		particles.spray(&"shard", contact.x, feet.y, z, 6 if counter else 4, away, 1.4, Vector2(0.8, 1.8), Vector2(1.2, 2.6), Vector2i(22, 34), colours)
		particles.burst(&"mote", contact.x, feet.y, z, 5, Vector2(0.2, 0.6), Vector2(0.15, 0.4), Vector2i(18, 30), colours)
		rings.append({"at": feet, "tick": tick, "life": 14 if counter else 11, "rx0": 5.0, "rx1": 22.0 if counter else 15.0, "colours": colours})
	# dust kicked up at the target's feet
	particles.spray(&"dust", feet.x, feet.y, 0.0, 3 if heavy else 2, away, 0.9, Vector2(0.3, 0.7), Vector2(0.02, 0.06), Vector2i(12, 18), DUST, Vector2(1.0, 2.6 if heavy else 2.0))
	lights.append({"at": contact, "tick": tick, "life": 12 if heavy else 8, "radius": 56.0 if counter else (44.0 if finisher else 30.0),
		"strength": 1.3 if counter else (1.0 if finisher else 0.7), "colour": GOLD_LIGHT if counter else STEEL_LIGHT, "core": GOLD_CORE if counter else STEEL_LIGHT})


## The hero parried at `contact`; `feet` is the ground under the clash. A perfect parry rings bigger and throws more.
func parry(tick: int, feet: Vector2, contact: Vector2, perfect: bool) -> void:
	var z: float = maxf(0.0, feet.y - contact.y)
	particles.burst(&"spark", contact.x, feet.y, z, 18 if perfect else 9, Vector2(1.0, 2.6 if perfect else 2.0), Vector2(0.8, 2.2), Vector2i(10, 20), GOLD)
	if perfect:
		particles.burst(&"shard", contact.x, feet.y, z, 5, Vector2(0.6, 1.4), Vector2(1.4, 2.6), Vector2i(24, 34), GOLD)
		particles.burst(&"mote", contact.x, feet.y, z, 6, Vector2(0.2, 0.7), Vector2(0.15, 0.45), Vector2i(18, 30), GOLD)
	rings.append({"at": feet, "tick": tick, "life": 14 if perfect else 9, "rx0": 4.0, "rx1": 24.0 if perfect else 13.0, "colours": GOLD})
	lights.append({"at": contact, "tick": tick, "life": 14 if perfect else 9, "radius": 60.0 if perfect else 38.0,
		"strength": 1.4 if perfect else 0.8, "colour": GOLD_LIGHT, "core": GOLD_CORE})


## A plain dash started (the Star Staff's blink is staff_view's): dust thrown back from where he pushed off.
func dash_started(tick: int, from: Vector2, direction: Vector2) -> void:
	var back: Vector2 = -direction if direction.length() > 0.01 else Vector2.LEFT
	particles.spray(&"dust", from.x, from.y, 0.0, 5, back, 0.7, Vector2(0.5, 1.2), Vector2(0.03, 0.08), Vector2i(14, 22), DUST, Vector2(1.2, 3.4))
	particles.spray(&"dust", from.x, from.y, 0.0, 2, Vector2(back.y, -back.x), 0.3, Vector2(0.3, 0.6), Vector2(0.02, 0.05), Vector2i(12, 18), DUST, Vector2(1.0, 2.4))
	rings.append({"at": from, "tick": tick, "life": 8, "rx0": 3.0, "rx1": 10.0, "colours": WIND})
	_dashing = true


## The blades' slash is sweeping: a few sparks fly off its leading end (`lead`, on the ground), outward along `out`.
func swing_sparks(tick: int, lead: Vector2, out: Vector2, colours: Array) -> void:
	if tick == _last_spark_tick:
		return
	_last_spark_tick = tick
	particles.spray(&"spark", lead.x, lead.y, 3.0, 2, out, 0.6, Vector2(0.6, 1.4), Vector2(0.3, 0.9), Vector2i(6, 11), colours)


## One tick older (30 Hz particles, like the staff); while he dashes, wind motes stream off him.
func step(tick: int, hero: Snapshots.EntitySnapshot) -> void:
	if tick == _last_tick:
		return
	_last_tick = tick
	if tick % 2 == 0:
		particles.step()
	if _dashing and hero.state != &"dash":
		_dashing = false
	if _dashing and not hero.blink:
		var rng: RandomNumberGenerator = particles.rng
		var back: Vector2 = -hero.facing if hero.facing.length() > 0.01 else Vector2.LEFT
		particles.add(&"streak", hero.position.x + back.x * 4.0, hero.position.y + rng.randf_range(-1.0, 1.0), rng.randf_range(3.0, 18.0),
			Vector3(back.x * rng.randf_range(0.8, 1.6), back.y * 0.4, 0.0), rng.randi_range(5, 9), WIND)
		if tick % 3 == 0:
			particles.add(&"dust", hero.position.x + back.x * 3.0, hero.position.y, 0.0, Vector3(back.x * 0.3, back.y * 0.12, 0.04), rng.randi_range(10, 16), DUST, Vector2(1.0, 2.2))
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


## Over the characters: sparks, shards, motes, wind.
func draw_air(canvas: CanvasItem, colors: Dictionary, frames: Dictionary, sprites: Texture2D, glow: float) -> void:
	particles.draw(canvas, colors, frames, sprites, glow, false)


## Lights for the road's lamps: {point: Vector4(x, y, radius, strength), colour, core}.
func lamps(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in lights:
		var f: float = float(tick - int(l["tick"])) / float(l["life"])
		var at: Vector2 = l["at"]
		out.append({"point": Vector4(at.x, at.y, float(l["radius"]), float(l["strength"]) * pow(1.0 - f, 1.5)), "colour": l["colour"], "core": l["core"]})
	return out
