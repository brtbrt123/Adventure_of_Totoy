extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_character_menu.gd
## The character menu (TAB) and the pop-ups restyled with the shared frame (approved 2026-10-21):
## open/close with TAB and ESC; no open during a cut-in or on the result screen; restart closes it; the world is frozen
## while it is open and resumes after; tabs (Q/E, clicks); selection movement; a description for every aspect, weapon
## and stat (with real numbers, every line fits the box); equipping from the inventory through the core (EQUIPPED, the
## drawn frame set changes; NOT NOW when the core refuses); the HUD has no weapon info box, no Q SWAP and no CD text;
## tooltip, result panels and menu draw with the shared frame. With `-- --capture` in a window it saves
## art/build/arena_menu_*.png for a visual check (delete them afterwards).
const Arena := preload("res://presentation/arena/arena.gd")
const Menu := preload("res://presentation/arena/character_menu.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const UiPanel := preload("res://presentation/arena/ui_panel.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")

var arena: Arena
var menu: Menu
var failures: Array[String] = []
var capture: bool = false
var titles: Array[String] = []


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


func fixture(gap: float = 60.0) -> void:
	arena._restart()
	arena.core.boss.cooldown = 100000
	arena.core.boss.position = Vector2(400, 240)
	arena.core.player.position = Vector2(400 - gap, 240)
	arena.core.player.edge = Tuning.EDGE_MAX
	observe()


## One arena physics frame with `action` just pressed (called directly, so is_action_just_pressed is true this frame).
func physics_with(action: String) -> void:
	await process_frame  # a fresh frame: one action press per frame, like a player
	if action != "":
		Input.action_press(action)
	arena._physics_process(1.0 / 60.0)
	if action != "":
		Input.action_release(action)


func menu_with(action: String) -> void:
	await process_frame
	Input.action_press(action)
	menu.poll_input()
	Input.action_release(action)


func save(label: String) -> void:
	if not capture:
		return
	arena.queue_redraw()
	arena.hud.queue_redraw()
	menu.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://art/build/arena_menu_" + label + ".png") == OK, "capture " + label)


func chosen() -> String:
	return String(arena.selected_frames.get(arena.snapshot.player.id, ""))


func open_close() -> void:
	fixture()
	check(InputMap.has_action("menu_toggle"), "no menu_toggle action")
	var tab_key: bool = false
	for event: InputEvent in InputMap.action_get_events("menu_toggle"):
		tab_key = tab_key or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_TAB)
		check(not (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_C), "C is Moon Cleave")
	check(tab_key, "TAB does not open the menu")
	var tick: int = arena.core.tick
	await physics_with("")
	check(arena.core.tick == tick + 1, "the arena steps normally when the menu is closed")
	tick = arena.core.tick
	await physics_with("menu_toggle")
	check(menu.is_open and menu.visible, "TAB did not open the menu")
	check(arena.core.tick == tick, "opening stepped the core")
	check(menu.tab == Menu.TAB_STATS, "the menu opens on STATS")
	for i: int in range(30):
		await physics_with("")
	check(arena.core.tick == tick, "the world is not frozen while the menu is open (%d ticks)" % (arena.core.tick - tick))
	# attacks and skills pressed while the menu is open never reach the core
	for action: String in ["arena_attack", "arena_skill_2", "arena_dash", "arena_parry", "arena_weapon_active"]:
		await physics_with(action)
	check(arena.core.tick == tick and arena.snapshot.player.state == &"idle", "an input leaked through the open menu")
	await physics_with("menu_toggle")
	check(not menu.is_open and not menu.visible, "TAB did not close the menu")
	check(arena.core.tick == tick, "the closing frame stepped the core")
	await physics_with("")
	check(arena.core.tick == tick + 1, "the world does not resume after closing")
	# ESC closes it and does not go back to the title
	var went: Array[String] = []
	arena.change_scene = func(path: String) -> void: went.append(path)
	var was_persist: bool = arena.persist
	arena.persist = true
	await physics_with("menu_toggle")
	check(menu.is_open, "TAB did not reopen the menu")
	await physics_with("menu_back")
	check(not menu.is_open, "ESC did not close the menu")
	check(went.is_empty(), "ESC with the menu open went to the title")
	arena.persist = was_persist
	# restart closes it
	check(arena.open_menu(), "open_menu refused while playing")
	arena._restart()
	check(not menu.is_open, "restart did not close the menu")


