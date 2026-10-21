extends "res://tests/test_case.gd"
## The Chain Scythe (third weapon, 2026-10-20): the 3-weapon swap cycle, the slow wide 3-hit combo and the right-click
## Reaper's Coil (hook, drag, stun, spin; or a pull on a miss).

const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const Obstacle := preload("res://core/obstacle.gd")

const BOSS_AT: Vector2 = Vector2(400.0, 240.0)
const SCYTHE: StringName = &"chain_scythe"


## A pinned boss (it neither walks nor attacks) in an open field, the player `offset` from it facing it, full Edge.
func _core(offset: Vector2 = Vector2(-100.0, 0.0), boss_at: Vector2 = BOSS_AT, clear_props: bool = true, weapon: StringName = SCYTHE) -> GameCore:
	var core: GameCore = GameCore.new()
	if clear_props:
		core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = boss_at
	core.player.position = boss_at + offset
	core.player.facing = -offset.normalized() if offset.length_squared() > 0.0001 else Vector2.RIGHT
	core.player.edge = 100.0
	core.player.weapon_id = weapon
	return core


func _activate(aim: Vector2 = Vector2.ZERO) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_active_pressed = true
	frame.aim = aim
	return frame


## The old Q press: an equip request for the weapon after the one `core`'s player holds (Weapons.IDS order).
func _swap_frame(core: GameCore) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_equip = Weapons.next(core.player.weapon_id)
	return frame


## Step `ticks` ticks (idle input unless `frame`) and return every event, in order.
func _run(core: GameCore, ticks: int, frame: InputFrame = null) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	for i: int in ticks:
		core.step(frame if frame != null else InputFrame.new())
		events.append_array(core.last_events)
	return events


## Activate (aimed at `aim`, else the facing) and step until the coil is over (plus `extra` ticks). Every event.
func _run_coil(core: GameCore, aim: Vector2 = Vector2.ZERO, extra: int = 2) -> Array[GameEvent]:
	core.step(_activate(aim))
	var events: Array[GameEvent] = core.last_events.duplicate()
	var guard: int = 0
	while core.player.coil_running and guard < 400:
		core.step(InputFrame.new())
		events.append_array(core.last_events)
		guard += 1
	events.append_array(_run(core, extra))
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


func _swing_total(weapon: StringName, swing: int) -> int:
	var phases: Array[int] = Weapons.swing_phases(weapon, swing)
	return phases[0] + phases[1] + phases[2]


## Ticks the hook needs to reach a boss whose centre is `dist` px straight ahead.
func _hook_ticks(dist: float) -> int:
	return maxi(1, ceili((dist - Tuning.BOSS_RADIUS - Tuning.REAPER_COIL_CHAIN_WIDTH * 0.5) / Tuning.REAPER_COIL_HOOK_SPEED))


func _drag_goal() -> float:
	return Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS + Tuning.REAPER_COIL_DRAG_GAP


## Ticks the drag needs in the open field from `dist` px.
func _drag_ticks(dist: float) -> int:
	return maxi(1, ceili((dist - _drag_goal()) / Tuning.REAPER_COIL_DRAG_SPEED))


func _arena_ok(p: Vector2, radius: float, core: GameCore) -> String:
	var low: float = Tuning.ARENA_MARGIN
	var high: Vector2 = Tuning.ARENA_SIZE - Vector2(low, low)
	if p.x < low - 0.01 or p.y < low - 0.01 or p.x > high.x + 0.01 or p.y > high.y + 0.01:
		return "outside the arena at %s" % str(p)
	for obstacle: Obstacle in core.obstacles:
		if p.distance_to(obstacle.center) < obstacle.radius + radius - 0.05:
			return "inside prop %d at %s" % [obstacle.id, str(p)]
	return ""


# --- tuning ---

func test_tuning_is_sane() -> void:
	assert_eq(Weapons.IDS, [Tuning.WEAPON_BLACK_KATANA, Tuning.WEAPON_DUAL_DAGGER, SCYTHE] as Array[StringName], "swap order")
	assert_eq(Tuning.WEAPON_CHAIN_SCYTHE, SCYTHE)
	assert_eq(Weapons.combo_max(SCYTHE), 3)
	assert_true(Tuning.SCYTHE_ARC_DOT < Tuning.ATTACK_ARC_DOT - 0.2, "clearly wider than the katana")
	assert_true(Tuning.SCYTHE_ARC_DOT < 0.0, "reaches straight to the sides")
	assert_near(Tuning.ATTACK_RANGE * Tuning.SCYTHE_SWING_RANGE_MULT[0], 34.0, 1.0, "about 1.3x the katana's reach")
	for swing: int in range(1, 4):
		assert_true(_swing_total(SCYTHE, swing) > _swing_total(Tuning.WEAPON_BLACK_KATANA, swing), "scythe swing %d slower than the katana" % swing)
		assert_true(_swing_total(SCYTHE, swing) <= _swing_total(Tuning.WEAPON_BLACK_KATANA, swing) + 6, "but only slightly (swing %d)" % swing)
	assert_true(Weapons.reaper_coil_hook_ticks() >= 10 and Weapons.reaper_coil_hook_ticks() <= 14, "hook about 10-14 ticks")
	var spin_last: int = Weapons.reaper_coil_spin_hit_tick(Tuning.REAPER_COIL_SPIN_HITS)
	assert_true(spin_last <= Tuning.REAPER_COIL_SPIN_TICKS, "every spin hit lands inside the spin")
	assert_true(Tuning.REAPER_COIL_STAGGER_TICKS > Tuning.REAPER_COIL_SPIN_TICKS + Tuning.REAPER_COIL_RECOVERY_TICKS, "the boss is still stunned when the player can act again")
	assert_eq(Weapons.active_duration(SCYTHE), Weapons.reaper_coil_total_ticks())
	assert_eq(Weapons.active_cooldown(SCYTHE), 600)
	assert_near(Weapons.active_edge_cost(SCYTHE), 50.0, 0.0001)
	assert_eq(Weapons.active_form(SCYTHE), Weapons.FORM_REAPER_COIL)


# --- swap ---

func test_swap_cycles_katana_dagger_scythe_and_back() -> void:
	var core: GameCore = _core()
	core.player.weapon_id = Tuning.WEAPON_BLACK_KATANA
	var order: Array[StringName] = [Tuning.WEAPON_DUAL_DAGGER, SCYTHE, Tuning.WEAPON_BLACK_KATANA, Tuning.WEAPON_DUAL_DAGGER]
	var previous: StringName = Tuning.WEAPON_BLACK_KATANA
	for expected: StringName in order:
		core.step(_swap_frame(core))
		assert_eq(core.player.weapon_id, expected, "swap to " + String(expected))
		var swapped: GameEvent = find_event(core, GameEvent.WEAPON_SWAPPED)
		assert_true(swapped != null, "weapon_swapped for " + String(expected))
		if swapped != null:
			assert_eq(swapped.data["weapon_id"], expected)
			assert_eq(swapped.data["previous_weapon_id"], previous)
		assert_eq(core.snapshot().player.combo_max, Weapons.combo_max(expected))
		previous = expected
		# the lockout still blocks the next press for WEAPON_SWAP_LOCKOUT_TICKS - 1 ticks
		for i: int in Tuning.WEAPON_SWAP_LOCKOUT_TICKS - 1:
			core.step(_swap_frame(core))
			assert_eq(core.player.weapon_id, expected, "locked out after the swap to " + String(expected))
			assert_true(find_event(core, GameEvent.WEAPON_SWAPPED) == null)


