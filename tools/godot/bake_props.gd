extends SceneTree
## Bakes the collider part of the prop definitions from the prop scenes.
##   godot --headless --path . --script res://tools/godot/bake_props.gd -- [--scenes res://presentation/props] [--out DIR]
## Without --out the three data/props/prop_defs*.json files are rewritten in place (only when a value really changed).
## With --out the files are written there under the same names (round-trip tests). Exit 0 on success.
const BakeLib := preload("res://tools/godot/bake_lib.gd")


func _init() -> void:
	var scenes: String = BakeLib.PROPS_DIR
	var out_dir: String = ""
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
		i += 1
	var baked: Dictionary = BakeLib.bake_prop_defs(scenes)
	var changed: int = 0
	for file: Variant in baked:
		var name: String = str(file).get_file()
		var data: Dictionary = baked[file]
		if out_dir == "":
			var before: Variant = BakeLib.normalize(JSON.parse_string(FileAccess.get_file_as_string(str(file))))
			if JSON.stringify(before) == JSON.stringify(data):
				continue
			BakeLib.write_json(str(file), data, str(file))
			changed += 1
		else:
			BakeLib.write_json(out_dir.path_join(name), data, str(file))
			changed += 1
	print("BAKE PROPS OK: %d file(s) written" % changed)
	quit(0)
