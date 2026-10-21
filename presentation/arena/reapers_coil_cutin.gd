extends Node2D
## The Reaper's Coil cut-in: when the Chain Scythe's right click starts Reaper's Coil, a pale flash pops, a slanted
## teal banner slams in from the left, Totoy winds up in rising ghost wisps, cuts to the whip-out, then to the haul
## (he skids back on the taut chain while a giant chain whips across), "REAPER'S COIL" slams in, and the banner is
## yanked out to the LEFT (the drag). The arena stops stepping the core while it plays (like the Black Form and
## Lightning Form cut-ins: no game time passes). Cosmetic only. A parallel sibling of lightning_form_cutin.gd.
##
## Art: presentation/cutin/chainscythe_* (made by tools/art/export_chain_scythe_cutin.py; timing suggested in
## chainscythe_cutin.json and art/reference/chain_scythe/README.md). Laid out on the same 800x450 canvas and drawn at
## SCALE (0.4) on the game canvas. The art is palette pixel art scaled by whole numbers, so this node samples with
## nearest filtering.
const Hud := preload("res://presentation/arena/hud.gd")

const DIR: String = "res://presentation/cutin/"
const DATA_PATH: String = "res://presentation/cutin/chainscythe_cutin.json"
const SCALE: float = 0.4
const FPS: float = 30.0  # the preview's frame rate: flicker and flashes step at this rate
## Preview seconds per real second. The preview runs 1.16 s; the game plays it a little slower (about 1.25 s).
const SPEED: float = 0.93
const END_TIME: float = 1.16
## Real length in seconds (the arena freezes the world this long).
const DURATION: float = END_TIME / SPEED

const INK: Color = Color8(28, 24, 36)
const CREAM: Color = Color8(244, 236, 214)
const PALE: Color = Color8(224, 240, 236)
## Teal/green spectral steel (art/reference/chain_scythe/README.md; preview colours of export_chain_scythe_cutin.py).
const TEAL: Color = Color8(106, 168, 154)
const TEAL_D: Color = Color8(63, 127, 122)
const GLINT: Color = Color8(194, 203, 124)
const DEEP: Color = Color8(36, 54, 92)
const IMPACT: Color = Color8(226, 240, 232)
const BAN_TOP: Color = Color8(26, 64, 66)
const BAN_BOT: Color = Color8(6, 14, 22)
const DIM: Color = Color(0.01, 0.04, 0.05)

const SLOPE: float = -0.075
const TOP0: float = 112.0
const BOT0: float = 352.0
const LEFT0: float = -90.0
const RIGHT_TOP: float = 640.0
const RIGHT_BOT: float = 575.0
const FIG_SCALE: float = 0.63
const FIG_FIT: Dictionary = {"crouch": 1.0, "ready": 0.78, "burst": 0.8}
## Where the figure's feet stand on the banner (x from the banner offset).
const FIG_X: float = 300.0
## [pose, from, to] in preview seconds; the cuts are where the pose changes (crouch = wind-up, ready = whip-out,
## burst = the haul on the taut chain).
const BEATS: Array = [["crouch", 0.10, 0.37], ["ready", 0.37, 0.62], ["burst", 0.62, 1.20]]
const CUTS: Array[float] = [0.37, 0.62]
const SLAM: float = 0.70
const EXIT: Array[float] = [0.98, 1.16]
const TITLE: String = "REAPER'S COIL"
const SUBTITLE: String = "HOOK - DRAG - STAGGER"
const TITLE_SIZES: Array[int] = [52, 55, 58, 61, 65]

var active: bool = false
var available: bool = false
var clock: float = 0.0
var poses: Dictionary = {}
var aura_texture: Texture2D
var aura_frames: Array = []
var strikes: Array[Texture2D] = []
var flashes: Array[Texture2D] = []
var _warming: bool = false

