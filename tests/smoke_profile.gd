extends SceneTree
## Headless assertions; add -- --capture in a windowed run for review images.
const Arena := preload("res://presentation/arena/arena.gd")
const HeadAnchors := preload("res://presentation/arena/head_anchors.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Snapshots := preload("res://core/snapshots.gd")
const InputFrame := preload("res://core/input_frame.gd")
var arena: Arena
var failures: Array[String] = []
var capture: bool = false

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _observe() -> void:
	arena.snapshot = arena.core.snapshot()
	arena._update_camera(true)
	arena.prepare_visuals()
	arena._update_hud()
	arena.queue_redraw()

func _step() -> void:
	arena.core.step(InputFrame.new())
	_observe()

func _save(name_key: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png("res://art/build/" + name_key + ".png") == OK, "capture failed: " + name_key)

func _catalog() -> void:
	var icons: Array[String] = ["ui_aspect_breaking_edge_1", "ui_aspect_gale_cut_1", "ui_aspect_moon_cleave_1", "ui_weapon_frame_1"]
	_expect(arena.frames.has(arena.hud.weapon_icon_key), "equipped blade icon missing")
	if arena.frames.has(arena.hud.weapon_icon_key):
		_expect(int(arena.frames[arena.hud.weapon_icon_key]["w"]) == 32, "blade glyph must use native 32px size")
	var sockets: Array[Rect2] = arena.hud.aspect_rects()
	sockets.append(arena.hud.weapon_rect())
	for slot: int in range(4):
		_expect(arena.frames.has(icons[slot]), "medallion absent: " + icons[slot])
		if arena.frames.has(icons[slot]):
			var icon: Dictionary = arena.frames[icons[slot]]
			_expect(Vector2(icon["w"], icon["h"]) == sockets[slot].size, "medallion must use native pixel size")
		_expect(Rect2(0, 0, 320, 180).encloses(sockets[slot]), "socket clipped by viewport")
		for other: int in range(slot):
			_expect(sockets[slot].get_center().distance_to(sockets[other].get_center()) >= (sockets[slot].size.x + sockets[other].size.x) * 0.5, "overlapping medallion frames")
	_expect(sockets[3].size == sockets[0].size * 2, "weapon icon must be larger than Aspects")
	_expect(sockets[3].position.x < 54, "weapon stays left of the bottom meters")
	for slot: int in range(3):
		_expect(sockets[slot].position.y == 147 and sockets[slot].position.x >= 174, "Aspects align beside bottom meters")

	_expect(arena.frames.has("totoy_portrait"), "portrait absent from atlas")
	_expect(arena.frames.has("ui_profile"), "profile frame absent from atlas")
	_expect(not arena.hud.profile_frame.is_empty(), "HUD frame not connected")
	arena.hud.prepare_portrait()
	_expect(arena.hud.portrait_mask != null, "circular portrait missing")
	var distinct: Dictionary = {}
	var source: Image = arena.sprites.get_image()
	for name_key: String in arena.frames:
		if not name_key.begins_with("golem2_"):
			continue
		_expect(arena.head_anchors.has(name_key), "uncached boss frame: " + name_key)
		var frame: Dictionary = arena.frames[name_key]
		var head: Vector2 = arena.head_anchors[name_key]
		distinct[head] = true
		_expect(source.get_pixel(int(frame["x"]) + roundi(head.x), int(frame["y"]) + roundi(head.y)).a == 1.0, "head is not on opaque art: " + name_key)
		var right: Vector2 = HeadAnchors.world(Vector2(160, 100), frame, head, false)
		var left: Vector2 = HeadAnchors.world(Vector2(160, 100), frame, head, true)
		_expect(is_equal_approx(left.x + right.x, 319.0) and left.y == right.y, "mirror anchor mismatch: " + name_key)
	_expect(distinct.size() >= 2, "head anchor is constant across boss frames")
	var idle: Vector2 = arena.head_anchors["golem2_idle_1"]
	var charge: Vector2 = arena.head_anchors["golem2_charge_4"]
	_expect(not idle.is_equal_approx(charge), "charge lean must move head")
	_expect(Vector2(arena.head_anchors["golem2_slam_3"]).y >= 4, "raised fist mistaken for head")
	for at: Vector2 in [Vector2.ZERO, Vector2(320, 0), Vector2(0, 180), Vector2(320, 180)]:
		for counter: bool in [false, true]:
			_expect(Rect2(1, 1, 318, 165).encloses(arena.hud.boss_panel(at, counter).grow(1)), "panel/highlight left screen")
	arena.hud.reset_head()
	arena.hud.track_head(Vector2(100, 100), 0, 2)
	arena.hud.track_head(Vector2(110, 106), 1, 2)
	_expect(arena.hud.head_position == Vector2(105, 103), "head interpolation missing")
	arena.hud.track_head(Vector2(110, 106), 1, 2)
	_expect(arena.hud.head_position == Vector2(105, 103), "head advances twice on same tick")
	# Translation follows the body immediately; only the animated head offset eases.
	arena.hud.reset_head()
	arena.hud.track_head(Vector2(100, 60), 10, 2, Vector2(100, 100))
	arena.hud.track_head(Vector2(130, 60), 11, 2, Vector2(130, 100))
	_expect(arena.hud.head_position == Vector2(130, 60), "charge translation must not lag behind body")
	arena.hud.track_head(Vector2(40, 30), 0, 2, Vector2(40, 70))
	_expect(arena.hud.head_position == Vector2(40, 30), "restart tick must snap head position")
	arena.hud.reset_head()

func _fight(attack: StringName, left: bool) -> void:
	arena._restart()
	arena.core.boss.phase = 2
	# in the open middle of the plaza (no props in the way)
	arena.core.boss.position = Vector2(450 if left else 360, 240)
	arena.core.player.position = Vector2(380 if left else 430, 240)
	arena.core.boss.next_attack_override = attack
	arena.core.boss.cooldown = 1
	_observe()
	var seen: Dictionary = {}
	var mirror_seen: bool = false
	var unmirror_seen: bool = false
	var charge_mirrored: Array[bool] = []
	var saved: bool = false
	for i: int in range(120):
		_step()
		var boss: Snapshots.EntitySnapshot = arena.snapshot.entities[0]
		var name_key: String = arena.selected_frames[boss.id]
		seen[name_key] = true
		var mirrored: bool = ArenaAnimation.boss_mirrored(boss, arena.snapshot, arena.last_attacks.get(boss.id, {}))
		mirror_seen = mirror_seen or mirrored
		unmirror_seen = unmirror_seen or not mirrored
		var tell: Snapshots.TelegraphSnapshot = ArenaAnimation.attack_tell(boss.id, arena.snapshot)
		if tell != null and tell.attack == &"red_charge":
			charge_mirrored.append(mirrored)
		# the HUD is in screen space: the head's world position minus the camera's top-left corner
		var target: Vector2 = HeadAnchors.world(boss.position, arena.frames[name_key], arena.head_anchors[name_key], mirrored) - arena.view_origin
		_expect(arena.hud.head_position.distance_to(target) < 20.0, "panel trails head too far: %s tick %d head %s target %s" % [attack, arena.snapshot.tick, arena.hud.head_position, target])
		_expect(arena.hud.head_tick == arena.snapshot.tick, "head not updated for fight frame")
		if capture and attack == &"gold_slam" and not saved and name_key == "golem2_slam_3":
			await _save("arena_bossbar2")
			saved = true
		await process_frame
	_expect(seen.size() >= 4, "too few boss frames exercised")
	if attack == &"red_charge":
		# The charge source art faces LEFT: a leftward charge is native, a rightward one is mirrored.
		_expect(not charge_mirrored.is_empty(), "no charge frames exercised")
		for was_mirrored: bool in charge_mirrored:
			_expect(was_mirrored == (not left), "charge mirror direction wrong for a %s charge" % ("left" if left else "right"))

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	if capture and DisplayServer.get_name() == "headless":
		printerr("PROFILE FAIL: capture requires windowed renderer")
		quit(1)
		return
	var packed: PackedScene = load("res://presentation/arena/arena.tscn") as PackedScene
	arena = packed.instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	_catalog()
	arena._restart()
	_observe()
	await _save("arena_hud2")
	# Deliberate core fixture for inspecting all three partially filled meters.
	arena.core.player.hp = 65
	arena.core.player.edge = 45.0
	arena.core.player.dash_cooldown = 20
	_observe()
	_expect(arena.snapshot.hud.player_hp < arena.snapshot.hud.player_max_hp, "reduced HP fixture")
	_expect(arena.snapshot.hud.edge > 0 and arena.snapshot.hud.edge < arena.snapshot.hud.edge_max, "partial Edge fixture")
	_expect(arena.hud.dash_fraction(arena.snapshot.hud) > 0 and arena.hud.dash_fraction(arena.snapshot.hud) < 1, "partial dash fixture")
	await _save("arena_profile2")
	await _fight(&"gold_slam", false)
	await _fight(&"red_charge", false)
	await _fight(&"red_charge", true)
	await _fight(&"red_sweep", true)
	arena._restart()
	_observe()
	_expect(arena.hud.dash_fraction(arena.snapshot.hud) == 1.0, "ready dash must be full")
	arena.queue_free()
	if failures.is_empty():
		print("PROFILE SMOKE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("PROFILE FAIL: " + message)
		quit(1)
