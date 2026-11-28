extends SceneTree
## The Mossbound Colossus on the road, through the real scene (docs/PLAN_colossus_step3.md, part 3a): Rootcrown loads it asleep,
## the stand-in frame exists, walking up wakes it and seals the climb, the fight camera shows the whole body, its warnings, the boss
## panel and its chest light work, a posture break and phase 2 play, its fall clears the scene, lights the beacon and opens the climb,
## and debug key Y's jump lets it be fought again. No save is read or written (no persist meta). Prints FAIL and exits 1 on failure.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const ColossusView := preload("res://presentation/explore/colossus_view.gd")
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const Tuning := preload("res://core/tuning.gd")
const VIEW: Vector2 = Vector2(384, 216)
var failures: int = 0
var scene: Explore
var seen: Array[StringName] = []


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("COLOSSUS FAIL: ", label)
		failures += 1


func steps(count: int, keep_alive: bool = true) -> void:
	for i: int in count:
		if keep_alive and scene.core.player.state != &"dead":
			scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		for event: GameEvent in scene.core.last_events:
			seen.append(event.type)
			if event.type == GameEvent.ATTACK_TELEGRAPHED:
				seen.append(StringName("told_" + String(event.data["attack"])))


func draw_once() -> void:
	scene.queue_redraw()
	scene.hud.queue_redraw()
	await process_frame


func boss() -> Object:
	return scene.core.mobs.encounters[0].mobs[0]


func whole_body_on_screen() -> bool:
	var view: Rect2 = Rect2(scene.view_origin, VIEW)
	var body: Rect2 = ColossusView.body_rect(ColossusView.find(scene.snapshot), scene.frames)
	return view.encloses(body)


