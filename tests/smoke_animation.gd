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
		if name_key.begins_with("mossbound_colossus_") or name_key.begins_with("totoy_"):
			var hero: bool = name_key.begins_with("totoy_")
			var source: FileAccess = FileAccess.open("res://art/src/" + name_key + ".txt", FileAccess.READ)
			_expect(source != null, "boss source missing " + name_key)
			if source != null:
				var rows: PackedStringArray = PackedStringArray()
				for line: String in source.get_as_text().split("\n"):
					var row: String = line.strip_edges()
					if not row.is_empty() and not row.begins_with("#"):
						rows.append(row)
				_expect(rows.size() == (24 if hero else 48), "actor height changed: " + name_key)
				for row: String in rows:
					_expect(row.length() == (16 if hero else 48), "actor width changed: " + name_key)
					for reserved: String in ["x", "y", "z", "A"]:
						_expect(not row.contains(reserved), "combat cue color on actor body: " + name_key)
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
	for attack: String in ["gold_slam", "red_sweep", "red_shards", "red_stomp", "gold_combo", "red_charge"]:
		var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		tell.owner_id = 2
		tell.attack = StringName(attack)
		tell.start_tick = 10
		tell.hit_tick = 70
		tell.end_tick = 74
		snap.telegraphs.clear()
		snap.telegraphs.append(tell)
		for tick: int in range(10, 75):
			snap.tick = tick
			var phase: String = "strike" if tick >= 70 else "windup"
			var spec: Array = ArenaAnimation.BOSS[attack + "_" + phase]
			var index: int = ArenaAnimation.frame_index(spec, tick - 70)
			if tick < 70:
				index = mini(int(spec[0]) - 1, floori(float(tick - 10) / 60.0 * int(spec[0]))) + 1
			var expected: String = "mossbound_colossus_%s_%s_%d" % [attack, phase, index]
			_expect(ArenaAnimation.choose(actor, snap, {}) == expected, "attack boundary " + expected)
		actor.state = &"recover"
		snap.telegraphs.clear()
		snap.tick = 75
		var history: Dictionary = {"attack": attack, "hit_tick": 70, "end_tick": 74}
		_expect(ArenaAnimation.choose(actor, snap, history) == "mossbound_colossus_%s_strike_%d" % [attack, ArenaAnimation.frame_index(ArenaAnimation.BOSS[attack + "_strike"], 5)], "strike hold")
		snap.tick = 74 + ArenaAnimation.STRIKE_HOLD_TICKS + 1
		_expect(ArenaAnimation.choose(actor, snap, history) == ("mossbound_colossus_red_sweep_recover_1" if attack == "red_sweep" else "mossbound_colossus_recover_1"), "hold expires")
		actor.state = &"posture_broken"
		_expect(ArenaAnimation.choose(actor, snap, history).contains("posture_broken"), "break cancels strike hold")
		actor.state = &"attack"

# Follow real core state lifetimes so a pose that is unreachable before a state
# expires cannot pass merely because the catalog can synthesize its name.
func _hero_timelines() -> void:
	for facing: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		_reset()
		_step(_frame(facing))
		var requested: Dictionary = {}
		for i: int in range(50):
			_step(_frame())
			requested[arena.selected_frames[arena.snapshot.player.id]] = true
		for i: int in range(40):
			_step(_frame(facing))
			requested[arena.selected_frames[arena.snapshot.player.id]] = true
		for action: int in range(3):
			_step(_frame(Vector2.ZERO, action == 0, action == 1, action == 2))
			requested[arena.selected_frames[arena.snapshot.player.id]] = true
			for i: int in range(40):
				_step(_frame())
				requested[arena.selected_frames[arena.snapshot.player.id]] = true
		for name_key: String in ArenaAnimation.all_names():
			if name_key.begins_with("totoy_") and name_key.contains("_" + ArenaAnimation.direction(facing) + "_") and not name_key.contains("_dead_"):
				_expect(requested.has(name_key), "real state lifetime never requests " + name_key)

func _combo_boundaries() -> void:
	var snap: Snapshots.GameSnapshot = Snapshots.GameSnapshot.new()
	var actor: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	actor.id = 2
	actor.visual_id = &"mossbound_colossus"
	actor.state = &"attack"
	var first: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	first.owner_id = 2
	first.attack = &"gold_combo"
	first.start_tick = 10
	first.hit_tick = 70
	first.end_tick = 70
	var second: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	second.owner_id = 2
	second.attack = &"gold_combo"
	second.start_tick = 10
	second.hit_tick = 96
	second.end_tick = 96
	for reverse: bool in [false, true]:
		snap.telegraphs.assign([second, first] if reverse else [first, second])
		for tick: int in range(10, 101):
			snap.tick = tick
			var selected: String = ArenaAnimation.choose(actor, snap, {})
			_expect(selected.contains("strike") == ((tick >= 70 and tick <= 74) or tick >= 96), "combo phase at %d" % tick)
			snap.tick = 75
			_expect(ArenaAnimation.choose(actor, snap, {}).ends_with("windup_1"), "combo must re-raise")
	first.attack = &"red_charge"
	first.direction = Vector2.LEFT
	snap.telegraphs.assign([first])
	_expect(ArenaAnimation.boss_mirrored(actor, snap, {}), "left charge must mirror")
	first.direction = Vector2.RIGHT
	_expect(not ArenaAnimation.boss_mirrored(actor, snap, {}), "right charge must not mirror")

func _encounter(attack: StringName, parry_slam: bool) -> void:
	_reset()
	if attack in [&"gold_combo", &"red_charge"]:
		arena.core.boss.phase = 2
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	_step(_frame())
	_expect(not arena.snapshot.telegraphs.is_empty(), "scripted boss attack did not start")
	for i: int in range(240):
		var parry: bool = false
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if parry_slam and tell.kind == &"gold" and arena.snapshot.tick == tell.hit_tick - 2:
				parry = true
		_step(_frame(Vector2.ZERO, false, parry))
		await process_frame
		if parry_slam and arena.snapshot.entities[0].state == &"posture_broken":
			_wait(26)
			return
		if not parry_slam and arena.snapshot.entities[0].state == &"recover" and arena.snapshot.entities[0].state_ticks > ArenaAnimation.STRIKE_HOLD_TICKS + 2:
			return
	_expect(false, "encounter did not reach expected state: " + String(attack))

func _run() -> void:
	_catalog()
	_combo_boundaries()
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	if packed == null:
		printerr("ANIMATION FAIL: cannot load arena")
		quit(1)
		return
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	_hero_timelines()
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
	for attack: StringName in [&"gold_slam", &"red_sweep", &"red_shards", &"red_stomp", &"gold_combo", &"red_charge"]:
		await _encounter(attack, false)
	await _encounter(&"gold_slam", true)
	await _encounter(&"gold_combo", true)
	for state: String in ArenaAnimation.PLAYER:
		if state != "dead":
			_expect(player_states.has(state), "script never reached player " + state)
	for name_key: String in ArenaAnimation.all_names():
		if name_key.begins_with("mossbound_colossus_") and (name_key.contains("windup") or name_key.contains("strike") or name_key.contains("red_sweep_recover")):
			_expect(boss_poses.has(name_key), "fight never requested " + name_key)
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
