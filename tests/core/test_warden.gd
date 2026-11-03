extends "res://tests/test_case.gd"
## The Runebound Warden (Tuning.MOBS[warden], docs/PLAN_hollow_trial.md): a rune GUARD (hits do 0.4x until a parried gold attack stuns it), a gold
## Rune Cleave that chains into a red Root Lash when it is not parried, a stationary red line, a red burst around itself, and one Warden attacking
## at a time. Built by swapping the glade's Stag for Wardens (the trial room itself is a later step).

const SceneDefs := preload("res://core/scene_defs.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const MobField := preload("res://core/mob_field.gd")
const Mob := preload("res://core/mob.gd")

const ARMED: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]


## The glade with its Stag replaced by `count` Wardens (the first where the Stag stood, the others 60 px apart), the hero tough enough to watch.
func _core(count: int = 1) -> ExploreCore:
	var core: ExploreCore = ExploreCore.new(SceneDefs.GLADE_LAYERED)
	core.set_story_flags(ARMED)
	var enc: MobField.Encounter = core.mobs.encounters[0]
	var home: Vector2 = enc.mobs[0].home
	enc.mobs.clear()
	for i: int in count:
		var w: Mob = Mob.new()
		w.setup(900 + i, &"warden", enc.id, home + Vector2(0, 60 * i), i)
		enc.mobs.append(w)
	core.player.hp = 9999
	return core


func _warden(core: ExploreCore, n: int = 0) -> Mob:
	return core.mobs.encounters[0].mobs[n]


func _events(core: ExploreCore, type: StringName) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for e: GameEvent in core.last_events:
		if e.type == type:
			out.append(e)
	return out


## The attack_hit event of a list (hitting a dormant pack also records encounter_started first).
func _hit(events: Array[GameEvent]) -> GameEvent:
	for e: GameEvent in events:
		if e.type == GameEvent.ATTACK_HIT:
			return e
	return null


func _parry_when_due(w: Mob) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	var windup: int = int(w.attack_stats()["windup"])
	if w.state == &"windup" and w.state_ticks >= windup - 5 and w.state_ticks <= windup:
		f.parry_pressed = true
	return f


## Steps until an attack is telegraphed; returns its event (null after `limit` ticks).
func _until_told(core: ExploreCore, limit: int) -> GameEvent:
	for i: int in limit:
		core.step(InputFrame.new())
		var found: Array[GameEvent] = _events(core, GameEvent.ATTACK_TELEGRAPHED)
		if not found.is_empty():
			return found[0]
	return null


func test_the_warden_has_three_attacks_and_a_guard() -> void:
	var w: Mob = _warden(_core())
	assert_eq(w.attacks().size(), 3, "cleave, lash and ring")
	assert_eq(w.max_hp, 140, "health")
	assert_true(w.is_guarded(), "guarded from the start")
	assert_false(w.is_exposed(), "and not exposed")


func test_a_guarded_hit_does_a_fraction_and_an_exposed_hit_does_triple() -> void:
	var core: ExploreCore = _core()
	var w: Mob = _warden(core)
	var enc: MobField.Encounter = core.mobs.encounters[0]
	var events: Array[GameEvent] = []
	core.mobs.hit_mob(core, enc, w, 10.0, {}, events)
	assert_eq(w.hp, 136, "10 x 0.4 = 4 damage while guarded")
	assert_true(bool(_hit(events).data.get("guarded", false)), "the hit event says it was guarded")
	assert_eq(_hit(events).data["kind"], &"normal", "a normal hit")
	w.set_state(&"stagger")
	events.clear()
	core.mobs.hit_mob(core, enc, w, 10.0, {}, events)
	assert_eq(w.hp, 106, "30 damage while exposed")
	assert_false(_hit(events).data.has("guarded"), "no guard flag on an exposed hit")
	assert_eq(_hit(events).data["kind"], &"counter", "a counter hit")


func test_a_guarded_hit_still_does_at_least_one_damage() -> void:
	var core: ExploreCore = _core()
	var w: Mob = _warden(core)
	var events: Array[GameEvent] = []
	core.mobs.hit_mob(core, core.mobs.encounters[0], w, 1.0, {}, events)
	assert_eq(w.hp, 139, "never zero")


func test_up_close_it_cleaves_with_a_gold_cone() -> void:
	var core: ExploreCore = _core()
	var w: Mob = _warden(core)
	core.player.position = w.position + Vector2(-34, 0)
	var told: GameEvent = _until_told(core, 160)
	assert_true(told != null and told.data["attack"] == &"warden_cleave" and told.data["kind"] == &"gold", "a gold cleave first")
	assert_eq(w.telegraph.shape, Telegraph.SHAPE_CONE, "drawn as a cone")


