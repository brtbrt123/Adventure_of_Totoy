extends RefCounted
## The chapter 1 scene graph (static data only): the explorable scenes, their sizes, entries (spawn points), exits
## (trigger rectangles leading to another scene's entry), checkpoints, NPCs and interactables, and the solid colliders.
## core/explore_core.gd runs a scene from this table; presentation draws it.
##
## The chapter's maps are LAYERED scenes (one floor painting + separate prop sprites, data/scenes/<id>_props.json read through
## core/prop_scene.gd, docs/LAYERED_SCENE_PILOT.md) and the Colossus arena. The painted village, forest and glade were retired on
## 2026-10-28; SaveProfile.from_dict still moves a save from them to the layered twin (`migrate_legacy`).
##
##   village_layered   east exit                          -> woodland_layered "west"
##   woodland_layered  west exit                          -> village_layered  "return"
##   woodland_layered  east exit                          -> forest_layered   "village_side"
##   forest_layered    west exit                          -> woodland_layered "east"
##   forest_layered    north exit behind the root gate    -> root_hollow_layered "forest_side"   (gate closed = solid)
##   root_hollow_layered west exit                        -> forest_layered   "north"
##   root_hollow_layered east exit                        -> glade_layered    "entrance"
##   root_hollow_layered north shortcut (once the hollow is cleared) -> hollow_trial_layered "south"
##   hollow_trial_layered bottom exit (shut while a trial wave lives) -> root_hollow_layered "shortcut"   (a dead end: the trial room)
##   glade_layered     bottom-left entrance               -> root_hollow_layered "glade_side"
##   glade_layered     root arch                          -> arena            "start"      (the Colossus fight)
##   arena             no exits (the fight's victory screen returns to the title)
##
## The forest's root gate is solid until the lantern puzzle opens it; `gate_open` (a scene state flag, saved in
## SaveProfile.gate_open, toggled by the debug key F6 or G) builds the forest with the gate open.
const Tuning := preload("res://core/tuning.gd")
const Obstacle := preload("res://core/obstacle.gd")
const SceneBounds := preload("res://core/scene_bounds.gd")
const ArenaLayout := preload("res://core/arena_layout.gd")
const PropScene := preload("res://core/prop_scene.gd")

const ARENA: StringName = &"arena"
## The scenes that are not layered (the Colossus arena).
const IDS: Array[StringName] = [ARENA]
## The layered scenes (floor + prop sprites, built from data/scenes/<id>_props.json).
const GLADE_LAYERED: StringName = &"glade_layered"
const VILLAGE_LAYERED: StringName = &"village_layered"
const FOREST_LAYERED: StringName = &"forest_layered"
const WOODLAND_LAYERED: StringName = &"woodland_layered"
const ROOT_HOLLOW_LAYERED: StringName = &"root_hollow_layered"
const HOLLOW_TRIAL_LAYERED: StringName = &"hollow_trial_layered"
const LAYERED: Array[StringName] = [VILLAGE_LAYERED, WOODLAND_LAYERED, FOREST_LAYERED, ROOT_HOLLOW_LAYERED, HOLLOW_TRIAL_LAYERED, GLADE_LAYERED]
## Every scene the game knows, in route order (the layered chapter, then the arena).
const ALL: Array[StringName] = [VILLAGE_LAYERED, WOODLAND_LAYERED, FOREST_LAYERED, ROOT_HOLLOW_LAYERED, HOLLOW_TRIAL_LAYERED, GLADE_LAYERED, ARENA]
const LAYERED_PATHS: Dictionary = {
	GLADE_LAYERED: "res://data/scenes/glade_layered_props.json",
	VILLAGE_LAYERED: "res://data/scenes/village_layered_props.json",
	FOREST_LAYERED: "res://data/scenes/forest_layered_props.json",
	WOODLAND_LAYERED: "res://data/scenes/woodland_layered_props.json",
	ROOT_HOLLOW_LAYERED: "res://data/scenes/root_hollow_layered_props.json",
	HOLLOW_TRIAL_LAYERED: "res://data/scenes/hollow_trial_layered_props.json",
}