func test_swap_refusals_are_unchanged_with_the_scythe() -> void:
	for setup: String in ["attack", "dash", "parry", "skill", "dead", "coil"]:
		var core: GameCore = _core(Vector2(-100.0, 0.0))
		match setup:
			"attack":
				core.step(input(Vector2.ZERO, false, false, true))
			"dash":
				core.step(input(Vector2.UP, true))
			"parry":
				core.step(input(Vector2.ZERO, false, true))
			"skill":
				var frame: InputFrame = InputFrame.new()
				frame.skill_pressed = 2
				frame.move = Vector2.UP
				core.step(frame)
			"dead":
				core.player.take_damage(Tuning.PLAYER_MAX_HP, core.tick, [], core.boss.id)
			"coil":
				core.step(_activate())
		core.step(_swap_frame(core))
		assert_eq(core.player.weapon_id, SCYTHE, "no swap during " + setup)
		assert_true(find_event(core, GameEvent.WEAPON_SWAPPED) == null, "no event during " + setup)
	# During the whole coil the swap is refused, the tick after it ends it is allowed.
	var coil: GameCore = _core()
	coil.step(_activate())
	var refused: int = 0
	while coil.player.coil_running and refused < 400:
		coil.step(_swap_frame(coil))
		if coil.player.coil_running:
			assert_eq(coil.player.weapon_id, SCYTHE, "refused during the coil (tick %d)" % coil.tick)
			refused += 1
	assert_eq(coil.player.weapon_id, SCYTHE, "not on the tick the coil ends (the press came first)")
	coil.step(_swap_frame(coil))
	assert_eq(coil.player.weapon_id, Tuning.WEAPON_BLACK_KATANA, "allowed right after the coil")


func test_three_weapons_keep_their_own_cooldowns() -> void:
	var core: GameCore = _core(Vector2(-100.0, 0.0), BOSS_AT, true, Tuning.WEAPON_DUAL_DAGGER)
	core.step(_activate())  # Lightning Barrage
	var dagger_at: int = core.tick
	while core.player.barrage_running:
		core.step(InputFrame.new())
	core.step(_swap_frame(core))  # -> scythe
	assert_eq(core.player.weapon_id, SCYTHE)
	assert_eq(core.snapshot().hud.weapon_buff_cooldown_ticks, 0, "the scythe's own cooldown: ready")
	core.player.edge = 100.0
	core.player.position = core.boss.position + Vector2(-100.0, 0.0)
	core.step(_activate(Vector2.RIGHT))
	var scythe_at: int = core.tick
	assert_true(core.player.coil_running, "the coil started")
	while core.player.coil_running:
		core.step(InputFrame.new())
	core.step(_swap_frame(core))  # -> katana
	assert_eq(core.player.weapon_id, Tuning.WEAPON_BLACK_KATANA)
	core.player.edge = 100.0
	core.step(_activate())
	var katana_at: int = core.tick
	assert_true(core.player.is_buff_active(), "katana buff")
	run(core, 30)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	var now: int = core.tick
	assert_eq(snap.hud.weapon_cooldowns[Tuning.WEAPON_DUAL_DAGGER], Tuning.LIGHTNING_FORM_COOLDOWN_TICKS - (now - dagger_at), "dagger counts from its activation")
	assert_eq(snap.hud.weapon_cooldowns[SCYTHE], Tuning.REAPER_COIL_COOLDOWN_TICKS - (now - scythe_at), "scythe counts from its activation")
	assert_eq(snap.hud.weapon_cooldowns[Tuning.WEAPON_BLACK_KATANA], Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS - (now - katana_at), "katana counts from its activation")
	assert_eq(snap.hud.weapon_cooldowns.size(), 3, "every weapon listed")
	assert_eq(snap.hud.weapon_buff_cooldown_max, Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS, "HUD shows the equipped weapon")


# --- the scythe combo ---

func test_scythe_swing_timings_follow_tuning() -> void:
	for swing: int in Tuning.SCYTHE_COMBO_MAX:
		var core: GameCore = _core(Vector2(-30.0, 0.0))
		core.player._start_swing(swing + 1)
		var label: String = "scythe swing %d" % (swing + 1)
		run(core, Tuning.SCYTHE_SWING_WINDUP_TICKS[swing] - 1)
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP, "still winding up, " + label)
		core.step(input())
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_ACTIVE, "active after the windup, " + label)
		run(core, Tuning.SCYTHE_SWING_ACTIVE_TICKS[swing])
		assert_eq(core.player.state, PlayerState.STATE_ATTACK_RECOVERY, "recovery after the active ticks, " + label)
		run(core, Tuning.SCYTHE_SWING_RECOVERY_TICKS[swing])
		assert_eq(core.player.state, PlayerState.STATE_IDLE, "idle after the recovery, " + label)


func test_scythe_combo_chains_three_swings_then_starts_over() -> void:
	var core: GameCore = _core(Vector2(-30.0, 0.0))
	var order: Array[int] = []
	for i: int in 200:
		core.step(input(Vector2.ZERO, false, false, true))
		if core.player.state == PlayerState.STATE_ATTACK_WINDUP and core.player.state_ticks == 0:
			order.append(core.player.combo_index)
	assert_true(order.size() >= 5, "several swings, got %s" % str(order))
	if order.size() >= 5:
		assert_eq(order.slice(0, 5), [1, 2, 3, 1, 2] as Array[int])
	assert_eq(order.max(), 3, "never past swing 3")


## Swing `swing` with `weapon` against a pinned boss at `offset`, facing `facing`: the attack_hit events.
func _swing_hits(weapon: StringName, swing: int, offset: Vector2, facing: Vector2) -> Array[GameEvent]:
	var core: GameCore = _core(offset, BOSS_AT, true, weapon)
	core.player.facing = facing
	core.player._start_swing(swing)
	return _of(_run(core, _swing_total(weapon, swing) + 2), GameEvent.ATTACK_HIT)


func test_scythe_reaches_farther_than_the_katana() -> void:
	# boss edge 30 px away: the katana (26) whiffs, the scythe (33.8) hits
	assert_eq(_swing_hits(Tuning.WEAPON_BLACK_KATANA, 1, Vector2(-50.0, 0.0), Vector2.RIGHT).size(), 0, "katana whiffs at 30 px")
	assert_eq(_swing_hits(SCYTHE, 1, Vector2(-50.0, 0.0), Vector2.RIGHT).size(), 1, "scythe hits at 30 px")
	assert_eq(_swing_hits(SCYTHE, 1, Vector2(-56.0, 0.0), Vector2.RIGHT).size(), 0, "but not at 36 px")
	assert_eq(_swing_hits(SCYTHE, 3, Vector2(-56.0, 0.0), Vector2.RIGHT).size(), 1, "the finisher reaches 36.4 px")


