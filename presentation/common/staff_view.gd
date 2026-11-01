extends RefCounted
## The Star Staff's look in every scene that draws the hero (presentation/common/hero_fx.gd owns one; the arena and the road
## draw it), wired 2026-11-01 after the owner approved the preview GIFs (art/reference/staff_v1/preview/). It draws:
##   the cast       the crystal flares, the bolt flies to the burst's point (snapshot swing_point) during the windup, then the
##                  Arcane Burst (staff_burst); the third cast forms a small circle under the point and erupts as the Great Burst
##   the blink      he breaks into streaks of light, a streak runs along the ground and he re-forms where he lands
##   Disintegration the circle forms under the target (the scene darkens, rocks lift, smoke curls), charges (rays, sparkles, the
##                  beam from his staff), the meteor falls (its shadow and firelight grow), the impact (flash, shake, the fire
##                  ring, the blast, rocks, sparks, shards, dust), then smoke columns over the crater as its cracks cool
## Ground effects (circles, rings, the meteor's shadow, the crater, dust) draw under the characters (draw_ground), the rest over
## them (draw_air). Frames are art/src fx_staff_* (tools/art/make_staff_sprites.py, drawn by tools/art/staff_fx.py like the
## previews). The core decides everything; this only follows its events and the hero's snapshot. 60 ticks a second.
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")
const PlayerState := preload("res://core/player.gd")
const StaffParticles := preload("res://presentation/common/staff_particles.gd")

const BURST_FRAME_TICKS: int = 3
const BIG_BURST_FRAME_TICKS: int = 4
const COLUMN_FRAME_TICKS: int = 3
const RING_TICKS: int = 18
const SHOCK_TICKS: int = 28
const EXPLOSION_FRAME_TICKS: int = 4
const FIRE_RING_FRAME_TICKS: int = 2
const CRATER_HEAT_TICKS: int = 150  # the cracks cool from glowing to dark (6 frames)
const CRATER_FADE_TICKS: int = 30  # then the crater fades out (3 frames)
const METEOR_DROP: float = 170.0  # how high above the circle the meteor appears
const MAGIC: Array = ["1", "p", "o", "u", "t"]
const FIRE: Array = ["1", "x", "y", "z", "A"]
const PHANTOM: Array = ["1", "p", "v", "v", "k"]  # Phantom Cut's lilac
const PHANTOM_TINT: Color = Color(0.82, 0.66, 1.0)
const TEAL_LIGHT: Vector3 = Vector3(0.45, 0.95, 0.9)
const WARM_LIGHT: Vector3 = Vector3(1.0, 0.62, 0.28)
const WARM_CORE: Vector3 = Vector3(1.05, 0.95, 0.8)

var particles: StaffParticles = StaffParticles.new(23)
## One-shot effects: {kind, tick, at, ...}: burst, big_burst, ring, shock, column, blink_column, blink_streak, explosion,
## fire_ring, crater.
var effects: Array[Dictionary] = []
## The running Disintegration from its start event: {start_tick, impact_tick, center}; the centre follows the snapshot.
var ult: Dictionary = {}
var shake_request: int = 0  # read and cleared by the owner (HeroFx.shake_left)
var flash_request: bool = false  # the impact's screen flash, read and cleared by the owner
var hide_until: int = -1  # the blink hides the hero until this tick
var _blinking: bool = false
var _blink_from: Vector2 = Vector2.ZERO
var _last_tick: int = -1


func clear() -> void:
	particles.clear()
	effects.clear()
	ult.clear()
	hide_until = -1
	_blinking = false


# ---- events -----------------------------------------------------------------------------------------------------------------

