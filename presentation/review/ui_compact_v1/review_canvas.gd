extends "res://presentation/arena/hud.gd"
## Isolated review drawing. No live UI or gameplay code uses this script.
const ExploreCore := preload("res://core/explore_core.gd")
var state: ExploreCore.ExploreSnapshot
var mode: String = "training"
var small_icons: Dictionary = {}
var portraits: Texture2D
var portrait_frames: Dictionary = {}
var checks: Array[String] = []
var text_checks: int = 0
var hero_key: String = ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portraits = load("res://art/reference/chapter1_characters_v2/portraits_v2.png") as Texture2D
	portrait_frames = JSON.parse_string(FileAccess.get_file_as_string("res://art/reference/chapter1_characters_v2/portraits_v2.json"))["frames"]

func txt(at: Vector2, value: String, size: int = 8, tone: String = "1", max_width: float = 999.0) -> void:
	var width: float = ui_font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_checks += 1
	if width > max_width + 0.1:
		checks.append("%s: '%s' width %.1f > %.1f" % [mode, value, width, max_width])
	draw_string(ui_font(), at + Vector2(0, size * 0.78), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colors[tone])

func title(at: Vector2, value: String, size: int = 10, tone: String = "1") -> void:
	draw_string(menu_font(), at + Vector2(0, size * 0.78), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colors[tone])

func frame(rect: Rect2, accent: String = "t", fill: String = "0") -> void:
	draw_rect(rect, colors[fill])
	UiPanel.outline(self, rect, colors["0"])
	UiPanel.outline(self, rect.grow(-1), colors[accent])
	draw_line(rect.position + Vector2(3, 3), Vector2(rect.end.x - 4, rect.position.y + 3), colors["f"])
	for corner: Vector2 in [rect.position + Vector2(1, 1), Vector2(rect.end.x - 2, rect.position.y + 1)]:
		draw_rect(Rect2(corner, Vector2.ONE), colors["u" if accent == "t" else "d"])

func icon(key: String, at: Vector2, size: int = 16, muted: bool = false) -> void:
	var cache_key: String = key + str(size)
	if not small_icons.has(cache_key) and ui_frames.has(key):
		var f: Dictionary = ui_frames[key]
		var source: Image = portrait_atlas.get_image().get_region(Rect2i(f["x"], f["y"], f["w"], f["h"]))
		# Preview-only resampling once into an integer native raster, not fractional canvas scaling.
		source.resize(size, size, Image.INTERPOLATE_NEAREST)
		small_icons[cache_key] = ImageTexture.create_from_image(source)
	if small_icons.has(cache_key):
		draw_texture(small_icons[cache_key], at, Color(0.45, 0.45, 0.45) if muted else Color.WHITE)

func lock(at: Vector2) -> void:
	UiPanel.outline(self, Rect2(at + Vector2(2, 0), Vector2(4, 5)), colors["h"])
	draw_rect(Rect2(at + Vector2(1, 4), Vector2(6, 5)), colors["b"])
	draw_rect(Rect2(at + Vector2(4, 6), Vector2(1, 2)), colors["0"])

func portrait(key: String, at: Vector2, size: int = 32) -> void:
	var f: Dictionary = portrait_frames[key]
	var cache_key: String = key + str(size)
	if not small_icons.has(cache_key):
		var source: Image = portraits.get_image().get_region(Rect2i(f["x"], f["y"], f["w"], f["h"]))
		source.resize(size, size, Image.INTERPOLATE_NEAREST)
		small_icons[cache_key] = ImageTexture.create_from_image(source)
	draw_texture(small_icons[cache_key], at)

func wrapped_rows(text: String, width: float, size: int = 9) -> Array[String]:
	var result: Array[String] = []
	var row: String = ""
	for word: String in text.split(" "):
		var next: String = word if row.is_empty() else row + " " + word
		if ui_font().get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not row.is_empty():
			result.append(row)
			row = word
		else: row = next
	result.append(row)
	return result

func task(training: bool = false) -> void:
	var lines: Array[String] = wrapped_rows(str(state.objective.get("text", "Explore the woodland.")), 142, 8)
	var h: int = 20 + lines.size() * 9 + (8 if training else 0)
	frame(Rect2(7, 7, 158, h))
	txt(Vector2(14, 13), "TRAINING  2 / 4" if training else "CURRENT TASK", 7, "u")
	for i: int in lines.size(): txt(Vector2(14, 24 + i * 9), lines[i], 8, "1", 142)
	if training:
		txt(Vector2(14, h - 3), "SHIFT  Dash", 7, "o")
		for i: int in 4:
			draw_rect(Rect2(126 + i * 7, h + 1, 4, 2), colors["u" if i == 0 else ("1" if i == 1 else "f")])

