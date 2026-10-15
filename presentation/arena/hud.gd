extends Node2D
## Original 3x5 bitmap lettering, drawn on integer pixels; no external font assets.
const Snapshots := preload("res://core/snapshots.gd")
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var debug_enabled: bool = false
var counter_max: int = 1
var portrait_atlas: Texture2D
var portrait_frame: Dictionary = {}
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

func bar(at: Vector2, width: int, value: float, maximum: float, color: Color, height: int = 3) -> void:
	draw_rect(Rect2(at - Vector2.ONE, Vector2(width + 2, height + 2)), colors["0"])
	draw_rect(Rect2(at, Vector2(width, height)), colors["f"])
	draw_rect(Rect2(at, Vector2(floori(width * clampf(value / maxf(maximum, 1.0), 0.0, 1.0)), height)), color)

func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	var h: Snapshots.HudSnapshot = snapshot.hud
	var center: Vector2 = Vector2(25, 25)
	draw_circle(center, 23, colors["0"], true, -1.0, false)
	if portrait_atlas != null and not portrait_frame.is_empty():
		draw_texture_rect_region(portrait_atlas, Rect2(13, 13, 24, 24), Rect2(portrait_frame["x"], portrait_frame["y"], 24, 24))
	ring_gauge(center, 21, h.player_hp, h.player_max_hp, colors["u"])
	ring_gauge(center, 18, h.edge, h.edge_max, colors["v"])
	ring_gauge(center, 15, h.dash_cooldown_max - h.dash_cooldown_ticks, h.dash_cooldown_max, colors["n"])
	lettering(Vector2(5, 51), "%d/%d" % [h.player_hp, h.player_max_hp], colors["1"])
	if not snapshot.entities.is_empty():
		var boss: Snapshots.EntitySnapshot = snapshot.entities[0]
		var panel: Rect2 = boss_panel(boss.position, h.counter_window_ticks_left > 0)
		draw_rect(panel, colors["0"])
		if boss.state == &"posture_broken":
			draw_rect(panel.grow(1), colors["p"], false, 1.0)
		lettering(panel.position + Vector2(4, 3), "MOSSBOUND COLOSSUS", colors["1"])
		bar(panel.position + Vector2(4, 10), 72, h.boss_hp, h.boss_max_hp, colors["7"], 3)
		lettering(panel.position + Vector2(4, 15), "POSTURE", colors["o"])
		bar(panel.position + Vector2(4, 22), 72, h.boss_posture, h.boss_posture_max, colors["v"], 2)
		if h.counter_window_ticks_left > 0:
			lettering(panel.position + Vector2(4, 28), "COUNTER - ATTACK", colors["p"])
			bar(panel.position + Vector2(4, 35), 72, h.counter_window_ticks_left, counter_max, colors["o"], 2)
	draw_rect(Rect2(4, 167, 312, 10), colors["0"])
	lettering(Vector2(8, 169), "LMB HIT  SPACE PARRY  SHIFT DASH  F1 DEBUG", colors["j"])
	if debug_enabled:
		draw_rect(Rect2(5, 131, 175, 16), colors["0"])
		lettering(Vector2(8, 134), "TICK %d" % snapshot.tick, colors["p"])
		lettering(Vector2(8, 141), "PLAYER " + String(snapshot.player.state), colors["p"])
	if snapshot.result != &"playing":
		draw_rect(Rect2(60, 67, 200, 43), colors["0"])
		var title: String = "VICTORY" if snapshot.result == &"victory" else "DEFEAT"
		lettering(Vector2(160 - title.length() * 4, 75), title, colors["1"], 2)
		lettering(Vector2(124, 96), "PRESS R TO RESTART", colors["o"])

## Pixel raster annuli: top origin, clockwise, no smoothed line edges.
func ring_gauge(center: Vector2, radius: int, value: float, maximum: float, color: Color) -> void:
	var fraction: float = clampf(value / maxf(1.0, maximum), 0.0, 1.0)
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var distance: float = Vector2(x, y).length()
			if distance <= radius and distance > radius - 2:
				var angle: float = fposmod(atan2(float(x), float(-y)), TAU)
				draw_rect(Rect2(center + Vector2(x, y), Vector2.ONE), color if fraction >= 1.0 or angle < fraction * TAU else colors["f"])

static func boss_panel(at: Vector2, counter: bool) -> Rect2:
	var height: float = 40.0 if counter else 27.0
	return Rect2(Vector2(clampf(at.x - 40, 2, 238), clampf(at.y - 48 - height, 2, 164 - height)).round(), Vector2(80, height))
