extends "res://tests/test_case.gd"
## The Lightning Barrage: activating the Dual Dagger's Lightning Form runs 8 automatic blink-slashes at the boss, one
## from each side. The form is only the barrage: it ends with it.

const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const Obstacle := preload("res://core/obstacle.gd")

const BOSS_AT: Vector2 = Vector2(400.0, 240.0)


## A pinned boss (it neither walks nor attacks), the player `offset` from it with the dagger and full Edge.
func _core(offset: Vector2 = Vector2(-100.0, 0.0), boss_at: Vector2 = BOSS_AT, clear_props: bool = true, weapon: StringName = Tuning.WEAPON_DUAL_DAGGER) -> GameCore:
	var core: GameCore = GameCore.new()
	if clear_props:
		core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = boss_at
	core.player.position = boss_at + offset
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	core.player.weapon_id = weapon
	return core


func _activate() -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_active_pressed = true
	return frame


## Activate, then step idle input through the whole barrage (plus `extra` ticks). Returns every event, in order.
func _run_barrage(core: GameCore, extra: int = 2, frame: InputFrame = null) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	core.step(_activate())
	events.append_array(core.last_events)
	for i: int in Weapons.barrage_total_ticks() + extra:
		core.step(frame if frame != null else InputFrame.new())
		events.append_array(core.last_events)
	return events


func _of(events: Array[GameEvent], type: StringName) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event: GameEvent in events:
		if event.type == type:
			found.append(event)
	return found


func _player_hits(events: Array[GameEvent], core: GameCore) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event: GameEvent in _of(events, GameEvent.ATTACK_HIT):
		if int(event.data["attacker_id"]) == core.player.id:
			found.append(event)
	return found


func test_tuning_is_sane() -> void:
	assert_eq(Weapons.barrage_slashes(), 8, "8 slashes")
	assert_true(Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS < Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS, "a slash lands before the next starts")
	assert_true(Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS >= 5 and Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS <= 7, "5-7 ticks apart")
	assert_true(Weapons.barrage_total_ticks() >= 45 and Weapons.barrage_total_ticks() <= 70, "about a second (%d ticks)" % Weapons.barrage_total_ticks())
	assert_eq(Weapons.active_duration(Tuning.WEAPON_DUAL_DAGGER), Weapons.barrage_total_ticks(), "the form is the barrage")
	var sorted: Array[int] = Tuning.LIGHTNING_BLINK_ORDER.duplicate()
	sorted.sort()
	assert_eq(sorted, [0, 1, 2, 3, 4, 5, 6, 7] as Array[int], "the order uses every side once")


func test_eight_slashes_one_from_each_side_in_the_blink_order() -> void:
	var core: GameCore = _core()
	var events: Array[GameEvent] = _run_barrage(core)
	var blinks: Array[GameEvent] = _of(events, GameEvent.LIGHTNING_BLINK)
	assert_eq(blinks.size(), 8, "exactly 8 blinks")
	var sides: Array[int] = []
	for i: int in blinks.size():
		sides.append(int(blinks[i].data["direction_index"]))
		assert_eq(int(blinks[i].data["barrage_slash"]), i + 1, "blink %d is slash %d" % [i + 1, i + 1])
		assert_eq(blinks[i].data["to"], BOSS_AT + Weapons.blink_direction(sides[i]) * Tuning.LIGHTNING_BLINK_DISTANCE, "next to the boss, slash %d" % (i + 1))
		if i > 0:
			assert_eq(blinks[i].data["from"], blinks[i - 1].data["to"], "chained from the previous spot")
	assert_eq(sides, Tuning.LIGHTNING_BLINK_ORDER, "sides follow LIGHTNING_BLINK_ORDER, each once")
	var hits: Array[GameEvent] = _player_hits(events, core)
	assert_eq(hits.size(), 8, "one hit per slash")
	for i: int in hits.size():
		assert_eq(int(hits[i].data["barrage_slash"]), i + 1)
		assert_eq(hits[i].data["weapon_id"], Tuning.WEAPON_DUAL_DAGGER)
		assert_false(hits[i].data.has("combo_index"), "a barrage hit is not a combo swing")
	var strikes: Array[GameEvent] = _of(events, GameEvent.LIGHTNING_STRIKE)
	assert_eq(strikes.size(), 1, "the last slash calls the sky bolt")
	if strikes.size() == 1:
		assert_eq(strikes[0].tick, hits[7].tick, "on the last slash's hit tick")
		assert_eq(strikes[0].data["source"], &"barrage")
		assert_eq(int(strikes[0].data["barrage_slash"]), 8)
	assert_eq(_of(events, GameEvent.LIGHTNING_BARRAGE_STARTED).size(), 1)
	assert_eq(_of(events, GameEvent.LIGHTNING_BARRAGE_ENDED).size(), 1)
	# Nothing more after it: the next 100 idle ticks are quiet.
	var later: Array[GameEvent] = []
	for i: int in 100:
		core.step(InputFrame.new())
		later.append_array(core.last_events)
	assert_eq(_of(later, GameEvent.LIGHTNING_BLINK).size() + _player_hits(later, core).size(), 0, "the barrage is over")


