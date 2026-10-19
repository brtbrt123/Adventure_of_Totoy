extends Node2D
## Original 3x5 bitmap lettering, drawn on integer pixels; no external font assets.
const Tuning := preload("res://core/tuning.gd")
const Snapshots := preload("res://core/snapshots.gd")
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var debug_enabled: bool = false
# Extra result-screen lines (the arena fills them when progress is saved).
var result_lines: Array[String] = []
var result_hint: String = ""
# Snapshot weapon identity selects the matching blade glyph.
var weapon_icon_key: String = "ui_weapon_totoy_blade_1"
var counter_max: int = 1
var portrait_atlas: Texture2D
var portrait_frame: Dictionary = {}
var profile_frame: Dictionary = {}
var ui_frames: Dictionary = {}
var portrait_mask: Texture2D
var health_tick: int = -1
var health_ghosts: Dictionary = {}
var health_values: Dictionary = {}
var health_delays: Dictionary = {}
var head_position: Vector2 = Vector2.ZERO
var head_tick: int = -1
var head_id: int = -1
var head_ground: Vector2 = Vector2.ZERO
const GLYPHS: Dictionary = {
	"0": "111101101101111",
	"1": "010110010010111",
	"2": "110001010100111",
	"3": "110001010001110",
	"4": "101101111001001",
	"5": "111100110001110",
	"6": "011100111101111",
	"7": "111001010010010",
	"8": "111101111101111",
	"9": "111101111001110",
	"A": "010101111101101",
	"B": "110101110101110",
	"C": "011100100100011",
	"D": "110101101101110",
	"E": "111100110100111",
	"F": "111100110100100",
	"G": "011100101101011",
	"H": "101101111101101",
	"I": "111010010010111",
	"J": "001001001101010",
	"K": "101101110101101",
	"L": "100100100100111",
	"M": "101111111101101",
	"N": "101111111111101",
	"O": "010101101101010",
	"P": "110101110100100",
	"Q": "010101101111011",
	"R": "110101110101101",
	"S": "011100010001110",
	"T": "111010010010010",
	"U": "101101101101111",
	"V": "101101101101010",
	"W": "101101111111101",
	"X": "101101010101101",
	"Y": "101101010010010",
	"Z": "111001010100111",
	":": "000010000010000",
	"/": "001001010100100",
	"-": "000000111000000",
	"_": "000000000000111",
	"?": "110001010000010",
	".": "000000000000010",
	",": "000000000010100",
	"'": "010010000000000",
	"(": "001010010010001",
	")": "100010010010100",
	"!": "010010010000010",
	">": "100010001010100",
	" ": "000000000000000",
}

## 3600 ticks -> "1:00.0".
static func format_ticks(ticks: int) -> String:
	var tenths: int = int(round(ticks / 6.0))
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]

## Text is a real font drawn at the window resolution (the project stretches the canvas, so a font size of 7
## "game pixels" is rendered with 28 screen pixels at the default 4x window): crisp at any size. The old
## 3x5 bitmap glyph table above is no longer used for drawing.
const FONT_PATH: String = "res://presentation/fonts/PixelifySans.ttf"
const FONT_SIZE: int = 9  # game pixels; the cap height is about 5-6 game pixels, like the old bitmap letters
const FONT_WEIGHT: int = 400  # Pixelify Sans has a weight axis of 400-700
static var _font: Font = null

## Pixelify Sans (OFL, see presentation/fonts/README.md); Godot's built-in font if that file is missing.
static func ui_font() -> Font:
	if _font == null:
		var variation: FontVariation = FontVariation.new()
		if ResourceLoader.exists(FONT_PATH):
			variation.base_font = load(FONT_PATH) as Font
			variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): FONT_WEIGHT}
		else:
			variation.base_font = ThemeDB.fallback_font
			variation.variation_embolden = 0.55
		_font = variation
	return _font

## Numbers and key letters use a clearer bold sans face: the pixel font's 0/O, 5/S, 3/8 and Z/2 are too alike at
## HUD size. Titles, menus, names and sentences use the pixel font.
const STAT_FONT_SIZE: int = 7
static var _stat_font: Font = null

static func stat_font() -> Font:
	if _stat_font == null:
		var bold: FontVariation = FontVariation.new()
		bold.base_font = ThemeDB.fallback_font
		bold.variation_embolden = 0.55
		_stat_font = bold
	return _stat_font

static func _size_for(font: Font, scale_px: int) -> int:
	return (STAT_FONT_SIZE if font == _stat_font and _stat_font != null else FONT_SIZE) * scale_px

