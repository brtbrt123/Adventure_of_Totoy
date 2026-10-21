extends "res://presentation/arena/hud.gd"
## The menu's lettering layer. It lives in a 320x180 SubViewport (see title.gd) and has the HUD's text helpers
## (outlined, centered); the title screen decides what to draw (draw_text_layer) and pixel_text.gdshader turns the
## result into hard palette pixels.
var view: Object = null


func _draw() -> void:
	if view == null or colors.is_empty():
		return
	view.draw_text_layer(self)
