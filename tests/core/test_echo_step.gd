extends "res://tests/test_case.gd"
## Echo Step (aspect, 2026-10-21): a free action that places an anchor; ECHO_STEP_DELAY_TICKS later the player is
## pulled back to it (instant teleport, cancels the current action, ECHO_STEP_INVULN_TICKS of i-frames from the
## arrival). Also the determinism check and the soak of all eight aspects.

const Aspects := preload("res://core/aspects.gd")
const Weapons := preload("res://core/weapons.gd")
const ArenaLayout := preload("res://core/arena_layout.gd")
const Obstacle := preload("res://core/obstacle.gd")

const START: Vector2 = Vector2(200.0, 240.0)


## Open field, a pinned boss at (600, 240), full Edge, Echo Step in slot 2.
func _core(real_arena: bool = false) -> GameCore:
	var core: GameCore = GameCore.new()
	if not real_arena:
		core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = Vector2(600.0, 240.0)
	core.player.position = START
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	var equip: InputFrame = InputFrame.new()
	equip.aspect_equip = Aspects.ECHO_STEP
	equip.aspect_equip_slot = 2
	core.step(equip)
	assert_eq(core.player.equipped_aspects[1], Aspects.ECHO_STEP)
	return core


func _press(core: GameCore, move: Vector2 = Vector2.ZERO) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 2
	frame.move = move
	core.step(frame)


func _to(core: GameCore, target: int, frame: InputFrame = null) -> void:
	var f: InputFrame = frame if frame != null else InputFrame.new()
	while core.tick < target and core.result == GameCore.RESULT_PLAYING:
		core.step(f)


func _overlaps_prop(core: GameCore, point: Vector2, radius: float) -> bool:
	for o: Obstacle in core.obstacles:
		if point.distance_to(o.center) < o.radius + radius - 0.01:
			return true
	return false


func _in_arena(point: Vector2) -> bool:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	return point == point.clamp(low, Tuning.ARENA_SIZE - low)


func test_placement_and_recall_are_tick_exact() -> void:
	var core: GameCore = _core()
	_press(core)
	var a: int = core.tick
	var placed: GameEvent = find_event(core, GameEvent.ECHO_PLACED)
	assert_true(placed != null, "echo_placed on the press tick")
	var anchor: Vector2 = core.player.position
	if placed != null:
		assert_eq(placed.data["position"], anchor, "at the player's feet")
		assert_eq(placed.data["duration"], Tuning.ECHO_STEP_DELAY_TICKS)
		assert_eq(placed.data["entity_id"], core.player.id)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "no state change, no windup")
	assert_true(find_event(core, GameEvent.SKILL_STARTED) == null)
	assert_near(core.player.edge, 100.0 - Tuning.ECHO_STEP_EDGE_COST, 0.001, "25 Edge")
	assert_eq(int(core.player.aspect_cooldowns[Aspects.ECHO_STEP]), Tuning.ECHO_STEP_COOLDOWN_TICKS)
	var snap = core.snapshot()
	assert_eq(snap.echoes.size(), 1)
	if snap.echoes.size() == 1:
		assert_eq(snap.echoes[0].id, placed.data["echo_id"] if placed != null else -1)
		assert_eq(snap.echoes[0].owner_id, core.player.id)
		assert_eq(snap.echoes[0].position, anchor)
		assert_eq(snap.echoes[0].placed_tick, a)
		assert_eq(snap.echoes[0].duration, Tuning.ECHO_STEP_DELAY_TICKS)
		assert_eq(snap.echoes[0].ticks_left, Tuning.ECHO_STEP_DELAY_TICKS)
	var row: Dictionary = snap.hud.aspect_slots[1]
	assert_eq(row["running"], true)
	assert_eq(row["ticks_left"], Tuning.ECHO_STEP_DELAY_TICKS)
	assert_eq(row["kind"], Aspects.KIND_SKILL)
	for i: int in Tuning.ECHO_STEP_DELAY_TICKS - 1:
		core.step(input(Vector2.RIGHT))
		assert_true(find_event(core, GameEvent.ECHO_RECALL) == null, "not before the delay (tick %d)" % core.tick)
	assert_eq(core.snapshot().echoes[0].ticks_left, 1)
	var walked: Vector2 = core.player.position
	core.step(input(Vector2.RIGHT))
	assert_eq(core.tick, a + Tuning.ECHO_STEP_DELAY_TICKS)
	var recall: GameEvent = find_event(core, GameEvent.ECHO_RECALL)
	assert_true(recall != null, "echo_recall on placement + 120")
	if recall != null:
		assert_eq(recall.data["from"], walked + Vector2.RIGHT * Tuning.PLAYER_SPEED, "from where this tick's walk ended")
		assert_eq(recall.data["to"], anchor)
		assert_eq(recall.data["invuln_ticks"], Tuning.ECHO_STEP_INVULN_TICKS)
		assert_eq(recall.data["waited"], 0)
	assert_eq(core.player.position, anchor, "teleported back")
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_eq(core.echoes.size(), 0, "the echo disappears on arrival")
	assert_eq(core.snapshot().echoes.size(), 0)
	assert_eq(core.snapshot().player.echo_invuln_ticks, Tuning.ECHO_STEP_INVULN_TICKS)
	assert_eq(core.snapshot().hud.aspect_slots[1]["running"], false)