## Width of `text` in game pixels at a size multiplier (`font` defaults to the pixel font).
static func text_width(text: String, scale_px: int = 1, font: Font = null) -> float:
	var face: Font = font if font != null else ui_font()
	return face.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, _size_for(face, scale_px)).x

## `at` is the top-left of the letters, as with the old bitmap text.
func lettering(at: Vector2, text: String, color: Color, scale_px: int = 1, font: Font = null) -> void:
	var face: Font = font if font != null else ui_font()
	draw_string(face, Vector2(at.x, at.y + 5.0 * scale_px), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, _size_for(face, scale_px), color)

func outlined(at: Vector2, text: String, color: Color, outline: Color, scale_px: int = 1, font: Font = null) -> void:
	var face: Font = font if font != null else ui_font()
	draw_string_outline(face, Vector2(at.x, at.y + 5.0 * scale_px), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, _size_for(face, scale_px), 2 * scale_px, outline)
	lettering(at, text, color, scale_px, font)

## Text centred on `center_x`.
func centered(center_x: float, y: float, text: String, color: Color, outline: Color, scale_px: int = 1, font: Font = null) -> void:
	outlined(Vector2(center_x - text_width(text, scale_px, font) * 0.5, y), text, color, outline, scale_px, font)

func track_health() -> void:
	if snapshot == null:
		return
	var reset: bool = health_tick < 0 or snapshot.tick < health_tick
	var elapsed: int = maxi(0, snapshot.tick - health_tick)
	for key: String in ["player", "boss"]:
		var value: float = snapshot.hud.player_hp if key == "player" else snapshot.hud.boss_hp
		if reset or not health_values.has(key) or value > float(health_values[key]):
			health_ghosts[key] = value
			health_delays[key] = 0
		elif value < float(health_values[key]):
			health_delays[key] = 18
		elif elapsed > 0:
			health_delays[key] = maxi(0, int(health_delays[key]) - elapsed)
			if int(health_delays[key]) == 0:
				health_ghosts[key] = move_toward(float(health_ghosts[key]), value, elapsed * 0.7)
		health_values[key] = value
	health_tick = snapshot.tick

func bar(at: Vector2, width: int, value: float, maximum: float, color: Color, height: int = 3, ghost: float = -1.0) -> void:
	draw_rect(Rect2(at - Vector2.ONE, Vector2(width + 2, height + 2)), colors["0"])
	draw_rect(Rect2(at, Vector2(width, height)), colors["e"])
	var amount: int = floori(width * clampf(value / maxf(maximum, 1.0), 0.0, 1.0))
	var trail: int = floori(width * clampf(ghost / maxf(maximum, 1.0), 0.0, 1.0))
	if trail > amount:
		draw_rect(Rect2(at + Vector2(amount, 0), Vector2(trail - amount, height)), colors["j"])
	if amount > 0:
		draw_rect(Rect2(at, Vector2(amount, height)), color)
		draw_line(at, at + Vector2(amount - 1, 0), colors["u"] if color == colors["t"] else colors["j"])
		if height > 2:
			draw_line(at + Vector2(0, height - 1), at + Vector2(amount - 1, height - 1), colors["f"])

## The round portrait is cut from the owner's original high-resolution portrait (not the 48 px palette copy), so
## it stays sharp when the HUD is drawn at the window resolution. It is a smooth-filtered sprite behind the
## frame; everything else in the HUD stays nearest-neighbour. Falls back to the palette portrait if the file is missing.
const PORTRAIT_SIZE: int = 200
const PORTRAIT_SOURCE: String = "res://art/reference/hero_portrait.jpg"
const PORTRAIT_CROP: Rect2i = Rect2i(330, 0, 1260, 1260)  # square around the head (the same crop import_reference.py uses)
var portrait_sprite: Sprite2D = null