func refusals() -> void:
	fixture()
	# during a cut-in
	arena._on_event(GameEvent.new(GameEvent.WEAPON_BUFF_STARTED, 5, {"entity_id": 1, "weapon_id": Tuning.WEAPON_BLACK_KATANA, "form": Weapons.FORM_BLACK_KATANA_BUFF, "duration": 600, "attack_speed_mult": 1.5, "damage_mult": 1.4, "move_speed_mult": 1.0}))
	if arena.cutin_playing():
		check(not arena.open_menu(), "the menu opened during a cut-in")
		await physics_with("menu_toggle")
		check(not menu.is_open, "TAB opened the menu during a cut-in")
	else:
		failures.append("the Black Form cut-in did not start (art missing?)")
	fixture()
	# on the result screen
	var events: Array[GameEvent] = []
	arena.core.player.take_damage(Tuning.PLAYER_MAX_HP, arena.core.tick, events, arena.core.boss.id)
	step()
	check(arena.snapshot.result == &"defeat", "fixture: no defeat")
	check(not arena.open_menu(), "the menu opened on the result screen")
	await physics_with("menu_toggle")
	check(not menu.is_open, "TAB opened the menu on the result screen")
	fixture()


func tabs_and_selection() -> void:
	fixture()
	check(arena.open_menu(), "open")
	await menu_with("menu_tab_next")
	check(menu.tab == Menu.TAB_INVENTORY, "E did not switch to INVENTORY")
	await menu_with("menu_tab_next")
	check(menu.tab == Menu.TAB_STATS, "E does not wrap")
	await menu_with("menu_tab_prev")
	check(menu.tab == Menu.TAB_INVENTORY, "Q did not switch the tab")
	menu.click(Menu.tab_rect(Menu.TAB_STATS).get_center())
	check(menu.tab == Menu.TAB_STATS, "a click on the STATS tab")
	menu.click(Menu.tab_rect(Menu.TAB_INVENTORY).get_center())
	check(menu.tab == Menu.TAB_INVENTORY, "a click on the INVENTORY tab")
	menu.set_tab(Menu.TAB_STATS)
	# STATS: nothing selected shows the hint; the first move selects the weapon; every item is reachable
	check(menu.description_key() == &"none", "an untouched STATS tab shows the hint")
	await menu_with("menu_down")
	check(menu.stats_selection == &"weapon", "the first move selects the weapon slot")
	var reached: Dictionary = {&"weapon": true}
	var frontier: Array[StringName] = [&"weapon"]
	while not frontier.is_empty():
		var key: StringName = frontier.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			menu.stats_selection = key
			menu.move_selection(dir)
			if not reached.has(menu.stats_selection):
				reached[menu.stats_selection] = true
				frontier.append(menu.stats_selection)
	for item: Dictionary in menu.stats_items():
		check(reached.has(item["key"]), "arrow keys never reach " + String(item["key"]))
	menu.stats_selection = &"weapon"
	menu.move_selection(Vector2i.DOWN)
	check(menu.stats_selection in Menu.ASPECT_KEYS, "down from the weapon goes to an Aspect: " + String(menu.stats_selection))
	menu.stats_selection = &"weapon"
	menu.move_selection(Vector2i.RIGHT)
	check(String(menu.stats_selection).begins_with("stat_"), "right from the weapon goes to the stat list: " + String(menu.stats_selection))
	menu.stats_selection = &"stat_health"
	menu.move_selection(Vector2i.DOWN)
	check(menu.stats_selection == &"stat_edge", "down the stat list")
	menu.click(Menu.aspect_rect(1).get_center())
	check(menu.stats_selection == &"gale_cut" and menu.description_key() == &"gale_cut", "a click selects an Aspect")
	# INVENTORY grid moves (clamped at the edges)
	menu.set_tab(Menu.TAB_INVENTORY)
	menu.inventory_selection = 0
	await menu_with("menu_right")
	check(menu.inventory_selection == 1, "right in the grid")
	await menu_with("menu_down")
	check(menu.inventory_selection == 7, "down in the grid")
	await menu_with("menu_left")
	await menu_with("menu_left")
	check(menu.inventory_selection == 6, "left clamps at the edge")
	await menu_with("menu_up")
	await menu_with("menu_up")
	check(menu.inventory_selection == 0, "up clamps at the edge")
	menu.hover_at(Menu.inventory_rect(2).get_center())
	check(menu.inventory_selection == 2 and menu.description_key() == Tuning.WEAPON_CHAIN_SCYTHE, "hovering a slot selects it")
	menu.hover_at(Menu.inventory_rect(10).get_center())
	check(menu.description_key() == &"empty", "an empty slot")
	arena.close_menu()


