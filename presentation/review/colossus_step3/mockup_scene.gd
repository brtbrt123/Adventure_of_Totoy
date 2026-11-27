extends "res://presentation/explore/explore_scene.gd"
## MOCK-UP only (presentation/review/colossus_step3/capture_mockup.gd): the exploration scene with `after_draw` run at the end of
## its own _draw, so a stand-in boss lands on top of the floor and the warnings, as a real actor would.

var after_draw: Callable = Callable()


func _draw() -> void:
	super()
	if after_draw.is_valid():
		after_draw.call()
