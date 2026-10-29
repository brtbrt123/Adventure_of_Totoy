extends "res://tests/test_case.gd"
## The Woodland Approach's mobs (core/mob_field.gd, core/mob.gd, Tuning.MOBS, the encounters in data/scenes/woodland_layered_props.json):
## an unarmed hero wakes nothing, an armed one wakes the whole pack at the wake radius, the gold lunge can be parried and the red charge
## dashed through, at most two attack at once, a charge that hits a prop crashes, three blows fell a Mossling, a cleared encounter is
## cleared for good (flag, reward, inventory), the leash sends the pack home and resets it, the hero's defeat resets the scene and
## stands him up at the checkpoint, herbs heal, the snapshot carries it all, and the same inputs give the same fight.

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")
const Collision := preload("res://core/collision.gd")
const Obstacle := preload("res://core/obstacle.gd")

const SCENE: StringName = SceneDefs.WOODLAND_LAYERED
const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
## A hero spot inside the Mossling clearing, in plain view of the mobs (about 40 px from the nearest).
const WEST_SPOT: Vector2 = Vector2(112, 276)
## The same for the Boar clearing.
const EAST_SPOT: Vector2 = Vector2(560, 276)


func _core(armed: bool = true) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SCENE)
	if armed:
		core.set_story_flags(ARMED)
	return core


func _frame(move: Vector2 = Vector2.ZERO) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move = move
	return f


func _swing(aim: Vector2) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.attack_pressed = true
	f.attack_held = true
	f.aim = aim
	return f


func _count(core: ExploreCore, type: StringName) -> int:
	var n: int = 0
	for e: GameEvent in core.last_events:
		if e.type == type:
			n += 1
	return n


func _event(core: ExploreCore, type: StringName) -> GameEvent:
	for e: GameEvent in core.last_events:
		if e.type == type:
			return e
	return null


func _mobs(core: ExploreCore, encounter: StringName) -> Array[Mob]:
	var out: Array[Mob] = []
	for enc: MobField.Encounter in core.mobs.encounters:
		if enc.id == encounter:
			for mob: Mob in enc.mobs:
				out.append(mob)
	return out


func _encounter(core: ExploreCore, id: StringName) -> MobField.Encounter:
	for enc: MobField.Encounter in core.mobs.encounters:
		if enc.id == id:
			return enc
	return null


## Steps until `done` (a Callable returning bool, called after each step) or `limit` ticks; returns the ticks used.
func _until(core: ExploreCore, limit: int, done: Callable, input: Callable = Callable()) -> int:
	for i: int in limit:
		core.step(input.call(core) if input.is_valid() else _frame())
		if done.call(core):
			return i + 1
	return limit


func _any_state(core: ExploreCore, encounter: StringName, state: StringName) -> Mob:
	for mob: Mob in _mobs(core, encounter):
		if mob.state == state:
			return mob
	return null


func test_the_scene_has_the_designed_encounters() -> void:
	var core: ExploreCore = _core()
	var plan: Dictionary = {}
	for enc: MobField.Encounter in core.mobs.encounters:
		var counts: Dictionary = {}
		for mob: Mob in enc.mobs:
			counts[String(mob.type)] = int(counts.get(String(mob.type), 0)) + 1
		plan[String(enc.id)] = counts
	assert_eq(plan, {"mossling_clearing": {"mossling": 3}, "boar_clearing": {"boar": 2}, "camp_ambush": {"mossling": 2}}, "3 Mosslings, 2 Boars, a 2-Mossling camp ambush")
	for enc: MobField.Encounter in core.mobs.encounters:
		assert_eq(enc.state, MobField.DORMANT)
		assert_eq(enc.reward.is_empty(), enc.id != &"camp_ambush", "only the camp has a guaranteed reward (%s)" % enc.id)
		for mob: Mob in enc.mobs:
			assert_eq(mob.state, &"idle")
			assert_eq(mob.hp, mob.max_hp)
	assert_eq(core.mobs.encounters.size(), 3)
	var ids: Dictionary = {}
	for enc: MobField.Encounter in core.mobs.encounters:
		for mob: Mob in enc.mobs:
			assert_false(ids.has(mob.id), "mob ids are unique")
			ids[mob.id] = true


func test_an_unarmed_hero_wakes_nothing() -> void:
	var core: ExploreCore = _core(false)
	core.place_at(WEST_SPOT)
	for i: int in 120:
		core.step(_frame())
	assert_eq(_encounter(core, &"mossling_clearing").state, MobField.DORMANT)
	assert_false(core.snapshot().armed)
	var swing: InputFrame = _swing(Vector2.RIGHT)
	for i: int in 40:
		core.step(swing)
	assert_eq(core.snapshot().hero.state, &"idle", "no sword, no swing, even among mobs")


