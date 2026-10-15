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
const Hud := preload("res://presentation/arena/hud.gd")

var core: GameCore = GameCore.new(17)
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var frames: Dictionary = {}
var floor_regions: Array[Rect2] = []
var missing_frames: Dictionary = {}
var selected_frames: Dictionary = {}
var last_attacks: Dictionary = {}
var previous_telegraphs: Array[Snapshots.TelegraphSnapshot] = []
var red_history: Dictionary = {}
var red_plan: Array[Dictionary] = []
var slash_plan: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var visual_tick: int = -1
var particles: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var flashes: Dictionary = {}
var debug_enabled: bool = false
var shake_left: int = 0
var sprites: Texture2D
var tiles: Texture2D
@onready var hud: Hud = $HUD/Display

func _ready() -> void:
	Bindings.register()
	var palette: Dictionary = _read_json("res://art/palette.json")
	for entry: Dictionary in palette.get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	frames = _read_json("res://art/build/sprites.json").get("frames", {})
	sprites = load("res://art/build/sprites.png") as Texture2D
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
	core.step(Bindings.read_frame(snapshot.player.position, get_local_mouse_position()))
	snapshot = core.snapshot()
	_age_effects()
	prepare_visuals()
	for event: GameEvent in core.last_events:
		_on_event(event)
	if snapshot.player.state == &"dash":
		trails.append({"position": snapshot.player.position, "life": 4})
	_update_hud()
	queue_redraw()

func _restart() -> void:
	core = GameCore.new(17)
	snapshot = core.snapshot()
	selected_frames.clear()
	last_attacks.clear()
	previous_telegraphs.clear()
	rings.clear()
	red_history.clear()
	red_plan.clear()
	slash_plan.clear()
	visual_tick = -1
	prepare_visuals()
	particles.clear()
	trails.clear()
	flashes.clear()
	shake_left = 0
	hud.counter_max = 1

func _update_hud() -> void:
	hud.snapshot = snapshot
	hud.colors = colors
	hud.debug_enabled = debug_enabled
	hud.queue_redraw()

func _age_effects() -> void:
	shake_left = maxi(0, shake_left - 1)
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
			flashes[int(event.data["entity_id"])] = 6
			_sound_damage_taken(event)
		&"parry_succeeded":
			var perfect: bool = event.data["quality"] == &"perfect"
			_burst(event.data["position"], 16 if perfect else 7, colors["x"], 1.6 if perfect else 1.0)
			_sound_parry_succeeded(event)
		&"posture_broken":
			flashes[int(event.data["entity_id"])] = 5
			shake_left = 6
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
				_burst(event.data["position"], 16 if counter else 8, colors["1"], 1.8 if counter else 0.9)
				if counter:
					shake_left = maxi(shake_left, 5)
			_sound_attack_hit(event)
		&"attack_telegraphed": _sound_attack_telegraphed(event)
		&"parry_failed": _sound_parry_failed(event)
		&"dash_ready": _sound_dash_ready(event)
		&"entity_died": _sound_entity_died(event)
		&"boss_phase_changed": _sound_boss_phase_changed(event)
		&"game_result": _sound_game_result(event)

