extends "res://presentation/common/hero_fx.gd"
## Owns the simulation; only snapshot data crosses into drawing.
const GameCore := preload("res://core/game_core.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const CombatAudio := preload("res://presentation/arena/combat_audio.gd")
const SaveStore := preload("res://core/save_store.gd")
const BlackFormCutIn := preload("res://presentation/arena/black_form_cutin.gd")
const LightningFormCutIn := preload("res://presentation/arena/lightning_form_cutin.gd")
const LightningEffects := preload("res://presentation/arena/lightning_effects.gd")
const ReapersCoilCutIn := preload("res://presentation/arena/reapers_coil_cutin.gd")
const ScytheEffects := preload("res://presentation/arena/scythe_effects.gd")
const Aspects := preload("res://core/aspects.gd")
## Per-frame data of the scythe import (chain_origin of the Reaper's Coil whip/pull frames).
const SCYTHE_MANIFEST: String = "res://art/build/chain_scythe_sprites_manifest.json"
## Height above the ground plane where the Reaper's Coil chain flies and bites (the hand is at about this height).
const CHAIN_HEIGHT: Vector2 = Vector2(0, -14)
const TITLE_SCENE: String = "res://presentation/menu/title.tscn"
const CoreAnchors := preload("res://presentation/arena/core_anchors.gd")
const HeadAnchors := preload("res://presentation/arena/head_anchors.gd")
const GroundView := preload("res://presentation/arena/ground_view.gd")
const ArenaDecor := preload("res://presentation/arena/arena_decor.gd")
## The shared soft ground shadow under the actors and the painted props drawn over actors behind them (2026-10-22).
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const DepthOccluders := preload("res://presentation/common/depth_occluders.gd")
const OCCLUDER_SCENE: StringName = &"arena"
## The ground is drawn at this modulate; the occluders (cut from it) must match.
const GROUND_MODULATE: Color = Color(0.92, 0.92, 0.92)
const GROUND_PATH: String = "res://presentation/arena/arena_ground.png"
const VIEW_SIZE: Vector2 = Vector2(384.0, 216.0)
## Non-solid decoration (the solid props come from the core's snapshot).
var decor: Array[Dictionary] = []
## The camera follows the player on the same 384x216 screen. `view_origin` is the world position of the screen's
## top-left corner, whole pixels, kept inside the arena.
var camera: Camera2D
var camera_focus: Vector2 = Vector2.ZERO
var view_origin: Vector2 = Vector2.ZERO
const Hud := preload("res://presentation/arena/hud.gd")
const CharacterMenu := preload("res://presentation/arena/character_menu.gd")
## The character menu (TAB) on the HUD layer. While it is open the arena does not step the core (like the cut-ins),
## except once for each weapon equip request it sends.
var character_menu: CharacterMenu

var combat_audio: CombatAudio
## Progress is saved only when the game was started from the title screen (it sets this Engine meta).
var persist: bool = false
## The Black Form cut-in (drawn on the HUD layer). While it plays the arena does not step the core.
var cutin: BlackFormCutIn
## The Lightning Form cut-in (Dual Dagger right click); freezes the world the same way.
var lightning_cutin: LightningFormCutIn
## Lightning effects from core events, in world coordinates: {"kind", "tick", ...}; aged by the cosmetic tick.
var lightning_fx: Array[Dictionary] = []
## The Reaper's Coil cut-in (Chain Scythe right click); freezes the world the same way.
var coil_cutin: ReapersCoilCutIn
## Chain Scythe / Reaper's Coil event effects in world coordinates ({"kind", "tick", "life", ...}), capped at
## ScytheEffects.MAX_LIVE. The chain, flying head, ring halves, pull streaks and dizzy stars are drawn from the snapshot.
var coil_fx: Array[Dictionary] = []
## Tick of the latest reaper_coil_hooked (the chain flashes spectral on it).
var coil_hook_tick: int = -1
## Boss id -> the tick its current drag began (paces the dust puffs and scuff decals).
var drag_started: Dictionary = {}
## Frame name -> where the chain leaves the fist (relative to the feet, facing right), from the scythe manifest.
var chain_origins: Dictionary = {}
## True between a Phantom echo's attack_hit and its damage_taken (the echo flashes the boss less than a real hit).
var echo_hit_pending: bool = false
var profile: Object = null
var new_best: bool = false
## Replaced by tests so going back to the title does not leave the scene they run in.
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)
var previous_combo_index: int = 0
var previous_skill_id: StringName = &""
var core: GameCore = GameCore.new(17)
var snapshot: Snapshots.GameSnapshot
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
var visual_tick: int = -1
var skill_trails: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var flashes: Dictionary = {}
var debug_enabled: bool = false
var gold_sprites: Texture2D
var hurt_blink: bool = false
var previous_player_state: StringName = &""
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
	# The Black Form, gold-impact and hit-flash copies of the atlas are built by tools/art/build_art.py (they used to be
	# recoloured here pixel by pixel, about 1 s of _ready); the runtime recolour stays only as a fallback.
	empowered_sprites = _variant_atlas(DARK_ATLAS, &"dark")
	gold_sprites = _variant_atlas(GOLD_ATLAS, &"gold")
	white_sprites = _variant_atlas(WHITE_ATLAS, &"white")
	var atlas_image: Image = sprites.get_image()
	if atlas_image.get_format() != Image.FORMAT_RGBA8:
		atlas_image.convert(Image.FORMAT_RGBA8)
	for name_key: String in frames:
		if (name_key.begins_with("mossbound_colossus_") or name_key.begins_with("golem2_")):
			head_anchors[name_key] = HeadAnchors.measure(atlas_image, frames[name_key])
			core_anchors[name_key] = CoreAnchors.measure(atlas_image, frames[name_key], colors["1"])
	tiles = load("res://art/build/tiles.png") as Texture2D
	if ResourceLoader.exists(GROUND_PATH):
		ground_texture = load(GROUND_PATH) as Texture2D
	else:
		var tile_entries: Dictionary = _read_json("res://art/build/tiles.json").get("tiles", {})
		ground_texture = ImageTexture.create_from_image(GroundView.build(tiles.get_image(), tile_entries))
	decor = ArenaDecor.build(core.obstacles)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	snapshot = core.snapshot()
	_update_camera(true)
	prepare_visuals()
	_update_hud()
	_begin_persistence()
	cutin = BlackFormCutIn.new()
	cutin.position = Vector2(32, 18)
	$HUD.add_child(cutin)
	lightning_cutin = LightningFormCutIn.new()
	lightning_cutin.position = Vector2(32, 18)
	$HUD.add_child(lightning_cutin)
	coil_cutin = ReapersCoilCutIn.new()
	coil_cutin.position = Vector2(32, 18)
	$HUD.add_child(coil_cutin)
	character_menu = CharacterMenu.new()
	character_menu.equip_request = request_equip
	character_menu.aspect_request = request_aspect_equip
	$HUD.add_child(character_menu)
	_update_hud()
	_load_chain_origins()

