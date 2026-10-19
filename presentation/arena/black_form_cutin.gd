extends Node2D
## The Black Form cut-in: when the Black Katana buff starts, a slanted banner slams in from the left with three
## quick pose beats (crouch, rise, burst), impact flashes, a title and the buff's real numbers, then leaves. The
## arena stops stepping the core while it plays (so no game time passes and the buff timer does not run); it is
## purely cosmetic and holds no rules. Approved by the human as a preview GIF (docs/previews/black_form_cutin_v3).
##
## Art: presentation/cutin/ (made by tools/art/export_black_form_cutin.py from Codex's concept poses and aura
## wisps). Everything is laid out on the 800x450 canvas of the preview and drawn at SCALE (0.4) on the game canvas;
## with the project's canvas_items stretch it is rendered at the window resolution.
const Tuning := preload("res://core/tuning.gd")
const Hud := preload("res://presentation/arena/hud.gd")

const DATA_PATH: String = "res://presentation/cutin/black_form_cutin.json"
const SCALE: float = 0.4
## Preview seconds per real second: the preview runs 2.3 s until the banner has left, the game plays it faster.
const SPEED: float = 1.3
const END_TIME: float = 2.32
## Real length of the cut-in in seconds (the arena freezes the world for this long).
const DURATION: float = END_TIME / SPEED

const VIOLET: Color = Color8(154, 100, 255)
const CREAM: Color = Color8(244, 236, 214)
const INK: Color = Color8(14, 6, 30)
const BAN_TOP: Color = Color8(78, 34, 150)
const BAN_BOT: Color = Color8(8, 3, 20)

const SLOPE: float = -0.075
const TOP0: float = 112.0
const BOT0: float = 352.0
const LEFT0: float = -90.0
const RIGHT_TOP: float = 640.0
const RIGHT_BOT: float = 575.0
const FIG_SCALE: float = 0.63
## [pose name, from, to] in preview seconds; the cuts are where the pose changes; the slam is the title landing.
const BEATS: Array = [["crouch", 0.30, 0.80], ["ready", 0.80, 1.30], ["burst", 1.30, 2.45]]
const CUTS: Array[float] = [0.80, 1.30]
const SLAM: float = 1.42

var active: bool = false
var available: bool = false
var clock: float = 0.0
var poses: Dictionary = {}
var aura_texture: Texture2D
var aura_frames: Array = []
var vignette: GradientTexture2D
var dots: Array[Vector3] = []  # x, y, radius of the halftone dots (fixed on the screen, like the preview)

signal finished


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not (data is Dictionary):
		push_warning("Black Form cut-in art is missing; the cut-in is skipped (run tools/art/export_black_form_cutin.py)")
		return
	for name_key: String in (data as Dictionary)["poses"]:
		var meta: Dictionary = data["poses"][name_key]
		var base: String = "res://presentation/cutin/black_form_pose_%s" % name_key
		if not ResourceLoader.exists(base + ".png") or not ResourceLoader.exists(base + "_sil.png"):
			return
		poses[name_key] = {"tex": load(base + ".png"), "sil": load(base + "_sil.png"), "meta": meta}
	if not ResourceLoader.exists("res://presentation/cutin/black_form_aura.png"):
		return
	aura_texture = load("res://presentation/cutin/black_form_aura.png") as Texture2D
	aura_frames = data["aura"]["frames"]
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.04, 0.016, 0.11, 0.0), Color(0.04, 0.016, 0.11, 0.0), Color(0.04, 0.016, 0.11, 0.9)])
	vignette = GradientTexture2D.new()
	vignette.gradient = gradient
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.0, 0.5)
	vignette.width = 128
	vignette.height = 128
	for yy: int in range(0, 450, 16):
		for xx: int in range(0 if (yy / 16) % 2 == 0 else 8, 800, 16):
			var radius: float = 3.4 * (yy / 450.0) - 0.3
			if radius > 0.7:
				dots.append(Vector3(xx, yy, radius))
	available = true


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


# ---------------------------------------------------------------- easing
static func ramp(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)