func on_event(event: GameEvent, hero: Snapshots.EntitySnapshot) -> void:
	var tick: int = event.tick
	match event.type:
		GameEvent.STAFF_BURST:
			var at: Vector2 = event.data["position"]
			var finisher: bool = bool(event.data.get("finisher", false))
			if finisher:
				effects.append({"kind": "big_burst", "tick": tick, "at": at})
				effects.append({"kind": "column", "tick": tick, "at": at})
				effects.append({"kind": "shock", "tick": tick, "at": at, "rx0": 20.0, "rx1": 70.0})
				particles.burst(&"shard", at.x, at.y, 6.0, 16, Vector2(0.8, 2.4), Vector2(2.0, 4.2), Vector2i(30, 45))
				particles.burst(&"spark", at.x, at.y, 18.0, 30, Vector2(1.5, 3.5), Vector2(0.5, 3.0), Vector2i(12, 22))
				particles.burst(&"mote", at.x, at.y, 10.0, 12, Vector2(0.2, 0.8), Vector2(0.3, 0.7), Vector2i(30, 50))
				particles.ring(&"dust", at.x, at.y, 26.0, 14, Vector2(0.02, 0.06), Vector2i(16, 26), ["d", "c"], 0.8, Vector2(1.5, 4.0))
				shake_request = maxi(shake_request, 8)
			else:
				effects.append({"kind": "burst", "tick": tick, "at": at})
				effects.append({"kind": "ring", "tick": tick, "at": at, "rx0": 6.0, "rx1": 22.0})
				particles.burst(&"spark", at.x, at.y, 15.0, 18, Vector2(1.2, 2.8), Vector2(0.4, 2.2), Vector2i(10, 18))
				particles.burst(&"mote", at.x, at.y, 12.0, 6, Vector2(0.2, 0.6), Vector2(0.25, 0.5), Vector2i(24, 40))
				particles.burst(&"dust", at.x, at.y, 0.0, 6, Vector2(0.4, 1.0), Vector2(0.02, 0.06), Vector2i(14, 22), ["d", "c"], 6.0, Vector2(1.0, 3.0))
				shake_request = maxi(shake_request, 2)
		GameEvent.DASH_STARTED:
			if not bool(event.data.get("blink", false)):
				return
			var from: Vector2 = event.data.get("from", hero.position)
			_blinking = true
			_blink_from = from
			hide_until = tick + Tuning.STAFF_BLINK_TICKS + 2
			effects.append({"kind": "ring", "tick": tick, "at": from, "rx0": 8.0, "rx1": 17.0})
			var dir: Vector2 = Vector2(event.data.get("direction", Vector2.RIGHT))
			for i: int in 70:  # his body breaks into streaks of light flying the way he blinks
				var z: float = particles.rng.randf_range(2.0, 30.0)
				var x: float = from.x + particles.rng.randf_range(-6.0, 6.0)
				var speed: float = particles.rng.randf_range(1.8, 4.2)
				particles.add(&"streak", x, from.y + particles.rng.randf_range(-1.0, 1.0), z,
					Vector3(dir.x * speed, dir.y * speed * 0.6 + particles.rng.randf_range(-0.2, 0.3), particles.rng.randf_range(-0.15, 0.35)),
					particles.rng.randi_range(5, 10), MAGIC.slice(particles.rng.randi_range(0, 2)))
			particles.burst(&"spark", from.x, from.y, 14.0, 10, Vector2(0.8, 2.0), Vector2(0.2, 1.2), Vector2i(8, 14))
		GameEvent.DISINTEGRATION_STARTED:
			ult = {"start_tick": tick, "impact_tick": int(event.data["impact_tick"]), "center": Vector2(event.data["position"]), "lifted": false}
		GameEvent.DISINTEGRATION_IMPACT:
			var at: Vector2 = event.data["position"]
			effects.append({"kind": "fire_ring", "tick": tick, "at": at})
			effects.append({"kind": "explosion", "tick": tick, "at": at})
			effects.append({"kind": "crater", "tick": tick, "at": at})
			particles.release_lifts(at.x, at.y, 2.6)
			particles.burst(&"rock", at.x, at.y, 6.0, 26, Vector2(1.2, 3.4), Vector2(2.6, 5.5), Vector2i(55, 75), MAGIC, 8.0)
			particles.burst(&"fspark", at.x, at.y, 10.0, 46, Vector2(1.5, 4.2), Vector2(0.5, 4.0), Vector2i(12, 26), FIRE, 6.0)
			particles.ring(&"shard", at.x, at.y, Tuning.DISINTEGRATION_RADIUS * 0.9, 16, Vector2(1.5, 3.5), Vector2i(30, 45), MAGIC, 1.2, Vector2.ONE, 2.0)
			particles.burst(&"spark", at.x, at.y, 6.0, 20, Vector2(1.0, 3.0), Vector2(0.5, 2.5), Vector2i(12, 20))
			particles.ring(&"dust", at.x, at.y, Tuning.DISINTEGRATION_RADIUS * 0.65, 24, Vector2(0.02, 0.08), Vector2i(20, 32), ["d", "c"], 1.3, Vector2(2.0, 6.0))
			shake_request = maxi(shake_request, 22)
			flash_request = true
		GameEvent.DISINTEGRATION_ENDED:
			ult.clear()


