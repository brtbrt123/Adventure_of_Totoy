extends Node
## One global policy: show a pointer only on screens with mouse interaction.
const TITLE: String = "res://presentation/menu/title.tscn"
const CharacterMenu := preload("res://presentation/arena/character_menu.gd")

var pointer_needed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	var needed: bool = false
	if scene != null:
		needed = scene.scene_file_path == TITLE
		# Character menus share one implementation in arena and exploration.
		for menu: Node in get_tree().get_nodes_in_group(&"mouse_cursor_menus"):
			if menu is CharacterMenu and (menu as CharacterMenu).is_open:
				needed = true
				break
	pointer_needed = needed
	var mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE if needed else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
