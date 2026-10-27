extends "res://tests/test_case.gd"
## Layered scenes (core/prop_scene.gd): the shared prop data gives the colliders and the placements, validation catches
## bad data, solid props stop the hero from every side, decor is walkable, a flip mirrors the colliders, determinism,
## and every real scene file under data/scenes/ validates against data/props/prop_defs.json (when the files exist).

const Obstacle := preload("res://core/obstacle.gd")
const PropScene := preload("res://core/prop_scene.gd")
const Collision := preload("res://core/collision.gd")

const HERO: float = 6.0  # Tuning.PLAYER_RADIUS
const DEFS: String = "res://tests/fixtures/props/test_defs.json"
const SCENE: String = "res://tests/fixtures/props/test_scene.json"
const DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]


func _data() -> Array:
	return [PropScene.load_scene(SCENE), PropScene.load_defs(DEFS)]


func test_the_fixture_is_valid() -> void:
	var d: Array = _data()
	assert_eq(PropScene.validate(d[0], d[1]).size(), 0, "no problems: %s" % str(PropScene.validate(d[0], d[1])))


func test_validation_catches_bad_data() -> void:
	var d: Array = _data()
	var scene: Dictionary = d[0].duplicate(true)
	var defs: Dictionary = d[1].duplicate(true)
	assert_true(PropScene.validate({}, defs).size() > 0, "an empty scene is an error")
	assert_true(PropScene.validate(scene, {}).size() > 0, "no defs is an error")
	scene["props"].append({"id": "pillar_a", "type": "pillar", "x": 10, "y": 10})
	assert_true(PropScene.validate(scene, defs).size() > 0, "a duplicate id is an error")
	scene = d[0].duplicate(true)
	scene["props"].append({"id": "ghost", "type": "nope", "x": 10, "y": 10})
	assert_true(PropScene.validate(scene, defs).size() > 0, "an unknown type is an error")
	scene = d[0].duplicate(true)
	scene["props"].append({"id": "far", "type": "bone", "x": 999, "y": 10})
	assert_true(PropScene.validate(scene, defs).size() > 0, "an anchor outside the world is an error")
	scene = d[0].duplicate(true)
	defs["props"]["pillar"]["colliders"] = []
	assert_true(PropScene.validate(scene, defs).size() > 0, "solid without colliders is an error")
	defs = d[1].duplicate(true)
	defs["props"]["pillar"]["colliders"] = [[0, 4, 5]]
	assert_true(PropScene.validate(scene, defs).size() > 0, "a collider below the base line is an error")
	defs = d[1].duplicate(true)
	defs["props"]["pillar"]["anchor"] = [12, 99]
	assert_true(PropScene.validate(scene, defs).size() > 0, "an anchor outside the sprite is an error")


func test_placements_carry_what_presentation_draws() -> void:
	var d: Array = _data()
	var list: Array = PropScene.placements(d[0], d[1])
	assert_eq(list.size(), 3, "three props in file order")
	assert_eq(list[0]["id"], &"pillar_a", "file order")
	assert_eq(list[0]["feet"], Vector2(100, 70), "the anchor's place in the world")
	assert_eq(list[0]["anchor"], Vector2(12, 48), "the anchor in the sprite")
	assert_eq(list[0]["size"], Vector2(24, 48), "the sprite size")
	assert_eq(list[0]["image"], "pillar.png", "the image name")
	assert_true(list[1]["flip"], "flip is passed on")
	assert_false(list[2]["solid"], "decor is not solid")


func test_colliders_come_from_the_props_and_decor_adds_none() -> void:
	var d: Array = _data()
	var circles: Array[Vector3] = PropScene.prop_colliders(d[0], d[1])
	assert_eq(circles.size(), 3, "two for the pillar, one for the lopsided prop, none for the bone")
	assert_true(circles.has(Vector3(95, 68, 5)) and circles.has(Vector3(105, 68, 5)), "the pillar's circles at its anchor")
	assert_true(circles.has(Vector3(162, 97, 6)), "the flipped lopsided prop's circle is mirrored (dx -12 -> +12)")
	var chain_only: Dictionary = d[0].duplicate(true)
	chain_only["props"] = []
	var list: Array[Obstacle] = PropScene.build(d[0], d[1])
	var edge: Array[Obstacle] = PropScene.build(chain_only, d[1])
	assert_eq(list.size(), edge.size() + 3, "the edge chain plus the solid props' circles")
	assert_true(edge.size() > 8, "the outline gets its edge chain (%d)" % edge.size())
	for o: Obstacle in list:
		assert_eq(o.visual_id, &"", "colliders draw nothing: the props layer does")
		assert_true(o.radius > 0.0, "positive radius")


func test_build_is_deterministic() -> void:
	var d: Array = _data()
	var a: Array[Obstacle] = PropScene.build(d[0], d[1])
	var b: Array[Obstacle] = PropScene.build(d[0], d[1])
	assert_eq(a.size(), b.size(), "same count")
	for i: int in a.size():
		assert_eq(a[i].center, b[i].center, "same centre %d" % i)
		assert_eq(a[i].radius, b[i].radius, "same radius %d" % i)


func test_the_hero_cannot_enter_a_solid_prop_and_walks_through_decor() -> void:
	var d: Array = _data()
	var list: Array[Obstacle] = PropScene.build(d[0], d[1])
	for anchor: Vector2 in [Vector2(100, 70), Vector2(150, 100)]:
		var closest: float = INF
		for dir: Vector2 in DIRECTIONS:
			var heading: Vector2 = dir.normalized()
			var pos: Vector2 = anchor - heading * 30.0
			if not Collision.fits(list, pos, HERO):
				continue
			for i: int in 60:
				pos = Collision.move_resolved(list, pos, pos + heading * 2.0, HERO)
				assert_true(Collision.fits(list, pos, HERO), "the hero is never inside a collider at %s walking %s" % [str(anchor), str(dir)])
				closest = minf(closest, pos.distance_to(anchor))
		assert_true(closest < 20.0, "the hero reaches the prop's base from some side (%.1f)" % closest)
	var bone: Vector2 = Vector2(60, 100)
	assert_true(Collision.fits(list, bone, HERO), "the hero can stand on the decor bone")


func test_every_real_scene_file_validates() -> void:
	var defs: Dictionary = PropScene.load_defs()
	var dir: DirAccess = DirAccess.open("res://data/scenes")
	if dir == null:
		return
	for file: String in dir.get_files():
		if not file.ends_with("_props.json"):
			continue
		var scene: Dictionary = PropScene.load_scene("res://data/scenes/" + file)
		var errors: PackedStringArray = PropScene.validate(scene, defs)
		assert_eq(errors.size(), 0, "%s: %s" % [file, str(errors)])
