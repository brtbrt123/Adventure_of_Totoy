extends Node2D
## The hero's combat effects, shared by every scene that draws him: the fight (arena.gd) and the road (explore_scene.gd).
## Both extend this script, so one effect looks and behaves the same everywhere. Mob and boss effects are NOT here (each
## scene has its own). The effects come from core events and the hero's snapshot: hit bursts, particles, dust, parry
## impacts, screen shake and flashes, dash afterimages, and the three aspects' looks (Sprint, Echo Step, Stone Ward).
## A scene only says who the hero is and what tick it is (the fx_* hooks below) and calls the on_hero_* / fx_* helpers.
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const PlayerState := preload("res://core/player.gd")
const CombatEffects := preload("res://presentation/arena/combat_effects.gd")
const WardEchoSprintEffects := preload("res://presentation/arena/ward_echo_sprint_effects.gd")

var colors: Dictionary = {}
var frames: Dictionary = {}
var sprites: Texture2D
var facing_left: bool = false
## Short bursts of single pixels: {"position", "velocity", "life", "color"}.
var particles: Array[Dictionary] = []
## The hero's landed swings: {"position", "contact", "tick", "counter", "finisher", "skill_id", "facing"}.
var hit_bursts: Array[Dictionary] = []
## Successful parries: {"position", "tick", "perfect", "contact"}.
var parry_impacts: Array[Dictionary] = []
## Dash afterimages: {"position", "left", "life"}.
var dash_ghosts: Array[Dictionary] = []
## Screen shake ticks left, and the tick until which a faint full-screen flash shows.
var shake_left: int = 0
var screen_flash_until: int = -1
## Short full-screen flashes: {"tick", "color", "strengths": Array[float]} (one strength per tick of age).
var screen_flashes: Array[Dictionary] = []
## Echo Step / Stone Ward / Sprint event effects in world coordinates ({"kind", "tick", "life", ...}), capped at
## WardEchoSprintEffects.MAX_LIVE. The echo anchor, the ward pose/barrier/glow and the sprint look draw from the snapshot.
var wes_fx: Array[Dictionary] = []
## Past hero samples for the sprint afterimages: {"at", "frame", "left"}, one per fresh tick while Sprint runs.
var sprint_trail: Array[Dictionary] = []
## True when the hero moved on the latest fresh tick (speed lines, dust and wind only show while moving).
var hero_moving: bool = false
## Cosmetic tick until which the hero is not drawn (arrive frame 1 of an Echo Step recall); -1 = none.
var hero_hidden_until: int = -1
## Tick of the latest ward_blocked (the barrier shows the absorb flash for a few ticks).
var ward_absorb_tick: int = -1000
var previous_player_position: Vector2 = Vector2.ZERO


# --- what a scene tells this layer (override in the scene) ---

func fx_hero() -> Snapshots.EntitySnapshot:
	return null


func fx_tick() -> int:
	return 0


## Ticks that keep counting after the fight ended (so the last effects finish); 0 on the road.
func fx_result_ticks() -> int:
	return 0


## False once a result is showing (no hero auras then).
func fx_playing() -> bool:
	return true


func fx_cue(_key: String, _tick: int, _strength: float = 1.0) -> void:
	pass


# --- the hero's swing and parry (called from the scene's event handler) ---

## The hero's swing landed: the burst picture at `contact`, a spray of particles and a little shake.
func on_hero_hit(tick: int, position: Vector2, contact: Vector2, counter: bool, finisher: bool, skill_id: Variant = &"") -> void:
	hit_bursts.append({"position": position, "contact": contact, "tick": tick, "counter": counter, "finisher": finisher, "skill_id": skill_id, "facing": fx_hero().facing})
	shake_left = maxi(shake_left, 3 if finisher else 1)
	_burst(contact, 16 if counter or finisher else 8, colors["1"], 1.8 if counter else 0.9)
	if counter:
		shake_left = maxi(shake_left, 5)


