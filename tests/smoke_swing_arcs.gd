extends SceneTree
## The blades' slash matches the swing's hit area (owner 2026-11-02: "check the basic attack range match effects on it"):
## presentation/common/swing_arc.gd draws a crescent whose outer edge is core/weapons.gd swing_reach around the hero's feet and
## whose ends are the swing's arc (swing_arc_dot), turned to his facing. Checks every blade and swing in four facings: every
## pixel lies inside the hit area (within the reach, inside the arc), the outer edge reaches the reach, the arc is centred on the
## facing; the slash shows only while a blade swings; and both real scenes (the road and the fight) show it for a real swing.
const SwingArc := preload("res://presentation/common/swing_arc.gd")
const Arena := preload("res://presentation/arena/arena.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)


func hero(weapon: StringName, swing: int, facing: Vector2, state: StringName = &"attack_active", ticks: int = 0) -> Snapshots.EntitySnapshot:
	var actor: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	actor.weapon_id = weapon
	actor.combo_index = swing
	actor.facing = facing
	actor.state = state
	actor.state_ticks = ticks
	actor.position = Vector2(200, 150)
	return actor


func run() -> void:
	var facings: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized()]
	for weapon: StringName in Weapons.IDS:
		if Weapons.is_ranged(weapon):
			var cast: Snapshots.EntitySnapshot = hero(weapon, 1, Vector2.RIGHT)
			check(SwingArc.plan(cast, false, "totoy_staff_attack1_right_3").is_empty(), "the Star Staff casts: no blade slash")
			continue
		for swing: int in range(1, Weapons.combo_max(weapon) + 1):
			var reach: float = Weapons.swing_reach(weapon, swing)
			var half: float = acos(Weapons.swing_arc_dot(weapon))
			for facing: Vector2 in facings:
				var actor: Snapshots.EntitySnapshot = hero(weapon, swing, facing, &"attack_active", Weapons.swing_phases(weapon, swing)[1] - 1)
				var plan: Dictionary = SwingArc.plan(actor, facing.x < 0, "hero2_attack%d_right_4" % swing)
				var label: String = "%s swing %d facing %s" % [weapon, swing, facing]
				check(not plan.is_empty(), "a slash at the end of the active frames: " + label)
				if plan.is_empty():
					continue
				check(is_equal_approx(float(plan["reach"]), reach), "the slash's reach is the swing's: " + label)
				check(is_equal_approx(absf(float(plan["to"]) - float(plan["from"])), 2.0 * half), "the slash spans the swing's arc: " + label)
				check(absf(angle_difference((float(plan["from"]) + float(plan["to"])) * 0.5, facing.angle())) < 0.001, "the arc is centred on the facing: " + label)
				check(float(plan["progress"]) >= 1.0, "the sweep has reached the arc's end: " + label)
				var outer: float = 0.0
				var outside: int = 0
				var pixels: Array[Array] = SwingArc.pixels(plan)
				for pixel: Array in pixels:
					var offset: Vector2 = Vector2(pixel[0]) - actor.position
					outer = maxf(outer, offset.length())
					var off_arc: bool = offset.length() > 2.0 and facing.dot(offset.normalized()) < Weapons.swing_arc_dot(weapon) - 0.06
					if offset.length() > reach + 0.75 or off_arc:
						outside += 1
				check(pixels.size() > 40, "the slash has a body: " + label)
				check(outside == 0, "every pixel of the slash is inside the hit area (%d outside): %s" % [outside, label])
				check(outer >= reach - 1.0, "the slash's edge reaches the reach (%.1f of %.1f): %s" % [outer, reach, label])
			# the sweep: before the active frames it is only starting, in the recovery it fades out and ends
			var phases: Array[int] = Weapons.swing_phases(weapon, swing)
			check(SwingArc.plan(hero(weapon, swing, Vector2.RIGHT, &"attack_windup", 0), false, "x_attack1_right_2").is_empty(), "no slash early in the windup")
			var lead_in: Dictionary = SwingArc.plan(hero(weapon, swing, Vector2.RIGHT, &"attack_windup", phases[0] - 1), false, "x_attack1_right_2")
			check(not lead_in.is_empty() and float(lead_in["progress"]) < 0.25, "the sweep starts just before the active frames")
			var fading: Dictionary = SwingArc.plan(hero(weapon, swing, Vector2.RIGHT, &"attack_recovery", 2), false, "x_attack1_right_5")
			check(not fading.is_empty() and float(fading["fade"]) < 1.0 and float(fading["fade"]) > 0.0, "the recovery fades the slash")
			check(SwingArc.plan(hero(weapon, swing, Vector2.RIGHT, &"attack_recovery", 30), false, "x_attack1_right_6").is_empty(), "the slash ends")
	for state: StringName in [&"idle", &"walk", &"dash", &"hurt", &"dead", &"skill_active", &"parry"]:
		check(SwingArc.plan(hero(Tuning.WEAPON_BLACK_KATANA, 1, Vector2.RIGHT, state), false, "hero2_attack1_right_3").is_empty(), "no slash during " + String(state))
	check(SwingArc.plan(hero(Tuning.WEAPON_BLACK_KATANA, 1, Vector2.RIGHT), false, "totoy_unarmed_attack1_right_3").is_empty(), "unarmed: no slash")
	check(SwingArc.plan(hero(Tuning.WEAPON_BLACK_KATANA, 1, Vector2.RIGHT), false, "hero2_hurt_right_1").is_empty(), "an interrupted pose cancels the slash")
	var down: Dictionary = SwingArc.plan(hero(Tuning.WEAPON_BLACK_KATANA, 1, Vector2.RIGHT), false, "hero2_attack1_right_4")
	var up: Dictionary = SwingArc.plan(hero(Tuning.WEAPON_BLACK_KATANA, 2, Vector2.RIGHT), false, "hero2_attack2_right_4")
	check(float(down["to"]) > float(down["from"]) and float(up["to"]) < float(up["from"]), "odd swings sweep down, even swings back up")
	# the real scenes: a real swing shows the slash in the fight and on the road
	var previous_save: String = OS.get_environment("TOTOY_SAVE_PATH")
	OS.set_environment("TOTOY_SAVE_PATH", "res://art/build/arena_swing_arcs_test_save.json")
	for weapon: StringName in [Tuning.WEAPON_BLACK_KATANA, Tuning.WEAPON_DUAL_DAGGER, Tuning.WEAPON_CHAIN_SCYTHE]:
		var arena: Arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
		root.add_child(arena)
		arena.set_physics_process(false)
		arena.core.boss.cooldown = 100000
		arena.core.player.weapon_id = weapon
		arena.core.player.position = Vector2(400, 340)
		arena.core.boss.position = Vector2(600, 140)
		var seen_arena: bool = false
		for tick: int in 40:
			var frame: InputFrame = InputFrame.new()
			frame.aim = Vector2.RIGHT
			frame.attack_pressed = tick == 0
			arena.advance(frame)
			var plan: Dictionary = arena.hero_swing_plan()
			if not plan.is_empty():
				seen_arena = true
				check(is_equal_approx(float(plan["reach"]), Weapons.swing_reach(weapon, arena.snapshot.player.combo_index)), "arena slash reach for " + String(weapon))
		check(seen_arena, "a real swing in the fight shows the slash for " + String(weapon))
		arena.free()
		Engine.set_meta(Explore.START_META, {"scene": &"woodland_layered"})
		var road: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
		root.add_child(road)
		road.set_physics_process(false)
		road.fade_phase = &""
		road.core.set_story_flags([&"debug_all_unlocked", &"received_first_sword"])
		road.core.set_loadout(weapon, [&"breaking_edge", &"gale_cut", &"moon_cleave"])
		road.core.place_at(Vector2(100, 300))
		road.snapshot = road.core.snapshot()
		var seen_road: bool = false
		for tick: int in 40:
			var frame: InputFrame = InputFrame.new()
			frame.aim = Vector2.LEFT
			frame.attack_pressed = tick == 0
			road.advance(frame)
			var plan: Dictionary = road.hero_swing_plan()
			if not plan.is_empty():
				seen_road = true
				check(absf(angle_difference((float(plan["from"]) + float(plan["to"])) * 0.5, PI)) < 0.01, "the road slash faces left with the hero")
		check(seen_road, "a real swing on the road shows the slash for " + String(weapon))
		road.free()
	OS.set_environment("TOTOY_SAVE_PATH", previous_save)
	if failures.is_empty():
		print("SWING ARCS OK")
		quit(0)
	else:
		for failure: String in failures:
			printerr("SWING ARCS FAIL: ", failure)
		quit(1)
