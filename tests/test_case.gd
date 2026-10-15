extends RefCounted
## Base class for headless core tests. A test file extends this and defines test_* methods.
## Assertions record failures instead of aborting, so one run reports every problem.

const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const GameCore := preload("res://core/game_core.gd")
const PlayerState := preload("res://core/player.gd")
const BossState := preload("res://core/boss.gd")
const Telegraph := preload("res://core/telegraph.gd")

var failures: Array[String] = []


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s expected %s but got %s" % [message, str(expected), str(actual)])


func assert_near(actual: float, expected: float, epsilon: float, message: String = "") -> void:
	if absf(actual - expected) > epsilon:
		failures.append("%s expected %s (+/- %s) but got %s" % [message, str(expected), str(epsilon), str(actual)])


# --- helpers ---

func input(move: Vector2 = Vector2.ZERO, dash: bool = false, parry: bool = false, attack: bool = false) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.move = move
	frame.dash_pressed = dash
	frame.parry_pressed = parry
	frame.attack_pressed = attack
	return frame


func run(core: GameCore, ticks: int, frame: InputFrame = null) -> void:
	var idle: InputFrame = frame if frame != null else InputFrame.new()
	for i: int in ticks:
		core.step(idle)


## Step with idle input until core.tick == target_tick (does nothing if already there or past).
func run_to_tick(core: GameCore, target_tick: int) -> void:
	while core.tick < target_tick:
		core.step(InputFrame.new())


func event_types(core: GameCore) -> Array[StringName]:
	var types: Array[StringName] = []
	for event: GameEvent in core.last_events:
		types.append(event.type)
	return types


func find_event(core: GameCore, type: StringName) -> GameEvent:
	for event: GameEvent in core.last_events:
		if event.type == type:
			return event
	return null


## A core whose boss will start the given attack on the very next step, with the player already in place.
## Returns the tick on which the attack's danger window starts (hit_tick) after that step.
func begin_attack(core: GameCore, attack: StringName, player_pos: Vector2) -> int:
	core.player.position = player_pos
	core.boss.next_attack_override = attack
	core.boss.cooldown = 1
	core.step(InputFrame.new())
	assert_eq(core.boss.state, BossState.STATE_ATTACK, "boss should have started " + str(attack))
	return core.boss.telegraphs[0].hit_tick
