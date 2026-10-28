extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const OUT: String = "res://art/reference/woodland_installed_20261028/"
var scene: Explore
func _init() -> void:call_deferred("run")
func refresh() -> void:
	scene._choose_frames()
	scene._update_camera()
	scene._update_hud()
	scene.encounter_effects.sync(scene.snapshot,scene.colors,scene.frames,scene.sprites)
	scene.practice_view.sync(scene.snapshot,scene.practice_effects,scene.frames,scene.sprites)
	scene.queue_redraw()
func snap(name: String) -> void:
	refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(OUT+name+".png")!=OK:quit(1)
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META,{"scene":Explore.SceneDefs.WOODLAND_LAYERED})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	scene.core.set_flag(&"received_first_sword")
	scene.core.set_inventory({"herb":3})
	scene.core.place_at(Vector2(112,276))
	scene.snapshot = scene.core.snapshot()
	scene.toast_message = "CAPTURE FIXTURE - HUD / MOB STATES"
	scene.toast_ticks = 150
	await process_frame
	await snap("hud_locked_slots")
	for fraction: float in [0.0,0.25,0.5,0.95,1.0]:
		scene.hud.exp_fill = fraction
		scene.snapshot.exp_to_next = 0 if fraction==1.0 else 100
		scene.snapshot.exp = roundi(fraction*100)
		scene.snapshot.level = 10 if fraction==1.0 else 5
		scene.hud.shown_level = scene.snapshot.level
		await snap("exp_%d" % int(fraction*100))
	scene.snapshot.exp_to_next = 100
	scene.snapshot.level = 5
	scene.snapshot.exp = 50
	scene.snapshot.tick = 100
	scene._on_event(Explore.GameEvent.new(&"level_up",100,{"level":5}))
	await snap("level_up")
	scene.hud.level_up_tick = -1000
	for percentage: int in [100,55,15]:
		for i: int in scene.snapshot.mobs.size():
			scene.snapshot.mobs[i]["hp"] = maxi(1,roundi(int(scene.snapshot.mobs[i]["max_hp"])*percentage/100.0))
			scene.snapshot.mobs[i]["level"] = i+1
		await snap("mob_hp_%d" % percentage)
	for mob_type: String in ["mossling","boar"]:
		var sample: Dictionary = {}
		for mob: Dictionary in scene.core.snapshot().mobs:
			if String(mob["type"])==mob_type:sample=mob.duplicate(true);break
		for state: String in ["idle","alert","chase","windup","strike","recover","crash","stagger","hurt","return","dead"]:
			var mob: Dictionary = sample.duplicate(true)
			mob["position"] = Vector2(160,276)
			mob["state"] = StringName(state)
			mob["state_ticks"] = 5
			mob["hp"] = 0 if state=="dead" else int(mob["max_hp"])/2
			mob["exposed"] = state in ["crash","stagger"]
			scene.snapshot.mobs.assign([mob])
			await snap(mob_type+"_"+state)
	scene.snapshot.mobs = scene.core.snapshot().mobs
	scene.encounter_effects.clear()
	for entry: Dictionary in [{"style":"mob","at":Vector2(150,276),"amount":12},{"style":"counter","at":Vector2(190,276),"amount":36},{"style":"hero","at":scene.snapshot.hero.position,"amount":12},{"style":"heal","at":Vector2(112,310),"amount":35}]:
		scene.encounter_effects.number(entry["at"],entry["amount"],entry["style"],hash(entry["style"]),scene.snapshot.tick)
	await snap("damage_styles")
	scene.encounter_effects.clear()
	for name: String in ["mob_alerted","attack_hit","parry_succeeded","mob_staggered","mob_defeated","mob_dropped","item_used"]:
		var data: Dictionary = {"position":Vector2(156,276),"damage":12,"healed":35,"target_id":99}
		scene.encounter_effects.handle_event(Explore.GameEvent.new(StringName(name),scene.snapshot.tick,data),scene.snapshot)
		await snap("fx_"+name)
		scene.encounter_effects.clear()
	scene.snapshot.defeated = true
	await snap("down")
	print("INSTALLED WOODLAND CAPTURES OK")
	quit(0)
