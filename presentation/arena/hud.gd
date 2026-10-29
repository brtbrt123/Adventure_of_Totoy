extends Node2D
## Original 3x5 bitmap lettering, drawn on integer pixels; no external font assets.
const Tuning := preload("res://core/tuning.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const UiPanel := preload("res://presentation/arena/ui_panel.gd")
const Kit := preload("res://presentation/common/ui_kit.gd")
const HudStrip := preload("res://presentation/ui/hud_strip.tscn")
const Aspects := preload("res://core/aspects.gd")
var snapshot: Snapshots.GameSnapshot
## The HUD strip (presentation/ui/hud_strip.tscn, the same scene the road uses), made when the fight HUD first draws.
var arena_strip: Control = null
var colors: Dictionary = {}
var debug_enabled: bool = false
# Extra result-screen lines (the arena fills them when progress is saved).
var result_lines: Array[String] = []
var result_hint: String = ""
# Snapshot weapon identity selects the matching blade glyph.
var weapon_icon_key: String = "ui_weapon_totoy_blade_1"
## The Dual Dagger medallion is a whole 48 px socket (its own ring), drawn in place of the frame plus blade.
const DAGGER_MEDALLION: String = "ui_weapon_dual_dagger_1"
## The Lightning Form's slot icon (24 px, like the Aspect sockets), left of the weapon active box.
const LIGHTNING_FORM_ICON: String = "ui_aspect_lightning_form_1"
## The Chain Scythe medallion (a whole 48 px socket like the dagger's) and its Reaper's Coil slot icon (24 px).
const SCYTHE_MEDALLION: String = "ui_weapon_chain_scythe_1"
const REAPER_COIL_ICON: String = "ui_aspect_reapers_coil_1"
## Whole-socket medallions by weapon (the katana draws the frame plus its blade glyph instead).
const MEDALLIONS: Dictionary = {Tuning.WEAPON_DUAL_DAGGER: DAGGER_MEDALLION, Tuning.WEAPON_CHAIN_SCYTHE: SCYTHE_MEDALLION}
## Active slot icons by weapon (the katana's buff has none: its box only).
const FORM_ICONS: Dictionary = {Tuning.WEAPON_DUAL_DAGGER: LIGHTNING_FORM_ICON, Tuning.WEAPON_CHAIN_SCYTHE: REAPER_COIL_ICON}
static func form_icon_rect() -> Rect2:
	return Rect2(58, 148, 24, 24)
var counter_max: int = 1
## Tests and captures: draw this Aspect socket's (0-2) hover tooltip as if the mouse were on it; -1 = off.
var hint_slot_override: int = -1
## True while the character menu is open: the boss panel (which follows the boss and can sit above the menu panel,
## under only the thin veil) is not drawn.
var menu_open: bool = false
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
const FONT_PATH: String = "res://presentation/fonts/Cinzel.ttf"
const FONT_SIZE: int = 9  # game pixels; Cinzel cap height is about 6 game pixels
const FONT_WEIGHT: int = 400  # Cinzel regular body weight
static var _font: Font = null

## Cinzel body text (OFL, see presentation/fonts/README.md), rendered at window resolution.
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

## Original bitmap digits and input glyphs, installed with the approved kit (2026-10-29).
static func stat_font() -> Font:
	return preload("res://art/ui_kit/pixel_keys.fnt")

## The menu face: Cinzel (OFL, see presentation/fonts/README.md), carved-looking capitals like the title logo.
## Falls back to the pixel font if the file is missing.
const MENU_FONT_PATH: String = "res://presentation/fonts/Cinzel.ttf"
const MENU_FONT_WEIGHT: int = 900
static var _menu_font: Font = null

static func menu_font() -> Font:
	if _menu_font == null:
		if ResourceLoader.exists(MENU_FONT_PATH):
			var variation: FontVariation = FontVariation.new()
			variation.base_font = load(MENU_FONT_PATH) as Font
			variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): MENU_FONT_WEIGHT}
			_menu_font = variation
		else:
			_menu_font = ui_font()
	return _menu_font

## Cap height as a fraction of the font size: six pixels on the bitmap font's eight-pixel em.
static func _cap_ratio(face: Font) -> float:
	return 0.75 if face == stat_font() else 0.70

static func _size_for(_font: Font, scale_px: int, size_px: int = 0) -> int:
	if _font == stat_font():
		return 8 * maxi(1, (size_px if size_px > 0 else FONT_SIZE * scale_px) / 8)
	return size_px if size_px > 0 else FONT_SIZE * scale_px


