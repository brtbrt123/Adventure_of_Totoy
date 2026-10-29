extends SceneTree
## Regression for the road/arena split: one selector and render entry point for every regular weapon swing.
const Paths := preload("res://presentation/common/weapon_paths.gd")
const Fx := preload("res://presentation/common/hero_fx.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Arena := preload("res://presentation/arena/arena.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const InputFrame := preload("res://core/input_frame.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)


func run() -> void:
	var previous: String = OS.get_environment("TOTOY_SAVE_PATH")
	OS.set_environment("TOTOY_SAVE_PATH", "res://art/build/arena_weapon_paths_test_save.json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json")) as Dictionary
	var frames: Dictionary = data["frames"]
	var actor: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	for prefix: String in Paths.SETS:
		var max_swings: int = 4 if Paths.SETS[prefix] == "daggers" else 3
		for swing: int in range(1, max_swings + 1):
			for pose: int in range(3, 7):
				actor.state = &"attack_active" if pose < 5 else &"attack_recovery"
				actor.state_ticks = 0 if pose < 6 else 3
				var key: String = Paths.key(actor, "%s_attack%d_right_%d" % [prefix, swing, pose])
				check(not key.is_empty() and frames.has(key), "missing path %s swing %d pose %d" % [prefix, swing, pose])
				if frames.has(key):
					var frame: Dictionary = frames[key]
					check(Vector2(frame["ax"], frame["ay"]) == Vector2(48, 78), "path feet anchor")
					var a: Rect2 = ArenaAnimation.destination(Vector2(100, 100), frame, false)
					var b: Rect2 = ArenaAnimation.destination(Vector2(100, 100), frame, true)
					check(a.size == Vector2(128, 96) and b.size == Vector2(-128, 96) and a.position.y == b.position.y, "native/mirrored path geometry")
	for state: StringName in [&"idle", &"walk", &"attack_windup", &"dash", &"hurt", &"dead", &"skill_active"]:
		actor.state = state
		check(Paths.key(actor, "hero2_attack1_right_3").is_empty(), "no path during " + String(state))
	actor.state = &"attack_recovery"
	actor.state_ticks = Paths.RECOVERY_TICKS
	check(Paths.key(actor, "hero2_attack1_right_6").is_empty(), "recovery expires")
	actor.state = &"attack_active"
	actor.state_ticks = 0
	check(Paths.key(actor, "totoy_unarmed_attack1_right_3").is_empty(), "unarmed has no weapon path")
	check(Paths.key(actor, "hero2_hurt_right_1").is_empty(), "hurt pose override cancels the path")
	# The finisher goes over the head and down in front. A shortest-angle interpolation previously sent it under
	# the hands instead. Check the authored path reaches the upper-forward arc and the actual low blade tip.
	var overhead: Image = (load("res://art/build/sprites/fx_weapon_path_katana_attack3_1.png") as Texture2D).get_image()
	var forward_arc: int = 0
	for y: int in range(40, 50):
		for x: int in range(56, 76):
			if overhead.get_pixel(x, y).a > 0.5:
				forward_arc += 1
	check(forward_arc > 10 and overhead.get_pixel(67, 78).a > 0.5, "third katana cut follows the overhead arc into its low blade tip")
	for weapon: StringName in Weapons.IDS:
		var arena: Arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
		root.add_child(arena)
		arena.set_physics_process(false)
		arena.core.boss.cooldown = 100000
		arena.core.player.weapon_id = weapon
		arena.core.player.position = Vector2(400, 340)
		arena.core.boss.position = Vector2(600, 140)
		var seen_arena: bool = false
		var arena_sparks: bool = false
		for tick: int in 55:
			var frame: InputFrame = InputFrame.new()
			frame.aim = Vector2.RIGHT
			frame.attack_pressed = tick == 0
			arena.advance(frame)
			arena.weapon_path_glow.sync_from_host()
			arena_sparks = arena_sparks or not arena.weapon_path_glow.sparks.is_empty()
			var selected: String = arena.hero_weapon_path_key()
			check(arena.weapon_path_glow.glow_key == selected, "arena glow follows the same shared path")
			var count: int = arena.weapon_path_glow.sparks.size()
			arena.weapon_path_glow.sync_from_host()
			check(arena.weapon_path_glow.sparks.size() == count and count <= arena.weapon_path_glow.MAX_SPARKS, "arena particles are capped and frame-rate independent")
			if not selected.is_empty():
				check(selected.begins_with("fx_weapon_path_"), "arena uses shared paths")
				seen_arena = true
		check(seen_arena, "real arena attack shows path for " + String(weapon))
		check(arena_sparks and arena.weapon_path_glow.sparks.is_empty(), "arena emits then expires trail particles for " + String(weapon))
		check(arena is Fx, "arena inherits the shared effect base")
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
		var road_sparks: bool = false
		for tick: int in 55:
			var frame: InputFrame = InputFrame.new()
			frame.aim = Vector2.LEFT
			frame.attack_pressed = tick == 0
			road.advance(frame)
			road.weapon_path_glow.sync_from_host()
			road_sparks = road_sparks or not road.weapon_path_glow.sparks.is_empty()
			var selected: String = road.hero_weapon_path_key()
			check(road.weapon_path_glow.glow_key == selected, "road glow follows the same shared path")
			var count: int = road.weapon_path_glow.sparks.size()
			road.weapon_path_glow.sync_from_host()
			check(road.weapon_path_glow.sparks.size() == count and count <= road.weapon_path_glow.MAX_SPARKS, "road particles are capped and frame-rate independent")
			if not selected.is_empty():
				check(road.frames.has(selected) and road.facing_left, "road path asset and left-facing pose")
				seen_road = true
		check(seen_road, "real road attack shows path for " + String(weapon))
		check(road_sparks and road.weapon_path_glow.sparks.is_empty(), "road emits then expires trail particles for " + String(weapon))
		check(road is Fx, "road inherits the same effect base")
		road.free()
	OS.set_environment("TOTOY_SAVE_PATH", previous)
	if failures.is_empty():
		print("SHARED WEAPON PATHS OK: all combos, mirrored poses, real arena and road attacks for all weapons")
	else:
		for failure: String in failures:
			printerr("WEAPON PATH FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
