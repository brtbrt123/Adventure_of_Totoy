extends SceneTree
## Windowed mock capture of the forest route and the Stag glade as the player would see them, for the human's review
## of the converted paintings and the layouts (no scene manager exists yet, so this does NOT use the arena scene or
## any game code: it draws the ground texture under a Camera2D clamped to the world, like the arena camera, the hero
## frame hero2_idle_right_1 from art/build/sprites.png and the chapter 1 creatures from the reference sheets in
## art/reference/chapter1_creatures/ at the layouts' spawn points):
##   godot --path . --script res://tests/capture_forest_review.gd
## Every actor stands on the arena's ground shadow (presentation/arena/arena.gd _draw_actor: an opaque ink (palette 0)
## ellipse, x radius r, y radius 0.3 r, 2 px below the feet; r = 10 for the hero, here scaled per creature) and its
## sprite is multiplied by the scene's AMBIENT tint (a few percent toward the canopy light) so it sits in the painting
## without losing readability. The real scene renderer should do the same: that shadow plus one ambient tint constant
## per scene.
## Saves into docs/previews/:
##   forest_full_v1.png, glade_full_v1.png   the whole 800x480 scene at 2x, stitched from 9 real camera views, with the
##                                           hero at the entry point and the creatures (the Stag in the glade)
##   forest_view_<name>.png, glade_view_<name>.png   1x camera views (320x180) with the hero standing somewhere
## Run tools/art/compare_forest_target.py afterwards for forest_vs_target.png and glade_vs_target.png.
## Scale options (the human's review, 2026-10-22: the hero looks tiny next to the painted trees and stones):
##   godot --path . --script res://tests/capture_forest_review.gd -- --scales
## renders, for every scale in SCALES (1.0 = the approved files, the others the *_sNNN.png options made by
## tools/art/make_forest_ground_from_reference.py --scale S, with the layouts' *_scaled points; characters keep their
## pixel size), <scene>_sNNN_full.png (2x stitch) and the comparison crops <scene>_sNNN_crop_<name>.png (1x camera
## views: forest sign / pedestals, glade ring) into docs/previews/scale_options/; tools/art/make_forest_scale_sheet.py
## turns them into docs/previews/forest_scale_options.png and glade_scale_options.png.
const ForestLayout := preload("res://core/forest_layout.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const OUT_DIR: String = "res://docs/previews/"
const VIEW: Vector2 = Vector2(320.0, 180.0)
const SCALES: Array[float] = [1.0, 0.7, 0.6, 0.5]
const SCALE_DIR: String = "res://docs/previews/scale_options/"
## The comparison crops at 1.0: [name, where the hero stands, where the camera looks] (both scaled with the scene).
const FOREST_CROPS: Array = [["sign", Vector2(262, 210), Vector2(250, 222)], ["pedestals", Vector2(630, 302), Vector2(580, 252)]]
const GLADE_CROPS: Array = [["ring", Vector2(262, 270), Vector2(415, 262)]]
const CREATURES: String = "res://art/reference/chapter1_creatures/"
## kind -> [sheet base name, frame name]
const FRAMES: Dictionary = {
	"mossling": ["creature_mossling_v1", "creature_mossling_idle_1"],
	"thornback_boar": ["creature_thornback_boar_v1", "creature_thornback_boar_idle_1"],
	"glowmoth": ["creature_glowmoth_v1", "creature_glowmoth_flutter_1"],
	"thornback_stag": ["creature_thornback_stag_v1", "creature_thornback_stag_idle_1"],
}
const HERO_FRAME: String = "hero2_idle_right_1"
## [name, where the hero stands]
const FOREST_VIEWS: Array = [
	["entrance", Vector2(60, 268)], ["first_clearing", Vector2(200, 262)], ["second_clearing", Vector2(440, 330)],
	["lantern_gate", Vector2(596, 212)], ["dead_end_chest", Vector2(724, 326)], ["north_exit", Vector2(646, 40)],
]
## Shadow x radius per actor (the arena: hero 10, boss 20) and the per-scene ambient multiply.
const SHADOW_RADIUS: Dictionary = {"hero": 10.0, "mossling": 7.0, "thornback_boar": 14.0, "glowmoth": 5.0, "thornback_stag": 18.0}
const AMBIENT: Dictionary = {"forest": Color(0.9, 0.94, 0.88), "glade": Color(0.88, 0.95, 0.94)}
const INK: Color = Color("#1c1824")
const GLADE_VIEWS: Array = [
	["entrance", Vector2(60, 440)], ["ring", Vector2(300, 330)], ["spring", Vector2(445, 300)],
	["arch", Vector2(615, 190)],
]

var world_size: Vector2 = Vector2(800.0, 480.0)
var camera: Camera2D
var world: Node2D
var actors: Node2D
var hero: Node2D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ok: bool = true
	if OS.get_cmdline_user_args().has("--scales"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCALE_DIR))
		for sc: float in SCALES:
			var tag: String = "" if is_equal_approx(sc, 1.0) else "_s%03d" % roundi(sc * 100.0)
			var stem: String = "_s%03d" % roundi(sc * 100.0)
			world_size = ForestLayout.size_scaled(sc)
			ok = await _scene("forest", "res://presentation/forest/forest_route_ground%s.png" % tag, _forest_actors(sc),
				ForestLayout.point_scaled(ForestLayout.ENTRY_POINT, sc), _crops(FOREST_CROPS, sc), SCALE_DIR + "forest" + stem) and ok
			ok = await _scene("glade", "res://presentation/forest/stag_glade_ground%s.png" % tag, _glade_actors(sc),
				GladeLayout.point_scaled(GladeLayout.PLAYER_START, sc), _crops(GLADE_CROPS, sc), SCALE_DIR + "glade" + stem) and ok
		print("FOREST SCALES captured" if ok else "FOREST SCALES failed")
		quit(0 if ok else 1)
		return
	# (the north_exit view puts the hero on the exit path behind the gate; the painting always shows the gate closed)
	ok = await _scene("forest", "res://presentation/forest/forest_route_ground.png", _forest_actors(1.0), ForestLayout.ENTRY_POINT, FOREST_VIEWS, "") and ok
	ok = await _scene("glade", "res://presentation/forest/stag_glade_ground.png", _glade_actors(1.0), GladeLayout.PLAYER_START, GLADE_VIEWS, "") and ok
	print("FOREST REVIEW captured" if ok else "FOREST REVIEW failed")
	quit(0 if ok else 1)


