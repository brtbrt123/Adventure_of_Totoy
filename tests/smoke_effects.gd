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
			var heavy_sound: bool = event.data["kind"] == &"counter" or int(event.data.get("combo_index", 1)) == 3
			_expect(arena.combat_audio.played.has("counter_hit" if heavy_sound else "armor_hit"), "confirmed hit audio missing")
			_expect(Vector2(arena.hit_bursts.back()["contact"]).y < Vector2(event.data["position"]).y, "hit spark is still at feet")
			if event.data["kind"] == &"counter":
				_expect(int(arena.flashes[arena.snapshot.entities[0].id]) == 10, "counter flash duration")
			_expect(not arena.particles.is_empty(), "hit has no spark")
			_expect(not arena.hit_bursts.is_empty(), "hit has no short bright burst")
			if event.data["kind"] == &"counter":
				_expect(arena.shake_left > 0, "counter has no shake")
	for event: GameEvent in arena.core.last_events:
		if event.type == &"damage_taken" and int(event.data["entity_id"]) == arena.snapshot.entities[0].id:
			_expect(arena.actor_is_white(arena.snapshot.entities[0]), "boss damage must flash white")
	if arena.snapshot.player.state in [&"attack_windup", &"attack_active", &"attack_recovery"]:
		if arena.snapshot.player.state_ticks < 3:
			_expect(arena.slash_plan.is_empty(), "painted sword arc duplicated")
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


# Force each new pattern through the real core; assert effects at snapshot impact
# boundaries, independent of whether the player happens to stand in the hit area.
func _new_patterns() -> void:
	for attack: StringName in [&"red_stomp", &"gold_combo", &"red_charge"]:
		_reset()
		arena.core.boss.phase = 2
		arena.core.boss.next_attack_override = attack
		arena.core.boss.cooldown = 1
		var impact_ids: Dictionary = {}
		var saw_rush: bool = false
		var saw_reraise: bool = false
		var charge_start: Vector2 = Vector2.ZERO
		var last_end: int = -1
		for i: int in range(180):
			_step(InputFrame.new())
			for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
				last_end = maxi(last_end, tell.end_tick)
				if arena.snapshot.tick == tell.hit_tick:
					impact_ids[tell.id] = true
					if attack == &"red_stomp":
						_expect(not arena.red_plan.is_empty(), "stomp has no shockwave")
						_expect(arena.shake_left > 0, "stomp has no impact shake")
					elif attack == &"gold_combo":
						var centered: bool = false
						for ring: Dictionary in arena.rings:
							if int(ring["start_tick"]) == tell.hit_tick and Vector2(ring["position"]).is_equal_approx(tell.center):
								centered = true
						_expect(centered, "combo dust missing at impact center")
				if attack == &"red_charge":
					charge_start = tell.center
					if arena.snapshot.tick >= tell.hit_tick and arena.snapshot.tick <= tell.end_tick:
						var boss: Snapshots.EntitySnapshot = arena.snapshot.entities[0]
						var behind: Vector2 = boss.position - tell.direction * 14.0
						var follows: bool = false
						for trail: Dictionary in arena.trails:
							if bool(trail.get("charge", false)) and int(trail["life"]) == 5 and Vector2(trail["position"]).is_equal_approx(behind):
								follows = true
						_expect(follows, "charge dust does not follow snapshot position")
						_expect(not boss.position.is_equal_approx(charge_start), "charge body did not move")
						saw_rush = true
			if attack == &"gold_combo" and impact_ids.size() == 1:
				var pose: String = String(arena.selected_frames.get(2, ""))
				saw_reraise = saw_reraise or pose.begins_with("golem2_slam_") and int(pose.get_slice("_", 2)) <= 3
			# Rendering the same snapshot twice must not duplicate impacts or dust.
			var particle_count: int = arena.particles.size()
			var trail_count: int = arena.trails.size()
			var ring_count: int = arena.rings.size()
			arena.prepare_visuals()
			_expect(arena.particles.size() == particle_count and arena.trails.size() == trail_count and arena.rings.size() == ring_count, "effects duplicated on repeated snapshot")
			await process_frame
			if last_end >= 0 and arena.snapshot.tick > last_end + 12:
				break
		_expect(impact_ids.size() == (2 if attack == &"gold_combo" else 1), "missing impacts for " + String(attack))
		if attack == &"gold_combo":
			_expect(saw_reraise, "combo did not re-raise between slams")
		if attack == &"red_charge":
			_expect(saw_rush, "charge rush never exercised")
		_expect(arena.missing_frames.is_empty(), "new pattern requested missing frames")