func test_invulnerable_for_exactly_twelve_ticks_from_the_arrival() -> void:
	var core: GameCore = _core()
	_press(core)
	_to(core, core.tick + Tuning.ECHO_STEP_DELAY_TICKS)
	assert_true(find_event(core, GameEvent.ECHO_RECALL) != null)
	var arrival: int = core.tick
	var covered: int = 0
	for k: int in 20:
		if core.snapshot().player.invulnerable:
			covered += 1
			assert_eq(core.tick, arrival + covered - 1, "contiguous from the arrival")
		core.step(InputFrame.new())
	assert_eq(covered, Tuning.ECHO_STEP_INVULN_TICKS, "12 ticks: arrival .. arrival + 11")


## A slam aimed at the anchor that lands `offset` ticks after the arrival.
func _slam_after_arrival(offset: int) -> GameCore:
	var core: GameCore = _core()
	core.player.hp = 1000
	_press(core)
	var anchor: Vector2 = core.player.position
	var arrival: int = core.tick + Tuning.ECHO_STEP_DELAY_TICKS
	var commit: int = arrival + offset - Tuning.SLAM_WINDUP_TICKS
	_to(core, commit - 1, input(Vector2.UP))
	core.boss.state = BossState.STATE_IDLE
	core.boss.cooldown = 1
	core.boss.next_attack_override = BossState.ATTACK_SLAM
	core.step(input(Vector2.UP))
	assert_eq(core.boss.telegraphs.size(), 1, "the slam started")
	if core.boss.telegraphs.size() == 1:
		core.boss.telegraphs[0].center = anchor
		assert_eq(core.boss.telegraphs[0].hit_tick, arrival + offset)
	_to(core, arrival, input(Vector2.UP))
	assert_eq(core.player.position, anchor, "back on the anchor")
	_to(core, arrival + offset)
	return core


func test_damage_is_ignored_during_the_invulnerability_and_lands_after_it() -> void:
	var covered: GameCore = _slam_after_arrival(Tuning.ECHO_STEP_INVULN_TICKS - 1)
	assert_eq(covered.player.hp, 1000, "a slam on the last i-frame does nothing")
	assert_true(find_event(covered, GameEvent.DAMAGE_TAKEN) == null)
	var late: GameCore = _slam_after_arrival(Tuning.ECHO_STEP_INVULN_TICKS)
	assert_eq(late.player.hp, 1000 - Tuning.SLAM_DAMAGE, "one tick later it hits")


