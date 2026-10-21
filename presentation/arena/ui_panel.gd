extends RefCounted
## The one shared frame for every pop-up (approved mockups 2026-10-21, docs/previews/character_menu_README.md): the
## character menu and its description box, the HUD skill tooltip and the DEFEAT / VICTORY panels.
## Everything is filled rectangles and single pixels on the 320x180 grid (hard-edged at any window size); text is
## drawn by the caller with the HUD's font helpers (decision 0004). Use: const UiPanel := preload("res://presentation/arena/ui_panel.gd").
##
## Frame layers from the outside in: 1 px ink edge, 1 px accent line, 1 px ink, a 1 px bevel (light top/left, dark
## bottom/right), the ink fill; plus a 5x5 diamond gem on each corner of the accent line.

## A theme is a few palette symbols. No reserved combat colours (gold x/y, red z/A).
const THEMES: Dictionary = {
	&"menu": {"accent": "v", "bevel_hi": "f", "bevel_lo": "8", "gem": "1", "plate": "k"},  # lilac, the HUD Edge colour
	&"info": {"accent": "t", "bevel_hi": "f", "bevel_lo": "8", "gem": "u", "plate": "k"},  # teal, the HUD HP colour
	&"victory": {"accent": "u", "bevel_hi": "g", "bevel_lo": "8", "gem": "p", "plate": "t"},  # teal and pale water
	&"defeat": {"accent": "q", "bevel_hi": "a", "bevel_lo": "8", "gem": "s", "plate": "9"},  # muted skin/dirt, no red
}
## The corner gem: 0 = ink, a = accent, g = the theme's gem colour.
## How many frames were drawn since start (tests check that a pop-up really used the shared frame).
static var drawn: int = 0
const GEM: Array[String] = ["..0..", ".0a0.", "0aga0", ".0a0.", "..0.."]


static func theme(name: StringName) -> Dictionary:
	return THEMES.get(name, THEMES[&"menu"])


static func px(canvas: CanvasItem, x: float, y: float, color: Color) -> void:
	canvas.draw_rect(Rect2(x, y, 1, 1), color)


static func outline(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	canvas.draw_rect(Rect2(x, y, w, 1), color)
	canvas.draw_rect(Rect2(x, y + h - 1, w, 1), color)
	canvas.draw_rect(Rect2(x, y, 1, h), color)
	canvas.draw_rect(Rect2(x + w - 1, y, 1, h), color)


## A 5x5 diamond centred on `centre`.
static func gem(canvas: CanvasItem, centre: Vector2, theme_name: StringName, colors: Dictionary) -> void:
	var t: Dictionary = theme(theme_name)
	for j: int in range(GEM.size()):
		var row: String = GEM[j]
		for i: int in range(row.length()):
			var ch: String = row[i]
			if ch == ".":
				continue
			var symbol: String = "0" if ch == "0" else (t["gem"] if ch == "g" else t["accent"])
			px(canvas, centre.x - 2 + i, centre.y - 2 + j, colors[symbol])


## The shared frame. `rect` is in whole game pixels.
static func draw_panel(canvas: CanvasItem, rect: Rect2, theme_name: StringName, colors: Dictionary, gems: bool = true, fill: String = "0") -> void:
	drawn += 1
	var t: Dictionary = theme(theme_name)
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	canvas.draw_rect(rect, colors["0"])
	outline(canvas, Rect2(x + 1, y + 1, w - 2, h - 2), colors[t["accent"]])
	canvas.draw_rect(Rect2(x + 3, y + 3, w - 6, h - 6), colors[fill])
	canvas.draw_rect(Rect2(x + 3, y + 3, w - 6, 1), colors[t["bevel_hi"]])
	canvas.draw_rect(Rect2(x + 3, y + 3, 1, h - 6), colors[t["bevel_hi"]])
	canvas.draw_rect(Rect2(x + 3, y + h - 4, w - 6, 1), colors[t["bevel_lo"]])
	canvas.draw_rect(Rect2(x + w - 4, y + 3, 1, h - 6), colors[t["bevel_lo"]])
	if gems:
		for corner: Vector2 in [Vector2(x + 1, y + 1), Vector2(x + w - 2, y + 1), Vector2(x + 1, y + h - 2), Vector2(x + w - 2, y + h - 2)]:
			gem(canvas, corner, theme_name, colors)


## A title plate with notched ribbon ends, centred on `center_x` (the result panels' title). The caller draws the title.
static func banner(canvas: CanvasItem, center_x: int, y: int, w: int, h: int, theme_name: StringName, colors: Dictionary) -> void:
	var t: Dictionary = theme(theme_name)
	var x: int = center_x - w / 2
	canvas.draw_rect(Rect2(x, y, w, h), colors["0"])
	canvas.draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), colors[t["accent"]])
	canvas.draw_rect(Rect2(x + 2, y + 2, w - 4, h - 4), colors[t["plate"]])
	canvas.draw_rect(Rect2(x + 2, y + 2, w - 4, 1), colors[t["gem"]])
	# notched ends: a V cut into both short sides
	var mid: int = y + h / 2
	for k: int in range(5):
		for side: int in [x + k, x + w - 1 - k]:
			canvas.draw_rect(Rect2(side, mid - (4 - k), 1, 1 + 2 * (4 - k)), colors["0"])
	gem(canvas, Vector2(center_x, y + h - 1), theme_name, colors)
	# wings: short accent lines running out of the plate
	canvas.draw_rect(Rect2(x - 8, mid, 6, 1), colors[t["accent"]])
	canvas.draw_rect(Rect2(x + w + 2, mid, 6, 1), colors[t["accent"]])
	px(canvas, x - 10, mid, colors[t["gem"]])
	px(canvas, x + w + 9, mid, colors[t["gem"]])


## An item/skill slot: ink fill, stone border; a highlighted one gets a cream border and teal corner brackets.
static func slot(canvas: CanvasItem, rect: Rect2, highlighted: bool, colors: Dictionary) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	canvas.draw_rect(rect, colors["0"])
	outline(canvas, rect, colors["1"] if highlighted else colors["f"])
	canvas.draw_rect(Rect2(x + 1, y + 1, w - 2, 1), colors["e"])
	if highlighted:
		for corner: Array in [[x - 2, y - 2, 1, 1], [x + w + 1, y - 2, -1, 1], [x - 2, y + h + 1, 1, -1], [x + w + 1, y + h + 1, -1, -1]]:
			var bx: float = corner[0]
			var by: float = corner[1]
			canvas.draw_rect(Rect2(minf(bx, bx + 3 * corner[2]), by, 4, 1), colors["u"])
			canvas.draw_rect(Rect2(bx, minf(by, by + 3 * corner[3]), 1, 4), colors["u"])


## The key cap (8x8, lilac border) a key letter is drawn into by the caller.
static func key_badge(canvas: CanvasItem, at: Vector2, colors: Dictionary, size: Vector2 = Vector2(8, 8)) -> void:
	canvas.draw_rect(Rect2(at, size), colors["0"])
	outline(canvas, Rect2(at, size), colors["v"])