func test_scythe_arc_is_wider_than_the_katana() -> void:
	# The boss straight to the side (90 degrees off the facing): the katana whiffs, the scythe hits.
	var side: Vector2 = Vector2(0.0, 30.0)  # player below the boss, facing right: the boss is straight up
	assert_eq(_swing_hits(Tuning.WEAPON_BLACK_KATANA, 1, side, Vector2.RIGHT).size(), 0, "katana whiffs to the side")
	assert_eq(_swing_hits(SCYTHE, 1, side, Vector2.RIGHT).size(), 1, "scythe hits to the side")
	# 70 degrees off: both hit (control); behind the player: neither.
	var seventy: Vector2 = -Vector2.RIGHT.rotated(deg_to_rad(-70.0)) * 30.0
	assert_eq(_swing_hits(Tuning.WEAPON_BLACK_KATANA, 1, seventy, Vector2.RIGHT).size(), 1, "katana hits at 70 degrees")
	assert_eq(_swing_hits(SCYTHE, 1, seventy, Vector2.RIGHT).size(), 1, "scythe hits at 70 degrees")
	assert_eq(_swing_hits(SCYTHE, 1, Vector2(30.0, 0.0), Vector2.RIGHT).size(), 0, "scythe does not hit behind")
	assert_eq(_swing_hits(SCYTHE, 1, Vector2(-30.0, 0.0).rotated(deg_to_rad(110.0)), Vector2.RIGHT).size(), 0, "nor 110 degrees off")


