extends SceneTree
## Review-only mockup of a redesigned TAB menu (2026-11-03, owner: "fix the tab menu improve the layout, and design, make it
## consistent in layout and design, make sure every function is useful and needed"). It builds the proposed tabs out of the
## real kit frames (art/ui_kit), fonts, icons and game text over the village and saves one picture per state to
## presentation/review/menu_redesign/. Nothing in the game uses it; the real menu is presentation/arena/character_menu.gd.
##   godot --path . --resolution 1152x648 --script res://presentation/review/menu_redesign/build_mockup.gd
## One layout for every tab: the content on the left (x 16..226), a detail card on the right (x 232..368) that always
## describes what is selected, the same selection mark (teal corners on a dark blue row), the same fonts (Cinzel for
## titles, Pixelify for text, the key font only on key badges) and a footer that lists only the keys that work here.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const CharacterMenu := preload("res://presentation/arena/character_menu.gd")
const Hud := preload("res://presentation/arena/hud.gd")
const Kit := preload("res://presentation/common/ui_kit.gd")
const Aspects := preload("res://core/aspects.gd")
const Tuning := preload("res://core/tuning.gd")
const QuestBook := preload("res://core/quest_book.gd")
const OUT: String = "res://presentation/review/menu_redesign/"

const INK: Color = Color("1c1824")
const CREAM: Color = Color("f4ecd6")
const GREY: Color = Color("9a9886")
const DIM: Color = Color("5a625e")
const LINE: Color = Color("444b49")
const TEAL: Color = Color("6aa89a")
const LILAC: Color = Color("8a6fa8")
const SELECT: Color = Color(0.141, 0.212, 0.361, 0.9)

const TABS: Array[String] = ["HERO", "GEAR", "QUESTS"]
const TAB_X: Array[int] = [14, 78, 136]
const TAB_W: Array[int] = [60, 54, 64]
const LEFT: Rect2 = Rect2(16, 34, 210, 158)
const CARD: Rect2 = Rect2(232, 32, 136, 162)
const WEAPONS: Array[StringName] = [&"black_katana", &"dual_dagger", &"chain_scythe", &"star_staff"]

var cinzel: FontVariation
var pixel: FontVariation
var keys: Font
var atlas: Texture2D
var frames: Dictionary = {}
var page: Control
var explore: Explore


func _init() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	cinzel = FontVariation.new()
	cinzel.base_font = load("res://presentation/fonts/Cinzel.ttf")
	cinzel.variation_opentype = {2003265652: 900.0}
	pixel = FontVariation.new()
	pixel.base_font = load("res://presentation/fonts/PixelifySans.ttf")
	pixel.variation_opentype = {2003265652: 400.0}
	keys = load("res://art/ui_kit/pixel_keys.fnt")
	atlas = load("res://art/build/sprites.png")
	frames = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	OS.set_environment("TOTOY_SAVE_PATH", "user://menu_mockup_save.json")
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered"})
	explore = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(explore)
	explore.set_physics_process(false)
	explore.fade_phase = &""
	explore.conversation.controls_open = false
	await process_frame
	explore.core.place_at(Vector2(300, 250))
	explore.snapshot = explore.core.snapshot()
	explore._update_camera()
	(explore.get_node("HUD") as CanvasLayer).visible = false
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	page = Control.new()
	page.size = Vector2(384, 216)
	page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(page)
	await _shot("1_hero", _hero)
	await _shot("2_gear", _gear_weapon)
	await _shot("3_gear_weapon_list", _gear_weapon_list)
	await _shot("4_gear_aspect_list", _gear_aspect_list)
	await _shot("5_quests", _quests)
	print("MOCKUP DONE")
	quit()


func _shot(name: String, build: Callable) -> void:
	for child: Node in page.get_children():
		child.free()
	build.call()
	for i: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


# --- pieces ----------------------------------------------------------------------------------------------------------

func _nine(path: String, rect: Rect2, m: Array) -> NinePatchRect:
	var n: NinePatchRect = NinePatchRect.new()
	n.texture = load(path)
	n.position = rect.position
	n.size = rect.size
	n.patch_margin_left = m[0]
	n.patch_margin_top = m[1]
	n.patch_margin_right = m[2]
	n.patch_margin_bottom = m[3]
	page.add_child(n)
	return n


func _label(text: String, rect: Rect2, font: Font, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -1)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.clip_text = not wrap
	l.text = text
	page.add_child(l)
	l.position = rect.position
	l.size = rect.size
	return l


