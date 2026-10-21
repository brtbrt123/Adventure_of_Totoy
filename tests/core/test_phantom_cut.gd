extends "res://tests/test_case.gd"
## Phantom Cut (aspect, 2026-10-21): a free-action buff. While it runs every normal swing that connects queues a
## phantom echo that lands PHANTOM_CUT_DELAY_TICKS later for PHANTOM_CUT_DAMAGE_MULT of the swing.

const Aspects := preload("res://core/aspects.gd")
const Weapons := preload("res://core/weapons.gd")

const BOSS_AT: Vector2 = Vector2(400.0, 240.0)


## A pinned boss right in front of the player (in every weapon's reach), full Edge, Phantom Cut in slot 3.
func _core(weapon: StringName = Tuning.WEAPON_BLACK_KATANA, seed_value: int = 1) -> GameCore:
	var core: GameCore = GameCore.new(seed_value)
	core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = BOSS_AT
	core.player.position = BOSS_AT + Vector2(-30.0, 0.0)
	core.player.facing = Vector2.RIGHT
	core.player.edge = 100.0
	core.player.weapon_id = weapon
	var equip: InputFrame = InputFrame.new()
	equip.aspect_equip = Aspects.PHANTOM_CUT
	equip.aspect_equip_slot = 3
	core.step(equip)
	assert_eq(core.player.equipped_aspects[2], Aspects.PHANTOM_CUT)
	return core


## Step with idle input until core.tick == target, but never past the end of the fight (a finished fight no longer
## advances core.tick, so the shared run_to_tick would never return if a broken rule ended it early).
func _to(core: GameCore, target: int) -> void:
	while core.tick < target and core.result == GameCore.RESULT_PLAYING:
		core.step(InputFrame.new())


func _activate(core: GameCore) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 3
	core.step(frame)


func _attack() -> InputFrame:
	return input(Vector2.ZERO, false, false, true)


func _events_of(core: GameCore, type: StringName) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event: GameEvent in core.last_events:
		if event.type == type:
			found.append(event)
	return found


## The swing attack_hit of this tick (not an echo), or null.
func _swing_hit(core: GameCore) -> GameEvent:
	for event: GameEvent in _events_of(core, GameEvent.ATTACK_HIT):
		if event.data.has("combo_index") and not event.data.get("echo", false):
			return event
	return null


func _echo_hit(core: GameCore) -> GameEvent:
	for event: GameEvent in _events_of(core, GameEvent.ATTACK_HIT):
		if event.data.get("echo", false):
			return event
	return null


## Press attack and step until that swing connects. Returns the hit tick, or -1 after `limit` ticks.
func _swing_until_hit(core: GameCore, limit: int = 40) -> int:
	core.step(_attack())
	for i: int in limit:
		if _swing_hit(core) != null:
			return core.tick
		core.step(InputFrame.new())
	return -1


func test_activation_is_a_free_action_with_a_cost_and_a_cooldown() -> void:
	var core: GameCore = _core()
	_activate(core)
	var started: GameEvent = find_event(core, GameEvent.PHANTOM_CUT_STARTED)
	assert_true(started != null, "phantom_cut_started")
	if started != null:
		assert_eq(started.data["duration"], Tuning.PHANTOM_CUT_DURATION_TICKS)
		assert_eq(started.data["entity_id"], core.player.id)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "no state change")
	assert_true(find_event(core, GameEvent.SKILL_STARTED) == null, "not a skill action")
	assert_near(core.player.edge, 100.0 - Tuning.PHANTOM_CUT_EDGE_COST, 0.001)
	assert_eq(core.player.phantom_ticks_left, Tuning.PHANTOM_CUT_DURATION_TICKS)
	assert_eq(int(core.player.aspect_cooldowns[Aspects.PHANTOM_CUT]), Tuning.PHANTOM_CUT_COOLDOWN_TICKS)
	assert_eq(core.snapshot().player.phantom_ticks_left, Tuning.PHANTOM_CUT_DURATION_TICKS)
	var mid: GameCore = _core()
	mid.step(_attack())
	mid.step(InputFrame.new())
	assert_eq(mid.player.state, PlayerState.STATE_ATTACK_WINDUP)
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 3
	mid.step(frame)
	assert_true(mid.player.phantom_ticks_left > 0, "works mid-swing")
	assert_true(String(mid.player.state).begins_with("attack_"), "and the swing goes on")


