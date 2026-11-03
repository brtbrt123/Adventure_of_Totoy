extends SceneTree
## The Thornback Stag on the road scene: every pose its states ask for exists in the atlas, the glade loads with the Stag as a boss mob, the
## slam, the charge, the roar and the defeat play through the real scene without errors, and the HUD shows the fight.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("STAG GLADE FAIL: ", label)
		failures += 1


func run() -> void:
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	var none: Array[Snapshots.TelegraphSnapshot] = []
	for state: String in MobView.STATES["stag"]:
		for attack: StringName in [&"stag_slam", &"stag_charge", &"stag_roots"]:
			for ticks: int in [0, 5, 30, 90]:
				var mob: Dictionary = {"type": &"stag", "state": StringName(state), "state_ticks": ticks, "id": 201, "attack_id": attack}
				var key: String = MobView.frame(mob, none, 100)
				check(frames.has(key), "%s/%s/%d asks for %s" % [state, attack, ticks, key])
	Engine.set_meta(Explore.START_META, {"scene": Explore.SceneDefs.GLADE_LAYERED})
	var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	await process_frame
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	var stag: Object = scene.core.mobs.encounters[0].mobs[0]
	var enc: Object = scene.core.mobs.encounters[0]
	check(scene.snapshot.mobs.size() == 1 and bool(scene.snapshot.mobs[0]["boss"]), "the Stag is the glade's boss mob")
	scene.core.player.position = stag.position + Vector2(-60, 0)
	scene.snapshot = scene.core.snapshot()
	var told: Dictionary = {}
	for i: int in 400:
		scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		for event: Object in scene.core.last_events:
			if event.type == scene.GameEvent.ATTACK_TELEGRAPHED:
				told[String(event.data["attack"])] = true
		if i == 120:
			var events: Array[GameEvent] = []
			while stag.hp > stag.max_hp / 2:
				scene.core.mobs.hit_mob(scene.core, enc, stag, 30.0, {}, events)
		if i % 40 == 0:
			scene._update_camera()
			scene.queue_redraw()
			await process_frame
	check(told.has("stag_slam") or told.has("stag_charge"), "it attacked with its first-phase moves")
	check(told.has("stag_roots"), "and with the roots after the roar")
	check(scene.hud.fight_hud, "the fight HUD is on")
	var events2: Array[GameEvent] = []
	while stag.is_alive():
		scene.core.mobs.hit_mob(scene.core, enc, stag, 80.0, {}, events2)
	for i: int in 30:
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
	check(scene.core.has_flag(&"cleared_stag_glade"), "defeating it clears the glade")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("STAG GLADE OK")
	quit(1 if failures else 0)