static func ease_out(x: float) -> float:
	var v: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - v, 3.0)

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

## Banner offset (x) at a preview time: slams in with a small overshoot, leaves to the left.
static func banner_offset(t: float) -> float:
	return -760.0 * (1.0 - ease_back(ramp(t, 0.06, 0.30))) - 820.0 * ease_in(ramp(t, 2.08, 2.32))

## The beat (pose name) showing at a preview time, "" when none.
static func beat_at(t: float) -> Array:
	for beat: Array in BEATS:
		if t >= float(beat[1]) and t < float(beat[2]):
			return beat
	return []


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if not active or not available:
		return
	var t: float = preview_time()
	var step: int = int(t * 20.0)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	# dim and vignette while the cut-in is up
	var dim: float = ramp(t, 0.02, 0.22) * (1.0 - ramp(t, 2.2, 2.55))
	if dim > 0.0:
		draw_rect(Rect2(0, 0, 800, 450), Color(0.024, 0.012, 0.063, 0.62 * dim))
		draw_texture_rect(vignette, Rect2(0, 0, 800, 450), false, Color(1, 1, 1, dim))
	var off: float = banner_offset(t)
	if off <= -740.0:
		return
	# shake: a short one on every pose cut and a bigger one on the title slam
	var shake: Vector2 = Vector2.ZERO
	rnd.seed = 2000 + step
	if t >= SLAM and t < SLAM + 0.15:
		var amp: float = 7.0 * (1.0 - ramp(t, SLAM, SLAM + 0.15))
		shake = Vector2(rnd.randf_range(-amp, amp), rnd.randf_range(-amp, amp))
	for cut: float in CUTS:
		if t >= cut and t < cut + 0.1:
			shake = Vector2(rnd.randf_range(-4.0, 4.0), rnd.randf_range(-3.0, 3.0))
	var poly: PackedVector2Array = banner_poly(off)
	var beat: Array = beat_at(t)
	var burst: float = ramp(t, 1.30, 1.36) if (not beat.is_empty() and beat[0] == "burst") else 0.0
	_draw_banner(poly, t, step, off, burst)
	if not beat.is_empty():
		_draw_aura_behind(t, off)
	_draw_border(poly)
	var chest: Vector2 = Vector2(off + 330.0, 230.0)
	if not beat.is_empty():
		chest = _draw_figure(str(beat[0]), t, float(beat[1]), off, shake, false)
	_draw_sparks(t, off)
	_draw_sweep(poly, t, 0.22, 0.22, 70.0)
	_draw_sweep(poly, t, 1.30, 0.22, 90.0)
	# impact frames: the first frame of a cut is a white banner with the new pose as an ink silhouette,
	# the second is the colour pose under a fading white veil
	for cut: float in CUTS:
		if t >= cut and t < cut + 0.1 and not beat.is_empty():
			if t < cut + 0.049:
				_draw_impact(poly, chest, str(beat[0]), t, float(beat[1]), off, step)
			else:
				draw_colored_polygon(poly, Color(0.96, 0.93, 1.0, 0.37))
	if t >= SLAM:
		_draw_title(t, step, off, shake)
	_draw_exit_smear(t, off, step)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_banner(poly: PackedVector2Array, t: float, step: int, off: float, burst: float) -> void:
	draw_polygon(poly, PackedColorArray([BAN_TOP, BAN_TOP, BAN_BOT, BAN_BOT]))
	for dot: Vector3 in dots:
		if Geometry2D.is_point_in_polygon(Vector2(dot.x, dot.y), poly):
			draw_circle(Vector2(dot.x, dot.y), dot.z, Color(0.51, 0.31, 0.86, 0.27))
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 300 + step
	# speed lines running along the banner, streaming left
	for i: int in 26:
		var y: float = rnd.randf_range(70.0, 380.0)
		var x: float = rnd.randf_range(-100.0, 760.0)
		var length: float = rnd.randf_range(60.0, 260.0)
		var tint: Color = Color(CREAM, rnd.randf_range(0.23, 0.58)) if rnd.randf() < 0.5 else Color(0.75, 0.59, 1.0, rnd.randf_range(0.27, 0.63))
		var width: float = [1.0, 1.0, 2.0, 3.0][rnd.randi() % 4]
		var a: Vector2 = Vector2(x, y)
		var b: Vector2 = Vector2(x + length, y + SLOPE * length)
		if Geometry2D.is_point_in_polygon(a, poly) and Geometry2D.is_point_in_polygon(b, poly):
			draw_line(a, b, tint, width)
	if burst > 0.0:
		_radial_lines(Vector2(off + 330.0, 230.0), step, Color(0.92, 0.86, 1.0), burst, poly, 44, 60.0, 120.0, 160.0, 420.0)


