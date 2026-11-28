extends SceneTree
## Pictures for the owner, build step 5 (docs/PLAN_colossus_step5.md): the REAL fight in Rootcrown at night with, drawn over it, a
## MOCK of the PROPOSED effects for the six attacks kept from the arena (nothing of them is wired):
##   Gold Slam and Gold Combo: PixelFX impacts/ground-slam (stone, the song's blue in the cracks; art/reference/pixelfx_colossus_v1/
##     ground_slam/) on each real circle as it strikes;
##   Red Stomp: the approved stone shards (fx_colossus_shard) bursting round the middle of its real ring;
##   Red Shards: the stone shards racing out along its three real lanes (as the Root Snare's thorns do);
##   Gold Sweep: PixelFX impacts/blunt-hit in pale stone dust, past its flash (a ring of dust puffs and clods; art/reference/
##     pixelfx_colossus_v1/dust_puff/), kicked up across the real cone (two rows) in the order the arm swings through it;
##   Red Charge: that dust as a trail where its feet pass along the real lane.
##   & "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 1152x648 --script res://presentation/review/colossus_5/capture_5.gd
## Writes user://colossus_5/<name>.png; tools/art/make_colossus_5_sheet.py makes the sheet. With `-- --gifs` (the owner asked for
## GIFs with every effect, 2026-11-28) it records each attack instead, a picture every 2 ticks from before its warning until after its
## last blow, into user://colossus_5/gif_<attack>/seq_NNNN.png with meta.json (the first blow's picture);
## `make_colossus_5_sheet.py --gifs` makes one GIF each. With `--gifs --real` nothing is mocked (the wired game), into gif_real_<attack>.
## No save is read or written.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const Telegraph := preload("res://core/telegraph.gd")
const PFX: String = "res://art/reference/pixelfx_colossus_v1/"
const OUT: String = "user://colossus_5/"
const HOME: Vector2 = Vector2(512, 378)
const SLAM_FRAMES: int = 15  # ground_slam frames 1, 3, 5 ... 29 (the flash, the rocks, the first dust), 4 ticks each
const DUST_FIRST: int = 6  # dust_puff frames 7, 9 ... 21: past blunt-hit's flash and hit marks, 4 ticks each
const DUST_FRAMES: int = 8
const SHARD_FRAMES: int = 11

var scene: Explore
var mock: StringName = &""
var tells: Array[Telegraph] = []
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


func force(id: StringName, offset: Vector2) -> void:
	boss().clear_telegraph()
	boss().state = &"chase"
	boss().cooldown = 1
	boss().next_attack_override = id
	boss().position = HOME
	scene.core.player.position = HOME + offset
	steps(1)
	boss().cooldown = 100000
	mock = id
	tells.assign(boss().all_telegraphs().filter(func(w: Telegraph) -> bool: return w.attack == id))


func to_tick(tick: int) -> void:
	steps(maxi(0, tick - scene.core.tick))


func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("capture_5: run it windowed")
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
	if not OS.get_cmdline_user_args().has("--real"):  # --real (after the owner's "Wire all five"): the game's own effects, no mock
		scene.set("after_draw", Callable(self, "draw_mock"))
	scene.fade_phase = &""
	var flags: Array[StringName] = [&"received_first_sword", &"debug_all_unlocked"]
	scene.core.set_story_flags(flags)
	scene.core.player.position = HOME + Vector2(-70, 60)
	steps(220)  # it wakes and appears
	if OS.get_cmdline_user_args().has("--gifs"):
		await run_gifs()
		return
	force(&"gold_slam", Vector2(-120, 0))
	to_tick(tells[0].hit_tick + 3)
	await shot("5_01_slam_flash")
	to_tick(tells[0].hit_tick + 14)
	await shot("5_02_slam_rocks")
	steps(40)
	boss().phase = 2
	force(&"gold_combo", Vector2(-110, -10))
	to_tick(tells[1].hit_tick + 6)
	await shot("5_03_combo")
	steps(80)
	force(&"red_stomp", Vector2(-100, 20))
	to_tick(tells[0].hit_tick + 6)
	await shot("5_04_stomp")
	steps(40)
	force(&"red_shards", Vector2(-140, 10))
	to_tick(tells[0].hit_tick + 9)
	await shot("5_05_shards")
	steps(40)
	force(&"red_sweep", Vector2(-90, 10))
	to_tick(tells[0].hit_tick + 5)
	await shot("5_06_sweep")
	steps(40)
	force(&"red_charge", Vector2(-160, 0))
	to_tick(tells[0].hit_tick + 8)
	await shot("5_07_charge_running")
	to_tick(tells[0].end_tick + 8)
	await shot("5_08_charge_trail")
	print("CAPTURE 5 OK")
	quit(0)


# ---- GIF mode -----------------------------------------------------------------------------------------------------------------

## Each attack once, Totoy standing in its hit area (he is kept alive): [attack, phase (its windup speed), where he stands].
const GIF_RUNS: Array = [[&"gold_slam", 1, Vector2(-110, 0)], [&"gold_combo", 2, Vector2(-110, -10)], [&"red_stomp", 1, Vector2(-110, 0)],
	[&"red_shards", 1, Vector2(-140, 10)], [&"red_charge", 2, Vector2(-160, 0)]]


