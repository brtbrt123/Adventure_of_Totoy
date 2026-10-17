extends "res://tests/test_case.gd"
## The red_shards beam leaves the boss's chest core: aim, warning and damage all start at one locked muzzle.

const Snapshots := preload("res://core/snapshots.gd")

const PLAYER_AT: Vector2 = Vector2(160.0, 88.0)


func _shards() -> Array:
	var core: GameCore = GameCore.new()
	var hit_tick: int = begin_attack(core, BossState.ATTACK_SHARDS, PLAYER_AT)
	return [core, hit_tick]


func _muzzle(core: GameCore) -> Vector2:
	return core.boss.position + Tuning.SHARDS_ORIGIN_OFFSET


func test_all_three_lines_start_at_the_chest_muzzle() -> void:
	var made: Array = _shards()
	var core: GameCore = made[0]
	assert_eq(core.boss.telegraphs.size(), 3)
	for telegraph: Telegraph in core.boss.telegraphs:
		assert_eq(telegraph.center, _muzzle(core), "the line starts at the chest, not at the feet")
		assert_eq(telegraph.muzzle, _muzzle(core), "and reports it as its muzzle")
		assert_true(telegraph.center != core.boss.position, "no longer the boss position")
	assert_true(Tuning.SHARDS_ORIGIN_OFFSET.y < 0.0, "the muzzle is above the feet")


func test_the_beam_is_aimed_from_the_muzzle_at_the_player() -> void:
	var made: Array = _shards()
	var core: GameCore = made[0]
	var expected: Vector2 = (PLAYER_AT - _muzzle(core)).normalized()
	var middle: Telegraph = core.boss.telegraphs[1]
	assert_near(middle.direction.x, expected.x, 0.0001, "the middle line points from the chest at the player")
	assert_near(middle.direction.y, expected.y, 0.0001)
	assert_near(absf(core.boss.telegraphs[0].direction.angle_to(middle.direction)), deg_to_rad(Tuning.SHARDS_SPREAD_DEG), 0.0001, "side lines keep the spread")
	assert_near(absf(core.boss.telegraphs[2].direction.angle_to(middle.direction)), deg_to_rad(Tuning.SHARDS_SPREAD_DEG), 0.0001)


func test_the_muzzle_and_aim_stay_locked_through_windup_and_strike() -> void:
	var made: Array = _shards()
	var core: GameCore = made[0]
	var hit_tick: int = made[1]
	var centers: Array[Vector2] = []
	var directions: Array[Vector2] = []
	for telegraph: Telegraph in core.boss.telegraphs:
		centers.append(telegraph.center)
		directions.append(telegraph.direction)
	var end_tick: int = core.boss.telegraphs[0].end_tick
	while core.tick <= end_tick:
		core.step(input(Vector2.UP))  # the player runs around the whole time
		for i: int in core.boss.telegraphs.size():
			assert_eq(core.boss.telegraphs[i].center, centers[i], "line %d origin never moves" % i)
			assert_eq(core.boss.telegraphs[i].direction, directions[i], "line %d aim never changes" % i)
		var snap: Snapshots.GameSnapshot = core.snapshot()
		for t: Snapshots.TelegraphSnapshot in snap.telegraphs:
			assert_eq(t.muzzle, centers[0], "the snapshot reports the same muzzle")
	assert_true(hit_tick > 0)


func test_damage_starts_at_the_chest_not_the_feet() -> void:
	var made: Array = _shards()
	var core: GameCore = made[0]
	var legacy: Telegraph = Telegraph.new()  # the old geometry: one line from the feet straight at the player
	legacy.shape = Telegraph.SHAPE_LINE
	legacy.center = core.boss.position
	legacy.direction = (PLAYER_AT - core.boss.position).normalized()
	legacy.size = Tuning.SHARDS_LENGTH
	legacy.width = Tuning.SHARDS_WIDTH
	# Ground on the upper side line of the chest fan, 45 px from the muzzle: the feet line never covered it.
	var upper: Telegraph = core.boss.telegraphs[0]
	for telegraph: Telegraph in core.boss.telegraphs:
		if telegraph.direction.y < upper.direction.y:
			upper = telegraph
	var spot: Vector2 = upper.center + upper.direction * 45.0
	assert_true(spot.distance_to(core.boss.position) >= Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS, "the spot is outside the solid boss")
	assert_false(legacy.overlaps_circle(spot, Tuning.PLAYER_RADIUS), "the old feet-origin beam did not cover it")
	assert_true(upper.overlaps_circle(spot, Tuning.PLAYER_RADIUS), "the chest beam does")
	var end_tick: int = upper.end_tick
	core.player.position = spot
	run_to_tick(core, end_tick + 1)
	assert_true(core.player.hp < Tuning.PLAYER_MAX_HP, "so the player standing there is hit: the damage capsule starts at the chest")


func test_the_damage_follows_the_chest_line() -> void:
	var made: Array = _shards()
	var core: GameCore = made[0]
	var middle: Telegraph = core.boss.telegraphs[1]
	var end_tick: int = core.boss.telegraphs[0].end_tick
	core.player.position = middle.center + middle.direction * 70.0
	run_to_tick(core, end_tick + 1)
	assert_true(core.player.hp < Tuning.PLAYER_MAX_HP, "standing on the chest line is hit")


func test_other_attacks_keep_the_boss_position_as_their_muzzle() -> void:
	var core: GameCore = GameCore.new()
	begin_attack(core, BossState.ATTACK_SWEEP, PLAYER_AT)
	assert_eq(core.boss.telegraphs[0].muzzle, core.boss.position, "a sweep does not use the chest")
	assert_eq(core.boss.telegraphs[0].center, core.boss.position)