## A free spot in the clearing that touches a solid prop (0.5 px gap), far from the boss: [spot, direction into the prop].
func _spot_beside_prop(core: GameCore) -> Array:
	var outline: PackedVector2Array = PackedVector2Array(ArenaLayout.BOUNDARY)
	for o: Obstacle in core.obstacles:
		for k: int in 8:
			var dir: Vector2 = Vector2.RIGHT.rotated(TAU * k / 8.0)
			var candidate: Vector2 = o.center + dir * (o.radius + Tuning.PLAYER_RADIUS + 0.5)
			if core.arena_point(candidate, Tuning.PLAYER_RADIUS) == candidate and Geometry2D.is_point_in_polygon(candidate, outline) and candidate.distance_to(core.boss.position) > 80.0:
				return [candidate, -dir]
	return [Vector2.INF, Vector2.ZERO]


func test_an_echo_next_to_a_prop_and_at_the_arena_edge_is_a_valid_spot() -> void:
	var core: GameCore = _core(true)
	var outline: PackedVector2Array = PackedVector2Array(ArenaLayout.BOUNDARY)
	var found: Array = _spot_beside_prop(core)
	var spot: Vector2 = found[0]
	var toward: Vector2 = found[1]
	assert_true(spot != Vector2.INF, "found a free spot touching a prop")
	core.player.position = spot
	_press(core, toward)  # pushing into the prop on the press tick
	var placed: GameEvent = find_event(core, GameEvent.ECHO_PLACED)
	assert_true(placed != null)
	var anchor: Vector2 = placed.data["position"] if placed != null else Vector2.ZERO
	assert_false(_overlaps_prop(core, anchor, Tuning.PLAYER_RADIUS), "the anchor is out of the prop")
	assert_true(Geometry2D.is_point_in_polygon(anchor, outline), "and in the clearing")
	_to(core, core.tick + Tuning.ECHO_STEP_DELAY_TICKS, input(-toward))
	assert_true(find_event(core, GameEvent.ECHO_RECALL) != null)
	assert_eq(core.player.position, anchor, "arrives exactly on it")
	assert_false(_overlaps_prop(core, core.player.position, Tuning.PLAYER_RADIUS))
	var edge: GameCore = _core()
	edge.player.position = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	_press(edge, Vector2(-1.0, -1.0))
	var corner: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	assert_eq(edge.echoes[0].position if edge.echoes.size() > 0 else Vector2.ZERO, corner, "the corner of the arena is kept")
	_to(edge, edge.tick + Tuning.ECHO_STEP_DELAY_TICKS, input(Vector2(1.0, 1.0)))
	assert_eq(edge.player.position, corner, "back in the corner")
	assert_true(_in_arena(edge.player.position))


func test_a_boss_standing_on_the_anchor_moves_the_arrival_to_the_nearest_free_spot() -> void:
	var core: GameCore = _core()
	_press(core)
	var anchor: Vector2 = core.player.position
	_to(core, core.tick + Tuning.ECHO_STEP_DELAY_TICKS - 1, input(Vector2.DOWN))
	core.boss.position = anchor + Vector2(4.0, 0.0)  # the boss body covers the anchor
	core.step(InputFrame.new())
	var recall: GameEvent = find_event(core, GameEvent.ECHO_RECALL)
	assert_true(recall != null)
	var min_dist: float = Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS
	assert_true(core.player.position.distance_to(core.boss.position) >= min_dist - 0.01, "not inside the boss")
	assert_true(core.player.position.distance_to(anchor) <= min_dist + 4.0 + 0.01, "right next to the anchor")
	if recall != null:
		assert_eq(recall.data["anchor"], anchor)
		assert_eq(recall.data["to"], core.player.position)
	# The same with the real arena: anchor beside a prop and the boss on it.
	var real: GameCore = _core(true)
	var outline: PackedVector2Array = PackedVector2Array(ArenaLayout.BOUNDARY)
	var found: Array = _spot_beside_prop(real)
	real.player.position = found[0]
	_press(real)
	var spot: Vector2 = real.echoes[0].position
	_to(real, real.tick + Tuning.ECHO_STEP_DELAY_TICKS - 1, input(-found[1]))
	real.boss.position = spot
	real.step(InputFrame.new())
	assert_true(find_event(real, GameEvent.ECHO_RECALL) != null)
	assert_false(_overlaps_prop(real, real.player.position, Tuning.PLAYER_RADIUS), "not in a prop")
	assert_true(real.player.position.distance_to(real.boss.position) >= min_dist - 0.01, "not in the boss")
	assert_true(Geometry2D.is_point_in_polygon(real.player.position, outline), "in the clearing")


