extends SceneTree
const MapView := preload("res://presentation/maps/hollow_trial_view.gd")
const Bake := preload("res://tools/godot/bake_lib.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("TRIAL SCENE FAIL: ",label)

func run() -> void:
	var scene: MapView = load("res://presentation/maps/hollow_trial_layered.tscn").instantiate() as MapView
	# Baker is read-only here; no data or registration output is written.
	var baked: Dictionary = Bake.bake_map(scene)
	var registration: Dictionary = Bake.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://art/reference/hollow_trial_v1/scene_registration.json")))
	for type_id: String in registration["props"]:
		var prop: Node2D = load("res://presentation/props/"+type_id+".tscn").instantiate() as Node2D
		var values: Dictionary = Bake.bake_prop(prop)
		check(values["anchor"] == registration["props"][type_id]["anchor"],"baked anchor agrees with registration: "+type_id)
		check(values["colliders"] == registration["props"][type_id]["colliders"],"baked editor circles agree with registration: "+type_id)
		prop.free()
	check(baked["size"] == [512,352],"map size")
	check(baked["entries"]["south"] == [256,328],"entry registration")
	check(baked["objects"].size() == 1 and baked["objects"][0]["stand"] == [256,204],"one altar stand starts trial and opens on-altar chest")
	check(baked["props"].size() == 32,"all approved placements editable and bakeable")
	check(baked["trial"]["spawn_points"].size() == 12,"real core trial configuration retained")
	root.add_child(scene)
	scene.animate_preview = false
	await process_frame
	check(scene.prop_records.size() == 32,"32 separate prop instances")
	check(scene.get_node("Props").y_sort_enabled,"props sort by feet rather than painted layers")
	check(int(scene.lamps["count"]) == 16,"eight rune rocks each with fixture and floor pool")
	for record: Dictionary in scene.prop_records:
		check(record["texture"] != null,"prop texture loads")
		check(record["node"].get_node("Sprite").use_parent_material,"night material reaches sprites")
		if record["id"] not in ["trial_altar","trial_chest"]:
			var anchor: Vector2 = record["anchor"]
			var size: Vector2 = record["size"]
			var offset: Vector2 = Vector2(size.x-anchor.x if record["flip"] else anchor.x,anchor.y)
			var rect: Rect2 = Rect2(Vector2(record["at"])-offset,size)
			check(not rect.intersects(Rect2(112,92,288,184)),"rim silhouette clears fight floor: " + String(record["id"]))
			if String(record["id"]).begins_with("rim_tree"):
				for point: Array in baked["trial"]["spawn_points"]:
					check(not rect.has_point(Vector2(point[0],point[1])),"tree canopy clears spawn point: "+String(record["id"]))
	var flags: Array[StringName] = [&"cleared_hollow_trial", &"trial_chest_opened"]
	scene.sync_snapshot({"state":&"won","sealed":false},flags,100)
	check(scene.get_node("Props/trial_altar").scene_file_path.ends_with("altar_lit.tscn"),"won switches altar")
	check(scene.get_node("Props/trial_chest").scene_file_path.ends_with("chest_open.tscn"),"chest flag switches chest")
	check(int(scene.lamps["count"]) == 18,"altar light only when lit")
	var material_before: Material = scene.material
	scene.sync_snapshot({"state":&"won","sealed":false},flags,101)
	check(scene.material == material_before,"steady snapshot does not recreate shader")
	scene.sync_snapshot({"state":&"wave","sealed":true},[],102)
	check(scene.get_node("Props/entry_roots").scene_file_path.ends_with("barrier_closed.tscn"),"core seal chooses closed roots")
	check(scene.get_node("Props/trial_altar").scene_file_path.ends_with("altar_dark.tscn"),"unlit state has dark altar")
	check(int(scene.lamps["count"]) == 16,"reset extinguishes altar light")
	check(scene.visual_tick == 102 and scene.snapshot_driven,"motes use supplied simulation tick")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("HOLLOW TRIAL SCENE OK")
	quit(1 if failures else 0)
