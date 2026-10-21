extends SceneTree
## Windowed capture of the arena as the player sees it, for the human's review of the arena look:
##   godot --path . --script res://tests/capture_arena_review.gd
## Saves into docs/previews/:
##   arena_full_v2.png      the whole 800x480 arena at 2x, stitched from 9 real camera views (HUD, hero and boss hidden)
##   arena_view_<name>.png  1x camera views (320x180) with the hero standing in the plaza, by the statue, by the altar and
##                          at the forest edge (HUD hidden)
## Run tools/art/compare_arena_target.py afterwards for docs/previews/arena_vs_target.png.
const Arena := preload("res://presentation/arena/arena.gd")
const InputFrameClass := preload("res://core/input_frame.gd")
const Tuning := preload("res://core/tuning.gd")
const OUT_DIR: String = "res://docs/previews/"
const AWAY: Vector2 = Vector2(-4000.0, -4000.0)
## [name, where the hero stands]
const VIEWS: Array = [
	["plaza", Vector2(312, 250)], ["statue", Vector2(396, 112)], ["altar", Vector2(398, 372)],
	["forest_west", Vector2(92, 226)], ["forest_east", Vector2(724, 240)],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: Arena = (load("res://presentation/arena/arena.tscn") as PackedScene).instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	arena.core.boss.cooldown = 100000
	var hud: Node = arena.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var view: Vector2 = arena.VIEW_SIZE
	# the whole arena from 9 camera views, without the hero and the boss
	var full: Image = Image.create(int(Tuning.ARENA_SIZE.x) * 2, int(Tuning.ARENA_SIZE.y) * 2, false, Image.FORMAT_RGBA8)
	var xs: Array[float] = [0.0, (Tuning.ARENA_SIZE.x - view.x) * 0.5, Tuning.ARENA_SIZE.x - view.x]
	var ys: Array[float] = [0.0, (Tuning.ARENA_SIZE.y - view.y) * 0.5, Tuning.ARENA_SIZE.y - view.y]
	for y: float in ys:
		for x: float in xs:
			var origin: Vector2 = Vector2(x, y).round()
			var shot: Image = await _shot(arena, origin + view * 0.5, true)
			shot.resize(int(view.x) * 2, int(view.y) * 2, Image.INTERPOLATE_NEAREST)
			full.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(origin * 2.0))
	full.save_png(ProjectSettings.globalize_path(OUT_DIR + "arena_full_v2.png"))
	# 1x views with the hero standing somewhere (the boss stays at its start)
	for entry: Array in VIEWS:
		var shot: Image = await _shot(arena, entry[1], false)
		shot.resize(int(view.x), int(view.y), Image.INTERPOLATE_NEAREST)
		shot.save_png(ProjectSettings.globalize_path(OUT_DIR + "arena_view_%s.png" % entry[0]))
	print("ARENA REVIEW captured")
	quit(0)


## One frame of the real camera with the hero at `at` (or the camera centred on `at` with nobody drawn).
func _shot(arena: Arena, at: Vector2, empty: bool) -> Image:
	arena.core.player.position = at
	arena.core.boss.position = Tuning.BOSS_START
	arena.core.step(InputFrameClass.new())
	arena.core.player.position = at
	arena.snapshot = arena.core.snapshot()
	arena._update_camera(true)
	if empty:
		arena.snapshot.player.position = AWAY
		for actor: Variant in arena.snapshot.entities:
			actor.position = AWAY
	arena.prepare_visuals()
	arena.particles.clear()
	arena.queue_redraw()
	for k: int in 3:
		await process_frame
	return root.get_texture().get_image()
