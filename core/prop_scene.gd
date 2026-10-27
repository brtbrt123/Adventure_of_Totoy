extends RefCounted
## Layered scenes: a scene whose floor is one painting and whose props are separate sprites with a base line. The props'
## places and colliders come from two plain JSON files that core and presentation both read, so what blocks the hero
## and what is drawn never disagree (docs/architecture.md "Layered scenes", docs/LAYERED_SCENE_PILOT.md).
##
##   prop DEFS   data/props/prop_defs.json  (written by tools/art/extract_props.py; "locked" entries are hand-tuned)
##     {"version": 1, "props": {"<type>": {"image", "w", "h", "anchor": [ax, ay], "base_width", "solid",
##                                         "colliders": [[dx, dy, r], ...]}}}
##     anchor = the middle of the base, in sprite pixels from the sprite's top left; colliders are circles relative to
##     the anchor (dx right, dy down; at or above the base line, so dy <= 0).
##   scene FILE  data/scenes/<scene>_props.json  (hand-edited; adding or moving a prop is one line)
##     {"version": 1, "scene": "glade", "size": [w, h], "outline": [[x, y], ...] (the walkable ground, clockwise, game
##      pixels; edges on the world border are the openings), "boundary_radius", "boundary_spacing",
##      "props": [{"id": "stone_back", "type": "<type>", "x", "y" (where the anchor stands in the world), "flip"?}]}
##
## No sprites are loaded here (the core stays headless): sizes and colliders are numbers in the files.
const Obstacle := preload("res://core/obstacle.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")

const DEFS_PATH: String = "res://data/props/prop_defs.json"


## Reads a JSON file into a Dictionary; empty when it is missing or not an object (callers validate()).
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func load_defs(path: String = DEFS_PATH) -> Dictionary:
	return read_json(path)


static func load_scene(path: String) -> Dictionary:
	return read_json(path)


## The scene's prop placements with their def folded in, in file order:
## [{id, type, feet (Vector2), flip, size (Vector2), anchor (Vector2), image, solid}]. Presentation draws the sprite
## `image` with its anchor on `feet`, mirrored when `flip`, sorted by feet.y.
static func placements(scene: Dictionary, defs: Dictionary) -> Array:
	var out: Array = []
	var types: Dictionary = defs.get("props", {})
	for row: Variant in scene.get("props", []):
		var p: Dictionary = row
		var def: Dictionary = types.get(p.get("type", ""), {})
		var anchor: Array = def.get("anchor", [0, 0])
		out.append({
			"id": StringName(str(p.get("id", ""))),
			"type": StringName(str(p.get("type", ""))),
			"feet": Vector2(float(p.get("x", 0)), float(p.get("y", 0))),
			"flip": bool(p.get("flip", false)),
			"size": Vector2(float(def.get("w", 0)), float(def.get("h", 0))),
			"anchor": Vector2(float(anchor[0]), float(anchor[1])),
			"image": str(def.get("image", "")),
			"solid": bool(def.get("solid", false)),
		})
	return out


## The collision circles of every solid prop at its place (a flipped prop mirrors dx).
static func prop_colliders(scene: Dictionary, defs: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var types: Dictionary = defs.get("props", {})
	for row: Variant in scene.get("props", []):
		var p: Dictionary = row
		var def: Dictionary = types.get(p.get("type", ""), {})
		if not bool(def.get("solid", false)):
			continue
		var flip: float = -1.0 if bool(p.get("flip", false)) else 1.0
		for c: Variant in def.get("colliders", []):
			var circle: Array = c
			out.append(Vector3(float(p.get("x", 0)) + float(circle[0]) * flip, float(p.get("y", 0)) + float(circle[1]), float(circle[2])))
	return out


## The outline as Vector2s.
static func outline(scene: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v: Variant in scene.get("outline", []):
		var pair: Array = v
		out.append(Vector2(float(pair[0]), float(pair[1])))
	return out


static func size(scene: Dictionary) -> Vector2:
	var s: Array = scene.get("size", [0, 0])
	return Vector2(float(s[0]), float(s[1]))


## The scene's solid colliders: the edge chain along the outline, then every solid prop's circles (visual_id empty:
## presentation draws the props from the same placements).
static func build(scene: Dictionary, defs: Dictionary) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	var line: Array[Vector2] = outline(scene)
	var radius: float = float(scene.get("boundary_radius", 25.0))
	var spacing: float = float(scene.get("boundary_spacing", 17.0))
	for centre: Vector2 in SceneBounds.boundary_centres(line, radius, spacing, size(scene)):
		SceneBounds.add(list, centre, SceneBounds.fit_radius(line, centre, radius), centre)
	for c: Vector3 in prop_colliders(scene, defs):
		SceneBounds.add(list, Vector2(c.x, c.y), c.z, Vector2(c.x, c.y))
	return list


## Problems in the data (empty when fine): version, size, outline, unknown prop types, duplicate ids, bad colliders,
## anchors outside the sprite, props whose anchor is outside the world.
static func validate(scene: Dictionary, defs: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if defs.is_empty():
		errors.append("no prop defs")
	if scene.is_empty():
		errors.append("no scene data")
		return errors
	var world: Vector2 = size(scene)
	if world.x <= 0.0 or world.y <= 0.0:
		errors.append("bad size")
	if outline(scene).size() < 3:
		errors.append("outline needs at least 3 points")
	var types: Dictionary = defs.get("props", {})
	for type_id: Variant in types:
		var def: Dictionary = types[type_id]
		var anchor: Array = def.get("anchor", [])
		if anchor.size() != 2 or float(anchor[0]) < 0.0 or float(anchor[0]) > float(def.get("w", 0)) or float(anchor[1]) < 0.0 or float(anchor[1]) > float(def.get("h", 0)):
			errors.append("type %s: anchor outside the sprite" % type_id)
		for c: Variant in def.get("colliders", []):
			var circle: Array = c
			if circle.size() != 3 or float(circle[2]) <= 0.0 or float(circle[1]) > 0.0:
				errors.append("type %s: collider needs [dx, dy <= 0, r > 0]" % type_id)
		if bool(def.get("solid", false)) and def.get("colliders", []).is_empty():
			errors.append("type %s: solid without colliders" % type_id)
	var seen: Dictionary = {}
	for row: Variant in scene.get("props", []):
		var p: Dictionary = row
		var id: String = str(p.get("id", ""))
		if id.is_empty() or seen.has(id):
			errors.append("prop id '%s' is empty or duplicated" % id)
		seen[id] = true
		if not types.has(p.get("type", "")):
			errors.append("prop %s: unknown type '%s'" % [id, p.get("type", "")])
		var x: float = float(p.get("x", -1))
		var y: float = float(p.get("y", -1))
		if x < 0.0 or y < 0.0 or x > world.x or y > world.y:
			errors.append("prop %s: anchor outside the world" % id)
	return errors
