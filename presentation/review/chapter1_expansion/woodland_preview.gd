extends Node2D
## Review renderer only: no movement, encounters, routes or save state.
const PropScene := preload("res://core/prop_scene.gd")
const PropsLayer := preload("res://presentation/common/props_layer.gd")
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")
var data: Dictionary = {}
var frames: Dictionary = {}
var items: Array[Dictionary] = []
var atlas: Texture2D
var ground_texture: Texture2D
var annotations: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	data = PropScene.read_json("res://presentation/review/chapter1_expansion/woodland_approach.json")
	frames = PropScene.read_json("res://art/build/sprites.json")["frames"]
	atlas = load("res://art/build/sprites.png") as Texture2D
	var definitions: Dictionary = PropScene.load_defs()
	definitions["props"].merge(PropScene.read_json("res://art/reference/woodland_approach_v1/review_prop_defs.json")["props"])
	ground_texture = load("res://presentation/forest/woodland_approach_ground.png") as Texture2D
	var placements: Array[Dictionary] = PropScene.placements(data, definitions)
	var review_art: Dictionary = PropScene.read_json("res://art/reference/woodland_approach_v1/review_prop_art.json")["props"]
	items = PropsLayer.drawables(placements, frames, Rect2(0, 0, 640, 400), review_art)
	material = EnvironmentLight.make_material(&"forest_layered", Vector2(640, 400), placements)
	queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	draw_texture(ground_texture, Vector2.ZERO)
	PropsLayer.draw_shadows(self, items, 0.3, atlas)
	var hero: Vector2 = Vector2(data["hero_marker"][0], data["hero_marker"][1])
	var actors: Array[Dictionary] = [{"kind": &"actor", "id": "review_hero", "at": hero}]
	for item: Dictionary in PropsLayer.sorted_with_actors(items, actors):
		if item["kind"] == &"prop":
			PropsLayer.draw(self, item, atlas)
		else:
			var frame: Dictionary = frames["hero2_idle_right_1"]
			draw_texture_rect_region(atlas, Rect2(hero - Vector2(frame["ax"], frame["ay"]), Vector2(frame["w"], frame["h"])), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))
	if annotations:
		for zone: Dictionary in data["encounters"]:
			var r: Array = zone["rect"]
			draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color("a7d6c1"), false, 1.0)
