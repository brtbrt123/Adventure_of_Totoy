extends Node2D
## The character menu (TAB), redesigned with the owner on 2026-11-03 (mockups: presentation/review/menu_redesign/): a pop-up
## over the frozen world with three tabs. HERO: Totoy, his level and EXP, the stat points to spend and Respec. GEAR: the
## weapon, the Aspect sockets Z X C and the item slots 1 2. QUESTS: the chapter's tasks. Every tab has its content on the left
## and the detail card on the right, which always describes what is selected; choosing a weapon or an Aspect happens in that
## card, as a short list that scrolls. The road (explore_scene.gd) and the boss fight (arena.gd) both use it: in the boss
## fight HERO has no stat points (the fight runs on base stats) and QUESTS shows the fight's goal.
##
## Presentation only: it shows snapshot data and numbers read (read-only) from core/tuning.gd, core/weapons.gd,
## core/aspects.gd and the quest book. Its four actions are requests its owner sends to the core: equip a weapon
## (`equip_request`), set an Aspect in a socket (`aspect_request`), spend a stat point (`stat_request`) and take every point
## back (`respec_request`). The core decides; the menu reads the result from the snapshot (EQUIPPED or NOT NOW).
##
## The drawing is the editable scenes presentation/ui/menu_shell.tscn (frame, tabs, the card's frame, footer),
## menu_hero.tscn, menu_gear.tscn, menu_quests.tscn and menu_card.tscn (the card's text and lists); this script fills them in
## and draws only the teal selection corners on top.
##
## Controls: TAB (gamepad Back) opens and closes, ESC closes (or only the card's list when one is open), Q/E (shoulders) or a
## click on a tab switches tabs, arrows/WASD move the selection, ENTER/click acts on it (add a point, Respec, open the weapon
## or Aspect list, equip from the list), the mouse wheel scrolls a list, and moving the mouse over something selects it.
## The owner of the menu does not step the core while it is open, except once per request.
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Aspects := preload("res://core/aspects.gd")
const QuestBook := preload("res://core/quest_book.gd")
const ExploreCore := preload("res://core/explore_core.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const MenuShell := preload("res://presentation/ui/menu_shell.tscn")
const MenuHero := preload("res://presentation/ui/menu_hero.tscn")
const MenuGear := preload("res://presentation/ui/menu_gear.tscn")
const MenuQuests := preload("res://presentation/ui/menu_quests.tscn")
const MenuCard := preload("res://presentation/ui/menu_card.tscn")

const TAB_HERO: int = 0
const TAB_GEAR: int = 1
const TAB_QUESTS: int = 2
const TAB_NAMES: Array[String] = ["HERO", "GEAR", "QUESTS"]
## The tab plates (menu_shell.tscn Tab0..Tab2) and the detail card (menu_shell.tscn Card), in the game's 384x216 pixels.
const TAB_RECTS: Array[Rect2] = [Rect2(14, 9, 60, 16), Rect2(78, 9, 54, 16), Rect2(136, 9, 64, 16)]
const CARD: Rect2 = Rect2(232, 32, 136, 162)
const STAT_IDS: Array[StringName] = [&"vitality", &"might", &"agility"]
const STAT_KEYS: Array[StringName] = [&"stat_vitality", &"stat_might", &"stat_agility"]
const ASPECT_KEYS: Array[StringName] = [&"aspect_slot_1", &"aspect_slot_2", &"aspect_slot_3"]
const ITEM_KEYS: Array[StringName] = [&"item_1", &"item_2"]
const SLOT_LETTERS: Array[String] = ["Z", "X", "C"]
## The card's list: LIST_ROWS rows in view (menu_card.tscn ListRow0..2), more scroll; the scroll bar's track (Track) height.
const LIST_ROWS: int = 3
const LIST_TOP: float = 64.0
const LIST_STEP: float = 18.0
const TRACK_H: float = 53.0
const FEEDBACK_SECONDS: float = 1.6
const VILLAGE: StringName = &"village_layered"
const UNARMED_FIGURE: String = "totoy_unarmed_idle_right_1"
const KATANA_GLYPH: String = "ui_weapon_totoy_blade_1"
const HERB_ICON: String = "hud_copper_herb"
## The inner 32x32 of a 48 px weapon medallion (its picture without the ring), for the small weapon icons.
const MEDALLION_INNER: Rect2 = Rect2(8, 8, 32, 32)
const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")
const DIM: Color = Color("5a625e")
const TEAL: Color = Color("6aa89a")
const LILAC: Color = Color("8a6fa8")
const WARN: Color = Color("c28a6c")

const WEAPON_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "BLACK KATANA", Tuning.WEAPON_DUAL_DAGGER: "DUAL DAGGER", Tuning.WEAPON_CHAIN_SCYTHE: "CHAIN SCYTHE", Tuning.WEAPON_STAR_STAFF: "STAR STAFF"}
## The weapon's right-click active, by name.
const ACTIVE_ROW_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "BLACK FORM", Tuning.WEAPON_DUAL_DAGGER: "BARRAGE", Tuning.WEAPON_CHAIN_SCYTHE: "REAPER'S COIL", Tuning.WEAPON_STAR_STAFF: "DISINTEGRATION"}
## One word for how the weapon fights (the start of its description).
const WEAPON_TAGS: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "BALANCED", Tuning.WEAPON_DUAL_DAGGER: "FAST", Tuning.WEAPON_CHAIN_SCYTHE: "WIDE SWEEPS", Tuning.WEAPON_STAR_STAFF: "RANGED CASTS"}

## Set by the road (the exploration snapshot: level, stats, quests, items); null in the boss fight.
var progression: ExploreCore.ExploreSnapshot
## The fight's snapshot (the road passes its loadout core's): the weapon and the Aspects in the sockets.
var snapshot: Snapshots.GameSnapshot
var atlas: Texture2D
var frames: Dictionary = {}
## Called with a weapon id; the owner steps the core once with InputFrame.weapon_equip.
var equip_request: Callable = Callable()
## Called with (aspect id, socket 1-3); the owner steps the core once with InputFrame.aspect_equip / aspect_equip_slot.
var aspect_request: Callable = Callable()
## Called with a stat id (the road only).
var stat_request: Callable = Callable()
## Called with nothing (the road only, in Lanternfen).
var respec_request: Callable = Callable()
var is_open: bool = false
var tab: int = TAB_HERO
## The selected thing on HERO (a STAT_KEYS entry or &"respec") and on GEAR (&"weapon", an ASPECT_KEYS or ITEM_KEYS entry).
var hero_selection: StringName = STAT_KEYS[0]
var gear_selection: StringName = &"weapon"
## The card's list: &"weapons" or &"aspects" while it shows one, else &"". `list_slot` is the socket (1-3) the Aspect list
## fills; `list_selection` the highlighted entry of list_ids(); `list_scroll` the first one in view.
var list_kind: StringName = &""
var list_slot: int = 0
var list_selection: int = 0
var list_scroll: int = 0
## After a request from a list: {ok, reason, left}; shown in the card under its title.
var feedback: Dictionary = {}
## A short refusal shown in the card ("SOCKET LOCKED", "ONLY IN LANTERNFEN"), for FEEDBACK_SECONDS.
var notice: String = ""
var notice_left: float = 0.0
var shell: Control = null
var hero_scene: Control = null
var gear_scene: Control = null
var quests_scene: Control = null
var card_scene: Control = null
var _last_mouse: Vector2 = Vector2(-1000, -1000)
static var _book: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	shell = MenuShell.instantiate()
	add_child(shell)
	hero_scene = MenuHero.instantiate()
	add_child(hero_scene)
	gear_scene = MenuGear.instantiate()
	add_child(gear_scene)
	quests_scene = MenuQuests.instantiate()
	add_child(quests_scene)
	card_scene = MenuCard.instantiate()
	add_child(card_scene)


