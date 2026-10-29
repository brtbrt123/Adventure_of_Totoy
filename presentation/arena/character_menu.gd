extends Node2D
## The character menu (approved mockups 2026-10-21, docs/previews/character_menu_*.png): a pop-up over the frozen arena
## with the tabs STATS and INVENTORY, drawn in the shared frame (ui_panel.gd) on the HUD layer.
##
## Presentation only: it shows snapshot data and numbers read (read-only) from core/tuning.gd, core/weapons.gd and
## core/aspects.gd, and its two actions, equipping a weapon and slotting an aspect, are requests to the core
## (InputFrame.weapon_equip, InputFrame.aspect_equip + aspect_equip_slot) sent through `equip_request` and
## `aspect_request` (the arena steps the core once with each). The core decides; the menu shows EQUIPPED or NOT NOW
## from the snapshot.
##
## Controls: TAB (gamepad Back) opens and closes, ESC closes (or only the aspect picker when it is open), Q/E
## (shoulders) or a click on a tab switches tabs, arrows/WASD move the selection, ENTER/click selects (STATS), opens the
## aspect picker on an Aspect slot, equips the picked aspect (picker) or equips a weapon (INVENTORY); the mouse hover
## shows descriptions.
## The arena does not step the core while the menu is open (see arena.gd), except once per equip request.
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")
const PlayerState := preload("res://core/player.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Aspects := preload("res://core/aspects.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const UiPanel := preload("res://presentation/arena/ui_panel.gd")
const Kit := preload("res://presentation/common/ui_kit.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")

const TAB_STATS: int = 0
const TAB_ASPECTS: int = 1
const TAB_INVENTORY: int = 2
const TAB_QUESTS: int = 3
const TAB_NAMES: Array[String] = ["STATUS", "ASPECTS", "ITEMS", "QUESTS"]
## Tab plates on the panel's top edge (x, width), kit tabs.
const TAB_SPECS: Array[Vector2i] = [Vector2i(14, 58), Vector2i(76, 60), Vector2i(140, 52), Vector2i(196, 58)]
const PANEL: Rect2 = Rect2(6, 24, 372, 176)
const DESC: Rect2 = Rect2(40, 149, 304, 46)
const VEIL_ALPHA: float = 0.62
const FOOTER: String = "TAB/ESC: CLOSE    Q/E: SWITCH TAB"
## STATS layout (384x216, kit frames)
const FIGURE: Rect2 = Rect2(16, 36, 58, 110)
const WEAPON_SLOT: Rect2 = Rect2(110, 36, 48, 48)
const MID_X: float = 134.0
const STAT_X0: float = 204.0
const STAT_X1: float = 362.0
const STAT_TOP: float = 36.0
const ROW_STEP: float = 8.0
## The STATS items of the three Aspect slots (Z, X, C); their description is the aspect slotted there.
const ASPECT_KEYS: Array[StringName] = [&"aspect_slot_1", &"aspect_slot_2", &"aspect_slot_3"]
const SLOT_LETTERS: Array[String] = ["Z", "X", "C"]
## The aspect picker (ENTER/click on an Aspect slot): every aspect in a list over the stat list, in the shared frame.
const PICKER: Rect2 = Rect2(196, 28, 178, 118)
const PICKER_ROW_TOP: float = 52.0
const PICKER_ROW_STEP: float = 17.0
## Whole rows that fit in the picker (52 + 5 x 17 = 137, inside its bottom bronze); more aspects scroll (arrows / wheel), never a half row.
const PICKER_VISIBLE_ROWS: int = 5
## The scroll bar on the picker's right edge (shown only when the list is longer than the window).
const PICKER_BAR_W: float = 3.0
## INVENTORY layout: 6x3 slots of 36 px, step 38; the weapons fill the first slots in Weapons.IDS order.
const GRID_ORIGIN: Vector2 = Vector2(20, 38)
const GRID_STEP: float = 38.0
const GRID_COLS: int = 6
const GRID_ROWS: int = 3
const SLOT_SIZE: float = 36.0
const CARD: Rect2 = Rect2(260, 36, 108, 106)
## INVENTORY: the aspects fill the second grid row (view-only; they are slotted on STATS).
const ASPECT_GRID_START: int = GRID_COLS
const FEEDBACK_SECONDS: float = 1.6

const WEAPON_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "BLACK KATANA", Tuning.WEAPON_DUAL_DAGGER: "DUAL DAGGER", Tuning.WEAPON_CHAIN_SCYTHE: "CHAIN SCYTHE"}
## The weapon's right-click active: its description key and the short name of the RMB stat row.
const ACTIVE_KEYS: Dictionary = {Tuning.WEAPON_BLACK_KATANA: &"black_form", Tuning.WEAPON_DUAL_DAGGER: &"lightning_barrage", Tuning.WEAPON_CHAIN_SCYTHE: &"reapers_coil"}
const ACTIVE_ROW_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "BLACK FORM", Tuning.WEAPON_DUAL_DAGGER: "BARRAGE", Tuning.WEAPON_CHAIN_SCYTHE: "REAPER'S COIL"}
const SHORT_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "KATANA", Tuning.WEAPON_DUAL_DAGGER: "DAGGER", Tuning.WEAPON_CHAIN_SCYTHE: "SCYTHE"}

const ExploreCore := preload("res://core/explore_core.gd")
var progression: ExploreCore.ExploreSnapshot
var stat_request: Callable=Callable()
var respec_request: Callable=Callable()
var stats_notice: String=""
var is_open: bool = false
var tab: int = TAB_STATS
## STATS: the selected item key (&"" = none yet); INVENTORY: the selected slot index.
var stats_selection: StringName = &""
var inventory_selection: int = 0
## The item under the mouse (STATS), set on mouse motion, cleared by keyboard navigation.
var hover_key: StringName = &""
## {"slot": int, "ok": bool, "reason": String, "left": float} after an equip request, else empty.
var feedback: Dictionary = {}
## The aspect picker: the slot (1-3) it fills, 0 when closed; the highlighted row (an Aspects.ALL index); its feedback
## {"aspect", "ok", "reason", "left"} after a request.
var picker_slot: int = 0
var picker_selection: int = 0
## The first Aspects.ALL index shown in the picker window (0 .. size - PICKER_VISIBLE_ROWS).
var picker_scroll: int = 0
var picker_feedback: Dictionary = {}
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var atlas: Texture2D
var frames: Dictionary = {}
## Called with a weapon id; the arena steps the core once with InputFrame.weapon_equip and returns nothing (the menu
## reads the result from `snapshot`, which the arena refreshes).
var equip_request: Callable = Callable()
## Called with (aspect id, slot 1-3); the arena steps the core once with InputFrame.aspect_equip / aspect_equip_slot.
var aspect_request: Callable = Callable()
var _last_mouse: Vector2 = Vector2(-1000, -1000)
var _atlas_image: Image = null
var _used_rects: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func open() -> void:
	stats_notice=""
	is_open = true
	visible = true
	tab = TAB_STATS
	stats_selection = &"stat_vitality" if progression!=null else &""
	hover_key = &""
	feedback = {}
	close_picker()
	inventory_selection = maxi(0, Weapons.IDS.find(_equipped()))
	_last_mouse = get_local_mouse_position()
	queue_redraw()


func close() -> void:
	is_open = false
	visible = false
	hover_key = &""
	feedback = {}
	close_picker()


