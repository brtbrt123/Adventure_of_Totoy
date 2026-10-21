extends RefCounted
## Input names belong to presentation. Safe to register repeatedly in headless tests.
const InputFrame := preload("res://core/input_frame.gd")

static func register() -> void:
	var keys: Dictionary = {
		"arena_left": [KEY_A, KEY_LEFT], "arena_right": [KEY_D, KEY_RIGHT],
		"arena_up": [KEY_W, KEY_UP], "arena_down": [KEY_S, KEY_DOWN],
		"arena_attack": [], "arena_weapon_active": [], "arena_parry": [KEY_SPACE],
		"arena_dash": [KEY_SHIFT], "arena_restart": [KEY_R],
		"arena_debug": [KEY_F1],
		"menu_up": [KEY_W, KEY_UP], "menu_down": [KEY_S, KEY_DOWN],
		"menu_accept": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], "menu_back": [KEY_ESCAPE],
		"arena_skill_1": [KEY_Z], "arena_skill_2": [KEY_X], "arena_skill_3": [KEY_C],
		# the character menu (presentation/arena/character_menu.gd): TAB opens and closes it, Q/E switch its tabs
		"menu_toggle": [KEY_TAB], "menu_tab_prev": [KEY_Q], "menu_tab_next": [KEY_E],
		"menu_left": [KEY_A, KEY_LEFT], "menu_right": [KEY_D, KEY_RIGHT],
	}
	# Q no longer swaps weapons in the arena (2026-10-21): weapons are equipped in the character menu's inventory.
	if InputMap.has_action("arena_weapon_swap"):
		InputMap.erase_action("arena_weapon_swap")
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for key: int in keys[action]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		match action:
			"arena_left": _axis(action, JOY_AXIS_LEFT_X, -1.0)
			"arena_right": _axis(action, JOY_AXIS_LEFT_X, 1.0)
			"arena_up": _axis(action, JOY_AXIS_LEFT_Y, -1.0)
			"arena_down": _axis(action, JOY_AXIS_LEFT_Y, 1.0)
			"arena_attack":
				var click: InputEventMouseButton = InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				InputMap.action_add_event(action, click)
				_button(action, JOY_BUTTON_X)
			"arena_weapon_active":
				var click: InputEventMouseButton = InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_RIGHT
				InputMap.action_add_event(action, click)
				_button(action, JOY_BUTTON_Y)
			"menu_up": _button(action, JOY_BUTTON_DPAD_UP)
			"menu_down": _button(action, JOY_BUTTON_DPAD_DOWN)
			"menu_accept": _button(action, JOY_BUTTON_A)
			"menu_back": _button(action, JOY_BUTTON_B)
			"arena_parry": _button(action, JOY_BUTTON_A)
			"arena_dash": _button(action, JOY_BUTTON_B)
			"menu_toggle": _button(action, JOY_BUTTON_BACK)
			"menu_tab_prev": _button(action, JOY_BUTTON_LEFT_SHOULDER)
			"menu_tab_next": _button(action, JOY_BUTTON_RIGHT_SHOULDER)
			"menu_left": _button(action, JOY_BUTTON_DPAD_LEFT)
			"menu_right": _button(action, JOY_BUTTON_DPAD_RIGHT)

static func _axis(action: String, axis: int, value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

static func _button(action: String, button: int) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

## Attacks, skills and the weapon active go where the character is heading (the movement direction), or the way he already
## faces when standing still. The mouse is not used for aiming; the parameters stay so callers need not change.
static func read_frame(_player_position: Vector2 = Vector2.ZERO, _mouse_position: Vector2 = Vector2.ZERO) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.move = Input.get_vector("arena_left", "arena_right", "arena_up", "arena_down")
	frame.weapon_active_pressed = Input.is_action_just_pressed("arena_weapon_active")
	frame.attack_pressed = Input.is_action_just_pressed("arena_attack")
	for slot: int in range(1, 4):
		if Input.is_action_just_pressed("arena_skill_%d" % slot):
			frame.skill_pressed = slot
			break
	# the core reads the aim on the press tick; no aim means "keep facing" (the last heading)
	if (frame.attack_pressed or frame.skill_pressed > 0 or frame.weapon_active_pressed) and frame.move.length_squared() > 0.0001:
		frame.aim = frame.move.normalized()
	frame.attack_held = Input.is_action_pressed("arena_attack")
	frame.parry_pressed = Input.is_action_just_pressed("arena_parry")
	frame.dash_pressed = Input.is_action_just_pressed("arena_dash")
	return frame
