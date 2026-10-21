extends "res://tests/test_case.gd"
## The three sword skills (skill_pressed 1, 2, 3): Breaking Edge (melee retaliation), Gale Cut (dash corridor)
## and Moon Cleave (travelling sword-aura projectile).

const Snapshots := preload("res://core/snapshots.gd")
const SkillAttack := preload("res://core/skill_attack.gd")

const FAR: Vector2 = Vector2(300.0, 20.0)  # a corner the dash and the projectile never reach


## The boss is pinned at `where` (it would otherwise walk towards the player) and the player stands at
## `player_at`, facing right.
func _core(player_at: Vector2 = Vector2(40.0, 88.0), boss_at: Vector2 = FAR) -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()  # these tests pin positions in an open field; the props have their own tests
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = boss_at
	core.player.position = player_at
	core.player.facing = Vector2.RIGHT
	return core


func _press(core: GameCore, slot: int, move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.ZERO) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = slot
	frame.move = move
	frame.aim = aim
	core.step(frame)


## A successful parry just happened: Edge and the retaliation window are set the way the core sets them.
func _after_parry(core: GameCore, edge: float = 0.0) -> void:
	core.player.edge = edge
	core.player.on_parry_success(Vector2.ZERO)


func _hit_events(core: GameCore, ticks: int) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for i: int in ticks:
		core.step(input())
		for event: GameEvent in core.last_events:
			if event.type == GameEvent.ATTACK_HIT:
				found.append(event)
	return found


func _in_skill(core: GameCore) -> bool:
	return String(core.player.state).begins_with("skill_")


func _armored(damage: float) -> int:
	return maxi(1, roundi(damage * Tuning.ARMOR_DAMAGE_FACTOR))


func _swing_total(windup: int, active: int, recovery: int) -> int:
	return windup + active + recovery


## Start Gale Cut and play it to the end of the dash. Returns every attack_hit seen.
func _gale(core: GameCore, move: Vector2 = Vector2.RIGHT) -> Array[GameEvent]:
	core.player.edge = 100.0
	_press(core, 2, move)
	return _hit_events(core, Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS)


# --- direction: skills go where the player is moving ---

func test_skill_direction_prefers_the_move_input_over_the_aim() -> void:
	var core: GameCore = _core(Vector2(300.0, 300.0))
	core.player.edge = 100.0
	_press(core, 2, Vector2.UP, Vector2.RIGHT)  # moving up while the mouse points right
	assert_near(core.player.skill_dir.y, -1.0, 0.001, "the skill goes up, where the player moves")
	assert_near(core.player.skill_dir.x, 0.0, 0.001)
	assert_near(core.player.facing.y, -1.0, 0.001, "and the player faces that way")
	var start: Vector2 = core.player.position
	run(core, Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS)
	assert_true(core.player.position.y < start.y - 100.0, "the dash went up")
	assert_near(core.player.position.x, start.x, 0.5, "not towards the mouse")


func test_skill_direction_falls_back_to_the_aim_then_the_facing() -> void:
	var aimed: GameCore = _core()
	aimed.player.edge = 100.0
	_press(aimed, 2, Vector2.ZERO, Vector2.DOWN)
	assert_near(aimed.player.skill_dir.y, 1.0, 0.001, "standing still: the aim")
	var facing: GameCore = _core()
	facing.player.edge = 100.0
	facing.player.facing = Vector2.LEFT
	_press(facing, 2)
	assert_near(facing.player.skill_dir.x, -1.0, 0.001, "no move and no aim: the facing")


func test_diagonal_movement_gives_a_unit_direction() -> void:
	var core: GameCore = _core(Vector2(300.0, 300.0))
	core.player.edge = 100.0
	_press(core, 3, Vector2(1.0, 1.0))
	assert_near(core.player.skill_dir.length(), 1.0, 0.001, "normalised")
	assert_near(core.player.skill_dir.x, core.player.skill_dir.y, 0.001, "diagonal")


