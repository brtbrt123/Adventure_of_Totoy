extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_ward_echo_sprint_presentation.gd
## Echo Step, Stone Ward and Sprint in presentation (2026-10-21), through the real arena loop (arena.advance):
## every effect name exists; the HUD rows (lit icons, run rings and seconds, the ward's stored ring, tooltips); Sprint
## (start burst, aura over every drawn frame, afterimages from the real past positions, capped and cleared, speed lines,
## dust and wind while moving, the faster walk cycle, end burst); Echo Step (placement burst, anchor, countdown, recall
## vanish / trail / arrival, the hero hidden for the arrival's first frame, the camera snapped with no smoothing, every
## smear buffer cleared, i-frame shield, expiry on death); Stone Ward for all three weapons (pose frames, barrier, block
## spark and absorb, stored glow levels, release shockwave at the core radius and its crack decal, the release hit drawn
## as a skill hit with no swing sound); restart clears it all; effect caps.
## With `-- --capture` in a window it saves art/build/arena_wes_*.png for a visual check (delete them afterwards).
const Arena := preload("res://presentation/arena/arena.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const W := preload("res://presentation/arena/ward_echo_sprint_effects.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Aspects := preload("res://core/aspects.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const PlayerState := preload("res://core/player.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")

const LOADOUT: Array[StringName] = [&"sprint", &"echo_step", &"stone_ward"]

var arena: Arena
var failures: Array[String] = []
var capture: bool = false


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func observe() -> void:
	arena.snapshot = arena.core.snapshot()
	arena._update_camera(false)
	arena.prepare_visuals()
	arena._update_hud()
	arena.queue_redraw()


func step(frame: InputFrame = null) -> void:
	arena.advance(frame if frame != null else InputFrame.new())


func move(direction: Vector2, ticks: int = 1) -> void:
	for i: int in range(ticks):
		var frame: InputFrame = InputFrame.new()
		frame.move = direction
		step(frame)


func press(slot: int, direction: Vector2 = Vector2.ZERO) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = slot
	frame.move = direction
	frame.aim = Vector2.RIGHT
	step(frame)


func fixture(weapon: StringName = Tuning.WEAPON_BLACK_KATANA, hero: Vector2 = Vector2(300, 250), boss: Vector2 = Vector2(560, 250)) -> void:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = boss
	arena.core.player.position = hero
	arena.core.player.edge = Tuning.EDGE_MAX
	arena.core.player.weapon_id = weapon
	check(arena.core.player.set_equipped_aspects(LOADOUT), "fixture loadout refused")
	observe()


func save(label: String) -> void:
	if not capture:
		return
	arena.queue_redraw()
	arena.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_wes_" + label + ".png") == OK, "capture " + label)


func kinds() -> Array:
	return arena.wes_fx.map(func(e: Dictionary) -> String: return String(e["kind"]))


func types() -> Array:
	return arena.core.last_events.map(func(e: GameEvent) -> StringName: return e.type)


func hero() -> Snapshots.EntitySnapshot:
	return arena.snapshot.player


func chosen() -> String:
	return String(arena.selected_frames.get(hero().id, ""))


func keys(plan: Array[Dictionary]) -> Array:
	return plan.map(func(item: Dictionary) -> String: return String(item["key"]))


func overlays() -> Array:
	return keys(arena.hero_overlay_plan(hero(), chosen(), hero().position.round(), arena.facing_left))


func back() -> Array:
	return keys(arena.sprint_back_plan(hero(), hero().position.round(), arena.facing_left))


func all_exist(names: Array, label: String) -> void:
	for key: Variant in names:
		check(arena.frames.has(String(key)), "%s: missing frame %s" % [label, key])


func catalog() -> void:
	all_exist(W.all_names(), "catalog")
	for aspect: StringName in LOADOUT:
		check(arena.frames.has(Hud.aspect_icon(aspect)) and arena.frames.has(Hud.aspect_icon(aspect, true, 0)), "icons of " + aspect)
		check(Hud.aspect_icon(aspect, true, 0) == "ui_aspect_%s_lit_1" % aspect, "lit icon name " + Hud.aspect_icon(aspect, true, 0))
	# trail families: pixel-exact for the 8 main directions, the nearest family rotated otherwise
	for case: Array in [[0.0, "h"], [PI * 0.5, "v"], [PI * 0.25, "d"], [-PI * 0.5, "v"], [PI, "h"], [PI * 0.75, "d"], [-PI * 0.25, "d"]]:
		var family: Dictionary = W.trail_family(float(case[0]))
		var quarter: float = float(family["rotation"]) / (PI * 0.5)
		check(absf(quarter - roundf(quarter)) < 0.001, "trail at %.2f rotates off the grid: %s" % [case[0], str(family)])
		if case[1] != "h":  # left/right may use h turned half or v turned a quarter
			check(family["family"] == case[1] or (case[1] == "v" and family["family"] == "h"), "trail family at %.2f: %s" % [case[0], str(family)])
	check(W.trail_family(0.0)["family"] == "h" and is_zero_approx(float(W.trail_family(0.0)["rotation"])), "a rightward streak is the h art unrotated")
	check(W.trail_family(PI * 0.25)["family"] == "d" and is_zero_approx(float(W.trail_family(PI * 0.25)["rotation"])), "a down-right streak is the d art unrotated")
	var odd: Dictionary = W.trail_family(0.3)
	check(absf(float(odd["rotation"])) <= PI * 0.125 + 0.001, "an odd angle uses the nearest family: %s" % str(odd))
	var tiles: Array[Dictionary] = W.trail_tiles(40.0, "h")
	check(tiles.size() == 3 and is_equal_approx(float(tiles[2]["fraction"]), 0.5), "trail tiles over 40 px: %s" % str(tiles))
	# shockwave and stored glow numbers
	check(is_equal_approx(W.shockwave_scale(Tuning.STONE_WARD_RADIUS), Tuning.STONE_WARD_RADIUS / 64.0) and is_equal_approx(W.shockwave_radius(8, W.shockwave_scale(Tuning.STONE_WARD_RADIUS)), Tuning.STONE_WARD_RADIUS), "the last shockwave frame draws the core radius")
	check(W.store_level(0) == 0 and W.store_level(1) == 1 and W.store_level(20) == 1 and W.store_level(21) == 2 and W.store_level(40) == 2 and W.store_level(41) == 3 and W.store_level(60) == 3, "stored glow thirds")
	# the ward pose covers 60 ticks: raise from the first tick, drop ending on the last
	check(W.ward_pose(60) == ["raise", 1] and W.ward_pose(1) == ["drop", 3] and W.ward_pose(30)[0] == "hold", "ward pose timing")
	check(W.anchor_key(0, 120) == "" and W.anchor_key(W.sequence_length(W.PLACE_TICKS), 100) == "fx_echo_anchor_1" and W.anchor_key(110, 20) == "fx_echo_countdown_1" and W.anchor_key(119, 1) == "fx_echo_countdown_4" and W.anchor_key(150, 0).begins_with("fx_echo_anchor_"), "echo anchor/countdown keys")
	check(W.shield_phase(12) == 1 and W.shield_phase(8) == 2 and W.shield_phase(4) == 3 and W.shield_phase(3) == 4 and W.shield_phase(1) == 4, "shield phases")
	# the effect list is capped
	var effects: Array[Dictionary] = []
	for i: int in range(100):
		W.add(effects, {"kind": "echo_dust", "tick": i, "life": 10})
	check(effects.size() == W.MAX_LIVE and int(effects[0]["tick"]) == 100 - W.MAX_LIVE, "effect cap drops the oldest")


func hud() -> void:
	fixture()
	var rows: Array[Dictionary] = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	for i: int in range(3):
		check(rows[i]["aspect_id"] == LOADOUT[i] and rows[i]["icon"] == "ui_aspect_%s_1" % LOADOUT[i] and not rows[i]["running"], "idle row %d: %s" % [i, str(rows[i])])
	check(rows[0]["kind"] == Aspects.KIND_BUFF and rows[1]["kind"] == Aspects.KIND_SKILL and rows[2]["kind"] == Aspects.KIND_SKILL, "kinds")
	await save("hud_idle")
	press(1)
	press(2)
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(rows[0]["running"] and String(rows[0]["icon"]).begins_with("ui_aspect_sprint_lit_") and Hud.run_fraction(rows[0]) > 0.98, "sprint row running: %s" % str(rows[0]))
	check(rows[1]["running"] and String(rows[1]["icon"]).begins_with("ui_aspect_echo_step_lit_") and Hud.run_fraction(rows[1]) > 0.98 and Hud.cooldown_fraction(rows[1]) > 0.98, "echo row running: %s" % str(rows[1]))
	check(rows[0]["aspect_id"] in Hud.RUN_SECONDS_ASPECTS and rows[1]["aspect_id"] in Hud.RUN_SECONDS_ASPECTS and rows[2]["aspect_id"] in Hud.RUN_SECONDS_ASPECTS, "the three show the seconds they still run")
	for i: int in range(60):
		step()
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(absf(Hud.run_fraction(rows[1]) - float(rows[1]["ticks_left"]) / Tuning.ECHO_STEP_DELAY_TICKS) < 0.001 and Hud.run_fraction(rows[1]) < 0.55, "echo run ring follows the countdown: %s" % str(rows[1]))
	check(arena.frames.has(rows[0]["icon"]) and arena.frames.has(rows[1]["icon"]), "lit icon frames")
	await save("hud_sprint_echo")
	arena.hud.hint_slot_override = 0
	await save("tooltip_sprint")
	arena.hud.hint_slot_override = 1
	await save("tooltip_echo")
	arena.hud.hint_slot_override = 2
	await save("tooltip_ward")
	arena.hud.hint_slot_override = -1
	for i: int in range(Tuning.SPRINT_DURATION_TICKS):
		step()
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(not rows[0]["running"] and rows[0]["icon"] == "ui_aspect_sprint_1" and int(rows[0]["cooldown"]) > 0, "sprint row after: %s" % str(rows[0]))
	check(not rows[1]["running"] and rows[1]["icon"] == "ui_aspect_echo_step_1", "echo row after the recall: %s" % str(rows[1]))
	press(3)
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(rows[2]["running"] and String(rows[2]["icon"]).begins_with("ui_aspect_stone_ward_lit_") and Hud.run_fraction(rows[2]) > 0.98 and Hud.stored_fraction(rows[2]) == 0.0, "ward row: %s" % str(rows[2]))
	# the stored ring and the faster rune loop follow ward_stored
	var fake: Dictionary = rows[2].duplicate()
	fake["stored"] = 30
	check(is_equal_approx(Hud.stored_fraction(fake), 0.5) and Hud.lit_ticks(Aspects.STONE_WARD, 60) < Hud.lit_ticks(Aspects.STONE_WARD, 0), "stored ring / pulse rate")
	await save("hud_ward")


func sprint() -> void:
	fixture()
	press(1)
	check(GameEvent.SPRINT_STARTED in types() and "sprint_start" in kinds(), "no sprint start")
	check(hero().sprint_ticks_left > 0 and is_equal_approx(hero().move_speed_mult, Tuning.SPRINT_MOVE_SPEED_MULT), "sprint not running")
	all_exist(keys(arena.ward_echo_front_plan()), "sprint start")
	var walk_frames: Array[String] = []
	var aura_misses: Array[String] = []
	var max_trail: int = 0
	var saved: bool = false
	for i: int in range(60):
		move(Vector2.RIGHT if i < 40 else Vector2.LEFT)
		walk_frames.append(chosen())
		max_trail = maxi(max_trail, arena.sprint_trail.size())
		var over: Array = overlays()
		all_exist(over, "sprint overlay")
		if not over.any(func(k: String) -> bool: return k.begins_with("fx_sprint_aura_")):
			aura_misses.append(chosen())
		check(over.has(W.wind_key(arena.snapshot.tick)), "no wind while sprinting (tick %d)" % i)
		var behind: Array = back()
		all_exist(behind, "sprint back")
		check(behind.has(W.lines_key(arena.snapshot.tick)) and behind.has(W.dust_key(arena.snapshot.tick)), "no speed lines / dust while moving")
		if i == 30:
			var afters: Array = behind.filter(func(k: String) -> bool: return k.begins_with("fx_sprint_after_"))
			check(afters.size() == 3, "three afterimages at full speed: %s" % str(afters))
			for item: Dictionary in arena.sprint_back_plan(hero(), hero().position.round(), arena.facing_left):
				if String(item["key"]).begins_with("fx_sprint_after_"):
					check(Vector2(item["at"]).x < hero().position.x, "an afterimage is not behind the hero")
		if i == 30 and not saved:
			saved = true
			await save("sprint_run_right")
		if i == 52:
			await save("sprint_run_left")
	check(aura_misses.is_empty(), "frames without an aura: %s" % str(aura_misses.slice(0, 4)))
	check(max_trail <= W.TRAIL_CAP and max_trail == W.TRAIL_CAP, "afterimage buffer cap: %d" % max_trail)
	# the walk cycle runs twice as fast (one frame per 5 ticks normally, so here a new frame about every 2-3 ticks)
	var changes: int = 0
	for i: int in range(1, 20):
		if walk_frames[i] != walk_frames[i - 1]:
			changes += 1
	check(changes >= 7, "the sprint walk cycle is not faster (%d frame changes in 19 ticks)" % changes)
	# standing still: no lines, dust or wind, the aura stays
	step()
	step()
	check(not back().any(func(k: String) -> bool: return k.begins_with("fx_sprint_lines_") or k.begins_with("fx_sprint_dust_")), "lines/dust while standing")
	check(overlays().any(func(k: String) -> bool: return k.begins_with("fx_sprint_aura_")), "no aura while standing")
	while hero().sprint_ticks_left > 0:
		step()
	check("sprint_end" in kinds() and arena.sprint_trail.is_empty(), "the end burst / trail cleanup is missing")
	check(not overlays().any(func(k: String) -> bool: return k.begins_with("fx_sprint_")) and back().is_empty(), "sprint look after the end")
	all_exist(keys(arena.ward_echo_front_plan()), "sprint end")
	step()
	await save("sprint_end")
	check(arena.missing_frames.is_empty(), "sprint missing frames: %s" % str(arena.missing_frames.keys()))


func echo() -> void:
	fixture()
	press(1)  # sprint first, so there are afterimage samples for the recall to clear
	press(2)
	var placed: Snapshots.EchoSnapshot = arena.snapshot.echoes[0] if not arena.snapshot.echoes.is_empty() else null
	check(placed != null and GameEvent.ECHO_PLACED in types(), "no echo placed")
	if placed == null:
		return
	var anchor: Vector2 = placed.position.round()
	check("echo_place" in kinds() and "echo_dust" in kinds(), "no placement burst")
	check(arena.echo_drawables().is_empty(), "the anchor shows during the placement burst")
	all_exist(keys(arena.ward_echo_front_plan()), "echo place")
	step()
	step()
	await save("echo_place")
	move(Vector2.RIGHT, 40)
	var drawables: Array[Dictionary] = arena.echo_drawables()
	check(drawables.size() == 1 and String(drawables[0]["name"]).begins_with("fx_echo_anchor_") and Vector2(drawables[0]["at"]).round() == anchor, "the anchor: %s" % str(drawables))
	await save("echo_anchor")
	while not arena.snapshot.echoes.is_empty() and arena.snapshot.echoes[0].ticks_left > W.COUNTDOWN_TICKS:
		move(Vector2.RIGHT)
	move(Vector2.RIGHT)
	drawables = arena.echo_drawables()
	check(drawables.size() == 1 and String(drawables[0]["name"]).begins_with("fx_echo_countdown_"), "no countdown: %s" % str(drawables))
	await save("echo_countdown")
	check(not arena.sprint_trail.is_empty(), "fixture: no afterimage samples before the recall")
	var before: Vector2 = hero().position
	var smooth: bool = arena.camera.position_smoothing_enabled
	while not GameEvent.ECHO_RECALL in types() and arena.snapshot.tick < placed.placed_tick + Tuning.ECHO_STEP_DELAY_TICKS + 5:
		move(Vector2.RIGHT)
	check(GameEvent.ECHO_RECALL in types(), "no recall")
	check(hero().position.distance_to(anchor) < 2.0 and before.distance_to(anchor) > 60.0, "the hero did not jump back")
	check(arena.camera_focus == hero().position.round() and arena.camera.position == arena.view_origin + Arena.VIEW_SIZE * 0.5 and not smooth, "the camera did not snap with the teleport")
	check(arena.sprint_trail.is_empty() and arena.dash_ghosts.is_empty() and arena.previous_player_position == hero().position, "smear buffers survived the teleport")
	check(arena.echo_drawables().is_empty(), "the anchor outlived the recall")
	check("echo_vanish" in kinds() and "echo_trail" in kinds() and "echo_arrive" in kinds(), "recall effects: %s" % str(kinds()))
	check(arena.hero_hidden(), "the hero shows on arrive frame 1")
	var front: Array[Dictionary] = arena.ward_echo_front_plan()
	all_exist(keys(front), "recall")
	var trail: Array = front.filter(func(item: Dictionary) -> bool: return bool(item.get("trail", false)))
	check(trail.size() == 1 and Vector2(trail[0]["to"]).distance_to(anchor + W.CHEST) < 2.0, "the trail does not end at the echo: %s" % str(trail))
	await save("echo_recall")
	check(hero().echo_invuln_ticks == Tuning.ECHO_STEP_INVULN_TICKS and hero().invulnerable, "no i-frames on arrival")
	check(overlays().any(func(k: String) -> bool: return k.begins_with("fx_echo_shield_") or k.begins_with("fx_echo_bubble_")), "no shield on arrival: %s" % str(overlays()))
	step()
	await save("echo_trail")
	step()
	step()
	check(not arena.hero_hidden(), "the hero stays hidden after arrive frame 1")
	await save("echo_arrive")
	for i: int in range(Tuning.ECHO_STEP_INVULN_TICKS):
		if hero().echo_invuln_ticks > 0:
			all_exist(overlays(), "shield")
			check(overlays().any(func(k: String) -> bool: return k.begins_with("fx_echo_shield_") or k.begins_with("fx_echo_bubble_")), "no shield with %d i-frames left" % hero().echo_invuln_ticks)
		step()
	check(not overlays().any(func(k: String) -> bool: return k.begins_with("fx_echo_")), "shield after the i-frames")
	# a recall from left of the anchor: the trail runs the other way and stays on the grid
	fixture(Tuning.WEAPON_DUAL_DAGGER)
	press(2)
	move(Vector2(-1, -1).normalized(), 60)
	while not GameEvent.ECHO_RECALL in types() and arena.snapshot.tick < 400:
		step()
	var diagonal: Array = arena.ward_echo_front_plan().filter(func(item: Dictionary) -> bool: return bool(item.get("trail", false)))
	check(diagonal.size() == 1 and String(diagonal[0]["family"]) == "d", "a diagonal recall uses the d tiles: %s" % str(diagonal))
	step()
	await save("echo_recall_diagonal")
	# the hero dies with an echo standing: it is cleared and fades
	fixture()
	press(2)
	move(Vector2.RIGHT, 30)
	check(arena.echo_drawables().size() == 1, "fixture: no anchor")
	arena.core.player.die(arena.core.tick, [])
	step()
	check(GameEvent.ECHO_EXPIRED in types() and arena.snapshot.echoes.is_empty() and arena.echo_drawables().is_empty(), "the anchor outlived the death")
	check("echo_vanish" in kinds(), "no fade at the expired echo")
	# restart clears everything
	arena._restart()
	check(arena.wes_fx.is_empty() and arena.sprint_trail.is_empty() and not arena.hero_hidden() and arena.echo_drawables().is_empty(), "restart left Echo Step effects")
	check(arena.missing_frames.is_empty(), "echo missing frames: %s" % str(arena.missing_frames.keys()))


## A Stone Ward next to the boss with a scripted gold slam: block, absorb, stored glow, the release shockwave hitting the
## boss as a skill hit (no swing sound), the cracks decal; for `weapon`.
func ward(weapon: StringName) -> void:
	var label: String = String(weapon)
	fixture(weapon, Vector2(420, 250), Vector2(462, 250))
	arena.core.boss.next_attack_override = &"gold_slam"
	arena.core.boss.cooldown = 1
	step()
	var tell: Snapshots.TelegraphSnapshot = arena.snapshot.telegraphs[0] if not arena.snapshot.telegraphs.is_empty() else null
	check(tell != null, "%s: no scripted slam" % label)
	if tell == null:
		return
	while arena.snapshot.tick < tell.hit_tick - 20:
		step()
	press(3, Vector2.RIGHT)
	check(hero().state == PlayerState.STATE_WARD and GameEvent.WARD_RAISED in types(), "%s: the ward did not raise" % label)
	check(chosen().contains("_ward_raise_right_1") and chosen().begins_with(ArenaAnimation.hero_set(hero())), "%s: raise frame %s" % [label, chosen()])
	check(not arena.facing_left, "%s: the ward faces the boss" % label)
	var raised: int = arena.snapshot.tick
	var blocked: bool = false
	var levels: Dictionary = {}
	var poses: Dictionary = {}
	var swings: int = int(arena.combat_audio.played.get("swing", 0))
	var released: bool = false
	var hit_seen: bool = false
	while arena.snapshot.tick < raised + Tuning.STONE_WARD_DURATION_TICKS + 2:
		step()
		if hero().state == PlayerState.STATE_WARD:
			poses[chosen()] = true
			var over: Array = overlays()
			all_exist(over, label + " ward overlay")
			if W.barrier_visible(hero().ward_ticks_left):
				check(over.any(func(k: String) -> bool: return k.begins_with("fx_ward_barrier_") or k.begins_with("fx_ward_absorb_")), "%s: no barrier at %d ticks left" % [label, hero().ward_ticks_left])
			if hero().ward_stored > 0 and W.barrier_visible(hero().ward_ticks_left):  # the glow sits on the barrier
				levels[W.store_level(hero().ward_stored)] = true
				check(over.any(func(k: String) -> bool: return k.begins_with("fx_ward_store_")), "%s: no stored glow" % label)
		if GameEvent.WARD_BLOCKED in types():
			blocked = true
			check("ward_block" in kinds() and overlays().any(func(k: String) -> bool: return k.begins_with("fx_ward_absorb_")), "%s: no block spark / absorb" % label)
			check(not arena.hurt_blink, "%s: a blocked hit blinked the hero" % label)
			all_exist(keys(arena.ward_echo_front_plan()), label + " block")
			step()
			await save("ward_block_" + label)
		if GameEvent.WARD_RELEASED in types():
			released = true
			var event: GameEvent = arena.core.last_events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.WARD_RELEASED)[0]
			hit_seen = bool(event.data["hit"])
			var ground: Array[Dictionary] = arena.ward_echo_ground_plan()
			all_exist(keys(ground), label + " release")
			var wave: Array = ground.filter(func(item: Dictionary) -> bool: return String(item["key"]).begins_with("fx_ward_shockwave_"))
			check(wave.size() == 1 and is_equal_approx(float(wave[0]["scale"]), float(event.data["radius"]) / 64.0) and Vector2(wave[0]["at"]) == Vector2(event.data["position"]).round(), "%s: shockwave %s" % [label, str(wave)])
			check(ground.any(func(item: Dictionary) -> bool: return String(item["key"]).begins_with("fx_ward_cracks_")), "%s: no cracks" % label)
			if hit_seen:
				check(arena.hit_bursts.any(func(b: Dictionary) -> bool: return b["skill_id"] == &"stone_ward" and bool(b["finisher"])), "%s: the release hit has no heavy burst" % label)
			check(int(arena.combat_audio.played.get("swing", 0)) == swings, "%s: the ward played a swing sound" % label)
			for i: int in range(6):
				step()
			await save("ward_shockwave_" + label)
			# the last frame of the ring reaches the core's radius
			while arena.ward_echo_ground_plan().any(func(item: Dictionary) -> bool: return String(item["key"]).begins_with("fx_ward_shockwave_") and String(item["key"]) != "fx_ward_shockwave_8"):
				step()
			var last: Array = arena.ward_echo_ground_plan().filter(func(item: Dictionary) -> bool: return String(item["key"]) == "fx_ward_shockwave_8")
			check(last.size() == 1 and is_equal_approx(float(last[0]["radius"]), Tuning.STONE_WARD_RADIUS), "%s: the full ring is not %d px" % [label, Tuning.STONE_WARD_RADIUS])
			break
		if hero().state == PlayerState.STATE_WARD and hero().ward_ticks_left == 30 and blocked:
			await save("ward_hold_" + label)
	check(blocked and not levels.is_empty(), "%s: nothing blocked / stored (%s)" % [label, str(levels)])
	check(released and hit_seen, "%s: the release did not hit the boss" % label)
	var prefix: String = ArenaAnimation.hero_set(hero())
	for pose: String in ArenaAnimation.WARD_POSES:
		for n: int in range(1, int(ArenaAnimation.WARD_POSES[pose]) + 1):
			check(poses.has(ArenaAnimation.hero_frame(prefix, pose, n)), "%s: never drew %s" % [label, ArenaAnimation.hero_frame(prefix, pose, n)])
	# the crack decal fades and the list empties
	for i: int in range(W.sequence_length(W.CRACKS_TICKS) + 2):
		step()
	check(arena.ward_echo_ground_plan().is_empty(), "%s: the decal never faded" % label)
	arena._restart()
	check(arena.wes_fx.is_empty() and arena.ward_absorb_tick < 0, "%s: restart left ward effects" % label)
	check(arena.missing_frames.is_empty(), "%s: missing frames: %s" % [label, str(arena.missing_frames.keys())])


## Capture only: the stored glow at all three levels (by blocking a scripted gold combo slam pair twice), raised in the
## open with the boss away, for a look at the barrier and glow.
func ward_glow_showcase() -> void:
	if not capture:
		return
	for level: int in [1, 2, 3]:
		fixture(Tuning.WEAPON_BLACK_KATANA, Vector2(300, 250), Vector2(560, 250))
		press(3, Vector2.LEFT)
		for i: int in range(24):
			step()
		arena.core.player.ward_stored = level * 20
		step()
		await save("ward_glow_level%d" % level)


func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	Bindings.register()
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	catalog()
	await hud()
	await sprint()
	await echo()
	for weapon: StringName in Weapons.IDS:
		await ward(weapon)
	await ward_glow_showcase()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("WARD ECHO SPRINT FAIL: " + message)
	print("WARD ECHO SPRINT PRESENTATION SMOKE OK" if failures.is_empty() else "WARD ECHO SPRINT PRESENTATION SMOKE FAILED")
	quit(0 if failures.is_empty() else 1)
