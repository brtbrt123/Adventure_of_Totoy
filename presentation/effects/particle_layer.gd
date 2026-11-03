@tool
extends Resource
## One layer of a particle burst kind (presentation/effects/particles/<kind>.tres, owner 2026-11-01: "make the rest editable").
## The particles of a layer start together when the burst is thrown and each moves on its own seeded path
## (presentation/explore/creature_particles.gd); every value below is editable in the Inspector. Distances are game pixels, times
## ticks (60 a second).

@export_range(0, 200) var count: int = 8  ## how many particles
@export_enum("dot", "smoke", "leaf", "blade", "spark", "mote") var shape: String = "dot"  ## dot: grit/clod; smoke: dust puff; leaf; blade: grass; spark: twinkle; mote: heal cross
@export_range(1, 240) var life_min: int = 12  ## shortest life (ticks)
@export_range(1, 240) var life_max: int = 24  ## longest life (ticks)
@export_range(0.0, 5.0, 0.01) var speed_min: float = 0.5  ## slowest start speed (px a tick)
@export_range(0.0, 5.0, 0.01) var speed_max: float = 1.0  ## fastest start speed (px a tick)
@export_range(0.0, 0.5, 0.005) var drag: float = 0.05  ## share of its speed lost every tick
@export_range(-2.0, 3.0, 0.01) var up: float = 0.3  ## extra upward speed at the start (px a tick)
@export_range(-0.3, 0.3, 0.001) var gravity: float = 0.05  ## px a tick, each tick (+ falls, - rises)
@export_range(0.0, 8.0, 0.5) var size_min: float = 1.0  ## smallest size (px)
@export_range(0.0, 8.0, 0.5) var size_max: float = 2.0  ## largest size (px)
@export_range(0.0, 0.5, 0.01) var grow: float = 0.0  ## smoke only: px it grows a tick
@export_range(0.0, 6.0, 0.1) var flutter: float = 0.0  ## leaves and motes: px of sideways sway
## Totoy 36 palette symbols (art/palette.json), picked at random per particle (smoke fades through them in order): dirt 8 9 a b c d,
## stone e f g h i j, cream 1, moss 2 3 4 5 6 7, water/teal k l m n o p, teal t u, gold x y, red z A.
@export var colours: PackedStringArray = PackedStringArray(["c"])


## The layer in the shape creature_particles.gd reads.
func to_layer() -> Dictionary:
	var out: Dictionary = {"n": count, "shape": shape, "life": [life_min, maxi(life_min, life_max)], "speed": [speed_min, maxf(speed_min, speed_max)],
		"drag": drag, "up": up, "g": gravity, "size": [size_min, maxf(size_min, size_max)], "cols": Array(colours) if not colours.is_empty() else ["c"]}
	if grow != 0.0:
		out["grow"] = grow
	if flutter != 0.0:
		out["flutter"] = flutter
	return out


## Fills the layer from creature_particles.gd's built-in table (the generator's starting values).
func from_layer(layer: Dictionary) -> void:
	count = int(layer["n"])
	shape = String(layer["shape"])
	life_min = int(layer["life"][0])
	life_max = int(layer["life"][1])
	speed_min = float(layer["speed"][0])
	speed_max = float(layer["speed"][1])
	drag = float(layer["drag"])
	up = float(layer["up"])
	gravity = float(layer["g"])
	size_min = float(layer["size"][0])
	size_max = float(layer["size"][1])
	grow = float(layer.get("grow", 0.0))
	flutter = float(layer.get("flutter", 0.0))
	colours = PackedStringArray(layer["cols"])
