extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_arena.gd
const Arena := preload("res://presentation/arena/arena.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const GameEvent := preload("res://core/game_event.gd")
var failures: Array[String] = []
var saw_dash: bool = false
var saw_parry: bool = false
var saw_attack: bool = false
var saw_telegraph: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	if packed == null:
		printerr("ARENA FAIL: scene did not load")
		quit(1)
		return
	var arena: Arena = packed.instantiate() as Arena
	root.add_child(arena)
	_expect(Engine.physics_ticks_per_second == 60, "physics must run at 60 Hz")
	_expect(arena.frames.has("mossbound_colossus_idle"), "boss atlas is stale: run validate/build/preview")
	_expect(arena.floor_regions.size() == 220, "floor must contain 20x11 tiles")
	# Re-registration must not accumulate duplicate bindings.
	var before: int = InputMap.action_get_events("arena_attack").size()
	Bindings.register()
	_expect(InputMap.action_get_events("arena_attack").size() == before, "input registration must be idempotent")
	for index: int in range(360):
		match index:
			0: Input.action_press("arena_right")
			20: Input.action_press("arena_dash")
			21: Input.action_release("arena_dash")
			55: Input.action_release("arena_right")
			65: Input.action_press("arena_parry")
			66: Input.action_release("arena_parry")
			105: Input.action_press("arena_attack")
			106: Input.action_release("arena_attack")
		await physics_frame
		# physics_frame emits before node callbacks; process_frame observes their results.
		await process_frame
		saw_parry = saw_parry or arena.snapshot.player.state == &"parry"
		saw_attack = saw_attack or arena.snapshot.player.state == &"attack_windup"
		saw_telegraph = saw_telegraph or not arena.snapshot.telegraphs.is_empty()
		for event: GameEvent in arena.core.last_events:
			saw_dash = saw_dash or event.type == &"dash_started"
	_expect(arena.core.tick >= 300, "core tick did not advance for hundreds of frames")
	_expect(saw_dash, "scripted dash did not reach core")
	_expect(saw_parry, "scripted parry did not reach core")
	_expect(saw_attack, "scripted attack did not reach core")
	_expect(saw_telegraph, "boss never supplied a telegraph")
	_expect(arena.snapshot.player.position.x > 64.0, "scripted walking did not move player")
	_expect(arena.frames.has("totoy_idle_right_1"), "new hero atlas absent")
	_expect(arena.missing_frames.is_empty(), "scripted arena requested missing art")
	for action: String in ["arena_right", "arena_dash", "arena_parry", "arena_attack"]:
		Input.action_release(action)
	arena.queue_free()
	if failures.is_empty():
		print("ARENA SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("ARENA FAIL: " + message)
		quit(1)
