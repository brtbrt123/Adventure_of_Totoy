extends RefCounted
## How the road's Mossbound Colossus is drawn (docs/PLAN_colossus_step3.md, part 3a, the owner's choices of 2026-11-27): the
## STAND-IN body (one still, art/src/colossus_idle_right_1.txt) moved per state, the fight camera that keeps it whole on screen, the
## hero's outline when he walks behind it, the glowing edges of its warnings, its chest light, and the sounds, shake and dust of
## its blows. It reads the snapshot only: the core (core/colossus.gd) decides every hit and time.
const ExploreCore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const WHITE := preload("res://art/build/sprites_white.png")
const Fireflies := preload("res://presentation/common/ambient_fireflies.gd")

const TYPE: StringName = &"colossus"
const FRAME: String = "colossus_idle_right_1"
const HEIGHT: float = 116.0  # the stand-in's visible height (the owner's choice B)
const CHEST: float = 53.0  # the song's light above the feet
const ASLEEP_SINK: int = 46  # rows sunk into the ground while it sleeps (it rises out of it)
const VIEW: Vector2 = Vector2(384, 216)
## The fight camera: how near each screen edge the hero may get, and how fast the view slides when the fight starts or ends.
const HERO_SIDE: float = 28.0
const HERO_TOP: float = 44.0
const HERO_BOTTOM: float = 20.0
const SNAP_DISTANCE: float = 160.0  # a jump this far (a respawn) is not eased
const OUTLINE: Color = Color("e0f0ec")  # water_6
const CHEST_COLOUR: Vector3 = Vector3(0.36, 0.82, 1.0)
const CHEST_CORE: Vector3 = Vector3(0.80, 0.96, 1.0)
## The sound of each blow as it lands (the arena's recordings).
const STRIKE_CUES: Dictionary = {&"gold_slam": "golem_slam", &"gold_combo": "golem_slam", &"red_stomp": "golem_stomp", &"red_sweep": "golem_sweep",
	&"red_charge": "golem_charge", &"red_shards": "golem_beam", &"root_snare": "golem_stomp", &"boulder_toss": "golem_slam", &"heartroot_grab": "golem_sweep"}
const HEAVY: Array[StringName] = [&"gold_slam", &"gold_combo", &"red_stomp", &"boulder_toss"]

## The attacks' effects (PixelFX in Totoy 36, approved 2026-11-27; tools/art/import_pixelfx.py --install). Frames last 4 ticks.
const THORN: String = "fx_colossus_thorn_%d"
const THORN_COUNT: int = 11
const THORN_LEAD: int = 4  # the first frame (the floor cracking) shows this many ticks before the blow
const THORN_SPACING: float = 22.0  # one thorn every this many px along the lane, from the body's edge to the lane's real end
const THORN_FIRST: float = 50.0
const SHARD: String = "fx_colossus_shard_%d"  # the same burst in stone (the owner's option B, 2026-11-28), set round a ring of shock
const SHARDS: int = 14  # round the middle of the ring's real band (inner to outer radius)
const STONE_SPIN: String = "fx_colossus_stone_spin_%d"
const STONE_SPIN_COUNT: int = 18
const STONE_LAND: String = "fx_colossus_stone_land_%d"
const STONE_LAND_COUNT: int = 21
const STONE_FROM: Vector2 = Vector2(0, -96)  # where the stone leaves its raised hands, from its feet
const STONE_ARC: float = 70.0  # how high the throw rises above the straight line
const FRAME_TICKS: int = 4
## The Heartroot Grab's root-arm (PixelFX nature/vine-whip, the owner's "Yes, wire it", 2026-11-28): rendered every 15 degrees from -90
## (up the screen) to 90 (down), the left half drawn mirrored; ARM_SOURCES are the PixelFX frames kept (30 fps, 2 game ticks each),
## frame ARM_LASH is the lash and meets the blow. It grows out of the floor ARM_ROOT px along the lane, at the body's edge.
const ARM: String = "fx_colossus_arm_%d_%d"
const ARM_SOURCES: Array[int] = [1, 3, 5, 7, 9, 11, 13, 14, 15, 16, 18, 21, 24, 28, 32]
const ARM_ANGLES: int = 13
const ARM_LASH: int = 15
const ARM_ROOT: float = 40.0