## Recoloured atlas copies written by tools/art/build_art.py next to sprites.png (same frame rectangles).
const GOLD_ATLAS: String = "res://art/build/sprites_gold.png"
const WHITE_ATLAS: String = "res://art/build/sprites_white.png"
const DARK_ATLAS: String = "res://art/build/sprites_dark.png"

## The built copy, else (a stale build) the same recolour done here at runtime, slowly, with a warning.
func _variant_atlas(path: String, kind: StringName) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path) as Texture2D
		if texture != null and texture.get_size() == sprites.get_size():
			return texture
	push_warning("Arena: %s is missing or stale (run tools/art/build_art.py); recolouring at runtime" % path)
	return ImageTexture.create_from_image(recolour_atlas(sprites.get_image(), kind, frames, colors))

## The recolour rules of the atlas copies (the same as build_art.build_variant_atlases): `gold` turns the reserved reds
## gold (z -> x, A -> y) everywhere; `white` makes every pixel white with its own alpha; `dark` darkens the stone and
## blue ramps inside each hero2_* frame rectangle (the Black Form look). Used as the fallback and by the tests.
static func recolour_atlas(source: Image, kind: StringName, frame_table: Dictionary, palette: Dictionary) -> Image:
	var image: Image = source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	match kind:
		&"gold":
			for y: int in range(image.get_height()):
				for x: int in range(image.get_width()):
					var pixel: Color = image.get_pixel(x, y)
					if pixel == palette["z"]:
						image.set_pixel(x, y, palette["x"])
					elif pixel == palette["A"]:
						image.set_pixel(x, y, palette["y"])
		&"white":
			for y: int in range(image.get_height()):
				for x: int in range(image.get_width()):
					image.set_pixel(x, y, Color(1, 1, 1, image.get_pixel(x, y).a))
		&"dark":
			var dark_colors: Dictionary = {palette["e"]: palette["0"], palette["f"]: palette["0"], palette["g"]: palette["e"], palette["h"]: palette["k"], palette["k"]: palette["0"], palette["l"]: palette["e"], palette["m"]: palette["k"]}
			for key: String in frame_table:
				if not key.begins_with("hero2_"):
					continue
				var region: Dictionary = frame_table[key]
				for y: int in range(region["y"], region["y"] + region["h"]):
					for x: int in range(region["x"], region["x"] + region["w"]):
						var pixel: Color = image.get_pixel(x, y)
						if pixel.a > 0.0 and dark_colors.has(pixel):
							image.set_pixel(x, y, dark_colors[pixel])
	return image

## The hooks of presentation/common/hero_fx.gd: who the hero is here and what tick it is.
func fx_hero() -> Snapshots.EntitySnapshot:
	return snapshot.player


func fx_tick() -> int:
	return snapshot.tick


func fx_result_ticks() -> int:
	return snapshot.result_ticks


func fx_playing() -> bool:
	return snapshot.result == &"playing"


func fx_cue(key: String, tick: int, strength: float = 1.0) -> void:
	combat_audio.cue(key, tick, strength)


func fx_snapshot() -> RefCounted:
	return snapshot


## The boss's core (the painted glow), else the position plus the boss's body offset.
func fx_target_contact(target_id: int, fallback: Vector2) -> Vector2:
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if actor.id == target_id:
			return boss_core_position(actor)
	return fallback + ScytheEffects.BOSS_BODY


## True while any weapon cut-in plays (the world does not step).
func cutin_playing() -> bool:
	return (cutin != null and cutin.active) or (lightning_cutin != null and lightning_cutin.active) or (coil_cutin != null and coil_cutin.active)

func _load_chain_origins() -> void:
	var sprites_data: Dictionary = _read_json(SCYTHE_MANIFEST).get("sprites", {})
	for group: String in sprites_data:
		var origins: Array = Dictionary(sprites_data[group]).get("chain_origin", [])
		for index: int in range(origins.size()):
			chain_origins["%s_%d" % [group, index + 1]] = Vector2(float(origins[index][0]), float(origins[index][1]))

func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Arena cannot open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func _physics_process(delta: float) -> void:
	# A weapon cut-in freezes the world: no core steps, so no game time passes and nothing is missed.
	if cutin_playing():
		if cutin.active:
			cutin.advance(delta)
		if lightning_cutin.active:
			lightning_cutin.advance(delta)
		if coil_cutin.active:
			coil_cutin.advance(delta)
		return
	# The character menu freezes the world the same way; TAB / ESC close it (the closing frame does not step either).
	if character_menu != null and character_menu.is_open:
		if not character_menu.poll_input():
			_update_hud()
		return
	if Input.is_action_just_pressed("menu_toggle") and open_menu():
		return
	if Input.is_action_just_pressed("arena_debug"):
		debug_enabled = not debug_enabled
	if snapshot.result != &"playing" and Input.is_action_just_pressed("arena_restart"):
		_restart()
	elif snapshot.result != &"playing" and persist and Input.is_action_just_pressed("menu_back"):
		change_scene.call(TITLE_SCENE)
	# Node-local mouse coordinates already account for viewport scaling and canvas transforms.
	var intent: InputFrame = Bindings.read_frame(snapshot.player.position, Bindings.world_mouse(self))
	advance(intent)

## One core step with `intent`, then everything presentation derives from it (camera, effects, events, HUD).
func advance(intent: InputFrame) -> void:
	core.step(intent)
	snapshot = core.snapshot()
	_update_camera(false)
	_age_effects()
	prepare_visuals()
	for event: GameEvent in core.last_events:
		_on_event(event)
	_update_hud()
	queue_redraw()

## Opens the character menu; refused during a cut-in and on the result screen. Returns true if it opened.
func open_menu() -> bool:
	if character_menu == null or character_menu.is_open or cutin_playing() or snapshot.result != &"playing":
		return false
	character_menu.open()
	_update_hud()
	return true

