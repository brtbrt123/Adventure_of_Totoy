extends SceneTree
const Arena := preload("res://presentation/arena/arena.gd")
const SkillEffects := preload("res://presentation/arena/skill_effects.gd")
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
	var releases: Dictionary = {"breaking_edge": "z_metal_clash", "gale_cut": "x_air_cut", "moon_cleave": "c_energy_aura"}
	for skill: String in releases:
		var stream: AudioStream = arena.combat_audio.CUES["release_" + skill]
		_expect(stream.resource_path.ends_with(str(releases[skill]) + "_candidate.wav"), "new release recording missing: " + skill)
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
		_expect(frame.aim.is_equal_approx(Vector2.RIGHT), "the skill aims at the mouse " + str(slot))
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
	if slot == 2:
		_expect(arena.skill_trails.is_empty(), "skill start invents a travelled lane")
	var durations: Array[int] = ArenaAnimation.skill_durations(id)
	var seen: Dictionary = {}
	var effect_frames: Dictionary = {}
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
				effect_frames[int(effect["frame"])] = true
				if hero.state == &"skill_active" and hero.state_ticks == 0:
					_expect(int(effect["frame"]) == 3, "effect peak must land on first active tick")
				_expect(arena.frames.has(effect["key"]), "missing skill effect " + str(effect["key"]))
			if not phases.has(hero.state):
				phases[hero.state] = true
				await _save(String(id) + "_" + String(hero.state).trim_prefix("skill_"))
		if hero.state == &"skill_windup" and hero.state_ticks == durations[0] - 1:
			await _save(String(id) + "_charged")
		if hero.state == &"skill_active" and hero.state_ticks == 1:
			await _save(String(id) + "_impact")
		for projectile: Dictionary in arena.skill_projectile_effects():
			_expect(arena.frames.has(projectile["key"]), "missing live projectile frame")
			_expect(projectile["width"] == arena.snapshot.skill_attacks[0].width, "projectile width not from snapshot")
		for event: GameEvent in arena.core.last_events:
			if event.type == GameEvent.ATTACK_HIT and event.data.get("skill_id", &"") == id:
				hits += 1
				if slot == 3:
					_expect(not arena.hit_bursts.is_empty() and arena.hit_bursts[-1]["finisher"], "moon hit spark not heavy")
		if capture:
			await physics_frame
		arena.core.step(InputFrame.new())
		_observe()
	_expect(effect_frames.size() == (2 if slot == 3 else 6), "not all six skill VFX frames played " + String(id))
	_expect(int(arena.combat_audio.played.get("release_" + String(id), 0)) == 1, "release cue must play once " + String(id))
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
		_expect(start == ("hero2_dash_right_1" if slot == 2 and phase == 1 else "hero2_attack%d_right_%d" % [swing, phase * 2 + 1]), "phase start " + String(id))
		_expect(end == ("hero2_dash_right_4" if slot == 2 and phase == 1 else "hero2_attack%d_right_%d" % [swing, phase * 2 + 2]), "phase end " + String(id))

func _catalog_effects() -> void:
	for key: String in SkillEffects.all_names():
		_expect(arena.frames.has(key), "missing approved VFX frame " + key)
		if arena.frames.has(key):
			var frame: Dictionary = arena.frames[key]
			_expect(int(frame["ax"]) * 2 == int(frame["w"]) and int(frame["ay"]) * 2 == int(frame["h"]), "effect origin must be centered " + key)

func _cancel_and_miss() -> void:
	# A real interrupted windup must never leave a scheduled release behind.
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.player.edge = Tuning.EDGE_MAX
	var start: InputFrame = InputFrame.new()
	start.skill_pressed = 3
	arena.core.step(start)
	_observe()
	_expect(not arena.skill_effect().is_empty(), "moon charge missing")
	arena.core.player.take_damage(1, arena.core.tick, arena.core.last_events, arena.core.boss.id)
	_observe()
	_expect(arena.skill_effect().is_empty(), "cancelled windup still draws")
	for tick: int in range(Tuning.MOON_CLEAVE_WINDUP_TICKS + 2):
		arena.core.step(InputFrame.new())
		_observe()
	_expect(not arena.combat_audio.played.has("release_moon_cleave"), "cancelled moon releases audio")
	_expect(SkillEffects.accents(arena.snapshot.player, arena.colors).is_empty(), "cancelled skill retains charge accents")
	for direction: Vector2 in [Vector2.LEFT, Vector2.UP]:
		arena._restart()
		arena.core.boss.cooldown = 100000
		arena.core.player.position = Vector2(150, 90)
		arena.core.boss.position = Vector2(280, 150)
		arena.core.player.edge = Tuning.EDGE_MAX
		start = InputFrame.new()
		start.skill_pressed = 2
		start.aim = direction
		if direction == Vector2.LEFT:
			start.move = direction
			start.aim = Vector2.RIGHT
		arena.core.step(start)
		_observe()
		_expect(is_equal_approx(float(arena.skill_effect()["rotation"]), direction.angle()), "skill VFX ignores core-selected direction")
		var hit: bool = false
		var trail_seen: bool = false
		for tick: int in range(Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS + Tuning.GALE_CUT_RECOVERY_TICKS + 1):
			arena.core.step(InputFrame.new())
			_observe()
			if arena.snapshot.player.state == &"skill_active" and arena.snapshot.player.state_ticks == 0:
				await _save("gale_cut_miss_" + ("left" if direction == Vector2.LEFT else "up"))
			if arena.snapshot.player.state == &"skill_active" and arena.snapshot.player.state_ticks == Tuning.GALE_CUT_ACTIVE_TICKS / 2:
				await _save("gale_cut_mid_dash_" + ("left" if direction == Vector2.LEFT else "up"))
			if not arena.skill_trails.is_empty():
				trail_seen = true
				for trace: Dictionary in arena.skill_trails:
					_expect(Vector2(trace["to"]).distance_to(trace["from"]) <= Tuning.GALE_CUT_SPEED + 0.01, "blade trace invents untravelled distance")
			# Re-reading the same snapshot must not replay its release sound.
			arena.prepare_visuals()
			for event: GameEvent in arena.core.last_events:
				if event.type == GameEvent.ATTACK_HIT:
					hit = true
		_expect(not hit and arena.hit_bursts.is_empty(), "miss creates hit feedback")
		_expect(int(arena.combat_audio.played.get("release_gale_cut", 0)) == 1, "miss must release audio exactly once")
		_expect(trail_seen, "Gale Cut leaves no blade trail")
		arena.snapshot.result = &"victory"
		arena.snapshot.result_ticks = SkillEffects.TRAIL_TICKS + 1
		arena._age_effects()
		_expect(arena.skill_trails.is_empty() and arena.skill_effect().is_empty(), "effects freeze after result")

