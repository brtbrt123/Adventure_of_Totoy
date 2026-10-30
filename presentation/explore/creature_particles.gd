extends RefCounted
## Pixel particles for the creature effects (presentation/explore/creature_effects.gd). A BURST is {kind, at, dir, half_angle, size, tick,
## seed}; every particle in it is a pure function of the burst and the current tick (no per-particle state, nothing simulated), so pause,
## replay and captures are repeatable. Colours are Totoy 36 palette symbols drawn opaque; particles shrink away instead of fading.
##
## A layer: n particles, shape (dot, leaf, smoke, spark, mote), life [min, max] ticks, speed [min, max] px/tick, drag (speed lost per tick),
## up (extra upward px/tick at the start), g (px/tick^2, + falls, - rises), size [min, max] px, grow (smoke px/tick), cols, flutter (px of
## sideways sway, leaves). Spawn modes per kind say where particles start and which way they go (see _spawn).

const LAYERS: Dictionary = {
	# the slam: smoke rolls out, dust kicks up, leaves are blown off the floor, all over the cone the core hit
	"slam": [
		{"n": 16, "shape": "smoke", "life": [36, 52], "speed": [0.3, 0.7], "drag": 0.05, "up": 0.15, "g": -0.003, "size": [2, 4], "grow": 0.12, "cols": ["j", "i", "d"]},
		{"n": 40, "shape": "dot", "life": [16, 30], "speed": [1.0, 2.2], "drag": 0.08, "up": 0.6, "g": 0.06, "size": [2, 4], "cols": ["j", "d", "c"]},
		{"n": 26, "shape": "leaf", "life": [40, 60], "speed": [1.0, 2.0], "drag": 0.04, "up": 0.5, "g": 0.02, "size": [2, 2], "cols": ["7", "6", "6", "d"], "flutter": 2.0},
	],
	# a root bursting out of the ground: clods thrown up and falling back, spirit sparks rising
	"roots": [
		{"n": 14, "shape": "dot", "life": [18, 28], "speed": [0.8, 1.8], "drag": 0.03, "up": 1.2, "g": 0.12, "size": [2, 3], "cols": ["d", "c", "b"]},
		{"n": 8, "shape": "spark", "life": [20, 34], "speed": [0.2, 0.6], "drag": 0.04, "up": 0.5, "g": -0.01, "size": [1, 1], "cols": ["o", "p", "u"]},
		{"n": 5, "shape": "leaf", "life": [26, 40], "speed": [0.6, 1.2], "drag": 0.04, "up": 0.9, "g": 0.05, "size": [2, 2], "cols": ["7", "6"], "flutter": 1.5},
	],
	# the charge: hooves kick dust and a leaf or two behind the Stag
	"kick": [
		{"n": 8, "shape": "dot", "life": [12, 22], "speed": [0.4, 1.0], "drag": 0.06, "up": 0.4, "g": 0.05, "size": [2, 4], "cols": ["j", "d", "c"]},
		{"n": 2, "shape": "leaf", "life": [24, 36], "speed": [0.5, 1.0], "drag": 0.04, "up": 0.5, "g": 0.03, "size": [2, 2], "cols": ["7", "6"], "flutter": 1.5},
	],
	# the charge stopped by a prop: a burst of smoke, debris and leaves in front of it
	"crash": [
		{"n": 12, "shape": "smoke", "life": [30, 44], "speed": [0.3, 0.8], "drag": 0.06, "up": 0.2, "g": -0.003, "size": [2, 4], "grow": 0.12, "cols": ["j", "i", "d"]},
		{"n": 24, "shape": "dot", "life": [14, 26], "speed": [1.0, 2.0], "drag": 0.07, "up": 0.8, "g": 0.08, "size": [2, 3], "cols": ["j", "d", "c", "i"]},
		{"n": 8, "shape": "leaf", "life": [36, 52], "speed": [0.8, 1.6], "drag": 0.04, "up": 0.7, "g": 0.02, "size": [2, 2], "cols": ["7", "6", "6", "d"], "flutter": 2.0},
	],
	# the phase-two roar: a ring of wind blows leaves and dust away from the Stag
	"roar": [
		{"n": 32, "shape": "leaf", "life": [40, 58], "speed": [1.4, 2.4], "drag": 0.04, "up": 0.3, "g": 0.01, "size": [2, 2], "cols": ["7", "6", "6", "d"], "flutter": 2.0},
		{"n": 30, "shape": "dot", "life": [16, 28], "speed": [1.2, 2.2], "drag": 0.07, "up": 0.3, "g": 0.03, "size": [2, 4], "cols": ["j", "d", "c"]},
		{"n": 10, "shape": "smoke", "life": [30, 44], "speed": [0.4, 0.8], "drag": 0.06, "up": 0.1, "g": -0.002, "size": [2, 4], "grow": 0.1, "cols": ["j", "i", "d"]},
	],
	# the chant: motes drawn in from around the horns (emitted every few ticks while it lasts)
	"chant": [
		{"n": 5, "shape": "spark", "life": [16, 22], "speed": [1.6, 2.2], "drag": 0.0, "up": 0.0, "g": 0.0, "size": [1, 1], "cols": ["o", "u", "p"]},
	],
	# the release: sparks thrown off the horns as the moths are called
	"release": [
		{"n": 26, "shape": "spark", "life": [20, 34], "speed": [0.8, 2.0], "drag": 0.06, "up": 0.3, "g": 0.01, "size": [1, 1], "cols": ["p", "o", "u", "1"]},
		{"n": 8, "shape": "smoke", "life": [24, 36], "speed": [0.2, 0.5], "drag": 0.05, "up": 0.2, "g": -0.004, "size": [2, 2], "grow": 0.08, "cols": ["o", "n", "u"]},
	],
	# a heal pulse: green motes rising off the Stag's body
	"heal": [
		{"n": 18, "shape": "mote", "life": [30, 46], "speed": [0.1, 0.35], "drag": 0.02, "up": 0.45, "g": -0.004, "size": [2, 2], "cols": ["6", "5"], "flutter": 1.2},
		{"n": 8, "shape": "mote", "life": [24, 36], "speed": [0.1, 0.3], "drag": 0.02, "up": 0.35, "g": -0.003, "size": [2, 2], "cols": ["6", "5"], "flutter": 1.0},
	],
	# the steady glow while the regeneration runs (a few motes every few ticks)
	"mist": [
		{"n": 4, "shape": "mote", "life": [26, 38], "speed": [0.05, 0.2], "drag": 0.02, "up": 0.3, "g": -0.003, "size": [2, 2], "cols": ["6", "5"], "flutter": 1.0},
	],
	# an orb in flight sheds sparks; an orb's end throws a few more
	"orb_trail": [
		{"n": 2, "shape": "spark", "life": [8, 14], "speed": [0.05, 0.3], "drag": 0.05, "up": 0.1, "g": 0.0, "size": [1, 1], "cols": ["o", "u", "p"]},
	],
	"pop": [
		{"n": 12, "shape": "spark", "life": [10, 18], "speed": [0.6, 1.4], "drag": 0.08, "up": 0.0, "g": 0.0, "size": [1, 1], "cols": ["p", "o", "u"]},
	],
	# a summoned moth arrives: teal sparks rising around it
	"reveal": [
		{"n": 12, "shape": "spark", "life": [16, 28], "speed": [0.3, 0.9], "drag": 0.05, "up": 0.6, "g": -0.005, "size": [1, 1], "cols": ["p", "o", "u"]},
	],
}