func close_menu() -> void:
	if character_menu != null and character_menu.is_open:
		character_menu.close()
		_update_hud()

## The character menu's equip request: one core step whose only intent is InputFrame.weapon_equip. The core applies
## or refuses it under the swap rules; the menu reads the result from the snapshot.
func request_equip(weapon: StringName) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_equip = weapon
	advance(frame)
	save_loadout()
	if snapshot.result != &"playing":
		close_menu()

## The menu's aspect request: one core step whose only intent is InputFrame.aspect_equip + aspect_equip_slot (the core
## applies it, swapping slots when the aspect is already slotted, or refuses it); the menu reads the snapshot.
func request_aspect_equip(aspect: StringName, slot: int) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.aspect_equip = aspect
	frame.aspect_equip_slot = slot
	advance(frame)
	save_loadout()
	if snapshot.result != &"playing":
		close_menu()

## Writes the equipped weapon and aspects into the profile (only when progress is saved) so the next fight starts with
## them (GameCore.apply_profile on load and restart).
func save_loadout() -> void:
	if not persist or profile == null or snapshot == null:
		return
	if profile.weapon_id == snapshot.player.weapon_id and profile.equipped_aspects == snapshot.player.equipped_aspects:
		return
	profile.weapon_id = snapshot.player.weapon_id
	profile.equipped_aspects = snapshot.player.equipped_aspects.duplicate()
	SaveStore.save(profile)

## Starts the current core with the saved loadout (weapon and aspects); nothing without a profile.
func apply_loadout() -> void:
	if profile == null:
		return
	core.apply_profile(profile)
	snapshot = core.snapshot()
	prepare_visuals()

func _begin_persistence() -> void:
	persist = Engine.has_meta(&"totoy_persist")
	if persist:
		profile = SaveStore.load_profile()
		profile.record_run_started()
		SaveStore.save(profile)
		apply_loadout()

func _record_result(event: GameEvent) -> void:
	if not persist or profile == null:
		return
	new_best = profile.record_result(StringName(event.data["result"]), core.tick)
	SaveStore.save(profile)
	var lines: Array[String] = []
	if event.data["result"] == &"victory":
		lines.append("TIME " + Hud.format_ticks(core.tick))
		lines.append("NEW BEST!" if new_best else "BEST " + Hud.format_ticks(profile.best_victory_ticks))
	hud.result_lines = lines
	hud.result_hint = "ESC: TITLE"

## Follows the player on a fixed 320x180 screen, locked to the player's own rounded position (the same rounding the
## sprite uses), so the player never wobbles against the screen. No smoothing or boss lean: both made the view shake.
## Never shows anything outside the arena.
func _update_camera(_snap: bool) -> void:
	if camera == null or snapshot == null:
		return
	camera_focus = snapshot.player.position.round()
	var half: Vector2 = VIEW_SIZE * 0.5
	view_origin = (camera_focus - half).clamp(Vector2.ZERO, Tuning.ARENA_SIZE - VIEW_SIZE)
	camera.position = view_origin + half

func _restart() -> void:
	new_best = false
	hud.result_lines = []
	if persist and profile != null:
		profile.record_run_started()
		SaveStore.save(profile)
	buff_events.clear()
	buff_transition.clear()
	if cutin != null:
		cutin.stop()
	if lightning_cutin != null:
		lightning_cutin.stop()
	if coil_cutin != null:
		coil_cutin.stop()
	close_menu()
	lightning_fx.clear()
	coil_fx.clear()
	aspect_fx.clear()
	wes_fx.clear()
	sprint_trail.clear()
	hero_moving = false
	hero_hidden_until = -1
	ward_absorb_tick = -1000
	echo_hit_pending = false
	coil_hook_tick = -1
	drag_started.clear()
	screen_flashes.clear()
	combat_audio.reset()
	combat_audio.set_music_active(true)
	previous_combo_index = 0
	previous_skill_id = &""
	core = GameCore.new(17)
	if persist and profile != null:
		core.apply_profile(profile)
	snapshot = core.snapshot()
	decor = ArenaDecor.build(core.obstacles)
	_update_camera(true)
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
				# the HUD lives in screen space: convert the boss's head from world to screen coordinates
				hud.track_head(HeadAnchors.world(actor.position, frames[chosen], head_anchors[chosen], mirrored) - view_origin, snapshot.tick, actor.id, actor.position.round() - view_origin)
	hud.snapshot = snapshot
	hud.colors = colors
	hud.debug_enabled = debug_enabled
	hud.menu_open = character_menu != null and character_menu.is_open
	hud.prepare_portrait()
	hud.track_health()
	hud.queue_redraw()
	if character_menu != null:
		character_menu.snapshot = snapshot
		character_menu.colors = colors
		character_menu.atlas = sprites
		character_menu.frames = frames
		character_menu.queue_redraw()

func _age_effects() -> void:
	var cosmetic_tick: int = snapshot.tick + snapshot.result_ticks
	for index: int in range(skill_trails.size() - 1, -1, -1):
		if cosmetic_tick - int(skill_trails[index]["tick"]) >= SkillEffects.TRAIL_TICKS:
			skill_trails.remove_at(index)
	if not snapshot.player.invulnerable:
		hurt_blink = false
	age_hero_fx()
	for i: int in range(lightning_fx.size() - 1, -1, -1):
		if cosmetic_tick - int(lightning_fx[i]["tick"]) >= int(lightning_fx[i]["life"]):
			lightning_fx.remove_at(i)
	for i: int in range(coil_fx.size() - 1, -1, -1):
		if cosmetic_tick - int(coil_fx[i]["tick"]) >= int(coil_fx[i]["life"]):
			coil_fx.remove_at(i)
	for id: int in flashes.keys():
		flashes[id] = int(flashes[id]) - 1
		if int(flashes[id]) <= 0:
			flashes.erase(id)
	for index: int in range(trails.size() - 1, -1, -1):
		trails[index]["life"] -= 1
		if trails[index]["life"] <= 0:
			trails.remove_at(index)