func _moon_until_release() -> GameEvent:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = Vector2(280, 150)
	arena.core.player.position = Vector2(65, 80)
	arena.core.player.edge = Tuning.EDGE_MAX
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 3
	frame.aim = Vector2.RIGHT
	arena.core.step(frame)
	_observe()
	for tick: int in range(Tuning.MOON_CLEAVE_WINDUP_TICKS + 1):
		arena.core.step(InputFrame.new())
		for event: GameEvent in arena.core.last_events:
			if event.type == &"skill_released":
				# A state transition alone must not synthesize release feedback.
				arena.snapshot = arena.core.snapshot()
				arena.prepare_visuals()
				_expect(not arena.combat_audio.played.has("release_moon_cleave"), "state transition plays release without event")
				_observe()
				return event
		_observe()
	_expect(false, "Moon never released")
	return null

func _projectile_lifecycle() -> void:
	var release: GameEvent = _moon_until_release()
	if release == null:
		return
	var effect: Dictionary = arena.skill_projectile_effects()[0]
	_expect(effect["attack_id"] == release.data["attack_id"], "release attack id mismatch")
	_expect(arena.skill_effect().is_empty(), "released Moon still attaches a melee crescent to hero")
	_expect(float(effect["visual_width"]) >= 64.0, "Moon aura should read larger than the hero")
	var cache: Dictionary = arena._projectile_texture(effect["key"], roundi(effect["width"]))
	_expect(not cache.is_empty() and int(cache["diameter"]) == roundi(effect["width"]), "projectile texture does not fit snapshot width")
	arena._on_event(release)
	_expect(int(arena.combat_audio.played.get("release_moon_cleave", 0)) == 1, "duplicate release event plays twice")
	var previous: Vector2 = effect["at"]
	arena.core.player.take_damage(1, arena.core.tick, arena.core.last_events, arena.core.boss.id)
	_observe()
	_expect(arena.snapshot.player.state == &"idle" and arena.skill_projectile_effects().size() == 1, "projectile disappears after player hit")
	for tick: int in range(6):
		var move: InputFrame = InputFrame.new()
		move.move = Vector2.DOWN
		arena.core.step(move)
		_observe()
		effect = arena.skill_projectile_effects()[0]
		_expect(effect["at"] == arena.snapshot.skill_attacks[0].position, "projectile is not at core position")
		_expect(Vector2(effect["at"]).x > previous.x and is_equal_approx(Vector2(effect["at"]).y, previous.y), "projectile follows player instead of its own direction")
		previous = effect["at"]
	await _save("moon_projectile_after_hit")
	for tick: int in range(14):
		arena.core.step(InputFrame.new())
		_observe()
	await _save("moon_projectile_ranged")
	for tick: int in range(60):
		arena.core.step(InputFrame.new())
		_observe()
	_expect(arena.skill_projectile_effects().is_empty(), "expired projectile still draws")
	# A released projectile is still represented even with a dead player/result.
	release = _moon_until_release()
	arena.core.player.take_damage(Tuning.PLAYER_MAX_HP, arena.core.tick, arena.core.last_events, arena.core.boss.id)
	arena.core.step(InputFrame.new())
	_observe()
	_expect(arena.snapshot.player.state == &"dead" and arena.skill_projectile_effects().size() == 1, "death hides a still-live projectile snapshot")
	await _save("moon_projectile_after_death")
	arena._restart()
	_expect(arena.skill_projectile_effects().is_empty() and arena.released_skill_attacks.is_empty(), "restart retains an old projectile/release")
func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	_catalog_effects()
	await _inputs()
	await _skill(1, &"breaking_edge")
	await _skill(2, &"gale_cut")
	await _skill(3, &"moon_cleave")
	_expect(ArenaAnimation.skill_frame(&"moon_cleave", &"skill_windup", Tuning.MOON_CLEAVE_WINDUP_TICKS / 2) == "hero2_attack3_right_2", "moon charge hold")
	await _cancel_and_miss()
	await _projectile_lifecycle()
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