func test_scythe_damage_posture_and_edge() -> void:
	var damages: Array[int] = []
	for swing: int in range(1, 4):
		var core: GameCore = _core(Vector2(-30.0, 0.0))
		core.player.edge = 0.0
		core.player._start_swing(swing)
		var hits: Array[GameEvent] = _of(_run(core, _swing_total(SCYTHE, swing)), GameEvent.ATTACK_HIT)
		assert_eq(hits.size(), 1, "swing %d hits once" % swing)
		if hits.size() != 1:
			return
		var expected: int = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.SCYTHE_SWING_DAMAGE_MULT[swing - 1] * Tuning.ARMOR_DAMAGE_FACTOR))
		assert_eq(int(hits[0].data["damage"]), expected, "armored scythe swing %d" % swing)
		assert_eq(hits[0].data["weapon_id"], SCYTHE)
		assert_eq(int(hits[0].data["combo_index"]), swing)
		damages.append(expected)
		assert_near(core.boss.posture, Tuning.SCYTHE_SWING_POSTURE[swing - 1], Tuning.BOSS_POSTURE_DECAY * 30.0, "posture of swing %d (less decay)" % swing)
		assert_near(core.player.edge, Tuning.SCYTHE_EDGE_PER_HIT, 0.0001, "Edge like the katana")
	assert_true(damages[2] > damages[0], "the third swing is the biggest")
	assert_true(Tuning.SCYTHE_SWING_POSTURE[2] > Tuning.SCYTHE_SWING_POSTURE[0] and Tuning.SCYTHE_SWING_POSTURE[0] > Tuning.NORMAL_HIT_POSTURE, "heavy posture")
	# Counters (raw multipliers are visible here): scythe 1 = katana 1 < scythe 2 < scythe 3, and every scythe hit beats a dagger hit.
	var counter: Array[int] = []
	for swing: int in range(1, 4):
		var core: GameCore = _core(Vector2(-30.0, 0.0))
		core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 0, [])
		core.player.edge = 0.0
		core.player._start_swing(swing)
		var hits: Array[GameEvent] = _of(_run(core, _swing_total(SCYTHE, swing)), GameEvent.ATTACK_HIT)
		counter.append(int(hits[0].data["damage"]) if hits.size() == 1 else -1)
	assert_eq(counter[0], roundi(Tuning.ATTACK_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "swing 1 counter like the katana's")
	assert_true(counter[0] < counter[1] and counter[1] < counter[2], "counter damage grows: %s" % str(counter))
	assert_true(counter[0] > roundi(Tuning.ATTACK_DAMAGE * Tuning.DAGGER_SWING_DAMAGE_MULT[3] * Tuning.COUNTER_DAMAGE_MULT), "above the dagger's best")
	# the katana's own numbers are untouched
	assert_eq(Weapons.swing_posture(Tuning.WEAPON_BLACK_KATANA, 3), Tuning.NORMAL_HIT_POSTURE)
	assert_near(Weapons.arc_dot(Tuning.WEAPON_DUAL_DAGGER), Tuning.ATTACK_ARC_DOT, 0.0001)


# --- Reaper's Coil ---

func test_reaper_coil_full_flow_on_a_hit() -> void:
	var core: GameCore = _core(Vector2(-100.0, 0.0))
	var start: Vector2 = core.player.position
	var k: int = _hook_ticks(100.0)
	var d: int = _drag_ticks(100.0)
	core.step(_activate(Vector2.RIGHT))
	var a: int = core.tick
	var events: Array[GameEvent] = core.last_events.duplicate()
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.state, PlayerState.STATE_REAPER_COIL)
	assert_eq(snap.player.reaper_coil_phase, PlayerState.COIL_HOOK)
	assert_eq(snap.player.reaper_coil_phase_tick, 0)
	assert_eq(snap.player.weapon_form, Weapons.FORM_REAPER_COIL)
	assert_near(core.player.edge, 100.0 - Tuning.REAPER_COIL_EDGE_COST, 0.001, "Edge spent")
	var hook_tick: int = a + k
	var drag_end: int = hook_tick + d
	var spin_end: int = drag_end + Tuning.REAPER_COIL_SPIN_TICKS
	var end_tick: int = spin_end + Tuning.REAPER_COIL_RECOVERY_TICKS
	var phases: Array[String] = []
	var noisy: InputFrame = InputFrame.new()
	while core.tick < end_tick + Tuning.REAPER_COIL_STAGGER_TICKS:
		noisy.move = Vector2.UP.rotated(float(core.tick))
		noisy.aim = Vector2.LEFT
		noisy.attack_pressed = core.tick % 2 == 0
		noisy.dash_pressed = core.tick % 3 == 0
		noisy.parry_pressed = core.tick % 5 == 0
		noisy.skill_pressed = 1 + core.tick % 3
		noisy.weapon_active_pressed = true
		core.step(noisy if core.tick < end_tick else InputFrame.new())
		events.append_array(core.last_events)
		snap = core.snapshot()
		var t: int = core.tick
		var boss_snap: Snapshots.EntitySnapshot = snap.entities[0]
		if t < end_tick:
			assert_eq(snap.player.state, PlayerState.STATE_REAPER_COIL, "in the coil at tick %d" % t)
			assert_true(snap.player.invulnerable and not core.player.take_damage(10, t, [], core.boss.id), "invulnerable at tick %d" % t)
			assert_true(core.player.position.distance_to(start) < 0.001, "immobile at tick %d" % t)
			assert_true(snap.player.weapon_buff_active, "the form runs at tick %d" % t)
			phases.append("%s%d" % [snap.player.reaper_coil_phase, snap.player.reaper_coil_phase_tick])
		if t < hook_tick:
			assert_eq(snap.player.reaper_coil_phase, PlayerState.COIL_HOOK, "hook at %d" % t)
			assert_eq(snap.player.reaper_coil_phase_tick, t - a)
			assert_true(snap.player.reaper_coil_target.distance_to(start + Vector2.RIGHT * Tuning.REAPER_COIL_HOOK_SPEED * (t - a)) < 0.01, "the tip flies out at tick %d" % t)
			assert_eq(boss_snap.state, BossState.STATE_RECOVER, "not hooked yet")
		elif t < drag_end:
			assert_eq(snap.player.reaper_coil_phase, PlayerState.COIL_DRAG, "drag at %d" % t)
			assert_true(boss_snap.dragged, "dragged at %d" % t)
			assert_eq(boss_snap.state, BossState.STATE_STAGGERED)
		elif t < spin_end:
			assert_eq(snap.player.reaper_coil_phase, PlayerState.COIL_SPIN, "spin at %d" % t)
			assert_eq(snap.player.reaper_coil_phase_tick, t - drag_end)
		elif t < end_tick:
			assert_eq(snap.player.reaper_coil_phase, PlayerState.COIL_RECOVERY, "recovery at %d" % t)
		if t >= drag_end:
			assert_false(boss_snap.dragged, "released at %d" % t)
		if t >= hook_tick and t < drag_end + Tuning.REAPER_COIL_STAGGER_TICKS:
			assert_eq(core.boss.state, BossState.STATE_STAGGERED, "stunned at tick %d" % t)
		if t >= drag_end and t < drag_end + Tuning.REAPER_COIL_STAGGER_TICKS:
			assert_eq(boss_snap.stagger_ticks_left, drag_end + Tuning.REAPER_COIL_STAGGER_TICKS - 1 - t, "stagger countdown at %d" % t)
		if t == drag_end + Tuning.REAPER_COIL_STAGGER_TICKS:
			assert_eq(core.boss.state, BossState.STATE_RECOVER, "the stun lasts exactly REAPER_COIL_STAGGER_TICKS")
	# events, in order
	var order: Array[StringName] = []
	for event: GameEvent in events:
		if String(event.type).begins_with("reaper_coil") or event.type == GameEvent.WEAPON_BUFF_STARTED or event.type == GameEvent.WEAPON_BUFF_ENDED or (event.type == GameEvent.ATTACK_HIT and int(event.data["attacker_id"]) == core.player.id):
			order.append(event.type)
	assert_eq(order, [GameEvent.WEAPON_BUFF_STARTED, GameEvent.REAPER_COIL_STARTED, GameEvent.REAPER_COIL_HOOKED, GameEvent.REAPER_COIL_DRAG,
		GameEvent.REAPER_COIL_SPIN, GameEvent.ATTACK_HIT, GameEvent.REAPER_COIL_SPIN, GameEvent.ATTACK_HIT,
		GameEvent.REAPER_COIL_ENDED, GameEvent.WEAPON_BUFF_ENDED] as Array[StringName], "event order")
	var started: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_STARTED)
	if started.size() == 1:
		assert_eq(started[0].tick, a)
		assert_eq(started[0].data["direction"], Vector2.RIGHT)
	var hooked: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_HOOKED)
	if hooked.size() == 1:
		assert_eq(hooked[0].tick, hook_tick, "hooked when the tip reaches the boss")
		assert_eq(int(hooked[0].data["target_id"]), core.boss.id)
		assert_eq(hooked[0].data["from"], start)
		assert_true((hooked[0].data["to"] as Vector2).distance_to(BOSS_AT) <= Tuning.BOSS_RADIUS + Tuning.REAPER_COIL_CHAIN_WIDTH * 0.5 + 0.01, "the chain end is on the boss")
	var drag: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_DRAG)
	if drag.size() == 1:
		assert_eq(drag[0].tick, drag_end)
		assert_eq(drag[0].data["from"], BOSS_AT)
		assert_near((drag[0].data["to"] as Vector2).distance_to(start), _drag_goal(), 0.02, "dragged until adjacent")
		assert_eq(int(drag[0].data["stagger_ticks"]), Tuning.REAPER_COIL_STAGGER_TICKS)
	var spins: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_SPIN)
	var hits: Array[GameEvent] = _player_hits(events, core)
	assert_eq(spins.size(), 2)
	assert_eq(hits.size(), 2, "two real spin hits")
	for i: int in mini(spins.size(), hits.size()):
		assert_eq(spins[i].tick, drag_end + Weapons.reaper_coil_spin_hit_tick(i + 1), "spin %d on time" % (i + 1))
		assert_eq(int(spins[i].data["hit_index"]), i + 1)
		assert_near(float(spins[i].data["radius"]), Tuning.REAPER_COIL_SPIN_RADIUS, 0.0001)
		assert_eq(hits[i].tick, spins[i].tick)
		assert_eq(int(hits[i].data["reaper_coil_hit"]), i + 1)
		assert_eq(hits[i].data["weapon_id"], SCYTHE)
		assert_false(hits[i].data.has("combo_index"), "not a combo swing")
		assert_eq(int(hits[i].data["damage"]), maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.REAPER_COIL_SPIN_DAMAGE_MULT * Tuning.ARMOR_DAMAGE_FACTOR)))
	var ended: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_ENDED)
	if ended.size() == 1:
		assert_eq(ended[0].tick, end_tick)
		assert_eq(ended[0].data["reason"], &"complete")
		assert_eq(ended[0].data["hooked"], true)
		assert_eq(int(ended[0].data["spin_hits"]), 2)
	assert_near(core.boss.posture, 2.0 * Tuning.REAPER_COIL_SPIN_POSTURE, 3.0, "posture from both spin hits (less decay)")
	assert_near(core.player.edge, 100.0 - Tuning.REAPER_COIL_EDGE_COST + 2.0 * Tuning.REAPER_COIL_EDGE_PER_HIT, 0.001, "small Edge gain")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "control is back")
	assert_eq(core.player.buff_ticks, 0, "no lingering buff")
	snap = core.snapshot()
	assert_eq(snap.player.weapon_form, &"")
	assert_eq(snap.player.reaper_coil_phase, &"")
	assert_eq(snap.player.reaper_coil_spin_hit, 0)
	assert_near(core.player.swing_speed_mult, 1.0, 0.0001)