## The hero parried: gold sparks, the parry ring, shake and a faint flash (a perfect parry is bigger).
func on_hero_parry(tick: int, position: Vector2, contact: Vector2, perfect: bool) -> void:
	_burst(contact, 16 if perfect else 7, colors["x"], 1.6 if perfect else 1.0)
	parry_impacts.append({"position": position, "tick": tick, "perfect": perfect, "contact": contact})
	shake_left = maxi(shake_left, 7 if perfect else 3)
	screen_flash_until = tick + (2 if perfect else 1)


## One tick older: particles move and die, the effect lists drop what has finished, the shake runs down.
func age_hero_fx() -> void:
	var cosmetic_tick: int = _cosmetic_tick()
	shake_left = maxi(0, shake_left - 1)
	for i: int in range(wes_fx.size() - 1, -1, -1):
		if cosmetic_tick - int(wes_fx[i]["tick"]) >= int(wes_fx[i]["life"]):
			wes_fx.remove_at(i)
	for i: int in range(screen_flashes.size() - 1, -1, -1):
		if cosmetic_tick - int(screen_flashes[i]["tick"]) >= Array(screen_flashes[i]["strengths"]).size():
			screen_flashes.remove_at(i)
	for i: int in range(hit_bursts.size() - 1, -1, -1):
		if cosmetic_tick - int(hit_bursts[i]["tick"]) >= 12:
			hit_bursts.remove_at(i)
	for index: int in range(particles.size() - 1, -1, -1):
		particles[index]["life"] -= 1
		particles[index]["position"] += particles[index]["velocity"]
		if particles[index]["life"] <= 0:
			particles.remove_at(index)


## The uniform offset that shakes floor, actors and effects together.
func shake_offset() -> Vector2:
	if shake_left <= 0:
		return Vector2.ZERO
	return Vector2(1 if shake_left % 2 == 0 else -1, 1 if shake_left % 3 == 0 else -1)


## The painted parry rings, hit bursts and particles (above the actors).
func draw_hero_impacts() -> void:
	var tick: int = fx_tick()
	for impact: Dictionary in parry_impacts:
		var age: int = tick - int(impact["tick"])
		var contact: Vector2 = impact.get("contact", impact["position"])
		var size_scale: Vector2 = Vector2(1.15, 1.15) if bool(impact["perfect"]) else Vector2(0.75, 0.75)
		_draw_imported("fx_parry_%d" % (mini(5, age / 2) + 1), contact, size_scale)
		if age < 2 and bool(impact["perfect"]):
			_draw_imported("fx_flash_1", contact, Vector2(0.6, 0.6))
	for burst: Dictionary in hit_bursts:
		var age: int = _cosmetic_tick() - int(burst["tick"])
		var contact: Vector2 = burst.get("contact", burst["position"])
		var heavy: bool = bool(burst.get("finisher", false)) or bool(burst["counter"])
		_draw_imported("fx_%s_%d" % ["counter" if bool(burst["counter"]) else "hit", mini(5, age / 2) + 1], contact, Vector2(1.3, 1.3) if heavy else Vector2.ONE)
		if age < 2:
			_draw_imported("fx_flash_1", contact, Vector2(0.65, 0.65) if heavy else Vector2(0.4, 0.4))
	for particle: Dictionary in particles:
		var at: Vector2 = particle["position"]
		draw_rect(Rect2(at.round(), Vector2.ONE), particle["color"])


## Screen-sized flashes (call after the shake transform is reset, with the screen's top-left in world space).
func draw_hero_screen_flashes(view_origin: Vector2, view_size: Vector2) -> void:
	if fx_tick() < screen_flash_until:
		draw_rect(Rect2(view_origin, view_size), Color(colors["1"], 0.10))
	var cosmetic_tick: int = _cosmetic_tick()
	for flash: Dictionary in screen_flashes:
		var strengths: Array = flash["strengths"]
		var age: int = cosmetic_tick - int(flash["tick"])
		if age >= 0 and age < strengths.size():
			draw_rect(Rect2(view_origin, view_size), Color(flash["color"], float(strengths[age])))


