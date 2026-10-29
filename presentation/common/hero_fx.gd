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
const AspectEffects := preload("res://presentation/arena/aspect_effects.gd")
const Weapons := preload("res://core/weapons.gd")
const WeaponBuffView := preload("res://presentation/arena/weapon_buff_view.gd")
const SkillEffects := preload("res://presentation/arena/skill_effects.gd")

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
## The Black Form hero (a darkened copy of the atlas), the weapon buff's pixel-coverage textures, the weapon_buff_* events
## already seen, and the latest start/end ({"tick", "started", "at", "form"}) that draws a short aura burst.
var empowered_sprites: Texture2D
var buff_textures: Dictionary = {}
var buff_events: Dictionary = {}
var buff_transition: Dictionary = {}
## A lantern sorts just in front of a body standing on the same ground row (it is placed at the hero's feet and would
## otherwise vanish behind his legs); under a pixel, so the whole-pixel draw position does not move.
const LANTERN_SORT_BIAS: Vector2 = Vector2(0, 0.4)
## Spirit Lantern / Phantom Cut event effects in world coordinates ({"kind", "tick", "life", ...}), capped at
## AspectEffects.MAX_LIVE. The lantern prop, its pool, the Phantom glow and the echo marker draw from the snapshot.
var aspect_fx: Array[Dictionary] = []
var projectile_textures: Dictionary = {}
## Frame name -> top row of its visible pixels (the Phantom marker floats over the head).
var frame_tops: Dictionary = {}
## The latest skill_released event's data (the melee crescent follows it) and the attack ids already seen.
var current_skill_release: Dictionary = {}
var released_skill_attacks: Dictionary = {}


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


## The scene's snapshot (it has tick, skill_attacks, lanterns and echoes, like the fight's GameSnapshot).
func fx_snapshot() -> RefCounted:
	return null


## Where an effect lands on the target with this id (a mob's or the boss's body); `fallback` when it is unknown.
func fx_target_contact(_target_id: int, fallback: Vector2) -> Vector2:
	return fallback


## skill_started / skill_released: keeps what the skill's picture follows. False for a release already seen.
func on_hero_skill_event(event: GameEvent) -> bool:
	if event.type == &"skill_started":
		current_skill_release.clear()
		return true
	var attack_id: int = int(event.data["attack_id"])
	if released_skill_attacks.has(attack_id):
		return false
	released_skill_attacks[attack_id] = true
	current_skill_release = event.data.duplicate()
	return true


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
	for i: int in range(aspect_fx.size() - 1, -1, -1):
		if cosmetic_tick - int(aspect_fx[i]["tick"]) >= int(aspect_fx[i]["life"]):
			aspect_fx.remove_at(i)
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
	return black_form_look(fx_hero())


func fx_dark_sprites() -> Texture2D:
	return empowered_sprites


## The dark aura behind a dash afterimage in the Black Form look.
func fx_black_ghost(at: Vector2, left: bool) -> void:
	_draw_buff_frame("fx_black_aura_back_%d" % (posmod(fx_tick() / 5, 6) + 1), at, 1, left)


## weapon_buff_started / weapon_buff_ended: the aura burst and particles. Returns {"started", "form"} for the scene to play its
## cut-in and sound, or {} for an event already seen.
func on_hero_weapon_buff(event: GameEvent) -> Dictionary:
	var identity: String = "%s:%d:%d" % [event.type, event.tick, int(event.data["entity_id"])]
	if buff_events.has(identity):
		return {}
	buff_events[identity] = true
	var started: bool = event.type == &"weapon_buff_started"
	# Older events have no form: the weapon says which active it was.
	var form: StringName = StringName(event.data.get("form", Weapons.active_form(StringName(event.data.get("weapon_id", Tuning.WEAPON_BLACK_KATANA)))))
	var lightning: bool = form == Weapons.FORM_LIGHTNING
	var coil: bool = form == Weapons.FORM_REAPER_COIL
	buff_transition = {"tick": event.tick, "started": started, "at": fx_hero().position, "form": form}
	_burst(fx_hero().position - Vector2(0, 12), 12 if started else 6, colors["o"] if lightning else (colors["u"] if coil else colors["k"]), 0.8)
	return {"started": started, "form": form}