## Every hoverable thing has a description with real numbers, for every equipped weapon; every line fits.
func descriptions() -> void:
	var limit: float = Menu.DESC.size.x - 10.0
	for weapon: StringName in Weapons.IDS:
		fixture()
		arena.core.player.weapon_id = weapon
		observe()
		check(arena.open_menu(), "open")
		var all: Dictionary = Menu.descriptions(weapon)
		menu.set_tab(Menu.TAB_STATS)
		for item: Dictionary in menu.stats_items():
			menu.hover_at(Rect2(item["rect"]).get_center())
			check(menu.hover_key == item["key"], "hover misses %s (%s)" % [item["key"], weapon])
			var key: StringName = menu.description_key()
			check(all.has(key), "no description for %s (%s)" % [key, weapon])
		for key: StringName in all:
			var entry: Array = all[key]
			var lines: Array = entry[2]
			check(lines.size() == 3, "description %s has %d lines" % [key, lines.size()])
			for line: String in lines:
				check(Hud.text_width(line) <= limit, "%s (%s) line too wide (%.0f > %.0f): %s" % [key, weapon, Hud.text_width(line), limit, line])
			if not String(entry[0]).is_empty():
				check(not String(lines[2]).is_empty() and String(lines[2]).contains(" "), "description %s has no numbers line" % key)
				var title_w: float = Hud.text_width(entry[0], 1, Hud.menu_font(), 10)
				check(title_w + Hud.text_width(entry[1]) + 8.0 <= limit, "title and tag overlap: %s (%s)" % [key, weapon])
		# the weapon-dependent block follows the equipped weapon (header and the RMB row)
		var rows: Array[Array] = Menu.stat_rows(weapon)
		check(rows.size() == 13, "13 stat lines")
		check(rows[7][1] == Menu.WEAPON_NAMES[weapon], "the weapon header follows the equipped weapon")
		check(rows[12][2] == Menu.ACTIVE_KEYS[weapon], "the RMB row follows the equipped weapon")
		check(all[&"stat_damage"][1] == Menu.WEAPON_NAMES[weapon], "the damage description is the equipped weapon's")
		for row: Array in rows:
			if row[0] != "header":
				check(Hud.text_width(row[0]) + Hud.text_width(row[1]) + 8.0 < Menu.STAT_X1 - Menu.STAT_X0, "stat row too wide: %s %s" % [row[0], row[1]])
		menu.hover_at(Menu.WEAPON_SLOT.get_center())
		check(menu.description_key() == weapon, "the weapon slot describes the equipped weapon")
		check(String(all[weapon][1]).contains("EQUIPPED"), "the equipped weapon's tag says EQUIPPED")
		arena.close_menu()
	# real numbers: spot checks against the tuning (not invented)
	var d: Dictionary = Menu.descriptions(Tuning.WEAPON_BLACK_KATANA)
	check(String(d[&"gale_cut"][2][2]).begins_with("%d EDGE  CD %d S" % [int(Tuning.GALE_CUT_EDGE_COST), Tuning.GALE_CUT_COOLDOWN_TICKS / 60]), "Gale Cut numbers: " + String(d[&"gale_cut"][2][2]))
	check(String(d[Tuning.WEAPON_DUAL_DAGGER][2][2]).contains("CD %s S" % Menu.secs(Tuning.LIGHTNING_FORM_COOLDOWN_TICKS)), "dagger cooldown from the tuning")
	check(Menu.stat_rows(Tuning.WEAPON_BLACK_KATANA)[1][1] == str(Tuning.PLAYER_MAX_HP), "health from the tuning")
	check(Menu.secs(14) == "0.23" and Menu.secs(1800) == "30" and Menu.secs(750) == "12.5" and Menu.num(1.5) == "1.5" and Menu.num(50.0) == "50", "number formatting")


