extends SceneTree
## Pictures for the owner, part 3b (docs/PLAN_colossus_step3.md): the REAL warnings of Root Snare, Boulder Toss and Heartroot Grab
## and the phase 3 roar in Rootcrown, and, drawn over some of them, a MOCK of the effects proposed for them: PixelFX effects in
## Totoy 36 with hard alpha (art/reference/pixelfx_colossus_v1/, tools/art/import_pixelfx.py), placed on the real lanes. Nothing of
## the mock is in the game. Root Snare's thorns and the Boulder Toss's stone (2026-11-27) the ring's stone shards (option B) and the Grab's root-arm (2026-11-28) are wired: every shot is REAL. Windowed only:
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_3b/capture_3b.gd
## Writes user://colossus_3b/<name>.png; tools/art/make_colossus_3b_sheet.py makes the sheet. No save is read or written.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Telegraph := preload("res://core/telegraph.gd")
const Tuning := preload("res://core/tuning.gd")
const GameEvent := preload("res://core/game_event.gd")
const OUT: String = "user://colossus_3b/"
const HOME: Vector2 = Vector2(512, 378)

var scene: Explore
var mock: String = ""
var ring_center: Vector2 = Vector2.ZERO
var ring_tick: int = 0


func _init() -> void:
	call_deferred("run")


func boss() -> Object:
	return scene.core.mobs.encounters[0].mobs[0]


func steps(count: int) -> void:
	for i: int in count:
		scene.core.player.hp = scene.core.hero_max_hp()
		scene.advance(InputFrame.new())
		scene.fade_phase = &""
		scene.toast_ticks = 0


func shot(name: String) -> void:
	scene.queue_redraw()
	scene.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name, " ", error_string(error))


## The attack `id` begun at the hero standing `spot` from the boss at home, `ticks` into its warning.
func attack(id: StringName, spot: Vector2, ticks: int, phase: int = 2) -> void:
	var b: Object = boss()
	b.clear_telegraph()
	b.position = HOME
	b.phase = phase
	b.state = &"chase"
	b.cooldown = 1
	b.next_attack_override = id
	scene.core.player.position = HOME + spot
	scene.core.player.facing = (HOME - scene.core.player.position).normalized()
	steps(1)
	b.cooldown = 100000
	steps(ticks)


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_3b: run it windowed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"rootcrown_layered"})
	var node: Node = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate()
	node.set_script(load("res://presentation/review/colossus_step3/mockup_scene.gd"))
	scene = node as Explore
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.set("after_draw", Callable(self, "draw_mock"))
	scene.fade_phase = &""
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	scene.core.player.position = HOME + Vector2(60, 120)
	steps(Tuning.COLOSSUS_WAKE_TICKS + 10)
	# Root Snare: the first lane warns; then (he dodged) the roots burst along it and the second lane warns where he went
	attack(&"root_snare", Vector2(120, 40), 36, 1)
	await shot("3b_01_snare_warning")
	var hit: int = boss().telegraph.hit_tick
	steps(hit - scene.core.tick - 1)
	scene.core.player.position = HOME + Vector2(70, 110)
	steps(9)
	await shot("3b_02_snare_second_lane")  # the thorns are the game's own now
	steps(40)
	# Boulder Toss: the stone in the air over its warning; then landed, the ring of shock warns round it
	attack(&"boulder_toss", Vector2(140, 40), 26)
	await shot("3b_03_boulder_in_flight")
	hit = boss().telegraph.hit_tick
	scene.core.player.position = HOME + Vector2(140, 120)
	steps(hit - scene.core.tick + 8)
	await shot("3b_04_boulder_ring")
	var ring_hit: int = boss().extra_telegraphs[0].hit_tick
	ring_center = boss().extra_telegraphs[0].center  # read now: the warning is gone once the ring has struck
	ring_tick = ring_hit
	steps(ring_hit - scene.core.tick + 6)
	await shot("3b_04b_ring_strikes")  # the stone shards are the game's own since the owner chose option B
	steps(50)
	# Heartroot Grab: the gold lane; then the root-arm rearing up out of the floor at the end of its warning, about to lash
	attack(&"heartroot_grab", Vector2(120, 30), 24)
	await shot("3b_05_grab_warning")
	hit = boss().telegraph.hit_tick
	scene.core.player.position = HOME + Vector2(120, 100)  # out of its reach: the picture shows the arm, not a hit
	steps(hit - scene.core.tick - 6)
	await shot("3b_06_grab_strike")  # the root-arm is the game's own since "Yes, wire it"
	steps(40)
	# phase 3: the roar at a quarter of its health
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().position = HOME
	scene.core.player.position = HOME + Vector2(80, 50)
	var events: Array[GameEvent] = []
	boss().hp = 152
	scene.core.mobs.hit_mob(scene.core, scene.core.mobs.encounters[0], boss(), 8.0, {"combo_index": 1, "weapon_id": &"black_katana"}, events)
	steps(20)
	await shot("3b_07_phase3_roar")
	print("CAPTURE 3B OK")
	quit(0)