func test_the_recall_waits_for_a_barrage_or_a_coil() -> void:
	var core: GameCore = _core()
	core.player.weapon_id = Tuning.WEAPON_DUAL_DAGGER
	_press(core)
	var a: int = core.tick
	_to(core, a + 100)
	core.player.edge = 100.0
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	core.step(active)
	assert_eq(core.player.state, PlayerState.STATE_LIGHTNING_BARRAGE)
	var barrage_start: int = core.tick
	var recall_tick: int = -1
	var ended_tick: int = -1
	var waited: int = -1
	for i: int in 80:
		core.step(InputFrame.new())
		if find_event(core, GameEvent.LIGHTNING_BARRAGE_ENDED) != null:
			ended_tick = core.tick
		var recall: GameEvent = find_event(core, GameEvent.ECHO_RECALL)
		if recall != null:
			recall_tick = core.tick
			waited = recall.data["waited"]
	assert_eq(ended_tick, barrage_start + Weapons.barrage_total_ticks())
	assert_eq(recall_tick, ended_tick, "the recall happens the tick the barrage ends")
	assert_eq(waited, recall_tick - (a + Tuning.ECHO_STEP_DELAY_TICKS))
	assert_true(waited > 0 and waited <= Weapons.reaper_coil_total_ticks(), "waited %d" % waited)
	var coil: GameCore = _core()
	coil.player.weapon_id = Tuning.WEAPON_CHAIN_SCYTHE
	coil.boss.position = START + Vector2(100.0, 0.0)
	_press(coil)
	var c: int = coil.tick
	_to(coil, c + 110)
	coil.player.edge = 100.0
	var hook: InputFrame = InputFrame.new()
	hook.weapon_active_pressed = true
	hook.aim = Vector2.RIGHT
	coil.step(hook)
	assert_eq(coil.player.state, PlayerState.STATE_REAPER_COIL)
	var coil_end: int = -1
	var coil_recall: int = -1
	for i: int in 80:
		coil.step(InputFrame.new())
		if find_event(coil, GameEvent.REAPER_COIL_ENDED) != null:
			coil_end = coil.tick
		if find_event(coil, GameEvent.ECHO_RECALL) != null:
			coil_recall = coil.tick
			assert_eq(coil.player.state, PlayerState.STATE_IDLE)
	assert_true(coil_end > c + Tuning.ECHO_STEP_DELAY_TICKS, "the coil was still running when the recall was due")
	assert_eq(coil_recall, coil_end, "the recall happens the tick the coil ends")


func test_a_second_placement_is_refused_while_an_echo_exists() -> void:
	var core: GameCore = _core()
	_press(core)
	run(core, 5)
	core.player.edge = 100.0
	core.player.aspect_cooldowns[Aspects.ECHO_STEP] = 0  # isolate the one-echo rule from the cooldown
	_press(core, Vector2.RIGHT)
	assert_true(find_event(core, GameEvent.ECHO_PLACED) == null, "no second echo")
	assert_near(core.player.edge, 100.0, 0.001, "nothing spent")
	assert_eq(int(core.player.aspect_cooldowns[Aspects.ECHO_STEP]), 0, "no cooldown started")
	assert_eq(core.echoes.size(), 1)


func test_the_cooldown_counts_from_the_placement() -> void:
	var core: GameCore = _core()
	_press(core)
	var a: int = core.tick
	_to(core, a + Tuning.ECHO_STEP_COOLDOWN_TICKS - 2)
	core.player.edge = 100.0
	_press(core)
	assert_true(find_event(core, GameEvent.ECHO_PLACED) == null, "one tick early: refused")
	_press(core)
	assert_eq(core.tick, a + Tuning.ECHO_STEP_COOLDOWN_TICKS)
	assert_true(find_event(core, GameEvent.ECHO_PLACED) != null, "ready 840 ticks after the placement")
	assert_eq(Tuning.ECHO_STEP_COOLDOWN_TICKS, 840)
	assert_near(Tuning.ECHO_STEP_EDGE_COST, 25.0, 0.0001)
	var poor: GameCore = _core()
	poor.player.edge = Tuning.ECHO_STEP_EDGE_COST - 1.0
	_press(poor)
	assert_eq(poor.echoes.size(), 0, "not enough Edge")


