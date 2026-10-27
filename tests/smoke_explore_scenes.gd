extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_explore_scenes.gd
## The exploration scene (presentation/explore/explore_scene.tscn): every scene loads with its ground and frames, the
## camera clamps, NPCs stand at their stand points with idle loops and face the hero, the interact hint and the "..."
## bubble, the debug jumps and the gate key, the fade, the character menu, checkpoint save / CONTINUE through a
## throwaway TOTOY_SAVE_PATH, and ESC to the title.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const InputFrame := preload("res://core/input_frame.gd")
const SaveStore := preload("res://core/save_store.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const VillageLayout := preload("res://core/village_layout.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const Title := preload("res://presentation/menu/title.gd")

const SAVE_PATH: String = "user://smoke_explore_save.json"

var failures: Array[String] = []
var changed_to: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _spawn(start: Dictionary = {}, persist: bool = false) -> Explore:
	if persist:
		Engine.set_meta(Explore.PERSIST_META, true)
	elif Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	if not start.is_empty():
		Engine.set_meta(Explore.START_META, start)
	var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	scene.change_scene = func(path: String) -> void: changed_to.append(path)
	root.add_child(scene)
	return scene


func _finish_fade(scene: Explore) -> void:
	for i: int in 3 * Explore.FADE_TICKS:
		if scene.fade_phase == &"":
			return
		scene.advance_fade()


func _step(scene: Explore, move: Vector2 = Vector2.ZERO, interact: bool = false) -> void:
	var f: InputFrame = InputFrame.new()
	f.move = move
	f.interact_pressed = interact
	scene.advance(f)


func _run() -> void:
	OS.set_environment(SaveStore.PATH_ENV, SAVE_PATH)
	SaveStore.delete(SAVE_PATH)
	await _every_scene_loads()
	await _village()
	await _jumps_gate_and_menu()
	await _save_and_continue()
	SaveStore.delete(SAVE_PATH)
	OS.set_environment(SaveStore.PATH_ENV, "")
	for meta: StringName in [Explore.PERSIST_META, Explore.START_META]:
		if Engine.has_meta(meta):
			Engine.remove_meta(meta)
	if failures.is_empty():
		print("EXPLORE SCENES SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("EXPLORE FAIL: " + message)
		print("EXPLORE SCENES SMOKE FAILED")
		quit(1)


func _every_scene_loads() -> void:
	for scene_id: StringName in [SceneDefs.VILLAGE, SceneDefs.FOREST, SceneDefs.GLADE]:
		var scene: Explore = _spawn({"scene": scene_id})
		await process_frame
		_expect(scene.snapshot != null and scene.snapshot.scene_id == scene_id, "%s loads" % scene_id)
		var ground: Texture2D = scene.ground_texture(scene_id)
		_expect(ground != null and ground.get_size() == scene.snapshot.size, "%s ground is the scene size" % scene_id)
		_expect(scene.fade_phase == &"in", "%s fades in" % scene_id)
		_finish_fade(scene)
		_expect(scene.fade_alpha() == 0.0, "the fade ends clear")
		_expect(scene.hud.toast_text == SceneDefs.get_def(scene_id)["name"] and scene.hud.toast_alpha > 0.0, "%s shows its name toast" % scene_id)
		for item: Dictionary in scene.drawables():
			if item["kind"] in [&"occluder", &"firefly"]:
				continue  # the painted props drawn over actors behind them (smoke_depth_occluders.gd)
			_expect(scene.frames.has(item["frame"]), "%s draws a missing frame %s" % [scene_id, item["frame"]])
		_expect(Explore.AMBIENT.has(scene_id) and scene.ambient() == Explore.AMBIENT[scene_id], "%s has its ambient tint" % scene_id)
		# camera: clamped at the four corners and the hero always on screen
		var size: Vector2 = scene.snapshot.size
		for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), size * 0.5]:
			scene.core.place_at(corner)
			_step(scene)
			var o: Vector2 = scene.view_origin
			_expect(o.x >= 0.0 and o.y >= 0.0 and o.x <= size.x - 320.0 and o.y <= size.y - 180.0, "%s camera stays inside (%s)" % [scene_id, o])
			_expect(o == o.round(), "whole-pixel camera")
			var on_screen: Vector2 = scene.snapshot.hero.position - o
			_expect(on_screen.x >= 0.0 and on_screen.y >= 0.0 and on_screen.x <= 320.0 and on_screen.y <= 180.0, "%s hero on screen" % scene_id)
		# walking animates the katana set
		scene.core.place_at(SceneDefs.get_def(scene_id)["entries"][SceneDefs.get_def(scene_id)["default_entry"]])
		for i: int in 12:
			_step(scene, Vector2.DOWN)
		_expect(scene.hero_frame.begins_with("hero2_"), "the hero uses the katana frames: %s" % scene.hero_frame)
		_expect(scene.missing_frames.is_empty(), "%s: no missing frames %s" % [scene_id, str(scene.missing_frames.keys())])
		scene.queue_free()
		await process_frame
	# the arena can be drawn by the explore renderer too (the game uses the fight scene there)
	var arena_view: Explore = _spawn({"scene": SceneDefs.VILLAGE})
	await process_frame
	arena_view.core = ExploreCore.new(SceneDefs.ARENA)
	_step(arena_view)
	_expect(arena_view.ground_texture(SceneDefs.ARENA).get_size() == Vector2(800, 480) and arena_view.view_origin.x <= 480.0, "the arena ground and camera")
	arena_view.queue_free()
	await process_frame