func _parry_visuals() -> void:
	var counts: Array[int] = []
	for lead: int in [10, 2]:
		_reset()
		arena.core.boss.next_attack_override = &"gold_slam"
		arena.core.boss.cooldown = 1
		var succeeded: bool = false
		for i: int in range(120):
			var frame: InputFrame = InputFrame.new()
			for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
				if arena.snapshot.tick == tell.hit_tick - lead:
					frame.parry_pressed = true
			_step(frame)
			for event: GameEvent in arena.core.last_events:
				if event.type == &"parry_succeeded":
					succeeded = true
					_expect(event.data["quality"] == (&"perfect" if lead == 2 else &"early"), "fixture parry quality")
					_expect(arena.combat_audio.played.has("perfect_parry" if lead == 2 else "deflect"), "parry quality audio missing")
					_expect(arena.parry_impacts.size() == 1, "parry impact missing")
					_expect(arena.selected_frames[arena.snapshot.player.id] == "hero2_parry_right_6", "successful parry must show painted spark")
					_expect(arena.screen_flash_until > arena.snapshot.tick and arena.shake_left > 0, "parry flash or shake missing")
					counts.append(arena.particles.size())
					var impact: Dictionary = arena.parry_impacts[0]
					_expect(Vector2(impact["position"]) == Vector2(event.data["position"]), "impact moved away from event contact")
					_expect(not CombatEffects.parry_impact(impact["position"], 0, lead == 2, arena.colors).is_empty(), "impact drawing missing")
			if succeeded:
				break
		_expect(succeeded, "scripted parry did not succeed")
		for i: int in range(12):
			_step(InputFrame.new())
		_expect(arena.parry_impacts.is_empty() and arena.snapshot.tick >= arena.screen_flash_until, "parry effect never expired")
	_expect(counts.size() == 2 and counts[1] > counts[0], "perfect must have more sparks than early")
	_reset()
	var parry: InputFrame = InputFrame.new()
	parry.parry_pressed = true
	_step(parry)
	_expect(arena.slash_plan.is_empty(), "painted parry spark duplicated")
	for i: int in range(14):
		_step(InputFrame.new())
	_expect(arena.parry_impacts.is_empty() and not arena.particles.is_empty(), "whiff must create only a dull puff")
	_reset()
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	_step(attack)
	for i: int in range(7):
		_step(InputFrame.new())
	var draw_commands: int = arena.slash_plan.size()
	_expect(arena.snapshot.player.state == &"attack_active", "draw transition fixture")
	_step(InputFrame.new())
	_step(InputFrame.new())
	_expect(draw_commands == 0 and arena.slash_plan.is_empty(), "runtime draw streak duplicated imported art")

func _run() -> void:
	await process_frame
	_controls()
	_hip_streaks()
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	if packed == null:
		printerr("EFFECTS FAIL: arena cannot load")
		quit(1)
		return
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	await _flash_visuals()
	_parry_visuals()
	await _red_encounter(&"red_shards")
	await _red_encounter(&"red_sweep")
	await _new_patterns()
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

func _flash_visuals() -> void:
	_reset()
	var dash: InputFrame = InputFrame.new()
	dash.dash_pressed = true
	dash.move = Vector2.DOWN
	_step(dash)
	for i: int in range(10):
		_expect(not arena.actor_is_white(arena.snapshot.player), "dash i-frames blinked")
		_step(InputFrame.new())
	_reset()
	arena.core.player.position = arena.core.boss.position - Vector2(30, 0)
	arena.core.boss.next_attack_override = &"red_sweep"
	arena.core.boss.cooldown = 1
	var damaged: bool = false
	var white: bool = false
	var normal: bool = false
	for i: int in range(140):
		_step(InputFrame.new())
		for event: GameEvent in arena.core.last_events:
			if event.type == &"damage_taken" and int(event.data["entity_id"]) == arena.snapshot.player.id:
				damaged = true
				_expect(arena.actor_is_white(arena.snapshot.player), "player damage must flash white")
		if damaged and arena.snapshot.player.invulnerable and not arena.flashes.has(arena.snapshot.player.id):
			white = white or arena.actor_is_white(arena.snapshot.player)
			normal = normal or not arena.actor_is_white(arena.snapshot.player)
		await process_frame
	_expect(damaged and white and normal, "hurt flash/blink paths missing")
	_expect(not arena.hurt_blink, "hurt blink must expire")
	for at: Vector2 in [Vector2.ZERO, Vector2(320, 0), Vector2(0, 180), Vector2(320, 180)]:
		for counter: bool in [false, true]:
			var panel: Rect2 = arena.hud.boss_panel(at, counter)
			_expect(Rect2(0, 0, 320, 180).encloses(panel), "boss panel left screen")
	_expect(not arena.hud.portrait_frame.is_empty(), "HUD portrait missing")
	var source: Image = arena.sprites.get_image()
	var image: Image = arena.white_sprites.get_image()
	var opaque: bool = false
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			_expect(color.a == source.get_pixel(x, y).a, "white silhouette changed alpha")
			if color.a > 0.0:
				opaque = true
				if color != Color.WHITE:
					_expect(false, "white silhouette contains tinted pixels")
					return
	_expect(opaque, "white silhouette atlas is empty")

# Imported attack and guard art is the only source of blade marks.
func _hip_streaks() -> void:
	var actor: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	for state: StringName in [&"attack_windup", &"attack_active", &"attack_recovery", &"parry"]:
		actor.state = state
		_expect(CombatEffects.slash(actor, {}).is_empty(), "duplicate blade marks: " + String(state))