func _radial_lines(centre: Vector2, step: int, color: Color, strength: float, clip: PackedVector2Array, count: int, r0_min: float, r0_max: float, len_min: float, len_max: float) -> void:
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 900 + step
	for i: int in count:
		var angle: float = rnd.randf_range(0.0, TAU)
		var r0: float = rnd.randf_range(r0_min, r0_max)
		var r1: float = r0 + rnd.randf_range(len_min, len_max)
		var a: Vector2 = centre + Vector2.from_angle(angle) * r0
		var b: Vector2 = centre + Vector2.from_angle(angle) * r1
		var width: float = [1.0, 2.0, 3.0][rnd.randi() % 3]
		var alpha: float = rnd.randf_range(0.23, 0.66) * strength
		# keep the lines inside the banner by trimming the far end to the polygon edge
		if not Geometry2D.is_point_in_polygon(a, clip):
			continue
		var steps: int = 8
		var end: Vector2 = a
		for s: int in range(1, steps + 1):
			var probe: Vector2 = a.lerp(b, float(s) / steps)
			if not Geometry2D.is_point_in_polygon(probe, clip):
				break
			end = probe
		draw_line(a, end, Color(color, alpha), width)


func _draw_aura(index: int, height: float, flip: bool, opacity: float, bottom_centre: Vector2) -> void:
	if opacity <= 0.01:
		return
	var frame: Dictionary = aura_frames[index % aura_frames.size()]
	var scale: float = height / float(frame["h"])
	var size: Vector2 = Vector2(float(frame["w"]) * scale, height)
	var rect: Rect2 = Rect2(bottom_centre - Vector2(size.x * 0.5, size.y), size)
	if flip:
		rect = Rect2(Vector2(rect.end.x, rect.position.y), Vector2(-size.x, size.y))
	draw_texture_rect_region(aura_texture, rect, Rect2(frame["x"], frame["y"], frame["w"], frame["h"]), Color(1, 1, 1, opacity))


func _draw_aura_behind(t: float, off: float) -> void:
	var fx: float = off + 330.0
	var strength: float = ramp(t, 0.36, 0.6)
	var flick: int = int(t * 12.0)
	# flames burn behind the figure with their feet on the banner's lower edge (nothing hangs below it)
	_draw_aura(flick, 250.0 + 30.0 * ramp(t, 0.8, 1.4), flick % 2 == 1, 0.95 * strength, Vector2(fx, y_bot(fx, off) - 2.0))
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 9
	for i: int in 10:
		var start: float = rnd.randf_range(0.0, 0.6)
		var wx: float = off + rnd.randf_range(80.0, 560.0)
		var size: float = 40.0 + 30.0 * rnd.randf()
		var index: int = rnd.randi_range(0, 11)
		var mirrored: bool = rnd.randf() < 0.5
		if t < 0.3 + start:
			continue
		var p: float = fposmod(t - 0.3 - start, 0.6) / 0.6
		_draw_aura(index, size, mirrored, 0.8 * sin(PI * p), Vector2(wx, y_bot(wx, off) - 4.0 - 150.0 * p))


func _draw_border(poly: PackedVector2Array) -> void:
	var loop: PackedVector2Array = poly.duplicate()
	loop.append(poly[0])
	draw_polyline(loop, Color(VIOLET, 0.16), 26.0, true)
	draw_polyline(loop, Color(VIOLET, 0.30), 18.0, true)
	draw_polyline(loop, Color(VIOLET, 0.80), 10.0, true)
	draw_polyline(loop, CREAM, 4.0, true)
	draw_line(Vector2(poly[0].x, poly[0].y + 10.0), Vector2(poly[1].x - 8.0, poly[1].y + 10.0), Color(VIOLET, 0.78), 2.0)


