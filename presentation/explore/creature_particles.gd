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
		{"n": 16, "shape": "smoke", "life": [36, 52], "speed": [0.3, 0.7], "drag": 0.05, "up": 0.15, "g": -0.003, "size": [2, 4], "grow": 0.12, "cols": ["d", "c", "b"]},
		{"n": 40, "shape": "dot", "life": [16, 30], "speed": [1.0, 2.2], "drag": 0.08, "up": 0.6, "g": 0.06, "size": [2, 4], "cols": ["j", "d", "c"]},
		{"n": 26, "shape": "leaf", "life": [40, 60], "speed": [1.0, 2.0], "drag": 0.04, "up": 0.5, "g": 0.02, "size": [2, 2], "cols": ["7", "6", "6", "d"], "flutter": 2.0},
		{"n": 10, "shape": "blade", "life": [18, 30], "speed": [0.8, 1.6], "drag": 0.06, "up": 0.9, "g": 0.1, "size": [1, 1], "cols": ["5", "4", "6"]},
	],
	# a root bursting out of the ground: clods thrown up and falling back, spirit sparks rising
	"roots": [
		{"n": 14, "shape": "dot", "life": [18, 28], "speed": [0.8, 1.8], "drag": 0.03, "up": 1.2, "g": 0.12, "size": [2, 3], "cols": ["d", "c", "b"]},
		{"n": 8, "shape": "spark", "life": [20, 34], "speed": [0.2, 0.6], "drag": 0.04, "up": 0.5, "g": -0.01, "size": [1, 1], "cols": ["o", "p", "u"]},
		{"n": 5, "shape": "leaf", "life": [26, 40], "speed": [0.6, 1.2], "drag": 0.04, "up": 0.9, "g": 0.05, "size": [2, 2], "cols": ["7", "6"], "flutter": 1.5},
		{"n": 3, "shape": "blade", "life": [16, 26], "speed": [0.5, 1.1], "drag": 0.05, "up": 1.0, "g": 0.1, "size": [1, 1], "cols": ["5", "4"]},
	],
	# the charge: hooves kick dust and a leaf or two behind the Stag
	"kick": [
		{"n": 8, "shape": "dot", "life": [12, 22], "speed": [0.4, 1.0], "drag": 0.06, "up": 0.4, "g": 0.05, "size": [2, 4], "cols": ["j", "d", "c"]},
		{"n": 2, "shape": "leaf", "life": [24, 36], "speed": [0.5, 1.0], "drag": 0.04, "up": 0.5, "g": 0.03, "size": [2, 2], "cols": ["7", "6"], "flutter": 1.5},
	],
	# the charge stopped by a prop: a burst of smoke, debris and leaves in front of it
	"crash": [
		{"n": 12, "shape": "smoke", "life": [30, 44], "speed": [0.3, 0.8], "drag": 0.06, "up": 0.2, "g": -0.003, "size": [2, 4], "grow": 0.12, "cols": ["d", "c", "b"]},
		{"n": 24, "shape": "dot", "life": [14, 26], "speed": [1.0, 2.0], "drag": 0.07, "up": 0.8, "g": 0.08, "size": [2, 3], "cols": ["j", "d", "c", "i"]},
		{"n": 8, "shape": "leaf", "life": [36, 52], "speed": [0.8, 1.6], "drag": 0.04, "up": 0.7, "g": 0.02, "size": [2, 2], "cols": ["7", "6", "6", "d"], "flutter": 2.0},
	],
	# the phase-two roar: a ring of wind blows leaves and dust away from the Stag
	"roar": [
		{"n": 32, "shape": "leaf", "life": [40, 58], "speed": [1.4, 2.4], "drag": 0.04, "up": 0.3, "g": 0.01, "size": [2, 2], "cols": ["7", "6", "6", "d"], "flutter": 2.0},
		{"n": 30, "shape": "dot", "life": [16, 28], "speed": [1.2, 2.2], "drag": 0.07, "up": 0.3, "g": 0.03, "size": [2, 4], "cols": ["j", "d", "c"]},
		{"n": 10, "shape": "smoke", "life": [30, 44], "speed": [0.4, 0.8], "drag": 0.06, "up": 0.1, "g": -0.002, "size": [2, 4], "grow": 0.1, "cols": ["d", "c", "b"]},
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
		{"n": 6, "shape": "mote", "life": [30, 46], "speed": [0.1, 0.3], "drag": 0.02, "up": 0.45, "g": -0.004, "size": [2, 2], "cols": ["6", "5"], "flutter": 1.2},
	],
	# the steady glow while the regeneration runs (a few motes every few ticks)
	"mist": [
		{"n": 1, "shape": "mote", "life": [26, 38], "speed": [0.05, 0.2], "drag": 0.02, "up": 0.3, "g": -0.003, "size": [2, 2], "cols": ["6", "5"], "flutter": 1.0},
	],
	# an orb in flight sheds sparks; an orb's end throws a few more
	"orb_trail": [
		{"n": 2, "shape": "spark", "life": [8, 14], "speed": [0.05, 0.3], "drag": 0.05, "up": 0.1, "g": 0.0, "size": [1, 1], "cols": ["o", "u", "p"]},
	],
	"pop": [
		{"n": 12, "shape": "spark", "life": [10, 18], "speed": [0.6, 1.4], "drag": 0.08, "up": 0.0, "g": 0.0, "size": [1, 1], "cols": ["p", "o", "u"]},
	],
	# a summoned moth arrives: teal sparks rising around it
	# the Warden's footfall: a flat puff of dust and grit kicked out sideways along the ground
	"stomp": [
		{"n": 5, "shape": "smoke", "life": [20, 30], "speed": [0.25, 0.55], "drag": 0.07, "up": 0.04, "g": -0.002, "size": [1, 2], "grow": 0.06, "cols": ["c", "b", "a"]},
		{"n": 9, "shape": "dot", "life": [10, 18], "speed": [0.6, 1.3], "drag": 0.08, "up": 0.5, "g": 0.09, "size": [1, 2], "cols": ["c", "b", "d"]},
		{"n": 1, "shape": "leaf", "life": [24, 34], "speed": [0.4, 0.8], "drag": 0.04, "up": 0.6, "g": 0.03, "size": [2, 2], "cols": ["6", "7"], "flutter": 1.5},
		{"n": 2, "shape": "blade", "life": [14, 22], "speed": [0.5, 1.0], "drag": 0.06, "up": 0.8, "g": 0.1, "size": [1, 1], "cols": ["5", "4"]},
	],
	# the Cleave's blade tearing through the cone: clods, grass and leaves thrown out along the swept arc (the real hit edge)
	"gouge": [
		{"n": 26, "shape": "dot", "life": [14, 26], "speed": [0.8, 1.8], "drag": 0.07, "up": 0.7, "g": 0.09, "size": [2, 3], "cols": ["d", "c", "b", "9"]},
		{"n": 10, "shape": "leaf", "life": [30, 46], "speed": [0.8, 1.6], "drag": 0.04, "up": 0.6, "g": 0.02, "size": [2, 2], "cols": ["7", "6", "6", "d"], "flutter": 2.0},
		{"n": 8, "shape": "smoke", "life": [26, 38], "speed": [0.2, 0.5], "drag": 0.06, "up": 0.1, "g": -0.003, "size": [2, 3], "grow": 0.1, "cols": ["d", "c", "b"]},
	],
	# the Spore Ring's shock: dust rolls outward from the ring's real edge, grit flies, teal spores rise
	"quake": [
		{"n": 18, "shape": "smoke", "life": [30, 44], "speed": [0.3, 0.7], "drag": 0.06, "up": 0.1, "g": -0.003, "size": [2, 4], "grow": 0.12, "cols": ["d", "c", "b"]},
		{"n": 30, "shape": "dot", "life": [14, 26], "speed": [0.9, 1.9], "drag": 0.08, "up": 0.7, "g": 0.09, "size": [2, 3], "cols": ["d", "c", "j"]},
		{"n": 16, "shape": "spark", "life": [24, 40], "speed": [0.2, 0.6], "drag": 0.04, "up": 0.6, "g": -0.008, "size": [1, 1], "cols": ["o", "p", "u"]},
	],
	# a reduced hit on the rune guard: stone chips and teal sparks off the chest
	"chips": [
		{"n": 9, "shape": "dot", "life": [12, 22], "speed": [0.7, 1.5], "drag": 0.06, "up": 0.9, "g": 0.12, "size": [1, 2], "cols": ["h", "i", "g"]},
		{"n": 10, "shape": "spark", "life": [10, 18], "speed": [0.6, 1.4], "drag": 0.08, "up": 0.2, "g": 0.0, "size": [1, 1], "cols": ["p", "o", "u"]},
	],
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
		"gouge":
			# along the swept arc, out near the real hit edge, thrown outward
			var size: float = float(burst["size"])
			var r: float = size * lerpf(0.55, 1.0, u)
			var angle: float = dir.angle() + (v * 2.0 - 1.0) * float(burst["half_angle"])
			return {"origin": at + Vector2.from_angle(angle) * r, "heading": Vector2.from_angle(angle + (rand(s, i, li * 7 + 3) - 0.5) * 0.6), "delay": int(v * 5.0)}
		"quake":
			# on the ring's real edge, rolling outward
			var size: float = float(burst["size"])
			var angle: float = u * TAU
			return {"origin": at + Vector2.from_angle(angle) * size * lerpf(0.8, 1.0, v), "heading": Vector2.from_angle(angle + (v - 0.5) * 0.4), "delay": int(v * 3.0)}
		"stomp":
			# out sideways along the floor (the camera looks down at the ground, so the spread is flattened)
			var angle: float = u * TAU
			return {"origin": at + Vector2((v - 0.5) * 10.0, (u - 0.5) * 2.0), "heading": Vector2(cos(angle), sin(angle) * 0.35), "delay": 0}
		"chips":
			return {"origin": at + Vector2.from_angle(u * TAU) * 3.0, "heading": Vector2.from_angle(u * TAU), "delay": int(v * 2.0)}
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
			# beside the body (not over it), so the Stag stays readable while it heals
			var side: float = -1.0 if u < 0.5 else 1.0
			return {"origin": at + Vector2(side * lerpf(18.0, 28.0, rand(s, i, li * 7 + 9)), -lerpf(6.0, 34.0, v)), "heading": Vector2.from_angle(-PI / 2.0 + side * 0.3), "delay": int(v * 6.0)}
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
			out.append({"at": at, "size": size, "col": col, "shape": layer["shape"], "age": age, "frac": frac, "flip": int(rand(s, i, 99) * 2.0)})
	return out


