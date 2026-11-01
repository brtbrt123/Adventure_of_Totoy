extends SceneTree
## The owner's SpriteFrames (presentation/animations/*.tres, presentation/common/anim_library.gd) are usable by the game: every
## animation has frames, every frame is a built sprite with an anchor, speeds and durations are positive, and the library's
## frame picking stays in range. It does not pin the timings: those are the owner's to change.
const AnimLib := preload("res://presentation/common/anim_library.gd")
var failures: int = 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("ANIM LIBRARY FAIL: ", label)
		failures += 1


func run() -> void:
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	var sets: int = 0
	var animations: int = 0
	for file: String in DirAccess.get_files_at(AnimLib.DIR):
		if not file.ends_with(".tres"):
			continue
		sets += 1
		var set_name: String = file.get_basename()
		var frames: SpriteFrames = load(AnimLib.DIR + file) as SpriteFrames
		check(frames != null, set_name + " loads as SpriteFrames")
		if frames == null:
			continue
		for anim: StringName in frames.get_animation_names():
			animations += 1
			var count: int = frames.get_frame_count(anim)
			check(count > 0, "%s/%s has frames" % [set_name, anim])
			check(frames.get_animation_speed(anim) > 0.0, "%s/%s speed above 0" % [set_name, anim])
			for i: int in count:
				var texture: Texture2D = frames.get_frame_texture(anim, i)
				var key: String = texture.resource_path.get_file().get_basename() if texture != null else ""
				check(atlas.has(key), "%s/%s frame %d is a built sprite (%s)" % [set_name, anim, i + 1, key])
				check(frames.get_frame_duration(anim, i) > 0.0, "%s/%s frame %d duration above 0" % [set_name, anim, i + 1])
			var length: int = AnimLib.length(set_name, String(anim), 0)
			for t: int in range(0, length * 2 + 5, 3):
				var n: int = AnimLib.at(set_name, String(anim), t, [count, 1, true])
				check(n >= 1 and n <= count, "%s/%s frame %d in range at tick %d" % [set_name, anim, n, t])
	check(sets >= 17, "every character set has a SpriteFrames (%d)" % sets)
	print("ANIM LIBRARY OK: %d sets, %d animations" % [sets, animations] if failures == 0 else "ANIM LIBRARY FAILED: %d" % failures)
	quit(1 if failures else 0)
