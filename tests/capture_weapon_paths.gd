extends SceneTree
## Windowed integration check: the shared render helper must submit a path in both real scene types, for every weapon
## and facing. Uses an isolated fixture save; captures the same active blade pose in all twelve cases.
const Arena := preload("res://presentation/arena/arena.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Fx := preload("res://presentation/common/hero_fx.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Weapons := preload("res://core/weapons.gd")
const OUT: String = "res://art/reference/weapon_paths_review_v1/ingame/"
const MOTION: String = "res://art/build/arena_weapon_paths_motion/"
var failures: Array[String] = []


func _init() -> void:
	OS.set_environment("TOTOY_SAVE_PATH", "res://art/build/arena_weapon_paths_capture_save.json")
	call_deferred("run")


func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Weapon path captures require a windowed renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1152, 648)
	var motion: bool = OS.get_cmdline_user_args().has("--motion")
	var third: bool = OS.get_cmdline_user_args().has("--third")
	if motion:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOTION))
		var ignore: FileAccess = FileAccess.open(MOTION + ".gdignore", FileAccess.WRITE)
		ignore.store_string("# Temporary runtime capture frames.\n")
		ignore.close()
	for road: bool in [false, true]:
		for weapon: StringName in Weapons.IDS:
			for left: bool in [false, true]:
				var view: Fx
				if road:
					Engine.set_meta(Explore.START_META, {"scene": &"woodland_layered"})
					var exploration: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
					root.add_child(exploration)
					exploration.set_physics_process(false)
					var flags: Array[StringName] = [&"debug_all_unlocked", &"received_first_sword"]
					# Isolate the blade alignment from mob hits interrupting the third swing in a capture fixture.
					for encounter: Dictionary in exploration.core.snapshot().encounters:
						flags.append(StringName("cleared_" + String(encounter["id"])))
					exploration.core.set_story_flags(flags)
					exploration.core.set_loadout(weapon, [&"breaking_edge", &"gale_cut", &"moon_cleave"])
					exploration.core.place_at(Vector2(100, 300))
					exploration.snapshot = exploration.core.snapshot()
					exploration.fade_phase = &""
					exploration.conversation.controls_open = false
					view = exploration
				else:
					var arena: Arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
					root.add_child(arena)
					arena.set_physics_process(false)
					arena.core.boss.cooldown = 100000
					arena.core.player.weapon_id = weapon
					arena.core.player.position = Vector2(400, 340)
					arena.core.boss.position = Vector2(600, 140)
					view = arena
				var label: String = "%s_%s_%s" % ["road" if road else "arena", weapon, "left" if left else "right"]
				if third:
					label += "_third"
				var saved: bool = false
				for tick: int in (120 if third else (90 if motion and not left else 55)):
					var input: InputFrame = InputFrame.new()
					input.attack_pressed = tick % 14 == 0 if third or (motion and not left) else tick == 0
					input.attack_held = third or (motion and not left)
					input.aim = Vector2.LEFT if left else Vector2.RIGHT
					view.call("advance", input)
					if motion and not left:
						view.queue_redraw()
						await process_frame
						await process_frame
						await RenderingServer.frame_post_draw
						var origin: Vector2 = view.get("view_origin")
						var feet: Vector2 = view.fx_hero().position.round() - origin + view.shake_offset()
						var crop: Rect2i = Rect2i(Vector2i((feet - Vector2(48, 60)) * 3.0), Vector2i(384, 240))
						root.get_texture().get_image().get_region(crop).save_png(MOTION + "arena_%s_%03d.png" % [label, tick])
					if saved or not view.hero_weapon_path_key().ends_with("_2"):
						continue
					if third and "_attack3_" not in view.hero_weapon_path_key():
						continue
					var before: int = view.weapon_path_draws
					var glow_before: int = view.weapon_path_glow.glow_draws
					view.queue_redraw()
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					if view.weapon_path_draws <= before:
						failures.append(label + " never submitted the shared trail to the renderer")
					if view.weapon_path_glow.glow_draws <= glow_before or view.weapon_path_glow.sparks.is_empty():
						failures.append(label + " missing shared glow or particles")
					root.get_texture().get_image().save_png(OUT + label + ".png")
					print("PATH CAPTURE ", label, " ", view.hero_weapon_path_key())
					saved = true
					if not motion or left:
						break
				if not saved:
					failures.append(label + " never reached an active path pose")
				view.free()
	if failures.is_empty():
		print("WEAPON PATH RENDER OK: 12/12 real scene/weapon/facing cases")
	else:
		for failure: String in failures:
			printerr("WEAPON PATH RENDER FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
