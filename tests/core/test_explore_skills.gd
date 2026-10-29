extends "res://tests/test_case.gd"
## The hero's Aspects on the road (core/explore_skills.gd), against the Woodland Approach's mobs: every skill goes through
## MobField.hit_mob(), the Stone Ward's shockwave hits mobs in its radius, the Spirit Lantern heals the hero standing in it, an
## Echo Step pulls him back to its anchor, a Phantom Cut echo lands on the mob that was hit, and the loadout decides what Z/X/C do.

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")
const Aspects := preload("res://core/aspects.gd")

const ALL_UNLOCKED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
const ENCOUNTER: StringName = &"mossling_clearing"


func _core(aspect: StringName) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SceneDefs.WOODLAND_LAYERED)
	core.set_story_flags(ALL_UNLOCKED)
	core.set_loadout(&"black_katana", _loadout(aspect))
	core.player.edge = Tuning.EDGE_MAX
	return core


## The aspect in slot 1, two others (never the same one twice) after it.
func _loadout(first: StringName) -> Array[StringName]:
	var out: Array[StringName] = [first]
	for other: StringName in [Aspects.SPRINT, Aspects.GALE_CUT, Aspects.MOON_CLEAVE]:
		if out.size() < 3 and other != first:
			out.append(other)
	return out


func _enc(core: ExploreCore) -> MobField.Encounter:
	for enc: MobField.Encounter in core.mobs.encounters:
		if enc.id == ENCOUNTER:
			return enc
	return null


## The hero beside the first living mob of the clearing, facing it, one pixel closer than the mob's own body.
func _stand_next_to_a_mob(core: ExploreCore) -> Mob:
	var mob: Mob = _enc(core).mobs[0]
	core.player.position = mob.position + Vector2(-30, 0)
	core.player.facing = Vector2.RIGHT
	return mob


func _press(slot: int, aim: Vector2 = Vector2.RIGHT) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.skill_pressed = slot
	f.aim = aim
	return f