## Which frame the hero is drawn with this tick (the Sprint afterimages copy it).
func fx_hero_frame() -> String:
	return ""


## The Black Form look (a dark hero): the dash afterimages use `fx_dark_sprites()` instead of white ones.
func fx_black_form() -> bool:
	return false


func fx_dark_sprites() -> Texture2D:
	return sprites


## Extra picture behind a dash afterimage in the Black Form look (the fight draws its dark aura there).
func fx_black_ghost(_position: Vector2, _left: bool) -> void:
	pass


## The hero's movement for this fresh tick: dash afterimages, footstep and dash dust, the Sprint trail. `was_left` is
## the facing before this tick; `gale` adds an afterimage for a skill that travels (the fight's Gale Cut).
func track_hero_motion(moved: bool, previous_state: StringName, was_left: bool, gale: bool = false) -> void:
	var hero: Snapshots.EntitySnapshot = fx_hero()
	hero_moving = moved and hero.state != &"dead"
	if hero.sprint_ticks_left > 0 and fx_playing():
		if _motion_seen and fx_hero_frame() != "":
			sprint_trail.append({"at": previous_player_position.round(), "frame": fx_hero_frame(), "left": was_left})
			while sprint_trail.size() > WardEchoSprintEffects.TRAIL_CAP:
				sprint_trail.pop_front()
	else:
		sprint_trail.clear()
	for i: int in range(dash_ghosts.size() - 1, -1, -1):
		dash_ghosts[i]["life"] -= 1
		if int(dash_ghosts[i]["life"]) <= 0:
			dash_ghosts.remove_at(i)
	if (hero.state == &"dash" and previous_state == &"dash") or gale:
		dash_ghosts.append({"position": previous_player_position, "left": facing_left, "life": 6})
		if dash_ghosts.size() > 3:
			dash_ghosts.pop_front()
	if hero.state == &"dash" and hero.state_ticks == 0:
		_dust(hero.position)
	if hero.state == &"walk":
		var cadence: int = int(ArenaAnimation.PLAYER["walk"][1])
		if hero.state_ticks % (cadence * 2) == 0:
			_dust(hero.position)
	_motion_seen = true
	previous_player_position = hero.position


var _motion_seen: bool = false
var white_sprites: Texture2D


## The dash afterimages and the dash streak at the hero's feet (under the actors' effects, over the floor).
func draw_dash_fx() -> void:
	var hero: Snapshots.EntitySnapshot = fx_hero()
	var frame: Dictionary = frames.get(ArenaAnimation.hero_frame(ArenaAnimation.hero_set(hero), "dash", 1), frames.get("hero2_dash_right_1", {}))
	if frame.is_empty():
		return
	for ghost: Dictionary in dash_ghosts:
		var fade: float = float(ghost["life"]) / 6.0
		var rect: Rect2 = ArenaAnimation.destination(ghost["position"], frame, bool(ghost["left"]))
		var source: Rect2 = Rect2(frame["x"], frame["y"], frame["w"], frame["h"])
		if fx_black_form():
			draw_texture_rect_region(fx_dark_sprites(), rect, source)
			fx_black_ghost(ghost["position"], bool(ghost["left"]))
		elif white_sprites != null:
			draw_texture_rect_region(white_sprites, rect, source, Color(colors["o"], fade * 0.55))
	if hero.state == &"dash":
		_draw_imported("fx_dash_%d" % (mini(5, hero.state_ticks / 2) + 1), hero.position - Vector2(0, 10), Vector2(-1 if facing_left else 1, 1))


# --- moved here from the arena (unchanged apart from the fx_* hooks) ---

func _burst(at: Vector2, count: int, color: Color, speed: float) -> void:
	for i: int in range(count):
		particles.append({"position": at, "velocity": Vector2.from_angle(TAU * i / count) * speed, "life": 7 if i % 3 == 0 else 11, "color": colors["p"] if color == colors["1"] and i % 3 == 0 else (colors["o"] if color == colors["1"] and i % 3 == 1 else color)})

