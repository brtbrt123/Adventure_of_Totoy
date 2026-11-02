extends RefCounted
## The blades' basic attack slash, drawn from the hit test itself (owner 2026-11-02: "check the basic attack range match effects
## on it"; before that "make it just a crescent slash"). A swing hits what is within its reach of the hero's feet and inside its
## arc (core/weapons.gd swing_reach and swing_arc_dot), so the slash is a crescent on the ground whose outer edge is that reach
## and whose ends are that arc, turned to where he faces: what the crescent covers is what the swing hits, in every direction.
## It sweeps from one end of the arc to the other during the swing (odd swings one way, even swings back), white hot where the
## blade is, then fades through the recovery. Drawn in the Star Staff's style: Totoy 36 colours, hard alpha, ordered dithering
## for the fade (fx_particles.gd keep). It replaces the pose-traced trail frames (fx_weapon_path_*), which reached behind and
## above the hero where nothing is hit. The Star Staff casts instead (staff_view.gd). Pure presentation.
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")
const FxParticles := preload("res://presentation/common/fx_particles.gd")

## Each blade's slash, edge to inside (the old trails' colours: lilac katana, steel daggers, teal scythe).
const COLOURS: Dictionary = {
	Tuning.WEAPON_BLACK_KATANA: ["1", "p", "v", "l", "k"],
	Tuning.WEAPON_DUAL_DAGGER: ["1", "p", "o", "n", "l"],
	Tuning.WEAPON_CHAIN_SCYTHE: ["1", "p", "u", "t", "k"],
}
const LEAD_TICKS: int = 2  # the sweep starts this many ticks before the active frames
const FADE_TICKS: int = 8  # the recovery fades it out over this many ticks (the finisher over FADE_TICKS + 4)


## The slash the hero shows this tick, or {} for none: {center (his feet), reach, from, to (angles in radians: the arc's ends,
## the sweep goes from -> to), progress (0..1: how far the blade has gone), fade (1 while sweeping, then down to 0), colours,
## finisher, swing}. `left` is the side his sprite faces (picks the sweep's direction when he faces straight up or down);
## `pose` is the frame shown (an interrupted or unarmed pose shows no slash).
static func plan(hero: Snapshots.EntitySnapshot, left: bool, pose: String) -> Dictionary:
	if hero == null or not COLOURS.has(hero.weapon_id) or hero.state not in [&"attack_windup", &"attack_active", &"attack_recovery"]:
		return {}
	if not pose.contains("_attack") or pose.contains("_unarmed"):
		return {}
	var weapon: StringName = hero.weapon_id
	var swing: int = clampi(hero.combo_index, 1, Weapons.combo_max(weapon))
	var phases: Array[int] = Weapons.swing_phases(weapon, swing)
	var finisher: bool = swing == Weapons.combo_max(weapon)
	var progress: float = 1.0
	var fade: float = 1.0
	match hero.state:
		&"attack_windup":
			var lead_in: int = hero.state_ticks - (phases[0] - LEAD_TICKS)
			if lead_in < 0:
				return {}
			progress = 0.1 * float(lead_in + 1)
		&"attack_active":
			progress = 0.25 + 0.75 * clampf(float(hero.state_ticks + 1) / float(maxi(1, phases[1])), 0.0, 1.0)
		&"attack_recovery":
			fade = 1.0 - float(hero.state_ticks) / float(FADE_TICKS + (4 if finisher else 0))
			if fade <= 0.0:
				return {}
	var facing: Vector2 = hero.facing if hero.facing.length() > 0.01 else (Vector2.LEFT if left else Vector2.RIGHT)
	var half: float = acos(clampf(Weapons.swing_arc_dot(weapon), -1.0, 1.0))
	# odd swings sweep top to bottom on his right side (mirrored on the left), even swings back; the screen's y points down
	var side: float = -1.0 if (facing.x < -0.01 or (absf(facing.x) <= 0.01 and left)) else 1.0
	var down: float = (1.0 if swing % 2 == 1 else -1.0) * side
	var angle: float = facing.angle()
	return {"center": hero.position, "reach": Weapons.swing_reach(weapon, swing), "from": angle - half * down, "to": angle + half * down,
		"progress": clampf(progress, 0.0, 1.0), "fade": fade, "colours": COLOURS[weapon], "finisher": finisher, "swing": swing}


