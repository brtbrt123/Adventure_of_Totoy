extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_aspects_presentation.gd
## Equippable aspects, Spirit Lantern and Phantom Cut in presentation (2026-10-21), through the real arena loop:
## every requested fx/icon frame exists (incl. the glow overlay of every covered hero frame of the three weapons); the
## HUD slots draw from hud.aspect_slots (icons, costs, cooldown and run rings, the burning lantern icon, Breaking Edge's
## retaliation flag follows its slot); the lantern is placed, opens its pool, pulses (motes and sparks only with the
## hero inside), is replaced, fades on expiry and leaves nothing after a restart; Phantom Cut starts, glows over the hero
## frame, shows the marker while echoes are pending, draws ghost + arc + spark on each echo for the katana, dagger and
## scythe (the echo's attack_hit triggers no hit burst, hit sound or shake of a real swing) and ends; effects are capped.
## With `-- --capture` in a window it saves art/build/arena_aspect_*.png for a visual check (delete them afterwards).
const Arena := preload("res://presentation/arena/arena.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const AspectEffects := preload("res://presentation/arena/aspect_effects.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Aspects := preload("res://core/aspects.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")

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


func press_skill(slot: int) -> void:
	var frame: InputFrame = InputFrame.new()
	frame.skill_pressed = slot
	frame.aim = Vector2.RIGHT
	step(frame)


func swing() -> void:
	var frame: InputFrame = InputFrame.new()
	frame.attack_pressed = true
	frame.aim = Vector2.RIGHT
	step(frame)


func fixture(aspects: Array, weapon: StringName = Tuning.WEAPON_BLACK_KATANA, gap: float = 28.0) -> void:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = Vector2(420, 250)
	arena.core.player.position = Vector2(420 - gap, 250)
	arena.core.player.edge = Tuning.EDGE_MAX
	arena.core.player.weapon_id = weapon
	check(arena.core.player.set_equipped_aspects(aspects), "fixture loadout refused: %s" % str(aspects))
	observe()


func save(label: String) -> void:
	if not capture:
		return
	arena.queue_redraw()
	arena.hud.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_aspect_" + label + ".png") == OK, "capture " + label)


func kinds() -> Array:
	return arena.aspect_fx.map(func(e: Dictionary) -> String: return String(e["kind"]))


func types() -> Array:
	return arena.core.last_events.map(func(e: GameEvent) -> StringName: return e.type)


func catalog() -> void:
	for key: String in AspectEffects.all_names():
		check(arena.frames.has(key), "missing aspect frame " + key)
	for aspect: StringName in Aspects.ALL:
		check(arena.frames.has(Hud.aspect_icon(aspect)), "missing aspect icon " + Hud.aspect_icon(aspect))
	# the glow overlay exists for every covered hero frame of the three weapons, and nothing for victory / coil / lightning
	var covered: int = 0
	for prefix: String in [ArenaAnimation.SET_KATANA, ArenaAnimation.SET_DAGGER, ArenaAnimation.SET_SCYTHE]:
		for name_key: String in ArenaAnimation.hero_names(prefix):
			var victory: bool = name_key.contains("_victory_")
			for phase: int in range(1, 7):
				var glow: String = "fx_phantom_glow_%s_%d" % [name_key, phase]
				check(arena.frames.has(glow) != victory, "glow coverage wrong for " + glow)
				if arena.frames.has(glow):
					covered += 1
					# cropped to the glow: it must lie inside the hero frame's rectangle when both are placed by anchor
					var hero: Rect2 = ArenaAnimation.destination(Vector2(100, 100), arena.frames[name_key], false)
					var over: Rect2 = ArenaAnimation.destination(Vector2(100, 100), arena.frames[glow], false)
					check(hero.grow(1).encloses(over), "glow %s sticks out of its hero frame (%s vs %s)" % [glow, over, hero])
	check(covered == 792, "glow overlays covered: %d" % covered)
	check(AspectEffects.glow_phase(0) == 1 and AspectEffects.glow_phase(5) == 2 and AspectEffects.glow_phase(29) == 6 and AspectEffects.glow_phase(30) == 1, "glow phase rule")
	check(AspectEffects.weapon_key(Tuning.WEAPON_DUAL_DAGGER) == "dagger" and AspectEffects.weapon_key(Tuning.WEAPON_CHAIN_SCYTHE) == "scythe" and AspectEffects.weapon_key(Tuning.WEAPON_BLACK_KATANA) == "katana", "weapon keys")
	# the effect list is capped
	var effects: Array[Dictionary] = []
	for i: int in range(100):
		AspectEffects.add(effects, {"kind": "echo", "tick": i, "life": 10})
	check(effects.size() == AspectEffects.MAX_LIVE and int(effects[0]["tick"]) == 100 - AspectEffects.MAX_LIVE, "effect cap drops the oldest")


func hud_slots() -> void:
	fixture(Aspects.DEFAULT_EQUIPPED)
	var rows: Array[Dictionary] = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(rows.size() == 3, "three rows")
	for i: int in range(3):
		check(rows[i]["aspect_id"] == Aspects.DEFAULT_EQUIPPED[i] and rows[i]["icon"] == "ui_aspect_%s_1" % Aspects.DEFAULT_EQUIPPED[i] and rows[i]["key"] == ["Z", "X", "C"][i], "default row %d: %s" % [i, str(rows[i])])
	check(rows[0]["needs_retaliation"] and not rows[1]["needs_retaliation"], "Breaking Edge flag in slot 1")
	await save("hud_default")
	fixture([&"spirit_lantern", &"phantom_cut", &"breaking_edge"])
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(rows[0]["name"] == "SPIRIT LANTERN" and rows[0]["cost"] == Tuning.SPIRIT_LANTERN_EDGE_COST and rows[0]["icon"] == "ui_aspect_spirit_lantern_1", "lantern row: %s" % str(rows[0]))
	check(rows[1]["name"] == "PHANTOM CUT" and rows[1]["cost"] == Tuning.PHANTOM_CUT_EDGE_COST and rows[1]["kind"] == Aspects.KIND_BUFF, "phantom row: %s" % str(rows[1]))
	check(rows[2]["needs_retaliation"] and rows[2]["key"] == "C", "the retaliation flag follows Breaking Edge to C")
	# Phantom Cut (X): the run ring with the seconds left, plus the cooldown ring
	press_skill(2)
	check(GameEvent.PHANTOM_CUT_STARTED in types(), "Phantom Cut did not start from X")
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(rows[1]["running"] and Hud.run_fraction(rows[1]) > 0.95 and Hud.cooldown_fraction(rows[1]) > 0.95, "phantom rings: %s" % str(rows[1]))
	for i: int in range(90):
		step()
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(absf(Hud.run_fraction(rows[1]) - float(rows[1]["ticks_left"]) / Tuning.PHANTOM_CUT_DURATION_TICKS) < 0.001 and Hud.run_fraction(rows[1]) < 0.75, "phantom run ring follows ticks_left")
	# the lantern (Z): the burning icon while it stands
	press_skill(1)
	for i: int in range(Tuning.SPIRIT_LANTERN_WINDUP_TICKS + 2):
		step()
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(rows[0]["running"] and String(rows[0]["icon"]).begins_with("ui_aspect_spirit_lantern_lit_") and Hud.run_fraction(rows[0]) > 0.9, "lantern HUD while it stands: %s" % str(rows[0]))
	check(arena.frames.has(rows[0]["icon"]), "lit icon frame")
	await save("hud_running")
	arena.hud.hint_slot_override = 1
	await save("tooltip_phantom")
	arena.hud.hint_slot_override = 0
	await save("tooltip_lantern")
	arena.hud.hint_slot_override = -1
	for i: int in range(Tuning.SPIRIT_LANTERN_DURATION_TICKS):
		step()
	rows = Hud.skill_rows(arena.snapshot.hud, arena.snapshot.tick)
	check(not rows[0]["running"] and rows[0]["icon"] == "ui_aspect_spirit_lantern_1" and int(rows[0]["cooldown"]) > 0, "lantern HUD after it went out: %s" % str(rows[0]))
	await save("hud_cooldowns")


func lantern() -> void:
	fixture([&"spirit_lantern", &"gale_cut", &"moon_cleave"], Tuning.WEAPON_BLACK_KATANA, 60.0)
	press_skill(1)
	var placed_tick: int = -1
	for i: int in range(Tuning.SPIRIT_LANTERN_WINDUP_TICKS + 1):
		if GameEvent.LANTERN_PLACED in types():
			placed_tick = arena.snapshot.tick
			break
		step()
	check(placed_tick > 0 and arena.snapshot.lanterns.size() == 1, "no lantern placed")
	check(arena.snapshot.player.skill_id == &"spirit_lantern" and arena.selected_frames.get(arena.snapshot.player.id, "") != "", "no placing pose")
	var drawables: Array[Dictionary] = arena.lantern_drawables()
	check(drawables.size() == 1 and drawables[0]["name"] == "fx_lantern_place_1", "placement frame: %s" % str(drawables))
	check(Vector2(drawables[0]["at"]).round() == arena.snapshot.lanterns[0].position.round() and Vector2(drawables[0]["at"]).y > arena.snapshot.lanterns[0].position.round().y, "the lantern stands at the snapshot position, sorted in front of the hero's feet")
	for i: int in range(5):
		step()
	await save("lantern_place")
	check(AspectEffects.pool_key(arena.snapshot.tick - placed_tick).begins_with("fx_lantern_pool_open_"), "the pool opens with the placement")
	for i: int in range(30):
		step()
	check(String(arena.lantern_drawables()[0]["name"]).begins_with("fx_lantern_idle_") and AspectEffects.pool_key(arena.snapshot.tick - placed_tick).begins_with("fx_lantern_pool_idle_"), "the burning loop and the pool loop")
	await save("lantern_idle")
	# pulse 1 with the hero inside: pool ring, motes and sparks; the lantern flares
	arena.core.player.hp = 50
	while not GameEvent.LANTERN_PULSE in types():
		step()
	check(arena.core.last_events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.LANTERN_PULSE)[0].data["player_inside"], "fixture: the hero is not inside")
	check("pool_pulse" in kinds() and "motes" in kinds() and "spark" in kinds(), "pulse effects inside: %s" % str(kinds()))
	for i: int in range(2):
		step()
	check(String(arena.lantern_drawables()[0]["name"]).begins_with("fx_lantern_pulse_"), "the lantern does not flare on a pulse")
	for i: int in range(4):
		step()
	await save("lantern_pulse_inside")
	# pulse 2 with the hero outside: the ring only
	arena.core.player.position = arena.snapshot.lanterns[0].position + Vector2(-Tuning.SPIRIT_LANTERN_RADIUS - 14, 0)
	observe()
	for i: int in range(40):
		step()
	arena.aspect_fx.clear()
	while not GameEvent.LANTERN_PULSE in types():
		step()
	check("pool_pulse" in kinds() and not "motes" in kinds() and not "spark" in kinds(), "pulse effects outside: %s" % str(kinds()))
	for i: int in range(6):
		step()
	await save("lantern_pulse_outside")
	# replace: a second lantern (cooldown cleared by the fixture) fades the first one
	arena.core.player.aspect_cooldowns[&"spirit_lantern"] = 0
	press_skill(1)
	var replaced: bool = false
	for i: int in range(Tuning.SPIRIT_LANTERN_WINDUP_TICKS + 1):
		step()
		for event: GameEvent in arena.core.last_events:
			replaced = replaced or (event.type == GameEvent.LANTERN_EXPIRED and event.data["reason"] == &"replaced")
		if replaced:
			break
	check(replaced and "fade" in kinds() and arena.snapshot.lanterns.size() == 1, "replacing did not fade the old lantern: %s" % str(kinds()))
	var names: Array = arena.lantern_drawables().map(func(d: Dictionary) -> String: return String(d["name"]))
	check(names.has("fx_lantern_place_1") and names.any(func(n: String) -> bool: return n.begins_with("fx_lantern_fade_")), "new lantern and fading old one: %s" % str(names))
	for i: int in range(8):
		step()
	await save("lantern_replaced")
	# expiry: fade, then nothing
	var expired: bool = false
	for i: int in range(Tuning.SPIRIT_LANTERN_DURATION_TICKS + 2):
		step()
		expired = expired or GameEvent.LANTERN_EXPIRED in types()
		if expired:
			break
	check(expired and arena.snapshot.lanterns.is_empty() and "fade" in kinds(), "no fade on expiry")
	for i: int in range(6):
		step()
	await save("lantern_fade")
	for i: int in range(AspectEffects.sequence_length(AspectEffects.FADE_TICKS)):
		step()
	check(arena.lantern_drawables().is_empty(), "the lantern is still drawn after its fade")
	# restart clears everything
	fixture([&"spirit_lantern", &"gale_cut", &"moon_cleave"])
	press_skill(1)
	for i: int in range(Tuning.SPIRIT_LANTERN_WINDUP_TICKS + 70):
		step()
	check(not arena.lantern_drawables().is_empty(), "fixture: no lantern before restart")
	arena._restart()
	observe()
	check(arena.aspect_fx.is_empty() and arena.lantern_drawables().is_empty() and arena.snapshot.lanterns.is_empty(), "lantern drawing survives a restart")
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## Phantom Cut through the loop for one weapon: start burst, glow on every covered frame, marker while echoes are
## pending, ghost/arc/spark per echo (frames exist), the echo hit is not a real swing hit, end fade.
func phantom(weapon: StringName) -> void:
	var label: String = AspectEffects.weapon_key(weapon)
	fixture([&"breaking_edge", &"phantom_cut", &"moon_cleave"], weapon)
	press_skill(2)
	check(arena.snapshot.player.phantom_ticks_left > 0 and "phantom_start" in kinds(), "%s: no start" % label)
	for i: int in range(3):
		step()
	await save("phantom_start_" + label)
	if capture:
		await glow_showcase(label)
	var echoes: int = 0
	var glows: int = 0
	var glow_misses: Array[String] = []
	var marker_seen: bool = false
	var echo_saved: bool = false
	var glow_saved: bool = false
	var ticks: int = 0
	while arena.snapshot.player.phantom_ticks_left > 0 and ticks < Tuning.PHANTOM_CUT_DURATION_TICKS + 5:
		var hero: Object = arena.snapshot.player
		var bursts: int = arena.hit_bursts.size()
		var armor_hits: int = int(arena.combat_audio.played.get("armor_hit", 0)) + int(arena.combat_audio.played.get("counter_hit", 0))
		var shake: int = arena.shake_left
		var flash_before: int = int(arena.flashes.get(arena.snapshot.entities[0].id, 0))
		if ticks % 6 == 0 and ticks < 200:
			swing()
		else:
			step()
		ticks += 1
		hero = arena.snapshot.player
		var chosen: String = String(arena.selected_frames.get(hero.id, ""))
		var key: String = arena.phantom_glow_key(hero, chosen)
		if key != "":
			glows += 1
			if hero.state == &"attack_active" and not glow_saved and ticks > 20:
				glow_saved = true
				await save("phantom_glow_" + label)
		elif hero.phantom_ticks_left > 0 and not chosen.contains("_victory_") and not chosen.contains("_coil_"):
			glow_misses.append(chosen)
		if hero.phantom_pending_echoes > 0:
			marker_seen = true
			check(arena.frames.has(AspectEffects.marker_key(arena.snapshot.tick)), "marker frame")
		var echo_events: Array = arena.core.last_events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.PHANTOM_ECHO)
		var real_hits: Array = arena.core.last_events.filter(func(e: GameEvent) -> bool: return e.type == GameEvent.ATTACK_HIT and not bool(e.data.get("echo", false)))
		if not echo_events.is_empty():
			echoes += 1
			var effect: Dictionary = arena.aspect_fx.filter(func(e: Dictionary) -> bool: return e["kind"] == "echo")[-1]
			check(effect["weapon"] == label and int(effect["swing"]) == int(echo_events[0].data["swing_combo_index"]), "%s: echo effect %s" % [label, str(effect)])
			for n: int in range(1, 5):
				check(arena.frames.has(AspectEffects.ghost_key(label, int(effect["swing"]), n)) and arena.frames.has(AspectEffects.arc_key(label, int(effect["swing"]), n)), "%s: ghost/arc frames swing %d" % [label, int(effect["swing"])])
			check(Vector2(effect["at"]).distance_to(hero.position.round()) <= AspectEffects.GHOST_OFFSET + 1.0, "%s: ghost not 8 px ahead" % label)
			check("echo_spark" in kinds(), "%s: no echo spark" % label)
			if real_hits.is_empty():
				check(arena.hit_bursts.size() == bursts, "%s: an echo made a hit burst" % label)
				check(int(arena.combat_audio.played.get("armor_hit", 0)) + int(arena.combat_audio.played.get("counter_hit", 0)) == armor_hits, "%s: an echo played the hit sound" % label)
				check(arena.shake_left <= maxi(0, shake - 1), "%s: an echo shook the screen" % label)
				check(int(arena.flashes.get(arena.snapshot.entities[0].id, 0)) <= maxi(flash_before - 1, AspectEffects.ECHO_FLASH_TICKS), "%s: an echo flashed like a real hit (%d)" % [label, int(arena.flashes.get(arena.snapshot.entities[0].id, 0))])
				if not echo_saved:
					echo_saved = true
					step()
					step()
					await save("phantom_echo_" + label)
	check(echoes >= 3, "%s: only %d echoes" % [label, echoes])
	check(glows > 100, "%s: glow drawn on %d ticks" % [label, glows])
	check(glow_misses.is_empty(), "%s: hero frames without glow: %s" % [label, str(glow_misses.slice(0, 5))])
	check(marker_seen, "%s: no echo marker" % label)
	check("phantom_end" in kinds() or GameEvent.PHANTOM_CUT_ENDED in types(), "%s: no end effect" % label)
	check(arena.phantom_glow_key(arena.snapshot.player, String(arena.selected_frames.get(arena.snapshot.player.id, ""))) == "", "%s: glow after the end" % label)
	step()
	await save("phantom_end_" + label)
	check(arena.missing_frames.is_empty(), "%s: missing frames: %s" % [label, str(arena.missing_frames.keys())])