func _process(delta: float) -> void:
	if not is_open:
		return
	if not feedback.is_empty():
		feedback["left"] = float(feedback["left"]) - delta
		if float(feedback["left"]) <= 0.0:
			feedback = {}
	if not picker_feedback.is_empty():
		picker_feedback["left"] = float(picker_feedback["left"]) - delta
		if float(picker_feedback["left"]) <= 0.0:
			picker_feedback = {}
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
		elif (button == MOUSE_BUTTON_WHEEL_UP or button == MOUSE_BUTTON_WHEEL_DOWN) and picker_open():
			scroll_picker(-1 if button == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()


## Keyboard / gamepad, once per physics frame while open (the arena calls it instead of stepping the core).
## TAB and ESC close the menu (returns false then).
func poll_input() -> bool:
	if Input.is_action_just_pressed("menu_toggle"):
		close()
		return false
	if Input.is_action_just_pressed("menu_back"):
		if picker_open():
			close_picker()
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
	if tab == TAB_ASPECTS and stats_selection not in ASPECT_KEYS:
		stats_selection = ASPECT_KEYS[0]
	hover_key = &""
	feedback = {}
	close_picker()
	queue_redraw()


# --- selection -------------------------------------------------------------------------------------------------------

## Every selectable item of the STATS tab with its rect: the weapon slot, the three Aspect slots, the stat rows.
func stats_items() -> Array[Dictionary]:
	if tab == TAB_ASPECTS:
		var sockets: Array[Dictionary] = []
		for i: int in 3:
			sockets.append({"key": ASPECT_KEYS[i], "rect": aspects_tab_rect(i)})
		return sockets
	if progression!=null:return progression_items()
	var items: Array[Dictionary] = [{"key": &"weapon", "rect": WEAPON_SLOT}]
	for i: int in range(3):
		items.append({"key": ASPECT_KEYS[i], "rect": aspect_rect(i)})
	var y: float = STAT_TOP
	for row: Array in stat_rows(_equipped()):
		if row[0] != "header":
			items.append({"key": row[2], "rect": Rect2(STAT_X0 - 2, y - 1, STAT_X1 - STAT_X0 + 3, ROW_STEP)})
		y += ROW_STEP
	return items


static func aspect_rect(index: int) -> Rect2:
	return Rect2(78 + index * 38, 107, 37, 40)


static func inventory_rect(index: int) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(index % GRID_COLS, index / GRID_COLS) * GRID_STEP, Vector2(SLOT_SIZE, SLOT_SIZE))


static func tab_rect(index: int) -> Rect2:
	var spec: Vector2i = TAB_SPECS[index]
	return Rect2(spec.x, 8, spec.y, 17)


## Arrow keys: on STATS the nearest item in that direction (spatial), on INVENTORY the grid neighbour (clamped).
func move_selection(direction: Vector2i) -> void:
	if tab == TAB_QUESTS:
		return
	hover_key = &""
	feedback = {}
	if picker_open():
		if direction.y != 0:
			picker_selection = clampi(picker_selection + direction.y, 0, Aspects.ALL.size() - 1)
			picker_feedback = {}
			_scroll_to_selection()
		queue_redraw()
		return
	if tab == TAB_INVENTORY:
		var col: int = clampi(inventory_selection % GRID_COLS + direction.x, 0, GRID_COLS - 1)
		var row: int = clampi(inventory_selection / GRID_COLS + direction.y, 0, GRID_ROWS - 1)
		inventory_selection = row * GRID_COLS + col
		queue_redraw()
		return
	var items: Array[Dictionary] = stats_items()
	var current: Rect2 = Rect2()
	for item: Dictionary in items:
		if item["key"] == stats_selection:
			current = item["rect"]
	if current.size == Vector2.ZERO:
		stats_selection = items[0]["key"]
		queue_redraw()
		return
	var from: Vector2 = current.get_center()
	var dir: Vector2 = Vector2(direction)
	var best: StringName = stats_selection
	var best_score: float = INF
	for item: Dictionary in items:
		if item["key"] == stats_selection:
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
	stats_selection = best
	queue_redraw()


## Mouse hover: STATS shows the hovered item's description; INVENTORY moves the selection to the hovered slot.
func hover_at(pos: Vector2) -> void:
	hover_key = &""
	if picker_open():
		for index: int in range(Aspects.ALL.size()):
			if row_visible(index) and picker_row_rect(index, picker_scroll).has_point(pos):
				if index != picker_selection:
					picker_feedback = {}
				picker_selection = index
		return
	if tab == TAB_STATS or tab == TAB_ASPECTS:
		for item: Dictionary in stats_items():
			if Rect2(item["rect"]).has_point(pos):
				hover_key = item["key"]
	else:
		for index: int in range(GRID_COLS * GRID_ROWS):
			if inventory_rect(index).has_point(pos):
				if index != inventory_selection:
					feedback = {}
				inventory_selection = index


## A left click: a tab plate switches the tab; an item selects it (STATS) or selects and equips it (INVENTORY).
func click(pos: Vector2) -> void:
	for index: int in range(TAB_NAMES.size()):
		if tab_rect(index).has_point(pos):
			if index != tab:
				set_tab(index)
			return
	if picker_open():
		for index: int in range(Aspects.ALL.size()):
			if row_visible(index) and picker_row_rect(index, picker_scroll).has_point(pos):
				picker_selection = index
				accept()
				return
		if not PICKER.has_point(pos):
			close_picker()  # a click outside closes the picker and does nothing else
		return
	if tab == TAB_STATS or tab == TAB_ASPECTS:
		for item: Dictionary in stats_items():
			if Rect2(item["rect"]).has_point(pos):
				stats_selection = item["key"]
				hover_key = &""
				if progression!=null and (String(item["key"]).begins_with("stat_") or item["key"]==&"respec"):
					accept()
				elif item["key"] in ASPECT_KEYS:
					open_picker(ASPECT_KEYS.find(item["key"]) + 1)
		return
	for index: int in range(GRID_COLS * GRID_ROWS):
		if inventory_rect(index).has_point(pos):
			inventory_selection = index
			accept()


## ENTER: on INVENTORY equip the selected weapon through the core; on STATS pin the selection (first press: weapon).
func accept() -> void:
	if tab == TAB_QUESTS:
		return
	if progression!=null and not picker_open() and tab==TAB_STATS:
		if String(stats_selection).begins_with("stat_"):
			if stat_request.is_valid():stat_request.call(StringName(String(stats_selection).trim_prefix("stat_")))
			queue_redraw()
			return
		if stats_selection==&"respec":
			if progression.scene_id==&"village_layered" and respec_request.is_valid():respec_request.call()
			else:stats_notice="Respec in the village"
			queue_redraw()
			return
	if picker_open():
		_equip_aspect(Aspects.ALL[picker_selection])
		return
	if tab == TAB_STATS or tab == TAB_ASPECTS:
		if stats_selection == &"":
			stats_selection = &"weapon"
		elif stats_selection in ASPECT_KEYS:
			open_picker(ASPECT_KEYS.find(stats_selection) + 1)
		queue_redraw()
		return
	var weapon: StringName = slot_weapon(inventory_selection)
	if weapon == &"":
		feedback = {}  # an empty slot or an aspect (aspects are slotted on STATS)
		return
	if weapon != _equipped() and equip_request.is_valid():
		equip_request.call(weapon)
	var ok: bool = _equipped() == weapon
	feedback = {"slot": inventory_selection, "ok": ok, "reason": "" if ok else refusal_reason(snapshot), "left": FEEDBACK_SECONDS}
	queue_redraw()


# --- the aspect picker -----------------------------------------------------------------------------------------------

func picker_open() -> bool:
	return picker_slot > 0