## Where a new game starts.
const START_SCENE: StringName = VILLAGE_LAYERED
const START_ENTRY: StringName = &"arrival"

## Body radius of an NPC as a solid circle (people stand still; the hero walks round them).
const NPC_RADIUS: float = 5.0

## The whole definition of one scene (a fresh Dictionary each call):
## id, name (display), size, margin (bodies stay this far inside the world edge), entries {entry id: Vector2},
## default_entry, exits [{id, rect, target_scene, target_entry}], checkpoints [{id, position}],
## npcs [{id, visual, position, face_left (the way they face when the hero is far)}], objects [{id, kind, position, stand}] (interactables that are not people).
static func get_def(scene_id: StringName) -> Dictionary:
	if scene_id in LAYERED:
		return PropScene.scene_def(layered_data(scene_id), scene_id, Tuning.PLAYER_RADIUS)
	match scene_id:
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


## The layered twin of each painted scene, and of each painted checkpoint (ids of saves written before the migration).
const LEGACY_SCENES: Dictionary = {&"village": VILLAGE_LAYERED, &"forest": FOREST_LAYERED, &"glade": GLADE_LAYERED}
const LEGACY_CHECKPOINTS: Dictionary = {
	&"village_gate": &"village_layered_gate",
	&"forest_entrance": &"forest_layered_entrance",
	&"forest_puzzle": &"forest_layered_puzzle",
	&"glade_entrance": &"glade_layered_entrance",
}


## A saved scene and checkpoint moved to the layered maps: a painted scene becomes its layered twin and a painted
## checkpoint its layered one (never the painted coordinates); any other id (layered, arena, unknown) is returned unchanged.
## A painted checkpoint that does not belong to the saved scene is dropped (the scene's default entry is used).
static func migrate_legacy(scene_id: StringName, checkpoint_id: StringName) -> Dictionary:
	if not LEGACY_SCENES.has(scene_id):
		return {"scene": scene_id, "checkpoint": checkpoint_id}
	var twin: StringName = LEGACY_SCENES[scene_id]
	var moved: StringName = LEGACY_CHECKPOINTS.get(checkpoint_id, &"")
	if moved == &"" or checkpoint(twin, moved).is_empty():
		moved = &""
	return {"scene": twin, "checkpoint": moved}


static func is_known(scene_id: StringName) -> bool:
	return scene_id in ALL


## The scene file of a layered scene (data/scenes/<id>_props.json), empty for any other id.
static func layered_data(scene_id: StringName) -> Dictionary:
	if not LAYERED_PATHS.has(scene_id):
		return {}
	return PropScene.load_scene(LAYERED_PATHS[scene_id])


## The solid colliders of a scene: a layered scene builds the types its stateful props show for `gate_open`, the `lit`
## switch ids, the story `flags` and the `trial` tags (core/trial.gd: "sealed"), plus a small circle on every NPC (drawn as sprites); the arena its layout's.
static func build_obstacles(scene_id: StringName, gate_open: bool = false, lit: Array = [], flags: Array = [], trial: Array = []) -> Array[Obstacle]:
	var list: Array[Obstacle] = []
	if scene_id in LAYERED:
		list = PropScene.build(layered_data(scene_id), PropScene.load_defs(), {"gate_open": gate_open, "lit": lit, "flags": flags, "trial": trial})
		for npc: Dictionary in get_def(scene_id)["npcs"]:
			SceneBounds.add(list, npc["position"], NPC_RADIUS, npc["position"])
		return list
	match scene_id:
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
	for scene_id: StringName in ALL:
		if not checkpoint(scene_id, checkpoint_id).is_empty():
			return scene_id
	return &""