## Phantom Cut's echo of a cast: the same burst again on the target, in the phantom's lilac (a lilac ring and motes too).
func phantom_burst(tick: int, at: Vector2, swing: int) -> void:
	var big: bool = swing >= Tuning.STAFF_COMBO_MAX
	effects.append({"kind": "phantom_burst", "tick": tick, "at": at, "big": big})
	effects.append({"kind": "phantom_ring", "tick": tick, "at": at, "rx0": 6.0, "rx1": 26.0 if big else 20.0})
	particles.burst(&"mote", at.x, at.y, 14.0, 10, Vector2(0.3, 1.0), Vector2(0.2, 0.6), Vector2i(20, 34), PHANTOM)
	particles.burst(&"spark", at.x, at.y, 14.0, 12, Vector2(1.0, 2.4), Vector2(0.3, 1.8), Vector2i(10, 16), PHANTOM)


# ---- one tick ---------------------------------------------------------------------------------------------------------------

## Once per drawn tick (the owner calls it from age_hero_fx with the cosmetic tick): continuous particles, the blink's arrival,
## the particle step (30 Hz) and the end of finished effects.
func step(tick: int, hero: Snapshots.EntitySnapshot) -> void:
	if tick == _last_tick:
		return
	_last_tick = tick
	var rng: RandomNumberGenerator = particles.rng
	if _blinking and not hero.blink:  # the blink landed: he re-forms out of motes, a ring and a small pillar of light
		_blinking = false
		var at: Vector2 = hero.position
		effects.append({"kind": "ring", "tick": tick, "at": at, "rx0": 5.0, "rx1": 15.0})
		effects.append({"kind": "blink_column", "tick": tick, "at": at})
		for i: int in 60:
			var p: Dictionary = particles.add(&"seek", 0.0, 0.0, 0.0, Vector3.ZERO, rng.randi_range(4, 7), ["1", "p", "o", "u"])
			p["sx"] = rng.randf_range(_blink_from.x, at.x)
			p["sgy"] = at.y + rng.randf_range(-2.0, 2.0)
			p["sz"] = rng.randf_range(6.0, 22.0)
			p["tx"] = at.x + rng.randf_range(-6.0, 6.0)
			p["tgy"] = at.y
			p["tz"] = rng.randf_range(2.0, 30.0)
		particles.burst(&"mote", at.x, at.y, 16.0, 8, Vector2(0.2, 0.7), Vector2(0.2, 0.5), Vector2i(20, 34))
		particles.burst(&"dust", at.x, at.y, 0.0, 4, Vector2(0.4, 0.8), Vector2(0.02, 0.05), Vector2i(12, 18), ["d", "c"], 4.0, Vector2(1.0, 2.5))
	if not ult.is_empty():
		if hero.disintegration_phase != &"":
			ult["center"] = hero.disintegration_center
		var c: Vector2 = ult["center"]
		var t: int = tick - int(ult["start_tick"])
		var rx: float = Tuning.DISINTEGRATION_RADIUS
		if t == 8 and not bool(ult["lifted"]):  # rocks lift off the ground around the rim
			ult["lifted"] = true
			for j: int in 12:
				var a: float = float(j) * TAU / 12.0 + rng.randf_range(-0.2, 0.2)
				var d: float = rng.randf_range(0.92, 1.12)
				var p: Dictionary = particles.add(&"lift", c.x + cos(a) * rx * d, c.y + sin(a) * rx * 0.4 * d, 0.0, Vector3.ZERO, 100000)
				p["shape"] = rng.randi_range(5, StaffParticles.ROCKS - 1)
				p["tz"] = rng.randf_range(5.0, 14.0)
		if t < Tuning.DISINTEGRATION_FORM_TICKS + Tuning.DISINTEGRATION_CHARGE_TICKS and rng.randf() < 0.28:
			var a: float = rng.randf_range(0.0, TAU)
			particles.add(&"wisp", c.x + cos(a) * rx * rng.randf_range(0.85, 1.1), c.y + sin(a) * rx * 0.4, 0.0, Vector3(0, 0, rng.randf_range(0.3, 0.5)), rng.randi_range(18, 28), ["g", "f", "t", "e"])
		if tick < int(ult["impact_tick"]) and tick % 2 == 0:
			particles.ring(&"mote", c.x, c.y, rx * rng.randf_range(0.75, 1.0), 1, Vector2(0.25, 0.55), Vector2i(20, 32))
		var charging: bool = t >= Tuning.DISINTEGRATION_FORM_TICKS and tick < int(ult["impact_tick"]) - 4
		if charging and tick % 4 == 0:
			var tw: Dictionary = particles.add(&"twinkle", c.x + rng.randf_range(-rx, rx), c.y + rng.randf_range(-rx * 0.4, rx * 0.4), rng.randf_range(14.0, 52.0), Vector3.ZERO, rng.randi_range(10, 16))
			tw["kind"] = &"twinkle"
		var fall: int = tick - (int(ult["impact_tick"]) - Tuning.DISINTEGRATION_FALL_TICKS)
		if fall >= 0 and tick < int(ult["impact_tick"]):  # the meteor's embers and smoke trail
			var height: float = meteor_height(tick)
			for i: int in (3 if tick % 2 == 0 else 2):
				particles.add(&"ember", c.x + rng.randf_range(-10.0, 10.0), c.y + rng.randf_range(-1.0, 1.0), height + rng.randf_range(6.0, 22.0),
					Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(0.2, 0.8)), rng.randi_range(10, 18), FIRE)
			if tick % 4 == 0:
				particles.add(&"smoke", c.x + rng.randf_range(-5.0, 5.0), c.y - 0.5, height + 44.0, Vector3(rng.randf_range(-0.2, 0.2), 0.0, 0.15), rng.randi_range(14, 20), ["f", "e", "g"], Vector2(2.0, 4.5))
	for effect: Dictionary in effects:  # what the blast leaves going: embers, smoke rolling up, then columns from the crater
		if effect["kind"] != "crater":
			continue
		var c: Vector2 = effect["at"]
		var since: int = tick - int(effect["tick"])
		if since < 52:
			for i: int in (2 if tick % 2 == 0 else 1):
				particles.add(&"ember", c.x + rng.randf_range(-44.0, 44.0), c.y + rng.randf_range(-6.0, 6.0), rng.randf_range(8.0, 60.0),
					Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(0.5, 1.2)), rng.randi_range(20, 34), FIRE)
		if since >= 20 and since < 52 and tick % 2 == 0:
			particles.add(&"smoke", c.x + rng.randf_range(-36.0, 36.0), c.y + rng.randf_range(-8.0, 4.0), rng.randf_range(10.0, 36.0),
				Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(0.7, 1.1)), rng.randi_range(30, 44), ["f", "e", "g"], Vector2(2.0, 7.0))
		if since >= 24 and since < 148 and since % 4 == 0:
			for vent: Vector2 in [Vector2(-26, -3), Vector2(4, -6), Vector2(28, 1)]:
				particles.add(&"smoke", c.x + vent.x + rng.randf_range(-2.0, 2.0), c.y + vent.y, rng.randf_range(4.0, 8.0),
					Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(1.1, 1.5)), rng.randi_range(40, 52), ["e", "0"], Vector2(1.5, 5.0 if since < 100 else 3.5))
		if since >= 32 and since < 140 and tick % 4 == 0:
			particles.add(&"mote", c.x + rng.randf_range(-30.0, 30.0), c.y + rng.randf_range(-8.0, 8.0), 0.0, Vector3(0, 0, rng.randf_range(0.3, 0.6)), rng.randi_range(24, 40))
	if tick % 2 == 0:
		particles.step()
	for i: int in range(effects.size() - 1, -1, -1):
		if tick - int(effects[i]["tick"]) >= _life(effects[i]["kind"]):
			effects.remove_at(i)


