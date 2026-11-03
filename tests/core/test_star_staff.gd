extends "res://tests/test_case.gd"
## The Star Staff (fourth weapon, 2026-11-01): the cast that bursts at range (two Arcane Bursts, then the Great Burst), the blink
## dash, and the right-click Disintegration (a circle under the target, the meteor, the impact), against the boss and on the road.

const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")
const Aspects := preload("res://core/aspects.gd")

const STAFF: StringName = &"star_staff"
const BOSS_AT: Vector2 = Vector2(400.0, 240.0)


## A pinned boss (it neither walks nor attacks) in an open field, the player `offset` from it facing it, full Edge, the staff.
func _core(offset: Vector2 = Vector2(-80.0, 0.0)) -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = BOSS_AT
	core.player.position = BOSS_AT + offset
	core.player.facing = -offset.normalized()
	core.player.edge = 100.0
	core.player.weapon_id = STAFF
	return core


func _attack() -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.attack_pressed = true
	return frame


func _run(core: RefCounted, ticks: int, frame: InputFrame = null) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	for i: int in ticks:
		core.step(frame if frame != null else InputFrame.new())
		events.append_array(core.last_events)
	return events


func _of(events: Array[GameEvent], type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in events:
		if e.type == type:
			out.append(e)
	return out


## One cast: press, then step through its windup and active ticks. Every event.
func _cast(core: RefCounted, combo_index: int = 1) -> Array[GameEvent]:
	var events: Array[GameEvent] = _run(core, 1, _attack())
	var phases: Array[int] = Weapons.swing_phases(STAFF, combo_index)
	events.append_array(_run(core, phases[0] + phases[1]))
	return events


func test_the_staff_is_a_fourth_weapon_with_a_ranged_burst() -> void:
	assert_true(Weapons.IDS.has(STAFF), "in the inventory")
	assert_eq(Weapons.combo_max(STAFF), 3)
	assert_true(Weapons.is_ranged(STAFF) and not Weapons.is_ranged(Tuning.WEAPON_BLACK_KATANA))
	assert_true(Weapons.burst_radius(STAFF, 3) > Weapons.burst_radius(STAFF, 1), "the Great Burst is bigger")
	assert_true(Tuning.STAFF_BURST_RANGE > Tuning.ATTACK_RANGE * 2.0, "it reaches far beyond a blade")
	assert_true(Weapons.has_blink_dash(STAFF) and Weapons.has_disintegration(STAFF) and Weapons.active_needs_target(STAFF))
	assert_eq(Weapons.active_form(STAFF), Weapons.FORM_DISINTEGRATION)
	assert_eq(Weapons.disintegration_impact_ticks(), Tuning.DISINTEGRATION_FORM_TICKS + Tuning.DISINTEGRATION_CHARGE_TICKS + Tuning.DISINTEGRATION_FALL_TICKS)


func test_a_cast_bursts_on_the_boss_far_beyond_blade_reach() -> void:
	var core: GameCore = _core(Vector2(-80.0, 0.0))  # 60 px from the boss's edge: no blade reaches that
	var hp: int = core.boss.hp
	var events: Array[GameEvent] = _cast(core)
	var bursts: Array[GameEvent] = _of(events, GameEvent.STAFF_BURST)
	assert_eq(bursts.size(), 1, "one burst")
	if bursts.size() == 1:
		assert_true((bursts[0].data["position"] as Vector2).distance_to(BOSS_AT) < 0.5, "it snapped onto the boss")
		assert_eq(bursts[0].data["radius"], Tuning.STAFF_BURST_RADIUS[0])
		assert_eq(bursts[0].data["finisher"], false)
	assert_true(core.boss.hp < hp, "the boss took the hit")
	assert_true(find_event(core, GameEvent.ATTACK_HIT) != null or _of(events, GameEvent.ATTACK_HIT).size() == 1)


func test_a_cast_out_of_range_or_aimed_away_bursts_in_the_open() -> void:
	var far: GameCore = _core(Vector2(-160.0, 0.0))  # 140 px from its edge: beyond STAFF_BURST_RANGE
	var hp: int = far.boss.hp
	var events: Array[GameEvent] = _cast(far)
	var bursts: Array[GameEvent] = _of(events, GameEvent.STAFF_BURST)
	assert_eq(bursts.size(), 1, "the cast still goes off (presentation draws it)")
	if bursts.size() == 1:
		var expected: Vector2 = BOSS_AT + Vector2(-160.0, 0.0) + Vector2.RIGHT * Tuning.STAFF_BURST_RANGE
		assert_true((bursts[0].data["position"] as Vector2).distance_to(expected) < 0.5, "straight ahead at full range")
	assert_eq(far.boss.hp, hp, "out of reach")
	var away: GameCore = _core(Vector2(-60.0, 0.0))
	away.player.facing = Vector2.LEFT
	hp = away.boss.hp
	_cast(away)
	assert_eq(away.boss.hp, hp, "aimed away: the boss behind is not hit")


func test_the_third_cast_is_the_great_burst() -> void:
	var core: GameCore = _core(Vector2(-80.0, 0.0))
	var total: int = 0
	for i: int in 3:
		for ticks: int in Weapons.swing_phases(STAFF, i + 1):
			total += ticks
	var finishers: Array[GameEvent] = _of(_run(core, total + 3, _attack()), GameEvent.STAFF_BURST)  # attack pressed every tick: the casts chain
	assert_true(finishers.size() >= 3, "three casts")
	if finishers.size() >= 3:
		assert_eq(finishers[0].data["finisher"], false)
		assert_eq(finishers[2].data["combo_index"], 3)
		assert_eq(finishers[2].data["finisher"], true)
		assert_eq(finishers[2].data["radius"], Tuning.STAFF_BURST_RADIUS[2])


func test_the_dash_is_a_short_invulnerable_blink() -> void:
	var core: GameCore = _core(Vector2(-150.0, 0.0))
	var start: Vector2 = core.player.position
	var frame: InputFrame = InputFrame.new()
	frame.dash_pressed = true
	frame.move = Vector2.UP
	core.step(frame)
	var started: GameEvent = find_event(core, GameEvent.DASH_STARTED)
	assert_true(started != null and started.data["blink"] == true, "dash_started says it is a blink")
	assert_true(core.snapshot().player.blink, "the snapshot too")
	assert_true(core.player.is_invulnerable(), "i-frames")
	_run(core, Tuning.STAFF_BLINK_TICKS + 1)
	var moved: float = core.player.position.distance_to(start)
	assert_true(absf(moved - Tuning.STAFF_BLINK_TICKS * Tuning.STAFF_BLINK_SPEED) < 1.0, "it covers STAFF_BLINK_TICKS x STAFF_BLINK_SPEED px (%.1f)" % moved)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "and is over")


