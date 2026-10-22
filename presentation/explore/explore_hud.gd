extends "res://presentation/arena/hud.gd"
## The exploration HUD-lite (screen space, 320x180, text at window resolution like the fight HUD): the scene-name toast
## top left when a scene is entered, the interact hint ("[E] TALK" near an NPC), the debug lines (F1) and the
## transition fade. Presentation only: explore_scene.gd sets the fields from the ExploreCore snapshot.

## The scene name and how strongly it shows (0..1; explore_scene.gd fades it out).
var toast_text: String = ""
var toast_alpha: float = 0.0
## "[E] TALK" etc.; empty = nothing in range.
var hint_text: String = ""
## Where the hint's plate is centred (screen space, its bottom edge): above the target's head; INF = bottom centre.
var hint_at: Vector2 = Vector2.INF
## 0 = clear, 1 = the screen is ink (the 0.3 s fade between scenes).
var fade_alpha: float = 0.0
var debug_lines: Array[String] = []

const TOAST_SIZE: int = 11
const HINT_Y: float = 160.0


## The plate behind the scene-name toast (top left).
func toast_rect() -> Rect2:
	var w: float = ceilf(text_width(toast_text, 1, menu_font(), TOAST_SIZE)) + 14.0
	return Rect2(4, 4, w, 15)


## The plate behind the interact hint: centred above the target (kept on screen), else at the bottom centre.
func hint_rect() -> Rect2:
	var w: float = ceilf(text_width(hint_text)) + 10.0
	if hint_at == Vector2.INF:
		return Rect2(floorf(160.0 - w * 0.5), HINT_Y - 3.0, w, 12)
	var x: float = clampf(floorf(hint_at.x - w * 0.5), 2.0, 318.0 - w)
	var y: float = clampf(floorf(hint_at.y - 12.0), 22.0, 166.0)
	return Rect2(x, y, w, 12)


func _draw() -> void:
	if colors.is_empty():
		return
	if toast_text != "" and toast_alpha > 0.0:
		var rect: Rect2 = toast_rect()
		draw_rect(rect, Color(colors["0"], 0.78 * toast_alpha))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.size.x, 1)), Color(colors["u"], toast_alpha))
		outlined(rect.position + Vector2(7, 3), toast_text, Color(colors["1"], toast_alpha), Color(colors["0"], toast_alpha), 1, menu_font(), TOAST_SIZE)
	if hint_text != "" and fade_alpha <= 0.0:
		var plate: Rect2 = hint_rect()
		draw_rect(plate, Color(colors["0"], 0.78))
		draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1)), colors["v"])
		outlined(plate.position + Vector2(5, 3), hint_text, colors["1"], colors["0"])
	if not debug_lines.is_empty():
		var y: float = 24.0
		draw_rect(Rect2(3, y - 2, 170, debug_lines.size() * 8 + 4), Color(colors["0"], 0.7))
		for line: String in debug_lines:
			lettering(Vector2(6, y), line, colors["p"], 1, stat_font())
			y += 8
	if fade_alpha > 0.0:
		draw_rect(Rect2(-4, -4, 328, 188), Color(colors["0"], clampf(fade_alpha, 0.0, 1.0)))
