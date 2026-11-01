extends RefCounted
## The character animations as Godot SpriteFrames the owner edits in the editor (owner 2026-11-01: "make all of it editable").
## One resource per frame set: presentation/animations/<set>.tres (hero2, totoy_dagger, warden, stag, npc_mira, ...), made by
## tools/godot/generate_sprite_frames.gd. Each animation lists its frames (the built PNGs, art/build/sprites/<frame>.png) in order,
## with a speed (frames per second) and a duration per frame, and loops or not.
##
## The game picks WHICH animation and when it starts from the core state, exactly as before; this library supplies, per animation:
## - the frames and their order (reorder, remove, repeat a frame in the editor and the game shows that);
## - how long each frame shows, for the animations that run freely (idle, walk, hurt, victory, NPC idles, mob idles and walks, ...).
## Animations locked to the combat timing (the hero's swings, dash and ward poses, attack wind-ups and strikes timed by the core's
## telegraphs) take their frames and order from here but their pace from the core.
## A set without a resource, or an animation missing from it, falls back to the code's own tables (nothing breaks).
## Pure lookup; the game state never depends on it.

const DIR: String = "res://presentation/animations/"
const TICKS_PER_SECOND: float = 60.0

## set -> {animation: {"keys": Array[String], "ticks": Array[int], "loop": bool}}; {} for a set with no resource.
static var _sets: Dictionary = {}


## Forgets the loaded resources (the galleries reload after the owner edits them).
static func clear_cache() -> void:
	_sets.clear()


static func _animations_of(set_name: String) -> Dictionary:
	if _sets.has(set_name):
		return _sets[set_name]
	var data: Dictionary = {}
	var path: String = DIR + set_name + ".tres"
	if ResourceLoader.exists(path):
		var frames: SpriteFrames = load(path) as SpriteFrames
		if frames != null:
			for anim: StringName in frames.get_animation_names():
				var keys: Array[String] = []
				var ticks: Array[int] = []
				var fps: float = maxf(0.001, frames.get_animation_speed(anim))
				for i: int in frames.get_frame_count(anim):
					var texture: Texture2D = frames.get_frame_texture(anim, i)
					if texture == null or texture.resource_path.is_empty():
						continue
					keys.append(texture.resource_path.get_file().get_basename())
					ticks.append(maxi(1, roundi(TICKS_PER_SECOND / fps * frames.get_frame_duration(anim, i))))
				if not keys.is_empty():
					data[String(anim)] = {"keys": keys, "ticks": ticks, "loop": frames.get_animation_loop(anim)}
	_sets[set_name] = data
	return data


## True when the set's resource has this animation.
static func has(set_name: String, anim: String) -> bool:
	return _animations_of(set_name).has(anim)


## How many frames the animation has (`fallback` without a resource).
static func count(set_name: String, anim: String, fallback: int) -> int:
	var entry: Dictionary = _animations_of(set_name).get(anim, {})
	return (entry["keys"] as Array).size() if not entry.is_empty() else fallback


## The frame name of frame `n` (1-based, held at the last frame) of the animation; `fallback` without a resource.
static func key(set_name: String, anim: String, n: int, fallback: String) -> String:
	var entry: Dictionary = _animations_of(set_name).get(anim, {})
	if entry.is_empty():
		return fallback
	var keys: Array = entry["keys"]
	return keys[clampi(n, 1, keys.size()) - 1]


## The animation's whole length in ticks (`fallback` without a resource); the galleries loop every animation over it.
static func length(set_name: String, anim: String, fallback: int) -> int:
	var entry: Dictionary = _animations_of(set_name).get(anim, {})
	if entry.is_empty():
		return fallback
	var total: int = 0
	for d: int in entry["ticks"]:
		total += d
	return total


## The 1-based frame shown `ticks` into a freely running animation: its frames' own durations, looping or holding the last frame.
## `spec` is the code's [frame count, ticks per frame, loop] used when the set has no resource.
static func at(set_name: String, anim: String, ticks: int, spec: Array) -> int:
	var entry: Dictionary = _animations_of(set_name).get(anim, {})
	var t: int = maxi(0, ticks)
	if entry.is_empty():
		var count_: int = int(spec[0])
		var elapsed: int = t / maxi(1, int(spec[1]))
		return (elapsed % count_ if bool(spec[2]) else mini(count_ - 1, elapsed)) + 1
	var durations: Array = entry["ticks"]
	var total: int = 0
	for d: int in durations:
		total += d
	if bool(entry["loop"]):
		t = posmod(t, maxi(1, total))
	elif t >= total:
		return durations.size()
	for i: int in durations.size():
		if t < int(durations[i]):
			return i + 1
		t -= int(durations[i])
	return durations.size()