## The longest any particle of `kind` lives (a burst can be dropped after that, plus its spawn delay).
static func max_life(kind: String) -> int:
	var longest: int = 0
	for layer: Dictionary in LAYERS.get(kind, []):
		longest = maxi(longest, int(layer["life"][1]))
	return longest + 10


## A number in [0, 1) that depends only on its three inputs.
static func rand(seed_value: int, i: int, k: int) -> float:
	var x: int = (seed_value * 73856093) ^ (i * 19349663) ^ (k * 83492791)
	x = (x * 1103515245 + 12345) & 0x7fffffff
	x = (x * 1103515245 + 12345) & 0x7fffffff
	return float(x % 100000) / 100000.0


static func _span(range_pair: Array, t: float) -> float:
	return lerpf(float(range_pair[0]), float(range_pair[1]), t)


## Where particle `i` of layer `li` starts, the way it heads, and its spawn delay, by the burst's kind.
static func _spawn(burst: Dictionary, li: int, i: int) -> Dictionary:
	var s: int = int(burst["seed"])
	var u: float = rand(s, i, li * 7 + 1)
	var v: float = rand(s, i, li * 7 + 2)
	var at: Vector2 = burst["at"]
	var dir: Vector2 = burst.get("dir", Vector2.RIGHT)
	match String(burst["kind"]):
		"slam":
			# anywhere inside the hit cone, appearing as the shock front passes (it reaches the edge in 8 ticks), blown outward
			var size: float = float(burst["size"])
			var r: float = size * sqrt(maxf(0.04, u))
			var angle: float = dir.angle() + (v * 2.0 - 1.0) * float(burst["half_angle"]) * 0.95
			return {"origin": at + Vector2.from_angle(angle) * r, "heading": Vector2.from_angle(angle + (rand(s, i, li * 7 + 3) - 0.5) * 0.5), "delay": int(r / size * 8.0)}
		"roots":
			var spot: Vector2 = at + Vector2.from_angle(u * TAU) * 10.0 * v
			return {"origin": spot, "heading": Vector2.from_angle(-PI / 2.0 + (u - 0.5) * 2.2), "delay": int(v * 3.0)}
		"kick":
			return {"origin": at, "heading": dir.rotated((u - 0.5) * 1.6), "delay": 0}
		"crash":
			return {"origin": at, "heading": dir.rotated((u - 0.5) * PI * 0.9), "delay": int(v * 3.0)}
		"roar", "release", "pop", "reveal":
			return {"origin": at + Vector2.from_angle(u * TAU) * 4.0, "heading": Vector2.from_angle(u * TAU + (v - 0.5) * 0.3), "delay": int(v * 2.0)}
		"chant":
			# starts on a ring around the horns and travels inward to them
			var start: Vector2 = Vector2.from_angle(u * TAU) * lerpf(26.0, 38.0, v)
			return {"origin": at + start, "heading": -start.normalized(), "delay": 0}
		"heal", "mist":
			return {"origin": at + Vector2((u - 0.5) * 34.0, -v * 34.0), "heading": Vector2.from_angle(-PI / 2.0 + (u - 0.5) * 1.2), "delay": int(v * 6.0)}
		"orb_trail":
			return {"origin": at + Vector2((u - 0.5) * 4.0, (v - 0.5) * 4.0), "heading": Vector2.from_angle(u * TAU), "delay": 0}
	return {"origin": at, "heading": dir, "delay": 0}


