extends SceneTree
## Headless six-attack effects check; windowed invocation also captures actual states.
const HeadAnchors := preload("res://presentation/arena/head_anchors.gd")
const Tuning := preload("res://core/tuning.gd")
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

func _attack(attack: StringName, right_charge: bool = false) -> void:
	arena._restart()
	arena.core.boss.position = Vector2(310 if right_charge else 390, 240)  # open plaza (the arena edges are solid since 2026-10-21)
	arena.core.player.position = Vector2(390 if right_charge else 310, 240)
	if attack in [&"gold_combo", &"red_charge"]:
		arena.core.boss.phase = 2
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	var impacts: Dictionary = {}
	var hit_ticks: Dictionary = {}
	var captured: bool = false
	var moved: bool = false
	var before: Vector2 = arena.core.boss.position
	var previous_charge: Dictionary = {}
	for i: int in range(160):
		arena.core.step(InputFrame.new())
		arena.snapshot = arena.core.snapshot()
		arena._age_effects()
		arena.prepare_visuals()
		arena._update_hud()
		arena.queue_redraw()
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			_expect(TelegraphView.warning_visible(tell, arena.snapshot.tick) == (arena.snapshot.tick >= tell.start_tick and arena.snapshot.tick < tell.hit_tick), "warning timing " + String(attack))
			if arena.snapshot.tick == tell.hit_tick - 1:
				_expect(TelegraphView.warning_visible(tell, arena.snapshot.tick), "warning vanishes before strike " + String(attack))
			if arena.snapshot.tick >= tell.hit_tick:
				_expect(not TelegraphView.warning_visible(tell, arena.snapshot.tick), "warning remains during attack " + String(attack))
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
				_expect(ArenaAnimation.boss_mirrored(arena.snapshot.entities[0], arena.snapshot, {}) == (tell.direction.x > 0.0), "charge source orientation does not match movement")
				var plan: Dictionary = CombatEffects.charge_plan(tell, arena.snapshot.tick, arena.impact_origin(tell), arena.frames, arena.sprites.get_size())
				_expect(plan["body_position"] == arena.snapshot.entities[0].position, "charge trail not attached to moving body")
				var f: Dictionary = arena.frames[plan["key"]]
				var polygon: PackedVector2Array = plan["polygon"]
				_expect(absf(polygon[0].distance_to(polygon[1]) - float(f["w"] - 1)) < 1.5, "charge dust stretched across lane")
				for uv: Vector2 in plan["uv"]:
					var pixel: Vector2 = uv * arena.sprites.get_size()
					_expect(pixel.x >= f["x"] - 0.001 and pixel.x <= f["x"] + f["w"] - 1 + 0.001 and pixel.y >= f["y"] - 0.001 and pixel.y <= f["y"] + f["h"] - 1 + 0.001, "charge samples adjacent atlas art")
				if not previous_charge.is_empty():
					_expect((Vector2(plan["origin"]) - Vector2(previous_charge["origin"])).is_equal_approx(Vector2(plan["body_position"]) - Vector2(previous_charge["body_position"])), "charge dust origin moves independently")
				previous_charge = plan
			if attack == &"red_shards" and arena.snapshot.tick >= tell.hit_tick:
				var owner: Snapshots.EntitySnapshot = arena.snapshot.entities[0]
				var muzzle: Vector2 = arena.impact_origin(tell)
				_expect(muzzle == tell.muzzle and muzzle == tell.center and muzzle.y < owner.position.y - 10.0, "laser does not start at the core muzzle")
				_expect(muzzle.distance_to(arena.boss_core_position(owner)) <= 8.0, "the drawn core and the beam muzzle disagree")
				var original_center: Vector2 = tell.center
				var original_direction: Vector2 = tell.direction
				var original_size: float = tell.size
				var visual: Snapshots.TelegraphSnapshot = CombatEffects.beam_visual_tell(tell, muzzle)
				_expect(visual.center == muzzle, "laser visual detached from chest")
				_expect((visual.center + visual.direction * visual.size).is_equal_approx(tell.center + tell.direction * tell.size) and visual.direction.is_equal_approx(tell.direction), "the drawn beam is not the ray the core damages")
				_expect(visual.width == tell.width and tell.center == original_center and tell.direction == original_direction and tell.size == original_size, "laser render changes hit geometry")

			if attack == &"red_shards" and arena.snapshot.tick == tell.hit_tick - 2:
				await _save("shards_warning")
			if attack == &"red_sweep" and arena.snapshot.tick == tell.hit_tick - 1:
				await _save("sweep_warning")
			if attack == &"red_sweep" and arena.snapshot.tick == tell.hit_tick:
				await _save("sweep_strike")
			var target: int = tell.hit_tick + (3 if attack == &"red_charge" else (2 if attack == &"red_sweep" else 0))
			if not captured and arena.snapshot.tick == target:
				captured = true
				await _save("charge_right" if right_charge else String(attack).trim_prefix("red_").trim_prefix("gold_"))
			if attack == &"gold_combo" and arena.snapshot.tick == tell.hit_tick:
				await _save("combo_impact_" + str(impacts.size()))
		await process_frame
		if arena.snapshot.entities[0].state == &"recover" and arena.snapshot.entities[0].state_ticks > 12:
			break
	_expect(captured, "attack never struck " + String(attack))
	_expect(impacts.size() == (2 if attack == &"gold_combo" else (3 if attack == &"red_shards" else 1)), "impact count " + String(attack))
	var cue_key: String = {&"gold_slam": "golem_slam", &"gold_combo": "golem_slam", &"red_stomp": "golem_stomp", &"red_sweep": "golem_sweep", &"red_charge": "golem_charge", &"red_shards": "golem_beam"}[attack]
	_expect(int(arena.combat_audio.played.get(cue_key, 0)) == (2 if attack == &"gold_combo" else 1), "strike audio count " + String(attack))
	if attack == &"gold_combo":
		_expect(hit_ticks.size() == 2, "combo needs distinct hit ticks")
	if attack == &"red_charge":
		_expect(moved, "charge snapshot never moved")
		var owner: Snapshots.EntitySnapshot = arena.snapshot.entities[0]
		_expect(ArenaAnimation.boss_mirrored(owner, arena.snapshot, arena.last_attacks.get(owner.id, {})) == right_charge, "charge recovery turns away from travel")
	_expect(arena.missing_frames.is_empty(), "missing frame " + str(arena.missing_frames))

