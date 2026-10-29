extends SceneTree
## Real runtime captures with an isolated fixture profile, never the player's save.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
const OUT: String = "res://presentation/review/ui_kit_live/"
var scene: Explore

func _init() -> void:
	OS.set_environment("TOTOY_SAVE_PATH", "res://art/build/arena_ui_capture_fixture.json")
	call_deferred("run")

func save_screen(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("UI CAPTURE ", label)

func refresh() -> void:
	scene.snapshot = scene.core.snapshot()
	scene._choose_frames()
	scene._update_camera()
	scene._update_hud()
	scene.queue_redraw()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1152, 648)
	Engine.set_meta(Explore.START_META, {"scene": &"woodland_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.core.set_flag(&"debug_all_unlocked")
	scene.core.set_flag(&"received_first_sword")
	scene.core.set_exp(95)
	scene.core.set_inventory({&"herb": 2})
	scene.core.place_at(Vector2(406, 262))
	for tick: int in 30:
		scene.advance(InputFrame.new())
	scene.fade_phase = &""
	scene.conversation.controls_open = false
	refresh()
	await save_screen("1_explore_hud")
	scene.open_menu()
	await save_screen("2_status")
	scene.character_menu.set_tab(scene.character_menu.TAB_INVENTORY)
	await save_screen("3_items")
	scene.character_menu.set_tab(scene.character_menu.TAB_ASPECTS)
	await save_screen("8_aspects")
	scene.character_menu.set_tab(scene.character_menu.TAB_QUESTS)
	await save_screen("9_quests")
	scene.character_menu.close()
	refresh()
	scene.conversation.sync({"dialogue_id": "capture", "index": 0, "portrait": "mira", "speaker": "Mira", "text": "Welcome home, Totoy. The lanterns still remember you. Follow the road to the Elder; there is something you need to see."})
	scene.conversation.finish_typing()
	await save_screen("4_dialogue")
	scene.conversation.sync({})
	scene.reward_popup.enqueue({"name": "Black Katana", "quantity": 1, "icon": "ui_weapon_totoy_blade_1"})
	scene.reward_popup.blocked = false
	scene.reward_popup.advance(0.01)
	await save_screen("5_reward")
	# The real post-village loadout: Sprint in Z, X/C locked, herb in 1, 2 locked.
	var quest_book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests/chapter1.json")) as Dictionary
	var story_flags: Array[StringName] = []
	for step: Dictionary in quest_book["steps"]:
		story_flags.append(StringName(step["done_flag"]))
	story_flags.append(&"aspect_owned_sprint")
	story_flags.append(&"unlocked_item_slot_1")
	scene.core.set_story_flags(story_flags)
	scene.core.set_loadout(&"black_katana", [&"sprint", &"gale_cut", &"moon_cleave"])
	scene.hud.task_tick = -1000
	refresh()
	await save_screen("10_story_sprint_hud")
	scene.core.set_exp(99999)
	refresh()
	await save_screen("11_level_cap")
	root.remove_child(scene)
	scene.free()
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.core.boss.cooldown = 100000
	arena.snapshot = arena.core.snapshot()
	arena._update_camera(true)
	arena.prepare_visuals()
	arena._update_hud()
	arena.queue_redraw()
	await save_screen("6_arena_hud")
	arena.character_menu.open()
	await save_screen("7_arena_status")
	arena.character_menu.close()
	arena.core.boss.hp = 0
	arena.advance(InputFrame.new())
	# Result fixture: death animation completion is covered by the character-menu smoke.
	arena.snapshot.result = &"victory"
	arena.hud.snapshot = arena.snapshot
	arena.hud.queue_redraw()
	await save_screen("12_victory")
	root.remove_child(arena)
	arena.free()
	var title: Node = (load("res://presentation/menu/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await save_screen("13_title")
	root.remove_child(title)
	title.free()
	print("UI KIT CAPTURE OK")
	quit(0)
