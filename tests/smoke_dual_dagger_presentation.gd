extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_dual_dagger_presentation.gd
## Dual Dagger presentation: Q no longer swaps (equip requests come from the character menu), the swap changing the drawn frame set, the HUD (medallion, form slot,
## labels, swap hint), the Lightning Form look (no Black Form aura, darkening or slash), the Lightning Form cut-in
## (starts only for the form, freezes and resumes the world), the blink / sky strike effects from real core
## events, and the automatic Lightning Barrage the form starts with. With `-- --capture` in a window it also saves art/build/arena_dagger_*.png for a visual check.
const Arena := preload("res://presentation/arena/arena.gd")
const Anim := preload("res://presentation/arena/animation.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const View := preload("res://presentation/arena/weapon_buff_view.gd")
const Fx := preload("res://presentation/arena/lightning_effects.gd")
const CutIn := preload("res://presentation/arena/lightning_form_cutin.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const Snapshots := preload("res://core/snapshots.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")

var arena: Arena
var failures: Array[String] = []
var capture: bool = false
var seen: Dictionary = {}


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func observe() -> void:
	arena.snapshot = arena.core.snapshot()
	arena._update_camera(false)
	arena._age_effects()
	arena.prepare_visuals()
	for event: GameEvent in arena.core.last_events:
		seen[event.type] = int(seen.get(event.type, 0)) + 1
		arena._on_event(event)
	arena._update_hud()
	arena.queue_redraw()


func step(frame: InputFrame = null) -> void:
	arena.core.step(frame if frame != null else InputFrame.new())
	observe()


func press(field: String) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.set(field, true)
	if field == "attack_pressed":
		frame.aim = Vector2.RIGHT
	step(frame)


## The old Q press as an equip request: the weapon after the equipped one in Weapons.IDS.
func swap() -> void:
	var frame: InputFrame = InputFrame.new()
	frame.weapon_equip = Weapons.next(arena.snapshot.player.weapon_id)
	step(frame)


func save(label: String) -> void:
	if not capture:
		return
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_dagger_" + label + ".png") == OK, "capture " + label)


## The fight with the boss quiet, the hero just left of it (inside dagger reach), full Edge.
func fixture(gap: float = 28.0) -> void:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = Vector2(400, 240)
	arena.core.player.position = Vector2(400 - gap, 240)
	arena.core.player.edge = Tuning.EDGE_MAX
	observe()


func chosen() -> String:
	return String(arena.selected_frames.get(arena.snapshot.player.id, ""))


## Q no longer swaps in the arena (2026-10-21): no arena_weapon_swap action, and Q only switches the menu's tabs.
func input_binding() -> void:
	Bindings.register()
	check(not InputMap.has_action("arena_weapon_swap"), "arena_weapon_swap must be gone")
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("arena_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			check(not (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q), "Q is still bound to " + action)
	var q_tab: bool = false
	for event: InputEvent in InputMap.action_get_events("menu_tab_prev"):
		q_tab = q_tab or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q)
	check(q_tab, "Q must switch the character menu's tab")
	await process_frame
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	var frame: InputFrame = Bindings.read_frame()
	check(frame.weapon_equip == &"" and not frame.weapon_active_pressed and not frame.attack_pressed, "Q must send no arena intent")
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame


func pure_helpers() -> void:
	for name_key: String in Fx.all_names() + View.all_names():
		check(arena.frames.has(name_key), "atlas misses " + name_key)
	for key: String in [Hud.DAGGER_MEDALLION, Hud.LIGHTNING_FORM_ICON]:
		check(arena.frames.has(key), "HUD art missing " + key)
	check(Vector2(arena.frames[Hud.DAGGER_MEDALLION]["w"], arena.frames[Hud.DAGGER_MEDALLION]["h"]) == Hud.weapon_rect().size, "dagger medallion must be drawn at its native 48 px")
	check(Vector2(arena.frames[Hud.LIGHTNING_FORM_ICON]["w"], arena.frames[Hud.LIGHTNING_FORM_ICON]["h"]) == Hud.form_icon_rect().size, "form icon must be drawn at its native 24 px")
	for rect: Rect2 in Hud.aspect_rects() + [Hud.weapon_rect()]:
		check(not rect.intersects(Hud.form_icon_rect()), "form icon overlaps a socket")
	check(Rect2(0, 0, 320, 180).encloses(Hud.form_icon_rect()), "form icon off screen")
	# the cut travels from the blink side through the boss
	for side: int in range(8):
		var arrival: Vector2 = Vector2(400, 240) + Weapons.blink_direction(side) * 30.0
		check(Fx.cut_direction(side, arrival, Vector2(400, 240)) == posmod(side + 4, 8), "cut direction from side %d" % side)
		check(Fx.cut_direction(side) == posmod(side + 4, 8), "cut direction from index %d" % side)
	var total: float = 0.0
	var segments: Array[Dictionary] = Fx.chain_segments(Vector2(10, 10), Vector2(110, 10))
	for segment: Dictionary in segments:
		total += float(segment["length"])
	check(segments.size() == 4 and is_equal_approx(total, 100.0), "chain segments must join end to end over the whole line")
	check(Fx.strike_scale(40.0) == 1 and Fx.strike_scale(170.0) == 2, "strike scale")
	check(Fx.sequence_frame(Fx.STRIKE_TICKS, 0) == 1 and Fx.sequence_frame(Fx.STRIKE_TICKS, Fx.sequence_length(Fx.STRIKE_TICKS)) == 0, "strike sequence ends")
	# cut-in timeline: short, on screen in the middle, off at both ends, beats in order
	check(CutIn.DURATION > 0.8 and CutIn.DURATION < 1.9, "lightning cut-in length %.2f s" % CutIn.DURATION)
	check(CutIn.banner_offset(0.0) < -700.0 and CutIn.banner_offset(CutIn.END_TIME) > 800.0, "banner enters from the left and leaves to the right")
	check(absf(CutIn.banner_offset(0.5)) < 5.0, "banner rests on screen")
	check(CutIn.beat_at(0.2)[0] == "crouch" and CutIn.beat_at(0.5)[0] == "ready" and CutIn.beat_at(0.8)[0] == "burst", "beats crouch, ready, burst")
	check(CutIn.flash_at(0.0) == 1 and CutIn.bolt_at(0.61) == 1 and CutIn.bolt_at(0.64) == 2, "flash pop and burst bolt")


func swap_and_hud() -> void:
	fixture(60.0)
	check(chosen().begins_with("hero2_"), "the fight starts with the katana set")
	check(Hud.weapon_label(arena.snapshot.player.weapon_id) == "BLACK", "katana label")
	swap()
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_DUAL_DAGGER, "swap did not equip the dagger")
	check(int(seen.get(GameEvent.WEAPON_SWAPPED, 0)) >= 1, "no weapon_swapped event")
	check(chosen().begins_with("totoy_dagger_idle_right_"), "Q swap must change the drawn set: " + chosen())
	check(Hud.weapon_label(arena.snapshot.player.weapon_id) == "DAGGER", "dagger label")
	var status: Dictionary = Hud.weapon_status(arena.snapshot)
	check(status["weapon"] == Tuning.WEAPON_DUAL_DAGGER and int(status["cost"]) == int(Tuning.LIGHTNING_FORM_EDGE_COST), "HUD shows the dagger's active cost")
	check(not bool(status["active"]) and float(status["cooldown_fraction"]) == 0.0, "idle dagger: no ring")
	check(arena.snapshot.hud.weapon_swap_lockout_ticks == 0, "no swap lockout after an equip")
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS + 1):
		step()
	check(arena.snapshot.hud.weapon_swap_lockout_ticks == 0, "lockout over")
	await save("idle")
	var walk_left: InputFrame = InputFrame.new()
	walk_left.move = Vector2.LEFT
	for i: int in range(8):
		step(walk_left)
	check(arena.facing_left and chosen().begins_with("totoy_dagger_walk_right_"), "dagger walking left draws the mirrored walk")
	await save("walk_left")
	for i: int in range(8):
		walk_left.move = Vector2.RIGHT
		step(walk_left)
	step()
	# swing through the whole combo; the dagger draws its own frames and never the katana's slash
	press("attack_pressed")
	var swings: Dictionary = {}
	for i: int in range(120):
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		if hero.state.begins_with("attack_"):
			check(chosen().begins_with("totoy_dagger_attack%d_" % hero.combo_index), "swing %d drew %s" % [hero.combo_index, chosen()])
			check(arena.weapon_slash_effect().is_empty(), "katana slash drawn over a dagger swing")
			if hero.state == &"attack_active" and not swings.has(hero.combo_index):
				swings[hero.combo_index] = true
				await save("swing%d" % hero.combo_index)
		var chain: InputFrame = InputFrame.new()
		chain.attack_pressed = hero.state == &"attack_recovery" and hero.combo_index < 4
		chain.aim = Vector2.RIGHT
		step(chain)
		await process_frame
	check(swings.size() == 4, "the dagger combo did not reach 4 swings: %s" % str(swings.keys()))
	check(int(seen.get(GameEvent.LIGHTNING_STRIKE, 0)) >= 1, "the connecting 4th swing called no lightning strike")
	# Q cycles katana -> dagger -> scythe -> katana: the next swap draws the scythe, the one after the katana again
	swap()
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE and chosen().begins_with("totoy_scythe_"), "swap from the dagger to the scythe set: " + chosen())
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	swap()
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_BLACK_KATANA and chosen().begins_with("hero2_"), "swap back to the katana set")