func test_death_clears_the_echo() -> void:
	var core: GameCore = _core()
	_press(core)
	run(core, 10)
	var events: Array[GameEvent] = []
	core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
	core.step(InputFrame.new())
	var expired: GameEvent = find_event(core, GameEvent.ECHO_EXPIRED)
	assert_true(expired != null and expired.data["reason"] == &"death", "echo_expired death")
	assert_eq(core.echoes.size(), 0)
	assert_eq(core.result, GameCore.RESULT_DEFEAT)
	var died: GameCore = _core()
	died.player.hp = 1
	_press(died)
	died.boss.state = BossState.STATE_IDLE
	var hit_tick: int = begin_attack(died, BossState.ATTACK_STOMP, died.boss.position + Vector2(-70.0, 0.0))
	_to(died, hit_tick)
	assert_eq(died.player.state, PlayerState.STATE_DEAD)
	var types: Array[StringName] = event_types(died)
	assert_true(types.has(GameEvent.ECHO_EXPIRED), "a death by a boss hit removes it the same tick")
	assert_true(types.find(GameEvent.ENTITY_DIED) < types.find(GameEvent.ECHO_EXPIRED), "after entity_died")
	assert_eq(GameCore.new().echoes.size(), 0, "a new fight has none")


func test_the_recall_cancels_swings_dashes_skills_and_releases_a_ward() -> void:
	for setup: String in ["attack", "dash", "moon_cleave", "ward"]:
		var core: GameCore = _core()
		core.boss.position = START + Vector2(40.0, 0.0)
		var e: InputFrame = InputFrame.new()
		e.aspect_equip = Aspects.STONE_WARD if setup == "ward" else Aspects.MOON_CLEAVE
		e.aspect_equip_slot = 1
		core.step(e)
		_press(core)
		var a: int = core.tick
		var due: int = a + Tuning.ECHO_STEP_DELAY_TICKS
		match setup:
			"attack":
				_to(core, due - 2)
				core.step(input(Vector2.ZERO, false, false, true))
			"dash":
				_to(core, due - 2)
				core.step(input(Vector2.UP, true))
			"moon_cleave", "ward":
				_to(core, due - 6)
				core.player.edge = 100.0
				var press: InputFrame = InputFrame.new()
				press.skill_pressed = 1
				press.move = Vector2.UP
				core.step(press)
		var busy: StringName = core.player.state
		assert_true(busy != PlayerState.STATE_IDLE and busy != PlayerState.STATE_WALK, "busy before the recall: " + setup)
		_to(core, due - 1, input(Vector2.UP))
		core.step(input(Vector2.UP))
		var recall: GameEvent = find_event(core, GameEvent.ECHO_RECALL)
		assert_true(recall != null, "recall during " + setup)
		assert_eq(core.player.state, PlayerState.STATE_IDLE, "back to idle from " + setup)
		assert_eq(core.player.combo_index, 1)
		if setup == "ward":
			var released: GameEvent = find_event(core, GameEvent.WARD_RELEASED)
			assert_true(released != null and released.data["reason"] == &"recall", "the ward releases on the recall")
			var types: Array[StringName] = event_types(core)
			assert_true(types.find(GameEvent.WARD_RELEASED) < types.find(GameEvent.ECHO_RECALL), "before the teleport")
			if released != null and recall != null:
				assert_eq(released.data["position"], recall.data["from"], "where the player stood")
		run(core, 60)
		assert_true(core.skill_attacks.is_empty(), "nothing of the cancelled action spawned: " + setup)


