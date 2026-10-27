extends SceneTree
## Windowed raster contract: mirroring changes pixels, never the prop's draw bounds.
const PropsLayer := preload("res://presentation/common/props_layer.gd")

class Fixture extends Node2D:
	var texture: Texture2D
	func _draw() -> void:
		for flipped: bool in [false, true]:
			PropsLayer.draw(self, {"rect": Rect2(26 if flipped else 10, 8, 8, 8), "src": Rect2(0, 0, 8, 8), "flip": flipped}, texture, Color.WHITE)


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y: int in range(8):
		image.set_pixel(0, y, Color.html("#6aa89a"))
		image.set_pixel(7, y, Color.html("#f4ecd6"))
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(48, 24)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var canvas: Fixture = Fixture.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.texture = ImageTexture.create_from_image(image)
	view.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = view.get_texture().get_image()
	var failures: int = 0
	for y: int in range(8):
		for x: int in range(8):
			if pixels.get_pixel(10 + x, 8 + y) != pixels.get_pixel(26 + 7 - x, 8 + y):
				failures += 1
	for point: Vector2i in [Vector2i(25, 10), Vector2i(34, 10), Vector2i(41, 10)]:
		if pixels.get_pixelv(point).a > 0.0:
			failures += 1
	if failures > 0:
		printerr("FAIL mirrored prop moved outside its anchored bounds: %d pixel mismatches" % failures)
		quit(1)
	else:
		print("PROP MIRROR RASTER OK: both facings share anchored bounds")
		quit()
