extends SceneTree
## The Star Staff in the real game (review capture, 2026-11-01): the Hollow Trial with the real core and the real explore scene,
## the staff equipped, against the Warden: three casts (two Arcane Bursts and the Great Burst), a blink, then Disintegration
## (the cut-in, the circle, the meteor, the blast, the crater). Every frame is the game's own window. Waves before the Warden
## are cleared by lethal hits and the hero's health is refilled each tick (an unattended capture, not play).
##   godot --path . --resolution 1152x648 --script res://presentation/review/staff/capture_staff.gd
## Saves PNG frames to user://staff_capture/ (seq_<n>.png) and prints where; tools turn them into GIFs. Headless: checks only.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")

var scene: Explore
var failures: int = 0
var seen: Dictionary = {}
var frame_index: int = 0
var out_dir: String = ""


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("STAFF CAPTURE FAIL: ", label)


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


func warden() -> Dictionary:
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["type"] == &"warden" and mob["state"] != &"dead":
			return mob
	return {}


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


## Steps `ticks` ticks of `input` (the first tick only, then idle), a frame saved every `every` ticks.
func play(ticks: int, input: InputFrame = null, every: int = 2) -> void:
	for i: int in ticks:
		step(input if input != null and i == 0 else InputFrame.new())
		if i % every == 0:
			await shot()


func run() -> void:
	out_dir = OS.get_user_data_dir() + "/staff_capture/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for file: String in DirAccess.get_files_at(out_dir):
		DirAccess.remove_absolute(out_dir + file)
	Engine.set_meta(Explore.START_META, {"scene": &"hollow_trial_layered"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	scene.core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"])
	scene.core.player.weapon_id = Tuning.WEAPON_STAR_STAFF
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
	for i: int in 240:  # let it finish arriving
		clear_other_mobs()
		step()
	var w: Dictionary = warden()
	if w.is_empty():
		printerr("no Warden: stopping")
		quit(1)
		return
	scene.core.player.position = Vector2(w["position"]) + Vector2(-86, 6)
	scene.core.player.facing = Vector2.RIGHT
	scene.core.player.edge = Tuning.EDGE_MAX
	step()
	await shot()
	# Phantom Cut first (owner 2026-11-01: its echo used to be a sword): every cast is echoed by a phantom burst on the target
	scene.core.player.equipped_aspects = [&"phantom_cut", &"sprint", &"gale_cut"] as Array[StringName]
	var phantom: InputFrame = InputFrame.new()
	phantom.skill_pressed = 1
	step(phantom)
	check(scene.core.player.phantom_ticks_left > 0, "Phantom Cut runs")
	# three casts: two Arcane Bursts, then the Great Burst
	for cast: int in 3:
		var attack: InputFrame = InputFrame.new()
		attack.attack_pressed = true
		attack.aim = aim_at_warden()
		var phases: Array[int] = Weapons.swing_phases(Tuning.WEAPON_STAR_STAFF, cast + 1)
		for i: int in phases[0] + phases[1] + phases[2] - 2:
			var frame_input: InputFrame = attack if i == 0 or i >= phases[0] + phases[1] + phases[2] - Tuning.COMBO_BUFFER_TICKS - 2 else InputFrame.new()
			step(frame_input)
			if i % 2 == 0:
				await shot()
	check(seen.has(GameEvent.STAFF_BURST), "the casts burst")
	check(seen.has(GameEvent.PHANTOM_ECHO), "Phantom Cut echoed the casts")
	check(scene.aspect_fx.filter(func(e: Dictionary) -> bool: return e["kind"] == "echo").is_empty(), "no sword ghost with the staff")
	await play(30)
	# the blink, up and back down
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN]:
		var dash: InputFrame = InputFrame.new()
		dash.dash_pressed = true
		dash.move = direction
		await play(Tuning.DASH_COOLDOWN_TICKS + 4, dash)
	scene.core.player.position = Vector2(warden()["position"]) + Vector2(-96, 4)
	scene.core.player.edge = Tuning.EDGE_MAX
	step()
	# Disintegration: the cut-in first (the world waits), then the skill
	var ult: InputFrame = InputFrame.new()
	ult.weapon_active_pressed = true
	ult.aim = aim_at_warden()
	print("STAFF CAPTURE ULT START %d" % frame_index)
	step(ult)
	check(seen.has(GameEvent.DISINTEGRATION_STARTED), "Disintegration started")
	check(scene.disint_cutin.active, "its cut-in plays")
	var clock: float = 0.0
	while scene.disint_cutin.active and clock < 3.0:
		scene.disint_cutin.advance(1.0 / 30.0)
		clock += 1.0 / 30.0
		await shot()
	await play(Weapons.disintegration_total_ticks() + 170)
	check(seen.has(GameEvent.DISINTEGRATION_IMPACT), "the meteor landed")
	print("STAFF CAPTURE: %d frames in %s" % [frame_index, out_dir])
	print("STAFF CAPTURE OK" if failures == 0 else "STAFF CAPTURE FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
