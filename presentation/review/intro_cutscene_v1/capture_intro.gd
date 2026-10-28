extends SceneTree
const Intro := preload("res://presentation/cutscene/intro.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const OUT: String = "res://art/reference/intro_cutscene_v1/runtime/"
var intro: Intro
var destination: String = ""
func _init() -> void:call_deferred("run")
func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(OUT+name+".png")!=OK:quit(1)
func settle() -> void:
	while intro.fade_phase!=&"" and not intro.finished:intro.advance()
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var previous: String = OS.get_environment(Intro.SaveStore.PATH_ENV)
	OS.set_environment(Intro.SaveStore.PATH_ENV,"res://art/build/arena_intro_capture_save.json")
	Intro.SaveStore.delete()
	intro = load("res://presentation/cutscene/intro.tscn").instantiate()
	intro.change_scene = func(path: String) -> void:destination=path
	root.add_child(intro)
	intro.set_physics_process(false)
	settle()
	for i: int in intro.beats.size():
		if i==0:
			for tick: int in 55:intro.advance()
			await snap("00_typewriter")
		intro.advance(true)
		await snap("%02d_%s" % [i+1,intro.current_beat()["id"]])
		intro.advance(true)
		if not intro.finished:settle()
	for tick: int in Intro.EXIT_TICKS/2:intro.advance()
	await snap("08_outgoing_fade")
	while not intro.handed_over:intro.advance()
	if destination!=Intro.EXPLORE_SCENE:quit(1);return
	intro.free()
	var village: Explore = load(Intro.EXPLORE_SCENE).instantiate()
	root.add_child(village)
	village.set_physics_process(false)
	for tick: int in Explore.FADE_TICKS/2:village._physics_process(0.0)
	await snap("09_incoming_village_fade")
	for tick: int in Explore.FADE_TICKS+18:village._physics_process(0.0)
	await snap("10_village_arrival")
	village.free()
	Intro.SaveStore.delete()
	OS.set_environment(Intro.SaveStore.PATH_ENV,previous)
	for key: StringName in [Explore.START_META,Explore.PERSIST_META]:
		if Engine.has_meta(key):Engine.remove_meta(key)
	print("INTRO RUNTIME CAPTURES OK")
	quit(0)
