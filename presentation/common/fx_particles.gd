extends RefCounted
## The particles of the Star Staff's style (a port of tools/art/staff_fx.py Particles, which made the approved preview GIFs),
## shared by the staff (staff_view.gd) and the hero's other combat effects (impact_view.gd). They live on the ground plane: x,
## gy (the ground y they stand over) and z (height above it), so a rock thrown by the blast arcs up, falls and bounces where it
## lands. Stepped at 30 Hz (every other game tick, like the preview). Pure presentation: nothing here touches the game. Kinds:
##   spark / fspark   fast pixels, a plus while young (magic / fire colours)      mote    a slow rising twinkle
##   ember            a fire pixel drifting up, flickering                        rock    a thrown rock sprite (fx_staff_rock_n)
##   shard            a crystal shard that spins and bounces                      smoke   a solid puff rising and swelling
##   dust             a puff on the ground                                        wisp    a curl of smoke while the circle forms
##   twinkle          a sparkle that swells and shrinks in place                  lift    a rock floating off the ground
##   streak           a fast mote with a smear (the blink)                        seek    a mote flying to a target (re-forming)

const BAYER: Array = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const GRAVITY: Dictionary = {&"spark": 0.07, &"fspark": 0.09, &"rock": 0.24, &"shard": 0.2}
const ROCKS: int = 12

var items: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 7) -> void:
	rng.seed = seed_value


func clear() -> void:
	items.clear()


func add(kind: StringName, x: float, gy: float, z: float = 0.0, v: Vector3 = Vector3.ZERO, life: int = 20, colours: Array = ["1", "p", "o", "u", "t"], r: Vector2 = Vector2.ONE) -> Dictionary:
	var p: Dictionary = {"kind": kind, "x": x, "gy": gy, "z": z, "vx": v.x, "vgy": v.y, "vz": v.z, "life": life, "age": 0,
		"seed": rng.randi_range(0, 65535), "r0": r.x, "r1": r.y, "colours": colours, "shape": rng.randi_range(0, ROCKS - 1), "bounces": 0}
	items.append(p)
	return p


## `n` particles flying out from (x, gy, z): speed and up are [min, max] ranges, life [min, max] ticks of 30 Hz.
func burst(kind: StringName, x: float, gy: float, z: float, n: int, speed: Vector2, up: Vector2, life: Vector2i, colours: Array = ["1", "p", "o", "u", "t"], spread: float = 1.0, r: Vector2 = Vector2.ONE) -> void:
	for i: int in n:
		var a: float = rng.randf_range(0.0, TAU)
		var s: float = rng.randf_range(speed.x, speed.y)
		add(kind, x + cos(a) * spread, gy + sin(a) * spread * 0.4, z, Vector3(cos(a) * s, sin(a) * s * 0.4, rng.randf_range(up.x, up.y)),
			rng.randi_range(life.x, life.y), colours, r)


## `n` particles thrown along `dir` (screen direction; its y is depth on the ground) within +-`cone` radians: sparks off a blade.
func spray(kind: StringName, x: float, gy: float, z: float, n: int, dir: Vector2, cone: float, speed: Vector2, up: Vector2, life: Vector2i, colours: Array = ["1", "p", "o", "u", "t"], r: Vector2 = Vector2.ONE) -> void:
	var base: float = dir.angle() if dir.length() > 0.01 else 0.0
	for i: int in n:
		var a: float = base + rng.randf_range(-cone, cone)
		var s: float = rng.randf_range(speed.x, speed.y)
		add(kind, x, gy, z, Vector3(cos(a) * s, sin(a) * s * 0.4, rng.randf_range(up.x, up.y)), rng.randi_range(life.x, life.y), colours, r)


## `n` particles on an ellipse of radius rx (rx x rx*0.4) around (x, gy), moving out at `out`.
func ring(kind: StringName, x: float, gy: float, rx: float, n: int, up: Vector2, life: Vector2i, colours: Array = ["1", "p", "o", "u", "t"], out: float = 0.0, r: Vector2 = Vector2.ONE, z: float = 0.0) -> void:
	for i: int in n:
		var a: float = rng.randf_range(0.0, TAU)
		add(kind, x + cos(a) * rx, gy + sin(a) * rx * 0.4, z, Vector3(cos(a) * out, sin(a) * out * 0.4, rng.randf_range(up.x, up.y)),
			rng.randi_range(life.x, life.y), colours, r)