func prepare_portrait() -> void:
	if portrait_mask != null:
		return
	var image: Image = null
	var source: Texture2D = load(PORTRAIT_SOURCE) as Texture2D if ResourceLoader.exists(PORTRAIT_SOURCE) else null
	if source != null:
		image = source.get_image().get_region(PORTRAIT_CROP)
		image.convert(Image.FORMAT_RGBA8)
		image.resize(PORTRAIT_SIZE, PORTRAIT_SIZE, Image.INTERPOLATE_LANCZOS)
	elif portrait_atlas != null and not portrait_frame.is_empty():
		image = portrait_atlas.get_image().get_region(Rect2i(int(portrait_frame["x"]), int(portrait_frame["y"]), int(portrait_frame["w"]), int(portrait_frame["h"])))
		image.convert(Image.FORMAT_RGBA8)
		image.resize(PORTRAIT_SIZE, PORTRAIT_SIZE, Image.INTERPOLATE_NEAREST)
	else:
		return
	var centre: float = (PORTRAIT_SIZE - 1) * 0.5
	var radius: float = PORTRAIT_SIZE * 0.5 - 1.0
	for y: int in range(PORTRAIT_SIZE):
		for x: int in range(PORTRAIT_SIZE):
			# a one pixel soft edge on the circle
			var coverage: float = clampf(radius - Vector2(x - centre, y - centre).length() + 0.5, 0.0, 1.0)
			var pixel: Color = image.get_pixel(x, y)
			image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, pixel.a * coverage))
	portrait_mask = ImageTexture.create_from_image(image)
	portrait_sprite = Sprite2D.new()
	portrait_sprite.texture = portrait_mask
	portrait_sprite.centered = false
	portrait_sprite.position = Vector2(11, 12)
	portrait_sprite.scale = Vector2.ONE * (25.0 / PORTRAIT_SIZE)
	portrait_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait_sprite.show_behind_parent = true
	add_child(portrait_sprite)

func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	var h: Snapshots.HudSnapshot = snapshot.hud
	_draw_profile(h)
	_draw_skills(h)
	if not snapshot.entities.is_empty():
		var boss: Snapshots.EntitySnapshot = snapshot.entities[0]
		var panel: Rect2 = boss_panel(head_position, h.counter_window_ticks_left > 0)
		ui("ui_boss", Rect2(panel.position + Vector2(0, 7), Vector2(104, 24)))
		outlined(panel.position + Vector2(18, 0), "MOSSBOUND COLOSSUS", colors["z"], colors["0"])
		bar(panel.position + Vector2(8, 18), 88, h.boss_hp, h.boss_max_hp, colors["7"], 3, float(health_ghosts.get("boss", h.boss_hp)))
		bar(panel.position + Vector2(20, 27), 64, h.boss_posture, h.boss_posture_max, colors["p"] if boss.state == &"posture_broken" else colors["v"], 2)
		if h.counter_window_ticks_left > 0:
			outlined(panel.position + Vector2(4, 33), "COUNTER - ATTACK", colors["p"], colors["0"])
			bar(panel.position + Vector2(4, 41), 88, h.counter_window_ticks_left, counter_max, colors["o"], 2)
	if debug_enabled:
		draw_rect(Rect2(5, 131, 175, 16), colors["0"])
		lettering(Vector2(8, 134), "TICK %d" % snapshot.tick, colors["p"], 1, stat_font())
		lettering(Vector2(8, 141), "PLAYER " + String(snapshot.player.state), colors["p"], 1, stat_font())
	if snapshot.result != &"playing":
		var extra: int = result_lines.size() + (1 if result_hint != "" else 0)
		draw_rect(Rect2(60, 67, 200, 43 + extra * 8), colors["0"])
		var title: String = "VICTORY" if snapshot.result == &"victory" else "DEFEAT"
		centered(160, 74, title, colors["1"], colors["0"], 2)
		centered(160, 96, "R TO RESTART", colors["o"], colors["0"])
		var line_y: int = 105
		for line: String in result_lines:
			centered(160, line_y, line, colors["1"], colors["0"], 1, stat_font())
			line_y += 8
		if result_hint != "":
			centered(160, line_y, result_hint, colors["o"], colors["0"])


## Fixed small footprint; all meter amounts are read directly from the HUD snapshot.
func _draw_profile(h: Snapshots.HudSnapshot) -> void:
	prepare_portrait()
	bar(Vector2(47, 20), 68, h.player_hp, h.player_max_hp, colors["t"], 5, float(health_ghosts.get("player", h.player_hp)))
	bar(Vector2(47, 33), 66, h.edge, h.edge_max, colors["v"], 2)
	bar(Vector2(47, 40), 66, dash_fraction(h), 1.0, colors["n"], 2)
	ui("ui_profile", Rect2(2, 2, 125, 48))
	ui("ui_icon_edge_1", Rect2(39, 31, 6, 6))
	ui("ui_icon_dash_1", Rect2(39, 38, 6, 6))
	ui("ui_icon_parry_1", Rect2(116, 32, 7, 7))
	var hp: String = "%d/%d" % [h.player_hp, h.player_max_hp]
	centered(81, 20, hp, colors["1"], colors["0"], 1, stat_font())

