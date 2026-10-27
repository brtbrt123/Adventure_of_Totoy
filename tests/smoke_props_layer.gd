extends SceneTree
const PropsLayer := preload("res://presentation/common/props_layer.gd")


func _init() -> void:
	var frames: Dictionary = {"stone": {"x": 1, "y": 2, "w": 24, "h": 32}}
	var placements: Array[Dictionary] = [{"id": "s", "type": "stone", "feet": Vector2(100, 80), "anchor": Vector2(8, 30), "flip": true}]
	var props: Array[Dictionary] = PropsLayer.drawables(placements, frames)
	assert(props.size() == 1)
	assert(props[0]["rect"] == Rect2(84, 50, 24, 32), "Mirrored anchor must stay at feet")
	var actors: Array[Dictionary] = [
		{"id": "behind", "kind": &"actor", "at": Vector2(100, 79)},
		{"id": "equal", "kind": &"actor", "at": Vector2(100, 80)},
		{"id": "front", "kind": &"actor", "at": Vector2(100, 81)}]
	var sorted: Array[Dictionary] = PropsLayer.sorted_with_actors(props, actors)
	assert(sorted[0]["id"] == "behind" and sorted[1]["id"] == "s")
	assert(sorted[2]["id"] == "equal" and sorted[3]["id"] == "front")
	assert(PropsLayer.drawables(placements, frames, Rect2(0, 0, 10, 10)).is_empty())
	assert(props.size() == 1 and actors.size() == 3, "Sorting must not mutate callers")
	# Real atlas path: source padding is cropped, shared half-pixel feet snap only once.
	var padded: Dictionary = {"village_dummy": {"x": 1, "y": 2, "w": 32, "h": 40, "ax": 14, "ay": 40}}
	var village: Array[Dictionary] = [{"id": "dummy", "type": "village_dummy", "feet": Vector2(100, 80), "anchor": Vector2(13.5, 38)}]
	var imported: Array[Dictionary] = PropsLayer.drawables(village, padded)
	assert(imported[0]["src"] == Rect2(1, 4, 28, 38), "Crop the top/right pad, keeping all original pixels")
	assert(imported[0]["rect"].position == Vector2(87, 42), "Shared half anchor snaps to a hard pixel")
	var log_frames: Dictionary = {"glade_log": {"x": 1, "y": 2, "w": 88, "h": 56, "ax": 59, "ay": 49}}
	var log_placement: Array[Dictionary] = [{"id": "log", "type": "glade_log", "feet": Vector2(100, 100), "anchor": Vector2(59, 49)}]
	var log_parts: Array[Dictionary] = PropsLayer.drawables(log_placement, log_frames)
	var crossing: Array[Dictionary] = [{"id": "hero", "kind": &"hero", "at": Vector2(45, 92)}]
	var crossed: Array[Dictionary] = PropsLayer.sorted_with_actors(log_parts, crossing)
	var hero_index: int = -1
	for i: int in crossed.size():
		if crossed[i]["kind"] == &"hero":
			hero_index = i
	assert(hero_index > 0 and hero_index < crossed.size() - 1, "Hero in front of raised end, behind lower end")
	print("PROPS LAYER OK: anchor, mirror, depth, ties, culling")
	quit()
