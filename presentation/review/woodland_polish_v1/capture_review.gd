extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Canvas := preload("res://presentation/review/woodland_polish_v1/review_canvas.gd")
const OUT: String = "res://art/reference/woodland_polish_v1/"
func _init() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("ART REVIEW requires windowed rendering")
		quit(1)
		return
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META,{"scene":Explore.SceneDefs.WOODLAND_LAYERED})
	var world: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(world)
	world.set_physics_process(false)
	world.get_node("HUD").hide()
	world.fade_phase=&""
	var flags: Array[StringName]=[&"received_first_sword"]
	world.core.set_story_flags(flags)
	world.core.place_at(Vector2(112,276))
	world.snapshot=world.core.snapshot()
	world._choose_frames()
	world._update_camera()
	world.queue_redraw()
	var layer: CanvasLayer=CanvasLayer.new()
	root.add_child(layer)
	var canvas: Canvas=Canvas.new()
	layer.add_child(canvas)
	canvas.world=world
	for mode: String in ["hud_snapshot","hud_proposal","hud_locked","hud_down","hud_gain","slots","gauges","numbers","drop","effects_a","effects_b","states_mossling","states_boar"]:
		canvas.mode=mode
		canvas.board_size=Vector2(320,400) if mode.begins_with("states_") else Vector2(320,180)
		root.content_scale_size=Vector2i(canvas.board_size)
		root.size=Vector2i(canvas.board_size)*4
		canvas.queue_redraw()
		await save(mode)
	for amount: float in [1.0,0.55,0.15]:
		canvas.mode="mob_bars"
		canvas.fill=amount
		canvas.board_size=Vector2(320,180)
		root.content_scale_size=Vector2i(320,180)
		root.size=Vector2i(1280,720)
		canvas.queue_redraw()
		await save("mob_bars_%d" % int(amount*100))
	print("WOODLAND ART REVIEW CAPTURES OK")
	quit(0)
func save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error=root.get_texture().get_image().save_png(OUT+name+".png")
	if error!=OK:
		printerr("ART REVIEW CAPTURE FAIL ",name,error)
		quit(1)