## Totoy 36 ramps, dark to light: a particle shades itself with the neighbouring steps of its own colour.
const RAMPS: Array[String] = ["089abcd", "efghij1", "234567", "klmnop", "tuop"]
## A tumbling leaf, 4 x 4 px, four turns (face up, edge on, face down, edge on the other way): B its colour, L a step lighter,
## D two steps darker (its vein and edge: a leaf stays readable on a dark floor).
const LEAF_TURNS: Array = [["..LB", ".LBB", "BBD.", "D..."], ["...B", "..BD", ".BD.", "D..."], ["BD..", "DBB.", ".DBB", "...D"], ["B...", "DB..", ".DB.", "..DB"]]
## Clods and grit by size (1-4 px): lit from the top left, a dark underside.
const CLODS: Array = [["B"], ["LB", "BD"], [".LB", "LBB", "BDD"], [".LB.", "LBBB", "BBBD", ".DD."]]
## A grass blade flicked up, two bends.
const BLADES: Array = [[".L", "B.", "B."], ["L.", ".B", ".B"]]


static func _step(symbol: String, by: int) -> String:
	for ramp: String in RAMPS:
		var i: int = ramp.find(symbol)
		if i >= 0:
			return ramp[clampi(i + by, 0, ramp.length() - 1)]
	return symbol


