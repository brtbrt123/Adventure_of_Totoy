extends SceneTree
## New atlas coverage and exact telegraph boundaries, including unordered combos.
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Arena := preload("res://presentation/arena/arena.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	var snap: Snapshots.GameSnapshot = Snapshots.GameSnapshot.new()
	var boss: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	boss.visual_id = &"mossbound_colossus"
	boss.id = 2
	boss.state = &"attack"
	for key: String in ArenaAnimation.all_names():
		check(atlas.has(key), "missing " + key)
		check(atlas[key].has("ax") and atlas[key].has("ay"), "anchor " + key)
	for pose: String in ["slam", "stomp", "sweep", "dust", "charge", "hit", "counter", "parry", "dash"]:
		for n: int in range(1, 7):
			check(atlas.has("fx_%s_%d" % [pose, n]), "effect atlas: " + pose)
	for pose: String in ["start", "body", "end"]:
		for n: int in range(1, 5):
			check(atlas.has("fx_beam_%s_%d" % [pose, n]), "beam atlas: " + pose)
	for key: String in ["ui_profile", "ui_boss", "ui_warning_gold_1", "ui_warning_gold_2", "ui_warning_red_1", "ui_warning_red_2", "ui_icon_edge_1", "ui_icon_dash_1", "ui_icon_parry_1", "prop_nature_1", "prop_nature_4", "prop_ruins_2", "prop_small_3"]:
		check(atlas.has(key), "UI/prop atlas: " + key)
	for attack: String in ArenaAnimation.ATTACKS:
		var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		tell.owner_id = 2
		tell.attack = StringName(attack)
		tell.start_tick = 10
		tell.hit_tick = 70
		tell.end_tick = 78
		snap.telegraphs.assign([tell])
		for tick: int in range(10, 79):
			snap.tick = tick
			var key: String = ArenaAnimation.choose(boss, snap, {})
			check(atlas.has(key), "selection " + key)
			var index: int = int(key.get_slice("_", 2))
			check(index <= 3 if tick < 70 else index >= 4, "impact boundary " + attack)
			if tick == 70:
				check(index == 4, "strike must land exactly on hit_tick")
		if attack == "gold_combo":
			var second: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
			second.owner_id = 2
			second.attack = &"gold_combo"
			second.start_tick = 10
			second.hit_tick = 100
			second.end_tick = 100
			for reverse: bool in [false, true]:
				snap.telegraphs.assign([second, tell] if reverse else [tell, second])
				snap.tick = 83
				check(ArenaAnimation.choose(boss, snap, {}) == "golem2_slam_1", "combo re-raise")
				snap.tick = 100
				check(ArenaAnimation.choose(boss, snap, {}) == "golem2_slam_4", "second combo impact")
	snap.telegraphs.clear()
	boss.state = &"dead"
	snap.result = &"victory"
	for tick: int in range(60):
		snap.result_ticks = tick
		check(ArenaAnimation.choose(boss, snap, {}) == "golem2_death_%d" % (mini(7, tick / 6) + 1), "death progression")
	var hero: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	hero.visual_id = &"totoy"
	check(ArenaAnimation.choose(hero, snap, {}).begins_with("hero2_victory_"), "victory art")
	hero.state = &"dead"
	snap.result = &"defeat"
	check(ArenaAnimation.choose(hero, snap, {}) == "hero2_hurt_right_4", "death substitute")
	var arena: Arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	for actor: Snapshots.EntitySnapshot in [arena.snapshot.player, arena.snapshot.entities[0]]:
		arena._on_event(GameEvent.new(&"damage_taken", arena.snapshot.tick, {"entity_id": actor.id, "amount": 1, "source_id": 0}))
		arena.prepare_visuals()
		check(String(arena.selected_frames[actor.id]).contains("_hurt_"), "damage reaction")
	arena._on_event(GameEvent.new(&"boss_phase_changed", arena.snapshot.tick, {"entity_id": arena.snapshot.entities[0].id, "phase": 2}))
	arena.prepare_visuals()
	check(String(arena.selected_frames[arena.snapshot.entities[0].id]).begins_with("golem2_roar_"), "phase roar")
	arena.snapshot.tick += 31
	arena.prepare_visuals()
	check(String(arena.selected_frames[arena.snapshot.entities[0].id]).begins_with("golem2_idle_"), "reaction expiration")
	arena._restart()
	check(arena.reactions.is_empty(), "reaction restart")
	arena.queue_free()
	for message: String in failures:
		printerr("GOLEM FAIL: " + message)
	print("GOLEM SMOKE ", "OK" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
