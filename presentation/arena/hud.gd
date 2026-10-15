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
	if not snapshot.entities.is_empty():
		var boss: Snapshots.EntitySnapshot = snapshot.entities[0]
		var panel: Rect2 = boss_panel(head_position, h.counter_window_ticks_left > 0)
		var tag: Vector2 = panel.position + Vector2(4, 3)
		outlined(tag, "BOSS", colors["1"], colors["A"])
		outlined(panel.position + Vector2(26, 3), "MOSSBOUND COLOSSUS", colors["z"], colors["0"])
		bar(panel.position + Vector2(4, 13), 96, h.boss_hp, h.boss_max_hp, colors["7"], 3, float(health_ghosts.get("boss", h.boss_hp)))
		bar(panel.position + Vector2(4, 19), 96, h.boss_posture, h.boss_posture_max, colors["p"] if boss.state == &"posture_broken" else colors["v"], 2)
		if h.counter_window_ticks_left > 0:
			outlined(panel.position + Vector2(4, 25), "COUNTER - ATTACK", colors["p"], colors["0"])
			bar(panel.position + Vector2(4, 33), 88, h.counter_window_ticks_left, counter_max, colors["o"], 2)
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
	var center: Vector2 = Vector2(28, 28)
	bar(Vector2(49, 16), 105, h.player_hp, h.player_max_hp, colors["t"], 9, float(health_ghosts.get("player", h.player_hp)))
	bar(Vector2(56, 33), 94, h.edge, h.edge_max, colors["v"], 2)
	bar(Vector2(56, 40), 94, dash_fraction(h), 1.0, colors["n"], 2)
	# Pixel-stepped vine shoulders wrap from the portrait into the health frame.
	for i: int in range(5):
		var at: Vector2 = Vector2(49 + i * 3, 12 - mini(i, 2))
		draw_rect(Rect2(at, Vector2(4, 2)), colors["0"])
		draw_rect(Rect2(at + Vector2(0, 1), Vector2(2, 1)), colors["u"])
		draw_rect(Rect2(Vector2(151 - i, 26 + i), Vector2(2, 2)), colors["0"])
	draw_circle(center, 24, colors["0"], true, -1.0, false)
	draw_arc(center, 23, 0, TAU, 96, colors["j"], 1.0, false)
	draw_arc(center, 22, 0, TAU, 96, colors["t"], 1.0, false)
	prepare_portrait()
	if portrait_mask != null:
		draw_texture(portrait_mask, Vector2(6, 6))
	# Small stepped leaves ornament the rim without covering the face.
	for side: int in [-1, 1]:
		for row: int in [-1, 1]:
			var leaf: Vector2 = center + Vector2(side * 18, row * 17)
			draw_polyline(PackedVector2Array([leaf + Vector2(-side * 3, 0), leaf, leaf + Vector2(0, row * 3)]), colors["0"], 3.0, false)
			draw_polyline(PackedVector2Array([leaf + Vector2(-side * 3, 0), leaf, leaf + Vector2(0, row * 3)]), colors["u"], 1.0, false)
	for offset: Vector2 in [Vector2(-24, 0), Vector2(24, 0), Vector2(0, -24), Vector2(0, 24)]:
		var tip: Vector2 = center + offset
		draw_rect(Rect2(tip - Vector2.ONE, Vector2(3, 3)), colors["0"])
		draw_rect(Rect2(tip, Vector2.ONE), colors["1"])
	var hp: String = "%d/%d" % [h.player_hp, h.player_max_hp]
	outlined(Vector2(101 - hp.length() * 2, 18), hp, colors["1"], colors["0"])
	outlined(Vector2(50, 32), "E", colors["v"], colors["0"])
	outlined(Vector2(50, 39), "D", colors["n"], colors["0"])

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
	var height: float = 39.0 if counter else 25.0
	return Rect2(Vector2(clampf(head.x - 52, 2, 214), clampf(head.y - 4 - height, 2, 164 - height)).round(), Vector2(104, height))
