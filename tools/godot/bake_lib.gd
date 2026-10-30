extends RefCounted
## The baker's shared code: reads the editable Godot scenes (presentation/props/*.tscn, presentation/maps/*.tscn) and
## builds the plain data the headless core reads (data/props/prop_defs*.json, data/scenes/<id>_props.json).
## Scene files are the source of truth; the JSON is a build output. Nothing here runs in the game, only in tools.
##
## Numbers: a position or size is a float32 in a scene, so every value is cleaned back to its shortest decimal
## (9.2 stays 9.2) and written as an integer when it is whole. Values kept as scene METADATA keep their own type
## (`22` stays an integer, `6.0` stays a float), so the files come back byte for byte.

const PROPS_DIR: String = "res://presentation/props"
const DEF_FILES: Array[String] = ["res://data/props/prop_defs.json", "res://data/props/prop_defs_woodland.json", "res://data/props/prop_defs_root_hollow.json"]


# ---------------------------------------------------------------------------------------------------------- numbers

## The value of a float32 property as the decimal a human wrote.
static func clean32(v: float) -> float:
	for digits: int in range(0, 9):
		var text: String = String.num(v, digits)
		if Vector2(text.to_float(), 0.0).x == v:
			return text.to_float()
	return v


## A coordinate: an int when whole, else the cleaned float.
static func coord(v: float) -> Variant:
	var c: float = clean32(v)
	if c == floorf(c) and absf(c) < 1.0e15:
		return int(c)
	return c


static func coords(v: Vector2) -> Array:
	return [coord(v.x), coord(v.y)]


