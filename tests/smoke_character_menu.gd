extends SceneTree
## godot_console --headless --path . --script res://tests/smoke_character_menu.gd
## The character menu (TAB), redesigned 2026-11-03 (HERO, GEAR, QUESTS; presentation/review/menu_redesign/), in the boss fight:
## open/close with TAB and ESC; no open during a cut-in or on the result screen; restart closes it; the world is frozen
## while it is open and resumes after; tabs (Q/E, clicks); the arrows reach everything on GEAR; hovering selects and the card
## describes the selection; HERO shows base stats and nothing to spend; QUESTS shows the fight's goal. The weapon list and the
## Aspect list open in the card, equip through the core in one step (EQUIPPED, NOT NOW when the core refuses, a swap between
## sockets), scroll three rows at a time (keys, wheel, clicks) and close with ESC; every weapon and Aspect has a description
## with real numbers; the HUD has no weapon info box; the frame and card are the editable scenes and the HUD strip hides
## under the menu; the equipped weapon and Aspects are saved in the profile (a temp TOTOY_SAVE_PATH) and used at restart.
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
	check(menu.tab == Menu.TAB_HERO, "the menu opens on HERO")
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
	check(menu.tab == Menu.TAB_HERO, "the menu opens on HERO")
	await menu_with("menu_tab_next")
	check(menu.tab == Menu.TAB_GEAR, "E did not switch to GEAR")
	await menu_with("menu_tab_next")
	check(menu.tab == Menu.TAB_QUESTS, "E did not switch to QUESTS")
	await menu_with("menu_tab_next")
	check(menu.tab == Menu.TAB_HERO, "E does not wrap")
	await menu_with("menu_tab_prev")
	check(menu.tab == Menu.TAB_QUESTS, "Q did not switch the tab")
	menu.click(Menu.tab_rect(Menu.TAB_GEAR).get_center())
	check(menu.tab == Menu.TAB_GEAR, "a click on the GEAR tab")
	menu.click(Menu.tab_rect(Menu.TAB_HERO).get_center())
	check(menu.tab == Menu.TAB_HERO, "a click on the HERO tab")
	# the boss fight's HERO: Totoy and a note, nothing to choose; base stats in the card
	check(menu.items().is_empty() and menu._hero_data()["rows"].is_empty() and not String(menu._hero_data()["note"]).is_empty(), "HERO in the boss fight shows stat rows")
	check(menu.stat_lines()[0][1] == str(Tuning.PLAYER_MAX_HP), "the card's health is not the fight's: %s" % str(menu.stat_lines()[0]))
	# GEAR: every thing is reachable by the arrows, and the arrows go where the eye expects
	menu.set_tab(Menu.TAB_GEAR)
	check(menu.gear_selection == &"weapon", "GEAR starts on the weapon")
	var reached: Dictionary = {&"weapon": true}
	var frontier: Array[StringName] = [&"weapon"]
	while not frontier.is_empty():
		var key: StringName = frontier.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			menu.gear_selection = key
			menu.move_selection(dir)
			if not reached.has(menu.gear_selection):
				reached[menu.gear_selection] = true
				frontier.append(menu.gear_selection)
	for item: Dictionary in menu.items():
		check(reached.has(item["key"]), "arrow keys never reach " + String(item["key"]))
	check(menu.items().size() == 6, "GEAR has the weapon, three sockets and two item slots: %d" % menu.items().size())
	menu.gear_selection = &"weapon"
	menu.move_selection(Vector2i.DOWN)
	check(menu.gear_selection in Menu.ASPECT_KEYS, "down from the weapon goes to a socket: " + String(menu.gear_selection))
	menu.gear_selection = &"aspect_slot_3"
	menu.move_selection(Vector2i.RIGHT)
	check(menu.gear_selection == &"item_1", "right from socket C goes to item 1: " + String(menu.gear_selection))
	menu.move_selection(Vector2i.RIGHT)
	check(menu.gear_selection == &"item_2", "right from item 1 goes to item 2")
	for rect: Rect2 in [Menu.weapon_rect(), Menu.socket_rect(0), Menu.socket_rect(2), Menu.item_rect(1)]:
		check(not rect.intersects(Menu.CARD), "a GEAR rect reaches into the card: %s" % rect)
	# hovering selects; the card describes the selection
	menu.hover_at(Menu.socket_rect(1).get_center())
	check(menu.gear_selection == &"aspect_slot_2" and menu._gear_card()["title"] == "GALE CUT", "hovering socket X selects Gale Cut: %s" % str(menu._gear_card().get("title")))
	menu.hover_at(Menu.item_rect(1).get_center())
	check(menu.gear_selection == &"item_2" and menu._gear_card()["title"] == "EMPTY SLOT", "item slot 2 is an empty slot")
	menu.accept()
	check(not menu.list_open(), "ENTER on an item slot opened a list")
	# a click on a socket opens its list; a click outside the card closes it
	menu.click(Menu.socket_rect(1).get_center())
	check(menu.list_open() and menu.list_kind == &"aspects" and menu.list_slot == 2, "a click on socket X did not open its list")
	check(String(menu.footer()[2][0]) == "ESC", "the footer does not offer ESC: BACK in a list: %s" % str(menu.footer()))
	menu.click(Vector2(20, 60))
	check(not menu.list_open() and menu.is_open, "a click outside the card did not close the list")
	check(String(menu.footer()[1][1]) == "CHANGE ASPECT", "the footer's ENTER does not say what it does on a socket: %s" % str(menu.footer()))
	# QUESTS: the fight's goal, nothing to choose
	menu.set_tab(Menu.TAB_QUESTS)
	var quests: Dictionary = menu._quests_data()
	check(quests["rows"].size() == 1 and String(quests["rows"][0]["text"]).contains("COLOSSUS") and bool(quests["rows"][0]["now"]), "QUESTS in the boss fight: %s" % str(quests))
	check(not String(menu._quests_card()["body"]).contains("MARKER ON THE ROAD"), "the boss fight's QUESTS points at the road")
	menu.move_selection(Vector2i.DOWN)
	menu.accept()
	check(menu.tab == Menu.TAB_QUESTS and not menu.list_open(), "QUESTS reacted to the arrows or ENTER")
	await save("quests")
	arena.close_menu()


