extends SceneTree
## Integration contract checks; synthetic future snapshots do not claim core gameplay is implemented.
const FX := preload("res://presentation/explore/creature_effects.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
const Explore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CREATURE FX FAIL: ", label)

func run() -> void:
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	var v: Explore.ExploreSnapshot = Explore.ExploreSnapshot.new()
	v.scene_id = &"glade_layered"
	v.tick = 10
	var boss: Dictionary = {"id": 201, "type": &"stag", "position": Vector2(100,100), "facing": Vector2.RIGHT, "state": &"windup", "state_ticks": 0, "hp": 100, "attack_id": &"stag_roots"}
	v.mobs.append(boss)
	for i: int in 8:
		var t: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		t.id = 100 + i
		t.owner_id = 201
		t.attack = &"stag_roots"
		t.center = Vector2(50 + i * 40, 150)
		t.size = 34
		t.hit_tick = 20
		t.end_tick = 25
		v.telegraphs.append(t)
	var fx: FX = FX.new()
	fx.sync(v)
	check(fx.ground_plans(v).size() == 8, "one distinct root effect for each core-provided warning")
	for i: int in 8:
		check(fx.ground_plans(v)[i]["at"] == v.telegraphs[i].center, "root centre matches warning")
		check(frames.has(fx.ground_plans(v)[i]["frame"]), "root effect source registered")
	var before: String = var_to_str(v.mobs)
	fx.sync(v)
	check(fx.ground_plans(v).size() == 8 and var_to_str(v.mobs) == before, "pause repeat does not duplicate or mutate")
	v.tick = 20
	boss["state"] = &"strike"
	fx.sync(v)
	v.tick = 25
	boss["state"] = &"recover"
	v.telegraphs.clear()
	fx.sync(v)
	check(fx.ground_plans(v).size() == 8, "root recovery stays at committed positions")
	v.tick = 26
	boss["state"] = &"dead"
	fx.sync(v)
	check(fx.ground_plans(v).is_empty(), "dead owner clears effects")
	for species: String in ["stag", "glowmoth"]:
		for state: String in MobView.STATES[species]:
			for attack: StringName in [&"stag_slam", &"stag_charge", &"stag_roots", &"stag_summon"]:
				for age: int in [0, 3, 30, 75, 150]:
					var mob: Dictionary = {"id":201,"type":StringName(species),"state":StringName(state),"state_ticks":age,"attack_id":attack}
					check(frames.has(MobView.frame(mob, v.telegraphs, 150)), "registered pose: %s %s" % [species,state])
	boss["state"] = &"windup"
	v.tick = 40
	var cone: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	cone.id = 900
	cone.owner_id = 201
	cone.attack = &"stag_slam"
	cone.size = 147.0 # Arbitrary enlarged core-provided geometry, never replaced by a hard-coded FX radius.
	cone.hit_tick = 41
	cone.end_tick = 47
	v.telegraphs.append(cone)
	fx.sync(v)
	v.tick = 41
	boss["state"] = &"strike"
	fx.sync(v)
	check(fx.tells[900].size == 147.0, "larger core cone kept exactly")
	v.tick = 42
	boss["state"] = &"stagger"
	fx.sync(v)
	check(fx.ground_plans(v).is_empty(), "parry cancellation removes slam")
	v.tick = 43
	boss["state"] = &"idle"
	boss["hp"] = 105
	fx.sync(v)
	check(fx.heals.size() == 1, "healing pulse comes from real HP increase")
	fx.sync(v)
	check(fx.heals.size() == 1, "same-tick HP pulse not duplicated")
	v.scene_id = &"forest_layered"
	v.tick = 44
	fx.sync(v)
	check(fx.heals.is_empty() and fx.tells.is_empty(), "scene transition clears history")
	v.telegraphs.clear()
	var cast: Dictionary = {"id":201,"type":&"stag","state":&"windup","state_ticks":50,"attack_id":&"stag_summon","cast_start_tick":10,"cast_release_tick":110}
	check(MobView.frame(cast, v.telegraphs, 60) == "stag_chant_right_15", "chant follows non-damaging core cast progress")
	check(v.telegraphs.is_empty(), "chant pose never manufactures a damage warning")
	if failures == 0:
		print("CREATURE FX OK")
	quit(1 if failures else 0)
