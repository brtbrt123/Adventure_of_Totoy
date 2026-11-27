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

var _seen_hits: Dictionary = {}  # telegraph id -> true once its blow landed (sound, shake, dust once)
var _previous: Array[Snapshots.TelegraphSnapshot] = []
var _ghosts: Dictionary = {}  # hero frame key -> ImageTexture (outline + every other pixel)
var _atlas_image: Image = null
var _last_tick: int = -1


func clear() -> void:
	_seen_hits.clear()
	_previous.clear()
	_last_tick = -1


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
	_previous.clear()
	for t: Snapshots.TelegraphSnapshot in view.telegraphs:
		if t.owner_id == int(boss["id"]):
			_previous.append(t)
	return out
