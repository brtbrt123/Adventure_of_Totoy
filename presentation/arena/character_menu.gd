extends Node2D
## The character menu (approved mockups 2026-10-21, docs/previews/character_menu_*.png): a pop-up over the frozen arena
## with the tabs STATS and INVENTORY, drawn in the shared frame (ui_panel.gd) on the HUD layer.
##
## Presentation only: it shows snapshot data and numbers read (read-only) from core/tuning.gd and core/weapons.gd, and
## its one action, equipping a weapon, is a request to the core (InputFrame.weapon_equip) sent through `equip_request`
## (the arena steps the core once with it). The core decides; the menu shows EQUIPPED or NOT NOW from the snapshot.
##
## Controls: TAB (gamepad Back) opens and closes, ESC closes, Q/E (shoulders) or a click on a tab switches tabs,
## arrows/WASD move the selection, ENTER/click selects (STATS) or equips (INVENTORY), the mouse hover shows descriptions.
## The arena does not step the core while the menu is open (see arena.gd), except once per equip request.
const Tuning := preload("res://core/tuning.gd")
const Weapons := preload("res://core/weapons.gd")
const PlayerState := preload("res://core/player.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const UiPanel := preload("res://presentation/arena/ui_panel.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")

const TAB_STATS: int = 0
const TAB_INVENTORY: int = 1
const TAB_NAMES: Array[String] = ["STATS", "INVENTORY"]
## Tab plates on the panel's top edge (x, width), as in the mockup.
const TAB_SPECS: Array[Vector2i] = [Vector2i(12, 54), Vector2i(68, 84)]
const PANEL: Rect2 = Rect2(6, 16, 308, 162)
const DESC: Rect2 = Rect2(11, 125, 298, 40)
const VEIL_ALPHA: float = 0.62
const FOOTER: String = "TAB/ESC: CLOSE    Q/E: SWITCH TAB"
## STATS layout
const FIGURE: Rect2 = Rect2(11, 21, 52, 101)
const WEAPON_SLOT: Rect2 = Rect2(85, 27, 50, 50)
const MID_X: float = 110.0
const STAT_X0: float = 159.0
const STAT_X1: float = 307.0
const STAT_TOP: float = 21.0
const ROW_STEP: float = 8.0
const ASPECT_KEYS: Array[StringName] = [&"breaking_edge", &"gale_cut", &"moon_cleave"]
## INVENTORY layout: 6x3 slots of 32 px, step 33; the weapons fill the first slots in Weapons.IDS order.
const GRID_ORIGIN: Vector2 = Vector2(13, 23)
const GRID_STEP: float = 33.0
const GRID_COLS: int = 6
const GRID_ROWS: int = 3
const CARD: Rect2 = Rect2(216, 21, 93, 101)
const FEEDBACK_SECONDS: float = 1.6

const WEAPON_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "BLACK KATANA", Tuning.WEAPON_DUAL_DAGGER: "DUAL DAGGER", Tuning.WEAPON_CHAIN_SCYTHE: "CHAIN SCYTHE"}
## The weapon's right-click active: its description key and the short name of the RMB stat row.
const ACTIVE_KEYS: Dictionary = {Tuning.WEAPON_BLACK_KATANA: &"black_form", Tuning.WEAPON_DUAL_DAGGER: &"lightning_barrage", Tuning.WEAPON_CHAIN_SCYTHE: &"reapers_coil"}
const ACTIVE_ROW_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "BLACK FORM", Tuning.WEAPON_DUAL_DAGGER: "BARRAGE", Tuning.WEAPON_CHAIN_SCYTHE: "REAPER'S COIL"}
const SHORT_NAMES: Dictionary = {Tuning.WEAPON_BLACK_KATANA: "KATANA", Tuning.WEAPON_DUAL_DAGGER: "DAGGER", Tuning.WEAPON_CHAIN_SCYTHE: "SCYTHE"}

var is_open: bool = false
var tab: int = TAB_STATS
## STATS: the selected item key (&"" = none yet); INVENTORY: the selected slot index.
var stats_selection: StringName = &""
var inventory_selection: int = 0
## The item under the mouse (STATS), set on mouse motion, cleared by keyboard navigation.
var hover_key: StringName = &""
## {"slot": int, "ok": bool, "reason": String, "left": float} after an equip request, else empty.
var feedback: Dictionary = {}
var snapshot: Snapshots.GameSnapshot
var colors: Dictionary = {}
var atlas: Texture2D
var frames: Dictionary = {}
## Called with a weapon id; the arena steps the core once with InputFrame.weapon_equip and returns nothing (the menu
## reads the result from `snapshot`, which the arena refreshes).
var equip_request: Callable = Callable()
var _last_mouse: Vector2 = Vector2(-1000, -1000)
var _atlas_image: Image = null
var _used_rects: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func open() -> void:
	is_open = true
	visible = true
	tab = TAB_STATS
	stats_selection = &""
	hover_key = &""
	feedback = {}
	inventory_selection = maxi(0, Weapons.IDS.find(_equipped()))
	_last_mouse = get_local_mouse_position()
	queue_redraw()


