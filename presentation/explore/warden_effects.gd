extends RefCounted
## Cosmetic history only. Ground geometry is the committed core telegraph, never the body scale.
const Snapshots := preload("res://core/snapshots.gd")
const Explore := preload("res://core/explore_core.gd")
const GameEvent := preload("res://core/game_event.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
static var attachments: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/explore/warden_attachments.json"))

const RUNE_COLOUR: Vector3 = Vector3(0.48, 0.94, 0.86)  # the rune stones' teal (presentation/common/local_lights.json)
const RUNE_CORE: Vector3 = Vector3(0.8, 1.0, 1.0)
const MobView := preload("res://presentation/explore/mob_view.gd")
const SHADOW_RADIUS: float = 40.0  # ActorShadow radius: a 26 x 7 px ellipse under its 69 px wide stance (drawn 1.5x smaller since 2026-10-31)
## The footfall frames of the walk (tools/art/rig_warden_v2.py poses(): the planted foot's offset from the feet, + = the leading side)
## and how long a footprint and a torn patch of ground stay on the floor.
const FOOTFALLS: Dictionary = {"warden_walk_right_1": 10.0, "warden_walk_right_4": -2.0}
const PRINT_TICKS: int = 90
const SCAR_TICKS: int = 70


## Where the Warden's chest stone is in the world for the frame `key` (attachment units: world px / 2.5, tools/art/rig_warden_v2.py).
static func chest_world(mob: Dictionary, key: String) -> Vector2:
	var chest: Array = attachments.get(key, {"chest": [5, -18]})["chest"]
	var left: bool = Vector2(mob["facing"]).x < 0.0
	return Vector2(mob["position"]) + Vector2(float(chest[0]) * (-1.0 if left else 1.0), float(chest[1])) * 2.5


## The moving rune lamps of the living Wardens, in the lighting shader's lamp format: a halo at the chest stone (like a rune stone's
## socket) and a pool on the floor under it. Full while the rune guard is up, a dim ember while it is exposed (the guard-down cue stays).
## [{point: Vector4, colour: Vector3, core: Vector3}]
static func lamps(mobs: Array[Dictionary], keys: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mob: Dictionary in mobs:
		if mob["type"] != &"warden" or mob["state"] == &"dead":
			continue
		var guarded: bool = bool(mob.get("guarded", false))
		var chest: Vector2 = chest_world(mob, String(keys.get(int(mob["id"]), "")))
		var feet: Vector2 = mob["position"]
		out.append({"point": Vector4(chest.x, chest.y, 34.0 if guarded else 14.0, 1.3 if guarded else 0.35), "colour": RUNE_COLOUR, "core": RUNE_CORE})
		out.append({"point": Vector4(chest.x, feet.y + 3.0, 44.0 if guarded else 20.0, -(0.85 if guarded else 0.2)), "colour": RUNE_COLOUR, "core": RUNE_CORE})
	return out
var tells: Dictionary = {}
var hits: Dictionary = {}
var breaks: Dictionary = {}
var arrivals: Dictionary = {}
var previous: Dictionary = {}
var last_tick: int = -1
var scene_id: StringName = &""
var keys: Dictionary = {}  # id -> the body frame of the last snapshot (a footfall is a change to a planted frame)
var prints: Array[Dictionary] = []  # footprints: {at, tick}
var scars: Array[Dictionary] = []  # ground torn by a strike: {tell, tick}
var fired: Dictionary = {}  # telegraph ids whose hit already threw particles
var pending_bursts: Array[Dictionary] = []  # particle bursts for creature_effects.gd to start: {kind, at, tick, extra}

func clear() -> void:
	tells.clear()
	hits.clear()
	breaks.clear()
	arrivals.clear()
	previous.clear()
	keys.clear()
	prints.clear()
	scars.clear()
	fired.clear()
	pending_bursts.clear()
	last_tick = -1
	scene_id = &""

func handle_event(event: GameEvent, view: Explore.ExploreSnapshot) -> void:
	if event.type == &"attack_hit" and bool(event.data.get("guarded", false)):
		for mob: Dictionary in view.mobs:
			if mob["type"] == &"warden" and mob["id"] == event.data.get("target_id", -1):
				hits[int(mob["id"])] = event.tick
				_burst("chips", chest_world(mob, String(keys.get(int(mob["id"]), ""))), event.tick)


func _burst(kind: String, at: Vector2, tick: int, extra: Dictionary = {}) -> void:
	pending_bursts.append({"kind": kind, "at": at, "tick": tick, "extra": extra})

func sync(view: Explore.ExploreSnapshot) -> void:
	if view.scene_id != scene_id or view.tick < last_tick:
		clear()
	if view.tick == last_tick:
		return
	scene_id = view.scene_id
	last_tick = view.tick
	var alive: Dictionary = {}
	for mob: Dictionary in view.mobs:
		if mob["type"] != &"warden":
			continue
		var id: int = int(mob["id"])
		alive[id] = mob
		if not previous.has(id):
			arrivals[id] = view.tick
		if mob["state"] == &"stagger" and previous.get(id, &"") != &"stagger":
			breaks[id] = view.tick
			_burst("stomp", mob["position"], view.tick)
		if mob["state"] == &"dead" and previous.has(id) and previous[id] != &"dead":
			_burst("crash", Vector2(mob["position"]) + Vector2(0, -4), view.tick, {"dir": Vector2(mob["facing"])})
		previous[id] = mob["state"]
		# Footfalls: the walk's planted frames stamp dust and a print under the foot that came down.
		var key: String = MobView.frame(mob, view.telegraphs, view.tick)
		if FOOTFALLS.has(key) and keys.get(id, "") != key:
			var side: float = -1.0 if Vector2(mob["facing"]).x < 0.0 else 1.0
			var foot: Vector2 = Vector2(mob["position"]) + Vector2(float(FOOTFALLS[key]) * side, 1.0)
			prints.append({"at": foot.round(), "tick": view.tick})
			_burst("stomp", foot, view.tick)
		keys[id] = key
	for tell: Snapshots.TelegraphSnapshot in view.telegraphs:
		if alive.has(tell.owner_id):
			tells[tell.owner_id] = tell
	# The hit tick of each attack throws its particles once and leaves the ground torn (the real hit area, nothing wider).
	for tell: Snapshots.TelegraphSnapshot in tells.values():
		if view.tick < tell.hit_tick or fired.has(tell.id):
			continue
		fired[tell.id] = view.tick
		scars.append({"tell": tell, "tick": tell.hit_tick})
		match tell.shape:
			&"cone":
				_burst("gouge", tell.center, tell.hit_tick, {"dir": tell.direction, "half_angle": tell.half_angle, "size": tell.size})
			&"line":
				for i: int in 6:
					_burst("roots", tell.center + tell.direction * tell.size * (float(i) + 0.5) / 6.0, tell.hit_tick + i)
			_:
				_burst("quake", tell.center, tell.hit_tick, {"size": tell.size})
	for id: int in fired.keys():
		if view.tick - int(fired[id]) > 120:
			fired.erase(id)
	prints = prints.filter(func(p: Dictionary) -> bool: return view.tick - int(p["tick"]) < PRINT_TICKS)
	scars = scars.filter(func(p: Dictionary) -> bool: return view.tick - int(p["tick"]) < SCAR_TICKS)
	if prints.size() > 40:
		prints = prints.slice(prints.size() - 40)
	for id: int in tells.keys():
		var mob: Dictionary = alive.get(id, {})
		var tell: Snapshots.TelegraphSnapshot = tells[id]
		if mob.is_empty() or mob["state"] not in [&"windup", &"strike", &"recover"] or view.tick > tell.end_tick + 24:
			tells.erase(id)
	for history: Dictionary in [previous, arrivals, hits, breaks, keys]:
		for id: int in history.keys():
			if not alive.has(id):
				history.erase(id)

func active_tells(tick: int) -> Array[Snapshots.TelegraphSnapshot]:
	var out: Array[Snapshots.TelegraphSnapshot] = []
	for tell: Snapshots.TelegraphSnapshot in tells.values():
		if tick >= tell.hit_tick and tick < tell.end_tick:
			out.append(tell)
	return out

## The floor around the Warden: its footprints, the ground its strikes tore (where they really hit), and each strike while it is active,
## drawn at the committed telegraph's real size (owner playtest 2026-10-31: the effects must match the Warden's size).
func draw_ground(canvas: CanvasItem, tick: int, colors: Dictionary) -> void:
	for mark: Dictionary in prints:
		var age: int = tick - int(mark["tick"])
		var at: Vector2 = mark["at"]
		if age > PRINT_TICKS - 30 and (int(at.x) + int(at.y) + age / 3) % 2 == 0:
			continue  # an old print breaks up before it goes
		canvas.draw_rect(Rect2(at + Vector2(-4, -1), Vector2(8, 2)), colors["8"])
		canvas.draw_rect(Rect2(at + Vector2(-3, -2), Vector2(6, 1)), colors["9"])
		canvas.draw_rect(Rect2(at + Vector2(-6, 0), Vector2(2, 1)), colors["8"])
		canvas.draw_rect(Rect2(at + Vector2(4, 0), Vector2(2, 1)), colors["8"])
	for scar: Dictionary in scars:
		_draw_scar(canvas, scar["tell"], tick - int(scar["tick"]), colors)
	for tell: Snapshots.TelegraphSnapshot in tells.values():
		var age: int = tick - tell.hit_tick
		var span: int = maxi(1, tell.end_tick - tell.hit_tick)
		if age >= 0 and tick < tell.end_tick + 6:
			match tell.shape:
				&"cone":
					_draw_cleave(canvas, tell, age, span, colors)
				&"line":
					_draw_lash(canvas, tell, age, span, colors)
				_:
					_draw_shock(canvas, tell, age, span, colors)
		elif age < 0 and tell.shape == &"line":
			# the lash winding up: a crack runs out under the floor along the line it will tear
			var progress: float = clampf(float(tick - tell.start_tick) / maxi(1, tell.hit_tick - tell.start_tick), 0.0, 1.0)
			var crack: PackedVector2Array = []
			for i: int in 19:
				var t: float = progress * float(i) / 18.0
				crack.append((tell.center + tell.direction * tell.size * t + tell.direction.orthogonal() * (2.0 if i % 2 == 0 else -2.0)).round())
			canvas.draw_polyline(crack, colors["8"], 2.0, false)
			canvas.draw_polyline(crack, colors["t"], 1.0, false)


## The Cleave: the blade's swept trail across the real cone (from one side to the other over the strike), drawn as slash lines out to
## the cone's real edge: a cream leading edge, gold behind it, the outer lines longest (the hook tip travels furthest), all gone a few
## ticks after the strike.
static func _draw_cleave(canvas: CanvasItem, tell: Snapshots.TelegraphSnapshot, age: int, span: int, colors: Dictionary) -> void:
	var sweep: float = clampf(float(age + 1) / float(span), 0.0, 1.0)
	var fade: int = maxi(0, age - span)
	if fade >= 5:
		return
	var start: float = tell.direction.angle() - tell.half_angle
	var lead: float = start + 2.0 * tell.half_angle * sweep
	for k: int in 6:
		var r: float = tell.size * (1.0 - 0.07 * float(k))
		var tail: float = lerpf(lead, start, clampf(0.95 - 0.13 * float(k) - 0.2 * float(fade), 0.0, 1.0))  # inner lines trail shorter
		if lead - tail < 0.02:
			continue
		var line: PackedVector2Array = []
		for i: int in 17:
			line.append((tell.center + Vector2.from_angle(lerpf(tail, lead, float(i) / 16.0)) * r).round())
		var cut: int = 12 if k < 2 else 14
		canvas.draw_polyline(line.slice(0, cut + 1), colors["y"] if k % 2 == 0 else colors["x"], 2.0 if k < 2 else 1.0, false)
		canvas.draw_polyline(line.slice(cut), colors["1"], 2.0 if k < 2 else 1.0, false)


## The Lash: roots burst out of the floor one after another along the real line (inside its width), stand while it is active, then sink.
static func _draw_lash(canvas: CanvasItem, tell: Snapshots.TelegraphSnapshot, age: int, span: int, colors: Dictionary) -> void:
	var across: Vector2 = tell.direction.orthogonal()
	var count: int = maxi(4, int(tell.size / 12.0))
	for i: int in count:
		var t: float = (float(i) + 0.5) / float(count)
		var born: int = int(t * 6.0)  # the eruption runs out along the line in six ticks
		var grown: float = clampf(float(age - born + 1) / 3.0, 0.0, 1.0)
		if age >= span:
			grown *= clampf(1.0 - float(age - span) / 6.0, 0.0, 1.0)
		if grown <= 0.0:
			continue
		var side: float = (1.0 if i % 2 == 0 else -1.0) * tell.width * 0.22
		var base: Vector2 = (tell.center + tell.direction * tell.size * t + across * side).round()
		var height: float = (14.0 + float((i * 7) % 5) * 3.0) * grown
		var lean: Vector2 = tell.direction * 3.0
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 2), base + Vector2(6, 2), base + Vector2(5, -1), base + Vector2(-5, -1)]), colors["8"])
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 1), base + Vector2(4, 1), base + lean + Vector2(1, -height), base + lean + Vector2(-1, -height)]), colors["0"])
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-2, 0), base + Vector2(2, 0), base + lean + Vector2(0, 1 - height), base + lean + Vector2(-1, 1 - height)]), colors["c"] if i % 2 == 0 else colors["b"])
		canvas.draw_line((base + Vector2(-1, -1)).round(), (base + lean * 0.6 + Vector2(-1, 2 - height * 0.6)).round(), colors["d"], 1.0, false)  # lit edge
		canvas.draw_rect(Rect2((base + lean + Vector2(-1, -height - 1)).round(), Vector2(2, 3)), colors["z"] if age < span else colors["u"])


