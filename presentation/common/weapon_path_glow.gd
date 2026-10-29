extends Node2D
## A local emissive pass owned by the shared hero_fx base, so night lighting cannot swallow the trails or sparks.
## Only the small path texture is sampled; this is not a full-screen bloom or a new lighting/gameplay rule.
const Paths := preload("res://presentation/common/weapon_paths.gd")
const Snapshots := preload("res://core/snapshots.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const GLOW_SHADER := preload("res://presentation/common/weapon_path_glow.gdshader")
const MAX_SPARKS: int = 48
const ANCHOR: Vector2 = Vector2(48, 78)
const COLOURS: Dictionary = {"katana": Color8(138, 111, 168), "daggers": Color8(167, 205, 224), "scythe": Color8(106, 168, 154)}
const PALE: Color = Color8(224, 240, 236)
var glow_key: String = ""
var sparks: Array[Dictionary] = []
var glow_draws: int = 0
var _textures: Dictionary = {}
var _points: Dictionary = {}
var _last_tick: int = -1
var _at: Vector2 = Vector2.ZERO
var _left: bool = false
var _tint: Color = Color.WHITE
var _tick: int = 0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var glow_material: ShaderMaterial = ShaderMaterial.new()
	glow_material.shader = GLOW_SHADER
	material = glow_material


func _process(_delta: float) -> void:
	sync_from_host()


func texture_for(key: String) -> Texture2D:
	if not _textures.has(key):
		var path: String = "res://art/build/sprites/%s.png" % key
		_textures[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[key]


func emission_points(key: String) -> Array[Vector2]:
	if not _points.has(key):
		var candidates: Array[Vector2] = []
		var texture: Texture2D = texture_for(key)
		if texture != null:
			var image: Image = texture.get_image()
			for y: int in image.get_height():
				for x: int in image.get_width():
					var pixel: Color = image.get_pixel(x, y)
					if pixel.a > 0.5 and maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.7:
						candidates.append(Vector2(x, y) - ANCHOR)
		_points[key] = candidates
	return _points[key]


func sync_from_host() -> void:
	var host: Node = get_parent()
	if host == null or host.call("fx_snapshot") == null:
		return
	_tick = int(host.call("fx_tick")) + int(host.call("fx_result_ticks"))
	if _tick < _last_tick:
		sparks.clear()  # restart or scene transition
	var hero: Snapshots.EntitySnapshot = host.call("fx_hero") as Snapshots.EntitySnapshot
	var pose: String = String(host.call("fx_hero_frame"))
	glow_key = Paths.key(hero, pose) if bool(host.call("fx_playing")) and not bool(host.call("hero_hidden")) else ""
	_at = hero.position.round()
	_left = bool(host.get("facing_left"))
	if not glow_key.is_empty():
		var family: String = glow_key.trim_prefix("fx_weapon_path_").get_slice("_", 0)
		_tint = COLOURS.get(family, PALE)
	var alive: Array[Dictionary] = []
	for spark: Dictionary in sparks:
		if _tick - int(spark["born"]) < int(spark["life"]):
			alive.append(spark)
	sparks = alive
	# Cosmetic only: emit along the existing bright cutting edge, even on a missed attack. One burst per fresh tick.
	if _tick != _last_tick and not glow_key.is_empty() and hero.state == &"attack_active":
		var points: Array[Vector2] = emission_points(glow_key)
		for index: int in 3:
			if points.is_empty():
				break
			var point: Vector2 = points[posmod(_tick * 7 + index * 19, points.size())]
			point.x *= -1.0 if _left else 1.0
			var angle: float = TAU * float(posmod(_tick * 13 + index * 29, 97)) / 97.0
			var velocity: Vector2 = Vector2.from_angle(angle) * (0.24 + index * 0.09) + Vector2(0, -0.18)
			sparks.append({"at": _at + point, "velocity": velocity, "born": _tick, "life": 9 + index * 2, "colour": _tint})
		while sparks.size() > MAX_SPARKS:
			sparks.pop_front()
	_last_tick = _tick
	queue_redraw()


func _draw() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var shake: Vector2 = host.call("shake_offset")
	if not glow_key.is_empty():
		var texture: Texture2D = texture_for(glow_key)
		if texture != null:
			var frame: Dictionary = {"w": 128, "h": 96, "ax": 48, "ay": 78}
			draw_texture_rect(texture, ArenaAnimation.destination(_at + shake, frame, _left), false, Color(_tint, 0.65))
			glow_draws += 1
	for spark: Dictionary in sparks:
		var age: int = maxi(0, _tick - int(spark["born"]))
		var at: Vector2 = (Vector2(spark["at"]) + Vector2(spark["velocity"]) * age + shake).round()
		var tint: Color = spark["colour"]
		draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), Color(tint, 0.40))
		draw_rect(Rect2(at, Vector2.ONE), Color(PALE if age < 3 else tint, 0.99))
