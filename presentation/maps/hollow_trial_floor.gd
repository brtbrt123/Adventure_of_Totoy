@tool
extends Node2D
## Floor pass before y-sorted props; all geometry is cosmetic.
func _draw() -> void:
	get_parent().call("draw_floor", self)