func test_timing_and_event_order() -> void:
	var core: GameCore = _core()
	var events: Array[GameEvent] = _run_barrage(core, 5)
	var activation: int = 1
	var started: Array[GameEvent] = _of(events, GameEvent.LIGHTNING_BARRAGE_STARTED)
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0].tick, activation, "starts on the activation tick")
		assert_eq(int(started[0].data["slashes"]), 8)
		assert_eq(int(started[0].data["entity_id"]), core.player.id)
	assert_true(events.find(_of(events, GameEvent.WEAPON_BUFF_STARTED)[0]) < events.find(started[0]), "weapon_buff_started first")
	var blinks: Array[GameEvent] = _of(events, GameEvent.LIGHTNING_BLINK)
	var hits: Array[GameEvent] = _player_hits(events, core)
	for i: int in mini(blinks.size(), hits.size()):
		var blink_tick: int = activation + Tuning.LIGHTNING_BARRAGE_START_DELAY_TICKS + i * Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS
		assert_eq(blinks[i].tick, blink_tick, "slash %d blinks on time" % (i + 1))
		assert_eq(hits[i].tick, blink_tick + Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS, "slash %d lands on time" % (i + 1))
		assert_true(events.find(blinks[i]) < events.find(hits[i]), "blink before its hit")
	var ended: Array[GameEvent] = _of(events, GameEvent.LIGHTNING_BARRAGE_ENDED)
	assert_eq(ended.size(), 1)
	if ended.size() == 1:
		assert_eq(ended[0].tick, activation + Weapons.barrage_total_ticks(), "ends RECOVERY ticks after the last hit")
		assert_eq(int(ended[0].data["slashes"]), 8)
		assert_eq(ended[0].data["reason"], &"complete")
		assert_true(events.find(ended[0]) > events.find(_of(events, GameEvent.LIGHTNING_STRIKE)[0]), "ended after the finisher")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "back to idle")
	assert_false(core.player.is_buff_active(), "the form ended with the barrage")


func test_snapshot_shows_the_state_and_the_slash() -> void:
	var core: GameCore = _core()
	core.step(_activate())
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.state, PlayerState.STATE_LIGHTNING_BARRAGE)
	assert_eq(snap.player.lightning_barrage_slash, 0, "no slash yet on the activation tick")
	assert_true(snap.player.invulnerable)
	for i: int in Weapons.barrage_total_ticks() - 1:
		core.step(InputFrame.new())
		snap = core.snapshot()
		var t: int = core.player.state_ticks - Tuning.LIGHTNING_BARRAGE_START_DELAY_TICKS
		var expected: int = mini(8, t / Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS + 1)
		assert_eq(snap.player.lightning_barrage_slash, expected, "slash number at barrage tick %d" % core.player.state_ticks)
		assert_eq(snap.player.lightning_barrage_slash_tick, snap.player.lightning_blink_tick, "slash tick is its blink tick")
		assert_true(snap.player.facing.dot((core.boss.position - core.player.position).normalized()) > 0.99, "faces the boss")
	core.step(InputFrame.new())
	snap = core.snapshot()
	assert_eq(snap.player.state, PlayerState.STATE_IDLE)
	assert_eq(snap.player.lightning_barrage_slash, 0)
	assert_eq(snap.player.lightning_barrage_slash_tick, -1)