## [kind, position] for every creature in the scene.
func _forest_actors(sc: float) -> Array:
	return ForestLayout.spawns_scaled(sc)


func _glade_actors(sc: float) -> Array:
	return [["thornback_stag", GladeLayout.point_scaled(GladeLayout.STAG_START, sc)]]


## The comparison crops at `sc`: [name, hero position, camera centre].
func _crops(rows: Array, sc: float) -> Array:
	var out: Array = []
	for row: Array in rows:
		out.append([row[0], ((row[1] as Vector2) * sc).round(), ((row[2] as Vector2) * sc).round()])
	return out


## Renders one scene: the 2x stitch and the 1x views. `stem` empty = the default review files (<name>_full_v1.png,
## <name>_view_<view>.png); otherwise <stem>_full.png and <stem>_crop_<view>.png. A view is [name, hero position] or
## [name, hero position, camera centre].
func _scene(name: String, ground_path: String, creatures: Array, hero_start: Vector2, views: Array, stem: String) -> bool:
	var ground: Texture2D = _texture(ground_path)
	if ground == null:
		return false
	world = Node2D.new()
	root.add_child(world)
	var g: Sprite2D = Sprite2D.new()
	g.texture = ground
	g.centered = false
	world.add_child(g)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	for row: Array in creatures:
		var kind: String = row[0]
		var node: Node2D = _creature(kind, AMBIENT[name])
		if node == null:
			return false
		node.position = row[1]
		# face the hero's side of the scene (the sheets face right; mirrored around the anchor)
		node.scale.x = -1.0 if (row[1] as Vector2).x > hero_start.x else 1.0
		actors.add_child(node)
	hero = _hero(AMBIENT[name])
	if hero == null:
		return false
	actors.add_child(hero)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	world.add_child(camera)
	camera.make_current()
	# the whole scene at 2x from 9 camera views, the hero at the entry point
	hero.position = hero_start
	var full: Image = Image.create(int(world_size.x) * 2, int(world_size.y) * 2, false, Image.FORMAT_RGBA8)
	var xs: Array[float] = [0.0, (world_size.x - VIEW.x) * 0.5, world_size.x - VIEW.x]
	var ys: Array[float] = [0.0, (world_size.y - VIEW.y) * 0.5, world_size.y - VIEW.y]
	for y: float in ys:
		for x: float in xs:
			var origin: Vector2 = Vector2(x, y).round()
			var shot: Image = await _shot(origin + VIEW * 0.5)
			shot.resize(int(VIEW.x) * 2, int(VIEW.y) * 2, Image.INTERPOLATE_NEAREST)
			full.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(origin * 2.0))
	full.save_png(ProjectSettings.globalize_path(OUT_DIR + "%s_full_v1.png" % name if stem.is_empty() else stem + "_full.png"))
	# 1x views following the hero (or looking at a fixed spot)
	for entry: Array in views:
		hero.position = entry[1]
		var shot: Image = await _shot(entry[2] if entry.size() > 2 else entry[1])
		shot.resize(int(VIEW.x), int(VIEW.y), Image.INTERPOLATE_NEAREST)
		var path: String = OUT_DIR + "%s_view_%s.png" % [name, entry[0]] if stem.is_empty() else stem + "_crop_%s.png" % entry[0]
		shot.save_png(ProjectSettings.globalize_path(path))
	world.queue_free()
	await process_frame
	return true


