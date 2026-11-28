extends "res://tests/test_case.gd"
## The Mossbound Colossus on the road (core/colossus.gd, Tuning.MOBS.colossus and COLOSSUS_*, docs/PLAN_colossus_step3.md part
## 3a): Rootcrown's one encounter. It sleeps until the hero is near, rises unhurt, seals the climb, keeps the arena's armour,
## posture and counter rules, warns of six attacks (gold = parry, red = dodge), takes Reaper's Coil as a stun, changes phase at
## 60 %, and falling clears the scene, lights the beacon and opens the climb.

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const Colossus := preload("res://core/colossus.gd")
const Weapons := preload("res://core/weapons.gd")

const SCENE: StringName = SceneDefs.ROOTCROWN_LAYERED
const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
const HOME: Vector2 = Vector2(512, 378)
## Where each attack is tried, as an offset from the boss: inside its distance band and inside its first warning.
const SPOTS: Dictionary = {
	&"gold_slam": Vector2(100, 40), &"red_sweep": Vector2(0, 74), &"red_shards": Vector2(130, 40), &"red_stomp": Vector2(100, 20),
	&"gold_combo": Vector2(80, 40), &"red_charge": Vector2(150, 40),
	&"root_snare": Vector2(120, 40), &"boulder_toss": Vector2(140, 40), &"heartroot_grab": Vector2(120, 30),
	&"song_flare": Vector2(70, 0),  # in its first ring
}
## What a hero who never moves takes from an attack's follow-up as well: nothing. The snare's second lane comes 30 ticks after the
## first, inside the 45 ticks a wounded hero cannot be hurt (PLAYER_HURT_INVULN_TICKS): it punishes the dodge, never doubles a hit.
## The boulder's ring of shock spares the crater he stands in.
## The Song Flare: its first ring, then (the hurt window long over) its gold blow.
const FOLLOW_ON_A_STILL_HERO: Dictionary = {&"song_flare": 35}
const LayoutFlood := preload("res://tests/layout_flood.gd")
const KATANA: StringName = &"black_katana"


func _core() -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.set_story_flags(ARMED)
	return core


func _boss(core: ExploreCore) -> Colossus:
	return core.mobs.encounters[0].mobs[0] as Colossus