func ui(key: String, rect: Rect2) -> void:
	if portrait_atlas == null or not ui_frames.has(key):
		return
	var frame: Dictionary = ui_frames[key]
	draw_texture_rect_region(portrait_atlas, rect, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))

static func dash_fraction(h: Snapshots.HudSnapshot) -> float:
	if h.dash_cooldown_ticks <= 0:
		return 1.0
	return clampf(1.0 - float(h.dash_cooldown_ticks) / maxi(1, h.dash_cooldown_max), 0.0, 1.0)

func reset_head() -> void:
	health_tick = -1
	head_tick = -1
	head_id = -1

## Advance once per snapshot tick, never per draw call. Restart/teleport snaps cleanly.
func track_head(target: Vector2, tick: int, actor_id: int, ground: Vector2 = Vector2.ZERO) -> void:
	if head_tick < 0 or tick < head_tick or actor_id != head_id:
		head_position = target
	elif tick > head_tick:
		var elapsed: int = mini(tick - head_tick, 6)
		head_position += ground - head_ground
		head_position = head_position.lerp(target, 1.0 - pow(0.5, elapsed))
	head_ground = ground
	head_tick = tick
	head_id = actor_id

static func boss_panel(head: Vector2, counter: bool) -> Rect2:
	var height: float = 47.0 if counter else 33.0
	return Rect2(Vector2(clampf(head.x - 52, 2, 214), clampf(head.y - 4 - height, 2, 164 - height)).round(), Vector2(104, height))

## Display facts from HUD snapshots; these labels do not gate input or predict hits.
static func skill_rows(h: Snapshots.HudSnapshot) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var names: Array[String] = ["BREAKING EDGE", "GALE CUT", "MOON CLEAVE"]
	var keys: Array[String] = ["Z", "X", "C"]
	var costs: Array[float] = [Tuning.BREAKING_EDGE_EDGE_COST, Tuning.GALE_CUT_EDGE_COST, Tuning.MOON_CLEAVE_EDGE_COST]
	for slot: int in range(3):
		var left: int = h.skill_cooldown_ticks[slot]
		var status: String = "%dS" % ceili(left * Tuning.TICK_DT) if left > 0 else "CD READY"
		if slot == 0 and left <= 0:
			status = "PARRY WINDOW" if h.retaliate_ticks_left <= 0 else "READY"
		rows.append({"key": keys[slot], "name": names[slot], "cost": costs[slot], "cooldown": left, "status": status})
	return rows


## The owner's layout: three small Aspect sockets climbing around a larger weapon socket.
## Native sprite sizes keep the new HUD at integer scale.
static func aspect_rects() -> Array[Rect2]:
	return [Rect2(241, 147, 24, 24), Rect2(253, 116, 24, 24), Rect2(284, 100, 24, 24)]

static func weapon_rect() -> Rect2:
	return Rect2(269, 130, 48, 48)

static func cooldown_fraction(slot: int, h: Snapshots.HudSnapshot) -> float:
	var maximum: int = [1, Tuning.GALE_CUT_COOLDOWN_TICKS, Tuning.MOON_CLEAVE_COOLDOWN_TICKS][slot]
	return clampf(float(h.skill_cooldown_ticks[slot]) / maxi(1, maximum), 0.0, 1.0)