func test_refused_without_edge_while_running_and_on_cooldown() -> void:
	var poor: GameCore = _core()
	poor.player.edge = Tuning.PHANTOM_CUT_EDGE_COST - 1.0
	_activate(poor)
	assert_eq(poor.player.phantom_ticks_left, 0, "not enough Edge")
	assert_true(find_event(poor, GameEvent.PHANTOM_CUT_STARTED) == null)
	var core: GameCore = _core()
	_activate(core)
	var start: int = core.tick
	run(core, 10)
	core.player.edge = 100.0
	_activate(core)
	assert_true(find_event(core, GameEvent.PHANTOM_CUT_STARTED) == null, "no refresh while it runs")
	assert_eq(core.player.phantom_ticks_left, Tuning.PHANTOM_CUT_DURATION_TICKS - 11)
	assert_near(core.player.edge, 100.0, 0.001, "nothing spent")
	_to(core, start + Tuning.PHANTOM_CUT_DURATION_TICKS)
	var ended: GameEvent = find_event(core, GameEvent.PHANTOM_CUT_ENDED)
	assert_true(ended != null and ended.data["reason"] == &"expired", "ends on the tick after its last one")
	assert_eq(core.player.phantom_ticks_left, 0)
	_to(core, start + Tuning.PHANTOM_CUT_COOLDOWN_TICKS - 2)
	_activate(core)
	assert_eq(core.player.phantom_ticks_left, 0, "still on cooldown one tick early")
	_activate(core)
	assert_eq(core.tick, start + Tuning.PHANTOM_CUT_COOLDOWN_TICKS)
	assert_eq(core.player.phantom_ticks_left, Tuning.PHANTOM_CUT_DURATION_TICKS, "ready again (cooldown from the activation)")
	assert_eq(Tuning.PHANTOM_CUT_EDGE_COST, 40.0)
	assert_eq(Tuning.PHANTOM_CUT_COOLDOWN_TICKS, 1200)


func test_a_connecting_swing_echoes_exactly_after_the_delay() -> void:
	var core: GameCore = _core()
	_activate(core)
	var hit_tick: int = _swing_until_hit(core)
	assert_true(hit_tick > 0, "the swing connects")
	assert_eq(core.phantom_echoes.size(), 1, "one echo queued")
	assert_eq(core.snapshot().player.phantom_pending_echoes, 1)
	var swing_damage: int = _swing_hit(core).data["damage"]
	for i: int in Tuning.PHANTOM_CUT_DELAY_TICKS - 1:
		core.step(InputFrame.new())
		assert_true(find_event(core, GameEvent.PHANTOM_ECHO) == null, "not before the delay (tick %d)" % core.tick)
	var hp_before: int = core.boss.hp
	core.step(InputFrame.new())
	assert_eq(core.tick, hit_tick + Tuning.PHANTOM_CUT_DELAY_TICKS)
	var echo: GameEvent = find_event(core, GameEvent.PHANTOM_ECHO)
	assert_true(echo != null, "the echo lands on hit + delay")
	var expected: int = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.SWING_DAMAGE_MULT[0] * Tuning.PHANTOM_CUT_DAMAGE_MULT * Tuning.ARMOR_DAMAGE_FACTOR))
	if echo != null:
		assert_eq(echo.data["damage"], expected, "0.6 of the swing under the armor rule")
		assert_eq(echo.data["swing_combo_index"], 1)
		assert_eq(echo.data["weapon_id"], Tuning.WEAPON_BLACK_KATANA)
		assert_eq(echo.data["target_id"], core.boss.id)
		assert_eq(echo.data["position"], core.boss.position)
	var hit: GameEvent = _echo_hit(core)
	assert_true(hit != null, "an attack_hit with echo true")
	if hit != null:
		assert_eq(hit.data["damage"], expected)
		assert_false(hit.data.has("combo_index"), "not mistaken for a swing")
	assert_eq(hp_before - core.boss.hp, expected, "the boss loses the echo's damage")
	assert_true(swing_damage >= expected, "the echo is weaker than the swing")
	assert_eq(core.phantom_echoes.size(), 0)