var _seen_hits: Dictionary = {}  # telegraph id -> true once its blow landed (sound, shake, dust once)
var _previous: Array[Snapshots.TelegraphSnapshot] = []
var _ghosts: Dictionary = {}  # hero frame key -> ImageTexture (outline + every other pixel)
var _atlas_image: Image = null
var _last_tick: int = -1
## Effects still playing after their blow: {kind (&"thorns", &"land", &"shards" or &"arm"), tick (the blow), at, direction, size, radius}.
var effects: Array[Dictionary] = []
var missing: Dictionary = {}  # effect frames asked for but not in the atlas (warned once)


func clear() -> void:
	_seen_hits.clear()
	_previous.clear()
	_last_tick = -1
	effects.clear()


## Every effect frame this view may ask for (smoke_colossus checks they are all in the atlas).
static func effect_frames() -> Array[String]:
	var out: Array[String] = []
	for n: int in range(1, THORN_COUNT + 1):
		out.append(THORN % n)
		out.append(SHARD % n)
	for n: int in range(1, STONE_SPIN_COUNT + 1):
		out.append(STONE_SPIN % n)
	for n: int in range(1, STONE_LAND_COUNT + 1):
		out.append(STONE_LAND % n)
	for a: int in ARM_ANGLES:
		for n: int in range(1, ARM_SOURCES.size() + 1):
			out.append(ARM % [a, n])
	return out


## The root-arm's frame (1-based in ARM_SOURCES) `ticks` after the lash (negative before it); 0 = not shown.
static func arm_frame(ticks: int) -> int:
	var source: float = float(ticks) / 2.0 + float(ARM_LASH)
	if source < float(ARM_SOURCES[0]) or source > float(ARM_SOURCES[-1] + 3):
		return 0
	var n: int = 0
	for i: int in ARM_SOURCES.size():
		if float(ARM_SOURCES[i]) <= source:
			n = i + 1
	return n


## The rendered angle nearest the lane: [angle index 0..12, mirrored (the lane points left)].
static func arm_angle(direction: Vector2) -> Array:
	var mirrored: bool = direction.x < 0.0
	var degrees: float = rad_to_deg(atan2(direction.y, absf(direction.x)))
	return [clampi(roundi((degrees + 90.0) / 15.0), 0, ARM_ANGLES - 1), mirrored]


func _arm_item(id: String, root: Vector2, direction: Vector2, ticks: int, tint: Color) -> Dictionary:
	var n: int = arm_frame(ticks)
	if n == 0:
		return {}
	var angle: Array = arm_angle(direction)
	return {"kind": &"colossus_fx", "id": id, "at": root.round(), "frame": ARM % [int(angle[0]), n], "left": bool(angle[1]), "tint": tint}


## The effects standing on the floor, as items for the scene's depth sort ({kind colossus_fx, id, at (feet), frame, tint}).
func effect_items(view: ExploreCore.ExploreSnapshot, tint: Color) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	effects = effects.filter(func(e: Dictionary) -> bool: return view.tick - int(e["tick"]) < _lifetime(e) and view.tick >= int(e["tick"]) - THORN_LEAD)
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:  # the root-arm rises during the Grab's warning
		if t.attack == &"heartroot_grab" and view.tick < t.hit_tick:
			var rising: Dictionary = _arm_item("colossus_arm_%d" % t.id, t.center + t.direction * ARM_ROOT, t.direction, view.tick - t.hit_tick, tint)
			if not rising.is_empty():
				out.append(rising)
	for i: int in effects.size():
		var e: Dictionary = effects[i]
		var age: int = view.tick - int(e["tick"])
		if e["kind"] == &"thorns":  # one thorn after another along the lane, a tick later each: the crack races out
			var k: int = 0
			var d: float = THORN_FIRST
			while d <= float(e["size"]):
				var n: int = floori(float(age - k + THORN_LEAD) / FRAME_TICKS) + 1  # floor: not yet = 0
				if n >= 1 and n <= THORN_COUNT:
					var side: Vector2 = Vector2(e["direction"]).orthogonal() * (4.0 if k % 2 == 0 else -4.0)
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d" % [i, k], "at": (Vector2(e["at"]) + Vector2(e["direction"]) * d + side).round(), "frame": THORN % n, "tint": tint})
				d += THORN_SPACING
				k += 1
		elif e["kind"] == &"arm":  # the lash, then the arm sliding back into the floor
			var lashing: Dictionary = _arm_item("colossus_fx_%d" % i, e["at"], e["direction"], age, tint)
			if not lashing.is_empty():
				out.append(lashing)
		elif e["kind"] == &"shards":  # stone shards burst up round the ring of shock, over its whole band
			for k: int in SHARDS:
				var n: int = floori(float(age - k % 3 + THORN_LEAD) / FRAME_TICKS) + 1
				if n >= 1 and n <= THORN_COUNT:
					var spot: Vector2 = Vector2(e["at"]) + Vector2.from_angle(TAU * float(k) / float(SHARDS)) * float(e["radius"])
					out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d_%d" % [i, k], "at": spot.round(), "frame": SHARD % n, "tint": tint})
		else:
			var n: int = age / FRAME_TICKS + 1
			if n >= 1 and n <= STONE_LAND_COUNT:
				out.append({"kind": &"colossus_fx", "id": "colossus_fx_%d" % i, "at": Vector2(e["at"]).round(), "frame": STONE_LAND % n, "tint": tint})
	return out


