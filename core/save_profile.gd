extends RefCounted
## The player's saved progress: a small, versioned profile. Pure data and (de)serialisation; no file access
## (see save_store.gd) and nothing that touches a running fight. Reading is forgiving: anything unreadable or
## from a newer version gives a fresh profile and says why in `load_note`.

const VERSION: int = 1  # equipped_aspects (2026-10-21) and scene_id / checkpoint_id / gate_open (2026-10-22) are optional fields: older version-1 saves load with the defaults
const Aspects := preload("res://core/aspects.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const MAX_FLAGS: int = 64
const MAX_ITEMS: int = 16
const MAX_STACK: int = 99
const RESULT_VICTORY: StringName = &"victory"
const RESULT_DEFEAT: StringName = &"defeat"

var runs_started: int = 0
var victories: int = 0
var defeats: int = 0
## Fastest victory in simulation ticks (60 per second); 0 = no victory yet.
var best_victory_ticks: int = 0
var last_result: StringName = &""
var weapon_id: StringName = &"black_katana"
## The aspects in skill slots 1-3 (three different Aspects.ALL ids). GameCore.apply_profile() starts a fight with them.
var equipped_aspects: Array[StringName] = Aspects.DEFAULT_EQUIPPED.duplicate()
## Chapter progress (exploration, 2026-10-22): the scene the player was last in (empty = no game started, CONTINUE
## has nothing to resume), the last checkpoint reached there (a SceneDefs checkpoint id of that scene, or empty) and
## whether the forest's root gate is open.
var scene_id: StringName = &""
var checkpoint_id: StringName = &""
var gate_open: bool = false
## The story flags set by conversations (ExploreCore.story_flags), e.g. met_mira. Optional in the file: older saves have none.
var story_flags: Array[StringName] = []
## What the hero carries ({item id: count}, e.g. herb from an encounter). Optional in the file: older saves carry nothing.
var inventory: Dictionary = {}
## Why this profile is a fresh one instead of a loaded one ("" when it was loaded or never saved before).
var load_note: String = ""


func record_run_started() -> void:
	runs_started += 1


## `ticks` is how long the fight lasted. Returns true when it is a new best victory time.
func record_result(result: StringName, ticks: int) -> bool:
	last_result = result
	if result == RESULT_VICTORY:
		victories += 1
		if best_victory_ticks == 0 or ticks < best_victory_ticks:
			best_victory_ticks = maxi(1, ticks)
			return true
	elif result == RESULT_DEFEAT:
		defeats += 1
	return false


## Records where the player is: the scene and its last checkpoint (empty = none reached there yet).
func record_scene(scene: StringName, checkpoint: StringName = &"") -> void:
	var moved: Dictionary = SceneDefs.migrate_legacy(scene, checkpoint)  # a painted scene or checkpoint becomes its layered twin
	scene = moved["scene"]
	checkpoint = moved["checkpoint"]
	scene_id = scene if SceneDefs.is_known(scene) else &""
	checkpoint_id = checkpoint if scene_id != &"" and not SceneDefs.checkpoint(scene_id, checkpoint).is_empty() else &""


## True when there is a chapter game to CONTINUE.
func has_progress() -> bool:
	return scene_id != &""


## A new game: the chapter progress is cleared (the record and the loadout stay).
func reset_progress() -> void:
	scene_id = &""
	checkpoint_id = &""
	gate_open = false
	story_flags.clear()
	inventory.clear()


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"runs_started": runs_started,
		"victories": victories,
		"defeats": defeats,
		"best_victory_ticks": best_victory_ticks,
		"last_result": String(last_result),
		"weapon_id": String(weapon_id),
		"equipped_aspects": equipped_aspects.map(func(aspect: StringName) -> String: return String(aspect)),
		"scene_id": String(scene_id),
		"checkpoint_id": String(checkpoint_id),
		"gate_open": gate_open,
		"story_flags": story_flags.map(func(flag: StringName) -> String: return String(flag)),
		"inventory": _inventory_dict(),
	}


func _inventory_dict() -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = inventory.keys()
	keys.sort()  # a stable file
	for key: Variant in keys:
		out[String(key)] = int(inventory[key])
	return out


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t", true)


static func from_dict(data: Dictionary) -> Object:
	var profile: Object = load("res://core/save_profile.gd").new()
	var version: Variant = data.get("version", null)
	if not (version is int or version is float) or int(version) < 1:
		profile.load_note = "missing or invalid version"
		return profile
	if int(version) > VERSION:
		profile.load_note = "saved by a newer version (%d)" % int(version)
		return profile
	profile.runs_started = _count(data.get("runs_started", 0))
	profile.victories = _count(data.get("victories", 0))
	profile.defeats = _count(data.get("defeats", 0))
	profile.best_victory_ticks = _count(data.get("best_victory_ticks", 0))
	var result: String = String(data.get("last_result", "")) if data.get("last_result", "") is String else ""
	profile.last_result = StringName(result) if result in ["victory", "defeat"] else &""
	var weapon: String = String(data.get("weapon_id", "black_katana")) if data.get("weapon_id", "") is String else ""
	profile.weapon_id = StringName(weapon) if weapon in ["black_katana", "dual_dagger", "chain_scythe"] else &"black_katana"
	var aspects: Variant = data.get("equipped_aspects", null)
	if aspects is Array and Aspects.is_valid_loadout(aspects):
		profile.equipped_aspects.clear()
		for value: Variant in aspects:
			profile.equipped_aspects.append(StringName(value))
	var scene: Variant = data.get("scene_id", "")
	var checkpoint: Variant = data.get("checkpoint_id", "")
	profile.record_scene(StringName(scene) if scene is String else &"", StringName(checkpoint) if checkpoint is String else &"")  # a save from the painted maps resumes on the layered ones (record_scene migrates)
	var gate: Variant = data.get("gate_open", false)
	profile.gate_open = gate if gate is bool else false
	var flags: Variant = data.get("story_flags", [])
	if flags is Array:
		for flag: Variant in flags:
			if flag is String and _is_flag(flag) and profile.story_flags.size() < MAX_FLAGS and not profile.story_flags.has(StringName(flag)):
				profile.story_flags.append(StringName(flag))
	var items: Variant = data.get("inventory", {})
	if items is Dictionary:
		for key: Variant in items:
			var count: Variant = items[key]
			if key is String and _is_flag(key) and (count is int or count is float) and profile.inventory.size() < MAX_ITEMS and int(count) > 0:
				profile.inventory[StringName(key)] = mini(int(count), MAX_STACK)
	return profile


static func from_json(text: String) -> Object:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		var fresh: Object = load("res://core/save_profile.gd").new()
		fresh.load_note = "not valid JSON"
		return fresh
	return from_dict(parsed as Dictionary)


## A non-negative whole number, else 0 (negative, fractional-garbage, strings and nulls all become 0).
static func _count(value: Variant) -> int:
	if value is int:
		return maxi(0, value)
	if value is float and is_finite(value):
		return maxi(0, int(value))
	return 0


## A story flag name: 1-40 characters of a-z, 0-9 and _.
static func _is_flag(text: String) -> bool:
	if text.is_empty() or text.length() > 40:
		return false
	for i: int in text.length():
		var c: String = text[i]
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true
