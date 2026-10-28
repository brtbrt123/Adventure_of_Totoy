extends SceneTree
class Board:
	extends Node2D
	var pictures: Array[Texture2D] = []
	func _draw() -> void:
		for i: int in pictures.size():
			draw_texture_rect(pictures[i],Rect2((i%2)*320,(i/2)*180,320,180),false)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_size=Vector2i(640,540)
	root.size=Vector2i(1280,1080)
	var board: Board=Board.new()
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for name: String in ["hud_proposal","slots","gauges","mob_bars_55","effects_a","effects_b"]:
		var picture: Image=Image.load_from_file("res://art/reference/woodland_polish_v1/"+name+".png")
		board.pictures.append(ImageTexture.create_from_image(picture))
	root.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error=root.get_texture().get_image().save_png("res://art/reference/woodland_polish_v1/review_contact.png")
	print("REVIEW CONTACT OK" if error==OK else "REVIEW CONTACT FAIL")
	quit(0 if error==OK else 1)
