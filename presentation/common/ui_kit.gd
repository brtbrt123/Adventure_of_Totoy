extends RefCounted
## The SpriteCook fantasy UI kit (carved bronze, set teal gems), installed in art/ui_kit by tools/art/install_ui_kit.py
## (review sheet: art/reference/ui_kit_spritecook_v1/kit_sheet.png). Every part is Totoy 36 with hard alpha and is drawn at
## whole game pixels. Frames are 9-sliced from their corners (edges tile, they never stretch); fixed objects (sockets,
## medallion, shield) are drawn 1:1. Presentation only: it draws what the caller says, it holds no rules.
## Use: const Kit := preload("res://presentation/common/ui_kit.gd"); Kit.panel(self, rect).

const DIR: String = "res://art/ui_kit/"
## Trough interiors (left, top, right, bottom insets in game pixels) where a fill strip sits.
const HEALTH_INSET: Vector4 = Vector4(11, 3, 11, 3)
const THIN_INSET: Vector4 = Vector4(2, 2, 3, 2)
## The socket's diamond centre and its key-holder stem, relative to its top-left (37x40).
const SOCKET_SIZE: Vector2 = Vector2(37, 40)
const SOCKET_CENTRE: Vector2 = Vector2(18.5, 18.0)
const SOCKET_KEY: Vector2 = Vector2(19.5, 34.0)

static var _meta: Dictionary = {}
static var _textures: Dictionary = {}
static var _boxes: Dictionary = {}


static func meta() -> Dictionary:
	if _meta.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "kit.json"))
		_meta = (parsed as Dictionary).get("parts", {}) if parsed is Dictionary else {}
	return _meta


static func tex(part: String) -> Texture2D:
	if not _textures.has(part):
		_textures[part] = load(DIR + part + ".png") as Texture2D if ResourceLoader.exists(DIR + part + ".png") else null
	return _textures[part]


static func size_of(part: String) -> Vector2:
	var entry: Dictionary = meta().get(part, {})
	var size: Array = entry.get("size", [0, 0])
	return Vector2(float(size[0]), float(size[1]))


## The part's 9-slice borders (left, top, right, bottom); zeros for fixed parts.
static func borders(part: String) -> Array:
	var entry: Dictionary = meta().get(part, {})
	return entry.get("nine_slice", [0, 0, 0, 0])


static func _box(part: String) -> StyleBoxTexture:
	if not _boxes.has(part):
		var box: StyleBoxTexture = StyleBoxTexture.new()
		box.texture = tex(part)
		var b: Array = borders(part)
		box.texture_margin_left = float(b[0])
		box.texture_margin_top = float(b[1])
		box.texture_margin_right = float(b[2])
		box.texture_margin_bottom = float(b[3])
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		_boxes[part] = box
	return _boxes[part]


## A 9-sliced part at `rect`, clamped to its corner sizes so a small rect never draws a broken frame.
static func nine(canvas: CanvasItem, part: String, rect: Rect2, alpha: float = 1.0) -> void:
	if tex(part) == null or alpha <= 0.0:
		return
	var b: Array = borders(part)
	var r: Rect2 = Rect2(rect.position.round(), Vector2(maxf(rect.size.x, float(b[0] + b[2])), maxf(rect.size.y, float(b[1] + b[3]))).round())
	var box: StyleBoxTexture = _box(part)
	box.modulate_color = Color(1, 1, 1, alpha)
	canvas.draw_style_box(box, r)
	box.modulate_color = Color.WHITE


## A part drawn 1:1 at `at` (top-left).
static func put(canvas: CanvasItem, part: String, at: Vector2) -> void:
	var t: Texture2D = tex(part)
	if t != null:
		canvas.draw_texture(t, at.round())


## A frame for pop-ups and cards. `ornate` is the large carved frame with a gem in each corner (menus, dialogue, results).
static func panel(canvas: CanvasItem, rect: Rect2, ornate: bool = false) -> void:
	nine(canvas, "panel_large_ornate" if ornate else "panel_medium", rect)


## The area inside a frame that text and icons may use (clear of the corner ornaments' edge bronze).
static func inner(rect: Rect2, ornate: bool = false) -> Rect2:
	var inset: float = 9.0 if ornate else 7.0
	return rect.grow(-inset)