func test_hook_cancels_every_boss_attack_without_dangling_telegraphs() -> void:
	for attack: StringName in BossState.ATTACKS:
		var core: GameCore = GameCore.new()
		core.obstacles.clear()
		core.boss.position = BOSS_AT
		core.player.weapon_id = SCYTHE
		core.player.edge = 100.0
		begin_attack(core, attack, BOSS_AT + Vector2(-90.0, 0.0))
		assert_true(core.boss.telegraphs.size() > 0, "%s telegraphed" % attack)
		var events: Array[GameEvent] = _run_coil(core, (core.boss.position - core.player.position).normalized(), Tuning.REAPER_COIL_STAGGER_TICKS)
		var hooked: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_HOOKED)
		assert_eq(hooked.size(), 1, "%s: hooked" % attack)
		if hooked.size() == 1:
			assert_eq(hooked[0].data["cancelled_attack"], attack, "the running attack was cancelled")
		var after_hook: bool = false
		var hurt: int = 0
		var boss_hits: int = 0
		var telegraphed: int = 0
		for event: GameEvent in events:
			if event.type == GameEvent.REAPER_COIL_HOOKED:
				after_hook = true
			if not after_hook:
				continue
			if event.type == GameEvent.DAMAGE_TAKEN and int(event.data["entity_id"]) == core.player.id:
				hurt += 1
			if event.type == GameEvent.ATTACK_HIT and int(event.data["attacker_id"]) == core.boss.id:
				boss_hits += 1
			if event.type == GameEvent.ATTACK_TELEGRAPHED:
				telegraphed += 1
		assert_eq(hurt + boss_hits, 0, "%s: nothing of the cancelled attack hits" % attack)
		assert_eq(telegraphed, 0, "%s: no new attack during the stun" % attack)
		assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "%s: player unhurt" % attack)


func test_staggered_boss_has_no_telegraphs_and_stays_put() -> void:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.boss.position = BOSS_AT
	core.player.weapon_id = SCYTHE
	core.player.edge = 100.0
	begin_attack(core, BossState.ATTACK_CHARGE, BOSS_AT + Vector2(-90.0, 0.0))
	core.step(_activate((core.boss.position - core.player.position).normalized()))
	var drag_end: int = -1
	var held: Vector2 = Vector2.ZERO
	for i: int in 120:
		core.step(InputFrame.new())
		if find_event(core, GameEvent.REAPER_COIL_DRAG) != null:
			drag_end = core.tick
			held = core.boss.position
		if core.boss.state == BossState.STATE_STAGGERED:
			assert_eq(core.boss.telegraphs.size(), 0, "no telegraph while staggered (tick %d)" % core.tick)
			assert_eq(core.snapshot().telegraphs.size(), 0)
		if drag_end > 0 and core.boss.state == BossState.STATE_STAGGERED:
			assert_true(core.boss.position.distance_to(held) < 0.001, "the stunned boss does not move (tick %d)" % core.tick)
	assert_true(drag_end > 0, "the drag happened")


func test_boss_is_dragged_adjacent_and_never_into_props_or_out_of_the_arena() -> void:
	var low: float = Tuning.ARENA_MARGIN
	var high: Vector2 = Tuning.ARENA_SIZE - Vector2(low, low)
	var spots: Array[Vector2] = [
		# the forest edge closing the clearing (core/arena_layout.gd BOUNDARY): west gap, east path, north, south, a corner, the east wall
		Vector2(90.0, 222.0), Vector2(728.0, 240.0), Vector2(300.0, 96.0), Vector2(480.0, 396.0),
		Vector2(124.0, 118.0), Vector2(672.0, 300.0), Vector2(152.0, 100.0), Vector2(400.0, 120.0), Vector2(400.0, 395.0),
		Vector2(96.0, 230.0), Vector2(256.0, 112.0),
	]
	var hooked_total: int = 0
	var missed_spots: Array[String] = []
	for boss_at: Vector2 in spots:
		var core: GameCore = _core(Vector2.ZERO, boss_at, false)
		core.boss.position = core.arena_point(boss_at, Tuning.BOSS_RADIUS)
		core.player.position = core.arena_point(core.boss.position + (Vector2(400.0, 240.0) - core.boss.position).normalized() * 90.0, Tuning.PLAYER_RADIUS)
		var label: String = "boss %s" % str(boss_at)
		var events: Array[GameEvent] = []
		core.step(_activate((core.boss.position - core.player.position).normalized()))
		var guard: int = 0
		var hooked: bool = false
		while (core.player.coil_running or guard < 3) and guard < 200:
			var dist_before: float = core.boss.position.distance_to(core.player.position)
			var dragging: bool = core.player.coil_phase == PlayerState.COIL_DRAG
			core.step(InputFrame.new())
			events.append_array(core.last_events)
			guard += 1
			if find_event(core, GameEvent.REAPER_COIL_HOOKED) != null:
				hooked = true
			var boss_bad: String = _arena_ok(core.boss.position, Tuning.BOSS_RADIUS, core)
			assert_eq(boss_bad, "", "boss %s, %s" % [boss_bad, label])
			var player_bad: String = _arena_ok(core.player.position, Tuning.PLAYER_RADIUS, core)
			assert_eq(player_bad, "", "player %s, %s" % [player_bad, label])
			var dist: float = core.boss.position.distance_to(core.player.position)
			assert_true(dist >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.05, "nobody inside the other (%.2f), %s" % [dist, label])
			if dragging:
				assert_true(dist <= dist_before + 0.01, "the drag only pulls closer, %s" % label)
		if hooked:
			hooked_total += 1
			var drag: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_DRAG)
			assert_eq(drag.size(), 1, "one drag, " + label)
			if drag.size() == 1:
				var to: Vector2 = drag[0].data["to"]
				var blocked: bool = int(drag[0].data["ticks"]) >= Tuning.REAPER_COIL_DRAG_MAX_TICKS or to.distance_to(core.player.position) > _drag_goal() + 0.02
				if not blocked:
					assert_near(to.distance_to(core.player.position), _drag_goal(), 0.02, "adjacent after the drag, " + label)
			assert_eq(_of(events, GameEvent.REAPER_COIL_SPIN).size(), 2, "two spins, " + label)
		else:
			var missed: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_MISSED)
			missed_spots.append("%s (%s)" % [label, str(missed[0].data["blocked_by"]) if missed.size() == 1 else "?"])
		assert_eq(_of(events, GameEvent.REAPER_COIL_ENDED).size(), 1, "ended once, " + label)
		assert_false(core.boss.dragged, "released, " + label)
	assert_true(hooked_total >= 9, "the hook reached the boss from almost every spot (%d of %d), missed: %s" % [hooked_total, spots.size(), str(missed_spots)])