## The point of the blade on the ground (the slash's leading end) for a plan.
static func lead_point(p: Dictionary) -> Vector2:
	var a: float = lerpf(float(p["from"]), float(p["to"]), float(p["progress"]))
	return Vector2(p["center"]) + Vector2.from_angle(a) * float(p["reach"])


## The crescent: its outer edge on the reach, thickest in the middle and toward the blade, the edge hot and the body in the
## blade's colour, the inside and the tail thinning out by dithering; the recovery cools it and dithers it away.
static func draw(canvas: CanvasItem, colors: Dictionary, p: Dictionary, glow: float) -> void:
	for pixel: Array in pixels(p):
		canvas.draw_rect(Rect2(pixel[0], Vector2.ONE), Color(colors[pixel[1]], glow))


## The crescent's pixels for a plan: [Vector2 position, palette symbol], dithering already applied. Shared by draw() and the tests.
static func pixels(p: Dictionary) -> Array[Array]:
	var center: Vector2 = Vector2(p["center"]).round()
	var out: Array[Array] = []
	for cell: Array in _shape(p):
		var spot: Vector2 = center + Vector2(cell[0])
		if FxParticles.keep(spot, float(cell[2])):
			out.append([spot, cell[1]])
	return out


static var _shapes: Dictionary = {}


## The crescent around (0, 0): [Vector2i offset, symbol, alpha]. Cached: a swing shows a handful of distinct shapes.
static func _shape(p: Dictionary) -> Array:
	var key: String = "%s|%d|%d|%d|%d|%d|%s" % [p["colours"][2], roundi(float(p["reach"]) * 10.0), roundi(float(p["from"]) * 200.0),
		roundi(float(p["to"]) * 200.0), roundi(float(p["progress"]) * 40.0), roundi(float(p["fade"]) * 40.0), p["finisher"]]
	if _shapes.has(key):
		return _shapes[key]
	var colours: Array = p["colours"]
	var reach: float = p["reach"]
	var a0: float = p["from"]
	var a1: float = p["to"]
	var progress: float = p["progress"]
	var fade: float = p["fade"]
	var tmax: float = minf(11.0, reach * (0.34 if bool(p["finisher"]) else 0.28))
	var cool: float = 0.0 if fade >= 1.0 else (1.0 - fade) * 1.8
	var best: Dictionary = {}  # Vector2i -> [level, alpha]
	var steps: int = maxi(12, int(absf(a1 - a0) * reach * 2.5 * progress))
	for k: int in steps + 1:
		var lead: float = float(k) / float(steps)  # 0 at the tail, 1 at the blade
		var dir: Vector2 = Vector2.from_angle(lerpf(a0, a1, progress * lead))
		var thick: float = tmax * pow(sin(PI * minf(1.0, 0.05 + 0.93 * lead)), 0.65) * (0.5 + 0.5 * lead)
		for di: int in int(thick * 2.0) + 1:
			var depth: float = float(di) * 0.5
			var f: float = depth / maxf(1.0, thick)
			var level: float = (1.0 if depth < 0.75 else (2.0 if f < 0.7 else 3.0)) + (1.0 if lead < 0.3 else 0.0) + cool
			if fade >= 1.0 and lead > 0.72 and depth < 1.25:
				level = 0.0  # where the blade is now: white hot
			var alpha: float = fade * clampf((1.15 - f) / 0.5, 0.0, 1.0) * clampf((lead + 0.2) / 0.35, 0.0, 1.0)
			var at: Vector2i = Vector2i((dir * (reach - depth)).round())
			if not best.has(at) or level < float(best[at][0]):
				best[at] = [level, alpha]
	var shape: Array = []
	for at: Vector2i in best:
		shape.append([at, colours[mini(colours.size() - 1, int(best[at][0]))], best[at][1]])
	if _shapes.size() > 256:
		_shapes.clear()
	_shapes[key] = shape
	return shape