signal finished


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not (data is Dictionary):
		push_warning("Reaper's Coil cut-in art is missing; the cut-in is skipped (run tools/art/export_chain_scythe_cutin.py)")
		return
	for name_key: String in (data as Dictionary)["poses"]:
		var base: String = DIR + "chainscythe_pose_%s" % name_key
		if not ResourceLoader.exists(base + ".png") or not ResourceLoader.exists(base + "_sil.png"):
			return
		poses[name_key] = {"tex": load(base + ".png"), "sil": load(base + "_sil.png"), "meta": data["poses"][name_key]}
	for file: String in data["strikes"]:
		if not ResourceLoader.exists(DIR + file):
			return
		strikes.append(load(DIR + file) as Texture2D)
	for file: String in data["flashes"]:
		if not ResourceLoader.exists(DIR + file):
			return
		flashes.append(load(DIR + file) as Texture2D)
	if not ResourceLoader.exists(DIR + "chainscythe_aura.png") or strikes.size() < 4 or flashes.size() < 3:
		return
	aura_texture = load(DIR + "chainscythe_aura.png") as Texture2D
	aura_frames = data["aura"]["frames"]
	available = true
	_warming = true  # one invisible pass so textures and glyphs are uploaded before the first real cut-in
	queue_redraw()


## Preview time in seconds.
func preview_time() -> float:
	return clock * SPEED


func start() -> void:
	if not available:
		return
	active = true
	clock = 0.0
	queue_redraw()


func stop() -> void:
	active = false
	clock = 0.0
	queue_redraw()


## Advance by real seconds; ends itself when the banner has left.
func advance(delta: float) -> void:
	if not active:
		return
	clock += delta
	if preview_time() >= END_TIME:
		active = false
		clock = 0.0
		finished.emit()
	queue_redraw()


# ---------------------------------------------------------------- timeline (pure, tested)
static func ramp(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)

static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

static func ease_in(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 3.0)

static func ease_back(x: float) -> float:
	var v: float = clampf(x, 0.0, 1.0)
	return 1.0 + 2.70158 * pow(v - 1.0, 3.0) + 1.70158 * pow(v - 1.0, 2.0)

static func y_top(x: float, off: float) -> float:
	return TOP0 + SLOPE * (x - off)

static func y_bot(x: float, off: float) -> float:
	return BOT0 + SLOPE * (x - off)

static func banner_poly(off: float) -> PackedVector2Array:
	var l: float = LEFT0 + off
	var rt: float = RIGHT_TOP + off
	var rb: float = RIGHT_BOT + off
	return PackedVector2Array([Vector2(l, y_top(l, off)), Vector2(rt, y_top(rt, off)), Vector2(rb, y_bot(rb, off)), Vector2(l, y_bot(l, off))])

## Banner offset (x): slams in from the left with an overshoot, then is yanked back out to the left (the drag).
static func banner_offset(t: float) -> float:
	return -760.0 * (1.0 - ease_back(ramp(t, 0.03, 0.17))) - 900.0 * ease_in(ramp(t, EXIT[0], EXIT[1]))

static func beat_at(t: float) -> Array:
	for beat: Array in BEATS:
		if t >= float(beat[1]) and t < float(beat[2]):
			return beat
	return []

## Backdrop chain strike (1-4) at a preview time, 0 for none: a flicker during the crouch, the strike sequence on
## the haul (2 breaks out over the whole screen).
static func strike_at(t: float) -> int:
	var k: int = int(t * FPS)
	if t >= CUTS[1]:
		var n: int = int((t - CUTS[1]) * FPS + 0.000001)
		if n < 7:
			return [1, 2, 2, 3, 3, 4, 4][n]
		return 3 if k % 4 < 2 else 4
	if t >= 0.2 and t < CUTS[0] and k % 3 == 0:
		return 4
	return 0