func test_damage_posture_and_edge_per_slash() -> void:
	var core: GameCore = _core()
	var events: Array[GameEvent] = _run_barrage(core)
	var per_slash: int = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.LIGHTNING_BARRAGE_DAMAGE_MULT * Tuning.ARMOR_DAMAGE_FACTOR))
	var strike: int = maxi(1, roundi(Tuning.LIGHTNING_STRIKE_DAMAGE * Tuning.ARMOR_DAMAGE_FACTOR))
	for hit: GameEvent in _player_hits(events, core):
		assert_eq(int(hit.data["damage"]), per_slash, "armored slash damage")
		assert_eq(hit.data["kind"], &"normal")
	var strikes: Array[GameEvent] = _of(events, GameEvent.LIGHTNING_STRIKE)
	if strikes.size() == 1:
		assert_eq(int(strikes[0].data["damage"]), strike, "normal sky bolt damage")
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, 8 * per_slash + strike, "the boss took 8 slashes and the bolt")
	var posture: float = 8.0 * Tuning.NORMAL_HIT_POSTURE + Tuning.LIGHTNING_STRIKE_POSTURE
	assert_near(core.boss.posture, posture, 2.5, "posture from every slash and the bolt (less decay)")
	assert_near(core.player.edge, 100.0 - Tuning.LIGHTNING_FORM_EDGE_COST + 8.0 * Tuning.LIGHTNING_BARRAGE_EDGE_PER_HIT, 0.001, "cost spent, Edge per slash gained")


func test_counter_rules_match_a_normal_swing() -> void:
	var core: GameCore = _core()
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 0, [])
	assert_eq(core.boss.state, BossState.STATE_BROKEN)
	var events: Array[GameEvent] = _run_barrage(core)
	var hits: Array[GameEvent] = _player_hits(events, core)
	assert_true(hits.size() >= 1)
	if hits.is_empty():
		return
	var base: float = Tuning.ATTACK_DAMAGE * Tuning.LIGHTNING_BARRAGE_DAMAGE_MULT
	var edge_left: float = 100.0 - Tuning.LIGHTNING_FORM_EDGE_COST
	assert_eq(hits[0].data["kind"], &"counter")
	assert_eq(int(hits[0].data["damage"]), roundi(base * Tuning.COUNTER_DAMAGE_MULT + edge_left * Tuning.EDGE_COUNTER_BONUS), "the first counter spends the Edge")
	if hits.size() >= 2 and hits[1].data["kind"] == &"counter":
		assert_eq(int(hits[1].data["damage"]), roundi(base * Tuning.COUNTER_DAMAGE_MULT), "later counters without Edge")


func test_a_slash_that_breaks_posture_makes_the_next_ones_counters() -> void:
	var core: GameCore = _core()
	core.boss.posture = Tuning.BOSS_POSTURE_MAX - Tuning.NORMAL_HIT_POSTURE * 2.0 + 0.5
	var events: Array[GameEvent] = _run_barrage(core)
	var kinds: Array[StringName] = []
	for hit: GameEvent in _player_hits(events, core):
		kinds.append(hit.data["kind"])
	assert_eq(_of(events, GameEvent.POSTURE_BROKEN).size(), 1, "a slash broke the posture")
	assert_eq(kinds.slice(0, 3), [&"normal", &"normal", &"counter"] as Array[StringName], "the slash after the break is a counter")