## Opens the picker for slot 1-3 with the aspect already there highlighted.
func open_picker(slot: int) -> void:
	if progression!=null:
		var unlocked: bool=slot<=progression.aspect_slots.size() and bool(progression.aspect_slots[slot-1].get("unlocked",false))
		var binding_lesson: bool=slot==1 and String(progression.objective.get("id",""))=="edda_equip"
		if not unlocked and not binding_lesson:
			stats_notice="Socket locked"
			queue_redraw()
			return
	picker_slot = clampi(slot, 1, 3)
	picker_selection = maxi(0, Aspects.ALL.find(slot_aspect(picker_slot)))
	picker_scroll = 0
	_scroll_to_selection()
	picker_feedback = {}
	hover_key = &""
	queue_redraw()


func close_picker() -> void:
	picker_slot = 0
	picker_scroll = 0
	picker_feedback = {}


## The largest scroll offset (0 when every aspect fits).
static func picker_max_scroll() -> int:
	return maxi(0, Aspects.ALL.size() - PICKER_VISIBLE_ROWS)


## True when picker row `index` is inside the scrolled window (only those are drawn, hovered or clicked).
func row_visible(index: int) -> bool:
	return index >= picker_scroll and index < picker_scroll + PICKER_VISIBLE_ROWS


## Keeps the highlighted row inside the window (keyboard moves and opening).
func _scroll_to_selection() -> void:
	if picker_selection < picker_scroll:
		picker_scroll = picker_selection
	elif picker_selection >= picker_scroll + PICKER_VISIBLE_ROWS:
		picker_scroll = picker_selection - PICKER_VISIBLE_ROWS + 1
	picker_scroll = clampi(picker_scroll, 0, picker_max_scroll())


## Mouse wheel: scrolls the window by whole rows; the highlighted row is pulled along so it never leaves the view.
func scroll_picker(delta: int) -> void:
	if not picker_open():
		return
	picker_scroll = clampi(picker_scroll + delta, 0, picker_max_scroll())
	picker_selection = clampi(picker_selection, picker_scroll, picker_scroll + PICKER_VISIBLE_ROWS - 1)
	picker_feedback = {}
	queue_redraw()


## Row `index` of the picker drawn with the window scrolled to `scroll` (whole rows, so nothing is ever half cut).
static func picker_row_rect(index: int, scroll: int = 0) -> Rect2:
	var width: float = PICKER.size.x - 18 - (PICKER_BAR_W + 3 if picker_max_scroll() > 0 else 0.0)
	return Rect2(PICKER.position.x + 9, PICKER_ROW_TOP + (index - scroll) * PICKER_ROW_STEP, width, PICKER_ROW_STEP - 1)


## The slotted aspects (Z, X, C) from the snapshot.
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


## The slot (1-3) holding `aspect`, 0 when it is not slotted.
func aspect_slot_of(aspect: StringName) -> int:
	return equipped_aspects().find(aspect) + 1


## One core step with aspect_equip + aspect_equip_slot (the core swaps when the aspect sits in another slot); the result
## is read from the snapshot. The aspect already in the slot sends nothing.
func _equip_aspect(aspect: StringName) -> void:
	if not aspect_owned(aspect):
		picker_feedback={"aspect":aspect,"ok":false,"reason":"LOCKED","left":FEEDBACK_SECONDS}
		queue_redraw()
		return
	if (progression!=null or aspect != slot_aspect(picker_slot)) and aspect_request.is_valid():
		aspect_request.call(aspect, picker_slot)
	if not is_open:
		return  # the step ended the fight and the arena closed the menu
	var ok: bool = slot_aspect(picker_slot) == aspect
	picker_feedback = {"aspect": aspect, "ok": ok, "reason": "" if ok else aspect_refusal_reason(snapshot), "left": FEEDBACK_SECONDS}
	queue_redraw()


## Why the core most likely refused an aspect equip (display text from snapshot facts; aspects have no lockout).
static func aspect_refusal_reason(snap: Snapshots.GameSnapshot) -> String:
	if snap != null and snap.player.weapon_buff_active:
		return "ACTIVE RUNNING"
	return "TRY WHEN IDLE"


## Why the core most likely refused, from snapshot facts only (display text; the core made the decision).
static func refusal_reason(snap: Snapshots.GameSnapshot) -> String:
	if snap == null:
		return "TRY WHEN IDLE"
	if snap.player.weapon_buff_active:
		return "ACTIVE RUNNING"
	if snap.hud.weapon_swap_lockout_ticks > 0:
		return "JUST SWAPPED"
	return "TRY WHEN IDLE"


static func slot_weapon(index: int) -> StringName:
	return Weapons.IDS[index] if index >= 0 and index < Weapons.IDS.size() else &""


## The aspect shown in an INVENTORY slot (the second grid row), else empty.
static func grid_aspect(index: int) -> StringName:
	var i: int = index - ASPECT_GRID_START
	return Aspects.ALL[i] if i >= 0 and i < Aspects.ALL.size() else &""


func _equipped() -> StringName:
	return snapshot.player.weapon_id if snapshot != null and snapshot.player != null else Tuning.WEAPON_BLACK_KATANA


## The key of the description shown now: the hovered item, else the selection (STATS); the selected slot (INVENTORY).
func description_key() -> StringName:
	if tab == TAB_INVENTORY:
		var weapon: StringName = slot_weapon(inventory_selection)
		if weapon != &"":
			return weapon
		var aspect: StringName = grid_aspect(inventory_selection)
		return aspect if aspect != &"" else &"empty"
	if picker_open():
		return Aspects.ALL[picker_selection]
	var key: StringName = hover_key if hover_key != &"" else stats_selection
	if key == &"weapon":
		return _equipped()
	if key in ASPECT_KEYS:
		return slot_aspect(ASPECT_KEYS.find(key) + 1)
	return key if key != &"" else &"none"


# --- numbers and texts (read from core/tuning.gd and core/weapons.gd; the formulas of the approved mockup script) ----

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
		reach.append(Tuning.ATTACK_RANGE * Weapons.range_mults(weapon)[i])
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


## The Black Form combo time: every phase scaled with Player.scaled_ticks.
static func black_form_combo_ticks() -> int:
	var total: int = 0
	for i: int in range(Tuning.COMBO_MAX):
		for phase: int in Weapons.swing_phases(Tuning.WEAPON_BLACK_KATANA, i + 1):
			total += PlayerState.scaled_ticks(phase, Tuning.BLACK_KATANA_ATTACK_SPEED_MULT)
	return total


## The tag of an aspect's description: its key when slotted ("ASPECT  KEY X"), else "ASPECT".
static func aspect_tag(aspect: StringName, aspects: Array) -> String:
	var index: int = aspects.find(aspect)
	return "ASPECT  KEY %s" % SLOT_LETTERS[index] if index >= 0 and index < 3 else "ASPECT"


