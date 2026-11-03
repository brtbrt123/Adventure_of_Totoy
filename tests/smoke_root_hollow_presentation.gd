extends SceneTree
const Shadows := preload("res://presentation/common/local_prop_shadows.gd")
const Props := preload("res://presentation/common/props_layer.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Event := preload("res://core/game_event.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var lights: PackedVector4Array = PackedVector4Array([Vector4(0,0,60,-1)])
	var plan: Dictionary = Shadows.plan(Vector2(20,0),lights,1)
	assert(not plan.is_empty() and Vector2(plan["y"]).x > -1.2,"light on left projects shadow toward right")
	assert(Shadows.plan(Vector2(200,0),lights,1).is_empty(),"far props have no local shadow")
	assert(Shadows.plan(Vector2.ZERO,lights,1).is_empty(),"fixture never casts a spurious self shadow")
	var scene: Explore = Explore.new()
	scene.snapshot = Explore.ExploreCore.ExploreSnapshot.new()
	var event: Event = Event.new(Event.REAPER_COIL_SPIN,0,{"position":Vector2.ZERO,"radius":40.0,"connects":true})
	scene.snapshot.mobs.append({"position":Vector2.ZERO,"radius":6,"state":&"dead","state_ticks":2})
	assert(scene.fx_spin_contacts(event).is_empty(),"old corpses have no sparks")
	scene.snapshot.mobs[0]["state_ticks"] = 1
	assert(scene.fx_spin_contacts(event).size()==1,"killing blow retains its spark")
	scene.free()
	for type: String in ["root_hollow_tree_ancient","root_hollow_tree_rootwall"]:
		var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
		var frame: Dictionary = frames[type]
		var placements: Array[Dictionary] = [{"id":&"tree","type":StringName(type),"feet":Vector2(100,100),"anchor":Vector2(frame["ax"],frame["ay"]),"size":Vector2(frame["w"],frame["h"])}]
		var props: Array[Dictionary] = Props.drawables(placements,frames)
		for y: float in [90.0,110.0]:
			var actors: Array[Dictionary] = [{"id":&"hero","kind":&"hero","at":Vector2(100,y)}]
			var sorted: Array[Dictionary] = Props.sorted_with_actors(props,actors)
			assert(sorted[0]["kind"] == (&"hero" if y<100 else &"prop"),"canopy preserves walk-behind sorting")
	Engine.set_meta(Explore.START_META,{"scene":&"root_hollow_layered"})
	var live: Explore = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
	root.add_child(live)
	live.set_physics_process(false)
	live.core.set_flag(&"cleared_hollow_center")
	live.snapshot = live.core.snapshot()
	live._on_event(Event.new(Event.FLAG_SET,live.snapshot.tick,{"flag":&"cleared_hollow_center"}))
	var open: bool = false
	for prop: Dictionary in live.prop_placements:
		if prop["id"] == &"hollow_barrier":open = prop["type"] == &"root_hollow_barrier_open"
	assert(open,"FLAG_SET refreshes the same sprite state as the collider")
	live.queue_free()
	await process_frame
	print("ROOT HOLLOW PRESENTATION OK: local shadows, canopy depth and corpse-spark correction")
	quit()
