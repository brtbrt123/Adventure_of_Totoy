extends SceneTree
## Pictures for the owner, part 3a (docs/PLAN_colossus_step3.md):
##   fight_*  the REAL fight in Rootcrown (real core, renderer, HUD and night light; the boss is the stand-in body): asleep, rising,
##            each of the six attacks warning, a posture break, the hero behind it, after its fall.
##   story_*  a STORYBOARD MOCK of the proposed victory cutscene: the real scene with drawn-on stand-ins (the body broken into
##            chunks, rubble, the song's motes); not gameplay, nothing of it is in the game.
## Windowed only (headless saves nothing):
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_3a/capture_3a.gd
## Writes user://colossus_3a/<name>.png; tools/art/make_colossus_3a_sheets.py makes the sheets. No save is read or written.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")
const ColossusView := preload("res://presentation/explore/colossus_view.gd")
const OUT: String = "user://colossus_3a/"
const HOME: Vector2 = Vector2(512, 378)
const VIEW: Vector2 = Vector2(384, 216)
const SPOTS: Dictionary = {
	&"gold_slam": Vector2(100, 40), &"red_sweep": Vector2(30, 70), &"red_shards": Vector2(130, 40), &"red_stomp": Vector2(100, 20),
	&"gold_combo": Vector2(80, 40), &"red_charge": Vector2(150, 40),
}
const FLAME: Vector2 = Vector2(510, 82)  # the beacon's flame in the world (tower feet 512,204; light socket 61.5,30.5 of anchor 63,152)

var scene: Explore
var mock: String = ""  # which storyboard overlay after_draw paints
var mock_age: int = 0


func _init() -> void:
	call_deferred("run")


func boss() -> Object:
	return scene.core.mobs.encounters[0].mobs[0]


func steps(count: int, frame: InputFrame = null) -> void:
	for i: int in count:
		if scene.core.player.state != &"dead":
			scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(frame if frame != null else InputFrame.new())
		scene.fade_phase = &""
		scene.toast_ticks = 0 if scene.toast_message == "" else scene.toast_ticks


func shot(name: String) -> void:
	scene.queue_redraw()
	scene.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name, " ", error_string(error))


func set_view(origin: Vector2) -> void:
	scene.view_origin = origin.round()
	scene.camera.position = scene.view_origin + VIEW * 0.5
	scene.camera.force_update_scroll()


## A fresh attack: the boss at home, the hero at `spot` from it, `ticks` into the warning.
func attack(id: StringName, ticks: int, phase: int = 1) -> void:
	var b: Object = boss()
	b.clear_telegraph()
	b.position = HOME
	b.phase = phase
	b.state = &"chase"
	b.state_ticks = 0
	b.cooldown = 1
	b.next_attack_override = id
	scene.core.player.position = HOME + SPOTS[id]
	scene.core.player.facing = (HOME - scene.core.player.position).normalized()
	steps(1)
	b.cooldown = 100000
	steps(ticks)


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_3a: run it windowed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"rootcrown_layered"})
	var node: Node = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate()
	node.set_script(load("res://presentation/review/colossus_step3/mockup_scene.gd"))
	scene = node as Explore
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.set("after_draw", Callable(self, "draw_mock"))
	scene.fade_phase = &""
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	scene.toast_ticks = 0
	# --- the real fight ---
	scene.core.player.position = Vector2(512, 600)
	steps(30)
	await shot("fight_01_asleep")
	scene.core.player.position = Vector2(512, 548)
	steps(60)
	await shot("fight_02_rising")
	steps(Tuning.COLOSSUS_WAKE_TICKS)
	var n: int = 3
	for id: StringName in [&"gold_slam", &"red_sweep", &"red_shards", &"red_stomp", &"gold_combo", &"red_charge"]:
		attack(id, 38, 2 if id in [&"gold_combo", &"red_charge"] else 1)
		await shot("fight_%02d_%s" % [n, id])
		n += 1
	boss().clear_telegraph()
	boss().state = &"chase"
	scene.core.player.position = HOME + Vector2(64, 20)
	var events: Array[GameEvent] = []
	boss().add_posture(100.0, scene.core.tick, events)
	steps(20)
	await shot("fight_09_posture_broken")
	steps(Tuning.COLOSSUS_BREAK_TICKS + 30)
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().position = HOME
	scene.core.player.position = HOME + Vector2(18, -36)
	steps(3)
	await shot("fight_10_behind")
	# the last blow: a real swing on a broken Colossus (the storyboard's first beat is this moment)
	boss().position = HOME
	boss().add_posture(100.0, scene.core.tick, events)
	scene.core.player.position = HOME + Vector2(58, 8)
	var swing: InputFrame = InputFrame.new()
	swing.attack_pressed = true
	swing.aim = Vector2.LEFT
	for i: int in 30:  # the picture: the frame the blow lands (the body flashes white); the next blow fells it
		scene.advance(swing if i == 0 else InputFrame.new())
		scene.fade_phase = &""
		if scene.core.last_events.any(func(e: GameEvent) -> bool: return e.type == GameEvent.ATTACK_HIT):
			break
	await shot("story_1_last_blow")
	boss().hp = 1
	for i: int in 60:
		scene.advance(swing if i % 25 == 0 else InputFrame.new())
		scene.fade_phase = &""
		if not boss().is_alive():
			break
	steps(Tuning.MOB_DEATH_TICKS + 30)
	await shot("fight_11_after_the_fall")
	# --- the storyboard mock-ups (the boss has fallen; the beacon is shown dark until its beat) ---
	var dark: Array[StringName] = scene.core.story_flags.filter(func(f: StringName) -> bool: return f != &"cleared_rootcrown")
	scene.core.story_flags.assign(dark)
	scene._refresh_props()
	scene.core.player.position = HOME + Vector2(70, 40)
	steps(1)
	(scene.get_node("HUD") as CanvasLayer).hide()  # a cutscene hides the HUD and the toast
	scene.toast_ticks = 0
	mock = "breaking"
	set_view(Vector2(320, 236))
	await shot("story_2_it_breaks")
	mock = "song"
	set_view(Vector2(320, 176))
	await shot("story_3_the_song_goes_home")
	scene.core.set_flag(&"cleared_rootcrown")
	steps(1)
	scene._refresh_props()
	mock = "rubble"
	scene.core.player.position = Vector2(548, 238)
	scene.core.player.facing = Vector2.UP
	steps(1)
	scene.toast_ticks = 0
	set_view(Vector2(320, 40))
	await shot("story_4_the_beacon_lights")
	print("CAPTURE 3A OK")
	quit(0)


