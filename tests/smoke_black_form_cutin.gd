extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_black_form_cutin.gd
## The Black Form cut-in: art and data are present, it starts on the buff event, freezes the world for its
## whole length (no core steps), resumes afterwards, draws at every moment, and never starts twice for one event.
const Arena := preload("res://presentation/arena/arena.gd")
const CutIn := preload("res://presentation/arena/black_form_cutin.gd")
const GameEvent := preload("res://core/game_event.gd")
const Tuning := preload("res://core/tuning.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	_art_and_timeline()
	await _in_the_arena()
	if failures.is_empty():
		print("BLACK FORM CUTIN SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("CUTIN FAIL: " + message)
		print("BLACK FORM CUTIN SMOKE FAILED")
		quit(1)


func _art_and_timeline() -> void:
	for file: String in ["black_form_aura.png", "black_form_cutin.json", "black_form_pose_crouch.png", "black_form_pose_ready.png", "black_form_pose_burst.png", "black_form_pose_crouch_sil.png", "black_form_pose_ready_sil.png", "black_form_pose_burst_sil.png"]:
		_expect(ResourceLoader.exists("res://presentation/cutin/" + file) or FileAccess.file_exists("res://presentation/cutin/" + file), "missing cut-in art: " + file)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CutIn.DATA_PATH)) as Dictionary
	_expect(data["poses"].size() == 3 and data["aura"]["frames"].size() == 12, "cut-in data lists 3 poses and 12 aura frames")
	_expect(CutIn.DURATION > 1.2 and CutIn.DURATION < 2.4, "the world freeze is a short, bearable length: %.2f s" % CutIn.DURATION)
	# the banner is off-screen at the start and the end, on-screen in the middle, and the beats cover the whole stay
	_expect(CutIn.banner_offset(0.0) < -700.0 and CutIn.banner_offset(CutIn.END_TIME) < -700.0, "the banner starts and ends off-screen")
	_expect(CutIn.banner_offset(1.5) > -5.0 and CutIn.banner_offset(1.5) < 5.0, "the banner rests on screen: %f" % CutIn.banner_offset(1.5))
	for t: float in [0.35, 0.8, 1.0, 1.3, 2.0]:
		_expect(not CutIn.beat_at(t).is_empty(), "a pose beat shows at %.2f s" % t)
	_expect(CutIn.beat_at(0.1).is_empty(), "no pose before the banner has arrived")
	var names: Array[String] = []
	for beat: Array in CutIn.BEATS:
		names.append(str(beat[0]))
	_expect(names == ["crouch", "ready", "burst"], "the beat order is crouch, ready, burst")


func _result_event() -> GameEvent:
	return GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, 7, {"entity_id": 1, "weapon_id": &"black_katana", "duration": 600, "attack_speed_mult": 1.5, "damage_mult": 1.4})


func _in_the_arena() -> void:
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	_expect(arena.cutin != null and arena.cutin.available, "the cut-in loaded its art")
	arena.core.boss.cooldown = 100000
	arena._on_event(_result_event())
	_expect(arena.cutin.active, "the buff event starts the cut-in")
	arena._on_event(_result_event())
	_expect(arena.cutin.clock == 0.0, "the same event does not restart it")
	# the world is frozen: physics frames do not step the core
	var tick_before: int = arena.core.tick
	var frames: int = 0
	while arena.cutin.active and frames < 400:
		await physics_frame
		frames += 1
		# draw at every moment of the cut-in
		await process_frame
	var seconds: float = frames / 60.0
	_expect(not arena.cutin.active, "the cut-in ends by itself")
	_expect(absf(seconds - CutIn.DURATION) < 0.15, "it lasts about %.2f s (took %.2f s)" % [CutIn.DURATION, seconds])
	_expect(arena.core.tick == tick_before, "no core step ran during the cut-in (tick %d -> %d)" % [tick_before, arena.core.tick])
	# afterwards the world runs again
	for i: int in 5:
		await physics_frame
	_expect(arena.core.tick > tick_before, "the core steps again after the cut-in")
	# restart cancels it
	arena._on_event(GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, 99, {"entity_id": 1, "weapon_id": &"black_katana", "duration": 600, "attack_speed_mult": 1.5, "damage_mult": 1.4}))
	_expect(arena.cutin.active, "a later buff starts it again")
	arena._restart()
	_expect(not arena.cutin.active, "a restart cancels it")
	# a missing-art cut-in is skipped quietly
	var broken: CutIn = CutIn.new()
	broken.start()
	_expect(not broken.active, "without art, start() does nothing")
	broken.free()
	arena.queue_free()
	await process_frame