func slot(at: Vector2, key: String, value: Dictionary, is_item: bool) -> void:
	frame(Rect2(at, Vector2(20, 22)), "b")
	var unlocked: bool = bool(value.get("unlocked", false))
	if not unlocked: lock(at + Vector2(6, 4))
	elif is_item: icon("hud_copper_herb", at + Vector2(3, 2), 14)
	else: icon(aspect_icon(StringName(value.get("aspect", &"sprint"))), at + Vector2(2, 2), 16)
	txt(at + Vector2(2, 16), key, 6, "1" if unlocked else "h")
	if is_item and unlocked: txt(at + Vector2(13, 16), str(value.get("count", 0)), 6, "1")

func hud() -> void:
	frame(Rect2(7, 151, 306, 24), "b")
	icon("ui_weapon_totoy_blade_1", Vector2(12, 154), 16, not state.armed)
	if not state.armed: lock(Vector2(17, 158))
	txt(Vector2(34, 154), "%d / %d" % [state.hero.hp, state.hero.max_hp], 7, "1")
	bar(Vector2(34, 163), 76, state.hero.hp, state.hero.max_hp, colors["t"], 3)
	bar(Vector2(34, 170), 44, 0, 1, colors["v"], 1)
	txt(Vector2(53, 166), "--", 6, "h")
	bar(Vector2(86, 170), 24, 1 if bool(state.unlocked.get("dash", false)) else 0, 1, colors["o"], 1)
	if not bool(state.unlocked.get("dash", false)): lock(Vector2(116, 158))
	else: txt(Vector2(117, 160), "DASH", 6, "o")
	for i: int in 2: slot(Vector2(148 + i * 22, 152), str(i + 1), state.item_slots[i], true)
	for i: int in 3: slot(Vector2(199 + i * 22, 152), ["Z", "X", "C"][i], state.aspect_slots[i], false)
	frame(Rect2(272, 156, 34, 14))
	txt(Vector2(278, 160), "TAB" + (" !" if state.stat_points_unspent > 0 else ""), 7, "u")
	# EXP shares the bottom edge; no tall left-side frame obscures the approach.
	var ratio: float = float(state.exp) / maxi(1, state.exp_to_next)
	draw_rect(Rect2(9, 176, 302, 2), colors["0"])
	draw_rect(Rect2(9, 176, floori(302 * ratio), 1), colors["u"])
	txt(Vector2(12, 140), "Lv %d" % state.level, 7, "1")

func dialogue() -> void:
	frame(Rect2(12, 120, 296, 54))
	portrait("portrait_mira_neutral", Vector2(19, 133), 32)
	title(Vector2(60, 128), "MIRA", 9, "u")
	var line: String = "You are carrying a beacon key. May I see it? Careful, it is cracked straight through."
	var lines: Array[String] = wrapped_rows(line, 236, 9)
	for i: int in lines.size(): txt(Vector2(60, 142 + i * 10), lines[i], 9, "1", 236)
	txt(Vector2(216, 165), "ENTER Next   ESC Skip", 7, "o")

func welcome() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color(colors["0"], 0.32))
	frame(Rect2(60, 60, 200, 60))
	title(Vector2(74, 71), "WELCOME TO LANTERNFEN", 10)
	txt(Vector2(74, 91), "Find Mira by the gate to begin.", 9, "u", 172)
	txt(Vector2(194, 108), "ENTER Begin", 7, "u")

func notice(level: bool = false) -> void:
	frame(Rect2(207, 24, 106, 30))
	if level:
		title(Vector2(216, 30), "LEVEL %d" % state.level, 10)
		txt(Vector2(216, 43), "+2 stat points  ·  TAB", 8, "u", 91)
	else:
		icon("hud_copper_herb", Vector2(214, 31), 16)
		txt(Vector2(236, 30), "RECEIVED", 7, "u")
		txt(Vector2(236, 41), "Herb  ×2", 9, "1", 68)

func menu_shell(selected: String) -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color(colors["0"], 0.58))
	frame(Rect2(22, 19, 276, 145))
	title(Vector2(35, 29), "TOTOY", 13)
	txt(Vector2(94, 33), "Waykeeper · Lv %d" % state.level, 8, "o")
	txt(Vector2(220, 33), "%d points available" % state.stat_points_unspent, 8, "u", 68)
	for i: int in 3:
		var name: String = ["STATS", "ASPECTS", "BAG"][i]
		var x: int = 35 + i * 57
		txt(Vector2(x, 49), name, 8, "1" if selected == name else "j")
		if selected == name: draw_rect(Rect2(x, 59, 45, 1), colors["u"])
	txt(Vector2(35, 151), "Q / E Tabs", 7, "j")
	txt(Vector2(230, 151), "TAB / ESC Close", 7, "j")