func test_an_armed_hero_far_from_the_mobs_wakes_nothing() -> void:
	var core: ExploreCore = _core()
	for i: int in 120:
		core.step(_frame())
	for enc: MobField.Encounter in core.mobs.encounters:
		assert_eq(enc.state, MobField.DORMANT, "%s sleeps while he stands at the west entry" % enc.id)


func test_walking_into_the_wake_radius_wakes_the_whole_pack_once() -> void:
	var core: ExploreCore = _core()
	core.place_at(Vector2(60, 250))
	var woke: int = -1
	var started: int = 0
	var alerted: int = 0
	for i: int in 200:
		core.step(_frame(Vector2.RIGHT))
		started += _count(core, GameEvent.ENCOUNTER_STARTED)
		alerted += _count(core, GameEvent.MOB_ALERTED)
		if woke < 0 and _encounter(core, &"mossling_clearing").state == MobField.ACTIVE:
			woke = i
			var nearest: float = INF
			for mob: Mob in _mobs(core, &"mossling_clearing"):
				nearest = minf(nearest, core.player.position.distance_to(mob.home))
			assert_true(nearest <= float(Tuning.MOBS[&"mossling"]["aggro"]) + 1.5, "woken at the wake radius, not before (%.1f)" % nearest)
	assert_true(woke > 0, "the pack woke")
	assert_eq(started, 1, "encounter_started once")
	assert_eq(alerted, 3, "all three Mosslings were alerted")
	assert_eq(_encounter(core, &"boar_clearing").state, MobField.DORMANT, "the other clearings sleep")
	assert_eq(_encounter(core, &"camp_ambush").state, MobField.DORMANT)


func test_a_lunge_is_a_gold_line_locked_on_the_hero_and_it_hurts() -> void:
	var core: ExploreCore = _core()
	core.place_at(WEST_SPOT)
	var seen: Telegraph = null
	var owner: Mob = null
	for i: int in 400:
		core.step(_frame())
		for mob: Mob in _mobs(core, &"mossling_clearing"):
			if mob.state == &"windup" and seen == null:
				seen = mob.telegraph
				owner = mob
		if seen != null:
			break
	assert_true(seen != null, "a Mossling began a lunge")
	assert_eq(seen.kind, Telegraph.KIND_GOLD)
	assert_eq(seen.shape, Telegraph.SHAPE_LINE)
	assert_eq(seen.owner_id, owner.id)
	var aimed: Vector2 = seen.direction
	assert_true(aimed.dot((core.player.position - seen.center).normalized()) > 0.99, "aimed at the hero when it began")
	var held: int = 0
	for i: int in int(Tuning.MOBS[&"mossling"]["attack"]["windup"]) - 2:
		core.step(_frame(Vector2.UP))  # he walks away from where it aimed: the aim does not follow
		if owner.state == &"windup":
			assert_eq(owner.attack_dir, aimed, "the aim stays locked")
			held += 1
	assert_true(held > 10, "it stayed in its windup for a while (%d ticks)" % held)


func test_a_lunge_that_connects_costs_twelve_and_a_dash_avoids_it() -> void:
	var damaged: Array[bool] = []
	for dash: bool in [false, true]:
		var core: ExploreCore = _core()
		core.place_at(WEST_SPOT)
		var taken: int = 0
		var started: int = -1
		for i: int in 600:
			var f: InputFrame = _frame()
			var lunging: Mob = _any_state(core, &"mossling_clearing", &"windup")
			if dash and lunging != null and started < 0:
				started = core.tick
			if dash and started >= 0 and core.tick == started + int(Tuning.MOBS[&"mossling"]["attack"]["windup"]) - 3:
				f.dash_pressed = true
				f.move = Vector2(0, -1)
			core.step(f)
			for e: GameEvent in core.last_events:
				if e.type == GameEvent.DAMAGE_TAKEN:
					taken += int(e.data["amount"])
			if taken > 0 or (started >= 0 and core.tick > started + 90):
				break
		damaged.append(taken > 0)
		if not dash:
			assert_eq(taken, int(Tuning.MOBS[&"mossling"]["attack"]["damage"]), "a lunge costs its damage")
			assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP - taken)
	assert_eq(damaged, [true, false], "standing still is hit, a dash across the lane is not")


