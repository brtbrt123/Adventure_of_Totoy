extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Event := preload("res://core/game_event.gd")
func _init() -> void:
	var scene: Explore = Explore.new()
	scene.snapshot = Explore.ExploreCore.ExploreSnapshot.new()
	scene.snapshot.mobs.append({"id": 999, "position": Vector2(10,0), "radius": 6.0, "hp": 0, "state": &"dead"})
	var event: Event = Event.new(Event.REAPER_COIL_SPIN, 100, {"position": Vector2.ZERO, "radius": 48.0, "connects": true})
	var contacts: Array[Vector2] = scene.fx_spin_contacts(event)
	print("REVIEW REPRO: previously dead mob contributes ",contacts.size()," false spin spark positions")
	scene.free()
	quit()