## Draws the pose and returns the chest point (used for the radial lines of the impact frame).
func _draw_figure(name_key: String, t: float, a0: float, off: float, shake: Vector2, silhouette: bool) -> Vector2:
	var pose: Dictionary = poses[name_key]
	var meta: Dictionary = pose["meta"]
	var local: float = t - a0
	# hit-stop: the beat lands big and holds for two frames, then settles and slowly pushes in
	var s: float = 1.10 if local < 0.1 else 1.0 + 0.10 * (1.0 - ease_out((local - 0.1) / 0.14)) + 0.05 * ramp(local, 0.1, 0.9)
	if name_key == "crouch":
		s *= 0.9 + 0.1 * ease_out(local / 0.12)
	var sc: float = FIG_SCALE * s
	var size: Vector2 = Vector2(float(meta["w"]), float(meta["h"])) * sc
	var pad: float = float(meta["pad"]) * sc
	var feet_x: float = off + 330.0 + (18.0 * ease_out(local / 0.5) if name_key == "burst" else 0.0)
	var feet_y: float = y_bot(feet_x, off) - 4.0
	var position_px: Vector2 = Vector2(feet_x - pad - float(meta["inner_w"]) * sc * float(meta["feet_x"]) + shake.x, feet_y - (size.y - pad) + shake.y)
	var tex: Texture2D = pose["sil"] if silhouette else pose["tex"]
	draw_texture_rect(tex, Rect2(position_px, size), false)
	return Vector2(feet_x, feet_y - 0.55 * float(meta["inner_h"]) * sc)


func _draw_impact(poly: PackedVector2Array, chest: Vector2, name_key: String, t: float, a0: float, off: float, step: int) -> void:
	draw_colored_polygon(poly, Color8(248, 242, 255))
	_radial_lines(chest, step, VIOLET, 1.0, poly, 36, 90.0, 150.0, 150.0, 420.0)
	_draw_figure(name_key, t, a0, off, Vector2.ZERO, true)
	var loop: PackedVector2Array = poly.duplicate()
	loop.append(poly[0])
	draw_polyline(loop, INK, 4.0, true)


func _draw_sparks(t: float, off: float) -> void:
	if t <= 0.3:
		return
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 55
	for i: int in 30:
		var start: float = rnd.randf_range(0.0, 1.0)
		var p: float = fposmod(t * 1.6 + start, 1.0)
		var x: float = off + rnd.randf_range(40.0, 600.0) - 80.0 * p
		var y: float = y_bot(x, off) - 20.0 - 260.0 * p
		var size: float = [2.0, 2.0, 3.0, 4.0][rnd.randi() % 4]
		if x >= 0.0 and x < 800.0 and y > y_top(x, off) - 70.0:
			draw_rect(Rect2(x, y, size, size), Color(CREAM if i % 3 == 0 else Color8(200, 160, 255), 1.0 - p))


func _draw_sweep(poly: PackedVector2Array, t: float, start: float, duration: float, width: float) -> void:
	var p: float = ramp(t, start, start + duration)
	if p <= 0.0 or p >= 1.0:
		return
	var x: float = -200.0 + p * 1200.0
	var bands: Array = [
		[PackedVector2Array([Vector2(x, -10), Vector2(x + width, -10), Vector2(x + width - 160.0, 460), Vector2(x - 160.0, 460)]), 0.59],
		[PackedVector2Array([Vector2(x + width + 14.0, -10), Vector2(x + width + 26.0, -10), Vector2(x + width - 134.0, 460), Vector2(x + width - 146.0, 460)]), 0.43],
	]
	for band: Array in bands:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(band[0], poly):
			draw_colored_polygon(piece, Color(1.0, 0.98, 0.94, band[1]))


