extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"woodland_layered"})
	var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	var failed: bool = scene.snapshot.size != Vector2(640,400) or scene.prop_placements.size() != Explore.SceneDefs.layered_data(&"woodland_layered")["props"].size()
	for item: Dictionary in Explore.PropsLayer.drawables(scene.prop_placements, scene.frames):
		if String(item["type"]).begins_with("woodland_") and item["cast_frame"].is_empty():
			printerr("MISSING CAST ", item["type"])
			failed = true
	scene.queue_free()
	await process_frame
	print("WOODLAND BLOCKOUT PRODUCTION OK" if not failed else "WOODLAND BLOCKOUT FAIL")
	quit(1 if failed else 0)
