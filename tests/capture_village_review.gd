extends SceneTree
## Windowed capture of Lanternfen village (scene S1) as a standalone mock, for the human's review of the village look.
## It does not use the arena scene or art/src: it loads PNG files directly (Image.load_from_file), draws the converted
## ground, the people at their stand points (core/village_layout.gd) and the hero at the gate, and looks through a
## 320x180 camera clamped to the village, the same crop rule as the arena camera. The village is the 0.7 conversion
## (571x336, VillageLayout.SCALE).
## Every person stands on a ground shadow drawn exactly like the arena's actor shadow (presentation/arena/arena.gd
## _draw_actor: an opaque ink (palette 0) 32-point ellipse, x radius r, y radius 0.3 r, 2 px below the feet; the hero's r
## is 10), with r scaled by the person's height against the hero's 34 px, and every person is modulated by AMBIENT, a
## slight warm-evening darkening, so the bright sprites sit in the dusk painting. The real village scene should do the
## same: the arena shadow plus a per-scene ambient tint constant.
##   godot --path . --script res://tests/capture_village_review.gd      (the regular, windowed exe)
## Saves into docs/previews/:
##   village_full_v1.png       the whole 571x336 village at 2x, stitched from 9 camera views, people and hero standing
##   village_view_<name>.png   1x camera views (320x180): gate, forge_yard, house, crossroads, the hero in each
## Run tools/art/compare_village_target.py afterwards for docs/previews/village_vs_target.png.
## The sprites are review art (art/reference/chapter1_characters_v2/npc_sprites_v2.png, the hero frame
## art/build/sprites/hero2_idle_right_1.png); the scene manager and the real village scene do not exist yet.
const VillageLayout := preload("res://core/village_layout.gd")
const OUT_DIR: String = "res://docs/previews/"
const GROUND: String = "res://presentation/village/village_ground.png"
const NPC_ATLAS: String = "res://art/reference/chapter1_characters_v2/npc_sprites_v2.png"
const NPC_JSON: String = "res://art/reference/chapter1_characters_v2/npc_sprites_v2.json"
const HERO: String = "res://art/build/sprites/hero2_idle_right_1.png"
const HERO_ANCHOR: Vector2 = Vector2(12, 35)  # art/build/sprites.json ax/ay of hero2_idle_right_1
const HERO_HEIGHT: float = 34.0
const VIEW_SIZE: Vector2 = Vector2(320.0, 180.0)
## The arena's hero shadow radius (presentation/arena/arena.gd _draw_actor) and its ink colour (palette 0).
const SHADOW_RADIUS: float = 10.0
const SHADOW_COLOUR: Color = Color("#1c1824")
## The village's evening ambient: a few percent darker and warmer on the people (multiply), not on the ground.
const AMBIENT: Color = Color(0.93, 0.89, 0.84)
## [stand point id, frame, face left] (the chest gets no shadow and no tint: it is an object, like the painted props)
const PEOPLE: Array = [
	[&"mira", "npc_mira_idle_right_1", true],
	[&"tovan", "npc_tovan_idle_right_1", true],
	[&"edda", "npc_edda_idle_right_1", true],
	[&"villager_elder", "npc_elder_idle_right_1", true],
	[&"villager_child", "npc_child_idle_right_1", false],
	[&"villager_worker", "npc_worker_idle_right_1", true],
	[&"chest", "obj_chest_closed_1", false],
]
## [name, camera focus, where the hero stands], measured at scale 1.0 (scaled by VillageLayout.SCALE when used)
const VIEWS: Array = [
	["gate", Vector2(190, 236), Vector2(172, 284)],
	["forge_yard", Vector2(450, 170), Vector2(420, 212)],
	["house", Vector2(640, 200), Vector2(606, 240)],
	["crossroads", Vector2(400, 320), Vector2(420, 292)],
]

