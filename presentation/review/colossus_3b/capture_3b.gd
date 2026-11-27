extends SceneTree
## Pictures for the owner, part 3b (docs/PLAN_colossus_step3.md): the REAL warnings of Root Snare, Boulder Toss and Heartroot Grab
## and the phase 3 roar in Rootcrown, and, drawn over some of them, a MOCK of the effects proposed for them: PixelFX effects in
## Totoy 36 with hard alpha (art/reference/pixelfx_colossus_v1/, tools/art/import_pixelfx.py), placed on the real lanes. Nothing of
## the mock is in the game. Windowed only:
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
	mock = "roots"
	await shot("3b_02_snare_second_lane")
	mock = ""
	steps(40)
	# Boulder Toss: the stone in the air over its warning; then landed, the ring of shock warns round it
	attack(&"boulder_toss", Vector2(140, 40), 26)
	mock = "stone"
	await shot("3b_03_boulder_in_flight")
	hit = boss().telegraph.hit_tick
	scene.core.player.position = HOME + Vector2(140, 120)
	steps(hit - scene.core.tick + 8)
	await shot("3b_04_boulder_ring")
	var ring_hit: int = boss().extra_telegraphs[0].hit_tick
	steps(ring_hit - scene.core.tick + 6)
	mock = "ring"
	await shot("3b_04b_ring_strikes")
	mock = ""
	steps(50)
	# Heartroot Grab: the gold lane; then the arm of roots at its strike
	attack(&"heartroot_grab", Vector2(120, 30), 30)
	await shot("3b_05_grab_warning")
	hit = boss().telegraph.hit_tick
	scene.core.player.position = HOME + Vector2(120, 100)  # out of its reach: the picture shows the arm, not a hit
	steps(hit - scene.core.tick + 3)
	mock = "arm"
	await shot("3b_06_grab_strike")
	mock = ""
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
	if mock == "" or boss().telegraph == null:
		return
	var tick: int = scene.core.tick
	var first: Telegraph = boss().telegraph
	match mock:
		"roots":  # one PixelFX thorn bursting up again and again along the lane, a little later the farther out (PixelFX's seam races)
			var anchor: Vector2 = Vector2(meta("root_thorn")["anchor"][0], meta("root_thorn")["anchor"][1])
			var k: int = 0
			var d: float = 50.0
			while d <= first.size:
				var age: int = tick - first.hit_tick - k
				var side: Vector2 = first.direction.orthogonal() * (4.0 if k % 2 == 0 else -4.0)
				pfx_draw("root_thorn", "frames", 9 + age / 2, anchor, first.center + first.direction * d + side, Rect2(anchor - Vector2(16, 70), Vector2(32, 78)))
				d += 22.0
				k += 1
		"arm":  # the PixelFX vine-whip, turned to the lane, rooted at the body's edge; its lash meets the strike
			var m: Dictionary = meta("grab_vine")
			pfx_draw("grab_vine", "frames", 15 + (tick - first.hit_tick) / 2, Vector2(m["pivot"][0], m["pivot"][1]), first.center + first.direction * 40.0)
		"stone":  # the PixelFX stone spins along the real arc to the warning; its shadow grows on the ground
			var m: Dictionary = meta("boulder")
			if tick < first.hit_tick:
				var progress: float = clampf(float(tick - first.start_tick) / float(first.hit_tick - first.start_tick), 0.0, 1.0)
				var at: Vector2 = (HOME + Vector2(0, -96)).lerp(first.center, progress) + Vector2(0, -sin(progress * PI) * 70.0)
				var shade: float = 6.0 + 14.0 * progress
				scene.draw_colored_polygon(_ellipse(first.center, shade, shade * 0.45), Color(0, 0, 0, 0.3))
				var spin: Array = m["spin"]
				var texture: ImageTexture = pfx("boulder", String(spin[(tick / 2) % spin.size()]))
				scene.draw_texture(texture, (at - texture.get_size() * 0.5).round(), scene.ambient())
			else:
				pfx_draw("boulder", "landing", (tick - first.hit_tick) / 2, Vector2(m["land_anchor"][0], m["land_anchor"][1]), first.center)
		"ring":  # the PixelFX dust rings roll out from the crater as the ring of shock strikes
			var m: Dictionary = meta("shock_ring")
			var ring: Telegraph = boss().extra_telegraphs[0] if not boss().extra_telegraphs.is_empty() else first
			pfx_draw("shock_ring", "frames", (tick - ring.hit_tick) / 2 + 2, Vector2(m["pivot"][0], m["pivot"][1]), ring.center)


func _ellipse(at: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i: int in 24:
		out.append(at + Vector2(cos(TAU * i / 24.0) * rx, sin(TAU * i / 24.0) * ry))
	return out