## A pixel pattern (rows of B/L/D, "." empty) at `at`, mirrored when `flip`, in the shades of `symbol`. With an `outline` colour it
## first gets a 1 px rim in it (a green leaf on green grass needs one to be seen).
static func _pattern(canvas: CanvasItem, rows: Array, at: Vector2, symbol: String, colors: Dictionary, flip: bool, dark_by: int = 1, outline: Color = Color(0, 0, 0, 0)) -> void:
	var shades: Dictionary = {"B": colors.get(symbol, Color.WHITE), "L": colors.get(_step(symbol, 1), Color.WHITE), "D": colors.get(_step(symbol, -dark_by), Color.BLACK)}
	var w: int = String(rows[0]).length()
	var origin: Vector2 = at - Vector2(w / 2, rows.size() / 2)
	if outline.a > 0.0:
		for y: int in rows.size():
			var line: String = rows[y]
			for x: int in w:
				if (line[w - 1 - x] if flip else line[x]) != ".":
					canvas.draw_rect(Rect2(origin + Vector2(x - 1, y - 1), Vector2(3, 3)), outline)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in w:
			var c: String = row[w - 1 - x] if flip else row[x]
			if c != ".":
				canvas.draw_rect(Rect2(origin + Vector2(x, y), Vector2.ONE), shades[c])


## A hard-edged pixel disc (whole-pixel row spans, no smoothing).
static func _disc(canvas: CanvasItem, centre: Vector2, radius: float, colour: Color) -> void:
	var c: Vector2 = centre.round()
	if radius < 0.8:
		canvas.draw_rect(Rect2(c, Vector2.ONE), colour)
		return
	var rows: int = int(ceil(radius - 0.2))
	for dy: int in range(-rows, rows + 1):
		var half: int = int(floor(sqrt(maxf(0.0, radius * radius - float(dy * dy))) + 0.3))
		canvas.draw_rect(Rect2(c + Vector2(-half, dy), Vector2(half * 2 + 1, 1)), colour)