func _dust(at: Vector2) -> void:
	for i: int in range(5):
		particles.append({"position": at + Vector2(i - 2, 2), "velocity": Vector2((i - 2) * 0.18, -0.22), "life": 6, "color": colors["c"] if i % 2 == 0 else colors["d"]})

func _flash(tick: int, color: Color, strengths: Array[float]) -> void:
	screen_flashes.append({"tick": tick, "color": color, "strengths": strengths})

func _add_wes_fx(effect: Dictionary) -> void:
	WardEchoSprintEffects.add(wes_fx, effect)

func _mirror(offset: Vector2, left: bool) -> Vector2:
	return Vector2(-offset.x, offset.y) if left else offset

## True for the first frame of an Echo Step arrival (the echo flares; the hero appears with arrive frame 2).
func hero_hidden() -> bool:
	return hero_hidden_until >= 0 and _cosmetic_tick() < hero_hidden_until

func _cosmetic_tick() -> int:
	return fx_tick() + fx_result_ticks()

func _draw_imported(key: String, at: Vector2, size_scale: Vector2 = Vector2.ONE) -> void:
	if not frames.has(key):
		push_warning("Missing imported effect/UI/prop: " + key)
		return
	var frame: Dictionary = frames[key]
	var anchor: Vector2 = Vector2(frame.get("ax", float(frame["w"]) / 2), frame.get("ay", float(frame["h"]) / 2))
	var extent: Vector2 = Vector2(frame["w"], frame["h"])
	var origin: Vector2 = at - anchor * size_scale.abs()
	if size_scale.x < 0:
		origin.x = at.x - (extent.x - anchor.x) * absf(size_scale.x)
	draw_texture_rect_region(sprites, Rect2(origin.round(), extent * size_scale), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))

## A frame by its own anchor, mirrored around it for `left` (the same rule as the hero frames).
func _draw_anchored(key: String, at: Vector2, left: bool) -> void:
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	draw_texture_rect_region(sprites, ArenaAnimation.destination(at, f, left), Rect2(f["x"], f["y"], f["w"], f["h"]))

## A frame by its own anchor at `scale_px` (1 = native), as _draw_imported does.
func _draw_scaled(key: String, at: Vector2, scale_px: float) -> void:
	if not frames.has(key):
		return
	if is_equal_approx(scale_px, 1.0):
		_draw_imported(key, at)
	else:
		_draw_imported(key, at, Vector2(scale_px, scale_px))

## Behind the hero sprite while Sprint runs: the afterimages where he was (farthest first), and while he moves the
## speed lines and the foot dust.
func sprint_back_plan(actor: Snapshots.EntitySnapshot, at: Vector2, left: bool) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if actor.sprint_ticks_left <= 0 or not fx_playing():
		return plan
	for k: int in range(WardEchoSprintEffects.AFTERIMAGES, 0, -1):
		var index: int = sprint_trail.size() - k * WardEchoSprintEffects.AFTERIMAGE_STEP
		if index < 0:
			continue
		var sample: Dictionary = sprint_trail[index]
		if Vector2(sample["at"]).distance_to(at) < WardEchoSprintEffects.AFTERIMAGE_MIN_GAP:
			continue
		var key: String = WardEchoSprintEffects.after_key(ArenaAnimation.overlay_frame(String(sample["frame"])), k)
		if frames.has(key):
			plan.append({"key": key, "at": sample["at"], "left": bool(sample["left"])})
	if hero_moving:
		plan.append({"key": WardEchoSprintEffects.lines_key(fx_tick()), "at": at, "left": left})
		plan.append({"key": WardEchoSprintEffects.dust_key(fx_tick()), "at": at, "left": left})
	return plan

