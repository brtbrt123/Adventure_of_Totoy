extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_chain_scythe_presentation.gd
## Chain Scythe presentation: the 3-weapon swap (drawn set, HUD medallion/labels/slot, swap hint), the scythe swings 1-3
## with their arcs (no katana slash, no Black Form look), and Reaper's Coil from real core events through the arena:
## its own cut-in (freezes and resumes the world, the other cut-ins stay with their weapons), the chain and flying head,
## the hook clink, the drag (boss pulled and staggered, streaks, dust, scuffs), the stagger burst and dizzy stars, the
## spin ring and its hit sparks, the miss (poof, the hero pulled to the anchor), a restart cancelling it, the effect cap,
## and no missing frames. With `-- --capture` in a window it saves art/build/arena_scythe_*.png for a visual check.
const Arena := preload("res://presentation/arena/arena.gd")
const Anim := preload("res://presentation/arena/animation.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const View := preload("res://presentation/arena/weapon_buff_view.gd")
const Fx := preload("res://presentation/arena/scythe_effects.gd")
const CutIn := preload("res://presentation/arena/reapers_coil_cutin.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const PlayerState := preload("res://core/player.gd")
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


func press(field: String, aim: Vector2 = Vector2.RIGHT) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.set(field, true)
	frame.aim = aim
	step(frame)


func save(label: String) -> void:
	if not capture:
		return
	arena.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_scythe_" + label + ".png") == OK, "capture " + label)


## The fight with the boss quiet at (400, 240), the hero `gap` px left of it, full Edge.
func fixture(gap: float = 30.0) -> void:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = Vector2(400, 240)
	arena.core.player.position = Vector2(400 - gap, 240)
	arena.core.player.edge = Tuning.EDGE_MAX
	observe()


## Q twice (with the lockout in between): katana -> dagger -> scythe.
func equip_scythe() -> void:
	press("weapon_swap_pressed")
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	press("weapon_swap_pressed")
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE, "two swaps did not equip the scythe")


## Puts the hero `gap` px left of the boss again (the boss walks toward the hero while the swap lockout runs).
func place(gap: float) -> void:
	arena.core.boss.position = Vector2(400, 240)
	arena.core.player.position = Vector2(400 - gap, 240)
	observe()


func chosen() -> String:
	return String(arena.selected_frames.get(arena.snapshot.player.id, ""))


func boss() -> Snapshots.EntitySnapshot:
	return arena.snapshot.entities[0]


func kinds() -> Dictionary:
	var found: Dictionary = {}
	for effect: Dictionary in arena.coil_fx:
		found[effect["kind"]] = true
	return found


func pure_helpers() -> void:
	for name_key: String in Fx.all_names() + Fx.coil_names():
		if name_key in ["fx_scythe_spin_front_1", "fx_scythe_spin_back_4"]:
			continue  # intentionally empty halves (README)
		check(arena.frames.has(name_key), "atlas misses " + name_key)
	for key: String in [Hud.SCYTHE_MEDALLION, Hud.REAPER_COIL_ICON]:
		check(arena.frames.has(key), "HUD art missing " + key)
	check(Vector2(arena.frames[Hud.SCYTHE_MEDALLION]["w"], arena.frames[Hud.SCYTHE_MEDALLION]["h"]) == Hud.weapon_rect().size, "scythe medallion must be drawn at its native 48 px")
	check(Vector2(arena.frames[Hud.REAPER_COIL_ICON]["w"], arena.frames[Hud.REAPER_COIL_ICON]["h"]) == Hud.form_icon_rect().size, "coil icon must be drawn at its native 24 px")
	for key: String in ["totoy_scythe_coil_whip_1", "totoy_scythe_coil_whip_3", "totoy_scythe_coil_pull_2"]:
		check(arena.chain_origins.has(key), "chain_origin not loaded for " + key)
	check(Hud.next_weapon(Tuning.WEAPON_BLACK_KATANA) == Tuning.WEAPON_DUAL_DAGGER and Hud.next_weapon(Tuning.WEAPON_DUAL_DAGGER) == Tuning.WEAPON_CHAIN_SCYTHE and Hud.next_weapon(Tuning.WEAPON_CHAIN_SCYTHE) == Tuning.WEAPON_BLACK_KATANA, "swap cycle")
	check(Fx.flying_frame(Vector2.UP) == 1 and Fx.flying_frame(Vector2.RIGHT) == 3 and Fx.flying_frame(Vector2.DOWN) == 5 and Fx.flying_frame(Vector2.LEFT) == 7, "flying head rotation")
	check(Fx.ring_phase(0) == 1 and Fx.ring_phase(8) == 2 and Fx.ring_phase(Tuning.REAPER_COIL_SPIN_TICKS - 1) == 4 and Fx.ring_phase(Tuning.REAPER_COIL_SPIN_TICKS) == 0, "spin ring phases")
	var effects: Array[Dictionary] = []
	for i: int in range(Fx.MAX_LIVE + 10):
		Fx.add(effects, {"kind": "dust", "tick": i})
	check(effects.size() == Fx.MAX_LIVE and int(effects[0]["tick"]) == 10, "the effect cap drops the oldest")
	# cut-in timeline: about 1.25 s, enters from the left and is yanked back out to the left
	check(CutIn.DURATION > 1.1 and CutIn.DURATION < 1.4, "coil cut-in length %.2f s" % CutIn.DURATION)
	check(CutIn.banner_offset(0.0) < -700.0 and CutIn.banner_offset(CutIn.END_TIME) < -800.0, "banner enters from the left and leaves to the left")
	check(absf(CutIn.banner_offset(0.5)) < 5.0, "banner rests on screen")
	check(CutIn.beat_at(0.2)[0] == "crouch" and CutIn.beat_at(0.5)[0] == "ready" and CutIn.beat_at(0.8)[0] == "burst", "beats crouch, ready, burst")
	check(CutIn.flash_at(0.0) == 1 and CutIn.strike_at(0.63) == 1 and CutIn.strike_at(0.66) == 2, "flash pop and haul strike")
	check(CutIn.TITLE == "REAPER'S COIL" and CutIn.SUBTITLE == "HOOK - DRAG - STAGGER", "title text")


func swap_swings_hud() -> void:
	fixture(60.0)
	equip_scythe()
	check(chosen().begins_with("totoy_scythe_idle_right_"), "the scythe swap must draw the scythe set: " + chosen())
	check(Hud.weapon_label(arena.snapshot.player.weapon_id) == "SCYTHE", "scythe label")
	var status: Dictionary = Hud.weapon_status(arena.snapshot)
	check(status["weapon"] == Tuning.WEAPON_CHAIN_SCYTHE and int(status["cost"]) == int(Tuning.REAPER_COIL_EDGE_COST), "HUD shows the coil's cost")
	check(Hud.weapon_active_line(status) in ["REAPER'S COIL", "COIL"], "idle scythe active line: " + Hud.weapon_active_line(status))
	check(Hud.swap_status(arena.snapshot)["next"] == Tuning.WEAPON_BLACK_KATANA, "after the scythe Q goes to the katana")
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS + 1):
		step()
	await save("idle_hud")
	var walk: InputFrame = InputFrame.new()
	walk.move = Vector2.LEFT
	for i: int in range(8):
		step(walk)
	check(arena.facing_left and chosen().begins_with("totoy_scythe_walk_right_"), "scythe walking left draws the mirrored walk")
	await save("walk_left")
	walk.move = Vector2.RIGHT
	for i: int in range(8):
		step(walk)
	await save("walk_right")
	fixture(28.0)
	equip_scythe()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	press("attack_pressed")
	var arcs: Dictionary = {}
	for i: int in range(140):
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		if hero.state.begins_with("attack_"):
			check(chosen().begins_with("totoy_scythe_attack%d_" % hero.combo_index), "swing %d drew %s" % [hero.combo_index, chosen()])
			check(arena.weapon_slash_effect().is_empty() and arena.weapon_buff_effect().is_empty(), "katana slash or aura over a scythe swing")
			var arc: Dictionary = arena.scythe_arc_effect()
			if hero.state == &"attack_active":
				check(not arc.is_empty() and String(arc["key"]).begins_with("fx_scythe_arc_%d_" % hero.combo_index), "swing %d active without its arc" % hero.combo_index)
			if not arc.is_empty():
				check(arena.frames.has(arc["key"]), "arc frame missing " + String(arc["key"]))
				var label: String = "swing%d_arc%s" % [hero.combo_index, String(arc["key"]).right(1)]
				if not arcs.has(label):
					arcs[label] = true
					await save(label)
		var chain: InputFrame = InputFrame.new()
		chain.attack_pressed = hero.state == &"attack_recovery" and hero.combo_index < 3
		chain.aim = Vector2.RIGHT
		step(chain)
	for swing: int in range(1, 4):
		for phase: int in range(1, 5):
			check(arcs.has("swing%d_arc%d" % [swing, phase]), "swing %d never drew arc phase %d" % [swing, phase])
	# a swing facing left mirrors the arc with the hero
	fixture(28.0)
	arena.core.player.position = Vector2(428, 240)
	equip_scythe()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	press("attack_pressed", Vector2.LEFT)
	while arena.snapshot.player.state == &"attack_windup":
		step()
	var left_arc: Dictionary = arena.scythe_arc_effect()
	check(arena.facing_left and not left_arc.is_empty() and bool(left_arc["left"]), "a left swing must mirror its arc")
	await save("swing1_left")
	# the third swap returns to the katana
	for i: int in range(60):
		step()
	press("weapon_swap_pressed")
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_BLACK_KATANA and chosen().begins_with("hero2_"), "third swap must return to the katana set")
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## A coil that hooks the boss 100 px away: chain, hook, drag, stun, spin, recovery, all from the real core.
func coil_hit() -> void:
	fixture(100.0)
	equip_scythe()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	place(100.0)
	seen.clear()
	arena.missing_frames.clear()
	press("weapon_active_pressed")
	check(arena.snapshot.player.state == PlayerState.STATE_REAPER_COIL, "Reaper's Coil did not start")
	check(arena.coil_cutin.active and not arena.cutin.active and not arena.lightning_cutin.active, "the coil must start only its own cut-in")
	arena.coil_cutin.stop()
	check(not arena.black_form_look(arena.snapshot.player) and arena.weapon_buff_effect().is_empty(), "the coil uses the Black Form look")
	var running: Dictionary = Hud.weapon_status(arena.snapshot)
	check(bool(running["active"]) and Hud.weapon_active_line(running) == "COILING" and float(running["duration_fraction"]) > 0.9, "HUD shows the coil running with its run ring")
	check(Hud.swap_status(arena.snapshot)["reason"] == "FORM", "swap hint shows the lock")
	await save("coil_windup")
	var boss_start: Vector2 = boss().position
	var most_fx: int = 0
	var shots: Dictionary = {}
	var staggered_seen: bool = false
	var stars_seen: bool = false
	var dragged_seen: bool = false
	for i: int in range(Weapons.reaper_coil_total_ticks() + 4):
		var hooked_before: int = int(seen.get(GameEvent.REAPER_COIL_HOOKED, 0))
		var drag_before: int = int(seen.get(GameEvent.REAPER_COIL_DRAG, 0))
		var spins_before: int = int(seen.get(GameEvent.REAPER_COIL_SPIN, 0))
		step()
		await process_frame
		most_fx = maxi(most_fx, arena.coil_fx.size())
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		if hero.state == PlayerState.STATE_REAPER_COIL:
			check(chosen().begins_with("totoy_scythe_coil_"), "coil pose: " + chosen())
			check(arena.weapon_buff_effect().is_empty() and arena.weapon_slash_effect().is_empty(), "katana look during the coil")
		var phase: StringName = hero.reaper_coil_phase
		if phase == PlayerState.COIL_HOOK and hero.reaper_coil_phase_tick == 5:
			check(Fx.chain_visible(hero) and arena.chain_hand().distance_to(arena.chain_tip()) > 30.0, "no chain in flight: %.1f px" % arena.chain_hand().distance_to(arena.chain_tip()))
			await save("hook_flight")
		if int(seen.get(GameEvent.REAPER_COIL_HOOKED, 0)) > hooked_before:
			check(kinds().has("hook") and arena.shake_left > 0 and not arena.screen_flashes.is_empty(), "hook has no clink, shake or flash")
			await save("hooked")
		if boss().dragged:
			dragged_seen = true
			check(boss().state == &"staggered", "a dragged boss is not staggered")
			check(String(arena.selected_frames[boss().id]).begins_with("golem2_staggered_") or String(arena.selected_frames[boss().id]).begins_with("golem2_hurt_"), "dragged boss pose: " + String(arena.selected_frames[boss().id]))
			if not shots.has("drag"):
				shots["drag"] = true
				step()
				await save("drag")
				check(kinds().has("dust") and kinds().has("scuff"), "the drag leaves no dust or scuffs: %s" % str(kinds().keys()))
		if int(seen.get(GameEvent.REAPER_COIL_DRAG, 0)) > drag_before:
			check(kinds().has("stagger"), "drag end has no stagger burst")
			check(boss().position.x < boss_start.x - 30.0, "the boss was not dragged toward the hero (%s)" % str(boss().position))
			await save("stagger_burst")
		if boss().state == &"staggered" and not boss().dragged and boss().stagger_ticks_left > 0:
			staggered_seen = true
			if phase == PlayerState.COIL_SPIN and hero.reaper_coil_phase_tick in [2, 6, 10, 15]:
				stars_seen = true
				await save("spin_%02d" % hero.reaper_coil_phase_tick)
		if int(seen.get(GameEvent.REAPER_COIL_SPIN, 0)) > spins_before:
			check(kinds().has("spark") or not arena.core.last_events.any(func(e: GameEvent) -> bool: return e.type == GameEvent.REAPER_COIL_SPIN and bool(e.data["connects"])), "a connecting spin draws no sparks")
		if phase == PlayerState.COIL_RECOVERY and hero.reaper_coil_phase_tick == 1:
			await save("recover")
	check(dragged_seen and staggered_seen and stars_seen, "drag %s, stun %s, stars %s" % [dragged_seen, staggered_seen, stars_seen])
	check(int(seen.get(GameEvent.REAPER_COIL_SPIN, 0)) == Tuning.REAPER_COIL_SPIN_HITS, "spin events: %d" % int(seen.get(GameEvent.REAPER_COIL_SPIN, 0)))
	check(int(seen.get(GameEvent.REAPER_COIL_ENDED, 0)) == 1, "no reaper_coil_ended")
	check(most_fx <= Fx.MAX_LIVE, "coil effects pile up: %d" % most_fx)
	var after: Dictionary = Hud.weapon_status(arena.snapshot)
	check(not bool(after["active"]) and float(after["cooldown_fraction"]) > 0.8 and int(after["cooldown"]) > 0 and Hud.weapon_active_line(after) in ["REAPER'S COIL", "COIL"], "after the coil the slot shows the cooldown ring: %s" % str(after))
	await save("after_cd_hud")
	for i: int in range(120):
		step()
	check(arena.coil_fx.is_empty() and arena.screen_flashes.is_empty(), "coil effects never expire")
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## A coil thrown away from the boss: it lands at full range, the poof shows, and the hero is pulled to the anchor.
func coil_miss() -> void:
	fixture(100.0)
	equip_scythe()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	place(100.0)
	seen.clear()
	arena.missing_frames.clear()
	var start: Vector2 = arena.snapshot.player.position
	press("weapon_active_pressed", Vector2.LEFT)
	arena.coil_cutin.stop()
	check(arena.facing_left, "a coil thrown left must face left")
	var pulled: bool = false
	for i: int in range(Weapons.reaper_coil_total_ticks() + 4):
		var missed_before: int = int(seen.get(GameEvent.REAPER_COIL_MISSED, 0))
		step()
		await process_frame
		if int(seen.get(GameEvent.REAPER_COIL_MISSED, 0)) > missed_before:
			check(kinds().has("land"), "the miss draws no landing poof")
			await save("miss_land")
		var hero: Snapshots.EntitySnapshot = arena.snapshot.player
		if hero.reaper_coil_phase == PlayerState.COIL_PULL:
			check(chosen().begins_with("totoy_scythe_coil_pull_"), "pull pose: " + chosen())
			if hero.reaper_coil_phase_tick == 6:
				pulled = true
				await save("miss_pull")
	check(pulled and int(seen.get(GameEvent.REAPER_COIL_MISSED, 0)) == 1, "the miss did not pull the hero")
	check(arena.snapshot.player.position.x < start.x - 100.0, "the hero was not pulled to the anchor (%s)" % str(arena.snapshot.player.position))
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## The arena's own loop: the cut-in freezes the world, then the coil runs on; a restart in the middle cancels it.
## Also: each weapon's cut-in plays only for its own active.
func arena_loop() -> void:
	fixture(100.0)
	equip_scythe()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS):
		step()
	press("weapon_active_pressed")
	var frozen_at: int = arena.core.tick
	arena.set_physics_process(true)
	var frames: int = 0
	var shots: int = 0
	var marks: Array[float] = [0.03, 0.14, 0.27, 0.45, 0.63, 0.7, 0.8, 0.95, 1.06]
	while arena.cutin_playing() and frames < 300:
		await physics_frame
		await process_frame
		frames += 1
		if capture and shots < marks.size() and arena.coil_cutin.preview_time() >= marks[shots]:
			await save("cutin_%02d" % shots)
			shots += 1
	check(not arena.cutin_playing(), "the coil cut-in never ended")
	check(absf(frames / 60.0 - CutIn.DURATION) < 0.2 or capture, "the cut-in lasts about %.2f s (took %.2f s)" % [CutIn.DURATION, frames / 60.0])
	check(arena.core.tick == frozen_at, "the world stepped during the cut-in")
	for i: int in 12:
		await physics_frame
	check(arena.core.tick >= frozen_at + 8, "the world is frozen after the cut-in (%d ticks)" % (arena.core.tick - frozen_at))
	check(arena.snapshot.player.state == PlayerState.STATE_REAPER_COIL and arena.snapshot.player.reaper_coil_phase != PlayerState.COIL_HOOK, "the coil does not progress in the arena loop: %s" % String(arena.snapshot.player.reaper_coil_phase))
	arena._restart()
	arena.set_physics_process(false)
	check(arena.snapshot.player.state == &"idle" and arena.snapshot.player.reaper_coil_phase == &"", "restart did not cancel the coil")
	check(arena.coil_fx.is_empty() and arena.screen_flashes.is_empty() and not arena.cutin_playing(), "restart left coil effects")
	var forms: Array = [[Tuning.WEAPON_CHAIN_SCYTHE, Weapons.FORM_REAPER_COIL, "coil"], [Tuning.WEAPON_DUAL_DAGGER, Weapons.FORM_LIGHTNING, "lightning"], [Tuning.WEAPON_BLACK_KATANA, Weapons.FORM_BLACK_KATANA_BUFF, "black"]]
	for index: int in range(forms.size()):
		arena._restart()
		arena._on_event(GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, 10 + index, {"entity_id": 1, "weapon_id": forms[index][0], "form": forms[index][1], "duration": 60, "attack_speed_mult": 1.0, "damage_mult": 1.0, "move_speed_mult": 1.0}))
		var playing: Array[bool] = [arena.coil_cutin.active, arena.lightning_cutin.active, arena.cutin.active]
		for other: int in range(3):
			check(playing[other] == (other == index), "%s active started cut-ins %s" % [forms[index][2], str(playing)])
	arena._restart()
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
	pure_helpers()
	await swap_swings_hud()
	await coil_hit()
	await coil_miss()
	await arena_loop()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("CHAIN SCYTHE FAIL: " + message)
	print("CHAIN SCYTHE PRESENTATION SMOKE OK" if failures.is_empty() else "CHAIN SCYTHE PRESENTATION FAILED")
	quit(0 if failures.is_empty() else 1)
