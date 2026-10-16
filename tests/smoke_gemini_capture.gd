extends SceneTree
## Windowed review fixtures: changes snapshots only, never production rules.
const Arena := preload("res://presentation/arena/arena.gd")
const Snapshots := preload("res://core/snapshots.gd")
var arena: Arena

func _init() -> void:
	call_deferred("run")

func save(label: String) -> void:
	arena.prepare_visuals()
	arena._update_hud()
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://art/build/arena_gemini_" + label + ".png")
	if error != OK:
		printerr("CAPTURE FAIL: " + label)
		quit(1)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE FAIL: windowed renderer required")
		quit(1)
		return
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.snapshot = arena.core.snapshot()
	arena.snapshot.player.position = Vector2(116, 117)
	arena.snapshot.entities[0].position = Vector2(220, 125)
	for state: String in ["walk", "attack_active", "parry"]:
		arena.snapshot.player.state = StringName(state)
		arena.snapshot.player.state_ticks = 10 if state == "walk" else (2 if state == "attack_active" else 10)
		await save("hero_" + state)
	arena.snapshot.player.state = &"idle"
	arena.snapshot.entities[0].state = &"attack"
	var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	tell.owner_id = arena.snapshot.entities[0].id
	tell.attack = &"gold_slam"
	tell.kind = &"gold"
	tell.center = Vector2(190, 126)
	tell.size = 32
	tell.start_tick = 0
	tell.hit_tick = 60
	tell.end_tick = 61
	arena.snapshot.telegraphs.assign([tell])
	arena.snapshot.tick = 60
	await save("golem_slam")
	arena.snapshot.telegraphs.clear()
	arena.rings.clear()
	arena.particles.clear()
	arena.snapshot.entities[0].state = &"posture_broken"
	arena.snapshot.entities[0].state_ticks = 16
	await save("golem_staggered")
	arena.snapshot.entities[0].position = Vector2(245, 162)
	arena.snapshot.entities[0].state = &"dead"
	arena.snapshot.result = &"victory"
	arena.snapshot.result_ticks = 42
	await save("golem_death")
	arena._restart()
	arena.snapshot = arena.core.snapshot()
	arena.snapshot.hud.player_hp = 65
	arena.snapshot.hud.edge = 45
	arena.snapshot.hud.dash_cooldown_ticks = 20
	await save("hud")
	arena.debug_enabled = true
	await save("hitboxes")
	print("GEMINI CAPTURE OK")
	quit(0)
