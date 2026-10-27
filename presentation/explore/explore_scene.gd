extends Node2D
## Exploration mode (chapter 1): draws any scene of core/scene_defs.gd from an ExploreCore snapshot and sends it the
## player's intents. The core decides movement, collisions, exits, checkpoints and interactions; this node draws the
## painted ground, the y-sorted actors (hero with the katana frames, NPCs with idle loops facing the hero when near,
## the village chest) on the shared soft ground shadow (presentation/common/actor_shadow.gd) with a per-scene ambient
## tint, the painted tall props drawn again over actors standing behind them (depth occluders,
## presentation/common/depth_occluders.gd), a 320x180 camera clamped to the scene, the HUD-lite (scene toast, interact
## hint), the 0.3 s fade between scenes, the "..." speech bubble on E, the character menu (TAB) and the debug keys
## (F1/H colliders, F2-F5 or 1-4 jump, F6/G forest gate).
##
## Start: Engine meta START_META (set by the title screen) = {scene, entry, checkpoint, gate_open}; without it the
## village arrival. Progress (scene, checkpoint, gate) is saved only when started from the title (Engine meta
## totoy_persist), through core/save_store.gd. Entering the arena (the glade's root arch or F5) loads the Colossus
## fight (presentation/arena/arena.tscn).
const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const GameCore := preload("res://core/game_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
const SaveStore := preload("res://core/save_store.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const CharacterMenu := preload("res://presentation/arena/character_menu.gd")
const ExploreHud := preload("res://presentation/explore/explore_hud.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const DepthOccluders := preload("res://presentation/common/depth_occluders.gd")
const PropScene := preload("res://core/prop_scene.gd")
const PropsLayer := preload("res://presentation/common/props_layer.gd")
const AmbientFireflies := preload("res://presentation/common/ambient_fireflies.gd")
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")

const ARENA_SCENE: String = "res://presentation/arena/arena.tscn"
const TITLE_SCENE: String = "res://presentation/menu/title.tscn"
const START_META: StringName = &"totoy_explore_start"
const PERSIST_META: StringName = &"totoy_persist"
const VIEW_SIZE: Vector2 = Vector2(320.0, 180.0)

const GROUNDS: Dictionary = {
	&"village": "res://presentation/village/village_ground.png",
	&"forest": "res://presentation/forest/forest_route_ground.png",
	&"glade": "res://presentation/forest/stag_glade_ground.png",
	&"arena": "res://presentation/arena/arena_ground.png",
}
## Per-scene ambient multiplied onto the actors (not the ground) so the sprites sit in the dusk paintings.
const AMBIENT: Dictionary = {
	&"village": Color(0.93, 0.89, 0.84),
	&"forest": Color(0.9, 0.94, 0.88),
	&"glade": Color(0.88, 0.95, 0.94),
	&"arena": Color(1, 1, 1),
	&"village_layered": Color(0.93, 0.89, 0.84),
	&"glade_layered": Color(0.88, 0.95, 0.94),
	&"forest_layered": Color(0.9, 0.94, 0.88),
}
## The actor shadow's radius for the hero (presentation/common/actor_shadow.gd draws it, the same as in the arena).
const HERO_SHADOW_RADIUS: float = 10.0
const HERO_HEIGHT: float = 34.0
## NPC sprite heights (art/reference/chapter1_characters_v2/README.md); the shadow radius scales with height / hero.
const NPC_HEIGHTS: Dictionary = {&"npc_mira": 32.0, &"npc_tovan": 31.0, &"npc_edda": 31.0, &"npc_elder": 28.0, &"npc_worker": 30.0, &"npc_child": 23.0}
const NPC_MANIFEST: String = "res://art/build/chapter1_npc_sprites_manifest.json"
const NPC_IDLE_TICKS_DEFAULT: Array = [24, 14, 14, 8]
## Fade out and fade in, each (0.3 s at 60 ticks per second).
const FADE_TICKS: int = 18
const TOAST_TICKS: int = 150
const TOAST_FADE_TICKS: int = 30
const BUBBLE_TICKS: int = 90
const HINTS: Dictionary = {&"npc": "[E] TALK", &"chest": "[E] OPEN", &"sign": "[E] READ", &"door": "[E] KNOCK", &"lantern_switch": "[E] LIGHT", &"dummy": "[E] LOOK"}
## Hints by target id where the kind's word does not fit (the root gate is a door nobody answers).
const HINT_OVERRIDES: Dictionary = {&"root_gate": "[E] LOOK"}
## The hint floats this far above an object's feet (people: their height + 8).
const OBJECT_HINT_HEIGHT: float = 30.0
const DEBUG_SCENES: Dictionary = {"debug_scene_village": &"village", "debug_scene_forest": &"forest", "debug_scene_glade": &"glade", "debug_scene_arena": &"arena", "debug_scene_village_layered": &"village_layered", "debug_scene_glade_layered": &"glade_layered", "debug_scene_forest_layered": &"forest_layered"}

var core: ExploreCore
var snapshot: ExploreCore.ExploreSnapshot
var colors: Dictionary = {}
var frames: Dictionary = {}
var sprites: Texture2D
var grounds: Dictionary = {}
var prop_placements: Array[Dictionary] = []
var lighting_enabled: bool = true
var npc_idle_ticks: Dictionary = {}
var camera: Camera2D
var view_origin: Vector2 = Vector2.ZERO
var facing_left: bool = false
var previous_hero_position: Vector2 = Vector2.INF
var hero_frame: String = ""
var npc_frames: Dictionary = {}  # npc id -> frame name drawn this tick
var bubbles: Dictionary = {}  # npc id -> ticks left
var toast_ticks: int = 0
## A message that replaces the scene name in the toast until the next scene (the gate key's feedback).
var toast_message: String = ""
var debug_enabled: bool = false
var gate_open: bool = false
## "" (no fade), "out" (to ink, then the scene changes) or "in" (from ink).
var fade_phase: StringName = &""
var fade_ticks: int = 0
var pending_scene: StringName = &""
var pending_entry: StringName = &""
var persist: bool = false
var profile: SaveProfile = null
var loadout_core: GameCore
var character_menu: CharacterMenu
var missing_frames: Dictionary = {}
var transitions: int = 0  # scene changes done (tests)
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)
@onready var hud: ExploreHud = $HUD/Display


func _ready() -> void:
	Bindings.register()
	var palette: Dictionary = _read_json("res://art/palette.json")
	for entry: Dictionary in palette.get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	frames = _read_json("res://art/build/sprites.json").get("frames", {})
	sprites = load("res://art/build/sprites.png") as Texture2D
	var manifest: Dictionary = _read_json(NPC_MANIFEST)
	var states: Dictionary = manifest.get("states", {})
	for npc_name: String in states:
		npc_idle_ticks[npc_name] = Dictionary(Dictionary(states[npc_name]).get("idle", {})).get("ticks", NPC_IDLE_TICKS_DEFAULT)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	persist = Engine.has_meta(PERSIST_META)
	profile = SaveStore.load_profile() if persist else SaveProfile.new()
	loadout_core = GameCore.new(17)
	loadout_core.apply_profile(profile)
	character_menu = CharacterMenu.new()
	character_menu.equip_request = request_equip
	character_menu.aspect_request = request_aspect_equip
	$HUD.add_child(character_menu)
	var start: Dictionary = Engine.get_meta(START_META, {}) if Engine.has_meta(START_META) else {}
	if Engine.has_meta(START_META):
		Engine.remove_meta(START_META)
	gate_open = bool(start.get("gate_open", profile.gate_open if persist else false))
	var scene: StringName = StringName(start.get("scene", SceneDefs.START_SCENE))
	if not SceneDefs.is_known(scene) or scene == SceneDefs.ARENA:
		scene = SceneDefs.START_SCENE
	enter_scene(scene, StringName(start.get("entry", &"")), StringName(start.get("checkpoint", &"")))
	fade_phase = &"in"
	fade_ticks = 0
	_update_hud()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Explore cannot open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func ground_texture(scene: StringName) -> Texture2D:
	if not grounds.has(scene):
		var path: String = String(GROUNDS.get(scene, ""))
		if path == "" and SceneDefs.LAYERED.has(scene):
			path = String(SceneDefs.layered_data(scene).get("ground", ""))
		if path != "":
			grounds[scene] = load(path) as Texture2D
	return grounds.get(scene, null)


## Builds the core of `scene` with the hero at `entry` (or on `checkpoint` when given, the CONTINUE case), shows the
## scene name and saves the scene as the current one. The arena is not explored: it loads the Colossus fight.
func enter_scene(scene: StringName, entry: StringName = &"", checkpoint: StringName = &"") -> void:
	if scene == SceneDefs.ARENA:
		_save_progress(SceneDefs.ARENA, &"ruins_gate")
		change_scene.call(ARENA_SCENE)
		return
	if checkpoint != &"" and not SceneDefs.checkpoint(scene, checkpoint).is_empty():
		core = ExploreCore.at_checkpoint(scene, checkpoint, gate_open) as ExploreCore
	else:
		core = ExploreCore.new(scene, entry, gate_open)
	snapshot = core.snapshot()
	gate_open = snapshot.gate_open
	_refresh_props()
	facing_left = snapshot.hero.facing.x < 0.0
	previous_hero_position = snapshot.hero.position
	bubbles.clear()
	npc_frames.clear()
	toast_message = ""
	toast_ticks = TOAST_TICKS
	transitions += 1
	_save_progress(scene, core.last_checkpoint)
	_choose_frames()
	_update_camera()
	queue_redraw()


func _save_progress(scene: StringName, checkpoint: StringName) -> void:
	profile.record_scene(scene, checkpoint)
	profile.gate_open = gate_open
	if persist:
		SaveStore.save(profile)


func _physics_process(_delta: float) -> void:
	if character_menu.is_open:
		if not character_menu.poll_input():
			_update_hud()
		return
	if fade_phase != &"":
		advance_fade()
		return
	if Input.is_action_just_pressed("menu_toggle") and open_menu():
		return
	if Input.is_action_just_pressed("arena_debug"):
		debug_enabled = not debug_enabled
	if Input.is_action_just_pressed("debug_lighting_toggle"):
		lighting_enabled = not lighting_enabled
		_update_lighting()
		queue_redraw()
	for action: String in DEBUG_SCENES:
		if Input.is_action_just_pressed(action):
			jump_to(DEBUG_SCENES[action])
			return
	if Input.is_action_just_pressed("debug_toggle_gate"):
		toggle_gate()
	if Input.is_action_just_pressed("menu_back"):
		change_scene.call(TITLE_SCENE)
		return
	var frame: InputFrame = Bindings.read_frame()
	frame.interact_pressed = Input.is_action_just_pressed("explore_interact")
	advance(frame)


## One core step with `intent`, then everything drawn from it.
func advance(intent: InputFrame) -> void:
	core.step(intent)
	snapshot = core.snapshot()
	gate_open = snapshot.gate_open
	for event: GameEvent in core.last_events:
		_on_event(event)
	if toast_ticks > 0:
		toast_ticks -= 1
	for id: StringName in bubbles.keys():
		bubbles[id] = int(bubbles[id]) - 1
		if int(bubbles[id]) <= 0:
			bubbles.erase(id)
	_choose_frames()
	_update_camera()
	_update_hud()
	queue_redraw()


func _on_event(event: GameEvent) -> void:
	match event.type:
		GameEvent.SCENE_EXIT:
			begin_transition(event.data["target_scene"], event.data["target_entry"])
		GameEvent.CHECKPOINT:
			_save_progress(core.scene_id, event.data["checkpoint_id"])
		GameEvent.SWITCH_LIT:
			_refresh_props()
		GameEvent.GATE_CHANGED:
			gate_open = snapshot.gate_open
			_refresh_props()
			_save_progress(core.scene_id, core.last_checkpoint)
		GameEvent.INTERACT:
			if event.data["kind"] == &"npc":
				bubbles[event.data["target_id"]] = BUBBLE_TICKS  # no dialogue yet (step 2): a placeholder "..."


## Starts the fade out; at its end the target scene is entered and the fade comes back in.
func begin_transition(scene: StringName, entry: StringName) -> void:
	pending_scene = scene
	pending_entry = entry
	fade_phase = &"out"
	fade_ticks = 0


## One tick of the fade (the world does not step while the screen fades).
func advance_fade() -> void:
	fade_ticks += 1
	if fade_phase == &"out" and fade_ticks >= FADE_TICKS:
		var scene: StringName = pending_scene
		pending_scene = &""
		if scene == SceneDefs.ARENA:
			fade_phase = &""
			enter_scene(scene)
			return
		enter_scene(scene, pending_entry)
		fade_phase = &"in"
		fade_ticks = 0
	elif fade_phase == &"in" and fade_ticks >= FADE_TICKS:
		fade_phase = &""
		fade_ticks = 0
	_update_hud()


## 0..1, how dark the screen is.
func fade_alpha() -> float:
	match fade_phase:
		&"out":
			return clampf(float(fade_ticks) / FADE_TICKS, 0.0, 1.0)
		&"in":
			return clampf(1.0 - float(fade_ticks) / FADE_TICKS, 0.0, 1.0)
	return 0.0


## Debug jump (F2-F5 or 1-4): to the scene's default entry, with the fade.
func jump_to(scene: StringName) -> void:
	begin_transition(scene, &"")


## Debug (F6 or G), later the lantern puzzle: opens or closes the forest's root gate (saved with the progress).
func toggle_gate() -> void:
	gate_open = not gate_open
	core.set_gate_open(gate_open)
	_save_progress(core.scene_id, core.last_checkpoint)
	toast_message = "ROOT GATE OPEN" if gate_open else "ROOT GATE CLOSED"
	toast_ticks = TOAST_TICKS
	snapshot = core.snapshot()
	_refresh_props()
	_update_hud()
	queue_redraw()


func toast_text() -> String:
	if snapshot == null:
		return ""
	return toast_message if toast_message != "" else snapshot.scene_name


func hint_text() -> String:
	if snapshot == null or snapshot.interact_target == &"" or snapshot.exiting or bubbles.has(snapshot.interact_target):
		return ""
	return HINT_OVERRIDES.get(snapshot.interact_target, HINTS.get(snapshot.interact_kind, "[E] LOOK"))


## Screen point above the interact target's head where the hint sits (Vector2.INF when nothing is in range).
func hint_anchor() -> Vector2:
	if snapshot == null or snapshot.interact_target == &"":
		return Vector2.INF
	var height: float = OBJECT_HINT_HEIGHT
	for npc: Dictionary in snapshot.npcs:
		if npc["id"] == snapshot.interact_target:
			height = float(NPC_HEIGHTS.get(npc["visual"], 30.0)) + 8.0
	return snapshot.interact_position.round() - view_origin - Vector2(0, height)


# --- the character menu (TAB): the loadout lives in a GameCore that is only stepped for equip requests ---

func open_menu() -> bool:
	if character_menu.is_open or fade_phase != &"":
		return false
	character_menu.open()
	_update_hud()
	return true


func request_equip(weapon: StringName) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_equip = weapon
	loadout_core.step(frame)
	_save_loadout()
	_update_hud()


func request_aspect_equip(aspect: StringName, slot: int) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.aspect_equip = aspect
	frame.aspect_equip_slot = slot
	loadout_core.step(frame)
	_save_loadout()
	_update_hud()


func _save_loadout() -> void:
	var player: Snapshots.EntitySnapshot = loadout_core.snapshot().player
	profile.weapon_id = player.weapon_id
	profile.equipped_aspects = player.equipped_aspects.duplicate()
	if persist:
		SaveStore.save(profile)


# --- drawing ---

## Follows the hero on a fixed 320x180 screen, locked to his rounded position and clamped to the scene (the arena's rule).
func _update_camera() -> void:
	if camera == null or snapshot == null:
		return
	var half: Vector2 = VIEW_SIZE * 0.5
	view_origin = (snapshot.hero.position.round() - half).clamp(Vector2.ZERO, (snapshot.size - VIEW_SIZE).max(Vector2.ZERO))
	camera.position = view_origin + half
	camera.force_update_scroll()


func _choose_frames() -> void:
	var hero: Snapshots.EntitySnapshot = snapshot.hero
	var moved: bool = previous_hero_position != Vector2.INF and not hero.position.is_equal_approx(previous_hero_position)
	if (moved or hero.state == &"dash") and absf(hero.facing.x) > 0.3:
		facing_left = hero.facing.x < 0.0
	previous_hero_position = hero.position
	hero_frame = hero_frame_for(hero)
	for i: int in snapshot.npcs.size():
		var npc: Dictionary = snapshot.npcs[i]
		npc_frames[npc["id"]] = npc_frame_for(npc, snapshot.tick + i * 13)


## The katana hero frame (hero2_*) for idle, walk and dash, timed like the fight (animation.gd).
static func hero_frame_for(hero: Snapshots.EntitySnapshot) -> String:
	var prefix: String = ArenaAnimation.SET_KATANA
	match hero.state:
		&"walk":
			return ArenaAnimation.hero_frame(prefix, "walk", ArenaAnimation.frame_index(ArenaAnimation.PLAYER["walk"], ArenaAnimation.walk_ticks(hero.state_ticks, hero.move_speed_mult)))
		&"dash":
			return ArenaAnimation.hero_frame(prefix, "dash", ArenaAnimation.frame_index(ArenaAnimation.PLAYER["dash"], hero.state_ticks))
	return ArenaAnimation.hero_frame(prefix, "idle", ArenaAnimation.frame_index(ArenaAnimation.PLAYER["idle"], hero.state_ticks))


## The NPC's idle loop frame (4 frames, the source ticks 24/14/14/8) at `tick`.
func npc_frame_for(npc: Dictionary, tick: int) -> String:
	var visual: String = String(npc["visual"])
	var ticks: Array = npc_idle_ticks.get(visual.trim_prefix("npc_"), NPC_IDLE_TICKS_DEFAULT)
	var total: int = 0
	for t: Variant in ticks:
		total += int(t)
	var at: int = posmod(tick, maxi(1, total))
	var n: int = 1
	for t: Variant in ticks:
		if at < int(t):
			break
		at -= int(t)
		n += 1
	return "%s_idle_right_%d" % [visual, mini(n, ticks.size())]


func ambient() -> Color:
	return AMBIENT.get(snapshot.scene_id, Color.WHITE) if snapshot != null else Color.WHITE


func _visible_world_rect() -> Rect2:
	return get_canvas_transform().affine_inverse() * get_viewport_rect()


## Actors, props, cosmetic motes and painted foreground occluders sorted by base.
func drawables() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tint: Color = ambient()
	for npc: Dictionary in snapshot.npcs:
		var height: float = float(NPC_HEIGHTS.get(npc["visual"], 30.0))
		out.append({"kind": &"npc", "id": npc["id"], "at": npc["position"], "frame": String(npc_frames.get(npc["id"], "")), "left": bool(npc["facing_left"]), "shadow": HERO_SHADOW_RADIUS * height / HERO_HEIGHT, "tint": tint, "height": height})
	if snapshot.scene_id == SceneDefs.VILLAGE:
		for object: Dictionary in snapshot.objects:
			if object["kind"] == &"chest":  # the village chest is not painted (the forest's is, in its nook)
				out.append({"kind": &"object", "id": object["id"], "at": object["position"], "frame": "obj_chest_closed_1", "left": false, "shadow": 0.0, "tint": Color.WHITE})
	out.append({"kind": &"hero", "id": &"totoy", "at": snapshot.hero.position, "frame": hero_frame, "left": facing_left, "shadow": HERO_SHADOW_RADIUS, "tint": tint, "height": HERO_HEIGHT})
	out.append_array(AmbientFireflies.drawables(snapshot.scene_id, snapshot.tick, snapshot.size))
	if SceneDefs.LAYERED.has(snapshot.scene_id):
		return PropsLayer.sorted_with_actors(PropsLayer.drawables(prop_placements, frames, _visible_world_rect().grow(8)), out)
	out.append_array(DepthOccluders.drawables(snapshot.scene_id, {&"gate_open": snapshot.gate_open}, _visible_world_rect().grow(8.0)))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["at"]).y < Vector2(b["at"]).y)
	return out