func strike_effects() -> void:
	fixture()
	swap()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	seen.clear()
	press("attack_pressed")
	var struck: bool = false
	var strike_tick: int = -1
	for i: int in range(140):
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		var chain: InputFrame = InputFrame.new()
		chain.attack_pressed = hero.state == &"attack_recovery" and hero.combo_index < 4
		chain.aim = Vector2.RIGHT
		step(chain)
		await process_frame
		if not struck and int(seen.get(GameEvent.LIGHTNING_STRIKE, 0)) > 0:
			struck = true
			strike_tick = arena.snapshot.tick
			var kinds: Dictionary = {}
			for effect: Dictionary in arena.lightning_fx:
				kinds[effect["kind"]] = true
			check(kinds.has("strike") and kinds.has("ground") and kinds.has("spark"), "strike effects missing: %s" % str(kinds.keys()))
			check(not arena.screen_flashes.is_empty() and arena.shake_left > 0, "strike has no flash or shake")
			await save("strike_0")
		if struck and arena.snapshot.tick - strike_tick in [2, 5, 9]:
			await save("strike_%d" % (arena.snapshot.tick - strike_tick))
	check(struck, "no lightning strike in a full dagger combo next to the boss")
	for i: int in range(120):
		step()
	check(arena.lightning_fx.is_empty() and arena.screen_flashes.is_empty(), "lightning effects never expire")


