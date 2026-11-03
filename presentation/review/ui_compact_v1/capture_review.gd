extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Canvas := preload("res://presentation/review/ui_compact_v1/review_canvas.gd")
const OUT: String = "res://art/reference/ui_compact_v1/"
var scene: Explore
var view: Canvas
var errors: Array[String] = []

func _init() -> void: call_deferred("run")

func fixture(count: int, at: Vector2, exp: int = 0) -> void:
	var all: Array[StringName] = Explore.ExploreCore.QuestBook.done_flags(Explore.ExploreCore.QuestBook.default_book())
	var selected: Array[StringName] = all.slice(0, count)
	if count >= 11: selected.append(&"aspect_owned_sprint")
	scene.core.set_story_flags(selected)
	scene.core.set_exp(exp)
	scene.core.set_loadout(&"black_katana", [&"sprint", &"gale_cut", &"moon_cleave"])
	scene.core.set_inventory({&"herb": 2} if count >= 10 else {})
	scene.core.place_at(at)
	scene.snapshot = scene.core.snapshot()
	scene.fade_phase = &""
	scene.conversation.controls_open = false
	scene.toast_ticks = 0

func refresh() -> void:
	scene._choose_frames()
	scene._update_camera()
	scene._update_hud()
	scene.get_node("HUD").hide()
	scene.progression_view.sync(scene.snapshot, scene.colors, scene.frames, scene.sprites)
	scene.queue_redraw()
	view.state = scene.snapshot
	view.hero_key = scene.hero_frame
	view.queue_redraw()

func snap(name: String, mode: String) -> void:
	view.mode = mode
	refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	if im.get_size() != Vector2i(1280, 720): errors.append("Unexpected screenshot size " + str(im.get_size()))
	if im.save_png(OUT + name + ".png") != OK: errors.append("Could not save " + name)
	print("COMPACT PREVIEW " + name)

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size = Vector2i(320, 180)
	root.size = Vector2i(1280, 720)
	if Engine.has_meta(Explore.PERSIST_META): Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	view = Canvas.new()
	view.colors = scene.colors
	view.portrait_atlas = scene.sprites
	view.ui_frames = scene.frames
	layer.add_child(view)
	fixture(3, Vector2(370, 232), 20)
	await snap("01_training", "training")
	scene.enter_scene(&"woodland_layered")
	fixture(12, Vector2(145, 236), 95)
	# The real core advances the first Mossling encounter; no mob art or HP is fabricated.
	for i: int in 35: scene.advance(Explore.InputFrame.new())
	await snap("02_woodland", "combat")
	scene.enter_scene(&"village_layered")
	fixture(0, Vector2(115, 154))
	await snap("03_dialogue", "dialogue")
	await snap("04_welcome", "welcome")
	fixture(10, Vector2(166, 208), 75)
	await snap("05_item_receipt", "item")
	fixture(12, Vector2(166, 208), 95)
	await snap("06_level_toast", "level")
	await snap("07_stats", "stats")
	await snap("08_aspects", "aspects")
	await snap("09_bag", "bag")
	await contact_sheet()
	for issue: String in view.checks:
		if not errors.has(issue): errors.append(issue)
	var notes: Dictionary = {"size": [1280, 720], "base": [320, 180], "screens": 9, "text_measurements": view.text_checks, "errors": errors, "installed": false}
	var file: FileAccess = FileAccess.open(OUT + "checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(notes, "  "))
	scene.free()
	layer.free()
	for issue: String in errors: printerr(issue)
	print("UI COMPACT REVIEW OK" if errors.is_empty() else "UI COMPACT REVIEW NEEDS FIXES")
	quit(0 if errors.is_empty() else 1)

func contact_sheet() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1170)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var names: Array[String] = ["01_training", "02_woodland", "03_dialogue", "04_welcome", "05_item_receipt", "06_level_toast", "07_stats", "08_aspects", "09_bag"]
	var labels: Array[String] = ["1  One training / task card", "2  Slim combat HUD", "3  Dialogue", "4  Message-only welcome", "5  Item receipt", "6  Level toast", "7  Stats", "8  Owned / locked Aspects", "9  Bag"]
	for i: int in names.size():
		var at: Vector2 = Vector2((i % 3) * 640, int(i / 3) * 390)
		var label: Label = Label.new()
		label.position = at + Vector2(8, 3)
		label.text = labels[i] + "  |  REVIEW"
		label.add_theme_font_override("font", Canvas.ui_font())
		label.add_theme_font_size_override("font_size", 22)
		viewport.add_child(label)
		var image: Image = Image.load_from_file(OUT + names[i] + ".png")
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.centered = false
		sprite.position = at + Vector2(0, 30)
		viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	if viewport.get_texture().get_image().save_png(OUT + "contact_sheet.png") != OK: errors.append("Could not save contact sheet")
	viewport.queue_free()
