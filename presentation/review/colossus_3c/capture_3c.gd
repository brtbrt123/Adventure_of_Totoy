extends SceneTree
## Pictures for the owner, part 3c (docs/PLAN_colossus_step3.md): the REAL Briar Ring (its warning, then standing, also over the whole
## map) and the REAL Song Flare (its rings and gold blow) in Rootcrown, and drawn over some of them a MOCK of the proposed effects: the
## approved root thorns as a wall round the safe circle, PixelFX shards in the song's blue round each real ring, and PixelFX
## mana-burst in the song's blue for the gold blow (art/reference/pixelfx_colossus_v1/). Since the owner's "Yes, wire them"
## (2026-11-28) all three are the game's own: every shot is REAL; the mock code stays for comparing later proposals.
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_3c/capture_3c.gd
## Writes user://colossus_3c/<name>.png; tools/art/make_colossus_3c_sheet.py makes the sheet. No save is read or written.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Telegraph := preload("res://core/telegraph.gd")
const Tuning := preload("res://core/tuning.gd")
const GameEvent := preload("res://core/game_event.gd")
const OUT: String = "user://colossus_3c/"
const PFX: String = "res://art/reference/pixelfx_colossus_v1/"
const HOME: Vector2 = Vector2(512, 378)
const WALL_RADIUS: float = 182.0  # the thorn wall stands just outside the safe circle (170)
const WALL_SPACING: float = 22.0
const SHARD_SPACING: float = 56.0  # sparse: 26 px made a forest of spikes that hid the hero standing in a gap

var scene: Explore
var mock: String = ""
var flare: Array[Telegraph] = []  # the Song Flare's warnings (kept: they are gone once it ends)
var _textures: Dictionary = {}
var _meta: Dictionary = {}


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


func whole_map(name: String) -> void:
	var view_size: Vector2i = root.content_scale_size
	var window_size: Vector2i = root.size
	scene.camera.enabled = false
	(scene.get_node("HUD") as CanvasLayer).hide()
	root.content_scale_size = Vector2i(scene.snapshot.size)
	root.size = Vector2i(scene.snapshot.size)
	await shot(name)
	scene.camera.enabled = true
	(scene.get_node("HUD") as CanvasLayer).show()
	root.content_scale_size = view_size
	root.size = window_size


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_3c: run it windowed")
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
	# the Briar Ring: phase 2 begins, the ring warns, then the briars stand for 10 s
	var enc: Object = scene.core.mobs.encounters[0]
	boss().position = HOME
	boss().hp = 362
	var events: Array[GameEvent] = []
	scene.core.mobs.hit_mob(scene.core, enc, boss(), 8.0, {"combo_index": 1, "weapon_id": &"black_katana"}, events)
	boss().state = &"stagger"  # held still for the pictures
	boss().stun_left = 100000
	scene.core.player.position = Vector2(440, 450)
	steps(80)
	await shot("3c_01_briar_warning")
	await whole_map("3c_01b_briar_warning_map")
	steps(int(Tuning.COLOSSUS_BRIAR["windup"]) - 80 + 20)
	await shot("3c_02_briars_stand")
	await whole_map("3c_02b_briars_stand_map")
	boss().briar = null
	# the Song Flare (phase 3): its three rings and gold blow; then the rings bursting and the blow
	boss().phase = 3
	boss().stun_left = 0
	steps(20)
	boss().clear_telegraph()
	boss().position = HOME
	boss().state = &"chase"
	boss().cooldown = 1
	boss().next_attack_override = &"song_flare"
	scene.core.player.position = HOME + Vector2(100, 0)  # in the gap between the first two rings
	steps(1)
	boss().cooldown = 100000
	flare.assign(boss().all_telegraphs())
	steps(24)
	await shot("3c_03_flare_warning")
	steps(flare[1].hit_tick - scene.core.tick + 4)
	await shot("3c_04_flare_rings")
	steps(flare[3].hit_tick - scene.core.tick + 3)
	await shot("3c_05_flare_gold_blow")
	print("CAPTURE 3C OK")
	quit(0)


# ---- the proposed effects (mock only) ------------------------------------------------------------------------------------------

func pfx(effect: String, file: String) -> ImageTexture:
	var key: String = effect + "/" + file
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(PFX + key)))
	return _textures[key]


func meta(effect: String) -> Dictionary:
	if not _meta.has(effect):
		_meta[effect] = JSON.parse_string(FileAccess.get_file_as_string(PFX + effect + "/frames.json"))
	return _meta[effect]


func pfx_draw(effect: String, index: int, anchor: Vector2, at: Vector2, window: Rect2 = Rect2()) -> void:
	var files: Array = meta(effect)["frames"]
	var texture: ImageTexture = pfx(effect, String(files[clampi(index, 0, files.size() - 1)]))
	var src: Rect2 = window if window.has_area() else Rect2(Vector2.ZERO, texture.get_size())
	scene.draw_texture_rect_region(texture, Rect2((at - anchor + src.position).round(), src.size), src, scene.ambient())


## One of the installed (approved) root thorns, frame n (1..11), standing at `at`.
func thorn(n: int, at: Vector2) -> void:
	var f: Dictionary = scene.frames["fx_colossus_thorn_%d" % n]
	var corner: Vector2 = (at - Vector2(float(f["ax"]), float(f["ay"]))).round()
	scene.draw_texture_rect_region(scene.sprites, Rect2(corner, Vector2(f["w"], f["h"])), Rect2(f["x"], f["y"], f["w"], f["h"]), scene.ambient())


func draw_mock() -> void:
	var tick: int = scene.core.tick
	match mock:
		"wall":  # the root thorns, risen and holding, all round the safe circle
			var centre: Vector2 = Vector2(512, 410)
			var count: int = roundi(TAU * WALL_RADIUS / WALL_SPACING)
			for k: int in count:
				thorn(6 + k % 2, centre + Vector2.from_angle(TAU * k / count) * WALL_RADIUS)
		"rings":  # song-blue shards burst round each ring that has struck, over its real band
			var anchor: Vector2 = Vector2(meta("song_shard")["anchor"][0], meta("song_shard")["anchor"][1])
			for w: Telegraph in flare.slice(0, 3):
				if tick < w.hit_tick:
					continue
				var radius: float = (w.inner_size + w.size) * 0.5
				var count: int = roundi(TAU * radius / SHARD_SPACING)
				for k: int in count:
					pfx_draw("song_shard", 9 + (tick - w.hit_tick) / 2, anchor, w.center + Vector2.from_angle(TAU * k / count) * radius, Rect2(anchor - Vector2(16, 70), Vector2(32, 78)))
		"burst":  # the song's light blowing out of its chest as the gold blow lands
			var m: Dictionary = meta("song_burst")
			pfx_draw("song_burst", 16 + (tick - flare[3].hit_tick) / 2, Vector2(m["pivot"][0], m["pivot"][1]), flare[3].center)
