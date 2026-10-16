extends SceneTree
## Real core swings plus snapshot-only cosmetic/input/HUD contract checks.
const Arena := preload("res://presentation/arena/arena.gd")
const View := preload("res://presentation/arena/weapon_buff_view.gd")
const Anim := preload("res://presentation/arena/animation.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const PlayerState := preload("res://core/player.gd")
const Tuning := preload("res://core/tuning.gd")
const Snapshots := preload("res://core/snapshots.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
var arena: Arena
var failures: Array[String] = []
var capture: bool = false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func observe() -> void:
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()

func step(frame: InputFrame) -> void:
	arena.core.step(frame)
	observe()

func fixture() -> void:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = Vector2(250, 100)
	arena.core.player.position = Vector2(100, 110)
	arena.core.player.edge = Tuning.EDGE_MAX
	observe()

func activate() -> void:
	var input: InputFrame = InputFrame.new()
	input.weapon_active_pressed = true
	step(input)
	check(arena.snapshot.player.weapon_buff_active, "fixture buff did not activate")
	check(arena.snapshot.player.state == &"idle", "free buff invents attack pose")
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	check(int(arena.combat_audio.played.get("weapon_buff_start", 0)) == 1, "start cue repeats")

func save(label: String) -> void:
	if not capture:
		return
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_black_" + label + ".png") == OK, "capture " + label)

func input_check() -> void:
	var right: bool = false
	for event: InputEvent in InputMap.action_get_events("arena_weapon_active"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			right = true
	check(right, "right mouse binding absent")
	await process_frame
	Input.action_press("arena_weapon_active")
	var frame: InputFrame = Bindings.read_frame()
	check(frame.weapon_active_pressed and not frame.attack_pressed, "weapon click also attacks")
	await process_frame
	await process_frame
	check(not Bindings.read_frame().weapon_active_pressed, "held weapon active repeats")
	Input.action_release("arena_weapon_active")
	await process_frame

func catalog() -> void:
	for key: String in View.all_names():
		check(arena.frames.has(key), "missing buff art " + key)
	# Effect-origin frames must be centred, unlike feet-anchored actor/aura frames.
	for frame: int in range(1, 7):
		var f: Dictionary = arena.frames["fx_black_slash_%d" % frame]
		var crop: Image = arena.sprites.get_image().get_region(Rect2i(f["x"], f["y"], f["w"], f["h"]))
		var used: Rect2i = crop.get_used_rect()
		var centre: Vector2 = Vector2(used.position) + Vector2(used.size) * 0.5
		check(centre.distance_to(Vector2(f["ax"], f["ay"])) <= 3.0, "slash art offset from effect anchor")
		check(used.position.y > 0 and used.end.y < int(f["h"]), "slash art clipped at canvas edge")
		if frame == 3:
			check(used.size.y >= 40, "peak slash lost half its crescent")
	var snap: Snapshots.GameSnapshot = arena.core.snapshot()
	var hero: Snapshots.EntitySnapshot = snap.player
	hero.weapon_buff_active = true
	hero.weapon_buff_ticks_left = snap.hud.weapon_buff_duration
	var all_states: Array[StringName] = [&"idle", &"walk", &"dash", &"parry", &"parry_recovery", &"attack_windup", &"attack_active", &"attack_recovery", &"skill_windup", &"skill_active", &"skill_recovery"]
	for state: StringName in all_states:
		hero.state = state
		hero.skill_id = &"moon_cleave"
		hero.combo_index = 3
		hero.attack_speed_mult = Tuning.BLACK_KATANA_ATTACK_SPEED_MULT
		for tick: int in range(30):
			snap.tick = tick
			hero.state_ticks = tick
			var plan: Dictionary = View.plan(snap)
			check(not plan.is_empty(), "aura lost during " + String(state))
			for layer: String in ["back", "front"]:
				check(arena.frames.has(plan[layer]), "missing aura layer")
			if not String(plan["slash"]).is_empty():
				check(arena.frames.has(plan["slash"]), "missing buff slash")
			check(arena.frames.has(Anim.choose(hero, snap, {})), "missing buff actor pose")
	check(View.fade_level(hero, snap.hud.weapon_buff_duration) == 4, "full duration aura faded early")
	hero.weapon_buff_ticks_left = 1
	check(View.fade_level(hero, snap.hud.weapon_buff_duration) == 1, "aura does not fade near expiry")
	hero.weapon_buff_active = false
	check(View.plan(snap).is_empty(), "inactive buff draws aura")
	# Speed is locked per swing even if the visual buff has expired mid-swing.
	hero.state = &"attack_recovery"
	hero.state_ticks = 0
	check(Anim.swing_durations(hero)[2] == PlayerState.scaled_ticks(Tuning.SWING_RECOVERY_TICKS[2], hero.attack_speed_mult), "inactive buff discards locked swing speed")
	for skill: StringName in [&"breaking_edge", &"gale_cut", &"moon_cleave"]:
		hero.skill_id = skill
		hero.state = &"skill_active"
		check(Anim.choose(hero, snap, {}) == Anim.skill_frame(skill, hero.state, 0), "buff changes skill cadence")
	snap.hud.weapon_buff_duration = 0
	check(Hud.weapon_status(snap).is_empty(), "weapon without active shows timer")
	var texture: Texture2D = arena._buff_texture("fx_black_aura_back_3", 2)
	var image: Image = texture.get_image()
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var alpha: float = image.get_pixel(x, y).a
			check(alpha == 0.0 or alpha == 1.0, "aura fade creates partial alpha")

func swings() -> void:
	fixture()
	activate()
	await save("active_hud")
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	step(attack)
	var counts: Dictionary = {}
	var frame_counts: Dictionary = {}
	while arena.snapshot.player.state.begins_with("attack_"):
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		var id: int = hero.combo_index
		var key: String = "%d:%s" % [id, hero.state]
		counts[key] = int(counts.get(key, 0)) + 1
		var chosen: String = Anim.choose(hero, arena.snapshot, {})
		check(arena.frames.has(chosen), "scaled swing frame absent")
		frame_counts[chosen] = true
		var phase: int = 0 if hero.state == &"attack_windup" else (1 if hero.state == &"attack_active" else 2)
		var durations: Array[int] = Anim.swing_durations(hero)
		var expected: int = phase * 2 + mini(1, hero.state_ticks * 2 / durations[phase]) + 1
		check(chosen == "hero2_attack%d_right_%d" % [id, expected], "scaled phase does not spread frames evenly")
		if hero.state == &"attack_active" and hero.state_ticks == 0:
			await save("swing%d" % id)
		var input: InputFrame = InputFrame.new()
		input.attack_pressed = id < 3 and hero.state == &"attack_recovery"
		step(input)
	for id: int in range(1, 4):
		var total: int = 0
		var expected_total: int = 0
		var tables: Array = [Tuning.SWING_WINDUP_TICKS, Tuning.SWING_ACTIVE_TICKS, Tuning.SWING_RECOVERY_TICKS]
		var phases: Array[String] = ["attack_windup", "attack_active", "attack_recovery"]
		for phase: int in range(3):
			var expected: int = PlayerState.scaled_ticks(tables[phase][id - 1], Tuning.BLACK_KATANA_ATTACK_SPEED_MULT)
			var actual: int = int(counts.get("%d:%s" % [id, phases[phase]], 0))
			check(actual == expected, "real scaled phase length: %d %s" % [id, phases[phase]])
			total += actual
			expected_total += expected
		check(total == expected_total, "animation length differs from scaled swing total")
		for frame: int in range(1, 7):
			check(frame_counts.has("hero2_attack%d_right_%d" % [id, frame]), "scaled swing misses frame")
	var status: Dictionary = Hud.weapon_status(arena.snapshot)
	check(int(status["remaining"]) == ceili(arena.snapshot.player.weapon_buff_ticks_left * Tuning.TICK_DT), "HUD time not snapshot derived")
	check(float(status["cost"]) == arena.snapshot.hud.weapon_buff_edge_cost, "HUD copied cost")
	while arena.snapshot.player.weapon_buff_active:
		step(InputFrame.new())
	check(arena.weapon_buff_effect().is_empty(), "expired aura persists")
	check(int(arena.combat_audio.played.get("weapon_buff_end", 0)) == 1, "expiry cue absent or repeated")
	await save("expired")

func actions() -> void:
	for action: String in ["walk", "dash", "parry", "skill"]:
		fixture()
		activate()
		var input: InputFrame = InputFrame.new()
		input.move = Vector2.RIGHT if action in ["walk", "dash"] else Vector2.ZERO
		input.dash_pressed = action == "dash"
		input.parry_pressed = action == "parry"
		input.skill_pressed = 3 if action == "skill" else 0
		input.aim = Vector2.RIGHT
		step(input)
		check(not arena.weapon_buff_effect().is_empty(), "buff lost during real action " + action)
		await save(action)
	fixture()
	activate()
	for tick: int in range(14):
		step(InputFrame.new())
	arena.core.player.buff_ticks = 1
	observe()
	await save("fading")
	var events: Array[GameEvent] = []
	arena.core.player.take_damage(Tuning.PLAYER_MAX_HP, arena.core.tick, events, arena.core.boss.id)
	arena.snapshot = arena.core.snapshot()
	for event: GameEvent in events:
		arena._on_event(event)
		arena._on_event(event)
	check(arena.weapon_buff_effect().is_empty(), "death keeps empowered look")
	check(int(arena.combat_audio.played.get("weapon_buff_end", 0)) == 1, "death end cue repeats")
	arena._restart()
	check(arena.buff_events.is_empty() and arena.buff_transition.is_empty() and arena.weapon_buff_effect().is_empty(), "restart retains buff effect")
	check(arena.combat_audio.played.is_empty(), "restart retains buff sound")

func slash_attachment() -> void:
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, -1).normalized()]:
		fixture()
		activate()
		var input: InputFrame = InputFrame.new()
		input.attack_pressed = true
		input.aim = direction
		step(input)
		check(arena.weapon_slash_effect().is_empty(), "slash appears before sword strike")
		while arena.snapshot.player.state == &"attack_windup":
			step(InputFrame.new())
		var trail: Dictionary = arena.weapon_slash_effect()
		check(not trail.is_empty(), "active swing loses its trail")
		if not trail.is_empty():
			var offset: Vector2 = Vector2(trail["at"]) - arena.snapshot.player.position
			check(offset == Vector2(-15 if arena.facing_left else 15, -12), "slash detaches from painted blade for aim " + str(direction))
			check(bool(trail["left"]) == arena.facing_left, "slash mirrors differently from hero")
		await save("attached_%d_%d" % [roundi(direction.x), roundi(direction.y)])
		while arena.snapshot.player.state == &"attack_active":
			step(InputFrame.new())
		while arena.snapshot.player.state == &"attack_recovery" and arena.snapshot.player.state_ticks < 6:
			step(InputFrame.new())
		check(arena.weapon_slash_effect().is_empty(), "stray slash hangs through recovery")
	fixture()
	activate()
	# A hurt/victory override must never receive an unrelated attack overlay.
	arena.snapshot.player.state = &"attack_active"
	arena.snapshot.player.state_ticks = 0
	arena.selected_frames[arena.snapshot.player.id] = "hero2_hurt_right_1"
	check(arena.weapon_slash_effect().is_empty(), "hurt pose retains attack overlay")
	arena.snapshot.result = &"victory"
	arena.selected_frames[arena.snapshot.player.id] = "hero2_victory_right_1"
	check(arena.weapon_slash_effect().is_empty(), "victory keeps frozen slash")
	arena.snapshot.result = &"playing"
	arena.snapshot.player.state = &"skill_windup"
	arena.snapshot.player.skill_id = &"moon_cleave"
	check(String(View.plan(arena.snapshot)["slash"]).is_empty(), "Moon hold shows a premature black cut")

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	await input_check()
	fixture()
	arena.core.player.edge = 0
	var rejected: InputFrame = InputFrame.new()
	rejected.weapon_active_pressed = true
	step(rejected)
	check(arena.weapon_buff_effect().is_empty() and not arena.combat_audio.played.has("weapon_buff_start"), "refused press invents buff cue")
	catalog()
	await swings()
	await actions()
	await slash_attachment()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("WEAPON BUFF FAIL: " + message)
	print("WEAPON BUFF PRESENTATION SMOKE OK" if failures.is_empty() else "WEAPON BUFF PRESENTATION FAILED")
	quit(0 if failures.is_empty() else 1)