func test_moon_cleave_and_breaking_edge_also_follow_the_move_input() -> void:
	var moon: GameCore = _core(Vector2(300.0, 300.0))
	moon.player.edge = 100.0
	_press(moon, 3, Vector2.UP, Vector2.RIGHT)
	run(moon, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	assert_eq(moon.skill_attacks.size(), 1)
	assert_near(moon.skill_attacks[0].direction.y, -1.0, 0.001, "the projectile flies up")
	var breaking: GameCore = _core(Vector2(300.0, 300.0))
	_after_parry(breaking, 50.0)
	var start: Vector2 = breaking.player.position
	_press(breaking, 1, Vector2.LEFT, Vector2.RIGHT)
	run(breaking, Tuning.BREAKING_EDGE_WINDUP_TICKS)
	assert_near(start.x - breaking.player.position.x, Tuning.BREAKING_EDGE_STEP, 0.01, "the retaliation steps left")


# --- Breaking Edge (1) ---

func test_breaking_edge_needs_a_successful_parry_and_enough_edge() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_press(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "no retaliation without a parry")
	assert_near(core.player.edge, 100.0, 0.001, "Edge untouched")
	_after_parry(core)
	core.player.edge = Tuning.BREAKING_EDGE_EDGE_COST - 1.0
	_press(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "not enough Edge")
	core.player.edge = 50.0
	run(core, Tuning.BREAKING_EDGE_WINDOW_TICKS)
	_press(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "the window has closed")


func test_breaking_edge_spends_edge_and_uses_up_the_window() -> void:
	var core: GameCore = _core()
	_after_parry(core)
	assert_near(core.player.edge, Tuning.EDGE_PER_PARRY, 0.001, "the parry built Edge")
	assert_true(core.snapshot().hud.retaliate_ticks_left > 0, "the HUD can show the window")
	_press(core, 1)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP)
	assert_eq(core.player.skill_id, PlayerState.SKILL_BREAKING_EDGE)
	assert_near(core.player.edge, Tuning.EDGE_PER_PARRY - Tuning.BREAKING_EDGE_EDGE_COST, 0.001, "Edge spent")
	assert_true(event_types(core).has(GameEvent.SKILL_STARTED), "skill_started event")
	assert_eq(core.player.retaliate_ticks, 0, "the window is used up")


func test_breaking_edge_is_fast_and_hits_once_with_strong_posture() -> void:
	var core: GameCore = _core(Vector2(180.0, 88.0), Vector2(240.0, 88.0))
	var start_x: float = core.player.position.x
	_after_parry(core, 50.0)
	_press(core, 1, Vector2.RIGHT)
	var hits: Array[GameEvent] = []
	for i: int in Tuning.BREAKING_EDGE_WINDUP_TICKS + Tuning.BREAKING_EDGE_ACTIVE_TICKS + Tuning.BREAKING_EDGE_RECOVERY_TICKS:
		core.step(input())
		for event: GameEvent in core.last_events:
			if event.type == GameEvent.ATTACK_HIT:
				hits.append(event)
	assert_true(core.player.position.x - start_x >= Tuning.BREAKING_EDGE_STEP - 0.01, "stepped forward")
	assert_eq(hits.size(), 1, "one confirmed hit")
	if hits.size() == 1:
		assert_eq(hits[0].data["skill_id"], PlayerState.SKILL_BREAKING_EDGE)
		assert_true(int(hits[0].data["attack_id"]) > 0, "the hit names its attack")
		assert_eq(int(hits[0].data["damage"]), _armored(Tuning.BREAKING_EDGE_DAMAGE))
	assert_near(core.boss.posture, Tuning.BREAKING_EDGE_POSTURE, 1.5, "strong posture damage")
	assert_true(Tuning.BREAKING_EDGE_WINDUP_TICKS <= 3, "a fast retaliation")


func test_two_retaliations_break_the_boss_and_a_broken_boss_takes_counter_damage() -> void:
	var core: GameCore = _core(Vector2(180.0, 88.0), Vector2(240.0, 88.0))
	for i: int in 2:
		core.player.position = Vector2(180.0, 88.0)
		_after_parry(core, 50.0)
		_press(core, 1, Vector2.RIGHT)
		run(core, _swing_total(Tuning.BREAKING_EDGE_WINDUP_TICKS, Tuning.BREAKING_EDGE_ACTIVE_TICKS, Tuning.BREAKING_EDGE_RECOVERY_TICKS))
	assert_eq(core.boss.state, BossState.STATE_BROKEN, "two retaliations open a posture break")
	var hp_before: int = core.boss.hp
	core.player.position = Vector2(180.0, 88.0)
	_after_parry(core, 50.0)
	_press(core, 1, Vector2.RIGHT)
	run(core, Tuning.BREAKING_EDGE_WINDUP_TICKS)
	assert_eq(hp_before - core.boss.hp, roundi(Tuning.BREAKING_EDGE_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "counter damage in a posture break")


# --- Gale Cut (2) ---

func test_gale_cut_spends_edge_and_starts_the_cooldown() -> void:
	var core: GameCore = _core()
	core.player.edge = Tuning.GALE_CUT_EDGE_COST - 1.0
	_press(core, 2, Vector2.RIGHT)
	assert_false(_in_skill(core), "not enough Edge")
	core.player.edge = Tuning.GALE_CUT_EDGE_COST + 5.0
	_press(core, 2, Vector2.RIGHT)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP)
	assert_near(core.player.edge, 5.0, 0.001, "35 Edge spent")
	assert_eq(core.player.skill_cooldowns[1], Tuning.GALE_CUT_COOLDOWN_TICKS, "cooldown started")
	assert_eq(Tuning.GALE_CUT_COOLDOWN_TICKS, 300)
	assert_eq(Tuning.GALE_CUT_EDGE_COST, 35.0)


