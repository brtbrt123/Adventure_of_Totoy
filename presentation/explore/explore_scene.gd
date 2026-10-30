extends "res://presentation/common/hero_fx.gd"
const LocalPropShadows := preload("res://presentation/common/local_prop_shadows.gd")
## Chapter 1 layered-ground/prop renderer. Core owns movement, collisions, transitions and rewards.
## F2/1 village, F3/2 forest, F4/3 glade, F5/4 arena; F7/5, F8/6 and F10/8 remain layered aliases; F11/9 woodland.
## The arena uses its own renderer. Save migration stays in core/SaveProfile.
const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameCore := preload("res://core/game_core.gd")
const SaveStore := preload("res://core/save_store.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const CharacterMenu := preload("res://presentation/arena/character_menu.gd")
const ExploreHud := preload("res://presentation/explore/explore_hud.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const PropScene := preload("res://core/prop_scene.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
const CreatureEffects := preload("res://presentation/explore/creature_effects.gd")
var creature_effects: CreatureEffects = CreatureEffects.new()
const PropsLayer := preload("res://presentation/common/props_layer.gd")
const AmbientFireflies := preload("res://presentation/common/ambient_fireflies.gd")
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")

const RewardPopup := preload("res://presentation/explore/reward_popup.gd")
var reward_popup: RewardPopup
const PracticeView := preload("res://presentation/explore/practice_view.gd")
var practice_view: PracticeView
const ConversationView := preload("res://presentation/explore/conversation_view.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
var conversation: ConversationView
var practice_effects: Array[Dictionary] = []
var hero_hit_tick: int = -1000
var defeat_started_tick: int = -1
var world_cues: Array[Dictionary] = []
const EncounterEffects := preload("res://presentation/explore/encounter_effects.gd")
var encounter_effects: EncounterEffects
const ProgressionView := preload("res://presentation/explore/progression_view.gd")
var progression_view: ProgressionView

const ARENA_SCENE: String = "res://presentation/arena/arena.tscn"
const TITLE_SCENE: String = "res://presentation/menu/title.tscn"
const START_META: StringName = &"totoy_explore_start"
const PERSIST_META: StringName = &"totoy_persist"
const VIEW_SIZE: Vector2 = Vector2(384.0, 216.0)

const GROUNDS: Dictionary = {
	&"arena": "res://presentation/arena/arena_ground.png",
}
## Per-scene ambient multiplied onto the actors (not the ground) so the sprites sit in the dusk paintings.
const AMBIENT: Dictionary = {
	&"woodland_layered": Color(0.9, 0.94, 0.88),
	&"root_hollow_layered": Color(0.88, 0.93, 0.87),
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
const DEBUG_SCENES: Dictionary = {"debug_scene_woodland": &"woodland_layered", "debug_scene_hollow": &"root_hollow_layered", "debug_scene_village": &"village_layered", "debug_scene_forest": &"forest_layered", "debug_scene_glade": &"glade_layered", "debug_scene_arena": &"arena", "debug_scene_village_layered": &"village_layered", "debug_scene_glade_layered": &"glade_layered", "debug_scene_forest_layered": &"forest_layered"}

var core: ExploreCore
var snapshot: ExploreCore.ExploreSnapshot
var grounds: Dictionary = {}
var prop_placements: Array[Dictionary] = []
var lighting_enabled: bool = true
var npc_idle_ticks: Dictionary = {}
var camera: Camera2D
var view_origin: Vector2 = Vector2.ZERO
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
## The katana's Black Form cut-in (drawn on the HUD layer). While it plays the road does not step the core.
const BlackFormCutIn := preload("res://presentation/arena/black_form_cutin.gd")
var cutin: BlackFormCutIn
const LightningFormCutIn := preload("res://presentation/arena/lightning_form_cutin.gd")
const ReapersCoilCutIn := preload("res://presentation/arena/reapers_coil_cutin.gd")
var lightning_cutin: LightningFormCutIn
var coil_cutin: ReapersCoilCutIn
var intro_arrival_ticks: int = 0
var transitions: int = 0  # scene changes done (tests)
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)
@onready var hud: ExploreHud = $HUD/Display


func _ready() -> void:
	Bindings.register()
	progression_view=ProgressionView.new()
	add_child(progression_view)
	encounter_effects = EncounterEffects.new()
	add_child(encounter_effects)
	practice_view = PracticeView.new()
	add_child(practice_view)
	var palette: Dictionary = _read_json("res://art/palette.json")
	for entry: Dictionary in palette.get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	frames = _read_json("res://art/build/sprites.json").get("frames", {})
	sprites = load("res://art/build/sprites.png") as Texture2D
	load_variant_atlases()
	cutin = BlackFormCutIn.new()
	cutin.position = Vector2(32, 18)
	$HUD.add_child(cutin)
	lightning_cutin = LightningFormCutIn.new()
	lightning_cutin.position = Vector2(32, 18)
	$HUD.add_child(lightning_cutin)
	coil_cutin = ReapersCoilCutIn.new()
	coil_cutin.position = Vector2(32, 18)
	$HUD.add_child(coil_cutin)
	_load_chain_origins()
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
	character_menu.stat_request=request_stat_spend
	character_menu.respec_request=request_stats_reset
	$HUD.add_child(character_menu)
	conversation = ConversationView.new()
	$HUD.add_child(conversation)
	conversation.blip = func() -> void: practice_view.audio.cue("dialogue_blip", snapshot.tick, 0.2)
	reward_popup = RewardPopup.new()
	$HUD.add_child(reward_popup)
	var start: Dictionary = Engine.get_meta(START_META, {}) if Engine.has_meta(START_META) else {}
	if Engine.has_meta(START_META):
		Engine.remove_meta(START_META)
	gate_open = bool(start.get("gate_open", profile.gate_open if persist else false))
	var scene: StringName = StringName(start.get("scene", SceneDefs.START_SCENE))
	if not SceneDefs.LAYERED.has(scene):
		scene = SceneDefs.START_SCENE
	enter_scene(scene, StringName(start.get("entry", &"")), StringName(start.get("checkpoint", &"")))
	if bool(start.get("intro_arrival",false)) and scene==SceneDefs.START_SCENE:
		intro_arrival_ticks = 18
		conversation.controls_open = false
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
	hud.reset_combat_feedback()
	core.set_story_flags(profile.story_flags)
	core.set_inventory(profile.inventory)
	core.set_exp(profile.exp_total)
	core.set_stats(profile.stats)
	core.set_loadout(profile.weapon_id,profile.equipped_aspects)
	snapshot = core.snapshot()
	practice_effects.clear()
	particles.clear()
	hit_bursts.clear()
	parry_impacts.clear()
	dash_ghosts.clear()
	sprint_trail.clear()
	wes_fx.clear()
	aspect_fx.clear()
	buff_events.clear()
	buff_transition.clear()
	for playing: Node in [cutin, lightning_cutin, coil_cutin]:
		if playing != null:
			playing.stop()
	lightning_fx.clear()
	coil_fx.clear()
	coil_hook_tick = -1
	drag_started.clear()
	hero_hidden_until = -1
	_motion_seen = false
	previous_player_position = snapshot.hero.position
	hero_hit_tick = -1000
	world_cues.clear()
	encounter_effects.clear()
	creature_effects.clear()
	progression_view.clear()
	defeat_started_tick = -1
	practice_view.enter_scene(scene)
	conversation.sync(snapshot.dialogue)
	conversation.controls_open = scene == SceneDefs.VILLAGE_LAYERED and not snapshot.story_flags.has(&"seen_controls")
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
	practice_view.sync(snapshot, practice_effects, frames, sprites)
	encounter_effects.sync(snapshot, colors, frames, sprites)
	creature_effects.sync(snapshot)
	progression_view.sync(snapshot, colors, frames, sprites)
	progression_view.visible=not character_menu.is_open and snapshot.dialogue.is_empty() and not conversation.controls_open
	_update_camera()
	queue_redraw()


func _save_progress(scene: StringName, checkpoint: StringName) -> void:
	profile.record_scene(scene, checkpoint)
	profile.gate_open = gate_open
	if snapshot != null:
		profile.story_flags = snapshot.story_flags.duplicate()
		profile.inventory = snapshot.inventory.duplicate(true)
		profile.exp_total = snapshot.exp_total
		profile.stats = snapshot.stats.duplicate()
	if persist:
		SaveStore.save(profile)


## True while any weapon cut-in plays (the road does not step).
func cutin_playing() -> bool:
	return (cutin != null and cutin.active) or (lightning_cutin != null and lightning_cutin.active) or (coil_cutin != null and coil_cutin.active)


func _physics_process(delta: float) -> void:
	if cutin_playing():
		if cutin.active:
			cutin.advance(delta)
		if lightning_cutin.active:
			lightning_cutin.advance(delta)
		if coil_cutin.active:
			coil_cutin.advance(delta)
		return
	if snapshot != null and snapshot.defeated:
		advance(InputFrame.new())
		return
	if character_menu.is_open:
		if not character_menu.poll_input():
			_update_hud()
		return
	if fade_phase != &"":
		advance_fade()
		return
	if intro_arrival_ticks>0:
		var arrival: InputFrame = InputFrame.new()
		arrival.move = Vector2.DOWN
		advance(arrival)
		intro_arrival_ticks -= 1
		if intro_arrival_ticks==0:
			conversation.controls_open = not snapshot.story_flags.has(&"seen_controls") and snapshot.dialogue.is_empty()
			_update_hud()
		return
	if conversation.controls_open:
		if Input.is_action_just_pressed("explore_interact") or Input.is_action_just_pressed("dialogue_next") or Input.is_action_just_pressed("menu_back"):
			dismiss_controls()
		return
	if not snapshot.dialogue.is_empty():
		var talk_frame: InputFrame = InputFrame.new()
		talk_frame.interact_pressed = Input.is_action_just_pressed("explore_interact") or Input.is_action_just_pressed("dialogue_next")
		talk_frame.skip_pressed = Input.is_action_just_pressed("dialogue_skip")
		advance(talk_frame)
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
	if not snapshot.dialogue.is_empty() and intent.interact_pressed and not intent.skip_pressed and not conversation.complete():
		conversation.finish_typing()
		intent = InputFrame.new()
		intent.interact_pressed = false
	for ability: String in ["attack","dash","parry"]:
		var pressed: bool=intent.attack_pressed if ability=="attack" else (intent.dash_pressed if ability=="dash" else intent.parry_pressed)
		if pressed and not bool(snapshot.unlocked.get(ability,false)):
			hud.locked_hint(ability.capitalize()+" locked")
			practice_view.audio.cue("slot_locked",snapshot.tick,0.4)
	if intent.use_item_slot>0 and intent.use_item_slot<=snapshot.item_slots.size() and not bool(snapshot.item_slots[intent.use_item_slot-1].get("unlocked",false)):
		practice_view.audio.cue("slot_locked",snapshot.tick,0.4)
		hud.locked_hint("Item slot locked")
	if intent.skill_pressed>0 and intent.skill_pressed<=snapshot.aspect_slots.size() and not bool(snapshot.aspect_slots[intent.skill_pressed-1].get("unlocked",false)):
		practice_view.audio.cue("slot_locked",snapshot.tick,0.4)
		hud.locked_hint("Aspect socket locked")
	core.step(intent)
	snapshot = core.snapshot()
	gate_open = snapshot.gate_open
	conversation.sync(snapshot.dialogue)
	conversation.tick()
	world_cues = world_cues.filter(func(cue: Dictionary) -> bool: return snapshot.tick-int(cue["tick"]) < 24)
	practice_effects = practice_effects.filter(func(effect: Dictionary) -> bool: return snapshot.tick - int(effect["tick"]) < 12)
	for event: GameEvent in core.last_events:
		_on_event(event)
	if toast_ticks > 0:
		toast_ticks -= 1
	for id: StringName in bubbles.keys():
		bubbles[id] = int(bubbles[id]) - 1
		if int(bubbles[id]) <= 0:
			bubbles.erase(id)
	age_hero_fx()
	_choose_frames()
	practice_view.sync(snapshot, practice_effects, frames, sprites)
	encounter_effects.sync(snapshot, colors, frames, sprites)
	creature_effects.sync(snapshot)
	progression_view.sync(snapshot, colors, frames, sprites)
	progression_view.visible=not character_menu.is_open and snapshot.dialogue.is_empty() and not conversation.controls_open
	_update_camera()
	_update_hud()
	queue_redraw()


func _on_event(event: GameEvent) -> void:
	hud.combat_event(event)
	encounter_effects.handle_event(event, snapshot)
	practice_view.audio.handle_event(event, snapshot.scene_id)
	if event.type in [GameEvent.MOB_DEFEATED,GameEvent.ITEM_USED,GameEvent.HERO_RESPAWNED]:
		world_cues.append({"type":event.type,"tick":snapshot.tick,"at":event.data.get("position",snapshot.hero.position)})
	if event.type == GameEvent.ENCOUNTER_CLEARED:
		toast_message = "CLEARING CLEARED"
		toast_ticks = 110
	match event.type:
		GameEvent.QUEST_COMPLETED, GameEvent.STAT_SPENT, GameEvent.STATS_RESET:
			_save_progress(core.scene_id,core.last_checkpoint)
		GameEvent.EXIT_BLOCKED:
			hud.gate_message=String(event.data.get("text",""))
			hud.gate_tick=snapshot.tick
		GameEvent.CHEST_OPENED:
			progression_view.chest_tick=snapshot.tick
			hud.task_message="The Elder's basket."
			hud.task_tick=snapshot.tick
			practice_view.audio.cue("chest_open",snapshot.tick,0.7)
		GameEvent.HERO_DEFEATED:
			character_menu.close()
			defeat_started_tick = snapshot.tick
		GameEvent.HERO_RESPAWNED:
			defeat_started_tick = -1
		GameEvent.SCENE_EXIT:
			begin_transition(event.data["target_scene"], event.data["target_entry"])
		GameEvent.CHECKPOINT:
			_save_progress(core.scene_id, event.data["checkpoint_id"])
		GameEvent.SWITCH_LIT:
			_refresh_props()
		GameEvent.GATE_CHANGED:
			gate_open = snapshot.gate_open
			_refresh_props()
			if profile.gate_open != gate_open:
				_save_progress(core.scene_id, core.last_checkpoint)
		GameEvent.INTERACT:
			if event.data["kind"] == &"npc" and snapshot.dialogue.is_empty():
				bubbles[event.data["target_id"]] = BUBBLE_TICKS
		GameEvent.EXP_GAINED:
			_save_progress(core.scene_id, core.last_checkpoint)
		GameEvent.ITEM_USED:
			_save_progress(core.scene_id, core.last_checkpoint)
		GameEvent.ITEM_RECEIVED:
			_save_progress(core.scene_id, core.last_checkpoint)
			var icons: Dictionary = {&"sprint": "ui_aspect_sprint_1", &"herb": "hud_copper_herb", &"black_katana": "ui_weapon_totoy_blade_1", &"dual_dagger": "ui_weapon_dual_dagger_1", &"chain_scythe": "ui_weapon_chain_scythe_1"}
			show_reward({"kind": event.data["kind"], "name": event.data["name"], "quantity": event.data["quantity"], "icon": icons.get(StringName(event.data["item_id"]), "")})
		GameEvent.FLAG_SET, GameEvent.DIALOGUE_ENDED:
			if event.type == GameEvent.FLAG_SET:
				_refresh_props()  # a prop may change state with a story flag (Root Hollow's root-knot barrier opens on cleared_hollow_center)
			_save_progress(core.scene_id, core.last_checkpoint)
			if event.type == GameEvent.FLAG_SET:
				var flag: String = String(event.data.get("flag", ""))
				if flag == "training_done":
					practice_message("TRAINING COMPLETE")
				elif flag.begins_with("lesson_"):
					practice_message(flag.trim_prefix("lesson_").to_upper() + " LEARNED")
		GameEvent.DAMAGE_TAKEN:
			hero_hit_tick = snapshot.tick
			practice_effects.append({"type": event.type, "tick": snapshot.tick, "at": snapshot.hero.position + Vector2(0,-14), "perfect": false})
		GameEvent.ATTACK_HIT:
			# the hero's swing: the same burst, sparks and shake as in the fight (presentation/common/hero_fx.gd)
			if bool(event.data.get("echo", false)):
				return  # a Phantom echo is not a swing: its own light effects come from phantom_echo
			var counter: bool = event.data.get("kind", &"") == &"counter"
			var finisher: bool = (int(event.data.get("combo_index", 0)) >= snapshot.hero.combo_max and snapshot.hero.combo_max > 0) or event.data.get("skill_id", &"") == &"moon_cleave" or bool(event.data.get("ward_release", false))
			if bool(event.data.get("lightning_strike", false)):
				return  # the sky strike draws its own burst (lightning_strike)
			on_hero_hit(event.tick, event.data["position"], Vector2(event.data["position"]) + Vector2(0, -12), counter, finisher, event.data.get("skill_id", event.data.get("aspect_id", &"")))
			if snapshot.hero.weapon_form == Weapons.FORM_LIGHTNING:
				_add_lightning_fx({"kind": "spark", "tick": event.tick, "at": Vector2(event.data["position"]) + Vector2(0, -12), "life": LightningEffects.sequence_length(LightningEffects.SPARK_TICKS)})
		GameEvent.MOB_STAGGERED:
			practice_effects.append({"type": event.type, "tick": snapshot.tick, "at": event.data["position"], "perfect": false})
		GameEvent.TRAINING_POST_HIT:
			practice_effects.append({"type": event.type, "tick": snapshot.tick, "at": event.data["position"], "perfect": false})
			on_hero_hit(event.tick, event.data["position"], Vector2(event.data["position"]) + Vector2(0, -8), false, false)
		GameEvent.PARRY_SUCCEEDED:
			# kept for the brief parry pose; the picture, sparks and shake come from the shared layer
			practice_effects.append({"type": event.type, "tick": snapshot.tick, "at": event.data["position"], "perfect": event.data.get("quality", &"") == &"perfect"})
			on_hero_parry(event.tick, event.data["position"], Vector2(event.data["position"]) + Vector2(0, -8), event.data.get("quality", &"") == &"perfect")
		&"lantern_placed", &"lantern_pulse", &"lantern_expired", &"phantom_cut_started", &"phantom_cut_ended", &"phantom_echo":
			_on_aspect_event(event)
		&"weapon_buff_started", &"weapon_buff_ended":
			var buff: Dictionary = on_hero_weapon_buff(event)
			if not buff.is_empty():
				if buff["started"]:
					if buff["form"] == Weapons.FORM_LIGHTNING and lightning_cutin != null:
						lightning_cutin.start()
					elif buff["form"] == Weapons.FORM_REAPER_COIL and coil_cutin != null:
						coil_cutin.start()
					elif cutin != null:
						cutin.start()
				practice_view.audio.cue("weapon_buff_start" if buff["started"] else "weapon_buff_end", event.tick)
		&"lightning_blink":
			_on_lightning_blink(event)
		&"lightning_strike":
			_on_lightning_strike(event)
		&"reaper_coil_started", &"reaper_coil_hooked", &"reaper_coil_missed", &"reaper_coil_drag", &"reaper_coil_spin", &"reaper_coil_ended":
			_on_reaper_coil(event)
		&"lightning_barrage_ended":
			if event.data.get("reason", &"") == &"complete":
				_burst(snapshot.hero.position - Vector2(0, 12), 8, colors["o"], 0.7)
		&"skill_started":
			on_hero_skill_event(event)
			practice_view.audio.cue("skill_" + String(event.data["skill_id"]), event.tick)
		&"skill_released":
			if on_hero_skill_event(event):
				practice_view.audio.cue("release_" + String(event.data["skill_id"]), event.tick)
		&"sprint_started", &"sprint_ended", &"echo_placed", &"echo_recall", &"echo_expired", &"ward_raised", &"ward_blocked", &"ward_released":
			_on_ward_echo_sprint(event)
		GameEvent.TRAINING_HERO_HIT:
			practice_message("TRY AGAIN")
		GameEvent.TRAINING_DODGED:
			practice_message("DODGE LEARNED")


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
	if snapshot != null and snapshot.defeated and defeat_started_tick >= 0:
		return clampf(float(snapshot.tick - defeat_started_tick) / 35.0, 0.0, 0.9)
	match fade_phase:
		&"out":
			return clampf(float(fade_ticks) / FADE_TICKS, 0.0, 1.0)
		&"in":
			return clampf(1.0 - float(fade_ticks) / FADE_TICKS, 0.0, 1.0)
	return 0.0


## Debug jump (F2-F5 or 1-4): to the scene's default entry, with the fade.
func jump_to(scene: StringName) -> void:
	core.set_flag(&"received_first_sword")  # debug combat needs an armed hero as well as ability unlocks
	core.set_flag(&"debug_all_unlocked")
	snapshot=core.snapshot()
	_save_progress(core.scene_id,core.last_checkpoint)
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
	if snapshot == null or not snapshot.dialogue.is_empty() or bool(snapshot.training.get("active", false)) or snapshot.interact_target == &"" or snapshot.exiting or bubbles.has(snapshot.interact_target):
		return ""
	if snapshot.interact_target==&"chest" and snapshot.story_flags.has(&"basket_found"):return "[E] LOOK"
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
	if character_menu.is_open or fade_phase != &"" or not snapshot.dialogue.is_empty():
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
	if not snapshot.owned_aspects.has(aspect):return
	var frame: InputFrame = InputFrame.new()
	frame.aspect_equip = aspect
	frame.aspect_equip_slot = slot
	loadout_core.step(frame)
	for event: GameEvent in loadout_core.last_events:
		practice_view.audio.handle_event(event, snapshot.scene_id)
	if aspect==&"sprint" and slot==1 and loadout_core.snapshot().player.equipped_aspects[0]==aspect:
		core.set_flag(&"lesson_aspect")
		advance(InputFrame.new())
	_save_loadout()
	_update_hud()


func request_stat_spend(stat: StringName) -> void:
	var frame: InputFrame=InputFrame.new()
	frame.spend_stat=stat
	advance(frame)


func request_stats_reset() -> void:
	var frame: InputFrame=InputFrame.new()
	frame.respec_stats=true
	advance(frame)


func _save_loadout() -> void:
	var player: Snapshots.EntitySnapshot = loadout_core.snapshot().player
	profile.weapon_id = player.weapon_id
	profile.equipped_aspects = player.equipped_aspects.duplicate()
	core.set_loadout(profile.weapon_id,profile.equipped_aspects)
	snapshot=core.snapshot()
	if persist:
		SaveStore.save(profile)


# --- drawing ---

## Follows the hero on a fixed 384x216 screen, locked to his rounded position and clamped to the scene (the arena's rule).
func _update_camera() -> void:
	if camera == null or snapshot == null:
		return
	var half: Vector2 = VIEW_SIZE * 0.5
	view_origin = (snapshot.hero.position.round() - half).clamp(Vector2.ZERO, (snapshot.size - VIEW_SIZE).max(Vector2.ZERO))
	camera.position = view_origin + half
	camera.force_update_scroll()


var _previous_hero_state: StringName = &""


## The hooks of presentation/common/hero_fx.gd.
func fx_hero() -> Snapshots.EntitySnapshot:
	return snapshot.hero


func fx_tick() -> int:
	return snapshot.tick


func fx_hero_frame() -> String:
	return hero_frame


func fx_snapshot() -> RefCounted:
	return snapshot


func fx_view_origin() -> Vector2:
	return view_origin


func fx_target_position(target_id: int, fallback: Vector2) -> Vector2:
	for mob: Dictionary in snapshot.mobs:
		if int(mob["id"]) == target_id:
			return mob["position"]
	return fallback


## The mobs held by the chain: [{id, position}].
func fx_dragged() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mob: Dictionary in snapshot.mobs:
		if bool(mob.get("dragged", false)):
			out.append({"id": mob["id"], "position": mob["position"]})
	return out


## Where a connecting spin hit lands: every mob within the spin radius.
func fx_spin_contacts(event: GameEvent) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for mob: Dictionary in snapshot.mobs:
		if mob["state"] == &"dead" and int(mob["state_ticks"]) > 1:
			continue  # already down before this spin (one felled by it has state_ticks 1): no false hit sparks
		if Vector2(event.data["position"]).distance_to(mob["position"]) - float(mob["radius"]) <= float(event.data.get("radius", Tuning.REAPER_COIL_SPIN_RADIUS)):
			out.append(Vector2(mob["position"]) + Vector2(0, -14))
	return out


## A mob's body: a little above its feet.
func fx_target_contact(_target_id: int, fallback: Vector2) -> Vector2:
	return fallback + Vector2(0, -14)


func fx_cue(key: String, tick: int, strength: float = 1.0) -> void:
	practice_view.audio.cue(key, tick, strength)


func _choose_frames() -> void:
	var hero: Snapshots.EntitySnapshot = snapshot.hero
	var was_left: bool = facing_left
	if absf(hero.facing.x) > 0.3:
		facing_left = hero.facing.x < 0.0
	track_hero_motion(not hero.position.is_equal_approx(previous_player_position), _previous_hero_state, was_left)
	_previous_hero_state = hero.state
	previous_hero_position = hero.position
	hero_frame = hero_frame_for(hero, snapshot.armed)
	if snapshot.armed and snapshot.tick - hero_hit_tick >= 0 and snapshot.tick - hero_hit_tick < 8:
		hero_frame = ArenaAnimation.hero_frame(ArenaAnimation.SET_KATANA, "hurt", mini(4, (snapshot.tick - hero_hit_tick) / 2 + 1))
	# Core returns to idle on success; hold the same brief contact pose as the arena.
	for effect: Dictionary in practice_effects:
		if snapshot.armed and effect["type"] == GameEvent.PARRY_SUCCEEDED and snapshot.tick - int(effect["tick"]) < 3 and hero.state in [&"idle", &"walk", &"parry"]:
			hero_frame = ArenaAnimation.hero_frame(ArenaAnimation.SET_KATANA, "parry", 6)
	for i: int in snapshot.npcs.size():
		var npc: Dictionary = snapshot.npcs[i]
		npc_frames[npc["id"]] = npc_frame_for(npc, snapshot.tick + i * 13)


## Appearance follows the core's armed snapshot; combat animation tables stay unchanged.
const UNARMED_FRAMES: Dictionary = {"idle": [6, 12, true], "walk": [6, 5, true], "dash": [6, 1, false]}


static func hero_frame_for(hero: Snapshots.EntitySnapshot, armed: bool = true) -> String:
	if not armed:
		var state: String = String(hero.state) if UNARMED_FRAMES.has(String(hero.state)) else "idle"
		var ticks: int = ArenaAnimation.walk_ticks(hero.state_ticks, hero.move_speed_mult) if state == "walk" else hero.state_ticks
		return ArenaAnimation.hero_frame("totoy_unarmed", state, ArenaAnimation.frame_index(UNARMED_FRAMES[state], ticks))
	var view: Snapshots.GameSnapshot = Snapshots.GameSnapshot.new()
	return ArenaAnimation.choose(hero, view, {})


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
	out.append({"kind": &"hero", "id": &"totoy", "at": snapshot.hero.position, "frame": hero_frame, "left": facing_left, "shadow": HERO_SHADOW_RADIUS, "tint": tint, "height": HERO_HEIGHT})
	for mob: Dictionary in snapshot.mobs:
		out.append({"kind": &"mob", "id": str(mob["id"]), "at": mob["position"], "frame": MobView.frame(mob, snapshot.telegraphs, snapshot.tick), "left": Vector2(mob["facing"]).x < 0.0, "shadow": float(mob["radius"]), "tint": tint, "height": 30.0, "mob": mob})
	out.append_array(AmbientFireflies.drawables(snapshot.scene_id, snapshot.tick, snapshot.size))
	if SceneDefs.LAYERED.has(snapshot.scene_id):
		var props: Array[Dictionary]=PropsLayer.drawables(prop_placements,frames,_visible_world_rect().grow(8))
		if snapshot.story_flags.has(&"basket_found"):
			var age: int=snapshot.tick-progression_view.chest_tick
			var n: int=mini(6,age/5+1) if progression_view.chest_tick>=0 and age>=0 else 6
			var f: Dictionary=frames["progress_chest_open_%d" % n]
			for item: Dictionary in props:
				if item["type"]==&"village_chest":
					item["rect"]=Rect2((Vector2(item["at"])-Vector2(f["ax"],f["ay"])).round(),Vector2(f["w"],f["h"]))
					item["src"]=Rect2(f["x"],f["y"],f["w"],f["h"])
		return PropsLayer.sorted_with_actors(props,out)
	return out



func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	draw_set_transform(shake_offset())
	draw_rect(Rect2(Vector2(-8, -8), snapshot.size + Vector2(16, 16)), colors["2"])
	var ground: Texture2D = ground_texture(snapshot.scene_id)
	if ground != null:
		draw_texture(ground, Vector2.ZERO)
	var ring: Dictionary = snapshot.training.get("ring",{})
	if bool(ring.get("active",false)):
		var at: Vector2=ring["center"]
		var f: Dictionary=frames["progress_ring_%d" % (posmod(snapshot.tick/10,4)+1)]
		var diameter: float=float(ring["radius"])*2.0
		draw_texture_rect_region(sprites,Rect2((at-Vector2.ONE*diameter/2).round(),Vector2.ONE*diameter),Rect2(f["x"]+6,f["y"]+6,28,28))
	for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		TelegraphView.draw_warning(self, tell, snapshot.tick, colors["x"] if tell.kind == &"gold" else colors["z"], colors["y"] if tell.kind == &"gold" else colors["A"], colors["0"])
	_draw_lightning_ground()
	_draw_coil_ground()
	_draw_lantern_ground()
	_draw_ward_echo_ground()
	creature_effects.draw_ground(self, snapshot, frames, sprites, colors)
	draw_dash_fx()
	for prop: Dictionary in lantern_drawables() + echo_drawables():
		_draw_imported(prop["name"], prop["at"], prop["scale"])
	var items: Array[Dictionary] = drawables()
	if SceneDefs.LAYERED.has(snapshot.scene_id):
		if snapshot.scene_id == &"root_hollow_layered" and lighting_enabled:
			LocalPropShadows.draw(self, items, prop_placements, sprites, shake_offset())
		# All shadows lie on the floor, never on a lower-sorted prop or actor.
		for item: Dictionary in items:
			if item["kind"] == &"prop":
				PropsLayer.draw_shadow(self, item, shadow_strength(), sprites)
			elif item["kind"] in [&"hero", &"npc", &"object", &"mob"]:
				_draw_actor_cast(item)
				ActorShadow.draw(self, item["at"], item["shadow"], shadow_strength())
	for item: Dictionary in items:
		_draw_item(item)
	_draw_ward_echo_front(shake_offset())
	_draw_aspects_front()
	for item: Dictionary in items:
		if item["kind"] == &"npc" and bubbles.has(item["id"]):
			_draw_bubble(Vector2(item["at"]) - Vector2(0, float(item["height"]) + 6.0))
	for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if TelegraphView.warning_visible(tell, snapshot.tick):
			TelegraphView.draw_marker(self, tell, colors["x"] if tell.kind == &"gold" else colors["z"], colors["0"])
	draw_hero_impacts()
	_draw_skill_effect(shake_offset())
	_draw_skill_projectiles(shake_offset())
	_draw_skill_contacts()
	_draw_buff_slash(shake_offset())
	_draw_buff_transition()
	_draw_lightning(shake_offset())
	_draw_scythe(shake_offset())
	for effect: Dictionary in practice_effects:
		if effect["type"] in [GameEvent.PARRY_SUCCEEDED, GameEvent.TRAINING_POST_HIT]:
			continue  # drawn by the shared layer
		var age: int = snapshot.tick - int(effect["tick"])
		var plan: Array[Dictionary] = CombatEffects.parry_impact(effect["at"], age, effect["perfect"], colors) if effect["type"] == GameEvent.PARRY_SUCCEEDED else CombatEffects.hit_impact(effect["at"], age, false, colors)
		CombatEffects.draw_plan(self, plan)
	if not snapshot.training.is_empty() and int(snapshot.training["since_hit"]) < 8:
		draw_arc(snapshot.training["center"], 10.0 + float(snapshot.training["since_hit"]) * 0.5, 0, TAU, 24, colors["1"], 1.0)
	for mob: Dictionary in snapshot.mobs:
		MobView.decorate(self, mob, colors, snapshot.hero.position, frames, sprites)
	for cue: Dictionary in world_cues:
		var age: int = snapshot.tick-int(cue["tick"])
		var at: Vector2 = cue["at"]
		var color: Color = colors["g"] if cue["type"] == GameEvent.MOB_DEFEATED else colors["u"]
		if age < 18:
			draw_arc(at,4.0+age*0.5,0.0,TAU,16,color,1.0)
	if debug_enabled:
		_draw_debug()
	draw_set_transform(Vector2.ZERO)
	draw_hero_screen_flashes(view_origin, VIEW_SIZE)


func hero_hit_flash() -> bool:
	var age: int = snapshot.tick - hero_hit_tick
	return age >= 0 and age < 12 and (age < 4 or age % 4 < 2)


func _draw_item(item: Dictionary) -> void:
	if item["kind"] == &"firefly":
		AmbientFireflies.draw(self, item)
		return
	if item["kind"] == &"prop":
		var drawn: Dictionary = item.duplicate()
		if not snapshot.training.is_empty() and item["type"] == &"village_dummy" and int(snapshot.training["since_hit"]) < 8:
			var offset: Vector2 = Vector2(1 if int(snapshot.training["since_hit"]) % 2 == 0 else -1, 0)
			drawn["at"] = Vector2(item["at"]) + offset
			var rect: Rect2 = item["rect"]
			rect.position += offset
			drawn["rect"] = rect
		PropsLayer.draw(self, drawn, sprites, ambient())
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
	if item["kind"] == &"hero" and hero_hidden():
		return  # an Echo Step arrival's first frame: only the echo flares
	if item["kind"] == &"hero":
		draw_hero_back(snapshot.hero, key, at, bool(item["left"]))
		_draw_spin_ring(snapshot.hero, false)
	var white: bool = hero_hit_flash() if item["kind"] == &"hero" else (item["kind"] == &"mob" and int(item["mob"]["since_hit"]) < 4)
	var sheet: Texture2D = MobView.WHITE if white else (empowered_sprites if item["kind"] == &"hero" and empowered_sprites != null and black_form_look(snapshot.hero) else sprites)
	draw_texture_rect_region(sheet, ArenaAnimation.destination(at, frame, bool(item["left"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]), item["tint"])
	if item["kind"] == &"mob":
		creature_effects.draw_actor(self, item["mob"], key, snapshot.tick, frames, sprites, colors)
	if item["kind"] == &"hero":
		_draw_phantom_glow(snapshot.hero, key, at, bool(item["left"]))
		_draw_buff_aura(snapshot.hero, true)
		_draw_spin_ring(snapshot.hero, true)
		_draw_hero_aspect_overlays(snapshot.hero, key, at, bool(item["left"]))


func _draw_actor_cast(item: Dictionary) -> void:
	if not frames.has(item["frame"]):
		return
	var frame: Dictionary = frames[item["frame"]]
	draw_set_transform_matrix(EnvironmentLight.actor_transform(item["at"], frame, bool(item["left"])))
	draw_texture_rect_region(sprites, Rect2(Vector2.ZERO, Vector2(frame["w"], frame["h"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]), Color(0, 0, 0, EnvironmentLight.ACTOR_SHADOW_ALPHA))
	draw_set_transform(shake_offset())


func shadow_strength() -> float:
	return ActorShadow.strength_for(snapshot.scene_id)



func _refresh_props() -> void:
	prop_placements.clear()
	if SceneDefs.LAYERED.has(snapshot.scene_id):
		prop_placements = PropScene.placements(SceneDefs.layered_data(snapshot.scene_id), PropScene.load_defs(), {"gate_open": snapshot.gate_open, "lit": snapshot.lit_switches, "flags": snapshot.story_flags})
	_update_lighting()


func _update_lighting() -> void:
	material = EnvironmentLight.make_material(snapshot.scene_id, snapshot.size, prop_placements) if lighting_enabled and EnvironmentLight.supports(snapshot.scene_id) else null


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
	reward_popup.colors = colors
	reward_popup.atlas = sprites
	reward_popup.frames = frames
	reward_popup.blocked = conversation.controls_open or not snapshot.dialogue.is_empty() or character_menu.is_open or fade_phase != &"" or snapshot.defeated
	conversation.colors = colors
	conversation.visible = not character_menu.is_open and fade_phase == &""
	hud.training = snapshot.training if snapshot.dialogue.is_empty() and not conversation.controls_open and not character_menu.is_open else {}
	hud.training_feedback = toast_message if toast_ticks > 0 else ""
	hud.training_at = Vector2(snapshot.training.get("center", Vector2.INF)) - view_origin
	hud.sync_combat(snapshot)
	practice_view.audio.mob_types.clear()
	for mob: Dictionary in snapshot.mobs: practice_view.audio.mob_types[int(mob["id"])] = String(mob["type"])
	hud.explore_hp = snapshot.hero.hp
	hud.explore_max_hp = snapshot.hero.max_hp
	hud.herb_count = int(snapshot.inventory.get("herb",0))
	hud.fight_hud = not snapshot.encounters.is_empty() and not character_menu.is_open and snapshot.dialogue.is_empty()
	hud.visible = not character_menu.is_open
	hud.portrait_atlas = sprites
	hud.ui_frames = frames
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
	character_menu.progression=snapshot
	character_menu.snapshot = loadout_core.snapshot()
	character_menu.colors = colors
	character_menu.atlas = sprites
	character_menu.frames = frames
	character_menu.queue_redraw()


func dismiss_controls() -> void:
	conversation.controls_open = false
	core.set_flag(&"seen_controls")
	snapshot = core.snapshot()
	_save_progress(core.scene_id, core.last_checkpoint)
	_update_hud()


func practice_message(message: String) -> void:
	toast_message = message
	toast_ticks = TOAST_TICKS


## Hook for Claude's confirmed reward event; no inventory or grant logic lives here.
func show_reward(receipt: Dictionary) -> void:
	reward_popup.enqueue(receipt)
