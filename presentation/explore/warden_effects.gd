extends RefCounted
## Cosmetic history only. Ground geometry is the committed core telegraph, never the body scale.
const Snapshots := preload("res://core/snapshots.gd")
const Explore := preload("res://core/explore_core.gd")
const GameEvent := preload("res://core/game_event.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
static var attachments: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/explore/warden_attachments.json"))
var tells: Dictionary = {}
var hits: Dictionary = {}
var breaks: Dictionary = {}
var arrivals: Dictionary = {}
var previous: Dictionary = {}
var last_tick: int = -1
var scene_id: StringName = &""

func clear() -> void:
	tells.clear()
	hits.clear()
	breaks.clear()
	arrivals.clear()
	previous.clear()
	last_tick = -1
	scene_id = &""

func handle_event(event: GameEvent, view: Explore.ExploreSnapshot) -> void:
	if event.type == &"attack_hit" and bool(event.data.get("guarded", false)):
		for mob: Dictionary in view.mobs:
			if mob["type"] == &"warden" and mob["id"] == event.data.get("target_id", -1):
				hits[int(mob["id"])] = event.tick

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
		previous[id] = mob["state"]
	for tell: Snapshots.TelegraphSnapshot in view.telegraphs:
		if alive.has(tell.owner_id):
			tells[tell.owner_id] = tell
	for id: int in tells.keys():
		var mob: Dictionary = alive.get(id, {})
		var tell: Snapshots.TelegraphSnapshot = tells[id]
		if mob.is_empty() or mob["state"] not in [&"windup", &"strike", &"recover"] or view.tick > tell.end_tick + 24:
			tells.erase(id)
	for history: Dictionary in [previous, arrivals, hits, breaks]:
		for id: int in history.keys():
			if not alive.has(id):
				history.erase(id)

func active_tells(tick: int) -> Array[Snapshots.TelegraphSnapshot]:
	var out: Array[Snapshots.TelegraphSnapshot] = []
	for tell: Snapshots.TelegraphSnapshot in tells.values():
		if tick >= tell.hit_tick and tick < tell.end_tick:
			out.append(tell)
	return out

func draw_ground(canvas: CanvasItem, tick: int, colors: Dictionary) -> void:
	for tell: Snapshots.TelegraphSnapshot in tells.values():
		var age: int = tick - tell.hit_tick
		var active: bool = age >= 0 and tick < tell.end_tick
		var outline: PackedVector2Array = TelegraphView.outline(tell)
		if active:
			# Full real boundary on the first active tick, with a decorative inner ripple.
			canvas.draw_polyline(outline, colors["p"] if age < 2 else colors["o"], 1.0, false)
			if tell.shape == &"cone":
				var ripple: PackedVector2Array = []
				var radius: float = tell.size * minf(1.0, float(age + 1) / maxi(1, tell.end_tick - tell.hit_tick))
				for i: int in 41:
					var angle: float = tell.direction.angle() - tell.half_angle + 2.0 * tell.half_angle * i / 40.0
					ripple.append((tell.center + Vector2.from_angle(angle) * radius).round())
				canvas.draw_polyline(ripple, colors["p"], 1.0, false)
				for i: int in 7:
					var angle: float = tell.direction.angle() + tell.half_angle * (float(i) / 3.0 - 1.0) * 0.9
					canvas.draw_line((tell.center + Vector2.from_angle(angle) * tell.size * 0.25).round(), (tell.center + Vector2.from_angle(angle) * tell.size).round(), colors["u"], 1.0, false)
			elif tell.shape == &"line":
				var end: Vector2 = tell.center + tell.direction * tell.size
				canvas.draw_line(tell.center.round(), end.round(), colors["8"], 7.0, false)
				canvas.draw_line(tell.center.round(), end.round(), colors["p"], 3.0, false)
			else:
				for i: int in 24:
					var point: Vector2 = tell.center + Vector2.from_angle(TAU * i / 24.0) * maxf(0.0,tell.size - 5.0) * (0.5 + 0.5 * float(age + 1) / maxi(1, tell.end_tick - tell.hit_tick))
					canvas.draw_rect(Rect2(point.round() - Vector2(2,2), Vector2(5,5)), colors["8"])
					canvas.draw_rect(Rect2(point.round() - Vector2.ONE, Vector2(3,3)), colors["p"] if age < 3 else colors["o"])
					canvas.draw_rect(Rect2(point.round(), Vector2.ONE), colors["1"])
		elif age < 0 and tell.shape == &"line":
			var progress: float = clampf(float(tick - tell.start_tick) / maxi(1, tell.hit_tick - tell.start_tick), 0.0, 1.0)
			for side: int in [-1, 1]:
				var points: PackedVector2Array = []
				for i: int in 18:
					points.append((tell.center + tell.direction * tell.size * progress * i / 17.0 + tell.direction.orthogonal() * float(side) * sin(i * 1.4) * minf(4.0, tell.width * 0.25)).round())
				canvas.draw_polyline(points, colors["t"], 1.0, false)
		elif age >= 0 and age < 24 and tell.shape == &"circle":
			canvas.draw_polyline(outline, colors["8"], 1.0, false)

static func sprite(canvas: CanvasItem, family: String, n: int, at: Vector2, frames: Dictionary, atlas: Texture2D, left: bool) -> void:
	var key: String = "fx_warden_%s_%d" % [family, n]
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	var dest: Rect2 = ArenaAnimation.destination(Vector2.ZERO, f, left)
	dest.position = (at + dest.position * 2.5).round()
	dest.size *= 2.5
	canvas.draw_texture_rect_region(atlas, dest, Rect2(f["x"], f["y"], f["w"], f["h"]))

func draw_actor(canvas: CanvasItem, mob: Dictionary, key: String, tick: int, frames: Dictionary, atlas: Texture2D) -> void:
	var id: int = int(mob["id"])
	var at: Vector2 = mob["position"]
	var left: bool = Vector2(mob["facing"]).x < 0.0
	var state: StringName = mob["state"]
	var body_frame: int = int(key.get_slice("_", key.get_slice_count("_") - 1))
	var native_key: String = key
	var attachment: Dictionary = attachments.get(native_key, {"chest":[5,-18], "hook":[15,-14]})
	var chest: Array = attachment["chest"]
	var chest_shift: Vector2 = Vector2((float(chest[0]) - 5.0) * (-1.0 if left else 1.0), float(chest[1]) + 18.0) * 2.5
	if state == &"dead":
		if int(mob["state_ticks"]) < 12:
			sprite(canvas, "death_flash", mini(4, int(mob["state_ticks"]) / 3 + 1), at, frames, atlas, left)
		sprite(canvas, "death_debris", mini(8, body_frame), at, frames, atlas, left)
		return
	if bool(mob.get("guarded", false)):
		sprite(canvas, "rune_glow", posmod(tick / 8, 6) + 1, at + chest_shift, frames, atlas, left)
		sprite(canvas, "idle_spores", posmod(tick / 8 + id, 6) + 1, at, frames, atlas, left)
	if hits.has(id) and tick - int(hits[id]) < 12:
		sprite(canvas, "guard_hit", mini(4, (tick - int(hits[id])) / 3 + 1), at + chest_shift, frames, atlas, left)
	if breaks.has(id) and tick - int(breaks[id]) < 16:
		sprite(canvas, "guard_break", mini(8, (tick - int(breaks[id])) / 2 + 1), at, frames, atlas, left)
	if state == &"stagger":
		sprite(canvas, "exposed_dust", posmod(tick / 6, 6) + 1, at, frames, atlas, left)
	if state == &"alert":
		sprite(canvas, "wake_flare", mini(4, body_frame), at + chest_shift, frames, atlas, left)
	if arrivals.has(id) and tick - int(arrivals[id]) < 18:
		sprite(canvas, "arrival", mini(6, (tick - int(arrivals[id])) / 3 + 1), at, frames, atlas, left)
	if state == &"strike" and mob.get("attack", &"") == &"warden_cleave":
		sprite(canvas, "cleave_arc", mini(6, (body_frame - 1) * 2 + 1), at, frames, atlas, left)
	if state == &"windup" and mob.get("attack", &"") == &"warden_ring":
		sprite(canvas, "ring_charge", mini(6, int(mob["state_ticks"]) / 10 + 1), at, frames, atlas, left)
	if state == &"strike" and mob.get("attack", &"") == &"warden_lash" and tells.has(id):
		var tell: Snapshots.TelegraphSnapshot = tells[id]
		var hook: Array = attachment["hook"]
		var start: Vector2 = at + Vector2(float(hook[0]) * (-1.0 if left else 1.0),float(hook[1])) * 2.5
		var end: Vector2 = tell.center + tell.direction * tell.size
		var path: PackedVector2Array = []
		for i: int in 25:
			var t: float = float(i) / 24.0
			path.append((start.lerp(end, t) + Vector2(0, sin(t * PI) * sin(i * 1.7) * 2.0)).round())
		canvas.draw_polyline(path, Color("2e211e"), 7.0, false)
		canvas.draw_polyline(path, Color("f4ecd6"), 3.0, false)