## One frame of the camera centred on `at` (clamped to the world like the arena camera, whole pixels).
func _shot(at: Vector2) -> Image:
	var half: Vector2 = VIEW * 0.5
	camera.position = Vector2(clampf(at.x, half.x, world_size.x - half.x), clampf(at.y, half.y, world_size.y - half.y)).round()
	camera.reset_smoothing()
	for k: int in 3:
		await process_frame
	return root.get_texture().get_image()


func _texture(path: String) -> Texture2D:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		printerr("cannot load " + path)
		return null
	return ImageTexture.create_from_image(img)


## A sprite cut from a sheet by a frame rect {x, y, w, h, ax, ay}, placed by its anchor (the node's origin = feet).
func _framed(sheet: Texture2D, frame: Dictionary, shadow: float, tint: Color) -> Node2D:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(frame["x"], frame["y"], frame["w"], frame["h"])
	var s: Sprite2D = Sprite2D.new()
	s.texture = atlas
	s.centered = false
	s.offset = -Vector2(frame["ax"], frame["ay"])
	s.modulate = tint
	var holder: Node2D = Node2D.new()
	# the arena's actor shadow: an opaque ink ellipse under the feet, drawn before the sprite
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		points.append(Vector2(cos(TAU * i / 32.0) * shadow, sin(TAU * i / 32.0) * shadow * 0.3 + 2))
	var ellipse: Polygon2D = Polygon2D.new()
	ellipse.polygon = points
	ellipse.color = INK
	holder.add_child(ellipse)
	holder.add_child(s)
	return holder


func _creature(kind: String, tint: Color) -> Node2D:
	var base: String = CREATURES + FRAMES[kind][0]
	var sheet: Texture2D = _texture(base + ".png")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if sheet == null or not (data is Dictionary) or not (data["frames"] as Dictionary).has(FRAMES[kind][1]):
		printerr("cannot read the %s sheet" % kind)
		return null
	return _framed(sheet, data["frames"][FRAMES[kind][1]], SHADOW_RADIUS[kind], tint)


func _hero(tint: Color) -> Node2D:
	var sheet: Texture2D = _texture("res://art/build/sprites.png")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))
	if sheet == null or not (data is Dictionary) or not (data["frames"] as Dictionary).has(HERO_FRAME):
		printerr("cannot read " + HERO_FRAME)
		return null
	return _framed(sheet, data["frames"][HERO_FRAME], SHADOW_RADIUS["hero"], tint)
