extends Node2D
## Original 3x5 bitmap lettering, drawn on integer pixels; no external font assets.
const Tuning := preload("res://core/tuning.gd")
const Snapshots := preload("res://core/snapshots.gd")
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var debug_enabled: bool = false
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
	" ": "000000000000000",
}

func lettering(at: Vector2, text: String, color: Color, scale_px: int = 1) -> void:
	var cursor: Vector2 = at.round()
	for character: String in text.to_upper():
		var bits: String = GLYPHS.get(character, GLYPHS["?"])
		for index: int in range(15):
			if bits[index] == "1":
				draw_rect(Rect2(cursor + Vector2(index % 3, floori(index / 3.0)) * scale_px, Vector2.ONE * scale_px), color)
		cursor.x += 4 * scale_px

func outlined(at: Vector2, text: String, color: Color, outline: Color, scale_px: int = 1) -> void:
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		lettering(at + offset, text, outline, scale_px)
	lettering(at, text, color, scale_px)

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

func prepare_portrait() -> void:
	if portrait_mask != null or portrait_atlas == null or portrait_frame.is_empty():
		return
	var image: Image = portrait_atlas.get_image().get_region(Rect2i(int(portrait_frame["x"]), int(portrait_frame["y"]), int(portrait_frame["w"]), int(portrait_frame["h"])))
	image.convert(Image.FORMAT_RGBA8)
	image.resize(44, 44, Image.INTERPOLATE_NEAREST)
	for y: int in range(44):
		for x: int in range(44):
			if Vector2(x - 21.5, y - 21.5).length_squared() > 22.0 * 22.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	portrait_mask = ImageTexture.create_from_image(image)

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
		lettering(Vector2(8, 134), "TICK %d" % snapshot.tick, colors["p"])
		lettering(Vector2(8, 141), "PLAYER " + String(snapshot.player.state), colors["p"])
	if snapshot.result != &"playing":
		draw_rect(Rect2(60, 67, 200, 43), colors["0"])
		var title: String = "VICTORY" if snapshot.result == &"victory" else "DEFEAT"
		lettering(Vector2(160 - title.length() * 4, 75), title, colors["1"], 2)
		outlined(Vector2(136, 96), "R TO RESTART", colors["o"], colors["0"])

## Fixed small footprint; all meter amounts are read directly from the HUD snapshot.
func _draw_profile(h: Snapshots.HudSnapshot) -> void:
	prepare_portrait()
	if portrait_mask != null:
		draw_texture_rect(portrait_mask, Rect2(11, 12, 25, 25), false)
	bar(Vector2(47, 20), 68, h.player_hp, h.player_max_hp, colors["t"], 5, float(health_ghosts.get("player", h.player_hp)))
	bar(Vector2(47, 33), 66, h.edge, h.edge_max, colors["v"], 2)
	bar(Vector2(47, 40), 66, dash_fraction(h), 1.0, colors["n"], 2)
	ui("ui_profile", Rect2(2, 2, 125, 48))
	ui("ui_icon_edge_1", Rect2(39, 31, 6, 6))
	ui("ui_icon_dash_1", Rect2(39, 38, 6, 6))
	ui("ui_icon_parry_1", Rect2(116, 32, 7, 7))
	var hp: String = "%d/%d" % [h.player_hp, h.player_max_hp]
	outlined(Vector2(81 - hp.length() * 2, 20), hp, colors["1"], colors["0"])

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
	ui("ui_weapon_sword_1", weapon_rect())
	outlined(weapon_rect().get_center() + Vector2(-10, 14), "SWORD", colors["j"], colors["0"])
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
			draw_rect(Rect2(centre + Vector2(-seconds.length() * 2 - 1, -3), Vector2(seconds.length() * 4 + 1, 7)), colors["0"])
			lettering(centre + Vector2(-seconds.length() * 2, -2), seconds, colors["p"])
		var badge: Vector2 = socket.position + Vector2(-2, 16)
		draw_rect(Rect2(badge - Vector2.ONE, Vector2(7, 7)), colors["0"])
		lettering(badge, row["key"], colors["1"])
		var cost: String = "%dE" % int(row["cost"])
		outlined(centre + Vector2(-cost.length() * 2, 14), cost, colors["v"] if h.edge >= float(row["cost"]) else colors["i"], colors["0"])
		if socket.has_point(get_local_mouse_position()):
			_draw_aspect_hint(row)
	if h.retaliate_ticks_left > 0:
		outlined(Vector2(216, 91), "Z BREAKING EDGE READY", colors["x"], colors["0"])
		var ring: PackedVector2Array = PackedVector2Array()
		for point: int in range(33):
			ring.append((sockets[0].get_center() + Vector2.from_angle(TAU * point / 32.0) * 12.0).round())
		draw_polyline(ring, colors["x"], 1.0, false)

func _draw_aspect_hint(row: Dictionary) -> void:
	var at: Vector2 = Vector2(163, 68)
	draw_rect(Rect2(at - Vector2(3, 3), Vector2(154, 27)), colors["0"])
	lettering(at, "%s %s" % [row["key"], row["name"]], colors["1"])
	lettering(at + Vector2(0, 8), "%d EDGE" % int(row["cost"]), colors["v"])
	lettering(at + Vector2(0, 16), row["status"], colors["o"])
