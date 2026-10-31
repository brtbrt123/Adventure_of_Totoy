extends RefCounted
## Layered scenes: a scene whose floor is one painting and whose props are separate sprites with a base line. The props'
## places and colliders come from two plain JSON files that core and presentation both read, so what blocks the hero
## and what is drawn never disagree (docs/architecture.md "Layered scenes", docs/LAYERED_SCENE_PILOT.md).
##
##   prop DEFS   data/props/prop_defs.json  (written by tools/art/extract_props.py; "locked" entries are hand-tuned), plus
##               data/props/prop_defs_woodland.json (the Woodland Approach props, same format, merged by load_defs())
##     {"version": 1, "props": {"<type>": {"image", "w", "h", "anchor": [ax, ay], "base_width", "solid",
##                                         "colliders": [[dx, dy, r], ...]}}}
##     anchor = the middle of the base, in sprite pixels from the sprite's top left; colliders are circles relative to
##     the anchor (dx right, dy down; at or above the base line, so dy <= 0).
##   scene FILE  data/scenes/<scene>_props.json  (hand-edited; adding or moving a prop is one line)
##     {"version": 1, "scene": "glade", "size": [w, h], "outline": [[x, y], ...] (the walkable ground, clockwise, game
##      pixels; edges on the world border are the openings), "boundary_radius", "boundary_spacing",
##      "props": [{"id": "stone_back", "type": "<type>", "x", "y" (where the anchor stands in the world), "flip"?,
##                 "shadow_radius"? (presentation's ground shadow, passed through)}],
##      and, for a scene the player walks through (SceneDefs.get_def / ExploreCore): "name", "ground" (the floor
##      painting, a res:// path), "entries": {id: [x, y]}, "default_entry", "exits": [{id, rect [x, y, w, h],
##      target_scene, target_entry}], "checkpoints": [{id, position}], "npcs": [{id, visual, position (where the person
##      stands), face_left}], "objects": [{id, kind (chest, door, dummy, ...), position (its feet), stand (where the hero
##      uses it from, in front)}] (the props that are interactable stay ordinary props; the object row says how to use
##      them), "encounters": [{id, name, rect [x, y, w, h], leash, reward {reward_id, kind, item, name, quantity},
##      mobs [{type, x, y}]}] (the mobs of a scene, core/mob_field.gd), "prop_margin" (props may stand this far outside the
##      world: trees hanging over the edge), and for the Stag fight room "stag_start", "stag_radius", "fight_area" [x, y, w, h]}
##
##   STATES  a placement may show another type while a scene state holds: {"when": "gate_open" | "lit:<switch id>" | "flag:<story flag>" | "trial:<tag>",
##     "on_type": "<type>"}. `states` = {"gate_open": bool, "lit": [switch ids], "flags": [story flags]} (ExploreCore owns it;
##     ExploreSnapshot exposes it; "flag:cleared_hollow_center" is how Root Hollow's root-knot barrier opens). The two types of a pair share w, h and anchor (tools/art/normalize_state_pairs.py; validate() checks
##     it), each has its own colliders: a closed root gate is solid across its doorway, the open one only at its trunks.
##
## No sprites are loaded here (the core stays headless): sizes and colliders are numbers in the files.
const Obstacle := preload("res://core/obstacle.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")

const DEFS_PATH: String = "res://data/props/prop_defs.json"
## Catalogues of later areas, merged into the main one by load_defs() (a type in the main file wins).
const EXTRA_DEFS_PATHS: Array[String] = ["res://data/props/prop_defs_woodland.json", "res://data/props/prop_defs_root_hollow.json"]


## Reads a JSON file into a Dictionary; empty when it is missing or not an object (callers validate()).
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func load_defs(path: String = DEFS_PATH) -> Dictionary:
	var defs: Dictionary = read_json(path)
	if path != DEFS_PATH or defs.is_empty():
		return defs
	for extra: String in EXTRA_DEFS_PATHS:
		var more: Dictionary = read_json(extra).get("props", {})
		for type_id: Variant in more:
			if not defs["props"].has(type_id):
				defs["props"][type_id] = more[type_id]
	return defs


static func load_scene(path: String) -> Dictionary:
	return read_json(path)


## True when the state `when` ("gate_open", "lit:<switch id>" or "flag:<story flag>") holds in `states`.
static func state_holds(when: String, states: Dictionary) -> bool:
	if when == "gate_open":
		return bool(states.get("gate_open", false))
	if when.begins_with("lit:"):
		var lit: Array = states.get("lit", [])
		return lit.has(when.substr(4)) or lit.has(StringName(when.substr(4)))
	if when.begins_with("flag:"):
		var flags: Array = states.get("flags", [])
		return flags.has(when.substr(5)) or flags.has(StringName(when.substr(5)))
	if when.begins_with("trial:"):  # a tag of the scene's trial (core/trial.gd), e.g. "trial:sealed" while a wave lives
		var tags: Array = states.get("trial", [])
		return tags.has(when.substr(6)) or tags.has(StringName(when.substr(6)))
	return false


