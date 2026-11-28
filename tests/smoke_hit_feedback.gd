extends SceneTree
## Hit feedback through the real scene (docs/PLAN_hit_feedback.md, the owner's "Yes, wire them", 2026-11-28): a real fight in the
## forest with real inputs (Totoy walks to the nearest mob and swings; he is kept alive). Every hit pops its own number in
## hit_numbers.gd, a killing blow pops as a kill, the "xN HITS" counter counts, the bar over a hurt mob shows its drain chunk
## (MobView.ghosts above its health), and the old small mob numbers stay off. No save is read or written (no persist meta). Prints
## FAIL and exits 1 on failure.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
var failures: int = 0
var scene: Explore


func _init() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		printerr("HIT FEEDBACK FAIL: ", label)
		failures += 1


func nearest() -> Dictionary:
	var best: Dictionary = {}
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["state"] == &"dead":
			continue
		if best.is_empty() or Vector2(mob["position"]).distance_to(scene.core.player.position) < Vector2(best["position"]).distance_to(scene.core.player.position):
			best = mob
	return best


func run() -> void:
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"forest_layered"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.fade_phase = &""
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	var first: Dictionary = {}
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["type"] == &"mossling" and first.is_empty():
			first = mob
	check(not first.is_empty(), "the forest has its Mosslings")
	if first.is_empty():
		quit(1)
		return
	scene.core.player.position = Vector2(first["position"]) + Vector2(-60, 30)
	var most_numbers: int = 0
	var most_combo: int = 0
	var kill_number: bool = false
	var drained: bool = false
	var old_mob_numbers: bool = false
	var kills: int = 0
	for i: int in 420:
		var frame: InputFrame = InputFrame.new()
		var mob: Dictionary = nearest()
		if not mob.is_empty():
			var to: Vector2 = Vector2(mob["position"]) - scene.core.player.position
			frame.aim = to.normalized()
			if to.length() > 24.0:
				frame.move = to.normalized()
			elif i % 9 == 0:
				frame.attack_pressed = true
		scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(frame)
		scene.fade_phase = &""
		for event: GameEvent in scene.core.last_events:
			if event.type == GameEvent.MOB_DEFEATED:
				kills += 1
		most_numbers = maxi(most_numbers, scene.hit_numbers.numbers.size())
		most_combo = maxi(most_combo, scene.hit_numbers.combo)
		kill_number = kill_number or scene.hit_numbers.numbers.any(func(n: Dictionary) -> bool: return n["style"] == &"kill")
		for m: Dictionary in scene.snapshot.mobs:
			drained = drained or float(MobView.ghosts.get(int(m["id"]), m["hp"])) > float(m["hp"])
		old_mob_numbers = old_mob_numbers or scene.encounter_effects.numbers.any(func(e: Dictionary) -> bool: return e["style"] in ["mob", "counter"])
		if i % 30 == 0:
			scene.queue_redraw()
			await process_frame
	check(kills >= 2, "Totoy felled mobs: %d" % kills)
	check(most_numbers >= 2, "hits pop their own numbers: at most %d at once" % most_numbers)
	check(kill_number, "a killing blow pops as a kill")
	check(most_combo >= 3, "the hit counter counts: x%d" % most_combo)
	check(drained, "a hurt mob's bar shows the drain chunk")
	check(not old_mob_numbers, "the old small mob numbers stay off")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("HIT FEEDBACK OK")
	quit(1 if failures else 0)
