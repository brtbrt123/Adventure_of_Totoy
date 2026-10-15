extends SceneTree
## Run after validate/build/preview and Godot import.
const Arena := preload("res://presentation/arena/arena.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const GameCore := preload("res://core/game_core.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
var failures: Array[String] = []
var player_states: Dictionary = {}
var boss_poses: Dictionary = {}
var arena: Arena

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _frame(move: Vector2 = Vector2.ZERO, dash: bool = false, parry: bool = false, attack: bool = false) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.move = move
	frame.dash_pressed = dash
	frame.parry_pressed = parry
	frame.attack_pressed = attack
	return frame

func _observe() -> void:
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()
	player_states[String(arena.snapshot.player.state)] = true
	for actor: Snapshots.EntitySnapshot in arena.snapshot.entities:
		boss_poses[String(arena.selected_frames.get(actor.id, ""))] = true

func _step(frame: InputFrame) -> void:
	arena.core.step(frame)
	_observe()

func _wait(ticks: int) -> void:
	for i: int in range(ticks):
		_step(_frame())

func _reset() -> void:
	arena._restart()
	arena.core.boss.cooldown = 10000
	_observe()

func _catalog() -> void:
	var file: FileAccess = FileAccess.open("res://art/build/sprites.json", FileAccess.READ)
	if file == null:
		_expect(false, "cannot open sprites.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_expect(false, "invalid sprites.json")
		return
	var atlas: Dictionary = parsed.get("frames", {})
	for name_key: String in ArenaAnimation.all_names():
		_expect(atlas.has(name_key), "atlas missing " + name_key)
	# Exercise every directional state and every frame index the table declares.
	var snap: Snapshots.GameSnapshot = Snapshots.GameSnapshot.new()
	var actor: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	actor.visual_id = &"totoy"
	for state: String in ArenaAnimation.PLAYER:
		actor.state = StringName(state)
		for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
			actor.facing = facing
			for t: int in range(int(ArenaAnimation.PLAYER[state][0]) * int(ArenaAnimation.PLAYER[state][1]) + 2):
				actor.state_ticks = t
				_expect(atlas.has(ArenaAnimation.choose(actor, snap, {})), "selector missing player %s %s tick %d" % [state, facing, t])
	_expect(ArenaAnimation.mirrored(Vector2.LEFT), "left must mirror right")
	_expect(not ArenaAnimation.mirrored(Vector2.UP), "up must not mirror")
	# Test exact attack boundaries and the post-impact hold independently of
	# the fight, where a perfect parry removes the active telegraph immediately.
	actor.visual_id = &"mossbound_colossus"
	actor.id = 2
	actor.state = &"attack"
	for attack: String in ["gold_slam", "red_sweep", "red_shards"]:
		var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		tell.owner_id = 2
		tell.attack = StringName(attack)
		tell.start_tick = 10
		tell.hit_tick = 70
		tell.end_tick = 74
		snap.telegraphs.clear()
		snap.telegraphs.append(tell)
		for tick: int in [10, 39, 40, 69, 70, 74]:
			snap.tick = tick
			var expected: String = "mossbound_colossus_" + attack
			expected += "_strike_1" if tick >= 70 else ("_windup_2" if tick >= 40 else "_windup_1")
			_expect(ArenaAnimation.choose(actor, snap, {}) == expected, "attack boundary " + expected)
		actor.state = &"recover"
		snap.telegraphs.clear()
		snap.tick = 75
		var history: Dictionary = {"attack": attack, "end_tick": 74}
		_expect(ArenaAnimation.choose(actor, snap, history) == "mossbound_colossus_" + attack + "_strike_1", "strike hold")
		snap.tick = 74 + ArenaAnimation.STRIKE_HOLD_TICKS + 1
		_expect(ArenaAnimation.choose(actor, snap, history) == "mossbound_colossus_recover_1", "hold expires")
		actor.state = &"posture_broken"
		_expect(ArenaAnimation.choose(actor, snap, history).contains("posture_broken"), "break cancels strike hold")
		actor.state = &"attack"

func _encounter(attack: StringName, parry_slam: bool) -> void:
	_reset()
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	_step(_frame())
	_expect(not arena.snapshot.telegraphs.is_empty(), "scripted boss attack did not start")
	for i: int in range(240):
		var parry: bool = false
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if parry_slam and tell.attack == &"gold_slam" and arena.snapshot.tick == tell.hit_tick - 2:
				parry = true
		_step(_frame(Vector2.ZERO, false, parry))
		if parry_slam and arena.snapshot.entities[0].state == &"posture_broken":
			_wait(26)
			return
		if not parry_slam and arena.snapshot.entities[0].state == &"recover" and arena.snapshot.entities[0].state_ticks > ArenaAnimation.STRIKE_HOLD_TICKS + 2:
			return
	_expect(false, "encounter did not reach expected state: " + String(attack))

func _run() -> void:
	_catalog()
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	if packed == null:
		printerr("ANIMATION FAIL: cannot load arena")
		quit(1)
		return
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	_reset()
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		for i: int in range(24):
			_step(_frame(facing))
	_step(_frame(Vector2.LEFT, true))
	_wait(16)
	_step(_frame(Vector2.ZERO, false, true))
	_wait(36)
	_step(_frame(Vector2.ZERO, false, false, true))
	_wait(22)
	for attack: StringName in [&"gold_slam", &"red_sweep", &"red_shards"]:
		_encounter(attack, false)
	_encounter(&"gold_slam", true)
	for state: String in ArenaAnimation.PLAYER:
		if state != "dead":
			_expect(player_states.has(state), "script never reached player " + state)
	for pose: String in ["gold_slam_windup_1", "gold_slam_windup_2", "gold_slam_strike_1", "red_sweep_windup_1", "red_sweep_windup_2", "red_sweep_strike_1", "red_shards_windup_1", "red_shards_windup_2", "red_shards_strike_1", "posture_broken_1", "posture_broken_2"]:
		_expect(boss_poses.has("mossbound_colossus_" + pose), "fight never requested " + pose)
	_expect(arena.missing_frames.is_empty(), "runtime missing names: " + str(arena.missing_frames.keys()))
	await process_frame
	arena.queue_free()
	if failures.is_empty():
		print("ANIMATION SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("ANIMATION FAIL: " + message)
		quit(1)
