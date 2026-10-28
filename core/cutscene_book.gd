extends RefCounted
## The story cutscenes as data (data/cutscenes/<file>.json, today only the new-game intro): ordered beats of art, caption lines and timing.
## Pure data and checks; core never plays one. Presentation shows the beats (a panel with its caption, typewriter, a key for the next
## beat, a key to skip) and, when the cutscene ends or is skipped, sets the story flag the cutscene names so it plays once per
## new game. Same idea as core/dialogue_book.gd: the writer edits the JSON, `validate` rejects broken data.
##   {"version": 1, "cutscenes": {"<id>": {"flag", "skippable", "music", "beats": [{"id", "art", "effect", "hold" (ticks, 60 per second),
##     "sound" (cue id or empty), "lines": [1-3 caption lines]}]}}}
const PATH: String = "res://data/cutscenes/intro.json"
const MAX_BEATS: int = 12
const MAX_LINES_PER_BEAT: int = 3
const MAX_TEXT_LENGTH: int = 110  # a caption line, in characters (the same limit as a dialogue line)
const MAX_LINES_TOTAL: int = 24
const MIN_HOLD: int = 60
const MAX_HOLD: int = 900
## How a beat comes on screen (presentation draws them): the picture fades in, slowly zooms, pans down, or flashes in.
const EFFECTS: Array[String] = ["fade_in", "slow_zoom", "pan_down", "flash"]
## The cutscene the New Game button plays, and the story flag that records it as seen.
const INTRO: StringName = &"intro"


static func default_book() -> Dictionary:
	return load_book(PATH)


static func load_book(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The cutscene `id` ({} when unknown).
static func cutscene(book: Dictionary, id: StringName) -> Dictionary:
	var all: Dictionary = book.get("cutscenes", {})
	return all.get(String(id), {})


## The story flag a finished or skipped cutscene sets (empty for an unknown cutscene).
static func flag_of(book: Dictionary, id: StringName) -> StringName:
	return StringName(str(cutscene(book, id).get("flag", "")))


## True when the story flags already record the cutscene as seen.
static func is_seen(book: Dictionary, id: StringName, flags: Array[StringName]) -> bool:
	var flag: StringName = flag_of(book, id)
	return flag != &"" and flags.has(flag)


## The beats of a cutscene, in order ([] when unknown).
static func beats(book: Dictionary, id: StringName) -> Array:
	return cutscene(book, id).get("beats", [])


## Every caption line of a cutscene, in order.
static func all_lines(book: Dictionary, id: StringName) -> Array[String]:
	var out: Array[String] = []
	for beat: Variant in beats(book, id):
		for line: Variant in (beat as Dictionary).get("lines", []):
			out.append(str(line))
	return out


## Problems in the data (empty when fine).
static func validate(book: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(book.get("version", 0)) != 1:
		errors.append("version must be 1")
	var all: Variant = book.get("cutscenes", null)
	if not (all is Dictionary) or (all as Dictionary).is_empty():
		errors.append("no cutscenes")
		return errors
	if not (all as Dictionary).has(String(INTRO)):
		errors.append("the intro cutscene is missing")
	for id: Variant in all:
		var scene: Variant = all[id]
		if not (scene is Dictionary):
			errors.append("%s: not an object" % id)
			continue
		var flag: String = str((scene as Dictionary).get("flag", ""))
		if not _is_flag(flag):
			errors.append("%s: flag '%s' must be 1-40 characters of a-z, 0-9 and _" % [id, flag])
		var list: Array = (scene as Dictionary).get("beats", [])
		if list.is_empty() or list.size() > MAX_BEATS:
			errors.append("%s: needs 1-%d beats (has %d)" % [id, MAX_BEATS, list.size()])
		var seen: Dictionary = {}
		var total: int = 0
		for beat: Variant in list:
			if not (beat is Dictionary):
				errors.append("%s: a beat is not an object" % id)
				continue
			var b: Dictionary = beat
			var bid: String = str(b.get("id", ""))
			if bid.is_empty() or seen.has(bid):
				errors.append("%s: beat id '%s' is empty or duplicated" % [id, bid])
			seen[bid] = true
			if str(b.get("art", "")).is_empty():
				errors.append("%s/%s: no art id" % [id, bid])
			if not EFFECTS.has(str(b.get("effect", ""))):
				errors.append("%s/%s: effect '%s' is not one of %s" % [id, bid, b.get("effect", ""), EFFECTS])
			var hold: int = int(b.get("hold", 0))
			if hold < MIN_HOLD or hold > MAX_HOLD:
				errors.append("%s/%s: hold %d must be %d-%d ticks" % [id, bid, hold, MIN_HOLD, MAX_HOLD])
			var lines: Array = b.get("lines", [])
			if lines.is_empty() or lines.size() > MAX_LINES_PER_BEAT:
				errors.append("%s/%s: needs 1-%d lines" % [id, bid, MAX_LINES_PER_BEAT])
			for line: Variant in lines:
				total += 1
				var text: String = str(line)
				if text.strip_edges().is_empty():
					errors.append("%s/%s: an empty line" % [id, bid])
				elif text.length() > MAX_TEXT_LENGTH:
					errors.append("%s/%s: a line is %d characters (limit %d)" % [id, bid, text.length(), MAX_TEXT_LENGTH])
		if total > MAX_LINES_TOTAL:
			errors.append("%s: %d caption lines (limit %d)" % [id, total, MAX_LINES_TOTAL])
	return errors


static func _is_flag(text: String) -> bool:
	if text.is_empty() or text.length() > 40:
		return false
	for i: int in text.length():
		var c: String = text[i]
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true