## Numerals and input labels keep the original square-pixel shapes (especially 5, Z and C).
static func text_face(text: String) -> Font:
	var value: String = text.to_upper()
	if value in ["TAB", "SHIFT", "SPACE", "LMB", "RMB", "ENTER", "ESC", "Z", "X", "C", "+"]:
		return stat_font()
	var digit: bool = false
	for ch: String in value:
		if ch in "0123456789":
			digit = true
		elif ch not in " /+-%.,:XES":
			return ui_font()
	return stat_font() if digit else ui_font()

## Width of `text` in game pixels at a size multiplier (`font` defaults to the pixel font).
static func text_width(text: String, scale_px: int = 1, font: Font = null, size_px: int = 0) -> float:
	var face: Font = font if font != null else text_face(text)
	if face == ui_font() and text_face(text) == stat_font():
		face = stat_font()
	return face.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, _size_for(face, scale_px, size_px)).x

## `at` is the top-left of the letters, as with the old bitmap text.
func lettering(at: Vector2, text: String, color: Color, scale_px: int = 1, font: Font = null, size_px: int = 0) -> void:
	var face: Font = font if font != null else text_face(text)
	if face == ui_font() and text_face(text) == stat_font():
		face = stat_font()
	var size: int = _size_for(face, scale_px, size_px)
	draw_string(face, Vector2(at.x, at.y + _cap_ratio(face) * size), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func outlined(at: Vector2, text: String, color: Color, outline: Color, scale_px: int = 1, font: Font = null, size_px: int = 0) -> void:
	var face: Font = font if font != null else text_face(text)
	if face == ui_font() and text_face(text) == stat_font():
		face = stat_font()
	var size: int = _size_for(face, scale_px, size_px)
	draw_string_outline(face, Vector2(at.x, at.y + _cap_ratio(face) * size), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, 2 * size / FONT_SIZE), outline)
	lettering(at, text, color, scale_px, font, size_px)

## Text centred on `center_x`.
func centered(center_x: float, y: float, text: String, color: Color, outline: Color, scale_px: int = 1, font: Font = null, size_px: int = 0) -> void:
	outlined(Vector2(center_x - text_width(text, scale_px, font, size_px) * 0.5, y), text, color, outline, scale_px, font, size_px)

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
## Square centred on the whole head (hair spikes to chin span x 430-1500, y 25-1300 of the 2000 px source) with a margin.
const PORTRAIT_CROP: Rect2i = Rect2i(215, 0, 1500, 1500)
## The circular opening of ui_profile (a hole at x 16-58, y 16-57 of the 208x80 art, drawn into Rect2(2, 2, 125, 48)):
## its centre and diameter in game pixels.
const PORTRAIT_CENTER: Vector2 = Vector2(24.54, 24.2)
const PORTRAIT_DIAMETER: float = 26.0
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
	portrait_sprite.position = PORTRAIT_CENTER - Vector2.ONE * (PORTRAIT_DIAMETER * 0.5)
	portrait_sprite.scale = Vector2.ONE * (PORTRAIT_DIAMETER / PORTRAIT_SIZE)
	portrait_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait_sprite.show_behind_parent = true
	add_child(portrait_sprite)

func _draw() -> void:
	if snapshot == null or colors.is_empty():
		return
	var h: Snapshots.HudSnapshot = snapshot.hud
	_draw_profile(h)
	_draw_skills(h)
	if not snapshot.entities.is_empty() and not menu_open:
		var boss: Snapshots.EntitySnapshot = snapshot.entities[0]
		var panel: Rect2 = boss_panel(head_position, h.counter_window_ticks_left > 0)
		if head_position.x < -12.0 or head_position.x > 396.0 or head_position.y < -24.0 or head_position.y > 236.0:
			panel.position = Vector2(278.0, 3.0)  # the boss is off screen: its panel waits in the top right corner
		ui("ui_boss", Rect2(panel.position + Vector2(0, 7), Vector2(104, 24)))
		centered(panel.position.x + 52.0, panel.position.y, "MOSSBOUND COLOSSUS", colors["z"], colors["0"], 1, menu_font(), 7)
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
		_draw_result()


