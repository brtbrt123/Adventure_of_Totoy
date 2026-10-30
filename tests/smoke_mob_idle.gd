extends SceneTree
const View := preload("res://presentation/explore/mob_view.gd")
const Snapshots := preload("res://core/snapshots.gd")
func _init() -> void:
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	var none: Array[Snapshots.TelegraphSnapshot] = []
	for type: String in ["mossling","boar"]:
		var count: int = 24 if type == "mossling" else 36
		var actor: Dictionary = {"type":StringName(type),"state":&"idle","state_ticks":0,"id":0}
		var seen: Dictionary = {}
		for tick: int in range(count*6):
			var key: String = View.frame(actor,none,tick)
			assert(frames.has(key),key)
			assert(Vector2(frames[key]["ax"],frames[key]["ay"]) == Vector2(32,40))
			seen[key] = true
		assert(seen.size() == count,"dormant idle must advance even when state_ticks stays zero")
		assert(View.frame(actor,none,0) == View.frame(actor,none,count*6),"loop wraps at authored duration")
		assert(View.frame(actor,none,9) == View.frame(actor,none,9),"paused clock holds pose")
		actor["id"] = 1
		assert(View.frame(actor,none,0) != View.frame({"type":StringName(type),"state":&"idle","state_ticks":0,"id":0},none,0),"individual idle phases")
		actor["state"] = &"alert"
		assert(not "play_idle" in View.frame(actor,none,100) and not "graze_idle" in View.frame(actor,none,100),"alert interrupts idle")
		for state: String in ["chase","windup","strike","recover","hurt","dead"]:
			actor["state"] = StringName(state)
			var key: String = View.frame(actor,none,100)
			assert(frames.has(key) and not "play_idle" in key and not "graze_idle" in key,"combat poses preserved")
	print("MOB IDLES OK: dormant loops, 60 frames, anchors, loop timing, phase offsets and combat interruption")
	quit()