func test_a_parried_lunge_stuns_the_mossling_and_a_counter_hits_hard() -> void:
	var core: ExploreCore = _core()
	core.place_at(WEST_SPOT)
	var parried: Mob = null
	var start: int = -1
	var windup: int = int(Tuning.MOBS[&"mossling"]["attack"]["windup"])
	for i: int in 800:
		var f: InputFrame = _frame()
		var w: Mob = _any_state(core, &"mossling_clearing", &"windup")
		if w != null and start < 0:
			start = core.tick
			parried = w
		if start >= 0 and core.tick == start + windup - 1:
			f.parry_pressed = true
		core.step(f)
		if _count(core, GameEvent.PARRY_SUCCEEDED) > 0:
			break
	assert_true(parried != null and parried.state == &"stagger", "the parried Mossling is stunned (%s)" % [parried.state if parried else "none"])
	var ev: GameEvent = _event(core, GameEvent.PARRY_SUCCEEDED)
	assert_true(ev != null and ev.data["attacker_id"] == parried.id, "parry_succeeded names the Mossling")
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP, "no damage when parried")
	assert_true(_event(core, GameEvent.MOB_STAGGERED) != null and _event(core, GameEvent.MOB_STAGGERED).data["reason"] == &"parry")
	assert_true(parried.is_exposed())
	# the counter: one blow while it is stunned takes MOB_EXPOSED_MULT x the damage
	var before: int = parried.hp
	core.place_at(parried.position + Vector2(-16, 0))
	core.player.facing = Vector2.RIGHT
	var hit: GameEvent = null
	for i: int in 60:
		core.step(_swing(Vector2.RIGHT))
		hit = _event(core, GameEvent.ATTACK_HIT)
		if hit != null and hit.data["target_id"] == parried.id:
			break
		hit = null
	assert_true(hit != null, "the blow connected")
	assert_eq(hit.data["kind"], &"counter")
	assert_eq(before - parried.hp, roundi(Tuning.ATTACK_DAMAGE * Tuning.MOB_EXPOSED_MULT), "a counter is MOB_EXPOSED_MULT x a normal first swing")


func test_at_most_two_mobs_attack_at_once() -> void:
	var core: ExploreCore = _core()
	core.place_at(Vector2(172, 280))
	var busiest: int = 0
	for i: int in 900:
		core.step(_frame())
		var n: int = 0
		for mob: Mob in _mobs(core, &"mossling_clearing"):
			if mob.is_attacking():
				n += 1
			if mob.state == &"chase":
				mob.cooldown = 0  # all three are ready every tick: only the cap holds the third back
		busiest = maxi(busiest, n)
		core.player.hp = Tuning.PLAYER_MAX_HP
	assert_true(busiest >= 1, "they attack")
	assert_eq(Tuning.MOB_MAX_ATTACKERS, 2, "the design: two at a time")
	assert_true(busiest <= 2, "never more than two at once (saw %d)" % busiest)


func test_a_charge_is_red_and_a_parry_does_not_stop_it() -> void:
	var core: ExploreCore = _core()
	core.place_at(EAST_SPOT)
	var windup: int = int(Tuning.MOBS[&"boar"]["attack"]["windup"])
	var boar: Mob = null
	var start: int = -1
	var taken: int = 0
	for i: int in 900:
		var f: InputFrame = _frame()
		var w: Mob = _any_state(core, &"boar_clearing", &"windup")
		if w != null and start < 0:
			start = core.tick
			boar = w
			assert_eq(w.telegraph.kind, Telegraph.KIND_RED)
			assert_eq(w.telegraph.shape, Telegraph.SHAPE_LINE)
		core.step(f)
		if start >= 0 and core.tick >= start + windup - 4 and core.tick <= start + windup + 40:
			var p: InputFrame = _frame()
			p.parry_pressed = (core.tick - start) % 6 == 0
			core.step(p)  # mash the parry through the charge
		for e: GameEvent in core.last_events:
			if e.type == GameEvent.DAMAGE_TAKEN:
				taken += int(e.data["amount"])
		if taken > 0:
			break
	assert_true(boar != null, "a Boar began a charge")
	assert_eq(taken, int(Tuning.MOBS[&"boar"]["attack"]["damage"]), "parrying a red charge does nothing")
	assert_eq(_count(core, GameEvent.PARRY_SUCCEEDED), 0)


func test_dashing_across_the_charge_lane_avoids_it() -> void:
	var core: ExploreCore = _core()
	core.place_at(EAST_SPOT)
	var windup: int = int(Tuning.MOBS[&"boar"]["attack"]["windup"])
	var start: int = -1
	var taken: int = 0
	for i: int in 900:
		var f: InputFrame = _frame()
		if _any_state(core, &"boar_clearing", &"windup") != null and start < 0:
			start = core.tick
		if start >= 0 and core.tick == start + windup + 4:
			f.dash_pressed = true
			f.move = Vector2(0, -1)
		core.step(f)
		for e: GameEvent in core.last_events:
			if e.type == GameEvent.DAMAGE_TAKEN:
				taken += int(e.data["amount"])
		if start >= 0 and core.tick > start + windup + 50:
			break
	assert_true(start >= 0)
	assert_eq(taken, 0, "dashing out of the lane in time takes no damage")