func _village() -> void:
	var scene: Explore = _spawn({"scene": SceneDefs.VILLAGE, "entry": &"arrival"})
	await process_frame
	_finish_fade(scene)
	var npcs: Array[Dictionary] = []
	for item: Dictionary in scene.drawables():
		if item["kind"] == &"npc":
			npcs.append(item)
	_expect(npcs.size() == 6, "six people in the village: %d" % npcs.size())
	var stand: Dictionary = {&"mira": &"mira", &"tovan": &"tovan", &"edda": &"edda", &"elder": &"villager_elder", &"child": &"villager_child", &"worker": &"villager_worker"}
	for item: Dictionary in npcs:
		_expect(Vector2(item["at"]) == VillageLayout.STAND_POINTS[stand[item["id"]]], "%s stands on its stand point" % item["id"])
		_expect(String(item["frame"]).begins_with("npc_%s_idle_right_" % String(item["id"])), "%s idles: %s" % [item["id"], item["frame"]])
		_expect(float(item["shadow"]) > 5.0 and float(item["shadow"]) <= 10.0, "%s has a ground shadow scaled by height" % item["id"])
	var chest: bool = false
	for item: Dictionary in scene.drawables():
		chest = chest or item.get("frame", "") == "obj_chest_closed_1"
	_expect(chest, "the village chest is drawn closed")
	# the idle loop advances (4 frames over 60 ticks)
	var seen: Dictionary = {}
	for i: int in 60:
		_step(scene)
		seen[scene.npc_frames[&"tovan"]] = true
	_expect(seen.size() == 4, "Tovan's idle loop shows 4 frames: %s" % str(seen.keys()))
	# near Mira: hint, facing, bubble
	var mira: Vector2 = VillageLayout.STAND_POINTS[&"mira"]
	scene.core.place_at(mira + Vector2(16, 2))
	_step(scene)
	_expect(scene.hud.hint_text == "[E] TALK", "the interact hint near Mira: '%s'" % scene.hud.hint_text)
	for character: String in "[E] TALK OPEN READ KNOCK LIGHT LOOK":
		_expect(Hud.ui_font().has_char(character.unicode_at(0)), "the HUD font has '%s'" % character)
	var mira_left: bool = true
	for npc: Dictionary in scene.snapshot.npcs:
		if npc["id"] == &"mira":
			mira_left = npc["facing_left"]
	_expect(not mira_left, "Mira turns to the hero on her right")
	_step(scene, Vector2.ZERO, true)
	_expect(scene.bubbles.has(&"mira"), "E shows the placeholder bubble over Mira")
	for i: int in Explore.BUBBLE_TICKS + 2:
		_step(scene)
	_expect(not scene.bubbles.has(&"mira"), "the bubble goes away")
	scene.core.place_at(Vector2(300, 250))
	_step(scene)
	_expect(scene.hud.hint_text == "", "no hint far from everyone")
	# the debug overlay
	scene.debug_enabled = true
	_step(scene)
	_expect(scene.hud.debug_lines.size() == 4, "F1 shows the debug lines")
	scene.queue_free()
	await process_frame