func test_disintegration_marks_the_target_then_the_meteor_lands() -> void:
	var core: GameCore = _core(Vector2(-120.0, 0.0))
	var hp: int = core.boss.hp
	var frame: InputFrame = InputFrame.new()
	frame.weapon_active_pressed = true
	core.step(frame)
	var started: GameEvent = find_event(core, GameEvent.DISINTEGRATION_STARTED)
	assert_true(started != null, "it starts")
	assert_eq(core.player.state, PlayerState.STATE_STAFF_CAST, "rooted in the cast")
	assert_true(core.player.is_invulnerable(), "and invulnerable while casting")
	assert_eq(core.player.edge, 100.0 - Tuning.DISINTEGRATION_EDGE_COST, "Edge spent")
	assert_eq(core.snapshot().player.weapon_form, Weapons.FORM_DISINTEGRATION)
	assert_eq(core.snapshot().player.disintegration_phase, &"form")
	var cast: int = Tuning.DISINTEGRATION_FORM_TICKS + Tuning.DISINTEGRATION_CHARGE_TICKS
	_run(core, cast - 1)
	assert_eq(core.player.state, PlayerState.STATE_STAFF_CAST, "still casting on the last charge tick")
	_run(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "free once the meteor falls")
	assert_eq(core.snapshot().player.disintegration_phase, &"fall")
	assert_eq(core.boss.hp, hp, "nothing hits before the impact")
	var events: Array[GameEvent] = _run(core, Tuning.DISINTEGRATION_FALL_TICKS)
	var impact: Array[GameEvent] = _of(events, GameEvent.DISINTEGRATION_IMPACT)
	assert_eq(impact.size(), 1, "one impact")
	if impact.size() == 1:
		assert_eq(impact[0].tick, started.data["impact_tick"], "on the tick it announced")
		assert_eq((impact[0].data["hit_ids"] as Array).size(), 1, "the boss was in the circle")
	assert_true(core.boss.hp < hp, "the meteor hurts")
	events = _run(core, Tuning.DISINTEGRATION_AFTER_TICKS + 2)
	var ended: Array[GameEvent] = _of(events, GameEvent.DISINTEGRATION_ENDED)
	assert_eq(ended.size(), 1, "it ends after the aftermath")
	if ended.size() == 1:
		assert_eq(ended[0].data["reason"], &"complete")
	assert_eq(core.snapshot().player.disintegration_phase, &"", "nothing runs")
	assert_true(core.player.active_cooldowns.get(STAFF, core.player.buff_cooldown) > 0 or core.player.buff_cooldown > 0, "on cooldown")


