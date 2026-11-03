extends SceneTree
func _init() -> void:
	print("CURSOR SETTINGS: ", ProjectSettings.get_setting("display/mouse_cursor/custom_image"), " hotspot ", ProjectSettings.get_setting("display/mouse_cursor/custom_image_hotspot"))
	var texture: Texture2D = load(ProjectSettings.get_setting("display/mouse_cursor/custom_image")) as Texture2D
	assert(texture != null and texture.get_size() == Vector2(32, 32))
	print("HAND CURSOR OK")
	quit()