func _on_event(event: GameEvent) -> void:
	combat_audio.handle_event(event)
	match event.type:
		&"weapon_buff_started", &"weapon_buff_ended":
			var buff: Dictionary = on_hero_weapon_buff(event)
			if buff.is_empty():
				return
			# Each active plays its own cut-in: Lightning Form, Reaper's Coil, else the katana's Black Form.
			if buff["started"]:
				if buff["form"] == Weapons.FORM_LIGHTNING and lightning_cutin != null:
					lightning_cutin.start()
				elif buff["form"] == Weapons.FORM_REAPER_COIL and coil_cutin != null:
					coil_cutin.start()
				elif buff["form"] not in [Weapons.FORM_LIGHTNING, Weapons.FORM_REAPER_COIL] and cutin != null:
					cutin.start()
			combat_audio.cue("weapon_buff_start" if buff["started"] else "weapon_buff_end", event.tick)
		&"lightning_blink":
			_on_lightning_blink(event)
		&"lightning_strike":
			_on_lightning_strike(event)
		&"reaper_coil_started", &"reaper_coil_hooked", &"reaper_coil_missed", &"reaper_coil_drag", &"reaper_coil_spin", &"reaper_coil_ended":
			_on_reaper_coil(event)
		&"lantern_placed", &"lantern_pulse", &"lantern_expired", &"phantom_cut_started", &"phantom_cut_ended", &"phantom_echo":
			_on_aspect_event(event)
		&"sprint_started", &"sprint_ended", &"echo_placed", &"echo_recall", &"echo_expired", &"ward_raised", &"ward_blocked", &"ward_released":
			_on_ward_echo_sprint(event)
		&"lightning_barrage_ended":
			# The barrage's slashes and finisher draw from lightning_blink / attack_hit / lightning_strike; only a small
			# discharge marks the hero getting control back.
			if event.data.get("reason", &"") == &"complete":
				_burst(snapshot.player.position - Vector2(0, 12), 8, colors["o"], 0.7)
		&"damage_taken":
			reactions[int(event.data["entity_id"])] = {"pose": "hurt", "tick": snapshot.tick, "duration": 12}
			# Barrage slashes land every few ticks: a short flash so the boss does not stay a white silhouette.
			var flash_ticks: int = LightningEffects.BARRAGE_HIT_FLASH_TICKS if snapshot.player.state == &"lightning_barrage" else 6
			if echo_hit_pending:
				# a Phantom echo: a lighter flash and a shorter recoil than a real hit
				echo_hit_pending = false
				flash_ticks = AspectEffects.ECHO_FLASH_TICKS
				reactions[int(event.data["entity_id"])]["duration"] = AspectEffects.ECHO_RECOIL_TICKS
			flashes[int(event.data["entity_id"])] = maxi(flash_ticks, int(flashes.get(int(event.data["entity_id"]), 0)))
			if int(event.data["entity_id"]) == snapshot.player.id:
				hurt_blink = true
			_sound_damage_taken(event)
		&"parry_succeeded":
			var perfect: bool = event.data["quality"] == &"perfect"
			var contact: Vector2 = _impact_contact(event.data["position"], int(event.data["player_id"]), int(event.data["attacker_id"]))
			on_hero_parry(event.tick, event.data["position"], contact, perfect)
			selected_frames[snapshot.player.id] = _resolve_frame(ArenaAnimation.hero_frame(ArenaAnimation.hero_set(snapshot.player), "parry", 6), snapshot.player)
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
			on_hero_skill_event(event)
			combat_audio.cue("skill_" + String(event.data["skill_id"]), event.tick)
		&"skill_released":
			if not on_hero_skill_event(event):
				return
			combat_audio.cue("release_" + String(event.data["skill_id"]), event.tick)
		&"dash_started":
			_sound_dash_started(event)
		&"attack_hit":
			if bool(event.data.get("echo", false)):
				# A Phantom echo is not a swing: no hit burst, shake, finisher, lightning spark or hit sound here (its own
				# light effects come from phantom_echo).
				echo_hit_pending = true
				return
			var counter: bool = event.data["kind"] == &"counter"
			if int(event.data["attacker_id"]) == snapshot.player.id:
				var contact: Vector2 = _impact_contact(event.data["position"], int(event.data["target_id"]), int(event.data["attacker_id"]))
				# A Stone Ward release is a skill hit, not a swing (no combo index, no swing sound): a heavy burst on the boss.
				var ward_release: bool = bool(event.data.get("ward_release", false))
				if ward_release:
					for actor: Snapshots.EntitySnapshot in snapshot.entities:
						if actor.id == int(event.data["target_id"]):
							contact = boss_core_position(actor)
				var finisher: bool = _is_finisher(event) or event.data.get("skill_id", &"") == &"moon_cleave" or ward_release
				on_hero_hit(event.tick, event.data["position"], contact, counter, finisher, event.data.get("skill_id", event.data.get("aspect_id", &"")))
				if snapshot.player.weapon_form == Weapons.FORM_LIGHTNING:
					_add_lightning_fx({"kind": "spark", "tick": event.tick, "at": contact, "life": LightningEffects.sequence_length(LightningEffects.SPARK_TICKS)})
				if counter:
					flashes[int(event.data["target_id"])] = 10
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
		&"game_result":
			_sound_game_result(event)
			_record_result(event)

## The last swing of the weapon's combo (katana 3, dagger 4, scythe 3), the Lightning Barrage's last slash, or a
## Reaper's Coil spin hit.
func _is_finisher(event: GameEvent) -> bool:
	if event.data.has("reaper_coil_hit"):
		return true
	if event.data.has("barrage_slash"):
		return int(event.data["barrage_slash"]) >= Weapons.barrage_slashes()
	if not event.data.has("combo_index"):
		return false
	return int(event.data["combo_index"]) >= Weapons.combo_max(StringName(event.data.get("weapon_id", snapshot.player.weapon_id)))

func _add_lightning_fx(effect: Dictionary) -> void:
	lightning_fx.append(effect)