# ---- the proposed effects (mock only): PixelFX frames, 30 fps, so one frame every 2 game ticks -----------------------------------

const PFX: String = "res://art/reference/pixelfx_colossus_v1/"
var _textures: Dictionary = {}
var _meta: Dictionary = {}


func pfx(effect: String, file: String) -> ImageTexture:
	var key: String = effect + "/" + file
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(PFX + key)))
	return _textures[key]


func meta(effect: String) -> Dictionary:
	if not _meta.has(effect):
		_meta[effect] = JSON.parse_string(FileAccess.get_file_as_string(PFX + effect + "/frames.json"))
	return _meta[effect]


## Frame `index` of `effect` (clamped) with the point `anchor` of the frame on `at`; `window` cuts a part of it round the anchor.
func pfx_draw(effect: String, list: String, index: int, anchor: Vector2, at: Vector2, window: Rect2 = Rect2()) -> void:
	var files: Array = meta(effect)[list]
	var texture: ImageTexture = pfx(effect, String(files[clampi(index, 0, files.size() - 1)]))
	var src: Rect2 = window if window.has_area() else Rect2(Vector2.ZERO, texture.get_size())
	scene.draw_texture_rect_region(texture, Rect2((at - anchor + src.position).round(), src.size), src, scene.ambient())


func draw_mock() -> void:
	var tick: int = scene.core.tick
	match mock:
		"arm":  # the reworked PixelFX vine-whip (pale root, the song's blue thorns), turned to the lane, rooted at the body's edge
			if boss().telegraph == null:
				return
			var first: Telegraph = boss().telegraph
			var m: Dictionary = meta("grab_vine")
			pfx_draw("grab_vine", "frames", 15 + (tick - first.hit_tick) / 2, Vector2(m["pivot"][0], m["pivot"][1]), first.center + first.direction * 40.0)
		"ring_nova":  # option A: PixelFX frost-nova as stone shards, its reach set to the ring's outer radius (72)
			var m: Dictionary = meta("shock_ring")
			pfx_draw("shock_ring", "frames", 26 + (tick - ring_tick) / 2, Vector2(m["pivot"][0], m["pivot"][1]), ring_center)
		"ring_thorns":  # option B: one PixelFX stone shard bursting up, 14 times round the middle of the real ring (56 px)
			var anchor: Vector2 = Vector2(meta("stone_thorn")["anchor"][0], meta("stone_thorn")["anchor"][1])
			for k: int in 14:
				var at: Vector2 = ring_center + Vector2.from_angle(TAU * k / 14.0) * 56.0
				pfx_draw("stone_thorn", "frames", 9 + (tick - ring_tick) / 2, anchor, at, Rect2(anchor - Vector2(16, 70), Vector2(32, 78)))


func _ellipse(at: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i: int in 24:
		out.append(at + Vector2(cos(TAU * i / 24.0) * rx, sin(TAU * i / 24.0) * ry))
	return out
