extends SceneTree
## Builds the TAB menu's editable scenes (the redesign the owner approved on 2026-11-03, presentation/review/menu_redesign/):
##   presentation/ui/menu_shell.tscn   the veil, three tabs, the name, the big panel, the detail card's frame, the footer
##   presentation/ui/menu_hero.tscn    HERO: Totoy, level and EXP, the points, three stat rows, Respec
##   presentation/ui/menu_gear.tscn    GEAR: the weapon socket and its numbers, the Aspect sockets Z X C, the item slots 1 2
##   presentation/ui/menu_quests.tscn  QUESTS: the chapter's tasks so far
##   presentation/ui/menu_card.tscn    the detail card's text, stat list, chooser list and scroll bar
##   godot --headless --path . --script res://tools/godot/build_menu_scenes.gd
## Run it once to make the scenes; after that they are edited in Godot (running it again overwrites those edits). Every
## position is in the game's 384x216 pixels and matches presentation/review/menu_redesign/build_mockup.gd. The scenes' own
## scripts only fill in words and icons (presentation/ui/menu_*.gd); presentation/arena/character_menu.gd drives them.

const OUT: String = "res://presentation/ui/"
const INK: Color = Color("1c1824")
const CREAM: Color = Color("f4ecd6")
const STONE: Color = Color("9a9886")
const DIM: Color = Color("5a625e")
const LINE: Color = Color("444b49")
const TEAL: Color = Color("6aa89a")
const LILAC: Color = Color("8a6fa8")
const SELECT: Color = Color(0.141, 0.212, 0.361, 0.9)
const TAB_RECTS: Array[Rect2] = [Rect2(14, 9, 60, 16), Rect2(78, 9, 54, 16), Rect2(136, 9, 64, 16)]
const TAB_NAMES: Array[String] = ["HERO", "GEAR", "QUESTS"]

var cinzel: FontVariation
var pixel: FontVariation
var keys: Font
var root_node: Control


func _init() -> void:
	cinzel = FontVariation.new()
	cinzel.resource_name = "cinzel"
	cinzel.base_font = load("res://presentation/fonts/Cinzel.ttf")
	cinzel.variation_opentype = {2003265652: 900.0}
	pixel = FontVariation.new()
	pixel.resource_name = "pixel"
	pixel.base_font = load("res://presentation/fonts/PixelifySans.ttf")
	pixel.variation_opentype = {2003265652: 400.0}
	keys = load("res://art/ui_kit/pixel_keys.fnt")
	var failed: int = 0
	failed += _save(_shell(), "menu_shell")
	failed += _save(_hero(), "menu_hero")
	failed += _save(_gear(), "menu_gear")
	failed += _save(_quests(), "menu_quests")
	failed += _save(_card(), "menu_card")
	print("MENU SCENES %s" % ("OK" if failed == 0 else "FAILED"))
	quit(failed)


func _save(scene_root: Control, name: String) -> int:
	var path: String = OUT + name + ".tscn"
	var uid: int = ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	var packed: PackedScene = PackedScene.new()
	if packed.pack(scene_root) != OK:
		printerr("could not pack " + name)
		return 1
	if ResourceSaver.save(packed, path) != OK:
		printerr("could not save " + path)
		return 1
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	scene_root.free()
	return 0


# --- pieces ----------------------------------------------------------------------------------------------------------

func _start(name: String, script: String) -> Control:
	root_node = Control.new()
	root_node.name = name
	root_node.size = Vector2(384, 216)
	root_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_node.show_behind_parent = true
	root_node.set_script(load(OUT + script))
	return root_node


func _add(parent: Node, node: Node, name: String) -> Node:
	parent.add_child(node)
	node.name = name
	node.owner = root_node
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _box(parent: Node, name: String, rect: Rect2) -> Control:
	var c: Control = _add(parent, Control.new(), name) as Control
	c.position = rect.position
	c.size = rect.size
	return c


func _fill(parent: Node, name: String, rect: Rect2, color: Color, shown: bool = true) -> ColorRect:
	var c: ColorRect = _add(parent, ColorRect.new(), name) as ColorRect
	c.position = rect.position
	c.size = rect.size
	c.color = color
	c.visible = shown
	return c