func run() -> void:
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	check(frames.has(ColossusView.FRAME), "the stand-in frame is in the atlas")
	check(int(frames.get(ColossusView.FRAME, {}).get("ay", 0)) == 118, "its feet anchor")
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": SceneDefs.ROOTCROWN_LAYERED})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.fade_phase = &""
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	scene.snapshot = scene.core.snapshot()
	check(ColossusView.find(scene.snapshot).get("state", &"") == &"idle", "it sleeps in Rootcrown")
	check(ColossusView.fighting(scene.snapshot).is_empty(), "no fight yet")
	steps(5)
	await draw_once()
	# walk up: it wakes, the climb closes, the camera slides to show it whole
	scene.core.player.position = Vector2(512, 548)
	steps(Tuning.COLOSSUS_WAKE_TICKS + 30)
	check(seen.has(GameEvent.ARENA_SEALED), "the climb sealed")
	check(scene.hud.road_boss.size() > 0, "the HUD has the boss")
	await draw_once()
	check(scene.hud.boss_panel_node != null and scene.hud.boss_panel_node.visible, "the boss panel shows")
	# from the wake spot (170 px below its feet) both cannot fit on one screen; within its sight they do
	scene.core.player.position = boss().position + Vector2(20, 70)
	steps(40)
	check(whole_body_on_screen(), "the whole body is on screen (view %s)" % scene.view_origin)
	# its chest light is among the lights
	scene._sync_moving_lights()
	var material: ShaderMaterial = scene.material as ShaderMaterial
	if material != null:
		var count: int = int(material.get_shader_parameter("lamp_count"))
		check(count <= EnvironmentLight.MAX_LIGHTS, "within the light budget: %d" % count)
		var lamps: PackedVector4Array = material.get_shader_parameter("lamps")
		var chest_y: float = boss().position.y - ColossusView.CHEST
		var found: bool = false
		for i: int in count:
			found = found or (absf(lamps[i].x - boss().position.x) < 0.5 and absf(lamps[i].y - chest_y) < 0.5)
		check(found, "the chest light is lit")
	# fight a while from in front of it, then from below (the camera keeps it whole)
	for spot: Vector2 in [Vector2(100, 40), Vector2(-90, 50), Vector2(0, 70)]:
		scene.core.player.position = boss().position + spot
		steps(150)
		await draw_once()
		check(whole_body_on_screen(), "whole on screen with the hero at %s (view %s)" % [spot, scene.view_origin])
	check(seen.has(&"told_gold_slam") or seen.has(&"told_red_sweep") or seen.has(&"told_red_stomp") or seen.has(&"told_red_shards"), "it attacked: %s" % [seen.filter(func(t: StringName) -> bool: return String(t).begins_with("told_"))])
	# the hero behind it (the outline path runs)
	scene.core.player.position = boss().position + Vector2(10, -40)
	steps(2)
	await draw_once()
	# a posture break and phase 2
	var events: Array[GameEvent] = []
	boss().add_posture(100.0, scene.core.tick, events)
	steps(1)
	await draw_once()
	check(scene.hud.road_boss.get("state", &"") == &"posture_broken" and int(scene.hud.road_boss.get("broken_ticks_left", 0)) > 0, "broken, its counter window shown")
	var enc: Object = scene.core.mobs.encounters[0]
	while boss().phase == 1:
		scene.core.mobs.hit_mob(scene.core, enc, boss(), 40.0, {"combo_index": 1, "weapon_id": &"black_katana"}, events)
	check(seen.has(GameEvent.BOSS_PHASE_CHANGED) or events.any(func(e: GameEvent) -> bool: return e.type == GameEvent.BOSS_PHASE_CHANGED), "phase 2")
	for spot: Vector2 in [Vector2(120, 40), Vector2(-140, 30)]:
		scene.core.player.position = boss().position + spot
		steps(200)
		await draw_once()
	while boss().phase == 2:
		scene.core.mobs.hit_mob(scene.core, enc, boss(), 40.0, {"combo_index": 1, "weapon_id": &"black_katana"}, events)
	check(boss().phase == 3, "phase 3")
	for spot: Vector2 in [Vector2(-120, 40), Vector2(150, 20)]:
		scene.core.player.position = boss().position + spot
		steps(200)
		await draw_once()
	check(seen.has(&"told_root_snare") or seen.has(&"told_boulder_toss") or seen.has(&"told_heartroot_grab"), "a part 3b attack: %s" % [seen.filter(func(t: StringName) -> bool: return String(t).begins_with("told_"))])
	# the PixelFX effects: every frame is in the atlas, and a forced snare and boulder play theirs through the real scene
	for name: String in ColossusView.effect_frames():
		check(frames.has(name), "effect frame %s" % name)
	var shards: bool = false
	var effect_of: Dictionary = {&"root_snare": &"thorns", &"boulder_toss": &"land", &"heartroot_grab": &"arm"}
	for id: StringName in [&"root_snare", &"boulder_toss", &"heartroot_grab"]:
		boss().clear_telegraph()
		boss().state = &"chase"
		boss().cooldown = 1
		boss().next_attack_override = id
		scene.core.player.position = boss().position + Vector2(130, 40)
		steps(1)
		boss().cooldown = 100000
		var played: bool = false
		for i: int in 110:
			steps(1)
			if i % 6 == 0:
				await draw_once()
			played = played or scene.colossus_view.effects.any(func(e: Dictionary) -> bool: return e["kind"] == effect_of[id])
			shards = shards or scene.colossus_view.effects.any(func(e: Dictionary) -> bool: return e["kind"] == &"shards")
		check(played, "%s played its effect" % id)
	check(shards, "the boulder's ring of shock played its stone shards")
	# part 3c: a phase change raises the Briar Ring (it warns, then stands), and a Song Flare plays its rings and gold blow
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().phase = 2
	boss().hp = 152
	var crossing: Array[GameEvent] = []
	scene.core.mobs.hit_mob(scene.core, enc, boss(), 8.0, {"combo_index": 1, "weapon_id": &"black_katana"}, crossing)
	check(boss().briar != null, "the Briar Ring rose with phase 3")
	scene.core.player.position = Vector2(420, 430)  # inside its safe circle
	boss().state = &"stagger"
	boss().stun_left = 100000
	for i: int in Tuning.COLOSSUS_BRIAR["windup"] + 40:
		steps(1)
		if i % 30 == 0:
			await draw_once()
	check(scene.snapshot.telegraphs.any(func(w: Variant) -> bool: return w.attack == &"briar_ring" and scene.snapshot.tick >= w.hit_tick), "the briars stand, in the snapshot")
	var wall: Array = scene.colossus_view.effect_items(scene.snapshot, Color.WHITE).filter(func(i: Dictionary) -> bool: return String(i["id"]).begins_with("colossus_wall_"))
	check(wall.size() > 40, "the thorn wall stands round the safe circle: %d thorns" % wall.size())
	boss().stun_left = 0
	steps(20)
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().cooldown = 1
	boss().next_attack_override = &"song_flare"
	scene.core.player.position = boss().position + Vector2(100, 0)
	steps(1)
	boss().cooldown = 100000
	check(scene.snapshot.telegraphs.filter(func(w: Variant) -> bool: return w.attack == &"song_flare").size() == 4, "the Song Flare: three rings and its gold blow")
	var song_kinds: Dictionary = {}
	for i: int in 140:
		steps(1)
		if i % 10 == 0:
			await draw_once()
		for e: Dictionary in scene.colossus_view.effects:
			song_kinds[e["kind"]] = true
	check(song_kinds.has(&"song_ring") and song_kinds.has(&"song_burst"), "the Song Flare played its shards and its burst: %s" % [song_kinds.keys()])
	check(scene.colossus_view.missing.is_empty(), "no missing effect frames after 3c: %s" % [scene.colossus_view.missing.keys()])
	check(scene.colossus_view.missing.is_empty(), "no missing effect frames: %s" % [scene.colossus_view.missing.keys()])
	# its fall: the last blow is a real swing inside a step, so the scene hears every event as in play
	boss().hp = 1
	boss().cooldown = 100000
	for i: int in 90:
		if not boss().is_alive():
			break
		var swing: InputFrame = InputFrame.new()
		swing.attack_pressed = true
		scene.core.player.position = boss().position + Vector2(60, 0)
		swing.aim = Vector2.LEFT
		scene.advance(swing)
		for event: GameEvent in scene.core.last_events:
			seen.append(event.type)
	check(not boss().is_alive(), "a swing felled it")
	for i: int in Tuning.MOB_DEATH_TICKS + 20:
		steps(1)
		if i % 10 == 0:
			await draw_once()
	check(scene.core.has_flag(&"cleared_rootcrown"), "cleared")
	check(seen.has(GameEvent.ARENA_OPENED), "the climb opened")
	check(scene.toast_message == "THE GUARDIAN FALLS", "the toast: %s" % scene.toast_message)
	var lit: bool = false
	for p: Dictionary in scene.prop_placements:
		lit = lit or (p["id"] == &"beacon" and p["type"] == &"rootcrown_tower_lit")
	check(lit, "the beacon is lit")
	check(ColossusView.fighting(scene.snapshot).is_empty() and scene.hud.road_boss.is_empty(), "the fight is over")
	# debug key Y: it can be fought again
	scene.jump_to(SceneDefs.ROOTCROWN_LAYERED)
	for i: int in 120:
		if scene.fade_phase == &"":
			break
		scene.advance_fade()
	check(not scene.core.has_flag(&"cleared_rootcrown"), "Y cleared the win")
	check(ColossusView.find(scene.snapshot).get("state", &"") == &"idle", "and it sleeps again")
	check(scene.missing_frames.is_empty(), "no missing frames: %s" % [scene.missing_frames.keys()])
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("COLOSSUS OK")
	quit(1 if failures else 0)
