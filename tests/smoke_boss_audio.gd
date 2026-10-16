extends SceneTree
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
var failures: Array[String] = []
func _init() -> void:
	call_deferred("_run")
func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func _run() -> void:
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.combat_audio.set_process(false)
	_expect(arena.combat_audio.music_active, "fight music did not start")
	for cancelled: bool in [false, true]:
		arena._restart()
		arena.core.boss.next_attack_override = &"gold_slam"
		arena.core.boss.cooldown = 1
		var hit_tick: int = -1
		for i: int in range(100):
			arena.core.step(InputFrame.new())
			arena.snapshot = arena.core.snapshot()
			arena.prepare_visuals()
			if not arena.snapshot.telegraphs.is_empty():
				hit_tick = arena.snapshot.telegraphs[0].hit_tick
				break
		_expect(hit_tick > arena.snapshot.tick, "no future slam")
		# Move outside the locked attack; strike audio must not depend on damage.
		arena.core.player.position = Vector2(10, 10)
		if cancelled:
			arena.core.boss.add_posture(999, arena.core.tick, arena.core.last_events)
		while arena.core.tick <= hit_tick + 1:
			arena.core.step(InputFrame.new())
			arena.snapshot = arena.core.snapshot()
			arena.prepare_visuals()
			arena.prepare_visuals()
		_expect(int(arena.combat_audio.played.get("golem_slam", 0)) == (0 if cancelled else 1), "cancel/miss/duplicate strike routing")
	arena.combat_audio.music.volume_db = -18.0
	arena.combat_audio.cue("perfect_parry", 999)
	arena.combat_audio._process(0.05)
	_expect(arena.combat_audio.music.volume_db < -18.0, "clash did not duck music")
	arena.combat_audio.set_music_active(false)
	arena.combat_audio._process(2.0)
	_expect(not arena.combat_audio.music_active and not arena.combat_audio.music.playing, "result did not stop music")
	arena._restart()
	_expect(arena.combat_audio.music_active and arena.combat_audio.played.is_empty(), "restart did not reset audio")
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr(message)
	print("BOSS AUDIO SMOKE OK" if failures.is_empty() else "BOSS AUDIO FAILED")
	quit(0 if failures.is_empty() else 1)