## Lightning Form blink: the player snapshot already stands at `to`. Departure burst and afterimage at `from`, a
## chain bolt from `from` to `to`, an arrival burst, then the cut through the boss once the swing's windup is over.
func _on_lightning_blink(event: GameEvent) -> void:
	var from: Vector2 = event.data["from"]
	var to: Vector2 = event.data["to"]
	var side: int = int(event.data.get("direction_index", 0))
	var target: Vector2 = to - Weapons.blink_direction(side) * Tuning.LIGHTNING_BLINK_DISTANCE
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if actor.id == int(event.data.get("target_id", -1)):
			target = actor.position
	var windup: int = Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS  # a barrage slash lands this many ticks after its blink
	var tick: int = event.tick
	var depart_left: bool = from.x > to.x if absf(from.x - to.x) > 2.0 else facing_left
	_add_lightning_fx({"kind": "depart", "tick": tick, "at": from, "life": LightningEffects.sequence_length(LightningEffects.DEPART_TICKS)})
	_add_lightning_fx({"kind": "afterimage", "tick": tick, "at": from, "left": depart_left, "life": LightningEffects.sequence_length(LightningEffects.AFTERIMAGE_TICKS)})
	if not event.data.has("barrage_slash"):  # barrage blinks cross the boss: their midpoint is the boss itself
		_add_lightning_fx({"kind": "afterimage", "tick": tick, "at": from.lerp(to, 0.5), "left": depart_left, "flicker": true, "life": LightningEffects.sequence_length(LightningEffects.AFTERIMAGE_TICKS)})
	_add_lightning_fx({"kind": "chain", "tick": tick, "from": from + LightningEffects.CHEST, "to": to + LightningEffects.CHEST, "life": LightningEffects.CHAIN_TICKS})
	_add_lightning_fx({"kind": "arrive", "tick": tick, "at": to, "life": LightningEffects.sequence_length(LightningEffects.BLINK_TICKS)})
	_add_lightning_fx({"kind": "cut", "tick": tick + windup, "at": (target + LightningEffects.BOSS_BODY).round(), "direction": LightningEffects.cut_direction(side, to, target), "life": LightningEffects.sequence_length(LightningEffects.CUT_TICKS)})
	shake_left = maxi(shake_left, 2)
	_flash(tick, colors["p"], [0.14])
	combat_audio.cue("lightning_blink", tick, 0.6)

## Dual Dagger finisher: a bolt from the sky onto the boss (the event position), white flash, shake, scorch decal.
## The boss's own hit flash and hurt pose come from its damage_taken event as for any hit.
func _on_lightning_strike(event: GameEvent) -> void:
	var at: Vector2 = event.data["position"]
	var tick: int = event.tick
	_add_lightning_fx({"kind": "ground", "tick": tick, "at": at, "life": LightningEffects.sequence_length(LightningEffects.GROUND_TICKS)})
	_add_lightning_fx({"kind": "strike", "tick": tick, "at": at, "life": LightningEffects.sequence_length(LightningEffects.STRIKE_TICKS)})
	_add_lightning_fx({"kind": "spark", "tick": tick + 2, "at": at + LightningEffects.BOSS_BODY, "life": 2 + LightningEffects.sequence_length(LightningEffects.SPARK_TICKS)})
	hit_bursts.append({"position": at, "contact": at + LightningEffects.BOSS_BODY, "tick": tick, "counter": event.data.get("kind", &"normal") == &"counter", "finisher": true, "skill_id": &"", "facing": snapshot.player.facing})
	var strengths: Array[float] = []
	for age: int in range(4):
		strengths.append(LightningEffects.strike_flash(age))
	_flash(tick, colors["p"], strengths)
	shake_left = maxi(shake_left, 8)
	_burst(at + LightningEffects.BOSS_BODY, 18, colors["1"], 1.6)
	combat_audio.cue("lightning_crack", tick)

func _add_coil_fx(effect: Dictionary) -> void:
	ScytheEffects.add(coil_fx, effect)

## The boss snapshot with this id (or the first entity).
func _entity(id: int) -> Snapshots.EntitySnapshot:
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if actor.id == id:
			return actor
	return snapshot.entities[0] if not snapshot.entities.is_empty() else null

## Reaper's Coil, from the core's events only (the chain itself is drawn from the snapshot every frame):
## throw: a whoosh; hooked: a clink at the bite with shake and flash; missed: a poof where the hook lands (the hero is
## then pulled there); drag end: the stagger burst on the golem's chest; spin: a whoosh per pass, sparks and a flash
## when it connects; end: a small burst. Sounds reuse the combat cues (no new audio).
func _on_reaper_coil(event: GameEvent) -> void:
	var tick: int = event.tick
	match event.type:
		&"reaper_coil_started":
			combat_audio.cue("chain_coil", tick, 1.0)
		&"reaper_coil_hooked":
			coil_hook_tick = tick
			var bite: Vector2 = Vector2(event.data["to"]) + CHAIN_HEIGHT
			_add_coil_fx({"kind": "hook", "tick": tick, "at": bite.round(), "life": ScytheEffects.sequence_length(ScytheEffects.HOOK_TICKS)})
			_burst(bite, 10, colors["u"], 1.0)
			shake_left = maxi(shake_left, 3)
			_flash(tick, colors["p"], [0.16, 0.06])
			combat_audio.cue("deflect", tick, 0.9)
			combat_audio.cue("dash", tick, 0.7)
		&"reaper_coil_missed":
			var anchor: Vector2 = event.data["to"]
			_add_coil_fx({"kind": "land", "tick": tick, "at": anchor.round(), "life": ScytheEffects.sequence_length(ScytheEffects.LAND_TICKS)})
			if event.data.get("blocked_by", &"range") != &"range":
				_add_coil_fx({"kind": "spark", "tick": tick, "at": (anchor + CHAIN_HEIGHT).round(), "life": ScytheEffects.sequence_length(ScytheEffects.SPARK_TICKS)})
			_dust(anchor)
			shake_left = maxi(shake_left, 1)
			combat_audio.cue("deflect", tick, 0.5)
			combat_audio.cue("dash", tick, 0.7)
		&"reaper_coil_drag":
			var boss: Snapshots.EntitySnapshot = _entity(int(event.data.get("target_id", -1)))
			var chest: Vector2 = boss_core_position(boss) if boss != null else Vector2(event.data["to"]) + ScytheEffects.BOSS_BODY
			_add_coil_fx({"kind": "stagger", "tick": tick, "at": chest.round(), "life": ScytheEffects.sequence_length(ScytheEffects.STAGGER_TICKS)})
			_burst(chest, 14, colors["p"], 1.2)
			shake_left = maxi(shake_left, 5)
			combat_audio.cue("posture_break", tick)
		&"reaper_coil_spin":
			var connects: bool = bool(event.data.get("connects", false))
			combat_audio.cue("swing", tick, 1.0 if connects else 0.7)
			if connects:
				for actor: Snapshots.EntitySnapshot in snapshot.entities:
					var contact: Vector2 = boss_core_position(actor)
					_add_coil_fx({"kind": "spark", "tick": tick, "at": contact.round(), "life": ScytheEffects.sequence_length(ScytheEffects.SPARK_TICKS)})
				shake_left = maxi(shake_left, 2)
				_flash(tick, colors["p"], [0.12])
		&"reaper_coil_ended":
			if event.data.get("reason", &"") in [&"complete", &"missed"]:
				_burst(snapshot.player.position - Vector2(0, 12), 6, colors["u"], 0.6)

