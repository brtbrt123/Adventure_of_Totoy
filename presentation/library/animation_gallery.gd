@tool
extends Node2D
## Every animation in the game, playing in the Godot editor (owner 2026-11-01: "make a scene for all"). Open
## presentation/library/animation_gallery.tscn: the 2D view shows each animated sequence of the built atlas (art/build/sprites.json:
## every `<name>_<n>` with two or more frames) looping, grouped by set (hero2, totoy, warden, stag, ..., then the effects fx_*), each
## cell labelled with its name and frame. Frames line up on their anchors (the feet), the way the game places them.
##
## Inspector:
## - filter: show only the names containing any of these words (comma separated), e.g. "hero2" or "stag, glowmoth" or "fx_warden2";
## - ticks_per_frame: one speed for all (the game times each animation in code: presentation/arena/animation.gd, mob_view.gd,
##   hero_fx.gd; the Warden's own gallery, warden_gallery.tscn, uses the Warden's real timings);
## - playing, speed, facing_left, include_stills (single frames too), row_width, show_labels.
## It reads the built atlas: after changing art, run build_art.py and press "reload" (or reopen the scene).

const TICKS_PER_SECOND: float = 60.0
const AnimLib := preload("res://presentation/common/anim_library.gd")
## The character sets with an editable SpriteFrames (presentation/animations/<set>.tres): their animations play in the owner's
## frame order and timing here, like in the game; every other animation at ticks_per_frame.
const EDITABLE_SETS: Array[String] = ["hero2", "totoy_dagger", "totoy_lightning", "totoy_scythe", "totoy_unarmed", "golem2", "warden", "stag",
	"boar", "mossling", "glowmoth", "npc_child", "npc_edda", "npc_elder", "npc_mira", "npc_tovan", "npc_worker"]
const LABEL_HEIGHT: float = 10.0
const PAD: float = 6.0

@export var filter: String = "":  ## words to match in the names, comma separated (empty: everything)
	set(value):
		filter = value
		_layout()
@export var playing: bool = true  ## untick to freeze every animation
@export_range(0.1, 2.0, 0.05) var speed: float = 1.0  ## 1 = game speed (60 ticks a second)
@export_range(1, 30) var ticks_per_frame: int = 6  ## how long each frame shows (one value for every animation)
@export var facing_left: bool = false  ## mirror everything (the game mirrors right-facing art when a character faces left)
@export var include_stills: bool = false:  ## also show names with a single frame (props, tiles of art, single poses)
	set(value):
		include_stills = value
		_layout()
@export var row_width: float = 1400.0:  ## where a row wraps, in pixels
	set(value):
		row_width = value
		_layout()
@export var show_labels: bool = true
@export var reload: bool = false:  ## tick after rebuilding the art: reloads the atlas
	set(value):
		reload = false
		_load()

var time: float = 0.0
var frames: Dictionary = {}
var atlas: Texture2D
var entries: Array[Dictionary] = []  # {name, keys, at (cell origin), size, feet (anchor point in the cell)}
var titles: Array[Dictionary] = []  # {text, at}


func _ready() -> void:
	_load()


func _load() -> void:
	AnimLib.clear_cache()  # the owner may have edited the SpriteFrames
	frames = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	atlas = load("res://art/build/sprites.png")
	_layout()


## The set an animation belongs to: its first word, or the first two for effects (fx_warden2, fx_stag, ...).
static func set_of(name: String) -> String:
	var words: PackedStringArray = name.split("_")
	return words[0] + "_" + words[1] if words[0] == "fx" and words.size() > 1 else words[0]