## A puff of dust or smoke: a lumpy cloud (a body and two side lobes) with a darker underside and a lighter top; late in its life it
## breaks into three wisps that drift apart, then shrinks away (hard pixels only).
static func _puff(canvas: CanvasItem, at: Vector2, size: float, symbol: String, frac: float, seed_flip: int, colors: Dictionary) -> void:
	var base: Color = colors.get(symbol, Color.WHITE)
	var dark: Color = colors.get(_step(symbol, -1), base)
	var light: Color = colors.get(_step(symbol, 1), base)
	var r: float = clampf(roundf(size), 1.0, 6.0)  # its lobes reach 1.4 r: a puff stays under ~17 px
	var side: float = -1.0 if seed_flip == 1 else 1.0
	# a cloud: wide low lobes at the sides, two bumps on top, a flat-ish bottom
	var lobes: Array[Vector2] = [Vector2(-0.85 * side, 0.2), Vector2(0.85 * side, 0.25), Vector2(-0.3 * side, -0.45), Vector2(0.4 * side, -0.35)]
	var sizes: Array[float] = [0.6, 0.55, 0.55, 0.5]
	if frac < 0.72:
		for k: int in lobes.size():
			_disc(canvas, at + lobes[k] * r + Vector2(0, 1), r * sizes[k], dark)
		_disc(canvas, at + Vector2(0, 1), r * 0.8, dark)
		for k: int in lobes.size():
			_disc(canvas, at + lobes[k] * r, r * sizes[k], base)
		_disc(canvas, at, r * 0.8, base)
		_disc(canvas, at + lobes[2] * r + Vector2(-0.1, -0.15) * r, maxf(0.5, r * 0.3), light)
	else:
		var apart: float = 1.0 + (frac - 0.72) * 3.0
		for k: int in [0, 1, 3]:
			_disc(canvas, at + lobes[k] * r * apart + Vector2(0, 1), r * 0.4, dark)
			_disc(canvas, at + lobes[k] * r * apart, r * 0.4, base)


static func draw(canvas: CanvasItem, bursts: Array[Dictionary], tick: int, colors: Dictionary) -> void:
	for burst: Dictionary in bursts:
		for p: Dictionary in points(burst, tick):
			var at: Vector2 = Vector2(p["at"]).round()
			var symbol: String = p["col"]
			var colour: Color = colors.get(symbol, Color.WHITE)
			var size: float = float(p["size"])
			var age: int = int(p["age"])
			var flip: bool = int(p["flip"]) == 1
			match String(p["shape"]):
				"smoke":
					_puff(canvas, at, size, symbol, float(p["frac"]), int(p["flip"]), colors)
				"leaf":
					# tumbles through its four turns (faster while it is thrown, slower as it drifts down)
					var turn: int = posmod(age / (3 if age < 12 else 5) + int(p["flip"]), 4)
					_pattern(canvas, LEAF_TURNS[turn], at, symbol, colors, flip, 2, colors["2"])
				"blade":
					_pattern(canvas, BLADES[posmod(age / 6 + int(p["flip"]), 2)], at, symbol, colors, flip, 1, colors["2"])
				"mote":
					# a healing sparkle: a dark-green edged cross with a light green heart that pulses, so it stays green under the night light
					var big: bool = (age / 6) % 2 == 0
					canvas.draw_rect(Rect2(at + Vector2(-2, -1), Vector2(5, 3)), colors["3"])
					canvas.draw_rect(Rect2(at + Vector2(-1, -2), Vector2(3, 5)), colors["3"])
					canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), colour)
					canvas.draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), colour)
					canvas.draw_rect(Rect2(at, Vector2.ONE), colors["7"] if big else colour)
				"spark":
					# twinkles: a dot, a cross, a star with a bright heart, a cross again (fresh sparks start as a star)
					var phase: int = 2 if age < 3 else posmod(age / 2 + int(p["flip"]) * 3, 6)
					var heart: Color = colors.get(_step(symbol, 1), colour)
					if phase in [1, 3]:
						canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), colour)
						canvas.draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), colour)
					elif phase == 2:
						canvas.draw_rect(Rect2(at + Vector2(-2, 0), Vector2(5, 1)), colour)
						canvas.draw_rect(Rect2(at + Vector2(0, -2), Vector2(1, 5)), colour)
						canvas.draw_rect(Rect2(at, Vector2.ONE), heart)
						continue
					canvas.draw_rect(Rect2(at, Vector2.ONE), heart if phase != 0 else colour)
				_:
					# a clod of dirt or grit, lit from the top left, by its size
					_pattern(canvas, CLODS[clampi(int(roundf(size)) - 1, 0, 3)], at, symbol, colors, flip)