func run_gifs() -> void:
	for spec: Array in GIF_RUNS:
		var id: StringName = spec[0]
		var folder: String = ("gif_real_" if OS.get_cmdline_user_args().has("--real") else "gif_") + String(id)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + folder))
		boss().clear_telegraph()
		boss().state = &"chase"
		boss().phase = int(spec[1])
		boss().position = HOME
		boss().cooldown = 12
		boss().next_attack_override = id
		mock = &""
		tells.clear()
		var n: int = 0
		var first_blow: int = -1
		var last_end: int = 1 << 30
		for i: int in 400:
			scene.core.player.position = HOME + Vector2(spec[2])
			steps(1)
			if tells.is_empty():
				var found: Array = boss().all_telegraphs().filter(func(w: Telegraph) -> bool: return w.attack == id)
				if not found.is_empty():
					tells.assign(found)
					mock = id
					last_end = 0
					for w: Telegraph in tells:
						last_end = maxi(last_end, w.end_tick)
			if first_blow < 0 and not tells.is_empty() and scene.core.tick >= tells[0].hit_tick:
				first_blow = n
			if i % 2 == 0:
				await shot("%s/seq_%04d" % [folder, n])
				n += 1
			if scene.core.tick > last_end + 48:
				break
		boss().cooldown = 100000
		var meta_file: FileAccess = FileAccess.open(OUT + folder + "/meta.json", FileAccess.WRITE)
		meta_file.store_string(JSON.stringify({"attack": String(id), "first_blow": first_blow, "pictures": n}))
		meta_file.close()
		print("GIF RUN ", id, " ", n, " pictures, first blow at ", first_blow)
		for i: int in 40:
			steps(1)
	print("CAPTURE 5 GIFS OK")
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


## The ground slam's frame `n` (1..SLAM_FRAMES) with its impact point on `at`.
func slam(n: int, at: Vector2) -> void:
	var m: Dictionary = meta("ground_slam")
	var texture: ImageTexture = pfx("ground_slam", String(m["frames"][(n - 1) * 2]))
	var pivot: Vector2 = Vector2(m["pivot"][0], m["pivot"][1])
	scene.draw_texture(texture, (at - pivot).round(), scene.ambient())


## An installed (approved) effect frame of the atlas standing at `at`.
func sprite(name: String, at: Vector2) -> void:
	if not scene.frames.has(name):
		return
	var f: Dictionary = scene.frames[name]
	var corner: Vector2 = (at - Vector2(float(f["ax"]), float(f["ay"]))).round()
	scene.draw_texture_rect_region(scene.sprites, Rect2(corner, Vector2(f["w"], f["h"])), Rect2(f["x"], f["y"], f["w"], f["h"]), scene.ambient())


func shard(age: int, at: Vector2) -> void:
	var n: int = floori(float(age) / 4.0) + 1
	if n >= 1 and n <= SHARD_FRAMES:
		sprite("fx_colossus_shard_%d" % n, at)


func dust(age: int, at: Vector2) -> void:
	var n: int = age / 4
	if age < 0 or n >= DUST_FRAMES:
		return
	var m: Dictionary = meta("dust_puff")
	var texture: ImageTexture = pfx("dust_puff", String(m["frames"][DUST_FIRST + n * 2]))
	scene.draw_texture(texture, (at - Vector2(m["pivot"][0], m["pivot"][1])).round(), scene.ambient())


func draw_mock() -> void:
	var tick: int = scene.core.tick
	match mock:
		&"gold_slam", &"gold_combo":  # the floor cracks under each real circle as it strikes
			for t: Telegraph in tells:
				var n: int = (tick - t.hit_tick) / 4 + 1
				if tick >= t.hit_tick and n <= SLAM_FRAMES:
					slam(n, t.center)
		&"red_stomp":  # stone shards across the real ring's band
			var t: Telegraph = tells[0]
			var radius: float = (t.inner_size + t.size) * 0.5
			var count: int = roundi(TAU * radius / 40.0)
			for k: int in count:
				shard(tick - t.hit_tick - k % 3, t.center + Vector2.from_angle(TAU * float(k) / float(count)) * radius)
		&"red_shards":  # stone shards racing out along each real lane
			for t: Telegraph in tells:
				var k: int = 0
				var d: float = 30.0
				while d <= t.size:
					var side: Vector2 = t.direction.orthogonal() * (3.0 if k % 2 == 0 else -3.0)
					shard(tick - t.hit_tick - k, t.center + t.direction * d + side)
					d += 22.0
					k += 1
		&"red_sweep":  # dust kicked up along the real cone's arc, in the order the arm swings through it
			var t: Telegraph = tells[0]
			var puffs: int = 7
			for k: int in puffs:
				var angle: float = t.direction.angle() + t.half_angle * (1.0 - 2.0 * float(k) / float(puffs - 1))
				for reach: float in [0.55, 0.85]:
					dust(tick - t.hit_tick - k, t.center + Vector2.from_angle(angle) * t.size * reach)
		&"red_charge":  # dust where its feet pass along the real lane
			var t: Telegraph = tells[0]
			var run: int = t.end_tick - t.hit_tick + 1
			for k: int in range(0, mini(tick, t.end_tick) - t.hit_tick + 1, 2):
				var along: float = t.size * float(k + 1) / float(run)
				for side: float in [-22.0, 22.0]:
					dust(tick - t.hit_tick - k, t.center + t.direction * along + t.direction.orthogonal() * side)