static func _lifetime(e: Dictionary) -> int:
	if e["kind"] == &"thorns":
		return THORN_COUNT * FRAME_TICKS + int(float(e["size"]) / THORN_SPACING) + 1
	if e["kind"] == &"shards":
		return THORN_COUNT * FRAME_TICKS + 3
	if e["kind"] == &"arm":
		return (ARM_SOURCES[-1] + 3 - ARM_LASH) * 2 + 1
	return STONE_LAND_COUNT * FRAME_TICKS


## One effect item at its anchor (`frame` of the atlas); a missing frame warns once and draws nothing.
func draw_effect(canvas: CanvasItem, item: Dictionary, frames: Dictionary, sprites: Texture2D) -> void:
	var key: String = item["frame"]
	if not frames.has(key):
		if not missing.has(key):
			missing[key] = true
			push_warning("Missing Colossus effect frame: " + key)
		return
	var f: Dictionary = frames[key]
	var rect: Rect2 = ArenaAnimation.destination(Vector2(item["at"]), f, bool(item.get("left", false)))  # the actors' rule, mirroring too
	canvas.draw_texture_rect_region(sprites, rect, Rect2(f["x"], f["y"], f["w"], f["h"]), item["tint"])


## The stone of a Boulder Toss in the air: it leaves the raised hands as the warning begins and spins along an arc onto the warned
## circle, landing on the tick the warning strikes. Its shadow on the floor grows as it falls (draw_stone_shadows, under the actors).
func draw_stones(canvas: CanvasItem, view: ExploreCore.ExploreSnapshot, frames: Dictionary, sprites: Texture2D, tint: Color) -> void:
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.attack != &"boulder_toss" or t.shape != &"circle" or view.tick >= t.hit_tick:
			continue
		var progress: float = clampf(float(view.tick - t.start_tick) / maxf(1.0, float(t.hit_tick - t.start_tick)), 0.0, 1.0)
		var from: Vector2 = t.muzzle + STONE_FROM
		var at: Vector2 = from.lerp(t.center, progress) + Vector2(0, -sin(progress * PI) * STONE_ARC)
		var n: int = posmod(view.tick / 2, STONE_SPIN_COUNT) + 1
		draw_effect(canvas, {"at": at, "frame": STONE_SPIN % n, "tint": tint}, frames, sprites)