## The DEFEAT / VICTORY panel in the shared frame (UiPanel) with a banner title in Cinzel; every line is kept
## (R TO RESTART, the saved TIME / BEST lines, ESC: TITLE when the game came from the title screen).
static func result_panel_rect(line_count: int, has_hint: bool) -> Rect2:
	var h: int = 44 + (line_count * 9 + 4 if line_count > 0 else 0) + (12 if has_hint else 0)
	return Rect2(96, 108 - h / 2, 192, h)

func _draw_result() -> void:
	var victory: bool = snapshot.result == &"victory"
	var theme: StringName = &"victory" if victory else &"defeat"
	var rect: Rect2 = result_panel_rect(result_lines.size(), result_hint != "")
	var top: int = int(rect.position.y)
	UiPanel.draw_panel(self, rect, theme, colors)
	UiPanel.banner(self, 192, top - 7, 80, 16, theme, colors)
	centered(192, top - 5, "VICTORY" if victory else "DEFEAT", colors["1"], colors["0"], 1, menu_font(), 10)
	var hint_color: Color = colors["o"] if victory else colors["j"]
	var y: int = top + 16
	lettering(Vector2(192 - text_width("R TO RESTART") * 0.5, y), "R TO RESTART", hint_color)
	y += 10
	if not result_lines.is_empty():
		draw_rect(Rect2(142, y - 2, 100, 1), colors["f"])
		y += 2
		for line: String in result_lines:
			lettering(Vector2(192 - text_width(line, 1, stat_font()) * 0.5, y), line, colors["1"], 1, stat_font())
			y += 9
	if result_hint != "":
		var t: Dictionary = UiPanel.theme(theme)
		draw_rect(Rect2(156, y, 72, 1), colors[t["accent"]])
		UiPanel.px(self, 192, y, colors[t["gem"]])
		y += 4
		lettering(Vector2(192 - text_width(result_hint) * 0.5, y), result_hint, hint_color)

## The fight strip, bottom left (kit bars, 384x216 layout): HEALTH and its numbers over the health vial with its ghost
## segment, then the Edge and dash bars. All meter amounts are read directly from the HUD snapshot.
const STRIP_X: float = 58.0
const STRIP_W: float = 136.0
const HP_Y: float = 182.0
const THIN_Y: float = 203.0


func _draw_profile(h: Snapshots.HudSnapshot) -> void:
	if portrait_sprite != null:
		portrait_sprite.hide()
	if arena_strip == null:
		arena_strip = HudStrip.instantiate()
		arena_strip.show_behind_parent = true  # the rings and seconds drawn by this script go on top
		add_child(arena_strip)
	arena_strip.atlas = portrait_atlas
	arena_strip.frames = ui_frames
	var weapon: StringName = snapshot.player.weapon_id
	var status: Array = []
	for row: Dictionary in skill_rows(h, snapshot.tick):
		if bool(row["running"]):
			status.append(row["icon"])
	var aspects: Array = []
	for row: Dictionary in skill_rows(h, snapshot.tick):
		aspects.append({"unlocked": true, "owned": true, "usable": true, "icon": row["icon"], "key": row["key"], "cost": "%dE" % int(row["cost"]), "cost_color": colors["v"] if h.edge >= float(row["cost"]) else colors["i"]})
	arena_strip.apply({
		"whole_medallion": MEDALLIONS.get(weapon, ""), "weapon_glyph": weapon_icon_key, "armed": true, "plate": weapon_label(weapon),
		"hp": h.player_hp, "max_hp": h.player_max_hp, "ghost": float(health_ghosts.get("player", h.player_hp)),
		"edge": h.edge / maxf(1.0, h.edge_max), "dash": dash_fraction(h), "status": status, "aspects": aspects,
	})

func ui(key: String, rect: Rect2, source_offset: Vector2 = Vector2.ZERO, source_size: Vector2 = Vector2.ZERO) -> void:
	if portrait_atlas == null or not ui_frames.has(key):
		return
	var frame: Dictionary = ui_frames[key]
	var size: Vector2 = source_size if source_size != Vector2.ZERO else Vector2(frame["w"], frame["h"])
	draw_texture_rect_region(portrait_atlas, rect, Rect2(Vector2(frame["x"], frame["y"]) + source_offset, size))

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
	return Rect2(Vector2(clampf(head.x - 52, 2, 278), clampf(head.y - 4 - height, 2, 200 - height)).round(), Vector2(104, height))