## Capture only: the glow over walk and swing frames in open ground (no boss in front), facing right and left.
func glow_showcase(label: String) -> void:
	var home: Vector2 = arena.core.player.position
	arena.core.player.position = Vector2(300, 250)
	observe()
	for facing: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
		var walk: InputFrame = InputFrame.new()
		walk.move = facing
		for i: int in range(8):
			step(walk)
		await save("glow_walk_%s_%s" % [label, "left" if facing.x < 0 else "right"])
		var frame: InputFrame = InputFrame.new()
		frame.attack_pressed = true
		frame.aim = facing
		step(frame)
		while arena.snapshot.player.state != &"attack_active":
			step()
		await save("glow_swing_%s_%s" % [label, "left" if facing.x < 0 else "right"])
		for i: int in range(30):
			step()
	arena.core.boss.position = Vector2(420, 250)
	arena.core.player.position = home
	observe()


func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	Bindings.register()
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	catalog()
	await hud_slots()
	await lantern()
	for weapon: StringName in Weapons.IDS:
		await phantom(weapon)
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("ASPECTS FAIL: " + message)
	print("ASPECTS PRESENTATION SMOKE OK" if failures.is_empty() else "ASPECTS PRESENTATION SMOKE FAILED")
	quit(0 if failures.is_empty() else 1)