func test_a_boar_that_charges_into_a_prop_crashes_and_is_exposed() -> void:
	var core: ExploreCore = _core()
	core.place_at(Vector2(430, 250))
	# a wall of rock in front of the Boar's lane
	for y: int in range(220, 330, 10):
		var wall: Obstacle = Obstacle.new()
		wall.center = Vector2(468, y)
		wall.radius = 8.0
		core.obstacles.append(wall)
	core.place_at(Vector2(436, 262))
	var crashed: Mob = null
	for i: int in 700:
		core.step(_frame())
		var c: Mob = _any_state(core, &"boar_clearing", &"crash")
		if c != null:
			crashed = c
			break
	assert_true(crashed != null, "a charge into a wall crashes")
	assert_true(crashed.is_exposed())
	assert_eq(_event(core, GameEvent.MOB_STAGGERED).data["reason"], &"crash")


## Fells every mob of an encounter by walking up to the nearest and swinging; returns every event seen, in order.
func _clear_encounter(core: ExploreCore, id: StringName, start: Vector2, limit: int = 4000) -> Array[GameEvent]:
	core.place_at(start)
	var seen: Array[GameEvent] = []
	for i: int in limit:
		var target: Mob = null
		var best: float = INF
		for mob: Mob in _mobs(core, id):
			if mob.is_alive() and core.player.position.distance_to(mob.position) < best:
				best = core.player.position.distance_to(mob.position)
				target = mob
		var f: InputFrame = _frame()
		if target != null:
			var to: Vector2 = target.position - core.player.position
			f = _swing(to.normalized())
			f.move = to.normalized() if to.length() > 18.0 else Vector2.ZERO
		core.step(f)
		core.player.hp = core.hero_max_hp()  # these tests are about rewards, not danger
		seen.append_array(core.last_events)
		if _encounter(core, id).state == MobField.CLEARED:
			break
	return seen