func test_a_whiff_spawns_no_echo() -> void:
	var core: GameCore = _core()
	core.player.position = BOSS_AT + Vector2(-120.0, 0.0)
	_activate(core)
	assert_eq(_swing_until_hit(core, 30), -1, "the swing whiffs")
	assert_eq(core.phantom_echoes.size(), 0, "nothing queued")
	run(core, 30)
	assert_true(find_event(core, GameEvent.PHANTOM_ECHO) == null)
	var behind: GameCore = _core()
	behind.player.facing = Vector2.LEFT
	_activate(behind)
	var frame: InputFrame = _attack()
	frame.aim = Vector2.LEFT
	behind.step(frame)
	run(behind, 30, InputFrame.new())
	assert_eq(behind.phantom_echoes.size(), 0, "out of the arc: no echo")


func test_echo_damage_matches_each_swing_of_the_combo_and_every_swing_gets_one() -> void:
	var core: GameCore = _core()
	core.boss.hp = 10000
	_activate(core)
	var swings: Array[int] = []
	var echoes: Array[int] = []
	var echo_damage: Array[int] = []
	for i: int in 120:
		core.step(_attack())
		var hit: GameEvent = _swing_hit(core)
		if hit != null:
			swings.append(hit.data["combo_index"])
		var echo: GameEvent = find_event(core, GameEvent.PHANTOM_ECHO)
		if echo != null:
			echoes.append(echo.data["swing_combo_index"])
			echo_damage.append(echo.data["damage"])
	assert_true(swings.size() >= 5, "several swings in 2 s (%d)" % swings.size())
	var pending: int = core.phantom_echoes.size()
	assert_eq(echoes.size() + pending, swings.size(), "one echo per connecting swing")
	for k: int in echoes.size():
		assert_eq(echoes[k], swings[k], "echo %d belongs to swing %d" % [k, swings[k]])
		var base: float = Tuning.ATTACK_DAMAGE * Tuning.SWING_DAMAGE_MULT[swings[k] - 1] * Tuning.PHANTOM_CUT_DAMAGE_MULT
		assert_eq(echo_damage[k], maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR)), "echo damage of swing %d" % swings[k])


func test_a_counter_echo_uses_the_counter_rule_without_edge() -> void:
	var core: GameCore = _core()
	core.boss.hp = 10000
	_activate(core)
	var hit_tick: int = _swing_until_hit(core)
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, core.tick, [] as Array[GameEvent])
	assert_eq(core.boss.state, BossState.STATE_BROKEN)
	core.player.edge = 50.0
	_to(core, hit_tick + Tuning.PHANTOM_CUT_DELAY_TICKS)
	var echo: GameEvent = find_event(core, GameEvent.PHANTOM_ECHO)
	assert_true(echo != null)
	if echo != null:
		assert_eq(echo.data["kind"], &"counter")
		assert_eq(echo.data["damage"], roundi(Tuning.ATTACK_DAMAGE * Tuning.PHANTOM_CUT_DAMAGE_MULT * Tuning.COUNTER_DAMAGE_MULT), "x4, no Edge bonus")
	assert_near(core.player.edge, 50.0, 0.001, "a counter echo does not spend Edge")


