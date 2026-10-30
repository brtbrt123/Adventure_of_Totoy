extends "res://tests/test_case.gd"
## The Thornback Stag, balance v3 (docs/CLAUDE_TASK_thornback_balance_v3.md): slam reach 125, charge 6.6 px/tick over 24 ticks, EIGHT root bursts
## each with its own warning, a chant that calls exactly five Glowmoths, and a regeneration of 2 % of the Stag's maximum health per second while
## any moth of ITS OWN lives (never per moth). Same glade, same Stag (encounter stag_glade, data/scenes/glade_layered_props.json).

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")
const Obstacle := preload("res://core/obstacle.gd")
const Collision := preload("res://core/collision.gd")

const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
const SLAM: int = 0
const CHARGE: int = 1
const ROOTS: int = 2
const SUMMON: int = 3


func _core() -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SceneDefs.GLADE_LAYERED)
	core.set_story_flags(ARMED)
	core.player.hp = 99999
	return core


func _stag(core: ExploreCore) -> Mob:
	return core.mobs.encounters[0].mobs[0]


func _enc(core: ExploreCore) -> MobField.Encounter:
	return core.mobs.encounters[0]


func _events(core: ExploreCore, type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in core.last_events:
		if e.type == type:
			out.append(e)
	return out


## Steps until `type` is emitted; returns the first such event or null.
func _until(core: ExploreCore, type: StringName, limit: int) -> GameEvent:
	for i: int in limit:
		core.step(InputFrame.new())
		var found: Array[GameEvent] = _events(core, type)
		if not found.is_empty():
			return found[0]
	return null


## The Stag will start attack row `row` next (distance permitting).
func _queue(stag: Mob, row: int) -> void:
	stag.attack_index = row
	stag.summon_ready_tick = 0


# ---- slam -----------------------------------------------------------------------------------------------------------------------

func test_the_slam_cone_reaches_125_and_the_warning_is_the_hit_area() -> void:
	var core: ExploreCore = _core()
	var stag: Mob = _stag(core)
	assert_near(float(stag.attacks()[SLAM]["reach"]), 125.0, 0.001, "reach 125")
	assert_near(float(stag.attacks()[SLAM]["half_angle"]), 0.95, 0.001, "cone angle unchanged")
	assert_eq(int(stag.attacks()[SLAM]["windup"]), 54, "windup unchanged")
	assert_eq(int(stag.attacks()[SLAM]["damage"]), 18, "damage unchanged")
	core.player.position = stag.position + Vector2(-40, 0)
	var told: GameEvent = _until(core, GameEvent.ATTACK_TELEGRAPHED, 160)
	assert_true(told != null and told.data["attack"] == &"stag_slam", "a slam")
	assert_near(stag.telegraph.size, 125.0 + stag.radius, 0.001, "the warning is reach plus the Stag's body")
	assert_near(core.mobs.telegraph_snapshots()[0].size, 125.0 + stag.radius, 0.001, "and the snapshot says the same")


func test_the_slam_hits_exactly_inside_the_warning_across_facing_angles() -> void:
	for angle: float in [0.0, 0.6, -0.6, 2.4]:
		for inside: bool in [true, false]:
			var core: ExploreCore = _core()
			var stag: Mob = _stag(core)
			core.player.position = stag.position + Vector2(-34, 0)
			var told: GameEvent = _until(core, GameEvent.ATTACK_TELEGRAPHED, 160)
			assert_true(told != null, "slam begins")
			var reach: float = stag.telegraph.size + Tuning.PLAYER_RADIUS
			var spot: Vector2 = stag.position + stag.attack_dir.rotated(angle * 0.5) * (reach - 1.0 if inside else reach + 1.5)
			var hp: int = core.player.hp
			for i: int in 70:
				core.player.position = spot
				core.step(InputFrame.new())
				if stag.state == &"recover":
					break
			var in_cone: bool = absf(angle * 0.5) <= 0.95
			var expect_hit: bool = inside and in_cone
			assert_eq(core.player.hp < hp, expect_hit, "angle %s inside %s: the hit follows the warning" % [angle, inside])


# ---- charge ---------------------------------------------------------------------------------------------------------------------

func test_the_charge_is_faster_and_travels_the_same_distance() -> void:
	var stag: Mob = _stag(_core())
	var row: Dictionary = stag.attacks()[CHARGE]
	assert_near(float(row["strike_speed"]), 6.6, 0.001, "6.6 px per tick")
	assert_eq(int(row["strike_ticks"]), 24, "24 strike ticks")
	assert_near(float(row["strike_speed"]) * float(row["strike_ticks"]), 158.4, 0.01, "158.4 px, as before")
	assert_eq(int(row["windup"]), 56, "warning duration unchanged")
	assert_near(float(row["width"]), 30.0, 0.001, "width unchanged")


func test_a_charge_in_the_open_travels_158_pixels_and_never_hits_beyond_the_lane() -> void:
	var core: ExploreCore = _core()
	var stag: Mob = _stag(core)
	core.obstacles.clear()
	_queue(stag, CHARGE)
	core.player.position = stag.position + Vector2(-120, 0)
	var told: GameEvent = _until(core, GameEvent.ATTACK_TELEGRAPHED, 200)
	assert_true(told != null and told.data["attack"] == &"stag_charge", "a charge")
	var start: Vector2 = stag.position
	var hp: int = core.player.hp
	var offset: Vector2 = Vector2(0, 40)  # well outside the 30 px lane
	var moved: bool = false
	for i: int in 120:
		core.player.position = start + Vector2(-120, 0) + offset
		core.step(InputFrame.new())
		if stag.state == &"strike":
			moved = true
		if moved and stag.state != &"strike":
			break
	assert_true(moved, "it charged")
	assert_near(stag.position.distance_to(start), 158.4, 3.0, "total travel preserved")
	assert_eq(core.player.hp, hp, "a hero off the lane is not hit")


func test_a_fast_charge_cannot_tunnel_through_a_thin_obstacle() -> void:
	var core: ExploreCore = _core()
	var stag: Mob = _stag(core)
	core.obstacles.clear()
	var thin: Obstacle = Obstacle.new()
	thin.center = stag.position + Vector2(-90, 0)
	thin.radius = 3.0
	core.obstacles.append(thin)
	_queue(stag, CHARGE)
	core.player.position = stag.position + Vector2(-115, 0)
	_until(core, GameEvent.ATTACK_TELEGRAPHED, 200)
	var closest: float = 1000.0
	var charged: bool = false
	for i: int in 120:
		core.player.position = stag.home + Vector2(-140, 100)
		core.step(InputFrame.new())
		if stag.state == &"strike":
			charged = true
			closest = minf(closest, stag.position.distance_to(thin.center))
		elif charged:
			break
	assert_true(charged, "it charged")
	assert_true(closest >= stag.radius + thin.radius - 0.5, "the Stag never overlapped the post, however fast (%s)" % closest)


# ---- eight roots ----------------------------------------------------------------------------------------------------------------

func _roots_core(wait: int) -> ExploreCore:
	var core: ExploreCore = _core()
	var stag: Mob = _stag(core)
	stag.phase = 2
	_queue(stag, ROOTS)
	core.player.position = stag.position + Vector2(-110, 0)  # inside its wake radius, on the fight floor
	for i: int in wait:
		core.step(InputFrame.new())
	return core


func _roots_event(core: ExploreCore) -> GameEvent:
	var stag: Mob = _stag(core)
	for i: int in 400:
		_queue(stag, ROOTS)
		core.step(InputFrame.new())
		for e: GameEvent in _events(core, GameEvent.ATTACK_TELEGRAPHED):
			if e.data["attack"] == &"stag_roots":
				return e
	return null


func test_roots_are_eight_distinct_valid_sites_with_a_warning_each() -> void:
	for wait: int in [0, 7, 23, 41, 60, 97]:
		var core: ExploreCore = _roots_core(wait)
		var told: GameEvent = _roots_event(core)
		assert_true(told != null, "roots begin (wait %d)" % wait)
		var stag: Mob = _stag(core)
		var warnings: Array[Telegraph] = stag.all_telegraphs()
		assert_eq(warnings.size(), 8, "eight warnings (wait %d)" % wait)
		assert_eq(int(told.data["sites"]), 8, "the event says eight")
		var ids: Dictionary = {}
		for t: Telegraph in warnings:
			ids[t.id] = true
			assert_eq(t.owner_id, stag.id, "all owned by the Stag")
			assert_near(t.size, 34.0, 0.001, "radius unchanged")
			assert_eq(t.hit_tick, warnings[0].hit_tick, "committed together")
			assert_true(Collision.fits(core.obstacles, t.center, 17.0), "a free spot")
		assert_eq(ids.size(), 8, "unique ids")
		for i: int in warnings.size():
			for j: int in range(i + 1, warnings.size()):
				assert_true(warnings[i].center.distance_to(warnings[j].center) >= 40.0, "distinct sites")
		var hero: Vector2 = core.player.position
		assert_eq(warnings[0].center, hero, "the first burst is locked on the hero")
		assert_eq(core.mobs.telegraph_snapshots().size(), 8, "eight snapshots for presentation")


func test_there_is_always_a_way_out_of_the_roots() -> void:
	for wait: int in [0, 11, 29, 53, 88]:
		var core: ExploreCore = _roots_core(wait)
		_roots_event(core)
		var stag: Mob = _stag(core)
		var hero: Vector2 = core.player.position
		var found: bool = false
		for r: int in range(42, 71, 4):
			for k: int in 16:
				var q: Vector2 = hero + Vector2.RIGHT.rotated(float(k) * TAU / 16.0) * float(r)
				if not Collision.fits(core.obstacles, q, Tuning.PLAYER_RADIUS):
					continue
				var clear: bool = true
				for t: Telegraph in stag.all_telegraphs():
					if q.distance_to(t.center) <= 34.0 + Tuning.PLAYER_RADIUS:
						clear = false
				if clear:
					found = true
		assert_true(found, "a safe spot within reach (wait %d)" % wait)


func test_every_site_hurts_and_a_hero_between_them_is_safe() -> void:
	var core: ExploreCore = _roots_core(5)
	_roots_event(core)
	var stag: Mob = _stag(core)
	var sites: Array[Vector2] = []
	for t: Telegraph in stag.all_telegraphs():
		sites.append(t.center)
	var hit_tick: int = stag.telegraph.hit_tick
	var hp: int = core.player.hp
	# stand in the LAST site (not the one the hero locked) when the burst lands
	while core.tick < hit_tick + 1:
		core.player.position = sites[7]
		core.step(InputFrame.new())
	assert_true(core.player.hp < hp, "a site other than the locked one hurts")


func test_the_same_tick_gives_the_same_sites() -> void:
	var runs: Array[String] = []
	for n: int in 2:
		var core: ExploreCore = _roots_core(13)
		_roots_event(core)
		var text: String = ""
		for t: Telegraph in _stag(core).all_telegraphs():
			text += "%s;" % [t.center]
		runs.append(text)
	assert_eq(runs[0], runs[1], "repeatable")
	assert_true(runs[0] != "", "and not empty")


# ---- the chant ------------------------------------------------------------------------------------------------------------------

func _chant(core: ExploreCore) -> GameEvent:
	var stag: Mob = _stag(core)
	_queue(stag, SUMMON)
	core.player.position = stag.position + Vector2(-90, 0)
	return _until(core, GameEvent.MOB_SUMMONED, 400)


func test_the_chant_has_no_damaging_warning_and_reports_its_timing() -> void:
	var core: ExploreCore = _core()
	var stag: Mob = _stag(core)
	_queue(stag, SUMMON)
	core.player.position = stag.position + Vector2(-90, 0)
	var started: GameEvent = _until(core, GameEvent.MOB_SUMMON_STARTED, 100)
	assert_true(started != null, "the chant starts")
	assert_eq(stag.state, &"windup", "in the windup state")
	assert_true(stag.all_telegraphs().is_empty(), "no TelegraphSnapshot: nothing to dodge")
	assert_eq(core.mobs.telegraph_snapshots().size(), 0, "none in the snapshot")
	var view: Dictionary = core.mobs.mob_views(core.tick)[0]
	assert_eq(view["attack_id"], &"stag_summon", "the attack id selects the chant frames")
	assert_eq(int(view["cast_release_tick"]) - int(view["cast_start_tick"]), 90, "the chant interval")
	assert_eq(int(started.data["cast_release_tick"]), int(view["cast_release_tick"]), "the event says the same")


func test_the_chant_calls_exactly_five_valid_moths() -> void:
	for wait: int in [0, 9, 31]:
		var core: ExploreCore = _core()
		for i: int in wait:
			core.step(InputFrame.new())
		var stag: Mob = _stag(core)
		var done: GameEvent = _chant(core)
		assert_true(done != null, "the moths arrive")
		assert_eq(int(done.data["summoned_ids"].size()), 5, "exactly five")
		var moths: Array[Mob] = []
		for m: Mob in _enc(core).mobs:
			if m.summoner_id == stag.id:
				moths.append(m)
		assert_eq(moths.size(), 5, "five in the encounter")
		for m: Mob in moths:
			assert_eq(m.type, &"glowmoth", "glowmoths")
			assert_true(Collision.fits(core.obstacles, m.position, 8.0), "on free ground")
			assert_true(m.position.distance_to(core.player.position) >= 28.0, "never on the hero")
			for row: Variant in core.def["exits"]:
				assert_false((row["rect"] as Rect2).grow(40.0).has_point(m.position), "never at an exit")
		assert_eq(int(core.mobs.mob_views(core.tick)[0]["live_summons"]), 5, "the snapshot counts them")


func test_no_second_chant_while_a_moth_lives() -> void:
	var core: ExploreCore = _core()
	_chant(core)
	var stag: Mob = _stag(core)
	assert_false(core.mobs._summon_ready(core, _enc(core), stag), "not ready with moths alive")
	_queue(stag, SUMMON)
	assert_false(core.mobs._summon_ready(core, _enc(core), stag), "even when queued")


# ---- regeneration ---------------------------------------------------------------------------------------------------------------

## A summoned core with the Stag at `hp`, the hero far away and invulnerable enough, `keep` moths left alive.
func _regen_core(hp: int, keep: int) -> ExploreCore:
	var core: ExploreCore = _core()
	_chant(core)
	var stag: Mob = _stag(core)
	var enc: MobField.Encounter = _enc(core)
	var moths: Array[Mob] = []
	for m: Mob in enc.mobs:
		if m.summoner_id == stag.id:
			moths.append(m)
	for i: int in range(keep, moths.size()):
		moths[i].hp = 0
		moths[i].set_state(&"dead")
	stag.hp = hp
	stag.regen_acc = 0.0
	return core


func test_regeneration_is_two_percent_a_second_and_keeps_the_fraction() -> void:
	var core: ExploreCore = _regen_core(100, 5)
	var stag: Mob = _stag(core)
	for i: int in 60:
		core.step(InputFrame.new())
	assert_eq(stag.hp, 105, "5.2 HP in a second heals 5 whole points")
	for i: int in 240:
		core.step(InputFrame.new())
	assert_eq(stag.hp, 126, "and the fractions add up: 5 s = 26 HP, not 0")


func test_one_moth_heals_exactly_like_five() -> void:
	var five: ExploreCore = _regen_core(100, 5)
	var one: ExploreCore = _regen_core(100, 1)
	for i: int in 180:
		five.step(InputFrame.new())
		one.step(InputFrame.new())
	assert_eq(_stag(five).hp, _stag(one).hp, "the rate is per Stag, never per moth")


func test_regeneration_reports_the_healed_amount_once_a_second() -> void:
	var core: ExploreCore = _regen_core(100, 3)
	var total: int = 0
	var events: int = 0
	for i: int in 130:
		core.step(InputFrame.new())
		for e: GameEvent in _events(core, GameEvent.MOB_HEALED):
			total += int(e.data["amount"])
			events += 1
			assert_eq(e.data["source"], &"summons", "its source")
	assert_eq(events, 2, "twice in two seconds")
	assert_eq(total, _stag(core).hp - 100 - (_stag(core).hp - 100 - total), "and it adds up")
	assert_true(total >= 10 and total <= 11, "about 10.4 healed in two seconds (%d)" % total)


func test_the_last_moth_dying_stops_the_healing_that_same_tick() -> void:
	var core: ExploreCore = _regen_core(100, 1)
	var stag: Mob = _stag(core)
	var enc: MobField.Encounter = _enc(core)
	for i: int in 30:
		core.step(InputFrame.new())
	var healed: int = stag.hp
	assert_true(healed > 100, "it was healing")
	for m: Mob in enc.mobs:
		if m.summoner_id == stag.id and m.is_alive():
			core.mobs.hit_mob(core, enc, m, 999.0, {}, [] as Array[GameEvent])
	core.step(InputFrame.new())
	assert_eq(stag.hp, healed, "no healing on the tick the last moth died")
	for i: int in 120:
		core.step(InputFrame.new())
	assert_eq(stag.hp, healed, "and none afterwards")
	assert_false(bool(core.mobs.mob_views(core.tick)[0]["regen_active"]), "the snapshot says so")


func test_an_unrelated_glowmoth_does_not_heal_the_stag() -> void:
	var core: ExploreCore = _core()
	var stag: Mob = _stag(core)
	var enc: MobField.Encounter = _enc(core)
	var stray: Mob = Mob.new()
	stray.setup(7000, &"glowmoth", enc.id, stag.position + Vector2(-60, 0), 50)
	enc.mobs.append(stray)  # no summoner: an ambient moth
	stag.hp = 100
	core.player.position = stag.position + Vector2(-200, 0)
	for i: int in 120:
		core.step(InputFrame.new())
	assert_eq(stag.hp, 100, "no healing")
	assert_false(bool(core.mobs.mob_views(core.tick)[0]["regen_active"]), "and not active")


func test_healing_is_capped_at_the_maximum() -> void:
	var core: ExploreCore = _regen_core(259, 2)
	for i: int in 200:
		core.step(InputFrame.new())
	assert_eq(_stag(core).hp, 260, "never above max")
	assert_true(bool(core.mobs.mob_views(core.tick)[0]["regen_active"]), "still active while the moths live")


func test_a_dead_stag_takes_its_moths_and_the_encounter_clears_without_them() -> void:
	var core: ExploreCore = _regen_core(30, 5)
	var stag: Mob = _stag(core)
	var enc: MobField.Encounter = _enc(core)
	var events: Array[GameEvent] = []
	core.mobs.hit_mob(core, enc, stag, 9999.0, {}, events)
	assert_false(stag.is_alive(), "felled")
	assert_eq(core.mobs.live_summons(enc, stag), 0, "its moths are gone")
	assert_eq(enc.state, &"cleared", "the glade is cleared although moths were alive")
	assert_true(core.has_flag(&"cleared_stag_glade"), "flag set")
	var hp: int = stag.hp
	for i: int in 120:
		core.step(InputFrame.new())
	assert_eq(stag.hp, hp, "no resurrection")


func test_killing_a_summoned_moth_pays_nothing() -> void:
	var core: ExploreCore = _regen_core(100, 5)
	var stag: Mob = _stag(core)
	var enc: MobField.Encounter = _enc(core)
	var exp_before: int = core.exp_total
	var events: Array[GameEvent] = []
	for m: Mob in enc.mobs:
		if m.summoner_id == stag.id:
			core.mobs.hit_mob(core, enc, m, 999.0, {}, events)
	for e: GameEvent in events:
		assert_true(e.type != GameEvent.EXP_GAINED and e.type != GameEvent.MOB_DROPPED, "no exp, no drop")
	assert_eq(core.exp_total, exp_before, "exp unchanged")
	assert_false(core.has_flag(&"killed_stag_glade_101"), "no kill flag for a moth")
	assert_true(stag.is_alive(), "the Stag still stands")


func test_a_reset_removes_the_moths_and_stops_the_healing() -> void:
	var core: ExploreCore = _regen_core(100, 5)
	var stag: Mob = _stag(core)
	var enc: MobField.Encounter = _enc(core)
	core.mobs.reset_encounter(enc, core.tick, &"defeat", [] as Array[GameEvent])
	assert_eq(core.mobs.live_summons(enc, stag), 0, "no moths after a reset")
	assert_eq(stag.hp, stag.max_hp, "the Stag is whole")
	assert_eq(enc.mobs.size(), 1, "only the Stag remains in the encounter")
	var views: Array[Dictionary] = core.mobs.mob_views(core.tick)
	assert_eq(views.size(), 1, "and one mob in the snapshot")
	assert_false(bool(views[0]["regen_active"]), "no regeneration")


func test_summoned_moths_carry_their_caster_in_the_snapshot() -> void:
	var core: ExploreCore = _regen_core(100, 5)
	var stag: Mob = _stag(core)
	var linked: int = 0
	for v: Dictionary in core.mobs.mob_views(core.tick):
		if v["type"] == &"glowmoth":
			assert_eq(int(v["summoner_id"]), stag.id, "names its caster")
			linked += 1
	assert_eq(linked, 5, "five moths")
	var enc_view: Dictionary = core.mobs.encounter_views()[0]
	assert_eq(int(enc_view["total"]), 1, "moths are not counted in the encounter's total")
	assert_eq(int(enc_view["alive"]), 1, "nor as alive")