var camera: Camera2D
var hero: Sprite2D
var hero_shadow: Polygon2D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node2D = Node2D.new()
	root.add_child(world)
	var ground: Sprite2D = Sprite2D.new()
	ground.texture = _texture(GROUND)
	ground.centered = false
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(ground)
	var shadows: Node2D = Node2D.new()  # under every actor, like the arena (shadows are drawn before the sprites)
	world.add_child(shadows)
	var actors: Node2D = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	var atlas: Texture2D = _texture(NPC_ATLAS)
	var frames: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(NPC_JSON))) as Dictionary)["frames"]
	for entry: Array in PEOPLE:
		var f: Dictionary = frames[entry[1]]
		var region: AtlasTexture = AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2(f["x"], f["y"], f["w"], f["h"])
		var feet: Vector2 = VillageLayout.STAND_POINTS[entry[0]]
		var person: Sprite2D = _sprite(region, feet, Vector2(f["ax"], f["ay"]), bool(entry[2]))
		actors.add_child(person)
		if String(entry[1]).begins_with("npc_"):
			person.modulate = AMBIENT
			shadows.add_child(_shadow(feet, SHADOW_RADIUS * _height(atlas.get_image(), f) / HERO_HEIGHT))
	hero = _sprite(_texture(HERO), VillageLayout.ARRIVAL_SPAWN, HERO_ANCHOR, false)
	hero.modulate = AMBIENT
	actors.add_child(hero)
	hero_shadow = _shadow(VillageLayout.ARRIVAL_SPAWN, SHADOW_RADIUS)
	shadows.add_child(hero_shadow)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	world.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# the whole village from 9 camera views, the hero at the gate
	var size: Vector2 = VillageLayout.VILLAGE_SIZE
	var full: Image = Image.create(int(size.x) * 2, int(size.y) * 2, false, Image.FORMAT_RGBA8)
	var xs: Array[float] = [0.0, (size.x - VIEW_SIZE.x) * 0.5, size.x - VIEW_SIZE.x]
	var ys: Array[float] = [0.0, (size.y - VIEW_SIZE.y) * 0.5, size.y - VIEW_SIZE.y]
	for y: float in ys:
		for x: float in xs:
			var origin: Vector2 = Vector2(x, y).round()
			var shot: Image = await _shot(origin + VIEW_SIZE * 0.5)
			shot.resize(int(VIEW_SIZE.x) * 2, int(VIEW_SIZE.y) * 2, Image.INTERPOLATE_NEAREST)
			full.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(origin * 2.0))
	full.save_png(ProjectSettings.globalize_path(OUT_DIR + "village_full_v1.png"))
	# 1x camera views with the hero standing in each
	for entry: Array in VIEWS:
		hero.position = VillageLayout.point_scaled(entry[2], VillageLayout.SCALE)
		hero_shadow.position = hero.position
		var shot: Image = await _shot(VillageLayout.point_scaled(entry[1], VillageLayout.SCALE))
		shot.resize(int(VIEW_SIZE.x), int(VIEW_SIZE.y), Image.INTERPOLATE_NEAREST)
		shot.save_png(ProjectSettings.globalize_path(OUT_DIR + "village_view_%s.png" % entry[0]))
	print("VILLAGE REVIEW captured")
	quit(0)


## One frame of the camera centred on `focus`, clamped so the view stays inside the village (the arena camera's rule).
func _shot(focus: Vector2) -> Image:
	var half: Vector2 = VIEW_SIZE * 0.5
	var origin: Vector2 = (focus - half).clamp(Vector2.ZERO, VillageLayout.VILLAGE_SIZE - VIEW_SIZE).round()
	camera.position = origin + half
	for k: int in 3:
		await process_frame
	return root.get_texture().get_image()


## A sprite placed by its feet: `anchor` is the feet inside the frame; facing left mirrors around the anchor.
func _sprite(texture: Texture2D, feet: Vector2, anchor: Vector2, face_left: bool) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.flip_h = face_left
	s.position = feet
	var w: float = texture.get_size().x
	s.offset = Vector2(-(w - anchor.x) if face_left else -anchor.x, -anchor.y)
	return s


## The arena's actor shadow (presentation/arena/arena.gd _draw_actor) at `feet` with x radius `radius`.
func _shadow(feet: Vector2, radius: float) -> Polygon2D:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		points.append(Vector2(cos(TAU * i / 32.0) * radius, sin(TAU * i / 32.0) * radius * 0.3 + 2))
	var shadow: Polygon2D = Polygon2D.new()
	shadow.polygon = points
	shadow.color = SHADOW_COLOUR
	shadow.position = feet.round()
	return shadow


## The visible height of an atlas frame (rows with any opaque pixel).
func _height(atlas_image: Image, f: Dictionary) -> float:
	var region: Image = atlas_image.get_region(Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"])))
	var used: Rect2i = region.get_used_rect()
	return float(used.size.y)


func _texture(path: String) -> Texture2D:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		push_error("cannot load " + path)
		return null
	return ImageTexture.create_from_image(img)