func _scripted(seed_value: int) -> Array[String]:
	var core: GameCore = GameCore.new(seed_value)
	core.player.set_equipped_aspects([Aspects.STONE_WARD, Aspects.ECHO_STEP, Aspects.SPRINT])
	core.player.hp = 100000
	var lines: Array[String] = []
	for i: int in 1500:
		var frame: InputFrame = InputFrame.new()
		frame.attack_pressed = i % 4 == 0
		frame.skill_pressed = [1, 2, 3][(i / 61) % 3] if i % 61 == 0 else 0
		frame.move = Vector2.RIGHT.rotated(float(i) * 0.05) if i % 40 < 20 else Vector2.ZERO
		if i % 61 == 0:
			core.player.edge = 100.0
		core.step(frame)
		for event: GameEvent in core.last_events:
			lines.append("%d %s %s" % [event.tick, event.type, str(event.data)])
		lines.append("%d %s %s" % [core.tick, str(core.player.position), str(core.boss.position)])
		if core.result != GameCore.RESULT_PLAYING:
			break
	return lines


func test_two_identical_runs_give_identical_results() -> void:
	var a: Array[String] = _scripted(7)
	var b: Array[String] = _scripted(7)
	assert_eq(a.size(), b.size(), "same number of lines")
	assert_true(a == b, "identical logs")
	var joined: String = "\n".join(a)
	for type: StringName in [GameEvent.SPRINT_STARTED, GameEvent.ECHO_RECALL, GameEvent.WARD_RELEASED]:
		assert_true(joined.contains(" " + String(type) + " "), "the run used " + String(type))