func _draw_title(t: float, step: int, off: float, shake: Vector2) -> void:
	var tx: float = ramp(t, SLAM, SLAM + 0.12)
	var size: int = int(round(56.0 * (1.0 + 0.45 * (1.0 - ease_out(tx)))))
	if t >= SLAM + 0.10 and t < SLAM + 0.15:
		size = 60  # overshoot punch on landing
	var glitch: bool = (t >= SLAM + 0.10 and t < SLAM + 0.20) or (t >= 1.85 and t < 1.9)
	var label: String = "BLACK FORM"
	var font: Font = Hud.ui_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var cx: float = off + 250.0
	var cy: float = y_bot(cx, off) + 22.0
	var alpha: float = 1.0 if tx >= 1.0 else 0.5 + 0.5 * tx
	var shear: float = 0.22
	# slant about the title's centre: the top leans right
	var origin: Vector2 = Vector2(cx + shake.x, cy + shake.y)
	var basis_x: Vector2 = Vector2(SCALE, 0.0)
	var basis_y: Vector2 = Vector2(-shear * SCALE, SCALE)
	draw_set_transform_matrix(Transform2D(basis_x, basis_y, origin * SCALE))
	var pen: Vector2 = Vector2(-text_size.x * 0.5, font.get_ascent(size) - text_size.y * 0.5)
	if glitch:
		var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
		rnd.seed = step
		draw_string(font, pen + Vector2(-8.0, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(VIOLET, 0.75 * alpha))
		draw_string(font, pen + Vector2(8.0, 0.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.7 * alpha))
		pen.x += [-6.0, 0.0, 6.0, 9.0][rnd.randi() % 4]
	draw_string_outline(font, pen, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 30, Color(VIOLET, 0.22 * alpha))
	draw_string_outline(font, pen, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 20, Color(VIOLET, 0.45 * alpha))
	draw_string_outline(font, pen + Vector2(4.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(INK, alpha))
	draw_string_outline(font, pen, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, Color(Color8(40, 14, 84), alpha))
	draw_string(font, pen, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(CREAM, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	# the subtitle states the buff's real numbers
	var so: float = ramp(t, SLAM + 0.12, SLAM + 0.3)
	if so > 0.0:
		var sub: String = "ATTACK SPEED +%d%%  /  DAMAGE +%d%%" % [roundi((Tuning.BLACK_KATANA_ATTACK_SPEED_MULT - 1.0) * 100.0), roundi((Tuning.BLACK_KATANA_DAMAGE_MULT - 1.0) * 100.0)]
		var sub_font_size: int = 18
		var sub_size: Vector2 = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_font_size)
		var sx: float = cx - (sub_size.x + 40.0) * 0.5 + 20.0 + 40.0 * (1.0 - ease_out(so))
		var sy: float = cy + 30.0
		var bar: PackedVector2Array = PackedVector2Array([Vector2(sx + 10.0, sy), Vector2(sx + sub_size.x + 40.0, sy), Vector2(sx + sub_size.x + 30.0, sy + sub_size.y + 14.0), Vector2(sx, sy + sub_size.y + 14.0)])
		draw_colored_polygon(bar, Color(INK, 0.88 * so))
		draw_line(bar[0], bar[1], Color(VIOLET, so), 2.0)
		draw_string(font, Vector2(sx + 20.0, sy + 7.0 + font.get_ascent(sub_font_size)), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_font_size, Color(0.82, 0.71, 1.0, so))


func _draw_exit_smear(t: float, off: float, step: int) -> void:
	var out: float = ease_in(ramp(t, 2.08, 2.32))
	if out <= 0.0 or out >= 1.0:
		return
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = step
	var rx: float = RIGHT_TOP + off
	for i: int in 14:
		var y: float = rnd.randf_range(100.0, 360.0)
		draw_line(Vector2(rx - 20.0, y), Vector2(rx + rnd.randf_range(80.0, 300.0) * (1.0 - out), y + SLOPE * 100.0), Color(0.78, 0.65, 1.0, rnd.randf_range(0.35, 0.78)), [1.0, 2.0, 3.0][rnd.randi() % 3])