func test_an_unparried_cleave_chains_into_a_stationary_red_lash() -> void:
	var core: ExploreCore = _core()
	var w: Mob = _warden(core)
	core.player.position = w.position + Vector2(-34, 0)
	var told: Array[StringName] = []
	for i: int in 400:
		core.step(InputFrame.new())
		for e: GameEvent in _events(core, GameEvent.ATTACK_TELEGRAPHED):
			told.append(e.data["attack"])
		if told.size() >= 2:
			break
	assert_eq(told.slice(0, 2), [&"warden_cleave", &"warden_lash"] as Array[StringName], "cleave, then the lash")
	assert_eq(w.telegraph.shape, Telegraph.SHAPE_LINE, "the lash is a line")
	assert_eq(w.telegraph.kind, Telegraph.KIND_RED, "and red")
	assert_near(w.telegraph.size, 150.0, 0.01, "150 long")
	var spot: Vector2 = w.position
	for i: int in 70:
		core.step(InputFrame.new())
	assert_true(w.position.distance_to(spot) < 20.0, "the Warden stood still while it lashed")


func test_a_parried_cleave_stuns_it_drops_the_guard_and_ends_the_chain() -> void:
	var core: ExploreCore = _core()
	var w: Mob = _warden(core)
	core.player.position = w.position + Vector2(-34, 0)
	var stunned: bool = false
	for i: int in 200:
		core.step(_parry_when_due(w))
		if not _events(core, GameEvent.MOB_STAGGERED).is_empty():
			stunned = true
			break
	assert_true(stunned, "the parry stuns it")
	assert_true(w.is_exposed(), "exposed")
	assert_false(w.is_guarded(), "the guard is down")
	assert_eq(w.chain_next, &"", "no lash follows")
	var view: Dictionary = core.mobs.mob_views(core.tick)[0]
	assert_false(bool(view["guarded"]), "the snapshot says so")
	assert_true(bool(view["exposed"]), "and exposed")
	for i: int in Tuning.MOB_STAGGER_TICKS + 2:
		core.step(InputFrame.new())
	assert_false(w.is_exposed(), "the stun ends")
	assert_true(w.is_guarded(), "and the guard is back")


func test_far_away_it_lashes_and_the_ring_is_a_burst_around_itself() -> void:
	var far: ExploreCore = _core()
	var w: Mob = _warden(far)
	far.player.position = w.position + Vector2(-110, 0)
	var told: GameEvent = _until_told(far, 200)
	assert_true(told != null and told.data["attack"] == &"warden_lash", "from afar the lash")
	var close: ExploreCore = _core()
	var other: Mob = _warden(close)
	other.attack_index = 2  # the ring is next in its rotation
	close.player.position = other.position + Vector2(-30, 0)
	var ring: GameEvent = _until_told(close, 200)
	assert_true(ring != null and ring.data["attack"] == &"warden_ring" and ring.data["kind"] == &"red", "a red ring")
	assert_eq(other.telegraph.shape, Telegraph.SHAPE_CIRCLE, "a circle")
	assert_eq(other.telegraph.center, other.position, "centred on the Warden, not on the hero")


func test_two_wardens_never_attack_at_the_same_time() -> void:
	var core: ExploreCore = _core(2)
	core.player.position = _warden(core, 0).position + Vector2(-34, 30)
	var overlap: bool = false
	var seen: Dictionary = {}
	for i: int in 900:
		core.step(InputFrame.new())
		var a: Mob = _warden(core, 0)
		var b: Mob = _warden(core, 1)
		if a.is_attacking():
			seen[0] = true
		if b.is_attacking():
			seen[1] = true
		if a.is_attacking() and b.is_attacking():
			overlap = true
	assert_false(overlap, "never both winding up or striking")
	assert_true(seen.has(0) and seen.has(1), "but they take turns")


func test_the_same_inputs_give_the_same_warden_fight() -> void:
	var trace: Array[String] = []
	for run: int in 2:
		var core: ExploreCore = _core()
		core.player.position = _warden(core).position + Vector2(-34, 0)
		var text: String = ""
		for i: int in 300:
			core.step(InputFrame.new())
			var w: Mob = _warden(core)
			text += "%s%d," % [w.state, int(w.position.x)]
		trace.append(text.sha256_text())
	assert_eq(trace[0], trace[1], "deterministic")