func test_a_miss_pulls_the_player_and_does_not_stagger() -> void:
	var core: GameCore = _core(Vector2(-100.0, 0.0))
	var start: Vector2 = core.player.position
	var events: Array[GameEvent] = _run_coil(core, Vector2.UP)
	var a: int = 1
	var missed: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_MISSED)
	assert_eq(missed.size(), 1, "missed")
	var anchor: Vector2 = start + Vector2.UP * Tuning.REAPER_COIL_HOOK_RANGE
	if missed.size() == 1:
		assert_eq(missed[0].tick, a + Weapons.reaper_coil_hook_ticks(), "after the full flight")
		assert_eq(missed[0].data["blocked_by"], &"range")
		assert_true((missed[0].data["to"] as Vector2).distance_to(anchor) < 0.01, "the chain stops at full range")
	assert_true(core.player.position.distance_to(anchor) <= Tuning.REAPER_COIL_DRAG_BLOCKED_PX + 0.01, "pulled to the anchor (%s)" % str(core.player.position))
	var ended: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_ENDED)
	assert_eq(ended.size(), 1)
	if ended.size() == 1:
		var pull: int = ceili(Tuning.REAPER_COIL_HOOK_RANGE / Tuning.REAPER_COIL_PULL_SPEED)
		assert_eq(ended[0].tick, a + Weapons.reaper_coil_hook_ticks() + pull + Tuning.REAPER_COIL_PULL_RECOVERY_TICKS, "pull then a short recovery")
		assert_eq(ended[0].data["reason"], &"missed")
		assert_eq(ended[0].data["hooked"], false)
	for type: StringName in [GameEvent.REAPER_COIL_HOOKED, GameEvent.REAPER_COIL_DRAG, GameEvent.REAPER_COIL_SPIN]:
		assert_eq(_of(events, type).size(), 0, "no %s on a miss" % type)
	assert_eq(core.boss.hp, Tuning.BOSS_MAX_HP)
	assert_eq(core.boss.state, BossState.STATE_RECOVER, "no stagger")
	assert_false(core.boss.dragged)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	# The pull speed: watch one run tick by tick.
	var watch: GameCore = _core(Vector2(-100.0, 0.0))
	watch.step(_activate(Vector2.UP))
	var last: Vector2 = watch.player.position
	var moved_ticks: int = 0
	while watch.player.coil_running:
		var phase_before: StringName = watch.player.coil_phase
		watch.step(InputFrame.new())
		var step_len: float = watch.player.position.distance_to(last)
		assert_true(step_len <= Tuning.REAPER_COIL_PULL_SPEED + 0.01, "at most PULL_SPEED per tick")
		if step_len > 0.01:
			moved_ticks += 1
			assert_eq(phase_before, PlayerState.COIL_PULL, "moves only in the pull (tick %d)" % watch.tick)
		last = watch.player.position
	assert_eq(moved_ticks, ceili(Tuning.REAPER_COIL_HOOK_RANGE / Tuning.REAPER_COIL_PULL_SPEED))


func test_a_far_boss_is_a_miss_and_the_wall_stops_the_chain() -> void:
	var far: GameCore = _core(Vector2(-300.0, 0.0))
	var events: Array[GameEvent] = _run_coil(far, Vector2.RIGHT)
	assert_eq(_of(events, GameEvent.REAPER_COIL_MISSED).size(), 1, "out of range: a miss")
	assert_eq(_of(events, GameEvent.WEAPON_BUFF_STARTED).size(), 1, "but allowed")
	assert_true(far.player.position.distance_to(BOSS_AT + Vector2(-150.0, 0.0)) < 1.0, "pulled 150 px toward it")
	var wall: GameCore = _core(Vector2(0.0, 0.0), BOSS_AT, true)
	wall.player.position = Vector2(400.0, Tuning.ARENA_MARGIN + 40.0)
	wall.boss.position = Vector2(400.0, 400.0)
	events = _run_coil(wall, Vector2.UP)
	var missed: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_MISSED)
	assert_eq(missed.size(), 1)
	if missed.size() == 1:
		assert_eq(missed[0].data["blocked_by"], &"wall")
		assert_true((missed[0].data["to"] as Vector2).distance_to(Vector2(400.0, Tuning.ARENA_MARGIN)) < 0.01, "the chain stops at the wall")
		assert_eq(missed[0].tick, 1 + ceili(40.0 / Tuning.REAPER_COIL_HOOK_SPEED))
	assert_eq(_arena_ok(wall.player.position, Tuning.PLAYER_RADIUS, wall), "")


func test_a_prop_between_blocks_the_chain() -> void:
	var core: GameCore = _core(Vector2(-100.0, 0.0))
	var prop: Obstacle = Obstacle.new()
	prop.id = 99
	prop.center = BOSS_AT + Vector2(-50.0, 0.0)
	prop.radius = 8.0
	core.obstacles.append(prop)
	var events: Array[GameEvent] = []
	core.step(_activate(Vector2.RIGHT))
	while core.player.coil_running:
		core.step(InputFrame.new())
		events.append_array(core.last_events)
		assert_eq(_arena_ok(core.player.position, Tuning.PLAYER_RADIUS, core), "", "never inside the prop (tick %d)" % core.tick)
	var missed: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_MISSED)
	assert_eq(missed.size(), 1, "the prop stops the chain")
	if missed.size() == 1:
		assert_eq(missed[0].data["blocked_by"], &"prop")
		assert_true((missed[0].data["to"] as Vector2).distance_to(prop.center) <= prop.radius + Tuning.REAPER_COIL_CHAIN_WIDTH * 0.5 + 0.01, "on the prop")
	assert_eq(_of(events, GameEvent.REAPER_COIL_HOOKED).size(), 0, "the boss behind it is not hooked")
	assert_eq(core.boss.position, BOSS_AT, "not dragged")
	assert_eq(core.boss.state, BossState.STATE_RECOVER, "not stunned")
	assert_true(core.player.position.x > BOSS_AT.x - 100.0 + 10.0, "pulled toward the prop")
	assert_true(core.player.position.distance_to(prop.center) < prop.radius + Tuning.PLAYER_RADIUS + 3.0, "up to the prop")
	# Control: a prop beside the line does not block it.
	var beside: GameCore = _core(Vector2(-100.0, 0.0))
	var off: Obstacle = Obstacle.new()
	off.id = 99
	off.center = BOSS_AT + Vector2(-50.0, 20.0)
	off.radius = 8.0
	beside.obstacles.append(off)
	assert_eq(_of(_run_coil(beside, Vector2.RIGHT), GameEvent.REAPER_COIL_HOOKED).size(), 1, "a prop beside the chain does not block it")


