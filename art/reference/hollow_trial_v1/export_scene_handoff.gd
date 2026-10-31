extends SceneTree
## Bakes a PROPOSAL under art/reference only; never writes data or core.
const Bake := preload("res://tools/godot/bake_lib.gd")
const OUT: String = "res://art/reference/hollow_trial_v1/baked_scene_proposal.json"
func _init() -> void:
	var scene: Node2D = load("res://presentation/maps/hollow_trial_layered.tscn").instantiate() as Node2D
	var proposed: Dictionary = Bake.bake_map(scene)
	var file: FileAccess = FileAccess.open(OUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(proposed," ")+"\n")
	file.close()
	scene.free()
	print("TRIAL SCENE PROPOSAL EXPORTED / art only, not registered")
	quit()
