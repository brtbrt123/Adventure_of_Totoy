extends SceneTree
## Windowed renderer captures. New-rule fixtures prove presentation only, not gameplay.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
var scene: Explore
var captured: Dictionary = {}
const OUT: String = "res://art/reference/thornback_fx_review_v3/live/"

func _init() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	scene._update_camera()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(OUT + name + ".png")
	print("CAPTURE ", name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.set_meta(Explore.START_META, {"scene": Explore.SceneDefs.GLADE_LAYERED})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	await process_frame
	scene.core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"])
	var stag: Object = scene.core.mobs.encounters[0].mobs[0]
	var enc: Object = scene.core.mobs.encounters[0]
	for i: int in 950:
		scene.core.player.hp = scene.core.hero_max_hp()
		if stag.state not in [&"windup", &"strike"]:
			scene.core.player.position = stag.position + Vector2(-100 if i % 300 > 150 else -42, 18)
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		if i == 240:
			var events: Array[Explore.GameEvent] = []
			while stag.hp > stag.max_hp / 2:
				scene.core.mobs.hit_mob(scene.core, enc, stag, 30.0, {}, events)
		for mob: Dictionary in scene.snapshot.mobs:
			if mob["type"] != &"stag":continue
			var key: String = String(mob["attack_id"]) + "_" + String(mob["state"])
			if mob["state"] in [&"strike", &"windup"] and int(mob["state_ticks"]) >= 3 and not captured.has(key):
				captured[key] = true
				await shot("live_" + key)
	# A deliberately labelled, core-shaped fixture for rules that Claude still needs to add.
	var base: Dictionary = scene.snapshot.mobs[0].duplicate(true)
	var center: Vector2 = base["position"]
	scene.snapshot.hero.position = center + Vector2(-35, 12)
	scene.snapshot.tick += 100
	base["state"] = &"strike"
	base["state_ticks"] = 3
	base["attack_id"] = &"stag_roots"
	base["facing"] = Vector2.RIGHT
	scene.snapshot.mobs.assign([base])
	scene.snapshot.telegraphs.clear()
	for i: int in 8:
		var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		tell.id = 9000 + i
		tell.owner_id = int(base["id"])
		tell.attack = &"stag_roots"
		tell.center = center + Vector2(-120 + (i % 4) * 80, -55 if i < 4 else 65)
		tell.size = 34
		tell.hit_tick = scene.snapshot.tick - 3
		tell.end_tick = scene.snapshot.tick + 2
		scene.snapshot.telegraphs.append(tell)
	scene.creature_effects.clear()
	scene.creature_effects.sync(scene.snapshot)
	await shot("fixture_eight_roots_NOT_CORE_GAMEPLAY")
	scene.snapshot.tick += 60
	scene.snapshot.telegraphs.clear()
	base["attack_id"] = &"stag_summon"
	base["state"] = &"windup"
	base["state_ticks"] = 66
	base["regen_active"] = true
	base["cast_start_tick"] = scene.snapshot.tick - 66
	base["cast_release_tick"] = scene.snapshot.tick + 18
	for i: int in 5:
		var moth: Dictionary = base.duplicate(true)
		moth["id"] = 500 + i
		moth["type"] = &"glowmoth"
		moth["position"] = center + Vector2(-100 + i * 50, -55 if i % 2 else 45)
		moth["state"] = &"idle"
		moth["boss"] = false
		moth["radius"] = 5.0
		moth["hp"] = 12
		moth["max_hp"] = 12
		moth["summoner_id"] = int(base["id"])
		scene.snapshot.mobs.append(moth)
	scene.creature_effects.clear()
	scene.creature_effects.sync(scene.snapshot)
	await shot("fixture_chant_moths_regen_NOT_CORE_GAMEPLAY")
	scene.queue_free()
	await process_frame
	print("CREATURE CAPTURE OK / natural attacks plus labelled future-rule fixtures")
	quit()
