extends RefCounted
## The village sequence of Chapter 1 as data (data/quests/chapter1.json, docs/PROGRESSION_PLAN.md): an ordered chain of steps, one
## current at a time. Pure data and lookups (no state): ExploreCore reads the story flags to find the current step, pays a step's reward
## when its `done_flag` is set and sets the ability flags a step `unlocks` when it becomes current. Same idea as core/dialogue_book.gd.
##   step {id, requires [flags], done_flag, objective (HUD line, <= 60 chars), target (NPC or object id, may be empty),
##         unlocks? [flags], reward {exp?, items? [{reward_id, kind, item, name, quantity}], flags? [flags]}}
##   road {requires [flags], blocked_text}: the flags that open the village's east gate.
const PATH: String = "res://data/quests/chapter1.json"
const MAX_OBJECTIVE_LENGTH: int = 60
const MAX_BLOCKED_LENGTH: int = 90
## The abilities a quest can unlock and the flag of each (HUD locks and input filters read these).
const ABILITY_FLAGS: Dictionary = {
	&"attack": &"unlocked_attack", &"dash": &"unlocked_dash", &"parry": &"unlocked_parry", &"item_slot_1": &"unlocked_item_slot_1",
}
## Every flag counts as set for the abilities (debug jumps and tests): nothing is locked.
const DEBUG_FLAG: StringName = &"debug_all_unlocked"


static func default_book() -> Dictionary:
	return load_book(PATH)


static func load_book(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func steps(book: Dictionary) -> Array:
	return book.get("steps", [])


static func _flags_of(row: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for flag: Variant in row:
		out.append(StringName(str(flag)))
	return out


static func _all_set(required: Array[StringName], flags: Array[StringName]) -> bool:
	for flag: StringName in required:
		if not flags.has(flag):
			return false
	return true


## The current step: the first one whose `done_flag` is not set and whose `requires` all are ({} when the chain is finished or stuck).
static func current(book: Dictionary, flags: Array[StringName]) -> Dictionary:
	for step: Variant in steps(book):
		var row: Dictionary = step
		if flags.has(StringName(str(row["done_flag"]))):
			continue
		if _all_set(_flags_of(row.get("requires", [])), flags):
			return row
		return {}
	return {}


## The steps whose `done_flag` is `flag`.
static func steps_done_by(book: Dictionary, flag: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for step: Variant in steps(book):
		if StringName(str((step as Dictionary)["done_flag"])) == flag:
			out.append(step)
	return out


## The ability flags of every step that has begun (all its `requires` are set, whether it is done or not) that are not set yet: an
## ability stays unlocked once its step began.
static func missing_unlocks(book: Dictionary, flags: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for step: Variant in steps(book):
		var row: Dictionary = step
		if not _all_set(_flags_of(row.get("requires", [])), flags):
			continue
		for flag: StringName in _flags_of(row.get("unlocks", [])):
			if not flags.has(flag) and not out.has(flag):
				out.append(flag)
	return out


## Every step's done flag, in order.
static func done_flags(book: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for step: Variant in steps(book):
		out.append(StringName(str((step as Dictionary)["done_flag"])))
	return out


## True when the village's east gate is open for these flags.
static func road_open(book: Dictionary, flags: Array[StringName]) -> bool:
	return _all_set(_flags_of(book.get("road", {}).get("requires", [])), flags)


static func blocked_text(book: Dictionary) -> String:
	return str(book.get("road", {}).get("blocked_text", ""))


## Total EXP of every step (the plan's 95).
static func total_exp(book: Dictionary) -> int:
	var total: int = 0
	for step: Variant in steps(book):
		total += int((step as Dictionary).get("reward", {}).get("exp", 0))
	return total


## Problems in the data (empty when fine).
static func validate(book: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(book.get("version", 0)) != 1:
		errors.append("version must be 1")
	var list: Array = steps(book)
	if list.is_empty():
		errors.append("no steps")
		return errors
	var seen_ids: Dictionary = {}
	var done_before: Dictionary = {}
	for step: Variant in list:
		var row: Dictionary = step
		var id: String = str(row.get("id", ""))
		if id.is_empty() or seen_ids.has(id):
			errors.append("step id '%s' is empty or duplicated" % id)
		seen_ids[id] = true
		var done: String = str(row.get("done_flag", ""))
		if not _is_flag(done):
			errors.append("%s: done_flag '%s' is not a flag name" % [id, done])
		elif done_before.has(done):
			errors.append("%s: done_flag '%s' is used by an earlier step" % [id, done])
		for flag: Variant in row.get("requires", []):
			if not _is_flag(str(flag)):
				errors.append("%s: required flag '%s' is not a flag name" % [id, flag])
			elif not done_before.has(str(flag)):
				errors.append("%s: requires '%s' which no earlier step sets (the chain must be in order)" % [id, flag])
		for flag: Variant in row.get("unlocks", []):
			if not ABILITY_FLAGS.values().has(StringName(str(flag))):
				errors.append("%s: unlock '%s' is not an ability flag" % [id, flag])
		var objective: String = str(row.get("objective", ""))
		if objective.strip_edges().is_empty() or objective.length() > MAX_OBJECTIVE_LENGTH:
			errors.append("%s: the objective needs 1-%d characters" % [id, MAX_OBJECTIVE_LENGTH])
		var reward: Dictionary = row.get("reward", {})
		if int(reward.get("exp", 0)) < 0:
			errors.append("%s: negative exp" % id)
		for flag: Variant in reward.get("flags", []):
			if not _is_flag(str(flag)):
				errors.append("%s: reward flag '%s' is not a flag name" % [id, flag])
		for item: Variant in reward.get("items", []):
			var it: Dictionary = item
			for key: String in ["reward_id", "kind", "item", "name"]:
				if str(it.get(key, "")).is_empty():
					errors.append("%s: a reward item has no %s" % [id, key])
			if int(it.get("quantity", 1)) < 1:
				errors.append("%s: a reward item needs a quantity of at least 1" % id)
		done_before[done] = true
	var road: Dictionary = book.get("road", {})
	if road.is_empty():
		errors.append("no road")
	else:
		for flag: Variant in road.get("requires", []):
			if not done_before.has(str(flag)):
				errors.append("road: requires '%s' which no step sets" % flag)
		var text: String = str(road.get("blocked_text", ""))
		if text.strip_edges().is_empty() or text.length() > MAX_BLOCKED_LENGTH:
			errors.append("road: blocked_text needs 1-%d characters" % MAX_BLOCKED_LENGTH)
	return errors


static func _is_flag(text: String) -> bool:
	if text.is_empty() or text.length() > 40:
		return false
	for i: int in text.length():
		var c: String = text[i]
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true