## Every visible particle of `burst` at `tick`: [{at (Vector2, world px), size (px), col (palette symbol), shape}].
static func points(burst: Dictionary, tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var age_all: int = tick - int(burst["tick"])
	if age_all < 0:
		return out
	var layers: Array = LAYERS.get(String(burst["kind"]), [])
	var s: int = int(burst["seed"])
	for li: int in layers.size():
		var layer: Dictionary = layers[li]
		for i: int in int(layer["n"]):
			var spawn: Dictionary = _spawn(burst, li, i)
			var age: int = age_all - int(spawn["delay"])
			var life: int = int(roundf(_span(layer["life"], rand(s, i, li * 7 + 4))))
			if age < 0 or age > life:
				continue
			var speed: float = _span(layer["speed"], rand(s, i, li * 7 + 5))
			var drag: float = float(layer["drag"])
			var travel: float = float(age) if drag <= 0.0 else (1.0 - pow(1.0 - drag, float(age))) / drag
			var velocity: Vector2 = Vector2(spawn["heading"]) * speed + Vector2(0.0, -float(layer["up"]))
			var at: Vector2 = Vector2(spawn["origin"]) + velocity * travel + Vector2(0.0, 0.5 * float(layer["g"]) * float(age * age))
			if layer.has("flutter"):
				at.x += sin(float(age) * 0.25 + rand(s, i, li * 7 + 6) * TAU) * float(layer["flutter"]) * minf(1.0, float(age) / 10.0)
			var frac: float = float(age) / float(maxi(1, life))
			var size: float = _span(layer["size"], rand(s, i, li * 7 + 7)) + float(layer.get("grow", 0.0)) * float(age)
			if frac > 0.7:
				size *= 1.0 - (frac - 0.7) / 0.3  # shrink away instead of fading (hard pixels only)
			if size < 0.5:
				continue
			var cols: Array = layer["cols"]
			var col: String = cols[mini(cols.size() - 1, int(frac * cols.size()))] if layer["shape"] == "smoke" else cols[int(rand(s, i, li * 7 + 8) * cols.size()) % cols.size()]
			out.append({"at": at, "size": size, "col": col, "shape": layer["shape"], "age": age, "flip": int(rand(s, i, 99) * 2.0)})
	return out


static func draw(canvas: CanvasItem, bursts: Array[Dictionary], tick: int, colors: Dictionary) -> void:
	for burst: Dictionary in bursts:
		for p: Dictionary in points(burst, tick):
			var at: Vector2 = Vector2(p["at"]).round()
			var colour: Color = colors.get(p["col"], Color.WHITE)
			var size: float = float(p["size"])
			match String(p["shape"]):
				"smoke":
					canvas.draw_circle(at, maxf(1.0, roundf(size)), colour)
				"leaf":
					# a small leaf (3x2, a darker vein edge) that turns over as it tumbles
					var turned: bool = ((int(p["age"]) / 5) + int(p["flip"])) % 2 == 0
					var body: Vector2 = Vector2(3, 2) if turned else Vector2(2, 3)
					canvas.draw_rect(Rect2(at - Vector2.ONE, body + Vector2(2, 2)), colors["3"])  # dark-green edge: green survives the night light
					canvas.draw_rect(Rect2(at, body), colour)
				"mote":
					# a healing sparkle: a dark-green edged cross with a light green heart, so it stays green under the night light
					canvas.draw_rect(Rect2(at + Vector2(-2, -1), Vector2(5, 3)), colors["3"])
					canvas.draw_rect(Rect2(at + Vector2(-1, -2), Vector2(3, 5)), colors["3"])
					canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), colour)
					canvas.draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), colour)
					canvas.draw_rect(Rect2(at, Vector2.ONE), colors["7"])
				"spark":
					canvas.draw_rect(Rect2(at, Vector2.ONE), colour)
					if int(p["age"]) < 4:  # a fresh spark flashes as a tiny cross
						canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), colour)
						canvas.draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), colour)
				_:
					var side: float = maxf(1.0, roundf(size))
					canvas.draw_rect(Rect2(at + Vector2(0, 1), Vector2(side, side)), colors["9"])  # a darker underside so dust reads on the grass
					canvas.draw_rect(Rect2(at, Vector2(side, side)), colour)
