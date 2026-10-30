extends "res://tests/test_case.gd"
## The Thornback Stag (the glade's mini-boss: Tuning.MOBS[stag], the encounter stag_glade in data/scenes/glade_layered_props.json): one mob with a
## gold antler slam (parry it), a red charge (dash across it) and, after it roars at half health, red roots; defeating it clears the glade,
## pays the reward and opens the root arch to the arena (closed with a message until then).

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")

const SCENE: StringName = SceneDefs.GLADE_LAYERED
const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]


func _core() -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.set_story_flags(ARMED)
	return core


func _stag(core: ExploreCore) -> Mob:
	return core.mobs.encounters[0].mobs[0]


func _events(core: ExploreCore, type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in core.last_events:
		if e.type == type:
			out.append(e)
	return out


## Steps until `type` shows up (returns the first such event) or `limit` ticks pass.
func _until_event(core: ExploreCore, type: StringName, limit: int, input: Callable = Callable()) -> GameEvent:
	for i: int in limit:
		core.step(input.call(core) if input.is_valid() else InputFrame.new())
		var found: Array[GameEvent] = _events(core, type)
		if not found.is_empty():
			return found[0]
	return null


func test_the_stag_is_the_glades_one_mob() -> void:
	var core: ExploreCore = _core()
	assert_eq(core.mobs.encounters.size(), 1)
	var stag: Mob = _stag(core)
	assert_eq(stag.type, &"stag")
	assert_eq(stag.radius, 20.0, "it keeps the Colossus's body size")
	assert_eq(stag.attacks().size(), 4, "slam, charge, roots and the summoning chant")
	assert_true(bool(core.snapshot().mobs[0]["boss"]), "the snapshot marks it as the boss")


func test_close_up_it_slams_with_a_gold_cone_and_far_away_it_charges_with_a_red_line() -> void:
	var near: ExploreCore = _core()
	var stag: Mob = _stag(near)
	near.player.position = stag.position + Vector2(-40, 0)
	var told: GameEvent = _until_event(near, GameEvent.ATTACK_TELEGRAPHED, 120)
	assert_true(told != null and told.data["attack"] == &"stag_slam" and told.data["kind"] == &"gold", "a gold slam up close")
	assert_eq(stag.telegraph.shape, Telegraph.SHAPE_CONE, "drawn as a cone")
	var far: ExploreCore = _core()
	var other: Mob = _stag(far)
	far.player.position = other.position + Vector2(-120, 0)
	var charge: GameEvent = _until_event(far, GameEvent.ATTACK_TELEGRAPHED, 160)
	assert_true(charge != null and charge.data["attack"] == &"stag_charge" and charge.data["kind"] == &"red", "a red charge from afar")
	assert_eq(other.telegraph.shape, Telegraph.SHAPE_LINE, "drawn as a line")


func test_a_slam_that_is_not_parried_wounds_and_a_parried_one_stuns_the_stag() -> void:
	var hit: ExploreCore = _core()
	var stag: Mob = _stag(hit)
	hit.player.position = stag.position + Vector2(-34, 0)
	var hp: int = hit.player.hp
	for i: int in 140:
		hit.step(InputFrame.new())
	assert_true(hit.player.hp < hp, "the slam hurt him")
	var parried: ExploreCore = _core()
	var other: Mob = _stag(parried)
	parried.player.position = other.position + Vector2(-34, 0)
	var stunned: bool = false
	for i: int in 160:
		var f: InputFrame = InputFrame.new()
		if other.state == &"windup" and other.state_ticks >= int(other.attack_stats()["windup"]) - 5 and other.state_ticks <= int(other.attack_stats()["windup"]):
			f.parry_pressed = true
		parried.step(f)
		if not _events(parried, GameEvent.MOB_STAGGERED).is_empty():
			stunned = true
			break
	assert_true(stunned, "a parry stuns it")
	assert_true(other.is_exposed(), "and it is exposed")


func test_at_half_health_it_roars_once_and_then_adds_the_roots() -> void:
	var core: ExploreCore = _core()
	var stag: Mob = _stag(core)
	core.player.position = stag.position + Vector2(-70, 0)
	core.step(InputFrame.new())
	var enc: MobField.Encounter = core.mobs.encounters[0]
	var roars: int = 0
	var events: Array[GameEvent] = []
	while stag.hp > stag.max_hp / 2:
		core.mobs.hit_mob(core, enc, stag, 40.0, {}, events)
	for e: GameEvent in events:
		if e.type == GameEvent.BOSS_PHASE_CHANGED:
			roars += 1
	assert_eq(roars, 1, "one roar")
	assert_eq(stag.state, &"roar")
	assert_eq(stag.phase, 2)
	core.mobs.hit_mob(core, enc, stag, 5.0, {}, events)
	assert_eq(stag.phase, 2, "it never roars twice")
	var seen: bool = false
	for i: int in 500:
		core.player.hp = core.hero_max_hp()
		core.step(InputFrame.new())
		for e: GameEvent in _events(core, GameEvent.ATTACK_TELEGRAPHED):
			if e.data["attack"] == &"stag_roots":
				seen = true
		if seen:
			break
	assert_true(seen, "the roots join its attacks")
	assert_eq(stag.telegraph.shape if stag.telegraph != null else Telegraph.SHAPE_CIRCLE, Telegraph.SHAPE_CIRCLE, "a burst where the hero stood")


func test_freeing_the_stag_clears_the_glade_and_opens_the_root_arch() -> void:
	var core: ExploreCore = ExploreCore.new(SCENE)
	core.set_story_flags([&"received_first_sword"] as Array[StringName])  # no debug flag: it would open every gate
	var stag: Mob = _stag(core)
	# the arch is shut until then
	var arch: Rect2 = core.def["exits"][1]["rect"]
	core.player.position = arch.get_center()
	core.step(InputFrame.new())
	core.exiting = false
	var blocked: bool = false
	for i: int in 3:
		core.player.position = Vector2(arch.position.x - 40, arch.end.y + 20)
		core.step(InputFrame.new())
		core.player.position = arch.get_center()
		core.step(InputFrame.new())
		blocked = blocked or not _events(core, GameEvent.EXIT_BLOCKED).is_empty()
	assert_false(core.exiting, "the arch did not let him through")
	assert_true(blocked, "and it said so")
	var enc: MobField.Encounter = core.mobs.encounters[0]
	var events: Array[GameEvent] = []
	core.player.position = stag.position + Vector2(-40, 0)
	while stag.is_alive():
		core.mobs.hit_mob(core, enc, stag, 60.0, {}, events)
	var cleared: bool = false
	var herbs: bool = false
	for e: GameEvent in events:
		if e.type == GameEvent.ENCOUNTER_CLEARED:
			cleared = true
		if e.type == GameEvent.ITEM_RECEIVED and e.data["item_id"] == &"herb":
			herbs = true
	assert_true(cleared, "the glade is cleared")
	assert_true(herbs, "the reward arrives")
	assert_true(core.has_flag(&"cleared_stag_glade"))
	core.player.position = Vector2(arch.position.x - 40, arch.end.y + 20)
	core.step(InputFrame.new())
	core.player.position = arch.get_center()
	core.step(InputFrame.new())
	assert_true(core.exiting and core.pending_exit["target_scene"] == SceneDefs.ARENA, "now the arch leads to the arena")
