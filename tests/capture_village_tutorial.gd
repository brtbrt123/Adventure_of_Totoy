extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const OUT: String = "res://art/reference/tutorial_review_v1/"
var output: String = OUT
var scene: Explore


func _init() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	scene._update_hud()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output + name + ".png") != OK:
		printerr("FAIL saving " + name)
		quit(1)


func run() -> void:
	if "--compact-v3" in OS.get_cmdline_user_args():
		output = "res://art/reference/tutorial_cards_compact_v3/"
	elif "--cards-v2" in OS.get_cmdline_user_args():
		output = "res://art/reference/tutorial_cards_v2/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	root.size = Vector2i(1280, 720)
	for id: StringName in [&"village_layered"]:
		Engine.set_meta(Explore.START_META, {"scene": id})
		scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
		scene.set_physics_process(false)
		root.add_child(scene)
		scene.set_physics_process(false)
		scene.fade_phase = &""
		await capture(String(id) + "_controls")
		scene.dismiss_controls()
		for npc: Dictionary in scene.snapshot.npcs:
			if npc["id"] == &"mira":
				scene.core.place_at(npc["position"] + Vector2(16, 2))
		scene.advance(Intent.new())
		var talk: Intent = Intent.new()
		talk.interact_pressed = true
		scene.advance(talk)
		scene.conversation.finish_typing()
		await capture(String(id) + "_dialogue")
		var skip: Intent = Intent.new()
		skip.skip_pressed = true
		scene.advance(skip)
		scene.core.set_flag(&"met_tovan")
		# Review fixture starts at the warning lessons; the smoke earns every flag.
		scene.core.set_flag(&"lesson_dash")
		scene.core.set_flag(&"lesson_attack")
		for object: Dictionary in scene.snapshot.objects:
			if object["kind"] == &"dummy":
				scene.core.place_at(object["stand"])
		scene.advance(Intent.new())
		for kind: StringName in [&"gold", &"red"]:
			if kind == &"red":
				scene.core.set_flag(&"lesson_parry")
				# Let the current gold attempt finish; core chooses its next warning.
				for i: int in 80:
					scene.advance(Intent.new())
			for i: int in 400:
				scene.advance(Intent.new())
				if not scene.snapshot.telegraphs.is_empty():
					var tell: RefCounted = scene.snapshot.telegraphs[0]
					if tell.kind == kind and scene.snapshot.tick == tell.hit_tick - 10:
						break
			# Show the instruction after transient event feedback, for layout review.
			scene.toast_message = ""
			scene.toast_ticks = 0
			await capture(String(id) + "_" + String(kind))
		var attack: Intent = Intent.new()
		attack.attack_pressed = true
		attack.aim = Vector2.UP
		scene.advance(attack)
		for i: int in 40:
			scene.advance(Intent.new())
			if int(scene.snapshot.training["since_hit"]) == 0:
				break
		await capture(String(id) + "_post_hit")
		root.remove_child(scene)
		scene.queue_free()
		await process_frame
	print("TUTORIAL CAPTURES OK")
	quit(0)