func stone_shadows(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.attack == &"boulder_toss" and t.shape == &"circle" and view.tick < t.hit_tick:
			var progress: float = clampf(float(view.tick - t.start_tick) / maxf(1.0, float(t.hit_tick - t.start_tick)), 0.0, 1.0)
			out.append({"at": t.center, "radius": 4.0 + 12.0 * progress})
	return out


static func is_colossus(mob: Dictionary) -> bool:
	return mob.get("type", &"") == TYPE


## The Colossus of the snapshot, {} when the scene has none.
static func find(view: ExploreCore.ExploreSnapshot) -> Dictionary:
	for mob: Dictionary in view.mobs:
		if is_colossus(mob):
			return mob
	return {}


## The Colossus whose fight is on (awake, alive): the camera frames it and the HUD shows its panel.
static func fighting(view: ExploreCore.ExploreSnapshot) -> Dictionary:
	var mob: Dictionary = find(view)
	if mob.is_empty() or mob["state"] in [&"idle", &"dead"]:
		return {}
	return mob


# ---- the body ---------------------------------------------------------------------------------------------------------------

## The pose of the still for this tick: {offset (px), sink (rows below the ground), dim (0..1 darker)}.
static func pose(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> Dictionary:
	var t: int = int(mob["state_ticks"])
	var offset: Vector2 = Vector2.ZERO
	var sink: int = 0
	var dim: float = 0.0
	match mob["state"]:
		&"idle":
			sink = ASLEEP_SINK
			dim = 0.3
			offset.y = 0.0 if posmod(tick / 40, 2) == 0 else 1.0  # slow breath
		&"alert":
			var risen: float = clampf(float(t) / Tuning.COLOSSUS_WAKE_TICKS, 0.0, 1.0)
			sink = roundi(ASLEEP_SINK * (1.0 - risen * risen * (3.0 - 2.0 * risen)))
			dim = 0.3 * (1.0 - risen)
			offset.x = float(posmod(t / 3, 3) - 1) if risen < 0.9 else 0.0
		&"chase":
			offset.y = -1.0 if posmod(t / 16, 2) == 1 else 0.0
		&"windup":
			var progress: float = 0.0
			for tell: Snapshots.TelegraphSnapshot in tells:
				if tell.owner_id == int(mob["id"]):
					progress = clampf(float(tick - tell.start_tick) / maxf(1.0, float(tell.hit_tick - tell.start_tick)), 0.0, 1.0)
					break
			offset.y = -roundf(3.0 * progress)
			if progress > 0.8:
				offset.x = float(posmod(t, 2) * 2 - 1)
		&"strike":
			offset.y = 2.0 if mob.get("attack", &"") in HEAVY else 0.0
		&"recover":
			offset.y = 1.0 if t < 8 else 0.0
		&"posture_broken":
			offset.y = 4.0
			dim = 0.25 + 0.1 * float(posmod(t / 8, 2))
		&"stagger":
			offset = Vector2(float(posmod(t / 2, 2) * 2 - 1), 2.0)
		&"roar":
			offset = Vector2(float(posmod(t / 2, 2) * 2 - 1), -2.0)
		&"dead":
			sink = roundi(HEIGHT * clampf(float(t) / Tuning.MOB_DEATH_TICKS, 0.0, 1.0))
			offset.x = float(posmod(t / 2, 2) * 2 - 1)
	return {"offset": offset, "sink": sink, "dim": dim}


## Draws the body at its feet: the visible part above the ground line (it sinks into the ground asleep and as it falls), white for
## a few ticks after a blow, darker asleep and broken.
static func draw_body(canvas: CanvasItem, item: Dictionary, frames: Dictionary, sprites: Texture2D, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> void:
	var mob: Dictionary = item["mob"]
	if not frames.has(FRAME):
		return
	var frame: Dictionary = frames[FRAME]
	var p: Dictionary = pose(mob, tells, tick)
	var sink: int = int(p["sink"])
	var w: float = float(frame["w"])
	var h: float = float(frame["h"])
	var shown: float = h - float(sink)
	if shown <= 0.0:
		return
	var corner: Vector2 = (Vector2(item["at"]).round() - Vector2(float(frame["ax"]), float(frame["ay"])) + Vector2(p["offset"])).round()
	var tint: Color = item["tint"]
	var dim: float = float(p["dim"])
	tint = Color(tint.r * (1.0 - dim), tint.g * (1.0 - dim), tint.b * (1.0 - dim * 0.6), tint.a)
	var white: bool = int(mob.get("since_hit", 1000)) < 4 and mob["state"] != &"dead"
	canvas.draw_texture_rect_region(WHITE if white else sprites, Rect2(corner + Vector2(0, float(sink)), Vector2(w, shown)), Rect2(float(frame["x"]), float(frame["y"]), w, shown), tint)


## The drawn rectangle of the body (for the hero's outline test and the camera).
static func body_rect(mob: Dictionary, frames: Dictionary) -> Rect2:
	var frame: Dictionary = frames.get(FRAME, {"w": 144, "h": 120, "ax": 72, "ay": 118})
	return Rect2(Vector2(mob["position"]) - Vector2(float(frame["ax"]), float(frame["ay"])), Vector2(float(frame["w"]), float(frame["h"])))


## Where the hero's blow meets the body: on its side facing him, at chest height.
static func contact(mob: Dictionary, hero: Vector2) -> Vector2:
	var at: Vector2 = mob["position"]
	var toward: Vector2 = (hero - at).normalized() if hero.distance_to(at) > 0.5 else Vector2.DOWN
	return at + toward * (float(mob["radius"]) - 6.0) + Vector2(0, -30)


# ---- the hero behind it -----------------------------------------------------------------------------------------------------

## The hero stands behind the body: a pale one-pixel outline of his frame and every other pixel of it, over the boss.
func draw_hero_ghost(canvas: CanvasItem, mob: Dictionary, hero_at: Vector2, hero_key: String, left: bool, frames: Dictionary, sprites: Texture2D, tint: Color) -> void:
	if not frames.has(hero_key) or mob["state"] == &"dead" or hero_at.y >= Vector2(mob["position"]).y:
		return
	var frame: Dictionary = frames[hero_key]
	var rect: Rect2 = ArenaAnimation.destination(hero_at, frame, left).abs()
	if not rect.intersects(body_rect(mob, frames)):
		return
	var ghost: ImageTexture = _ghost(hero_key, frame, sprites)
	if ghost != null:
		canvas.draw_texture_rect(ghost, ArenaAnimation.destination(hero_at, frame, left), false, tint)


func _ghost(key: String, frame: Dictionary, sprites: Texture2D) -> ImageTexture:
	if _ghosts.has(key):
		return _ghosts[key]
	if _atlas_image == null:
		_atlas_image = sprites.get_image()
		if _atlas_image == null:
			return null
		_atlas_image.convert(Image.FORMAT_RGBA8)
	var source: Image = _atlas_image.get_region(Rect2i(int(frame["x"]), int(frame["y"]), int(frame["w"]), int(frame["h"])))
	var out: Image = Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, source.get_size())
	for y: int in source.get_height():
		for x: int in source.get_width():
			if source.get_pixel(x, y).a > 0.5:
				if (x + y) % 2 == 0:
					out.set_pixel(x, y, source.get_pixel(x, y))
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = Vector2i(x, y) + step
				if bounds.has_point(near) and source.get_pixelv(near).a > 0.5:
					out.set_pixel(x, y, OUTLINE)
					break
	var texture: ImageTexture = ImageTexture.create_from_image(out)
	_ghosts[key] = texture
	return texture


# ---- warnings ---------------------------------------------------------------------------------------------------------------

## Its warnings' edges once more, unlit and 2 px wide, so the night floor does not dim them.
static func draw_glowing_edges(canvas: CanvasItem, view: ExploreCore.ExploreSnapshot, colors: Dictionary) -> void:
	var boss: Dictionary = find(view)
	if boss.is_empty():
		return
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.owner_id != int(boss["id"]) or not TelegraphView.warning_visible(t, view.tick):
			continue
		var colour: Color = colors["x"] if t.kind == &"gold" else colors["z"]
		var edges: Array[PackedVector2Array] = [TelegraphView.outline(t)]
		if t.shape == &"ring":
			edges.append(TelegraphView.ring_points(t.center, t.inner_size))
		for edge: PackedVector2Array in edges:
			canvas.draw_polyline(edge, Color(colors["0"], Fireflies.EMISSIVE_ALPHA), 4.0)
			canvas.draw_polyline(edge, Color(colour, Fireflies.EMISSIVE_ALPHA), 2.0)


# ---- the camera -------------------------------------------------------------------------------------------------------------

## The view's top-left corner in the fight: the hero-centred view slid only as far as it takes to show the whole body, the hero
## kept off the screen's edges, inside the scene.
static func fight_view(hero: Vector2, mob: Dictionary, frames: Dictionary, scene_size: Vector2) -> Vector2:
	var origin: Vector2 = hero - VIEW * 0.5
	var box: Rect2 = body_rect(mob, frames).grow(4.0)
	origin = origin.clamp(box.end - VIEW, box.position.max(box.end - VIEW))
	origin = origin.clamp(hero - VIEW + Vector2(HERO_SIDE, HERO_BOTTOM), hero - Vector2(HERO_SIDE, HERO_TOP))
	return origin.round().clamp(Vector2.ZERO, (scene_size - VIEW).max(Vector2.ZERO))


## One step of the view toward `target`. Only `blending` (the fight framing just switched on or off) eases; otherwise the view is
## exactly the target, as it always was (no lag behind a dash). A jump (a respawn) never eases. Returns [view, still blending].
static func ease_view(current: Vector2, target: Vector2, blending: bool) -> Array:
	var gap: float = current.distance_to(target)
	if not blending or gap > SNAP_DISTANCE or gap < 1.0:
		return [target, false]
	return [current.move_toward(target, maxf(2.0, gap * 0.15)).round(), true]


# ---- light ------------------------------------------------------------------------------------------------------------------

## The song's light in its chest (a halo and a pool on the floor): faint asleep, full awake, none once it has fallen.
static func lamps(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mob: Dictionary = find(view)
	if mob.is_empty() or mob["state"] == &"dead":
		return out
	var feet: Vector2 = mob["position"]
	var asleep: bool = mob["state"] == &"idle"
	var chest: Vector2 = feet - Vector2(0, CHEST - (ASLEEP_SINK if asleep else 0))
	out.append({"point": Vector4(chest.x, chest.y, 20.0 if asleep else 56.0, 0.35 if asleep else 1.1), "colour": CHEST_COLOUR, "core": CHEST_CORE})
	out.append({"point": Vector4(feet.x, feet.y + 6.0, 50.0 if asleep else 140.0, -(0.3 if asleep else 1.2)), "colour": CHEST_COLOUR, "core": CHEST_CORE})
	return out


# ---- blows landing: sound, shake, dust ----------------------------------------------------------------------------------------

## Once per snapshot tick: the blows that landed this tick. Returns [{attack, at, heavy}] for the scene to sound, shake and dust.
## A parry can clear a warning on the tick it lands, so the last tick's warnings count too.
func landed(view: ExploreCore.ExploreSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if view.tick == _last_tick:
		return out
	if view.tick < _last_tick:
		clear()
	_last_tick = view.tick
	var boss: Dictionary = find(view)
	if boss.is_empty():
		_previous.clear()
		return out
	var candidates: Array[Snapshots.TelegraphSnapshot] = []
	candidates.append_array(_previous)
	candidates.append_array(view.telegraphs)
	for t: Snapshots.TelegraphSnapshot in candidates:
		if t.owner_id != int(boss["id"]) or _seen_hits.has(t.id) or view.tick < t.hit_tick or view.tick > t.end_tick + 1:
			continue
		_seen_hits[t.id] = true
		out.append({"attack": t.attack, "at": t.center if t.shape in [&"circle", &"ring"] else Vector2(boss["position"]), "heavy": t.attack in HEAVY,
			"cue": String(STRIKE_CUES.get(t.attack, ""))})
		if t.attack == &"root_snare":  # its lane bursts into thorns (the second lane too)
			effects.append({"kind": &"thorns", "tick": t.hit_tick, "at": t.center, "direction": t.direction, "size": t.size})
		elif t.attack == &"boulder_toss" and t.shape == &"circle":  # the stone lands
			effects.append({"kind": &"land", "tick": t.hit_tick, "at": t.center})
		elif t.attack == &"heartroot_grab":  # the root-arm lashes (parried or not) and slides back
			effects.append({"kind": &"arm", "tick": t.hit_tick, "at": t.center + t.direction * ARM_ROOT, "direction": t.direction})
		elif t.attack == &"boulder_toss" and t.shape == &"ring":  # its ring of shock strikes: shards over the real band
			effects.append({"kind": &"shards", "tick": t.hit_tick, "at": t.center, "radius": (t.inner_size + t.size) * 0.5})
	_previous.clear()
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.owner_id == int(boss["id"]):
			_previous.append(t)
	return out
