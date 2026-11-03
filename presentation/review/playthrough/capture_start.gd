extends SceneTree
## A debugging playthrough of the start of the game (2026-11-02; owner: "lets start debugging starting to the first scene"). The
## real game from its main scene, driven by real input actions in real time: the title screen, NEW GAME, the intro cutscene
## (each panel advanced, then the rest skipped), and the village arrival walked about. It saves a frame every so often and prints
## a marker at each stage, so the console's errors and warnings can be placed. A throwaway save (user://playthrough_save.json),
## so the owner's save is never touched.
##   godot --path . --resolution 1152x648 --script res://presentation/review/playthrough/capture_start.gd > log.txt
## Frames: user://playthrough/<stage>_<n>.png. Window only.
const SAVE_PATH: String = "user://playthrough_save.json"

var out_dir: String = ""
var shots: int = 0


func _init() -> void:
	call_deferred("run")


func shot(stage: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "%s_%03d.png" % [stage, shots])
	shots += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


## Holds `action` down for `hold` frames, sent through the input pipeline as a key press is (_input handlers and the action
## state both see it).
func press(action: String, hold: int = 2) -> void:
	send(action, true)
	await frames(hold)
	send(action, false)
	await frames(1)


func send(action: String, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func mark(stage: String) -> void:
	print("PLAYTHROUGH: ", stage, " (scene ", current_scene.scene_file_path if current_scene != null else "none", ")")


func run() -> void:
	out_dir = OS.get_user_data_dir() + "/playthrough/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for file: String in DirAccess.get_files_at(out_dir):
		DirAccess.remove_absolute(out_dir + file)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	OS.set_environment("TOTOY_SAVE_PATH", SAVE_PATH)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(5)
	mark("title")
	await frames(90)
	await shot("title")
	await press("menu_accept")
	await frames(20)
	mark("after title accept")
	await shot("title_after")
	for i: int in 24:  # the intro: a frame every 30, a panel advanced every 90
		await frames(30)
		await shot("intro")
		if i % 3 == 2:
			await press("dialogue_next")
		if current_scene != null and current_scene.scene_file_path.ends_with("explore_scene.tscn"):
			break
	mark("intro: skipping the rest")
	await press("dialogue_skip")
	for i: int in 300:
		await frames(1)
		if current_scene != null and current_scene.scene_file_path.ends_with("explore_scene.tscn"):
			break
	mark("village arrival")
	for i: int in 20:  # the arrival and its first lines
		await frames(20)
		await shot("village")
		if i % 4 == 3:
			await press("dialogue_next")
	mark("village: walking about")
	for step: Array in [["arena_right", 70], ["arena_down", 50], ["arena_left", 90], ["arena_up", 60], ["arena_right", 40]]:
		send(step[0], true)
		for i: int in int(step[1]) / 10:
			await frames(10)
			await shot("walk")
		send(step[0], false)
	mark("village: interact and attack")
	await press("explore_interact")
	await frames(30)
	await shot("interact")
	for i: int in 4:
		await press("dialogue_next")
		await frames(20)
		await shot("interact")
	await press("arena_attack")
	await frames(20)
	await shot("attack")
	mark("done")
	print("PLAYTHROUGH: %d frames in %s" % [shots, out_dir])
	quit(0)