func test_gale_cut_covers_about_120_pixels_along_the_direction() -> void:
	var core: GameCore = _core()
	var start: Vector2 = core.player.position
	_gale(core, Vector2.RIGHT)
	assert_near(core.player.position.x - start.x, Tuning.GALE_CUT_DISTANCE, 0.01, "dash distance")
	assert_near(core.player.position.y, start.y, 0.01, "straight")
	assert_near(Tuning.GALE_CUT_SPEED * Tuning.GALE_CUT_ACTIVE_TICKS, Tuning.GALE_CUT_DISTANCE, 0.001, "speed x ticks = distance")


func test_gale_cut_has_no_invulnerability() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_press(core, 2, Vector2.RIGHT)
	for i: int in Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS:
		assert_false(core.player.is_invulnerable(), "vulnerable on tick %d" % i)
		core.step(input())
	var events: Array[GameEvent] = []
	core.player.state = PlayerState.STATE_SKILL_ACTIVE
	assert_true(core.player.take_damage(5, core.tick, events, core.boss.id), "a hit lands during the dash")
	assert_eq(core.player.state, PlayerState.STATE_IDLE, "and stops it")


func test_gale_cut_hits_a_target_inside_the_corridor_once() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(120.0, 88.0))  # in the way
	var hits: Array[GameEvent] = _gale(core)
	assert_eq(hits.size(), 1, "once per target per cast, although the dash overlaps the boss for many ticks")
	if hits.size() == 1:
		assert_eq(hits[0].data["skill_id"], PlayerState.SKILL_GALE_CUT)
		assert_eq(int(hits[0].data["damage"]), _armored(Tuning.GALE_CUT_DAMAGE))
	assert_near(core.boss.posture, Tuning.GALE_CUT_POSTURE, 1.5, "light posture damage")
	assert_true(_clear_of_boss(core), "the player ends outside the boss")


func _clear_of_boss(core: GameCore) -> bool:
	return core.player.position.distance_to(core.boss.position) >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.01


func _inside_arena(core: GameCore) -> bool:
	var low: float = Tuning.ARENA_MARGIN - 0.001
	var high: Vector2 = Tuning.ARENA_SIZE - Vector2(low, low)
	var p: Vector2 = core.player.position
	return p.x >= low and p.y >= low and p.x <= high.x and p.y <= high.y


func test_gale_cut_passes_through_the_boss_during_skill_active() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(130.0, 88.0))
	var boss_start: Vector2 = core.boss.position
	core.player.edge = 100.0
	_press(core, 2, Vector2.RIGHT)
	var min_gap: float = 1000.0
	var min_gap_while_dashing: float = 1000.0
	var hits: int = 0
	for i: int in Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS:
		core.step(input())
		var gap: float = core.player.position.distance_to(core.boss.position)
		if core.player.state == PlayerState.STATE_SKILL_WINDUP:
			assert_true(gap >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.01, "the windup is still solid")
		if core.player.state == PlayerState.STATE_SKILL_ACTIVE:
			min_gap_while_dashing = minf(min_gap_while_dashing, gap)
		min_gap = minf(min_gap, gap)
		hits += event_types(core).count(GameEvent.ATTACK_HIT)
	assert_true(min_gap_while_dashing < Tuning.PLAYER_RADIUS, "the player went through the middle of the boss (gap %s)" % str(min_gap_while_dashing))
	assert_near(core.player.position.x, 40.0 + Tuning.GALE_CUT_DISTANCE, 0.01, "and covered the full dash distance, 120 px")
	assert_true(core.player.position.x > core.boss.position.x, "ending on the far side of the boss")
	assert_eq(hits, 1, "one hit for the whole pass")
	assert_eq(core.boss.position, boss_start, "the boss was not moved")
	assert_true(_clear_of_boss(core), "not left inside the boss")