func _draw_sprint_back(actor: Snapshots.EntitySnapshot, at: Vector2, left: bool) -> void:
	for item: Dictionary in sprint_back_plan(actor, at, left):
		_draw_anchored(item["key"], item["at"], bool(item["left"]))

## Over the hero sprite: the sprint aura and wind, the Echo Step i-frame shield (the per-frame outline, else the
## bubble), and the Stone Ward's barrier (or its absorb flash) with the stored glow (and the slab, should the drawn
## frame not have it painted in).
func hero_overlay_plan(actor: Snapshots.EntitySnapshot, hero_frame: String, at: Vector2, left: bool) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if not fx_playing():
		return plan
	var base: String = ArenaAnimation.overlay_frame(hero_frame)
	if actor.sprint_ticks_left > 0:
		var aura: String = WardEchoSprintEffects.aura_key(base, WardEchoSprintEffects.since_sprint_start(actor.sprint_ticks_left))
		if frames.has(aura):
			plan.append({"key": aura, "at": at, "left": left})
		if hero_moving:
			plan.append({"key": WardEchoSprintEffects.wind_key(fx_tick()), "at": at, "left": left})
	if actor.state == PlayerState.STATE_WARD and actor.ward_ticks_left > 0:
		if not hero_frame.contains("_ward_"):
			plan.append({"key": WardEchoSprintEffects.slab_key(actor.ward_ticks_left), "at": at, "left": left})
		if WardEchoSprintEffects.barrier_visible(actor.ward_ticks_left):
			var absorb: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.ABSORB_TICKS, fx_tick() - ward_absorb_tick)
			plan.append({"key": "fx_ward_absorb_%d" % absorb if absorb > 0 else WardEchoSprintEffects.barrier_key(actor.ward_ticks_left), "at": at, "left": left})
			var level: int = WardEchoSprintEffects.store_level(actor.ward_stored)
			if level > 0:
				plan.append({"key": WardEchoSprintEffects.store_key(level, fx_tick()), "at": at, "left": left})
	if actor.echo_invuln_ticks > 0:
		var phase: int = WardEchoSprintEffects.shield_phase(actor.echo_invuln_ticks)
		var shield: String = WardEchoSprintEffects.shield_key(base, phase)
		plan.append({"key": shield if frames.has(shield) else WardEchoSprintEffects.bubble_key(phase), "at": at, "left": left})
	return plan

func _draw_hero_aspect_overlays(actor: Snapshots.EntitySnapshot, hero_frame: String, at: Vector2, left: bool) -> void:
	for item: Dictionary in hero_overlay_plan(actor, hero_frame, at, left):
		_draw_anchored(item["key"], item["at"], bool(item["left"]))

## Floor layer (under every character): the ward's shockwave ring and its crack decal.
func ward_echo_ground_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var cosmetic_tick: int = _cosmetic_tick()
	for effect: Dictionary in wes_fx:
		var age: int = cosmetic_tick - int(effect["tick"])
		match String(effect["kind"]):
			"ward_cracks":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.CRACKS_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_ward_cracks_%d" % frame, "at": effect["at"], "scale": 1.0})
			"ward_shockwave":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.SHOCKWAVE_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_ward_shockwave_%d" % frame, "at": effect["at"], "scale": float(effect["scale"]), "radius": WardEchoSprintEffects.shockwave_radius(frame, float(effect["scale"]))})
	return plan

func _draw_ward_echo_ground() -> void:
	for item: Dictionary in ward_echo_ground_plan():
		_draw_scaled(item["key"], item["at"], float(item["scale"]))

