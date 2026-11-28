extends SceneTree
## Pictures for the owner, step 4c (docs/PLAN_colossus_step4.md): the REAL game with the rigged body wired in, in Rootcrown at night:
## asleep, the appearing (also as a frame sequence for a GIF), a Gold Slam, a Sweep, a Boulder Toss (held, then thrown), the Song
## Flare's gold blow, a posture break, and the death. Attacks are forced with next_attack_override; the hero is kept alive.
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_4c/capture_4c.gd
## Writes user://colossus_4c/<name>.png and user://colossus_4c/appear/seq_NNNN.png; tools/art/make_colossus_4c_sheet.py makes the
## sheet and the GIF. No save is read or written.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Telegraph := preload("res://core/telegraph.gd")
const Tuning := preload("res://core/tuning.gd")
const GameEvent := preload("res://core/game_event.gd")
const OUT: String = "user://colossus_4c/"
const HOME: Vector2 = Vector2(512, 378)
const APPEAR_EVERY: int = 4  # ticks between the appearing's sequence frames

var scene: Explore


func _init() -> void:
	call_deferred("run")


func boss() -> Object:
	return scene.core.mobs.encounters[0].mobs[0]


func steps(count: int) -> void:
	for i: int in count:
		scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		scene.toast_ticks = 0


func shot(name: String) -> void:
	scene.queue_redraw()
	scene.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name, " ", error_string(error))


## Starts attack `id` now with the hero at `offset` from the boss; returns its warnings (the core's, with their ticks).
func force(id: StringName, offset: Vector2) -> Array[Telegraph]:
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().cooldown = 1
	boss().next_attack_override = id
	boss().position = HOME
	scene.core.player.position = HOME + offset
	steps(1)
	boss().cooldown = 100000
	var out: Array[Telegraph] = []
	out.assign(boss().all_telegraphs().filter(func(w: Telegraph) -> bool: return w.attack == id))
	return out


func to_tick(tick: int) -> void:
	steps(maxi(0, tick - scene.core.tick))


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_4c: run it windowed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "appear"))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"rootcrown_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.fade_phase = &""
	# asleep: an unarmed hero does not wake it, so he can stand close
	scene.core.player.position = HOME + Vector2(-70, 30)
	steps(30)
	await shot("4c_01_asleep")
	# the appearing: armed and near, it wakes on the next tick; every APPEAR_EVERY ticks a frame of the sequence
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	scene.core.player.position = HOME + Vector2(-70, 60)
	var stills: Dictionary = {22: "4c_02_appear_fist", 48: "4c_03_appear_other_fist", 74: "4c_04_appear_plant", 108: "4c_05_appear_rising", 140: "4c_06_appear_roar"}
	var frame: int = 0
	for i: int in 400:
		steps(1)
		if boss().state == &"alert" or (frame > 0 and boss().state == &"chase" and boss().state_ticks < 30):
			if boss().state == &"alert" and stills.has(boss().state_ticks):
				await shot(stills[boss().state_ticks])
			if i % APPEAR_EVERY == 0:
				await shot("appear/seq_%04d" % frame)
				frame += 1
		elif frame > 0:
			break
	# a Gold Slam: fists overhead, then the blow
	var slam: Array[Telegraph] = force(&"gold_slam", Vector2(-70, 50))
	to_tick(slam[0].hit_tick - 8)
	await shot("4c_07_slam_windup")
	to_tick(slam[0].hit_tick + 2)
	await shot("4c_08_slam_blow")
	steps(40)
	# a Sweep: the arm swings across
	var sweep: Array[Telegraph] = force(&"red_sweep", Vector2(-80, 50))
	to_tick(sweep[0].hit_tick + 1)
	await shot("4c_09_sweep")
	steps(40)
	# a Boulder Toss: held overhead, then in flight
	var stone: Array[Telegraph] = force(&"boulder_toss", Vector2(-120, 40))
	var span: int = stone[0].hit_tick - stone[0].start_tick
	to_tick(stone[0].start_tick + roundi(span * 0.35))
	await shot("4c_10_boulder_held")
	to_tick(stone[0].start_tick + roundi(span * 0.7))
	await shot("4c_11_boulder_thrown")
	steps(80)
	# the Song Flare's gold blow (phase 3): the song gathers, then blows out
	boss().phase = 3
	var flare: Array[Telegraph] = force(&"song_flare", Vector2(-70, 50))
	to_tick(flare[3].hit_tick - 6)
	await shot("4c_12_flare_gathers")
	to_tick(flare[3].hit_tick + 2)
	await shot("4c_13_flare_gold_blow")
	steps(60)
	# a posture break: slumped, the song flickering
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().position = HOME
	var events: Array[GameEvent] = []
	boss().add_posture(100.0, scene.core.tick, events)
	steps(12)
	await shot("4c_14_posture_broken")
	# the death: the last blow (a real swing), then it breaks apart
	boss().broken_left = 0
	steps(4)
	boss().hp = 1
	boss().cooldown = 100000
	for i: int in 90:
		if not boss().is_alive():
			break
		var swing: InputFrame = InputFrame.new()
		swing.attack_pressed = true
		scene.core.player.position = boss().position + Vector2(-60, 10)
		swing.aim = Vector2.RIGHT
		scene.advance(swing)
		scene.core.player.hp = scene.core.hero_max_hp()
	steps(12)
	await shot("4c_15_death_breaks")
	steps(24)
	await shot("4c_16_death_heap")
	print("CAPTURE 4C OK ", frame, " appear frames")
	quit(0)