## The Spore Ring: a shock band runs out from the Warden to the ring's real edge and holds there for a moment.
static func _draw_shock(canvas: CanvasItem, tell: Snapshots.TelegraphSnapshot, age: int, span: int, colors: Dictionary) -> void:
	var front: float = tell.size * minf(1.0, float(age + 1) / maxf(1.0, float(span)))
	for layer: int in 3:
		var r: float = front - float(layer) * 4.0
		if r <= 3.0:
			continue
		var colour: Color = colors["z"] if layer == 0 and age < span else (colors["j"] if layer == 0 else (colors["i"] if layer == 1 else colors["9"]))
		canvas.draw_arc(tell.center.round(), r, 0.0, TAU, 48, colour, 2.0 if layer == 0 else 1.0, false)
	for i: int in 16:
		var angle: float = float(i) / 16.0 * TAU + 0.2
		var point: Vector2 = (tell.center + Vector2.from_angle(angle) * front).round()
		canvas.draw_rect(Rect2(point - Vector2.ONE, Vector2(3, 3)), colors["9"])
		canvas.draw_rect(Rect2(point - Vector2(0, 1), Vector2(1, 1)), colors["j"])


## Torn ground the strike leaves at its real hit area: furrows for the Cleave, a split line for the Lash, a cracked ring for the Ring.
static func _draw_scar(canvas: CanvasItem, tell: Snapshots.TelegraphSnapshot, age: int, colors: Dictionary) -> void:
	if age < tell.end_tick - tell.hit_tick or age >= SCAR_TICKS:
		return  # the torn ground shows once the strike itself is over
	var thin: bool = age > SCAR_TICKS - 24
	match tell.shape:
		&"cone":
			for k: int in 3:
				var r: float = tell.size * (0.62 + 0.15 * float(k))
				var furrow: PackedVector2Array = []
				for i: int in 15:
					var angle: float = tell.direction.angle() + tell.half_angle * (float(i) / 7.0 - 1.0) * (0.85 - 0.1 * float(k))
					furrow.append((tell.center + Vector2.from_angle(angle) * (r + (1.0 if (i + k) % 3 == 0 else 0.0))).round())
				canvas.draw_polyline(furrow, colors["8"], 1.0 if thin else 2.0, false)
		&"line":
			var split: PackedVector2Array = []
			for i: int in 25:
				split.append((tell.center + tell.direction * tell.size * float(i) / 24.0 + tell.direction.orthogonal() * (1.0 if i % 4 == 0 else 0.0)).round())
			canvas.draw_polyline(split, colors["8"], 1.0 if thin else 2.0, false)
		_:
			for i: int in 12:
				if i % 4 == 3:
					continue
				var a0: float = float(i) / 12.0 * TAU
				canvas.draw_arc(tell.center.round(), tell.size - 1.0, a0, a0 + TAU / 14.0, 6, colors["8"], 1.0 if thin else 2.0, false)


