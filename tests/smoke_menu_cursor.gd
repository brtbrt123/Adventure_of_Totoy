extends SceneTree
const Policy := preload("res://presentation/common/menu_cursor.gd")
const Menu := preload("res://presentation/arena/character_menu.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node = Node.new()
	root.add_child(scene)
	current_scene = scene
	var policy: Node = Policy.new()
	root.add_child(policy)
	policy.set_process(false)
	policy._process(0.0)
	assert(not policy.pointer_needed)
	var menu: Menu = Menu.new()
	scene.add_child(menu)
	menu.is_open = true
	policy._process(0.0)
	assert(policy.pointer_needed)
	menu.is_open = false
	policy._process(0.0)
	assert(not policy.pointer_needed)
	scene.scene_file_path = Policy.TITLE
	policy._process(0.0)
	assert(policy.pointer_needed)
	print("MENU CURSOR VISIBILITY OK: title, TAB open/close, gameplay")
	quit()