## Per fresh tick while the boss is dragged: dust puffs at its leading foot and scuff decals where it slid.
func _coil_drag_trail() -> void:
	var hero: Snapshots.EntitySnapshot = snapshot.player
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if not actor.dragged:
			drag_started.erase(actor.id)
			continue
		if not drag_started.has(actor.id):
			drag_started[actor.id] = snapshot.tick
		var toward_right: bool = hero.position.x > actor.position.x
		var tick: int = snapshot.tick - int(drag_started[actor.id])  # from the hook tick: a short drag still leaves marks
		if tick % ScytheEffects.DUST_EVERY == 0:
			_add_coil_fx({"kind": "dust", "tick": snapshot.tick, "at": (actor.position + Vector2(12 if toward_right else -12, 0)).round(), "left": toward_right, "life": ScytheEffects.sequence_length(ScytheEffects.DUST_TICKS)})
		if tick % ScytheEffects.SCUFF_EVERY == 0:
			_add_coil_fx({"kind": "scuff", "tick": snapshot.tick, "at": actor.position.round(), "left": toward_right, "life": ScytheEffects.sequence_length(ScytheEffects.SCUFF_TICKS)})

func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	# A uniform transform shakes floor, actors and tells together, preserving alignment.
	var offset: Vector2 = shake_offset()
	draw_set_transform(offset)
	draw_rect(Rect2(-2, -2, Tuning.ARENA_SIZE.x + 4.0, Tuning.ARENA_SIZE.y + 4.0), colors["2"])
	draw_texture(ground_texture, Vector2.ZERO, GROUND_MODULATE)
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
	_draw_lightning_ground()
	_draw_coil_ground()
	_draw_lantern_ground()
	_draw_ward_echo_ground()
	_draw_dash()
	var actors: Array[Snapshots.EntitySnapshot] = [snapshot.player]
	actors.append_array(snapshot.entities)
	actors.sort_custom(_behind)
	var drawables: Array[Dictionary] = []
	var view: Rect2 = Rect2(view_origin - Vector2(90, 90), VIEW_SIZE + Vector2(180, 200))  # a margin for tall props
	for decoration: Dictionary in decor:
		if view.has_point(decoration["at"]):
			drawables.append(decoration)
	for obstacle: Snapshots.ObstacleSnapshot in snapshot.obstacles:
		if obstacle.visual_id != &"" and view.has_point(obstacle.feet):
			drawables.append({"name": String(obstacle.visual_id), "at": obstacle.feet, "scale": Vector2(obstacle.visual_scale, obstacle.visual_scale)})
	drawables.append_array(lantern_drawables())
	drawables.append_array(echo_drawables())
	for actor: Snapshots.EntitySnapshot in actors:
		drawables.append({"actor": actor, "at": actor.position})
	# the painted pillars, statue, altar, trees, ... over actors standing behind them (sort key: their base line)
	drawables.append_array(DepthOccluders.drawables(OCCLUDER_SCENE, {}, view))
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["at"]).y < Vector2(b["at"]).y)
	for item: Dictionary in drawables:
		if item.has("actor"):
			_draw_actor(item["actor"])
		elif item.has("occluder"):
			DepthOccluders.draw(self, OCCLUDER_SCENE, item, GROUND_MODULATE)
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
	for t: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if not TelegraphView.warning_visible(t, snapshot.tick):
			continue
		_draw_imported("ui_warning_%s_%d" % ["gold" if t.kind == &"gold" else "red", 1 + (snapshot.tick / 12) % 2], TelegraphView.marker_position(t), Vector2(0.5, 0.5))
	draw_hero_impacts()
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
	_draw_lightning(offset)
	_draw_scythe(offset)
	_draw_aspects_front()
	_draw_ward_echo_front(offset)
	if debug_enabled:
		draw_circle(snapshot.player.position, Tuning.PLAYER_RADIUS, colors["p"], false, 1.0)
		for actor: Snapshots.EntitySnapshot in snapshot.entities:
			draw_circle(actor.position, Tuning.BOSS_RADIUS, colors["p"], false, 1.0)
		# aim check: a line from the player along the core's facing, and a cross where the mouse is in the world
		draw_line(snapshot.player.position, snapshot.player.position + snapshot.player.facing * 60.0, colors["p"], 1.0)
		var mouse: Vector2 = get_local_mouse_position()
		draw_line(mouse - Vector2(4, 0), mouse + Vector2(4, 0), colors["p"], 1.0)
		draw_line(mouse - Vector2(0, 4), mouse + Vector2(0, 4), colors["p"], 1.0)
	draw_set_transform(Vector2.ZERO)
	draw_hero_screen_flashes(view_origin, VIEW_SIZE)

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
			combat_audio.cue("swing", snapshot.tick, 1.0 if hero.combo_index >= Weapons.combo_max(hero.weapon_id) else 0.75)
		var coiling: bool = hero.state == PlayerState.STATE_REAPER_COIL  # faces the chain's direction (core facing)
		var warding: bool = hero.state == PlayerState.STATE_WARD  # the ward's facing is locked by the core
		var was_left: bool = facing_left
		if ((moved and hero.state != &"dead") or attack_started or coiling or warding or hero.state.begins_with("skill_")) and absf(hero.facing.x) > 0.3:
			facing_left = hero.facing.x < 0.0
		var gale_travel: bool = hero.skill_id == &"gale_cut" and previous_skill_id == &"gale_cut" and moved and (hero.state == &"skill_active" or (previous_player_state == &"skill_active" and hero.state == &"skill_recovery"))
		if gale_travel:
			skill_trails.append({"from": previous_player_position, "to": hero.position, "tick": snapshot.tick})
		# the shared part: afterimages, dust and the Sprint trail (previous_player_position is updated inside)
		_motion_seen = visual_tick >= 0 and selected_frames.has(hero.id)
		track_hero_motion(moved, previous_player_state, was_left, gale_travel)
		_coil_drag_trail()
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
					requested = ArenaAnimation.hero_frame(ArenaAnimation.hero_set(actor), "parry", 6)
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
				if actor.id == snapshot.player.id:
					requested = ArenaAnimation.hero_frame(ArenaAnimation.hero_set(actor), pose, ArenaAnimation.frame_index(spec, age))
				else:
					requested = "golem2_%s_%d" % [pose, ArenaAnimation.frame_index(spec, age)]
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