func test_gale_cut_that_ends_inside_the_boss_is_moved_out() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(150.0, 88.0))  # the dash ends at x=160, 10 px from the centre
	var hits: Array[GameEvent] = _gale(core)
	assert_eq(hits.size(), 1, "still one hit")
	assert_true(_clear_of_boss(core), "pushed out of the boss")
	assert_true(core.player.position.x >= 150.0 + Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS - 0.01, "out on the side the dash was heading")
	assert_true(_inside_arena(core))
	assert_false(core.player.state == PlayerState.STATE_SKILL_ACTIVE, "the dash is over")


func test_gale_cut_ending_inside_a_boss_next_to_a_wall_still_ends_free() -> void:
	var wall: float = Tuning.ARENA_SIZE.x - Tuning.ARENA_MARGIN
	var core: GameCore = _core(Vector2(wall - 122.0, 240.0), Vector2(wall - 12.0, 240.0))  # the dash ends inside the boss, by the wall
	_gale(core)
	assert_true(_clear_of_boss(core), "a free spot was found although the wall blocks the forward side")
	assert_true(_inside_arena(core), "and it is inside the arena")


func test_gale_cut_stops_at_the_wall_even_when_passing_through_the_boss() -> void:
	var wall: float = Tuning.ARENA_SIZE.x - Tuning.ARENA_MARGIN
	var core: GameCore = _core(Vector2(wall - 62.0, 240.0), Vector2(wall - 32.0, 240.0))
	var hits: Array[GameEvent] = _gale(core)
	assert_near(core.player.position.x, wall, 0.01, "stopped by the right wall, 62 px of the 120 px dash")
	assert_eq(hits.size(), 1, "the boss on the way was hit once")
	assert_true(_inside_arena(core))
	assert_true(_clear_of_boss(core))


func test_gale_cut_stops_at_every_wall() -> void:
	var low: float = Tuning.ARENA_MARGIN
	var high: Vector2 = Tuning.ARENA_SIZE - Vector2(low, low)
	var cases: Array = [
		[Vector2.LEFT, Vector2(low + 40.0, 240.0), "x", low],
		[Vector2.RIGHT, Vector2(high.x - 40.0, 240.0), "x", high.x],
		[Vector2.UP, Vector2(400.0, low + 40.0), "y", low],
		[Vector2.DOWN, Vector2(400.0, high.y - 40.0), "y", high.y],
	]
	for case: Array in cases:
		var core: GameCore = _core(case[1])
		_gale(core, case[0])
		var axis: String = case[2]
		assert_near(core.player.position[axis], float(case[3]), 0.01, "stopped by the wall dashing %s" % str(case[0]))
		assert_true(_inside_arena(core), "inside the arena after dashing %s" % str(case[0]))


func test_normal_collision_returns_after_the_dash() -> void:
	var core: GameCore = _core(Vector2(100.0, 88.0), Vector2(150.0, 88.0))
	run(core, 60, input(Vector2.RIGHT))
	assert_true(_clear_of_boss(core), "before the dash the boss is solid")
	core.player.position = Vector2(40.0, 88.0)
	_gale(core, Vector2.RIGHT)
	run(core, Tuning.GALE_CUT_RECOVERY_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	run(core, 60, input(Vector2.LEFT))  # walk back towards the boss from the far side
	assert_true(_clear_of_boss(core), "after the dash the boss is solid again")
	assert_true(core.player.position.x > core.boss.position.x, "still on the far side: no walking through")


func test_interrupted_inside_the_boss_the_player_is_moved_out() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(100.0, 88.0))
	core.player.edge = 100.0
	_press(core, 2, Vector2.RIGHT)
	run(core, Tuning.GALE_CUT_WINDUP_TICKS + 8)  # about x=104, in the middle of the boss
	assert_true(core.player.position.distance_to(core.boss.position) < Tuning.PLAYER_RADIUS, "the player is inside the boss")
	var events: Array[GameEvent] = []
	core.player.take_damage(5, core.tick, events, core.boss.id)
	core.step(input())
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	assert_true(_clear_of_boss(core), "not stuck inside the boss")
	assert_true(_inside_arena(core))


