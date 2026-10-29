@tool
extends RefCounted
## Editor-only helper: when you open a TAB-menu piece (the Status tab, the Items tab, the description box...) on its own in
## Godot, this puts the menu's frame (menu_shell.tscn: veil, big panel, tabs) behind it so it looks like it does in the game.
## The frame is an internal child: it is shown in the editor but never saved into the scene you are editing, and it does nothing
## in the running game. To change the frame itself, open presentation/ui/menu_shell.tscn.

const Shell := preload("res://presentation/ui/menu_shell.tscn")
const TAB_NAMES: Array = ["STATUS", "ASPECTS", "ITEMS", "QUESTS"]


static func add(piece: Node, tab: int) -> void:
	if not Engine.is_editor_hint() or piece.get_node_or_null("EditorBackdrop") != null:
		return
	var shell: Control = Shell.instantiate()
	shell.name = "EditorBackdrop"
	shell.show_behind_parent = true
	piece.add_child(shell, false, Node.INTERNAL_MODE_FRONT)
	shell.apply(tab, TAB_NAMES)