## The floating rocks are blasted out from (cx, cgy).
func release_lifts(cx: float, cgy: float, power: float) -> void:
	for p: Dictionary in items:
		if p["kind"] != &"lift":
			continue
		var a: float = atan2((float(p["gy"]) - cgy) * 2.5, float(p["x"]) - cx)
		p["kind"] = &"rock"
		p["vx"] = cos(a) * power * rng.randf_range(0.7, 1.2)
		p["vgy"] = sin(a) * power * 0.4 * rng.randf_range(0.7, 1.2)
		p["vz"] = rng.randf_range(2.0, 3.6)
		p["life"] = rng.randi_range(45, 70)
		p["age"] = 0


func step() -> void:
	var alive: Array[Dictionary] = []
	for p: Dictionary in items:
		p["age"] = int(p["age"]) + 1
		var k: StringName = p["kind"]
		var age: float = float(p["age"])
		var seed_f: float = float(p["seed"])
		match k:
			&"spark", &"fspark":
				p["x"] += p["vx"]
				p["gy"] += p["vgy"]
				p["z"] += p["vz"]
				p["vx"] *= 0.9
				p["vgy"] *= 0.9
				p["vz"] = float(p["vz"]) * 0.92 - float(GRAVITY[k])
				if float(p["z"]) < 0.0:
					p["z"] = 0.0
					p["vz"] = 0.0
			&"mote", &"ember":
				p["x"] += float(p["vx"]) + sin(age * 0.35 + seed_f) * (0.25 if k == &"mote" else 0.35)
				p["gy"] += p["vgy"]
				p["z"] += p["vz"]
				p["vx"] *= 0.95
				p["vgy"] *= 0.95
				p["vz"] *= 0.985 if k == &"mote" else 0.97
			&"rock", &"shard":
				p["vz"] = float(p["vz"]) - float(GRAVITY[k])
				p["z"] += p["vz"]
				p["x"] += p["vx"]
				p["gy"] += p["vgy"]
				if float(p["z"]) <= 0.0:
					p["z"] = 0.0
					if float(p["vz"]) < -0.8 and int(p["bounces"]) < 2:
						p["vz"] = -float(p["vz"]) * 0.32
						p["vx"] *= 0.55
						p["vgy"] *= 0.55
						p["bounces"] = int(p["bounces"]) + 1
					else:
						p["vz"] = 0.0
						p["vx"] *= 0.7
						p["vgy"] *= 0.7
			&"smoke", &"wisp", &"dust":
				p["x"] += float(p["vx"]) + sin(age * (0.3 if k == &"wisp" else 0.12) + seed_f) * (0.35 if k == &"wisp" else 0.18)
				p["gy"] += p["vgy"]
				p["z"] += p["vz"]
				p["vx"] *= 0.93
				p["vgy"] *= 0.93
				p["vz"] *= {&"smoke": 0.99, &"wisp": 0.97, &"dust": 0.9}[k]
			&"lift":
				p["z"] = float(p["tz"]) * _ease_out(age / 30.0) + sin(age * 0.18 + seed_f) * 0.8
			&"seek":
				var f: float = _ease_out(age / float(p["life"]))
				p["x"] = lerpf(float(p["sx"]), float(p["tx"]), f)
				p["gy"] = lerpf(float(p["sgy"]), float(p["tgy"]), f)
				p["z"] = lerpf(float(p["sz"]), float(p["tz"]), f) + sin(f * PI) * 4.0
			&"streak":
				p["x"] += p["vx"]
				p["gy"] += p["vgy"]
				p["z"] += p["vz"]
				p["vx"] *= 0.88
				p["vgy"] *= 0.88
				p["vz"] *= 0.9
		if int(p["age"]) < int(p["life"]):
			alive.append(p)
	items = alive


