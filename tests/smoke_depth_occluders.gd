extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_depth_occluders.gd
## Arena depth occluders and shared actor-shadow regression. Layered depth/gate coverage lives in the layered suites.
const Arena := preload("res://presentation/arena/arena.gd")
const DepthOccluders := preload("res://presentation/common/depth_occluders.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Tuning := preload("res://core/tuning.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


## The index of the first drawable of `kind` (and occluder `id`) in the scene's sorted list, or -1.
func _index(list: Array[Dictionary], kind: StringName, id: StringName = &"") -> int:
	for i: int in list.size():
		var item: Dictionary = list[i]
		if item.get("kind", &"") != kind:
			continue
		if id != &"" and Dictionary(item.get("occluder", {})).get("id", &"") != id:
			continue
		return i
	return -1


func _run() -> void:
	# the data of every scene
	for scene_id: StringName in [SceneDefs.ARENA]:
		var data: Dictionary = DepthOccluders.scene_data(scene_id)
		_expect(not data.is_empty(), "%s: occluders load" % scene_id)
		if data.is_empty():
			continue
		_expect(data["texture"] is Texture2D, "%s: the atlas is a texture" % scene_id)
		_expect(Array(data["items"]).size() >= 5, "%s: at least 5 occluders (%d)" % [scene_id, Array(data["items"]).size()])
		for item: Dictionary in data["items"]:
			var rect: Rect2 = item["rect"]
			_expect(rect.size.x > 0 and rect.size.y > 0 and item["src"].size == rect.size, "%s/%s: rect and atlas region" % [scene_id, item["id"]])
			_expect(float(item["base_y"]) >= rect.position.y, "%s/%s: base below the top" % [scene_id, item["id"]])
	_expect(DepthOccluders.is_behind(140.0, 147.0) and not DepthOccluders.is_behind(147.0, 147.0) and not DepthOccluders.is_behind(150.0, 147.0), "is_behind: north of the base only")

	# the arena: a pillar sorts after the hero behind it, also after a restart
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	_expect(_arena_order(arena, Vector2(258, 384)), "arena: the hero behind the south pillar is drawn before it")
	arena._restart()
	await process_frame
	_expect(_arena_order(arena, Vector2(258, 384)), "arena: the same after a restart")
	var arena_draw: String = FileAccess.get_file_as_string("res://presentation/arena/arena.gd")
	arena_draw = arena_draw.substr(arena_draw.find("func _draw()"))
	arena_draw = arena_draw.substr(0, arena_draw.find("
func "))
	_expect(arena_draw.contains("DepthOccluders.drawables(OCCLUDER_SCENE") and arena_draw.find("DepthOccluders.drawables(") < arena_draw.find("drawables.sort_custom"), "arena: the occluders go into the y-sorted list before it is sorted")
	_expect(not DepthOccluders.scene_data(&"arena").is_empty(), "arena occluders stay loaded")
	arena.queue_free()

	# the shadow routine
	var p: Dictionary = ActorShadow.plan(Vector2(100.4, 50.6), 10.0)
	var core: Array = p["core"]
	var ring: Array = p["ring"]
	_expect(core.size() >= 3 and ring.size() >= 6, "the shadow has core rows (%d) and a ring (%d)" % [core.size(), ring.size()])
	var top: float = INF
	var bottom: float = -INF
	for r: Rect2 in core:
		_expect(r.position == r.position.round() and r.size == r.size.round() and r.size.y == 1.0, "core rows are whole-pixel spans %s" % str(r))
		_expect(r.get_center().x >= 99.0 and r.get_center().x <= 101.0, "core rows are centred under the feet %s" % str(r))
		_expect(r.size.x <= 2.0 * 10.0 * ActorShadow.SIZE, "no row is wider than the shadow %s" % str(r))
		top = minf(top, r.position.y)
		bottom = maxf(bottom, r.end.y)
	_expect(is_equal_approx((top + bottom) * 0.5, 51.0 + ActorShadow.OFFSET_Y + 0.5) or absf((top + bottom) * 0.5 - (51.0 + ActorShadow.OFFSET_Y + 0.5)) <= 1.0, "the shadow is OFFSET_Y below the feet (%.1f..%.1f)" % [top, bottom])
	for px: Vector2i in ring:
		_expect(posmod(px.x + px.y, 2) == 0, "the ring is a checkerboard %s" % str(px))
		for r: Rect2 in core:
			_expect(not r.has_point(Vector2(px) + Vector2(0.5, 0.5)), "ring pixel %s is not under a core row" % str(px))
	var small: Dictionary = ActorShadow.plan(Vector2(100, 50), 6.0)
	_expect(Array(small["core"]).size() <= core.size(), "a smaller radius gives a smaller shadow")
	_expect(ActorShadow.ALPHA >= 0.15 and ActorShadow.ALPHA <= 0.3, "subtle grounded actor shadow (alpha %.2f)" % ActorShadow.ALPHA)
	for scene_id: StringName in [SceneDefs.ARENA]:
		var s: float = ActorShadow.strength_for(scene_id)
		_expect(s >= 0.15 and s <= 0.3, "%s shadow strength %.2f" % [scene_id, s])
	for path: String in ["res://presentation/explore/explore_scene.gd", "res://presentation/arena/arena.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		_expect(src.contains("ActorShadow.draw(") and not src.contains("draw_colored_polygon(shadow"), "%s draws the shared shadow, not the ink ellipse" % path)
	var explore_src: String = FileAccess.get_file_as_string("res://presentation/explore/explore_scene.gd")
	var item_fn: String = explore_src.substr(explore_src.find("func _draw_item"))
	_expect(item_fn.find("ActorShadow.draw(") < item_fn.find("draw_texture_rect_region(sprites"), "explore: the shadow is drawn before the sprite")
	var arena_src: String = FileAccess.get_file_as_string("res://presentation/arena/arena.gd")
	var actor_fn: String = arena_src.substr(arena_src.find("func _draw_actor"))
	_expect(actor_fn.find("ActorShadow.draw(") < actor_fn.find("draw_texture_rect_region(actor_texture"), "arena: the shadow is drawn before the sprite")

	if failures.is_empty():
		print("SMOKE DEPTH OCCLUDERS OK")
		quit(0)
	else:
		for f: String in failures:
			printerr("FAIL " + f)
		quit(1)


## Builds the arena's draw list like _draw() and checks the hero sorts before the south pillar's occluder.
func _arena_order(arena: Arena, at: Vector2) -> bool:
	arena.core.player.position = at
	arena.core.step(InputFrame.new())
	arena.core.player.position = at
	arena.snapshot = arena.core.snapshot()
	var list: Array[Dictionary] = [{"actor": arena.snapshot.player, "at": arena.snapshot.player.position}]
	list.append_array(DepthOccluders.drawables(Arena.OCCLUDER_SCENE, {}, Rect2(at - Vector2(200, 200), Vector2(400, 400))))
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a["at"]).y < Vector2(b["at"]).y)
	var hero: int = -1
	var pillar: int = -1
	for i: int in list.size():
		if list[i].has("actor"):
			hero = i
		elif list[i]["occluder"]["id"] == &"pillar_s_left":
			pillar = i
	return hero >= 0 and pillar > hero