## The Aspect socket icons (24 px) by aspect id: "ui_aspect_<id>_1". While a Spirit Lantern stands its slot shows the
## burning icon ui_aspect_spirit_lantern_lit_1..4 (about 120 ms per frame).
const ASPECT_KEYS_ZXC: Array[String] = ["Z", "X", "C"]
const LANTERN_LIT_TICKS: int = 7

## Aspects with a lit icon loop (ui_aspect_<id>_lit_1..4) while they run: a lantern standing, Sprint running, an Echo
## Step anchor standing, the Stone Ward raised.
const LIT_ASPECTS: Array[StringName] = [Aspects.SPIRIT_LANTERN, Aspects.SPRINT, Aspects.ECHO_STEP, Aspects.STONE_WARD]
## Aspects whose socket shows the seconds they still run (instead of the cooldown seconds) while running.
const RUN_SECONDS_ASPECTS: Array[StringName] = [Aspects.PHANTOM_CUT, Aspects.SPRINT, Aspects.ECHO_STEP, Aspects.STONE_WARD]

## `stored` (Stone Ward's stored damage) makes the lit rune loop run faster: 7 ticks per frame empty, down to 3 at the cap.
static func lit_ticks(aspect: StringName, stored: int = 0) -> int:
	if aspect == Aspects.STONE_WARD and stored > 0:
		return maxi(3, LANTERN_LIT_TICKS - ceili(4.0 * clampf(float(stored) / Tuning.STONE_WARD_STORE_CAP, 0.0, 1.0)))
	return LANTERN_LIT_TICKS

static func aspect_icon(aspect: StringName, lit: bool = false, tick: int = 0, stored: int = 0) -> String:
	if lit and aspect in LIT_ASPECTS:
		return "ui_aspect_%s_lit_%d" % [aspect, posmod(tick / lit_ticks(aspect, stored), 4) + 1]
	return "ui_aspect_%s_1" % aspect

## Stone Ward's stored-damage ring fill (0..1 of STONE_WARD_STORE_CAP) of a skill row; 0 for anything else.
static func stored_fraction(row: Dictionary) -> float:
	if row.get("aspect_id", &"") != Aspects.STONE_WARD or not bool(row.get("running", false)):
		return 0.0
	return clampf(float(row.get("stored", 0)) / Tuning.STONE_WARD_STORE_CAP, 0.0, 1.0)