## Every description: key -> [title, tag, [body line, body line, numbers line]]. Weapon-dependent ones (the stat rows
## under the weapon header) follow `equipped`; the aspects' tags follow the slotted `aspects` (Z, X, C).
static func descriptions(equipped: StringName, aspects: Array = Aspects.DEFAULT_EQUIPPED) -> Dictionary:
	var kat: Dictionary = weapon_data(Tuning.WEAPON_BLACK_KATANA)
	var dag: Dictionary = weapon_data(Tuning.WEAPON_DUAL_DAGGER)
	var scy: Dictionary = weapon_data(Tuning.WEAPON_CHAIN_SCYTHE)
	var cur: Dictionary = weapon_data(equipped)
	var barrage_slashes: int = Weapons.barrage_slashes()
	var barrage_ticks: int = Weapons.barrage_total_ticks()
	var dash_px: float = Tuning.DASH_TICKS * Tuning.DASH_SPEED
	var move_px_s: float = Tuning.PLAYER_SPEED * 60.0
	var armor_pct: int = roundi(Tuning.ARMOR_DAMAGE_FACTOR * 100)
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
	d[&"black_form"] = ["BLACK FORM", "BLACK KATANA  RMB", [
		"FOR %s S YOUR SWINGS ARE X%s FASTER AND ALL YOUR HITS DEAL X%s." % [secs(Tuning.BLACK_KATANA_BUFF_DURATION_TICKS), num(Tuning.BLACK_KATANA_ATTACK_SPEED_MULT), num(Tuning.BLACK_KATANA_DAMAGE_MULT)],
		"NO ANIMATION LOCK: USE IT EVEN MID-SWING. NO SWAP WHILE ON.",
		"%s EDGE  CD %s S FROM ACTIVATION  COMBO %s S" % [num(kat["cost"]), secs(kat["cd"]), secs(black_form_combo_ticks())]]]
	d[&"lightning_barrage"] = ["LIGHTNING BARRAGE", "DUAL DAGGER  RMB", [
		"BLINK AROUND THE BOSS: %d AUTOMATIC SLASHES, ONE PER SIDE;" % barrage_slashes,
		"THE LAST CALLS SKY LIGHTNING. YOU CANNOT BE HIT WHILE IT RUNS.",
		"%s EDGE  CD %s S  %d X %s DMG  %s S" % [num(dag["cost"]), secs(dag["cd"]), barrage_slashes, num(Tuning.ATTACK_DAMAGE * Tuning.LIGHTNING_BARRAGE_DAMAGE_MULT), secs(barrage_ticks)]]]
	d[&"reapers_coil"] = ["REAPER'S COIL", "CHAIN SCYTHE  RMB", [
		"THROW THE CHAIN: A HOOKED BOSS IS DRAGGED IN, STUNNED AND HIT BY",
		"A SPIN. A MISS PULLS YOU TO THE HOOK. YOU CANNOT BE HIT.",
		"%s EDGE  CD %s S  %s PX  STUN %s S  %d X %s DMG" % [num(scy["cost"]), secs(scy["cd"]), num(Tuning.REAPER_COIL_HOOK_RANGE), secs(Tuning.REAPER_COIL_STAGGER_TICKS), Tuning.REAPER_COIL_SPIN_HITS, spin_damage]]]
	d[&"stat_health"] = ["HEALTH", "TOTOY", [
		"DAMAGE YOU CAN TAKE. AFTER A HIT YOU ARE BRIEFLY UNTOUCHABLE.",
		"DASH THROUGH RED ATTACKS, PARRY GOLD ONES.",
		"%d HP  %s S INVULNERABLE AFTER A HIT" % [Tuning.PLAYER_MAX_HP, secs(Tuning.PLAYER_HURT_INVULN_TICKS)]]]
	d[&"stat_edge"] = ["EDGE", "TOTOY", [
		"PAYS FOR ASPECTS AND WEAPON ACTIVES. HITS AND PARRIES",
		"FILL IT; A COUNTER ON A BROKEN BOSS SPENDS ALL OF IT FOR DAMAGE.",
		"MAX %s  +%s PER PARRY  HITS: SEE THE WEAPON" % [num(Tuning.EDGE_MAX), num(Tuning.EDGE_PER_PARRY)]]]
	d[&"stat_move"] = ["MOVE SPEED", "TOTOY", [
		"WALKING SPEED. SWINGING SLOWS YOU TO A SHUFFLE.",
		"",
		"%s PX/S  X%s WHILE ATTACKING  X%s AFTER A MISSED PARRY" % [num(move_px_s), num(Tuning.ATTACK_MOVE_FACTOR), num(Tuning.PARRY_RECOVERY_MOVE_FACTOR)]]]
	d[&"stat_dash"] = ["DASH", "TOTOY", [
		"A SHORT BURST WITH INVULNERABILITY. THE ANSWER TO RED ATTACKS.",
		"WORKS WITH EVERY WEAPON.",
		"%s PX IN %s S  %s S INVULNERABLE  CD %s S" % [num(dash_px), secs(Tuning.DASH_TICKS), secs(Tuning.DASH_INVULN_TICKS), secs(Tuning.DASH_COOLDOWN_TICKS)]]]
	d[&"stat_parry"] = ["PARRY", "TOTOY", [
		"CATCH A GOLD ATTACK IN THE WINDOW. EARLY IN IT IS PERFECT: THE",
		"BOSS'S POSTURE BREAKS AT ONCE. LATER ONLY ADDS POSTURE.",
		"WINDOW %s S  PERFECT %s S  LATE %s POSTURE  MISS %s S" % [secs(Tuning.PARRY_ACTIVE_TICKS), secs(Tuning.PARRY_PERFECT_TICKS), num(Tuning.PARRY_EARLY_POSTURE), secs(Tuning.PARRY_WHIFF_RECOVERY_TICKS)]]]
	d[&"stat_counter"] = ["COUNTER", "TOTOY", [
		"HITS ON A POSTURE-BROKEN BOSS DEAL X%s PLUS HALF YOUR EDGE." % num(Tuning.COUNTER_DAMAGE_MULT),
		"OTHERWISE ITS ARMOR LETS ONLY %d%% THROUGH." % armor_pct,
		"X%s +%s PER EDGE  BREAK LASTS %s S  ARMOR X%s" % [num(Tuning.COUNTER_DAMAGE_MULT), num(Tuning.EDGE_COUNTER_BONUS), secs(Tuning.BOSS_BREAK_TICKS), num(Tuning.ARMOR_DAMAGE_FACTOR)]]]
	# the stats under the weapon header follow the equipped weapon
	var armored: PackedStringArray = PackedStringArray()
	for dmg: float in cur["damage"]:
		armored.append(str(maxi(1, roundi(dmg * Tuning.ARMOR_DAMAGE_FACTOR))))
	var damage_extra: String = ""
	var speed_extra: String = ""
	match equipped:
		Tuning.WEAPON_BLACK_KATANA:
			damage_extra = "  BLACK FORM X%s" % num(Tuning.BLACK_KATANA_DAMAGE_MULT)
			speed_extra = "  BLACK FORM %s S" % secs(black_form_combo_ticks())
		Tuning.WEAPON_DUAL_DAGGER:
			damage_extra = "  SKY LIGHTNING %s" % num(Tuning.LIGHTNING_STRIKE_DAMAGE)
	d[&"stat_damage"] = ["DAMAGE", cur["name"], [
		"BASE DAMAGE OF EACH SWING OF THE COMBO.",
		"ARMOR CUTS IT TO %d%%; A COUNTER DOES X%s." % [armor_pct, num(Tuning.COUNTER_DAMAGE_MULT)],
		"%s  ARMORED %s%s" % [damage_text(cur), "/".join(armored), damage_extra]]]
	var swings: PackedStringArray = PackedStringArray()
	for t: int in cur["swing_ticks"]:
		swings.append(secs(t) + " S")
	d[&"stat_speed"] = ["ATTACK SPEED", cur["name"], [
		"TIME OF EACH SWING: WIND-UP, STRIKE AND RECOVERY.",
		"THE FINISHER IS SLOWEST AND LEAVES THE LONGEST OPENING.",
		"SWINGS %s  COMBO %s S%s" % [" / ".join(swings), secs(cur["combo_ticks"]), speed_extra]]]
	var others: String = ""
	for weapon: StringName in Weapons.IDS:
		if weapon == equipped:
			continue
		var other: Dictionary = weapon_data(weapon)
		others += "  %s %s" % [SHORT_NAMES[weapon], reach_text(other)]
		if weapon == Tuning.WEAPON_CHAIN_SCYTHE:
			others += " (%d DEG)" % roundi(other["arc_deg"])
	var uniform: bool = not reach_text(cur).contains("/")
	d[&"stat_reach"] = ["REACH", cur["name"], [
		"HOW FAR EACH SWING REACHES, IN A %d DEGREE ARC EACH SIDE" % roundi(cur["arc_deg"]),
		"OF WHERE YOU FACE. " + ("EVERY SWING REACHES AS FAR." if uniform else "THE FINISHER REACHES FURTHEST."),
		"%s PX%s" % [reach_text(cur), others]]]
	d[&"stat_edge_gain"] = ["EDGE GAIN", cur["name"], [
		"EDGE EARNED BY EACH SWING THAT LANDS ON AN UNBROKEN BOSS.",
		"",
		"KATANA +%s  DAGGER +%s  SCYTHE +%s  PARRY +%s" % [num(kat["edge"]), num(dag["edge"]), num(scy["edge"]), num(Tuning.EDGE_PER_PARRY)]]]
	d[&"none"] = ["", "", ["HOVER OR SELECT A SLOT OR A STAT TO READ ABOUT IT.", "", "ARROWS/WASD: MOVE   ENTER/CLICK: SELECT"]]
	d[&"empty"] = ["", "", ["AN EMPTY SLOT.", "", "ARROWS/WASD: MOVE   ENTER/CLICK: EQUIP"]]
	return d


