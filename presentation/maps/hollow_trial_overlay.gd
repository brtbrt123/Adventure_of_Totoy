@tool
extends Node2D
func _draw() -> void:
	get_parent().call("draw_motes", self)
