extends SceneTree
## Windowed only (regular Godot exe, not headless): captures the SpriteCook-kit UI at 384x216 (3x window) into
## art/reference/ui_kit_spritecook_v1/ingame/*.png for a visual check. Review only; not a harness test.
## Godot_v4.7.2-stable_win64.exe --path . --script res://tests/capture_ui_kit.gd
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const OUT: String = "res://art/reference/ui_kit_spritecook_v1/ingame/"
var scene: Explore


func _init() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func save(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("CAPTURE ", label)


func fresh(start: Dictionary) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, start)
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	await frames(10)


func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Bindings.register()
	root.content_scale_size = Vector2i(384, 216)
	root.size = Vector2i(1152, 648)
	# woodland: fight HUD, items, sockets, level pillar
	await fresh({"scene": &"woodland_layered"})
	scene.core.set_flag(&"debug_all_unlocked")
	scene.core.set_flag(&"received_first_sword")
	scene.core.set_exp(95)
	scene.core.set_inventory({&"herb": 2})
	scene.core.place_at(Vector2(406, 262))
	await frames(40)
	await save("hud_woodland")
	# the TAB menu over it
	scene.open_menu()
	await frames(4)
	await save("menu_stats")
	scene.character_menu.set_tab(1)
	await frames(4)
	await save("menu_aspects")
	scene.character_menu.set_tab(2)
	scene.character_menu.inventory_selection = 0
	await frames(4)
	await save("menu_items")
	scene.character_menu.inventory_selection = 6
	await frames(4)
	await save("menu_items_aspect")
	scene.character_menu.set_tab(3)
	await frames(4)
	await save("menu_quests")
	scene.character_menu.close()
	# village: objective, chips, dialogue, reward card
	await fresh({"scene": &"village_layered", "entry": &"arrival"})
	scene.core.set_flag(&"seen_controls")
	await frames(30)
	await save("village_plain")
	scene.show_reward({"kind": "item", "name": "Herb", "quantity": 1, "icon": "hud_copper_herb"})
	await frames(30)
	await save("village_reward")
	scene.core.place_at(Vector2(176, 210))
	await frames(10)
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.conversation.controls_open = false
	scene.conversation.sync({"dialogue_id": "x", "index": 0, "count": 3, "speaker": "Tovan", "portrait": "tovan", "text": "Hold out your hands, Totoy. This is a Black Katana, and it is yours. It was always yours. Remember the colours: gold, parry. Red, dash."})
	scene.conversation.finish_typing()
	await frames(4)
	await save("dialogue")
	scene.conversation.sync({})
	scene.conversation.controls_open = true
	await frames(4)
	await save("controls_card")
	quit(0)
