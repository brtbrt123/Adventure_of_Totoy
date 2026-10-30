extends RefCounted
## Input names belong to presentation. Safe to register repeatedly in headless tests.
const InputFrame := preload("res://core/input_frame.gd")

static func register() -> void:
	var keys: Dictionary = {
		"arena_left": [KEY_A, KEY_LEFT], "arena_right": [KEY_D, KEY_RIGHT],
		"arena_up": [KEY_W, KEY_UP], "arena_down": [KEY_S, KEY_DOWN],
		"arena_attack": [], "arena_weapon_active": [], "arena_parry": [KEY_SPACE],
		"arena_dash": [KEY_SHIFT], "arena_restart": [KEY_R],
		"arena_debug": [KEY_F1, KEY_H],
		"menu_up": [KEY_W, KEY_UP], "menu_down": [KEY_S, KEY_DOWN],
		"menu_accept": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], "menu_back": [KEY_ESCAPE],
		"arena_skill_1": [KEY_Z], "arena_skill_2": [KEY_X], "arena_skill_3": [KEY_C],
		# the character menu (presentation/arena/character_menu.gd): TAB opens and closes it, Q/E switch its tabs
		"menu_toggle": [KEY_TAB], "menu_tab_prev": [KEY_Q], "menu_tab_next": [KEY_E],
		"menu_left": [KEY_A, KEY_LEFT], "menu_right": [KEY_D, KEY_RIGHT],
		# exploration (presentation/explore/explore_scene.gd): E interacts; F2-F5 jump to a scene, F6 opens/closes the
		# forest's root gate (debug keys for testing)
		"explore_interact": [KEY_E], "explore_use_herb": [], "explore_item_1": [KEY_1], "explore_item_2": [KEY_2],
		"dialogue_next": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
		"dialogue_skip": [KEY_ESCAPE],
		# Numeric1/2 are item slots. Other legacy debug aliases remain; G toggles gate, H shows debug.
		"debug_scene_village": [KEY_F2], "debug_scene_forest": [KEY_F3], "debug_scene_glade": [KEY_F4, KEY_3],
		"debug_scene_arena": [KEY_F5, KEY_4], "debug_toggle_gate": [KEY_F6, KEY_G],
		"debug_scene_village_layered": [KEY_F7, KEY_5],
		"debug_scene_glade_layered": [KEY_F8, KEY_6],
		"debug_lighting_toggle": [KEY_F9, KEY_7],
		"debug_scene_forest_layered": [KEY_F10, KEY_8],
		"debug_scene_woodland": [KEY_F11, KEY_9],
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
			"dialogue_next": _button(action, JOY_BUTTON_A)
			"dialogue_skip": _button(action, JOY_BUTTON_B)
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

## Attacks, skills and the weapon active aim at the mouse: the direction from the hero to the cursor, both in world space, read
## on the press tick (the hero's facing follows it for that action only; walking does not turn him toward the cursor).
## Without a usable cursor (`mouse_position` left at INF, the cursor outside the window, or the cursor on the hero) they go
## where the character is heading, else the way he already faces when standing still (no aim).
static func read_frame(player_position: Vector2 = Vector2.ZERO, mouse_position: Vector2 = Vector2.INF) -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.move = Input.get_vector("arena_left", "arena_right", "arena_up", "arena_down")
	frame.weapon_active_pressed = Input.is_action_just_pressed("arena_weapon_active")
	frame.attack_pressed = Input.is_action_just_pressed("arena_attack")
	for slot: int in range(1, 4):
		if Input.is_action_just_pressed("arena_skill_%d" % slot):
			frame.skill_pressed = slot
			break
	# the core reads the aim on the press tick; no aim means "keep facing" (the last heading)
	if frame.attack_pressed or frame.skill_pressed > 0 or frame.weapon_active_pressed:
		var to_mouse: Vector2 = mouse_position - player_position
		if mouse_position.is_finite() and to_mouse.length_squared() > 1.0:
			frame.aim = to_mouse.normalized()
		elif frame.move.length_squared() > 0.0001:
			frame.aim = frame.move.normalized()
	frame.use_item_slot = 1 if Input.is_action_just_pressed("explore_item_1") else (2 if Input.is_action_just_pressed("explore_item_2") else 0)
	frame.attack_held = Input.is_action_pressed("arena_attack")
	frame.parry_pressed = Input.is_action_just_pressed("arena_parry")
	frame.dash_pressed = Input.is_action_just_pressed("arena_dash")
	return frame


## Keyboard/mouse labels reflect the currently registered map, including later remaps.
static func action_label(action: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
		if event is InputEventMouseButton:
			return "Left click" if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT else "Right click"
	return "Unbound"


## The mouse cursor in world space for `canvas` (a node drawn under the scene's camera), or INF while it is outside the window.
static func world_mouse(canvas: CanvasItem) -> Vector2:
	var viewport: Viewport = canvas.get_viewport()
	if viewport == null or not viewport.get_visible_rect().has_point(viewport.get_mouse_position()):
		return Vector2.INF
	return canvas.get_global_mouse_position()