func _jumps_gate_and_menu() -> void:
	var scene: Explore = _spawn({"scene": SceneDefs.VILLAGE})
	await process_frame
	_finish_fade(scene)
	for target: StringName in [SceneDefs.FOREST, SceneDefs.GLADE, SceneDefs.VILLAGE]:
		scene.jump_to(target)
		scene.advance_fade()
		_expect(scene.fade_alpha() > 0.0 and scene.fade_alpha() < 1.0, "the fade runs")
		_finish_fade(scene)
		var def: Dictionary = SceneDefs.get_def(target)
		_expect(scene.snapshot.scene_id == target and scene.snapshot.hero.position == def["entries"][def["default_entry"]], "jump to %s puts the hero at its entry" % target)
	scene.jump_to(SceneDefs.FOREST)
	_finish_fade(scene)
	scene.toggle_gate()
	_expect(scene.gate_open and scene.core.gate_open and scene.snapshot.gate_open, "F6 opens the forest gate")
	scene.toggle_gate()
	_expect(not scene.core.gate_open, "and closes it")
	changed_to.clear()
	scene.jump_to(SceneDefs.ARENA)
	_finish_fade(scene)
	_expect(changed_to == [Explore.ARENA_SCENE], "F5 / the arena loads the Colossus fight: %s" % str(changed_to))
	# the character menu
	var menu_scene: Explore = _spawn({"scene": SceneDefs.VILLAGE})
	await process_frame
	_finish_fade(menu_scene)
	_expect(menu_scene.open_menu() and menu_scene.character_menu.is_open, "TAB opens the character menu in exploration")
	menu_scene.request_equip(&"dual_dagger")
	_expect(menu_scene.loadout_core.snapshot().player.weapon_id == &"dual_dagger" and menu_scene.profile.weapon_id == &"dual_dagger", "an equip request changes the loadout")
	menu_scene.character_menu.close()
	scene.queue_free()
	menu_scene.queue_free()
	await process_frame


func _save_and_continue() -> void:
	SaveStore.delete(SAVE_PATH)
	var scene: Explore = _spawn({"scene": SceneDefs.FOREST, "entry": &"village_side"}, true)
	await process_frame
	_finish_fade(scene)
	_step(scene, Vector2.RIGHT)
	_step(scene, Vector2.RIGHT)
	var saved: SaveProfile = SaveStore.load_profile(SAVE_PATH)
	_expect(saved.scene_id == &"forest" and saved.checkpoint_id == &"forest_entrance", "the forest entrance checkpoint is saved: %s / %s" % [saved.scene_id, saved.checkpoint_id])
	scene.toggle_gate()
	_expect(SaveStore.load_profile(SAVE_PATH).gate_open, "the gate flag is saved")
	scene.queue_free()
	await process_frame
	# CONTINUE through the title
	var title: Title = (load("res://presentation/menu/title.tscn") as PackedScene).instantiate() as Title
	root.add_child(title)
	title.change_scene = func(path: String) -> void: changed_to.append(path)
	await process_frame
	changed_to.clear()
	title.index = 1
	title.activate()
	_expect(changed_to == [Title.EXPLORE_SCENE], "CONTINUE opens the exploration scene")
	title.queue_free()
	var resumed: Explore = _spawn({}, true)  # the title set START_META
	await process_frame
	_expect(resumed.snapshot.scene_id == &"forest" and resumed.snapshot.hero.position == SceneDefs.checkpoint(&"forest", &"forest_entrance")["position"], "CONTINUE resumes at the forest checkpoint")
	_expect(resumed.core.gate_open, "with the gate open")
	# ESC goes back to the title (through the real input map)
	_finish_fade(resumed)
	changed_to.clear()
	Input.action_press("menu_back")
	await physics_frame
	await physics_frame
	Input.action_release("menu_back")
	_expect(changed_to.has(Explore.TITLE_SCENE), "ESC returns to the title: %s" % str(changed_to))
	resumed.queue_free()
	await process_frame