func close() -> void:
	is_open = false
	visible = false
	hover_key = &""
	feedback = {}


func _process(delta: float) -> void:
	if not is_open:
		return
	if not feedback.is_empty():
		feedback["left"] = float(feedback["left"]) - delta
		if float(feedback["left"]) <= 0.0:
			feedback = {}
	var mouse: Vector2 = get_local_mouse_position()
	if mouse.distance_squared_to(_last_mouse) > 0.01:
		_last_mouse = mouse
		hover_at(mouse)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		click(get_local_mouse_position())
		get_viewport().set_input_as_handled()


## Keyboard / gamepad, once per physics frame while open (the arena calls it instead of stepping the core).
## TAB and ESC close the menu (returns false then).
func poll_input() -> bool:
	if Input.is_action_just_pressed("menu_toggle") or Input.is_action_just_pressed("menu_back"):
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
	hover_key = &""
	feedback = {}
	queue_redraw()


# --- selection -------------------------------------------------------------------------------------------------------

## Every selectable item of the STATS tab with its rect: the weapon slot, the three Aspect slots, the stat rows.
func stats_items() -> Array[Dictionary]:
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
	return Rect2(68 + index * 29, 96, 26, 26)


static func inventory_rect(index: int) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(index % GRID_COLS, index / GRID_COLS) * GRID_STEP, Vector2(32, 32))


static func tab_rect(index: int) -> Rect2:
	var spec: Vector2i = TAB_SPECS[index]
	return Rect2(spec.x, 3, spec.y, PANEL.position.y - 2)


## Arrow keys: on STATS the nearest item in that direction (spatial), on INVENTORY the grid neighbour (clamped).
func move_selection(direction: Vector2i) -> void:
	hover_key = &""
	feedback = {}
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
		stats_selection = &"weapon"
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
	if tab == TAB_STATS:
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
	if tab == TAB_STATS:
		for item: Dictionary in stats_items():
			if Rect2(item["rect"]).has_point(pos):
				stats_selection = item["key"]
				hover_key = &""
		return
	for index: int in range(GRID_COLS * GRID_ROWS):
		if inventory_rect(index).has_point(pos):
			inventory_selection = index
			accept()


## ENTER: on INVENTORY equip the selected weapon through the core; on STATS pin the selection (first press: weapon).
func accept() -> void:
	if tab == TAB_STATS:
		if stats_selection == &"":
			stats_selection = &"weapon"
		queue_redraw()
		return
	var weapon: StringName = slot_weapon(inventory_selection)
	if weapon == &"":
		feedback = {}
		return
	if weapon != _equipped() and equip_request.is_valid():
		equip_request.call(weapon)
	var ok: bool = _equipped() == weapon
	feedback = {"slot": inventory_selection, "ok": ok, "reason": "" if ok else refusal_reason(snapshot), "left": FEEDBACK_SECONDS}
	queue_redraw()


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


func _equipped() -> StringName:
	return snapshot.player.weapon_id if snapshot != null and snapshot.player != null else Tuning.WEAPON_BLACK_KATANA


## The key of the description shown now: the hovered item, else the selection (STATS); the selected slot (INVENTORY).
func description_key() -> StringName:
	if tab == TAB_INVENTORY:
		var weapon: StringName = slot_weapon(inventory_selection)
		return weapon if weapon != &"" else &"empty"
	var key: StringName = hover_key if hover_key != &"" else stats_selection
	if key == &"weapon":
		return _equipped()
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