## Every weapon and Aspect has a description with real numbers; the cards and lists show them for every weapon.
func descriptions() -> void:
	for weapon: StringName in Weapons.IDS:
		fixture()
		arena.core.player.weapon_id = weapon
		observe()
		check(arena.open_menu(), "open")
		var all: Dictionary = Menu.descriptions(weapon)
		check(all.size() == Weapons.IDS.size() + Aspects.ALL.size(), "descriptions are only the weapons and Aspects: %d" % all.size())
		for key: StringName in all:
			var entry: Array = all[key]
			var lines: Array = entry[2]
			check(lines.size() == 3 and not String(entry[0]).is_empty(), "description %s is incomplete" % key)
			check(not String(lines[2]).is_empty() and String(lines[2]).contains(" "), "description %s has no numbers line" % key)
		menu.set_tab(Menu.TAB_GEAR)
		var card: Dictionary = menu._gear_card()
		check(card["title"] == Menu.WEAPON_NAMES[weapon] and String(card["sub"]).begins_with("EQUIPPED"), "the weapon card does not show the equipped %s: %s" % [weapon, str(card)])
		var gear: Dictionary = menu._gear_data()["weapon"]
		check(gear["name"] == Menu.WEAPON_NAMES[weapon] and (gear["glyph"] != "") != (gear["whole"] != ""), "the weapon socket shows the wrong art: %s" % str(gear))
		check(Menu.figure_frame(weapon).contains("idle"), "no idle figure for %s" % weapon)
		arena.close_menu()
	# real numbers: spot checks against the tuning (not invented)
	var d: Dictionary = Menu.descriptions(Tuning.WEAPON_BLACK_KATANA)
	check(String(d[&"gale_cut"][2][2]).begins_with("%d EDGE  CD %d S" % [int(Tuning.GALE_CUT_EDGE_COST), Tuning.GALE_CUT_COOLDOWN_TICKS / 60]), "Gale Cut numbers: " + String(d[&"gale_cut"][2][2]))
	check(String(d[Tuning.WEAPON_DUAL_DAGGER][2][2]).contains("CD %s S" % Menu.secs(Tuning.LIGHTNING_FORM_COOLDOWN_TICKS)), "dagger cooldown from the tuning")
	var lantern: String = String(d[&"spirit_lantern"][2][2])
	check(lantern.begins_with("%d EDGE  CD %d S" % [int(Tuning.SPIRIT_LANTERN_EDGE_COST), Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS / 60]) and lantern.contains("+%d HP" % Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE), "lantern numbers: " + lantern)
	check(String(d[&"spirit_lantern"][2][1]).contains("%d PX" % int(Tuning.SPIRIT_LANTERN_RADIUS)), "lantern radius")
	check(String(d[&"phantom_cut"][2][0]).contains(Menu.secs(Tuning.PHANTOM_CUT_DELAY_TICKS) + " S"), "phantom echo delay: " + String(d[&"phantom_cut"][2][0]))
	check(String(d[&"phantom_cut"][2][2]).contains("%d%% DMG" % roundi(Tuning.PHANTOM_CUT_DAMAGE_MULT * 100)), "phantom damage")
	check(d[&"gale_cut"][1] == "ASPECT  KEY X" and d[&"spirit_lantern"][1] == "ASPECT", "aspect tags follow the default slots")
	var moved: Dictionary = Menu.descriptions(Tuning.WEAPON_BLACK_KATANA, [&"spirit_lantern", &"gale_cut", &"phantom_cut"])
	check(moved[&"spirit_lantern"][1] == "ASPECT  KEY Z" and moved[&"breaking_edge"][1] == "ASPECT", "aspect tags follow the slots")
	check(Menu.secs(14) == "0.23" and Menu.secs(1800) == "30" and Menu.secs(750) == "12.5" and Menu.num(1.5) == "1.5" and Menu.num(50.0) == "50", "number formatting")
	for key: StringName in [&"stat_vitality", &"stat_might", &"stat_agility", &"respec"]:
		check(not Menu.stat_text(key).is_empty(), "no text for " + String(key))
	check(Menu.stat_text(&"stat_vitality").contains("+%d MAX HEALTH" % Tuning.VITALITY_HP_PER_POINT), "vitality text from the tuning")