## The type a placement row shows now: its `on_type` while its `when` state holds, else its own `type`.
static func type_of(row: Dictionary, states: Dictionary) -> String:
	if row.has("when") and row.has("on_type") and state_holds(str(row["when"]), states):
		return str(row["on_type"])
	return str(row.get("type", ""))


## The scene's prop placements with their def folded in, in file order:
## [{id, type, feet (Vector2), flip, size (Vector2), anchor (Vector2), image, solid, shadow_radius?, state?}]. Presentation
## draws the sprite `image` with its anchor on `feet`, mirrored when `flip`, sorted by feet.y. `states` (see the header)
## picks the type of a stateful prop (`type` is then the shown one and `state` is &"on" or &"off"); the default is every
## state off.
static func placements(scene: Dictionary, defs: Dictionary, states: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var types: Dictionary = defs.get("props", {})
	for row: Variant in scene.get("props", []):
		var p: Dictionary = row
		var shown: String = type_of(p, states)
		var def: Dictionary = types.get(shown, {})
		var anchor: Array = def.get("anchor", [0, 0])
		var entry: Dictionary = {
			"id": StringName(str(p.get("id", ""))),
			"type": StringName(shown),
			"feet": Vector2(float(p.get("x", 0)), float(p.get("y", 0))),
			"flip": bool(p.get("flip", false)),
			"size": Vector2(float(def.get("w", 0)), float(def.get("h", 0))),
			"anchor": Vector2(float(anchor[0]), float(anchor[1])),
			"image": str(def.get("image", "")),
			"solid": bool(def.get("solid", false)),
		}
		if p.has("shadow_radius"):
			entry["shadow_radius"] = float(p["shadow_radius"])
		if p.has("when"):
			entry["state"] = &"on" if shown != str(p.get("type", "")) else &"off"
		out.append(entry)
	return out


## The collision circles of every solid prop at its place (a flipped prop mirrors dx), for the types shown in `states`.
static func prop_colliders(scene: Dictionary, defs: Dictionary, states: Dictionary = {}) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var types: Dictionary = defs.get("props", {})
	for row: Variant in scene.get("props", []):
		var p: Dictionary = row
		var def: Dictionary = types.get(type_of(p, states), {})
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


static func _vec(v: Variant) -> Vector2:
	var pair: Array = v
	return Vector2(float(pair[0]), float(pair[1]))


static func _rect(v: Variant) -> Rect2:
	var r: Array = v
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## The scene as SceneDefs.get_def() describes a walkable scene (id, name, size, margin, entries, default_entry, exits,
## checkpoints, npcs, objects), so ExploreCore can run it. `id` is the scene id the game uses for it.
static func scene_def(scene: Dictionary, id: StringName, margin: float) -> Dictionary:
	var entries: Dictionary = {}
	for key: Variant in scene.get("entries", {}):
		entries[StringName(str(key))] = _vec(scene["entries"][key])
	var exits: Array = []
	for row: Variant in scene.get("exits", []):
		var e: Dictionary = row
		var exit_row: Dictionary = {"id": StringName(str(e["id"])), "rect": _rect(e["rect"]), "target_scene": StringName(str(e["target_scene"])),
			"target_entry": StringName(str(e["target_entry"]))}
		if e.has("gate"):  # "road": closed until the village sequence is done (core/quest_book.gd)
			exit_row["gate"] = StringName(str(e["gate"]))
		if e.has("requires_flag"):  # closed until this story flag is set (the glade's root arch: cleared_stag_glade)
			exit_row["requires_flag"] = StringName(str(e["requires_flag"]))
			exit_row["blocked_text"] = str(e.get("blocked_text", ""))
		exits.append(exit_row)
	var checkpoints: Array = []
	for row: Variant in scene.get("checkpoints", []):
		var c: Dictionary = row
		checkpoints.append({"id": StringName(str(c["id"])), "position": _vec(c["position"])})
	var npcs: Array = []
	for row: Variant in scene.get("npcs", []):
		var n: Dictionary = row
		npcs.append({"id": StringName(str(n["id"])), "visual": StringName(str(n["visual"])), "position": _vec(n["position"]),
			"face_left": bool(n.get("face_left", false))})
	var objects: Array = []
	for row: Variant in scene.get("objects", []):
		var o: Dictionary = row
		objects.append({"id": StringName(str(o["id"])), "kind": StringName(str(o["kind"])), "position": _vec(o["position"]),
			"stand": _vec(o["stand"])})
	var result: Dictionary = {"id": id, "name": str(scene.get("name", "")), "size": size(scene), "margin": margin, "entries": entries,
		"default_entry": StringName(str(scene.get("default_entry", ""))), "exits": exits, "checkpoints": checkpoints,
		"npcs": npcs, "objects": objects}
	result["encounters"] = scene.get("encounters", []).duplicate(true)  # raw rows: core/mob_field.gd reads them
	if scene.has("trial"):  # a trial room (core/trial.gd): waves, spawn points, the altar, the chest and its reward
		result["trial"] = scene["trial"].duplicate(true)
	if scene.has("puzzle"):  # {"switches": [object ids]}: lighting them all opens the gate (ExploreCore)
		var switches: Array[StringName] = []
		for switch_id: Variant in scene["puzzle"].get("switches", []):
			switches.append(StringName(str(switch_id)))
		result["puzzle"] = {"switches": switches}
	return result


## The Stag fight room: {start (Vector2), radius, area (Rect2)}; empty when the scene has none.
static func fight_room(scene: Dictionary) -> Dictionary:
	if not scene.has("stag_start"):
		return {}
	return {"start": _vec(scene["stag_start"]), "radius": float(scene.get("stag_radius", 20.0)), "area": _rect(scene["fight_area"])}


static func size(scene: Dictionary) -> Vector2:
	var s: Array = scene.get("size", [0, 0])
	return Vector2(float(s[0]), float(s[1]))


## The scene's solid colliders: the edge chain along the outline, then every solid prop's circles (visual_id empty:
## presentation draws the props from the same placements), for the stateful props' types shown in `states`.
static func build(scene: Dictionary, defs: Dictionary, states: Dictionary = {}) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	var line: Array[Vector2] = outline(scene)
	var radius: float = float(scene.get("boundary_radius", 25.0))
	var spacing: float = float(scene.get("boundary_spacing", 17.0))
	for centre: Vector2 in SceneBounds.boundary_centres(line, radius, spacing, size(scene)):
		SceneBounds.add(list, centre, SceneBounds.fit_radius(line, centre, radius), centre)
	for c: Vector3 in prop_colliders(scene, defs, states):
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
	var people: Dictionary = {}
	for row: Variant in scene.get("npcs", []):
		var n: Dictionary = row
		var who: String = str(n.get("id", ""))
		var at: Vector2 = _vec(n.get("position", [-1, -1]))
		if who.is_empty() or people.has(who) or at.x < 0.0 or at.y < 0.0 or at.x > world.x or at.y > world.y:
			errors.append("npc '%s' is empty, duplicated or outside the world" % who)
		people[who] = true
	var things: Dictionary = {}
	for row: Variant in scene.get("objects", []):
		var o: Dictionary = row
		var what: String = str(o.get("id", ""))
		if what.is_empty() or things.has(what) or not o.has("stand") or not o.has("position"):
			errors.append("object '%s' is empty, duplicated or lacks position/stand" % what)
		things[what] = true
	var seen: Dictionary = {}
	for row: Variant in scene.get("props", []):
		var p: Dictionary = row
		var id: String = str(p.get("id", ""))
		if id.is_empty() or seen.has(id):
			errors.append("prop id '%s' is empty or duplicated" % id)
		seen[id] = true
		if not types.has(p.get("type", "")):
			errors.append("prop %s: unknown type '%s'" % [id, p.get("type", "")])
		if p.has("when") or p.has("on_type"):
			errors.append_array(_validate_state_row(id, p, types, scene))
		var x: float = float(p.get("x", -1))
		var y: float = float(p.get("y", -1))
		var slack: float = float(scene.get("prop_margin", 0.0))
		if x < -slack or y < -slack or x > world.x + slack or y > world.y + slack:
			errors.append("prop %s: anchor outside the world" % id)
	return errors


## Problems of a stateful row: a known `when`, an `on_type` that exists and has the SAME w, h and anchor as `type`
## (the two states stand in one place), and a lit:<id> naming one of the scene's puzzle switches.
static func _validate_state_row(id: String, row: Dictionary, types: Dictionary, scene: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var when: String = str(row.get("when", ""))
	if when != "gate_open" and not when.begins_with("lit:") and not when.begins_with("flag:") and not when.begins_with("trial:"):
		errors.append("prop %s: unknown state '%s' (gate_open, lit:<switch>, flag:<story flag> or trial:<tag>)" % [id, when])
	elif when.begins_with("lit:") and not scene.get("puzzle", {}).get("switches", []).has(when.substr(4)):
		errors.append("prop %s: '%s' is not a puzzle switch of the scene" % [id, when.substr(4)])
	var base: Dictionary = types.get(row.get("type", ""), {})
	var on: Dictionary = types.get(row.get("on_type", ""), {})
	if on.is_empty():
		errors.append("prop %s: unknown on_type '%s'" % [id, row.get("on_type", "")])
	elif on.get("w") != base.get("w") or on.get("h") != base.get("h") or on.get("anchor") != base.get("anchor"):
		errors.append("prop %s: the two states must share w, h and anchor" % id)
	return errors