func test_gale_cut_lane_width_boundary() -> void:
	var reach: float = Tuning.BOSS_RADIUS + Tuning.GALE_CUT_LANE_WIDTH * 0.5  # 29 px from the lane centre
	var inside: GameCore = _core(Vector2(40.0, 88.0), Vector2(110.0, 88.0 + reach - 0.5))
	assert_eq(_gale(inside).size(), 1, "just inside the lane edge is hit")
	var outside: GameCore = _core(Vector2(40.0, 88.0), Vector2(110.0, 88.0 + reach + 0.5))
	assert_eq(_gale(outside).size(), 0, "just outside the lane edge is missed")


func test_gale_cut_does_not_hit_what_it_never_travelled_past() -> void:
	var beyond: GameCore = _core(Vector2(40.0, 88.0), Vector2(40.0 + Tuning.GALE_CUT_DISTANCE + Tuning.BOSS_RADIUS + 12.0, 88.0))
	assert_eq(_gale(beyond).size(), 0, "past the end of the corridor")
	var behind: GameCore = _core(Vector2(160.0, 88.0), Vector2(100.0, 88.0))
	assert_eq(_gale(behind, Vector2.RIGHT).size(), 0, "behind the start")


func test_gale_cut_is_stopped_by_the_arena_wall() -> void:
	# Dash up from y=60: the wall at y=8 ends the dash after 52 px, not the planned 120.
	var core: GameCore = _core(Vector2(160.0, 60.0))
	_gale(core, Vector2.UP)
	assert_near(core.player.position.y, Tuning.ARENA_MARGIN, 0.01, "stopped by the wall")


func test_gale_cut_cooldown_blocks_a_second_cast() -> void:
	var core: GameCore = _core()
	_gale(core)
	run(core, Tuning.GALE_CUT_RECOVERY_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	core.player.edge = 100.0
	core.player.position = Vector2(40.0, 88.0)
	_press(core, 2, Vector2.RIGHT)
	assert_false(_in_skill(core), "blocked by the cooldown")
	assert_true(core.snapshot().hud.skill_cooldown_ticks[1] > 0, "the HUD sees the cooldown")
	run(core, Tuning.GALE_CUT_COOLDOWN_TICKS)
	_press(core, 2, Vector2.RIGHT)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP, "available again")


func test_gale_cut_interrupted_in_the_windup_does_not_dash_or_hit() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(120.0, 88.0))
	core.player.edge = 100.0
	_press(core, 2, Vector2.RIGHT)
	var events: Array[GameEvent] = []
	core.player.take_damage(5, core.tick, events, core.boss.id)
	assert_eq(core.player.skill_id, &"", "skill cleared")
	run(core, 40)
	assert_eq(core.boss.hp, Tuning.BOSS_MAX_HP, "nothing was hit")
	assert_eq(core.skill_attacks.size(), 0, "no attack was created")
	assert_near(core.player.edge, 100.0 - Tuning.GALE_CUT_EDGE_COST, 0.001, "the Edge is not refunded")


func test_gale_cut_interrupted_mid_dash_stops_the_corridor() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), FAR)
	core.player.edge = 100.0
	_press(core, 2, Vector2.RIGHT)
	run(core, Tuning.GALE_CUT_WINDUP_TICKS + 5)
	var x: float = core.player.position.x
	var events: Array[GameEvent] = []
	core.player.take_damage(5, core.tick, events, core.boss.id)
	core.step(input())
	assert_near(core.player.position.x, x, 0.01, "the dash stopped")
	assert_eq(core.skill_attacks.size(), 0, "the lane is gone")


# --- Moon Cleave (3) ---

func test_moon_cleave_needs_edge_and_spends_it_on_press() -> void:
	var core: GameCore = _core()
	core.player.edge = Tuning.MOON_CLEAVE_EDGE_COST - 1.0
	_press(core, 3, Vector2.RIGHT)
	assert_false(_in_skill(core), "not enough Edge")
	core.player.edge = Tuning.MOON_CLEAVE_EDGE_COST
	_press(core, 3, Vector2.RIGHT)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP)
	assert_near(core.player.edge, 0.0, 0.001, "the cost is spent")


