extends RefCounted
## Snapshot-driven cosmetics shared by every exploration map. Never spawns mobs or changes HP/hits.
const ExploreCore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const SLAM_TICKS: int = 26  # how long the slam's ground effects last after the hit tick
var tells: Dictionary = {}
var previous: Dictionary = {}
var trails: Array[Dictionary] = []
var heals: Array[Dictionary] = []
var orbs: Dictionary = {}  # id -> {at, dir, path: [Vector2]} of the orbs seen last snapshot
var pops: Array[Dictionary] = []  # orbs that ended: {at, tick}
var reveals: Array[Dictionary] = []  # moths that just appeared: {at, tick}
var seen_moths: Dictionary = {}
var scene_id: StringName = &""
var last_tick: int = -1

func clear() -> void:
	tells.clear()
	previous.clear()
	trails.clear()
	heals.clear()
	orbs.clear()
	pops.clear()
	reveals.clear()
	seen_moths.clear()
	last_tick = -1
	scene_id = &""

func sync(view: ExploreCore.ExploreSnapshot) -> void:
	if scene_id != view.scene_id or view.tick < last_tick:
		clear()
	if view.tick == last_tick:
		return
	scene_id = view.scene_id
	last_tick = view.tick
	var alive: Dictionary = {}
	for mob: Dictionary in view.mobs:
		if mob["type"] == &"glowmoth" and int(mob.get("summoner_id", 0)) != 0 and mob["state"] != &"dead" and not seen_moths.has(int(mob["id"])):
			seen_moths[int(mob["id"])] = true
			reveals.append({"at": mob["position"], "tick": view.tick})
		if mob["type"] != &"stag" or mob["state"] == &"dead":
			continue
		var id: int = int(mob["id"])
		alive[id] = mob
		var old: Dictionary = previous.get(id, {})
		var at: Vector2 = mob["position"]
		if mob.get("attack_id", &"") == &"stag_charge" and mob["state"] == &"strike" and not old.is_empty():
			if at.distance_to(old["at"]) > 0.5 and view.tick - int(old["trail_tick"]) >= 3:
				trails.append({"at": at - Vector2(mob["facing"]) * 14, "tick": view.tick, "crash": false})
				old["trail_tick"] = view.tick
		if mob["state"] == &"crash" and old.get("state", &"") != &"crash":
			trails.append({"at": at + Vector2(mob["facing"]) * 14, "tick": view.tick, "crash": true})
		if not old.is_empty() and int(mob["hp"]) > int(old["hp"]) and bool(mob.get("regen_active", false)):
			heals.append({"id": id, "tick": view.tick, "amount": int(mob["hp"]) - int(old["hp"])})
		previous[id] = {"at": at, "state": mob["state"], "hp": mob["hp"], "trail_tick": old.get("trail_tick", view.tick - 3)}
	var current: Dictionary = {}
	for tell: Snapshots.TelegraphSnapshot in view.telegraphs:
		if alive.has(tell.owner_id) and tell.attack in [&"stag_slam", &"stag_roots"]:
			tells[tell.id] = tell
			current[tell.id] = true
	for id: int in tells.keys():
		var tell: Snapshots.TelegraphSnapshot = tells[id]
		var owner: Dictionary = alive.get(tell.owner_id, {})
		if owner.is_empty() or owner["state"] not in [&"windup", &"strike", &"recover"] or view.tick - tell.hit_tick >= 34 or (view.tick < tell.hit_tick and not current.has(id)):
			tells.erase(id)
	for id: int in previous.keys():
		if not alive.has(id):
			previous.erase(id)
	# Orbs: an id that vanished from the snapshot ended (hit, prop, range or its moth died): pop where it was last drawn.
	var flying: Dictionary = {}
	for orb: Dictionary in view.mob_projectiles:
		var oid: int = int(orb["id"])
		var path: Array = orbs.get(oid, {}).get("path", [])
		path.append(Vector2(orb["position"]))
		if path.size() > 6:
			path = path.slice(path.size() - 6)
		flying[oid] = {"at": Vector2(orb["position"]), "dir": Vector2(orb["direction"]), "path": path}
	for oid: int in orbs:
		if not flying.has(oid):
			pops.append({"at": orbs[oid]["at"], "tick": view.tick})
	orbs = flying
	trails = trails.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < 24)
	heals = heals.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < 30)
	pops = pops.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < 16)
	reveals = reveals.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < 24)
	if trails.size() > 80:
		trails = trails.slice(trails.size() - 80)

