extends SceneTree
## Rootcrown in the game (docs/FINAL_SCENE_chapter1.md): the window with the game's night light, the hero at the top of the stair,
## on the fight floor, under the beacon and at both sides; then the beacon lit (story flag cleared_rootcrown); then the whole map
## lit at 2x. Windowed only (headless saves nothing):
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/rootcrown_v1/capture_rootcrown.gd
## Writes presentation/review/rootcrown_v1/rootcrown_<view>.png. No save is read or written (no persist meta).
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const OUT: String = "res://presentation/review/rootcrown_v1/"
const VIEWS: Array = [["stair", Vector2(322, 338)], ["plateau", Vector2(322, 214)], ["beacon_dark", Vector2(300, 150)], ["west", Vector2(150, 190)], ["east", Vector2(500, 190)]]

var scene: Explore


func _init() -> void:
	call_deferred("run")


func stand(at: Vector2) -> void:
	scene.core.place_at(at)
	for i: int in 4:
		scene.advance(InputFrame.new())


func shot(name: String) -> void:
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(OUT + "rootcrown_" + name + ".png")
	print("CAPTURE ", name, " ", error_string(error))


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_rootcrown: run it windowed")
		quit(1)
		return
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"rootcrown_layered"})
	scene = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	scene.set_physics_process(false)
	root.add_child(scene)
	await process_frame
	scene.fade_phase = &""
	scene.core.set_flag(&"received_first_sword")  # as the debug jump (Y) does: the hero is armed
	scene.core.set_flag(&"debug_all_unlocked")
	for view: Array in VIEWS:
		stand(view[1])
		await shot(view[0])
		scene.toast_ticks = 0  # the scene's title shows on the first view only
	scene.core.set_flag(&"cleared_rootcrown")
	stand(Vector2(300, 150))
	scene._refresh_props()
	await shot("beacon_lit")
	scene.camera.enabled = false
	(scene.get_node("HUD") as CanvasLayer).hide()
	root.content_scale_size = Vector2i(scene.snapshot.size)
	root.size = Vector2i(scene.snapshot.size) * 2
	stand(Vector2(322, 300))
	await shot("map_lit")
	print("ROOTCROWN CAPTURE OK")
	quit(0)
