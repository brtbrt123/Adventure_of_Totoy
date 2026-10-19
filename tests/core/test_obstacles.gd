extends "res://tests/test_case.gd"
## The solid props of the ruins arena: layout validity, blocking, sliding, no tunnelling, determinism, snapshots.

const Obstacle := preload("res://core/obstacle.gd")
const ArenaLayout := preload("res://core/arena_layout.gd")
const Snapshots := preload("res://core/snapshots.gd")


func _pillar(at: Vector2, radius: float = 11.0) -> Obstacle:
	var o: Obstacle = Obstacle.new()
	o.id = 1
	o.visual_id = &"prop_ruins_1"
	o.feet = at + Vector2(0.0, 7.0)
	o.center = at
	o.radius = radius
	return o


## A core with exactly one pillar and a pinned boss far away.
func _core_with(pillar_at: Vector2, player_at: Vector2) -> GameCore:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.obstacles.append(_pillar(pillar_at))
	core.boss.state = BossState.STATE_RECOVER
	core.boss._recover_ticks = 1000000
	core.boss.position = Vector2(700.0, 400.0)
	core.player.position = player_at
	return core


func _overlaps(core: GameCore, point: Vector2, radius: float) -> bool:
	for o: Obstacle in core.obstacles:
		if point.distance_to(o.center) < o.radius + radius - 0.01:
			return true
	return false


# --- layout ---

func test_the_layout_is_valid() -> void:
	var core: GameCore = GameCore.new()
	assert_true(core.obstacles.size() > 20, "the ruins have a good number of solid props (%d)" % core.obstacles.size())
	var low: float = Tuning.ARENA_MARGIN
	var high: Vector2 = Tuning.ARENA_SIZE - Vector2(low, low)
	var ids: Dictionary = {}
	for o: Obstacle in core.obstacles:
		assert_false(ids.has(o.id), "unique id %d" % o.id)
		ids[o.id] = true
		assert_true(o.radius > 0.0 and o.visual_scale > 0.0, "obstacle %d has a size" % o.id)
		assert_true(o.center.x >= low - o.radius and o.center.x <= high.x + o.radius and o.center.y >= low - o.radius and o.center.y <= high.y + o.radius, "obstacle %d is in the arena" % o.id)
	assert_true(ArenaLayout.build().size() == core.obstacles.size(), "building the layout again gives the same list")


func test_both_spawn_points_are_free() -> void:
	var core: GameCore = GameCore.new()
	assert_false(_overlaps(core, Tuning.PLAYER_START, Tuning.PLAYER_RADIUS), "the player does not spawn inside a prop")
	assert_false(_overlaps(core, Tuning.BOSS_START, Tuning.BOSS_RADIUS), "the boss does not spawn inside a prop")
	assert_eq(core.push_out_of_obstacles(Tuning.PLAYER_START, Tuning.PLAYER_RADIUS), Tuning.PLAYER_START, "nothing moves them at the first tick")
	var again: GameCore = GameCore.new()  # a restart builds a fresh core
	assert_eq(again.player.position, Tuning.PLAYER_START)
	assert_false(_overlaps(again, again.boss.position, Tuning.BOSS_RADIUS))
	assert_true(Tuning.PLAYER_START.distance_to(Tuning.BOSS_START) > 100.0, "they start apart")


func test_the_altar_is_one_sprite_with_three_colliders() -> void:
	var core: GameCore = GameCore.new()
	var altar_sprites: int = 0
	var altar_colliders: int = 0
	for o: Obstacle in core.obstacles:
		if o.feet == Vector2(ArenaLayout.ALTAR[1], ArenaLayout.ALTAR[2]):
			altar_colliders += 1
			if o.visual_id != &"":
				altar_sprites += 1
	assert_eq(altar_sprites, 1, "drawn once")
	assert_eq(altar_colliders, 3, "blocked along its base")


# --- blocking and sliding ---

func test_a_pillar_blocks_a_direct_approach() -> void:
	var core: GameCore = _core_with(Vector2(400.0, 250.0), Vector2(340.0, 250.0))
	run(core, 200, input(Vector2.RIGHT))
	var reach: float = 11.0 + Tuning.PLAYER_RADIUS
	assert_near(core.player.position.x, 400.0 - reach, 0.6, "stopped at the pillar's edge")
	assert_true(core.player.position.x < 400.0, "never got past it")


func test_walking_diagonally_into_a_pillar_slides_around_it() -> void:
	var core: GameCore = _core_with(Vector2(400.0, 250.0), Vector2(340.0, 238.0))  # the line of travel misses the centre by about 5 px
	var reach: float = 11.0 + Tuning.PLAYER_RADIUS
	for i: int in 500:
		core.step(input(Vector2(1.0, 0.2)))
		assert_false(_overlaps(core, core.player.position, Tuning.PLAYER_RADIUS), "never inside the pillar")
	assert_true(core.player.position.x > 400.0 + reach, "slid past the pillar and kept going (x=%s)" % str(core.player.position.x))