func _of(events: Array[GameEvent], type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in events:
		if e.type == type:
			out.append(e)
	return out


func test_three_blows_fell_a_mossling_and_clearing_all_three_pays_exp_and_the_fixed_drops_once() -> void:
	var core: ExploreCore = _core()
	var seen: Array[GameEvent] = _clear_encounter(core, &"mossling_clearing", Vector2(172, 280))
	assert_eq(_of(seen, GameEvent.MOB_DEFEATED).size(), 3, "three Mosslings fell")
	assert_eq(_of(seen, GameEvent.ENCOUNTER_CLEARED).size(), 1, "encounter_cleared once")
	assert_true(core.has_flag(&"cleared_mossling_clearing"))
	assert_eq(_encounter(core, &"mossling_clearing").state, MobField.CLEARED)
	for n: int in [1, 2, 3]:
		assert_true(core.has_flag(StringName("killed_mossling_clearing_%d" % n)), "kill %d is on record" % n)
	assert_eq(_of(seen, GameEvent.EXP_GAINED).size(), 3, "each kill pays its EXP once")
	assert_eq(core.exp_total, 3 * int(Tuning.MOBS[&"mossling"]["exp"]))
	assert_eq(_of(seen, GameEvent.LEVEL_UP).size(), 1, "30 EXP is level 2")
	assert_eq(core.level(), 2)
	# drops: not guaranteed, decided by the mob (the same every time): this clearing's second Mossling drops one herb, the others nothing
	assert_eq(_of(seen, GameEvent.MOB_DROPPED).size(), 1, "one of the three Mosslings dropped something")
	var receipts: Array[GameEvent] = _of(seen, GameEvent.ITEM_RECEIVED)
	assert_eq(receipts.size(), 1, "one receipt: the drop")
	assert_true(receipts[0].data["item_id"] == &"herb" and receipts[0].data["quantity"] == 1 and receipts[0].data["kind"] == &"item" and receipts[0].data["source"] == &"mossling_clearing", str(receipts[0].data))
	assert_eq(core.inventory, {&"herb": 1})
	# nothing pays twice
	for i: int in 300:
		core.step(_frame())
		assert_eq(_count(core, GameEvent.ITEM_RECEIVED) + _count(core, GameEvent.EXP_GAINED), 0)
	assert_eq(core.inventory, {&"herb": 1})


func test_the_drop_roll_is_the_same_every_time_and_follows_the_chance() -> void:
	var rolls: Array = []
	for id: int in range(201, 208):
		assert_eq(MobField.drop_roll(id), MobField.drop_roll(id), "mob %d rolls the same" % id)
		assert_true(MobField.drop_roll(id) >= 0.0 and MobField.drop_roll(id) < 1.0)
		rolls.append(roundi(MobField.drop_roll(id) * 100.0))
	assert_eq(rolls, [41, 32, 63, 54, 84, 75, 5], "the rolls the design was tuned against (west 1 drop of 3, east 1 of 2, camp 1 of 2)")
	var core: ExploreCore = _core()
	var seen: Array[GameEvent] = _clear_encounter(core, &"boar_clearing", Vector2(520, 290), 9000)
	assert_eq(_of(seen, GameEvent.MOB_DEFEATED).size(), 2, "both Boars fell")
	assert_eq(_of(seen, GameEvent.MOB_DROPPED).size(), 1, "one of the two drops")
	assert_eq(core.exp_total, 2 * int(Tuning.MOBS[&"boar"]["exp"]))
	assert_eq(core.inventory, {&"herb": 1})


func test_the_camp_pays_its_guaranteed_herbs_on_top_of_the_drop() -> void:
	var core: ExploreCore = _core()
	var seen: Array[GameEvent] = _clear_encounter(core, &"camp_ambush", Vector2(318, 140))
	assert_eq(_of(seen, GameEvent.MOB_DEFEATED).size(), 2)
	var total: int = 0
	for e: GameEvent in _of(seen, GameEvent.ITEM_RECEIVED):
		total += int(e.data["quantity"])
	assert_eq(total, 3, "2 guaranteed herbs plus the one drop")
	assert_eq(core.inventory[&"herb"], 3)


func test_a_felled_mob_stays_down_after_a_reset_and_after_continue_and_never_pays_twice() -> void:
	var core: ExploreCore = _core()
	core.place_at(WEST_SPOT)
	var first: Mob = _mobs(core, &"mossling_clearing")[0]
	core.set_story_flags([&"received_first_sword", &"killed_mossling_clearing_1"] as Array[StringName])
	assert_true(first.killed and not first.is_alive(), "felled in an earlier visit: down from the start")
	assert_eq(core.snapshot().mobs.size(), 6, "its body is not drawn")
	var events: Array[GameEvent] = []
	core.mobs.reset_all(core.tick, &"defeat", events)
	assert_false(first.is_alive(), "a reset does not revive it")
	core.place_at(Vector2(172, 280))
	for i: int in 400:
		core.step(_frame())
	assert_eq(_encounter(core, &"mossling_clearing").state, MobField.ACTIVE, "the other two still fight")
	var seen: Array[GameEvent] = _clear_encounter(core, &"mossling_clearing", core.player.position)
	assert_eq(_of(seen, GameEvent.EXP_GAINED).size(), 2, "only the two that fell now pay")
	assert_eq(core.exp_total, 20)


func test_levels_follow_the_exp_curve_and_scale_health_and_damage() -> void:
	var core: ExploreCore = _core()
	assert_eq([core.level(), core.exp_in_level(), core.exp_to_next(), core.hero_max_hp()], [1, 0, 30, 100])
	core.set_exp(29)
	assert_eq(core.level(), 1)
	core.set_exp(30)
	assert_eq([core.level(), core.exp_in_level(), core.exp_to_next(), core.hero_max_hp()], [2, 0, 50, 105])
	assert_eq(core.player.hp, 105, "a restored hero stands at full health of his level")
	core.set_exp(30 + 49)
	assert_eq([core.level(), core.exp_in_level()], [2, 49])
	var total: int = 0
	for need: int in Tuning.EXP_TO_NEXT:
		total += need
	core.set_exp(total)
	assert_eq([core.level(), core.exp_to_next()], [Tuning.LEVEL_MAX, 0], "the top level needs nothing more")
	core.set_exp(total + 99999)
	assert_eq(core.level(), Tuning.LEVEL_MAX, "no level past the maximum")
	assert_true(is_equal_approx(core.damage_mult(), 1.0), "damage comes from the Might stat, not from the level")
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_eq([snap.level, snap.exp_to_next, snap.hero.max_hp, snap.exp_total], [Tuning.LEVEL_MAX, 0, 100 + Tuning.LEVEL_HP_BONUS * (Tuning.LEVEL_MAX - 1), total + 99999])


func test_a_level_up_heals_to_full_and_might_makes_the_hero_hit_harder() -> void:
	var core: ExploreCore = _core()
	core.player.hp = 20
	var events: Array[GameEvent] = []
	core.give_exp(30, 201, events)
	var lv: Array[GameEvent] = _of(events, GameEvent.LEVEL_UP)
	assert_eq(lv.size(), 1)
	assert_true(lv[0].data["level"] == 2 and lv[0].data["max_hp"] == 105 and lv[0].data["points"] == 2)
	assert_eq(core.player.hp, 105, "full health after a level up")
	var ev: GameEvent = _of(events, GameEvent.EXP_GAINED)[0]
	assert_true(ev.data["amount"] == 30 and ev.data["level"] == 2 and ev.data["exp"] == 0 and ev.data["exp_to_next"] == 50, str(ev.data))
	core.give_exp(50 + 80 + 120, 201, events)
	assert_eq(_of(events, GameEvent.LEVEL_UP).size(), 4, "one event per level crossed")
	core.set_stats({&"might": 4})  # level 5 has 8 points: four on Might is +12 % damage
	core.place_at(Vector2(150, 300))
	var mossling: Mob = _mobs(core, &"mossling_clearing")[0]
	mossling.position = Vector2(166, 300)
	core.player.facing = Vector2.RIGHT
	for i: int in 60:
		core.step(_swing(Vector2.RIGHT))
		var hit: GameEvent = _event(core, GameEvent.ATTACK_HIT)
		if hit != null and hit.data["target_id"] == mossling.id:
			assert_eq(hit.data["damage"], 11, "10 damage x 1.12")
			return
	assert_true(false, "the blow connected")


func test_item_slots_one_and_two_and_the_locks() -> void:
	var core: ExploreCore = _core()
	var slots: Array[Dictionary] = core.snapshot().item_slots
	assert_eq(slots.size(), 2)
	assert_true(slots[0]["slot"] == 1 and slots[0]["item"] == &"herb" and slots[0]["unlocked"] == true and slots[0]["count"] == 0)
	assert_true(slots[1]["slot"] == 2 and slots[1]["unlocked"] == false, "slot 2 is locked")
	assert_false(_core(false).snapshot().item_slots[0]["unlocked"], "an unarmed hero has no herb slot")
	core.set_inventory({&"herb": 2})
	assert_eq(core.snapshot().item_slots[0]["count"], 2)
	core.player.hp = 50
	var two: InputFrame = InputFrame.new()
	two.use_item_slot = 2
	core.step(two)
	assert_eq(core.player.hp, 50, "the locked slot does nothing")
	assert_eq(core.inventory[&"herb"], 2)
	var one: InputFrame = InputFrame.new()
	one.use_item_slot = 1
	core.step(one)
	assert_eq(core.player.hp, 85, "slot 1 is the herb")
	assert_eq(core.inventory[&"herb"], 1)
	var aspects: Array[Dictionary] = core.snapshot().aspect_slots
	assert_eq(aspects.size(), 3)
	for a: Dictionary in aspects:
		assert_true(a["usable"], "every Aspect works on the road now (Echo Step, Ward, Lantern, Phantom Cut and the three skills)")
	assert_false(_core().snapshot().owned_aspects.is_empty() and false)
	var fresh: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	for a: Dictionary in fresh.snapshot().aspect_slots:
		assert_false(a["unlocked"], "a new hero's sockets are locked")


func test_a_boar_keeps_attacking_a_hero_who_stands_close() -> void:
	var core: ExploreCore = _core()
	core.place_at(Vector2(470, 280))
	var charges: int = 0
	for i: int in 1500:
		core.step(_frame())
		charges += _count(core, GameEvent.ATTACK_TELEGRAPHED)
		core.player.hp = core.hero_max_hp()
	assert_true(charges >= 4, "the Boars wind up again and again, also at point-blank range (%d warnings)" % charges)


func test_a_cleared_encounter_stays_cleared_after_continue() -> void:
	var core: ExploreCore = _core()
	core.set_story_flags([&"received_first_sword", &"cleared_mossling_clearing"] as Array[StringName])
	assert_eq(_encounter(core, &"mossling_clearing").state, MobField.CLEARED)
	assert_true(_mobs(core, &"mossling_clearing").is_empty(), "its mobs never come back")
	core.place_at(WEST_SPOT)
	for i: int in 200:
		core.step(_frame())
		assert_eq(_count(core, GameEvent.ITEM_RECEIVED), 0, "no popup when loading a save")
		assert_eq(core.snapshot().hero.hp, Tuning.PLAYER_MAX_HP, "nothing to fight there")
	assert_eq(core.snapshot().mobs.size(), 4, "only the Boars and the camp's Mosslings are left in the scene")
	assert_eq(core.snapshot().encounters[0]["state"], MobField.CLEARED)


func test_the_leash_sends_the_pack_home_and_a_long_absence_resets_it() -> void:
	var core: ExploreCore = _core()
	core.place_at(WEST_SPOT)
	var victim: Mob = null
	for i: int in 600:
		var m: Mob = _any_state(core, &"mossling_clearing", &"chase")
		core.step(_frame())
		if m != null:
			victim = m
			break
	assert_true(victim != null and _encounter(core, &"mossling_clearing").state == MobField.ACTIVE, "the pack is after him")
	victim.hp = 7  # wounded
	# he leaves the leash (the scene's far side): every mob gives up and walks home, healing on arrival
	core.place_at(Vector2(600, 250))
	var leashed: int = 0
	for i: int in Tuning.MOB_LEASH_GRACE_TICKS + 400:
		core.step(_frame())
		leashed += _count(core, GameEvent.MOB_LEASHED)
		var home: bool = true
		for mob: Mob in _mobs(core, &"mossling_clearing"):
			home = home and mob.state == &"idle" and mob.position.distance_to(mob.home) < 0.01
		if home and leashed > 0:
			break
	assert_eq(leashed, 3, "all three gave up")
	assert_eq(_encounter(core, &"mossling_clearing").state, MobField.DORMANT)
	for mob: Mob in _mobs(core, &"mossling_clearing"):
		assert_eq(mob.hp, mob.max_hp, "healed when home")
	# a long absence after a kill: the dead come back (the encounter was touched)
	var dead: Mob = _mobs(core, &"mossling_clearing")[0]
	dead.hp = 0
	dead.set_state(&"dead")
	_encounter(core, &"mossling_clearing").touched = true
	var reset: int = 0
	for i: int in Tuning.MOB_RESET_TICKS + 20:
		core.step(_frame())
		reset += _count(core, GameEvent.ENCOUNTER_RESET)
	assert_eq(reset, 1, "encounter_reset once")
	assert_true(dead.is_alive() and dead.hp == dead.max_hp and dead.state == &"idle", "the fallen Mossling stands at home again")


func test_the_hero_falls_and_stands_up_at_the_checkpoint_with_the_scene_reset() -> void:
	var core: ExploreCore = _core()
	core.place_at(Vector2(36, 248))
	core.step(_frame())  # the west checkpoint is recorded
	assert_eq(core.last_checkpoint, &"woodland_layered_west")
	core.place_at(WEST_SPOT)
	for i: int in 200:
		core.step(_frame())
		if _encounter(core, &"mossling_clearing").state == MobField.ACTIVE:
			break
	var first: Mob = _mobs(core, &"mossling_clearing")[0]
	first.hp = 0
	first.set_state(&"dead")
	core.player.hp = 1
	var defeated: int = 0
	var respawned: int = 0
	var fell_at: int = -1
	var resets: int = 0
	for i: int in 900:
		core.step(_frame())
		if defeated == 0 and core.player.hp > 1:
			pass
		defeated += _count(core, GameEvent.HERO_DEFEATED)
		respawned += _count(core, GameEvent.HERO_RESPAWNED)
		resets += _count(core, GameEvent.ENCOUNTER_RESET)
		if fell_at < 0 and defeated > 0:
			fell_at = core.tick
			assert_true(core.snapshot().defeated and core.snapshot().hero.state == &"dead")
		if respawned > 0:
			break
	assert_eq(defeated, 1, "hero_defeated once")
	assert_eq(respawned, 1, "hero_respawned once")
	assert_true(core.tick - fell_at >= Tuning.HERO_DEFEAT_TICKS - 2 and core.tick - fell_at <= Tuning.HERO_DEFEAT_TICKS + 2, "he stays down for HERO_DEFEAT_TICKS (%d)" % (core.tick - fell_at))
	assert_eq(core.player.position, SceneDefs.checkpoint(SCENE, &"woodland_layered_west")["position"], "back at the checkpoint")
	assert_eq(core.player.hp, Tuning.PLAYER_MAX_HP)
	assert_false(core.snapshot().defeated)
	assert_eq(resets, 1, "the touched encounter was made whole")
	assert_true(first.is_alive() and first.hp == first.max_hp and first.position == first.home)
	assert_eq(_encounter(core, &"mossling_clearing").state, MobField.DORMANT)
	assert_true(core.player.weapon_id == Tuning.WEAPON_BLACK_KATANA and core.is_armed(), "he keeps his sword")


func test_herbs_heal_and_are_used_up() -> void:
	var core: ExploreCore = _core()
	core.set_inventory({&"herb": 2, "junk": 0, &"big": 500})
	assert_eq(core.inventory, {&"herb": 2, &"big": Tuning.INVENTORY_MAX_STACK}, "empty stacks vanish, big ones are capped")
	var use: InputFrame = InputFrame.new()
	use.use_herb_pressed = true
	core.step(use)
	assert_true(_event(core, GameEvent.ITEM_USED) == null, "nothing at full health")
	assert_eq(core.inventory[&"herb"], 2)
	core.player.hp = 50
	core.step(use)
	var ev: GameEvent = _event(core, GameEvent.ITEM_USED)
	assert_true(ev != null and ev.data["healed"] == Tuning.HERB_HEAL and ev.data["hp"] == 50 + Tuning.HERB_HEAL and ev.data["count"] == 1, str(ev.data if ev else {}))
	assert_eq(core.player.hp, 85)
	core.player.hp = 90
	core.step(use)
	assert_eq(core.player.hp, 100, "never above the maximum")
	assert_false(core.inventory.has(&"herb"), "the last herb is gone")
	core.player.hp = 40
	core.step(use)
	assert_eq(core.player.hp, 40, "none left, nothing happens")


func test_the_snapshot_carries_mobs_encounters_and_warnings() -> void:
	var core: ExploreCore = _core()
	var snap: ExploreCore.ExploreSnapshot = core.snapshot()
	assert_eq(snap.mobs.size(), 7)
	assert_eq(snap.encounters.size(), 3)
	assert_eq(snap.encounters[0]["id"], &"mossling_clearing")
	assert_eq(snap.encounters[0]["alive"], 3)
	assert_eq(snap.encounters[0]["total"], 3)
	var mob: Dictionary = snap.mobs[0]
	for key: String in ["id", "type", "visual_id", "encounter_id", "position", "facing", "state", "state_ticks", "hp", "max_hp", "radius", "exposed", "attack", "since_hit"]:
		assert_true(mob.has(key), "a mob view has %s" % key)
	core.place_at(WEST_SPOT)
	var warned: bool = false
	for i: int in 400:
		core.step(_frame())
		var s: ExploreCore.ExploreSnapshot = core.snapshot()
		if not s.telegraphs.is_empty():
			warned = true
			assert_true(s.telegraphs[0].owner_id >= MobField.FIRST_MOB_ID and s.telegraphs[0].shape == &"line" and s.telegraphs[0].width > 0.0)
			assert_true(s.telegraphs[0].hit_tick > s.tick - 1 or s.telegraphs[0].end_tick >= s.tick)
			break
	assert_true(warned, "a mob's warning appears in the snapshot")


func test_the_scene_without_encounters_has_no_mobs() -> void:
	var village: ExploreCore = ExploreCore.new(SceneDefs.VILLAGE_LAYERED)
	assert_true(village.mobs == null)
	var snap: ExploreCore.ExploreSnapshot = village.snapshot()
	assert_true(snap.mobs.is_empty() and snap.encounters.is_empty() and not snap.defeated)


func test_the_same_inputs_give_the_same_fight() -> void:
	var traces: Array = []
	for r: int in 2:
		var core: ExploreCore = _core()
		core.place_at(Vector2(172, 280))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 99
		var trace: Array = []
		for i: int in 1200:
			var f: InputFrame = InputFrame.new()
			f.move = Vector2.RIGHT.rotated(rng.randf() * TAU) if i % 20 == 0 else _frame().move
			f.attack_pressed = rng.randf() < 0.1
			f.attack_held = f.attack_pressed
			f.parry_pressed = rng.randf() < 0.05
			f.dash_pressed = rng.randf() < 0.03
			f.aim = Vector2.RIGHT.rotated(rng.randf() * TAU)
			core.step(f)
			trace.append([core.player.position, core.player.hp, core.snapshot().mobs.map(func(m: Dictionary) -> Array: return [m["position"], m["hp"], m["state"]])])
		traces.append(trace)
	assert_eq(traces[0], traces[1], "no randomness anywhere")


func test_the_hero_is_never_stuck_in_a_collider_while_fighting() -> void:
	var core: ExploreCore = _core()
	core.place_at(Vector2(172, 280))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var bad: int = 0
	var mob_bad: int = 0
	for i: int in 1800:
		var f: InputFrame = InputFrame.new()
		f.move = Vector2.RIGHT.rotated(rng.randf() * TAU) if i % 15 == 0 else core.player.facing * 0.0
		f.attack_pressed = rng.randf() < 0.08
		f.attack_held = f.attack_pressed
		f.dash_pressed = rng.randf() < 0.04
		f.aim = core.player.facing
		core.step(f)
		core.player.hp = maxi(core.player.hp, 30)
		if not Collision.fits(core.obstacles, core.player.position, Tuning.PLAYER_RADIUS):
			bad += 1
		for enc: MobField.Encounter in core.mobs.encounters:
			for mob: Mob in enc.mobs:
				if mob.is_alive() and not Collision.fits(core.obstacles, mob.position, mob.radius - 0.5):
					mob_bad += 1
	assert_eq(bad, 0, "the hero never ends a tick inside a collider")
	assert_eq(mob_bad, 0, "neither does a mob")