func test_an_echo_gains_no_edge_and_changes_no_combo_state() -> void:
	var core: GameCore = _core()
	var control: GameCore = _core()  # the same swings without Phantom Cut
	core.boss.hp = 10000
	control.boss.hp = 10000
	_activate(core)
	control.step(InputFrame.new())
	core.player.edge = 0.0
	control.player.edge = 0.0
	var hit_tick: int = _swing_until_hit(core)
	_swing_until_hit(control)
	for i: int in Tuning.PHANTOM_CUT_DELAY_TICKS + 20:
		var edge: float = core.player.edge
		var posture: float = core.boss.posture
		var frame: InputFrame = _attack() if i % 5 == 0 else InputFrame.new()
		core.step(frame)
		control.step(frame)
		assert_eq(core.player.combo_index, control.player.combo_index, "combo untouched (tick %d)" % core.tick)
		assert_eq(core.player.state, control.player.state, "state untouched (tick %d)" % core.tick)
		assert_eq(core.player.state_ticks, control.player.state_ticks)
		assert_eq(core.player.attack_hit_done, control.player.attack_hit_done, "one-hit-per-swing flag untouched")
		assert_near(core.player.edge, control.player.edge, 0.001, "Edge identical (tick %d)" % core.tick)
		if core.tick == hit_tick + Tuning.PHANTOM_CUT_DELAY_TICKS:
			assert_true(find_event(core, GameEvent.PHANTOM_ECHO) != null)
			assert_true(_swing_hit(core) == null, "the test needs a tick without a real hit")
			assert_near(core.player.edge, edge, 0.001, "no Edge gain on the echo tick")
			assert_near(core.boss.posture, posture + Tuning.NORMAL_HIT_POSTURE * Tuning.PHANTOM_CUT_POSTURE_MULT, 0.05, "posture x0.6 of the swing's")


func test_the_dagger_finisher_echo_calls_no_second_lightning_strike() -> void:
	var core: GameCore = _core(Tuning.WEAPON_DUAL_DAGGER)
	core.boss.hp = 10000
	_activate(core)
	var strikes: int = 0
	var echoes: Array[int] = []
	var finisher_tick: int = -1
	for i: int in 90:
		core.step(_attack())
		strikes += _events_of(core, GameEvent.LIGHTNING_STRIKE).size()
		var hit: GameEvent = _swing_hit(core)
		if hit != null and hit.data["combo_index"] == Tuning.DAGGER_COMBO_MAX and finisher_tick < 0:
			finisher_tick = core.tick
		var echo: GameEvent = find_event(core, GameEvent.PHANTOM_ECHO)
		if echo != null:
			echoes.append(echo.data["swing_combo_index"])
			if echo.data["swing_combo_index"] == Tuning.DAGGER_COMBO_MAX:
				assert_true(find_event(core, GameEvent.LIGHTNING_STRIKE) == null, "no bolt on the finisher's echo")
				assert_eq(echo.data["weapon_id"], Tuning.WEAPON_DUAL_DAGGER)
	assert_true(finisher_tick > 0, "the finisher connected")
	assert_true(echoes.has(Tuning.DAGGER_COMBO_MAX), "and was echoed")
	var finishers: int = 0
	for hit_index: int in echoes:
		if hit_index == Tuning.DAGGER_COMBO_MAX:
			finishers += 1
	assert_true(strikes >= finishers, "one bolt per real finisher")
	var real_finishers: int = 0
	# Count the real finishers again from a fresh run to compare bolts one to one.
	var again: GameCore = _core(Tuning.WEAPON_DUAL_DAGGER)
	again.boss.hp = 10000
	for i: int in 90:
		again.step(_attack())
		var hit: GameEvent = _swing_hit(again)
		if hit != null and hit.data["combo_index"] == Tuning.DAGGER_COMBO_MAX:
			real_finishers += 1
	assert_eq(strikes, real_finishers, "the same number of bolts with and without Phantom Cut")


func test_works_with_every_weapon() -> void:
	for weapon: StringName in Weapons.IDS:
		var core: GameCore = _core(weapon)
		_activate(core)
		var hit_tick: int = _swing_until_hit(core)
		assert_true(hit_tick > 0, "the %s swing connects" % weapon)
		_to(core, hit_tick + Tuning.PHANTOM_CUT_DELAY_TICKS)
		var echo: GameEvent = find_event(core, GameEvent.PHANTOM_ECHO)
		assert_true(echo != null, "echo with " + String(weapon))
		if echo != null:
			assert_eq(echo.data["weapon_id"], weapon)
			var base: float = Tuning.ATTACK_DAMAGE * Weapons.damage_mults(weapon)[0] * Tuning.PHANTOM_CUT_DAMAGE_MULT
			assert_eq(echo.data["damage"], maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR)), "damage with " + String(weapon))