func test_moon_cleave_holds_then_releases_a_projectile() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	for i: int in Tuning.MOON_CLEAVE_WINDUP_TICKS - 1:
		core.step(input())
		assert_eq(core.skill_attacks.size(), 0, "nothing exists during the hold")
		assert_false(event_types(core).has(GameEvent.SKILL_RELEASED))
	core.step(input())
	assert_eq(core.player.state, PlayerState.STATE_SKILL_ACTIVE)
	assert_true(event_types(core).has(GameEvent.SKILL_RELEASED), "release event")
	assert_eq(core.skill_attacks.size(), 1, "the projectile exists")
	var released: GameEvent = find_event(core, GameEvent.SKILL_RELEASED)
	assert_eq(released.data["skill_id"], PlayerState.SKILL_MOON_CLEAVE)
	assert_eq(released.data["shape"], SkillAttack.SHAPE_PROJECTILE)
	assert_eq(released.data["width"], Tuning.MOON_CLEAVE_WIDTH)
	assert_true(int(released.data["attack_id"]) > 0)


func test_moon_cleave_projectile_travels_at_its_speed_and_expires() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	var attack: SkillAttack = core.skill_attacks[0]
	var start_x: float = attack.position.x
	assert_near(start_x, 40.0 + Tuning.MOON_CLEAVE_SPAWN_OFFSET, 0.01, "spawns in front of the player")
	run(core, 10)
	assert_near(attack.position.x - start_x, 10.0 * Tuning.MOON_CLEAVE_SPEED, 0.01, "4 px per tick")
	var ticks_total: int = ceili(Tuning.MOON_CLEAVE_TRAVEL / Tuning.MOON_CLEAVE_SPEED)
	run(core, ticks_total - 10)
	assert_eq(core.skill_attacks.size(), 0, "gone after its travel distance")
	assert_eq(Tuning.MOON_CLEAVE_TRAVEL, 140.0)
	assert_eq(Tuning.MOON_CLEAVE_SPEED, 4.0)
	assert_eq(Tuning.MOON_CLEAVE_WIDTH, 20.0)


func test_moon_cleave_pierces_and_hits_each_target_once() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(130.0, 88.0))
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	var hits: Array[GameEvent] = _hit_events(core, Tuning.MOON_CLEAVE_WINDUP_TICKS + 60)
	assert_eq(hits.size(), 1, "the boss overlaps the projectile for about a dozen ticks but is hit once")
	if hits.size() == 1:
		assert_eq(hits[0].data["skill_id"], PlayerState.SKILL_MOON_CLEAVE)
		assert_eq(int(hits[0].data["damage"]), _armored(Tuning.MOON_CLEAVE_DAMAGE))
	assert_near(core.boss.posture, Tuning.MOON_CLEAVE_POSTURE, 1.5, "posture damage")


func test_moon_cleave_on_a_broken_boss_is_a_counter() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(130.0, 88.0))
	core.boss.add_posture(Tuning.BOSS_POSTURE_MAX, 1, [])
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS + 40)
	assert_eq(Tuning.BOSS_MAX_HP - core.boss.hp, roundi(Tuning.MOON_CLEAVE_DAMAGE * Tuning.COUNTER_DAMAGE_MULT), "best during a posture break")


func test_moon_cleave_width_and_range_boundaries() -> void:
	var reach: float = Tuning.BOSS_RADIUS + Tuning.MOON_CLEAVE_WIDTH * 0.5  # 30 px
	var start_x: float = 40.0 + Tuning.MOON_CLEAVE_SPAWN_OFFSET
	var cases: Array = [
		["lateral just inside", Vector2(start_x + 80.0, 88.0 + reach - 0.5), 1],
		["lateral just outside", Vector2(start_x + 80.0, 88.0 + reach + 0.5), 0],
		["end of travel, just inside", Vector2(start_x + Tuning.MOON_CLEAVE_TRAVEL + reach - 0.5, 88.0), 1],
		["end of travel, just outside", Vector2(start_x + Tuning.MOON_CLEAVE_TRAVEL + reach + 0.5, 88.0), 0],
		["behind the player", Vector2(start_x - 40.0, 88.0), 0],
	]
	for case: Array in cases:
		var core: GameCore = _core(Vector2(40.0, 88.0), case[1])
		core.player.edge = 100.0
		_press(core, 3, Vector2.RIGHT)
		var hits: Array[GameEvent] = _hit_events(core, Tuning.MOON_CLEAVE_WINDUP_TICKS + 60)
		assert_eq(hits.size(), case[2], String(case[0]))


func test_a_fast_projectile_does_not_tunnel_through_a_target() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(110.0, 88.0))
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	var attack: SkillAttack = core.skill_attacks[0]
	attack.speed = 1000.0  # crosses the whole travel distance in a single tick
	var hits: Array[GameEvent] = _hit_events(core, 2)
	assert_eq(hits.size(), 1, "the swept segment still catches the boss in the middle of the path")
	assert_eq(core.skill_attacks.size(), 0, "and the projectile is done")