func test_cost_cooldown_from_activation_and_no_refresh() -> void:
	var poor: GameCore = _core()
	poor.player.edge = Tuning.REAPER_COIL_EDGE_COST - 1.0
	poor.step(_activate())
	assert_false(poor.player.coil_running, "not enough Edge")
	assert_eq(poor.last_events.size(), 0, "a refused press emits nothing")
	var dead: GameCore = _core()
	dead.boss.take_damage(Tuning.BOSS_MAX_HP, 0, [], dead.player.id)
	dead.step(_activate())
	assert_false(dead.player.coil_running, "no coil on a dead boss")
	assert_true(find_event(dead, GameEvent.WEAPON_BUFF_STARTED) == null)
	assert_near(dead.player.edge, 100.0, 0.001, "nothing spent")
	assert_eq(dead.player.buff_cooldown, 0)
	var core: GameCore = _core()
	core.step(_activate(Vector2.RIGHT))
	var a: int = core.tick
	assert_eq(core.player.buff_cooldown, Tuning.REAPER_COIL_COOLDOWN_TICKS)
	var started: GameEvent = find_event(core, GameEvent.WEAPON_BUFF_STARTED)
	assert_true(started != null)
	if started != null:
		assert_eq(started.data["form"], Weapons.FORM_REAPER_COIL)
		assert_eq(int(started.data["duration"]), Weapons.reaper_coil_total_ticks())
	run(core, 5)
	core.player.buff_cooldown = 0
	var edge: float = core.player.edge
	core.step(_activate(Vector2.UP))
	assert_true(find_event(core, GameEvent.REAPER_COIL_STARTED) == null and find_event(core, GameEvent.WEAPON_BUFF_STARTED) == null, "no refresh while it runs")
	assert_near(core.player.edge, edge, 0.001, "no second cost")
	core.player.buff_cooldown = Tuning.REAPER_COIL_COOLDOWN_TICKS - (core.tick - a)
	while core.player.coil_running:
		core.step(InputFrame.new())
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.hud.weapon_buff_cooldown_ticks, Tuning.REAPER_COIL_COOLDOWN_TICKS - (core.tick - a), "counted from the activation")
	assert_eq(snap.hud.weapon_buff_cooldown_max, Tuning.REAPER_COIL_COOLDOWN_TICKS)
	assert_eq(snap.hud.weapon_buff_duration, Weapons.reaper_coil_total_ticks())
	assert_near(snap.hud.weapon_buff_edge_cost, Tuning.REAPER_COIL_EDGE_COST, 0.0001)
	while core.tick < a + Tuning.REAPER_COIL_COOLDOWN_TICKS - 2:  # the next step is activation + COOLDOWN - 1
		core.player.hp = Tuning.PLAYER_MAX_HP  # the boss fights again after its stun; keep the fight going
		core.step(InputFrame.new())
	core.player.edge = 100.0
	core.boss.hp = Tuning.BOSS_MAX_HP
	core.step(_activate())
	assert_false(core.player.coil_running, "one tick short of the cooldown")
	core.step(_activate())
	assert_true(core.player.coil_running, "ready exactly REAPER_COIL_COOLDOWN_TICKS after the activation")


func test_the_coil_starts_from_a_swing_and_stops_it() -> void:
	var core: GameCore = _core(Vector2(-30.0, 0.0))
	core.step(input(Vector2.ZERO, false, false, true))
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_WINDUP)
	core.step(_activate())
	assert_eq(core.player.state, PlayerState.STATE_REAPER_COIL, "a free action like the barrage: it takes over")
	var events: Array[GameEvent] = _run(core, Weapons.reaper_coil_total_ticks())
	for hit: GameEvent in _player_hits(events, core):
		assert_true(hit.data.has("reaper_coil_hit"), "the interrupted swing never lands")


func test_boss_death_ends_the_coil() -> void:
	var core: GameCore = _core()
	core.boss.hp = maxi(1, roundi(Tuning.ATTACK_DAMAGE * Tuning.REAPER_COIL_SPIN_DAMAGE_MULT * Tuning.ARMOR_DAMAGE_FACTOR))
	var events: Array[GameEvent] = _run_coil(core, Vector2.RIGHT)
	assert_eq(_of(events, GameEvent.REAPER_COIL_SPIN).size(), 1, "no spin after the boss died")
	var ended: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_ENDED)
	assert_eq(ended.size(), 1)
	if ended.size() == 1:
		assert_eq(ended[0].data["reason"], &"boss_dead")
		assert_true(events.find(ended[0]) < events.find(_of(events, GameEvent.GAME_RESULT)[0]), "ended before the result")
	assert_eq(core.result, GameCore.RESULT_VICTORY)
	assert_false(core.player.coil_running)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_false(core.player.is_buff_active())


func test_player_death_ends_the_coil_and_releases_the_boss() -> void:
	var core: GameCore = _core()
	core.step(_activate(Vector2.RIGHT))
	var guard: int = 0
	while core.player.coil_phase != PlayerState.COIL_DRAG and guard < 50:
		core.step(InputFrame.new())
		guard += 1
	core.step(InputFrame.new())
	assert_true(core.boss.dragged, "mid-drag")
	var events: Array[GameEvent] = []
	core.player.die(core.tick, events)
	var types: Array[StringName] = []
	for event: GameEvent in events:
		types.append(event.type)
	assert_true(types.has(GameEvent.REAPER_COIL_ENDED), "the coil ended on death")
	assert_true(types.find(GameEvent.REAPER_COIL_ENDED) < types.find(GameEvent.WEAPON_BUFF_ENDED), "before the form")
	assert_true(types.find(GameEvent.WEAPON_BUFF_ENDED) < types.find(GameEvent.ENTITY_DIED), "before entity_died")
	if types.has(GameEvent.REAPER_COIL_ENDED):
		assert_eq(events[types.find(GameEvent.REAPER_COIL_ENDED)].data["reason"], &"death")
		assert_eq(events[types.find(GameEvent.WEAPON_BUFF_ENDED)].data["reason"], &"death")
	core.step(InputFrame.new())
	assert_false(core.boss.dragged, "the boss is never left held")
	assert_eq(core.boss.state, BossState.STATE_STAGGERED, "it gets its normal stun")
	assert_eq(core.result, GameCore.RESULT_DEFEAT)
	assert_eq(_player_hits(_run(core, 30), core).size(), 0, "no spin after death")


func test_a_broken_boss_stays_broken_and_spin_hits_are_counters() -> void:
	var core: GameCore = _core()
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 0, [])
	core.player.edge = 100.0
	var events: Array[GameEvent] = _run_coil(core, Vector2.RIGHT, 0)
	assert_eq(_of(events, GameEvent.REAPER_COIL_HOOKED).size(), 1)
	var drag: Array[GameEvent] = _of(events, GameEvent.REAPER_COIL_DRAG)
	if drag.size() == 1:
		assert_eq(int(drag[0].data["stagger_ticks"]), 0, "no stun on a broken boss")
	var hits: Array[GameEvent] = _player_hits(events, core)
	assert_true(hits.size() >= 1, "the spin hit")
	if hits.size() >= 1:
		assert_eq(hits[0].data["kind"], &"counter", "existing counter rules")
	assert_true(core.boss.state != BossState.STATE_STAGGERED, "never staggered")


func test_snapshot_fields() -> void:
	var core: GameCore = _core()
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.player.weapon_id, SCYTHE)
	assert_eq(snap.player.combo_max, 3)
	assert_eq(snap.player.reaper_coil_phase, &"")
	assert_false(snap.entities[0].dragged)
	assert_eq(snap.hud.weapon_buff_duration, Weapons.reaper_coil_total_ticks())
	assert_eq(snap.hud.weapon_buff_cooldown_max, Tuning.REAPER_COIL_COOLDOWN_TICKS)
	assert_true(snap.hud.weapon_cooldowns.has(SCYTHE))
	core.step(_activate(Vector2.RIGHT))
	var seen_drag: bool = false
	while core.player.coil_running:
		core.step(InputFrame.new())
		snap = core.snapshot()
		if core.player.coil_running:
			assert_eq(snap.player.reaper_coil_from, core.player.position)
		else:
			assert_eq(snap.player.reaper_coil_phase, &"", "cleared on the last tick")
		if snap.player.reaper_coil_phase == PlayerState.COIL_DRAG and snap.player.reaper_coil_phase_tick > 0 and snap.entities[0].dragged:
			seen_drag = true
			assert_near(snap.player.reaper_coil_target.distance_to(snap.entities[0].position), Tuning.BOSS_RADIUS, 0.6, "the chain holds the boss edge")
		assert_eq(snap.player.reaper_coil_spin_hit, core.player.coil_spin_hit)
	assert_true(seen_drag)