func _burst(at: Vector2, count: int, color: Color, speed: float) -> void:
	for i: int in range(count):
		particles.append({"position": at, "velocity": Vector2.from_angle(TAU * i / count) * speed, "life": 12, "color": color})

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
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		TelegraphView.draw_warning(self, t, snapshot.tick, colors["x"] if t.kind == &"gold" else colors["z"], colors["y"] if t.kind == &"gold" else colors["A"], colors["0"])
	for ring: Dictionary in rings:
		var age: int = snapshot.tick - int(ring["start_tick"])
		draw_arc(ring["position"], 5.0 + age * 2.0, 0.0, TAU, 32, colors["j"], 1.0, false)
	for trail: Dictionary in trails:
		if bool(trail.get("charge", false)):
			var dust_at: Vector2 = trail["position"]
			var life: int = int(trail["life"])
			for fleck: int in range(3):
				var dust_offset: Vector2 = Vector2(fleck * 3 - 3, (fleck % 2) * 4 - 2 - (5 - life))
				draw_rect(Rect2((dust_at + dust_offset).round(), Vector2(2 if life > 2 else 1, 2)), colors["j"] if fleck == 1 else colors["c"])
		else:
			draw_circle(trail["position"], 2, colors["t"], false, 1.0)
	var actors: Array[Snapshots.EntitySnapshot] = [snapshot.player]
	actors.append_array(snapshot.entities)
	actors.sort_custom(_behind)
	for actor: Snapshots.EntitySnapshot in actors:
		_draw_actor(actor)
	CombatEffects.draw_plan(self, red_plan)
	CombatEffects.draw_plan(self, slash_plan)
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		TelegraphView.draw_marker(self, t, colors["x"] if t.kind == &"gold" else colors["z"], colors["0"])
	for particle: Dictionary in particles:
		var at: Vector2 = particle["position"]
		draw_rect(Rect2(at.round(), Vector2.ONE), particle["color"])
	if debug_enabled:
		draw_circle(snapshot.player.position, Tuning.PLAYER_RADIUS, colors["p"], false, 1.0)
		for actor: Snapshots.EntitySnapshot in snapshot.entities:
			draw_circle(actor.position, Tuning.BOSS_RADIUS, colors["p"], false, 1.0)
	draw_set_transform(Vector2.ZERO)

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
						rings.append({"position": tell.center, "start_tick": tell.hit_tick})
					_burst(tell.center, 18, colors["j"], 1.4)
					shake_left = maxi(shake_left, 4)
		for i: int in range(rings.size() - 1, -1, -1):
			if snapshot.tick - int(rings[i]["start_tick"]) > 9:
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
		selected_frames[actor.id] = _resolve_frame(ArenaAnimation.choose(actor, snapshot, last_attacks.get(actor.id, {})), actor)

func _resolve_frame(requested: String, actor: Snapshots.EntitySnapshot) -> String:
	if frames.has(requested):
		return requested
	if not missing_frames.has(requested):
		push_warning("Missing arena frame: " + requested + "; using idle fallback")
		missing_frames[requested] = true
	var fallback: String = "totoy_idle_down_1" if actor.visual_id == &"totoy" else "mossbound_colossus_idle_1"
	if frames.has(fallback):
		return fallback
	return "totoy_idle_down" if actor.visual_id == &"totoy" else "mossbound_colossus_idle"

func _dust(at: Vector2) -> void:
	for i: int in range(5):
		particles.append({"position": at + Vector2(i - 2, 2), "velocity": Vector2((i - 2) * 0.18, -0.22), "life": 6, "color": colors["c"] if i % 2 == 0 else colors["d"]})

func _draw_actor(actor: Snapshots.EntitySnapshot) -> void:
	var chosen: String = String(selected_frames.get(actor.id, ""))
	var at: Vector2 = actor.position.round()
	var radius: float = 7.0 if actor.visual_id == &"totoy" else 20.0
	var shadow: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		shadow.append(at + Vector2(cos(TAU * i / 32.0) * radius, sin(TAU * i / 32.0) * radius * 0.3 + 2))
	draw_colored_polygon(shadow, colors["0"])
	if not frames.has(chosen):
		draw_rect(Rect2(at - Vector2(radius, radius * 2), Vector2(radius * 2, radius * 2)), colors["g"])
		return
	var frame: Dictionary = frames[chosen]
	var size: Vector2 = Vector2(frame["w"], frame["h"])
	var destination: Rect2 = Rect2(at - Vector2(size.x * 0.5, size.y - 4), size)
	if (actor.visual_id == &"totoy" and ArenaAnimation.mirrored(actor.facing)) or (actor.visual_id != &"totoy" and ArenaAnimation.boss_mirrored(actor, snapshot, last_attacks.get(actor.id, {}))):
		# CanvasItem mirrors a texture region when the destination width is negative.
		destination.size.x = -destination.size.x
	draw_texture_rect_region(sprites, destination, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	if flashes.has(actor.id):
		# An opaque palette sparkle leaves the authored colors intact.
		draw_line(at + Vector2(-3, -16), at + Vector2(3, -16), colors["p"])
		draw_line(at + Vector2(0, -19), at + Vector2(0, -13), colors["p"])

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