func _label(parent: Node, name: String, text: String, rect: Rect2, font: Font, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l: Label = _add(parent, Label.new(), name) as Label
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("line_spacing", -1)
	l.text = text
	l.position = rect.position
	l.size = rect.size
	return l


func _nine(parent: Node, name: String, texture: String, rect: Rect2, margins: Array) -> NinePatchRect:
	var n: NinePatchRect = _add(parent, NinePatchRect.new(), name) as NinePatchRect
	n.texture = load(texture)
	n.patch_margin_left = margins[0]
	n.patch_margin_top = margins[1]
	n.patch_margin_right = margins[2]
	n.patch_margin_bottom = margins[3]
	n.position = rect.position
	n.size = rect.size
	return n


func _picture(parent: Node, name: String, rect: Rect2, texture: String = "") -> TextureRect:
	var t: TextureRect = _add(parent, TextureRect.new(), name) as TextureRect
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not texture.is_empty():
		t.texture = load(texture)
	t.position = rect.position
	t.size = rect.size
	return t


func _key(parent: Node, name: String, at: Vector2, letter: String) -> NinePatchRect:
	var badge: NinePatchRect = _nine(parent, name, "res://art/ui_kit/key_badge.png", Rect2(at, Vector2(11, 11)), [4, 4, 4, 4])
	_label(badge, "Letter", letter, Rect2(0, 1, 11, 10), keys, 8, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	return badge


# --- the scenes ------------------------------------------------------------------------------------------------------

func _shell() -> Control:
	var r: Control = _start("MenuShell", "menu_shell.gd")
	_fill(r, "Veil", Rect2(0, 0, 384, 216), Color(INK, 0.72))
	var panel: NinePatchRect = _nine(r, "Panel", "res://art/ui_kit/panel_large_ornate.png", Rect2(6, 24, 372, 176), [30, 20, 30, 20])
	panel.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	panel.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	for i: int in 3:
		var tab: NinePatchRect = _nine(r, "Tab%d" % i, "res://art/ui_kit/tab_on.png" if i == 0 else "res://art/ui_kit/tab_off.png", TAB_RECTS[i], [6, 5, 6, 5])
		_label(tab, "Name", TAB_NAMES[i], Rect2(0, 2, TAB_RECTS[i].size.x, 12), cinzel, 9, CREAM if i == 0 else STONE, HORIZONTAL_ALIGNMENT_CENTER)
	_label(r, "HeroName", "TOTOY", Rect2(250, 8, 120, 14), cinzel, 10, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	_nine(r, "Card", "res://art/ui_kit/panel_medium.png", Rect2(232, 32, 136, 162), [10, 10, 10, 10])
	var footer: HBoxContainer = _add(r, HBoxContainer.new(), "Footer") as HBoxContainer
	footer.add_theme_constant_override("separation", 3)
	footer.position = Vector2(100, 202)
	_label(footer, "KeyTemplate", "TAB", Rect2(), cinzel, 7, CREAM).visible = false
	_label(footer, "ActionTemplate", "CLOSE", Rect2(), pixel, 7, STONE).visible = false
	return r


func _hero() -> Control:
	var r: Control = _start("MenuHero", "menu_hero.gd")
	var box: NinePatchRect = _nine(r, "FigureBox", "res://art/ui_kit/slot_frame.png", Rect2(18, 34, 34, 44), [8, 8, 8, 8])
	_picture(box, "Figure", Rect2(1, 2, 32, 40))
	_label(r, "Title", "LEVEL 3", Rect2(60, 34, 160, 12), cinzel, 9, CREAM)
	_nine(r, "ExpFrame", "res://art/ui_kit/thin_bar_frame.png", Rect2(60, 48, 112, 9), [4, 0, 4, 0])
	_nine(r, "ExpFill", "res://art/ui_kit/fill_exp_thin.png", Rect2(62, 50, 54, 5), [1, 0, 2, 0])
	_label(r, "ExpText", "40 / 80 EXP", Rect2(176, 47, 50, 9), pixel, 6, LILAC)
	_label(r, "Points", "2 POINTS TO SPEND", Rect2(60, 62, 164, 10), pixel, 7, TEAL)
	_fill(r, "LineTop", Rect2(18, 82, 206, 1), LINE)
	var names: Array[String] = ["VITALITY", "MIGHT", "AGILITY"]
	var hints: Array[String] = ["MORE MAX HEALTH", "MORE DAMAGE", "FASTER DASH AND STEPS"]
	for i: int in 3:
		var row: Control = _box(r, "Row%d" % i, Rect2(18, 85 + i * 25, 206, 23))
		_fill(row, "Fill", Rect2(0, 0, 206, 23), SELECT, i == 0)
		_label(row, "Name", names[i], Rect2(6, 2, 96, 11), cinzel, 8, CREAM)
		_label(row, "Hint", hints[i], Rect2(6, 12, 100, 9), pixel, 6, STONE)
		var pips: Control = _box(row, "Pips", Rect2(100, 8, 70, 5))
		for p: int in 10:
			_fill(pips, "Pip%d" % p, Rect2(p * 7, 0, 5, 5), TEAL if p < 2 else LINE)
		var plus: NinePatchRect = _nine(row, "Plus", "res://art/ui_kit/button_normal.png", Rect2(182, 4, 16, 15), [6, 6, 6, 6])
		_label(plus, "Sign", "+", Rect2(0, 1, 16, 12), pixel, 9, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_fill(r, "LineBottom", Rect2(18, 164, 206, 1), LINE)
	var respec: NinePatchRect = _nine(r, "Respec", "res://art/ui_kit/button_normal.png", Rect2(20, 170, 58, 16), [6, 6, 6, 6])
	_label(respec, "Name", "RESPEC", Rect2(0, 3, 58, 11), cinzel, 7, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_label(r, "RespecNote", "FREE IN LANTERNFEN: ALL POINTS BACK", Rect2(84, 174, 140, 9), pixel, 6, STONE)
	_label(r, "Note", "", Rect2(20, 90, 200, 60), pixel, 7, STONE, HORIZONTAL_ALIGNMENT_LEFT, true).visible = false
	return r


func _gear() -> Control:
	var r: Control = _start("MenuGear", "menu_gear.gd")
	_label(r, "WeaponHeading", "WEAPON", Rect2(20, 34, 100, 10), cinzel, 8, TEAL)
	var medallion: TextureRect = _picture(r, "Medallion", Rect2(22, 46, 48, 52), "res://art/ui_kit/weapon_medallion.png")
	medallion.stretch_mode = TextureRect.STRETCH_KEEP
	_picture(medallion, "Glyph", Rect2(8, 9, 32, 32))
	_picture(r, "WholeMedallion", Rect2(22, 48, 48, 48)).visible = false
	_label(r, "WeaponName", "BLACK KATANA", Rect2(80, 45, 144, 12), cinzel, 9, CREAM)
	_label(r, "WeaponTag", "BALANCED  3-HIT COMBO", Rect2(80, 58, 144, 9), pixel, 6, TEAL)
	_label(r, "WeaponLine0", "DAMAGE  10/12/20", Rect2(80, 68, 144, 9), pixel, 6, STONE)
	_label(r, "WeaponLine1", "REACH  26/26/33 PX", Rect2(80, 77, 144, 9), pixel, 6, STONE)
	_label(r, "WeaponLine2", "RMB  BLACK FORM  50E", Rect2(80, 86, 144, 9), pixel, 6, LILAC)
	_fill(r, "Line", Rect2(18, 103, 206, 1), LINE)
	_label(r, "AspectsHeading", "ASPECTS", Rect2(20, 105, 100, 10), cinzel, 8, TEAL)
	for i: int in 3:
		var socket: TextureRect = _picture(r, "Socket%d" % i, Rect2(22 + i * 44, 116, 37, 40), "res://art/ui_kit/aspect_socket_open.png")
		socket.stretch_mode = TextureRect.STRETCH_KEEP
		_picture(socket, "Icon", Rect2(11, 10, 16, 16))
		_key(socket, "Key", Vector2(14, 29), ["Z", "X", "C"][i])
	_label(r, "ItemsHeading", "ITEMS", Rect2(162, 105, 64, 10), cinzel, 8, TEAL)
	for i: int in 2:
		var slot: NinePatchRect = _nine(r, "Item%d" % i, "res://art/ui_kit/slot_frame.png", Rect2(162 + i * 34, 120, 30, 30), [8, 8, 8, 8])
		_picture(slot, "Icon", Rect2(7, 7, 16, 16))
		_label(slot, "Count", "", Rect2(18, 3, 9, 9), pixel, 7, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		_key(slot, "Key", Vector2(10, 25), str(i + 1))
	return r


func _quests() -> Control:
	var r: Control = _start("MenuQuests", "menu_quests.gd")
	_label(r, "Heading", "CHAPTER 1   LANTERNFEN", Rect2(20, 34, 204, 10), cinzel, 8, TEAL)
	for i: int in 12:
		var row: Control = _box(r, "Row%d" % i, Rect2(18, 45 + i * 11, 206, 12))
		_fill(row, "Fill", Rect2(0, 0, 206, 12), SELECT, false)
		_picture(row, "Icon", Rect2(4, 0, 12, 12), "res://art/ui_kit/icon_check.png")
		_label(row, "Text", "", Rect2(20, 1, 186, 10), pixel, 7, STONE)
	return r


func _card() -> Control:
	var r: Control = _start("MenuCard", "menu_card.gd")
	_picture(r, "Icon", Rect2(240, 40, 20, 20))
	_label(r, "Title", "YOUR STATS", Rect2(242, 41, 116, 12), cinzel, 9, CREAM)
	_label(r, "Sub", "WHAT YOUR POINTS GIVE YOU NOW", Rect2(242, 53, 116, 9), pixel, 6, STONE)
	for i: int in 5:
		var row: Control = _box(r, "Stat%d" % i, Rect2(242, 68 + i * 12, 116, 9))
		_label(row, "Name", "", Rect2(0, 0, 80, 9), pixel, 7, STONE)
		_label(row, "Value", "", Rect2(36, 0, 54, 9), pixel, 7, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
		_label(row, "Extra", "", Rect2(94, 0, 22, 9), pixel, 7, TEAL)
	_label(r, "Body", "", Rect2(242, 70, 116, 70), pixel, 6, CREAM, HORIZONTAL_ALIGNMENT_LEFT, true)
	var reward: Control = _box(r, "Reward", Rect2(242, 102, 116, 9))
	_label(reward, "Name", "REWARD", Rect2(0, 0, 60, 9), pixel, 7, STONE)
	_label(reward, "Value", "", Rect2(36, 0, 80, 9), pixel, 7, LILAC, HORIZONTAL_ALIGNMENT_RIGHT)
	_fill(r, "Line", Rect2(242, 132, 116, 1), LINE)
	_label(r, "Foot", "", Rect2(242, 138, 116, 50), pixel, 6, LILAC, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i: int in 3:
		var row: Control = _box(r, "ListRow%d" % i, Rect2(239, 64 + i * 18, 116, 17))
		_fill(row, "Fill", Rect2(0, 0, 116, 17), SELECT, false)
		_picture(row, "Icon", Rect2(3, 0, 16, 16))
		_label(row, "Name", "", Rect2(22, 0, 80, 9), pixel, 7, CREAM)
		_label(row, "Sub", "", Rect2(22, 8, 80, 8), pixel, 6, STONE)
		_key(row, "Badge", Vector2(102, 3), "")
		row.visible = false
	var track: ColorRect = _fill(r, "Track", Rect2(358, 64, 2, 53), LINE, false)
	_fill(track, "Thumb", Rect2(0, 0, 2, 18), TEAL)
	_label(r, "Note", "", Rect2(242, 119, 116, 9), pixel, 6, DIM).visible = false
	_fill(r, "ListLine", Rect2(242, 130, 116, 1), LINE, false)
	_label(r, "ListBody", "", Rect2(242, 134, 116, 56), pixel, 6, CREAM, HORIZONTAL_ALIGNMENT_LEFT, true).visible = false
	return r