func equip() -> void:
	fixture()
	check(arena.open_menu(), "open")
	menu.set_tab(Menu.TAB_INVENTORY)
	menu.inventory_selection = 1
	var tick: int = arena.core.tick
	await menu_with("menu_accept")
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_DUAL_DAGGER, "ENTER on the dagger did not equip it")
	check(arena.core.tick == tick + 1, "an equip request is exactly one core step (%d)" % (arena.core.tick - tick))
	check(not menu.feedback.is_empty() and bool(menu.feedback["ok"]) and menu.card_lines(Tuning.WEAPON_DUAL_DAGGER)[0] == "EQUIPPED!", "no EQUIPPED feedback")
	check(chosen().begins_with("totoy_dagger_"), "the drawn frame set did not change: " + chosen())
	check(Menu.figure_frame(arena.snapshot.player.weapon_id).begins_with("totoy_dagger_idle"), "the STATS figure holds the dagger")
	check(menu.is_open, "equipping closed the menu")
	await save("equipped")
	# a second equip right away works (no swap lockout: the menu is paused anyway)
	menu.inventory_selection = 2
	menu.accept()
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE, "a second equip right away did not equip the scythe")
	check(bool(menu.feedback["ok"]), "no EQUIPPED feedback for the second equip: %s" % str(menu.feedback))
	# the equipped one: no core step, shown as equipped
	tick = arena.core.tick
	menu.inventory_selection = 2
	menu.accept()
	check(arena.core.tick == tick, "re-equipping the equipped weapon stepped the core")
	# a click equips too
	arena.close_menu()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS + 1):
		step()
	check(arena.open_menu(), "reopen")
	menu.click(Menu.tab_rect(Menu.TAB_INVENTORY).get_center())
	menu.click(Menu.inventory_rect(2).get_center())
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE and chosen().begins_with("totoy_scythe_"), "a click did not equip the scythe")
	arena.close_menu()
	# busy (mid-swing): NOT NOW, nothing changes
	fixture(30.0)
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	step(attack)
	check(arena.snapshot.player.state.begins_with("attack_"), "fixture: not swinging")
	check(arena.open_menu(), "the menu opens mid-swing")
	menu.set_tab(Menu.TAB_INVENTORY)
	menu.inventory_selection = 2
	await save("inventory_selection")
	menu.accept()
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_BLACK_KATANA, "equipped while busy")
	check(not bool(menu.feedback["ok"]) and menu.card_lines(Tuning.WEAPON_CHAIN_SCYTHE)[0] == "NOT NOW" and menu.feedback["reason"] == "TRY WHEN IDLE", "no NOT NOW (busy): %s" % str(menu.feedback))
	await save("not_now")
	arena.close_menu()
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## The HUD's weapon info box, Q SWAP hint and the CD text are gone; the cooldown is only on the icons.
func hud_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://presentation/arena/hud.gd")
	for gone: String in ["CD READY", "Q SWAP", "\"CD %d", "RMB %dE", "FORM OFF", "_draw_swap_hint", "swap_status"]:
		check(not source.contains(gone), "hud.gd still has " + gone)
	check(not arena.hud.has_method("swap_status") and not arena.hud.has_method("weapon_active_line"), "old HUD box helpers remain")
	fixture()
	for row: Dictionary in Hud.skill_rows(arena.snapshot.hud):
		check(not row.has("status"), "skill rows still carry a CD status text")
	var swap_frame: InputFrame = InputFrame.new()
	swap_frame.weapon_equip = Tuning.WEAPON_DUAL_DAGGER
	step(swap_frame)
	var events: Array = arena.core.last_events.map(func(e: GameEvent) -> StringName: return e.type)
	check(GameEvent.WEAPON_SWAPPED in events, "fixture: no weapon_swapped")
	check(arena.particles.is_empty(), "the old swap puff is still drawn")


