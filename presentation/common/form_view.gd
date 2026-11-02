extends RefCounted
## The live part of the weapon forms in the Star Staff's style (owner 2026-11-02, phase 2 of "redo all effects ... except the
## golem"): what their frames (tools/art/make_form_fx_art.py) cannot do.
##   Black Katana form  embers and dark wisps rising off him, a violet ring pulsing at his feet, a violet light; a burst of
##                      black fire when it starts, smoke when it ends.
##   Lightning Form     sparks crackling off him and a flickering blue-white light; at each blink, sparks at both ends and a
##                      streak of motes along the jump; the sky strike throws sparks, shards and smoke, rings the ground and
##                      lights the whole place for a moment.
##   Reaper's Coil      sparks at the hook's bite, dust where a missed hook lands, dust and sparks on the dragged target, a
##                      dust ring at his feet while the scythe spins round him, sparks where it connects, a teal light.
## Particles live on the ground plane (fx_particles.gd: x, gy = the ground line under them, z = height). Owned by
## hero_fx.gd, which calls it from the core's events and steps it with the hero each tick. Pure presentation.
const FxParticles := preload("res://presentation/common/fx_particles.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")

const VOID: Array = ["p", "v", "l", "k", "0"]  # black fire's embers, bright to dark
const SMOKE: Array = ["0", "e", "k"]
const BOLT: Array = ["1", "p", "o", "n", "m"]
const TEAL: Array = ["1", "p", "u", "t", "k"]
const DUST: Array = ["j", "i"]
const VIOLET_LIGHT: Vector3 = Vector3(0.62, 0.42, 1.0)
const BOLT_LIGHT: Vector3 = Vector3(0.72, 0.86, 1.0)
const BOLT_CORE: Vector3 = Vector3(0.95, 0.98, 1.05)
const TEAL_LIGHT: Vector3 = Vector3(0.45, 0.95, 0.9)
const CHEST: float = 14.0  # how high his chest is above his feet

var particles: FxParticles = FxParticles.new(47)
## Rings of light on the ground: {at, tick, life, rx0, rx1, colours}.
var rings: Array[Dictionary] = []
## Short lights: {at, tick, life, radius, strength, colour, core}.
var lights: Array[Dictionary] = []
var _last_tick: int = -1
## What runs now, from the hero each tick (for the lights while a form lasts).
var _form: StringName = &""
var _spinning: bool = false
var _hero_at: Vector2 = Vector2.ZERO


func clear() -> void:
	particles.clear()
	rings.clear()
	lights.clear()
	_form = &""
	_spinning = false


## A form started at `at` (his feet).
func form_started(tick: int, form: StringName, at: Vector2) -> void:
	var rng: RandomNumberGenerator = particles.rng
	match form:
		Weapons.FORM_BLACK_KATANA_BUFF:
			particles.ring(&"mote", at.x, at.y, 10.0, 18, Vector2(0.5, 1.2), Vector2i(20, 34), VOID, 0.5)
			for i: int in 6:
				particles.add(&"smoke", at.x + rng.randf_range(-9.0, 9.0), at.y + rng.randf_range(-2.0, 2.0), rng.randf_range(0.0, 6.0),
					Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(0.6, 1.1)), rng.randi_range(20, 30), SMOKE, Vector2(2.0, 5.0))
			rings.append({"at": at, "tick": tick, "life": 16, "rx0": 6.0, "rx1": 30.0, "colours": VOID})
			lights.append({"at": at - Vector2(0, CHEST), "tick": tick, "life": 18, "radius": 70.0, "strength": 1.2, "colour": VIOLET_LIGHT, "core": VIOLET_LIGHT})
		Weapons.FORM_LIGHTNING:
			particles.burst(&"spark", at.x, at.y, CHEST, 22, Vector2(1.2, 3.0), Vector2(0.8, 2.4), Vector2i(10, 20), BOLT)
			rings.append({"at": at, "tick": tick, "life": 12, "rx0": 5.0, "rx1": 26.0, "colours": BOLT})
			lights.append({"at": at - Vector2(0, CHEST), "tick": tick, "life": 10, "radius": 80.0, "strength": 1.6, "colour": BOLT_LIGHT, "core": BOLT_CORE})
		Weapons.FORM_REAPER_COIL:
			particles.ring(&"mote", at.x, at.y, 9.0, 10, Vector2(0.4, 0.9), Vector2i(16, 26), TEAL, 0.4)


