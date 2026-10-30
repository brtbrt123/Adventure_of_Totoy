extends SceneTree
## Integration contract checks; synthetic future snapshots do not claim core gameplay is implemented.
const FX := preload("res://presentation/explore/creature_effects.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
const Explore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Particles := preload("res://presentation/explore/creature_particles.gd")
const CreatureGlow := preload("res://presentation/explore/creature_glow.gd")
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
	cone.direction = Vector2.LEFT
	cone.half_angle = 0.95
	var far: float = 0.0
	for mark: Dictionary in FX.slam_marks(cone, 20):
		far = maxf(far, Vector2(mark["at"]).distance_to(cone.center))
		check(Vector2(mark["at"]).distance_to(cone.center) <= cone.size + 0.01, "slam marks stay inside the hit cone")
	check(absf(far - cone.size) < 0.5, "slam marks reach the cone's real edge (%s of %s)" % [far, cone.size])
	v.tick = 42
	boss["state"] = &"stagger"
	fx.sync(v)
	check(fx.ground_plans(v).is_empty(), "parry cancellation removes slam")
	v.tick = 43
	boss["state"] = &"idle"
	boss["hp"] = 105
	boss["regen_active"] = true  # pulses follow the core's summon regeneration only
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
	# Orbs: drawn while the core reports them, popped where they were when they vanish; moths that appear get a reveal.
	var o: FX = FX.new()
	var w: Explore.ExploreSnapshot = Explore.ExploreSnapshot.new()
	w.scene_id = &"glade_layered"
	w.tick = 1
	w.mob_projectiles.append({"id": 7, "owner_id": 501, "visual": &"glowmoth_orb", "position": Vector2(10, 10), "direction": Vector2.LEFT, "radius": 4.0, "fired_tick": 1})
	w.mobs.append({"id": 501, "type": &"glowmoth", "position": Vector2(30, 10), "facing": Vector2.LEFT, "state": &"chase", "state_ticks": 0, "hp": 20, "summoner_id": 201})
	o.sync(w)
	check(o.orbs.size() == 1 and o.reveals.size() == 1, "an orb in flight and a summoned moth's reveal")
	w.tick = 2
	w.mob_projectiles.clear()
	o.sync(w)
	check(o.orbs.is_empty() and o.pops.size() == 1 and Vector2(o.pops[0]["at"]) == Vector2(10, 10), "a vanished orb pops where it was")
	check(o.reveals.size() == 1, "a moth is revealed once")
	for key: String in ["fx_glowmoth_orb_1", "fx_glowmoth_orb_pop_4", "fx_ch1_moth_trail_4", "fx_ch1_moth_shadow_1", "woodland_fx_heal_6"]:
		check(frames.has(key), "registered effect " + key)
	var release: Dictionary = {"id":201,"type":&"stag","state":&"recover","state_ticks":2,"attack_id":&"stag_summon","cast_start_tick":10,"cast_release_tick":100}
	check(MobView.frame(release, v.telegraphs, 112) == "stag_summon_right_3", "release frames continue from the release tick into recover")
	# Particles: every kind draws, is deterministic and ends; the slam's start inside the cone the core hit.
	for kind: String in ["slam", "roots", "kick", "crash", "roar", "chant", "release", "heal", "mist", "orb_trail", "pop", "reveal"]:
		var burst: Dictionary = {"kind": kind, "at": Vector2(100, 100), "tick": 0, "seed": 4242, "dir": Vector2.LEFT, "half_angle": 0.95, "size": 145.0}
		var first: Array[Dictionary] = Particles.points(burst, 6)
		check(not first.is_empty(), "particles of " + kind)
		check(var_to_str(first) == var_to_str(Particles.points(burst, 6)), "deterministic " + kind)
		check(Particles.points(burst, Particles.max_life(kind) + 20).is_empty(), "particles of %s end" % kind)
	var slam_burst: Dictionary = {"kind": "slam", "at": Vector2.ZERO, "tick": 0, "seed": 7, "dir": Vector2.LEFT, "half_angle": 0.95, "size": 145.0}
	for li: int in Particles.LAYERS["slam"].size():
		for i: int in int(Particles.LAYERS["slam"][li]["n"]):
			var p0: Vector2 = Particles._spawn(slam_burst, li, i)["origin"]
			check(p0.length() <= 145.01 and absf(Vector2.LEFT.angle_to(p0)) <= 0.95 + 0.001, "slam particles start inside the hit cone")
	var heal_burst: Array[Dictionary] = [{"kind": "heal", "at": Vector2(50, 50), "tick": 0, "seed": 11}]
	check(not CreatureGlow.halo_plan(heal_burst, 8, [], []).is_empty(), "healing particles glow")
	var dust_burst: Array[Dictionary] = [{"kind": "slam", "at": Vector2(50, 50), "tick": 0, "seed": 11, "dir": Vector2.LEFT, "half_angle": 0.9, "size": 100.0}]
	check(CreatureGlow.halo_plan(dust_burst, 8, [], []).is_empty(), "only healing glows")
	if failures == 0:
		print("CREATURE FX OK")
	quit(1 if failures else 0)