func test_the_echo_needs_no_range_and_lands_where_the_boss_is_then() -> void:
	var core: GameCore = _core()
	_activate(core)
	var hit_tick: int = _swing_until_hit(core)
	core.boss.position = BOSS_AT + Vector2(150.0, 60.0)  # the boss is far away when the echo lands
	_to(core, hit_tick + Tuning.PHANTOM_CUT_DELAY_TICKS)
	var echo: GameEvent = find_event(core, GameEvent.PHANTOM_ECHO)
	assert_true(echo != null, "the phantom steps in")
	if echo != null:
		assert_eq(echo.data["position"], core.boss.position)


func test_skills_and_weapon_actives_are_not_echoed() -> void:
	var core: GameCore = _core(Tuning.WEAPON_DUAL_DAGGER)
	core.boss.hp = 10000
	_activate(core)
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	core.step(active)
	assert_eq(core.player.state, PlayerState.STATE_LIGHTNING_BARRAGE)
	run(core, Weapons.barrage_total_ticks() + Tuning.PHANTOM_CUT_DELAY_TICKS + 2)
	assert_eq(core.phantom_echoes.size(), 0, "no echo from barrage slashes")
	var gale: GameCore = _core()
	gale.boss.hp = 10000
	_activate(gale)
	gale.player.position = BOSS_AT + Vector2(-60.0, 0.0)
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 2
	frame.move = Vector2.RIGHT
	gale.step(frame)
	var skill_hits: int = 0
	for i: int in 50:
		gale.step(InputFrame.new())
		for event: GameEvent in _events_of(gale, GameEvent.ATTACK_HIT):
			if event.data.has("skill_id"):
				skill_hits += 1
		assert_true(find_event(gale, GameEvent.PHANTOM_ECHO) == null, "no echo from Gale Cut")
	assert_eq(skill_hits, 1, "Gale Cut hit")


func test_boss_death_drops_pending_echoes_safely() -> void:
	var core: GameCore = _core()
	_activate(core)
	var hit_tick: int = _swing_until_hit(core)
	assert_eq(core.phantom_echoes.size(), 1)
	var events: Array[GameEvent] = []
	core.boss.take_damage(core.boss.hp, core.tick, events, core.player.id)
	core.step(InputFrame.new())
	assert_eq(core.phantom_echoes.size(), 0, "dropped")
	assert_eq(core.result, GameCore.RESULT_VICTORY)
	run(core, Tuning.PHANTOM_CUT_DELAY_TICKS + 2)  # the fight is over: steps only count result_ticks
	assert_true(core.tick < hit_tick + Tuning.PHANTOM_CUT_DELAY_TICKS, "frozen before the echo's tick")
	assert_eq(core.snapshot().player.phantom_pending_echoes, 0)
	var last: GameCore = _core()
	_activate(last)
	var t: int = _swing_until_hit(last)
	last.boss.hp = 1
	_to(last, t + Tuning.PHANTOM_CUT_DELAY_TICKS)
	assert_true(find_event(last, GameEvent.PHANTOM_ECHO) != null, "an echo can finish the boss")
	assert_eq(last.boss.state, BossState.STATE_DEAD)
	assert_eq(last.result, GameCore.RESULT_VICTORY)


