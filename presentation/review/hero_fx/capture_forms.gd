extends SceneTree
## The weapon forms in the staff's style in the real game (review capture, 2026-11-02, phase 2 of the effects redo): the Hollow
## Trial with the real core and explore scene, against the Warden. The katana's Black Form with a combo (black fire, the black
## slash on the hit area, embers, the violet light), the daggers' Lightning Form (blinks, cuts, chains, the sky strike, the
## crackle) and the scythe's Reaper's Coil (the throw, hook, drag, spin and pull). The weapon cut-ins are skipped (not part of
## this redo). Waves before the Warden are cleared by lethal hits, the hero's health is refilled and the Warden's health topped
## up each tick (an unattended capture, not play).
##   godot --path . --resolution 1152x648 --script res://presentation/review/hero_fx/capture_forms.gd
## Saves PNG frames to user://forms_capture/ (seq_<n>.png) and segments.json; tools/art/hero_fx_capture_gif.py <dir> 0.55
## art/reference/form_fx_v1/ingame turns them into GIFs. Headless: checks only.
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
		printerr("FORMS CAPTURE FAIL: ", label)


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
	var mob: Object = warden_mob()
	if mob != null:
		mob.hp = mob.max_hp
	scene.advance(input)
	scene.fade_phase = &""
	for event: GameEvent in scene.core.last_events:
		seen[event.type] = true
	while scene.cutin_playing():  # skip the weapon cut-ins (the world waits for them)
		for cut: Object in [scene.cutin, scene.lightning_cutin, scene.coil_cutin, scene.disint_cutin]:
			if cut != null and cut.active:
				cut.advance(1.0 / 30.0)


func warden() -> Dictionary:
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["type"] == &"warden" and mob["state"] != &"dead":
			return mob
	return {}


func warden_mob() -> Object:
	for enc: Object in scene.core.mobs.encounters:
		for mob: Object in enc.mobs:
			if mob.type == &"warden" and mob.is_alive():
				return mob
	return null


func clear_other_mobs() -> void:
	var events: Array[GameEvent] = []
	for enc: Object in scene.core.mobs.encounters:
		for mob: Object in enc.mobs:
			if mob.is_alive() and mob.type != &"warden":
				scene.core.mobs.hit_mob(scene.core, enc, mob, 10000.0, {}, events)
	scene.snapshot = scene.core.snapshot()
	for event: GameEvent in events:
		scene._on_event(event)


func aim_at_warden() -> Vector2:
	var w: Dictionary = warden()
	return (Vector2(w["position"]) - scene.snapshot.hero.position).normalized() if not w.is_empty() else Vector2.RIGHT


## The form: its active pressed by the Warden, then `ticks` ticks with an attack pressed every `attack_every` ticks.
func form(weapon: StringName, offset: Vector2, ticks: int, attack_every: int) -> void:
	for i: int in 1200:  # the form before ends first (an active never starts while another runs)
		if not scene.snapshot.hero.weapon_buff_active and scene.snapshot.hero.weapon_form == &"" and scene.snapshot.hero.state in [&"idle", &"walk"]:
			break
		step()
	scene.core.player.weapon_id = weapon
	scene.core.player.edge = Tuning.EDGE_MAX
	scene.core.player.active_cooldowns.clear()
	scene.core.player.position = Vector2(warden()["position"]) + offset
	scene.core.player.facing = Vector2.RIGHT
	step()
	var start: int = frame_index
	await shot()
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	active.aim = aim_at_warden()
	step(active)
	for i: int in ticks:
		var input: InputFrame = InputFrame.new()
		if attack_every > 0 and i % attack_every == 0:
			input.attack_pressed = true
			input.aim = aim_at_warden()
		step(input)
		if i % 2 == 0:
			await shot()
	segments[String(weapon)] = [start, frame_index]


func run() -> void:
	out_dir = OS.get_user_data_dir() + "/forms_capture/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for file: String in DirAccess.get_files_at(out_dir):
		DirAccess.remove_absolute(out_dir + file)
	Engine.set_meta(Explore.START_META, {"scene": &"hollow_trial_layered"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	scene.core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"])
	scene.snapshot = scene.core.snapshot()
	scene.fade_phase = &""
	scene._refresh_props()
	scene._update_hud()
	for i: int in 130:  # walk to the altar and wake the trial
		if scene.snapshot.hero.position.distance_to(Vector2(256, 204)) < 4:
			break
		var walk: InputFrame = InputFrame.new()
		walk.move = (Vector2(256, 204) - scene.snapshot.hero.position).normalized()
		step(walk)
	var press: InputFrame = InputFrame.new()
	press.interact_pressed = true
	step(press)
	for i: int in 6000:  # clear the waves until the Warden stands
		step()
		if not warden().is_empty():
			break
		if i % 20 == 0:
			clear_other_mobs()
	check(not warden().is_empty(), "the Warden arrived")
	for i: int in 240:
		clear_other_mobs()
		step()
	if warden().is_empty():
		printerr("no Warden: stopping")
		quit(1)
		return
	var mob: Object = warden_mob()
	mob.position = Vector2(300, 262)  # the fight in the middle of the room
	scene.snapshot = scene.core.snapshot()
	await form(Tuning.WEAPON_BLACK_KATANA, Vector2(-30, 4), 110, 9)
	check(seen.has(&"weapon_buff_started"), "the Black Form started")
	await form(Tuning.WEAPON_DUAL_DAGGER, Vector2(-30, 4), 150, 6)
	check(seen.has(&"lightning_blink") or seen.has(&"lightning_strike"), "the Lightning Form blinked")
	await form(Tuning.WEAPON_CHAIN_SCYTHE, Vector2(-70, 4), 150, 0)
	check(seen.has(&"reaper_coil_hooked") or seen.has(&"reaper_coil_missed"), "the Reaper's Coil threw its hook")
	var file: FileAccess = FileAccess.open(out_dir + "segments.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(segments))
	file.close()
	print("FORMS CAPTURE: %d frames in %s" % [frame_index, out_dir])
	print("FORMS CAPTURE OK" if failures == 0 else "FORMS CAPTURE FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