func test_the_circle_follows_the_target_until_the_lock() -> void:
	var core: GameCore = _core(Vector2(-120.0, 0.0))
	var frame: InputFrame = InputFrame.new()
	frame.weapon_active_pressed = true
	core.step(frame)
	core.boss.position = BOSS_AT + Vector2(0.0, 30.0)
	_run(core, 2)
	assert_true(core.snapshot().player.disintegration_center.distance_to(core.boss.position) < 0.5, "it follows before the lock")
	_run(core, Weapons.disintegration_impact_ticks() - Tuning.DISINTEGRATION_LOCK_TICKS - 2)
	var locked: Vector2 = core.snapshot().player.disintegration_center
	core.boss.position = BOSS_AT + Vector2(0.0, -200.0)  # it got away after the lock
	var hp: int = core.boss.hp
	_run(core, Tuning.DISINTEGRATION_LOCK_TICKS + 1)
	assert_true(core.snapshot().player.disintegration_center.distance_to(locked) < 0.5 or core.snapshot().player.disintegration_phase == &"after", "it stays after the lock")
	assert_eq(core.boss.hp, hp, "the meteor lands where the circle was: the boss stepped out")


func test_disintegration_needs_a_living_target() -> void:
	var core: GameCore = _core(Vector2(-120.0, 0.0))
	core.boss.state = BossState.STATE_DEAD
	var frame: InputFrame = InputFrame.new()
	frame.weapon_active_pressed = true
	core.step(frame)
	assert_true(find_event(core, GameEvent.DISINTEGRATION_STARTED) == null, "refused")
	assert_eq(core.player.edge, 100.0, "no Edge spent")


# ---- on the road, against mobs ----------------------------------------------------------------------------------------------

func _road() -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SceneDefs.WOODLAND_LAYERED)
	core.set_story_flags([&"received_first_sword", &"debug_all_unlocked"] as Array[StringName])
	core.set_loadout(STAFF, [Aspects.SPRINT, Aspects.GALE_CUT, Aspects.MOON_CLEAVE] as Array[StringName])
	core.player.edge = Tuning.EDGE_MAX
	return core


func _mob(core: ExploreCore) -> Mob:
	for enc: MobField.Encounter in core.mobs.encounters:
		if enc.id == &"mossling_clearing":
			return enc.mobs[0]
	return null


func test_on_the_road_a_cast_and_disintegration_hit_mobs_at_range() -> void:
	var core: ExploreCore = _road()
	assert_eq(core.player.weapon_id, STAFF, "the loadout equips the staff")
	var mob: Mob = _mob(core)
	core.player.position = mob.position + Vector2(-70.0, 0.0)
	core.player.facing = Vector2.RIGHT
	var hp: int = mob.hp
	var events: Array[GameEvent] = _cast(core)
	assert_eq(_of(events, GameEvent.STAFF_BURST).size(), 1, "a burst")
	assert_true(mob.hp < hp, "the mob 70 px away took it")
	_run(core, 40)
	hp = mob.hp
	core.player.position = mob.position + Vector2(-70.0, 0.0)
	core.player.facing = Vector2.RIGHT
	core.player.edge = Tuning.EDGE_MAX
	var frame: InputFrame = InputFrame.new()
	frame.weapon_active_pressed = true
	frame.aim = Vector2.RIGHT
	core.step(frame)
	assert_eq(_of(core.last_events, GameEvent.DISINTEGRATION_STARTED).size(), 1, "Disintegration starts on the mob in front")
	events = _run(core, Weapons.disintegration_impact_ticks())
	var impact: Array[GameEvent] = _of(events, GameEvent.DISINTEGRATION_IMPACT)
	assert_eq(impact.size(), 1, "the meteor lands")
	if impact.size() == 1:
		assert_true((impact[0].data["hit_ids"] as Array).has(mob.id), "on the mob")
	assert_true(mob.hp < hp, "and hurts it")