func test_segment_circle_test_is_swept() -> void:
	assert_true(SkillAttack.segment_touches_circle(Vector2(0, 0), Vector2(500, 0), Vector2(250, 4), 5.0), "a long segment hits a small circle in the middle")
	assert_false(SkillAttack.segment_touches_circle(Vector2(0, 0), Vector2(500, 0), Vector2(250, 6), 5.0), "and misses it just outside")
	assert_true(SkillAttack.segment_touches_circle(Vector2(0, 0), Vector2(0, 0), Vector2(3, 0), 5.0), "a zero-length segment is a point test")
	assert_false(SkillAttack.segment_touches_circle(Vector2(0, 0), Vector2(100, 0), Vector2(-6, 0), 5.0), "beyond the start end")
	assert_false(SkillAttack.segment_touches_circle(Vector2(0, 0), Vector2(100, 0), Vector2(106, 0), 5.0), "beyond the far end")


func test_the_projectile_outlives_an_interrupted_player() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(150.0, 88.0))
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	assert_eq(core.skill_attacks.size(), 1)
	var events: Array[GameEvent] = []
	core.player.take_damage(10, core.tick, events, core.boss.id)  # knocked out of the release pose
	assert_eq(core.player.state, PlayerState.STATE_IDLE)
	var hits: Array[GameEvent] = _hit_events(core, 60)
	assert_eq(hits.size(), 1, "the released projectile still lands")


func test_an_interrupted_hold_spawns_nothing() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(130.0, 88.0))
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS - 5)
	var events: Array[GameEvent] = []
	core.player.take_damage(10, core.tick, events, core.boss.id)
	var released: bool = false
	for i: int in 120:
		core.step(input())
		released = released or event_types(core).has(GameEvent.SKILL_RELEASED)
	assert_false(released, "no release event")
	assert_eq(core.skill_attacks.size(), 0, "no projectile")
	assert_eq(core.boss.hp, Tuning.BOSS_MAX_HP, "nothing hit")
	assert_near(core.player.edge, 100.0 - Tuning.MOON_CLEAVE_EDGE_COST, 0.001, "the Edge is not refunded")


func test_moon_cleave_is_the_biggest_hit_and_the_longest_commitment() -> void:
	assert_true(Tuning.MOON_CLEAVE_DAMAGE > Tuning.BREAKING_EDGE_DAMAGE and Tuning.BREAKING_EDGE_DAMAGE > Tuning.GALE_CUT_DAMAGE, "health damage order")
	assert_true(Tuning.MOON_CLEAVE_EDGE_COST > Tuning.GALE_CUT_EDGE_COST and Tuning.GALE_CUT_EDGE_COST > Tuning.BREAKING_EDGE_EDGE_COST, "Edge cost order")
	assert_true(Tuning.MOON_CLEAVE_RECOVERY_TICKS > Tuning.BREAKING_EDGE_RECOVERY_TICKS and Tuning.MOON_CLEAVE_RECOVERY_TICKS > Tuning.GALE_CUT_RECOVERY_TICKS, "longest recovery")


func test_moon_cleave_recovery_cannot_be_cancelled() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS + Tuning.MOON_CLEAVE_ACTIVE_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_RECOVERY)
	core.step(input(Vector2.ZERO, true, false, false))
	core.step(input(Vector2.ZERO, false, true, false))
	core.step(input(Vector2.ZERO, false, false, true))
	assert_eq(core.player.state, PlayerState.STATE_SKILL_RECOVERY, "committed")
	run(core, Tuning.MOON_CLEAVE_RECOVERY_TICKS)
	assert_eq(core.player.state, PlayerState.STATE_IDLE)


# --- snapshots and events ---

