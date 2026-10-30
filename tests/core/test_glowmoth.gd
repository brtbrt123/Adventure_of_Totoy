extends "res://tests/test_case.gd"
## The Glowmoth's orb (Tuning.MOBS[glowmoth].attack moth_orb, core/mob_field.gd _fire / _step_projectiles): a red lane warns of the path
## (as wide as the orb's hit), then a real projectile flies along it until it hits the hero, a prop or its range. The moth's death or an
## encounter reset removes it. Built on the glade with its Stag replaced by one moth.

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")
const Obstacle := preload("res://core/obstacle.gd")

const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]


func _core() -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SceneDefs.GLADE_LAYERED)
	core.set_story_flags(ARMED)
	var enc: MobField.Encounter = core.mobs.encounters[0]
	var home: Vector2 = enc.mobs[0].home
	enc.mobs.clear()
	var moth: Mob = Mob.new()
	moth.setup(950, &"glowmoth", enc.id, home, 0)
	enc.mobs.append(moth)
	core.obstacles.clear()
	core.player.hp = 9999
	return core


func _moth(core: ExploreCore) -> Mob:
	return core.mobs.encounters[0].mobs[0]


func _events(core: ExploreCore, type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in core.last_events:
		if e.type == type:
			out.append(e)
	return out


## Steps with the hero held at `hero` until the moth fires; returns the fired event (null after `limit` ticks).
func _until_fired(core: ExploreCore, hero: Vector2, limit: int = 300) -> GameEvent:
	for i: int in limit:
		core.player.position = hero
		core.step(InputFrame.new())
		var fired: Array[GameEvent] = _events(core, GameEvent.MOB_PROJECTILE_FIRED)
		if not fired.is_empty():
			return fired[0]
	return null


## Steps with the hero held at `hero` until the orb ends; returns the ended event.
func _until_ended(core: ExploreCore, hero: Vector2, limit: int = 200) -> GameEvent:
	for i: int in limit:
		core.player.position = hero
		core.step(InputFrame.new())
		var ended: Array[GameEvent] = _events(core, GameEvent.MOB_PROJECTILE_ENDED)
		if not ended.is_empty():
			return ended[0]
	return null


func test_the_windup_warns_with_a_red_lane_as_wide_as_the_orb() -> void:
	var core: ExploreCore = _core()
	var moth: Mob = _moth(core)
	var hero: Vector2 = moth.position + Vector2(-80, 0)
	var told: GameEvent = null
	for i: int in 300:
		core.player.position = hero
		core.step(InputFrame.new())
		var found: Array[GameEvent] = _events(core, GameEvent.ATTACK_TELEGRAPHED)
		if not found.is_empty():
			told = found[0]
			break
	assert_true(told != null and told.data["attack"] == &"moth_orb" and told.data["kind"] == &"red", "a red warning")
	assert_eq(moth.telegraph.shape, Telegraph.SHAPE_LINE, "a lane")
	assert_near(moth.telegraph.size, 140.0, 0.001, "as long as the orb flies")
	assert_near(moth.telegraph.width, 8.0, 0.001, "as wide as the orb (2 x radius 4)")


func test_the_orb_is_a_real_projectile_in_the_snapshot_and_the_lane_goes_away() -> void:
	var core: ExploreCore = _core()
	var moth: Mob = _moth(core)
	var hero: Vector2 = moth.position + Vector2(-120, 0)
	var fired: GameEvent = _until_fired(core, hero)
	assert_true(fired != null, "it fires")
	assert_true(moth.all_telegraphs().is_empty(), "the warning ends with the release")
	assert_eq(core.mobs.projectile_views().size(), 1, "one orb in flight")
	core.player.position = hero
	core.step(InputFrame.new())
	var view: Dictionary = core.snapshot().mob_projectiles[0]
	assert_eq(view["visual"], &"glowmoth_orb", "drawn as the approved orb")
	assert_eq(int(view["owner_id"]), moth.id, "owned by the moth")
	assert_true(Vector2(view["position"]).distance_to(moth.position) > 2.0, "and it moves")


func test_the_orb_hits_a_hero_on_its_path_once() -> void:
	var core: ExploreCore = _core()
	var moth: Mob = _moth(core)
	var hero: Vector2 = moth.position + Vector2(-80, 0)
	_until_fired(core, hero)
	var hp: int = core.player.hp
	var ended: GameEvent = _until_ended(core, hero)
	assert_true(ended != null and ended.data["reason"] == &"hit", "it ends on the hero")
	assert_eq(hp - core.player.hp, 6, "six damage, once")
	assert_eq(core.mobs.projectile_views().size(), 0, "gone")


func test_the_orb_never_hits_outside_the_warned_lane() -> void:
	var core: ExploreCore = _core()
	var moth: Mob = _moth(core)
	var hero: Vector2 = moth.position + Vector2(-80, 0)
	var fired: GameEvent = _until_fired(core, hero)
	var aim: Vector2 = fired.data["direction"]
	var side: Vector2 = aim.orthogonal()
	var outside: Vector2 = moth.position + aim * 80.0 + side * (4.0 + Tuning.PLAYER_RADIUS + 1.0)
	var hp: int = core.player.hp
	var ended: GameEvent = _until_ended(core, outside)
	assert_true(ended != null and ended.data["reason"] == &"range", "it flies past to its full range")
	assert_eq(core.player.hp, hp, "one pixel outside the lane is safe")
	assert_near(Vector2(ended.data["position"]).distance_to(fired.data["position"]), 140.0, 3.0, "and stops 140 px from where it left")


func test_a_prop_stops_the_orb() -> void:
	var core: ExploreCore = _core()
	var moth: Mob = _moth(core)
	var hero: Vector2 = moth.position + Vector2(-110, 0)
	var fired: GameEvent = _until_fired(core, hero)
	var post: Obstacle = Obstacle.new()
	post.center = moth.position + Vector2(fired.data["direction"]) * 50.0
	post.radius = 3.0
	core.obstacles.append(post)
	var hp: int = core.player.hp
	var ended: GameEvent = _until_ended(core, hero)
	assert_true(ended != null and ended.data["reason"] == &"prop", "a thin post stops it (%s)" % [ended.data["reason"] if ended else "none"])
	assert_eq(core.player.hp, hp, "the hero behind it is safe")


func test_the_moths_death_removes_its_orb() -> void:
	var core: ExploreCore = _core()
	var moth: Mob = _moth(core)
	var hero: Vector2 = moth.position + Vector2(-110, 0)
	_until_fired(core, hero)
	var events: Array[GameEvent] = []
	core.mobs.hit_mob(core, core.mobs.encounters[0], moth, 999.0, {}, events)
	var reasons: Array = []
	for e: GameEvent in events:
		if e.type == GameEvent.MOB_PROJECTILE_ENDED:
			reasons.append(e.data["reason"])
	assert_eq(reasons, [&"owner"], "ended because its moth died")
	assert_eq(core.mobs.projectile_views().size(), 0, "no orb left")


func test_a_reset_removes_orbs_in_flight() -> void:
	var core: ExploreCore = _core()
	var moth: Mob = _moth(core)
	_until_fired(core, moth.position + Vector2(-110, 0))
	core.mobs.reset_encounter(core.mobs.encounters[0], core.tick, &"defeat", [] as Array[GameEvent])
	assert_eq(core.mobs.projectile_views().size(), 0, "none after a reset")


func test_the_stags_moths_shoot_orbs_and_lose_them_with_the_stag() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.GLADE_LAYERED)
	core.set_story_flags(ARMED)
	core.player.hp = 99999
	var stag: Mob = core.mobs.encounters[0].mobs[0]
	stag.attack_index = 3
	stag.summon_ready_tick = 0
	var hero: Vector2 = stag.position + Vector2(-90, 10)
	var flying: bool = false
	for i: int in 900:
		core.player.position = hero
		core.step(InputFrame.new())
		if not core.mobs.projectile_views().is_empty():
			flying = true
			break
	assert_true(flying, "a summoned moth fired an orb")
	var events: Array[GameEvent] = []
	core.mobs.hit_mob(core, core.mobs.encounters[0], stag, 9999.0, {}, events)
	assert_eq(core.mobs.projectile_views().size(), 0, "the Stag's fall takes its moths' orbs")
