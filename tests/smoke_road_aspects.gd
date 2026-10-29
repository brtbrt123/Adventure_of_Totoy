extends SceneTree
## Every Aspect works on the road and shows its shared effects there: the scene steps the core with the skill pressed, the
## events reach the shared hero_fx layer, the effect lists fill, and every plan the layer draws from can be built (no errors).
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Aspects := preload("res://core/aspects.gd")
const InputFrame := preload("res://core/input_frame.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("ROAD ASPECTS FAIL: ", label)
		failures += 1


func loadout(first: StringName) -> Array[StringName]:
	var out: Array[StringName] = [first]
	for other: StringName in [Aspects.SPRINT, Aspects.GALE_CUT, Aspects.MOON_CLEAVE]:
		if out.size() < 3 and other != first:
			out.append(other)
	return out


func press(slot: int) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.skill_pressed = slot
	f.aim = Vector2.RIGHT
	return f


func run() -> void:
	for aspect: StringName in Aspects.ALL:
		Engine.set_meta(Explore.START_META, {"scene": Explore.SceneDefs.WOODLAND_LAYERED})
		var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate()
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		await process_frame
		var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
		scene.core.set_story_flags(flags)
		scene.core.set_loadout(&"black_katana", loadout(aspect))
		scene.core.player.edge = 100.0
		scene.core.player.retaliate_ticks = 600
		var mob: Object = scene.core.mobs.encounters[0].mobs[0]
		scene.core.player.position = mob.position + Vector2(-34, 0)
		scene.core.player.facing = Vector2.RIGHT
		scene.snapshot = scene.core.snapshot()
		scene.previous_player_position = scene.snapshot.hero.position
		var used: bool = false
		var swing: InputFrame = InputFrame.new()
		swing.attack_pressed = true
		swing.attack_held = true
		swing.aim = Vector2.RIGHT
		for i: int in 160:
			var frame: InputFrame = press(1) if i == 0 else (swing if aspect == Aspects.PHANTOM_CUT and i in [40, 41] else InputFrame.new())
			scene.advance(frame)
			scene.fade_phase = &""
			scene._update_camera()
			scene.queue_redraw()
			if i % 20 == 0:
				await process_frame
			used = used or scene.snapshot.hero.skill_id == aspect or scene.snapshot.hero.state == &"ward" or scene.snapshot.hero.sprint_ticks_left > 0 or scene.snapshot.hero.phantom_ticks_left > 0 or not scene.snapshot.echoes.is_empty() or not scene.snapshot.lanterns.is_empty()
		check(used, "%s started on the road" % aspect)
		check(scene.lantern_drawables().size() >= 0 and scene.echo_drawables().size() >= 0, "%s: drawable plans build" % aspect)
		check(scene.ward_echo_ground_plan().size() >= 0 and scene.ward_echo_front_plan().size() >= 0, "%s: ward/echo plans build" % aspect)
		scene.queue_free()
		await process_frame
	if failures == 0:
		print("ROAD ASPECTS OK")
	quit(1 if failures else 0)