## Contact shadow under the feet (darker than the wide stance shadow), so the Warden stands on the floor instead of floating.
func draw_feet(canvas: CanvasItem, mobs: Array[Dictionary]) -> void:
	for mob: Dictionary in mobs:
		if mob["type"] != &"warden" or mob["state"] == &"dead":
			continue
		var at: Vector2 = Vector2(mob["position"]).round()
		var side: float = -1.0 if Vector2(mob["facing"]).x < 0.0 else 1.0
		for x: float in [-9.0, 7.0]:
			var foot: Vector2 = at + Vector2(x * side, 1)
			canvas.draw_rect(Rect2(foot + Vector2(-6, -1), Vector2(12, 2)), Color(0.11, 0.094, 0.141, 0.38))
			canvas.draw_rect(Rect2(foot + Vector2(-4, -2), Vector2(8, 4)), Color(0.11, 0.094, 0.141, 0.22))


static func sprite(canvas: CanvasItem, family: String, n: int, at: Vector2, frames: Dictionary, atlas: Texture2D, left: bool) -> void:
	var key: String = "fx_warden_%s_%d" % [family, n]
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	# The effect frames are drawn at their native game size (redrawn at 2.5x by tools/art/redraw_warden_2p5.py): no stretching here.
	var dest: Rect2 = ArenaAnimation.destination(at.round(), f, left)
	canvas.draw_texture_rect_region(atlas, dest, Rect2(f["x"], f["y"], f["w"], f["h"]))