## Display facts from the HUD snapshot's aspect_slots (one row per slot Z/X/C: whichever aspect is slotted there);
## these labels do not gate input or predict hits. The cooldown is shown only on the icons (ring and seconds), never as
## text in a box. A snapshot without aspect_slots (none should exist) falls back to the default slots.
static func skill_rows(h: Snapshots.HudSnapshot, tick: int = 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot: int in range(3):
		var data: Dictionary = h.aspect_slots[slot] if slot < h.aspect_slots.size() else {}
		var aspect: StringName = StringName(data.get("aspect_id", Aspects.DEFAULT_EQUIPPED[slot]))
		var running: bool = bool(data.get("running", false))
		rows.append({
			"slot": slot + 1, "key": ASPECT_KEYS_ZXC[slot], "aspect_id": aspect, "name": Aspects.display_name(aspect).to_upper(),
			"kind": StringName(data.get("kind", Aspects.kind(aspect))), "cost": float(data.get("edge_cost", Aspects.edge_cost(aspect))),
			"cooldown": int(data.get("cooldown_ticks", h.skill_cooldown_ticks[slot] if slot < h.skill_cooldown_ticks.size() else 0)),
			"cooldown_max": int(data.get("cooldown_max", Aspects.cooldown(aspect))), "running": running,
			"ticks_left": int(data.get("ticks_left", 0)), "duration": int(data.get("duration", Aspects.duration(aspect))),
			"needs_retaliation": bool(data.get("needs_retaliation", Aspects.needs_retaliation(aspect))),
			"stored": int(data.get("stored", 0)),
			"icon": aspect_icon(aspect, running, tick, int(data.get("stored", 0))),
		})
	return rows


## The owner's layout: three small Aspect sockets beside the bottom health strip.
## Native sprite sizes keep the new HUD at integer scale.
static func aspect_rects() -> Array[Rect2]:
	return [Rect2(268, 172, 37, 40), Rect2(306, 172, 37, 40), Rect2(344, 172, 37, 40)]

## The 16x16 icon spot inside socket `slot` (the diamond's middle; the icons' own rings are cropped away).
static func aspect_icon_rect(slot: int) -> Rect2:
	return Kit.socket_icon_rect(aspect_rects()[slot].position)

static func weapon_rect() -> Rect2:
	return Rect2(4, 164, 48, 48)

## The cooldown ring's fill (1 = just used) of a skill row.
static func cooldown_fraction(row: Dictionary) -> float:
	return clampf(float(row["cooldown"]) / maxi(1, int(row["cooldown_max"])), 0.0, 1.0)

## The run ring's fill (1 = just started) while a lantern stands or a buff runs, else 0.
static func run_fraction(row: Dictionary) -> float:
	if not bool(row["running"]) or int(row["duration"]) <= 0:
		return 0.0
	return clampf(float(row["ticks_left"]) / int(row["duration"]), 0.0, 1.0)

func _ring(centre: Vector2, fraction: float, radius: float, color: Color) -> void:
	var arc: PackedVector2Array = PackedVector2Array()
	for point: int in range(33):
		arc.append((centre + Vector2.from_angle(-PI * 0.5 + TAU * fraction * point / 32.0) * radius).round())
	draw_polyline(arc, color, 1.0, false)

func _seconds(centre: Vector2, ticks: int, color: Color) -> void:
	var seconds: String = str(ceili(ticks * Tuning.TICK_DT))
	var seconds_width: float = text_width(seconds, 1, null, 12)
	draw_rect(Rect2(centre + Vector2(-seconds_width * 0.5 - 1, -5), Vector2(seconds_width + 2, 10)), colors["0"])
	lettering(centre + Vector2(-seconds_width * 0.5, -4), seconds, color, 1, null, 12)

func _draw_skills(h: Snapshots.HudSnapshot) -> void:
	var rows: Array[Dictionary] = skill_rows(h, snapshot.tick)
	var sockets: Array[Rect2] = aspect_rects()
	_draw_weapon_active()
	var hint: Dictionary = {}
	for slot: int in range(3):
		var row: Dictionary = rows[slot]
		var socket: Rect2 = sockets[slot]
		var icon: Rect2 = aspect_icon_rect(slot)
		var centre: Vector2 = icon.get_center()
		# Snapshot-only rings. The core still accepts or rejects every press.
		var running: float = run_fraction(row)
		if int(row["cooldown"]) > 0:
			_ring(centre, cooldown_fraction(row), 11.0, colors["o"])
		if running > 0.0:
			_ring(centre, running, 12.0, colors["p"])
		var stored: float = stored_fraction(row)
		if stored > 0.0:
			_ring(centre, stored, 13.0, colors["u"])  # Stone Ward: the damage stored so far, of the cap
		if running > 0.0 and row["aspect_id"] in RUN_SECONDS_ASPECTS:
			_seconds(centre, int(row["ticks_left"]), colors["v"])  # buffs, the echo countdown, the ward: seconds still running
		elif running <= 0.0 and int(row["cooldown"]) > 0:
			_seconds(centre, int(row["cooldown"]), colors["p"])
		if socket.has_point(get_local_mouse_position()) or slot == hint_slot_override:
			hint = row
	if h.retaliate_ticks_left > 0:
		for slot: int in range(3):
			if not bool(rows[slot]["needs_retaliation"]):
				continue
			outlined(Vector2(268, 150), "%s %s READY" % [rows[slot]["key"], rows[slot]["name"]], colors["x"], colors["0"], 1, stat_font())
			var ring: PackedVector2Array = PackedVector2Array()
			var ring_centre: Vector2 = aspect_icon_rect(slot).get_center()
			for point: int in range(33):
				ring.append((ring_centre + Vector2.from_angle(TAU * point / 32.0) * 14.0).round())
			draw_polyline(ring, colors["x"], 1.0, false)
	if not hint.is_empty():
		_draw_aspect_hint(hint)

## The skill hover tooltip in the shared frame: the key in a badge, the slotted Aspect's name, a divider, its Edge cost,
## its icon on the right. No cooldown text (the icon's ring shows it).
static func aspect_hint_rect() -> Rect2:
	return Rect2(222, 124, 160, 44)

func _draw_aspect_hint(row: Dictionary) -> void:
	var rect: Rect2 = aspect_hint_rect()
	UiPanel.draw_panel(self, rect, &"info", colors)
	ui(row["icon"], Rect2(rect.position + Vector2(130, 9), Vector2(24, 24)))
	UiPanel.key_badge(self, rect.position + Vector2(9, 9), colors)
	lettering(rect.position + Vector2(13.5 - text_width(row["key"]) * 0.5, 10), row["key"], colors["1"])
	lettering(rect.position + Vector2(22, 10), row["name"], colors["1"], 1, null, 10)
	draw_rect(Rect2(rect.position + Vector2(9, 22), Vector2(116, 1)), colors["f"])
	var cost: String = "%d EDGE" % int(row["cost"])
	if row["kind"] == Aspects.KIND_BUFF:
		cost += "  BUFF %s S" % str(ceili(int(row["duration"]) * Tuning.TICK_DT))
	elif row["aspect_id"] == Aspects.ECHO_STEP:
		cost += "  RECALL %s S" % str(ceili(int(row["duration"]) * Tuning.TICK_DT))
	elif row["aspect_id"] == Aspects.STONE_WARD:
		cost += "  GUARD %s S" % str(ceili(int(row["duration"]) * Tuning.TICK_DT))
	lettering(rect.position + Vector2(9, 26), cost, colors["v"], 1, null, 10)

static func weapon_label(weapon: StringName) -> String:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA: return "BLACK"
		Tuning.WEAPON_DUAL_DAGGER: return "DAGGER"
		Tuning.WEAPON_CHAIN_SCYTHE: return "SCYTHE"
	return "SWORD"

static func weapon_status(snap: Snapshots.GameSnapshot) -> Dictionary:
	var h: Snapshots.HudSnapshot = snap.hud
	if h.weapon_buff_duration <= 0:
		return {}
	return {"weapon": snap.player.weapon_id, "active": snap.player.weapon_buff_active, "remaining": ceili(snap.player.weapon_buff_ticks_left * Tuning.TICK_DT), "cooldown": ceili(h.weapon_buff_cooldown_ticks * Tuning.TICK_DT), "cost": h.weapon_buff_edge_cost, "duration_fraction": clampf(float(snap.player.weapon_buff_ticks_left) / h.weapon_buff_duration, 0.0, 1.0), "cooldown_fraction": clampf(float(h.weapon_buff_cooldown_ticks) / maxi(1, h.weapon_buff_cooldown_max), 0.0, 1.0)}

## The weapon active's state lives only on the icons (approved 2026-10-21: the RMB / FORM / CD text box is gone): the
## run ring and the cooldown ring around the weapon medallion, and for the dagger and the scythe their active slot icon
## with its own ring and the cooldown seconds.
func _draw_weapon_active() -> void:
	var data: Dictionary = weapon_status(snapshot)
	if data.is_empty():
		return
	if FORM_ICONS.has(data["weapon"]):
		_draw_form_icon(data)
	for active: bool in [false, true]:
		var fraction: float = float(data["duration_fraction" if active else "cooldown_fraction"])
		if fraction <= 0.0:
			continue
		var arc: PackedVector2Array = PackedVector2Array()
		for point: int in range(33):
			arc.append((weapon_rect().get_center() + Vector2.from_angle(-PI * 0.5 + TAU * fraction * point / 32.0) * (21.0 if active else 24.0)).round())
		draw_polyline(arc, colors["v"] if active else colors["o"], 1.0, false)

## The weapon's active slot (Lightning Form, Reaper's Coil): its icon, a bright ring while it runs, the cooldown arc
## and seconds while it recharges.
func _draw_form_icon(data: Dictionary) -> void:
	var rect: Rect2 = form_icon_rect()
	var centre: Vector2 = rect.get_center()
	ui(FORM_ICONS[data["weapon"]], rect)
	var fraction: float = float(data["duration_fraction"]) if bool(data["active"]) else float(data["cooldown_fraction"])
	if fraction > 0.0:
		var arc: PackedVector2Array = PackedVector2Array()
		for point: int in range(33):
			arc.append((centre + Vector2.from_angle(-PI * 0.5 + TAU * fraction * point / 32.0) * 12.0).round())
		draw_polyline(arc, colors["p"] if bool(data["active"]) else colors["o"], 1.0, false)
	if not bool(data["active"]) and int(data["cooldown"]) > 0:
		var seconds: String = str(int(data["cooldown"]))
		var seconds_width: float = text_width(seconds, 1, null, 12)
		draw_rect(Rect2(centre + Vector2(-seconds_width * 0.5 - 1, -5), Vector2(seconds_width + 2, 10)), colors["0"])
		lettering(centre + Vector2(-seconds_width * 0.5, -4), seconds, colors["p"], 1, null, 12)