## A form ended at `at`: black fire leaves smoke, lightning a last crackle.
func form_ended(_tick: int, form: StringName, at: Vector2) -> void:
	var rng: RandomNumberGenerator = particles.rng
	if form == Weapons.FORM_BLACK_KATANA_BUFF:
		for i: int in 5:
			particles.add(&"smoke", at.x + rng.randf_range(-7.0, 7.0), at.y, rng.randf_range(4.0, 20.0), Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(0.4, 0.8)),
				rng.randi_range(18, 26), SMOKE, Vector2(1.5, 4.0))
	elif form == Weapons.FORM_LIGHTNING:
		particles.burst(&"spark", at.x, at.y, CHEST, 8, Vector2(0.6, 1.6), Vector2(0.6, 1.4), Vector2i(8, 14), BOLT)
	elif form == Weapons.FORM_REAPER_COIL:
		particles.ring(&"mote", at.x, at.y, 7.0, 6, Vector2(0.3, 0.7), Vector2i(12, 20), TEAL, 0.3)


## A Lightning Form blink from `from` to `to` (feet): sparks at both ends, motes streaming along the jump, a flash at each end.
func blink(tick: int, from: Vector2, to: Vector2) -> void:
	var rng: RandomNumberGenerator = particles.rng
	particles.burst(&"spark", from.x, from.y, CHEST, 8, Vector2(0.8, 2.0), Vector2(0.4, 1.4), Vector2i(8, 14), BOLT)
	particles.burst(&"spark", to.x, to.y, CHEST, 10, Vector2(1.0, 2.4), Vector2(0.6, 1.6), Vector2i(8, 16), BOLT)
	var along: Vector2 = (to - from)
	for i: int in 14:
		var f: float = rng.randf()
		var at: Vector2 = from + along * f
		particles.add(&"streak", at.x, at.y + rng.randf_range(-1.0, 1.0), CHEST + rng.randf_range(-8.0, 8.0),
			Vector3(along.normalized().x * rng.randf_range(0.6, 1.6), along.normalized().y * 0.4, 0.0), rng.randi_range(5, 10), BOLT)
	for at: Vector2 in [from, to]:
		lights.append({"at": at - Vector2(0, CHEST), "tick": tick, "life": 6, "radius": 50.0, "strength": 1.0, "colour": BOLT_LIGHT, "core": BOLT_CORE})


## The sky strike lands at `at` (the target's feet), cutting through `body` (where it hits the target).
func strike(tick: int, at: Vector2, body: Vector2) -> void:
	var rng: RandomNumberGenerator = particles.rng
	var z: float = maxf(0.0, at.y - body.y)
	particles.burst(&"spark", at.x, at.y, z, 30, Vector2(1.4, 3.6), Vector2(1.0, 3.0), Vector2i(12, 24), BOLT)
	particles.burst(&"shard", at.x, at.y, 2.0, 8, Vector2(0.8, 2.0), Vector2(1.6, 3.0), Vector2i(26, 38), BOLT)
	particles.ring(&"dust", at.x, at.y, 8.0, 8, Vector2(0.03, 0.08), Vector2i(16, 26), DUST, 0.6, Vector2(1.5, 3.5))
	for i: int in 4:
		particles.add(&"smoke", at.x + rng.randf_range(-6.0, 6.0), at.y, rng.randf_range(2.0, 10.0), Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(0.5, 0.9)),
			rng.randi_range(20, 30), ["g", "f", "e"], Vector2(2.0, 5.0))
	rings.append({"at": at, "tick": tick, "life": 16, "rx0": 6.0, "rx1": 36.0, "colours": BOLT})
	lights.append({"at": at - Vector2(0, 20), "tick": tick, "life": 20, "radius": 140.0, "strength": 2.2, "colour": BOLT_LIGHT, "core": BOLT_CORE})


## Reaper's Coil: the hook bites at `bite` (in the air), a missed hook lands at `anchor` (ground), the dragged target's chest is hit.
func coil_hooked(tick: int, bite: Vector2, ground_y: float) -> void:
	particles.burst(&"spark", bite.x, ground_y, maxf(0.0, ground_y - bite.y), 12, Vector2(1.0, 2.4), Vector2(0.6, 1.8), Vector2i(8, 16), TEAL)
	lights.append({"at": bite, "tick": tick, "life": 8, "radius": 40.0, "strength": 0.9, "colour": TEAL_LIGHT, "core": TEAL_LIGHT})


func coil_missed(anchor: Vector2) -> void:
	particles.ring(&"dust", anchor.x, anchor.y, 3.0, 6, Vector2(0.03, 0.08), Vector2i(14, 22), DUST, 0.5, Vector2(1.2, 3.0))


func coil_drag_hit(tick: int, chest: Vector2, feet_y: float) -> void:
	var z: float = maxf(0.0, feet_y - chest.y)
	particles.burst(&"spark", chest.x, feet_y, z, 16, Vector2(1.0, 2.6), Vector2(0.8, 2.0), Vector2i(10, 18), TEAL)
	particles.burst(&"shard", chest.x, feet_y, z, 4, Vector2(0.6, 1.4), Vector2(1.2, 2.4), Vector2i(22, 32), TEAL)
	rings.append({"at": Vector2(chest.x, feet_y), "tick": tick, "life": 12, "rx0": 5.0, "rx1": 22.0, "colours": TEAL})
	lights.append({"at": chest, "tick": tick, "life": 12, "radius": 60.0, "strength": 1.2, "colour": TEAL_LIGHT, "core": TEAL_LIGHT})