## The copies of the atlas the shared effects need (built by tools/art/build_art.py): the white silhouette and the dark hero.
func load_variant_atlases() -> void:
	if ResourceLoader.exists("res://art/build/sprites_white.png"):
		white_sprites = load("res://art/build/sprites_white.png") as Texture2D
	if ResourceLoader.exists("res://art/build/sprites_dark.png"):
		empowered_sprites = load("res://art/build/sprites_dark.png") as Texture2D


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


# --- the aspects and skills (moved here from the arena) ---

## Effects follow current snapshot phases; cancelled skills leave no queued release.
func skill_effect() -> Dictionary:
	if not fx_playing():
		return {}
	if fx_hero().state != &"skill_windup" and current_skill_release.get("skill_id", &"") != fx_hero().skill_id:
		return {}
	return SkillEffects.plan(fx_hero())

func _draw_skill_effect(shake_offset: Vector2 = Vector2.ZERO) -> void:
	var effect: Dictionary = skill_effect()
	if effect.is_empty():
		return
	var key: String = effect["key"]
	if not frames.has(key):
		push_warning("Missing skill effect: " + key)
		return
	var frame: Dictionary = frames[key]
	var anchor: Vector2 = Vector2(frame["ax"], frame["ay"])
	draw_set_transform(Vector2(effect["at"]) + shake_offset, float(effect["rotation"]))
	var rect: Rect2 = Rect2(-anchor, Vector2(frame["w"], frame["h"]))
	var region: Rect2 = Rect2(frame["x"], frame["y"], frame["w"], frame["h"])
	draw_texture_rect_region(sprites, rect, region)
	draw_set_transform(shake_offset)
	CombatEffects.draw_plan(self, SkillEffects.accents(fx_hero(), colors))

## Strong contact accents are driven by confirmed attack_hit events only.
func _draw_skill_contacts() -> void:
	for burst: Dictionary in hit_bursts:
		if burst.get("skill_id", &"") != &"breaking_edge":
			continue
		var age: int = fx_tick() + fx_result_ticks() - int(burst["tick"])
		if age < 0 or age >= 10:
			continue
		var at: Vector2 = burst["contact"]
		var radius: float = 17.0 - age
		var commands: Array[Dictionary] = []
		for angle: float in [-0.75, 0.75]:
			var axis: Vector2 = Vector2(burst["facing"]).rotated(angle) * radius
			var cut: PackedVector2Array = PackedVector2Array([at - axis, at + axis])
			CombatEffects.stroke(commands, cut, colors["0"], 5.0)
			CombatEffects.stroke(commands, cut, colors["1"] if age < 3 else colors["x"], 2.0)
		CombatEffects.draw_plan(self, commands)

func skill_projectile_effects() -> Array[Dictionary]:
	return SkillEffects.projectiles(fx_snapshot())

## Resize once into integer-pixel textures; width is supplied by the core snapshot.
## Keep each frame's declared anchor when trimming its transparent padding.
func _projectile_texture(key: String, diameter: int) -> Dictionary:
	var cache_key: String = "%s:%d" % [key, diameter]
	if projectile_textures.has(cache_key):
		return projectile_textures[cache_key]
	if not frames.has(key):
		push_warning("Missing projectile effect: " + key)
		return {}
	var frame: Dictionary = frames[key]
	var image: Image = sprites.get_image().get_region(Rect2i(frame["x"], frame["y"], frame["w"], frame["h"]))
	var used: Rect2i = image.get_used_rect()
	if not used.has_area():
		return {}
	image = image.get_region(used)
	var ratio: float = float(diameter) / maxi(used.size.x, used.size.y)
	var size: Vector2i = Vector2i(maxi(1, roundi(used.size.x * ratio)), maxi(1, roundi(used.size.y * ratio)))
	image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var anchor: Vector2 = Vector2(roundf((float(frame["ax"]) - used.position.x) * float(size.x) / used.size.x), roundf((float(frame["ay"]) - used.position.y) * float(size.y) / used.size.y))
	var entry: Dictionary = {"texture": ImageTexture.create_from_image(image), "anchor": anchor, "diameter": diameter}
	projectile_textures[cache_key] = entry
	return entry

