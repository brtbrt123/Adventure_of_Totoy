extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const OUT: String="res://art/reference/progression_v1/runtime/"
var scene: Explore
func _init() -> void:call_deferred("run")
func refresh() -> void:
	scene._choose_frames()
	scene._update_camera()
	scene._update_hud()
	scene.progression_view.sync(scene.snapshot,scene.colors,scene.frames,scene.sprites)
	scene.progression_view.visible=not scene.character_menu.is_open
	scene.queue_redraw()
func snap(name: String) -> void:
	refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(OUT+name+".png")!=OK:quit(1)
func flags(count: int, at: Vector2) -> void:
	var all: Array[StringName]=Explore.ExploreCore.QuestBook.done_flags(Explore.ExploreCore.QuestBook.default_book())
	var selected: Array[StringName]=all.slice(0,count)
	if count>=11:selected.append(&"aspect_owned_sprint")
	scene.core.set_story_flags(selected)
	scene.core.place_at(at)
	scene.snapshot=scene.core.snapshot()
	scene.toast_ticks=0
	scene.hud.reset_combat_feedback()
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META,{"scene":&"village_layered"})
	scene=load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase=&""
	scene.conversation.controls_open=false
	await process_frame
	flags(0,Vector2(104,150))
	await snap("01_mira_locked")
	flags(1,Vector2(258,160))
	await snap("02_tovan_objective")
	flags(2,Vector2(380,210))
	await snap("03_attack_unlocked")
	flags(3,Vector2(370,232))
	await snap("04_dash_ring")
	flags(0,Rect2(scene.core.def["exits"][0]["rect"]).get_center()+Vector2(-26,0))
	var move: Explore.InputFrame=Explore.InputFrame.new()
	move.move=Vector2.RIGHT
	for i: int in 60:scene.advance(move)
	await snap("05_gate_banner")
	flags(8,Vector2(52,278))
	scene.advance(Explore.InputFrame.new())
	var open: Explore.InputFrame=Explore.InputFrame.new()
	open.interact_pressed=true
	scene.advance(open)
	for n: int in 6:
		await snap("06_chest_%d" % (n+1))
		for i: int in 5:scene.advance(Explore.InputFrame.new())
	flags(12,Vector2(142,190))
	scene.profile.equipped_aspects=[&"sprint",&"gale_cut",&"moon_cleave"]
	scene.loadout_core.apply_profile(scene.profile)
	scene.core.set_loadout(&"black_katana",scene.profile.equipped_aspects)
	scene.core.set_exp(95)
	scene.snapshot=scene.core.snapshot()
	refresh()
	scene.open_menu()
	await snap("07_stats_unspent")
	scene.character_menu.click(Vector2(282,49))
	scene.character_menu.click(Vector2(282,73))
	await snap("08_stats_spent")
	scene.character_menu.open_picker(1)
	scene.character_menu.picker_selection=5
	scene.character_menu._scroll_to_selection()
	await snap("09_owned_aspects")
	scene.character_menu.close()
	scene.hud.combat_event(Explore.GameEvent.new(&"level_up",scene.snapshot.tick,{"points":2}))
	await snap("10_level_points")
	scene.enter_scene(&"forest_layered")
	scene._update_hud()
	scene.open_menu()
	await snap("11_respec_outside")
	scene.character_menu.close()
	scene.enter_scene(&"village_layered")
	scene.core.set_exp(99999)
	scene.core.set_stats({"vitality":10,"might":8,"agility":0})
	scene.snapshot=scene.core.snapshot()
	refresh()
	scene.open_menu()
	await snap("12_stats_caps")
	scene.free()
	for key: StringName in [Explore.START_META,Explore.PERSIST_META]:
		if Engine.has_meta(key):Engine.remove_meta(key)
	print("PROGRESSION CAPTURES OK")
	quit(0)
