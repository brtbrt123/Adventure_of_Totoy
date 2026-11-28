extends SceneTree
## Pictures for the owner (the owner asked for "a gif with full effect even the gold mark", 2026-11-28): the REAL game in Rootcrown at
## night, a Gold Sweep twice, with its real gold warning (the cone and the parry marker), the real hit and parry effects and the HUD.
## MOCKED (not in the game yet): the reworked swing frames (sweep_view_mock.gd) and the proposed step 5 dust across the cone
## (PixelFX impacts/blunt-hit in pale stone, art/reference/pixelfx_colossus_v1/dust_puff/). Run A: Totoy takes the blow. Run B: he
## parries it (pressed 8 ticks before it lands: an early parry).
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_sweep/capture_sweep.gd
## Writes user://colossus_sweep/a/seq_NNNN.png and b/seq_NNNN.png (every 2 ticks); tools/art/make_colossus_sweep_review.py --game
## makes the GIF. With `-- --real` (after the owner's "Looks good, wire it") nothing is mocked: the game's own swing and dust, into
## user://colossus_sweep/real_a and real_b (`make_colossus_sweep_review.py --game --real`). No save is read or written.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Telegraph := preload("res://core/telegraph.gd")
const SweepView := preload("res://presentation/review/colossus_sweep/sweep_view_mock.gd")
const PFX: String = "res://art/reference/pixelfx_colossus_v1/"
const OUT: String = "user://colossus_sweep/"
const HOME: Vector2 = Vector2(512, 378)
const HERO: Vector2 = Vector2(-92, 14)  # where Totoy stands from its feet: inside the cone, the whole body on screen
const DUST_FIRST: int = 6
const DUST_FRAMES: int = 8

var scene: Explore
var sweep: Telegraph = null
var real: bool = false
var _textures: Dictionary = {}
var _meta: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func boss() -> Object:
	return scene.core.mobs.encounters[0].mobs[0]


func step(frame: InputFrame = null) -> void:
	scene.core.player.hp = scene.core.hero_max_hp()
	scene.advance(frame if frame != null else InputFrame.new())
	scene.fade_phase = &""
	scene.toast_ticks = 0


func shot(path: String) -> void:
	scene.queue_redraw()
	scene.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + path)


## One Gold Sweep from 12 ticks before its warning to 40 after its blow, a picture every 2 ticks; `parry` presses parry 8 ticks early.
func run_sweep(folder: String, parry: bool) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + folder))
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().position = HOME
	boss().cooldown = 12
	boss().next_attack_override = &"red_sweep"
	scene.core.player.position = HOME + HERO
	var n: int = 0
	sweep = null
	for i: int in 200:
		var frame: InputFrame = InputFrame.new()
		if sweep != null and parry and scene.core.tick == sweep.hit_tick - 8:
			frame.parry_pressed = true
			frame.aim = Vector2.RIGHT
		step(frame)
		scene.core.player.position = HOME + HERO
		if sweep == null:
			for w: Telegraph in boss().all_telegraphs():
				if w.attack == &"red_sweep":
					sweep = w
		if i % 2 == 0:
			await shot("%s/seq_%04d.png" % [folder, n])
			n += 1
		if sweep != null and scene.core.tick > sweep.hit_tick + 40:
			break
	boss().cooldown = 100000
	return n


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_sweep: run it windowed")
		quit(1)
		return
	if Engine.has_meta(Explore.PERSIST_META):
		Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"rootcrown_layered"})
	var node: Node = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate()
	node.set_script(load("res://presentation/review/colossus_step3/mockup_scene.gd"))
	scene = node as Explore
	root.add_child(scene)
	await process_frame
	real = OS.get_cmdline_user_args().has("--real")
	if not real:
		scene.colossus_view = SweepView.new()
		scene.set("after_draw", Callable(self, "draw_mock"))
	scene.set_physics_process(false)
	scene.fade_phase = &""
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	scene.core.player.position = HOME + Vector2(-70, 60)
	for i: int in 220:  # it wakes and appears
		step()
	boss().cooldown = 100000
	var a: int = await run_sweep("real_a" if real else "a", false)
	for i: int in 60:
		step()
	var b: int = await run_sweep("real_b" if real else "b", true)
	print("CAPTURE SWEEP OK ", a, " + ", b)
	quit(0)


# ---- the proposed dust (mock only) ---------------------------------------------------------------------------------------------

func pfx(effect: String, file: String) -> ImageTexture:
	var key: String = effect + "/" + file
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(PFX + key)))
	return _textures[key]


func dust(age: int, at: Vector2) -> void:
	var n: int = age / 4
	if age < 0 or n >= DUST_FRAMES:
		return
	if not _meta.has("dust_puff"):
		_meta["dust_puff"] = JSON.parse_string(FileAccess.get_file_as_string(PFX + "dust_puff/frames.json"))
	var m: Dictionary = _meta["dust_puff"]
	scene.draw_texture(pfx("dust_puff", String(m["frames"][DUST_FIRST + n * 2])), (at - Vector2(m["pivot"][0], m["pivot"][1])).round(), scene.ambient())


func draw_mock() -> void:
	if sweep == null:
		return
	var tick: int = scene.core.tick
	var puffs: int = 7
	for k: int in puffs:  # kicked up across the real cone in the order the arm swings through it (from its right to its left)
		var angle: float = sweep.direction.angle() - sweep.half_angle * (1.0 - 2.0 * float(k) / float(puffs - 1))
		for reach: float in [0.55, 0.85]:
			dust(tick - sweep.hit_tick - k, sweep.center + Vector2.from_angle(angle) * sweep.size * reach)
