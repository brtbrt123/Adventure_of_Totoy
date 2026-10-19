extends SceneTree
## Windowed capture of the title screen pages: godot --path . --script res://tests/capture_title.gd
const Title := preload("res://presentation/menu/title.gd")
const SaveStore := preload("res://core/save_store.gd")
const SaveProfile := preload("res://core/save_profile.gd")

func _init() -> void:
	call_deferred("_run")

func _save(name_key: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png("res://art/build/arena_title_" + name_key + ".png")

func _run() -> void:
	var title: Title = (load("res://presentation/menu/title.tscn") as PackedScene).instantiate() as Title
	root.add_child(title)
	await process_frame
	var profile: SaveProfile = SaveProfile.new()
	profile.victories = 3
	profile.defeats = 7
	profile.best_victory_ticks = 4236
	title.profile = profile  # a made-up record for the picture only; nothing is saved
	title.index = 1
	title.queue_redraw()
	await _save("menu")
	title.screen = Title.SCREEN_CONTROLS
	title.queue_redraw()
	await _save("controls")
	title.screen = Title.SCREEN_CREDITS
	title.queue_redraw()
	await _save("credits")
	quit(0)