func test_invulnerable_and_boss_attacks_do_nothing() -> void:
	for barrage: bool in [true, false]:
		var core: GameCore = _core(Vector2(-100.0, 0.0), BOSS_AT, true, Tuning.WEAPON_DUAL_DAGGER if barrage else Tuning.WEAPON_BLACK_KATANA)
		var telegraph: Telegraph = Telegraph.new()
		telegraph.id = 99
		telegraph.owner_id = core.boss.id
		telegraph.kind = Telegraph.KIND_RED
		telegraph.shape = Telegraph.SHAPE_CIRCLE
		telegraph.center = BOSS_AT
		telegraph.size = 1000.0
		telegraph.damage = 20
		telegraph.hit_tick = 3
		telegraph.end_tick = Weapons.barrage_total_ticks() - 1
		core.boss.telegraphs.append(telegraph)
		var events: Array[GameEvent] = []
		core.step(_activate())
		for i: int in Weapons.barrage_total_ticks() - 1:
			core.step(InputFrame.new())
			events.append_array(core.last_events)
			if barrage:
				assert_true(core.player.is_invulnerable() and core.snapshot().player.invulnerable, "invulnerable at barrage tick %d" % core.player.state_ticks)
		var hurt: int = 0
		for event: GameEvent in _of(events, GameEvent.DAMAGE_TAKEN):
			if int(event.data["entity_id"]) == core.player.id:
				hurt += 1
		if barrage:
			assert_eq(hurt, 0, "a boss attack hitting the barrage does nothing")
			assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP)
			assert_false(core.player.take_damage(10, core.tick, [], core.boss.id), "take_damage is refused")
		else:
			assert_true(hurt > 0, "control: the same attack hits a player without the barrage")


func test_the_player_cannot_move_or_act_during_the_barrage() -> void:
	var core: GameCore = _core()
	core.player.retaliate_ticks = 1000
	core.step(_activate())
	var spot: Vector2 = core.player.position
	for i: int in Weapons.barrage_total_ticks() - 1:
		var frame: InputFrame = InputFrame.new()
		frame.move = Vector2.RIGHT.rotated(float(i))
		frame.aim = Vector2.LEFT
		frame.attack_pressed = true
		frame.dash_pressed = i % 2 == 0
		frame.parry_pressed = i % 3 == 0
		frame.skill_pressed = 1 + i % 3
		frame.weapon_equip = Tuning.WEAPON_BLACK_KATANA
		frame.weapon_active_pressed = true
		core.step(frame)
		assert_eq(core.player.state, PlayerState.STATE_LIGHTNING_BARRAGE, "still in the barrage at tick %d" % core.tick)
		for type: StringName in [GameEvent.DASH_STARTED, GameEvent.SKILL_STARTED, GameEvent.WEAPON_SWAPPED, GameEvent.WEAPON_BUFF_STARTED, GameEvent.PARRY_FAILED]:
			assert_true(find_event(core, type) == null, "no %s during the barrage" % type)
		var blink: GameEvent = find_event(core, GameEvent.LIGHTNING_BLINK)
		if blink != null:
			spot = blink.data["to"]
		assert_true(core.player.position.distance_to(spot) < 0.01, "only the blinks move the player (tick %d)" % core.tick)
		assert_true(core.player.facing.dot((core.boss.position - core.player.position).normalized()) > 0.99, "aim does not turn the player away")
	assert_eq(core.player.weapon_id, Tuning.WEAPON_DUAL_DAGGER)
	assert_eq(core.player.skill_cooldowns, [0, 0, 0] as Array[int], "no skill was used")
	core.step(InputFrame.new())
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	var dash: InputFrame = InputFrame.new()
	dash.dash_pressed = true
	dash.move = Vector2.LEFT
	core.step(dash)
	assert_eq(core.player.state, PlayerState.STATE_DASH, "control returns after the barrage")