func _life(kind: String) -> int:
	match kind:
		"burst", "phantom_burst":
			return 6 * BURST_FRAME_TICKS
		"big_burst":
			return 6 * BIG_BURST_FRAME_TICKS
		"ring", "phantom_ring":
			return RING_TICKS
		"shock":
			return SHOCK_TICKS
		"column":
			return 6 * COLUMN_FRAME_TICKS
		"blink_column":
			return 5 * COLUMN_FRAME_TICKS
		"explosion":
			return 12 * EXPLOSION_FRAME_TICKS
		"fire_ring":
			return 5 * FIRE_RING_FRAME_TICKS
		"crater":
			return CRATER_HEAT_TICKS + CRATER_FADE_TICKS
	return 30


# ---- what the scene asks ----------------------------------------------------------------------------------------------------

## How dark the scene is while Disintegration is cast (0 none .. 1): it falls as the circle forms, deepens as it charges, and the
## meteor's fire lights it back up; the blast clears it.
func dim(tick: int) -> float:
	if ult.is_empty():
		return 0.0
	var t: float = float(tick - int(ult["start_tick"]))
	var form: float = float(Tuning.DISINTEGRATION_FORM_TICKS)
	var charge_end: float = form + float(Tuning.DISINTEGRATION_CHARGE_TICKS)
	var impact: float = float(int(ult["impact_tick"]) - int(ult["start_tick"]))
	if t >= impact:
		return 0.0
	if t < form:
		return 0.45 * (1.0 - pow(1.0 - t / form, 3.0))
	if t < charge_end:
		return 0.45 + 0.1 * (t - form) / (charge_end - form)
	return 0.55 - 0.2 * (t - charge_end) / maxf(1.0, impact - charge_end)


