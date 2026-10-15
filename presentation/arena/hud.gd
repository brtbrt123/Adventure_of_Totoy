extends Node2D
## Original 3x5 bitmap lettering, drawn on integer pixels; no external font assets.
const Snapshots := preload("res://core/snapshots.gd")
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var debug_enabled: bool = false
var counter_max: int = 1
var portrait_atlas: Texture2D
var portrait_frame: Dictionary = {}
var profile_frame: Dictionary = {}
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

func bar(at: Vector2, width: int, value: float, maximum: float, color: Color, height: int = 3) -> void:
	draw_rect(Rect2(at - Vector2.ONE, Vector2(width + 2, height + 2)), colors["0"])
	draw_rect(Rect2(at, Vector2(width, height)), colors["f"])
	draw_rect(Rect2(at, Vector2(floori(width * clampf(value / maxf(maximum, 1.0), 0.0, 1.0)), height)), color)

func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	var h: Snapshots.HudSnapshot = snapshot.hud
	_draw_profile(h)
	if not snapshot.entities.is_empty():
		var boss: Snapshots.EntitySnapshot = snapshot.entities[0]
		var panel: Rect2 = boss_panel(head_position, h.counter_window_ticks_left > 0)
		draw_rect(panel, colors["0"])
		if boss.state == &"posture_broken":
			draw_rect(panel.grow(1), colors["p"], false, 1.0)
		# 3x5 name lettering and a clipped-corner elite chip.
		var tag: Vector2 = panel.position + Vector2(3, 2)
		draw_rect(Rect2(tag + Vector2(1, 0), Vector2(18, 9)), colors["k"])
		draw_rect(Rect2(tag + Vector2(0, 1), Vector2(20, 7)), colors["k"])
		lettering(tag + Vector2(2, 2), "BOSS", colors["1"])
		lettering(panel.position + Vector2(27, 5), "MOSSBOUND COLOSSUS", colors["A"])
		lettering(panel.position + Vector2(26, 4), "MOSSBOUND COLOSSUS", colors["z"])
		bar(panel.position + Vector2(4, 13), 96, h.boss_hp, h.boss_max_hp, colors["7"], 3)
		bar(panel.position + Vector2(4, 19), 96, h.boss_posture, h.boss_posture_max, colors["p"] if boss.state == &"posture_broken" else colors["v"], 2)
		if h.counter_window_ticks_left > 0:
			lettering(panel.position + Vector2(4, 25), "COUNTER - ATTACK", colors["p"])
			bar(panel.position + Vector2(4, 33), 88, h.counter_window_ticks_left, counter_max, colors["o"], 2)
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

## Fixed small footprint; all meter amounts are read directly from the HUD snapshot.
func _draw_profile(h: Snapshots.HudSnapshot) -> void:
	var origin: Vector2 = Vector2(4, 3)
	draw_circle(origin + Vector2(19, 19), 15, colors["0"], true, -1.0, false)
	if portrait_atlas != null and not portrait_frame.is_empty():
		draw_texture_rect_region(portrait_atlas, Rect2(origin + Vector2(7, 7), Vector2(24, 24)), Rect2(portrait_frame["x"], portrait_frame["y"], 24, 24))
	bar(origin + Vector2(33, 11), 97, h.player_hp, h.player_max_hp, colors["t"], 8)
	var health_width: int = floori(97 * clampf(float(h.player_hp) / maxi(1, h.player_max_hp), 0.0, 1.0))
	if health_width > 0:
		draw_rect(Rect2(origin + Vector2(33, 11), Vector2(health_width, 1)), colors["u"])
	bar(origin + Vector2(40, 25), 86, h.edge, h.edge_max, colors["v"], 2)
	bar(origin + Vector2(40, 30), 86, dash_fraction(h), 1.0, colors["n"], 2)
	if portrait_atlas != null and not profile_frame.is_empty():
		draw_texture_rect_region(portrait_atlas, Rect2(origin, Vector2(profile_frame["w"], profile_frame["h"])), Rect2(profile_frame["x"], profile_frame["y"], profile_frame["w"], profile_frame["h"]))
	var hp: String = "%d/%d" % [h.player_hp, h.player_max_hp]
	var hp_at: Vector2 = origin + Vector2(82 - floori(hp.length() * 2.0), 13)
	lettering(hp_at + Vector2.DOWN, hp, colors["0"])
	lettering(hp_at, hp, colors["1"])
	lettering(origin + Vector2(34, 24), "E", colors["v"])
	lettering(origin + Vector2(34, 30), "D", colors["n"])

static func dash_fraction(h: Snapshots.HudSnapshot) -> float:
	if h.dash_cooldown_ticks <= 0:
		return 1.0
	return clampf(1.0 - float(h.dash_cooldown_ticks) / maxi(1, h.dash_cooldown_max), 0.0, 1.0)

func reset_head() -> void:
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
	var height: float = 39.0 if counter else 25.0
	return Rect2(Vector2(clampf(head.x - 52, 2, 214), clampf(head.y - 4 - height, 2, 164 - height)).round(), Vector2(104, height))
