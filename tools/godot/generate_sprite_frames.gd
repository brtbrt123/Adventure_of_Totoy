extends SceneTree
## Writes presentation/animations/<set>.tres, a Godot SpriteFrames per character frame set, for the owner to edit in the editor
## (owner 2026-11-01: "make all of it editable"; the game reads them through presentation/common/anim_library.gd).
##
##   godot --headless --path . --script res://tools/godot/generate_sprite_frames.gd            # after build_art.py and an import
##   godot --headless --path . --script res://tools/godot/generate_sprite_frames.gd -- --reset # rebuild every set from the code tables
##
## Each animation's frames are the built PNGs (art/build/sprites/<set>_<anim>[_right]_<n>.png) in frame order. Speed, per-frame
## durations and looping start from the game's own tables (presentation/arena/animation.gd PLAYER and BOSS, mob_view.gd STATES and
## its pose overrides, the unarmed hero, the NPC manifest's per-frame idle and walk ticks), so the game looks the same until the
## owner changes them.
## An existing resource is the owner's: its animations, frame order, speeds, durations and loop flags are kept. This only adds the
## animations that are new in the art, drops frames whose PNG is gone, and saves only when something changed. --reset ignores them.

const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
const OUT: String = "res://presentation/animations/"
const SPRITES: String = "res://art/build/sprites/"
const DEFAULT_TICKS: int = 6
const NPC_MANIFEST: String = "res://art/build/chapter1_npc_sprites_manifest.json"
## The unarmed hero's table (presentation/explore/explore_scene.gd UNARMED_FRAMES).
const UNARMED: Dictionary = {"idle": [6, 12, true], "walk": [6, 5, true], "dash": [6, 1, false]}
## Poses mob_view.gd picks outside its STATES table: [ticks per frame, loop].
const MOB_EXTRA: Dictionary = {
	"stag": {"breathe": [6, true], "amble": [5, true], "chant": [3, false], "summon": [6, false], "charge_tell": [1, false], "charge_run": [3, true]},
	"mossling": {"hurt": [6, true]},
	"boar": {"charge_tell": [6, false]},
	"warden": {"lash_tell": [1, false], "lash_strike": [1, false], "ring_tell": [1, false], "ring_strike": [1, false], "guard_hit": [5, false],
		"exposed": [8, true]},
}


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var reset: bool = "--reset" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	var names: Array[String] = []
	for file: String in DirAccess.get_files_at(SPRITES):
		if file.ends_with(".png"):
			names.append(file.get_basename())
	var written: int = 0
	var kept: int = 0
	for set_name: String in sets():
		var anims: Dictionary = animations(set_name, names)
		if anims.is_empty():
			continue
		if write(set_name, anims, defaults(set_name), reset):
			written += 1
		else:
			kept += 1
	print("SPRITE FRAMES OK: %d written, %d unchanged in %s" % [written, kept, OUT])
	quit(0)


## Every character frame set (the legacy totoy and mossbound_colossus frames are not used by the game and are left out).
func sets() -> Array[String]:
	var out: Array[String] = [ArenaAnimation.SET_KATANA, ArenaAnimation.SET_DAGGER, ArenaAnimation.SET_LIGHTNING, ArenaAnimation.SET_SCYTHE,
		"totoy_unarmed", "golem2", "warden", "stag", "boar", "mossling", "glowmoth"]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NPC_MANIFEST))
	for npc: String in Dictionary(manifest.get("states", {})).keys():
		out.append("npc_" + npc)
	return out


## {animation: [frame names in order]} from the built PNG names `<set>_<anim>[_right]_<n>`.
func animations(set_name: String, names: Array[String]) -> Dictionary:
	var numbered: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("^" + set_name + "_(.+?)(_right)?_(\\d+)$")
	for name: String in names:
		var m: RegExMatch = pattern.search(name)
		if m == null:
			continue
		var anim: String = m.get_string(1)
		# a longer set (totoy_dagger inside totoy_...) or an NPC's other set never matches: the sets do not share prefixes
		if not numbered.has(anim):
			numbered[anim] = {}
		numbered[anim][int(m.get_string(3))] = name
	var out: Dictionary = {}
	for anim: String in numbered:
		var order: Array = numbered[anim].keys()
		order.sort()
		var keys: Array[String] = []
		for n: int in order:
			keys.append(numbered[anim][n])
		out[anim] = keys
	return out