func _events(core: ExploreCore, type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in core.last_events:
		if e.type == type:
			out.append(e)
	return out


func _steps(core: ExploreCore, ticks: int, frame: InputFrame = null) -> Array[GameEvent]:
	var seen: Array[GameEvent] = []
	for i: int in ticks:
		core.step(frame if frame != null else InputFrame.new())
		seen.append_array(core.last_events)
	return seen


func _of(events: Array[GameEvent], type: StringName) -> Array[GameEvent]:
	return events.filter(func(e: GameEvent) -> bool: return e.type == type)


## A core whose fight is on: the Colossus has risen and walks, held from attacking until a test forces an attack.
func _fight(hero: Vector2 = HOME + Vector2(100, 60)) -> ExploreCore:
	var core: ExploreCore = _core()
	core.player.position = hero
	_steps(core, Tuning.COLOSSUS_WAKE_TICKS + 2)
	var boss: Colossus = _boss(core)
	assert_eq(boss.state, &"chase", "risen")
	boss.position = HOME
	boss.cooldown = 100000
	core.player.position = hero
	return core


## Forces `attack` at the hero standing `offset` from the boss; the tick its first warning turns dangerous.
func _force(core: ExploreCore, attack: StringName, offset: Vector2) -> int:
	var boss: Colossus = _boss(core)
	boss.position = HOME
	boss.state = &"chase"
	boss.cooldown = 1
	boss.next_attack_override = attack
	core.player.position = HOME + offset
	core.step(InputFrame.new())
	assert_eq(boss.state, &"windup", "it began " + String(attack))
	return boss.telegraph.hit_tick


func _swing(combo: int = 1, weapon: StringName = KATANA) -> Dictionary:
	return {"combo_index": combo, "weapon_id": weapon}


func _hit(core: ExploreCore, base: float, extra: Dictionary) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	core.mobs.hit_mob(core, core.mobs.encounters[0], _boss(core), base, extra, events)
	return events


# ---- waking, the seal, the body ---------------------------------------------------------------------------------------------

func test_rootcrown_holds_one_sleeping_colossus() -> void:
	var core: ExploreCore = _core()
	assert_eq(core.mobs.encounters.size(), 1)
	assert_eq(core.mobs.encounters[0].id, &"rootcrown")
	var boss: Colossus = _boss(core)
	assert_eq([boss.type, boss.position, boss.hp, boss.state], [&"colossus", HOME, 600, &"idle"])
	var view: Dictionary = core.snapshot().mobs[0]
	assert_true(bool(view["boss"]) and bool(view["invulnerable"]), "the boss, not yet to be hurt")
	assert_eq([view["posture"], view["posture_max"], view["broken_ticks_left"]], [0.0, 100.0, 0])
	assert_false(bool(core.snapshot().encounters[0]["sealed"]), "the climb is open")


func test_it_wakes_only_when_the_hero_is_near_and_cannot_be_hurt_while_it_rises() -> void:
	var core: ExploreCore = _core()
	_steps(core, 30)
	assert_eq(_boss(core).state, &"idle", "asleep while the hero is on the climb")
	_hit(core, 1000.0, _swing())
	assert_eq([_boss(core).hp, _boss(core).state], [600, &"idle"], "a blow from afar does nothing and does not wake it")
	core.player.position = HOME + Vector2(0, 170)
	core.step(InputFrame.new())
	assert_eq(_boss(core).state, &"alert", "woken at 170 px")
	_hit(core, 1000.0, _swing())
	assert_eq(_boss(core).hp, 600, "unhurt while it rises")
	assert_true(core.mobs.living().is_empty(), "and no skill finds it")
	var told: Array[GameEvent] = _steps(core, Tuning.COLOSSUS_WAKE_TICKS - 2)
	assert_eq(_of(told, GameEvent.ATTACK_TELEGRAPHED).size(), 0, "no attack while rising")
	_steps(core, 3)
	assert_eq(_boss(core).state, &"chase", "it has risen")
	assert_eq(core.mobs.living().size(), 1)


func test_the_climb_closes_during_the_fight_and_opens_when_the_hero_falls() -> void:
	var core: ExploreCore = _core()
	var open: int = core.obstacles.size()
	core.player.position = HOME + Vector2(0, 170)
	core.step(InputFrame.new())
	assert_eq(_of(core.last_events, GameEvent.ARENA_SEALED).size(), 1, "sealed as it wakes")
	assert_eq(core.obstacles.size(), open + 8, "the eight seal circles are solid")
	assert_true(bool(core.snapshot().encounters[0]["sealed"]))
	assert_eq((core.snapshot().encounters[0]["seal"] as Array).size(), 8)
	_boss(core).cooldown = 100000
	core.player.position = Vector2(512, 655)  # the climb, above the seal
	_steps(core, 120, input(Vector2.DOWN))
	assert_true(core.player.position.y < 672.0 and not core.exiting, "he cannot walk down: %s" % core.player.position)
	_boss(core).hp = 100
	core.player.hp = 0
	var events: Array[GameEvent] = []
	core.player.die(core.tick, events)
	var after: Array[GameEvent] = _steps(core, Tuning.HERO_DEFEAT_TICKS + 2)
	assert_eq(_of(after, GameEvent.ARENA_OPENED).size(), 1, "opened by the defeat")
	assert_eq(core.obstacles.size(), open)
	var boss: Colossus = _boss(core)
	assert_eq([boss.state, boss.hp, boss.phase, boss.posture, boss.position], [&"idle", 600, 1, 0.0, HOME], "whole again")


func test_the_hero_cannot_walk_into_its_body() -> void:
	var core: ExploreCore = _fight()
	core.player.position = HOME + Vector2(10, 5)
	core.step(InputFrame.new())
	var gap: float = core.player.position.distance_to(_boss(core).position)
	assert_true(gap >= 46.0 + Tuning.PLAYER_RADIUS - 0.01, "pushed to its edge: %s" % gap)
	_steps(core, 60, input(Vector2.LEFT))
	assert_true(core.player.position.distance_to(_boss(core).position) >= 46.0 + Tuning.PLAYER_RADIUS - 0.01, "and held there")


# ---- armour, posture, counters ----------------------------------------------------------------------------------------------

func test_blows_are_armoured_fill_posture_and_earn_edge() -> void:
	var core: ExploreCore = _fight()
	core.player.edge = 0.0
	var events: Array[GameEvent] = _hit(core, 20.0, _swing())
	var boss: Colossus = _boss(core)
	assert_eq(boss.hp, 600 - 5, "a quarter of the damage")
	assert_near(boss.posture, Weapons.swing_posture(KATANA, 1), 0.001)
	assert_near(core.player.edge, Weapons.edge_per_hit(KATANA), 0.001)
	assert_eq(_of(events, GameEvent.ATTACK_HIT)[0].data["kind"], &"normal")


func test_a_broken_one_takes_counters_that_spend_the_edge() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	var events: Array[GameEvent] = []
	boss.add_posture(100.0, core.tick, events)
	assert_eq(boss.state, &"posture_broken")
	assert_eq(_of(events, GameEvent.POSTURE_BROKEN).size() + _of(events, GameEvent.COUNTER_WINDOW_OPENED).size(), 2)
	assert_true(boss.is_exposed())
	core.player.edge = 60.0
	var hit: Array[GameEvent] = _hit(core, 20.0, _swing())
	assert_eq(boss.hp, 600 - (80 + 30), "x4, plus half the Edge")
	assert_eq(core.player.edge, 0.0, "spent")
	assert_eq(_of(hit, GameEvent.ATTACK_HIT)[0].data["kind"], &"counter")
	core.player.edge = 60.0
	_hit(core, 10.0, {"skill_id": &"gale_cut", "attack_id": 1})
	assert_eq([boss.hp, core.player.edge], [490 - 40, 60.0], "a skill counters without the Edge")
	var after: Array[GameEvent] = _steps(core, Tuning.COLOSSUS_BREAK_TICKS + 1)
	assert_eq(_of(after, GameEvent.COUNTER_WINDOW_CLOSED).size(), 1)
	assert_eq([boss.state != &"posture_broken", boss.posture], [true, 0.0])


func test_each_kind_of_hit_fills_the_arenas_posture() -> void:
	assert_eq(Colossus.posture_of({"echo": true, "swing_combo_index": 3, "weapon_id": KATANA}), Weapons.swing_posture(KATANA, 3) * Tuning.PHANTOM_CUT_POSTURE_MULT)
	assert_eq(Colossus.posture_of({"lightning_strike": true}), Tuning.LIGHTNING_STRIKE_POSTURE)
	assert_eq(Colossus.posture_of({"barrage_slash": 2}), Tuning.NORMAL_HIT_POSTURE)
	assert_eq(Colossus.posture_of({"reaper_coil_hit": 1}), Tuning.REAPER_COIL_SPIN_POSTURE)
	assert_eq(Colossus.posture_of({"aspect_id": &"stone_ward", "ward_release": true, "ward_stored": 20}), Tuning.STONE_WARD_POSTURE + 20.0 * Tuning.STONE_WARD_POSTURE_PER_STORED)
	assert_eq(Colossus.posture_of({"skill_id": &"breaking_edge"}), Tuning.BREAKING_EDGE_POSTURE)
	assert_eq(Colossus.posture_of({"skill_id": Weapons.FORM_DISINTEGRATION, "weapon_id": &"star_staff"}), Tuning.DISINTEGRATION_POSTURE)


func test_a_real_swing_of_the_hero_lands_on_it() -> void:
	var core: ExploreCore = _fight(HOME + Vector2(62, 0))
	var frame: InputFrame = input(Vector2.ZERO, false, false, true)
	frame.aim = Vector2.LEFT
	core.step(frame)
	var after: Array[GameEvent] = _steps(core, 30)
	assert_eq(_of(after, GameEvent.ATTACK_HIT).size(), 1, "one blow, one hit")
	assert_true(_boss(core).hp < 600)


# ---- the attacks ------------------------------------------------------------------------------------------------------------

func test_every_attack_wounds_a_hero_who_stands_still() -> void:
	for row: Dictionary in Tuning.COLOSSUS_ATTACKS:
		var core: ExploreCore = _fight()
		var hit: int = _force(core, row["id"], SPOTS[row["id"]])
		var told: Array[GameEvent] = _of(core.last_events, GameEvent.ATTACK_TELEGRAPHED)
		assert_eq([told.size(), told[0].data["attack"], told[0].data["kind"]], [1, row["id"], row["kind"]], String(row["id"]))
		assert_eq(hit - core.tick, int(row["windup"]), "its warning runs the full time: " + String(row["id"]))
		assert_eq(core.snapshot().telegraphs.size(), int(told[0].data["sites"]), "every warning is in the snapshot")
		var hp: int = core.player.hp
		var last_end: int = 0
		for w: Variant in core.snapshot().telegraphs:
			last_end = maxi(last_end, int(w.end_tick))
		_steps(core, hit - core.tick - 1)
		assert_eq(core.player.hp, hp, "nothing hurts before the warning ends: " + String(row["id"]))
		_steps(core, maxi(int(row["active"]) + 60, last_end - core.tick + 5))
		assert_eq(core.player.hp, hp - int(row["damage"]) - int(FOLLOW_ON_A_STILL_HERO.get(row["id"], 0)), "once each: " + String(row["id"]))
		assert_eq(core.snapshot().telegraphs.size(), 0, "and the warning is gone")


func test_gold_attacks_are_parried_and_red_ones_are_not() -> void:
	for row: Dictionary in Tuning.COLOSSUS_ATTACKS:
		var core: ExploreCore = _fight()
		var hit: int = _force(core, row["id"], SPOTS[row["id"]])
		_steps(core, hit - core.tick - 3)
		var hp: int = core.player.hp
		var events: Array[GameEvent] = _steps(core, 1, input(Vector2.ZERO, false, true))
		events.append_array(_steps(core, 6))
		var parried: bool = _of(events, GameEvent.PARRY_SUCCEEDED).size() == 1
		if row["kind"] == &"gold":
			assert_true(parried and core.player.hp == hp, "parried: " + String(row["id"]))
			assert_eq(_boss(core).state, &"posture_broken", "a perfect parry breaks it: " + String(row["id"]))
		else:
			assert_true(not parried and core.player.hp < hp, "a red one cannot be parried: " + String(row["id"]))


func test_an_early_parry_fills_part_of_the_posture() -> void:
	var core: ExploreCore = _fight()
	var hit: int = _force(core, &"gold_slam", SPOTS[&"gold_slam"])
	_steps(core, hit - core.tick - 10)
	var events: Array[GameEvent] = _steps(core, 1, input(Vector2.ZERO, false, true))
	events.append_array(_steps(core, 11))
	assert_eq(_of(events, GameEvent.PARRY_SUCCEEDED)[0].data["quality"], &"early")
	assert_near(_boss(core).posture, Tuning.PARRY_EARLY_POSTURE, 1.0)


func test_a_parried_grab_cracks_the_posture_wide() -> void:
	var core: ExploreCore = _fight()
	var hit: int = _force(core, &"heartroot_grab", SPOTS[&"heartroot_grab"])
	assert_eq([_boss(core).telegraph.shape, _boss(core).telegraph.kind], [Telegraph.SHAPE_LINE, &"gold"])
	_steps(core, hit - core.tick - 10)
	var events: Array[GameEvent] = _steps(core, 1, input(Vector2.ZERO, false, true))
	events.append_array(_steps(core, 11))
	assert_eq(_of(events, GameEvent.PARRY_SUCCEEDED)[0].data["quality"], &"early")
	assert_near(_boss(core).posture, 60.0, 1.0, "an early parry adds 60, not 35")


func test_the_root_snare_sends_a_second_lane_where_he_went() -> void:
	var core: ExploreCore = _fight()
	var hit: int = _force(core, &"root_snare", SPOTS[&"root_snare"])
	_steps(core, hit - core.tick - 1)
	var went: Vector2 = HOME + Vector2(60, 110)  # he dodged
	core.player.position = went
	var events: Array[GameEvent] = _steps(core, 1)
	var follow: Array[GameEvent] = _of(events, GameEvent.ATTACK_TELEGRAPHED)
	assert_eq(follow.size(), 1, "the second warning begins as the first strikes")
	assert_true(bool(follow[0].data.get("follow", false)))
	assert_eq(follow[0].data["hit_tick"] - core.tick, 30, "it warns 0.5 s")
	var second: Telegraph = _boss(core).extra_telegraphs[0]
	assert_true(second.direction.dot((went - HOME).normalized()) > 0.999, "aimed where he went")
	assert_eq([second.shape, second.kind, second.width], [Telegraph.SHAPE_LINE, &"red", 28.0])
	var hp: int = core.player.hp
	_steps(core, 40)
	assert_eq(core.player.hp, hp - 18, "it catches him if he stays")


func test_the_boulder_lands_where_he_stood_then_a_ring_of_shock_follows() -> void:
	for case: Array in [[Vector2(20, 0), 0], [Vector2(56, 0), 12]]:  # back in the crater: safe; in the ring: 12
		var core: ExploreCore = _fight()
		var stood: Vector2 = HOME + SPOTS[&"boulder_toss"]
		var hit: int = _force(core, &"boulder_toss", SPOTS[&"boulder_toss"])
		assert_eq([_boss(core).telegraph.shape, _boss(core).telegraph.center], [Telegraph.SHAPE_CIRCLE, stood], "where he stood")
		core.player.position = stood + Vector2(0, 80)  # he dodged the stone
		_steps(core, hit - core.tick + 3)  # it has landed (3 dangerous ticks)
		var ring: Telegraph = _boss(core).extra_telegraphs[0]
		assert_eq([ring.shape, ring.center, ring.inner_size, ring.size], [Telegraph.SHAPE_RING, stood, 40.0, 72.0])
		assert_eq(ring.hit_tick - core.tick, 37, "40 ticks after the landing")
		core.player.position = stood + case[0]
		var hp: int = core.player.hp
		_steps(core, 50)
		assert_eq(hp - core.player.hp, case[1], "standing %s from the crater" % case[0])


func test_the_combo_is_three_blows_in_a_row() -> void:
	var core: ExploreCore = _fight()
	var hit: int = _force(core, &"gold_combo", SPOTS[&"gold_combo"])
	var warnings: Array = core.snapshot().telegraphs
	assert_eq(warnings.size(), 3)
	assert_eq([warnings[1].hit_tick - hit, warnings[2].hit_tick - hit], [26, 52])
	var forward: Vector2 = (SPOTS[&"gold_combo"] as Vector2).normalized()
	assert_near(warnings[1].center.distance_to(warnings[0].center), 56.0, 0.1)
	assert_true(forward.dot((warnings[2].center - warnings[0].center).normalized()) > 0.99, "marching away from it")


func test_the_charge_carries_the_body_down_its_lane() -> void:
	var core: ExploreCore = _fight()
	var hit: int = _force(core, &"red_charge", SPOTS[&"red_charge"])
	core.player.position = HOME + Vector2(-150, 60)  # out of the way
	_steps(core, hit - core.tick - 1)
	assert_eq(_boss(core).position, HOME, "it stands while it warns")
	_steps(core, 14)
	var travelled: Vector2 = _boss(core).position - HOME
	assert_true(travelled.length() > 200.0, "it ran: %s" % travelled)
	assert_true((SPOTS[&"red_charge"] as Vector2).normalized().dot(travelled.normalized()) > 0.98, "along the lane")


## From every spot near it where an attack may start, there is a straight way (standing still counts) to a spot outside all of
## that attack's warnings: on foot within the warning in phase 1; with one dash (24 px more) within the shorter warnings of phases 2
## and 3. A follow-up warning is checked the same way from wherever he may stand when it begins.
func test_every_warning_leaves_a_way_out() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	var trapped: Array[String] = []
	for phase: int in [1, 2, 3]:
		boss.phase = phase
		for row: Dictionary in Tuning.COLOSSUS_ATTACKS:
			if int(row["phase"]) > phase:
				continue
			for angle: int in 16:
				for dist: float in [53.0, 60.0, 75.0, 90.0, 110.0, 130.0, 150.0, 175.0, 200.0, 230.0]:
					if dist < float(row["start_min"]) or dist > float(row["start_max"]):
						continue
					var at: Vector2 = HOME + Vector2.from_angle(TAU * angle / 16.0) * dist
					if not boss.sees(at):
						continue
					core.player.position = at
					var first: Array[Telegraph] = boss.build_warnings(core, core.mobs, row)
					if row["id"] == Colossus.ATTACK_FLARE:  # each ring and the blow on its own beat (stand in a gap, dash through, parry)
						for w: Telegraph in first:
							if not _has_way_out([w], at, _way_ticks(w.hit_tick - core.tick, phase)):
								trapped.append("song_flare %s %.0f..%.0f phase %d at %s" % [w.shape, w.inner_size, w.size, phase, at - HOME])
					elif not _has_way_out(first, at, _way(int(row["windup"]), phase)):
						trapped.append("%s phase %d at %s" % [row["id"], phase, at - HOME])
					if not row.has("follow"):
						continue
					for near: float in [0.0, 20.0, 40.0, 56.0, 72.0, 90.0]:  # where he may be when the follow-up begins
						var there: Vector2 = first[0].center + Vector2.from_angle(TAU * angle / 16.0 + 0.4) * near
						if there.distance_to(HOME) < 52.0:
							continue  # inside the body: never
						core.player.position = there
						if not _has_way_out(boss.build_follow(core, core.mobs, row, first[0]), there, _way(int(row["follow"]["windup"]), phase)):
							trapped.append("%s follow-up phase %d at %s" % [row["id"], phase, there - HOME])
	assert_eq(trapped, [] as Array[String])


## How far he gets during a warning of `windup` ticks in `phase` (a dash adds 24 px from phase 2 on).
func _way(windup: int, phase: int) -> float:
	var factor: float = 1.0 if phase == 1 else Tuning.COLOSSUS_PHASE2_WINDUP_FACTOR
	return _way_ticks(roundi(windup * factor), phase)


## How far he gets in `ticks` already counted (a dash adds 24 px from phase 2 on).
func _way_ticks(ticks: int, phase: int) -> float:
	var way: float = ticks * Tuning.PLAYER_SPEED
	if phase > 1:
		way += (Tuning.DASH_SPEED - Tuning.PLAYER_SPEED) * Tuning.DASH_TICKS
	return way


func _has_way_out(warnings: Array, from: Vector2, way: float) -> bool:
	var body: float = 46.0 + Tuning.PLAYER_RADIUS
	for k: int in 64:
		var step: float = 0.0
		while step <= way:
			var to: Vector2 = from + Vector2.from_angle(TAU * k / 64.0) * step
			step += 2.0
			if Geometry2D.get_closest_point_to_segment(HOME, from, to).distance_to(HOME) < body - 0.5:
				break  # the way leads through the body
			var clear: bool = true
			for warning: Telegraph in warnings:
				if warning.overlaps_circle(to, Tuning.PLAYER_RADIUS):
					clear = false
					break
			if clear:
				return true
	return false


# ---- choosing, phases, sight ------------------------------------------------------------------------------------------------

func test_it_attacks_only_a_hero_it_can_see_and_walks_closer_otherwise() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	boss.cooldown = 1
	core.player.position = HOME + Vector2(0, 130)
	var events: Array[GameEvent] = _steps(core, 20)
	assert_eq(_of(events, GameEvent.ATTACK_TELEGRAPHED).size(), 0, "too far below to be seen whole")
	assert_true(boss.position.y > HOME.y + 8.0, "it walks down to him")
	var later: Array[GameEvent] = _steps(core, 120)
	assert_true(_of(later, GameEvent.ATTACK_TELEGRAPHED).size() >= 1, "then it attacks")


func test_phase_two_starts_at_sixty_percent_with_a_roar_and_two_more_attacks() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	var ids: Callable = func(dist: float) -> Array: return boss.choices(dist).map(func(r: Dictionary) -> StringName: return r["id"])
	for later: StringName in [&"gold_combo", &"red_charge", &"boulder_toss", &"heartroot_grab"]:
		assert_false((ids.call(120.0) as Array).has(later), "not in phase 1: " + String(later))
	assert_true((ids.call(120.0) as Array).has(&"root_snare"), "the snare is in every phase")
	boss.hp = 362
	_force(core, &"gold_slam", SPOTS[&"gold_slam"])
	var events: Array[GameEvent] = _hit(core, 8.0, _swing())
	assert_eq([boss.hp, boss.phase, boss.state], [360, 2, &"roar"])
	assert_eq(_of(events, GameEvent.BOSS_PHASE_CHANGED)[0].data["phase"], 2)
	assert_true(boss.telegraph == null, "the attack it was making is dropped")
	for later: StringName in [&"gold_combo", &"red_charge", &"boulder_toss", &"heartroot_grab"]:
		assert_true((ids.call(120.0) as Array).has(later), "joins in phase 2: " + String(later))
	_steps(core, Tuning.COLOSSUS_ROAR_TICKS + 1)
	assert_eq([boss.state, boss.cooldown <= Tuning.COLOSSUS_COOLDOWN_TICKS[1]], [&"chase", true])
	var hit: int = _force(core, &"gold_slam", SPOTS[&"gold_slam"])
	assert_eq(hit - core.tick, roundi(60 * Tuning.COLOSSUS_PHASE2_WINDUP_FACTOR), "shorter warnings")


func test_phase_three_starts_at_a_quarter_and_one_big_blow_can_skip_to_it() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	boss.phase = 2
	boss.hp = 152
	var events: Array[GameEvent] = _hit(core, 8.0, _swing())
	assert_eq([boss.hp, boss.phase, boss.state], [150, 3, &"roar"])
	assert_eq(_of(events, GameEvent.BOSS_PHASE_CHANGED)[0].data["phase"], 3)
	_steps(core, Tuning.COLOSSUS_ROAR_TICKS + 1)
	assert_eq(boss.cooldown <= Tuning.COLOSSUS_COOLDOWN_TICKS[2], true, "the shortest pause between attacks")
	var other: ExploreCore = _fight()
	var big: Colossus = _boss(other)
	var jump: Array[GameEvent] = _hit(other, 2000.0, _swing())  # 500 of 600 in one counter-less blow
	assert_eq([big.phase, _of(jump, GameEvent.BOSS_PHASE_CHANGED).size()], [3, 1], "straight to phase 3, one roar")
	var flare: Callable = func(b: Colossus) -> bool: return b.choices(100.0).any(func(r: Dictionary) -> bool: return r["id"] == Colossus.ATTACK_FLARE)
	assert_true(flare.call(boss), "the Song Flare in phase 3")
	boss.phase = 2
	assert_false(flare.call(boss), "not before")


# ---- part 3c: the Song Flare and the Briar Ring ----------------------------------------------------------------------------------

func test_the_song_flare_leaves_gaps_and_any_parry_of_its_gold_blow_breaks_it() -> void:
	var core: ExploreCore = _fight()
	_force(core, Colossus.ATTACK_FLARE, Vector2(160, 0))  # between the second and the third ring, outside the gold blow
	var warnings: Array = core.snapshot().telegraphs
	assert_eq(warnings.map(func(w: Variant) -> StringName: return w.kind), [&"red", &"red", &"red", &"gold"])
	assert_eq([warnings[1].hit_tick - warnings[0].hit_tick, warnings[2].hit_tick - warnings[0].hit_tick, warnings[3].hit_tick - warnings[0].hit_tick], [18, 36, 90], "the beats")
	var hp: int = core.player.hp
	_steps(core, warnings[3].end_tick - core.tick + 5)
	assert_eq(core.player.hp, hp, "the gap between the rings is safe")
	var other: ExploreCore = _fight()
	_force(other, Colossus.ATTACK_FLARE, Vector2(100, 0))  # between the first two rings, inside the gold blow
	var blow: Variant = other.snapshot().telegraphs[3]
	_steps(other, int(blow.hit_tick) - other.tick - 10)
	var events: Array[GameEvent] = _steps(other, 1, input(Vector2.ZERO, false, true))
	events.append_array(_steps(other, 11))
	assert_eq(_of(events, GameEvent.PARRY_SUCCEEDED)[0].data["quality"], &"early")
	assert_eq(_boss(other).state, &"posture_broken", "an early parry breaks it too")


func test_the_briar_ring_rises_at_each_phase_and_hurts_outside_its_circle() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	boss.hp = 362
	var events: Array[GameEvent] = _hit(core, 8.0, _swing())
	var ring: Telegraph = boss.briar
	assert_true(ring != null, "it rises with phase 2")
	assert_eq([ring.shape, ring.kind, ring.center, ring.inner_size, ring.size], [Telegraph.SHAPE_RING, &"red", Vector2(512, 410), 170.0, 420.0])
	assert_eq([ring.hit_tick - core.tick, ring.end_tick - ring.hit_tick], [270, 599], "4.5 s of warning, 10 s standing")
	assert_true(_of(events, GameEvent.ATTACK_TELEGRAPHED).any(func(e: GameEvent) -> bool: return e.data["attack"] == Colossus.BRIAR), "announced")
	assert_true(core.snapshot().telegraphs.any(func(w: Variant) -> bool: return w.attack == Colossus.BRIAR), "drawn")
	boss.state = &"stagger"  # held still: only the briars act
	boss.stun_left = 100000
	core.player.position = Vector2(512, 600)  # outside the circle
	var hp: int = core.player.hp
	_steps(core, ring.hit_tick - core.tick - 1)
	assert_eq(core.player.hp, hp, "nothing during its warning")
	_steps(core, 100)
	assert_eq(hp - core.player.hp, 24, "8 every 48 ticks outside")
	core.player.position = Vector2(400, 430)  # inside
	hp = core.player.hp
	_steps(core, 200)
	assert_eq(core.player.hp, hp, "safe inside")
	boss.hp = 152
	_hit(core, 8.0, _swing())
	assert_true(boss.briar != ring and boss.briar.start_tick == core.tick, "phase 3 raises a new one")
	_steps(core, 270 + 600 + 2)
	assert_true(boss.briar == null, "and it goes")
	boss.hp = 100
	boss.phase = 2
	_hit(core, 8.0, _swing())
	boss.briar = null
	var dying: ExploreCore = _fight()
	var last: Colossus = _boss(dying)
	last.hp = 362
	_hit(dying, 8.0, _swing())
	last.hp = 1
	_hit(dying, 400.0, _swing())
	assert_true(last.briar == null, "its fall ends it")


## From anywhere he can stand in the clearing (above the sealed climb), its warning leaves time to walk into the safe circle.
func test_the_briar_ring_leaves_time_to_walk_in_from_anywhere() -> void:
	var def: Dictionary = SceneDefs.get_def(SCENE)
	var flood: LayoutFlood = LayoutFlood.new(def["size"], SceneDefs.build_obstacles(SCENE), Tuning.PLAYER_RADIUS)
	flood.flood(HOME + Vector2(0, 80))
	var spec: Dictionary = Tuning.COLOSSUS_BRIAR
	var centre: Vector2 = Vector2(512, 410)
	var worst: float = 0.0
	var y: float = 8.0
	while y < 672.0:
		var x: float = 8.0
		while x < 1016.0:
			if flood.reaches(Vector2(x, y)):
				worst = maxf(worst, Vector2(x, y).distance_to(centre) - (float(spec["safe_radius"]) - Tuning.PLAYER_RADIUS))
			x += 12.0
		y += 12.0
	assert_true(worst > 100.0, "the flood found the clearing: %s" % worst)
	assert_true(worst <= float(spec["windup"]) * Tuning.PLAYER_SPEED, "the farthest walk in (%.0f px) fits its %d ticks" % [worst, int(spec["windup"])])


func test_it_does_not_repeat_the_attack_it_just_used() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	var seen: Array[StringName] = []
	boss.cooldown = 1  # _fight() held it
	for i: int in 1500:
		core.player.position = boss.position + Vector2(100, 40)
		core.player.hp = 100
		boss.position = HOME
		core.step(InputFrame.new())
		for e: GameEvent in _of(core.last_events, GameEvent.ATTACK_TELEGRAPHED):
			if not bool(e.data.get("follow", false)):  # a follow-up is part of the same attack
				seen.append(e.data["attack"])
	assert_true(seen.size() >= 8, "it kept attacking: %d" % seen.size())
	for i: int in range(1, seen.size()):
		assert_true(seen[i] != seen[i - 1], "twice in a row: %s" % seen[i])
	assert_true(seen.has(&"gold_slam") and seen.has(&"red_stomp") and seen.has(&"red_shards"), "it varies: %s" % [seen])


# ---- weapons and aspects ----------------------------------------------------------------------------------------------------

func test_reapers_coil_drags_it_and_stuns_it_without_a_counter_window() -> void:
	var core: ExploreCore = _fight(HOME + Vector2(130, 0))
	core.set_loadout(&"chain_scythe", core.player.equipped_aspects)
	core.player.edge = 100.0
	var boss: Colossus = _boss(core)
	_force(core, &"red_stomp", Vector2(130, 0))
	var frame: InputFrame = InputFrame.new()
	frame.weapon_active_pressed = true
	frame.aim = Vector2.LEFT
	core.step(frame)
	var events: Array[GameEvent] = []
	for i: int in 40:
		core.step(InputFrame.new())
		events.append_array(core.last_events)
		if not _of(core.last_events, GameEvent.REAPER_COIL_DRAG).is_empty():
			break
	assert_eq(_of(events, GameEvent.REAPER_COIL_HOOKED)[0].data["cancelled_attack"], &"red_stomp")
	assert_true(boss.position.x > HOME.x + 40.0, "dragged toward him: %s" % boss.position)
	# let go and stepped in the same tick: the stun counts that tick (as the arena's end_drag does)
	assert_eq([boss.state, boss.is_exposed(), boss.stun_left], [&"stagger", false, Tuning.COLOSSUS_STUN_TICKS - 1])
	assert_eq(_of(events, GameEvent.REAPER_COIL_DRAG)[0].data["stagger_ticks"], Tuning.COLOSSUS_STUN_TICKS)
	_steps(core, Tuning.COLOSSUS_STUN_TICKS + Tuning.COLOSSUS_STUN_RECOVER_TICKS + 3)
	assert_eq(boss.state, &"chase", "it shakes it off")


func test_a_stone_ward_takes_the_blow_once() -> void:
	var core: ExploreCore = _fight()
	var aspects: Array[StringName] = [&"stone_ward", &"echo_step", &"sprint"]  # a loadout is always three
	core.set_loadout(KATANA, aspects)
	core.player.edge = 100.0
	var hit: int = _force(core, &"red_stomp", SPOTS[&"red_stomp"])
	_steps(core, hit - core.tick - 12)
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = 1
	var events: Array[GameEvent] = _steps(core, 1, frame)
	events.append_array(_steps(core, 30))
	assert_eq(_of(events, GameEvent.WARD_BLOCKED).size(), 1)
	assert_eq(core.player.hp, core.hero_max_hp(), "blocked")


# ---- the end ----------------------------------------------------------------------------------------------------------------

func test_its_fall_clears_rootcrown_lights_the_beacon_opens_the_climb_and_pays() -> void:
	var core: ExploreCore = _fight()
	var boss: Colossus = _boss(core)
	boss.hp = 1
	var exp_before: int = core.exp_total
	var frame: InputFrame = input(Vector2.ZERO, false, false, true)
	frame.aim = Vector2.LEFT
	core.player.position = HOME + Vector2(62, 0)
	core.step(frame)
	var events: Array[GameEvent] = _steps(core, 30)
	assert_eq(_of(events, GameEvent.MOB_DEFEATED).size(), 1)
	assert_eq(_of(events, GameEvent.ENCOUNTER_CLEARED).size(), 1)
	assert_eq(_of(events, GameEvent.ARENA_OPENED).size(), 1)
	assert_true(core.has_flag(&"cleared_rootcrown") and core.has_flag(&"killed_rootcrown_1"))
	assert_eq(core.exp_total - exp_before, 200)
	var again: ExploreCore = ExploreCore.new(SCENE)
	again.set_story_flags(core.story_flags.duplicate())
	assert_eq(again.mobs.living().size(), 0, "it stays dead after CONTINUE")
	assert_eq(again.snapshot().encounters[0]["state"], &"cleared")


func test_the_same_inputs_make_the_same_fight() -> void:
	var logs: Array = []
	for run_index: int in 2:
		var core: ExploreCore = _core()
		core.player.position = HOME + Vector2(90, 60)
		var log: Array = []
		for i: int in 900:
			core.step(input(Vector2.LEFT if i % 200 < 100 else Vector2.RIGHT, i % 90 == 0))
			var boss: Colossus = _boss(core)
			log.append([boss.state, boss.position, core.player.hp, core.player.position])
		logs.append(log)
	assert_true(logs[0] == logs[1], "deterministic")
