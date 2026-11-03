extends RefCounted
const Kit := preload("res://presentation/common/ui_kit.gd")
## The one shared frame for every pop-up (approved mockups 2026-10-21, docs/previews/character_menu_README.md): the
## character menu and its description box, the HUD skill tooltip and the DEFEAT / VICTORY panels.
## Frames are the SpriteCook kit's 9-sliced parts on the 384x216 grid (hard-edged at any window size); text is
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


## The shared frame. `rect` is in whole game pixels. Since the SpriteCook kit (2026-10-28) it is the carved bronze frame
## with teal corner gems from presentation/common/ui_kit.gd: the large ornate one for big pop-ups (200x90 and up), the
## medium one otherwise. `theme_name`, `gems` and `fill` are kept for the callers but the kit has one look; keep text
## 7 px inside the rect (Kit.inner).
static func draw_panel(canvas: CanvasItem, rect: Rect2, theme_name: StringName, colors: Dictionary, gems: bool = true, fill: String = "0") -> void:
	drawn += 1
	Kit.panel(canvas, rect, rect.size.x >= 200.0 and rect.size.y >= 90.0)


## A title plate with the swallowtail ribbon, centred on `center_x` (the result panels' title). The caller draws the title.
static func banner(canvas: CanvasItem, center_x: int, y: int, w: int, h: int, theme_name: StringName, colors: Dictionary) -> void:
	Kit.ribbon(canvas, Rect2(center_x - w / 2.0 - 24.0, y, w + 48.0, h))


## An item/skill slot: the kit's carved frame on its stone floor; a highlighted one also gets teal corner brackets.
static func slot(canvas: CanvasItem, rect: Rect2, highlighted: bool, colors: Dictionary) -> void:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	Kit.slot(canvas, rect, &"normal")
	if highlighted:
		for corner: Array in [[x - 2, y - 2, 1, 1], [x + w + 1, y - 2, -1, 1], [x - 2, y + h + 1, 1, -1], [x + w + 1, y + h + 1, -1, -1]]:
			var bx: float = corner[0]
			var by: float = corner[1]
			canvas.draw_rect(Rect2(minf(bx, bx + 3 * corner[2]), by, 4, 1), colors["u"])
			canvas.draw_rect(Rect2(bx, minf(by, by + 3 * corner[3]), 1, 4), colors["u"])


## The key cap (9x9, bronze with a teal rivet) a key letter is drawn into by the caller.
static func key_badge(canvas: CanvasItem, at: Vector2, colors: Dictionary, size: Vector2 = Vector2(9, 9)) -> void:
	Kit.badge(canvas, Rect2(at, size))
