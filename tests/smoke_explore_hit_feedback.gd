extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
var failures: int = 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("HIT FEEDBACK FAIL: ",label)
		failures += 1
func run() -> void:
	Engine.set_meta(Explore.START_META,{"scene":Explore.SceneDefs.WOODLAND_LAYERED})
	var scene: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	await process_frame
	scene.core.set_flag(&"received_first_sword")
	scene.snapshot = scene.core.snapshot()
	check(not scene.hero_hit_flash(),"no flash without a damage event")
	var hp: int = scene.snapshot.hero.hp
	var event: Explore.GameEvent = Explore.GameEvent.new(Explore.GameEvent.DAMAGE_TAKEN,scene.snapshot.tick,{"amount":10,"entity_id":scene.snapshot.hero.id})
	scene._on_event(event)
	scene._choose_frames()
	check(scene.hero_hit_flash(),"confirmed hit flashes hero")
	check(scene.hero_frame.contains("hurt"),"confirmed hit shows hurt pose")
	check(scene.practice_effects.back()["type"] == Explore.GameEvent.DAMAGE_TAKEN,"confirmed hit adds existing impact sparks")
	check(scene.snapshot.hero.hp == hp,"feedback does not apply damage")
	if "--capture" in OS.get_cmdline_user_args():
		scene._update_camera()
		scene._update_hud()
		scene.practice_view.sync(scene.snapshot,scene.practice_effects,scene.frames,scene.sprites)
		scene.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/reference/woodland_polish_v1/hero_hit.png")
	scene.snapshot.tick += 12
	check(not scene.hero_hit_flash(),"flash ends after twelve ticks")
	scene.enter_scene(Explore.SceneDefs.WOODLAND_LAYERED)
	check(not scene.hero_hit_flash(),"scene entry clears hit feedback")
	scene.queue_free()
	await process_frame
	if failures == 0: print("EXPLORE HIT FEEDBACK OK")
	quit(1 if failures else 0)