## The hero is not drawn while the blink carries him.
func hides_hero(tick: int) -> bool:
	return hide_until >= 0 and tick < hide_until and _blinking


## The meteor's height above the circle on `tick` of its fall (falls faster and faster).
func meteor_height(tick: int) -> float:
	var t: float = clampf(float(tick - (int(ult["impact_tick"]) - Tuning.DISINTEGRATION_FALL_TICKS) + 1) / float(Tuning.DISINTEGRATION_FALL_TICKS), 0.0, 1.0)
	return METEOR_DROP * (1.0 - pow(t, 1.8))


## Lights for the lighting shader (the scene's moving lamps): the circle's teal glow on the ground, the meteor's fire, the blast,
## the crater's embers. {point: Vector4(x, y, radius, strength; negative = a pool on the floor), colour, core}.
func lamps(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not ult.is_empty():
		var c: Vector2 = ult["center"]
		var t: int = tick - int(ult["start_tick"])
		var power: float = clampf(float(t) / float(Tuning.DISINTEGRATION_FORM_TICKS + Tuning.DISINTEGRATION_CHARGE_TICKS), 0.15, 1.0)
		out.append({"point": Vector4(c.x, c.y, 80.0, -0.9 * power), "colour": TEAL_LIGHT, "core": TEAL_LIGHT})
		var fall: int = tick - (int(ult["impact_tick"]) - Tuning.DISINTEGRATION_FALL_TICKS)
		if fall >= 0 and tick < int(ult["impact_tick"]):
			var f: float = float(fall) / float(Tuning.DISINTEGRATION_FALL_TICKS)
			out.append({"point": Vector4(c.x, c.y - meteor_height(tick) - 20.0, 60.0 + 50.0 * f, 0.8 + 1.0 * f), "colour": WARM_LIGHT, "core": WARM_CORE})
	for effect: Dictionary in effects:
		var since: int = tick - int(effect["tick"])
		var at: Vector2 = effect["at"]
		if effect["kind"] == "explosion" and since < 80:
			out.append({"point": Vector4(at.x, at.y - 20.0, 150.0, 2.2 * pow(1.0 - float(since) / 80.0, 1.5)), "colour": WARM_LIGHT, "core": WARM_CORE})
		elif effect["kind"] == "crater" and since < CRATER_HEAT_TICKS:
			out.append({"point": Vector4(at.x, at.y, 70.0, -0.6 * (1.0 - float(since) / float(CRATER_HEAT_TICKS))), "colour": WARM_LIGHT, "core": WARM_CORE})
		elif effect["kind"] in ["burst", "big_burst"] and since < 14:
			out.append({"point": Vector4(at.x, at.y - 12.0, 46.0 if effect["kind"] == "burst" else 90.0, 0.9 * (1.0 - float(since) / 14.0)), "colour": TEAL_LIGHT, "core": TEAL_LIGHT})
	return out


# ---- drawing ----------------------------------------------------------------------------------------------------------------

## Under the characters: the circles, rings, the meteor's shadow, the crater and dust.
func draw_ground(canvas: CanvasItem, frames: Dictionary, sprites: Texture2D, colors: Dictionary, tick: int, hero: Snapshots.EntitySnapshot, glow: float) -> void:
	for effect: Dictionary in effects:
		var since: int = tick - int(effect["tick"])
		var at: Vector2 = effect["at"]
		match effect["kind"]:
			"crater":
				if since < CRATER_HEAT_TICKS:
					_sprite(canvas, frames, sprites, "fx_staff_crater_%d" % (1 + mini(5, since * 6 / CRATER_HEAT_TICKS)), at, 1.0)
				else:
					var fade: int = 1 + mini(2, (since - CRATER_HEAT_TICKS) * 3 / CRATER_FADE_TICKS)
					_sprite(canvas, frames, sprites, "fx_staff_crater_fade_%d" % fade, at, 1.0)
			"ring", "shock", "phantom_ring":
				var f: float = float(since) / float(SHOCK_TICKS if effect["kind"] == "shock" else RING_TICKS)
				_ring(canvas, colors, at, lerpf(float(effect["rx0"]), float(effect["rx1"]), 1.0 - pow(1.0 - f, 3.0)), 1.0 - f, glow,
					PHANTOM if effect["kind"] == "phantom_ring" else MAGIC)
	# the third cast's small circle forms under the burst's point during its windup
	if hero.weapon_id == Tuning.WEAPON_STAR_STAFF and hero.state == PlayerState.STATE_ATTACK_WINDUP and hero.combo_index == Weapons.combo_max(hero.weapon_id):
		var windup: int = maxi(1, PlayerState.scaled_ticks(Weapons.swing_phases(hero.weapon_id, hero.combo_index)[0], hero.attack_speed_mult))
		_sprite(canvas, frames, sprites, "fx_staff_circle_small_%d" % (1 + mini(5, hero.state_ticks * 6 / windup)), hero.swing_point, glow)
	for effect: Dictionary in effects:  # it lingers a moment after the eruption, dimming
		if effect["kind"] == "big_burst" and tick - int(effect["tick"]) < 10:
			_sprite(canvas, frames, sprites, "fx_staff_circle_small_6", effect["at"], glow)
	if not ult.is_empty():
		var c: Vector2 = ult["center"]
		var t: int = tick - int(ult["start_tick"])
		if tick < int(ult["impact_tick"]) + 2:
			if t < Tuning.DISINTEGRATION_FORM_TICKS:
				_sprite(canvas, frames, sprites, "fx_staff_circle_form_%d" % (1 + mini(11, t * 12 / Tuning.DISINTEGRATION_FORM_TICKS)), c, glow)
			else:
				_sprite(canvas, frames, sprites, "fx_staff_circle_charge_%d" % (1 + (tick / 3) % 8), c, glow)
		var fall: int = tick - (int(ult["impact_tick"]) - Tuning.DISINTEGRATION_FALL_TICKS)
		if fall >= 0 and tick < int(ult["impact_tick"]):  # the meteor's shadow and the mark it will land on
			var f: float = float(fall + 1) / float(Tuning.DISINTEGRATION_FALL_TICKS)
			_ellipse(canvas, colors, c, 4.0 + 14.0 * f, 0.25 + 0.45 * f)
			_ring(canvas, colors, c, 7.0 + sin(float(tick) * 0.45), 1.0, glow, ["1", "p", "o", "u"])
	particles.draw(canvas, colors, frames, sprites, glow, true)


## Over the characters: the cast, the bolt, bursts, pillars, the circle's rays and the call, the meteor, the blast, particles.
func draw_air(canvas: CanvasItem, frames: Dictionary, sprites: Texture2D, colors: Dictionary, tick: int, hero: Snapshots.EntitySnapshot, crystal: Vector2, glow: float) -> void:
	if hero.weapon_id == Tuning.WEAPON_STAR_STAFF and hero.state == PlayerState.STATE_ATTACK_WINDUP:
		var windup: int = maxi(1, PlayerState.scaled_ticks(Weapons.swing_phases(hero.weapon_id, hero.combo_index)[0], hero.attack_speed_mult))
		if hero.state_ticks < 8:
			_sprite(canvas, frames, sprites, "fx_staff_cast_%d" % (1 + mini(3, hero.state_ticks / 2)), crystal, glow)
		if hero.combo_index < Weapons.combo_max(hero.weapon_id) and hero.state_ticks >= 2:  # the bolt flies to the burst's point
			var f: float = clampf(float(hero.state_ticks - 1) / float(maxi(1, windup - 1)), 0.0, 1.0)
			var target: Vector2 = hero.swing_point + Vector2(0, -15)
			var at: Vector2 = crystal.lerp(target, f).round()
			_trail(canvas, colors, crystal, at, glow)
			_sprite(canvas, frames, sprites, "fx_staff_bolt_%d" % (1 + (tick / 2) % 2), at, glow)
	for effect: Dictionary in effects:
		var since: int = tick - int(effect["tick"])
		var at: Vector2 = effect["at"]
		match effect["kind"]:
			"burst":
				_sprite(canvas, frames, sprites, "fx_staff_burst_%d" % (1 + mini(5, since / BURST_FRAME_TICKS)), at + Vector2(0, -15), glow)
			"phantom_burst":
				var key: String = ("fx_staff_burst_big_%d" if bool(effect["big"]) else "fx_staff_burst_%d") % (1 + mini(5, since / BURST_FRAME_TICKS))
				StaffParticles._sprite(canvas, frames, sprites, key, at + Vector2(0, -20 if bool(effect["big"]) else -15), glow, PHANTOM_TINT)
			"big_burst":
				_sprite(canvas, frames, sprites, "fx_staff_burst_big_%d" % (1 + mini(5, since / BIG_BURST_FRAME_TICKS)), at + Vector2(0, -20), glow)
			"column":
				_sprite(canvas, frames, sprites, "fx_staff_column_%d" % (1 + mini(5, since / COLUMN_FRAME_TICKS)), at, glow)
			"blink_column":
				_sprite(canvas, frames, sprites, "fx_staff_blink_column_%d" % (1 + mini(4, since / COLUMN_FRAME_TICKS)), at, glow)
			"fire_ring":
				_sprite(canvas, frames, sprites, "fx_staff_fire_ring_%d" % (1 + mini(4, since / FIRE_RING_FRAME_TICKS)), at, glow)
			"explosion":
				_sprite(canvas, frames, sprites, "fx_staff_explosion_%d" % (1 + mini(11, since / EXPLOSION_FRAME_TICKS)), at, glow)
	if not ult.is_empty():
		var c: Vector2 = ult["center"]
		var t: int = tick - int(ult["start_tick"])
		if t >= Tuning.DISINTEGRATION_FORM_TICKS and tick < int(ult["impact_tick"]) + 2:
			_sprite(canvas, frames, sprites, "fx_staff_circle_rays_%d" % (1 + (tick / 3) % 8), c, glow)
		if t >= Tuning.DISINTEGRATION_FORM_TICKS + 4 and hero.state == PlayerState.STATE_STAFF_CAST:  # the call: a beam from his staff into the sky
			for y: int in range(int(crystal.y) - 220, int(crystal.y) - 3):
				var flick: float = 0.75 + 0.25 * sin(float(tick) * 1.7 + float(y) * 0.3)
				_pixel(canvas, colors, Vector2(crystal.x, y), "1", glow, flick)
				_pixel(canvas, colors, Vector2(crystal.x - 1, y), "p", glow, 0.6)
				_pixel(canvas, colors, Vector2(crystal.x + 1, y), "p", glow, 0.6)
				_pixel(canvas, colors, Vector2(crystal.x + 2, y), "o", glow, 0.3)
			_sprite(canvas, frames, sprites, "fx_staff_cast_%d" % (2 + (tick / 2) % 2), crystal, glow)
		var fall: int = tick - (int(ult["impact_tick"]) - Tuning.DISINTEGRATION_FALL_TICKS)
		if fall >= 0 and tick < int(ult["impact_tick"]):
			_sprite(canvas, frames, sprites, "fx_staff_meteor_%d" % (1 + (tick / 2) % 6), c - Vector2(0, meteor_height(tick)), glow)
	particles.draw(canvas, colors, frames, sprites, glow, false)


func _sprite(canvas: CanvasItem, frames: Dictionary, sprites: Texture2D, key: String, at: Vector2, glow: float) -> void:
	StaffParticles._sprite(canvas, frames, sprites, key, at, glow)


static func _pixel(canvas: CanvasItem, colors: Dictionary, at: Vector2, sym: String, glow: float, alpha: float = 1.0) -> void:
	if StaffParticles.keep(at, alpha):
		canvas.draw_rect(Rect2(at.round(), Vector2.ONE), Color(colors[sym], glow))


## A flat ring of light on the ground (rx across, rx * 0.38 deep); `power` 1 bright and solid, 0 gone.
static func _ring(canvas: CanvasItem, colors: Dictionary, at: Vector2, rx: float, power: float, glow: float, colours: Array = MAGIC) -> void:
	if power <= 0.0:
		return
	var ry: float = rx * 0.38
	var lead: int = 0 if power > 0.75 else (1 if power > 0.45 else 2)
	var steps: int = maxi(16, int((rx + ry) * 5.0))
	for i: int in steps:
		var a: float = TAU * float(i) / float(steps)
		_pixel(canvas, colors, at + Vector2(cos(a) * rx, sin(a) * ry), colours[mini(colours.size() - 1, lead + 1)], glow, minf(1.0, power * 1.4))
		_pixel(canvas, colors, at + Vector2(cos(a) * (rx - 1.0), sin(a) * (ry - 1.0)), colours[lead], glow, minf(1.0, power * 1.2))


## A dark ellipse on the ground (the meteor's shadow).
static func _ellipse(canvas: CanvasItem, colors: Dictionary, at: Vector2, rx: float, alpha: float) -> void:
	var ry: float = rx * 0.4
	for y: int in range(int(-ry) - 1, int(ry) + 2):
		var dy: float = float(y) / maxf(0.5, ry)
		if absf(dy) > 1.0:
			continue
		var half: float = rx * sqrt(1.0 - dy * dy)
		for x: int in range(int(-half), int(half) + 1):
			var p: Vector2 = (at + Vector2(x, y)).round()
			if StaffParticles.keep(p, alpha * (1.0 if absf(float(x)) < half * 0.6 else 0.7)):
				canvas.draw_rect(Rect2(p, Vector2.ONE), colors["0"])


## The bolt's tapering trail back toward the staff.
static func _trail(canvas: CanvasItem, colors: Dictionary, from: Vector2, head: Vector2, glow: float) -> void:
	var n: int = mini(14, int(maxf(absf(head.x - from.x), absf(head.y - from.y))))
	for i: int in n:
		var f: float = float(i) / float(maxi(1, n))
		var at: Vector2 = head.lerp(from, f * float(n) / maxf(1.0, head.distance_to(from)))
		_pixel(canvas, colors, at, MAGIC[mini(4, int(f * 5.0))], glow, clampf((1.0 - f) / 0.6, 0.0, 1.0))
