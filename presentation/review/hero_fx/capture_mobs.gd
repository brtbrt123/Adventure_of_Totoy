extends SceneTree
## The mobs' attacks in the staff's style in the real game (review capture, 2026-11-02, phase 4 of the effects redo). The Hollow
## Trial's waves (mosslings and boars charging and crashing), then the Warden (its blows, guard hits, the stagger, its fall), then
## the Thornback stag in its glade (slam, charge, roots, the chant and its glowmoths). The hero fights with the katana, swinging
## at the nearest mob and parrying gold attacks; his health is refilled each tick (an unattended capture, not play).
##   godot --path . --resolution 1152x648 --script res://presentation/review/hero_fx/capture_mobs.gd
##   godot --path . --resolution 1152x648 --script res://presentation/review/hero_fx/capture_mobs.gd -- --part=stag
## (one scene per run: the trial and the Warden, or the stag's glade). Saves PNG frames to user://mobs_capture/ or
## user://mobs_capture_stag/ (seq_<n>.png) and segments.json; tools/art/hero_fx_capture_gif.py <dir> 0.55
## art/reference/mob_fx_v1/ingame turns them into GIFs. Headless: checks only.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")

var scene: Explore
var failures: int = 0
var seen: Dictionary = {}
var frame_index: int = 0
var out_dir: String = ""
var segments: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("MOBS CAPTURE FAIL: ", label)


func shot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "seq_%04d.png" % frame_index)
	frame_index += 1


func step(input: InputFrame = InputFrame.new()) -> void:
	scene.core.player.hp = scene.core.hero_max_hp()
	scene.advance(input)
	scene.fade_phase = &""
	for event: GameEvent in scene.core.last_events:
		seen[event.type] = true


func open(id: StringName) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
	Engine.set_meta(Explore.START_META, {"scene": id})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	scene.core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"])
	scene.core.player.weapon_id = Tuning.WEAPON_BLACK_KATANA
	scene.snapshot = scene.core.snapshot()
	scene.fade_phase = &""
	scene._refresh_props()
	scene._update_hud()


func nearest(types: Array = []) -> Dictionary:
	var best: Dictionary = {}
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["state"] == &"dead" or (not types.is_empty() and mob["type"] not in types):
			continue
		if best.is_empty() or scene.snapshot.hero.position.distance_to(mob["position"]) < scene.snapshot.hero.position.distance_to(best["position"]):
			best = mob
	return best


## `ticks` ticks of fighting: close in on the nearest mob, swing every 14 ticks, parry gold attacks just before they land.
func fight(ticks: int, types: Array = [], keep: float = 26.0) -> void:
	for i: int in ticks:
		var input: InputFrame = InputFrame.new()
		var mob: Dictionary = nearest(types)
		if not mob.is_empty():
			var to: Vector2 = Vector2(mob["position"]) - scene.snapshot.hero.position
			if to.length() > keep + float(mob["radius"]):
				input.move = to.normalized()
			elif i % 14 == 0:
				input.attack_pressed = true
				input.aim = to.normalized()
		for tell: Variant in scene.snapshot.telegraphs:
			if tell.kind == &"gold" and tell.hit_tick - scene.snapshot.tick == 3:
				input.parry_pressed = true
		step(input)
		if i % 2 == 0:
			await shot()


func kill(types: Array) -> void:
	var events: Array[GameEvent] = []
	for enc: Object in scene.core.mobs.encounters:
		for mob: Object in enc.mobs:
			if mob.is_alive() and mob.type in types:
				scene.core.mobs.hit_mob(scene.core, enc, mob, 10000.0, {}, events)
	scene.snapshot = scene.core.snapshot()
	for event: GameEvent in events:
		scene._on_event(event)


func run() -> void:
	var part: String = "trial"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--part="):
			part = arg.trim_prefix("--part=")
	out_dir = OS.get_user_data_dir() + ("/mobs_capture/" if part == "trial" else "/mobs_capture_%s/" % part)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for file: String in DirAccess.get_files_at(out_dir):
		DirAccess.remove_absolute(out_dir + file)
	if part == "stag":
		await stag_part()
	else:
		await trial_part()
	var file: FileAccess = FileAccess.open(out_dir + "segments.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(segments))
	file.close()
	print("MOBS CAPTURE: %d frames in %s" % [frame_index, out_dir])
	print("MOBS CAPTURE OK" if failures == 0 else "MOBS CAPTURE FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func trial_part() -> void:
	await open(&"hollow_trial_layered")
	for i: int in 130:  # walk to the altar and wake the trial
		if scene.snapshot.hero.position.distance_to(Vector2(256, 204)) < 4:
			break
		var walk: InputFrame = InputFrame.new()
		walk.move = (Vector2(256, 204) - scene.snapshot.hero.position).normalized()
		step(walk)
	var wake: InputFrame = InputFrame.new()
	wake.interact_pressed = true
	step(wake)
	var start: int = frame_index
	await fight(420)
	segments["trial_waves"] = [start, frame_index]
	for i: int in 6000:  # on to the Warden: the rest of the waves fall quickly
		if not nearest([&"warden"]).is_empty():
			break
		if i % 20 == 0:
			kill([&"mossling", &"boar"])
		step()
	check(not nearest([&"warden"]).is_empty(), "the Warden arrived")
	for i: int in 240:
		kill([&"mossling", &"boar"])
		step()
	start = frame_index
	await fight(330, [&"warden"], 30.0)
	kill([&"warden"])
	for i: int in 70:
		step()
		if i % 2 == 0:
			await shot()
	segments["warden"] = [start, frame_index]


func stag_part() -> void:
	await open(&"glade_layered")
	var stag: Dictionary = nearest([&"stag"])
	check(not stag.is_empty(), "the glade has its stag")
	if stag.is_empty():
		return
	scene.core.player.position = Vector2(stag["position"]) + Vector2(-70, 10)
	step()
	var start: int = frame_index
	await fight(480, [&"stag", &"glowmoth"], 40.0)
	segments["stag"] = [start, frame_index]