func _layout() -> void:
	entries.clear()
	titles.clear()
	if frames.is_empty():
		return
	var groups: Dictionary = {}
	var number: RegEx = RegEx.create_from_string("^(.*)_(\\d+)$")
	for key: String in frames:
		var m: RegExMatch = number.search(key)
		if m == null:
			continue
		var name: String = m.get_string(1)
		if not groups.has(name):
			groups[name] = {}
		groups[name][int(m.get_string(2))] = key
	var words: PackedStringArray = []
	for word: String in filter.split(","):
		if not word.strip_edges().is_empty():
			words.append(word.strip_edges().to_lower())
	var names: Array = groups.keys()
	names = names.filter(func(n: String) -> bool:
		if groups[n].size() < 2 and not include_stills:
			return false
		if words.is_empty():
			return true
		for w: String in words:
			if n.to_lower().contains(w):
				return true
		return false)
	# characters, mobs and props first, the effects after; alphabetical inside
	names.sort_custom(func(a: String, b: String) -> bool:
		var fa: bool = a.begins_with("fx_")
		var fb: bool = b.begins_with("fx_")
		return a < b if fa == fb else fb)
	var x: float = 0.0
	var y: float = 0.0
	var row_h: float = 0.0
	var current: String = ""
	for name: String in names:
		var numbers: Array = groups[name].keys()
		numbers.sort()
		var keys: Array[String] = []
		for n: int in numbers:
			keys.append(groups[name][n])
		# the cell holds every frame placed on its anchor: the widest reach left/right of the anchor and above/below it
		var left: float = 0.0
		var right: float = 0.0
		var up: float = 0.0
		var down: float = 0.0
		for key: String in keys:
			var f: Dictionary = frames[key]
			var ax: float = float(f.get("ax", float(f["w"]) * 0.5))
			var ay: float = float(f.get("ay", float(f["h"]) - 4.0))
			left = maxf(left, ax)
			right = maxf(right, float(f["w"]) - ax)
			up = maxf(up, ay)
			down = maxf(down, float(f["h"]) - ay)
		var reach: float = maxf(left, right)  # mirrored frames reach the other way
		var label: float = ThemeDB.fallback_font.get_string_size(name + "  00/00", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0  # the full name fits
		var size: Vector2 = Vector2(maxf(maxf(reach * 2.0, 90.0) + PAD * 2.0, label), up + down + LABEL_HEIGHT + PAD * 2.0)
		var section: String = set_of(name)
		if section != current:
			current = section
			if x > 0.0:
				y += row_h + PAD
			x = 0.0
			row_h = 0.0
			titles.append({"text": section, "at": Vector2(0, y)})
			y += 16.0
		if x > 0.0 and x + size.x > row_width:
			y += row_h + PAD
			x = 0.0
			row_h = 0.0
		var owner_set: String = ""
		var anim: String = ""
		for candidate: String in EDITABLE_SETS:
			if name.begins_with(candidate + "_") and AnimLib.has(candidate, name.trim_prefix(candidate + "_").trim_suffix("_right")):
				owner_set = candidate
				anim = name.trim_prefix(candidate + "_").trim_suffix("_right")
		entries.append({"name": name, "keys": keys, "at": Vector2(x, y), "size": size, "feet": Vector2(size.x * 0.5, LABEL_HEIGHT + PAD + up), "set": owner_set, "anim": anim})
		x += size.x + PAD
		row_h = maxf(row_h, size.y)
	queue_redraw()


func _process(delta: float) -> void:
	if playing:
		time += delta * speed
	queue_redraw()


func _draw() -> void:
	if atlas == null:
		_load()
		if atlas == null:
			return
	var font: Font = ThemeDB.fallback_font
	var tick: int = int(time * TICKS_PER_SECOND)
	for title: Dictionary in titles:
		if show_labels:
			draw_string(font, Vector2(title["at"]) + Vector2(0, 12), String(title["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 0.78, 0.27))
	for entry: Dictionary in entries:
		var at: Vector2 = entry["at"]
		var size: Vector2 = entry["size"]
		draw_rect(Rect2(at, size), Color(0.29, 0.24, 0.2))  # the forest floor's dirt, like the contact sheets
		draw_rect(Rect2(at, size), Color(0.11, 0.094, 0.141), false, 1.0)
		var keys: Array[String] = entry["keys"]
		var i: int = (tick / ticks_per_frame) % keys.size()
		var shown: String = keys[i]
		var total: int = keys.size()
		if not String(entry["set"]).is_empty():  # the owner's SpriteFrames: their order and timing, looped with a short pause
			var set_name: String = entry["set"]
			var anim: String = entry["anim"]
			total = AnimLib.count(set_name, anim, keys.size())
			i = AnimLib.at(set_name, anim, tick % (AnimLib.length(set_name, anim, total * ticks_per_frame) + 12), [total, ticks_per_frame, true]) - 1
			shown = AnimLib.key(set_name, anim, i + 1, keys[mini(i, keys.size() - 1)])
		if not frames.has(shown):
			continue
		var f: Dictionary = frames[shown]
		var dest: Rect2 = Rect2(at + Vector2(entry["feet"]), Vector2.ZERO)
		var ax: float = float(f.get("ax", float(f["w"]) * 0.5))
		var ay: float = float(f.get("ay", float(f["h"]) - 4.0))
		var w: float = float(f["w"])
		var h: float = float(f["h"])
		dest.position -= Vector2(w - ax if facing_left else ax, ay)
		dest.size = Vector2(-w if facing_left else w, h)
		draw_texture_rect_region(atlas, dest, Rect2(f["x"], f["y"], w, h))
		if show_labels:
			draw_string(font, at + Vector2(3, 9), "%s  %d/%d" % [entry["name"], i + 1, total], HORIZONTAL_ALIGNMENT_LEFT, size.x - 4.0, 8, Color(0.96, 0.93, 0.84))
