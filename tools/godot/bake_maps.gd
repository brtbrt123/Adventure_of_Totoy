extends SceneTree
## Bakes data/scenes/<id>_props.json from the map scenes (presentation/maps/<id>.tscn), the file the core reads.
##   godot --headless --path . --script res://tools/godot/bake_maps.gd -- [--scenes res://presentation/maps] [--out DIR]
##       [--style-from res://data/scenes]
## Without --out the files are written to data/scenes (kept as they are when nothing changed). --style-from names the
## folder whose files give the end-of-line and trailing-newline habit (default data/scenes).
const BakeLib := preload("res://tools/godot/bake_lib.gd")
const SCENES_OUT: String = "res://data/scenes"


func _init() -> void:
	var scenes: String = "res://presentation/maps"
	var out_dir: String = ""
	var style_dir: String = SCENES_OUT
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--scenes":
				i += 1
				scenes = args[i]
			"--out":
				i += 1
				out_dir = args[i]
			"--style-from":
				i += 1
				style_dir = args[i]
		i += 1
	var count: int = 0
	for file: String in DirAccess.get_files_at(scenes):
		if file.get_extension() != "tscn":
			continue
		var root: Node2D = (load(scenes.path_join(file)) as PackedScene).instantiate()
		var data: Dictionary = BakeLib.bake_map(root)
		var name: String = "%s_props.json" % root.name
		root.free()
		var target: String = (out_dir if out_dir != "" else SCENES_OUT).path_join(name)
		BakeLib.write_json(target, data, style_dir.path_join(name))
		count += 1
	print("BAKE MAPS OK: %d map(s)" % count)
	quit(0)