func _fill(rect: Rect2, color: Color) -> void:
	var c: ColorRect = ColorRect.new()
	c.position = rect.position
	c.size = rect.size
	c.color = color
	page.add_child(c)


func _texture(path: String, at: Vector2) -> void:
	var t: TextureRect = TextureRect.new()
	t.texture = load(path)
	t.position = at
	page.add_child(t)


## A sprite-sheet frame drawn into `rect` (scaled to fit; `crop` picks a part of the frame).
func _sprite(frame_name: String, rect: Rect2, crop: Rect2 = Rect2(), tint: Color = Color.WHITE) -> void:
	if not frames.has(frame_name):
		return
	var f: Dictionary = frames[frame_name]
	var region: Rect2 = Rect2(f["x"], f["y"], f["w"], f["h"])
	if crop.size != Vector2.ZERO:
		region = Rect2(region.position + crop.position, crop.size)
	var a: AtlasTexture = AtlasTexture.new()
	a.atlas = atlas
	a.region = region
	var t: TextureRect = TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = a
	t.modulate = tint
	page.add_child(t)
	t.position = rect.position
	t.size = rect.size


func _key(letter: String, at: Vector2) -> void:
	_nine("res://art/ui_kit/key_badge.png", Rect2(at, Vector2(11, 11)), [4, 4, 4, 4])
	_label(letter, Rect2(at + Vector2(0, 1), Vector2(11, 10)), keys, 8, CREAM, HORIZONTAL_ALIGNMENT_CENTER)


## The one selection mark: a dark blue row with teal corners.
func _select(rect: Rect2, fill: bool = true) -> void:
	if fill:
		_fill(rect, SELECT)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x - 4, rect.position.y), Vector2(rect.position.x, rect.end.y - 1), Vector2(rect.end.x - 4, rect.end.y - 1)]:
		_fill(Rect2(corner, Vector2(4, 1)), TEAL)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x - 1, rect.position.y), Vector2(rect.position.x, rect.end.y - 4), Vector2(rect.end.x - 1, rect.end.y - 4)]:
		_fill(Rect2(corner, Vector2(1, 4)), TEAL)


func _heading(text: String, at: Vector2) -> void:
	_label(text, Rect2(at, Vector2(200, 10)), cinzel, 8, TEAL)


