extends SceneTree
## A phone-shaped view of the real game for the mobile blueprint (review capture, 2026-11-02; owner: "make a blueprint for how it
## is gonna look if we do a mobile"). The Hollow Trial with the real core and explore scene, against the Warden, in a 20:9 window
## with the expand aspect (the camera shows more world to the sides instead of black bars) and the desktop HUD hidden, so
## tools/art/mobile_blueprint.py can draw the touch layout over it. A katana combo is played; frames are saved during it.
##   godot --path . --resolution 1440x648 --script res://presentation/review/mobile/capture_mobile_view.gd
## Saves PNG frames to user://mobile_capture/ (seq_<n>.png, 3x of a 480x216 view) and hud.png (the desktop HUD alone in a 16:9
## window over magenta). Headless: checks only.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")

var scene: Explore
var frame_index: int = 0
var out_dir: String = ""


func _init() -> void:
	call_deferred("run")


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


func run() -> void:
	out_dir = OS.get_user_data_dir() + "/mobile_capture/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for file: String in DirAccess.get_files_at(out_dir):
		DirAccess.remove_absolute(out_dir + file)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	Engine.set_meta(Explore.START_META, {"scene": &"hollow_trial_layered"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	for child: Node in scene.get_children():
		if child is CanvasLayer:
			child.visible = false  # the desktop HUD: the blueprint draws the touch layout instead
	scene.core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"])
	scene.snapshot = scene.core.snapshot()
	scene.fade_phase = &""
	scene._refresh_props()
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
	for i: int in 240:
		clear_other_mobs()
		step()
	if warden().is_empty():
		printerr("no Warden: stopping")
		quit(1)
		return
	for enc: Object in scene.core.mobs.encounters:  # the fight in the middle of the room, so the wide view shows no void
		for mob: Object in enc.mobs:
			if mob.type == &"warden" and mob.is_alive():
				mob.position = Vector2(300, 262)
	scene.snapshot = scene.core.snapshot()
	scene.core.player.weapon_id = Tuning.WEAPON_BLACK_KATANA
	scene.core.player.position = Vector2(warden()["position"]) + Vector2(-30, 4)
	scene.core.player.facing = Vector2.RIGHT
	step()
	await shot()
	var phases: Array[int] = Weapons.swing_phases(Tuning.WEAPON_BLACK_KATANA, 1)
	for i: int in phases[0] + phases[1] + 6:
		var input: InputFrame = InputFrame.new()
		input.attack_pressed = i == 0
		input.aim = Vector2.RIGHT
		step(input)
		await shot()
	# the desktop HUD alone over a flat key colour in the normal 16:9 window, for the blueprint to cut its pieces out cleanly
	if DisplayServer.get_name() != "headless":
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		DisplayServer.window_set_size(Vector2i(1152, 648))
		RenderingServer.set_default_clear_color(Color(1, 0, 1))
		for child: Node in scene.get_children():
			if child is CanvasLayer:
				child.visible = child.name == "HUD"
		scene.modulate = Color(1, 1, 1, 0)  # the world; the HUD's CanvasLayer does not inherit it
		for i: int in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir + "hud.png")
	print("MOBILE CAPTURE: %d frames in %s" % [frame_index, out_dir])
	quit(0)