## Lightning Form is only the barrage: the form look (lightning set, aura) and the HUD's run ring last exactly as long
## as the barrage; afterwards the hero is the plain dagger again (no aura, no blinking swings, no lightning dash
## afterimages) and the slot shows the cooldown ring.
func lightning_form() -> void:
	fixture(90.0)
	swap()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	seen.clear()
	press("weapon_active_pressed")
	check(arena.snapshot.player.weapon_form == Weapons.FORM_LIGHTNING, "Lightning Form did not start")
	check(arena.lightning_cutin.active and not arena.cutin.active, "the form must start the lightning cut-in, not the Black Form one")
	arena.lightning_cutin.stop()
	check(chosen().begins_with("totoy_lightning_"), "form look not drawn: " + chosen())
	var effect: Dictionary = arena.weapon_buff_effect()
	check(not effect.is_empty() and String(effect["back"]).begins_with("fx_lightning_aura_back_") and String(effect["front"]).begins_with("fx_lightning_aura_front_"), "form aura layers")
	check(String(effect["slash"]).is_empty(), "form adds a detached slash")
	check(not arena.black_form_look(arena.snapshot.player), "form uses the Black Form darkening")
	var running: Dictionary = Hud.weapon_status(arena.snapshot)
	check(bool(running["active"]) and float(running["duration_fraction"]) > 0.9, "HUD shows the barrage running (run ring)")
	await save("form_aura")
	while arena.snapshot.player.state == &"lightning_barrage":
		check(arena.snapshot.player.weapon_form == Weapons.FORM_LIGHTNING and not arena.weapon_buff_effect().is_empty(), "the form look runs through the barrage")
		step()
	# The barrage is over: so is the form.
	check(not arena.snapshot.player.weapon_buff_active and arena.snapshot.player.weapon_form == &"", "the form outlived the barrage")
	check(arena.weapon_buff_effect().is_empty(), "the lightning aura lingers after the barrage")
	var after: Dictionary = Hud.weapon_status(arena.snapshot)
	check(not bool(after["active"]) and float(after["cooldown_fraction"]) > 0.9 and int(after["cooldown"]) > 0, "the slot shows the cooldown ring after the barrage")
	var left: InputFrame = InputFrame.new()
	left.move = Vector2.LEFT
	for i: int in range(6):
		step(left)
	check(arena.facing_left and chosen().begins_with("totoy_dagger_walk_right_"), "after the barrage the hero walks as the plain dagger: " + chosen())
	await save("after_barrage_walk")
	# swings after the barrage do not blink
	var blinks_before: int = int(seen.get(GameEvent.LIGHTNING_BLINK, 0))
	for i: int in range(60):
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		var chain: InputFrame = InputFrame.new()
		chain.attack_pressed = hero.state == &"idle" or (hero.state == &"attack_recovery" and hero.combo_index < 4)
		chain.aim = Vector2.RIGHT
		step(chain)
		if arena.snapshot.player.state.begins_with("attack_"):
			check(chosen().begins_with("totoy_dagger_attack"), "a swing after the barrage drew " + chosen())
	check(int(seen.get(GameEvent.LIGHTNING_BLINK, 0)) == blinks_before, "a swing after the barrage blinked")
	# a dash after the barrage leaves the plain ghosts, no lightning afterimages
	var dash: InputFrame = InputFrame.new()
	dash.dash_pressed = true
	dash.move = Vector2.LEFT
	for i: int in range(20):
		step()
	step(dash)
	step()
	step()
	var kinds: Dictionary = {}
	for fx: Dictionary in arena.lightning_fx:
		kinds[fx["kind"]] = true
	check(not kinds.has("afterimage"), "lightning afterimages after the barrage")
	await save("after_barrage_dash")
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## The Lightning Barrage from a real activation: 8 blinks, each drawn as departure/arrival bursts, afterimages, a chain
## bolt and a cut with a small shake and flash; the last slash calls the sky bolt; the effect count stays bounded and
## everything expires; every frame exists. Then, with the arena's own physics loop: the cut-in freezes the world, the
## barrage then runs on (not frozen by it), and a restart in the middle cancels it.
func barrage() -> void:
	fixture(90.0)
	swap()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	seen.clear()
	arena.missing_frames.clear()
	press("weapon_active_pressed")
	check(int(seen.get(GameEvent.LIGHTNING_BARRAGE_STARTED, 0)) == 1, "no lightning_barrage_started on the activation")
	check(arena.snapshot.player.state == &"lightning_barrage", "the hero is not in the barrage")
	check(arena.lightning_cutin.active, "the cut-in plays before the barrage")
	arena.lightning_cutin.stop()
	var blinks: int = 0
	var most_fx: int = 0
	var most_particles: int = 0
	var blink_tick: int = -1
	var sides: Dictionary = {}
	for i: int in range(Weapons.barrage_total_ticks() + 5):
		var before: int = int(seen.get(GameEvent.LIGHTNING_BLINK, 0))
		var strikes_before: int = int(seen.get(GameEvent.LIGHTNING_STRIKE, 0))
		step()
		await process_frame
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		if hero.state == &"lightning_barrage":
			check(chosen().begins_with("totoy_lightning_attack"), "barrage pose is not a lightning dagger attack: " + chosen())
		most_fx = maxi(most_fx, arena.lightning_fx.size())
		most_particles = maxi(most_particles, arena.particles.size())
		if int(seen.get(GameEvent.LIGHTNING_BLINK, 0)) > before:
			blinks += 1
			blink_tick = arena.snapshot.tick
			sides[hero.lightning_blink_index] = true
			var kinds: Dictionary = {}
			for fx: Dictionary in arena.lightning_fx:
				kinds[fx["kind"]] = true
			for kind: String in ["depart", "arrive", "chain", "cut", "afterimage"]:
				check(kinds.has(kind), "barrage blink %d effect missing: %s" % [blinks, kind])
			check(arena.shake_left > 0 and not arena.screen_flashes.is_empty(), "barrage blink %d has no shake or flash" % blinks)
			if blinks in [1, 2, 5]:
				await save("barrage%d_blink" % blinks)
		elif blinks in [1, 2, 5] and arena.snapshot.tick - blink_tick == Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS:
			check(chosen().ends_with("_right_4"), "the hit tick shows the strike pose: " + chosen())
			await save("barrage%d_hit" % blinks)
		elif blinks in [2, 5] and arena.snapshot.tick - blink_tick == Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS - 1:
			check(not arena.flashes.has(arena.snapshot.entities[0].id), "the boss stays white between barrage slashes")
			await save("barrage%d_gap" % blinks)
		if int(seen.get(GameEvent.LIGHTNING_STRIKE, 0)) > strikes_before:
			var kinds: Dictionary = {}
			for fx: Dictionary in arena.lightning_fx:
				kinds[fx["kind"]] = true
			check(kinds.has("strike") and kinds.has("ground"), "the barrage finisher has no sky bolt: %s" % str(kinds.keys()))
			check(arena.shake_left >= 8, "the finisher has no big shake")
			await save("barrage_strike_0")
			step()
			step()
			await save("barrage_strike_2")
	check(blinks == Weapons.barrage_slashes(), "barrage drew %d blinks" % blinks)
	check(sides.size() == 8, "the barrage did not come from all 8 sides: %s" % str(sides.keys()))
	check(int(seen.get(GameEvent.LIGHTNING_STRIKE, 0)) == 1, "the barrage called %d sky bolts" % int(seen.get(GameEvent.LIGHTNING_STRIKE, 0)))
	check(int(seen.get(GameEvent.LIGHTNING_BARRAGE_ENDED, 0)) == 1, "no lightning_barrage_ended")
	check(arena.snapshot.player.state != &"lightning_barrage" and arena.snapshot.player.weapon_form == &"", "the form ends with the barrage")
	check(most_fx <= 48, "lightning effects pile up: %d live at once" % most_fx)
	check(most_particles <= 160, "particles pile up: %d live at once" % most_particles)
	for i: int in range(120):
		step()
	check(arena.lightning_fx.is_empty() and arena.screen_flashes.is_empty(), "barrage effects never expire")
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))
	# The arena's own loop: the cut-in freezes, then the barrage runs on, and a restart cancels it midway.
	fixture(90.0)
	swap()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	press("weapon_active_pressed")
	var frozen_at: int = arena.core.tick
	arena.set_physics_process(true)
	var frames: int = 0
	while arena.cutin_playing() and frames < 300:
		await physics_frame
		frames += 1
	check(not arena.cutin_playing(), "the cut-in never ended")
	check(arena.core.tick == frozen_at, "the world stepped during the cut-in")
	for i: int in 20:
		await physics_frame
	check(arena.core.tick >= frozen_at + 15, "the world is frozen during the barrage (%d ticks)" % (arena.core.tick - frozen_at))
	check(arena.snapshot.player.state == &"lightning_barrage" and arena.snapshot.player.lightning_barrage_slash >= 2, "the barrage does not progress in the arena loop")
	arena._restart()
	arena.set_physics_process(false)
	check(arena.snapshot.player.state == &"idle" and not arena.core.player.barrage_running, "restart did not cancel the barrage")
	check(arena.lightning_fx.is_empty() and arena.screen_flashes.is_empty() and not arena.cutin_playing(), "restart left barrage effects")