func test_boss_death_ends_the_barrage() -> void:
	var core: GameCore = _core()
	var per_slash: int = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.LIGHTNING_BARRAGE_DAMAGE_MULT * Tuning.ARMOR_DAMAGE_FACTOR))
	core.boss.hp = per_slash * 2  # the second slash kills it
	var events: Array[GameEvent] = _run_barrage(core)
	assert_eq(_of(events, GameEvent.LIGHTNING_BLINK).size(), 2, "no slash after the boss died")
	var ended: Array[GameEvent] = _of(events, GameEvent.LIGHTNING_BARRAGE_ENDED)
	assert_eq(ended.size(), 1)
	if ended.size() == 1:
		assert_eq(ended[0].data["reason"], &"boss_dead")
		assert_eq(int(ended[0].data["slashes"]), 2)
		assert_true(events.find(ended[0]) < events.find(_of(events, GameEvent.GAME_RESULT)[0]), "ended before the result")
	assert_eq(core.result, GameCore.RESULT_VICTORY)
	assert_false(core.player.barrage_running)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)


func test_player_death_ends_the_barrage() -> void:
	var core: GameCore = _core()
	core.step(_activate())
	var blinks: int = 0
	while blinks < 3:
		core.step(InputFrame.new())
		if find_event(core, GameEvent.LIGHTNING_BLINK) != null:
			blinks += 1
	var events: Array[GameEvent] = []
	core.player.die(core.tick, events)
	var types: Array[StringName] = []
	for event: GameEvent in events:
		types.append(event.type)
	assert_true(types.has(GameEvent.LIGHTNING_BARRAGE_ENDED), "barrage ended on death")
	assert_true(types.find(GameEvent.LIGHTNING_BARRAGE_ENDED) < types.find(GameEvent.ENTITY_DIED), "before entity_died")
	var ended: GameEvent = events[types.find(GameEvent.LIGHTNING_BARRAGE_ENDED)]
	assert_eq(ended.data["reason"], &"death")
	assert_eq(int(ended.data["slashes"]), 3)
	var after: Array[GameEvent] = []
	for i: int in 20:
		core.step(InputFrame.new())
		after.append_array(core.last_events)
	assert_eq(_of(after, GameEvent.LIGHTNING_BLINK).size() + _player_hits(after, core).size(), 0, "no slash after death")
	assert_eq(core.result, GameCore.RESULT_DEFEAT)


func test_no_barrage_when_the_boss_is_dead_and_any_distance_otherwise() -> void:
	var dead: GameCore = _core()
	dead.boss.take_damage(Tuning.BOSS_MAX_HP, 0, [], dead.player.id)
	dead.step(_activate())
	assert_true(find_event(dead, GameEvent.WEAPON_BUFF_STARTED) == null, "the activation is refused on a dead boss")
	assert_true(find_event(dead, GameEvent.LIGHTNING_BARRAGE_STARTED) == null, "no barrage on a dead boss")
	assert_false(dead.player.barrage_running)
	var far: GameCore = _core(Vector2(-350.0, 0.0))
	assert_true(far.player.position.distance_to(BOSS_AT) > 300.0)
	var events: Array[GameEvent] = _run_barrage(far)
	assert_eq(_of(events, GameEvent.LIGHTNING_BLINK).size(), 8, "the barrage runs from any distance")
	assert_eq(_player_hits(events, far).size(), 8)


