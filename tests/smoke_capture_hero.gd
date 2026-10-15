extends SceneTree
## Optional windowed proof: real core states and events, frozen while captured.
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
var arena: Arena

func _init() -> void:
	call_deferred("_run")

func _step(frame: InputFrame) -> void:
	arena.core.step(frame)
	arena.snapshot = arena.core.snapshot()
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()

func _save(label: String) -> bool:
	var expected: Dictionary = {
		"hero_idle": "totoy_idle_right_1",
		"hero_draw": "totoy_attack_windup_right_2",
		"hero_slash": "totoy_attack_active_right_1",
		"hero_parry": "totoy_parry_right_2",
	}
	if expected.has(label) and ArenaAnimation.choose(arena.snapshot.player, arena.snapshot, {}) != expected[label]:
		printerr("HERO CAPTURE FAIL: wrong pose for " + label)
		return false
	if label == "parry_spark" and (arena.parry_impacts.is_empty() or not bool(arena.parry_impacts[0]["perfect"])):
		printerr("HERO CAPTURE FAIL: perfect impact missing")
		return false
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	return picture.save_png("res://art/build/arena_" + label + ".png") == OK

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("HERO CAPTURE FAIL: windowed renderer required")
		quit(1)
		return
	var scene: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	arena = scene.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.core.boss.cooldown = 10000
	arena.core.player.position = Vector2(180, 100)
	_step(InputFrame.new())
	if not await _save("hero_idle"):
		quit(1)
		return
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	_step(attack)
	for i: int in range(4):
		_step(InputFrame.new())
	if not await _save("hero_draw"):
		quit(1)
		return
	for i: int in range(3):
		_step(InputFrame.new())
	if not await _save("hero_slash"):
		quit(1)
		return
	for i: int in range(13):
		_step(InputFrame.new())
	var parry: InputFrame = InputFrame.new()
	parry.parry_pressed = true
	_step(parry)
	for i: int in range(5):
		_step(InputFrame.new())
	if not await _save("hero_parry"):
		quit(1)
		return
	arena._restart()
	arena.core.boss.next_attack_override = &"gold_slam"
	arena.core.boss.cooldown = 1
	for i: int in range(100):
		var frame: InputFrame = InputFrame.new()
		for tell: Snapshots.TelegraphSnapshot in arena.snapshot.telegraphs:
			if arena.snapshot.tick == tell.hit_tick - 2:
				frame.parry_pressed = true
		_step(frame)
		for event: GameEvent in arena.core.last_events:
			if event.type == &"parry_succeeded" and event.data["quality"] == &"perfect":
				if await _save("parry_spark"):
					print("HERO CAPTURE OK: idle, half draw, slash, guard, perfect impact")
					quit(0)
				else:
					quit(1)
				return
	printerr("HERO CAPTURE FAIL: perfect parry missing")
	quit(1)