## An item slot: the frame, the stone floor (or ink while locked/empty), the padlock when locked. The icon is the caller's.
static func slot(canvas: CanvasItem, rect: Rect2, state: StringName = &"normal") -> void:
	nine(canvas, "slot_frame", rect)
	var inside: Rect2 = rect.grow(-3.0)
	if state == &"normal" or state == &"cooldown":
		var floor_tex: Texture2D = tex("slot_floor")
		if floor_tex != null:
			canvas.draw_texture_rect(floor_tex, inside, true)
	if state == &"locked":
		put(canvas, "icon_padlock", rect.get_center() - size_of("icon_padlock") * 0.5)
	elif state == &"cooldown":
		put(canvas, "cooldown_sweep", rect.get_center() - size_of("cooldown_sweep") * 0.5)


## A diamond Aspect socket (37x40) at `at`; the caller draws the 16x16 icon at socket_icon_rect(at) and the key at socket_key(at).
static func socket(canvas: CanvasItem, at: Vector2, locked: bool) -> void:
	put(canvas, "aspect_socket_locked" if locked else "aspect_socket_open", at)


static func socket_icon_rect(at: Vector2) -> Rect2:
	return Rect2((at + SOCKET_CENTRE - Vector2(8, 8)).round(), Vector2(16, 16))


static func socket_key(at: Vector2) -> Vector2:
	return at + SOCKET_KEY


## The weapon medallion (48x52); the weapon glyph is the caller's (32x32, centred at medallion_centre).
static func medallion(canvas: CanvasItem, at: Vector2) -> void:
	put(canvas, "weapon_medallion", at)


static func medallion_centre(at: Vector2) -> Vector2:
	return at + Vector2(24, 25)


## A bar trough with fill strips drawn from its left: `fills` is [[part, fraction 0..1], ...] back to front.
## `thin` selects the slim trough. Returns the interior rect so the caller can place text.
static func bar(canvas: CanvasItem, at: Vector2, width: float, fills: Array, thin: bool = false) -> Rect2:
	var frame: String = "thin_bar_frame" if thin else "health_bar_frame"
	var height: float = size_of(frame).y
	nine(canvas, frame, Rect2(at, Vector2(width, height)))
	var inset: Vector4 = THIN_INSET if thin else HEALTH_INSET
	var inside: Rect2 = Rect2(at + Vector2(inset.x, inset.y), Vector2(width - inset.x - inset.z, height - inset.y - inset.w))
	for entry: Array in fills:
		var amount: float = floorf(inside.size.x * clampf(float(entry[1]), 0.0, 1.0))
		var part: String = String(entry[0])
		var b: Array = borders(part)
		if amount >= float(b[0] + b[2]):
			var strip_height: float = size_of(part).y
			nine(canvas, part, Rect2(inside.position + Vector2(0, floorf((inside.size.y - strip_height) * 0.5)), Vector2(amount, strip_height)))
	return inside


## The vertical level pillar (21x`height`) with the EXP fill (`color`, `fill` 0..1) rising inside its tube.
static func pillar(canvas: CanvasItem, at: Vector2, height: float, fill: float, color: Color, highlight: Color) -> void:
	var width: float = size_of("level_pillar").x
	nine(canvas, "level_pillar", Rect2(at, Vector2(width, height)))
	var tube: Rect2 = Rect2(at + Vector2(7, 30), Vector2(width - 14, height - 30 - 12))
	var amount: float = floorf(tube.size.y * clampf(fill, 0.0, 1.0))
	if amount > 0.0:
		canvas.draw_rect(Rect2(tube.position.x, tube.end.y - amount, tube.size.x, amount), color)
		canvas.draw_rect(Rect2(tube.position.x, tube.end.y - amount, tube.size.x, 1), highlight)


## The level shield (24x28) at `at`; its number is the caller's, centred at shield_centre.
static func shield(canvas: CanvasItem, at: Vector2) -> void:
	put(canvas, "level_shield", at)


static func shield_centre(at: Vector2) -> Vector2:
	return at + Vector2(12, 11)


## The swallowtail ribbon at `rect` (width stretches between its tails; its height is the art's).
static func ribbon(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> Rect2:
	var h: float = size_of("name_ribbon").y
	nine(canvas, "name_ribbon", Rect2(rect.position, Vector2(rect.size.x, h)), alpha)
	return Rect2(rect.position + Vector2(24, 2), Vector2(rect.size.x - 48, h - 4))


## A tab (on = selected) or a button ("normal", "pressed", "locked").
static func tab(canvas: CanvasItem, rect: Rect2, on: bool) -> void:
	nine(canvas, "tab_on" if on else "tab_off", rect)


static func button(canvas: CanvasItem, rect: Rect2, state: StringName = &"normal") -> void:
	nine(canvas, "button_" + String(state), rect)


## A key badge (>= 8x8) at `rect`; the letter is the caller's.
static func badge(canvas: CanvasItem, rect: Rect2) -> void:
	nine(canvas, "key_badge", rect)