func _draw_actor(actor: Snapshots.EntitySnapshot, silhouette_only: bool = false) -> void:
	if actor.id == snapshot.player.id and hero_hidden():
		return  # an Echo Step arrival's first frame: only the echo flares
	var chosen: String = String(selected_frames.get(actor.id, ""))
	var at: Vector2 = actor.position.round()
	var radius: float = 10.0 if actor.visual_id == &"totoy" else 20.0
	if not silhouette_only:
		ActorShadow.draw(self, at, radius, ActorShadow.strength_for(OCCLUDER_SCENE))
	if not frames.has(chosen):
		draw_rect(Rect2(at - Vector2(radius, radius * 2), Vector2(radius * 2, radius * 2)), colors["g"])
		return
	var frame: Dictionary = frames[chosen]
	var left: bool = facing_left if actor.visual_id == &"totoy" else ArenaAnimation.boss_mirrored(actor, snapshot, last_attacks.get(actor.id, {}))
	var destination: Rect2 = ArenaAnimation.destination(at, frame, left)
	if not silhouette_only:
		if actor.id == snapshot.player.id:
			draw_hero_back(actor, chosen, at, left)
			_draw_spin_ring(actor, false)
		var actor_texture: Texture2D = empowered_sprites if actor.id == snapshot.player.id and black_form_look(actor) else sprites
		draw_texture_rect_region(actor_texture, destination, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
		if actor.id == snapshot.player.id:
			_draw_phantom_glow(actor, chosen, at, left)
			_draw_hero_aspect_overlays(actor, chosen, at, left)
	if silhouette_only:
		draw_texture_rect_region(white_sprites, destination, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	if not silhouette_only and actor.id == snapshot.player.id:
		_draw_buff_aura(actor, true)
		_draw_spin_ring(actor, true)

func fx_hero_frame() -> String:
	return String(selected_frames.get(snapshot.player.id, ""))


func _draw_dash() -> void:
	draw_dash_fx()

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
		var heavy: bool = event.data["kind"] == &"counter" or _is_finisher(event) or event.data.get("skill_id", &"") in [&"moon_cleave", &"breaking_edge"] or bool(event.data.get("ward_release", false))
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


## Scorch decals of sky strikes, on the floor under everything standing.
func _draw_lightning_ground() -> void:
	var cosmetic_tick: int = snapshot.tick + snapshot.result_ticks
	for effect: Dictionary in lightning_fx:
		if effect["kind"] == "ground":
			var frame: int = LightningEffects.sequence_frame(LightningEffects.GROUND_TICKS, cosmetic_tick - int(effect["tick"]))
			if frame > 0:
				_draw_imported("fx_lightning_ground_%d" % frame, effect["at"], Vector2(2, 2))

## Blink bursts, afterimages, chain bolts, the cut through the boss, sparks and the sky strike (world space).
func _draw_lightning(shake_offset: Vector2) -> void:
	var cosmetic_tick: int = snapshot.tick + snapshot.result_ticks
	for effect: Dictionary in lightning_fx:
		var age: int = cosmetic_tick - int(effect["tick"])
		match String(effect["kind"]):
			"afterimage":
				var frame: int = LightningEffects.sequence_frame(LightningEffects.AFTERIMAGE_TICKS, age)
				if frame > 0 and not (bool(effect.get("flicker", false)) and age % 2 == 1):
					var key: String = "fx_lightning_afterimage_%d" % frame
					if frames.has(key):
						var f: Dictionary = frames[key]
						draw_texture_rect_region(sprites, ArenaAnimation.destination(effect["at"], f, bool(effect["left"])), Rect2(f["x"], f["y"], f["w"], f["h"]))
			"chain":
				var from: Vector2 = effect["from"]
				var to: Vector2 = effect["to"]
				var angle: float = (to - from).angle()
				var segments: Array[Dictionary] = LightningEffects.chain_segments(from, to)
				for index: int in range(segments.size()):
					var frame: int = LightningEffects.chain_frame(age, index)
					var key: String = "fx_lightning_chain_%d" % frame
					if frame == 0 or not frames.has(key):
						continue
					var f: Dictionary = frames[key]
					var length: float = float(segments[index]["length"])
					draw_set_transform(from.round() + shake_offset, angle)
					draw_texture_rect_region(sprites, Rect2(Vector2(float(segments[index]["offset"]), -float(f["ay"])), Vector2(length, f["h"])), Rect2(f["x"], f["y"], length, f["h"]))
					draw_set_transform(shake_offset)
			"depart":
				var frame: int = LightningEffects.sequence_frame(LightningEffects.DEPART_TICKS, age)
				if frame > 0:
					_draw_imported("fx_lightning_blink_%d" % frame, effect["at"])
			"arrive":
				var frame: int = LightningEffects.sequence_frame(LightningEffects.BLINK_TICKS, age)
				if frame > 0:
					_draw_imported("fx_lightning_blink_%d" % frame, effect["at"])
			"cut":
				var frame: int = LightningEffects.sequence_frame(LightningEffects.CUT_TICKS, age)
				if frame > 0:
					_draw_imported(LightningEffects.cut_key(int(effect["direction"]), frame), effect["at"])
			"spark":
				var frame: int = LightningEffects.sequence_frame(LightningEffects.SPARK_TICKS, age)
				if frame > 0:
					_draw_imported("fx_lightning_spark_%d" % frame, effect["at"])
			"strike":
				var frame: int = LightningEffects.sequence_frame(LightningEffects.STRIKE_TICKS, age)
				if frame > 0:
					var at: Vector2 = effect["at"]
					var scale_px: int = LightningEffects.strike_scale(at.y - view_origin.y)
					_draw_imported("fx_lightning_strike_%d" % frame, at, Vector2(scale_px, scale_px))


# ---------------------------------------------------------------- Chain Scythe / Reaper's Coil (world space)

## The spin ring around the hero: the back half before the sprite, the front half after it.
func _draw_spin_ring(actor: Snapshots.EntitySnapshot, front: bool) -> void:
	if actor.state != PlayerState.STATE_REAPER_COIL or actor.reaper_coil_phase != PlayerState.COIL_SPIN:
		return
	var ring: int = ScytheEffects.ring_phase(actor.reaper_coil_phase_tick)
	if ring > 0:
		_draw_anchored("fx_scythe_spin_%s_%d" % ["front" if front else "back", ring], actor.position, facing_left)

## Where the chain leaves the fist this frame (world), from the frame's chain_origin (mirrored when facing left).
func chain_hand() -> Vector2:
	var hero: Snapshots.EntitySnapshot = snapshot.player
	var origin: Vector2 = chain_origins.get(String(selected_frames.get(hero.id, "")), ScytheEffects.DEFAULT_HAND)
	if facing_left:
		origin.x = -origin.x
	return hero.position.round() + origin

## Where the chain ends (world): the flying tip or the bite on the golem at chain height, the anchor on the ground.
func chain_tip() -> Vector2:
	var hero: Snapshots.EntitySnapshot = snapshot.player
	var tip: Vector2 = hero.reaper_coil_target.round()
	return tip if hero.reaper_coil_phase == PlayerState.COIL_PULL else tip + CHAIN_HEIGHT

## The swing arc of a scythe swing in progress (empty when none), anchored at the hero's feet.
func scythe_arc_effect() -> Dictionary:
	if snapshot.result != &"playing":
		return {}
	var key: String = ScytheEffects.arc_key(snapshot.player)
	if key.is_empty() or not String(selected_frames.get(snapshot.player.id, "")).begins_with(ArenaAnimation.SET_SCYTHE + "_attack"):
		return {}
	return {"key": key, "at": snapshot.player.position.round(), "left": facing_left}

## Scuff decals of the drag, on the floor under everything standing.
func _draw_coil_ground() -> void:
	var cosmetic_tick: int = snapshot.tick + snapshot.result_ticks
	for effect: Dictionary in coil_fx:
		if effect["kind"] == "scuff":
			var frame: int = ScytheEffects.sequence_frame(ScytheEffects.SCUFF_TICKS, cosmetic_tick - int(effect["tick"]))
			if frame > 0:
				_draw_imported("fx_chain_scuff_%d" % frame, effect["at"], Vector2(-1 if bool(effect["left"]) else 1, 1))

## Swing arcs, the chain with its flying head, the pull streaks on a dragged golem, dizzy stars over a stunned one, and
## the event sequences (clink, poof, stagger burst, sparks, dust).
func _draw_scythe(shake_offset: Vector2) -> void:
	# Regular swing trails are drawn by shared draw_hero_back in both the arena and exploration.
	# Keep only the skill's chain/hook/spin effects here, avoiding an extra arena-only arc over the shared trail.
	var hero: Snapshots.EntitySnapshot = snapshot.player
	var cosmetic_tick: int = snapshot.tick + snapshot.result_ticks
	for actor: Snapshots.EntitySnapshot in snapshot.entities:
		if actor.dragged:
			_draw_imported("fx_chain_pull_%d" % ScytheEffects.pull_frame(snapshot.tick), actor.position.round(), Vector2(-1 if hero.position.x > actor.position.x else 1, 1))
		elif actor.state == &"staggered" and actor.stagger_ticks_left > 0:
			var key: String = String(selected_frames.get(actor.id, ""))
			var head: Vector2 = actor.position + Vector2(0, -44)
			if frames.has(key) and head_anchors.has(key):
				head = HeadAnchors.world(actor.position, frames[key], head_anchors[key], ArenaAnimation.boss_mirrored(actor, snapshot, last_attacks.get(actor.id, {})))
			_draw_imported("fx_chain_stars_%d" % ScytheEffects.stars_frame(snapshot.tick), (head + Vector2(0, -2)).round())
	if ScytheEffects.chain_visible(hero):
		var from: Vector2 = chain_hand()
		var to: Vector2 = chain_tip()
		var line: Vector2 = to - from
		var segments: Array[Dictionary] = ScytheEffects.chain_segments(line.length())
		for index: int in range(segments.size()):
			var key: String = "fx_chain_link_%d" % ScytheEffects.link_frame(index, segments.size(), snapshot.tick, hero.reaper_coil_phase, snapshot.tick == coil_hook_tick)
			if not frames.has(key):
				continue
			var f: Dictionary = frames[key]
			var length: float = float(segments[index]["length"])
			draw_set_transform(from + shake_offset, line.angle())
			draw_texture_rect_region(sprites, Rect2(Vector2(float(segments[index]["offset"]), -float(f["ay"])), Vector2(length, f["h"])), Rect2(f["x"], f["y"], length, f["h"]))
			draw_set_transform(shake_offset)
		# the scythe at the chain's end: tumbling while it flies, biting along the chain once it holds
		var frame: int = posmod(snapshot.tick, 8) + 1 if hero.reaper_coil_phase == PlayerState.COIL_HOOK else ScytheEffects.flying_frame(line)
		if line.length() > 2.0:
			_draw_imported("fx_scythe_flying_%d" % frame, to)
	for effect: Dictionary in coil_fx:
		var age: int = cosmetic_tick - int(effect["tick"])
		match String(effect["kind"]):
			"hook":
				var frame: int = ScytheEffects.sequence_frame(ScytheEffects.HOOK_TICKS, age)
				if frame > 0:
					_draw_imported("fx_chain_hook_%d" % frame, effect["at"])
			"land":
				var frame: int = ScytheEffects.sequence_frame(ScytheEffects.LAND_TICKS, age)
				if frame > 0:
					_draw_imported("fx_chain_land_%d" % frame, effect["at"])
			"stagger":
				var frame: int = ScytheEffects.sequence_frame(ScytheEffects.STAGGER_TICKS, age)
				if frame > 0:
					_draw_imported("fx_chain_stagger_%d" % frame, effect["at"])
			"spark":
				var frame: int = ScytheEffects.sequence_frame(ScytheEffects.SPARK_TICKS, age)
				if frame > 0:
					_draw_imported("fx_chain_hook_%d" % (frame + 3), effect["at"])
			"dust":
				var frame: int = ScytheEffects.sequence_frame(ScytheEffects.DUST_TICKS, age)
				if frame > 0:
					_draw_imported("fx_chain_dust_%d" % frame, effect["at"], Vector2(-1 if bool(effect["left"]) else 1, 1))


# ---------------------------------------------------------------- Spirit Lantern / Phantom Cut (world space)


# ---------------------------------------------------------------- Echo Step / Stone Ward / Sprint (world space)
# Every draw below goes through a plan (an Array of {"key", "at", "left", ...}) so the tests can check exactly what is
# drawn without a renderer. "left" mirrors a frame around its own anchor, like the hero frames.