## Full-screen flash (1-3) at a preview time, 0 for none.
static func flash_at(t: float) -> int:
	if t < 1.0 / FPS:
		return 1
	if t < 3.0 / FPS:
		return 2
	if t < 5.0 / FPS:
		return 3
	if t >= CUTS[1] and t < CUTS[1] + 1.0 / FPS:
		return 2
	if t >= CUTS[1] + 1.0 / FPS and t < CUTS[1] + 3.0 / FPS:
		return 3
	return 0


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if _warming:
		_warming = false
		_draw_warmup()
		return
	if not active or not available:
		return
	var t: float = preview_time()
	var k: int = int(t * FPS)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	var dim: float = ramp(t, 0.0, 0.08) * (1.0 - ramp(t, 0.94, END_TIME))
	if dim > 0.0:
		draw_rect(Rect2(0, 0, 800, 450), Color(DIM, 0.66 * dim))
	var off: float = banner_offset(t)
	var poly: PackedVector2Array = banner_poly(off)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 3000 + k
	var shake: Vector2 = Vector2.ZERO
	for cut: float in CUTS + [SLAM]:
		if t >= cut and t < cut + 0.1:
			shake = Vector2(rnd.randi_range(-6, 6), rnd.randi_range(-4, 4))
	var beat: Array = beat_at(t)
	var impact: bool = false
	var veil: bool = false
	if not beat.is_empty():
		for cut: float in CUTS:
			if t >= cut and t < cut + 1.0 / FPS + 0.000001:
				impact = true
			elif t >= cut + 1.0 / FPS and t < cut + 2.0 / FPS + 0.000001:
				veil = true
	var st: int = strike_at(t)
	var on_screen: bool = off > -820.0 and off < 820.0
	if st == 2:  # the chain strike breaks out over the whole screen, behind the banner
		draw_texture_rect(strikes[1], Rect2(off * 0.2, 0, 800, 450), false)
	if on_screen:
		draw_polygon(poly, PackedColorArray([BAN_TOP, BAN_TOP, BAN_BOT, BAN_BOT]))
		if st > 0 and st != 2:
			_draw_clipped(strikes[st - 1], poly, off * 0.2)
		_draw_speed_lines(poly, off, k)
		if not beat.is_empty():
			_draw_aura(t, k, off, str(beat[0]), poly)
		if impact:
			draw_colored_polygon(poly, IMPACT)
			_radial_lines(Vector2(off + FIG_X, 230.0), k, poly)
	var figure: Rect2 = Rect2()
	if on_screen and not beat.is_empty():
		figure = _draw_figure(str(beat[0]), t, float(beat[1]), off, shake, impact)
		if veil:
			draw_colored_polygon(poly, Color(IMPACT, 0.37))
			draw_texture_rect(poses[str(beat[0])]["tex"], figure, false, Color(IMPACT, 0.37))
	if on_screen:
		var loop: PackedVector2Array = poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, TEAL, 10.0)
		draw_polyline(loop, CREAM, 4.0)
	var fi: int = flash_at(t)
	if fi > 0:
		draw_texture_rect(flashes[fi - 1], Rect2(0, 0, 800, 450), false)
	if t >= SLAM and off > -700.0:
		_draw_title(t, off, shake)
	if t >= EXIT[0]:
		_draw_exit_smear(k, off)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A full-canvas texture shown only inside the banner (mapped onto the polygon with UVs).
func _draw_clipped(texture: Texture2D, poly: PackedVector2Array, shift_x: float) -> void:
	var uvs: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in poly:
		uvs.append((point - Vector2(shift_x, 0.0)) / Vector2(800.0, 450.0))
	draw_polygon(poly, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, texture)


func _draw_speed_lines(poly: PackedVector2Array, off: float, k: int) -> void:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 300 + k
	var tints: Array[Color] = [TEAL, CREAM, PALE, GLINT]
	for i: int in 22:
		var y: float = rnd.randf_range(70.0, 380.0)
		var x: float = rnd.randf_range(-100.0, 760.0) + off
		var length: float = rnd.randf_range(60.0, 260.0)
		var tint: Color = Color(tints[rnd.randi() % 4], rnd.randf_range(0.31, 0.67))
		var width: float = [2.0, 2.0, 4.0][rnd.randi() % 3]
		var a: Vector2 = Vector2(x, y)
		var b: Vector2 = Vector2(x + length, y + SLOPE * length)
		if Geometry2D.is_point_in_polygon(a, poly) and Geometry2D.is_point_in_polygon(b, poly):
			draw_line(a, b, tint, width)


