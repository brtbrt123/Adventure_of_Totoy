extends RefCounted
## The chapter 1 scene graph (static data only): the explorable scenes, their sizes, entries (spawn points), exits
## (trigger rectangles leading to another scene's entry), checkpoints, NPCs and interactables, and the solid colliders
## (from each scene's layout). core/explore_core.gd runs a scene from this table; presentation draws it.
##
##   village (Lanternfen)  EXIT_FOREST (right edge)            -> forest  "village_side"
##   forest                left edge                           -> village "return"
##   forest                north exit behind the root gate     -> glade   "entrance"   (gate closed = solid, see below)
##   glade                 bottom-left entrance                -> forest  "north"      (just below the forest's north exit)
##   glade                 root arch                           -> arena   "start"      (the Colossus fight)
##   arena                 no exits (the fight's victory screen returns to the title)
##
## glade_layered (the Stag glade as a layered scene: one floor painting + separate prop sprites, data/scenes/glade_layered_props.json
## read through core/prop_scene.gd) is a FIFTH scene, not in IDS, until the human switches the game over from the painted
## glade: forest -> glade stays the painted one. It has the same two exits (forest "north", arena "start"); its own entry
## is "entrance" and its own checkpoint "glade_layered_entrance". SceneDefs.LAYERED lists such scenes.
##
## The forest's root gate is solid until the lantern puzzle opens it (a later step); `gate_open` (a scene state flag,
## saved in SaveProfile.gate_open, toggled by the debug key F6 or G) builds the forest with build_with_gate(true).
const Tuning := preload("res://core/tuning.gd")
const Obstacle := preload("res://core/obstacle.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const VillageLayout := preload("res://core/village_layout.gd")
const ForestLayout := preload("res://core/forest_layout.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const ArenaLayout := preload("res://core/arena_layout.gd")
const PropScene := preload("res://core/prop_scene.gd")

const VILLAGE: StringName = &"village"
const FOREST: StringName = &"forest"
const GLADE: StringName = &"glade"
const ARENA: StringName = &"arena"
const IDS: Array[StringName] = [VILLAGE, FOREST, GLADE, ARENA]
## The layered scenes (floor + prop sprites, built from data/scenes/<id>_props.json).
const GLADE_LAYERED: StringName = &"glade_layered"
const LAYERED: Array[StringName] = [GLADE_LAYERED]
const LAYERED_PATHS: Dictionary = {GLADE_LAYERED: "res://data/scenes/glade_layered_props.json"}

## Where a new game starts.
const START_SCENE: StringName = VILLAGE
const START_ENTRY: StringName = &"arrival"

## Body radius of an NPC and of the village chest as solid circles (people stand still; the hero walks round them).
const NPC_RADIUS: float = 5.0
const CHEST_RADIUS: float = 6.0

## The forest's north entry (coming back from the glade): on the path behind the root gate, just below the exit trigger.
const FOREST_NORTH_ENTRY: Vector2 = Vector2(388.0, 28.0)


## The whole definition of one scene (a fresh Dictionary each call):
## id, name (display), size, margin (bodies stay this far inside the world edge), entries {entry id: Vector2},
## default_entry, exits [{id, rect, target_scene, target_entry}], checkpoints [{id, position}],
## npcs [{id, visual, position, face_left (the way they face when the hero is far)}], objects [{id, kind, position, stand}] (interactables that are not people).
static func get_def(scene_id: StringName) -> Dictionary:
	if scene_id in LAYERED:
		return PropScene.scene_def(layered_data(scene_id), scene_id, Tuning.PLAYER_RADIUS)
	match scene_id:
		VILLAGE:
			var points: Dictionary = VillageLayout.STAND_POINTS
			var half: float = VillageLayout.EXIT_FOREST_HALF_WIDTH
			var edge: Vector2 = VillageLayout.EXIT_FOREST
			return {
				"id": VILLAGE, "name": "LANTERNFEN", "size": VillageLayout.VILLAGE_SIZE, "margin": Tuning.PLAYER_RADIUS,
				"entries": {&"arrival": VillageLayout.ARRIVAL_SPAWN, &"return": VillageLayout.RETURN_SPAWN},
				"default_entry": &"arrival",
				"exits": [{"id": &"to_forest", "rect": Rect2(edge.x - 2.0, edge.y - half, VillageLayout.VILLAGE_SIZE.x - edge.x + 2.0, half * 2.0), "target_scene": FOREST, "target_entry": &"village_side"}],
				"checkpoints": [{"id": &"village_gate", "position": VillageLayout.ARRIVAL_SPAWN}],
				"npcs": [
					{"id": &"mira", "visual": &"npc_mira", "position": points[&"mira"], "face_left": true},
					{"id": &"tovan", "visual": &"npc_tovan", "position": points[&"tovan"], "face_left": true},
					{"id": &"edda", "visual": &"npc_edda", "position": points[&"edda"], "face_left": true},
					{"id": &"elder", "visual": &"npc_elder", "position": points[&"villager_elder"], "face_left": true},
					{"id": &"child", "visual": &"npc_child", "position": points[&"villager_child"], "face_left": false},
					{"id": &"worker", "visual": &"npc_worker", "position": points[&"villager_worker"], "face_left": true},
				],
				"objects": [
					{"id": &"chest", "kind": &"chest", "position": points[&"chest"], "stand": points[&"chest"] + Vector2(0, 14)},
					{"id": &"edda_door", "kind": &"door", "position": VillageLayout.EDDA_DOOR, "stand": points[&"edda_door"]},
					{"id": &"training_dummy", "kind": &"dummy", "position": VillageLayout.TRAINING_DUMMY, "stand": VillageLayout.TRAINING_DUMMY + Vector2(0, 14)},
				],
			}
		FOREST:
			var objects: Array = []
			for row: Array in ForestLayout.INTERACTABLES:
				objects.append({"id": StringName(row[0]), "kind": StringName(row[1]), "position": Vector2(row[2], row[3]), "stand": Vector2(row[4], row[5])})
			var checkpoints: Array = []
			var names: Array[StringName] = [&"forest_entrance", &"forest_puzzle"]
			for i: int in ForestLayout.CHECKPOINTS.size():
				checkpoints.append({"id": names[i], "position": ForestLayout.CHECKPOINTS[i]})
			return {
				"id": FOREST, "name": "FOREST ROUTE", "size": ForestLayout.SIZE, "margin": Tuning.PLAYER_RADIUS,
				"entries": {&"village_side": ForestLayout.ENTRY_POINT, &"north": FOREST_NORTH_ENTRY},
				"default_entry": &"village_side",
				"exits": [
					{"id": &"to_village", "rect": ForestLayout.ENTRY_RECT, "target_scene": VILLAGE, "target_entry": &"return"},
					{"id": &"to_glade", "rect": ForestLayout.EXIT_RECT, "target_scene": GLADE, "target_entry": &"entrance"},
				],
				"checkpoints": checkpoints, "npcs": [], "objects": objects,
			}
		GLADE:
			var objects: Array = []
			for row: Array in GladeLayout.INTERACTABLES:
				objects.append({"id": StringName(row[0]), "kind": StringName(row[1]), "position": Vector2(row[2], row[3]), "stand": Vector2(row[4], row[5])})
			return {
				"id": GLADE, "name": "STAG GLADE", "size": GladeLayout.SIZE, "margin": Tuning.PLAYER_RADIUS,
				"entries": {&"entrance": GladeLayout.ENTRY_POINT},
				"default_entry": &"entrance",
				"exits": [
					{"id": &"to_forest", "rect": GladeLayout.ENTRY_RECT, "target_scene": FOREST, "target_entry": &"north"},
					{"id": &"to_arena", "rect": GladeLayout.EXIT_RECT, "target_scene": ARENA, "target_entry": &"start"},
				],
				"checkpoints": [{"id": &"glade_entrance", "position": GladeLayout.CHECKPOINTS[0]}],
				"npcs": [], "objects": objects,
			}
		ARENA:
			return {
				"id": ARENA, "name": "COLOSSUS RUINS", "size": Tuning.ARENA_SIZE, "margin": Tuning.ARENA_MARGIN,
				"entries": {&"start": Tuning.PLAYER_START},
				"default_entry": &"start",
				"exits": [],
				"checkpoints": [{"id": &"ruins_gate", "position": Tuning.PLAYER_START}],
				"npcs": [], "objects": [],
			}
	return {}


static func is_known(scene_id: StringName) -> bool:
	return scene_id in IDS or scene_id in LAYERED


## The scene file of a layered scene (data/scenes/<id>_props.json), empty for any other id.
static func layered_data(scene_id: StringName) -> Dictionary:
	if not LAYERED_PATHS.has(scene_id):
		return {}
	return PropScene.load_scene(LAYERED_PATHS[scene_id])


## The solid colliders of a scene: the layout's colliders (the forest with its root gate closed unless `gate_open`),
## plus a small circle on every NPC and on the village chest (drawn as sprites, not painted).
static func build_obstacles(scene_id: StringName, gate_open: bool = false) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	if scene_id in LAYERED:
		return PropScene.build(layered_data(scene_id), PropScene.load_defs())
	match scene_id:
		VILLAGE:
			list = VillageLayout.build()
			var def: Dictionary = get_def(VILLAGE)
			for npc: Dictionary in def["npcs"]:
				SceneBounds.add(list, npc["position"], NPC_RADIUS, npc["position"])
			var chest: Vector2 = VillageLayout.STAND_POINTS[&"chest"]
			SceneBounds.add(list, chest, CHEST_RADIUS, chest)
		FOREST:
			list = ForestLayout.build_with_gate(gate_open)
		GLADE:
			list = GladeLayout.build()
		ARENA:
			list = ArenaLayout.build()
	return list


## The checkpoint `checkpoint_id` of a scene as {id, position}, or {} when the scene has no such checkpoint.
static func checkpoint(scene_id: StringName, checkpoint_id: StringName) -> Dictionary:
	for c: Dictionary in get_def(scene_id).get("checkpoints", []):
		if c["id"] == checkpoint_id:
			return c
	return {}


## The scene whose checkpoint list contains `checkpoint_id`, or empty.
static func scene_of_checkpoint(checkpoint_id: StringName) -> StringName:
	for scene_id: StringName in IDS + LAYERED:
		if not checkpoint(scene_id, checkpoint_id).is_empty():
			return scene_id
	return &""