func _sweep_atlas_bounds() -> void:
	var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	tell.shape = &"cone"
	tell.attack = &"red_sweep"
	tell.center = Vector2(190, 110)
	tell.size = Tuning.SWEEP_RADIUS
	tell.half_angle = deg_to_rad(Tuning.SWEEP_HALF_ANGLE_DEG)
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, -1).normalized()]:
		tell.direction = direction
		var polygon: PackedVector2Array = TelegraphView.outline(tell)
		for index: int in range(1, 7):
			var f: Dictionary = arena.frames["fx_sweep_%d" % index]
			var uv: PackedVector2Array = CombatEffects.effect_uvs(polygon, tell, f, arena.sprites.get_size())
			var bounds: Rect2 = Rect2(f["x"], f["y"], f["w"] - 1, f["h"] - 1)
			for point: Vector2 in uv:
				var pixel: Vector2 = point * arena.sprites.get_size()
				_expect(pixel.x >= bounds.position.x - 0.001 and pixel.x <= bounds.end.x + 0.001 and pixel.y >= bounds.position.y - 0.001 and pixel.y <= bounds.end.y + 0.001, "sweep samples another atlas frame %d" % index)
			var forward: PackedVector2Array = CombatEffects.effect_uvs(PackedVector2Array([tell.center, tell.center + direction * tell.size]), tell, f, arena.sprites.get_size())
			_expect(forward[1].x < forward[0].x, "left-facing sweep art points away from attack")

