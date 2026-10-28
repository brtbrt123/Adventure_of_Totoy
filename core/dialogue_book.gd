extends RefCounted
## The dialogue data (data/dialogue/*.json): which conversation an NPC plays for the story flags set so far, and the
## conversations' lines. Pure data and lookups; no state (ExploreCore holds the running conversation and the flags).
##
## File: `npcs {npc id: [{when?: {flags: [...], not: [...]}, dialogue: id}]}` (the first entry whose `when` holds is played; no
## `when` always holds) and `dialogues {id: {speaker, portrait, set?: [flags], lines: [{text, speaker?, portrait?}]}}`.
## A dialogue sets its `set` flags when it ends, finished or skipped. It may also `grants` [{reward_id, kind (weapon or item), item,
## name, flag, quantity?}]: when it ends and the grant's `flag` is not yet set, ExploreCore sets it and emits `item_received`.

const PATH: String = "res://data/dialogue/chapter1.json"
## Guides for the writer and the dialogue box (docs/CHAPTER1_PLAN.md: about 60 lines in the chapter).
const MAX_LINES_TOTAL: int = 60
const MAX_TEXT_LENGTH: int = 110

static var _cached: Dictionary = {}


## The chapter's book (read once). {} when the file is missing or broken (an NPC then has no conversation).
static func default_book() -> Dictionary:
	if _cached.is_empty():
		_cached = load_book(PATH)
	return _cached


static func load_book(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueBook: cannot read " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("DialogueBook: not a JSON object: " + path)
		return {}
	return parsed as Dictionary


## The id of the dialogue `npc_id` plays with these flags; &"" when the NPC has none.
static func pick(book: Dictionary, npc_id: StringName, flags: Array[StringName]) -> StringName:
	var entries: Variant = book.get("npcs", {}).get(String(npc_id), [])
	if not (entries is Array):
		return &""
	for entry: Variant in entries:
		if entry is Dictionary and holds(entry.get("when", {}), flags):
			return StringName(String(entry.get("dialogue", "")))
	return &""


## True when every `flags` entry is set and no `not` entry is.
static func holds(when: Variant, flags: Array[StringName]) -> bool:
	if not (when is Dictionary):
		return true
	for flag: Variant in when.get("flags", []):
		if not flags.has(StringName(String(flag))):
			return false
	for flag: Variant in when.get("not", []):
		if flags.has(StringName(String(flag))):
			return false
	return true


## The dialogue `id` ({} when unknown).
static func dialogue(book: Dictionary, id: StringName) -> Dictionary:
	var found: Variant = book.get("dialogues", {}).get(String(id), {})
	return found as Dictionary if found is Dictionary else {}


## The line `index` of a dialogue as {text, speaker, portrait}, the dialogue's speaker and portrait filling what the line leaves out.
static func line(dialogue_def: Dictionary, index: int) -> Dictionary:
	var lines: Array = dialogue_def.get("lines", [])
	if index < 0 or index >= lines.size():
		return {}
	var row: Dictionary = lines[index]
	return {
		"text": String(row.get("text", "")),
		"speaker": String(row.get("speaker", dialogue_def.get("speaker", ""))),
		"portrait": String(row.get("portrait", dialogue_def.get("portrait", ""))),
	}


## The flags a dialogue sets when it ends.
static func flags_set_by(dialogue_def: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for flag: Variant in dialogue_def.get("set", []):
		out.append(StringName(String(flag)))
	return out


## The grants a dialogue makes when it ends (empty when none).
static func grants_of(dialogue_def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for grant: Variant in dialogue_def.get("grants", []):
		if grant is Dictionary:
			out.append(grant)
	return out


## Every problem in the book (empty when fine). `npc_ids` are the NPCs that must be able to talk (each needs an entry
## without `when`, so it always has something to say).
static func validate(book: Dictionary, npc_ids: Array[StringName]) -> Array[String]:
	var problems: Array[String] = []
	var dialogues: Dictionary = book.get("dialogues", {})
	var npcs: Dictionary = book.get("npcs", {})
	var total: int = 0
	for id: String in dialogues:
		var def: Dictionary = dialogues[id]
		for grant: Dictionary in grants_of(def):
			for key: String in ["reward_id", "kind", "item", "name", "flag"]:
				if String(grant.get(key, "")).strip_edges() == "":
					problems.append("dialogue %s has a grant without %s" % [id, key])
			if not ["weapon", "item", "aspect"].has(String(grant.get("kind", ""))):
				problems.append("dialogue %s grant kind must be weapon, item or aspect" % id)
			if int(grant.get("quantity", 1)) < 1:
				problems.append("dialogue %s grant quantity must be at least 1" % id)
		var lines: Array = def.get("lines", [])
		if lines.is_empty():
			problems.append("dialogue %s has no lines" % id)
		for i: int in lines.size():
			total += 1
			var row: Dictionary = lines[i]
			var text: String = String(row.get("text", ""))
			if text.strip_edges() == "":
				problems.append("dialogue %s line %d has no text" % [id, i + 1])
			if text.length() > MAX_TEXT_LENGTH:
				problems.append("dialogue %s line %d is %d characters (max %d)" % [id, i + 1, text.length(), MAX_TEXT_LENGTH])
			if String(row.get("speaker", def.get("speaker", ""))) == "":
				problems.append("dialogue %s line %d has no speaker" % [id, i + 1])
	if total > MAX_LINES_TOTAL:
		problems.append("%d lines in total (budget %d)" % [total, MAX_LINES_TOTAL])
	for npc: String in npcs:
		var entries: Array = npcs[npc]
		var has_fallback: bool = false
		for entry: Dictionary in entries:
			if not dialogues.has(String(entry.get("dialogue", ""))):
				problems.append("npc %s plays unknown dialogue %s" % [npc, entry.get("dialogue", "")])
			if not entry.has("when"):
				has_fallback = true
		if not has_fallback:
			problems.append("npc %s has no fallback entry (one without `when`)" % npc)
	for npc_id: StringName in npc_ids:
		if not npcs.has(String(npc_id)):
			problems.append("npc %s has no conversation" % npc_id)
	return problems
