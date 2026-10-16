extends SceneTree
## Headless six-attack effects check; windowed invocation also captures actual states.
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const CombatEffects := preload("res://presentation/arena/combat_effects.gd")
var arena: Arena
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _save(name_key: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png("res://art/build/arena_" + name_key + ".png") == OK, "capture " + name_key)

func _attack(attack: StringName) -> void:
	arena._restart()
	arena.core.boss.position = Vector2(190, 110)
	arena.core.player.position = Vector2(110, 110)
	if attack in [&"gold_combo", &"red_charge"]:
		arena.core.boss.phase = 2
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	var impacts: Dictionary = {}
	var hit_ticks: Dictionary = {}
	var captured: bool = false
	var moved: bool = false
	var before: Vector2 = arena.core.boss.position
	for i: int in range(160):
		arena.core.step(InputFrame.new())
		arena.snapshot = arena.core.snapshot()
		arena._age_effects()
		arena.prepare_visuals()
		arena._update_hud()
		arena.queue_redraw()
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			hit_ticks[tell.hit_tick] = true
			if arena.snapshot.tick == tell.hit_tick:
				impacts[tell.id] = true
				if attack in [&"gold_slam", &"gold_combo", &"red_stomp"]:
					_expect(arena.shake_left > 0 and not arena.particles.is_empty(), "impact dust/shake " + String(attack))
			if tell.shape == &"ring":
				var outer: PackedVector2Array = TelegraphView.outline(tell)
				_expect(outer.size() == 97, "ring outline absent")
				_expect(is_equal_approx(outer[0].distance_to(tell.center), tell.size), "wrong outer radius")
				var inner: PackedVector2Array = TelegraphView.ring_points(tell.center, tell.inner_size)
				_expect(is_equal_approx(inner[0].distance_to(tell.center), tell.inner_size), "wrong safe radius")
				if arena.snapshot.tick >= tell.hit_tick:
					_expect(not arena.red_plan.is_empty(), "stomp shockwave missing")
					for command: Dictionary in CombatEffects.red(tell, arena.snapshot.tick, arena.colors):
						_expect(not bool(command["fill"]), "stomp effect fills safe center")
			if attack == &"red_charge" and arena.snapshot.tick >= tell.hit_tick:
				moved = moved or arena.snapshot.entities[0].position.distance_to(before) > 10.0
				_expect(not arena.trails.is_empty(), "charge dust trail missing")
				_expect(ArenaAnimation.boss_mirrored(arena.snapshot.entities[0], arena.snapshot, {}), "left charge not mirrored")
			var target: int = tell.hit_tick + (3 if attack == &"red_charge" else (2 if attack == &"red_sweep" else 0))
			if not captured and arena.snapshot.tick == target:
				captured = true
				await _save(String(attack).trim_prefix("red_").trim_prefix("gold_"))
			if attack == &"gold_combo" and arena.snapshot.tick == tell.hit_tick:
				await _save("combo_impact_" + str(impacts.size()))
		await process_frame
		if arena.snapshot.entities[0].state == &"recover" and arena.snapshot.entities[0].state_ticks > 12:
			break
	_expect(captured, "attack never struck " + String(attack))
	_expect(impacts.size() == (2 if attack == &"gold_combo" else (3 if attack == &"red_shards" else 1)), "impact count " + String(attack))
	if attack == &"gold_combo":
		_expect(hit_ticks.size() == 2, "combo needs distinct hit ticks")
	if attack == &"red_charge":
		_expect(moved, "charge snapshot never moved")
	_expect(arena.missing_frames.is_empty(), "missing frame " + str(arena.missing_frames))

func _run() -> void:
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	_expect(arena.frames.has("hero2_attack1_right_4"), "new slash frame absent")
	for attack: StringName in [&"gold_slam", &"red_sweep", &"red_shards", &"red_stomp", &"gold_combo", &"red_charge"]:
		await _attack(attack)
	arena.queue_free()
	if failures.is_empty():
		print("BOSS ATTACKS SMOKE OK (six attacks; capture=" + str(DisplayServer.get_name() != "headless") + ")")
		quit(0)
	else:
		for message: String in failures:
			printerr("BOSS ATTACKS FAIL: " + message)
		quit(1)