## The cut-in freezes the world while it plays and lets it run afterwards; Black Form stays katana-only.
func cutin_freeze() -> void:
	fixture(90.0)
	swap()
	arena.set_physics_process(true)
	arena._on_event(GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, 5, {"entity_id": 1, "weapon_id": Tuning.WEAPON_DUAL_DAGGER, "form": Weapons.FORM_LIGHTNING, "duration": 55, "attack_speed_mult": 1.0, "damage_mult": 1.0, "move_speed_mult": 1.0}))
	check(arena.lightning_cutin.active and not arena.cutin.active, "lightning event starts only the lightning cut-in")
	check(arena.cutin_playing(), "cut-in playing")
	var tick_before: int = arena.core.tick
	var frames: int = 0
	var shots: int = 0
	while arena.lightning_cutin.active and frames < 300:
		await physics_frame
		await process_frame
		frames += 1
		if capture and arena.lightning_cutin.preview_time() >= [0.02, 0.12, 0.25, 0.38, 0.45, 0.61, 0.65, 0.75, 0.92][mini(shots, 8)] and shots < 9:
			await save("cutin_%02d" % shots)
			shots += 1
	check(not arena.lightning_cutin.active, "the lightning cut-in ends by itself")
	check(absf(frames / 60.0 - CutIn.DURATION) < 0.2 or capture, "it lasts about %.2f s (took %.2f s)" % [CutIn.DURATION, frames / 60.0])
	check(arena.core.tick == tick_before, "the core stepped during the lightning cut-in")
	for i: int in 5:
		await physics_frame
	check(arena.core.tick > tick_before, "the world does not resume after the lightning cut-in")
	arena.set_physics_process(false)
	arena._on_event(GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, 50, {"entity_id": 1, "weapon_id": Tuning.WEAPON_BLACK_KATANA, "form": Weapons.FORM_BLACK_KATANA_BUFF, "duration": 600, "attack_speed_mult": 1.5, "damage_mult": 1.4, "move_speed_mult": 1.0}))
	check(arena.cutin.active and not arena.lightning_cutin.active, "the katana buff starts only the Black Form cut-in")
	arena._restart()
	check(not arena.cutin_playing(), "restart cancels the cut-ins")
	var broken: CutIn = CutIn.new()
	broken.start()
	check(not broken.active, "without art the cut-in is skipped")
	broken.free()


func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	await input_binding()
	pure_helpers()
	await swap_and_hud()
	await strike_effects()
	await lightning_form()
	await barrage()
	await cutin_freeze()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("DUAL DAGGER FAIL: " + message)
	print("DUAL DAGGER PRESENTATION SMOKE OK" if failures.is_empty() else "DUAL DAGGER PRESENTATION FAILED")
	quit(0 if failures.is_empty() else 1)
