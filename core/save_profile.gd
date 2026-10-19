extends RefCounted
## The player's saved progress: a small, versioned profile. Pure data and (de)serialisation; no file access
## (see save_store.gd) and nothing that touches a running fight. Reading is forgiving: anything unreadable or
## from a newer version gives a fresh profile and says why in `load_note`.

const VERSION: int = 1
const RESULT_VICTORY: StringName = &"victory"
const RESULT_DEFEAT: StringName = &"defeat"

var runs_started: int = 0
var victories: int = 0
var defeats: int = 0
## Fastest victory in simulation ticks (60 per second); 0 = no victory yet.
var best_victory_ticks: int = 0
var last_result: StringName = &""
var weapon_id: StringName = &"black_katana"
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


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"runs_started": runs_started,
		"victories": victories,
		"defeats": defeats,
		"best_victory_ticks": best_victory_ticks,
		"last_result": String(last_result),
		"weapon_id": String(weapon_id),
	}


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
	profile.weapon_id = StringName(weapon) if weapon in ["black_katana"] else &"black_katana"
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
