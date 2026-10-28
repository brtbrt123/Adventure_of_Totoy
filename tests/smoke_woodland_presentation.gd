extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const InputFrame := preload("res://core/input_frame.gd")
var scene: Explore
var failures: int = 0
func _init() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("WOODLAND PRESENTATION FAIL: ", message)
func spawn(persisted: bool = false) -> void:
	if persisted:
		Engine.set_meta(Explore.PERSIST_META, true)
	else:
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": SceneDefs.WOODLAND_LAYERED})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
func run() -> void:
	spawn()
	await process_frame
	expect(scene.snapshot.scene_id == SceneDefs.WOODLAND_LAYERED, "real woodland scene loads")
	expect(scene.material is ShaderMaterial, "night material active")
	expect(scene.ambient() == Explore.AMBIENT[SceneDefs.FOREST_LAYERED], "woodland actors and props share forest tint")
	expect(scene.ground_texture(SceneDefs.WOODLAND_LAYERED).get_size() == Vector2(640,400), "approved native floor")
	expect(Explore.AmbientFireflies.drawables(SceneDefs.WOODLAND_LAYERED, 0, scene.snapshot.size).size() == 22, "woodland fireflies")
	expect(scene.practice_view.audio.ambience_active and not scene.practice_view.audio.music_active, "forest ambience without village music")
	expect(InputMap.has_action("debug_scene_woodland") and Explore.DEBUG_SCENES["debug_scene_woodland"] == SceneDefs.WOODLAND_LAYERED, "woodland debug jump")
	expect(scene.snapshot.mobs.size() == 7, "all dormant mobs visible")
	var mob_draws: int = 0
	for item: Dictionary in scene.drawables():
		if item["kind"] == &"mob":
			mob_draws += 1
			expect(scene.frames.has(item["frame"]), "mob drawable uses imported art")
	expect(mob_draws == 7, "mobs join real depth list")
	for mob: Dictionary in scene.snapshot.mobs:
		for state: String in Explore.MobView.STATES[String(mob["type"])]:
			for tick: int in range(40):
				var sample: Dictionary = mob.duplicate(true)
				sample["state"] = StringName(state)
				sample["state_ticks"] = tick
				expect(scene.frames.has(Explore.MobView.frame(sample,scene.snapshot.telegraphs,scene.snapshot.tick)), "every core mob state has art")
	Input.action_press("arena_attack")
	Input.action_press("arena_parry")
	Input.action_press("explore_use_herb")
	var intent: InputFrame = Explore.Bindings.read_frame()
	expect(intent.attack_pressed and intent.attack_held and intent.parry_pressed and intent.use_herb_pressed, "fight and herb input forwarding")
	for action: String in ["arena_attack", "arena_parry", "explore_use_herb"]:
		Input.action_release(action)
	var death_events: Array[Explore.GameEvent] = []
	scene.core.player.die(scene.core.tick, death_events)
	scene.advance(InputFrame.new())
	expect(scene.snapshot.defeated, "real core defeat")
	var original: RefCounted = scene.core
	for tick: int in 50:
		scene._physics_process(0.0)
	expect(scene.fade_alpha() > 0.0 and scene.reward_popup.blocked, "defeat fades and holds receipts while core keeps stepping")
	for tick: int in 100:
		scene._physics_process(0.0)
	expect(not scene.snapshot.defeated and scene.core == original, "respawn without scene/core reload")
	scene.queue_free()
	await process_frame
	spawn()
	await process_frame
	var audio: Explore.PracticeView.VillageAudio = scene.practice_view.audio
	for type: StringName in [&"encounter_started",&"mob_alerted",&"attack_telegraphed",&"attack_hit",&"mob_staggered",&"mob_defeated",&"encounter_cleared",&"item_used",&"hero_defeated",&"hero_respawned"]:
		audio.handle_event(Explore.GameEvent.new(type,scene.snapshot.tick+audio.played.size()+10,{"kind":&"counter"}),SceneDefs.WOODLAND_LAYERED)
	for cue: String in ["dash","red_warning","counter_hit","posture_break","golem_sweep","lesson_complete","lantern_light","player_hurt","aspect_bind"]:
		expect(int(audio.played.get(cue,0)) > 0, "recorded event cue: "+cue)
	scene.queue_free()
	await process_frame
	await inventory_test()
	print("WOODLAND PRESENTATION OK" if failures == 0 else "WOODLAND PRESENTATION FAILED")
	quit(0 if failures == 0 else 1)

func inventory_test() -> void:
	var previous: String = OS.get_environment(Explore.SaveStore.PATH_ENV)
	OS.set_environment(Explore.SaveStore.PATH_ENV,"user://woodland_presentation_inventory.json")
	Explore.SaveStore.delete()
	var profile: Explore.SaveProfile = Explore.SaveProfile.new()
	profile.record_scene(SceneDefs.WOODLAND_LAYERED,&"woodland_layered_west")
	profile.story_flags.append(&"received_first_sword")
	profile.inventory = {"herb":3}
	Explore.SaveStore.save(profile)
	spawn(true)
	await process_frame
	expect(int(scene.snapshot.inventory.get("herb",0)) == 3, "core inventory restores on entry")
	scene.core.player.hp = 70
	var use: InputFrame = InputFrame.new()
	use.use_herb_pressed = true
	scene.advance(use)
	expect(scene.snapshot.hero.hp == scene.snapshot.hero.max_hp and int(scene.snapshot.inventory.get("herb",0)) == 2, "herb heals through real core intent")
	expect(int(Explore.SaveStore.load_profile().inventory.get("herb",0)) == 2 and scene.hud.herb_count == 2, "herb use saves and updates HUD")
	scene.enter_scene(SceneDefs.FOREST_LAYERED)
	expect(int(scene.snapshot.inventory.get("herb",0)) == 2, "inventory survives another core/scene")
	scene.enter_scene(SceneDefs.WOODLAND_LAYERED)
	scene._on_event(Explore.GameEvent.new(&"item_received",scene.snapshot.tick,{"kind":&"item","item_id":&"herb","name":"Herb","quantity":2}))
	expect(scene.reward_popup.pending[-1]["icon"] == "ui_item_herb_1" and scene.frames.has("ui_item_herb_1"), "herb receipt uses actual consumable icon")
	expect(int(scene.snapshot.inventory.get("herb",0)) == 2, "receipt never grants an item in presentation")
	scene.queue_free()
	await process_frame
	spawn(true)
	await process_frame
	expect(int(scene.snapshot.inventory.get("herb",0)) == 2 and scene.reward_popup.pending.is_empty(), "reload inventory without replaying receipt")
	scene.queue_free()
	await process_frame
	Explore.SaveStore.delete()
	OS.set_environment(Explore.SaveStore.PATH_ENV,previous)
	Engine.remove_meta(Explore.PERSIST_META)
