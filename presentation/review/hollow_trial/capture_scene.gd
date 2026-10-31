extends SceneTree
## Windowed render of the editable visual scene; no simulated trial gameplay.
const MapView := preload("res://presentation/maps/hollow_trial_view.gd")
const OUT: String = "res://presentation/review/hollow_trial/"
var map: MapView
var viewport: SubViewport

func _init() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.save_png(OUT+name+"_native.png")
	image.resize(1024,704,Image.INTERPOLATE_NEAREST)
	image.save_png(OUT+name+"_2x.png")
	print("CAPTURE ",name)

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(512,352)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	map = load("res://presentation/maps/hollow_trial_layered.tscn").instantiate() as MapView
	viewport.add_child(map)
	map.animate_preview = false
	map.sync_snapshot({"state":&"idle","sealed":false},[],120)
	await shot("idle_scene")
	map.sync_snapshot({"state":&"wave","sealed":true},[],120)
	await shot("sealed_scene_VISUAL_STATE")
	map.sync_snapshot({"state":&"won","sealed":false},[&"cleared_hollow_trial"],120)
	await shot("lit_altar_VISUAL_STATE")
	map.sync_snapshot({"state":&"won","sealed":false},[&"cleared_hollow_trial",&"trial_chest_opened"],120)
	await shot("open_chest_VISUAL_STATE")
	viewport.queue_free()
	await process_frame
	print("HOLLOW TRIAL VISUAL CAPTURE OK / snapshot fixtures, not gameplay")
	quit()
