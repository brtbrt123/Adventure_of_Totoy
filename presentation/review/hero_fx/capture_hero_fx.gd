extends SceneTree
## The hero's combat effects in the staff's style in the real game (review capture, 2026-11-02): the Hollow Trial with the real
## core and the real explore scene, against the Warden: the katana's, the daggers' and the scythe's full combos (the new trails,
## hits, sparks, dust, rings, light), a dash up and back, then parries. Every frame is the game's own window. Waves before the
## Warden are cleared by lethal hits, the hero's health is refilled each tick and the Warden's posture is kept from breaking (an
## unattended capture, not play).
##   godot --path . --resolution 1152x648 --script res://presentation/review/hero_fx/capture_hero_fx.gd
## Saves PNG frames to user://hero_fx_capture/ (seq_<n>.png) and segments.json (which frames show what); tools/art/
## hero_fx_capture_gif.py turns them into GIFs. Headless: checks only.
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
var segments: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("HERO FX CAPTURE FAIL: ", label)


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


## The Warden stays up for the whole capture: its health is topped up (the capture is about the hero's effects).
func keep_warden() -> void:
	var mob: Object = warden_mob()
	if mob != null:
		mob.hp = mob.max_hp


func aim_at_warden() -> Vector2:
	var w: Dictionary = warden()
	return (Vector2(w["position"]) - scene.snapshot.hero.position).normalized() if not w.is_empty() else Vector2.RIGHT


func stand_by_warden(offset: Vector2) -> void:
	scene.core.player.position = Vector2(warden()["position"]) + offset
	scene.core.player.facing = Vector2.RIGHT if offset.x < 0 else Vector2.LEFT
	step()


## Steps `ticks` ticks of `input` (the first tick only, then idle), a frame saved every `every` ticks.
func play(ticks: int, input: InputFrame = null, every: int = 2) -> void:
	for i: int in ticks:
		keep_warden()
		step(input if input != null and i == 0 else InputFrame.new())
		if i % every == 0:
			await shot()


## The weapon's whole combo: each swing pressed again just inside the combo buffer of the one before.
func combo(weapon: StringName) -> void:
	var swings: int = Weapons.combo_max(weapon)
	for swing: int in swings:
		var phases: Array[int] = Weapons.swing_phases(weapon, swing + 1)
		var length: int = phases[0] + phases[1] + phases[2]
		var last: bool = swing == swings - 1
		for i: int in (length + 16 if last else length - 2):
			keep_warden()
			var press: bool = i == 0 or (not last and i >= length - Tuning.COMBO_BUFFER_TICKS - 2)
			var input: InputFrame = InputFrame.new()
			if press:
				input.attack_pressed = true
				input.aim = aim_at_warden()
			step(input)
			if i % 2 == 0:
				await shot()


func run() -> void:
	out_dir = OS.get_user_data_dir() + "/hero_fx_capture/"
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
	for i: int in 240:  # let it finish arriving
		clear_other_mobs()
		step()
	if warden().is_empty():
		printerr("no Warden: stopping")
		quit(1)
		return
	for weapon: StringName in [Tuning.WEAPON_BLACK_KATANA, Tuning.WEAPON_DUAL_DAGGER, Tuning.WEAPON_CHAIN_SCYTHE]:
		scene.core.player.weapon_id = weapon
		stand_by_warden(Vector2(-30, 4))
		var start: int = frame_index
		await play(8)
		await combo(weapon)
		segments[String(weapon)] = [start, frame_index]
	check(seen.has(GameEvent.ATTACK_HIT), "the swings hit")
	# the dash: up and back down, with the katana
	scene.core.player.weapon_id = Tuning.WEAPON_BLACK_KATANA
	stand_by_warden(Vector2(-60, 10))
	var dash_start: int = frame_index
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN]:
		var dash: InputFrame = InputFrame.new()
		dash.dash_pressed = true
		dash.move = direction
		await play(Tuning.DASH_COOLDOWN_TICKS + 4, dash)
	segments["dash"] = [dash_start, frame_index]
	# parries: wait by the Warden for its gold attacks and press parry just before each lands
	stand_by_warden(Vector2(-26, 2))
	var parry_start: int = frame_index
	var parries: int = 0
	for i: int in 1500:
		keep_warden()
		var input: InputFrame = InputFrame.new()
		for tell: Variant in scene.snapshot.telegraphs:
			if tell.kind == &"gold" and tell.hit_tick - scene.snapshot.tick == 3:
				input.parry_pressed = true
		step(input)
		if scene.core.last_events.any(func(e: GameEvent) -> bool: return e.type == GameEvent.PARRY_SUCCEEDED):
			parries += 1
		var w: Dictionary = warden()
		if not w.is_empty() and scene.snapshot.hero.position.distance_to(Vector2(w["position"])) > 40.0:
			scene.core.player.position = Vector2(w["position"]) + Vector2(-26, 2)
		if i % 2 == 0 and (parries > 0 or i % 6 == 0):
			await shot()
		if parries >= 3:
			await play(30)
			break
	print("HERO FX CAPTURE parries: %d" % parries)
	segments["parry"] = [parry_start, frame_index]
	var file: FileAccess = FileAccess.open(out_dir + "segments.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(segments))
	file.close()
	print("HERO FX CAPTURE: %d frames in %s" % [frame_index, out_dir])
	print("HERO FX CAPTURE OK" if failures == 0 else "HERO FX CAPTURE FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