## The weapon list: ENTER on the weapon socket opens it in the card, arrows move, ENTER equips through the core in one step
## (EQUIPPED, the drawn frame set changes; NOT NOW when the core refuses); ESC closes only the list; clicks work too.
func equip() -> void:
	fixture()
	check(arena.open_menu(), "open")
	menu.set_tab(Menu.TAB_GEAR)
	await menu_with("menu_accept")
	check(menu.list_open() and menu.list_kind == &"weapons", "ENTER on the weapon socket did not open the weapon list")
	check(menu.list_selection == 0 and menu.list_ids()[0] == Tuning.WEAPON_BLACK_KATANA, "the list starts on the equipped katana")
	check(menu.list_ids().size() == Weapons.IDS.size() and menu.scroll_bar().size() == 2, "four weapons need the scroll bar (three in view)")
	await menu_with("menu_down")
	check(menu.list_selection == 1 and menu._gear_card()["mode"] == "list", "down in the weapon list")
	check(String(menu._gear_card()["list_body"]).begins_with(String(Menu.descriptions(Tuning.WEAPON_DUAL_DAGGER)[Tuning.WEAPON_DUAL_DAGGER][2][0])), "the list does not describe the highlighted dagger")
	var tick: int = arena.core.tick
	await menu_with("menu_accept")
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_DUAL_DAGGER, "ENTER on the dagger did not equip it")
	check(arena.core.tick == tick + 1, "an equip request is exactly one core step (%d)" % (arena.core.tick - tick))
	check(bool(menu.feedback.get("ok", false)) and menu._gear_card()["sub"] == "EQUIPPED!", "no EQUIPPED feedback: %s" % str(menu.feedback))
	check(chosen().begins_with("totoy_dagger_"), "the drawn frame set did not change: " + chosen())
	check(menu.is_open and menu.list_open(), "equipping closed the menu or the list")
	await save("equipped")
	# a second equip right away works (no swap lockout: the menu is paused anyway)
	menu.list_selection = 2
	menu.accept()
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_CHAIN_SCYTHE and bool(menu.feedback["ok"]), "a second equip right away did not equip the scythe")
	# the equipped one: no core step
	tick = arena.core.tick
	menu.accept()
	check(arena.core.tick == tick, "re-equipping the equipped weapon stepped the core")
	# the Star Staff, fourth, is a scroll away
	await menu_with("menu_down")
	check(menu.list_selection == 3 and menu.list_scroll == 1 and menu.row_visible(3), "down did not scroll to the staff (%d, scroll %d)" % [menu.list_selection, menu.list_scroll])
	await menu_with("menu_back")
	check(not menu.list_open() and menu.is_open and menu.gear_selection == &"weapon", "ESC did not close only the list")
	# clicks: the weapon socket opens the list, a row equips
	arena.close_menu()
	for i: int in range(Tuning.WEAPON_SWAP_LOCKOUT_TICKS + 1):
		step()
	check(arena.open_menu(), "reopen")
	menu.click(Menu.tab_rect(Menu.TAB_GEAR).get_center())
	menu.click(Menu.weapon_rect().get_center())
	check(menu.list_open() and menu.list_kind == &"weapons", "a click on the weapon socket did not open the list")
	menu.click(Menu.list_row_rect(0 - menu.list_scroll).get_center())
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_BLACK_KATANA and chosen().begins_with("hero2_"), "a click did not equip the katana: %s %s" % [arena.snapshot.player.weapon_id, chosen()])
	arena.close_menu()
	# busy (mid-swing): NOT NOW, nothing changes
	fixture(30.0)
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	step(attack)
	check(arena.snapshot.player.state.begins_with("attack_"), "fixture: not swinging")
	check(arena.open_menu(), "the menu opens mid-swing")
	menu.set_tab(Menu.TAB_GEAR)
	menu.open_weapon_list()
	menu.list_selection = 2
	menu.accept()
	check(arena.snapshot.player.weapon_id == Tuning.WEAPON_BLACK_KATANA, "equipped while busy")
	check(not bool(menu.feedback["ok"]) and menu.feedback["reason"] == "TRY WHEN IDLE" and String(menu._gear_card()["sub"]).begins_with("NOT NOW"), "no NOT NOW (busy): %s" % str(menu.feedback))
	await save("not_now")
	arena.close_menu()
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## The Aspect list: ENTER on a socket opens it in the card, arrows move, ENTER sets the Aspect through the core in one step
## (and swaps), ESC closes only the list, a click sets one, busy / a weapon form running gives NOT NOW; the HUD follows.
func aspect_list() -> void:
	fixture()
	check(arena.open_menu(), "open")
	menu.set_tab(Menu.TAB_GEAR)
	menu.gear_selection = &"aspect_slot_1"
	await menu_with("menu_accept")
	check(menu.list_open() and menu.list_kind == &"aspects" and menu.list_slot == 1, "ENTER on socket Z did not open the Aspect list")
	check(same(menu.list_ids(), Aspects.ALL), "the boss fight's list is every Aspect: %s" % str(menu.list_ids()))
	check(menu.list_selection == 0, "the list starts on the Aspect in the socket")
	await save("aspect_list")
	for i: int in range(3):
		await menu_with("menu_down")
	check(menu.list_ids()[menu.list_selection] == &"spirit_lantern", "down in the list")
	var tick: int = arena.core.tick
	await menu_with("menu_accept")
	check(arena.core.tick == tick + 1, "an Aspect request is exactly one core step (%d)" % (arena.core.tick - tick))
	check(arena.snapshot.player.equipped_aspects[0] == &"spirit_lantern", "ENTER did not set the lantern in Z")
	check(bool(menu.feedback.get("ok", false)), "no EQUIPPED feedback: %s" % str(menu.feedback))
	check(Hud.skill_rows(arena.snapshot.hud)[0]["aspect_id"] == &"spirit_lantern" and Hud.skill_rows(arena.snapshot.hud)[0]["icon"] == "ui_aspect_spirit_lantern_1", "the HUD Z socket does not show the lantern")
	# Gale Cut (in X) into Z: the core swaps the two sockets
	menu.list_selection = menu.list_ids().find(&"gale_cut")
	menu.accept()
	check(same(arena.snapshot.player.equipped_aspects, [&"gale_cut", &"spirit_lantern", &"moon_cleave"]), "no swap: %s" % str(arena.snapshot.player.equipped_aspects))
	tick = arena.core.tick
	menu.accept()
	check(arena.core.tick == tick and bool(menu.feedback["ok"]), "setting the same Aspect again stepped the core")
	await menu_with("menu_back")
	check(not menu.list_open() and menu.is_open, "ESC did not close only the list")
	# a click on socket C, then on Phantom Cut
	menu.click(Menu.socket_rect(2).get_center())
	check(menu.list_open() and menu.list_slot == 3, "a click on C did not open the list")
	var phantom: int = menu.list_ids().find(&"phantom_cut")
	menu.list_selection = phantom
	menu._scroll_to_selection()
	menu.click(Menu.list_row_rect(phantom - menu.list_scroll).get_center())
	check(arena.snapshot.player.equipped_aspects[2] == &"phantom_cut", "a click did not set Phantom Cut")
	menu.hover_at(Menu.list_row_rect(0).get_center())
	check(menu.list_selection == menu.list_scroll, "hover on the top row picks the first one in view")
	arena.close_menu()
	# busy (mid-swing): NOT NOW, nothing changes
	fixture(30.0)
	var attack: InputFrame = InputFrame.new()
	attack.attack_pressed = true
	attack.aim = Vector2.RIGHT
	step(attack)
	check(arena.open_menu(), "the menu opens mid-swing")
	menu.set_tab(Menu.TAB_GEAR)
	menu.open_aspect_list(1)
	menu.list_selection = menu.list_ids().find(&"phantom_cut")
	menu.accept()
	check(arena.snapshot.player.equipped_aspects[0] == &"breaking_edge", "set while busy")
	check(not bool(menu.feedback["ok"]) and menu.feedback["reason"] == "TRY WHEN IDLE", "no NOT NOW (busy): %s" % str(menu.feedback))
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
	menu.set_tab(Menu.TAB_GEAR)
	menu.open_aspect_list(2)
	menu.list_selection = menu.list_ids().find(&"spirit_lantern")
	menu.accept()
	check(arena.snapshot.player.equipped_aspects[1] == &"gale_cut" and menu.feedback["reason"] == "ACTIVE RUNNING", "no ACTIVE RUNNING refusal: %s" % str(menu.feedback))
	arena.close_menu()
	check(arena.missing_frames.is_empty(), "missing frames: %s" % str(arena.missing_frames.keys()))


