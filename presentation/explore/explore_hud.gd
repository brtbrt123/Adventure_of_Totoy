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
var training: Dictionary = {}
var herb_count: int = 0
var explore_hp: int = 0
var explore_max_hp: int = 0
var fight_hud: bool = false
var training_feedback: String = ""
var training_at: Vector2 = Vector2.INF
const Bindings := preload("res://presentation/arena/input_bindings.gd")


func training_hint() -> String:
	match String(training.get("hint", "")):
		"dash": return "Dash: " + Bindings.action_label("arena_dash")
		"attack": return "Attack 3 times: %s (%d/%d)" % [Bindings.action_label("arena_attack"), training.get("hits", 0), training.get("hits_needed", 3)]
		"parry": return "Parry GOLD just before hit: " + Bindings.action_label("arena_parry")
		"dodge": return "Dash through RED: " + Bindings.action_label("arena_dash")
	return ""


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
	if fight_hud:
		UiPanel.draw_panel(self, Rect2(6,146,118,28), &"info", colors, false)
		bar(Vector2(12,153),70,explore_hp,explore_max_hp,colors["t"],4)
		lettering(Vector2(12,163),"%d / %d" % [explore_hp,explore_max_hp],colors["1"],1,stat_font(),7)
		ui("ui_item_herb_1",Rect2(86,151,16,16))
		lettering(Vector2(104,151),str(herb_count),colors["1"],1,stat_font(),8)
		lettering(Vector2(104,162),Bindings.action_label("explore_use_herb"),colors["u"],1,ui_font(),7)
	if toast_text != "" and toast_alpha > 0.0 and not bool(training.get("active", false)):
		var rect: Rect2 = toast_rect()
		draw_rect(rect, Color(colors["0"], 0.78 * toast_alpha))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.size.x, 1)), Color(colors["u"], toast_alpha))
		outlined(rect.position + Vector2(7, 3), toast_text, Color(colors["1"], toast_alpha), Color(colors["0"], toast_alpha), 1, menu_font(), TOAST_SIZE)
	if hint_text != "" and fade_alpha <= 0.0:
		var plate: Rect2 = hint_rect()
		draw_rect(plate, Color(colors["0"], 0.78))
		draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1)), colors["v"])
		outlined(plate.position + Vector2(5, 3), hint_text, colors["1"], colors["0"])
	if bool(training.get("active", false)):
		_draw_training_cards()
	if not debug_lines.is_empty():
		var y: float = 24.0
		draw_rect(Rect2(3, y - 2, 170, debug_lines.size() * 8 + 4), Color(colors["0"], 0.7))
		for line: String in debug_lines:
			lettering(Vector2(6, y), line, colors["p"], 1, stat_font())
			y += 8
	if fade_alpha > 0.0:
		draw_rect(Rect2(-4, -4, 328, 188), Color(colors["0"], clampf(fade_alpha, 0.0, 1.0)))


## Same teal frame, corner gems, title face and body font as the controls/dialogue cards.
func _draw_training_cards() -> void:
	var lesson: String = String(training.get("hint", ""))
	var titles: Dictionary = {"dash": "Dash", "attack": "Attack", "parry": "Parry gold", "dodge": "Dodge red"}
	var details: Dictionary = {"dash": "Dash once in the training yard.", "attack": "Hit the post: %d / %d" % [training.get("hits", 0), training.get("hits_needed", 3)], "parry": "Press just before the gold hit.", "dodge": "Dash through the red hit."}
	var actions: Dictionary = {"dash": "arena_dash", "attack": "arena_attack", "parry": "arena_parry", "dodge": "arena_dash"}
	var feedback: bool = not training_feedback.is_empty() and toast_alpha > 0.0
	if titles.has(lesson) or (bool(training.get("done", false)) and feedback):
		UiPanel.draw_panel(self, Rect2(6, 6, 184, 29), &"info", colors)
		lettering(Vector2(14, 12), titles.get(lesson, "Training complete"), colors["u"], 1, menu_font(), 8)
		lettering(Vector2(14, 25), training_feedback if feedback else String(details.get(lesson, "All four lessons learned.")), colors["1"], 1, ui_font(), 8)
		var key: String = Bindings.action_label(actions[lesson]) if actions.has(lesson) else "Done"
		var width: float = text_width(key, 1, ui_font(), 8) + 10
		var badge: Rect2 = Rect2(182 - width, 10, width, 12)
		draw_rect(badge, colors["8"])
		UiPanel.outline(self, badge, colors["t"])
		lettering(badge.position + Vector2(5, 3), key, colors["1"], 1, ui_font(), 8)
	UiPanel.draw_panel(self, Rect2(180, 145, 134, 29), &"info", colors)
	var checks: Dictionary = training.get("lessons", {})
	var names: Array[String] = ["dash", "attack", "parry", "dodge"]
	for i: int in names.size():
		var name: String = names[i]
		var done: bool = bool(checks.get(name, false))
		var x: float = 188 + (i % 2) * 63
		var y: float = 152 + (i / 2) * 11
		var tone: Color = colors["u"] if done else (colors["1"] if name == lesson else colors["o"])
		UiPanel.outline(self, Rect2(x, y, 5, 5), tone)
		if done:
			draw_polyline(PackedVector2Array([Vector2(x + 1, y + 2), Vector2(x + 2, y + 3), Vector2(x + 4, y)]), tone)
		lettering(Vector2(x + 8, y), name, tone, 1, ui_font(), 8)
		if name == lesson:
			draw_rect(Rect2(x + 8, y + 7, 40, 1), colors["t"])