func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	draw_rect(Rect2(Vector2(-8, -8), snapshot.size + Vector2(16, 16)), colors["2"])
	var ground: Texture2D = ground_texture(snapshot.scene_id)
	if ground != null:
		draw_texture(ground, Vector2.ZERO)
	var items: Array[Dictionary] = drawables()
	if SceneDefs.LAYERED.has(snapshot.scene_id):
		# All shadows lie on the floor, never on a lower-sorted prop or actor.
		for item: Dictionary in items:
			if item["kind"] == &"prop":
				PropsLayer.draw_shadow(self, item, shadow_strength(), sprites)
			elif item["kind"] in [&"hero", &"npc", &"object"]:
				_draw_actor_cast(item)
				ActorShadow.draw(self, item["at"], item["shadow"], shadow_strength())
	for item: Dictionary in items:
		_draw_item(item)
	if snapshot.hero.state == &"dash":
		_draw_imported("fx_dash_%d" % (mini(5, snapshot.hero.state_ticks / 2) + 1), snapshot.hero.position - Vector2(0, 10), Vector2(-1 if facing_left else 1, 1))
	for item: Dictionary in items:
		if item["kind"] == &"npc" and bubbles.has(item["id"]):
			_draw_bubble(Vector2(item["at"]) - Vector2(0, float(item["height"]) + 6.0))
	if debug_enabled:
		_draw_debug()