func _draw_skill_projectiles(shake_offset: Vector2) -> void:
	for effect: Dictionary in skill_projectile_effects():
		var entry: Dictionary = _projectile_texture(effect["key"], maxi(1, roundi(float(effect["width"]))))
		if entry.is_empty():
			continue
		draw_set_transform(Vector2(effect["at"]).round() + shake_offset, float(effect["rotation"]))
		# Large cosmetic aura; collision width remains entirely core-owned.
		var diameter: int = maxi(1, roundi(float(effect["visual_width"])))
		var wake: Dictionary = _projectile_texture(effect["key"], diameter)
		var length: float = float(effect["trail_length"])
		var age: int = int(effect["age"])
		# Detached smaller crescents follow only the distance already travelled.
		for echo: int in range(2, 0, -1):
			var offset: float = float(echo * 14)
			if length < offset:
				continue
			var remnant: Dictionary = _projectile_texture("fx_aspect2_moon_cleave_5", diameter - echo * 12)
			if not remnant.is_empty():
				draw_texture(remnant["texture"], Vector2(-offset, 0) - Vector2(remnant["anchor"]))
		if length > 3.0:
			for lane: int in [-1, 0, 1]:
				var y: float = float(lane * 10)
				draw_line(Vector2(-length, y), Vector2(-5, y * 0.4), colors["l"], 5.0, false)
				draw_line(Vector2(-length + 3, y), Vector2(-5, y * 0.4), colors["o"], 2.0, false)
		if not wake.is_empty():
			draw_texture(wake["texture"], -Vector2(wake["anchor"]))
		# Crisp orbiting fragments, deterministic from the attack's age.
		for fragment: int in range(8):
			var phase: int = posmod(age + fragment * 5, 18)
			var side: float = -1.0 if fragment % 2 == 0 else 1.0
			var at: Vector2 = Vector2(-float(phase * 2), side * (18.0 + float(posmod(fragment * 7 + age, 16))))
			draw_line(at.round(), (at + Vector2(4, -side * 2)).round(), colors["p"] if phase < 9 else colors["v"], 2.0, false)
		# A short release star belongs to the projectile, so it survives interruption.
		if age < 5:
			var radius: float = float(18 - age * 2)
			for ray: int in range(4):
				var axis: Vector2 = Vector2.from_angle(PI * 0.25 + ray * PI * 0.5)
				draw_line((axis * 4).round(), (axis * radius).round(), colors["1"], 2.0, false)
		draw_texture(entry["texture"], -Vector2(entry["anchor"]))
		draw_set_transform(shake_offset)

## The light pools on the floor under every character: open with the lantern, then loop; the closing pool of a fading
## lantern; the pulse rings (event effects, so the last pulse still shows when the lantern expires on its tick).
func _draw_lantern_ground() -> void:
	var tick: int = fx_tick()
	for lantern: Snapshots.LanternSnapshot in fx_snapshot().lanterns:
		var key: String = AspectEffects.pool_key(tick - lantern.placed_tick)
		if key != "":
			_draw_scaled(key, lantern.position.round(), AspectEffects.pool_scale(lantern.radius))
	var cosmetic_tick: int = fx_tick() + fx_result_ticks()
	for effect: Dictionary in aspect_fx:
		var age: int = cosmetic_tick - int(effect["tick"])
		match String(effect["kind"]):
			"fade":
				var close: String = AspectEffects.pool_close_key(age)
				if close != "":
					_draw_scaled(close, effect["at"], float(effect["scale"]))
			"pool_pulse":
				var frame: int = AspectEffects.sequence_frame(AspectEffects.POOL_PULSE_TICKS, age)
				if frame > 0:
					_draw_scaled("fx_lantern_pool_pulse_%d" % frame, effect["at"], float(effect["scale"]))

## The lantern props (and fading ones) as y-sorted drawables: {"name", "at", "scale"} like the solid props.
func lantern_drawables() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for lantern: Snapshots.LanternSnapshot in fx_snapshot().lanterns:
		var key: String = AspectEffects.lantern_key(fx_tick() - lantern.placed_tick, AspectEffects.since_pulse(lantern, fx_tick()))
		if frames.has(key):
			items.append({"name": key, "at": lantern.position.round() + LANTERN_SORT_BIAS, "scale": Vector2.ONE})
	var cosmetic_tick: int = fx_tick() + fx_result_ticks()
	for effect: Dictionary in aspect_fx:
		if effect["kind"] == "fade":
			var frame: int = AspectEffects.sequence_frame(AspectEffects.FADE_TICKS, cosmetic_tick - int(effect["tick"]))
			if frame > 0:
				items.append({"name": "fx_lantern_fade_%d" % frame, "at": Vector2(effect["at"]) + LANTERN_SORT_BIAS, "scale": Vector2.ONE})
	return items

