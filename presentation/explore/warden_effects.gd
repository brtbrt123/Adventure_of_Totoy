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
		# the Cleave's and the Ring's frames carry their own debris; the Lash's clumps get spirit sparks and clods as they break the floor
		if tell.shape == &"line":
			for i: int in LASH_CLUMPS:
				_burst("roots", tell.center + tell.direction * tell.size * (float(i) + 0.5) / float(LASH_CLUMPS), tell.hit_tick + i * 2)
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

## The floor around the Warden: its footprints and footfall dust, the ground its strikes tore (where they really hit), and each strike
## while it is active. The strikes are the Gemini effect frames (tools/art/import_warden_fx.py, owner 2026-10-31), each fitted to the
## committed telegraph's real size: the Cleave's rim on the cone's edge, the Lash's roots along its line, the Ring's edge on its radius.
func draw_ground(canvas: CanvasItem, tick: int, colors: Dictionary, frames: Dictionary, atlas: Texture2D) -> void:
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
		var angle: float = tell.direction.angle()
		match tell.shape:
			&"cone":
				# 4 frames across the strike, then 2 of the slash breaking into splinters
				if age >= 0 and age < span + 6:
					turned(canvas, "cleave", 1 + age * 4 / span if age < span else 5 + (age - span) / 3, tell.center, angle, frames, atlas)
			&"line":
				if age < 0:  # the windup: the crack runs out along the line it will tear
					var progress: float = clampf(float(tick - tell.start_tick) / maxi(1, tell.hit_tick - tell.start_tick), 0.0, 1.0)
					turned(canvas, "lash_crack", 1 + int(progress * 5.99), tell.center, angle, frames, atlas)
				elif age < LASH_TICKS:
					turned(canvas, "lash_crack", 6, tell.center, angle, frames, atlas)
					_draw_lash(canvas, tell, age, frames, atlas)
			_:
				# 4 frames running out to the real edge during the strike, then 2 of spores and dust breaking up
				if age >= 0 and age < span + 10:
					placed(canvas, "ring", 1 + age * 4 / span if age < span else 5 + (age - span) / 5, tell.center, frames, atlas)
	for mark: Dictionary in prints:
		var age: int = tick - int(mark["tick"])
		if age < 16:
			placed(canvas, "footstep", 1 + age / 4, mark["at"], frames, atlas, false)


const LASH_CLUMPS: int = 5  # root clumps along the 150 px line (each about 30 px wide)
const LASH_TICKS: int = 24  # the last clump's 8 frames (2 ticks each) end 8 ticks after it starts


## The Lash: root clumps burst out of the floor one after another along the real line, from the Warden outward, stand and sink. The roots
## grow upright whatever way the line runs (only the crack under them turns with it); clumps further down the screen are drawn last.
static func _draw_lash(canvas: CanvasItem, tell: Snapshots.TelegraphSnapshot, age: int, frames: Dictionary, atlas: Texture2D) -> void:
	var spots: Array[Dictionary] = []
	for i: int in LASH_CLUMPS:
		var born: int = i * 2  # the eruption runs out along the line
		if age < born or age - born >= 16:
			continue
		spots.append({"at": tell.center + tell.direction * tell.size * (float(i) + 0.5) / float(LASH_CLUMPS), "n": 1 + (age - born) / 2})
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["at"]).y < Vector2(b["at"]).y)
	for spot: Dictionary in spots:
		placed(canvas, "lash", int(spot["n"]), spot["at"], frames, atlas)


## Combat effects glow through the night light (the lighting shader's emissive pass, as the fireflies do), so the gold and red stay
## gold and red in any scene; footfall dust is lit like the floor.
const GLOW: Color = Color(1.0, 1.0, 1.0, preload("res://presentation/common/ambient_fireflies.gd").EMISSIVE_ALPHA)


## Effect frame `fx_warden2_<name>_<n>` with its anchor at `at`, upright.
static func placed(canvas: CanvasItem, name: String, n: int, at: Vector2, frames: Dictionary, atlas: Texture2D, glow: bool = true) -> void:
	var key: String = "fx_warden2_%s_%d" % [name, n]
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	canvas.draw_texture_rect_region(atlas, Rect2((at - Vector2(f["ax"], f["ay"])).round(), Vector2(f["w"], f["h"])), Rect2(f["x"], f["y"], f["w"], f["h"]), GLOW if glow else Color.WHITE)


## Effect frame `fx_warden2_<name>_<n>` (drawn pointing right) turned to `angle` around its anchor at `at`. Pointing left it is also
## mirrored top to bottom, so its light still falls from above. Turned to an angle other than left or right, its pixels step (the
## owner judges that in play; the fallback is frames pre-turned to 8 directions).
static func turned(canvas: CanvasItem, name: String, n: int, at: Vector2, angle: float, frames: Dictionary, atlas: Texture2D) -> void:
	var key: String = "fx_warden2_%s_%d" % [name, n]
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	var base: Vector2 = canvas.call("shake_offset") if canvas.has_method("shake_offset") else Vector2.ZERO
	var mirror: float = -1.0 if cos(angle) < 0.0 else 1.0
	canvas.draw_set_transform_matrix(Transform2D(0.0, base) * Transform2D(angle, Vector2(1.0, mirror), 0.0, at.round()))
	canvas.draw_texture_rect_region(atlas, Rect2(-Vector2(f["ax"], f["ay"]), Vector2(f["w"], f["h"])), Rect2(f["x"], f["y"], f["w"], f["h"]), GLOW)
	canvas.draw_set_transform(base)


## In front of the Warden: the Spore Ring gathering at the chest stone (the spore vortex; the warning on the floor is the telegraph's own),
## the guard hit at the chest stone (a reduced hit on the rune guard) and the guard break when the Cleave is parried and the rune shatters.
func draw_overlay(canvas: CanvasItem, mobs: Array[Dictionary], tick: int, frames: Dictionary, atlas: Texture2D) -> void:
	for mob: Dictionary in mobs:
		if mob["type"] != &"warden" or mob["state"] == &"dead":
			continue
		var id: int = int(mob["id"])
		var chest: Vector2 = chest_world(mob, String(keys.get(id, "")))
		if mob["state"] == &"windup" and mob.get("attack", &"") == &"warden_ring":
			placed(canvas, "ring_charge", 1 + posmod(int(mob["state_ticks"]) / 6, 4), chest, frames, atlas)
		if hits.has(id) and tick - int(hits[id]) < 12:
			placed(canvas, "guard_hit", 1 + (tick - int(hits[id])) / 3, chest, frames, atlas)
		if breaks.has(id) and tick - int(breaks[id]) < 18:
			placed(canvas, "guard_break", 1 + (tick - int(breaks[id])) / 3, chest, frames, atlas)


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
	if state == &"stagger":
		sprite(canvas, "exposed_dust", posmod(tick / 6, 6) + 1, at, frames, atlas, left)
	if arrivals.has(id) and tick - int(arrivals[id]) < 18:
		sprite(canvas, "arrival", mini(6, (tick - int(arrivals[id])) / 3 + 1), at, frames, atlas, left)