## The STATS list: [label, value, description key], or ["header", text, &""]. The second block follows `equipped`.
static func stat_rows(equipped: StringName) -> Array[Array]:
	var w: Dictionary = weapon_data(equipped)
	var rows: Array[Array] = [
		["header", "BASE", &""],
		["HEALTH", str(Tuning.PLAYER_MAX_HP), &"stat_health"],
		["EDGE", "%s MAX" % num(Tuning.EDGE_MAX), &"stat_edge"],
		["MOVE SPEED", "%s PX/S" % num(Tuning.PLAYER_SPEED * 60.0), &"stat_move"],
		["DASH", "%s PX  %sS" % [num(Tuning.DASH_TICKS * Tuning.DASH_SPEED), secs(Tuning.DASH_COOLDOWN_TICKS, 1)], &"stat_dash"],
		["PARRY", "%s S" % secs(Tuning.PARRY_ACTIVE_TICKS), &"stat_parry"],
		["COUNTER", "X%s +EDGE" % num(Tuning.COUNTER_DAMAGE_MULT), &"stat_counter"],
		["header", w["name"], &""],
		["DAMAGE", damage_text(w), &"stat_damage"],
		["ATTACK SPEED", "%s S" % secs(w["combo_ticks"]), &"stat_speed"],
		["REACH", "%s PX" % reach_text(w), &"stat_reach"],
		["EDGE GAIN", "+%s/HIT" % num(w["edge"]), &"stat_edge_gain"],
		["RMB " + String(ACTIVE_ROW_NAMES.get(equipped, "ACTIVE")), "%sE %sS" % [num(w["cost"]), secs(w["cd"])], ACTIVE_KEYS.get(equipped, &"black_form")],
	]
	return rows


# --- drawing ---------------------------------------------------------------------------------------------------------