func _full_sweep_and_warning() -> void:
	var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	tell.attack = &"red_sweep"
	tell.shape = &"cone"
	tell.center = Vector2(190, 110)
	tell.direction = Vector2.LEFT
	tell.size = Tuning.SWEEP_RADIUS
	tell.half_angle = deg_to_rad(Tuning.SWEEP_HALF_ANGLE_DEG)
	tell.hit_tick = 100 # Isolated timeline fixture.
	_expect(TelegraphView.warning_visible(tell, tell.hit_tick - 1), "sweep loses windup warning")
	_expect(not TelegraphView.warning_visible(tell, tell.hit_tick), "yellow sweep warning persists on strike")
	_expect(not TelegraphView.warning_visible(tell, tell.hit_tick + 1), "yellow sweep warning returns after strike")
	_expect(CombatEffects.sweep_plan(tell, tell.hit_tick - 1, arena.frames, arena.sprites).is_empty(), "full sweep appears before hit")
	var strike: Dictionary = CombatEffects.sweep_plan(tell, tell.hit_tick, arena.frames, arena.sprites)
	_expect(strike["key"] == "fx_sweep_3", "full cut not on hit tick")
	_expect(strike["origin"] == tell.center, "sweep origin detached from boss attack")
	var f: Dictionary = arena.frames[strike["key"]]
	var uv: PackedVector2Array = strike["uv"]
	var polygon: PackedVector2Array = strike["polygon"]
	_expect(polygon.size() == 4, "sweep still clipped to warning cone")
	_expect((uv[0] * arena.sprites.get_size()).is_equal_approx(Vector2(f["x"], f["y"])), "sweep omits source top/left")
	_expect((uv[2] * arena.sprites.get_size()).is_equal_approx(Vector2(f["x"] + f["w"] - 1, f["y"] + f["h"] - 1)), "sweep omits source bottom/right")
	var extends_outside_cone: bool = false
	for point: Vector2 in polygon:
		var offset: Vector2 = point - tell.center
		if offset.length_squared() > 0.0 and offset.normalized().dot(tell.direction) < cos(tell.half_angle) - 0.05:
			extends_outside_cone = true
	_expect(extends_outside_cone, "sweep remains cut at cone boundaries")
	var later: Dictionary = CombatEffects.sweep_plan(tell, tell.hit_tick + 2, arena.frames, arena.sprites)
	_expect(is_equal_approx(float(strike["scale"]), float(later["scale"])), "sweep scale changes between frames")
	_expect(CombatEffects.sweep_plan(tell, tell.hit_tick + 10, arena.frames, arena.sprites).is_empty(), "sweep lingers after breakup")

func _core_anchor_art() -> void:
	var image: Image = arena.sprites.get_image()
	var distinct: Dictionary = {}
	for index: int in range(1, 7):
		var key: String = "golem2_beam_%d" % index
		var f: Dictionary = arena.frames[key]
		var point: Vector2 = arena.core_anchors[key]
		distinct[point] = true
		_expect(image.get_pixel(f["x"] + roundi(point.x), f["y"] + roundi(point.y)) == arena.colors["1"], "beam muzzle not on bright core art " + key)
		var right: Vector2 = HeadAnchors.world(Vector2(160, 100), f, point, false)
		var left: Vector2 = HeadAnchors.world(Vector2(160, 100), f, point, true)
		_expect(right.y == left.y and is_equal_approx(right.x + left.x, 319.0), "core point mirror/anchor mismatch")
	_expect(distinct.size() > 1, "core anchor does not follow animated chest")

func _run() -> void:
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	_expect(arena.frames.has("hero2_attack1_right_4"), "new slash frame absent")
	_sweep_atlas_bounds()
	_full_sweep_and_warning()
	_core_anchor_art()
	for attack: StringName in [&"gold_slam", &"red_sweep", &"red_shards", &"red_stomp", &"gold_combo", &"red_charge"]:
		await _attack(attack)
	await _attack(&"red_charge", true)
	arena.queue_free()
	if failures.is_empty():
		print("BOSS ATTACKS SMOKE OK (six attacks; capture=" + str(DisplayServer.get_name() != "headless") + ")")
		quit(0)
	else:
		for message: String in failures:
			printerr("BOSS ATTACKS FAIL: " + message)
		quit(1)
