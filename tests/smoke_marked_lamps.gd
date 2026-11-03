extends SceneTree
const Props := preload("res://core/prop_scene.gd")
const Shadows := preload("res://presentation/common/local_prop_shadows.gd")
const Light := preload("res://presentation/common/environment_light.gd")
func _init() -> void:
	var path: String = "res://data/scenes/root_hollow_layered_props.json"
	var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var defs: Dictionary = Props.load_defs()
	var expected: Array[Array] = [[187,62,false],[199,180,true],[455,138,false],[391,279,true]]
	var n: int = 0
	for row: Dictionary in scene["props"]:
		if row["type"] != "woodland_lantern": continue
		assert(row["x"]==expected[n][0] and row["y"]==expected[n][1] and row.get("flip",false)==expected[n][2],"marked post placement/facing")
		var circles: Array[Vector3] = Props.prop_colliders({"props":[row]},defs)
		assert(circles.size()==1)
		assert(is_equal_approx(circles[0].x,float(row["x"])+(-4.5 if row["flip"] else 4.5)),"pole collider mirrors with sprite")
		n+=1
	assert(n==4,"only four marked lamps remain")
	var placements: Array[Dictionary] = Props.placements(scene,defs,{"flags":[]})
	var plan: Dictionary = Light.lamp_plan(placements)
	assert(plan["dropped"]==0 and plan["count"]==18,"all four lamps and five teal fixtures get light slots")
	var sockets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/common/local_lights.json"))
	for key: String in ["glade_stone_1","glade_stone_2","glade_stone_3","glade_stone_4","glade_stone_5","forest_standing_stone","forest_pedestal_lit","root_hollow_shrine","root_hollow_rune_stones"]:
		assert(sockets[key][0]["energy"]==1.35 and sockets[key][0]["halo_radius"]==35.0,"consistent magical stone glow")
	assert(sockets["root_hollow_rune_stones"].size()==3,"each stone in the cluster has its own glow")
	assert(not sockets.has("forest_pedestal"),"unlit puzzle state stays distinct")
	assert(Shadows.plan(Vector2(20,0),PackedVector4Array([Vector4(0,0,60,-1)]),1,"stone",PackedStringArray(["stone"])).is_empty(),"multi-stone fixtures never shadow their own cluster")
	print("MARKED LAMPS OK: four positions/facings, mirrored real colliders, light budget and shared stone glow")
	quit()
