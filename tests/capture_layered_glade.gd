extends SceneTree
## Standalone visual review. Exercises PropsLayer with scripted walking poses;
## no gameplay scene or collision rules are replaced by this capture fixture.
const PropsLayer := preload("res://presentation/common/props_layer.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const OUT: String = "res://art/reference/layered_pilot/review/"

class ReviewCanvas extends Node2D:
	var ground: Texture2D
	var atlas: Texture2D
	var frames: Dictionary
	var placements: Array[Dictionary] = []
	var hero: Vector2 = Vector2(280, 195)
	var walk_frame: int = 1
	var only_id: String = ""

	func _draw() -> void:
		draw_texture(ground, Vector2.ZERO)
		var selected: Array[Dictionary] = []
		for p: Dictionary in placements:
			if only_id == "" or p["id"] == only_id:
				selected.append(p)
		var props: Array[Dictionary] = PropsLayer.drawables(selected, frames)
		PropsLayer.draw_shadows(self, props)
		ActorShadow.draw(self, hero, 10)
		var actors: Array[Dictionary] = [{"id": "hero", "kind": &"actor", "at": hero}]
		for item: Dictionary in PropsLayer.sorted_with_actors(props, actors):
			if item["kind"] == &"prop":
				PropsLayer.draw(self, item, atlas)
			else:
				var f: Dictionary = frames["hero2_walk_right_" + str(walk_frame)]
				draw_texture_rect_region(atlas, Rect2(hero - Vector2(f["ax"], f["ay"]), Vector2(f["w"], f["h"])),
					Rect2(f["x"], f["y"], f["w"], f["h"]), PropsLayer.GLADE_TINT)


func _init() -> void:
	call_deferred("run")


func save(view: SubViewport, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = view.get_texture().get_image().save_png(OUT + label + ".png")
	assert(error == OK, "Capture failed: " + label)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenes/glade_layered_props.json"))
	var defs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/props/prop_defs.json"))["props"]
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(560, 336)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var canvas: ReviewCanvas = ReviewCanvas.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.ground = load("res://presentation/forest/glade_layered_ground.png") as Texture2D
	canvas.atlas = load("res://art/build/sprites.png") as Texture2D
	canvas.frames = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	for p: Dictionary in data["props"]:
		var a: Array = defs[p["type"]]["anchor"]
		canvas.placements.append({"id": p["id"], "type": p["type"], "feet": Vector2(p["x"], p["y"]),
			"anchor": Vector2(a[0], a[1]), "flip": p.get("flip", false), "shadow_radius": p["shadow_radius"]})
	view.add_child(canvas)
	await save(view, "glade_full")
	for p: Dictionary in canvas.placements:
		canvas.only_id = p["id"]
		for side: String in ["behind", "front"]:
			var offset: float = -10.0 if side == "behind" else 10.0
			for tick: int in range(12):
				canvas.hero = p["feet"] + Vector2(tick - 11, offset)
				canvas.walk_frame = (tick / 3) % 4 + 1
				canvas.queue_redraw()
				await process_frame
			await save(view, String(p["id"]) + "_" + side)
	print("LAYERED REVIEW OK: full glade + 40 front/behind captures; visual fixture only")
	quit()