static func sprite(canvas: CanvasItem, key: String, at: Vector2, frames: Dictionary, atlas: Texture2D, left: bool = false) -> void:
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	canvas.draw_texture_rect_region(atlas, ArenaAnimation.destination(at.round(), f, left), Rect2(f["x"], f["y"], f["w"], f["h"]))

## The slam's ground marks, spread over the WHOLE cone the core hit (reach + body = tell.size): rubble at three depths, dust on the rim.
static func slam_marks(tell: Snapshots.TelegraphSnapshot, age: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if age < 0 or age >= SLAM_TICKS:
		return out
	var rubble: String = "fx_ch1_stag_slam_rubble_%d" % mini(5, age / 5 + 1)
	var dust: String = "fx_ch1_boar_dust_%d" % mini(4, age / 6 + 1)
	var rows: Array = [[0.28, 1, rubble], [0.55, 3, rubble], [0.82, 4, rubble], [1.0, 7, dust]]
	for row: Array in rows:
		var depth: float = float(row[0])
		var count: int = int(row[1])
		# the front arrives at each depth as the shock travels outward (a depth is reached at age = depth * 8)
		if float(age) < depth * 8.0:
			continue
		for i: int in count:
			var t: float = 0.0 if count == 1 else (float(i) / float(count - 1)) * 2.0 - 1.0
			var angle: float = tell.direction.angle() + t * tell.half_angle * 0.9
			out.append({"frame": row[2], "at": tell.center + Vector2.from_angle(angle) * tell.size * depth, "tell_id": tell.id})
	return out

func ground_plans(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: int in tells:
		var tell: Snapshots.TelegraphSnapshot = tells[id]
		var age: int = view.tick - tell.hit_tick
		if tell.attack == &"stag_roots" and age >= -15 and age < 34:
			var n: int = 1 if age < 0 else 2 if age < 1 else 3 if age < 5 else 4 if age < 10 else 5 if age < 24 else 6
			out.append({"frame": "fx_stag_spirit_root_%d" % n, "at": tell.center, "tell_id": id})
		elif tell.attack == &"stag_slam":
			out.append_array(slam_marks(tell, age))
	for mark: Dictionary in trails:
		var age: int = view.tick - int(mark["tick"])
		out.append({"frame": ("fx_ch1_boar_crash_%d" % mini(5, age / 5 + 1)) if mark["crash"] else ("fx_ch1_boar_dust_%d" % mini(4, age / 6 + 1)), "at": mark["at"]})
	return out

## The shock front of the slam: an arc that travels from the Stag to the cone's real edge (tell.size), cracks out to that edge, and
## the rim held for a moment so the player sees how far it reached.
static func draw_slam_shock(canvas: CanvasItem, tell: Snapshots.TelegraphSnapshot, age: int, colors: Dictionary) -> void:
	if age < 0 or age >= SLAM_TICKS:
		return
	var front: float = tell.size * minf(1.0, float(age + 1) / 8.0)
	var base: float = tell.direction.angle()
	for layer: int in 3:
		var r: float = front - float(layer) * 5.0
		if r <= 4.0:
			continue
		var arc: PackedVector2Array = []
		for i: int in 41:
			var angle: float = base - tell.half_angle + 2.0 * tell.half_angle * i / 40.0
			arc.append((tell.center + Vector2.from_angle(angle) * r).round())
		var colour: Color = colors["p"] if layer == 0 and age < 10 else (colors["o"] if layer == 0 else colors["t"])
		canvas.draw_polyline(arc, colour, 2.0 if layer == 0 else 1.0, false)
	# cracks: jagged lines from the hoof to the shock front, never past the hit edge
	for k: int in 5:
		var angle: float = base + (float(k) / 4.0 * 2.0 - 1.0) * tell.half_angle * 0.8
		var crack: PackedVector2Array = [tell.center.round()]
		var steps: int = 6
		for s: int in range(1, steps + 1):
			var d: float = minf(front, tell.size) * float(s) / float(steps)
			var wobble: float = (3.0 if (s + k) % 2 == 0 else -3.0) * (1.0 if s < steps else 0.0)
			crack.append((tell.center + Vector2.from_angle(angle) * d + Vector2.from_angle(angle + PI / 2.0) * wobble).round())
		canvas.draw_polyline(crack, colors["8"], 2.0, false)
		canvas.draw_polyline(crack, colors["9"], 1.0, false)
	# the rim of the real hit area lingers after the front reached it
	if age >= 8 and age < 20:
		var rim: PackedVector2Array = []
		for i: int in 41:
			var angle: float = base - tell.half_angle + 2.0 * tell.half_angle * i / 40.0
			rim.append((tell.center + Vector2.from_angle(angle) * tell.size).round())
		canvas.draw_polyline(rim, colors["j"] if age < 14 else colors["h"], 1.0, false)

func draw_ground(canvas: CanvasItem, view: ExploreCore.ExploreSnapshot, frames: Dictionary, atlas: Texture2D, colors: Dictionary) -> void:
	for plan: Dictionary in ground_plans(view):
		sprite(canvas, plan["frame"], plan["at"], frames, atlas)
	for id: int in tells:
		var tell: Snapshots.TelegraphSnapshot = tells[id]
		var age: int = view.tick - tell.hit_tick
		if tell.attack == &"stag_roots" and age >= -15 and age < 24:
			# Approved branching ground veins stay inside this particular committed root site.
			for branch: int in 7:
				var points: PackedVector2Array = [tell.center.round()]
				var angle: float = branch * TAU / 7.0 + 0.2
				for step: int in range(1, 5):
					var distance: float = minf(tell.size * 0.6, step * 5.0)
					points.append((tell.center + Vector2(cos(angle) * distance, sin(angle) * distance * 0.5 + step % 2)).round())
				canvas.draw_polyline(points, colors["8"], 2.0, false)
				if age < 15:
					var count: int = clampi((age + 15) / 4, 2, 5)
					canvas.draw_polyline(points.slice(0, count), colors["u"] if branch % 3 == 0 else colors["t"], 1.0, false)
		elif tell.attack == &"stag_slam":
			draw_slam_shock(canvas, tell, age, colors)
	for orb: Dictionary in orbs.values():
		sprite(canvas, "fx_ch1_moth_shadow_1", orb["at"], frames, atlas)

## The moth-to-Stag healing links: a dotted 2 px line and bright motes travelling toward the antlers, only while the core reports
## `regen_active` and the moth names that Stag.
static func draw_links(canvas: CanvasItem, view: ExploreCore.ExploreSnapshot, colors: Dictionary) -> void:
	for boss: Dictionary in view.mobs:
		if boss["type"] != &"stag" or boss["state"] == &"dead" or not bool(boss.get("regen_active", false)):
			continue
		var target: Vector2 = Vector2(boss["position"]) - Vector2(0, 40)
		for moth: Dictionary in view.mobs:
			if moth["type"] != &"glowmoth" or moth["state"] == &"dead" or int(moth.get("summoner_id", -1)) != int(boss["id"]):
				continue
			var from: Vector2 = Vector2(moth["position"]) - Vector2(0, 10)
			var length: float = from.distance_to(target)
			var dots: int = maxi(2, int(length / 6.0))
			for i: int in dots:
				var t: float = float(i) / float(dots)
				var point: Vector2 = from.lerp(target, t)
				point.y -= sin(t * PI) * 10.0
				canvas.draw_rect(Rect2(point.round(), Vector2(2, 2)), colors["t"])
			for m: int in 3:
				var t: float = fposmod(float(view.tick + m * 20 + int(moth["id"]) * 7), 60.0) / 60.0
				var point: Vector2 = from.lerp(target, t)
				point.y -= sin(t * PI) * 10.0
				canvas.draw_rect(Rect2(point.round() - Vector2.ONE, Vector2(3, 3)), colors["p"])

## Drawn over actors and HP bars: healing links, orbs with their trail, orb pops, moth reveals and the Stag's heal pulses.
func draw_overlay(canvas: CanvasItem, view: ExploreCore.ExploreSnapshot, frames: Dictionary, atlas: Texture2D, colors: Dictionary) -> void:
	draw_links(canvas, view, colors)
	for orb: Dictionary in orbs.values():
		var path: Array = orb["path"]
		for i: int in path.size() - 1:
			var p: Vector2 = path[i]
			var size: float = 1.0 + float(i) * 0.5
			canvas.draw_rect(Rect2(p.round() - Vector2.ONE * size * 0.5, Vector2.ONE * size), colors["u"] if i < path.size() - 3 else colors["o"])
		sprite(canvas, "fx_ch1_moth_trail_%d" % (posmod(view.tick / 4, 4) + 1), orb["at"], frames, atlas, Vector2(orb["dir"]).x < 0.0)
		sprite(canvas, "fx_glowmoth_orb_%d" % (posmod(view.tick / 4, 4) + 1), orb["at"], frames, atlas)
	for pop: Dictionary in pops:
		var age: int = view.tick - int(pop["tick"])
		sprite(canvas, "fx_glowmoth_orb_pop_%d" % mini(4, age / 4 + 1), pop["at"], frames, atlas)
	for reveal: Dictionary in reveals:
		var age: int = view.tick - int(reveal["tick"])
		var at: Vector2 = reveal["at"]
		canvas.draw_arc(at - Vector2(0, 10), 3.0 + float(age) * 0.9, 0.0, TAU, 20, colors["p"] if age < 8 else colors["u"], 1.0)
		if age < 10:
			canvas.draw_rect(Rect2((at - Vector2(1, 30 - age)).round(), Vector2(2, 22 - age * 2)), colors["o"])
		sprite(canvas, "fx_glowmoth_orb_pop_%d" % mini(4, age / 5 + 1), at - Vector2(0, 10), frames, atlas)
	for heal: Dictionary in heals:
		for boss: Dictionary in view.mobs:
			if int(boss["id"]) != int(heal["id"]) or boss["state"] == &"dead":
				continue
			var age: int = view.tick - int(heal["tick"])
			var at: Vector2 = boss["position"]
			# above the HP bar (bar top is 60 px over the feet for a boss) so it is never hidden behind it
			var point: Vector2 = (at + Vector2(10, -72 - age / 2)).round()
			canvas.draw_rect(Rect2(point - Vector2(3, 1), Vector2(8, 3)), colors["0"])
			canvas.draw_rect(Rect2(point - Vector2(1, 3), Vector2(3, 8)), colors["0"])
			canvas.draw_rect(Rect2(point - Vector2(2, 0), Vector2(6, 1)), colors["6"])
			canvas.draw_rect(Rect2(point - Vector2(0, 2), Vector2(1, 6)), colors["6"])
			if age < 16:
				sprite(canvas, "woodland_fx_heal_%d" % mini(6, age / 3 + 1), at - Vector2(0, 22), frames, atlas)

func draw_actor(canvas: CanvasItem, mob: Dictionary, key: String, tick: int, frames: Dictionary, atlas: Texture2D, colors: Dictionary) -> void:
	if mob["state"] == &"dead":
		return
	var at: Vector2 = mob["position"]
	var left: bool = Vector2(mob["facing"]).x < 0
	if mob["type"] == &"glowmoth":
		for i: int in 3:
			var point: Vector2 = at + Vector2(sin(float(tick + i * 31) * 0.08) * 7, -10 - posmod(tick / 3 + i * 5, 18))
			canvas.draw_rect(Rect2(point.round(), Vector2.ONE), colors["u"])
		return
	if mob["type"] != &"stag":
		return
	if mob["state"] in [&"windup", &"strike", &"roar"] or (mob.get("attack_id", &"") == &"stag_summon" and mob["state"] == &"recover"):
		if key.begins_with("stag_chant_right_"):
			sprite(canvas, "fx_stag_chant_" + key.get_slice("_", 3), at, frames, atlas, left)
		elif key.begins_with("stag_summon_right_"):
			sprite(canvas, "fx_stag_summon_" + key.get_slice("_", 3), at, frames, atlas, left)
		else:
			var stem: String = key.trim_prefix("stag_").replace("_right_", "_")
			sprite(canvas, "fx_stag_horn_%s_%d" % [stem, posmod(tick / 3, 4) + 1], at, frames, atlas, left)
