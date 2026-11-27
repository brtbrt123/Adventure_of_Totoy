extends SceneTree
## MOCK-UP pictures for the owner (docs/PLAN_colossus_step3.md), not gameplay: the real Rootcrown scene and renderer, with a
## stand-in boss image, a mock chest light, made-up warnings drawn by the game's warning code, and a proposed fight camera.
## Nothing in the game changes. Reads docs/previews/colossus_step3/shots.json (tools/art/make_colossus_step3_preview.py).
## Windowed only (headless saves nothing):
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_step3/capture_mockup.gd
## Writes user://colossus_step3/<shot>.png. No save is read or written (no persist meta).
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Snapshots := preload("res://core/snapshots.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const EnvironmentLight := preload("res://presentation/common/environment_light.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Fireflies := preload("res://presentation/common/ambient_fireflies.gd")
const PREVIEWS: String = "res://docs/previews/colossus_step3/"
const OUT: String = "user://colossus_step3/"
const VIEW: Vector2 = Vector2(384, 216)
## The proposed fight camera: how near each screen edge the hero may get.
const HERO_SIDE: float = 28.0
const HERO_TOP: float = 44.0
const HERO_BOTTOM: float = 20.0
const CHEST_COLOUR: Vector3 = Vector3(0.36, 0.82, 1.0)
const CHEST_CORE: Vector3 = Vector3(0.80, 0.96, 1.0)
const OUTLINE: Color = Color("e0f0ec")  # water_6

var scene: Explore
var shot: Dictionary = {}
var boss: Vector2 = Vector2.ZERO
var body_radius: float = 46.0
var textures: Dictionary = {}
var body: ImageTexture
var ghost: ImageTexture


func _init() -> void:
	call_deferred("run")


func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func stand_in(size: int) -> Image:
	if not textures.has(size):
		textures[size] = Image.load_from_file(ProjectSettings.globalize_path(PREVIEWS + "mock/colossus_stand_in_%d.png" % size))
	return textures[size]


func warnings() -> Array[Snapshots.TelegraphSnapshot]:
	var out: Array[Snapshots.TelegraphSnapshot] = []
	for row: Dictionary in shot["telegraphs"]:
		var t: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		t.id = 9000 + out.size()
		t.kind = StringName(str(row["kind"]))
		t.shape = StringName(str(row["shape"]))
		t.center = vec(row["center"])
		t.muzzle = t.center
		t.direction = vec(row["direction"])
		t.size = float(row.get("size", 0.0))
		t.inner_size = float(row.get("inner_size", 0.0))
		t.half_angle = float(row.get("half_angle", 0.0))
		t.width = float(row.get("width", 0.0))
		t.start_tick = scene.snapshot.tick - 36
		t.hit_tick = scene.snapshot.tick + 18
		t.end_tick = t.hit_tick + 4
		out.append(t)
	return out


## The proposed camera: the hero-centred view, slid only as far as it takes to show the whole boss, the hero kept off the edges.
func fight_view(hero: Vector2, art: Vector2) -> Vector2:
	var origin: Vector2 = hero - VIEW * 0.5
	var box: Rect2 = Rect2(boss - Vector2(art.x * 0.5, art.y), art).grow(4.0)
	origin = origin.clamp(box.end - VIEW, box.position.max(box.end - VIEW))
	origin = origin.clamp(hero - VIEW + Vector2(HERO_SIDE, HERO_BOTTOM), hero - Vector2(HERO_SIDE, HERO_TOP))
	return origin.round().clamp(Vector2.ZERO, scene.snapshot.size - VIEW)


## Runs after the scene's own _draw: the stand-in boss, sorted against the hero, then its warnings' markers and its chest light.
func draw_boss() -> void:
	if shot.is_empty():
		return
	var image: Image = stand_in(int(shot["size"]))
	var art: Vector2 = Vector2(image.get_size())
	var corner: Vector2 = (boss - Vector2(art.x * 0.5, art.y - 2.0)).round()
	var hero: Vector2 = scene.snapshot.hero.position
	var behind: bool = hero.y < boss.y
	if bool(shot.get("bright", false)):
		bright_outlines()
	ActorShadow.draw(scene, boss, body_radius * 0.9, scene.shadow_strength())
	body = ImageTexture.create_from_image(image)  # kept in a member: the frame is rendered after this function returns
	scene.draw_texture(body, corner)
	for item: Dictionary in scene.drawables():
		if item["kind"] != &"hero":
			continue
		if not behind:
			scene._draw_item(item)
		elif bool(shot["outline"]):
			draw_ghost(item)
	for t: Snapshots.TelegraphSnapshot in scene.snapshot.telegraphs:
		var gold: bool = t.kind == &"gold"
		TelegraphView.draw_marker(scene, t, scene.colors["x"] if gold else scene.colors["z"], scene.colors["0"])
	chest_light(Vector2(boss.x, boss.y - art.y * 0.46))


## Proposed night warnings: the same outlines again at the lighting shader's unlit alpha, so the dark does not dim them.
func bright_outlines() -> void:
	var unlit: float = Fireflies.EMISSIVE_ALPHA
	for t: Snapshots.TelegraphSnapshot in scene.snapshot.telegraphs:
		var colour: Color = scene.colors["x"] if t.kind == &"gold" else scene.colors["z"]
		var edges: Array[PackedVector2Array] = [TelegraphView.outline(t)]
		if t.shape == &"ring":
			edges.append(TelegraphView.ring_points(t.center, t.inner_size))
		for edge: PackedVector2Array in edges:
			scene.draw_polyline(edge, Color(scene.colors["0"], unlit), 4.0)
			scene.draw_polyline(edge, Color(colour, unlit), 2.0)


## The hero behind the body: a pale one-pixel outline of his frame, and every other pixel of the frame, over the boss.
func draw_ghost(item: Dictionary) -> void:
	var frame: Dictionary = scene.frames[item["frame"]]
	var source: Image = scene.sprites.get_image().get_region(Rect2i(int(frame["x"]), int(frame["y"]), int(frame["w"]), int(frame["h"])))
	source.convert(Image.FORMAT_RGBA8)
	var out: Image = Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in source.get_height():
		for x: int in source.get_width():
			if source.get_pixel(x, y).a > 0.5:
				if (x + y) % 2 == 0:
					out.set_pixel(x, y, source.get_pixel(x, y))
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near: Vector2i = Vector2i(x, y) + step
				if Rect2i(Vector2i.ZERO, source.get_size()).has_point(near) and source.get_pixelv(near).a > 0.5:
					out.set_pixel(x, y, OUTLINE)
					break
	ghost = ImageTexture.create_from_image(out)
	scene.draw_texture_rect(ghost, ArenaAnimation.destination(Vector2(item["at"]).round(), frame, bool(item["left"])), false)


func chest_light(chest: Vector2) -> void:
	var material: ShaderMaterial = scene.material as ShaderMaterial
	if material == null:
		return
	var plan: Dictionary = EnvironmentLight.lamp_plan(scene.prop_placements)
	var points: PackedVector4Array = (plan["points"] as PackedVector4Array).duplicate()
	var colours: PackedVector3Array = (plan["colours"] as PackedVector3Array).duplicate()
	var cores: PackedVector3Array = (plan["core_colours"] as PackedVector3Array).duplicate()
	var count: int = int(plan["count"])
	for point: Vector4 in [Vector4(chest.x, chest.y, 56.0, 1.1), Vector4(chest.x, boss.y + 6.0, 140.0, -1.2)]:
		points[count] = point
		colours[count] = CHEST_COLOUR
		cores[count] = CHEST_CORE
		count += 1
	material.set_shader_parameter("lamps", points)
	material.set_shader_parameter("lamp_colours", colours)
	material.set_shader_parameter("lamp_core_colours", cores)
	material.set_shader_parameter("lamp_count", count)


func capture() -> void:
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var name: String = str(shot["name"])
	var error: Error = root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name, " ", error_string(error))


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_mockup: run it windowed")
		quit(1)
		return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREVIEWS + "shots.json"))
	boss = vec(spec["boss"])
	body_radius = float(spec["body_radius"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"rootcrown_layered"})
	var node: Node = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate()
	node.set_script(load("res://presentation/review/colossus_step3/mockup_scene.gd"))
	scene = node as Explore
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)  # after it is ready (ready turns it on again): a live tick would reset the camera and warnings
	var view_size: Vector2i = root.content_scale_size
	var window_size: Vector2i = root.size
	scene.set("after_draw", Callable(self, "draw_boss"))
	scene.fade_phase = &""
	scene.core.set_flag(&"received_first_sword")
	scene.core.set_flag(&"debug_all_unlocked")
	(scene.get_node("HUD") as CanvasLayer).hide()
	for entry: Dictionary in spec["shots"]:
		shot = {}
		var hero: Vector2 = vec(entry["hero"])
		scene.core.place_at(hero)
		scene.core.player.facing = (boss - hero).normalized()
		for i: int in 4:
			scene.advance(InputFrame.new())
		scene.toast_ticks = 0
		shot = entry
		scene.snapshot.telegraphs.clear()
		scene.snapshot.telegraphs.append_array(warnings())
		var whole: bool = bool(entry["whole_map"])
		scene.camera.enabled = not whole
		root.content_scale_size = Vector2i(scene.snapshot.size) if whole else view_size
		root.size = Vector2i(scene.snapshot.size) if whole else window_size
		if str(entry["camera"]) == "frame" and not whole:
			scene.view_origin = fight_view(scene.snapshot.hero.position, Vector2(stand_in(int(entry["size"])).get_size()))
			scene.camera.position = scene.view_origin + VIEW * 0.5
			scene.camera.force_update_scroll()
		await capture()
	print("MOCKUP CAPTURE OK")
	quit(0)
