extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_effects.gd
const Arena := preload("res://presentation/arena/arena.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
const CombatEffects := preload("res://presentation/arena/combat_effects.gd")
var arena: Arena
var failures: Array[String] = []
var seen: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _controls() -> void:
	Bindings.register()
	Bindings.register()
	for action: String in ["arena_attack", "arena_dash", "arena_parry"]:
		var mouse_count: int = 0
		var key_count: int = 0
		var pad_count: int = 0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventMouseButton:
				mouse_count += 1
				_expect(action == "arena_attack" and event.button_index == MOUSE_BUTTON_LEFT, "unexpected mouse binding " + action)
			elif event is InputEventKey:
				key_count += 1
				var wanted: int = KEY_SHIFT if action == "arena_dash" else KEY_SPACE
				_expect(action != "arena_attack" and event.physical_keycode == wanted, "old or incorrect key " + action)
			elif event is InputEventJoypadButton:
				pad_count += 1
				var wanted: int = JOY_BUTTON_X if action == "arena_attack" else (JOY_BUTTON_A if action == "arena_parry" else JOY_BUTTON_B)
				_expect(event.button_index == wanted, "gamepad changed " + action)
			else:
				_expect(false, "unexpected input event " + action)
		_expect(mouse_count == (1 if action == "arena_attack" else 0), "mouse event count " + action)
		_expect(key_count == (0 if action == "arena_attack" else 1), "key count " + action)
		_expect(pad_count == 1, "gamepad event count " + action)
	# Shift bindings must accept either physical key location.
	for location_value: int in [1, 2]:
		var shift: InputEventKey = InputEventKey.new()
		shift.physical_keycode = KEY_SHIFT
		shift.set("location", location_value)
		shift.pressed = true
		_expect(shift.is_action("arena_dash"), "Shift location does not map to dash: %d" % location_value)
	# A stale pre-existing mapping must also be replaced, not silently preserved.
	var old_key: InputEventKey = InputEventKey.new()
	old_key.physical_keycode = KEY_J
	InputMap.action_add_event("arena_attack", old_key)
	Bindings.register()
	_expect(InputMap.action_get_events("arena_attack").size() == 2, "stale binding survived registration")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_expect(InputMap.action_has_event("arena_attack", click), "mouse click does not map to attack")
	# Action injection tests frame conversion independently of OS input dispatch.
	Input.action_press("arena_attack")
	var frame: InputFrame = Bindings.read_frame(Vector2(20, 30), Vector2(30, 20))
	_expect(frame.attack_pressed, "attack intent missing")
	_expect(frame.aim.is_equal_approx(Vector2(1,-1).normalized()), "mouse aim direction incorrect")
	Input.action_release("arena_attack")

func _step(frame: InputFrame) -> void:
	arena.core.step(frame)
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
		if event.type == &"attack_hit" and int(event.data["attacker_id"]) == arena.snapshot.player.id:
			seen[String(event.data["kind"])] = true
			_expect(not arena.particles.is_empty(), "hit has no spark")
			if event.data["kind"] == &"counter":
				_expect(arena.shake_left > 0, "counter has no shake")
	if arena.snapshot.player.state in [&"attack_windup", &"attack_active", &"attack_recovery"]:
		if arena.snapshot.player.state_ticks < 3:
			_expect(not arena.slash_plan.is_empty(), "sword state has no effect")
			seen[String(arena.snapshot.player.state)] = true
	for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
		if arena.snapshot.tick >= tell.hit_tick and tell.attack in [&"red_shards", &"red_sweep"]:
			seen[String(tell.attack)] = true
			_expect(not arena.red_plan.is_empty(), "red strike has no light plan")
	arena._update_hud()
	arena.queue_redraw()

func _reset() -> void:
	arena._restart()
	arena.core.boss.cooldown = 10000

func _red_encounter(attack: StringName) -> void:
	_reset()
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	var end_tick: int = -1
	for i: int in range(220):
		_step(InputFrame.new())
		# Let the canvas execute red drawing commands, including the cone, headless too.
		await process_frame
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if tell.attack == attack:
				end_tick = tell.end_tick
		if end_tick >= 0 and arena.snapshot.tick == end_tick + 1:
			_expect(not arena.red_plan.is_empty(), "afterglow missing " + String(attack))
		if end_tick >= 0 and arena.snapshot.tick > end_tick + CombatEffects.AFTERGLOW_TICKS:
			_expect(arena.red_history.is_empty() and arena.red_plan.is_empty(), "afterglow did not expire")
			return
	_expect(false, "red encounter timed out " + String(attack))

func _run() -> void:
	await process_frame
	_controls()
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	if packed == null:
		printerr("EFFECTS FAIL: arena cannot load")
		quit(1)
		return
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	await _red_encounter(&"red_shards")
	await _red_encounter(&"red_sweep")
	_reset()
	# Test fixture positions the player in sword range; hits are still resolved by core.
	arena.core.player.position = arena.core.boss.position - Vector2(30,0)
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	_step(attack)
	for i: int in range(24):
		_step(InputFrame.new())
		await process_frame
	# Obtain a real counter opening with a perfect parry of a scripted gold slam.
	arena.core.boss.next_attack_override = &"gold_slam"
	arena.core.boss.cooldown = 1
	for i: int in range(220):
		var frame: InputFrame = InputFrame.new()
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if tell.attack == &"gold_slam" and arena.snapshot.tick == tell.hit_tick - 2:
				frame.parry_pressed = true
		if arena.snapshot.entities[0].state == &"posture_broken" and arena.snapshot.player.state == &"idle":
			frame.attack_pressed = true
			frame.aim = Vector2.RIGHT
		_step(frame)
		if seen.has("counter"):
			break
	for key: String in ["red_shards", "red_sweep", "attack_windup", "attack_active", "attack_recovery", "normal", "counter"]:
		_expect(seen.has(key), "scripted fight never exercised " + key)
	# No-input frames leave aim zero, allowing core movement-facing behavior.
	await physics_frame
	await process_frame
	_expect(Bindings.read_frame(Vector2.ZERO, Vector2.ONE).aim == Vector2.ZERO, "aim persists without attack press")
	arena.queue_free()
	if failures.is_empty():
		print("EFFECTS SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("EFFECTS FAIL: " + message)
		quit(1)