func test_cost_and_cooldown_unchanged_and_nothing_after_the_barrage() -> void:
	var core: GameCore = _core()
	var events: Array[GameEvent] = _run_barrage(core)
	assert_eq(core.player.buff_cooldown, Tuning.LIGHTNING_FORM_COOLDOWN_TICKS - Weapons.barrage_total_ticks() - 2, "cooldown counted from the activation")
	var started: Array[GameEvent] = _of(events, GameEvent.WEAPON_BUFF_STARTED)
	assert_eq(started.size(), 1)
	assert_eq(int(started[0].data["duration"]), Weapons.barrage_total_ticks())
	var ended: Array[GameEvent] = _of(events, GameEvent.WEAPON_BUFF_ENDED)
	assert_eq(ended.size(), 1, "the form ended")
	if ended.size() == 1:
		assert_eq(ended[0].tick, 1 + Weapons.barrage_total_ticks(), "on the barrage's last tick")
	assert_eq(core.snapshot().player.weapon_form, &"")
	# After the barrage a swing is a plain dagger swing: no blink, normal speed.
	core.player.position = BOSS_AT + Vector2(-100.0, 0.0)
	core.step(input(Vector2.ZERO, false, false, true))
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP)
	assert_true(find_event(core, GameEvent.LIGHTNING_BLINK) == null, "manual swings do not blink")
	assert_near(core.player.swing_speed_mult, 1.0, 0.0001, "no attack speed bonus")


func test_katana_buff_has_no_barrage() -> void:
	var core: GameCore = _core(Vector2(-30.0, 0.0), BOSS_AT, true, Tuning.WEAPON_BLACK_KATANA)
	var events: Array[GameEvent] = _run_barrage(core)
	assert_true(core.player.is_buff_active(), "the katana buff started")
	for type: StringName in [GameEvent.LIGHTNING_BARRAGE_STARTED, GameEvent.LIGHTNING_BARRAGE_ENDED, GameEvent.LIGHTNING_BLINK, GameEvent.LIGHTNING_STRIKE]:
		assert_eq(_of(events, type).size(), 0, "no %s for the katana" % type)
	assert_eq(core.boss.hp, Tuning.BOSS_MAX_HP)
	var fresh: GameCore = _core(Vector2(-30.0, 0.0), BOSS_AT, true, Tuning.WEAPON_BLACK_KATANA)
	fresh.step(_activate())
	assert_eq(fresh.player.state, PlayerState.STATE_IDLE, "still a free action")


## Every barrage spot, with the boss next to walls, corners and props: inside the arena, outside the boss and every
## prop, within the dagger's reach; every slash connects.
func test_spots_respect_walls_props_and_the_boss() -> void:
	var low: float = Tuning.ARENA_MARGIN
	var high: Vector2 = Tuning.ARENA_SIZE - Vector2(low, low)
	var spots: Array[Vector2] = [
		# the forest edge closing the clearing (core/arena_layout.gd BOUNDARY): west gap, east path, north, south, a corner, the east wall
		Vector2(90.0, 222.0), Vector2(728.0, 240.0), Vector2(300.0, 96.0), Vector2(480.0, 396.0),
		Vector2(124.0, 118.0), Vector2(672.0, 300.0), Vector2(152.0, 100.0), Vector2(400.0, 120.0), Vector2(400.0, 395.0),
		Vector2(96.0, 230.0), Vector2(256.0, 112.0),
	]
	var reach: float = Tuning.BOSS_RADIUS + Tuning.ATTACK_RANGE * Tuning.DAGGER_SWING_RANGE_MULT[0]
	for boss_at: Vector2 in spots:
		var core: GameCore = _core(Vector2.ZERO, boss_at, false)
		core.boss.position = core.push_out_of_obstacles(boss_at, Tuning.BOSS_RADIUS).clamp(Vector2(low, low), high)
		core.player.position = core.push_out_of_obstacles(core.boss.position + (Vector2(400.0, 240.0) - core.boss.position).normalized() * 70.0, Tuning.PLAYER_RADIUS)
		var label: String = "boss %s" % str(boss_at)
		var events: Array[GameEvent] = []
		core.step(_activate())
		var sides: Dictionary = {}
		for i: int in Weapons.barrage_total_ticks() + 2:
			core.step(InputFrame.new())
			events.append_array(core.last_events)
			var blink: GameEvent = find_event(core, GameEvent.LIGHTNING_BLINK)
			if blink == null:
				continue
			var to: Vector2 = blink.data["to"]
			sides[int(blink.data["direction_index"])] = true
			assert_true(to.x >= low and to.y >= low and to.x <= high.x and to.y <= high.y, "inside the arena, " + label)
			var dist: float = to.distance_to(core.boss.position)
			assert_true(dist >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.02, "not inside the boss (%.2f), %s" % [dist, label])
			assert_true(dist <= reach + 0.01, "within reach (%.2f), %s" % [dist, label])
			for obstacle: Obstacle in core.obstacles:
				assert_true(to.distance_to(obstacle.center) >= obstacle.radius + Tuning.PLAYER_RADIUS - 0.02, "not inside prop %d, %s" % [obstacle.id, label])
			assert_true(core.player.position.distance_to(to) < 0.01, "nothing moved the player off the spot, " + label)
		assert_eq(_of(events, GameEvent.LIGHTNING_BLINK).size(), 8, "8 blinks, " + label)
		assert_eq(_player_hits(events, core).size(), 8, "8 hits, " + label)
		assert_true(sides.size() >= 2, "more than one side even between a wall and props (%d), %s" % [sides.size(), label])