## Every description: key -> [title, tag, [body line, body line, numbers line]]. Weapon-dependent ones (the stat rows
## under the weapon header) follow `equipped`.
static func descriptions(equipped: StringName) -> Dictionary:
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
	d[&"breaking_edge"] = ["BREAKING EDGE", "ASPECT  KEY Z", [
		"RIGHT AFTER A SUCCESSFUL PARRY: STEP IN %s PX AND STRIKE." % num(Tuning.BREAKING_EDGE_STEP),
		"HEAVY POSTURE DAMAGE: TWO OF THEM BREAK THE COLOSSUS.",
		"%s EDGE  %s S AFTER A PARRY  %s DMG  %s POSTURE" % [num(Tuning.BREAKING_EDGE_EDGE_COST), secs(Tuning.BREAKING_EDGE_WINDOW_TICKS), num(Tuning.BREAKING_EDGE_DAMAGE), num(Tuning.BREAKING_EDGE_POSTURE)]]]
	d[&"gale_cut"] = ["GALE CUT", "ASPECT  KEY X", [
		"AIMED DASH-SLASH: HITS ALL IN A %s PX CORRIDOR AND" % num(Tuning.GALE_CUT_DISTANCE),
		"PASSES THROUGH THE BOSS. IT GIVES NO INVULNERABILITY.",
		"%s EDGE  CD %s S  %s DMG  %s POSTURE  %s PX WIDE" % [num(Tuning.GALE_CUT_EDGE_COST), secs(Tuning.GALE_CUT_COOLDOWN_TICKS), num(Tuning.GALE_CUT_DAMAGE), num(Tuning.GALE_CUT_POSTURE), num(Tuning.GALE_CUT_LANE_WIDTH)]]]
	d[&"moon_cleave"] = ["MOON CLEAVE", "ASPECT  KEY C", [
		"HOLD %s S, THEN RELEASE A CRESCENT WAVE THAT FLIES" % secs(Tuning.MOON_CLEAVE_WINDUP_TICKS),
		"%s PX AND PIERCES. GETTING HIT DURING THE HOLD CANCELS IT." % num(Tuning.MOON_CLEAVE_TRAVEL),
		"%s EDGE  CD %s S  %s DMG  %s POSTURE" % [num(Tuning.MOON_CLEAVE_EDGE_COST), secs(Tuning.MOON_CLEAVE_COOLDOWN_TICKS), num(Tuning.MOON_CLEAVE_DAMAGE), num(Tuning.MOON_CLEAVE_POSTURE)]]]
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
	var font: Font = face if face != null else Hud.ui_font()
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
	_text(at + Vector2(4, 1), letter, colors["1"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)


func _draw() -> void:
	if not is_open or colors.is_empty() or snapshot == null:
		return
	draw_rect(Rect2(0, 0, 320, 180), Color(colors["0"], VEIL_ALPHA))
	UiPanel.draw_panel(self, PANEL, &"menu", colors)
	_draw_tabs()
	_text(Vector2(160, 168), FOOTER, colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	if tab == TAB_STATS:
		_draw_stats()
	else:
		_draw_inventory()
	_draw_description(description_key())


func _draw_tabs() -> void:
	var top: float = PANEL.position.y + 1  # the panel's accent line
	for index: int in range(TAB_NAMES.size()):
		if index == tab:
			continue
		var x: float = TAB_SPECS[index].x
		var w: float = TAB_SPECS[index].y
		draw_rect(Rect2(x, 7, w, top - 7), colors["0"])
		draw_rect(Rect2(x + 1, 8, w - 2, 1), colors["f"])
		draw_rect(Rect2(x + 1, 8, 1, top - 8), colors["f"])
		draw_rect(Rect2(x + w - 2, 8, 1, top - 8), colors["f"])
		_text(Vector2(x + w / 2, 10), TAB_NAMES[index], colors["i"], Hud.menu_font(), 10, HORIZONTAL_ALIGNMENT_CENTER)
	var ax: float = TAB_SPECS[tab].x
	var aw: float = TAB_SPECS[tab].y
	draw_rect(Rect2(ax, 3, aw, top), colors["0"])
	draw_rect(Rect2(ax + 1, 4, aw - 2, 1), colors["v"])
	draw_rect(Rect2(ax + 1, 4, 1, top - 3), colors["v"])
	draw_rect(Rect2(ax + aw - 2, 4, 1, top - 3), colors["v"])
	draw_rect(Rect2(ax + 3, 6, aw - 6, 1), colors["f"])
	UiPanel.gem(self, Vector2(ax + 1, 4), &"menu", colors)
	UiPanel.gem(self, Vector2(ax + aw - 2, 4), &"menu", colors)
	_text(Vector2(ax + aw / 2, 8), TAB_NAMES[tab], colors["1"], Hud.menu_font(), 10, HORIZONTAL_ALIGNMENT_CENTER)
	var name_width: float = _text(Vector2(308, 9), "TOTOY", colors["j"], Hud.menu_font(), 10, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(308 - name_width - 6, 10), "WAYKEEPER", colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)


## The weapon's 48 px socket art: the katana's frame plus blade glyph, or the dagger's / scythe's whole medallion.
func _draw_medallion(weapon: StringName, at: Vector2) -> void:
	if Hud.MEDALLIONS.has(weapon):
		_ui(Hud.MEDALLIONS[weapon], Rect2(at, Vector2(48, 48)))
	else:
		_ui("ui_weapon_frame_1", Rect2(at, Vector2(48, 48)))
		_ui("ui_weapon_totoy_blade_1", Rect2(at + Vector2(8, 8), Vector2(32, 32)))


func _equipped_badge(rect: Rect2) -> void:
	draw_rect(rect, colors["0"])
	UiPanel.outline(self, rect, colors["v"])
	_text(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 1), "E", colors["1"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)


func highlighted_key() -> StringName:
	return hover_key if hover_key != &"" else stats_selection


func _draw_stats() -> void:
	var equipped: StringName = _equipped()
	var lit: StringName = highlighted_key()
	# the figure box: Totoy at 2x, holding the equipped weapon, on a stone strip with a shadow
	draw_rect(FIGURE, colors["0"])
	UiPanel.outline(self, FIGURE, colors["f"])
	var strip_y: float = FIGURE.end.y - 16
	draw_rect(Rect2(FIGURE.position.x + 1, strip_y, FIGURE.size.x - 2, 15), colors["e"])
	draw_rect(Rect2(FIGURE.position.x + 1, strip_y, FIGURE.size.x - 2, 1), colors["f"])
	var feet: Vector2 = Vector2(FIGURE.get_center().x, FIGURE.end.y - 9)
	_ellipse(feet, Vector2(13, 3), colors["0"])
	_draw_figure(figure_frame(equipped), feet)
	# weapon slot
	_text(Vector2(MID_X, 20), "WEAPON", colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	UiPanel.slot(self, WEAPON_SLOT, lit == &"weapon", colors)
	_draw_medallion(equipped, WEAPON_SLOT.position + Vector2.ONE)
	_equipped_badge(Rect2(WEAPON_SLOT.position + Vector2(41, 1), Vector2(8, 8)))
	_text(Vector2(MID_X, 80), WEAPON_NAMES.get(equipped, "WEAPON"), colors["1"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	# aspects
	_text(Vector2(MID_X, 89), "ASPECTS", colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	for i: int in range(3):
		var rect: Rect2 = aspect_rect(i)
		UiPanel.slot(self, rect, lit == ASPECT_KEYS[i], colors)
		_ui(Hud.ASPECT_ICONS[i], Rect2(rect.position + Vector2.ONE, Vector2(24, 24)))
		_key_badge(rect.position + Vector2(-2, 17), ["Z", "X", "C"][i])
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
		UiPanel.slot(self, rect, index == inventory_selection, colors)
		var weapon: StringName = slot_weapon(index)
		if weapon == &"":
			continue
		_draw_item_icon(weapon, rect.position)
		if weapon == equipped:
			_equipped_badge(Rect2(rect.position + Vector2(24, 1), Vector2(7, 8)))
	# the detail card
	draw_rect(CARD, colors["0"])
	UiPanel.outline(self, CARD, colors["f"])
	var cx: float = CARD.get_center().x
	var weapon: StringName = slot_weapon(inventory_selection)
	if weapon == &"":
		_text(Vector2(cx, 66), "EMPTY", colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_draw_medallion(weapon, Vector2(cx - 24, 25))
	_text(Vector2(cx, 76), WEAPON_NAMES[weapon], colors["1"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	var equipped_now: bool = weapon == equipped
	_text(Vector2(cx, 85), "EQUIPPED" if equipped_now else "NOT EQUIPPED", colors["v"] if equipped_now else colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(Rect2(CARD.position.x + 6, 95, CARD.size.x - 12, 1), colors["f"])
	var lines: Array = card_lines(weapon)
	_text(Vector2(cx, 99), lines[0], colors[lines[2]], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(cx, 107), lines[1], colors[lines[2]], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)


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
	var all: Dictionary = descriptions(_equipped())
	var entry: Array = all.get(key, all[&"none"])
	UiPanel.draw_panel(self, DESC, &"info", colors, false)
	var x0: float = DESC.position.x + 5
	var lines: Array = entry[2]
	if String(entry[0]).is_empty():
		_text(Vector2(160, DESC.position.y + 9), lines[0], colors["i"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(160, DESC.position.y + 23), lines[2], colors["f"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_text(Vector2(x0, DESC.position.y + 4), entry[0], colors["1"], Hud.menu_font(), 10)
	_text(Vector2(DESC.end.x - 6, DESC.position.y + 4), entry[1], colors["u"], null, Hud.FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT)
	for i: int in range(lines.size()):
		if not String(lines[i]).is_empty():
			_text(Vector2(x0, DESC.position.y + 13 + i * 8), lines[i], colors["o"] if i == 2 else colors["j"])