func _radial_lines(centre: Vector2, k: int, clip: PackedVector2Array) -> void:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 900 + k
	for i: int in 36:
		var angle: float = rnd.randf_range(0.0, TAU)
		var r0: float = rnd.randf_range(90.0, 150.0)
		var r1: float = rnd.randf_range(300.0, 600.0)
		var a: Vector2 = centre + Vector2.from_angle(angle) * r0
		if not Geometry2D.is_point_in_polygon(a, clip):
			continue
		var end: Vector2 = a
		for s: int in range(1, 9):
			var probe: Vector2 = a.lerp(centre + Vector2.from_angle(angle) * r1, float(s) / 8.0)
			if not Geometry2D.is_point_in_polygon(probe, clip):
				break
			end = probe
		draw_line(a, end, TEAL_D, [2.0, 4.0][rnd.randi() % 2])


## Ghost-wisp aura behind the figure, feet on the banner's lower edge, flipped every other step.
func _draw_aura(t: float, k: int, off: float, pose: String, clip: PackedVector2Array) -> void:
	var strength: float = ramp(t, 0.15, 0.3)
	if strength <= 0.0 or aura_frames.is_empty():
		return
	var index: int = (k / 2) % aura_frames.size()
	var frame: Dictionary = aura_frames[index]
	var height: float = 250.0 if pose != "burst" else 290.0
	var size: Vector2 = Vector2(float(frame["w"]) * height / float(frame["h"]), height)
	var fx: float = off + FIG_X
	var rect: Rect2 = Rect2(Vector2(fx - size.x * 0.5, y_bot(fx, off) - height), size)
	var region: Rect2 = Rect2(frame["x"], frame["y"], frame["w"], frame["h"])
	var flip: bool = (k / 2) % 2 == 1
	# Only the part inside the banner shows (as in the preview): intersect, then map each corner back into the atlas.
	var box: PackedVector2Array = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var atlas_size: Vector2 = aura_texture.get_size()
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(box, clip):
		var uvs: PackedVector2Array = PackedVector2Array()
		var tints: PackedColorArray = PackedColorArray()
		for point: Vector2 in piece:
			var local: Vector2 = (point - rect.position) / rect.size
			if flip:
				local.x = 1.0 - local.x
			uvs.append((region.position + local * region.size) / atlas_size)
			tints.append(Color(1, 1, 1, strength))
		draw_polygon(piece, tints, uvs, aura_texture)


## Draws the pose (lit, or the ink silhouette on an impact frame) and returns where it went.
func _draw_figure(name_key: String, t: float, a0: float, off: float, shake: Vector2, silhouette: bool) -> Rect2:
	var pose: Dictionary = poses[name_key]
	var meta: Dictionary = pose["meta"]
	var local: float = t - a0
	# hit-stop: the beat lands big, then settles and slowly pushes in
	var s: float = 1.12 if local < 0.07 else 1.0 + 0.10 * (1.0 - ease_out((local - 0.07) / 0.12)) + 0.05 * ramp(local, 0.07, 0.6)
	var sc: float = FIG_SCALE * float(FIG_FIT.get(name_key, 1.0)) * s
	var size: Vector2 = Vector2(float(meta["w"]), float(meta["h"])) * sc
	var fx: float = off + FIG_X
	# the haul: he skids back on the taut chain
	var feet_x: float = fx - (30.0 * ease_out(local / 0.3) if name_key == "burst" else 0.0)
	var position_px: Vector2 = Vector2(feet_x - float(meta["pad"]) * sc - float(meta["inner_w"]) * sc * float(meta["feet_x"]) + shake.x, y_bot(feet_x, off) - 4.0 - (size.y - float(meta["pad"]) * sc) + shake.y)
	var rect: Rect2 = Rect2(position_px.round(), size.round())
	draw_texture_rect(pose["sil"] if silhouette else pose["tex"], rect, false)
	return rect