func _events(core: ExploreCore, type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in core.last_events:
		if e.type == type:
			out.append(e)
	return out


## Steps `ticks` ticks (an idle frame after the first one) and collects every event of `type`.
func _run(core: ExploreCore, first: InputFrame, ticks: int, type: StringName) -> Array[GameEvent]:
	var seen: Array[GameEvent] = []
	core.step(first)
	seen.append_array(_events(core, type))
	for i: int in ticks:
		core.step(InputFrame.new())
		seen.append_array(_events(core, type))
	return seen


func test_every_aspect_can_be_used_on_the_road() -> void:
	for aspect: StringName in Aspects.ALL:
		var core: ExploreCore = _core(aspect)
		var slot: Dictionary = core.snapshot().aspect_slots[0]
		assert_eq(slot["aspect"], aspect)
		assert_true(slot["usable"], "%s is usable on the road" % aspect)


func test_breaking_edge_hits_a_mob_in_front_of_the_hero_once() -> void:
	var core: ExploreCore = _core(Aspects.BREAKING_EDGE)
	var mob: Mob = _stand_next_to_a_mob(core)
	core.player.retaliate_ticks = 60  # Breaking Edge is the answer to a parry: it needs the retaliation window
	var hp: int = mob.hp
	var hits: Array[GameEvent] = _run(core, _press(1), 40, GameEvent.ATTACK_HIT)
	assert_eq(hits.size(), 1, "one cast hits a mob once")
	assert_eq(hits[0].data["skill_id"], Aspects.BREAKING_EDGE)
	assert_eq(hits[0].data["target_id"], mob.id)
	assert_true(mob.hp < hp, "the mob lost health")


func test_moon_cleave_flies_and_hits_a_mob_down_the_line() -> void:
	var core: ExploreCore = ExploreCore.new(SceneDefs.WOODLAND_LAYERED)
	core.set_story_flags(ALL_UNLOCKED)
	core.set_loadout(&"black_katana", _loadout(Aspects.MOON_CLEAVE))
	core.player.edge = Tuning.EDGE_MAX
	var mob: Mob = _enc(core).mobs[0]
	core.player.position = mob.position + Vector2(-90, 0)
	core.player.facing = Vector2.RIGHT
	var hits: Array[GameEvent] = _run(core, _press(1), 60, GameEvent.ATTACK_HIT)
	assert_true(hits.size() >= 1, "the projectile reached the mob")
	assert_eq(hits[0].data["skill_id"], Aspects.MOON_CLEAVE)


func test_stone_ward_release_hits_a_mob_in_its_radius() -> void:
	var core: ExploreCore = _core(Aspects.STONE_WARD)
	var mob: Mob = _stand_next_to_a_mob(core)
	core.player.position = mob.position + Vector2(-20, 0)
	var hp: int = mob.hp
	var released: Array[GameEvent] = _run(core, _press(1), Tuning.STONE_WARD_DURATION_TICKS + 20, GameEvent.WARD_RELEASED)
	assert_eq(released.size(), 1, "the ward ended with one shockwave")
	assert_true(bool(released[0].data["hit"]), "the mob stood inside the radius")
	assert_true(mob.hp < hp, "the shockwave hurt it")


func test_spirit_lantern_heals_the_hero_standing_in_its_light() -> void:
	var core: ExploreCore = _core(Aspects.SPIRIT_LANTERN)
	core.player.hp = 40  # he stays where the scene put him: no mob is awake there
	var placed: Array[GameEvent] = _run(core, _press(1), Tuning.SPIRIT_LANTERN_DURATION_TICKS + 60, GameEvent.LANTERN_PLACED)
	assert_eq(placed.size(), 1)
	assert_true(core.player.hp > 40, "the pulses healed him")
	assert_true(core.snapshot().lanterns.is_empty(), "the lantern is gone after its last pulse")


func test_echo_step_pulls_the_hero_back_to_where_he_stood() -> void:
	var core: ExploreCore = _core(Aspects.ECHO_STEP)
	core.player.position = Vector2(112, 276)
	var anchor: Vector2 = core.player.position
	var placed: Array[GameEvent] = _run(core, _press(1), 5, GameEvent.ECHO_PLACED)
	assert_eq(placed.size(), 1, "the anchor was placed")
	assert_eq(core.snapshot().echoes.size(), 1)
	var walk: InputFrame = InputFrame.new()
	walk.move = Vector2.LEFT
	for i: int in 30:
		core.step(walk)
	assert_true(core.player.position.distance_to(anchor) > 5.0, "he walked away")
	var recalled: Array[GameEvent] = []
	for i: int in Tuning.ECHO_STEP_DELAY_TICKS:
		core.step(InputFrame.new())
		recalled.append_array(_events(core, GameEvent.ECHO_RECALL))
	assert_eq(recalled.size(), 1, "the recall happened once")
	assert_true(core.player.position.distance_to(anchor) < 3.0, "he stands at the anchor again")


func test_phantom_cut_echo_lands_on_the_mob_that_was_hit() -> void:
	var core: ExploreCore = _core(Aspects.PHANTOM_CUT)
	var mob: Mob = _stand_next_to_a_mob(core)
	core.step(_press(1))
	for i: int in 30:
		core.step(InputFrame.new())
	assert_true(core.player.phantom_ticks_left > 0, "Phantom Cut is running")
	core.player.position = mob.position + Vector2(-26, 0)
	core.player.facing = Vector2.RIGHT
	var swing: InputFrame = InputFrame.new()
	swing.attack_pressed = true
	swing.attack_held = true
	swing.aim = Vector2.RIGHT
	var echoes: int = 0
	var echo_hits: int = 0
	core.step(swing)
	for i: int in Tuning.PHANTOM_CUT_DELAY_TICKS + 40:
		core.step(InputFrame.new())
		echoes += _events(core, GameEvent.PHANTOM_ECHO).size()
		for e: GameEvent in _events(core, GameEvent.ATTACK_HIT):
			if bool(e.data.get("echo", false)):
				echo_hits += 1
	assert_eq(echoes, 1, "one echo followed the swing")
	assert_eq(echo_hits, 1, "and it hit")


func test_the_same_inputs_give_the_same_skill_fight() -> void:
	var results: Array[String] = []
	for run: int in 2:
		var core: ExploreCore = _core(Aspects.BREAKING_EDGE)
		_stand_next_to_a_mob(core)
		core.step(_press(1))
		for i: int in 60:
			core.step(InputFrame.new())
		results.append("%d|%d|%d" % [_enc(core).mobs[0].hp, core.player.hp, int(core.player.edge)])
	assert_eq(results[0], results[1])


func test_black_form_runs_on_the_road_and_the_boss_actives_refuse() -> void:
	var core: ExploreCore = _core(Aspects.SPRINT)
	core.player.edge = Tuning.EDGE_MAX
	var press: InputFrame = InputFrame.new()
	press.weapon_active_pressed = true
	var started: int = 0
	core.step(press)
	for e: GameEvent in core.last_events:
		if e.type == GameEvent.WEAPON_BUFF_STARTED:
			started += 1
	assert_eq(started, 1, "the katana's Black Form starts on the road")
	assert_true(core.snapshot().hero.weapon_buff_active, "the snapshot says it runs")
	var dagger: ExploreCore = _core(Aspects.SPRINT)
	dagger.set_loadout(&"dual_dagger", _loadout(Aspects.SPRINT))
	dagger.player.edge = Tuning.EDGE_MAX
	dagger.step(press)
	assert_false(dagger.snapshot().hero.weapon_buff_active, "Lightning Form needs a boss: it does not start here")
	var scythe: ExploreCore = _core(Aspects.SPRINT)
	scythe.set_loadout(&"chain_scythe", _loadout(Aspects.SPRINT))
	scythe.player.edge = Tuning.EDGE_MAX
	scythe.step(press)
	assert_false(scythe.snapshot().hero.weapon_buff_active, "Reaper's Coil needs a boss: it does not start here")