func test_a_blocked_side_uses_the_nearest_unused_free_side() -> void:
	var core: GameCore = _core(Vector2(100.0, 0.0), Vector2(Tuning.ARENA_MARGIN + 4.0, 240.0))
	var events: Array[GameEvent] = _run_barrage(core)
	var sides: Array[int] = []
	for blink: GameEvent in _of(events, GameEvent.LIGHTNING_BLINK):
		sides.append(int(blink.data["direction_index"]))
	assert_eq(sides.size(), 8)
	# Against the left wall only sides 6, 7, 0, 1, 2 are free (4 is in the wall, 3 and 5 are clamped into the boss).
	# The order [0,3,6,1,4,...] becomes 0, 2 (3 blocked, 4 blocked, 2 free), 6, 1, 7 (4/5/3 blocked, 6 and 2 used).
	for side: int in sides:
		assert_true(side in [6, 7, 0, 1, 2], "only free sides are used: %s" % str(sides))
	var unique: Dictionary = {}
	for side: int in sides.slice(0, 5):
		unique[side] = true
	assert_eq(unique.size(), 5, "the first five slashes use the five free sides once each: %s" % str(sides))
	assert_eq(sides.slice(0, 5), [0, 2, 6, 1, 7] as Array[int], "nearest unused free side")
	assert_eq(_player_hits(events, core).size(), 8)


func _trace(seed_value: int) -> Array[String]:
	var core: GameCore = GameCore.new(seed_value)
	core.player.weapon_id = Tuning.WEAPON_DUAL_DAGGER
	var lines: Array[String] = []
	for i: int in 900:
		core.player.hp = Tuning.PLAYER_MAX_HP
		core.boss.hp = Tuning.BOSS_MAX_HP
		if not core.player.is_buff_active():
			core.player.buff_cooldown = 0
			core.player.edge = 100.0
		var frame: InputFrame = InputFrame.new()
		var to_boss: Vector2 = core.boss.position - core.player.position
		frame.move = to_boss.normalized() if i % 300 < 150 else Vector2.LEFT.rotated(float(i) / 40.0)
		frame.aim = to_boss.normalized()
		frame.attack_pressed = i % 3 == 0
		frame.weapon_active_pressed = i % 120 == 5
		frame.dash_pressed = i % 97 == 11
		core.step(frame)
		lines.append("%d %s %s %d %d %s %s" % [core.tick, str(core.player.position), core.player.state, core.player.hp, core.boss.hp, str(core.boss.position), str(event_types(core))])
	return lines


func test_deterministic() -> void:
	var a: Array[String] = _trace(5)
	var b: Array[String] = _trace(5)
	var first_diff: int = -1
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			first_diff = i
			break
	assert_eq(first_diff, -1, "the runs diverged at step %d" % first_diff)
	assert_true("\n".join(a).contains(String(GameEvent.LIGHTNING_BARRAGE_ENDED)), "the run used the barrage")