## The Phantom Cut buff glow over the hero frame being drawn (manifest naming rule), same position and mirroring, by
## its own anchor; nothing when that frame has no overlay (victory, coil poses, the Lightning set).
func phantom_glow_key(actor: Snapshots.EntitySnapshot, hero_frame: String) -> String:
	if actor.phantom_ticks_left <= 0 or not fx_playing():
		return ""
	var key: String = AspectEffects.glow_key(ArenaAnimation.overlay_frame(hero_frame), AspectEffects.since_start(actor.phantom_ticks_left))
	return key if frames.has(key) else ""

func _draw_phantom_glow(actor: Snapshots.EntitySnapshot, hero_frame: String, at: Vector2, left: bool) -> void:
	var key: String = phantom_glow_key(actor, hero_frame)
	if key == "":
		return
	var f: Dictionary = frames[key]
	draw_texture_rect_region(sprites, ArenaAnimation.destination(at, f, left), Rect2(f["x"], f["y"], f["w"], f["h"]))

## Top of the visible pixels of a frame, relative to its anchor's feet row (negative = above the feet).
func frame_top(key: String) -> float:
	if not frames.has(key):
		return -30.0
	if not frame_tops.has(key):
		var f: Dictionary = frames[key]
		var used: Rect2i = sprites.get_image().get_region(Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"]))).get_used_rect()
		frame_tops[key] = float(used.position.y) - float(f.get("ay", f["h"]))
	return float(frame_tops[key])

## Where the echo-pending marker stands (its anchor is its bottom centre): over the head of the idle pose of the set,
## so it does not bob with every swing frame.
func phantom_marker_position() -> Vector2:
	var hero: Snapshots.EntitySnapshot = fx_hero()
	var top: float = frame_top(ArenaAnimation.hero_frame(ArenaAnimation.hero_set(hero), "idle", 1))
	return hero.position.round() + Vector2(0, top - AspectEffects.MARKER_GAP)

## Over everything standing: the Phantom start/end bursts and marker on the hero, the echo ghosts with their arcs, the
## landing sparks on the boss, the lantern's heal motes and Edge sparks on the hero.
func _draw_aspects_front() -> void:
	if not fx_playing() and aspect_fx.is_empty():
		return
	var hero: Snapshots.EntitySnapshot = fx_hero()
	var feet: Vector2 = hero.position.round()
	var cosmetic_tick: int = fx_tick() + fx_result_ticks()
	for effect: Dictionary in aspect_fx:
		var age: int = cosmetic_tick - int(effect["tick"])
		match String(effect["kind"]):
			"echo":
				var ghost: int = AspectEffects.sequence_frame(AspectEffects.GHOST_TICKS, age)
				if ghost > 0:
					_draw_anchored(AspectEffects.ghost_key(effect["weapon"], int(effect["swing"]), ghost), effect["at"], bool(effect["left"]))
				var arc: int = AspectEffects.sequence_frame(AspectEffects.ARC_TICKS, age)
				if arc > 0:
					_draw_anchored(AspectEffects.arc_key(effect["weapon"], int(effect["swing"]), arc), effect["at"], bool(effect["left"]))
			"echo_spark":
				var frame: int = AspectEffects.sequence_frame(AspectEffects.ECHO_SPARK_TICKS, age)
				if frame > 0:
					_draw_imported("fx_phantom_spark_%d" % frame, effect["at"])
			"phantom_start":
				var frame: int = AspectEffects.sequence_frame(AspectEffects.START_TICKS, age)
				if frame > 0:
					_draw_anchored("fx_phantom_start_%d" % frame, feet, facing_left)
			"phantom_end":
				var frame: int = AspectEffects.sequence_frame(AspectEffects.END_TICKS, age)
				if frame > 0:
					_draw_anchored("fx_phantom_end_%d" % frame, feet, facing_left)
			"motes":
				var frame: int = AspectEffects.sequence_frame(AspectEffects.MOTES_TICKS, age)
				if frame > 0:
					_draw_anchored("fx_lantern_motes_%d" % frame, feet, facing_left)
			"spark":
				var frame: int = AspectEffects.sequence_frame(AspectEffects.SPARK_TICKS, age)
				if frame > 0:
					var chest: Vector2 = AspectEffects.CHEST
					if facing_left:
						chest.x = -chest.x
					_draw_imported("fx_lantern_spark_%d" % frame, feet + chest)
	if hero.phantom_pending_echoes > 0 and fx_playing():
		_draw_imported(AspectEffects.marker_key(fx_tick()), phantom_marker_position())

## The echo anchors as y-sorted drawables ({"name", "at", "scale"} like the lantern): the anchor loop, the countdown
## for the last ticks; nothing during the placement burst.
func echo_drawables() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for echo: Snapshots.EchoSnapshot in fx_snapshot().echoes:
		var key: String = WardEchoSprintEffects.anchor_key(fx_tick() - echo.placed_tick, echo.ticks_left)
		if key != "" and frames.has(key):
			items.append({"name": key, "at": echo.position.round() + LANTERN_SORT_BIAS, "scale": Vector2.ONE})
	return items

## Spirit Lantern and Phantom Cut, from the core's events (the lantern, its pool and the Phantom glow draw from the
## snapshot every frame). Sounds reuse the combat cues (no new audio).
func _on_aspect_event(event: GameEvent) -> void:
	var tick: int = event.tick
	match event.type:
		&"lantern_placed":
			_dust(Vector2(event.data["position"]))
			fx_cue("deflect", tick, 0.45)
		&"lantern_pulse":
			var at: Vector2 = event.data["position"]
			var scale_px: float = AspectEffects.pool_scale(float(event.data.get("radius", Tuning.SPIRIT_LANTERN_RADIUS)))
			AspectEffects.add(aspect_fx, {"kind": "pool_pulse", "tick": tick, "at": at.round(), "scale": scale_px, "life": AspectEffects.sequence_length(AspectEffects.POOL_PULSE_TICKS)})
			if bool(event.data.get("player_inside", false)):
				AspectEffects.add(aspect_fx, {"kind": "motes", "tick": tick, "life": AspectEffects.sequence_length(AspectEffects.MOTES_TICKS)})
				AspectEffects.add(aspect_fx, {"kind": "spark", "tick": tick + AspectEffects.SPARK_DELAY, "start": tick, "life": AspectEffects.SPARK_DELAY + AspectEffects.sequence_length(AspectEffects.SPARK_TICKS)})
				fx_cue("weapon_buff_end", tick, 0.35)
		&"lantern_expired":
			var at: Vector2 = event.data["position"]
			AspectEffects.add(aspect_fx, {"kind": "fade", "tick": tick, "at": at.round(), "scale": AspectEffects.pool_scale(Tuning.SPIRIT_LANTERN_RADIUS), "life": AspectEffects.sequence_length(AspectEffects.FADE_TICKS)})
		&"phantom_cut_started":
			AspectEffects.add(aspect_fx, {"kind": "phantom_start", "tick": tick, "life": AspectEffects.sequence_length(AspectEffects.START_TICKS)})
			fx_cue("phantom_cut", tick, 0.55)
		&"phantom_cut_ended":
			AspectEffects.add(aspect_fx, {"kind": "phantom_end", "tick": tick, "life": AspectEffects.sequence_length(AspectEffects.END_TICKS)})
			fx_cue("weapon_buff_end", tick, 0.45)
		&"phantom_echo":
			var hero: Snapshots.EntitySnapshot = fx_hero()
			var weapon: String = AspectEffects.weapon_key(StringName(event.data.get("weapon_id", hero.weapon_id)))
			var swing: int = int(event.data.get("swing_combo_index", 1))
			var ghost_at: Vector2 = (hero.position + Vector2(-AspectEffects.GHOST_OFFSET if facing_left else AspectEffects.GHOST_OFFSET, 0)).round()
			AspectEffects.add(aspect_fx, {"kind": "echo", "tick": tick, "at": ghost_at, "left": facing_left, "weapon": weapon, "swing": swing, "life": AspectEffects.echo_life()})
			var contact: Vector2 = fx_target_contact(int(event.data.get("target_id", -1)), Vector2(event.data.get("position", hero.position)))
			AspectEffects.add(aspect_fx, {"kind": "echo_spark", "tick": tick + AspectEffects.ECHO_SPARK_DELAY, "at": contact.round(), "life": AspectEffects.ECHO_SPARK_DELAY + AspectEffects.sequence_length(AspectEffects.ECHO_SPARK_TICKS)})
			fx_cue("swing", tick, 0.45)


# --- the weapon buff (Black Form, Lightning Form; moved here from the arena) ---

func weapon_buff_effect() -> Dictionary:
	return WeaponBuffView.plan_for(fx_hero(), fx_tick(), Weapons.active_duration(fx_hero().weapon_id), fx_playing())

## Binary pixel coverage instead of translucent aura edges.
func _buff_texture(key: String, level: int) -> Texture2D:
	var cache_key: String = "%s:%d" % [key, level]
	if buff_textures.has(cache_key):
		return buff_textures[cache_key]
	if not frames.has(key) or level <= 0:
		return null
	var f: Dictionary = frames[key]
	var image: Image = sprites.get_image().get_region(Rect2i(f["x"], f["y"], f["w"], f["h"]))
	image.convert(Image.FORMAT_RGBA8)
	if level < 4:
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				if posmod(x + y * 2, 4) >= level:
					image.set_pixel(x, y, Color.TRANSPARENT)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	buff_textures[cache_key] = texture
	return texture

func _draw_buff_frame(key: String, at: Vector2, level: int, left: bool) -> void:
	var texture: Texture2D = _buff_texture(key, level)
	if texture == null:
		return
	var f: Dictionary = frames[key]
	draw_texture_rect_region(texture, ArenaAnimation.destination(at, f, left), Rect2(0, 0, f["w"], f["h"]))

func _draw_buff_aura(actor: Snapshots.EntitySnapshot, front: bool) -> void:
	var effect: Dictionary = weapon_buff_effect()
	if effect.is_empty():
		return
	_draw_buff_frame(effect["front" if front else "back"], actor.position, int(effect["level"]), facing_left)

## Match the painted side-view blade rather than rotating independently toward aim.
func weapon_slash_effect() -> Dictionary:
	var effect: Dictionary = weapon_buff_effect()
	if effect.is_empty() or String(effect["slash"]).is_empty():
		return {}
	var chosen: String = fx_hero_frame()
	if not chosen.begins_with("hero2_attack") and not (fx_hero().state == &"skill_active" and chosen.begins_with("hero2_dash")):
		return {}
	return {"key": effect["slash"], "at": (fx_hero().position + Vector2(-15 if facing_left else 15, -12)).round(), "left": facing_left, "level": effect["level"]}

func _draw_buff_slash(_shake_offset: Vector2) -> void:
	var effect: Dictionary = weapon_slash_effect()
	if effect.is_empty():
		return
	# Draw directly in world coordinates, sharing the actor's current canvas transform.
	_draw_buff_frame(effect["key"], effect["at"], int(effect["level"]), bool(effect["left"]))

func _draw_buff_transition() -> void:
	if buff_transition.is_empty():
		return
	var age: int = fx_tick() + fx_result_ticks() - int(buff_transition["tick"])
	if age < 0 or age >= 12:
		return
	var level: int = maxi(1, 4 - age / 3)
	var at: Vector2 = fx_hero().position if bool(buff_transition["started"]) else Vector2(buff_transition["at"])
	if buff_transition.get("form", &"") == Weapons.FORM_LIGHTNING:
		_draw_buff_frame("fx_lightning_aura_back_%d" % (mini(9, age) + 1), at, level, facing_left)
		return
	if buff_transition.get("form", &"") == Weapons.FORM_REAPER_COIL:
		return  # no aura: the coil's chain and ring are its look
	_draw_buff_frame("fx_black_aura_back_%d" % (mini(5, age / 2) + 1), at, level, facing_left)

## The darkened Black Form hero and its black dash ghosts: only the katana's buff, never the dagger or the scythe.
func black_form_look(actor: Snapshots.EntitySnapshot) -> bool:
	return actor.weapon_buff_active and actor.weapon_id == Tuning.WEAPON_BLACK_KATANA and actor.weapon_form not in [Weapons.FORM_LIGHTNING, Weapons.FORM_REAPER_COIL]