## Ground puffs (dust) and rocks lying low draw under the characters; everything else over them.
func draw(canvas: CanvasItem, colors: Dictionary, frames: Dictionary, sprites: Texture2D, glow: float, ground: bool) -> void:
	for p: Dictionary in items:
		var k: StringName = p["kind"]
		var on_ground: bool = k == &"dust"
		if on_ground != ground:
			continue
		var f: float = float(p["age"]) / maxf(1.0, float(p["life"]))
		var at: Vector2 = Vector2(float(p["x"]), float(p["gy"]) - float(p["z"])).round()
		var colours: Array = p["colours"]
		match k:
			&"spark", &"fspark":
				if int(p["age"]) < 3:
					for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
						_px(canvas, at + d, colors, _ramp(colours, f + 0.25), glow)
				_px(canvas, at, colors, _ramp(colours, f), glow)
			&"mote":
				var alpha: float = clampf((1.0 - f) / 0.3, 0.0, 1.0)
				if (int(p["age"]) / 4 + int(p["seed"])) % 3 == 0 and f < 0.7:
					for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
						_px(canvas, at + d, colors, _ramp(colours, f + 0.3), glow, alpha)
				_px(canvas, at, colors, _ramp(colours, f), glow, alpha)
			&"ember":
				if (int(p["age"]) + int(p["seed"])) % 6 != 0:
					_px(canvas, at, colors, _ramp(colours, f), glow, clampf((1.0 - f) / 0.35, 0.0, 1.0))
			&"smoke", &"dust":
				var r: float = lerpf(float(p["r0"]), float(p["r1"]), _ease_out(f))
				var alpha: float = clampf((1.0 - f) / 0.3, 0.0, 1.0) if k == &"smoke" else clampf((1.0 - f) / 0.5, 0.0, 1.0) * 0.85
				_puff(canvas, at, r, colors[colours[0]], colors[colours[mini(1, colours.size() - 1)]], alpha, int(p["seed"]))
			&"wisp":
				var alpha: float = clampf((1.0 - f) / 0.5, 0.0, 1.0)
				for s: int in 5:
					var a: float = float(p["age"]) * 0.25 + float(s) * 0.5 + float(p["seed"])
					_px(canvas, (at + Vector2(cos(a) * (1.5 + s * 0.4), -s * 0.8 + sin(a) * 1.2)).round(), colors, _ramp(colours, f + s * 0.08), 1.0, alpha)
			&"twinkle":
				var size: int = roundi(sin(f * PI) * 2.4)
				if size > 0:
					_sprite(canvas, frames, sprites, "fx_staff_twinkle_%d" % mini(3, size), at, glow)
				else:
					_px(canvas, at, colors, "o", glow)
			&"streak":
				_px(canvas, at, colors, _ramp(colours, f), glow)
				var vel: Vector2 = Vector2(float(p["vx"]), float(p["vgy"]) - float(p["vz"]))
				if vel.length() > 0.6:
					_px(canvas, (at - vel.normalized() * 1.2).round(), colors, _ramp(colours, f + 0.3), glow, 0.7)
			&"seek":
				_px(canvas, at, colors, _ramp(colours, 0.2 + 0.5 * (1.0 - f)), glow)
			&"rock", &"lift":
				var fade: float = 1.0 if k == &"lift" else clampf((1.0 - f) / 0.25, 0.0, 1.0)
				if fade > 0.5 or (int(at.x) + int(at.y)) % 2 == 0:
					if k == &"lift" or float(p["z"]) > 0.5:  # its shadow on the ground
						canvas.draw_rect(Rect2(Vector2(float(p["x"]), float(p["gy"])).round() + Vector2(-2, 0), Vector2(4, 1)), Color(colors["0"], 0.5))
					_sprite(canvas, frames, sprites, "fx_staff_rock_%d" % (int(p["shape"]) + 1), at, 1.0)
			&"shard":  # its colours: the middle step is the body, one brighter and one darker for the spinning ends
				var alpha: float = clampf((1.0 - f) / 0.3, 0.0, 1.0)
				var spin: bool = (int(p["age"]) / 2 + int(p["seed"])) % 2 == 0
				var mid: int = mini(2, colours.size() - 1)
				_px(canvas, at, colors, colours[mid], glow, alpha)
				_px(canvas, at + (Vector2(0, -1) if spin else Vector2(-1, 0)), colors, colours[maxi(0, mid - 1)], glow, alpha)
				_px(canvas, at + (Vector2(0, 1) if spin else Vector2(1, 0)), colors, colours[mini(colours.size() - 1, mid + 1)], glow, alpha)