func test_save_profile_accepts_the_scythe() -> void:
	var SaveProfile: GDScript = load("res://core/save_profile.gd")
	var scythe: Object = SaveProfile.from_json("{\"version\": 1, \"weapon_id\": \"chain_scythe\"}")
	assert_eq(scythe.weapon_id, SCYTHE)
	assert_eq(SaveProfile.from_json(scythe.to_json()).weapon_id, SCYTHE, "round trip")
	var old: Object = SaveProfile.from_json("{\"version\": 1, \"weapon_id\": \"dual_dagger\"}")
	assert_eq(old.weapon_id, Tuning.WEAPON_DUAL_DAGGER, "older saves still load")
	var none: Object = SaveProfile.from_json("{\"version\": 1}")
	assert_eq(none.weapon_id, Tuning.WEAPON_BLACK_KATANA)


# --- determinism and soak ---

func _trace(seed_value: int) -> Array[String]:
	var core: GameCore = GameCore.new(seed_value)
	core.player.weapon_id = SCYTHE
	var lines: Array[String] = []
	for i: int in 1200:
		core.player.hp = Tuning.PLAYER_MAX_HP
		core.boss.hp = Tuning.BOSS_MAX_HP
		if not core.player.coil_running:
			core.player.buff_cooldown = 0
			core.player.edge = 100.0
		var frame: InputFrame = InputFrame.new()
		var to_boss: Vector2 = core.boss.position - core.player.position
		frame.move = to_boss.normalized() if i % 300 < 150 else Vector2.LEFT.rotated(float(i) / 40.0)
		frame.aim = to_boss.normalized().rotated(0.6 if i % 240 > 200 else 0.0)
		frame.attack_pressed = i % 3 == 0
		frame.weapon_active_pressed = i % 90 == 5
		frame.dash_pressed = i % 97 == 11
		core.step(frame)
		lines.append("%d %s %s %s %d %d %s %s %s" % [core.tick, str(core.player.position), core.player.state, core.player.coil_phase, core.player.hp, core.boss.hp, str(core.boss.position), core.boss.state, str(event_types(core))])
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
	var joined: String = "\n".join(a)
	assert_true(joined.contains(String(GameEvent.REAPER_COIL_HOOKED)) and joined.contains(String(GameEvent.REAPER_COIL_SPIN)), "the run hooked and spun")


func test_long_soak_with_random_reaper_coils() -> void:
	for seed_value: int in [3, 11]:
		var core: GameCore = GameCore.new(seed_value)
		core.player.weapon_id = SCYTHE
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value * 7919
		var bad: Array[String] = []
		var counts: Dictionary = {}
		var open: bool = false
		var resolved: bool = false
		for i: int in 3000:
			core.player.edge = 100.0
			core.player.hp = Tuning.PLAYER_MAX_HP
			core.boss.hp = Tuning.BOSS_MAX_HP
			if not core.player.coil_running:
				core.player.buff_cooldown = 0
			var frame: InputFrame = InputFrame.new()
			var to_boss: Vector2 = core.boss.position - core.player.position
			frame.move = to_boss.normalized() if i % 400 < 200 else Vector2.RIGHT.rotated(floorf(float(i) / 37.0))
			frame.aim = to_boss.normalized() if rng.randf() < 0.7 else Vector2.RIGHT.rotated(rng.randf() * TAU)
			frame.attack_pressed = i % 2 == 0
			frame.weapon_active_pressed = rng.randf() < 0.04
			frame.dash_pressed = i % 97 == 11
			core.step(frame)
			if core.result != GameCore.RESULT_PLAYING:
				bad.append("the fight ended at %d" % core.tick)
				break
			for event: GameEvent in core.last_events:
				counts[event.type] = int(counts.get(event.type, 0)) + 1
				match event.type:
					GameEvent.REAPER_COIL_STARTED:
						if open:
							bad.append("started twice at %d" % core.tick)
						open = true
						resolved = false
					GameEvent.REAPER_COIL_HOOKED, GameEvent.REAPER_COIL_MISSED:
						if not open or resolved:
							bad.append("hook result outside a coil at %d" % core.tick)
						resolved = true
					GameEvent.REAPER_COIL_ENDED:
						if not open:
							bad.append("ended without a start at %d" % core.tick)
						open = false
			if open != core.player.coil_running:
				bad.append("event state and player state disagree at %d" % core.tick)
			for pair: Array in [[core.player.position, Tuning.PLAYER_RADIUS, "player"], [core.boss.position, Tuning.BOSS_RADIUS, "boss"]]:
				var problem: String = _arena_ok(pair[0], pair[1], core)
				if problem != "":
					bad.append("%s %s at tick %d" % [pair[2], problem, core.tick])
			if core.player.position.distance_to(core.boss.position) < Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.05:
				bad.append("overlap at %d" % core.tick)
			if core.boss.dragged and core.player.coil_phase != PlayerState.COIL_DRAG:
				bad.append("boss held outside a drag at %d" % core.tick)
			if core.boss.state == BossState.STATE_STAGGERED and not core.boss.telegraphs.is_empty():
				bad.append("telegraph while staggered at %d" % core.tick)
		assert_eq(bad.slice(0, 5), [] as Array[String], "seed %d: %d problems" % [seed_value, bad.size()])
		var started: int = int(counts.get(GameEvent.REAPER_COIL_STARTED, 0))
		assert_true(started >= 10, "seed %d: many coils (%d)" % [seed_value, started])
		assert_true(int(counts.get(GameEvent.REAPER_COIL_HOOKED, 0)) >= 3, "seed %d: some hooks (%s)" % [seed_value, str(counts.get(GameEvent.REAPER_COIL_HOOKED, 0))])
		assert_true(int(counts.get(GameEvent.REAPER_COIL_MISSED, 0)) >= 1, "seed %d: some misses" % seed_value)
		# Two spin events per finished drag (minus the ones a spin still running at the end has not reached yet).
		var pending: int = Tuning.REAPER_COIL_SPIN_HITS - core.player.coil_spin_hit if core.player.coil_phase == PlayerState.COIL_SPIN else 0
		assert_eq(int(counts.get(GameEvent.REAPER_COIL_SPIN, 0)), Tuning.REAPER_COIL_SPIN_HITS * int(counts.get(GameEvent.REAPER_COIL_DRAG, 0)) - pending, "seed %d: two spins per drag" % seed_value)
