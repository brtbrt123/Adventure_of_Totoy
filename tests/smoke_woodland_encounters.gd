extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Bot := preload("res://tests/explore_bot.gd")
const Mob := preload("res://core/mob.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Title := preload("res://presentation/menu/title.gd")
var scene: Explore
var failures: int = 0
var capture: bool = false
var awards: int = 0
var output: String = "res://art/reference/woodland_playable_20261028/"
func _init() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		printerr("WOODLAND ENCOUNTERS FAIL: ",message)
		failures += 1
func step(intent: InputFrame = null) -> void:
	scene.advance(intent if intent != null else InputFrame.new())
	for event: Explore.GameEvent in scene.core.last_events:
		if event.type == &"item_received": awards += 1
func snap(label: String) -> void:
	if not capture:return
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output+label+".png") == OK,"capture "+label)
func walk(target: Vector2) -> bool:
	var bot: Bot = Bot.new()
	if not bot.plan(scene.snapshot.size,scene.core.obstacles,scene.snapshot.hero.position,target):return false
	for tick: int in 3000:
		step(bot.next_input(scene.snapshot.hero.position))
		if scene.snapshot.hero.position.distance_to(target)<4.0:return true
	return false
func spawn() -> void:
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var previous: String = OS.get_environment(Explore.SaveStore.PATH_ENV)
	OS.set_environment(Explore.SaveStore.PATH_ENV,"user://woodland_encounters_smoke.json")
	Explore.SaveStore.delete()
	Engine.set_meta(Explore.PERSIST_META,true)
	Engine.set_meta(Explore.START_META,{"scene":Explore.SceneDefs.WOODLAND_LAYERED})
	spawn()
	await process_frame
	expect(walk(Vector2(616,248)),"walk west to east")
	expect(walk(Vector2(24,248)),"walk east to west")
	scene.core.set_flag(&"received_first_sword")
	step()
	# Full production map, dormant creatures at real scale.
	if capture:
		scene.get_node("HUD").hide()
		scene.camera.enabled = false
		root.content_scale_size = Vector2i(640,400)
		root.size = Vector2i(1280,800)
		await snap("full_map")
		scene.get_node("HUD").show()
		scene.camera.enabled = true
		root.content_scale_size = Vector2i(320,180)
		root.size = Vector2i(1280,720)
	scene.core.place_at(Vector2(112,276))
	var started: int = -1
	var parried: bool = false
	var windup: int = int(Explore.Tuning.MOBS[&"mossling"]["attack"]["windup"])
	for tick: int in 800:
		for mob: Dictionary in scene.snapshot.mobs:
			if mob["encounter_id"] == &"mossling_clearing" and mob["state"] == &"windup" and started < 0:
				started = scene.snapshot.tick
				await snap("west_gold_warning")
		var intent: InputFrame = InputFrame.new()
		intent.parry_pressed = started >= 0 and scene.snapshot.tick == started+windup-1
		step(intent)
		for event: Explore.GameEvent in scene.core.last_events:
			parried = parried or event.type == &"parry_succeeded"
		if parried:break
	expect(started >= 0 and parried,"wake west pack and parry gold lunge")
	await snap("west_parry_exposed")
	# Isolate the award/save path from difficulty: subsequent enemy attacks are held on cooldown.
	# Every defeat still comes from real player attacks and real core hit resolution.
	var cleared: bool = false
	for tick: int in 3600:
		var target: Mob = null
		for encounter: Explore.ExploreCore.MobField.Encounter in scene.core.mobs.encounters:
			if encounter.id != &"mossling_clearing":continue
			cleared = encounter.state == &"cleared"
			for mob: Mob in encounter.mobs:
				mob.cooldown = 10000
				if mob.is_alive() and target == null:target = mob
		if cleared:break
		if target == null:break
		scene.core.place_at(target.position-Vector2(16,0))
		var strike: InputFrame = InputFrame.new()
		strike.attack_pressed = true
		strike.attack_held = true
		strike.aim = Vector2.RIGHT
		step(strike)
	expect(cleared and awards == 1,"clear pack and grant exactly one receipt")
	expect(int(scene.profile.inventory.get("herb",0)) == 1 and scene.profile.story_flags.has(&"cleared_mossling_clearing"),"reward and cleared flag saved together")
	expect(scene.profile.exp_total == 30,"west clearing saves30 EXP alongside one drop")
	scene.reward_popup.advance(0.0)
	expect(scene.reward_popup.receipt.get("icon","") == "hud_copper_herb","real reward popup icon")
	await snap("west_cleared_receipt")
	for area: Dictionary in [{"name":"east_red_warning","at":Vector2(560,276),"enc":&"boar_clearing"},{"name":"camp_gold_warning","at":Vector2(320,128),"enc":&"camp_ambush"}]:
		scene.core.player.hp = Explore.Tuning.PLAYER_MAX_HP
		scene.core.place_at(area["at"])
		var found_warning: bool = false
		for tick: int in 240:
			step()
			if not scene.snapshot.telegraphs.is_empty():
				var correct: bool = false
				for mob: Dictionary in scene.snapshot.mobs:
					correct = correct or (mob["encounter_id"] == area["enc"] and mob["state"] == &"windup")
				if correct:
					found_warning = true
					break
		expect(found_warning,"real warning in "+String(area["name"]))
		await snap(area["name"])
	scene.queue_free()
	await process_frame
	# The actual title's Continue metadata, not a manually rebuilt save fixture.
	var title: Title = (load("res://presentation/menu/title.tscn") as PackedScene).instantiate() as Title
	root.add_child(title)
	title.change_scene = func(_path: String) -> void: pass
	await process_frame
	title.index = 1
	title.activate()
	title.queue_free()
	spawn()
	await process_frame
	var west_alive: int = 0
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["encounter_id"] == &"mossling_clearing":west_alive += 1
	expect(scene.snapshot.scene_id == Explore.SceneDefs.WOODLAND_LAYERED and west_alive == 0,"Continue keeps west pack cleared")
	expect(int(scene.snapshot.inventory.get("herb",0)) == 1 and scene.reward_popup.pending.is_empty(),"Continue keeps herbs and never replays reward")
	expect(scene.snapshot.exp_total == 30,"Continue restores earned EXP")
	scene.queue_free()
	await process_frame
	Explore.SaveStore.delete()
	OS.set_environment(Explore.SaveStore.PATH_ENV,previous)
	Engine.remove_meta(Explore.PERSIST_META)
	print("WOODLAND ENCOUNTERS OK" if failures == 0 else "WOODLAND ENCOUNTERS FAILED")
	quit(0 if failures == 0 else 1)
