extends SceneTree
## Pictures for the owner (the TikTok reference, 2026-11-28; docs/PLAN_hit_feedback.md): a REAL fight in the forest, Totoy cutting
## through the Mossling group with real inputs (he walks to the nearest one and swings; he is kept alive), the same inputs every run.
## Since the owner's "Yes, wire them" the chunky numbers, the hit counter and the new mob bar are the game's own: this records it into
## user://hit_feedback/wired/. (The runs before wiring, `before` = the old game and `after` = the proposal plugged in, were recorded
## with the earlier version of this script.) tools/art/make_hit_feedback_gif.py makes the GIFs. No save is read or written.
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/hit_feedback/capture_hits.gd
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const OUT: String = "user://hit_feedback/"
const TICKS: int = 560

var scene: Explore


func _init() -> void:
	call_deferred("run")


func shot(path: String) -> void:
	scene.queue_redraw()
	scene.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + path)


## The living mob nearest Totoy, or {}.
func nearest() -> Dictionary:
	var best: Dictionary = {}
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["state"] == &"dead" or mob["type"] == &"colossus":
			continue
		if best.is_empty() or Vector2(mob["position"]).distance_to(scene.core.player.position) < Vector2(best["position"]).distance_to(scene.core.player.position):
			best = mob
	return best


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_hits: run it windowed")
		quit(1)
		return
	var folder: String = "wired"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + folder))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"forest_layered"})
	var node: Node = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate()
	node.set_script(load("res://presentation/review/colossus_step3/mockup_scene.gd"))
	scene = node as Explore
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.fade_phase = &""
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	# start beside the Mossling group (its first mob, from the snapshot)
	var first: Dictionary = {}
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["type"] == &"mossling" and first.is_empty():
			first = mob
	scene.core.player.position = Vector2(first["position"]) + Vector2(-60, 30)
	var n: int = 0
	for i: int in TICKS:
		var frame: InputFrame = InputFrame.new()
		var mob: Dictionary = nearest()
		if not mob.is_empty():
			var to: Vector2 = Vector2(mob["position"]) - scene.core.player.position
			frame.aim = to.normalized()
			if to.length() > 24.0:
				frame.move = to.normalized()
			elif i % 9 == 0:
				frame.attack_pressed = true
		scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(frame)
		scene.fade_phase = &""
		scene.toast_ticks = 0
		if i % 2 == 0:
			await shot("%s/seq_%04d.png" % [folder, n])
			n += 1
	print("CAPTURE HITS OK ", folder, " ", n)
	quit(0)