func _text(at: Vector2, text: String, color: Color, face: Font = null, size: int = Hud.FONT_SIZE, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var font: Font = face if face != null else Hud.text_face(text)
	size = Hud._size_for(font, 1, size)
	var width: float = Hud.text_width(text, 1, font, size)
	var x: float = at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	draw_string(font, Vector2(floorf(x), at.y + Hud._cap_ratio(font) * size), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return width


func _ui(key: String, rect: Rect2, source_offset: Vector2 = Vector2.ZERO, source_size: Vector2 = Vector2.ZERO) -> void:
	if atlas == null or not frames.has(key):
		return
	var f: Dictionary = frames[key]
	var size: Vector2 = source_size if source_size != Vector2.ZERO else Vector2(f["w"], f["h"])
	draw_texture_rect_region(atlas, rect, Rect2(Vector2(f["x"], f["y"]) + source_offset, size))


## A filled ellipse as whole-pixel rows (stays hard-edged).
func _ellipse(centre: Vector2, radii: Vector2, color: Color) -> void:
	for row: int in range(int(radii.y * 2)):
		var y: float = centre.y - radii.y + row
		var t: float = (y + 0.5 - centre.y) / radii.y
		var half: float = radii.x * sqrt(maxf(0.0, 1.0 - t * t))
		draw_rect(Rect2(roundf(centre.x - half), y, roundf(centre.x + half) - roundf(centre.x - half), 1), color)


func _key_badge(at: Vector2, letter: String) -> void:
	UiPanel.key_badge(self, at, colors)
	_text(at + Vector2(4.5, 1), letter, colors["1"], null, 7, HORIZONTAL_ALIGNMENT_CENTER)


func _draw() -> void:
	if not is_open or colors.is_empty() or snapshot == null:
		return
	draw_rect(Rect2(0, 0, 384, 216), Color(colors["0"], VEIL_ALPHA))
	UiPanel.draw_panel(self, PANEL, &"menu", colors)
	_draw_tabs()
	_text(Vector2(192, 202), FOOTER, colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	if tab == TAB_STATS:
		if progression!=null:_draw_progression_stats()
		else:_draw_stats()
	elif tab == TAB_INVENTORY:
		_draw_inventory()
	elif tab == TAB_ASPECTS:
		_draw_aspects_tab()
	else:
		_draw_quests_tab()
	if tab == TAB_INVENTORY or (tab == TAB_STATS and progression == null):
		_draw_description(description_key())


func _draw_tabs() -> void:
	for index: int in range(TAB_NAMES.size()):
		var rect: Rect2 = tab_rect(index)
		Kit.tab(self, rect, index == tab)
		_text(Vector2(rect.get_center().x, rect.position.y + 4), TAB_NAMES[index], colors["1"] if index == tab else colors["i"], Hud.menu_font(), 9, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(368, 11), "TOTOY", colors["j"], Hud.menu_font(), 10, HORIZONTAL_ALIGNMENT_RIGHT)


## The weapon's socket art: the katana's kit medallion around its blade glyph (48x52), or the dagger's / scythe's whole
## 48 px medallion.
func _draw_medallion(weapon: StringName, at: Vector2) -> void:
	if Hud.MEDALLIONS.has(weapon):
		_ui(Hud.MEDALLIONS[weapon], Rect2(at, Vector2(48, 48)))
	else:
		Kit.medallion(self, at - Vector2(0, 2))
		_ui("ui_weapon_totoy_blade_1", Rect2(Kit.medallion_centre(at - Vector2(0, 2)) - Vector2(16, 16), Vector2(32, 32)))


## Teal corner brackets round `rect` (the selection mark; the kit frames carry no highlight of their own).
func _brackets(rect: Rect2) -> void:
	for corner: Array in [[rect.position.x - 2, rect.position.y - 2, 1, 1], [rect.end.x + 1, rect.position.y - 2, -1, 1], [rect.position.x - 2, rect.end.y + 1, 1, -1], [rect.end.x + 1, rect.end.y + 1, -1, -1]]:
		var bx: float = corner[0]
		var by: float = corner[1]
		draw_rect(Rect2(minf(bx, bx + 3 * corner[2]), by, 4, 1), colors["u"])
		draw_rect(Rect2(bx, minf(by, by + 3 * corner[3]), 1, 4), colors["u"])


func _equipped_badge(rect: Rect2) -> void:
	Kit.badge(self, rect)
	_text(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 1), "E", colors["1"], null, 7, HORIZONTAL_ALIGNMENT_CENTER)


func highlighted_key() -> StringName:
	return hover_key if hover_key != &"" else stats_selection


func _draw_stats() -> void:
	var equipped: StringName = _equipped()
	var lit: StringName = highlighted_key()
	# the figure box: Totoy at 2x, holding the equipped weapon, on a stone strip with a shadow
	Kit.nine(self, "slot_frame", FIGURE)
	var strip_y: float = FIGURE.end.y - 20
	draw_rect(Rect2(FIGURE.position.x + 3, strip_y, FIGURE.size.x - 6, 17), colors["e"])
	draw_rect(Rect2(FIGURE.position.x + 3, strip_y, FIGURE.size.x - 6, 1), colors["f"])
	var feet: Vector2 = Vector2(FIGURE.get_center().x, FIGURE.end.y - 11)
	_ellipse(feet, Vector2(13, 3), colors["0"])
	_draw_figure(figure_frame(equipped), feet)
	# weapon slot
	_text(Vector2(MID_X, 28), "WEAPON", colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_medallion(equipped, WEAPON_SLOT.position)
	if lit == &"weapon":
		_brackets(WEAPON_SLOT)
	_equipped_badge(Rect2(WEAPON_SLOT.position + Vector2(38, 0), Vector2(10, 10)))
	_text(Vector2(MID_X, 90), WEAPON_NAMES.get(equipped, "WEAPON"), colors["1"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	# aspects
	_text(Vector2(MID_X, 99), "ASPECTS", colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	for i: int in range(3):
		var rect: Rect2 = aspect_rect(i)
		Kit.socket(self, rect.position, false)
		_ui(Hud.aspect_icon(slot_aspect(i + 1)), Kit.socket_icon_rect(rect.position), Vector2(4, 4), Vector2(16, 16))
		if lit == ASPECT_KEYS[i] or picker_slot == i + 1:
			_brackets(rect)
		var key_at: Vector2 = Kit.socket_key(rect.position)
		_text(Vector2(key_at.x, key_at.y - 3), SLOT_LETTERS[i], colors["1"], null, 8, HORIZONTAL_ALIGNMENT_CENTER)
	# the stat list
	var y: float = STAT_TOP
	for row: Array in stat_rows(equipped):
		if row[0] == "header":
			var w: float = _text(Vector2(STAT_X0, y), row[1], colors["v"])
			draw_rect(Rect2(STAT_X0 + w + 4, y + 3, STAT_X1 - STAT_X0 - w - 4, 1), colors["f"])
		else:
			var on: bool = lit == row[2]
			if on:
				draw_rect(Rect2(STAT_X0 - 2, y - 1, STAT_X1 - STAT_X0 + 3, 8), colors["k"])
				draw_rect(Rect2(STAT_X0 - 2, y + 7, STAT_X1 - STAT_X0 + 3, 1), colors["1"])
				_text(Vector2(STAT_X0 - 1, y), ">", colors["1"])
			_text(Vector2(STAT_X0 + (5 if on else 0), y), row[0], colors["1"] if on else colors["i"])
			_text(Vector2(STAT_X1, y), row[1], colors["1"] if on else colors["j"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
		y += ROW_STEP
	if picker_open():
		_draw_picker()


## The aspect picker over the stat list: a title (or the request's feedback), then one row per aspect: icon, name,
## Edge cost, and for a slotted one its key badge and a tick.
func _draw_picker() -> void:
	UiPanel.draw_panel(self, PICKER, &"info", colors)
	var x0: float = PICKER.position.x + 10
	var title_y: float = PICKER.position.y + 10
	if picker_feedback.is_empty():
		_text(Vector2(x0, title_y), "ASPECT FOR SLOT " + SLOT_LETTERS[picker_slot - 1], colors["1"])
		_text(Vector2(PICKER.end.x - 10, title_y), "ESC: BACK", colors["f"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	elif bool(picker_feedback["ok"]):
		_text(Vector2(x0, title_y), "EQUIPPED!", colors["u"])
	else:
		_text(Vector2(x0, title_y), "NOT NOW  " + String(picker_feedback["reason"]), colors["q"])
	draw_rect(Rect2(x0, title_y + 11, PICKER.size.x - 20, 1), colors["f"])
	if picker_max_scroll() > 0:
		_draw_picker_bar()
	for index: int in range(Aspects.ALL.size()):
		if not row_visible(index):
			continue
		var aspect: StringName = Aspects.ALL[index]
		var row: Rect2 = picker_row_rect(index, picker_scroll)
		var on: bool = index == picker_selection
		if on:
			draw_rect(row, colors["k"])
			draw_rect(Rect2(row.position.x, row.end.y - 1, row.size.x, 1), colors["1"])
		# the icon's inner 16x16 (the ring cropped) at native size
		_ui(Hud.aspect_icon(aspect), Rect2(row.position + Vector2(2, 0), Vector2(16, 16)), Vector2(4, 4), Vector2(16, 16))
		if not aspect_owned(aspect):
			draw_rect(row,Color(colors["0"],0.72))
			Kit.put(self,"icon_padlock",row.position+Vector2(6,3))
		_text(Vector2(row.position.x + 22, row.position.y + 4), Aspects.display_name(aspect), colors["1"] if on and aspect_owned(aspect) else colors["g"])
		_text(Vector2(row.end.x - 26, row.position.y + 4), "%sE" % num(Aspects.edge_cost(aspect)), colors["v"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
		var slot: int = aspect_slot_of(aspect)
		if slot > 0 and aspect_owned(aspect):
			_key_badge(Vector2(row.end.x - 22, row.position.y + 4), SLOT_LETTERS[slot - 1])
			_tick(Vector2(row.end.x - 11, row.position.y + 5), colors["u"])


## The picker's scroll bar: a dark track along the rows, a thumb sized to the window, and a small arrow at each end
## while more rows lie that way.
static func picker_bar_rect() -> Rect2:
	return Rect2(PICKER.end.x - 10 - PICKER_BAR_W, PICKER_ROW_TOP + 4, PICKER_BAR_W, PICKER_VISIBLE_ROWS * PICKER_ROW_STEP - 9)


func picker_thumb_rect() -> Rect2:
	var track: Rect2 = picker_bar_rect()
	var total: int = Aspects.ALL.size()
	var height: float = maxf(4.0, floorf(track.size.y * PICKER_VISIBLE_ROWS / total))
	var top: float = track.position.y + roundf((track.size.y - height) * picker_scroll / maxi(1, picker_max_scroll()))
	return Rect2(track.position.x, top, track.size.x, height)


func _draw_picker_bar() -> void:
	var track: Rect2 = picker_bar_rect()
	draw_rect(track, colors["0"])
	draw_rect(picker_thumb_rect(), colors["o"])
	var cx: float = track.position.x + 1
	var up: Color = colors["1"] if picker_scroll > 0 else colors["e"]
	var down: Color = colors["1"] if picker_scroll < picker_max_scroll() else colors["e"]
	# 3 px wide arrowheads just outside the track
	draw_rect(Rect2(cx, track.position.y - 3, 1, 1), up)
	draw_rect(Rect2(cx - 1, track.position.y - 2, 3, 1), up)
	draw_rect(Rect2(cx - 1, track.end.y + 1, 3, 1), down)
	draw_rect(Rect2(cx, track.end.y + 2, 1, 1), down)


## A 7x5 pixel check mark (top-left `at`).
func _tick(at: Vector2, color: Color) -> void:
	for p: Vector2i in [Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 3), Vector2i(4, 2), Vector2i(5, 1), Vector2i(6, 0), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 1), Vector2i(5, 0)]:
		draw_rect(Rect2(at + Vector2(p), Vector2.ONE), color)


## The equipped weapon's idle frame (the arena's own frame sets).
static func figure_frame(weapon: StringName) -> String:
	var prefix: String = ArenaAnimation.SET_KATANA
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER: prefix = ArenaAnimation.SET_DAGGER
		Tuning.WEAPON_CHAIN_SCYTHE: prefix = ArenaAnimation.SET_SCYTHE
	return ArenaAnimation.hero_frame(prefix, "idle", 1)


## Draws `key` at 2x with its visible pixels centred on `feet.x` and its anchor's feet on `feet.y`.
func _draw_figure(key: String, feet: Vector2) -> void:
	if atlas == null or not frames.has(key):
		key = "hero2_idle_right_1"
		if not frames.has(key):
			return
	var f: Dictionary = frames[key]
	var used: Rect2i = _used_rect(key)
	var centre_offset: float = (used.position.x + used.size.x * 0.5) - float(f.get("ax", f["w"] / 2))
	var left: float = roundf(feet.x - centre_offset * 2.0) - float(f.get("ax", 0)) * 2.0
	var top: float = feet.y - float(f.get("ay", f["h"])) * 2.0
	# clipped to the inside of the figure box in whole source pixels (the scythe's chain is wider than the box)
	var clip: Rect2 = FIGURE.grow(-1)
	var x0: int = maxi(0, ceili((clip.position.x - left) / 2.0))
	var y0: int = maxi(0, ceili((clip.position.y - top) / 2.0))
	var x1: int = mini(int(f["w"]), floori((clip.end.x - left) / 2.0))
	var y1: int = mini(int(f["h"]), floori((clip.end.y - top) / 2.0))
	if x1 <= x0 or y1 <= y0:
		return
	draw_texture_rect_region(atlas, Rect2(left + x0 * 2, top + y0 * 2, (x1 - x0) * 2, (y1 - y0) * 2), Rect2(float(f["x"]) + x0, float(f["y"]) + y0, x1 - x0, y1 - y0))


func _used_rect(key: String) -> Rect2i:
	if not _used_rects.has(key):
		var f: Dictionary = frames[key]
		if _atlas_image == null:
			_atlas_image = atlas.get_image()
		var region: Image = _atlas_image.get_region(Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"])))
		var used: Rect2i = region.get_used_rect()
		_used_rects[key] = used if used.size != Vector2i.ZERO else Rect2i(0, 0, int(f["w"]), int(f["h"]))
	return _used_rects[key]


func _draw_inventory() -> void:
	var equipped: StringName = _equipped()
	for index: int in range(GRID_COLS * GRID_ROWS):
		var rect: Rect2 = inventory_rect(index)
		Kit.slot(self, rect, &"normal")
		if index == inventory_selection:
			_brackets(rect)
		var weapon: StringName = slot_weapon(index)
		var grid_item: StringName = grid_aspect(index)
		if grid_item != &"":
			_ui(Hud.aspect_icon(grid_item), Rect2(rect.position + Vector2(6, 6), Vector2(24, 24)))
			if not aspect_owned(grid_item):
				draw_rect(rect.grow(-3),Color(colors["0"],0.8))
				Kit.put(self,"icon_padlock",rect.get_center() - Vector2(4, 5))
			var held: int = aspect_slot_of(grid_item)
			if held > 0:
				_key_badge(rect.position + Vector2(26, 1), SLOT_LETTERS[held - 1])
			continue
		if weapon == &"":
			continue
		_draw_item_icon(weapon, rect.position + Vector2(2, 2))
		if weapon == equipped:
			_equipped_badge(Rect2(rect.position + Vector2(26, 1), Vector2(9, 9)))
	# the detail card
	Kit.panel(self, CARD)
	var cx: float = CARD.get_center().x
	var top: float = CARD.position.y
	var weapon: StringName = slot_weapon(inventory_selection)
	var card_aspect: StringName = grid_aspect(inventory_selection)
	if card_aspect != &"":
		_draw_aspect_card(card_aspect, cx)
		return
	if weapon == &"":
		_text(Vector2(cx, top + 48), "EMPTY", colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_draw_medallion(weapon, Vector2(cx - 24, top + 8))
	_text(Vector2(cx, top + 62), WEAPON_NAMES[weapon], colors["1"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	var equipped_now: bool = weapon == equipped
	_text(Vector2(cx, top + 71), "EQUIPPED" if equipped_now else "NOT EQUIPPED", colors["v"] if equipped_now else colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(Rect2(CARD.position.x + 12, top + 81, CARD.size.x - 24, 1), colors["f"])
	var lines: Array = card_lines(weapon)
	_text(Vector2(cx, top + 85), lines[0], colors[lines[2]], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(cx, top + 93), lines[1], colors[lines[2]], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)


## An aspect's card (view-only): its icon in a socket, name, the slot holding it, Edge cost and cooldown.
func _draw_aspect_card(aspect: StringName, cx: float) -> void:
	var top: float = CARD.position.y
	if not aspect_owned(aspect):
		_text(Vector2(cx, top + 48), "LOCKED", colors["g"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var at: Vector2 = Vector2(cx - 18.5, top + 12)
	Kit.socket(self, at, false)
	_ui(Hud.aspect_icon(aspect), Kit.socket_icon_rect(at), Vector2(4, 4), Vector2(16, 16))
	_text(Vector2(cx, top + 62), Aspects.display_name(aspect), colors["1"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	var slot: int = aspect_slot_of(aspect)
	_text(Vector2(cx, top + 71), "SLOT " + SLOT_LETTERS[slot - 1] if slot > 0 else "NOT SLOTTED", colors["v"] if slot > 0 else colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(Rect2(CARD.position.x + 12, top + 81, CARD.size.x - 24, 1), colors["f"])
	var cd: int = Aspects.cooldown(aspect)
	_text(Vector2(cx, top + 85), "%s EDGE" % num(Aspects.edge_cost(aspect)) + ("  CD %s S" % secs(cd) if cd > 0 else ""), colors["o"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(cx, top + 93), "SLOT ON STATS", colors["o"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)


## The two lines under the card's divider and their colour symbol: the equip feedback, else how to equip.
func card_lines(weapon: StringName) -> Array:
	if not feedback.is_empty() and int(feedback["slot"]) == inventory_selection:
		if bool(feedback["ok"]):
			return ["EQUIPPED!", "READY TO FIGHT", "u"]
		return ["NOT NOW", String(feedback["reason"]), "q"]
	if weapon == _equipped():
		return ["IN YOUR HANDS", "", "o"]
	return ["ENTER / CLICK", "TO EQUIP", "o"]


## Inventory icon: the katana's 32 px blade glyph; the dagger and scythe show the centre 32x32 of their medallion.
func _draw_item_icon(weapon: StringName, at: Vector2) -> void:
	if Hud.MEDALLIONS.has(weapon):
		_ui(Hud.MEDALLIONS[weapon], Rect2(at, Vector2(32, 32)), Vector2(8, 8), Vector2(32, 32))
	else:
		_ui("ui_weapon_totoy_blade_1", Rect2(at, Vector2(32, 32)))


func _draw_description(key: StringName) -> void:
	var all: Dictionary = descriptions(_equipped(), equipped_aspects())
	var entry: Array = all.get(key, all[&"none"])
	UiPanel.draw_panel(self, DESC, &"info", colors, false)
	var x0: float = DESC.position.x + 10
	var lines: Array = entry[2]
	if String(entry[0]).is_empty():
		_text(Vector2(192, DESC.position.y + 12), lines[0], colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(192, DESC.position.y + 26), lines[2], colors["f"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_text(Vector2(x0, DESC.position.y + 7), entry[0], colors["1"], Hud.menu_font(), 10)
	_text(Vector2(DESC.end.x - 10, DESC.position.y + 8), entry[1], colors["u"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	for i: int in range(lines.size()):
		if not String(lines[i]).is_empty():
			_text(Vector2(x0, DESC.position.y + 17 + i * 8), lines[i], colors["o"] if i == 2 else colors["j"], null, 7)

func aspect_owned(aspect: StringName) -> bool:
	return progression==null or progression.owned_aspects.has(aspect)


static func aspects_tab_rect(index: int) -> Rect2:
	return Rect2(30 + index * 48, 55, 37, 40)


func _draw_aspects_tab() -> void:
	_text(Vector2(26, 37), "ASPECT SOCKETS", colors["u"], Hud.menu_font(), 9)
	for i: int in 3:
		var rect: Rect2 = aspects_tab_rect(i)
		var aspect: StringName = slot_aspect(i + 1)
		var unlocked: bool = progression == null or (i < progression.aspect_slots.size() and bool(progression.aspect_slots[i].get("unlocked", false)))
		Kit.socket(self, rect.position, not unlocked or not aspect_owned(aspect))
		if unlocked and aspect_owned(aspect):
			_ui(Hud.aspect_icon(aspect), Kit.socket_icon_rect(rect.position), Vector2(4, 4), Vector2(16, 16))
		var at: Vector2 = Kit.socket_key(rect.position)
		_text(Vector2(at.x, at.y - 3), SLOT_LETTERS[i], colors["1" if unlocked else "g"], Hud.stat_font(), 8, HORIZONTAL_ALIGNMENT_CENTER)
		if stats_selection == ASPECT_KEYS[i]:
			_brackets(rect)
	_text(Vector2(26, 108), "Select a socket, then choose an Aspect.", colors["i"], null, 7)
	_text(Vector2(26, 123), "Locked sockets open as your story advances.", colors["i"], null, 7)
	var selected: int = maxi(0, ASPECT_KEYS.find(stats_selection))
	var id: StringName = slot_aspect(selected + 1)
	var detail: Rect2 = Rect2(22, 142, 340, 48)
	Kit.panel(self, detail)
	_text(Vector2(34, 151), Aspects.display_name(id) if aspect_owned(id) else "LOCKED ASPECT", colors["1"], Hud.menu_font(), 10)
	if aspect_owned(id):
		_text(Vector2(34, 168), "%s Edge   Cooldown %s s" % [num(Aspects.edge_cost(id)), secs(Aspects.cooldown(id))], colors["u"], null, 8)
	if not stats_notice.is_empty():
		_text(Vector2(26, 132), stats_notice, colors["o"], null, 7)
	if picker_open():
		_draw_picker()


func _draw_quests_tab() -> void:
	_text(Vector2(30, 44), "CURRENT OBJECTIVE", colors["u"], Hud.menu_font(), 11)
	var card: Rect2 = Rect2(24, 66, 336, 106)
	Kit.panel(self, card)
	var objective: String = String(progression.objective.get("text", "Your village tasks are complete.")) if progression != null else "Defeat the Mossbound Colossus."
	var y: float = 82.0
	var line: String = ""
	for word: String in objective.split(" "):
		var candidate: String = word if line.is_empty() else line + " " + word
		if Hud.text_width(candidate, 1, Hud.ui_font(), 10) > 300.0:
			_text(Vector2(38, y), line, colors["1"], null, 10)
			y += 15.0
			line = word
		else:
			line = candidate
	_text(Vector2(38, y), line, colors["1"], null, 10)
	_text(Vector2(38, 150), "Follow the objective marker on the road.", colors["i"], null, 8)
static func progression_aspect_rect(i: int) -> Rect2:return Rect2(28+i*46,150,37,40)
static func progression_row_rect(i: int) -> Rect2:return Rect2(20,56+i*30,298,28)
static func progression_plus_rect(i: int) -> Rect2:return Rect2(292,61+i*30,18,18)
static func respec_rect() -> Rect2:return Rect2(246,152,116,20)
func progression_items() -> Array[Dictionary]:
	var items: Array[Dictionary]=[]
	for i: int in 3:items.append({"key":StringName("stat_"+["vitality","might","agility"][i]),"rect":progression_plus_rect(i)})
	items.append({"key":&"respec","rect":respec_rect()})
	for i: int in 3:items.append({"key":ASPECT_KEYS[i],"rect":progression_aspect_rect(i)})
	return items
func _draw_progression_stats() -> void:
	_text(Vector2(22,38),"UNSPENT POINTS: %d" % progression.stat_points_unspent,colors["u"],Hud.menu_font(),10)
	_text(Vector2(362,39),"LV %d   HP %d" % [progression.level,progression.hero.max_hp],colors["1"],null,Hud.FONT_SIZE,HORIZONTAL_ALIGNMENT_RIGHT)
	for i: int in 3:
		var stat: String=["vitality","might","agility"][i]
		var value: int=int(progression.stats.get(stat,0))
		var cap: int=int(progression.stat_caps.get(stat,0))
		var row: Rect2=progression_row_rect(i)
		var on: bool=stats_selection==StringName("stat_"+stat)
		Kit.panel(self,row)
		if on:_brackets(row)
		_text(Vector2(30,row.position.y+7),stat,colors["1"],Hud.menu_font(),9)
		_text(Vector2(30,row.position.y+18),["+6 max health a point","+3% damage a point","Shorter dash cooldown; a little faster"][i],colors["i"],null,6)
		_text(Vector2(278,row.position.y+11),"%d / %d" % [value,cap],colors["p"],null,Hud.FONT_SIZE,HORIZONTAL_ALIGNMENT_RIGHT)
		var enabled: bool=progression.stat_points_unspent>0 and value<cap
		var plus: Rect2=progression_plus_rect(i)
		Kit.button(self,plus,&"normal" if enabled else &"locked")
		_text(Vector2(plus.get_center().x,plus.position.y+4),"+",colors["u" if enabled else "g"],null,10,HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(28,141),"ASPECT SOCKETS",colors["i"])
	for i: int in 3:
		var rect: Rect2=progression_aspect_rect(i)
		var slot: Dictionary=progression.aspect_slots[i] if i<progression.aspect_slots.size() else {}
		var open: bool=bool(slot.get("unlocked",false)) and aspect_owned(StringName(slot.get("aspect",&"")))
		Kit.socket(self,rect.position,not open)
		if open:_ui(Hud.aspect_icon(slot.get("aspect",&"")),Kit.socket_icon_rect(rect.position),Vector2(4,4),Vector2(16,16))
		if stats_selection==ASPECT_KEYS[i]:_brackets(rect)
		var key_at: Vector2=Kit.socket_key(rect.position)
		_text(Vector2(key_at.x,key_at.y-3),SLOT_LETTERS[i],colors["1" if open else "g"],null,8,HORIZONTAL_ALIGNMENT_CENTER)
	var village: bool=progression.scene_id==&"village_layered"
	var respec: Rect2=respec_rect()
	Kit.button(self,respec,&"normal" if village else &"locked")
	if stats_selection==&"respec":_brackets(respec)
	_text(Vector2(respec.get_center().x,respec.position.y+5),"RESPEC",colors["1" if village else "g"],Hud.menu_font(),9,HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(respec.get_center().x,respec.end.y+5),"FREE IN VILLAGE" if village else "VILLAGE ONLY",colors["i"],null,6,HORIZONTAL_ALIGNMENT_CENTER)
	if not stats_notice.is_empty():_text(Vector2(160,184),stats_notice,colors["o"],null,6)
	elif String(progression.objective.get("id",""))=="edda_equip":_text(Vector2(160,184),"SELECT FIRST SOCKET TO BIND SPRINT",colors["u"],null,6)
	if picker_open():_draw_picker()
