extends SceneTree
const Arena := preload("res://presentation/arena/arena.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
var failures: Array[String] = []
var arena: Arena
var capture: bool = false
func _init() -> void:
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func _observe() -> void:
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()
func _save(label: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("res://art/build/arena_skill_" + label + ".png") == OK, "capture " + label)
func _inputs() -> void:
	await process_frame
	await process_frame
	var keys: Array[int] = [KEY_Z, KEY_X, KEY_C]
	for slot: int in range(1, 4):
		var action: String = "arena_skill_%d" % slot
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == keys[slot - 1]:
				found = true
		_expect(found, "physical skill key " + str(slot))
		Input.action_press(action)
		var frame: InputFrame = Bindings.read_frame(Vector2(40, 30), Vector2(100, 30))
		_expect(frame.skill_pressed == slot, "skill press " + str(slot))
		_expect(frame.aim == Vector2.RIGHT, "mouse skill aim " + str(slot))
		await process_frame
		await process_frame
		_expect(Bindings.read_frame().skill_pressed == 0, "held skill repeats " + str(slot))
		Input.action_release(action)
		await process_frame
func _skill(slot: int, id: StringName) -> void:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = Vector2(190, 110)
	arena.core.player.position = Vector2(145 if slot != 3 else 155, 110)
	arena.core.player.edge = Tuning.EDGE_MAX
	if slot == 1:
		arena.core.player.on_parry_success(Vector2.ZERO)
	_observe()
	if slot == 1:
		_expect(arena.snapshot.hud.retaliate_ticks_left > 0, "ready window missing")
		await _save("breaking_ready")
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = slot
	frame.aim = Vector2.RIGHT
	arena.core.step(frame)
	_observe()
	var durations: Array[int] = ArenaAnimation.skill_durations(id)
	var seen: Dictionary = {}
	var hits: int = 0
	var phases: Dictionary = {}
	for tick: int in range(durations[0] + durations[1] + durations[2] + 2):
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		if hero.state.begins_with("skill_"):
			var requested: String = ArenaAnimation.choose(hero, arena.snapshot, {})
			_expect(arena.frames.has(requested), "missing skill frame " + requested)
			_expect(requested == ArenaAnimation.skill_frame(id, hero.state, hero.state_ticks), "wrong skill frame")
			_expect(hero.skill_id == id, "wrong snapshot skill")
			seen[requested] = true
			var effect: Dictionary = arena.skill_effect()
			if not effect.is_empty():
				_expect(arena.frames.has(effect["key"]), "missing skill effect " + str(effect["key"]))
			if not phases.has(hero.state):
				phases[hero.state] = true
				await _save(String(id) + "_" + String(hero.state).trim_prefix("skill_"))
		if hero.state == &"skill_active" and hero.state_ticks == 1:
			await _save(String(id) + "_impact")
		for event: GameEvent in arena.core.last_events:
			if event.type == GameEvent.ATTACK_HIT and event.data.get("skill_id", &"") == id:
				hits += 1
				if slot == 3:
					_expect(not arena.hit_bursts.is_empty() and arena.hit_bursts[-1]["finisher"], "moon hit spark not heavy")
		arena.core.step(InputFrame.new())
		_observe()
	_expect(phases.size() == 3, "missing skill phase " + String(id))
	_expect(hits == 1, "confirmed skill hit count " + String(id))
	_expect(int(arena.combat_audio.played.get("skill_" + String(id), 0)) == 1, "skill start cue " + String(id))
	_expect(arena.skill_effect().is_empty(), "skill effect persists after recovery")
	_expect(arena.missing_frames.is_empty(), "frame fallback during skill")
	var rows: Array[Dictionary] = Hud.skill_rows(arena.snapshot.hud)
	_expect(rows.size() == 3 and rows[slot - 1]["cooldown"] == arena.snapshot.hud.skill_cooldown_ticks[slot - 1], "HUD cooldown snapshot")
	_expect(rows[2]["cost"] == Tuning.MOON_CLEAVE_EDGE_COST, "HUD Edge cost")
	# Boundary expectations independent of the chooser implementation.
	for phase: int in range(3):
		var state: StringName = [&"skill_windup", &"skill_active", &"skill_recovery"][phase]
		var start: String = ArenaAnimation.skill_frame(id, state, 0)
		var end: String = ArenaAnimation.skill_frame(id, state, durations[phase] - 1)
		var swing: int = 1 if slot == 2 else 3
		_expect(start == ("hero2_dash_right_1" if slot == 2 and phase == 0 else "hero2_attack%d_right_%d" % [swing, phase * 2 + 1]), "phase start " + String(id))
		_expect(end == ("hero2_dash_right_4" if slot == 2 and phase == 0 else "hero2_attack%d_right_%d" % [swing, phase * 2 + 2]), "phase end " + String(id))
func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	await _inputs()
	await _skill(1, &"breaking_edge")
	await _skill(2, &"gale_cut")
	await _skill(3, &"moon_cleave")
	_expect(ArenaAnimation.skill_frame(&"moon_cleave", &"skill_windup", Tuning.MOON_CLEAVE_WINDUP_TICKS / 2) == "hero2_attack3_right_2", "moon charge hold")
	arena._restart()
	arena.core.player.edge = 0
	var denied: InputFrame = InputFrame.new()
	denied.skill_pressed = 3
	arena.core.step(denied)
	_observe()
	_expect(not arena.combat_audio.played.has("skill_moon_cleave"), "rejected skill plays start cue")
	arena.combat_audio.reset()
	for frame: int in range(4):
		await process_frame
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("SKILLS PRESENTATION FAIL: " + message)
	print("SKILLS PRESENTATION SMOKE OK" if failures.is_empty() else "SKILLS PRESENTATION FAILED")
	quit(0 if failures.is_empty() else 1)

