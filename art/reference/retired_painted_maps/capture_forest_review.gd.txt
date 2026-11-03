extends SceneTree
## Windowed mock capture of the forest route and the Stag glade as the player would see them, for the human's review
## of the converted paintings and the layouts (no scene manager exists yet, so this does NOT use the arena scene or
## any game code: it draws the ground texture under a Camera2D clamped to the world, like the arena camera, the hero
## frame hero2_idle_right_1 from art/build/sprites.png and the chapter 1 creatures from the reference sheets in
## art/reference/chapter1_creatures/ at the layouts' spawn points). The scenes are at their game scales (forest 0.6 =
## 480x288, glade 0.7 = 560x336; core/forest_layout.gd / core/glade_layout.gd SCALE); characters keep their pixel size.
##   godot --path . --script res://tests/capture_forest_review.gd
## Every actor stands on the game's shared soft ground shadow (presentation/common/actor_shadow.gd: translucent ink,
## hard-pixel rows with a dithered ring; radius 10 for the hero, here scaled per creature) and its
## sprite is multiplied by the scene's AMBIENT tint (a few percent toward the canopy light) so it sits in the painting
## without losing readability. The real scene renderer should do the same: that shadow plus one ambient tint constant
## per scene.
## Saves into docs/previews/:
##   forest_full_v1.png, glade_full_v1.png   the whole scene at 2x, stitched from 9 real camera views, with the hero at
##                                           the entry point and the creatures (the Stag in the glade)
##   forest_view_<name>.png, glade_view_<name>.png   1x camera views (320x180) with the hero standing somewhere
## Run tools/art/compare_forest_target.py afterwards for forest_vs_target.png and glade_vs_target.png.
## (The scale options the human chose from, docs/previews/forest_scale_options.png and glade_scale_options.png, were
## rendered by an earlier version of this script; that mode and its files were removed after the choice.)
const ForestLayout := preload("res://core/forest_layout.gd")
const GladeLayout := preload("res://core/glade_layout.gd")
const OUT_DIR: String = "res://docs/previews/"
const VIEW: Vector2 = Vector2(320.0, 180.0)
const CREATURES: String = "res://art/reference/chapter1_creatures/"
## kind -> [sheet base name, frame name]
const FRAMES: Dictionary = {
	"mossling": ["creature_mossling_v1", "creature_mossling_idle_1"],
	"thornback_boar": ["creature_thornback_boar_v1", "creature_thornback_boar_idle_1"],
	"glowmoth": ["creature_glowmoth_v1", "creature_glowmoth_flutter_1"],
	"thornback_stag": ["creature_thornback_stag_v1", "creature_thornback_stag_idle_1"],
}
const HERO_FRAME: String = "hero2_idle_right_1"
## [name, where the hero stands] measured at 1.0 (the layouts' *_1X coordinates), scaled with the scene.
const FOREST_VIEWS_1X: Array = [
	["entrance", Vector2(60, 268)], ["first_clearing", Vector2(262, 210)], ["second_clearing", Vector2(470, 300)],
	["lantern_gate", Vector2(596, 212)], ["dead_end_chest", Vector2(724, 326)], ["north_exit", Vector2(646, 40)],
]
const GLADE_VIEWS_1X: Array = [
	["entrance", Vector2(60, 440)], ["ring", Vector2(262, 270)], ["spring", Vector2(445, 300)],
	["arch", Vector2(630, 150)],
]
## Shadow radius per actor (the arena: hero 10, boss 20) and the per-scene ambient multiply.
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const SHADOW_RADIUS: Dictionary = {"hero": 10.0, "mossling": 7.0, "thornback_boar": 14.0, "glowmoth": 5.0, "thornback_stag": 18.0}
const AMBIENT: Dictionary = {"forest": Color(0.9, 0.94, 0.88), "glade": Color(0.88, 0.95, 0.94)}
const INK: Color = Color("#1c1824")

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
	# (the north_exit view puts the hero on the exit path behind the gate; the painting always shows the gate closed)
	world_size = ForestLayout.SIZE
	ok = await _scene("forest", "res://presentation/forest/forest_route_ground.png", ForestLayout.spawns_scaled(ForestLayout.SCALE),
		ForestLayout.ENTRY_POINT, _views(FOREST_VIEWS_1X, ForestLayout.SCALE), "") and ok
	world_size = GladeLayout.SIZE
	ok = await _scene("glade", "res://presentation/forest/stag_glade_ground.png", [["thornback_stag", GladeLayout.STAG_START]],
		GladeLayout.PLAYER_START, _views(GLADE_VIEWS_1X, GladeLayout.SCALE), "") and ok
	print("FOREST REVIEW captured" if ok else "FOREST REVIEW failed")
	quit(0 if ok else 1)


## The views at `sc`: [name, hero position].
func _views(rows: Array, sc: float) -> Array:
	var out: Array = []
	for row: Array in rows:
		out.append([row[0], ((row[1] as Vector2) * sc).round()])
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
	# the game's actor shadow (presentation/common/actor_shadow.gd), drawn before the sprite
	var ground_shadow: Node2D = Node2D.new()
	ground_shadow.draw.connect(func() -> void: ActorShadow.draw(ground_shadow, Vector2.ZERO, shadow, ActorShadow.ALPHA))
	holder.add_child(ground_shadow)
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