func _draw_skills(h: Snapshots.HudSnapshot) -> void:
	var rows: Array[Dictionary] = skill_rows(h)
	var sockets: Array[Rect2] = aspect_rects()
	var icons: Array[String] = ["ui_aspect_breaking_edge_1", "ui_aspect_gale_cut_1", "ui_aspect_moon_cleave_1"]
	ui("ui_weapon_frame_1", weapon_rect())
	ui(weapon_icon_key, Rect2(weapon_rect().position + Vector2(8, 8), Vector2(32, 32)))
	outlined(weapon_rect().get_center() + Vector2(-10, 14), "BLACK" if snapshot.player.weapon_id == Tuning.WEAPON_BLACK_KATANA else "SWORD", colors["j"], colors["0"])
	_draw_weapon_active()
	for slot: int in range(3):
		var row: Dictionary = rows[slot]
		var socket: Rect2 = sockets[slot]
		var centre: Vector2 = socket.get_center()
		ui(icons[slot], socket)
		if int(row["cooldown"]) > 0:
			# Snapshot-only countdown. The core still accepts or rejects every press.
			var arc: PackedVector2Array = PackedVector2Array()
			var fraction: float = cooldown_fraction(slot, h)
			for point: int in range(33):
				arc.append((centre + Vector2.from_angle(-PI * 0.5 + TAU * fraction * point / 32.0) * 11.0).round())
			draw_polyline(arc, colors["o"], 1.0, false)
			var seconds: String = str(ceili(int(row["cooldown"]) * Tuning.TICK_DT))
			var seconds_width: float = text_width(seconds, 1, stat_font())
			draw_rect(Rect2(centre + Vector2(-seconds_width * 0.5 - 1, -3), Vector2(seconds_width + 2, 7)), colors["0"])
			lettering(centre + Vector2(-seconds_width * 0.5, -2), seconds, colors["p"], 1, stat_font())
		var badge: Vector2 = socket.position + Vector2(-2, 16)
		draw_rect(Rect2(badge - Vector2.ONE, Vector2(7, 7)), colors["0"])
		lettering(badge, row["key"], colors["1"], 1, stat_font())
		var cost: String = "%dE" % int(row["cost"])
		centered(centre.x, centre.y + 14, cost, colors["v"] if h.edge >= float(row["cost"]) else colors["i"], colors["0"], 1, stat_font())
		if socket.has_point(get_local_mouse_position()):
			_draw_aspect_hint(row)
	if h.retaliate_ticks_left > 0:
		outlined(Vector2(216, 91), "Z BREAKING EDGE READY", colors["x"], colors["0"], 1, stat_font())
		var ring: PackedVector2Array = PackedVector2Array()
		for point: int in range(33):
			ring.append((sockets[0].get_center() + Vector2.from_angle(TAU * point / 32.0) * 12.0).round())
		draw_polyline(ring, colors["x"], 1.0, false)

func _draw_aspect_hint(row: Dictionary) -> void:
	var at: Vector2 = Vector2(163, 68)
	draw_rect(Rect2(at - Vector2(3, 3), Vector2(154, 27)), colors["0"])
	lettering(at, "%s %s" % [row["key"], row["name"]], colors["1"], 1, stat_font())
	lettering(at + Vector2(0, 8), "%d EDGE" % int(row["cost"]), colors["v"], 1, stat_font())
	lettering(at + Vector2(0, 16), row["status"], colors["o"], 1, stat_font())

static func weapon_status(snap: Snapshots.GameSnapshot) -> Dictionary:
	var h: Snapshots.HudSnapshot = snap.hud
	if h.weapon_buff_duration <= 0:
		return {}
	return {"active": snap.player.weapon_buff_active, "remaining": ceili(snap.player.weapon_buff_ticks_left * Tuning.TICK_DT), "cooldown": ceili(h.weapon_buff_cooldown_ticks * Tuning.TICK_DT), "cost": h.weapon_buff_edge_cost, "duration_fraction": clampf(float(snap.player.weapon_buff_ticks_left) / h.weapon_buff_duration, 0.0, 1.0), "cooldown_fraction": clampf(float(h.weapon_buff_cooldown_ticks) / maxi(1, h.weapon_buff_cooldown_max), 0.0, 1.0)}

func _draw_weapon_active() -> void:
	var data: Dictionary = weapon_status(snapshot)
	if data.is_empty():
		return
	var at: Vector2 = Vector2(181, 153)
	draw_rect(Rect2(at - Vector2(2, 2), Vector2(55, 24)), colors["0"])
	lettering(at, "RMB %dE" % int(data["cost"]), colors["v"], 1, stat_font())
	lettering(at + Vector2(0, 8), "FORM %dS" % int(data["remaining"]) if bool(data["active"]) else "FORM OFF", colors["p"] if bool(data["active"]) else colors["j"], 1, stat_font())
	lettering(at + Vector2(0, 16), "CD %dS" % int(data["cooldown"]) if int(data["cooldown"]) > 0 else "CD READY", colors["o"], 1, stat_font())
	for active: bool in [false, true]:
		var fraction: float = float(data["duration_fraction" if active else "cooldown_fraction"])
		if fraction <= 0.0:
			continue
		var arc: PackedVector2Array = PackedVector2Array()
		for point: int in range(33):
			arc.append((weapon_rect().get_center() + Vector2.from_angle(-PI * 0.5 + TAU * fraction * point / 32.0) * (21.0 if active else 24.0)).round())
		draw_polyline(arc, colors["v"] if active else colors["o"], 1.0, false)
