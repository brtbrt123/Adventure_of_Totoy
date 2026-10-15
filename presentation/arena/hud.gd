extends Node2D
## Original 3x5 bitmap lettering, drawn on integer pixels; no external font assets.
const Snapshots := preload("res://core/snapshots.gd")
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var debug_enabled: bool = false
var counter_max: int = 1
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
	draw_rect(Rect2(4, 3, 312, 25), Color(colors["0"], 0.92))
	lettering(Vector2(8, 6), "MOSSBOUND COLOSSUS", colors["1"])
	bar(Vector2(8, 14), 304, h.boss_hp, h.boss_max_hp, colors["7"], 4)
	lettering(Vector2(8, 21), "POSTURE", colors["j"])
	bar(Vector2(41, 22), 271, h.boss_posture, h.boss_posture_max, colors["v"], 2)
	draw_rect(Rect2(4, 150, 312, 28), Color(colors["0"], 0.95))
	lettering(Vector2(8, 153), "HP %d/%d" % [h.player_hp, h.player_max_hp], colors["1"])
	bar(Vector2(8, 161), 92, h.player_hp, h.player_max_hp, colors["u"])
	lettering(Vector2(112, 153), "EDGE", colors["1"])
	bar(Vector2(112, 161), 92, h.edge, h.edge_max, colors["v"])
	lettering(Vector2(216, 153), "DASH" + (" READY" if h.dash_cooldown_ticks == 0 else ""), colors["o"])
	bar(Vector2(216, 161), 92, h.dash_cooldown_max - h.dash_cooldown_ticks, h.dash_cooldown_max, colors["n"])
	lettering(Vector2(8, 169), "J/Z HIT  K/X PARRY  SPACE/L DASH  F1 DEBUG", colors["j"])
	if h.counter_window_ticks_left > 0:
		draw_rect(Rect2(104, 30, 112, 16), colors["0"])
		lettering(Vector2(112, 33), "COUNTER OPEN - ATTACK", colors["p"])
		bar(Vector2(112, 41), 96, h.counter_window_ticks_left, counter_max, colors["p"], 2)
	if debug_enabled:
		draw_rect(Rect2(5, 131, 175, 16), colors["0"])
		lettering(Vector2(8, 134), "TICK %d" % snapshot.tick, colors["p"])
		lettering(Vector2(8, 141), "PLAYER " + String(snapshot.player.state), colors["p"])
	if snapshot.result != &"playing":
		draw_rect(Rect2(60, 67, 200, 43), colors["0"])
		var title: String = "VICTORY" if snapshot.result == &"victory" else "DEFEAT"
		lettering(Vector2(160 - title.length() * 4, 75), title, colors["1"], 2)
		lettering(Vector2(124, 96), "PRESS R TO RESTART", colors["o"])