func _draw_title(t: float, off: float, shake: Vector2) -> void:
	var tx: float = ramp(t, SLAM, SLAM + 0.08)
	var size: int = _title_size(54.0 * (1.0 + 0.25 * (1.0 - ease_out(tx))))
	var font: Font = Hud.ui_font()
	var text_size: Vector2 = font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var cx: float = off + 270.0 + shake.x
	var cy: float = y_bot(off + 270.0, off) + 14.0 + shake.y
	var alpha: float = 0.5 + 0.5 * tx
	# slant about the title's centre: the top leans right
	draw_set_transform_matrix(Transform2D(Vector2(SCALE, 0.0), Vector2(-0.22 * SCALE, SCALE), Vector2(cx, cy) * SCALE))
	var pen: Vector2 = Vector2(-text_size.x * 0.5, font.get_ascent(size) - text_size.y * 0.5)
	draw_string_outline(font, pen + Vector2(4.0, 5.0), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(INK, alpha))
	draw_string_outline(font, pen, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(DEEP, alpha))
	draw_string_outline(font, pen, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(TEAL, alpha))
	draw_string(font, pen, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(CREAM, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	# the subtitle states what the skill does
	var so: float = ramp(t, SLAM + 0.06, SLAM + 0.2)
	if so > 0.0:
		var sub: String = SUBTITLE
		var sub_size: Vector2 = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var sx: float = off + 270.0 - (sub_size.x + 40.0) * 0.5 + 30.0 + 40.0 * (1.0 - ease_out(so))
		var sy: float = cy + 30.0
		var bar: PackedVector2Array = PackedVector2Array([Vector2(sx + 10.0, sy), Vector2(sx + sub_size.x + 40.0, sy), Vector2(sx + sub_size.x + 30.0, sy + sub_size.y + 14.0), Vector2(sx, sy + sub_size.y + 14.0)])
		draw_colored_polygon(bar, Color(INK, 0.88 * so))
		draw_line(bar[0], bar[1], Color(TEAL, so), 2.0)
		draw_string(font, Vector2(sx + 20.0, sy + 7.0 + font.get_ascent(18)), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PALE, so))


static func _title_size(wanted: float) -> int:
	var best: int = TITLE_SIZES[0]
	for candidate: int in TITLE_SIZES:
		if absf(float(candidate) - wanted) < absf(float(best) - wanted):
			best = candidate
	return best


func _draw_exit_smear(k: int, off: float) -> void:
	var out: float = ramp(preview_time(), EXIT[0], EXIT[1])
	if out >= 1.0:
		return
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = k
	# the banner leaves to the left: the smear trails behind its right edge
	var rx: float = RIGHT_TOP + off
	var tints: Array[Color] = [TEAL, PALE, GLINT]
	for i: int in 16:
		var y: float = rnd.randf_range(100.0, 360.0)
		draw_line(Vector2(rx - 20.0, y), Vector2(rx + rnd.randf_range(80.0, 360.0), y + SLOPE * 100.0), Color(tints[rnd.randi() % 3], 0.78), [2.0, 2.0, 4.0][rnd.randi() % 3])


## Draws everything once at almost no opacity so the first real cut-in does not hitch on uploads or glyphs.
func _draw_warmup() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	var faint: Color = Color(1, 1, 1, 0.01)
	for key: String in poses:
		draw_texture_rect(poses[key]["tex"], Rect2(0, 0, 8, 8), false, faint)
		draw_texture_rect(poses[key]["sil"], Rect2(0, 0, 8, 8), false, faint)
	for texture: Texture2D in strikes + flashes:
		draw_texture_rect(texture, Rect2(0, 0, 8, 8), false, faint)
	draw_texture_rect(aura_texture, Rect2(0, 0, 8, 8), false, faint)
	var font: Font = Hud.ui_font()
	for size: int in TITLE_SIZES:
		draw_string_outline(font, Vector2.ZERO, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, faint)
		draw_string(font, Vector2.ZERO, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size, faint)
		draw_string_outline(font, Vector2.ZERO, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, faint)
	draw_string(font, Vector2.ZERO, SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, faint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