## Over everything standing: the echo placement burst, the recall's vanish column, pull streak, comet head and arrival,
## dust, the sprint start/end bursts and the ward's block sparks.
func ward_echo_front_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var hero: Snapshots.EntitySnapshot = fx_hero()
	var feet: Vector2 = hero.position.round()
	var cosmetic_tick: int = _cosmetic_tick()
	for effect: Dictionary in wes_fx:
		var age: int = cosmetic_tick - int(effect["tick"])
		match String(effect["kind"]):
			"echo_place":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.PLACE_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_echo_place_%d" % frame, "at": effect["at"], "left": false})
			"echo_dust":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.ECHO_DUST_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_echo_dust_%d" % frame, "at": effect["at"], "left": false})
			"echo_vanish":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.VANISH_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_echo_vanish_%d" % frame, "at": effect["at"], "left": false})
			"echo_trail":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.TRAIL_TICKS, age)
				if frame > 0:
					var from: Vector2 = effect["from"]
					var to: Vector2 = effect["to"]
					var family: Dictionary = WardEchoSprintEffects.trail_family((to - from).angle())
					plan.append({"key": WardEchoSprintEffects.trail_key(family["family"], frame), "trail": true, "from": from, "to": to, "family": family["family"], "rotation": float(family["rotation"])})
					plan.append({"key": "fx_echo_trail_head_%d" % frame, "at": to, "left": false})
			"echo_arrive":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.ARRIVE_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_echo_arrive_%d" % frame, "at": effect["at"], "left": false})
			"sprint_start":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.SPRINT_START_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_sprint_start_%d" % frame, "at": effect["at"], "left": bool(effect["left"])})
			"sprint_end":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.SPRINT_END_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_sprint_end_%d" % frame, "at": feet, "left": facing_left})
			"ward_block":
				var frame: int = WardEchoSprintEffects.sequence_frame(WardEchoSprintEffects.BLOCK_TICKS, age)
				if frame > 0:
					plan.append({"key": "fx_ward_block_%d" % frame, "at": feet + _mirror(WardEchoSprintEffects.BLOCK_POINT, bool(effect["left"])), "left": bool(effect["left"])})
	return plan

func _draw_ward_echo_front(shake_offset: Vector2) -> void:
	for item: Dictionary in ward_echo_front_plan():
		if bool(item.get("trail", false)):
			_draw_echo_trail(item, shake_offset)
		else:
			_draw_anchored(item["key"], item["at"], bool(item["left"]))

## The recall streak: trail tiles of the chosen family end to end from `from` to `to`, rotated so the art runs along
## the streak (pixel-exact for the 8 main directions), the last tile cropped to the remaining length.
func _draw_echo_trail(item: Dictionary, shake_offset: Vector2) -> void:
	var key: String = item["key"]
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	var from: Vector2 = item["from"]
	var to: Vector2 = item["to"]
	var family: String = item["family"]
	var step: Vector2 = WardEchoSprintEffects.TRAIL_FAMILIES[family]["step"]
	var unit: Vector2 = step.normalized()
	var anchor: Vector2 = Vector2(float(f.get("ax", 0)), float(f.get("ay", 0)))
	draw_set_transform(from + shake_offset, float(item["rotation"]))
	for tile: Dictionary in WardEchoSprintEffects.trail_tiles(from.distance_to(to), family):
		var fraction: float = float(tile["fraction"])
		var size: Vector2 = Vector2(f["w"], f["h"])
		# crop along the tile's own axis: h by width, v by height, d by both
		if family == "h":
			size.x = ceilf(size.x * fraction)
		elif family == "v":
			size.y = ceilf(size.y * fraction)
		else:
			size = (size * fraction).ceil()
		if size.x < 1.0 or size.y < 1.0:
			continue
		var origin: Vector2 = unit * float(tile["offset"]) - anchor
		draw_texture_rect_region(sprites, Rect2(origin.round(), size), Rect2(Vector2(f["x"], f["y"]), size))
	draw_set_transform(shake_offset)

