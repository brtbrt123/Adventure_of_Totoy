extends Node2D
## Owns the simulation; only snapshot data crosses into drawing.
const GameCore := preload("res://core/game_core.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const CombatEffects := preload("res://presentation/arena/combat_effects.gd")
const HeadAnchors := preload("res://presentation/arena/head_anchors.gd")
const Hud := preload("res://presentation/arena/hud.gd")

var core: GameCore = GameCore.new(17)
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var frames: Dictionary = {}
var head_anchors: Dictionary = {}
var floor_regions: Array[Rect2] = []
var missing_frames: Dictionary = {}
var selected_frames: Dictionary = {}
var last_attacks: Dictionary = {}
var previous_telegraphs: Array[Snapshots.TelegraphSnapshot] = []
var red_history: Dictionary = {}
var red_plan: Array[Dictionary] = []
var slash_plan: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var parry_impacts: Array[Dictionary] = []
var screen_flash_until: int = -1
var visual_tick: int = -1
var particles: Array[Dictionary] = []
var hit_bursts: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var flashes: Dictionary = {}
var debug_enabled: bool = false
var shake_left: int = 0
var white_sprites: Texture2D
var hurt_blink: bool = false
var facing_left: bool = false
var previous_player_position: Vector2 = Vector2.ZERO
var previous_player_state: StringName = &""
var dash_ghosts: Array[Dictionary] = []
var sprites: Texture2D
var reactions: Dictionary = {}
var tiles: Texture2D
@onready var hud: Hud = $HUD/Display

func _ready() -> void:
	Bindings.register()
	var palette: Dictionary = _read_json("res://art/palette.json")
	for entry: Dictionary in palette.get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	frames = _read_json("res://art/build/sprites.json").get("frames", {})
	sprites = load("res://art/build/sprites.png") as Texture2D
	var white_image: Image = sprites.get_image()
	white_image.convert(Image.FORMAT_RGBA8)
	for name_key: String in frames:
		if (name_key.begins_with("mossbound_colossus_") or name_key.begins_with("golem2_")):
			head_anchors[name_key] = HeadAnchors.measure(white_image, frames[name_key])
	for y: int in range(white_image.get_height()):
		for x: int in range(white_image.get_width()):
			var alpha: float = white_image.get_pixel(x, y).a
			white_image.set_pixel(x, y, Color(1, 1, 1, alpha))
	white_sprites = ImageTexture.create_from_image(white_image)
	tiles = load("res://art/build/tiles.png") as Texture2D
	var tile_entries: Dictionary = _read_json("res://art/build/tiles.json").get("tiles", {})
	var grass: Array[String] = []
	for key: String in tile_entries:
		if key.begins_with("grass"):
			grass.append(key)
	grass.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1908
	for y: int in range(11):
		for x: int in range(20):
			var name_key: String = grass[rng.randi_range(0, grass.size() - 1)]
			var tile: Dictionary = tile_entries[name_key]
			floor_regions.append(Rect2(tile["x"], tile["y"], 16, 16))
	snapshot = core.snapshot()
	prepare_visuals()
	_update_hud()

func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Arena cannot open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("arena_debug"):
		debug_enabled = not debug_enabled
	if snapshot.result != &"playing" and Input.is_action_just_pressed("arena_restart"):
		_restart()
	# Node-local mouse coordinates already account for viewport scaling and canvas transforms.
	var intent: InputFrame = Bindings.read_frame(snapshot.player.position, get_local_mouse_position())
	core.step(intent)
	snapshot = core.snapshot()
	_age_effects()
	prepare_visuals()
	for event: GameEvent in core.last_events:
		_on_event(event)
	_update_hud()
	queue_redraw()

func _restart() -> void:
	core = GameCore.new(17)
	snapshot = core.snapshot()
	facing_left = false
	previous_player_state = &""
	dash_ghosts.clear()
	selected_frames.clear()
	last_attacks.clear()
	previous_telegraphs.clear()
	rings.clear()
	parry_impacts.clear()
	screen_flash_until = -1
	red_history.clear()
	red_plan.clear()
	slash_plan.clear()
	visual_tick = -1
	prepare_visuals()
	particles.clear()
	hit_bursts.clear()
	trails.clear()
	flashes.clear()
	reactions.clear()
	hurt_blink = false
	shake_left = 0
	hud.counter_max = 1
	hud.reset_head()

func _update_hud() -> void:
	hud.portrait_atlas = sprites
	hud.ui_frames = frames
	hud.portrait_frame = frames.get("totoy_portrait", {})
	hud.profile_frame = frames.get("ui_profile", {})
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if actor.visual_id == &"mossbound_colossus":
			var chosen: String = String(selected_frames.get(actor.id, ""))
			if frames.has(chosen) and head_anchors.has(chosen):
				var mirrored: bool = ArenaAnimation.boss_mirrored(actor, snapshot, last_attacks.get(actor.id, {}))
				hud.track_head(HeadAnchors.world(actor.position, frames[chosen], head_anchors[chosen], mirrored), snapshot.tick, actor.id, actor.position.round())
	hud.snapshot = snapshot
	hud.colors = colors
	hud.debug_enabled = debug_enabled
	hud.prepare_portrait()
	hud.track_health()
	hud.queue_redraw()

func _age_effects() -> void:
	if not snapshot.player.invulnerable:
		hurt_blink = false
	shake_left = maxi(0, shake_left - 1)
	for i: int in range(hit_bursts.size() - 1, -1, -1):
		if snapshot.tick - int(hit_bursts[i]["tick"]) >= 12:
			hit_bursts.remove_at(i)
	for id: int in flashes.keys():
		flashes[id] = int(flashes[id]) - 1
		if int(flashes[id]) <= 0:
			flashes.erase(id)
	for index: int in range(particles.size() - 1, -1, -1):
		particles[index]["life"] -= 1
		particles[index]["position"] += particles[index]["velocity"]
		if particles[index]["life"] <= 0:
			particles.remove_at(index)
	for index: int in range(trails.size() - 1, -1, -1):
		trails[index]["life"] -= 1
		if trails[index]["life"] <= 0:
			trails.remove_at(index)

func _on_event(event: GameEvent) -> void:
	match event.type:
		&"damage_taken":
			reactions[int(event.data["entity_id"])] = {"pose": "hurt", "tick": snapshot.tick, "duration": 12}
			flashes[int(event.data["entity_id"])] = maxi(6, int(flashes.get(int(event.data["entity_id"]), 0)))
			if int(event.data["entity_id"]) == snapshot.player.id:
				hurt_blink = true
			_sound_damage_taken(event)
		&"parry_succeeded":
			var perfect: bool = event.data["quality"] == &"perfect"
			_burst(event.data["position"], 16 if perfect else 7, colors["x"], 1.6 if perfect else 1.0)
			parry_impacts.append({"position": event.data["position"], "tick": event.tick, "perfect": perfect})
			selected_frames[snapshot.player.id] = _resolve_frame("hero2_parry_right_6", snapshot.player)
			shake_left = maxi(shake_left, 7 if perfect else 3)
			screen_flash_until = event.tick + (2 if perfect else 1)
			for actor: Snapshots.EntitySnapshot in snapshot.entities:
				if actor.id == int(event.data["attacker_id"]):
					_burst(actor.position - Vector2(0, 8), 9 if perfect else 4, colors["j"], 0.65 if perfect else 0.35)
			_sound_parry_succeeded(event)
		&"posture_broken":
			flashes[int(event.data["entity_id"])] = 5
			shake_left = maxi(shake_left, 6)
			_sound_posture_broken(event)
		&"counter_window_opened":
			hud.counter_max = maxi(1, int(event.data["window_ticks"]))
			_sound_counter_window_opened(event)
		&"counter_window_closed": _sound_counter_window_closed(event)
		&"dash_started":
			_sound_dash_started(event)
		&"attack_hit":
			var counter: bool = event.data["kind"] == &"counter"
			if int(event.data["attacker_id"]) == snapshot.player.id:
				hit_bursts.append({"position": event.data["position"], "tick": event.tick, "counter": counter})
				_burst(event.data["position"], 16 if counter else 8, colors["1"], 1.8 if counter else 0.9)
				if counter:
					flashes[int(event.data["target_id"])] = 10
					shake_left = maxi(shake_left, 5)
			_sound_attack_hit(event)
		&"attack_telegraphed": _sound_attack_telegraphed(event)
		&"parry_failed":
			if event.data["reason"] == &"whiff":
				_burst(snapshot.player.position - Vector2(0, 8), 4, colors["f"], 0.3)
			_sound_parry_failed(event)
		&"dash_ready": _sound_dash_ready(event)
		&"entity_died": _sound_entity_died(event)
		&"boss_phase_changed":
			reactions[int(event.data["entity_id"])] = {"pose": "roar", "tick": snapshot.tick, "duration": 30}
			_sound_boss_phase_changed(event)
		&"game_result": _sound_game_result(event)

func _burst(at: Vector2, count: int, color: Color, speed: float) -> void:
	for i: int in range(count):
		particles.append({"position": at, "velocity": Vector2.from_angle(TAU * i / count) * speed, "life": 7 if i % 3 == 0 else 11, "color": colors["p"] if color == colors["1"] and i % 3 == 0 else (colors["o"] if color == colors["1"] and i % 3 == 1 else color)})

func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	# A uniform transform shakes floor, actors and tells together, preserving alignment.
	var offset: Vector2 = Vector2.ZERO
	if shake_left > 0:
		offset = Vector2(1 if shake_left % 2 == 0 else -1, 1 if shake_left % 3 == 0 else -1)
	draw_set_transform(offset)
	draw_rect(Rect2(-2, -2, 324, 184), colors["2"])
	for index: int in range(floor_regions.size()):
		draw_texture_rect_region(tiles, Rect2((index % 20) * 16, floori(index / 20.0) * 16, 16, 16), floor_regions[index], Color(0.72, 0.72, 0.72))
	for decoration: Dictionary in [{"name": "prop_nature_1", "at": Vector2(18, 85)}, {"name": "prop_nature_4", "at": Vector2(300, 160)}, {"name": "prop_ruins_2", "at": Vector2(292, 53)}, {"name": "prop_small_3", "at": Vector2(35, 170)}]:
		_draw_imported(decoration["name"], decoration["at"])
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		TelegraphView.draw_warning(self, t, snapshot.tick, colors["x"] if t.kind == &"gold" else colors["z"], colors["y"] if t.kind == &"gold" else colors["A"], colors["0"])
	for ring: Dictionary in rings:
		if ring.has("tell") and snapshot.tick > ring["tell"].end_tick:
			_draw_impact(ring["tell"])
		_draw_imported("fx_dust_%d" % (clampi((snapshot.tick - int(ring["start_tick"])) / 2, 0, 5) + 1), ring["position"])
	for trail: Dictionary in trails:
		_draw_imported("fx_dust_%d" % (6 - int(trail["life"])), trail["position"])
	_draw_dash()
	var actors: Array[Snapshots.EntitySnapshot] = [snapshot.player]
	actors.append_array(snapshot.entities)
	actors.sort_custom(_behind)
	for actor: Snapshots.EntitySnapshot in actors:
		_draw_actor(actor)
	for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if snapshot.tick >= tell.hit_tick and snapshot.tick <= tell.end_tick:
			_draw_impact(tell)
	for id: int in red_history:
		var tell: Snapshots.TelegraphSnapshot = red_history[id]
		if snapshot.tick > tell.end_tick:
			_draw_impact(tell)
	for impact: Dictionary in parry_impacts:
		_draw_imported("fx_parry_%d" % (mini(5, (snapshot.tick - int(impact["tick"])) / 2) + 1), impact["position"])
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		_draw_imported("ui_warning_%s_%d" % ["gold" if t.kind == &"gold" else "red", 1 + (snapshot.tick / 12) % 2], TelegraphView.marker_position(t), Vector2(0.5, 0.5))
	for burst: Dictionary in hit_bursts:
		_draw_imported("fx_%s_%d" % ["counter" if bool(burst["counter"]) else "hit", mini(5, (snapshot.tick - int(burst["tick"])) / 2) + 1], burst["position"])
	for particle: Dictionary in particles:
		var at: Vector2 = particle["position"]
		draw_rect(Rect2(at.round(), Vector2.ONE), particle["color"])
	# Damage silhouettes sit over translucent combat light so white stays pure white.
	for actor: Snapshots.EntitySnapshot in actors:
		if actor_is_white(actor):
			_draw_actor(actor, true)
	if debug_enabled:
		draw_circle(snapshot.player.position, Tuning.PLAYER_RADIUS, colors["p"], false, 1.0)
		for actor: Snapshots.EntitySnapshot in snapshot.entities:
			draw_circle(actor.position, Tuning.BOSS_RADIUS, colors["p"], false, 1.0)
	draw_set_transform(Vector2.ZERO)
	if snapshot.tick < screen_flash_until:
		draw_rect(Rect2(0, 0, 320, 180), Color(colors["1"], 0.10))

func _behind(a: Snapshots.EntitySnapshot, b: Snapshots.EntitySnapshot) -> bool:
	return a.position.y < b.position.y

func _direction(facing: Vector2) -> String:
	return ArenaAnimation.direction(facing)

## Called every snapshot even headless: missing-frame coverage does not depend
## on a rendering backend calling _draw(). Also callable by scripted tests.
func prepare_visuals() -> void:
	if snapshot == null:
		return
	# Retain only strikes actually observed; cancelled warnings leave no afterglow.
	for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if tell.attack in [&"red_shards", &"red_sweep", &"red_stomp"] and snapshot.tick >= tell.hit_tick and snapshot.tick <= tell.end_tick:
			red_history[tell.id] = tell
	red_plan.clear()
	for id: int in red_history.keys():
		var tell: Snapshots.TelegraphSnapshot = red_history[id]
		if snapshot.tick > tell.end_tick + CombatEffects.AFTERGLOW_TICKS:
			red_history.erase(id)
		else:
			red_plan.append_array(CombatEffects.red(tell, snapshot.tick, colors))
	slash_plan = CombatEffects.slash(snapshot.player, colors)
	var fresh: bool = snapshot.tick != visual_tick
	if fresh:
		var hero: Snapshots.EntitySnapshot = snapshot.player
		var moved: bool = not hero.position.is_equal_approx(previous_player_position)
		var attack_started: bool = hero.state == &"attack_windup" and previous_player_state != hero.state
		if ((moved and hero.state != &"dead") or attack_started) and absf(hero.facing.x) > 0.3:
			facing_left = hero.facing.x < 0.0
		for i: int in range(dash_ghosts.size() - 1, -1, -1):
			dash_ghosts[i]["life"] -= 1
			if int(dash_ghosts[i]["life"]) <= 0:
				dash_ghosts.remove_at(i)
		if hero.state == &"dash" and previous_player_state == &"dash":
			dash_ghosts.append({"position": previous_player_position, "left": facing_left, "life": 6})
			if dash_ghosts.size() > 3:
				dash_ghosts.pop_front()
		previous_player_position = hero.position
		previous_player_state = hero.state
	if fresh:
		for i: int in range(parry_impacts.size() - 1, -1, -1):
			if snapshot.tick - int(parry_impacts[i]["tick"]) >= 12:
				parry_impacts.remove_at(i)
		# Include the preceding snapshot for a parry that clears the tell exactly
		# at impact. An earlier cancellation disappears before this crossing.
		var impact_candidates: Array[Snapshots.TelegraphSnapshot] = []
		impact_candidates.append_array(previous_telegraphs)
		impact_candidates.append_array(snapshot.telegraphs)
		var impacts: Dictionary = {}
		for tell: Snapshots.TelegraphSnapshot in impact_candidates:
			if tell.attack in [&"gold_slam", &"gold_combo", &"red_stomp"] and visual_tick < tell.hit_tick and snapshot.tick >= tell.hit_tick and snapshot.tick <= tell.end_tick:
				if not impacts.has(tell.id):
					impacts[tell.id] = true
					if tell.attack != &"red_stomp":
						rings.append({"position": tell.center, "start_tick": tell.hit_tick, "tell": tell})
					_burst(tell.center, 18, colors["j"], 1.4)
					shake_left = maxi(shake_left, 4)
		for i: int in range(rings.size() - 1, -1, -1):
			if snapshot.tick - int(rings[i]["start_tick"]) >= 12:
				rings.remove_at(i)
		var player: Snapshots.EntitySnapshot = snapshot.player
		if player.state == &"dash" and player.state_ticks == 0:
			_dust(player.position)
		if player.state == &"walk":
			var cadence: int = int(ArenaAnimation.PLAYER["walk"][1])
			if player.state_ticks % (cadence * 2) == 0:
				_dust(player.position)
		for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
			if tell.attack == &"red_charge" and snapshot.tick >= tell.hit_tick and snapshot.tick <= tell.end_tick:
				for actor: Snapshots.EntitySnapshot in snapshot.entities:
					if actor.id == tell.owner_id:
						var behind: Vector2 = actor.position - tell.direction * 14.0
						_dust(behind)
						trails.append({"position": behind, "life": 5, "charge": true})
		previous_telegraphs.clear()
		previous_telegraphs.append_array(snapshot.telegraphs)
		visual_tick = snapshot.tick
	var actors: Array[Snapshots.EntitySnapshot] = [snapshot.player]
	actors.append_array(snapshot.entities)
	for actor: Snapshots.EntitySnapshot in actors:
		if actor.state != &"attack" and actor.state != &"recover":
			last_attacks.erase(actor.id)
		for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
			if tell.owner_id == actor.id:
				if not last_attacks.has(actor.id) or tell.hit_tick >= int(last_attacks[actor.id].get("hit_tick", -1)):
					last_attacks[actor.id] = {"attack": tell.attack, "hit_tick": tell.hit_tick, "end_tick": tell.end_tick, "direction_x": tell.direction.x}
		var requested: String = ArenaAnimation.choose(actor, snapshot, last_attacks.get(actor.id, {}))
		# A successful parry returns to idle immediately in core. Show the painted
		# spark pose briefly from the recorded event while its impact ring begins.
		if actor.id == snapshot.player.id and actor.state == &"idle":
			for impact: Dictionary in parry_impacts:
				if snapshot.tick - int(impact["tick"]) < 3:
					requested = "hero2_parry_right_6"
		var impact_pose: bool = false
		if actor.visual_id == &"mossbound_colossus":
			var active_tell: Snapshots.TelegraphSnapshot = ArenaAnimation.attack_tell(actor.id, snapshot)
			impact_pose = active_tell != null and snapshot.tick >= active_tell.hit_tick and snapshot.tick <= active_tell.end_tick
		if reactions.has(actor.id) and snapshot.result == &"playing" and actor.state not in [&"dead", &"posture_broken", &"dash"] and not impact_pose:
			var reaction: Dictionary = reactions[actor.id]
			var age: int = snapshot.tick - int(reaction["tick"])
			if age < int(reaction["duration"]):
				var pose: String = reaction["pose"]
				var spec: Array = ArenaAnimation.PLAYER[pose] if actor.id == snapshot.player.id else ArenaAnimation.BOSS[pose]
				requested = ("hero2_%s_right_%d" if actor.id == snapshot.player.id else "golem2_%s_%d") % [pose, ArenaAnimation.frame_index(spec, age)]
		selected_frames[actor.id] = _resolve_frame(requested, actor)

func _resolve_frame(requested: String, actor: Snapshots.EntitySnapshot) -> String:
	if frames.has(requested):
		return requested
	if not missing_frames.has(requested):
		push_warning("Missing arena frame: " + requested + "; using idle fallback")
		missing_frames[requested] = true
	var fallback: String = "hero2_idle_right_1" if actor.visual_id == &"totoy" else "golem2_idle_1"
	if frames.has(fallback):
		return fallback
	return "totoy_idle_down" if actor.visual_id == &"totoy" else "mossbound_colossus_idle"

func _dust(at: Vector2) -> void:
	for i: int in range(5):
		particles.append({"position": at + Vector2(i - 2, 2), "velocity": Vector2((i - 2) * 0.18, -0.22), "life": 6, "color": colors["c"] if i % 2 == 0 else colors["d"]})

func _draw_actor(actor: Snapshots.EntitySnapshot, silhouette_only: bool = false) -> void:
	var chosen: String = String(selected_frames.get(actor.id, ""))
	var at: Vector2 = actor.position.round()
	var radius: float = 10.0 if actor.visual_id == &"totoy" else 20.0
	var shadow: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		shadow.append(at + Vector2(cos(TAU * i / 32.0) * radius, sin(TAU * i / 32.0) * radius * 0.3 + 2))
	if not silhouette_only:
		draw_colored_polygon(shadow, colors["0"])
	if not frames.has(chosen):
		draw_rect(Rect2(at - Vector2(radius, radius * 2), Vector2(radius * 2, radius * 2)), colors["g"])
		return
	var frame: Dictionary = frames[chosen]
	var left: bool = facing_left if actor.visual_id == &"totoy" else ArenaAnimation.boss_mirrored(actor, snapshot, last_attacks.get(actor.id, {}))
	var destination: Rect2 = ArenaAnimation.destination(at, frame, left)
	if not silhouette_only:
		draw_texture_rect_region(sprites, destination, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	if silhouette_only:
		draw_texture_rect_region(white_sprites, destination, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))

func _draw_dash() -> void:
	var frame: Dictionary = frames.get("hero2_dash_right_1", {})
	if frame.is_empty():
		return
	for ghost: Dictionary in dash_ghosts:
		var fade: float = float(ghost["life"]) / 6.0
		draw_texture_rect_region(white_sprites, ArenaAnimation.destination(ghost["position"], frame, bool(ghost["left"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]), Color(colors["o"], fade * 0.55))
	if snapshot.player.state == &"dash":
		_draw_imported("fx_dash_%d" % (mini(5, snapshot.player.state_ticks / 2) + 1), snapshot.player.position - Vector2(0, 10), Vector2(-1 if facing_left else 1, 1))

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

func _draw_impact(tell: Snapshots.TelegraphSnapshot) -> void:
	CombatEffects.draw_imported_impact(self, tell, snapshot.tick, frames, sprites)

func actor_is_white(actor: Snapshots.EntitySnapshot) -> bool:
	if actor.visual_id == &"totoy" and actor.state == &"dash":
		return false
	return flashes.has(actor.id) or (actor.id == snapshot.player.id and hurt_blink and actor.invulnerable and snapshot.tick % 6 < 3)

# AUDIO HOOKS: one hook per core event. Add playback here when original audio exists.

func _sound_damage_taken(_event: GameEvent) -> void:
	pass

func _sound_parry_succeeded(_event: GameEvent) -> void:
	pass

func _sound_posture_broken(_event: GameEvent) -> void:
	pass

func _sound_counter_window_opened(_event: GameEvent) -> void:
	pass

func _sound_counter_window_closed(_event: GameEvent) -> void:
	pass

func _sound_dash_started(_event: GameEvent) -> void:
	pass

func _sound_attack_hit(_event: GameEvent) -> void:
	pass

func _sound_attack_telegraphed(_event: GameEvent) -> void:
	pass

func _sound_parry_failed(_event: GameEvent) -> void:
	pass

func _sound_dash_ready(_event: GameEvent) -> void:
	pass

func _sound_entity_died(_event: GameEvent) -> void:
	pass

func _sound_boss_phase_changed(_event: GameEvent) -> void:
	pass

func _sound_game_result(_event: GameEvent) -> void:
	pass