func test_expiry_stops_new_echoes_but_queued_ones_still_land() -> void:
	var core: GameCore = _core()
	core.boss.hp = 10000
	_activate(core)
	core.player.phantom_ticks_left = Tuning.ATTACK_WINDUP_TICKS + 3  # shortened for the test: expires after the hit
	var hit_tick: int = _swing_until_hit(core)
	assert_eq(core.phantom_echoes.size(), 1)
	var ended_tick: int = -1
	var echo_tick: int = -1
	for i: int in Tuning.PHANTOM_CUT_DELAY_TICKS + 2:
		core.step(InputFrame.new())
		if find_event(core, GameEvent.PHANTOM_CUT_ENDED) != null:
			ended_tick = core.tick
		if find_event(core, GameEvent.PHANTOM_ECHO) != null:
			echo_tick = core.tick
	assert_true(ended_tick > hit_tick and ended_tick < echo_tick, "the buff ended before the echo landed")
	assert_eq(echo_tick, hit_tick + Tuning.PHANTOM_CUT_DELAY_TICKS, "the queued echo still lands on time")
	run(core, 20)
	var later: int = _swing_until_hit(core)
	assert_true(later > 0)
	assert_eq(core.phantom_echoes.size(), 0, "no new echo after the buff")


func test_death_ends_it_and_drops_the_queue() -> void:
	var core: GameCore = _core()
	_activate(core)
	_swing_until_hit(core)
	assert_eq(core.phantom_echoes.size(), 1)
	var events: Array[GameEvent] = []
	core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, events, core.boss.id)
	var ended: GameEvent = null
	for event: GameEvent in events:
		if event.type == GameEvent.PHANTOM_CUT_ENDED:
			ended = event
	assert_true(ended != null and ended.data["reason"] == &"death", "ended: death")
	assert_eq(core.player.phantom_ticks_left, 0)
	core.step(InputFrame.new())
	assert_eq(core.phantom_echoes.size(), 0)
	assert_true(find_event(core, GameEvent.PHANTOM_ECHO) == null)


func _scripted(seed_value: int) -> Array[String]:
	var core: GameCore = _core(Tuning.WEAPON_BLACK_KATANA, seed_value)
	core.boss.state = BossState.STATE_IDLE
	core.boss._recover_ticks = 0
	core.boss.cooldown = 30
	var lines: Array[String] = []
	for i: int in 600:
		var frame: InputFrame = InputFrame.new()
		frame.attack_pressed = i % 3 == 0
		frame.skill_pressed = 3 if i % 97 == 0 else 0
		frame.move = Vector2.RIGHT.rotated(float(i) * 0.05) if i % 40 < 10 else Vector2.ZERO
		core.player.edge = maxf(core.player.edge, 45.0) if i % 97 == 0 else core.player.edge
		core.step(frame)
		for event: GameEvent in core.last_events:
			lines.append("%d %s %s" % [event.tick, event.type, str(event.data)])
		if core.result != GameCore.RESULT_PLAYING:
			break
	return lines


func test_two_identical_runs_give_identical_events() -> void:
	var a: Array[String] = _scripted(7)
	var b: Array[String] = _scripted(7)
	assert_eq(a.size(), b.size(), "same number of events")
	assert_true(a == b, "identical event logs")
	var echoes: int = 0
	for line: String in a:
		if line.contains(String(GameEvent.PHANTOM_ECHO)):
			echoes += 1
	assert_true(echoes > 0, "the run had echoes (%d)" % echoes)


