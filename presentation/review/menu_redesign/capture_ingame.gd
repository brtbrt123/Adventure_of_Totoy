extends SceneTree
## The real TAB menu in the game, for the owner's eyes (2026-11-03, after the redesign in this folder was built): the road at
## the start (unarmed, nothing to spend) and late in Lanternfen (level 3, points, the herbs, Sprint), then the boss fight's
## Aspect list scrolled. Saves presentation/review/menu_redesign/ingame_*.png. A throwaway save, so the owner's save is never
## touched. Window only:
##   godot --path . --resolution 1152x648 --script res://presentation/review/menu_redesign/capture_ingame.gd
const Explore := preload("res://presentation/explore/explore_scene.gd")
const OUT: String = "res://presentation/review/menu_redesign/"

var scene: Explore


func _init() -> void:
	call_deferred("run")


func snap(name: String) -> void:
	scene._choose_frames()
	scene._update_camera()
	scene._update_hud()
	scene.queue_redraw()
	for i: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "ingame_" + name + ".png"))


func flags(count: int, at: Vector2) -> void:
	var all: Array[StringName] = Explore.ExploreCore.QuestBook.done_flags(Explore.ExploreCore.QuestBook.default_book())
	var selected: Array[StringName] = all.slice(0, count)
	scene.core.set_story_flags(selected)
	scene.core.place_at(at)
	scene.snapshot = scene.core.snapshot()


func run() -> void:
	OS.set_environment("TOTOY_SAVE_PATH", "user://menu_ingame_capture.json")
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	scene.conversation.controls_open = false
	await process_frame
	var menu: Variant = scene.character_menu
	# the start: unarmed, level 1, the first task
	flags(0, Vector2(104, 170))
	scene.open_menu()
	await snap("1_start_hero")
	menu.set_tab(menu.TAB_GEAR)
	await snap("2_start_gear")
	menu.close()
	# late in Lanternfen: level 3 with points, the Elder's herbs, Sprint owned; Edda's lesson (set Sprint in Z) is the current task,
	# so the menu opens on GEAR at socket Z
	flags(11, Vector2(142, 190))
	scene.core.set_flag(&"aspect_owned_sprint")
	scene.core.set_exp(95)
	scene.core.set_inventory({&"herb": 2})
	scene.core.stats[&"vitality"] = 2
	scene.core.stats[&"might"] = 1
	scene.profile.equipped_aspects = [&"sprint", &"gale_cut", &"moon_cleave"]
	scene.loadout_core.apply_profile(scene.profile)
	scene.snapshot = scene.core.snapshot()
	scene.open_menu()
	await snap("3_gear_lesson")
	menu.set_tab(menu.TAB_HERO)
	await snap("4_hero")
	menu.set_tab(menu.TAB_GEAR)
	menu.gear_selection = &"weapon"
	menu.open_weapon_list()
	menu.move_selection(Vector2i.DOWN)
	await snap("5_gear_weapon_list")
	menu.close_list()
	menu.set_tab(menu.TAB_QUESTS)
	await snap("6_quests")
	menu.close()
	scene.queue_free()
	await process_frame
	# the boss fight: socket X's list scrolled down
	var arena: Node = load("res://presentation/arena/arena.tscn").instantiate()
	root.add_child(arena)
	for i: int in 30:
		await process_frame
	arena.open_menu()
	var fight: Variant = arena.character_menu
	fight.set_tab(fight.TAB_GEAR)
	fight.gear_selection = &"aspect_slot_2"
	fight.open_aspect_list(2)
	for i: int in 4:
		fight.move_selection(Vector2i.DOWN)
	for i: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "ingame_7_boss_aspect_list.png"))
	print("MENU INGAME CAPTURE DONE")
	quit()