## The tooltip, the result panels and the menu draw with the shared frame (and without script errors).
func shared_frame() -> void:
	fixture()
	await save("hud_plain")
	var before: int = UiPanel.drawn
	arena.hud.hint_slot_override = 1
	arena.hud.queue_redraw()
	await process_frame
	check(UiPanel.drawn > before, "the skill tooltip does not use the shared frame")
	await save("tooltip")
	arena.hud.hint_slot_override = -1
	check(Hud.aspect_hint_rect().end.x <= 320 and Hud.aspect_hint_rect().end.y <= Hud.aspect_rects()[1].position.y + 30, "tooltip rect")
	# the menu: every tab and a hover each
	check(arena.open_menu(), "open")
	before = UiPanel.drawn
	await process_frame
	check(UiPanel.drawn >= before + 2, "the menu does not use the shared frame (panel + description)")
	await save("stats")
	menu.hover_key = &"weapon"
	await save("stats_weapon")
	menu.hover_key = &"gale_cut"
	await save("stats_aspect")
	menu.hover_key = &"stat_speed"
	await save("stats_row")
	# the weapon block follows the equipped weapon
	for weapon: StringName in [Tuning.WEAPON_DUAL_DAGGER, Tuning.WEAPON_CHAIN_SCYTHE]:
		arena.core.player.weapon_id = weapon
		observe()
		menu.hover_key = &"stat_speed" if weapon == Tuning.WEAPON_DUAL_DAGGER else &"stat_reach"
		await save("stats_" + String(weapon))
	arena.core.player.weapon_id = Tuning.WEAPON_BLACK_KATANA
	observe()
	menu.hover_key = &""
	menu.set_tab(Menu.TAB_INVENTORY)
	menu.inventory_selection = 2
	await process_frame
	await save("inventory")
	arena.close_menu()
	# results
	for result: StringName in [&"defeat", &"victory"]:
		fixture()
		if result == &"defeat":
			var events: Array[GameEvent] = []
			arena.core.player.take_damage(Tuning.PLAYER_MAX_HP, arena.core.tick, events, arena.core.boss.id)
			arena.hud.result_lines = []
		else:
			var events: Array[GameEvent] = []
			arena.core.boss.take_damage(99999, arena.core.tick, events, arena.core.player.id)
			arena.hud.result_lines = ["TIME 0:27.2", "BEST 0:17.2"]
		arena.hud.result_hint = "ESC: TITLE"
		step()
		for i: int in range(90):
			step()
		check(arena.snapshot.result == result, "fixture: no %s (%s)" % [result, arena.snapshot.result])
		before = UiPanel.drawn
		arena.hud.queue_redraw()
		await process_frame
		check(UiPanel.drawn > before, "the %s panel does not use the shared frame" % result)
		var rect: Rect2 = Hud.result_panel_rect(arena.hud.result_lines.size(), true)
		check(rect.position.y - 8 >= 0 and rect.end.y <= 180, "%s panel off screen: %s" % [result, rect])
		await save(String(result))
	arena.hud.result_lines = []
	arena.hud.result_hint = ""
	fixture()


func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	Bindings.register()
	arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(arena)
	await process_frame
	arena.set_physics_process(false)
	menu = arena.character_menu
	check(menu != null and menu.get_parent() == arena.get_node("HUD"), "the menu is not on the HUD layer")
	await open_close()
	await refusals()
	await tabs_and_selection()
	await descriptions()
	await equip()
	await hud_contract()
	await shared_frame()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("CHARACTER MENU FAIL: " + message)
	print("CHARACTER MENU SMOKE OK" if failures.is_empty() else "CHARACTER MENU SMOKE FAILED")
	quit(0 if failures.is_empty() else 1)
