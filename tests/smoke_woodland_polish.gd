extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
var failures: int = 0
func _init() -> void:call_deferred("run")
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		printerr("WOODLAND POLISH FAIL: ",text)
func run() -> void:
	var previous: String = OS.get_environment(Explore.SaveStore.PATH_ENV)
	OS.set_environment(Explore.SaveStore.PATH_ENV,"user://woodland_polish_smoke.json")
	Explore.SaveStore.delete()
	Engine.set_meta(Explore.PERSIST_META,true)
	Engine.set_meta(Explore.START_META,{"scene":Explore.SceneDefs.WOODLAND_LAYERED})
	var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	await process_frame
	scene.core.set_flag(&"received_first_sword")
	scene.core.set_flag(&"unlocked_item_slot_1")
	scene.core.set_inventory({"herb":3})
	scene.snapshot = scene.core.snapshot()
	scene._update_hud()
	expect(scene.hud.fight_hud,"encounters enable full HUD")
	expect(scene.hud.combat.item_slots[0]["unlocked"] and not scene.hud.combat.item_slots[1]["unlocked"],"exact item locks")
	for slot: Dictionary in scene.hud.combat.aspect_slots:expect(not slot["unlocked"],"all core exploration Aspect locks preserved")
	for i: int in 2:
		Input.action_press("explore_item_%d" % (i+1))
		expect(Explore.Bindings.read_frame().use_item_slot == i+1,"number key forwards exact slot")
		Input.action_release("explore_item_%d" % (i+1))
		await process_frame
	for action: String in ["debug_scene_village","debug_scene_forest"]:
		for key: InputEvent in InputMap.action_get_events(action):
			if key is InputEventKey:expect(key.physical_keycode not in [KEY_1,KEY_2],"item keys never jump maps")
	var use: Explore.InputFrame = Explore.InputFrame.new()
	use.use_item_slot = 2
	scene.advance(use)
	expect(scene.snapshot.inventory["herb"]==3 and scene.hud.item_flash_tick<0,"locked key never consumes or heals")
	expect(scene.practice_view.audio.played.has("slot_locked"),"locked slot cue")
	scene.core.player.hp = 60
	use.use_item_slot = 1
	scene.advance(use)
	expect(scene.snapshot.hero.hp==95 and scene.snapshot.inventory["herb"]==2,"real core slot heals35")
	expect(scene.hud.item_flash_tick==scene.snapshot.tick,"confirmed item event flashes slot")
	expect(scene.encounter_effects.numbers.back()["amount"]==35,"heal amount from event")
	expect(scene.practice_view.audio.played.has("herb_use"),"new heal recording used")
	var events: Array[Explore.GameEvent] = []
	scene.core.give_exp(100,999,events)
	scene.snapshot = scene.core.snapshot()
	for event: Explore.GameEvent in events:scene._on_event(event)
	scene._update_hud()
	expect(scene.profile.exp_total==100 and Explore.SaveStore.load_profile().exp_total==100,"EXP event saves real total")
	expect(scene.hud.level_up_tick==scene.snapshot.tick and scene.practice_view.audio.played.has("level_up"),"level up banner and recording")
	expect(scene.hud.level_banner_visible(),"new level-up banner visible")
	expect(not scene.hud.feedback_active(0,1000,65),"future tick never displays old feedback")
	expect(not scene.hud.feedback_active(1065,1000,65),"level-up banner expires after65 ticks")
	var hp_max: int = scene.snapshot.hero.max_hp
	expect(hp_max>100,"HUD uses grown max health")
	scene.enter_scene(Explore.SceneDefs.FOREST_LAYERED)
	expect(scene.snapshot.exp_total==100 and scene.snapshot.inventory["herb"]==2,"new core restores EXP and inventory")
	scene._update_hud()
	expect(not scene.hud.level_banner_visible(),"scene change clears old banner")
	expect(scene.hud.exp_glow_tick<0 and scene.hud.item_flash_tick<0,"scene change clears other HUD flashes")
	scene.enter_scene(Explore.SceneDefs.VILLAGE_LAYERED)
	scene._update_hud()
	expect(not scene.hud.fight_hud,"village hides combat HUD")
	scene.enter_scene(Explore.SceneDefs.WOODLAND_LAYERED)
	var at: Vector2 = scene.snapshot.hero.position
	scene.encounter_effects.clear()
	for i: int in 3:
		scene.encounter_effects.number(at,10,"mob",99,scene.snapshot.tick+i)
	expect(scene.encounter_effects.numbers.size()==1 and scene.encounter_effects.numbers[0]["amount"]==30,"rapid hits merge per target/style")
	scene.encounter_effects.number(at,10,"counter",99,scene.snapshot.tick+3)
	expect(scene.encounter_effects.numbers.size()==2,"counter style stays distinct")
	var inventory: Dictionary = scene.snapshot.inventory.duplicate()
	scene._on_event(Explore.GameEvent.new(&"mob_dropped",scene.snapshot.tick,{"position":at,"item_id":&"herb"}))
	expect(scene.encounter_effects.effects.back()["family"]=="drop" and scene.snapshot.inventory==inventory,"drop visual never grants inventory")
	for cue: String in scene.practice_view.audio.WOODLAND_CUES:
		expect(scene.practice_view.audio.WOODLAND_CUES[cue].get_length()>0.0,"all owner clips load")
	var audio: Explore.PracticeView.VillageAudio = scene.practice_view.audio
	audio.mob_types[99] = "boar"
	var event_types: Array[StringName] = [&"mob_alerted",&"attack_telegraphed",&"attack_hit",&"mob_staggered",&"mob_defeated"]
	for i: int in event_types.size():
		audio.handle_event(Explore.GameEvent.new(event_types[i],1000+i*20,{"mob_id":99,"target_id":99,"kind":&"red","reason":&"crash"}),Explore.SceneDefs.WOODLAND_LAYERED)
	for cue: String in ["boar_alert","boar_charge","boar_hurt","boar_crash","boar_death"]:
		expect(audio.played.has(cue),"specific Boar event selects "+cue)
	var alerts: int = int(audio.played.get("boar_alert",0))
	audio.handle_event(Explore.GameEvent.new(&"mob_alerted",1001,{"mob_id":99}),Explore.SceneDefs.WOODLAND_LAYERED)
	expect(int(audio.played.get("boar_alert",0))==alerts,"pack alert deduplicates")
	scene.core.set_exp(100000)
	scene.snapshot = scene.core.snapshot()
	for tick: int in 40:scene._update_hud()
	expect(scene.snapshot.exp_to_next==0 and is_equal_approx(scene.hud.exp_fill,1.0),"top-level gauge is full")
	scene.queue_free()
	await process_frame
	Explore.SaveStore.delete()
	OS.set_environment(Explore.SaveStore.PATH_ENV,previous)
	Engine.remove_meta(Explore.PERSIST_META)
	print("WOODLAND POLISH OK" if failures==0 else "WOODLAND POLISH FAILED")
	quit(0 if failures==0 else 1)