func coil_spin_hit(tick: int, contacts: Array[Vector2]) -> void:
	for at: Vector2 in contacts:
		particles.burst(&"spark", at.x, at.y + 10.0, 10.0, 6, Vector2(0.8, 2.0), Vector2(0.5, 1.4), Vector2i(8, 14), TEAL)
	if not contacts.is_empty():
		lights.append({"at": contacts[0], "tick": tick, "life": 6, "radius": 40.0, "strength": 0.8, "colour": TEAL_LIGHT, "core": TEAL_LIGHT})


## One tick older (30 Hz particles, like the staff); while a form runs, its particles keep coming off him.
func step(tick: int, hero: Snapshots.EntitySnapshot) -> void:
	if tick == _last_tick:
		return
	_last_tick = tick
	if tick % 2 == 0:
		particles.step()
	_hero_at = hero.position
	_form = hero.weapon_form if hero.weapon_buff_active else &""
	_spinning = hero.weapon_form == Weapons.FORM_REAPER_COIL and hero.reaper_coil_phase == &"spin"
	var rng: RandomNumberGenerator = particles.rng
	var at: Vector2 = hero.position
	if _form == Weapons.FORM_BLACK_KATANA_BUFF and hero.weapon_id == Tuning.WEAPON_BLACK_KATANA:
		particles.add(&"ember", at.x + rng.randf_range(-8.0, 8.0), at.y + rng.randf_range(-1.0, 1.0), rng.randf_range(2.0, 22.0),
			Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(0.4, 0.9)), rng.randi_range(14, 24), VOID)
		if tick % 3 == 0:
			particles.add(&"wisp", at.x + rng.randf_range(-7.0, 7.0), at.y, rng.randf_range(0.0, 4.0), Vector3(0, 0, rng.randf_range(0.4, 0.7)), rng.randi_range(16, 24), SMOKE)
		if tick % 24 == 0:
			rings.append({"at": at, "tick": tick, "life": 14, "rx0": 5.0, "rx1": 17.0, "colours": VOID})
	elif _form == Weapons.FORM_LIGHTNING:
		if tick % 2 == 0:
			var a: float = rng.randf_range(0.0, TAU)
			particles.add(&"spark", at.x + cos(a) * 5.0, at.y, rng.randf_range(4.0, 26.0), Vector3(cos(a) * rng.randf_range(0.6, 1.6), sin(a) * 0.3, rng.randf_range(0.2, 1.2)),
				rng.randi_range(5, 10), BOLT)
		if tick % 7 == 0:
			particles.add(&"streak", at.x, at.y, rng.randf_range(2.0, 6.0), Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.4, 0.4), 0.0), rng.randi_range(5, 8), BOLT)
	if _spinning and tick % 4 == 0:
		particles.ring(&"dust", at.x, at.y, 22.0, 2, Vector2(0.02, 0.06), Vector2i(12, 18), DUST, 0.5, Vector2(1.2, 2.6))
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


## Over the characters: embers, wisps, sparks, shards, smoke.
func draw_air(canvas: CanvasItem, colors: Dictionary, frames: Dictionary, sprites: Texture2D, glow: float) -> void:
	particles.draw(canvas, colors, frames, sprites, glow, false)


## Lights for the road's lamps: the form's own light while it runs, and the short flashes.
func lamps(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var body: Vector2 = _hero_at - Vector2(0, CHEST)
	if _form == Weapons.FORM_BLACK_KATANA_BUFF:
		out.append({"point": Vector4(body.x, body.y, 46.0, 0.55 + 0.15 * sin(float(tick) * 0.3)), "colour": VIOLET_LIGHT, "core": VIOLET_LIGHT})
	elif _form == Weapons.FORM_LIGHTNING:
		var flicker: float = 0.35 + 0.45 * float(posmod(tick * 7919, 13)) / 12.0
		out.append({"point": Vector4(body.x, body.y, 44.0, flicker), "colour": BOLT_LIGHT, "core": BOLT_CORE})
	if _spinning:
		out.append({"point": Vector4(_hero_at.x, _hero_at.y, 48.0, -0.5), "colour": TEAL_LIGHT, "core": TEAL_LIGHT})
	for l: Dictionary in lights:
		var f: float = float(tick - int(l["tick"])) / float(l["life"])
		var at: Vector2 = l["at"]
		out.append({"point": Vector4(at.x, at.y, float(l["radius"]), float(l["strength"]) * pow(1.0 - f, 1.5)), "colour": l["colour"], "core": l["core"]})
	return out