## {animation: [per-frame ticks or a single ticks value, loop]} from the game's tables.
func defaults(set_name: String) -> Dictionary:
	var out: Dictionary = {}
	if set_name in [ArenaAnimation.SET_KATANA, ArenaAnimation.SET_DAGGER, ArenaAnimation.SET_LIGHTNING, ArenaAnimation.SET_SCYTHE]:
		for anim: String in ArenaAnimation.PLAYER:
			out[anim] = [int(ArenaAnimation.PLAYER[anim][1]), bool(ArenaAnimation.PLAYER[anim][2])]
		out["ward_hold"] = [DEFAULT_TICKS, true]
	elif set_name == "totoy_unarmed":
		for anim: String in UNARMED:
			out[anim] = [int(UNARMED[anim][1]), bool(UNARMED[anim][2])]
	elif set_name == "golem2":
		for anim: String in ArenaAnimation.BOSS:
			out[anim] = [int(ArenaAnimation.BOSS[anim][1]), bool(ArenaAnimation.BOSS[anim][2])]
	elif MobView.STATES.has(set_name):
		for state: String in MobView.STATES[set_name]:
			var pose: Array = MobView.STATES[set_name][state]
			if not out.has(pose[0]):
				out[pose[0]] = [int(pose[2]), bool(pose[3])]
		var extra: Dictionary = MOB_EXTRA.get(set_name, {})
		for anim: String in extra:
			if not out.has(anim):
				out[anim] = extra[anim]
	elif set_name.begins_with("npc_"):
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NPC_MANIFEST))
		var states: Dictionary = Dictionary(manifest["states"]).get(set_name.trim_prefix("npc_"), {})
		for anim: String in states:
			out[anim] = [Dictionary(states[anim]).get("ticks", [DEFAULT_TICKS]), true]
	return out


## Builds or updates the set's resource; true when the file was written.
func write(set_name: String, anims: Dictionary, timing: Dictionary, reset: bool) -> bool:
	var path: String = OUT + set_name + ".tres"
	var frames: SpriteFrames = null
	if not reset and ResourceLoader.exists(path):
		frames = load(path) as SpriteFrames
	var changed: bool = false
	if frames == null:
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		changed = true
	# frames whose PNG is gone are dropped (an owner's animation keeps everything else)
	for anim: StringName in frames.get_animation_names():
		for i: int in range(frames.get_frame_count(anim) - 1, -1, -1):
			var texture: Texture2D = frames.get_frame_texture(anim, i)
			if texture == null or not FileAccess.file_exists(texture.resource_path):
				frames.remove_frame(anim, i)
				changed = true
	var order: Array = anims.keys()
	order.sort()
	for anim: String in order:
		if frames.has_animation(anim):
			continue
		var spec: Array = timing.get(anim, [DEFAULT_TICKS, false])
		var ticks: Array = spec[0] if spec[0] is Array else [spec[0]]
		var base: int = int(ticks[0])  # the shortest frame is 1.0; longer frames get a longer duration (NPC idles)
		for t: Variant in ticks:
			base = mini(base, int(t))
		base = maxi(1, base)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 60.0 / base)
		frames.set_animation_loop(anim, bool(spec[1]))
		var keys: Array = anims[anim]
		for i: int in keys.size():
			var t: int = int(ticks[mini(i, ticks.size() - 1)])
			frames.add_frame(anim, load(SPRITES + String(keys[i]) + ".png"), float(t) / float(base))
		changed = true
	if changed:
		var err: Error = ResourceSaver.save(frames, path)
		if err != OK:
			push_error("cannot save %s: %d" % [path, err])
	return changed
