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
const CombatAudio := preload("res://presentation/arena/combat_audio.gd")
const WeaponBuffView := preload("res://presentation/arena/weapon_buff_view.gd")
const SkillEffects := preload("res://presentation/arena/skill_effects.gd")
const CombatEffects := preload("res://presentation/arena/combat_effects.gd")
const CoreAnchors := preload("res://presentation/arena/core_anchors.gd")
const HeadAnchors := preload("res://presentation/arena/head_anchors.gd")
const GroundView := preload("res://presentation/arena/ground_view.gd")
const DECORATIONS: Array[Dictionary] = [{"name": "prop_nature_1", "at": Vector2(18, 91), "scale": Vector2.ONE}, {"name": "prop_nature_4", "at": Vector2(289, 172), "scale": Vector2(2, 2)}, {"name": "prop_ruins_2", "at": Vector2(290, 80), "scale": Vector2(2, 2)}, {"name": "prop_small_3", "at": Vector2(35, 170), "scale": Vector2.ONE}]
const Hud := preload("res://presentation/arena/hud.gd")

var empowered_sprites: Texture2D
var buff_textures: Dictionary = {}
var buff_events: Dictionary = {}
var buff_transition: Dictionary = {}
var combat_audio: CombatAudio
var previous_combo_index: int = 0
var previous_skill_id: StringName = &""
var core: GameCore = GameCore.new(17)
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var frames: Dictionary = {}
var head_anchors: Dictionary = {}
var core_anchors: Dictionary = {}
var ground_texture: Texture2D
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
var skill_trails: Array[Dictionary] = []
var released_skill_attacks: Dictionary = {}
var current_skill_release: Dictionary = {}
var projectile_textures: Dictionary = {}
var trails: Array[Dictionary] = []
var flashes: Dictionary = {}
var debug_enabled: bool = false
var shake_left: int = 0
var gold_sprites: Texture2D
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
	combat_audio = CombatAudio.new()
	add_child(combat_audio)
	combat_audio.set_music_active(true)
	Bindings.register()
	var palette: Dictionary = _read_json("res://art/palette.json")
	for entry: Dictionary in palette.get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	frames = _read_json("res://art/build/sprites.json").get("frames", {})
	sprites = load("res://art/build/sprites.png") as Texture2D
	var empowered_image: Image = sprites.get_image().duplicate() as Image
	empowered_image.convert(Image.FORMAT_RGBA8)
	var dark_colors: Dictionary = {colors["e"]: colors["0"], colors["f"]: colors["0"], colors["g"]: colors["e"], colors["h"]: colors["k"], colors["k"]: colors["0"], colors["l"]: colors["e"], colors["m"]: colors["k"]}
	for key: String in frames:
		if not key.begins_with("hero2_"):
			continue
		var region: Dictionary = frames[key]
		for y: int in range(region["y"], region["y"] + region["h"]):
			for x: int in range(region["x"], region["x"] + region["w"]):
				var pixel: Color = empowered_image.get_pixel(x, y)
				if pixel.a > 0.0 and dark_colors.has(pixel):
					empowered_image.set_pixel(x, y, dark_colors[pixel])
	empowered_sprites = ImageTexture.create_from_image(empowered_image)
	var gold_image: Image = sprites.get_image().duplicate() as Image
	gold_image.convert(Image.FORMAT_RGBA8)
	for y: int in range(gold_image.get_height()):
		for x: int in range(gold_image.get_width()):
			var pixel: Color = gold_image.get_pixel(x, y)
			if pixel == colors["z"]:
				gold_image.set_pixel(x, y, colors["x"])
			elif pixel == colors["A"]:
				gold_image.set_pixel(x, y, colors["y"])
	gold_sprites = ImageTexture.create_from_image(gold_image)
	var white_image: Image = sprites.get_image().duplicate() as Image
	white_image.convert(Image.FORMAT_RGBA8)
	for name_key: String in frames:
		if (name_key.begins_with("mossbound_colossus_") or name_key.begins_with("golem2_")):
			head_anchors[name_key] = HeadAnchors.measure(white_image, frames[name_key])
			core_anchors[name_key] = CoreAnchors.measure(white_image, frames[name_key], colors["1"])
	for y: int in range(white_image.get_height()):
		for x: int in range(white_image.get_width()):
			var alpha: float = white_image.get_pixel(x, y).a
			white_image.set_pixel(x, y, Color(1, 1, 1, alpha))
	white_sprites = ImageTexture.create_from_image(white_image)
	tiles = load("res://art/build/tiles.png") as Texture2D
	var tile_entries: Dictionary = _read_json("res://art/build/tiles.json").get("tiles", {})
	var ground: Image = GroundView.build(tiles.get_image(), tile_entries)
	ground_texture = ImageTexture.create_from_image(ground)
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
	buff_events.clear()
	buff_transition.clear()
	combat_audio.reset()
	combat_audio.set_music_active(true)
	previous_combo_index = 0
	previous_skill_id = &""
	core = GameCore.new(17)
	snapshot = core.snapshot()
	facing_left = false
	previous_player_state = &""
	dash_ghosts.clear()
	skill_trails.clear()
	released_skill_attacks.clear()
	current_skill_release.clear()
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
	var cosmetic_tick: int = snapshot.tick + snapshot.result_ticks
	for index: int in range(skill_trails.size() - 1, -1, -1):
		if cosmetic_tick - int(skill_trails[index]["tick"]) >= SkillEffects.TRAIL_TICKS:
			skill_trails.remove_at(index)
	if not snapshot.player.invulnerable:
		hurt_blink = false
	shake_left = maxi(0, shake_left - 1)
	for i: int in range(hit_bursts.size() - 1, -1, -1):
		if cosmetic_tick - int(hit_bursts[i]["tick"]) >= 12:
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
		&"weapon_buff_started", &"weapon_buff_ended":
			var identity: String = "%s:%d:%d" % [event.type, event.tick, int(event.data["entity_id"])]
			if buff_events.has(identity):
				return
			buff_events[identity] = true
			var started: bool = event.type == &"weapon_buff_started"
			buff_transition = {"tick": event.tick, "started": started, "at": snapshot.player.position}
			combat_audio.cue("weapon_buff_start" if started else "weapon_buff_end", event.tick)
			_burst(snapshot.player.position - Vector2(0, 12), 12 if started else 6, colors["k"], 0.8)
		&"damage_taken":
			reactions[int(event.data["entity_id"])] = {"pose": "hurt", "tick": snapshot.tick, "duration": 12}
			flashes[int(event.data["entity_id"])] = maxi(6, int(flashes.get(int(event.data["entity_id"]), 0)))
			if int(event.data["entity_id"]) == snapshot.player.id:
				hurt_blink = true
			_sound_damage_taken(event)
		&"parry_succeeded":
			var perfect: bool = event.data["quality"] == &"perfect"
			var contact: Vector2 = _impact_contact(event.data["position"], int(event.data["player_id"]), int(event.data["attacker_id"]))
			_burst(contact, 16 if perfect else 7, colors["x"], 1.6 if perfect else 1.0)
			parry_impacts.append({"position": event.data["position"], "tick": event.tick, "perfect": perfect, "contact": contact})
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
		&"skill_started":
			current_skill_release.clear()
			combat_audio.cue("skill_" + String(event.data["skill_id"]), event.tick)
		&"skill_released":
			var attack_id: int = int(event.data["attack_id"])
			if released_skill_attacks.has(attack_id):
				return
			released_skill_attacks[attack_id] = true
			current_skill_release = event.data.duplicate()
			combat_audio.cue("release_" + String(event.data["skill_id"]), event.tick)
		&"dash_started":
			_sound_dash_started(event)
		&"attack_hit":
			var counter: bool = event.data["kind"] == &"counter"
			if int(event.data["attacker_id"]) == snapshot.player.id:
				var contact: Vector2 = _impact_contact(event.data["position"], int(event.data["target_id"]), int(event.data["attacker_id"]))
				var finisher: bool = int(event.data.get("combo_index", 1)) == 3 or event.data.get("skill_id", &"") == &"moon_cleave"
				hit_bursts.append({"position": event.data["position"], "contact": contact, "tick": event.tick, "counter": counter, "finisher": finisher, "skill_id": event.data.get("skill_id", &""), "facing": snapshot.player.facing})
				shake_left = maxi(shake_left, 3 if finisher else 1)
				_burst(contact, 16 if counter or finisher else 8, colors["1"], 1.8 if counter else 0.9)
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
	draw_texture(ground_texture, Vector2.ZERO, Color(0.72, 0.72, 0.72))
	for trace: Dictionary in skill_trails:
		CombatEffects.draw_plan(self, SkillEffects.trail(trace["from"], trace["to"], snapshot.tick + snapshot.result_ticks - int(trace["tick"]), colors))
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if t.attack != &"red_shards":  # the beam warning starts at the golem's chest: drawn over the golem below
			_draw_warning(t)
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
	var drawables: Array[Dictionary] = []
	for decoration: Dictionary in DECORATIONS:
		drawables.append(decoration)
	for actor: Snapshots.EntitySnapshot in actors:
		drawables.append({"actor": actor, "at": actor.position})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["at"]).y < Vector2(b["at"]).y)
	for item: Dictionary in drawables:
		if item.has("actor"):
			_draw_actor(item["actor"])
		else:
			_draw_imported(item["name"], item["at"], item["scale"])
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if t.attack == &"red_shards":
			_draw_warning(t)
	for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if snapshot.tick >= tell.hit_tick and snapshot.tick <= tell.end_tick:
			_draw_impact(tell)
	for id: int in red_history:
		var tell: Snapshots.TelegraphSnapshot = red_history[id]
		if snapshot.tick > tell.end_tick:
			_draw_impact(tell)
	for impact: Dictionary in parry_impacts:
		var age: int = snapshot.tick - int(impact["tick"])
		var contact: Vector2 = impact.get("contact", impact["position"])
		var size_scale: Vector2 = Vector2(1.15, 1.15) if bool(impact["perfect"]) else Vector2(0.75, 0.75)
		_draw_imported("fx_parry_%d" % (mini(5, age / 2) + 1), contact, size_scale)
		if age < 2 and bool(impact["perfect"]):
			_draw_imported("fx_flash_1", contact, Vector2(0.6, 0.6))
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if not TelegraphView.warning_visible(t, snapshot.tick):
			continue
		_draw_imported("ui_warning_%s_%d" % ["gold" if t.kind == &"gold" else "red", 1 + (snapshot.tick / 12) % 2], TelegraphView.marker_position(t), Vector2(0.5, 0.5))
	for burst: Dictionary in hit_bursts:
		var age: int = snapshot.tick + snapshot.result_ticks - int(burst["tick"])
		var contact: Vector2 = burst.get("contact", burst["position"])
		var heavy: bool = bool(burst.get("finisher", false)) or bool(burst["counter"])
		_draw_imported("fx_%s_%d" % ["counter" if bool(burst["counter"]) else "hit", mini(5, age / 2) + 1], contact, Vector2(1.3, 1.3) if heavy else Vector2.ONE)
		if age < 2:
			_draw_imported("fx_flash_1", contact, Vector2(0.65, 0.65) if heavy else Vector2(0.4, 0.4))
	for particle: Dictionary in particles:
		var at: Vector2 = particle["position"]
		draw_rect(Rect2(at.round(), Vector2.ONE), particle["color"])
	# Damage silhouettes sit over translucent combat light so white stays pure white.
	for actor: Snapshots.EntitySnapshot in actors:
		if actor_is_white(actor):
			_draw_actor(actor, true)
	# Skill trails remain legible over the brief damage silhouette.
	_draw_skill_effect(offset)
	_draw_skill_projectiles(offset)
	_draw_skill_contacts()
	_draw_buff_slash(offset)
	_draw_buff_transition()
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
		var changed: bool = previous_player_state != hero.state or previous_combo_index != hero.combo_index or previous_skill_id != hero.skill_id
		var attack_started: bool = hero.state == &"attack_windup" and changed
		if hero.state == &"attack_active" and changed:
			combat_audio.cue("swing", snapshot.tick, 1.0 if hero.combo_index == 3 else 0.75)
		if ((moved and hero.state != &"dead") or attack_started or hero.state.begins_with("skill_")) and absf(hero.facing.x) > 0.3:
			facing_left = hero.facing.x < 0.0
		for i: int in range(dash_ghosts.size() - 1, -1, -1):
			dash_ghosts[i]["life"] -= 1
			if int(dash_ghosts[i]["life"]) <= 0:
				dash_ghosts.remove_at(i)
		var gale_travel: bool = hero.skill_id == &"gale_cut" and previous_skill_id == &"gale_cut" and moved and (hero.state == &"skill_active" or (previous_player_state == &"skill_active" and hero.state == &"skill_recovery"))
		if gale_travel:
			skill_trails.append({"from": previous_player_position, "to": hero.position, "tick": snapshot.tick})
		if (hero.state == &"dash" and previous_player_state == &"dash") or gale_travel:
			dash_ghosts.append({"position": previous_player_position, "left": facing_left, "life": 6})
			if dash_ghosts.size() > 3:
				dash_ghosts.pop_front()
		previous_player_position = hero.position
		previous_player_state = hero.state
		previous_combo_index = hero.combo_index
		previous_skill_id = hero.skill_id
	if fresh:
		for i: int in range(parry_impacts.size() - 1, -1, -1):
			if snapshot.tick - int(parry_impacts[i]["tick"]) >= 12:
				parry_impacts.remove_at(i)
		# Only live tells sound: interrupted attacks must not produce a later impact.
		for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
			if visual_tick < tell.hit_tick and snapshot.tick >= tell.hit_tick and snapshot.tick <= tell.end_tick:
				var cue_key: String = {&"gold_slam": "golem_slam", &"gold_combo": "golem_slam", &"red_stomp": "golem_stomp", &"red_sweep": "golem_sweep", &"red_charge": "golem_charge", &"red_shards": "golem_beam"}.get(tell.attack, "")
				combat_audio.cue(cue_key, snapshot.tick)
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
		if actor.id == snapshot.player.id:
			_draw_buff_aura(actor, false)
		var actor_texture: Texture2D = empowered_sprites if actor.id == snapshot.player.id and actor.weapon_buff_active else sprites
		draw_texture_rect_region(actor_texture, destination, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	if silhouette_only:
		draw_texture_rect_region(white_sprites, destination, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	if not silhouette_only and actor.id == snapshot.player.id:
		_draw_buff_aura(actor, true)

func _draw_dash() -> void:
	var frame: Dictionary = frames.get("hero2_dash_right_1", {})
	if frame.is_empty():
		return
	for ghost: Dictionary in dash_ghosts:
		var fade: float = float(ghost["life"]) / 6.0
		if snapshot.player.weapon_buff_active:
			draw_texture_rect_region(empowered_sprites, ArenaAnimation.destination(ghost["position"], frame, bool(ghost["left"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
			_draw_buff_frame("fx_black_aura_back_%d" % (posmod(snapshot.tick / 5, 6) + 1), ghost["position"], 1, bool(ghost["left"]))
		else:
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

func boss_core_position(actor: Snapshots.EntitySnapshot) -> Vector2:
	var key: String = String(selected_frames.get(actor.id, ""))
	if not frames.has(key) or not core_anchors.has(key):
		return actor.position
	return HeadAnchors.world(actor.position, frames[key], core_anchors[key], ArenaAnimation.boss_mirrored(actor, snapshot, last_attacks.get(actor.id, {})))

func impact_origin(tell: Snapshots.TelegraphSnapshot) -> Vector2:
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if actor.id == tell.owner_id:
			# The beam leaves the core's authoritative muzzle (the chest), the same point the damage capsule starts at.
			return tell.muzzle if tell.attack == &"red_shards" else actor.position
	return tell.center

func _draw_warning(t: Snapshots.TelegraphSnapshot) -> void:
	TelegraphView.draw_warning(self, t, snapshot.tick, colors["x"] if t.kind == &"gold" else colors["z"], colors["y"] if t.kind == &"gold" else colors["A"], colors["0"])

func _draw_impact(tell: Snapshots.TelegraphSnapshot) -> void:
	CombatEffects.draw_imported_impact(self, tell, snapshot.tick, frames, gold_sprites if tell.kind == &"gold" and tell.shape == &"cone" else sprites, impact_origin(tell))

func actor_is_white(actor: Snapshots.EntitySnapshot) -> bool:
	if actor.visual_id == &"totoy" and actor.state == &"dash":
		return false
	return flashes.has(actor.id) or (actor.id == snapshot.player.id and hurt_blink and actor.invulnerable and snapshot.tick % 6 < 3)

## The event position remains untouched. Only the painted contact is raised to
## the target's torso/weapon, so feedback no longer appears underneath its feet.
func _impact_contact(at: Vector2, target_id: int, attacker_id: int) -> Vector2:
	var target: Snapshots.EntitySnapshot = snapshot.player
	var attacker: Snapshots.EntitySnapshot = snapshot.player
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if actor.id == target_id:
			target = actor
		if actor.id == attacker_id:
			attacker = actor
	var side: float = (attacker.position - at).normalized().x
	return at + Vector2(side * 9.0, -20.0 if target.visual_id == &"mossbound_colossus" else -14.0)

func _sound_damage_taken(event: GameEvent) -> void:
	if int(event.data["entity_id"]) == snapshot.player.id:
		combat_audio.cue("player_hurt", event.tick)

func _sound_parry_succeeded(event: GameEvent) -> void:
	combat_audio.cue("perfect_parry" if event.data["quality"] == &"perfect" else "deflect", event.tick)

func _sound_posture_broken(event: GameEvent) -> void:
	combat_audio.cue("posture_break", event.tick)

func _sound_counter_window_opened(_event: GameEvent) -> void:
	pass

func _sound_counter_window_closed(_event: GameEvent) -> void:
	pass

func _sound_dash_started(event: GameEvent) -> void:
	combat_audio.cue("dash", event.tick, 0.8)

func _sound_attack_hit(event: GameEvent) -> void:
	if int(event.data["attacker_id"]) == snapshot.player.id:
		var heavy: bool = event.data["kind"] == &"counter" or int(event.data.get("combo_index", 1)) == 3 or event.data.get("skill_id", &"") in [&"moon_cleave", &"breaking_edge"]
		combat_audio.cue("counter_hit" if heavy else "armor_hit", event.tick)

func _sound_attack_telegraphed(event: GameEvent) -> void:
	combat_audio.cue("gold_warning" if event.data["kind"] == &"gold" else "red_warning", event.tick, 0.7)

func _sound_parry_failed(_event: GameEvent) -> void:
	pass

func _sound_dash_ready(_event: GameEvent) -> void:
	pass

func _sound_entity_died(_event: GameEvent) -> void:
	pass

func _sound_boss_phase_changed(_event: GameEvent) -> void:
	pass

func _sound_game_result(_event: GameEvent) -> void:
	combat_audio.set_music_active(false)


## Effects follow current snapshot phases; cancelled skills leave no queued release.
func skill_effect() -> Dictionary:
	if snapshot.result != &"playing":
		return {}
	if snapshot.player.state != &"skill_windup" and current_skill_release.get("skill_id", &"") != snapshot.player.skill_id:
		return {}
	return SkillEffects.plan(snapshot.player)

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
	CombatEffects.draw_plan(self, SkillEffects.accents(snapshot.player, colors))


## Strong contact accents are driven by confirmed attack_hit events only.
func _draw_skill_contacts() -> void:
	for burst: Dictionary in hit_bursts:
		if burst.get("skill_id", &"") != &"breaking_edge":
			continue
		var age: int = snapshot.tick + snapshot.result_ticks - int(burst["tick"])
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
	return SkillEffects.projectiles(snapshot)

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

func weapon_buff_effect() -> Dictionary:
	return WeaponBuffView.plan(snapshot)

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
	var chosen: String = String(selected_frames.get(snapshot.player.id, ""))
	if not chosen.begins_with("hero2_attack") and not (snapshot.player.state == &"skill_active" and chosen.begins_with("hero2_dash")):
		return {}
	return {"key": effect["slash"], "at": (snapshot.player.position + Vector2(-15 if facing_left else 15, -12)).round(), "left": facing_left, "level": effect["level"]}

func _draw_buff_slash(_shake_offset: Vector2) -> void:
	var effect: Dictionary = weapon_slash_effect()
	if effect.is_empty():
		return
	# Draw directly in world coordinates, sharing the actor's current canvas transform.
	_draw_buff_frame(effect["key"], effect["at"], int(effect["level"]), bool(effect["left"]))

func _draw_buff_transition() -> void:
	if buff_transition.is_empty():
		return
	var age: int = snapshot.tick + snapshot.result_ticks - int(buff_transition["tick"])
	if age < 0 or age >= 12:
		return
	var level: int = maxi(1, 4 - age / 3)
	var at: Vector2 = snapshot.player.position if bool(buff_transition["started"]) else Vector2(buff_transition["at"])
	_draw_buff_frame("fx_black_aura_back_%d" % (mini(5, age / 2) + 1), at, level, facing_left)