## 3000 ticks of random input with random equips and uses of all eight aspects in the real arena (a new fight when one
## ends): no crash, nobody inside a prop or out in the forest, and the events stay consistent every tick.
func _soak(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var core: GameCore = GameCore.new(seed_value)
	var outline: PackedVector2Array = PackedVector2Array(ArenaLayout.BOUNDARY)
	var stats: Dictionary = {"fights": 1, "equips": 0, "sprints": 0, "echo_placed": 0, "echo_recall": 0, "echo_expired": 0, "wards": 0, "ward_released": 0, "ward_blocked": 0, "phantoms": 0, "lanterns": 0, "bad_ticks": 0}
	var sprint_open: int = 0
	var echo_open: int = 0
	for i: int in 3000:
		var calm: bool = i % 200 >= 150
		var frame: InputFrame = InputFrame.new()
		frame.move = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		frame.aim = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if not calm and rng.randf() < 0.6:
			var to_boss: Vector2 = core.boss.position - core.player.position
			frame.move = to_boss.normalized() if to_boss.length() > 30.0 else Vector2.ZERO
			frame.aim = to_boss.normalized()
		frame.attack_pressed = rng.randf() < (0.0 if calm else 0.3)
		frame.parry_pressed = rng.randf() < (0.0 if calm else 0.05)
		frame.dash_pressed = rng.randf() < (0.0 if calm else 0.03)
		frame.skill_pressed = rng.randi_range(1, 3) if rng.randf() < (0.06 if calm else 0.12) else 0
		frame.weapon_active_pressed = rng.randf() < (0.0 if calm else 0.005)
		if rng.randf() < 0.03:
			frame.weapon_equip = Weapons.IDS[rng.randi_range(0, 2)]
		if rng.randf() < (0.3 if calm else 0.05):
			frame.aspect_equip = Aspects.ALL[rng.randi_range(0, Aspects.ALL.size() - 1)]
			frame.aspect_equip_slot = rng.randi_range(1, 3)
		if rng.randf() < 0.1:
			core.player.edge = 100.0  # test shortcuts: enough Edge for the aspects, and longer fights
		if rng.randf() < 0.01 and core.player.hp > 0:
			core.player.hp = Tuning.PLAYER_MAX_HP
		var prev_state: StringName = core.player.state
		core.step(frame)
		var problems: Array[String] = []
		for event: GameEvent in core.last_events:
			match event.type:
				GameEvent.ASPECT_EQUIPPED:
					stats["equips"] += 1
				GameEvent.SPRINT_STARTED:
					stats["sprints"] += 1
					sprint_open += 1
				GameEvent.SPRINT_ENDED:
					sprint_open -= 1
				GameEvent.ECHO_PLACED:
					stats["echo_placed"] += 1
					echo_open += 1
					if _overlaps_prop(core, event.data["position"], Tuning.PLAYER_RADIUS) or not _in_arena(event.data["position"]):
						problems.append("anchor in a prop or out of the arena")
				GameEvent.ECHO_RECALL:
					stats["echo_recall"] += 1
					echo_open -= 1
					if _overlaps_prop(core, event.data["to"], Tuning.PLAYER_RADIUS):
						problems.append("recall into a prop")
				GameEvent.ECHO_EXPIRED:
					stats["echo_expired"] += 1
					echo_open -= 1
				GameEvent.WARD_RAISED:
					stats["wards"] += 1
				GameEvent.WARD_RELEASED:
					stats["ward_released"] += 1
					if prev_state != PlayerState.STATE_WARD:
						problems.append("released without a ward")
					if int(event.data["stored"]) > Tuning.STONE_WARD_STORE_CAP:
						problems.append("stored over the cap")
				GameEvent.WARD_BLOCKED:
					stats["ward_blocked"] += 1
					if core.player.state != PlayerState.STATE_WARD:
						problems.append("blocked outside a ward")
				GameEvent.DAMAGE_TAKEN:
					if event.data["entity_id"] == core.player.id and core.player.state == PlayerState.STATE_WARD:
						problems.append("damage taken through a raised ward")
				GameEvent.PHANTOM_CUT_STARTED:
					stats["phantoms"] += 1
				GameEvent.LANTERN_PLACED:
					stats["lanterns"] += 1
		if not Aspects.is_valid_loadout(core.player.equipped_aspects):
			problems.append("invalid loadout %s" % str(core.player.equipped_aspects))
		for body: Array in [[core.player.position, Tuning.PLAYER_RADIUS, "player"], [core.boss.position, Tuning.BOSS_RADIUS, "boss"]]:
			if _overlaps_prop(core, body[0], body[1]):
				problems.append("%s inside a prop at %s" % [body[2], str(body[0])])
			if not Geometry2D.is_point_in_polygon(body[0], outline):
				problems.append("%s out in the forest at %s" % [body[2], str(body[0])])
		if core.echoes.size() > 1 or echo_open != core.echoes.size():
			problems.append("echo events %d vs echoes %d" % [echo_open, core.echoes.size()])
		if sprint_open != (1 if core.player.sprint_ticks_left > 0 else 0):
			problems.append("sprint started/ended balance")
		if core.player.state == PlayerState.STATE_WARD and (core.player.ward_ticks_left < 1 or core.player.ward_ticks_left > Tuning.STONE_WARD_DURATION_TICKS):
			problems.append("ward ticks %d" % core.player.ward_ticks_left)
		if core.player.ward_stored > Tuning.STONE_WARD_STORE_CAP:
			problems.append("ward stored over the cap")
		if core.player.hp < 0 or core.player.hp > Tuning.PLAYER_MAX_HP or core.player.edge < 0.0 or core.player.edge > Tuning.EDGE_MAX + 0.0001:
			problems.append("hp/Edge out of range")
		if not problems.is_empty():
			stats["bad_ticks"] += 1
			if stats["bad_ticks"] <= 5:
				assert_true(false, "seed %d tick %d: %s" % [seed_value, core.tick, ", ".join(problems)])
		if core.result != GameCore.RESULT_PLAYING:
			core = GameCore.new(seed_value + i)
			stats["fights"] += 1
			sprint_open = 0
			echo_open = 0
	return stats


func test_soak_with_all_eight_aspects() -> void:
	var total: Dictionary = {}
	for seed_value: int in [11, 2024]:
		var stats: Dictionary = _soak(seed_value)
		assert_eq(stats["bad_ticks"], 0, "seed %d: %s" % [seed_value, str(stats)])
		for key: String in stats:
			total[key] = int(total.get(key, 0)) + int(stats[key])
	for key: String in ["equips", "sprints", "echo_placed", "echo_recall", "wards", "ward_released", "phantoms", "lanterns"]:
		assert_true(int(total[key]) > 0, "%s > 0 over both seeds: %s" % [key, str(total)])
	print("    soak totals: %s" % str(total))
