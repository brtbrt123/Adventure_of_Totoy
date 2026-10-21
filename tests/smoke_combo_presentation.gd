extends SceneTree
## Contract boundaries plus an uninterrupted real-core three-swing chain.
const Arena := preload("res://presentation/arena/arena.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Tuning := preload("res://core/tuning.gd")
const Snapshots := preload("res://core/snapshots.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
var arena: Arena
var failures: Array[String] = []
var capture: bool = false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func save(label: String) -> void:
	if not capture:
		return
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_combo_" + label + ".png") == OK, "capture " + label)

func step(frame: InputFrame) -> void:
	arena.core.step(frame)
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()

func run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	if capture and DisplayServer.get_name() == "headless":
		printerr("COMBO PRESENTATION FAIL: capture requires windowed renderer")
		quit(1)
		return
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	var snap: Snapshots.GameSnapshot = arena.core.snapshot()
	var hero: Snapshots.EntitySnapshot = snap.player
	for swing: int in range(1, 4):
		hero.combo_index = swing
		for state: String in ["attack_windup", "attack_active", "attack_recovery"]:
			hero.state = StringName(state)
			var duration: int = Tuning.SWING_WINDUP_TICKS[swing - 1] if state == "attack_windup" else (Tuning.SWING_ACTIVE_TICKS[swing - 1] if state == "attack_active" else Tuning.SWING_RECOVERY_TICKS[swing - 1])
			var offset: int = 0 if state == "attack_windup" else (2 if state == "attack_active" else 4)
			for tick: int in [0, ceili(duration / 2.0) - 1, ceili(duration / 2.0), duration - 1]:
				hero.state_ticks = tick
				var index: int = offset + (1 if tick < ceili(duration / 2.0) else 2)
				check(ArenaAnimation.choose(hero, snap, {}) == "hero2_attack%d_right_%d" % [swing, index], "phase duration %d %s %d" % [swing, state, tick])
			# Same-state swing changes must not inherit the previous frame.
			hero.state_ticks = 0
			check(ArenaAnimation.choose(hero, snap, {}).ends_with("_%d" % (offset + 1)), "phase restart")
		hero.state = &"idle"
		check(ArenaAnimation.choose(hero, snap, {}).begins_with("hero2_idle_"), "idle grace uses attack art")
	arena.core.boss.cooldown = 10000
	arena.core.player.position = arena.core.boss.position - Vector2(34, 0)
	var first: InputFrame = InputFrame.new()
	first.attack_pressed = true
	first.aim = Vector2.RIGHT
	step(first)
	var seen: Dictionary = {}
	var hits: Dictionary = {}
	var previous: int = 1
	var last_state: StringName = &"attack_windup"
	for tick: int in range(130):
		var player: Snapshots.EntitySnapshot = arena.snapshot.player
		if player.state == &"attack_active":
			seen[player.combo_index] = true
			if not hits.has(player.combo_index):
				hits[player.combo_index] = true
				await save("hit_%d" % player.combo_index)
		var input: InputFrame = InputFrame.new()
		input.aim = Vector2.RIGHT
		input.attack_pressed = player.state == &"attack_recovery" and player.combo_index < 3
		step(input)
		player = arena.snapshot.player
		if player.combo_index > previous and player.state.begins_with("attack_"):
			check(last_state == &"attack_recovery" and player.state == &"attack_windup" and player.state_ticks == 0, "chain has idle gap or stale phase")
			check(arena.selected_frames[player.id] == "hero2_attack%d_right_1" % player.combo_index, "chain did not restart animation")
		previous = player.combo_index
		last_state = player.state
		if capture:
			await physics_frame
	check(seen.size() == 3, "real core did not show all three attacks")
	check(arena.combat_audio.played.has("counter_hit"), "finisher impact sound missing")
	check(arena.missing_frames.is_empty(), "combo atlas missing frames")
	await parry_fixture(10)
	await parry_fixture(2)
	arena.combat_audio.reset()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("COMBO PRESENTATION FAIL: " + message)
	print("COMBO PRESENTATION SMOKE ", "OK" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func parry_fixture(lead: int) -> void:
	arena._restart()
	arena.core.player.position = arena.core.boss.position - Vector2(34, 0)
	arena.core.boss.next_attack_override = &"gold_slam"
	arena.core.boss.cooldown = 1
	var success: bool = false
	for tick: int in range(120):
		var input: InputFrame = InputFrame.new()
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if arena.snapshot.tick == tell.hit_tick - lead:
				input.parry_pressed = true
		step(input)
		for event: GameEvent in arena.core.last_events:
			if event.type == &"parry_succeeded":
				success = true
				check(arena.combat_audio.played.has("perfect_parry" if lead == 2 else "deflect"), "parry cue routing")
		if success:
			await save("perfect_parry" if lead == 2 else "early_deflect")
			break
		if capture:
			await physics_frame
	check(success, "real parry fixture")
	if lead == 2 and success:
		var attack: InputFrame = InputFrame.new()
		attack.attack_pressed = true
		attack.aim = Vector2.RIGHT
		step(attack)
		for tick: int in range(Tuning.SWING_WINDUP_TICKS[0] + 1):
			if arena.combat_audio.played.has("counter_hit"):
				await save("counter")
				break
			step(InputFrame.new())
			if capture:
				await physics_frame
		check(arena.combat_audio.played.has("counter_hit"), "real riposte cue")