## Converts the whole numbers of a parsed JSON tree to ints (Godot's parser reads every number as a float).
static func normalize(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for key: Variant in v:
			out[key] = normalize(v[key])
		return out
	if v is Array:
		var list: Array = []
		for item: Variant in v:
			list.append(normalize(item))
		return list
	if v is float and v == floorf(v) and absf(v) < 1.0e15:
		return int(v)
	return v


# ------------------------------------------------------------------------------------------------------------- JSON

## Python's json.dumps(value, indent=1) spelling: one space per level, "key": value, [] and {} when empty.
static func dump(v: Variant, level: int = 0) -> String:
	var pad: String = " ".repeat(level + 1)
	var end_pad: String = " ".repeat(level)
	if v is Dictionary:
		if v.is_empty():
			return "{}"
		var parts: PackedStringArray = PackedStringArray()
		for key: Variant in v:
			parts.append(pad + _quote(str(key)) + ": " + dump(v[key], level + 1))
		return "{\n" + ",\n".join(parts) + "\n" + end_pad + "}"
	if v is Array:
		if v.is_empty():
			return "[]"
		var items: PackedStringArray = PackedStringArray()
		for item: Variant in v:
			items.append(pad + dump(item, level + 1))
		return "[\n" + ",\n".join(items) + "\n" + end_pad + "]"
	if v is bool:
		return "true" if v else "false"
	if v is int:
		return str(v)
	if v is float:
		return _float_text(v)
	if v == null:
		return "null"
	return _quote(str(v))


static func _quote(s: String) -> String:
	return JSON.stringify(s)


static func _float_text(v: float) -> String:
	for digits: int in range(1, 18):
		var text: String = String.num(v, digits)
		if text.to_float() == v:
			return text
	return str(v)


## Writes `data` as JSON to `path`, with the end-of-line and trailing-newline habit of `style_path` when it exists.
static func write_json(path: String, data: Variant, style_path: String = "") -> void:
	var text: String = dump(data)
	var crlf: bool = false
	var trailing: bool = true
	if style_path != "" and FileAccess.file_exists(style_path):
		var old: String = FileAccess.get_file_as_string(style_path)
		crlf = old.contains("\r\n")
		trailing = old.ends_with("\n")
	if trailing:
		text += "\n"
	if crlf:
		text = text.replace("\n", "\r\n")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# ------------------------------------------------------------------------------------------------------------ props

## What the scene of one prop type says: {anchor, solid, colliders}. The rest of a definition (w, h, image, notes) is not
## edited in the scene and stays as it is in the JSON.
static func bake_prop(root: Node2D) -> Dictionary:
	var sprite: Sprite2D = root.get_node("Sprite")
	var offset: Vector2 = sprite.offset
	var colliders: Array = []
	var body: Node = root.get_node_or_null("Colliders")
	if body != null:
		for child: Node in body.get_children():
			var shape_node: CollisionShape2D = child
			var circle: CircleShape2D = shape_node.shape
			var at: Vector2 = shape_node.position
			colliders.append([coord(at.x), coord(at.y), coord(circle.radius)])
	return {"anchor": coords(-offset), "solid": bool(root.get_meta("solid", false)), "colliders": colliders}


## Reads the scene of `type_id` from `dir`; null when there is none.
static func load_prop_root(dir: String, type_id: String) -> Node2D:
	var path: String = "%s/%s.tscn" % [dir, type_id]
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	return packed.instantiate()


## The three definition files with the anchor, solid and colliders of every type that has a scene laid over them.
## Returns {file path: data}. A type without a scene keeps its JSON values.
static func bake_prop_defs(dir: String) -> Dictionary:
	var out: Dictionary = {}
	var claimed: Dictionary = {}
	for file: String in DEF_FILES:
		var data: Dictionary = normalize(JSON.parse_string(FileAccess.get_file_as_string(file)))
		var props: Dictionary = data["props"]
		for type_id: Variant in props:
			var root: Node2D = load_prop_root(dir, str(type_id))
			if root == null or claimed.has(type_id):
				continue
			claimed[type_id] = true
			var baked: Dictionary = bake_prop(root)
			root.free()
			var entry: Dictionary = props[type_id]
			# main file wins for a type that is in two files, exactly like PropScene.load_defs
			for key: String in ["anchor", "solid", "colliders"]:
				if entry.has(key):
					entry[key] = baked[key]
		out[file] = data
	return out


# ------------------------------------------------------------------------------------------------------------- maps

## World position of a node inside a scene that is not in the tree: the sum of the positions up to the root.
static func world(node: Node2D, root: Node) -> Vector2:
	var at: Vector2 = Vector2.ZERO
	var cursor: Node = node
	while cursor != null and cursor != root:
		if cursor is Node2D:
			at += cursor.position
		cursor = cursor.get_parent()
	return at


static func rect_of(area: Area2D, root: Node) -> Array:
	var shape_node: CollisionShape2D = area.get_node("Rect")
	var size: Vector2 = (shape_node.shape as RectangleShape2D).size
	var top_left: Vector2 = world(area, root) + shape_node.position - size * 0.5
	return [coord(top_left.x), coord(top_left.y), coord(size.x), coord(size.y)]


static func _meta_or(node: Node, key: String, fallback: Variant) -> Variant:
	return node.get_meta(key) if node.has_meta(key) else fallback


static func _children(root: Node, group: String) -> Array[Node]:
	var node: Node = root.get_node_or_null(group)
	var list: Array[Node] = []
	if node != null:
		list.assign(node.get_children())
	return list


## The scene data JSON of one map scene (data/scenes/<id>_props.json), keys in the order the files have them.
static func bake_map(root: Node2D) -> Dictionary:
	var out: Dictionary = {}
	out["version"] = root.get_meta("version", 1)
	out["scene"] = str(root.name)
	out["name"] = root.get_meta("title", "")
	out["size"] = root.get_meta("size", [0, 0])
	var ground: Sprite2D = root.get_node("Ground")
	out["ground"] = ground.texture.resource_path
	var outline: Array = []
	for point: Vector2 in (root.get_node("Walkable") as Polygon2D).polygon:
		outline.append(coords(point))
	out["outline"] = outline
	for key: String in ["boundary_radius", "boundary_spacing", "prop_margin"]:
		if root.has_meta(key):
			out[key] = root.get_meta(key)
	var entries: Dictionary = {}
	for marker: Node in _children(root, "Entries"):
		entries[str(marker.name)] = coords(world(marker, root))
	out["entries"] = entries
	out["default_entry"] = root.get_meta("default_entry", "")
	var exits: Array = []
	for node: Node in _children(root, "Exits"):
		var area: Area2D = node
		var row: Dictionary = {"id": str(area.name), "rect": rect_of(area, root)}
		for key: String in ["target_scene", "target_entry", "gate", "requires_flag", "blocked_text"]:
			if area.has_meta(key):
				row[key] = area.get_meta(key)
		exits.append(row)
	out["exits"] = exits
	var checkpoints: Array = []
	for marker: Node in _children(root, "Checkpoints"):
		checkpoints.append({"id": str(marker.name), "position": coords(world(marker, root))})
	out["checkpoints"] = checkpoints
	if root.get_node_or_null("Npcs") != null:
		var npcs: Array = []
		for marker: Node in _children(root, "Npcs"):
			var npc: Dictionary = {"id": str(marker.name), "visual": marker.get_meta("visual", ""), "position": coords(world(marker, root))}
			if marker.has_meta("face_left"):
				npc["face_left"] = marker.get_meta("face_left")
			npcs.append(npc)
		out["npcs"] = npcs
	if root.get_node_or_null("Objects") != null:
		var objects: Array = []
		for marker: Node in _children(root, "Objects"):
			var stand: Node2D = marker.get_node("Stand")
			objects.append({"id": str(marker.name), "kind": marker.get_meta("kind", ""), "position": coords(world(marker, root)), "stand": coords(world(stand, root))})
		out["objects"] = objects
	if root.has_meta("puzzle"):
		out["puzzle"] = root.get_meta("puzzle")
	var stag: Node2D = root.get_node_or_null("StagStart")
	if stag != null:
		out["stag_start"] = coords(world(stag, root))
		out["stag_radius"] = stag.get_meta("stag_radius", 20)
		out["fight_area"] = rect_of(root.get_node("FightArea"), root)
	if root.get_node_or_null("Encounters") != null:
		var encounters: Array = []
		for node: Node in _children(root, "Encounters"):
			var row: Dictionary = {"id": str(node.name), "name": node.get_meta("title", ""), "rect": rect_of(node.get_node("Zone"), root), "leash": node.get_meta("leash", 0)}
			if node.has_meta("reward"):
				row["reward"] = node.get_meta("reward")
			var mobs: Array = []
			for child: Node in node.get_children():
				if child.has_meta("mob"):
					var at: Vector2 = world(child, root)
					mobs.append({"type": child.get_meta("mob"), "x": coord(at.x), "y": coord(at.y)})
			row["mobs"] = mobs
			encounters.append(row)
		out["encounters"] = encounters
	var props: Array = []
	for node: Node in _children(root, "Props"):
		var prop: Node2D = node
		var at: Vector2 = world(prop, root)
		var row: Dictionary = {"id": str(prop.name), "type": prop.scene_file_path.get_file().get_basename(), "x": coord(at.x), "y": coord(at.y)}
		if prop.scale.x < 0.0:
			row["flip"] = true
		elif prop.has_meta("flip"):
			row["flip"] = bool(prop.get_meta("flip"))
		if prop.has_meta("shadow_radius"):
			row["shadow_radius"] = prop.get_meta("shadow_radius")
		if prop.has_meta("when"):
			row["when"] = prop.get_meta("when")
			row["on_type"] = prop.get_meta("on_type", "")
		props.append(row)
	out["props"] = props
	return out