func _enter_tree() -> void:
	add_to_group(&"mouse_cursor_menus")


func open() -> void:
	is_open = true
	visible = true
	tab = TAB_HERO
	hero_selection = STAT_KEYS[0]
	gear_selection = &"weapon"
	if progression != null and String(progression.objective.get("id", "")) == "edda_equip":
		tab = TAB_GEAR  # Edda's lesson: setting Sprint in socket Z is the task, so the menu opens there
		gear_selection = ASPECT_KEYS[0]
	close_list()
	notice = ""
	_last_mouse = get_local_mouse_position()
	queue_redraw()


func close() -> void:
	is_open = false
	visible = false
	close_list()
	notice = ""


func _process(delta: float) -> void:
	if not is_open:
		return
	if not feedback.is_empty():
		feedback["left"] = float(feedback["left"]) - delta
		if float(feedback["left"]) <= 0.0:
			feedback = {}
	if notice_left > 0.0:
		notice_left -= delta
		if notice_left <= 0.0:
			notice = ""
	var mouse: Vector2 = get_local_mouse_position()
	if mouse.distance_squared_to(_last_mouse) > 0.01:
		_last_mouse = mouse
		hover_at(mouse)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: MouseButton = (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_LEFT:
			click(get_local_mouse_position())
			get_viewport().set_input_as_handled()
		elif (button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN) and list_open():
			scroll_list(-1 if button == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()


## Keyboard / gamepad, once per physics frame while open (the owner calls it instead of stepping the core).
## TAB and ESC close the menu (returns false then); ESC with a list open closes only the list.
func poll_input() -> bool:
	if Input.is_action_just_pressed("menu_toggle"):
		close()
		return false
	if Input.is_action_just_pressed("menu_back"):
		if list_open():
			close_list()
			queue_redraw()
			return true
		close()
		return false
	if Input.is_action_just_pressed("menu_tab_prev"):
		switch_tab(-1)
	elif Input.is_action_just_pressed("menu_tab_next"):
		switch_tab(1)
	var move: Vector2i = Vector2i.ZERO
	if Input.is_action_just_pressed("menu_left"):
		move = Vector2i.LEFT
	elif Input.is_action_just_pressed("menu_right"):
		move = Vector2i.RIGHT
	elif Input.is_action_just_pressed("menu_up"):
		move = Vector2i.UP
	elif Input.is_action_just_pressed("menu_down"):
		move = Vector2i.DOWN
	if move != Vector2i.ZERO:
		move_selection(move)
	if Input.is_action_just_pressed("menu_accept"):
		accept()
	return true


func switch_tab(delta: int) -> void:
	set_tab(posmod(tab + delta, TAB_NAMES.size()))


func set_tab(index: int) -> void:
	tab = clampi(index, 0, TAB_NAMES.size() - 1)
	close_list()
	notice = ""
	queue_redraw()


# --- where things are (the scenes' layout; change these with the scenes) ---------------------------------------------

static func tab_rect(index: int) -> Rect2:
	return TAB_RECTS[index]


## HERO: a stat row, its "+" button and Respec (menu_hero.tscn Row0..2, Row*/Plus, Respec).
static func row_rect(index: int) -> Rect2:
	return Rect2(18, 85 + index * 25, 206, 23)


static func plus_rect(index: int) -> Rect2:
	return Rect2(200, 89 + index * 25, 16, 15)


static func respec_rect() -> Rect2:
	return Rect2(20, 170, 58, 16)


## GEAR: the weapon socket, an Aspect socket and an item slot with room for the selection corners (menu_gear.tscn).
static func weapon_rect() -> Rect2:
	return Rect2(20, 44, 52, 56)


static func socket_rect(index: int) -> Rect2:
	return Rect2(19 + index * 44, 114, 43, 49)


static func item_rect(index: int) -> Rect2:
	return Rect2(160 + index * 34, 118, 34, 34)


## The card's list row `index` places below the first row in view (menu_card.tscn ListRow0..2).
static func list_row_rect(index: int) -> Rect2:
	return Rect2(CARD.position.x + 7, LIST_TOP + index * LIST_STEP, 116, LIST_STEP - 1)


# --- selection -------------------------------------------------------------------------------------------------------

## The selected thing on the open tab (&"" on QUESTS, which has nothing to choose).
func selection() -> StringName:
	if tab == TAB_HERO:
		return hero_selection
	if tab == TAB_GEAR:
		return gear_selection
	return &""


func _select(key: StringName) -> void:
	if key != selection():
		notice = ""
	if tab == TAB_HERO:
		hero_selection = key
	elif tab == TAB_GEAR:
		gear_selection = key


## Every selectable thing of the open tab with its rect.
func items() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if tab == TAB_HERO and progression != null:
		for i: int in 3:
			list.append({"key": STAT_KEYS[i], "rect": row_rect(i)})
		list.append({"key": &"respec", "rect": respec_rect()})
	elif tab == TAB_GEAR:
		list.append({"key": &"weapon", "rect": weapon_rect()})
		for i: int in 3:
			list.append({"key": ASPECT_KEYS[i], "rect": socket_rect(i)})
		for i: int in 2:
			list.append({"key": ITEM_KEYS[i], "rect": item_rect(i)})
	return list


## Arrow keys: in a list up and down; otherwise the nearest thing in that direction.
func move_selection(direction: Vector2i) -> void:
	if list_open():
		if direction.y != 0:
			list_selection = clampi(list_selection + direction.y, 0, maxi(0, list_ids().size() - 1))
			feedback = {}
			_scroll_to_selection()
		queue_redraw()
		return
	var choices: Array[Dictionary] = items()
	if choices.is_empty():
		return
	var current: Rect2 = Rect2()
	for item: Dictionary in choices:
		if item["key"] == selection():
			current = item["rect"]
	if current.size == Vector2.ZERO:
		_select(choices[0]["key"])
		queue_redraw()
		return
	var from: Vector2 = current.get_center()
	var dir: Vector2 = Vector2(direction)
	var best: StringName = selection()
	var best_score: float = INF
	for item: Dictionary in choices:
		if item["key"] == selection():
			continue
		var offset: Vector2 = Rect2(item["rect"]).get_center() - from
		var along: float = offset.dot(dir)
		if along <= 0.5:
			continue
		var across: float = absf(offset.dot(Vector2(-dir.y, dir.x)))
		var score: float = along + across * 3.0
		if score < best_score:
			best_score = score
			best = item["key"]
	_select(best)
	queue_redraw()


## The mouse over something selects it (a list row in a list).
func hover_at(pos: Vector2) -> void:
	if list_open():
		for row: int in range(LIST_ROWS):
			var index: int = list_scroll + row
			if index < list_ids().size() and list_row_rect(row).has_point(pos):
				if index != list_selection:
					feedback = {}
				list_selection = index
		return
	for item: Dictionary in items():
		if Rect2(item["rect"]).has_point(pos):
			_select(item["key"])


## A left click: a tab switches the tab; a list row is chosen; outside the card a click closes the list. A stat's "+",
## Respec, the weapon socket and an Aspect socket act at once; anything else is only selected.
func click(pos: Vector2) -> void:
	for index: int in range(TAB_NAMES.size()):
		if tab_rect(index).has_point(pos):
			if index != tab:
				set_tab(index)
			return
	if list_open():
		for row: int in range(LIST_ROWS):
			var index: int = list_scroll + row
			if index < list_ids().size() and list_row_rect(row).has_point(pos):
				list_selection = index
				accept()
				return
		if not CARD.has_point(pos):
			close_list()
		return
	if tab == TAB_HERO and progression != null:
		for i: int in 3:
			if plus_rect(i).has_point(pos):
				_select(STAT_KEYS[i])
				accept()
				return
	for item: Dictionary in items():
		if Rect2(item["rect"]).has_point(pos):
			_select(item["key"])
			if item["key"] == &"respec" or item["key"] == &"weapon" or item["key"] in ASPECT_KEYS:
				accept()
			return


## ENTER: a stat point, Respec, open the weapon or Aspect list, or equip what the list highlights.
func accept() -> void:
	if list_open():
		var ids: Array[StringName] = list_ids()
		if list_selection >= 0 and list_selection < ids.size():
			if list_kind == &"weapons":
				_equip_weapon(ids[list_selection])
			else:
				_equip_aspect(ids[list_selection])
		return
	if tab == TAB_HERO and progression != null:
		if hero_selection == &"respec":
			if can_respec():
				if respec_request.is_valid():
					respec_request.call()
			else:
				_notice("ONLY IN LANTERNFEN" if progression.scene_id != VILLAGE else "NO POINTS TO TAKE BACK")
		else:
			var stat: StringName = STAT_IDS[maxi(0, STAT_KEYS.find(hero_selection))]
			if can_add(stat):
				if stat_request.is_valid():
					stat_request.call(stat)
			else:
				_notice("NO POINTS TO SPEND" if progression.stat_points_unspent <= 0 else "%s IS FULL" % String(stat).to_upper())
		queue_redraw()
		return
	if tab == TAB_GEAR:
		if gear_selection == &"weapon":
			open_weapon_list()
		elif gear_selection in ASPECT_KEYS:
			open_aspect_list(ASPECT_KEYS.find(gear_selection) + 1)
	queue_redraw()


func _notice(text: String) -> void:
	notice = text
	notice_left = FEEDBACK_SECONDS


# --- the card's lists ------------------------------------------------------------------------------------------------

func list_open() -> bool:
	return list_kind != &""


## The weapons, or the Aspects he owns (in the game's order), that the open list offers.
func list_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if list_kind == &"weapons":
		ids.append_array(Weapons.IDS)
	elif list_kind == &"aspects":
		for aspect: StringName in Aspects.ALL:
			if aspect_owned(aspect):
				ids.append(aspect)
	return ids


## Opens the weapon list with the equipped weapon highlighted (not before he has a weapon).
func open_weapon_list() -> void:
	if not armed():
		_notice("NO WEAPON YET")
		return
	list_kind = &"weapons"
	list_slot = 0
	list_selection = maxi(0, Weapons.IDS.find(_equipped()))
	list_scroll = 0
	feedback = {}
	_scroll_to_selection()
	queue_redraw()


## Opens the Aspect list for socket 1-3 with the Aspect already there highlighted (not on a locked socket).
func open_aspect_list(slot: int) -> void:
	if not socket_open(slot):
		_notice("SOCKET LOCKED")
		queue_redraw()
		return
	list_kind = &"aspects"
	list_slot = clampi(slot, 1, 3)
	list_selection = maxi(0, list_ids().find(slot_aspect(list_slot)))
	list_scroll = 0
	feedback = {}
	_scroll_to_selection()
	queue_redraw()


func close_list() -> void:
	list_kind = &""
	list_slot = 0
	list_selection = 0
	list_scroll = 0
	feedback = {}


## The largest scroll offset (0 when every entry fits).
func list_max_scroll() -> int:
	return maxi(0, list_ids().size() - LIST_ROWS)


## True when list entry `index` is in view (only those are drawn, hovered or clicked).
func row_visible(index: int) -> bool:
	return index >= list_scroll and index < list_scroll + LIST_ROWS


## Keeps the highlighted entry in view (keyboard moves and opening).
func _scroll_to_selection() -> void:
	if list_selection < list_scroll:
		list_scroll = list_selection
	elif list_selection >= list_scroll + LIST_ROWS:
		list_scroll = list_selection - LIST_ROWS + 1
	list_scroll = clampi(list_scroll, 0, list_max_scroll())


## Mouse wheel: scrolls by whole rows; the highlighted entry is pulled along so it never leaves the view.
func scroll_list(delta: int) -> void:
	if not list_open():
		return
	list_scroll = clampi(list_scroll + delta, 0, list_max_scroll())
	list_selection = clampi(list_selection, list_scroll, list_scroll + LIST_ROWS - 1)
	feedback = {}
	queue_redraw()


## The scroll bar's thumb inside the track: {thumb_y, thumb_h}, or {} when everything fits.
func scroll_bar() -> Dictionary:
	var count: int = list_ids().size()
	if count <= LIST_ROWS:
		return {}
	var height: float = maxf(4.0, roundf(TRACK_H * LIST_ROWS / count))
	return {"thumb_y": roundf((TRACK_H - height) * list_scroll / maxi(1, list_max_scroll())), "thumb_h": height}


## One core step with weapon_equip; the result is read from the snapshot. The weapon already in hand sends nothing.
func _equip_weapon(weapon: StringName) -> void:
	if weapon != _equipped() and equip_request.is_valid():
		equip_request.call(weapon)
	if not is_open:
		return  # the step ended the fight and its owner closed the menu
	var ok: bool = _equipped() == weapon
	feedback = {"ok": ok, "reason": "" if ok else refusal_reason(snapshot), "left": FEEDBACK_SECONDS}
	queue_redraw()


## One core step with aspect_equip + aspect_equip_slot (the core swaps when the Aspect sits in another socket); the result
## is read from the snapshot. The Aspect already in the socket sends nothing in the boss fight.
func _equip_aspect(aspect: StringName) -> void:
	if not aspect_owned(aspect):
		return
	if (progression != null or aspect != slot_aspect(list_slot)) and aspect_request.is_valid():
		aspect_request.call(aspect, list_slot)
	if not is_open:
		return
	var ok: bool = slot_aspect(list_slot) == aspect
	feedback = {"ok": ok, "reason": "" if ok else aspect_refusal_reason(snapshot), "left": FEEDBACK_SECONDS}
	queue_redraw()


# --- facts from the snapshots ----------------------------------------------------------------------------------------

## The slotted Aspects (Z, X, C) from the snapshot.
func equipped_aspects() -> Array[StringName]:
	var list: Array[StringName] = []
	if snapshot != null and snapshot.player != null and snapshot.player.equipped_aspects.size() == 3:
		list.append_array(snapshot.player.equipped_aspects)
	else:
		list.append_array(Aspects.DEFAULT_EQUIPPED)
	return list


func slot_aspect(slot: int) -> StringName:
	var list: Array[StringName] = equipped_aspects()
	return list[slot - 1] if slot >= 1 and slot <= list.size() else &""


## The socket (1-3) holding `aspect`, 0 when it is not in one.
func aspect_slot_of(aspect: StringName) -> int:
	return equipped_aspects().find(aspect) + 1


func aspect_owned(aspect: StringName) -> bool:
	return progression == null or progression.owned_aspects.has(aspect)


func _equipped() -> StringName:
	return snapshot.player.weapon_id if snapshot != null and snapshot.player != null else Tuning.WEAPON_BLACK_KATANA


## On the road he is unarmed until Tovan gives him the Black Katana; in the boss fight he is always armed.
func armed() -> bool:
	return progression == null or progression.armed


## Socket 1-3 may be filled: always in the boss fight; on the road once unlocked, and socket 1 during Edda's binding lesson.
func socket_open(slot: int) -> bool:
	if progression == null:
		return true
	if slot >= 1 and slot <= progression.aspect_slots.size() and bool(progression.aspect_slots[slot - 1].get("unlocked", false)):
		return true
	return slot == 1 and String(progression.objective.get("id", "")) == "edda_equip"


func can_add(stat: StringName) -> bool:
	return progression != null and progression.stat_points_unspent > 0 and int(progression.stats.get(stat, 0)) < int(progression.stat_caps.get(stat, 0))


func points_spent() -> int:
	var total: int = 0
	if progression != null:
		for stat: StringName in STAT_IDS:
			total += int(progression.stats.get(stat, 0))
	return total


## Respec is free and only in Lanternfen, when points have been spent.
func can_respec() -> bool:
	return progression != null and progression.scene_id == VILLAGE and points_spent() > 0


## Why the core most likely refused an Aspect (display text from snapshot facts; Aspects have no lockout).
static func aspect_refusal_reason(snap: Snapshots.GameSnapshot) -> String:
	if snap != null and snap.player.weapon_buff_active:
		return "ACTIVE RUNNING"
	return "TRY WHEN IDLE"


## Why the core most likely refused a weapon (display text from snapshot facts; the core made the decision).
static func refusal_reason(snap: Snapshots.GameSnapshot) -> String:
	if snap == null:
		return "TRY WHEN IDLE"
	if snap.player.weapon_buff_active:
		return "ACTIVE RUNNING"
	if snap.hud.weapon_swap_lockout_ticks > 0:
		return "JUST SWAPPED"
	return "TRY WHEN IDLE"


## The equipped weapon's idle frame (the fight's frame sets).
static func figure_frame(weapon: StringName) -> String:
	var prefix: String = ArenaAnimation.SET_KATANA
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER: prefix = ArenaAnimation.SET_DAGGER
		Tuning.WEAPON_CHAIN_SCYTHE: prefix = ArenaAnimation.SET_SCYTHE
		Tuning.WEAPON_STAR_STAFF: prefix = ArenaAnimation.SET_STAFF
	return ArenaAnimation.hero_frame(prefix, "idle", 1)


static func book() -> Dictionary:
	if _book.is_empty():
		_book = QuestBook.default_book()
	return _book


# --- numbers and texts (read from core/tuning.gd and core/weapons.gd) ------------------------------------------------

static func secs(ticks: float, digits: int = 2) -> String:
	var text: String = ("%." + str(digits) + "f") % (ticks / 60.0)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text


static func num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x


static func weapon_data(weapon: StringName) -> Dictionary:
	var combo: int = Weapons.combo_max(weapon)
	var swing_ticks: Array[int] = []
	var combo_ticks: int = 0
	var damage: Array[float] = []
	var reach: Array[float] = []
	for i: int in range(combo):
		var phases: Array[int] = Weapons.swing_phases(weapon, i + 1)
		var total: int = phases[0] + phases[1] + phases[2]
		swing_ticks.append(total)
		combo_ticks += total
		damage.append(roundi(Tuning.ATTACK_DAMAGE * Weapons.damage_mults(weapon)[i] * 100) / 100.0)
		reach.append(Tuning.STAFF_BURST_RANGE if Weapons.is_ranged(weapon) else Tuning.ATTACK_RANGE * Weapons.range_mults(weapon)[i])  # the staff casts at range
	return {"name": WEAPON_NAMES.get(weapon, "WEAPON"), "combo": combo, "swing_ticks": swing_ticks, "combo_ticks": combo_ticks, "damage": damage, "reach": reach, "edge": Weapons.edge_per_hit(weapon), "arc_deg": rad_to_deg(acos(Weapons.arc_dot(weapon))), "cost": Weapons.active_edge_cost(weapon), "cd": Weapons.active_cooldown(weapon)}


static func damage_text(w: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for d: float in w["damage"]:
		parts.append(num(d))
	return "/".join(parts)


static func reach_text(w: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var distinct: Dictionary = {}
	for r: float in w["reach"]:
		parts.append(str(roundi(r)))
		distinct[roundi(r)] = true
	return "/".join(parts) if distinct.size() > 1 else parts[0]



static func aspect_tag(aspect: StringName, aspects: Array) -> String:
	var index: int = aspects.find(aspect)
	return "ASPECT  KEY %s" % SLOT_LETTERS[index] if index >= 0 and index < 3 else "ASPECT"


## The description of every weapon and Aspect: key -> [title, tag, [body line, body line, numbers line]]. The weapon tags
## say which one is `equipped`; the Aspects' tags follow the slotted `aspects` (Z, X, C).
static func descriptions(equipped: StringName, aspects: Array = Aspects.DEFAULT_EQUIPPED) -> Dictionary:
	var kat: Dictionary = weapon_data(Tuning.WEAPON_BLACK_KATANA)
	var dag: Dictionary = weapon_data(Tuning.WEAPON_DUAL_DAGGER)
	var scy: Dictionary = weapon_data(Tuning.WEAPON_CHAIN_SCYTHE)
	var barrage_slashes: int = Weapons.barrage_slashes()
	var barrage_ticks: int = Weapons.barrage_total_ticks()
	var move_px_s: float = Tuning.PLAYER_SPEED * 60.0
	var spin_damage: String = num(Tuning.ATTACK_DAMAGE * Tuning.REAPER_COIL_SPIN_DAMAGE_MULT)
	var d: Dictionary = {}
	d[&"breaking_edge"] = ["BREAKING EDGE", aspect_tag(&"breaking_edge", aspects), [
		"RIGHT AFTER A SUCCESSFUL PARRY: STEP IN %s PX AND STRIKE." % num(Tuning.BREAKING_EDGE_STEP),
		"HEAVY POSTURE DAMAGE: TWO OF THEM BREAK THE COLOSSUS.",
		"%s EDGE  %s S AFTER A PARRY  %s DMG  %s POSTURE" % [num(Tuning.BREAKING_EDGE_EDGE_COST), secs(Tuning.BREAKING_EDGE_WINDOW_TICKS), num(Tuning.BREAKING_EDGE_DAMAGE), num(Tuning.BREAKING_EDGE_POSTURE)]]]
	d[&"gale_cut"] = ["GALE CUT", aspect_tag(&"gale_cut", aspects), [
		"AIMED DASH-SLASH: HITS ALL IN A %s PX CORRIDOR AND" % num(Tuning.GALE_CUT_DISTANCE),
		"PASSES THROUGH THE BOSS. IT GIVES NO INVULNERABILITY.",
		"%s EDGE  CD %s S  %s DMG  %s POSTURE  %s PX WIDE" % [num(Tuning.GALE_CUT_EDGE_COST), secs(Tuning.GALE_CUT_COOLDOWN_TICKS), num(Tuning.GALE_CUT_DAMAGE), num(Tuning.GALE_CUT_POSTURE), num(Tuning.GALE_CUT_LANE_WIDTH)]]]
	d[&"moon_cleave"] = ["MOON CLEAVE", aspect_tag(&"moon_cleave", aspects), [
		"HOLD %s S, THEN RELEASE A CRESCENT WAVE THAT FLIES" % secs(Tuning.MOON_CLEAVE_WINDUP_TICKS),
		"%s PX AND PIERCES. GETTING HIT DURING THE HOLD CANCELS IT." % num(Tuning.MOON_CLEAVE_TRAVEL),
		"%s EDGE  CD %s S  %s DMG  %s POSTURE" % [num(Tuning.MOON_CLEAVE_EDGE_COST), secs(Tuning.MOON_CLEAVE_COOLDOWN_TICKS), num(Tuning.MOON_CLEAVE_DAMAGE), num(Tuning.MOON_CLEAVE_POSTURE)]]]
	d[&"spirit_lantern"] = ["SPIRIT LANTERN", aspect_tag(&"spirit_lantern", aspects), [
		"SET A LANTERN AT YOUR FEET FOR %s S. IT PULSES EVERY %s S:" % [secs(Tuning.SPIRIT_LANTERN_DURATION_TICKS), secs(Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS)],
		"STAND IN ITS %s PX LIGHT TO HEAL AND GAIN EDGE. ONE AT A TIME." % num(Tuning.SPIRIT_LANTERN_RADIUS),
		"%s EDGE  CD %s S  %d PULSES  +%d HP  +%s EDGE EACH" % [num(Tuning.SPIRIT_LANTERN_EDGE_COST), secs(Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS), Tuning.SPIRIT_LANTERN_PULSES, Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE, num(Tuning.SPIRIT_LANTERN_EDGE_PER_PULSE)]]]
	d[&"phantom_cut"] = ["PHANTOM CUT", aspect_tag(&"phantom_cut", aspects), [
		"FOR %s S A PHANTOM REPEATS EVERY SWING THAT LANDS, %s S LATER," % [secs(Tuning.PHANTOM_CUT_DURATION_TICKS), secs(Tuning.PHANTOM_CUT_DELAY_TICKS)],
		"FOR %d%% OF ITS DAMAGE. NO ANIMATION LOCK: USE IT MID-SWING." % roundi(Tuning.PHANTOM_CUT_DAMAGE_MULT * 100),
		"%s EDGE  CD %s S FROM ACTIVATION  ECHO %d%% DMG  %d%% POSTURE" % [num(Tuning.PHANTOM_CUT_EDGE_COST), secs(Tuning.PHANTOM_CUT_COOLDOWN_TICKS), roundi(Tuning.PHANTOM_CUT_DAMAGE_MULT * 100), roundi(Tuning.PHANTOM_CUT_POSTURE_MULT * 100)]]]
	d[&"sprint"] = ["SPRINT", aspect_tag(&"sprint", aspects), [
		"FOR %s S YOU MOVE X%s AS FAST: WALKING, SWINGING, WARDING." % [secs(Tuning.SPRINT_DURATION_TICKS), num(Tuning.SPRINT_MOVE_SPEED_MULT)],
		"NO ANIMATION LOCK: USE IT ANY TIME. DASHES KEEP THEIR SPEED.",
		"%s EDGE  CD %s S FROM ACTIVATION  %s PX/S" % [num(Tuning.SPRINT_EDGE_COST), secs(Tuning.SPRINT_COOLDOWN_TICKS), num(move_px_s * Tuning.SPRINT_MOVE_SPEED_MULT)]]]
	d[&"echo_step"] = ["ECHO STEP", aspect_tag(&"echo_step", aspects), [
		"LEAVE AN ECHO WHERE YOU STAND. %s S LATER YOU ARE PULLED BACK" % secs(Tuning.ECHO_STEP_DELAY_TICKS),
		"TO IT, CANCELLING WHAT YOU WERE DOING, AND CANNOT BE HIT BRIEFLY.",
		"%s EDGE  CD %s S  RECALL %s S  %s S (%d TICKS) INVULNERABLE" % [num(Tuning.ECHO_STEP_EDGE_COST), secs(Tuning.ECHO_STEP_COOLDOWN_TICKS), secs(Tuning.ECHO_STEP_DELAY_TICKS), secs(Tuning.ECHO_STEP_INVULN_TICKS), Tuning.ECHO_STEP_INVULN_TICKS]]]
	d[&"stone_ward"] = ["STONE WARD", aspect_tag(&"stone_ward", aspects), [
		"RAISE A STONE GUARD FOR %s S THAT BLOCKS EVERY HIT AND STORES" % secs(Tuning.STONE_WARD_DURATION_TICKS),
		"ITS DAMAGE (UP TO %d). THEN A %s PX SHOCKWAVE HITS BACK." % [Tuning.STONE_WARD_STORE_CAP, num(Tuning.STONE_WARD_RADIUS)],
		"%s EDGE  CD %s S  WAVE %s + STORED DMG  %s POSTURE" % [num(Tuning.STONE_WARD_EDGE_COST), secs(Tuning.STONE_WARD_COOLDOWN_TICKS), num(Tuning.STONE_WARD_BASE_DAMAGE), num(Tuning.STONE_WARD_POSTURE)]]]
	d[Tuning.WEAPON_BLACK_KATANA] = ["BLACK KATANA", "WEAPON  EQUIPPED" if equipped == Tuning.WEAPON_BLACK_KATANA else "WEAPON", [
		"BALANCED %d-HIT COMBO, %s DMG, REACH %s PX." % [kat["combo"], damage_text(kat), reach_text(kat)],
		"RMB BLACK FORM: %s S OF X%s ATTACK SPEED AND X%s DAMAGE." % [secs(Tuning.BLACK_KATANA_BUFF_DURATION_TICKS), num(Tuning.BLACK_KATANA_ATTACK_SPEED_MULT), num(Tuning.BLACK_KATANA_DAMAGE_MULT)],
		"FORM %s EDGE  CD %s S FROM ACTIVATION  +%s EDGE PER HIT" % [num(kat["cost"]), secs(kat["cd"]), num(kat["edge"])]]]
	d[Tuning.WEAPON_DUAL_DAGGER] = ["DUAL DAGGER", "WEAPON  EQUIPPED" if equipped == Tuning.WEAPON_DUAL_DAGGER else "WEAPON", [
		"FAST %d-HIT COMBO, %s DMG, SHORT REACH. HIT %d CALLS" % [dag["combo"], damage_text(dag), dag["combo"]],
		"SKY LIGHTNING (%s DMG). RMB LIGHTNING BARRAGE: %d BLINK SLASHES." % [num(Tuning.LIGHTNING_STRIKE_DAMAGE), barrage_slashes],
		"BARRAGE %s EDGE  CD %s S  %s S INVULNERABLE  +%s EDGE PER HIT" % [num(dag["cost"]), secs(dag["cd"]), secs(barrage_ticks), num(dag["edge"])]]]
	d[Tuning.WEAPON_CHAIN_SCYTHE] = ["CHAIN SCYTHE", "WEAPON  EQUIPPED" if equipped == Tuning.WEAPON_CHAIN_SCYTHE else "WEAPON", [
		"SLOW, WIDE %d-HIT SWEEPS THAT ALSO HIT TO THE SIDES, %s DMG." % [scy["combo"], damage_text(scy)],
		"RMB REAPER'S COIL: HOOK UP TO %s PX, DRAG THE BOSS IN, STUN, SPIN." % num(Tuning.REAPER_COIL_HOOK_RANGE),
		"COIL %s EDGE  CD %s S  STUN %s S  SPIN %d X %s DMG" % [num(scy["cost"]), secs(scy["cd"]), secs(Tuning.REAPER_COIL_STAGGER_TICKS), Tuning.REAPER_COIL_SPIN_HITS, spin_damage]]]
	var stf: Dictionary = weapon_data(Tuning.WEAPON_STAR_STAFF)
	d[Tuning.WEAPON_STAR_STAFF] = ["STAR STAFF", "WEAPON  EQUIPPED" if equipped == Tuning.WEAPON_STAR_STAFF else "WEAPON", [
		"CASTS AT RANGE (%s PX): %d BURSTS, %s DMG TO ALL IN THE BLAST." % [num(Tuning.STAFF_BURST_RANGE), stf["combo"], damage_text(stf)],
		"THE THIRD IS THE GREAT BURST. DASH: A SHORT BLINK. RMB DISINTEGRATION.",
		"RMB %s EDGE  CD %s S  BLAST %s/%s PX  +%s EDGE PER HIT" % [num(stf["cost"]), secs(stf["cd"]), num(Tuning.STAFF_BURST_RADIUS[0]), num(Tuning.STAFF_BURST_RADIUS[2]), num(stf["edge"])]]]
	return d


## A weapon's small icon: [atlas frame, crop] (a medallion's inner picture, or the katana's glyph).
static func weapon_icon(weapon: StringName) -> Array:
	if Hud.MEDALLIONS.has(weapon):
		return [Hud.MEDALLIONS[weapon], MEDALLION_INNER]
	return [KATANA_GLYPH, Rect2()]


## What his points give him now ([name, value, what one more point of the selected stat adds]): health, damage, dash
## cooldown, walking speed and Edge. The boss fight shows the base numbers.
func stat_lines() -> Array:
	var hp: int = Tuning.PLAYER_MAX_HP
	var might: int = 0
	var agility: int = 0
	if progression != null:
		hp = progression.hero.max_hp
		might = int(progression.stats.get(&"might", 0))
		agility = int(progression.stats.get(&"agility", 0))
	elif snapshot != null and snapshot.player != null:
		hp = snapshot.player.max_hp
	var dash: int = Tuning.DASH_COOLDOWN_TICKS - Tuning.AGILITY_DASH_COOLDOWN_TICKS_PER_POINT * mini(agility, Tuning.AGILITY_DASH_POINTS)
	var speed: float = Tuning.PLAYER_SPEED * 60.0 * (1.0 + Tuning.AGILITY_SPEED_PER_POINT * agility)
	var lines: Array = [
		["HEALTH", str(hp), ""],
		["DAMAGE", "+%d%%" % roundi(Tuning.MIGHT_DAMAGE_PER_POINT * 100.0 * might), ""],
		["DASH COOLDOWN", "%s S" % secs(dash), ""],
		["MOVE SPEED", "%s PX/S" % num(roundf(speed * 10.0) / 10.0), ""],
		["EDGE", "%s MAX" % num(Tuning.EDGE_MAX), ""],
	]
	var index: int = STAT_KEYS.find(hero_selection)
	if index >= 0 and can_add(STAT_IDS[index]):
		match STAT_IDS[index]:
			&"vitality":
				lines[0][2] = "+%d" % Tuning.VITALITY_HP_PER_POINT
			&"might":
				lines[1][2] = "+%d%%" % roundi(Tuning.MIGHT_DAMAGE_PER_POINT * 100.0)
			&"agility":
				if agility < Tuning.AGILITY_DASH_POINTS:
					lines[2][2] = "-%s" % secs(Tuning.AGILITY_DASH_COOLDOWN_TICKS_PER_POINT)
				lines[3][2] = "+%s%%" % num(Tuning.AGILITY_SPEED_PER_POINT * 100.0)
	return lines


## What a stat (or Respec) does, for the card under the stat list.
static func stat_text(key: StringName) -> String:
	match key:
		&"stat_vitality":
			return "VITALITY: +%d MAX HEALTH A POINT, AND THE POINT HEALS YOU AT ONCE. UP TO %d POINTS." % [Tuning.VITALITY_HP_PER_POINT, int(Tuning.STAT_CAP[&"vitality"])]
		&"stat_might":
			return "MIGHT: +%d%% DAMAGE A POINT ON EVERY BLOW YOU LAND. UP TO %d POINTS." % [roundi(Tuning.MIGHT_DAMAGE_PER_POINT * 100.0), int(Tuning.STAT_CAP[&"might"])]
		&"stat_agility":
			return "AGILITY: %s S OFF THE DASH COOLDOWN A POINT FOR THE FIRST %d POINTS, AND +%s%% WALKING SPEED EVERY POINT. UP TO %d POINTS." % [secs(Tuning.AGILITY_DASH_COOLDOWN_TICKS_PER_POINT), Tuning.AGILITY_DASH_POINTS, num(Tuning.AGILITY_SPEED_PER_POINT * 100.0), int(Tuning.STAT_CAP[&"agility"])]
		&"respec":
			return "RESPEC TAKES EVERY POINT BACK SO YOU CAN SPEND THEM AGAIN. FREE, BUT ONLY IN LANTERNFEN."
	return ""


## Item slot 1 holds the herbs once that slot is open and the herb is set in it: {icon, count}; {} when empty.
func herb_slot() -> Dictionary:
	if progression == null:
		return {}
	for value: Dictionary in progression.item_slots:
		if int(value.get("slot", 0)) == 1 and bool(value.get("unlocked", false)) and String(value.get("item", "")) == "herb":
			return {"icon": HERB_ICON, "count": int(value.get("count", 0))}
	return {}


# --- what the scenes show --------------------------------------------------------------------------------------------

func _hero_data() -> Dictionary:
	var figure: String = figure_frame(_equipped()) if armed() else UNARMED_FIGURE
	if progression == null:
		return {"figure": figure, "title": "BOSS FIGHT", "exp": {}, "points": "", "rows": [], "respec": {},
			"note": "STAT POINTS ARE SPENT ON THE ROAD. THIS FIGHT USES BASE STATS."}
	var bar: Dictionary = {"fraction": 1.0, "text": "MAX LEVEL"}
	if progression.exp_to_next > 0:
		bar = {"fraction": float(progression.exp) / float(progression.exp_to_next), "text": "%d / %d EXP" % [progression.exp, progression.exp_to_next]}
	var unspent: int = progression.stat_points_unspent
	var points: String = "NO POINTS TO SPEND"
	if unspent > 0:
		points = ("%d POINT TO SPEND" if unspent == 1 else "%d POINTS TO SPEND") % unspent
	var rows: Array = []
	for stat: StringName in STAT_IDS:
		rows.append({"value": int(progression.stats.get(stat, 0)), "cap": int(progression.stat_caps.get(stat, 10)), "can_add": can_add(stat)})
	return {"figure": figure, "title": "LEVEL %d" % progression.level, "exp": bar, "points": points, "points_color": TEAL if unspent > 0 else STONE,
		"rows": rows, "selected": 3 if hero_selection == &"respec" else STAT_KEYS.find(hero_selection),
		"respec": {"enabled": can_respec(), "note": "FREE IN LANTERNFEN: ALL POINTS BACK" if progression.scene_id == VILLAGE else "ONLY IN LANTERNFEN"}}


func _hero_card() -> Dictionary:
	var card: Dictionary = {"mode": "info", "title": "YOUR STATS", "stats": stat_lines(), "foot_color": CREAM,
		"sub": "WHAT YOUR POINTS GIVE YOU NOW" if progression != null else "BASE STATS IN THIS FIGHT", "sub_color": STONE,
		"foot": stat_text(hero_selection) if progression != null else ""}
	return _with_notice(card)


func _gear_data() -> Dictionary:
	var weapon: Dictionary = {"glyph": "", "whole": "", "name": "NO WEAPON", "tag": "UNARMED", "lines": ["TOVAN AT THE FORGE", "HAS A SWORD FOR YOU.", ""]}
	if armed():
		var id: StringName = _equipped()
		var w: Dictionary = weapon_data(id)
		weapon = {"glyph": "" if Hud.MEDALLIONS.has(id) else KATANA_GLYPH, "whole": Hud.MEDALLIONS.get(id, ""), "name": WEAPON_NAMES.get(id, "WEAPON"),
			"tag": "%s  %d-HIT COMBO" % [WEAPON_TAGS.get(id, ""), int(w["combo"])],
			"lines": ["DAMAGE  %s" % damage_text(w), "REACH  %s PX" % reach_text(w), "RMB  %s  %sE" % [ACTIVE_ROW_NAMES.get(id, "ACTIVE"), num(w["cost"])]]}
	var sockets: Array = []
	for slot: int in range(1, 4):
		var aspect: StringName = slot_aspect(slot)
		sockets.append({"locked": not socket_open(slot), "icon": Hud.aspect_icon(aspect) if aspect_owned(aspect) else ""})
	return {"weapon": weapon, "sockets": sockets, "items": [herb_slot(), {}]}


func _gear_card() -> Dictionary:
	if list_open():
		return _list_card()
	var all: Dictionary = descriptions(_equipped(), equipped_aspects())
	var card: Dictionary = {}
	if gear_selection == &"weapon":
		if armed():
			var id: StringName = _equipped()
			var icon: Array = weapon_icon(id)
			var entry: Array = all[id]
			card = {"icon": icon[0], "icon_crop": icon[1], "title": entry[0], "sub": "EQUIPPED   ENTER: CHANGE", "sub_color": TEAL,
				"body": "%s %s" % [entry[2][0], entry[2][1]], "foot": entry[2][2]}
		else:
			card = {"title": "NO WEAPON", "sub": "UNARMED", "body": "TOVAN AT THE FORGE HAS A SWORD FOR YOU. UNTIL THEN YOU CANNOT FIGHT."}
	elif gear_selection in ASPECT_KEYS:
		var slot: int = ASPECT_KEYS.find(gear_selection) + 1
		var aspect: StringName = slot_aspect(slot)
		var key: String = "KEY %s" % SLOT_LETTERS[slot - 1]
		if not socket_open(slot):
			card = {"title": "LOCKED SOCKET", "sub": key, "body": "IT OPENS AS YOUR STORY GOES ON."}
		elif aspect_owned(aspect) and all.has(aspect):
			var entry: Array = all[aspect]
			card = {"icon": Hud.aspect_icon(aspect), "title": entry[0], "sub": key + "   ENTER: CHANGE", "sub_color": TEAL,
				"body": "%s %s" % [entry[2][0], entry[2][1]], "foot": entry[2][2]}
		else:
			var none: bool = Aspects.ALL.filter(func(a: StringName) -> bool: return aspect_owned(a)).is_empty()
			card = {"title": "EMPTY SOCKET", "sub": key, "body": "YOU HAVE NO ASPECTS YET." if none else "PRESS ENTER TO CHOOSE AN ASPECT."}
	else:
		var index: int = ITEM_KEYS.find(gear_selection)
		var herb: Dictionary = herb_slot() if index == 0 else {}
		if not herb.is_empty():
			card = {"icon": HERB_ICON, "title": "HERB", "sub": "X%d   KEY 1" % int(herb["count"]), "sub_color": TEAL,
				"body": "PRESS 1 TO EAT ONE AND HEAL %d HEALTH. CREATURES ON THE ROAD SOMETIMES DROP THEM." % Tuning.HERB_HEAL}
		elif index == 0:
			card = {"title": "EMPTY SLOT", "sub": "KEY 1", "body": "HERBS GO HERE ONCE YOU CARRY SOME."}
		else:
			card = {"title": "EMPTY SLOT", "sub": "KEY 2", "body": "FOR YOUR NEXT KIND OF ITEM."}
	card["mode"] = "info"
	return _with_notice(card)


## The card as the weapon or Aspect list: the rows in view, the scroll bar, the result of the last request under the
## title, and the highlighted entry's text.
func _list_card() -> Dictionary:
	var ids: Array[StringName] = list_ids()
	var all: Dictionary = descriptions(_equipped(), equipped_aspects())
	var rows: Array = []
	for index: int in range(list_scroll, mini(ids.size(), list_scroll + LIST_ROWS)):
		var id: StringName = ids[index]
		if list_kind == &"weapons":
			var on: bool = id == _equipped()
			var icon: Array = weapon_icon(id)
			rows.append({"icon": icon[0], "crop": icon[1], "name": WEAPON_NAMES.get(id, ""), "selected": index == list_selection,
				"sub": "EQUIPPED" if on else "%s  %d-HIT" % [WEAPON_TAGS.get(id, ""), int(weapon_data(id)["combo"])], "sub_color": TEAL if on else STONE, "badge": "E" if on else ""})
		else:
			var slot: int = aspect_slot_of(id)
			var cd: int = Aspects.cooldown(id)
			rows.append({"icon": Hud.aspect_icon(id), "name": Aspects.display_name(id), "selected": index == list_selection,
				"sub": "%s EDGE" % num(Aspects.edge_cost(id)) + ("  CD %s S" % secs(cd) if cd > 0 else ""), "sub_color": LILAC, "badge": SLOT_LETTERS[slot - 1] if slot > 0 else ""})
	var hint: String = "CHOOSE ONE TO EQUIP" if list_kind == &"weapons" else "CHOOSE AN ASPECT"
	var hint_color: Color = STONE
	if not feedback.is_empty():
		hint = "EQUIPPED!" if bool(feedback["ok"]) else "NOT NOW  " + String(feedback["reason"])
		hint_color = TEAL if bool(feedback["ok"]) else WARN
	var note: String = ""
	if list_kind == &"aspects" and progression != null:
		var missing: int = Aspects.ALL.size() - ids.size()
		if ids.is_empty():
			note = "NO ASPECTS YET"
		elif missing > 0:
			note = "%d MORE TO FIND" % missing
	var body: String = ""
	if list_selection < ids.size() and all.has(ids[list_selection]):
		var entry: Array = all[ids[list_selection]]
		body = "%s %s" % [entry[2][0], entry[2][1]]
	return {"mode": "list", "title": "WEAPONS" if list_kind == &"weapons" else "SOCKET  %s" % SLOT_LETTERS[list_slot - 1],
		"sub": hint, "sub_color": hint_color, "rows": rows, "scroll": scroll_bar(), "note": note, "list_body": body}


func _quests_data() -> Dictionary:
	if progression == null:
		return {"heading": "BOSS FIGHT", "rows": [{"text": "DEFEAT THE MOSSBOUND COLOSSUS.", "now": true}]}
	var rows: Array = []
	var now: String = String(progression.objective.get("id", ""))
	for step: Dictionary in QuestBook.steps(book()):
		var done: bool = progression.story_flags.has(StringName(String(step.get("done_flag", ""))))
		if done or String(step.get("id", "")) == now:
			rows.append({"text": String(step.get("objective", "")), "now": not done})
	return {"heading": "CHAPTER 1   LANTERNFEN", "rows": rows}


func _quests_card() -> Dictionary:
	if progression == null:
		return {"mode": "info", "title": "BOSS FIGHT", "sub": "THE RUINS", "body_size": 7,
			"body": "DEFEAT THE MOSSBOUND COLOSSUS. PARRY ITS GOLD ATTACKS AND DASH THROUGH THE RED ONES."}
	var road_open: bool = QuestBook.road_open(book(), progression.story_flags)
	if progression.objective.is_empty():
		return {"mode": "info", "title": "ALL TASKS DONE", "sub": "LANTERNFEN", "body_size": 7,
			"body": "YOUR VILLAGE TASKS ARE COMPLETE." + (" THE ROAD EAST IS OPEN." if road_open else "")}
	var step: Dictionary = {}
	for row: Dictionary in QuestBook.steps(book()):
		if String(row.get("id", "")) == String(progression.objective.get("id", "")):
			step = row
	var reward: Dictionary = step.get("reward", {})
	var parts: PackedStringArray = PackedStringArray()
	if int(reward.get("exp", 0)) > 0:
		parts.append("+%d EXP" % int(reward["exp"]))
	for item: Dictionary in reward.get("items", []):
		parts.append("%d %s" % [int(item.get("quantity", 1)), String(item.get("name", item.get("item", "")))])
	return {"mode": "info", "title": "CURRENT TASK", "sub": "FOLLOW THE MARKER", "body": String(progression.objective.get("text", "")), "body_size": 7,
		"reward": ["REWARD", "  ".join(parts)] if not parts.is_empty() else [], "foot": "" if road_open else QuestBook.blocked_text(book()), "foot_color": DIM}


## A refusal from the last ENTER replaces the card's short line for a moment.
func _with_notice(card: Dictionary) -> Dictionary:
	if not notice.is_empty():
		card["sub"] = notice
		card["sub_color"] = WARN
	return card


## The keys that work right now, for the footer: [[key, what it does], ...].
func footer() -> Array:
	var keys: Array = []
	if list_open():
		keys = [["UP / DOWN", "SCROLL"], ["ENTER", "EQUIP" if list_kind == &"weapons" else "SET IN %s" % SLOT_LETTERS[list_slot - 1]], ["ESC", "BACK"]]
	else:
		if tab == TAB_HERO and progression != null:
			keys = [["ARROWS", "CHOOSE"], ["ENTER", "RESPEC" if hero_selection == &"respec" else "ADD A POINT"]]
		elif tab == TAB_GEAR:
			keys = [["ARROWS", "CHOOSE"]]
			if gear_selection == &"weapon":
				keys.append(["ENTER", "CHANGE WEAPON"])
			elif gear_selection in ASPECT_KEYS:
				keys.append(["ENTER", "CHANGE ASPECT"])
		keys.append(["Q / E", "SWITCH"])
	keys.append(["TAB", "CLOSE"])
	return keys


func _sync_scenes() -> void:
	if shell == null:
		return
	shell.apply(tab, TAB_NAMES, footer())
	for scene: Control in [hero_scene, gear_scene, quests_scene, card_scene]:
		scene.set("atlas", atlas)
		scene.set("frames", frames)
	hero_scene.visible = tab == TAB_HERO
	gear_scene.visible = tab == TAB_GEAR
	quests_scene.visible = tab == TAB_QUESTS
	var card: Dictionary = {}
	if tab == TAB_HERO:
		hero_scene.apply(_hero_data())
		card = _hero_card()
	elif tab == TAB_GEAR:
		gear_scene.apply(_gear_data())
		card = _gear_card()
	else:
		quests_scene.apply(_quests_data())
		card = _quests_card()
	card_scene.apply(card)


func _draw() -> void:
	if not is_open or snapshot == null:
		return
	_sync_scenes()
	for item: Dictionary in items():
		if item["key"] == selection():
			_corners(item["rect"])
	if list_open() and row_visible(list_selection):
		_corners(list_row_rect(list_selection - list_scroll))


## The selection mark: teal corners on `rect`'s edges (the kit frames carry no highlight of their own).
func _corners(rect: Rect2) -> void:
	for corner: Vector2 in [rect.position, Vector2(rect.end.x - 4, rect.position.y), Vector2(rect.position.x, rect.end.y - 1), Vector2(rect.end.x - 4, rect.end.y - 1)]:
		draw_rect(Rect2(corner, Vector2(4, 1)), TEAL)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x - 1, rect.position.y), Vector2(rect.position.x, rect.end.y - 4), Vector2(rect.end.x - 1, rect.end.y - 4)]:
		draw_rect(Rect2(corner, Vector2(1, 4)), TEAL)
