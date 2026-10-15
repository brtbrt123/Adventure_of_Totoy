extends Node2D
## Owns the simulation; only snapshot data crosses into drawing.
const GameCore := preload("res://core/game_core.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const Hud := preload("res://presentation/arena/hud.gd")

var core: GameCore = GameCore.new(17)
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var frames: Dictionary = {}
var floor_regions: Array[Rect2] = []
var missing_frames: Dictionary = {}
var particles: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var flashes: Dictionary = {}
var debug_enabled: bool = false
var shake_left: int = 0
var dash_trail_left: int = 0
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
	# One and only one simulation step per physics frame; aim stays zero.
	core.step(Bindings.read_frame())
	snapshot = core.snapshot()
	_age_effects()
	for event: GameEvent in core.last_events:
		_on_event(event)
	if dash_trail_left > 0:
		trails.append({"position": snapshot.player.position, "life": 8})
		dash_trail_left -= 1
	_update_hud()
	queue_redraw()

func _restart() -> void:
	core = GameCore.new(17)
	snapshot = core.snapshot()
	particles.clear()
	trails.clear()
	flashes.clear()
	shake_left = 0
	dash_trail_left = 0
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
			shake_left = 9
			_sound_posture_broken(event)
		&"counter_window_opened":
			hud.counter_max = maxi(1, int(event.data["window_ticks"]))
			_sound_counter_window_opened(event)
		&"counter_window_closed": _sound_counter_window_closed(event)
		&"dash_started":
			dash_trail_left = 8
			_sound_dash_started(event)
		&"attack_hit":
			_burst(event.data["position"], 5, colors["j"], 0.7)
			# The slice's sole gold boss attack is the slam. No impact event is
			# emitted on a miss: do not invent a core fact from a visual timer.
			if event.data["kind"] == &"gold":
				shake_left = 6
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
	for trail: Dictionary in trails:
		draw_circle(trail["position"], 4, Color(colors["o"], float(trail["life"]) / 16.0))
	var actors: Array[Snapshots.EntitySnapshot] = [snapshot.player]
	actors.append_array(snapshot.entities)
	actors.sort_custom(_behind)
	for actor: Snapshots.EntitySnapshot in actors:
		_draw_actor(actor)
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
	if absf(facing.x) > absf(facing.y):
		return "right" if facing.x >= 0 else "left"
	return "down" if facing.y >= 0 else "up"

func _draw_actor(actor: Snapshots.EntitySnapshot) -> void:
	var base: String = String(actor.visual_id)
	var requested: String = base + "_" + String(actor.state) + "_" + _direction(actor.facing)
	var chosen: String = requested
	if not frames.has(chosen):
		chosen = base + "_" + String(actor.state)
	if actor.state == &"posture_broken" and not frames.has(chosen):
		chosen = base + "_broken"
	if not frames.has(chosen):
		if not missing_frames.has(requested):
			push_warning("Missing arena frame: " + requested + "; using idle fallback")
			missing_frames[requested] = true
		chosen = base + "_idle_down" if frames.has(base + "_idle_down") else base + "_idle"
	var at: Vector2 = actor.position.round()
	var radius: float = 7.0 if actor.visual_id == &"totoy" else 20.0
	var shadow: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		shadow.append(at + Vector2(cos(TAU * i / 32.0) * radius, sin(TAU * i / 32.0) * radius * 0.3 + 2))
	draw_colored_polygon(shadow, Color(colors["0"], 0.35))
	if not frames.has(chosen):
		# Visible, non-crashing placeholder until the required art build is run.
		draw_rect(Rect2(at - Vector2(radius, radius * 2), Vector2(radius * 2, radius * 2)), colors["g"])
		return
	var frame: Dictionary = frames[chosen]
	var tint: Color = Color.WHITE
	if actor.state != &"idle" and actor.state != &"walk":
		tint = Color(colors["o"])
	if actor.state == &"posture_broken" or flashes.has(actor.id) or actor.invulnerable:
		tint = Color(1.4, 1.4, 1.4)
	if actor.state == &"dead":
		tint = Color(colors["f"])
	var size: Vector2 = Vector2(frame["w"], frame["h"])
	draw_texture_rect_region(sprites, Rect2(at - Vector2(size.x * 0.5, size.y - 4), size), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]), tint)
	# Facing/state accents keep the idle fallback useful while animations are pending.
	if actor.visual_id == &"totoy":
		var hand: Vector2 = at + actor.facing * 8.0 - Vector2(0, 6)
		if String(actor.state).begins_with("attack"):
			draw_line(hand, hand + actor.facing * 11.0, colors["j"], 2.0)
		elif actor.state == &"parry":
			draw_circle(hand, 5, colors["o"], false, 1.0)

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