## Events of the three aspects. Sounds reuse the combat cues (no new audio).
func _on_ward_echo_sprint(event: GameEvent) -> void:
	var tick: int = event.tick
	match event.type:
		&"sprint_started":
			_add_wes_fx({"kind": "sprint_start", "tick": tick, "at": fx_hero().position.round(), "left": facing_left, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.SPRINT_START_TICKS)})
			fx_cue("sprint", tick, 0.5)
		&"sprint_ended":
			sprint_trail.clear()
			if event.data.get("reason", &"expired") == &"expired":
				_add_wes_fx({"kind": "sprint_end", "tick": tick, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.SPRINT_END_TICKS)})
				fx_cue("weapon_buff_end", tick, 0.3)
		&"echo_placed":
			var at: Vector2 = Vector2(event.data["position"]).round()
			_add_wes_fx({"kind": "echo_place", "tick": tick, "at": at, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.PLACE_TICKS)})
			_add_wes_fx({"kind": "echo_dust", "tick": tick, "at": at, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.ECHO_DUST_TICKS)})
			fx_cue("echo_place", tick, 0.45)
		&"echo_recall":
			var from: Vector2 = Vector2(event.data["from"]).round()
			var to: Vector2 = Vector2(event.data["to"]).round()
			_add_wes_fx({"kind": "echo_vanish", "tick": tick, "at": from, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.VANISH_TICKS)})
			_add_wes_fx({"kind": "echo_dust", "tick": tick, "at": from, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.ECHO_DUST_TICKS)})
			if from.distance_to(to) > 2.0:
				_add_wes_fx({"kind": "echo_trail", "tick": tick, "from": from + WardEchoSprintEffects.CHEST, "to": to + WardEchoSprintEffects.CHEST, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.TRAIL_TICKS)})
			_add_wes_fx({"kind": "echo_arrive", "tick": tick, "at": to, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.ARRIVE_TICKS)})
			_add_wes_fx({"kind": "echo_dust", "tick": tick + WardEchoSprintEffects.ARRIVE_HIDE_TICKS, "at": to, "life": WardEchoSprintEffects.ARRIVE_HIDE_TICKS + WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.ECHO_DUST_TICKS)})
			hero_hidden_until = tick + WardEchoSprintEffects.ARRIVE_HIDE_TICKS
			# a teleport: nothing may smear across it (afterimages, dash ghosts, the dust/trail bookkeeping); the camera
			# already follows the snapshot position without smoothing
			sprint_trail.clear()
			dash_ghosts.clear()
			previous_player_position = fx_hero().position
			shake_left = maxi(shake_left, 2)
			_flash(tick, colors["p"], [0.10])
			fx_cue("echo_recall", tick, 0.9)
		&"echo_expired":
			_add_wes_fx({"kind": "echo_vanish", "tick": tick, "at": Vector2(event.data["position"]).round(), "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.VANISH_TICKS)})
		&"ward_raised":
			var facing: Vector2 = event.data.get("facing", fx_hero().facing)
			if absf(facing.x) > 0.3:
				facing_left = facing.x < 0.0
			ward_absorb_tick = -1000
			_dust(fx_hero().position)
			fx_cue("ward_raise", tick, 0.5)
		&"ward_blocked":
			ward_absorb_tick = tick
			_add_wes_fx({"kind": "ward_block", "tick": tick, "left": facing_left, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.BLOCK_TICKS)})
			shake_left = maxi(shake_left, 2)
			fx_cue("deflect", tick, 1.0)
		&"ward_released":
			var at: Vector2 = Vector2(event.data["position"]).round()
			var radius: float = float(event.data.get("radius", Tuning.STONE_WARD_RADIUS))
			_add_wes_fx({"kind": "ward_shockwave", "tick": tick, "at": at, "scale": WardEchoSprintEffects.shockwave_scale(radius), "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.SHOCKWAVE_TICKS)})
			_add_wes_fx({"kind": "ward_cracks", "tick": tick, "at": at, "life": WardEchoSprintEffects.sequence_length(WardEchoSprintEffects.CRACKS_TICKS)})
			_burst(at - Vector2(0, 4), 10, colors["g"], 1.2)
			shake_left = maxi(shake_left, 4)
			fx_cue("ward_release", tick, 0.6 if bool(event.data.get("hit", false)) else 0.4)