func _draw_item(item: Dictionary) -> void:
	if item["kind"] == &"firefly":
		AmbientFireflies.draw(self, item)
		return
	if item["kind"] == &"prop":
		PropsLayer.draw(self, item, sprites, ambient())
		return
	if item["kind"] == &"occluder":
		DepthOccluders.draw(self, snapshot.scene_id, item)
		return
	var at: Vector2 = Vector2(item["at"]).round()
	var radius: float = float(item["shadow"])
	if radius > 0.0 and not SceneDefs.LAYERED.has(snapshot.scene_id):
		ActorShadow.draw(self, at, radius, ActorShadow.strength_for(snapshot.scene_id))
	var key: String = item["frame"]
	if not frames.has(key):
		if not missing_frames.has(key):
			push_warning("Missing explore frame: " + key)
			missing_frames[key] = true
		draw_rect(Rect2(at - Vector2(6, 24), Vector2(12, 24)), colors["g"])
		return
	var frame: Dictionary = frames[key]
	draw_texture_rect_region(sprites, ArenaAnimation.destination(at, frame, bool(item["left"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]), item["tint"])


func _draw_actor_cast(item: Dictionary) -> void:
	if not frames.has(item["frame"]):
		return
	var frame: Dictionary = frames[item["frame"]]
	draw_set_transform_matrix(EnvironmentLight.actor_transform(item["at"], frame, bool(item["left"])))
	draw_texture_rect_region(sprites, Rect2(Vector2.ZERO, Vector2(frame["w"], frame["h"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]), Color(0, 0, 0, EnvironmentLight.ACTOR_SHADOW_ALPHA))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func shadow_strength() -> float:
	var scene: StringName = snapshot.scene_id
	if scene == &"village_layered":
		scene = &"village"
	elif scene == &"forest_layered":
		scene = &"forest"
	elif scene == &"glade_layered":
		scene = &"glade"
	return ActorShadow.strength_for(scene)


func _refresh_props() -> void:
	prop_placements.clear()
	if SceneDefs.LAYERED.has(snapshot.scene_id):
		prop_placements = PropScene.placements(SceneDefs.layered_data(snapshot.scene_id), PropScene.load_defs(), {"gate_open": snapshot.gate_open, "lit": snapshot.lit_switches})
	_update_lighting()


func _update_lighting() -> void:
	material = EnvironmentLight.make_material(snapshot.scene_id, snapshot.size, prop_placements) if lighting_enabled and EnvironmentLight.supports(snapshot.scene_id) else null


func _draw_imported(key: String, at: Vector2, size_scale: Vector2 = Vector2.ONE) -> void:
	if not frames.has(key):
		return
	var frame: Dictionary = frames[key]
	var anchor: Vector2 = Vector2(frame.get("ax", float(frame["w"]) / 2), frame.get("ay", float(frame["h"]) / 2))
	var extent: Vector2 = Vector2(frame["w"], frame["h"])
	var origin: Vector2 = at - anchor * size_scale.abs()
	if size_scale.x < 0:
		origin.x = at.x - (extent.x - anchor.x) * absf(size_scale.x)
	draw_texture_rect_region(sprites, Rect2(origin.round(), extent * size_scale), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))


## The placeholder speech bubble "..." (cream, ink edge, a tail) with its bottom centre at `tip`.
func _draw_bubble(tip: Vector2) -> void:
	var t: Vector2 = tip.round()
	var rect: Rect2 = Rect2(t + Vector2(-9, -11), Vector2(18, 9))
	draw_rect(rect.grow(1), colors["0"])
	draw_rect(rect, colors["1"])
	draw_rect(Rect2(t + Vector2(-1, -2), Vector2(3, 1)), colors["0"])
	draw_rect(Rect2(t + Vector2(0, -2), Vector2(1, 2)), colors["0"])
	draw_rect(Rect2(t + Vector2(0, -2), Vector2(1, 1)), colors["1"])
	for k: int in 3:
		draw_rect(Rect2(t + Vector2(-5 + k * 4, -7), Vector2(2, 2)), colors["0"])


## F1 / H: colliders (circles), exits (rectangles), checkpoints, entries, the hero's body and the interact range.
func _draw_debug() -> void:
	for o: Dictionary in snapshot.obstacles:
		draw_circle(o["center"], float(o["radius"]), colors["p"], false, 1.0)
	for exit: Dictionary in snapshot.exits:
		draw_rect(exit["rect"], colors["o"], false, 1.0)
	for c: Dictionary in snapshot.checkpoints:
		draw_circle(c["position"], ExploreCore.CHECKPOINT_RADIUS, colors["u"], false, 1.0)
		draw_rect(Rect2(Vector2(c["position"]) - Vector2.ONE, Vector2(3, 3)), colors["u"])
	for key: StringName in snapshot.entries:
		draw_rect(Rect2(Vector2(snapshot.entries[key]) - Vector2.ONE, Vector2(3, 3)), colors["v"])
	for object: Dictionary in snapshot.objects:
		draw_rect(Rect2(Vector2(object["stand"]) - Vector2.ONE, Vector2(3, 3)), colors["7"])
	draw_circle(snapshot.hero.position, Tuning.PLAYER_RADIUS, colors["1"], false, 1.0)
	draw_circle(snapshot.hero.position, ExploreCore.INTERACT_RANGE, colors["n"], false, 1.0)


func _update_hud() -> void:
	if hud == null or snapshot == null:
		return
	hud.colors = colors
	hud.toast_text = toast_text()
	hud.toast_alpha = clampf(float(toast_ticks) / TOAST_FADE_TICKS, 0.0, 1.0)
	hud.hint_text = hint_text() if not character_menu.is_open else ""
	hud.hint_at = hint_anchor()
	hud.fade_alpha = fade_alpha()
	hud.debug_lines = []
	if debug_enabled:
		hud.debug_lines = ["SCENE %s  TICK %d" % [String(snapshot.scene_id).to_upper(), snapshot.tick], "HERO %d,%d %s" % [int(snapshot.hero.position.x), int(snapshot.hero.position.y), String(snapshot.hero.state).to_upper()], "CHECKPOINT %s" % String(snapshot.last_checkpoint).to_upper(), "GATE %s (F6/G)" % ("OPEN" if snapshot.gate_open else "CLOSED")]
	hud.queue_redraw()
	character_menu.snapshot = loadout_core.snapshot()
	character_menu.colors = colors
	character_menu.atlas = sprites
	character_menu.frames = frames
	character_menu.queue_redraw()