func test_snapshot_exposes_the_dash_lane() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	_press(core, 2, Vector2.RIGHT)
	run(core, Tuning.GALE_CUT_WINDUP_TICKS)
	var released: GameEvent = find_event(core, GameEvent.SKILL_RELEASED)
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.skill_attacks.size(), 1)
	var lane: Snapshots.SkillAttackSnapshot = snap.skill_attacks[0]
	assert_eq(lane.id, int(released.data["attack_id"]), "event and snapshot share the id")
	assert_eq(lane.skill_id, PlayerState.SKILL_GALE_CUT)
	assert_eq(lane.shape, &"lane")
	assert_eq(lane.owner_id, core.player.id)
	assert_near(lane.direction.x, 1.0, 0.001)
	assert_near(lane.start.x, 40.0, 0.01, "lane start")
	assert_near(lane.end.x, 40.0 + Tuning.GALE_CUT_DISTANCE, 0.01, "lane end")
	assert_eq(lane.width, Tuning.GALE_CUT_LANE_WIDTH)
	assert_true(lane.ticks_left > 0 and lane.end_tick >= lane.start_tick, "lifetime")
	run(core, 5)
	assert_near(core.snapshot().skill_attacks[0].position.x, 40.0 + 5.0 * Tuning.GALE_CUT_SPEED, 0.01, "the head follows the player")
	run(core, Tuning.GALE_CUT_ACTIVE_TICKS)
	assert_eq(core.snapshot().skill_attacks.size(), 0, "gone when the dash ends")


func test_snapshot_exposes_the_projectile_and_its_hits() -> void:
	var core: GameCore = _core(Vector2(40.0, 88.0), Vector2(130.0, 88.0))
	core.player.edge = 100.0
	_press(core, 3, Vector2.RIGHT)
	run(core, Tuning.MOON_CLEAVE_WINDUP_TICKS)
	var p: Snapshots.SkillAttackSnapshot = core.snapshot().skill_attacks[0]
	assert_eq(p.shape, &"projectile")
	assert_eq(p.width, Tuning.MOON_CLEAVE_WIDTH)
	assert_near(p.end.x - p.start.x, Tuning.MOON_CLEAVE_TRAVEL, 0.01, "endpoints span the travel distance")
	assert_eq(p.hit_target_ids.size(), 0, "nothing hit yet")
	run(core, 20)
	var later: Snapshots.SkillAttackSnapshot = core.snapshot().skill_attacks[0]
	assert_eq(later.hit_target_ids, [core.boss.id] as Array[int], "the hit target is listed")
	assert_true(later.ticks_left < p.ticks_left, "lifetime counts down")


func test_snapshot_exposes_the_melee_arc_and_the_skill_state() -> void:
	var core: GameCore = _core(Vector2(180.0, 88.0), Vector2(240.0, 88.0))
	_after_parry(core, 50.0)
	_press(core, 1, Vector2.RIGHT)
	assert_eq(core.snapshot().player.skill_id, PlayerState.SKILL_BREAKING_EDGE)
	run(core, Tuning.BREAKING_EDGE_WINDUP_TICKS)
	var arc: Snapshots.SkillAttackSnapshot = core.snapshot().skill_attacks[0]
	assert_eq(arc.shape, &"arc")
	assert_eq(arc.size, Tuning.BREAKING_EDGE_RANGE)
	assert_true(arc.half_angle > 0.0)
	assert_eq(core.snapshot().entities[0].skill_id, &"", "the boss has none")


# --- shared rules ---

func test_unknown_slots_do_nothing() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	for slot: int in [0, 4, -1]:
		_press(core, slot)
		assert_eq(core.player.state, PlayerState.STATE_IDLE, "slot %d" % slot)


func test_skills_cancel_the_recovery_of_a_normal_swing_and_reset_the_combo() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	core.step(input(Vector2.ZERO, false, false, true))
	var guard: int = 0
	while core.player.state != PlayerState.STATE_ATTACK_RECOVERY and guard < 50:
		core.step(input())
		guard += 1
	assert_eq(core.player.state, PlayerState.STATE_ATTACK_RECOVERY)
	_press(core, 2, Vector2.RIGHT)
	assert_eq(core.player.state, PlayerState.STATE_SKILL_WINDUP, "a skill cancels the swing's recovery")
	assert_eq(core.player.combo_index, 1, "and resets the combo")


func test_skill_cannot_start_during_a_parry_or_when_dead() -> void:
	var core: GameCore = _core()
	core.player.edge = 100.0
	core.step(input(Vector2.ZERO, false, true))
	assert_eq(core.player.state, PlayerState.STATE_PARRY)
	_press(core, 3)
	assert_eq(core.player.state, PlayerState.STATE_PARRY, "the parry window is not cancelled by a skill")
	var dead: GameCore = _core()
	dead.player.edge = 100.0
	var events: Array[GameEvent] = []
	dead.player.take_damage(Tuning.PLAYER_MAX_HP, dead.tick, events, dead.boss.id)
	_press(dead, 3)
	assert_eq(dead.player.state, PlayerState.STATE_DEAD)