func stats() -> void:
	menu_shell("STATS")
	if ui_frames.has(hero_key):
		var f: Dictionary = ui_frames[hero_key]
		draw_texture_rect_region(portrait_atlas, Rect2(65 - int(f["w"]) / 2, 111 - int(f["h"]), f["w"], f["h"]), Rect2(f["x"], f["y"], f["w"], f["h"]))
	txt(Vector2(40, 116), "HP  %d" % state.hero.max_hp, 9, "1")
	txt(Vector2(40, 129), String(state.hero.weapon_id).replace("_", " ").capitalize(), 8, "o")
	draw_rect(Rect2(104, 68, 1, 72), colors["f"])
	var names: Array[String] = ["Vitality", "Might", "Agility"]
	var keys: Array[StringName] = [&"vitality", &"might", &"agility"]
	var details: Array[String] = ["+6 max health / point", "+3% damage / point", "Faster walk · shorter dash cooldown"]
	for i: int in 3:
		var y: int = 69 + i * 23
		txt(Vector2(115, y), names[i], 9, "1")
		txt(Vector2(228, y), "%d / %d" % [state.stats.get(keys[i], 0), state.stat_caps.get(keys[i], 10)], 8, "u")
		txt(Vector2(115, y + 11), details[i], 7, "j", 142)
		frame(Rect2(265, y - 1, 19, 17))
		txt(Vector2(271, y + 3), "+", 10, "u")
	frame(Rect2(221, 138, 63, 12))
	txt(Vector2(234, 141), "Respec", 7, "u")
	txt(Vector2(115, 141), "Free in Lanternfen", 7, "j", 99)

func aspects() -> void:
	menu_shell("ASPECTS")
	frame(Rect2(35, 68, 104, 25))
	icon(aspect_icon(&"sprint"), Vector2(39, 72), 16)
	txt(Vector2(60, 72), "Sprint", 9)
	txt(Vector2(60, 83), "Owned · Equipped Z", 7, "u", 74)
	txt(Vector2(36, 101), "NOT YET FOUND", 7, "j")
	var locked: Array[StringName] = [&"breaking_edge", &"gale_cut", &"moon_cleave", &"spirit_lantern", &"phantom_cut", &"echo_step", &"stone_ward"]
	for i: int in locked.size():
		var at: Vector2 = Vector2(36 + (i % 4) * 25, 113 + int(i / 4) * 19)
		icon(aspect_icon(locked[i]), at, 16, true)
		lock(at + Vector2(10, 8))
	draw_rect(Rect2(148, 68, 1, 73), colors["f"])
	title(Vector2(159, 71), "SPRINT", 11)
	txt(Vector2(159, 88), "Move 2× faster for 3 seconds.", 8, "1", 126)
	txt(Vector2(159, 101), "20 Edge  ·  12s cooldown", 8, "o", 126)
	txt(Vector2(159, 116), "ASPECT SOCKETS", 7, "j")
	for i: int in 3: slot(Vector2(159 + i * 23, 127), ["Z", "X", "C"][i], state.aspect_slots[i], false)
	txt(Vector2(234, 130), "1 of 3", 8, "u")
	txt(Vector2(234, 140), "unlocked", 7, "j")

func bag() -> void:
	menu_shell("BAG")
	for i: int in 8:
		frame(Rect2(36 + (i % 4) * 27, 72 + int(i / 4) * 28, 24, 24), "t" if i == 1 else "f")
	icon("ui_weapon_totoy_blade_1", Vector2(40, 76), 16)
	icon("hud_copper_herb", Vector2(67, 76), 16)
	txt(Vector2(79, 87), str(state.inventory.get(&"herb", 0)), 7, "1")
	txt(Vector2(36, 132), "Katana equipped", 8, "o")
	draw_rect(Rect2(150, 68, 1, 74), colors["f"])
	title(Vector2(163, 73), "HERB", 11)
	txt(Vector2(163, 91), "%d carried" % state.inventory.get(&"herb", 0), 9, "u")
	txt(Vector2(163, 106), "Use from item slot 1.", 8, "1", 122)
	frame(Rect2(163, 124, 120, 19))
	txt(Vector2(172, 130), "1   Quick slot assigned", 8, "o", 104)

func _draw() -> void:
	if state == null or colors.is_empty(): return
	if mode == "stats": stats()
	elif mode == "aspects": aspects()
	elif mode == "bag": bag()
	elif mode == "dialogue": dialogue()
	elif mode == "welcome": welcome()
	else:
		if mode == "training": task(true)
		elif not state.objective.is_empty(): task()
		if not state.encounters.is_empty(): hud()
		else:
			frame(Rect2(278, 159, 34, 14))
			txt(Vector2(284, 163), "TAB" + (" !" if state.stat_points_unspent > 0 else ""), 7, "u")
		if mode == "item": notice()
		elif mode == "level": notice(true)
	# This badge is review furniture, never proposed runtime HUD.
	draw_rect(Rect2(242, 4, 74, 10), colors["0"])
	txt(Vector2(246, 6), "REVIEW · NOT INSTALLED", 6, "o", 68)