func draw_actor(canvas: CanvasItem, mob: Dictionary, key: String, tick: int, frames: Dictionary, atlas: Texture2D) -> void:
	var id: int = int(mob["id"])
	var at: Vector2 = mob["position"]
	var left: bool = Vector2(mob["facing"]).x < 0.0
	var state: StringName = mob["state"]
	var body_frame: int = int(key.get_slice("_", key.get_slice_count("_") - 1))
	if state == &"dead":
		if int(mob["state_ticks"]) < 12:
			sprite(canvas, "death_flash", mini(4, int(mob["state_ticks"]) / 3 + 1), at, frames, atlas, left)
		sprite(canvas, "death_debris", mini(8, body_frame), at, frames, atlas, left)
		return
	# The chest stone's glow is the scene's rune lamp (lamps()) and the halo (creature_glow.gd); a guard hit throws chips (handle_event).
	if bool(mob.get("guarded", false)):
		sprite(canvas, "idle_spores", posmod(tick / 8 + id, 6) + 1, at, frames, atlas, left)
	if breaks.has(id) and tick - int(breaks[id]) < 16:
		sprite(canvas, "guard_break", mini(8, (tick - int(breaks[id])) / 2 + 1), at, frames, atlas, left)
	if state == &"stagger":
		sprite(canvas, "exposed_dust", posmod(tick / 6, 6) + 1, at, frames, atlas, left)
	if arrivals.has(id) and tick - int(arrivals[id]) < 18:
		sprite(canvas, "arrival", mini(6, (tick - int(arrivals[id])) / 3 + 1), at, frames, atlas, left)
	if state == &"windup" and mob.get("attack", &"") == &"warden_ring":
		# the Spore Ring gathers: spores and rune light spiral in to the chest stone (the warning on the floor is the telegraph's own)
		var chest_at: Vector2 = chest_world(mob, key)
		var progress: float = clampf(float(mob["state_ticks"]) / 56.0, 0.0, 1.0)
		for i: int in 10:
			var turn: float = float(i) / 10.0 * TAU + float(tick) * 0.09
			var reach: float = lerpf(31.0, 7.0, fposmod(float(tick) * 0.03 + float(i) * 0.37, 1.0))
			var point: Vector2 = (chest_at + Vector2(cos(turn) * reach, sin(turn) * reach * 0.55)).round()
			var colour: Color = Color("e0f0ec") if (i + tick / 4) % 3 == 0 else Color("6aa89a")
			canvas.draw_rect(Rect2(point, Vector2.ONE * (2.0 if progress > 0.6 and i % 2 == 0 else 1.0)), colour)
