extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_character_menu.gd
## The character menu (TAB) and the pop-ups restyled with the shared frame (approved 2026-10-21):
## open/close with TAB and ESC; no open during a cut-in or on the result screen; restart closes it; the world is frozen
## while it is open and resumes after; tabs (Q/E, clicks); selection movement; a description for every aspect, weapon
## and stat (with real numbers, every line fits the box); equipping from the inventory through the core (EQUIPPED, the
## drawn frame set changes; NOT NOW when the core refuses); the HUD has no weapon info box, no Q SWAP and no CD text;
## tooltip, result panels and menu draw with the shared frame. Aspects (2026-10-21): ENTER/click on an Aspect slot opens
## the picker, which equips through the core (one step: EQUIPPED!, a swap when the aspect sits in another slot, NOT NOW
## when the hero is busy or a weapon form runs; ESC closes only the picker); the inventory lists the aspects; the
## equipped weapon and aspects are saved in the profile (a temp TOTOY_SAVE_PATH) and used again at restart.
## With `-- --capture` in a window it saves art/build/arena_menu_*.png for a visual check (delete them afterwards).
const Arena := preload("res://presentation/arena/arena.gd")
const Menu := preload("res://presentation/arena/character_menu.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const UiPanel := preload("res://presentation/arena/ui_panel.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const Weapons := preload("res://core/weapons.gd")
const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Aspects := preload("res://core/aspects.gd")
const SaveStore := preload("res://core/save_store.gd")

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


## Same ids in the same order (typed and untyped arrays alike).
func same(a: Array, b: Array) -> bool:
	return str(a) == str(b)


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
	check(menu.stats_selection == &"aspect_slot_2" and menu.description_key() == &"gale_cut", "a click selects an Aspect")
	check(menu.picker_open() and menu.picker_slot == 2, "a click on an Aspect slot opens the picker")
	menu.close_picker()
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
	for i: int in range(Aspects.ALL.size()):
		menu.hover_at(Menu.inventory_rect(Menu.ASPECT_GRID_START + i).get_center())
		check(menu.description_key() == Aspects.ALL[i], "the inventory lists the aspect " + String(Aspects.ALL[i]))
	menu.accept()
	check(arena.snapshot.player.equipped_aspects == Aspects.DEFAULT_EQUIPPED, "ENTER on an inventory aspect changed the slots")
	menu.hover_at(Menu.inventory_rect(15).get_center())
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
	var lantern: String = String(d[&"spirit_lantern"][2][2])
	check(lantern.begins_with("%d EDGE  CD %d S" % [int(Tuning.SPIRIT_LANTERN_EDGE_COST), Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS / 60]) and lantern.contains("+%d HP" % Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE), "lantern numbers: " + lantern)
	check(String(d[&"spirit_lantern"][2][1]).contains("%d PX" % int(Tuning.SPIRIT_LANTERN_RADIUS)), "lantern radius")
	check(String(d[&"phantom_cut"][2][0]).contains(Menu.secs(Tuning.PHANTOM_CUT_DELAY_TICKS) + " S"), "phantom echo delay: " + String(d[&"phantom_cut"][2][0]))
	check(String(d[&"phantom_cut"][2][2]).contains("%d%% DMG" % roundi(Tuning.PHANTOM_CUT_DAMAGE_MULT * 100)), "phantom damage")
	check(d[&"gale_cut"][1] == "ASPECT  KEY X" and d[&"spirit_lantern"][1] == "ASPECT", "aspect tags follow the default slots")
	var moved: Dictionary = Menu.descriptions(Tuning.WEAPON_BLACK_KATANA, [&"spirit_lantern", &"gale_cut", &"phantom_cut"])
	check(moved[&"spirit_lantern"][1] == "ASPECT  KEY Z" and moved[&"breaking_edge"][1] == "ASPECT", "aspect tags follow the slots")
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


## The aspect picker: ENTER on a slot opens it, arrows move, ENTER equips through the core in one step (and swaps),
## ESC closes only the picker, a click equips, busy / a weapon form running gives NOT NOW; the HUD follows.
func aspect_picker() -> void:
	fixture()
	check(arena.open_menu(), "open")
	menu.stats_selection = &"aspect_slot_1"
	await menu_with("menu_accept")
	check(menu.picker_open() and menu.picker_slot == 1, "ENTER on the Z slot did not open the picker")
	check(menu.picker_selection == 0 and menu.description_key() == &"breaking_edge", "the picker starts on the slotted aspect")
	await save("picker")
	for i: int in range(3):
		await menu_with("menu_down")
	check(Aspects.ALL[menu.picker_selection] == &"spirit_lantern" and menu.description_key() == &"spirit_lantern", "down in the picker")
	await save("picker_lantern")
	var tick: int = arena.core.tick
	await menu_with("menu_accept")
	check(arena.core.tick == tick + 1, "an aspect equip is exactly one core step (%d)" % (arena.core.tick - tick))
	check(arena.snapshot.player.equipped_aspects[0] == &"spirit_lantern", "ENTER did not slot the lantern into Z")
	check(bool(menu.picker_feedback.get("ok", false)), "no EQUIPPED feedback: %s" % str(menu.picker_feedback))
	check(Hud.skill_rows(arena.snapshot.hud)[0]["aspect_id"] == &"spirit_lantern" and Hud.skill_rows(arena.snapshot.hud)[0]["icon"] == "ui_aspect_spirit_lantern_1", "the HUD Z slot does not show the lantern")
	await save("picker_equipped")
	# Gale Cut (in X) into Z: the core swaps the two slots
	menu.picker_selection = Aspects.ALL.find(&"gale_cut")
	menu.accept()
	check(same(arena.snapshot.player.equipped_aspects, [&"gale_cut", &"spirit_lantern", &"moon_cleave"]), "no swap: %s" % str(arena.snapshot.player.equipped_aspects))
	# the aspect already in the slot sends nothing
	tick = arena.core.tick
	menu.accept()
	check(arena.core.tick == tick and bool(menu.picker_feedback["ok"]), "re-slotting the same aspect stepped the core")
	# ESC closes only the picker
	await menu_with("menu_back")
	check(not menu.picker_open() and menu.is_open, "ESC did not close only the picker")
	# a click on the C slot, then on Phantom Cut
	menu.click(Menu.aspect_rect(2).get_center())
	check(menu.picker_open() and menu.picker_slot == 3, "a click on C did not open the picker")
	menu.click(Menu.picker_row_rect(Aspects.ALL.find(&"phantom_cut")).get_center())
	check(arena.snapshot.player.equipped_aspects[2] == &"phantom_cut", "a click did not slot Phantom Cut")
	menu.hover_at(Menu.picker_row_rect(4).get_center())
	check(menu.description_key() == &"phantom_cut", "hover in the picker")
	menu.click(Vector2(20, 30))
	check(not menu.picker_open() and menu.is_open, "a click outside did not close the picker")
	menu.set_tab(Menu.TAB_INVENTORY)
	menu.inventory_selection = Menu.ASPECT_GRID_START + Aspects.ALL.find(&"spirit_lantern")
	await save("inventory_aspect")
	arena.close_menu()
	# busy (mid-swing): NOT NOW, nothing changes
	fixture(30.0)
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	step(attack)
	check(arena.open_menu(), "the menu opens mid-swing")
	menu.open_picker(1)
	menu.picker_selection = Aspects.ALL.find(&"phantom_cut")
	menu.accept()
	check(arena.snapshot.player.equipped_aspects[0] == &"breaking_edge", "slotted while busy")
	check(not bool(menu.picker_feedback["ok"]) and menu.picker_feedback["reason"] == "TRY WHEN IDLE", "no NOT NOW (busy): %s" % str(menu.picker_feedback))
	await save("picker_not_now")
	arena.close_menu()
	# a weapon form running: NOT NOW (ACTIVE RUNNING)
	fixture()
	var active: InputFrame = InputFrame.new()
	active.weapon_active_pressed = true
	step(active)
	if arena.cutin.active:
		arena.cutin.stop()
	check(arena.snapshot.player.weapon_buff_active and arena.snapshot.player.state == &"idle", "fixture: no Black Form")
	check(arena.open_menu(), "open with the form running")
	menu.open_picker(2)
	menu.picker_selection = Aspects.ALL.find(&"spirit_lantern")
	menu.accept()
	check(arena.snapshot.player.equipped_aspects[1] == &"gale_cut" and menu.picker_feedback["reason"] == "ACTIVE RUNNING", "no ACTIVE RUNNING refusal: %s" % str(menu.picker_feedback))
	arena.close_menu()
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## The picker lists all 8 aspects (Aspects.ALL) in a window of whole rows: the arrows scroll it so the highlighted row
## stays in view, the mouse wheel scrolls it (pulling the highlight along), a scroll bar shows when rows are hidden, no
## row is ever drawn past the picker's bottom, and the 8th aspect can be equipped by keyboard and by wheel + click.
func picker_scroll() -> void:
	fixture()
	check(Aspects.ALL.size() == 8, "the picker should list 8 aspects, not %d" % Aspects.ALL.size())
	check(arena.open_menu(), "open")
	menu.stats_selection = &"aspect_slot_1"
	await menu_with("menu_accept")
	check(menu.picker_open() and menu.picker_scroll == 0, "the picker opens at the top")
	check(Menu.picker_max_scroll() == Aspects.ALL.size() - Menu.PICKER_VISIBLE_ROWS and Menu.picker_max_scroll() > 0, "8 aspects need a scroll")
	for index: int in range(Menu.PICKER_VISIBLE_ROWS):
		check(Menu.picker_row_rect(index).end.y <= Menu.PICKER.end.y and Menu.picker_row_rect(index).position.y >= Menu.PICKER.position.y, "row %d leaves the picker" % index)
	check(not Menu.picker_bar_rect().intersects(Menu.picker_row_rect(0)) and Menu.PICKER.encloses(Menu.picker_bar_rect().grow(3)), "the scroll bar overlaps the rows or leaves the picker")
	# keyboard: down to the last aspect
	for i: int in range(Aspects.ALL.size() - 1):
		await menu_with("menu_down")
		check(menu.row_visible(menu.picker_selection), "the highlighted row %d left the view" % menu.picker_selection)
	check(menu.picker_selection == Aspects.ALL.size() - 1 and menu.picker_scroll == Menu.picker_max_scroll(), "down did not reach the 8th aspect (%d, scroll %d)" % [menu.picker_selection, menu.picker_scroll])
	check(Aspects.ALL[menu.picker_selection] == &"stone_ward" and menu.description_key() == &"stone_ward", "the 8th row is Stone Ward")
	await save("picker_scrolled")
	var tick: int = arena.core.tick
	await menu_with("menu_accept")
	check(arena.core.tick == tick + 1 and arena.snapshot.player.equipped_aspects[0] == &"stone_ward", "ENTER did not slot Stone Ward into Z: %s" % str(arena.snapshot.player.equipped_aspects))
	await menu_with("menu_up")
	check(menu.picker_scroll == Menu.picker_max_scroll(), "up inside the window scrolled")
	for i: int in range(Aspects.ALL.size()):
		await menu_with("menu_up")
	check(menu.picker_selection == 0 and menu.picker_scroll == 0, "up did not scroll back to the top")
	menu.close_picker()
	# the mouse wheel on slot X: scroll to the bottom, the highlight follows, then a click on the 7th aspect (Echo Step)
	menu.open_picker(2)
	check(menu.picker_scroll == 0 and menu.picker_selection == 1, "slot X opens on Gale Cut at the top")
	for i: int in range(6):
		var wheel: InputEventMouseButton = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		menu._input(wheel)
	check(menu.picker_scroll == Menu.picker_max_scroll(), "the wheel did not scroll to the bottom (%d)" % menu.picker_scroll)
	check(menu.row_visible(menu.picker_selection), "the wheel left the highlight out of view")
	var echo: int = Aspects.ALL.find(&"echo_step")
	check(menu.row_visible(echo), "Echo Step is not visible after the wheel")
	menu.click(Menu.picker_row_rect(echo, menu.picker_scroll).get_center())
	check(arena.snapshot.player.equipped_aspects[1] == &"echo_step", "a click after the wheel did not slot Echo Step: %s" % str(arena.snapshot.player.equipped_aspects))
	# a hidden row's old position does not react: row 0 is scrolled away, its rect now belongs to row 3
	menu.hover_at(Menu.picker_row_rect(0).get_center())
	check(menu.picker_selection == menu.picker_scroll, "hover on the top row picks the first visible aspect")
	await save("picker_wheel")
	var wheel_up: InputEventMouseButton = InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	menu._input(wheel_up)
	check(menu.picker_scroll == Menu.picker_max_scroll() - 1, "the wheel up did not scroll one row")
	# Sprint (6th) into C by keyboard from Moon Cleave
	menu.close_picker()
	menu.open_picker(3)
	for i: int in range(Aspects.ALL.find(&"sprint") - Aspects.ALL.find(&"moon_cleave")):
		await menu_with("menu_down")
	await menu_with("menu_accept")
	check(same(arena.snapshot.player.equipped_aspects, [&"stone_ward", &"echo_step", &"sprint"]), "the three new aspects are not slotted: %s" % str(arena.snapshot.player.equipped_aspects))
	var rows: Array[Dictionary] = Hud.skill_rows(arena.snapshot.hud)
	check(rows[0]["icon"] == "ui_aspect_stone_ward_1" and rows[1]["icon"] == "ui_aspect_echo_step_1" and rows[2]["icon"] == "ui_aspect_sprint_1", "HUD icons of the new aspects: %s" % str(rows.map(func(r: Dictionary) -> String: return r["icon"])))
	# their descriptions carry the real numbers
	var d: Dictionary = Menu.descriptions(Tuning.WEAPON_BLACK_KATANA, arena.snapshot.player.equipped_aspects)
	check(String(d[&"sprint"][2][0]).contains("X2") and String(d[&"sprint"][2][2]).contains("%d EDGE" % int(Tuning.SPRINT_EDGE_COST)) and String(d[&"sprint"][2][2]).contains("CD 12 S"), "sprint description: %s" % str(d[&"sprint"]))
	check(String(d[&"echo_step"][2][0]).contains("2 S") and String(d[&"echo_step"][2][2]).contains("12 TICKS") and String(d[&"echo_step"][2][2]).contains("CD 14 S"), "echo description: %s" % str(d[&"echo_step"]))
	check(String(d[&"stone_ward"][2][1]).contains("60") and String(d[&"stone_ward"][2][1]).contains("64 PX") and String(d[&"stone_ward"][2][2]).contains("WAVE 8 + STORED"), "ward description: %s" % str(d[&"stone_ward"]))
	check(d[&"stone_ward"][1] == "ASPECT  KEY Z" and d[&"sprint"][1] == "ASPECT  KEY C", "the new aspects' tags follow their slots")
	await save("picker_new_three")
	arena.close_menu()
	fixture()


## The menu's equips are written to the profile (only when progress is saved) and a restart starts with them.
## Uses a throwaway TOTOY_SAVE_PATH so no real save is ever touched.
func saved_loadout() -> void:
	var old_env: String = OS.get_environment(SaveStore.PATH_ENV)
	var path: String = "user://smoke_character_menu_loadout.json"
	OS.set_environment(SaveStore.PATH_ENV, path)
	check(SaveStore.default_path() == path, "the temp save path is not used")
	for file: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	var was_persist: bool = arena.persist
	arena.persist = true
	arena.profile = SaveStore.load_profile()
	fixture()
	check(arena.snapshot.player.equipped_aspects == Aspects.DEFAULT_EQUIPPED, "a fresh profile starts with the default slots")
	arena.request_aspect_equip(&"phantom_cut", 1)
	arena.request_aspect_equip(&"spirit_lantern", 3)
	arena.request_equip(Tuning.WEAPON_CHAIN_SCYTHE)
	var saved: Object = SaveStore.load_profile()
	check(same(saved.equipped_aspects, [&"phantom_cut", &"gale_cut", &"spirit_lantern"]), "aspects not saved: %s" % str(saved.equipped_aspects))
	check(saved.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE, "weapon not saved: %s" % saved.weapon_id)
	arena._restart()
	check(arena.snapshot.player.equipped_aspects == saved.equipped_aspects, "restart ignored the saved aspects: %s" % str(arena.snapshot.player.equipped_aspects))
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE, "restart ignored the saved weapon")
	check(Hud.skill_rows(arena.snapshot.hud)[0]["aspect_id"] == &"phantom_cut", "the HUD does not show the saved slots")
	# a fresh arena from the title (persist meta) loads and applies the profile too
	arena.profile = null
	arena.persist = false
	Engine.set_meta(&"totoy_persist", true)
	var second: Arena = load("res://presentation/arena/arena.tscn").instantiate() as Arena
	root.add_child(second)
	await process_frame
	second.set_physics_process(false)
	check(second.snapshot.player.equipped_aspects == saved.equipped_aspects and second.snapshot.player.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE, "a new arena did not apply the saved loadout")
	second.queue_free()
	Engine.remove_meta(&"totoy_persist")
	await process_frame
	arena.camera.make_current()
	for file: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	OS.set_environment(SaveStore.PATH_ENV, old_env)
	arena.persist = was_persist
	arena.profile = null
	fixture()
	check(arena.snapshot.player.equipped_aspects == Aspects.DEFAULT_EQUIPPED, "without a profile a restart uses the default slots")


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
	await aspect_picker()
	await picker_scroll()
	await saved_loadout()
	await hud_contract()
	await shared_frame()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("CHARACTER MENU FAIL: " + message)
	print("CHARACTER MENU SMOKE OK" if failures.is_empty() else "CHARACTER MENU SMOKE FAILED")
	quit(0 if failures.is_empty() else 1)