## 3000 ticks of random input with random aspect equips and uses (a new fight when one ends): no crash and the
## invariants hold every tick.
func _soak(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var core: GameCore = GameCore.new(seed_value)
	var stats: Dictionary = {"echoes": 0, "lanterns": 0, "pulses": 0, "phantoms": 0, "equips": 0, "fights": 1, "swing_hits": 0, "swing_hits_in_phantom": 0}
	var started: int = 0
	var ended: int = 0
	for i: int in 3000:
		var calm: bool = i % 200 >= 150  # a calmer stretch (no attacks) so equips find the player idle or walking
		var frame: InputFrame = InputFrame.new()
		frame.move = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		frame.aim = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if not calm and rng.randf() < 0.6:  # mostly press in on the boss, so swings connect
			var to_boss: Vector2 = core.boss.position - core.player.position
			frame.move = to_boss.normalized() if to_boss.length() > 30.0 else Vector2.ZERO
			frame.aim = to_boss.normalized()
		frame.attack_pressed = rng.randf() < (0.0 if calm else 0.3)
		frame.parry_pressed = rng.randf() < (0.0 if calm else 0.05)
		frame.dash_pressed = rng.randf() < (0.0 if calm else 0.03)
		frame.skill_pressed = rng.randi_range(1, 3) if rng.randf() < (0.02 if calm else 0.08) else 0
		frame.weapon_active_pressed = rng.randf() < (0.0 if calm else 0.005)
		if rng.randf() < 0.03:
			frame.weapon_equip = Weapons.IDS[rng.randi_range(0, 2)]
		if rng.randf() < (0.3 if calm else 0.05):
			frame.aspect_equip = Aspects.ALL[rng.randi_range(0, Aspects.ALL.size() - 1)] if rng.randf() < 0.9 else &"nonsense"
			frame.aspect_equip_slot = rng.randi_range(0, 4)
		if rng.randf() < 0.05:
			core.player.edge = 100.0  # test shortcuts: enough Edge for the aspects, and longer fights
		if rng.randf() < 0.01 and core.player.hp > 0:
			core.player.hp = Tuning.PLAYER_MAX_HP
		core.step(frame)
		var echo_events: int = 0
		var echo_hits: int = 0
		for event: GameEvent in core.last_events:
			match event.type:
				GameEvent.PHANTOM_ECHO:
					echo_events += 1
					stats["echoes"] += 1
				GameEvent.ATTACK_HIT:
					if event.data.get("echo", false):
						echo_hits += 1
					elif event.data.has("combo_index"):
						stats["swing_hits"] += 1
						if core.player.phantom_ticks_left > 0:
							stats["swing_hits_in_phantom"] += 1
				GameEvent.LANTERN_PLACED:
					stats["lanterns"] += 1
				GameEvent.LANTERN_PULSE:
					stats["pulses"] += 1
				GameEvent.PHANTOM_CUT_STARTED:
					stats["phantoms"] += 1
					started += 1
				GameEvent.PHANTOM_CUT_ENDED:
					ended += 1
				GameEvent.ASPECT_EQUIPPED:
					stats["equips"] += 1
		assert_eq(echo_events, echo_hits, "every phantom_echo has its attack_hit (tick %d)" % core.tick)
		var slots: Array[StringName] = core.player.equipped_aspects
		assert_true(Aspects.is_valid_loadout(slots), "three different known aspects (tick %d): %s" % [core.tick, str(slots)])
		assert_true(core.lanterns.size() <= 1, "one lantern at most")
		assert_true(core.player.hp >= 0 and core.player.hp <= Tuning.PLAYER_MAX_HP, "hp in range")
		assert_true(core.player.edge >= 0.0 and core.player.edge <= Tuning.EDGE_MAX + 0.0001, "Edge in range")
		assert_true(core.player.phantom_ticks_left >= 0 and core.player.phantom_ticks_left <= Tuning.PHANTOM_CUT_DURATION_TICKS)
		assert_eq(started - ended, 1 if core.player.phantom_ticks_left > 0 else 0, "started/ended balance (tick %d)" % core.tick)
		for echo: Dictionary in core.phantom_echoes:
			assert_true(int(echo["land_tick"]) > core.tick, "no overdue echo")
		if core.result != GameCore.RESULT_PLAYING:
			core = GameCore.new(seed_value + i)
			stats["fights"] += 1
			started = 0
			ended = 0
	return stats


func test_soak_with_random_inputs_and_aspects() -> void:
	var total: Dictionary = {}
	for seed_value: int in [11, 2024]:
		var stats: Dictionary = _soak(seed_value)
		assert_true(stats["equips"] > 10, "aspects were re-slotted (seed %d): %s" % [seed_value, str(stats)])
		for key: String in stats:
			total[key] = int(total.get(key, 0)) + int(stats[key])
	# Coverage over both seeds: the random play really used both new aspects.
	for key: String in ["phantoms", "echoes", "lanterns", "pulses"]:
		assert_true(int(total[key]) > 0, "%s > 0 over both seeds: %s" % [key, str(total)])
