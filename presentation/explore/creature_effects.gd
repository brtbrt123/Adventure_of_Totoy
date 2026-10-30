extends RefCounted
## Snapshot-driven cosmetics shared by every exploration map. Never spawns mobs or changes HP/hits.
const ExploreCore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
var tells: Dictionary = {}
var previous: Dictionary = {}
var trails: Array[Dictionary] = []
var heals: Array[Dictionary] = []
var scene_id: StringName = &""
var last_tick: int = -1

func clear() -> void:
	tells.clear()
	previous.clear()
	trails.clear()
	heals.clear()
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
		if not old.is_empty() and float(mob["hp"]) > float(old["hp"]):
			heals.append({"id": id, "tick": view.tick})
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
	trails = trails.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < 24)
	heals = heals.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < 24)
	if trails.size() > 80:
		trails = trails.slice(trails.size() - 80)

static func sprite(canvas: CanvasItem, key: String, at: Vector2, frames: Dictionary, atlas: Texture2D, left: bool = false) -> void:
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	canvas.draw_texture_rect_region(atlas, ArenaAnimation.destination(at.round(), f, left), Rect2(f["x"], f["y"], f["w"], f["h"]))

func ground_plans(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: int in tells:
		var tell: Snapshots.TelegraphSnapshot = tells[id]
		var age: int = view.tick - tell.hit_tick
		if tell.attack == &"stag_roots" and age >= -15 and age < 34:
			var n: int = 1 if age < 0 else 2 if age < 1 else 3 if age < 5 else 4 if age < 10 else 5 if age < 24 else 6
			out.append({"frame": "fx_stag_spirit_root_%d" % n, "at": tell.center, "tell_id": id})
		elif tell.attack == &"stag_slam" and age >= 0 and age < 25:
			out.append({"frame": "fx_ch1_stag_slam_rubble_%d" % mini(5, age / 5 + 1), "at": tell.center + tell.direction * minf(36.0, tell.size), "tell_id": id})
	for mark: Dictionary in trails:
		var age: int = view.tick - int(mark["tick"])
		out.append({"frame": ("fx_ch1_boar_crash_%d" % mini(5, age / 5 + 1)) if mark["crash"] else ("fx_ch1_boar_dust_%d" % mini(4, age / 6 + 1)), "at": mark["at"]})
	return out

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
		if tell.attack != &"stag_slam" or age < 0 or age >= 24:
			continue
		# Cosmetic shock uses the core's exact current cone, including its radius allowance.
		var radius: float = tell.size * minf(1.0, float(age + 3) / maxi(1, tell.end_tick - tell.hit_tick))
		var points: PackedVector2Array = []
		for i: int in 41:
			var angle: float = tell.direction.angle() - tell.half_angle + 2.0 * tell.half_angle * i / 40.0
			points.append((tell.center + Vector2.from_angle(angle) * radius).round())
		canvas.draw_polyline(points, colors["p"] if age < 6 else colors["t"], 1.0, false)
		for i: int in 5:
			var angle: float = tell.direction.angle() - tell.half_angle * 0.85 + i * tell.half_angle * 1.7 / 4.0
			var point: Vector2 = tell.center + Vector2.from_angle(angle) * tell.size * 0.8
			sprite(canvas, "fx_ch1_boar_dust_%d" % mini(4, age / 6 + 1), point, frames, atlas)
	for boss: Dictionary in view.mobs:
		if boss["type"] != &"stag" or boss["state"] == &"dead" or not bool(boss.get("regen_active", false)):
			continue
		for moth: Dictionary in view.mobs:
			if moth["type"] != &"glowmoth" or moth["state"] == &"dead" or int(moth.get("summoner_id", -1)) != int(boss["id"]):
				continue
			for i: int in 7:
				var t: float = fposmod(float(view.tick + i * 27), 180.0) / 180.0
				var point: Vector2 = Vector2(moth["position"]).lerp(Vector2(boss["position"]) - Vector2(0, 38), t)
				point.y -= sin(t * PI) * 12
				canvas.draw_rect(Rect2(point.round(), Vector2.ONE), colors["u"])

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
	if mob["state"] in [&"windup", &"strike", &"roar", &"chant"] or (mob.get("attack_id", &"") == &"stag_summon" and mob["state"] == &"recover"):
		if key.begins_with("stag_chant_right_"):
			sprite(canvas, "fx_stag_chant_" + key.get_slice("_", 3), at, frames, atlas, left)
		elif key.begins_with("stag_summon_right_"):
			sprite(canvas, "fx_stag_summon_" + key.get_slice("_", 3), at, frames, atlas, left)
		else:
			var stem: String = key.trim_prefix("stag_").replace("_right_", "_")
			sprite(canvas, "fx_stag_horn_%s_%d" % [stem, posmod(tick / 3, 4) + 1], at, frames, atlas, left)
	for heal: Dictionary in heals:
		if int(heal["id"]) == int(mob["id"]):
			var point: Vector2 = (at + Vector2(0, -55 - (tick - int(heal["tick"])) / 3)).round()
			canvas.draw_rect(Rect2(point - Vector2(3, 0), Vector2(7, 1)), colors["u"])
			canvas.draw_rect(Rect2(point - Vector2(0, 3), Vector2(1, 7)), colors["u"])