## A flat ring of light on the ground (rx across, rx * 0.38 deep); `power` 1 bright and solid, 0 gone. Colours bright to dark.
static func ground_ring(canvas: CanvasItem, colors: Dictionary, at: Vector2, rx: float, power: float, glow: float, colours: Array) -> void:
	if power <= 0.0:
		return
	var ry: float = rx * 0.38
	var lead: int = 0 if power > 0.75 else (1 if power > 0.45 else 2)
	var steps: int = maxi(16, int((rx + ry) * 5.0))
	for i: int in steps:
		var a: float = TAU * float(i) / float(steps)
		_px(canvas, (at + Vector2(cos(a) * rx, sin(a) * ry)).round(), colors, colours[mini(colours.size() - 1, lead + 1)], glow, minf(1.0, power * 1.4))
		_px(canvas, (at + Vector2(cos(a) * (rx - 1.0), sin(a) * (ry - 1.0))).round(), colors, colours[mini(colours.size() - 1, lead)], glow, minf(1.0, power * 1.2))


static func _ease_out(v: float) -> float:
	return 1.0 - pow(1.0 - clampf(v, 0.0, 1.0), 3.0)


static func _ramp(colours: Array, t: float) -> String:
	return colours[mini(colours.size() - 1, int(clampf(t, 0.0, 1.0) * colours.size()))]


## Ordered dithering: a hard-alpha pixel fades by being drawn less often.
static func keep(at: Vector2, alpha: float) -> bool:
	if alpha >= 1.0:
		return true
	return alpha > 0.0 and (float(BAYER[int(at.y) & 3][int(at.x) & 3]) + 0.5) / 16.0 < alpha


static func _px(canvas: CanvasItem, at: Vector2, colors: Dictionary, sym: String, glow: float, alpha: float = 1.0) -> void:
	if keep(at, alpha):
		canvas.draw_rect(Rect2(at, Vector2.ONE), Color(colors[sym], glow))


static func _sprite(canvas: CanvasItem, frames: Dictionary, sprites: Texture2D, key: String, at: Vector2, glow: float, tint: Color = Color.WHITE) -> void:
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	var origin: Vector2 = (at - Vector2(float(f.get("ax", float(f["w"]) / 2.0)), float(f.get("ay", float(f["h"]) / 2.0)))).round()
	canvas.draw_texture_rect_region(sprites, Rect2(origin, Vector2(f["w"], f["h"])), Rect2(f["x"], f["y"], f["w"], f["h"]), Color(tint, glow))


## A lumpy solid puff (smoke or dust): a main blob and two smaller ones, the lower edge darker.
static func _puff(canvas: CanvasItem, at: Vector2, r: float, fill: Color, edge: Color, alpha: float, seed_value: int) -> void:
	var rr: float = maxf(1.0, r)
	var blobs: Array[Vector3] = [Vector3(0.0, 0.5, rr * 0.9)]
	if rr >= 2.5:
		var local: RandomNumberGenerator = RandomNumberGenerator.new()
		local.seed = seed_value
		for i: int in 2:
			var a: float = local.randf_range(PI * 0.9, PI * 2.1)
			blobs.append(Vector3(cos(a) * rr * 0.45, 0.5 + sin(a) * rr * 0.4, rr * 0.55))
	var top: int = int(floor(-rr)) - 1
	var bottom: int = int(ceil(rr)) + 1
	for y: int in range(top, bottom + 1):
		for x: int in range(top, bottom + 1):
			var inside: bool = false
			var below: bool = false
			for b: Vector3 in blobs:
				var dx: float = (float(x) - b.x) / b.z
				var dy: float = (float(y) - b.y) / (b.z * 0.85)
				if dx * dx + dy * dy <= 1.0:
					inside = true
				var dy2: float = (float(y + 1) - b.y) / (b.z * 0.85)
				if dx * dx + dy2 * dy2 <= 1.0:
					below = true
			if inside:
				var p: Vector2 = at + Vector2(x, y)
				if keep(p, alpha):
					canvas.draw_rect(Rect2(p, Vector2.ONE), edge if not below else fill)