## The list shows LIST_ROWS whole rows: the arrows scroll it so the highlighted row stays in view, the mouse wheel scrolls it
## (pulling the highlight along), the scroll bar's thumb moves, and the 8th Aspect can be set by keyboard and by wheel + click.
func list_scroll() -> void:
	fixture()
	check(Aspects.ALL.size() == 8, "the list should hold 8 Aspects, not %d" % Aspects.ALL.size())
	check(arena.open_menu(), "open")
	menu.set_tab(Menu.TAB_GEAR)
	menu.gear_selection = &"aspect_slot_1"
	await menu_with("menu_accept")
	check(menu.list_open() and menu.list_scroll == 0, "the list opens at the top")
	check(menu.list_max_scroll() == Aspects.ALL.size() - Menu.LIST_ROWS, "8 Aspects need a scroll")
	for row: int in range(Menu.LIST_ROWS):
		check(Menu.CARD.encloses(Menu.list_row_rect(row)), "list row %d leaves the card" % row)
	var top_thumb: float = float(menu.scroll_bar()["thumb_y"])
	for i: int in range(Aspects.ALL.size() - 1):
		await menu_with("menu_down")
		check(menu.row_visible(menu.list_selection), "the highlighted row %d left the view" % menu.list_selection)
	check(menu.list_selection == Aspects.ALL.size() - 1 and menu.list_scroll == menu.list_max_scroll(), "down did not reach the 8th Aspect (%d, scroll %d)" % [menu.list_selection, menu.list_scroll])
	check(float(menu.scroll_bar()["thumb_y"]) > top_thumb and float(menu.scroll_bar()["thumb_y"]) + float(menu.scroll_bar()["thumb_h"]) <= Menu.TRACK_H, "the scroll thumb did not move down inside its track: %s" % str(menu.scroll_bar()))
	check(menu.list_ids()[menu.list_selection] == &"stone_ward", "the 8th row is Stone Ward")
	await save("list_scrolled")
	var tick: int = arena.core.tick
	await menu_with("menu_accept")
	check(arena.core.tick == tick + 1 and arena.snapshot.player.equipped_aspects[0] == &"stone_ward", "ENTER did not set Stone Ward in Z: %s" % str(arena.snapshot.player.equipped_aspects))
	for i: int in range(Aspects.ALL.size()):
		await menu_with("menu_up")
	check(menu.list_selection == 0 and menu.list_scroll == 0, "up did not scroll back to the top")
	menu.close_list()
	# the mouse wheel on socket X: scroll to the bottom, the highlight follows, then a click on Echo Step
	menu.open_aspect_list(2)
	check(menu.list_scroll == 0 and menu.list_selection == 1, "socket X opens on Gale Cut at the top")
	for i: int in range(8):
		var wheel: InputEventMouseButton = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		menu._input(wheel)
	check(menu.list_scroll == menu.list_max_scroll() and menu.row_visible(menu.list_selection), "the wheel did not scroll to the bottom with the highlight (%d)" % menu.list_scroll)
	var echo: int = menu.list_ids().find(&"echo_step")
	check(menu.row_visible(echo), "Echo Step is not visible after the wheel")
	menu.click(Menu.list_row_rect(echo - menu.list_scroll).get_center())
	check(arena.snapshot.player.equipped_aspects[1] == &"echo_step", "a click after the wheel did not set Echo Step: %s" % str(arena.snapshot.player.equipped_aspects))
	var wheel_up: InputEventMouseButton = InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	menu._input(wheel_up)
	check(menu.list_scroll == menu.list_max_scroll() - 1, "the wheel up did not scroll one row")
	# Sprint into C by keyboard from Moon Cleave
	menu.close_list()
	menu.open_aspect_list(3)
	for i: int in range(Aspects.ALL.find(&"sprint") - Aspects.ALL.find(&"moon_cleave")):
		await menu_with("menu_down")
	await menu_with("menu_accept")
	check(same(arena.snapshot.player.equipped_aspects, [&"stone_ward", &"echo_step", &"sprint"]), "the three new Aspects are not set: %s" % str(arena.snapshot.player.equipped_aspects))
	var rows: Array[Dictionary] = Hud.skill_rows(arena.snapshot.hud)
	check(rows[0]["icon"] == "ui_aspect_stone_ward_1" and rows[1]["icon"] == "ui_aspect_echo_step_1" and rows[2]["icon"] == "ui_aspect_sprint_1", "HUD icons of the new Aspects: %s" % str(rows.map(func(r: Dictionary) -> String: return r["icon"])))
	# their descriptions carry the real numbers
	var d: Dictionary = Menu.descriptions(Tuning.WEAPON_BLACK_KATANA, arena.snapshot.player.equipped_aspects)
	check(String(d[&"sprint"][2][0]).contains("X2") and String(d[&"sprint"][2][2]).contains("%d EDGE" % int(Tuning.SPRINT_EDGE_COST)) and String(d[&"sprint"][2][2]).contains("CD 12 S"), "sprint description: %s" % str(d[&"sprint"]))
	check(String(d[&"echo_step"][2][0]).contains("2 S") and String(d[&"echo_step"][2][2]).contains("12 TICKS") and String(d[&"echo_step"][2][2]).contains("CD 14 S"), "echo description: %s" % str(d[&"echo_step"]))
	check(String(d[&"stone_ward"][2][1]).contains("60") and String(d[&"stone_ward"][2][1]).contains("64 PX") and String(d[&"stone_ward"][2][2]).contains("WAVE 8 + STORED"), "ward description: %s" % str(d[&"stone_ward"]))
	check(d[&"stone_ward"][1] == "ASPECT  KEY Z" and d[&"sprint"][1] == "ASPECT  KEY C", "the new Aspects' tags follow their sockets")
	await save("new_three")
	arena.close_menu()
	fixture()


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
	check(Hud.aspect_hint_rect().end.x <= 384 and Hud.aspect_hint_rect().end.y <= Hud.aspect_rects()[1].position.y + 30, "tooltip rect")
	# the menu: its frame, card and tabs are the editable scenes; the fight's HUD under it is hidden
	check(arena.open_menu(), "open")
	observe()
	await process_frame
	check(menu.shell != null and menu.shell.visible and menu.shell.get_node("Panel") is NinePatchRect and menu.shell.get_node("Card") is NinePatchRect and menu.card_scene.visible and menu.hero_scene.visible, "the menu does not show its frame, card and HERO scenes")
	check(arena.hud.arena_strip == null or not arena.hud.arena_strip.visible, "the fight's HUD strip shows under the open menu")
	await save("hero")
	for t: int in [Menu.TAB_GEAR, Menu.TAB_QUESTS]:
		menu.set_tab(t)
		await process_frame
		check(menu.gear_scene.visible == (t == Menu.TAB_GEAR) and menu.quests_scene.visible == (t == Menu.TAB_QUESTS) and not menu.hero_scene.visible, "tab %d shows the wrong scenes" % t)
		await save(Menu.TAB_NAMES[t].to_lower())
	arena.close_menu()
	observe()
	check(arena.hud.arena_strip != null and arena.hud.arena_strip.visible, "the HUD strip does not come back after the menu")
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
		check(arena.hud.result_node != null and arena.hud.result_node.visible and arena.hud.result_node.get_node("Panel") is NinePatchRect, "the %s panel is not the result_panel.tscn scene" % result)
		var rect: Rect2 = Hud.result_panel_rect(arena.hud.result_lines.size(), true)
		check(rect.position.y - 8 >= 0 and rect.end.y <= 216, "%s panel off screen: %s" % [result, rect])
		await save(String(result))
	arena.hud.result_lines = []
	arena.hud.result_hint = ""
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
	await aspect_list()
	await list_scroll()
	await saved_loadout()
	await hud_contract()
	await shared_frame()
	arena.queue_free()
	await process_frame
	for message: String in failures:
		printerr("CHARACTER MENU FAIL: " + message)
	print("CHARACTER MENU SMOKE OK" if failures.is_empty() else "CHARACTER MENU SMOKE FAILED")
	quit(0 if failures.is_empty() else 1)