func test_the_boss_is_blocked_too() -> void:
	var core: GameCore = _core_with(Vector2(560.0, 250.0), Vector2(100.0, 250.0))
	core.boss.state = BossState.STATE_IDLE
	core.boss.cooldown = 1000000
	core.boss.position = Vector2(700.0, 250.0)
	for i: int in 600:
		core.step(input())
		assert_false(_overlaps(core, core.boss.position, Tuning.BOSS_RADIUS), "the boss is never inside the pillar")
	assert_true(core.boss.position.x >= 560.0 + 11.0 + Tuning.BOSS_RADIUS - 1.0, "it walked towards the player and stopped at the pillar")


# --- high speed: no tunnelling ---

func test_a_huge_step_cannot_jump_over_a_pillar() -> void:
	var core: GameCore = _core_with(Vector2(400.0, 250.0), Vector2(100.0, 250.0))
	var end: Vector2 = core.move_resolved(Vector2(300.0, 250.0), Vector2(520.0, 250.0), Tuning.PLAYER_RADIUS)
	assert_true(end.x < 400.0, "a 220 px move ends on this side of the pillar (x=%s)" % str(end.x))
	assert_false(_overlaps(core, end, Tuning.PLAYER_RADIUS))


func test_a_dash_into_a_pillar_stops_at_it() -> void:
	var core: GameCore = _core_with(Vector2(400.0, 250.0), Vector2(330.0, 250.0))
	core.step(input(Vector2.RIGHT, true))
	for i: int in 12:
		core.step(input())
		assert_false(_overlaps(core, core.player.position, Tuning.PLAYER_RADIUS), "never inside the pillar during the dash")
	assert_true(core.player.position.x < 400.0, "the dash did not carry the player through")


func test_gale_cut_is_stopped_by_a_pillar_but_still_passes_through_the_boss() -> void:
	var core: GameCore = _core_with(Vector2(400.0, 250.0), Vector2(300.0, 250.0))
	core.player.edge = 100.0
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 2
	frame.move = Vector2.RIGHT
	core.step(frame)
	run(core, Tuning.GALE_CUT_WINDUP_TICKS + Tuning.GALE_CUT_ACTIVE_TICKS)
	assert_true(core.player.position.x < 400.0, "the dash corridor ends at the pillar")
	assert_false(_overlaps(core, core.player.position, Tuning.PLAYER_RADIUS))


func test_a_charge_cannot_pass_through_a_pillar() -> void:
	var core: GameCore = GameCore.new()
	core.obstacles.clear()
	core.obstacles.append(_pillar(Vector2(400.0, 250.0)))
	core.boss.position = Vector2(560.0, 250.0)
	core.boss.phase = 2
	core.player.position = Vector2(260.0, 250.0)
	core.boss.next_attack_override = BossState.ATTACK_CHARGE
	core.boss.cooldown = 1
	var worst: float = 1000.0
	for i: int in 200:
		core.step(input())
		worst = minf(worst, core.boss.position.distance_to(core.obstacles[0].center) - 11.0 - Tuning.BOSS_RADIUS)
	assert_true(worst >= -0.5, "the charging boss never overlapped the pillar (closest %s)" % str(worst))
	assert_true(core.boss.position.x > 400.0, "and it stayed on its own side")


# --- determinism and a long soak ---

func _weave(core: GameCore, ticks: int) -> Array:
	var trail: Array = []
	for i: int in ticks:
		var move: Vector2 = Vector2(sin(i * 0.021), cos(i * 0.017))
		var frame: InputFrame = input(move, i % 90 == 0, false, i % 25 == 0)
		core.step(frame)
		trail.append([core.player.position, core.boss.position, core.player.hp])
	return trail


func test_the_simulation_with_props_is_deterministic() -> void:
	var a: GameCore = GameCore.new(5)
	var b: GameCore = GameCore.new(5)
	var ta: Array = _weave(a, 900)
	var tb: Array = _weave(b, 900)
	assert_eq(ta.size(), tb.size())
	var same: bool = true
	for i: int in ta.size():
		if ta[i] != tb[i]:
			same = false
			break
	assert_true(same, "identical inputs give identical positions and health")


func test_nobody_is_ever_inside_a_prop_in_a_long_fight() -> void:
	var core: GameCore = GameCore.new(9)
	core.player.hp = 100000  # keep the fight going
	var inside: int = 0
	for i: int in 2400:
		var move: Vector2 = Vector2(sin(i * 0.013) + 0.3, cos(i * 0.011))
		core.step(input(move, i % 70 == 0, false, i % 20 == 0))
		if _overlaps(core, core.player.position, Tuning.PLAYER_RADIUS) or _overlaps(core, core.boss.position, Tuning.BOSS_RADIUS):
			inside += 1
	assert_eq(inside, 0, "ticks with a body inside a prop")


# --- snapshots ---

func test_the_snapshot_lists_the_same_props() -> void:
	var core: GameCore = GameCore.new()
	var snap: Snapshots.GameSnapshot = core.snapshot()
	assert_eq(snap.obstacles.size(), core.obstacles.size())
	for i: int in snap.obstacles.size():
		var s: Snapshots.ObstacleSnapshot = snap.obstacles[i]
		var o: Obstacle = core.obstacles[i]
		assert_eq(s.id, o.id)
		assert_eq(s.visual_id, o.visual_id)
		assert_eq(s.feet, o.feet)
		assert_eq(s.center, o.center)
		assert_eq(s.radius, o.radius)
		assert_eq(s.visual_scale, o.visual_scale)