# ---- storyboard overlays (mock only) -------------------------------------------------------------------------------------------

func draw_mock() -> void:
	if mock == "":
		return
	var frames: Dictionary = scene.frames
	if not frames.has(ColossusView.FRAME):
		return
	var f: Dictionary = frames[ColossusView.FRAME]
	var corner: Vector2 = HOME - Vector2(float(f["ax"]), float(f["ay"]))
	var tint: Color = scene.ambient()
	var chunk: int = 24
	for row: int in 5:
		for col: int in 6:
			var src: Rect2 = Rect2(float(f["x"]) + col * chunk, float(f["y"]) + row * chunk, chunk, chunk)
			var home: Vector2 = corner + Vector2(col * chunk, row * chunk)
			var spread: float = float(col) - 2.5
			var at: Vector2 = home
			if mock == "breaking":  # mid-fall: the top pieces drop and spread, the bottom ones settle
				at += Vector2(spread * (6.0 + 3.0 * (4 - row)), float(4 - row) * 9.0 + absf(spread) * 2.0)
			else:  # rubble: every piece on the ground around its feet
				at = HOME + Vector2(spread * 15.0 + float(row % 2) * 6.0 - 12.0, -10.0 - float(4 - row) * 4.0 + absf(spread) * 2.0)
			scene.draw_texture_rect_region(scene.sprites, Rect2(at.round(), Vector2(chunk, chunk)), src, tint)
	var colours: Array[Color] = [scene.colors["p"], scene.colors["o"], scene.colors["n"], scene.colors["u"]]
	if mock == "breaking":  # the song bursting from the cracks
		for i: int in 40:
			var a: float = TAU * float(i) / 40.0
			var p: Vector2 = HOME + Vector2(0, -50) + Vector2.from_angle(a) * (14.0 + float(i % 5) * 9.0)
			scene.draw_rect(Rect2(p.round(), Vector2.ONE * (2 if i % 3 == 0 else 1)), Color(colours[i % 4], 0.99))
	elif mock == "song":  # a ribbon of motes rises from the rubble to the beacon's flame
		var start: Vector2 = HOME + Vector2(0, -20)
		for i: int in 160:
			var t: float = float(i) / 159.0
			var bend: Vector2 = Vector2(sin(t * 9.0) * 10.0 * (1.0 - t) - 40.0 * t * (1.0 - t) * 4.0, 0)
			var spread: Vector2 = Vector2(sin(float(i) * 2.7) * 6.0, cos(float(i) * 1.9) * 4.0) * (1.0 - t * 0.6)
			var p: Vector2 = start.lerp(FLAME, t) + bend + spread
			scene.draw_rect(Rect2(p.round(), Vector2.ONE * (3 if i % 5 == 0 else 2)), Color(colours[i % 4], 0.99))
