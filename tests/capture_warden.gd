extends SceneTree
## Real renderer, test encounter: glade Stag replaced with a Warden. No production map/rule changes.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Mob := preload("res://core/mob.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const OUT: String = "res://presentation/review/warden/"
var scene: Explore
var warden: Mob
var captured: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	scene._update_camera()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ",name)

func setup(attack_index: int = 0, distance: float = 34.0) -> void:
	scene.core = scene.ExploreCore.new(Explore.SceneDefs.GLADE_LAYERED)
	scene.core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"])
	var enc: Object = scene.core.mobs.encounters[0]
	var home: Vector2 = enc.mobs[0].home
	enc.mobs.clear()
	warden = Mob.new()
	warden.setup(900,&"warden",enc.id,home,0)
	warden.attack_index = attack_index
	enc.mobs.append(warden)
	scene.core.player.position = home + Vector2(-distance,0)
	scene.core.player.hp = scene.core.hero_max_hp()
	scene.snapshot = scene.core.snapshot()
	scene.creature_effects.clear()
	scene.practice_view.audio.reset()
	scene.fade_phase = &""
	scene._update_hud()
	scene.creature_effects.sync(scene.snapshot)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.set_meta(Explore.START_META, {"scene":Explore.SceneDefs.GLADE_LAYERED})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	setup()
	await shot("guarded")
	# Exercise real core state transitions and its automatic Cleave -> Lash chain.
	for i: int in 320:
		scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		if warden.state in [&"windup", &"strike"]:
			var name: String = String(warden.attack_stats()["id"]) + "_" + String(warden.state)
			if not captured.has(name) and warden.state_ticks >= (20 if warden.state == &"windup" else 1):
				captured[name] = true
				await shot(name)
	setup(2,30)
	for i: int in 170:
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		if warden.state in [&"windup", &"strike"]:
			var name: String = String(warden.attack_stats()["id"]) + "_" + String(warden.state)
			if not captured.has(name) and warden.state_ticks >= (30 if warden.state == &"windup" else 1):
				captured[name] = true
				await shot(name)
	setup()
	var events: Array[GameEvent] = []
	scene.core.mobs.hit_mob(scene.core,scene.core.mobs.encounters[0],warden,10.0,{},events)
	scene.snapshot = scene.core.snapshot()
	for event: GameEvent in events:
		scene._on_event(event)
	scene.creature_effects.sync(scene.snapshot)
	await shot("guard_hit")
	# Fresh encounter: parry is an input intent; core chooses success and exposure.
	setup()
	for i: int in 210:
		var input: InputFrame = InputFrame.new()
		if warden.state == &"windup" and warden.state_ticks >= int(warden.attack_stats()["windup"]) - 5:
			input.parry_pressed = true
		scene.advance(input)
		scene.fade_phase = &""
		if i % 3 == 0:
			await shot("loop_%03d" % (i / 3))
		if warden.state == &"stagger" and warden.state_ticks == 20:
			await shot("exposed")
			captured["exposed"] = true
	events.clear()
	scene.core.mobs.hit_mob(scene.core,scene.core.mobs.encounters[0],warden,10000.0,{},events)
	scene.snapshot = scene.core.snapshot()
	for event: GameEvent in events:
		scene._on_event(event)
	for i: int in 40:
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		if i in [0,12,28,37,38]:
			await shot("death_%02d" % i)
	setup()
	scene.core.player.position = warden.position + Vector2(34,0)
	for i: int in 120:
		scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		if warden.state in [&"windup", &"strike"]:
			var name: String = "right_" + String(warden.state)
			if not captured.has(name) and warden.state_ticks >= (20 if warden.state == &"windup" else 1):
				captured[name] = true
				await shot(name)
	var okay: bool = captured.has("exposed")
	for attack: String in ["cleave","lash","ring"]:
		for state: String in ["windup","strike"]:
			okay = okay and captured.has("warden_"+attack+"_"+state)
	scene.queue_free()
	await process_frame
	print("WARDEN CAPTURE ", "OK" if okay else "FAIL missing state")
	quit(0 if okay else 1)