func _shell(active: int, footer: String) -> void:
	_fill(Rect2(0, 0, 384, 216), Color(INK, 0.72))
	for i: int in TABS.size():
		var on: bool = i == active
		_nine("res://art/ui_kit/tab_on.png" if on else "res://art/ui_kit/tab_off.png", Rect2(TAB_X[i], 9, TAB_W[i], 16), [6, 5, 6, 5])
		_label(TABS[i], Rect2(TAB_X[i], 11, TAB_W[i], 12), cinzel, 9, CREAM if on else GREY, HORIZONTAL_ALIGNMENT_CENTER)
	_label("TOTOY", Rect2(250, 8, 120, 14), cinzel, 10, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	_nine("res://art/ui_kit/panel_large_ornate.png", Rect2(6, 24, 372, 176), [30, 20, 30, 20])
	_nine("res://art/ui_kit/panel_medium.png", CARD, [10, 10, 10, 10])
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	page.add_child(row)
	var pairs: PackedStringArray = footer.split("|")
	for i: int in pairs.size():
		var bits: PackedStringArray = pairs[i].split(":")
		for j: int in bits.size():
			var l: Label = Label.new()
			l.add_theme_font_override("font", cinzel if j == 0 else pixel)
			l.add_theme_font_size_override("font_size", 7)
			l.add_theme_color_override("font_color", CREAM if j == 0 else GREY)
			l.text = bits[j].strip_edges() + ("      " if j == bits.size() - 1 and i < pairs.size() - 1 else "")
			row.add_child(l)
	row.reset_size()
	row.position = Vector2(round((384 - row.size.x) / 2.0), 202)


func _card_title(text: String, sub: String, sub_color: Color) -> void:
	_label(text, Rect2(CARD.position + Vector2(10, 9), Vector2(116, 12)), cinzel, 9, CREAM)
	if not sub.is_empty():
		_label(sub, Rect2(CARD.position + Vector2(10, 21), Vector2(116, 9)), pixel, 6, sub_color)


func _card_text(text: String, y: float, color: Color = CREAM, size: int = 6) -> Label:
	return _label(text, Rect2(CARD.position.x + 10, y, 116, 60), pixel, size, color, HORIZONTAL_ALIGNMENT_LEFT, true)


# --- HERO --------------------------------------------------------------------------------------------------------------

func _hero() -> void:
	_shell(0, "ARROWS:CHOOSE|ENTER:ADD A POINT|Q / E:SWITCH|TAB:CLOSE")
	explore.core.set_exp(95)
	explore.core.stats[&"vitality"] = 2
	explore.core.stats[&"might"] = 1
	var snap: Explore.ExploreCore.ExploreSnapshot = explore.core.snapshot()
	var level: int = snap.level
	var stats: Dictionary = {&"vitality": 2, &"might": 1, &"agility": 0}
	var unspent: int = snap.stat_points_unspent
	# the hero box: figure, level, EXP bar, points
	_nine("res://art/ui_kit/slot_frame.png", Rect2(18, 34, 34, 44), [8, 8, 8, 8])
	_sprite(CharacterMenu.figure_frame(&"black_katana"), Rect2(19, 36, 32, 40))
	_label("LEVEL %d" % level, Rect2(60, 34, 120, 12), cinzel, 9, CREAM)
	_nine("res://art/ui_kit/thin_bar_frame.png", Rect2(60, 48, 112, 9), [4, 0, 4, 0])
	var fraction: float = float(snap.exp) / maxf(1.0, float(snap.exp_to_next))
	_nine("res://art/ui_kit/fill_exp_thin.png", Rect2(62, 50, maxf(3.0, 108 * fraction), 5), [1, 0, 2, 0])
	_label("%d / %d EXP" % [snap.exp, snap.exp_to_next], Rect2(176, 47, 50, 9), pixel, 6, LILAC)
	_label("%d POINT TO SPEND" % unspent if unspent == 1 else "%d POINTS TO SPEND" % unspent, Rect2(60, 62, 160, 10), pixel, 7, TEAL)
	_fill(Rect2(18, 82, 206, 1), LINE)
	var rows: Array = [["VITALITY", "MORE MAX HEALTH", &"vitality"], ["MIGHT", "MORE DAMAGE", &"might"], ["AGILITY", "FASTER DASH AND STEPS", &"agility"]]
	for i: int in rows.size():
		var y: float = 87 + i * 25
		if i == 0:
			_select(Rect2(18, y - 2, 206, 23))
		_label(rows[i][0], Rect2(24, y, 100, 11), cinzel, 8, CREAM)
		_label(rows[i][1], Rect2(24, y + 10, 100, 9), pixel, 6, GREY)
		var value: int = int(stats[rows[i][2]])
		for p: int in 10:
			_fill(Rect2(118 + p * 7, y + 6, 5, 5), TEAL if p < value else LINE)
		_nine("res://art/ui_kit/button_normal.png", Rect2(200, y + 2, 16, 15), [6, 6, 6, 6])
		_label("+", Rect2(200, y + 3, 16, 12), pixel, 9, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_fill(Rect2(18, 164, 206, 1), LINE)
	_nine("res://art/ui_kit/button_normal.png", Rect2(20, 170, 58, 16), [6, 6, 6, 6])
	_label("RESPEC", Rect2(20, 173, 58, 11), cinzel, 7, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_label("FREE IN LANTERNFEN: ALL POINTS BACK", Rect2(84, 174, 140, 9), pixel, 6, GREY)
	# the card: what the points do, now
	_card_title("YOUR STATS", "WHAT YOUR POINTS GIVE YOU NOW", GREY)
	var hp: int = Tuning.PLAYER_MAX_HP + Tuning.LEVEL_HP_BONUS * (level - 1) + Tuning.VITALITY_HP_PER_POINT * int(stats[&"vitality"])
	var dash_ticks: int = Tuning.DASH_COOLDOWN_TICKS - Tuning.AGILITY_DASH_COOLDOWN_TICKS_PER_POINT * mini(int(stats[&"agility"]), Tuning.AGILITY_DASH_POINTS)
	var lines: Array = [
		["HEALTH", "%d" % hp, "+%d" % Tuning.VITALITY_HP_PER_POINT],
		["DAMAGE", "+%d%%" % roundi(Tuning.MIGHT_DAMAGE_PER_POINT * 100 * int(stats[&"might"])), ""],
		["DASH COOLDOWN", "%.2f S" % (dash_ticks / 60.0), ""],
		["MOVE SPEED", "%d PX/S" % roundi(Tuning.PLAYER_SPEED * 60.0 * (1.0 + Tuning.AGILITY_SPEED_PER_POINT * int(stats[&"agility"]))), ""],
		["EDGE", "%d MAX" % roundi(Tuning.EDGE_MAX), ""],
	]
	for i: int in lines.size():
		var y: float = CARD.position.y + 36 + i * 12
		_label(lines[i][0], Rect2(CARD.position.x + 10, y, 80, 9), pixel, 7, GREY)
		_label(lines[i][1], Rect2(CARD.position.x + 46, y, 54, 9), pixel, 7, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		if not String(lines[i][2]).is_empty():
			_label(lines[i][2], Rect2(CARD.position.x + 104, y, 22, 9), pixel, 7, TEAL)
	_fill(Rect2(CARD.position.x + 10, CARD.position.y + 100, 116, 1), LINE)
	_card_text("VITALITY: +%d MAX HEALTH A POINT, AND THE POINT HEALS YOU AT ONCE. UP TO 10 POINTS." % Tuning.VITALITY_HP_PER_POINT, CARD.position.y + 106)


# --- GEAR --------------------------------------------------------------------------------------------------------------

const SLOTTED: Array[StringName] = [&"sprint", &"gale_cut", &"moon_cleave"]
const OWNED: Array[StringName] = [&"breaking_edge", &"gale_cut", &"moon_cleave", &"spirit_lantern", &"sprint"]
const WEAPON_TAGS: Dictionary = {&"black_katana": "BALANCED", &"dual_dagger": "FAST", &"chain_scythe": "WIDE SWEEPS", &"star_staff": "RANGED CASTS"}
## The card's list: rows of this height, this many in view; more rows scroll (a bar on the right shows where you are).
const LIST_ROW: float = 18.0
const LIST_ROWS: int = 3


## A weapon's small icon: the dagger's / scythe's / staff's medallion without its ring, or the katana's glyph.
func _weapon_icon(weapon: StringName, rect: Rect2) -> void:
	if Hud.MEDALLIONS.has(weapon):
		_sprite(Hud.MEDALLIONS[weapon], rect, Rect2(8, 8, 32, 32))
	else:
		_sprite("ui_weapon_totoy_blade_1", rect)


## The left side of GEAR: one weapon socket with the weapon's name and numbers, the three Aspect sockets, the item slot.
func _gear_slots(selected: String) -> void:
	var weapon: StringName = &"black_katana"
	var w: Dictionary = CharacterMenu.weapon_data(weapon)
	_heading("WEAPON", Vector2(20, 34))
	var at: Vector2 = Vector2(22, 46)
	_texture("res://art/ui_kit/weapon_medallion.png", at)
	_sprite("ui_weapon_totoy_blade_1", Rect2(at + Vector2(8, 9), Vector2(32, 32)))
	if selected == "weapon":
		_select(Rect2(at - Vector2(2, 2), Vector2(52, 56)), false)
	_label(CharacterMenu.WEAPON_NAMES[weapon], Rect2(80, 45, 144, 12), cinzel, 9, CREAM)
	_label("%s  %d-HIT COMBO" % [WEAPON_TAGS[weapon], w["combo"]], Rect2(80, 58, 144, 9), pixel, 6, TEAL)
	_label("DAMAGE  %s" % CharacterMenu.damage_text(w), Rect2(80, 68, 144, 9), pixel, 6, GREY)
	_label("REACH  %s PX" % CharacterMenu.reach_text(w), Rect2(80, 77, 144, 9), pixel, 6, GREY)
	_label("RMB  %s  %dE" % [CharacterMenu.ACTIVE_ROW_NAMES[weapon], roundi(float(w["cost"]))], Rect2(80, 86, 144, 9), pixel, 6, LILAC)
	_fill(Rect2(18, 103, 206, 1), LINE)
	_heading("ASPECTS", Vector2(20, 105))
	for i: int in 3:
		var s: Vector2 = Vector2(22 + i * 44, 116)
		_texture("res://art/ui_kit/aspect_socket_open.png", s)
		_sprite(Hud.aspect_icon(SLOTTED[i]), Kit.socket_icon_rect(s))
		_key(["Z", "X", "C"][i], (s + Kit.SOCKET_KEY - Vector2(5.5, 5.5)).round())
		if selected == "socket_%d" % i:
			_select(Rect2(s - Vector2(3, 3), Vector2(43, 50)), false)
	# two item slots (keys 1 and 2): the herbs in the first, the second empty until there is another kind of item
	_heading("ITEMS", Vector2(162, 105))
	for i: int in 2:
		var slot: Rect2 = Rect2(162 + i * 34, 120, 30, 30)
		_nine("res://art/ui_kit/slot_frame.png", slot, [8, 8, 8, 8])
		if i == 0:
			_sprite("hud_copper_herb", slot.grow(-7))
			_label("3", Rect2(slot.position + Vector2(18, 3), Vector2(9, 9)), pixel, 7, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		_key(str(i + 1), (slot.position + Vector2(slot.size.x / 2.0 - 5.5, 25)).round())
		if selected == "item_%d" % i:
			_select(slot.grow(2), false)


## The card as a chooser: title and hint, LIST_ROWS rows from `first` ({icon: Callable(Rect2), name, sub, color, badge}), the
## highlighted row, a scroll bar when the list is longer than the window, a note, then the highlighted row's text under a line.
func _chooser(title: String, hint: String, rows: Array, selected: int, first: int, note: String, text: String) -> void:
	_label(title, Rect2(CARD.position + Vector2(10, 9), Vector2(116, 12)), cinzel, 9, CREAM)
	_label(hint, Rect2(CARD.position + Vector2(10, 21), Vector2(116, 9)), pixel, 6, GREY)
	var top: float = CARD.position.y + 32
	for i: int in range(first, mini(rows.size(), first + LIST_ROWS)):
		var row: Rect2 = Rect2(CARD.position.x + 7, top + (i - first) * LIST_ROW, 116, LIST_ROW - 1)
		if i == selected:
			_select(row)
		(rows[i]["icon"] as Callable).call(Rect2(row.position + Vector2(3, 0), Vector2(16, 16)))
		_label(rows[i]["name"], Rect2(row.position + Vector2(22, 0), Vector2(80, 9)), pixel, 7, CREAM)
		_label(rows[i]["sub"], Rect2(row.position + Vector2(22, 8), Vector2(80, 8)), pixel, 6, rows[i]["color"])
		if not String(rows[i].get("badge", "")).is_empty():
			_key(rows[i]["badge"], row.position + Vector2(102, 3))
	if rows.size() > LIST_ROWS:
		var track: Rect2 = Rect2(CARD.position.x + 126, top, 2, LIST_ROW * LIST_ROWS - 1)
		_fill(track, LINE)
		var h: float = round(track.size.y * LIST_ROWS / rows.size())
		var y0: float = round((track.size.y - h) * first / float(rows.size() - LIST_ROWS))
		_fill(Rect2(track.position.x, track.position.y + y0, 2, h), TEAL)
	var y: float = top + LIST_ROW * LIST_ROWS + 1
	if not note.is_empty():
		_label(note, Rect2(CARD.position.x + 10, y, 116, 9), pixel, 6, DIM)
	_fill(Rect2(CARD.position.x + 10, y + 11, 116, 1), LINE)
	_card_text(text, y + 15)


## GEAR with the weapon socket selected: the card tells what the weapon does.
func _gear_weapon() -> void:
	_shell(1, "ARROWS:CHOOSE|ENTER:CHANGE WEAPON|Q / E:SWITCH|TAB:CLOSE")
	_gear_slots("weapon")
	var d: Array = CharacterMenu.descriptions(&"black_katana", SLOTTED)[&"black_katana"]
	_weapon_icon(&"black_katana", Rect2(CARD.position + Vector2(8, 8), Vector2(20, 20)))
	_label("BLACK KATANA", Rect2(CARD.position + Vector2(32, 9), Vector2(96, 12)), cinzel, 9, CREAM)
	_label("EQUIPPED", Rect2(CARD.position + Vector2(32, 21), Vector2(96, 9)), pixel, 6, TEAL)
	_card_text(String(d[2][0]) + " " + String(d[2][1]), CARD.position.y + 38)
	_fill(Rect2(CARD.position.x + 10, CARD.position.y + 112, 116, 1), LINE)
	_card_text(String(d[2][2]), CARD.position.y + 117, LILAC)


## After ENTER on the weapon socket: the weapons in the card, three in view, the rest a scroll away.
func _gear_weapon_list() -> void:
	_shell(1, "UP / DOWN:SCROLL|ENTER:EQUIP|ESC:BACK|TAB:CLOSE")
	_gear_slots("weapon")
	var rows: Array = []
	for w: StringName in WEAPONS:
		var data: Dictionary = CharacterMenu.weapon_data(w)
		var on: bool = w == &"black_katana"
		rows.append({"icon": _weapon_row_icon.bind(w), "name": CharacterMenu.WEAPON_NAMES[w], "sub": "EQUIPPED" if on else "%s  %d-HIT" % [WEAPON_TAGS[w], data["combo"]],
			"color": TEAL if on else GREY, "badge": "E" if on else ""})
	var d: Array = CharacterMenu.descriptions(&"black_katana", SLOTTED)[&"dual_dagger"]
	_chooser("WEAPONS", "CHOOSE ONE TO EQUIP", rows, 1, 0, "", String(d[2][0]) + " " + String(d[2][1]))


## After ENTER on socket X: the owned Aspects in the card, the same list.
func _gear_aspect_list() -> void:
	_shell(1, "UP / DOWN:SCROLL|ENTER:SET IN X|ESC:BACK|TAB:CLOSE")
	_gear_slots("socket_1")
	var rows: Array = []
	for a: StringName in OWNED:
		var cd: int = Aspects.cooldown(a)
		var slot: int = SLOTTED.find(a)
		rows.append({"icon": _aspect_row_icon.bind(a), "name": Aspects.display_name(a).to_upper(),
			"sub": "%d EDGE" % roundi(Aspects.edge_cost(a)) + ("  CD %d S" % roundi(cd / 60.0) if cd > 0 else ""), "color": LILAC,
			"badge": ["Z", "X", "C"][slot] if slot >= 0 else ""})
	var all: Dictionary = CharacterMenu.descriptions(&"black_katana", SLOTTED)
	_chooser("SOCKET  X", "CHOOSE AN ASPECT", rows, 3, 1, "%d MORE TO FIND" % (Aspects.ALL.size() - OWNED.size()),
		String(all[&"spirit_lantern"][2][0]) + " " + String(all[&"spirit_lantern"][2][1]))


func _aspect_row_icon(rect: Rect2, aspect: StringName) -> void:
	_sprite(Hud.aspect_icon(aspect), rect)


# --- QUESTS ------------------------------------------------------------------------------------------------------------

func _quests() -> void:
	_shell(2, "Q / E:SWITCH|TAB:CLOSE")
	_heading("CHAPTER 1   LANTERNFEN", Vector2(20, 34))
	var steps: Array = QuestBook.steps(QuestBook.default_book())
	var current: int = 9
	for i: int in mini(current + 1, steps.size()):
		var y: float = 47 + i * 12
		var now: bool = i == current
		if now:
			_select(Rect2(18, y - 2, 206, 13))
		_texture("res://art/ui_kit/icon_rune.png" if now else "res://art/ui_kit/icon_check.png", Vector2(22, y - 1))
		_label(String(steps[i].get("objective", "")).to_upper(), Rect2(38, y, 186, 10), pixel, 7, CREAM if now else GREY)
	_card_title("CURRENT TASK", "MARKED ON THE ROAD WITH A RUNE", GREY)
	var step: Dictionary = steps[current]
	_card_text(String(step.get("objective", "")).to_upper(), CARD.position.y + 40, CREAM, 7)
	var reward: Dictionary = step.get("reward", {})
	var parts: Array[String] = []
	if int(reward.get("exp", 0)) > 0:
		parts.append("+%d EXP" % int(reward["exp"]))
	for item: Dictionary in reward.get("items", []):
		parts.append("%d %s" % [int(item.get("quantity", 1)), String(item.get("name", item.get("item", ""))).to_upper()])
	if not parts.is_empty():
		_label("REWARD", Rect2(CARD.position.x + 10, CARD.position.y + 70, 60, 9), pixel, 7, GREY)
		_label("  ".join(parts), Rect2(CARD.position.x + 46, CARD.position.y + 70, 80, 9), pixel, 7, LILAC, HORIZONTAL_ALIGNMENT_RIGHT)
	_fill(Rect2(CARD.position.x + 10, CARD.position.y + 112, 116, 1), LINE)
	_card_text(String(QuestBook.blocked_text(QuestBook.default_book())).to_upper(), CARD.position.y + 118, DIM)


func _weapon_row_icon(rect: Rect2, weapon: StringName) -> void:
	_weapon_icon(weapon, rect)
