extends RefCounted
## The ground shadow under every actor (hero, NPCs, the boss), shared by the exploration scenes
## (presentation/explore/explore_scene.gd) and the arena (presentation/arena/arena.gd). It replaces the opaque ink
## ellipse (2026-10-22, the human: "fix the shadow on the character to match our game"): the painted scenes darken the
## ground softly under their objects, so the shadow is translucent ink, never a black hole, and stays hard-pixel:
## - a pixel-aligned ellipse of whole-pixel row spans (no smooth edges), x radius `radius` * SIZE, y radius
##   Y_RATIO of that (at least 2 px), its middle OFFSET_Y px below the feet;
## - the core rows at `strength` alpha (ALPHA by default, a scene may pass its own: STRENGTH below), the outermost pixel
##   of every row and the top and bottom rows a dithered ring (a checkerboard on the world pixel grid, so it does not
##   shimmer as the actor moves).
## Draw it before the actor's sprite. Pure drawing on any CanvasItem; nothing here changes game state.

## Opacity of the shadow's core (ink over the ground).
const ALPHA: float = 0.4
## The shadow is a little smaller than the old ellipse (radius 10 for the hero).
const SIZE: float = 0.9
const Y_RATIO: float = 0.3
const OFFSET_Y: int = 2
const INK: Color = Color(0.110, 0.094, 0.141)  # palette "0" (ink, #1c1824)
## Per-scene strength (the dark forest floor needs a little more to read, the bright village dirt a little less).
const STRENGTH: Dictionary = {&"village": 0.38, &"forest": 0.42, &"glade": 0.4, &"arena": 0.4}


## The shadow's pixels for feet at `feet` (rounded) and `radius`: {"core": [Rect2 row spans], "ring": [Vector2i pixels]}.
## The ring holds only the dithered pixels that are drawn (every other one).
static func plan(feet: Vector2, radius: float) -> Dictionary:
	var rx: float = maxf(2.0, radius * SIZE)
	var ry: float = maxf(2.0, rx * Y_RATIO)
	var c: Vector2i = Vector2i(feet.round()) + Vector2i(0, OFFSET_Y)
	var rows: int = int(round(ry))
	var core: Array[Rect2] = []
	var ring: Array[Vector2i] = []
	for dy: int in range(-rows, rows + 1):
		var t: float = float(dy) / (ry + 0.5)
		var half: int = int(floor(rx * sqrt(maxf(0.0, 1.0 - t * t)) + 0.5))
		if half <= 0:
			continue
		var y: int = c.y + dy
		var x0: int = c.x - half
		var x1: int = c.x + half - 1  # last pixel of the row
		var edge_row: bool = absi(dy) == rows
		for x: int in range(x0, x1 + 1):
			var on_ring: bool = edge_row or x == x0 or x == x1
			if on_ring and posmod(x + y, 2) == 0:
				ring.append(Vector2i(x, y))
		if not edge_row and x1 - x0 >= 2:
			core.append(Rect2(x0 + 1, y, x1 - x0 - 1, 1))
	return {"core": core, "ring": ring}


## Draws the shadow on `canvas` under feet at `feet`. `strength` is the core's alpha (the ring uses the same alpha on
## every other pixel).
static func draw(canvas: CanvasItem, feet: Vector2, radius: float, strength: float = ALPHA) -> void:
	if radius <= 0.0 or strength <= 0.0:
		return
	var colour: Color = Color(INK, strength)
	var p: Dictionary = plan(feet, radius)
	for r: Rect2 in p["core"]:
		canvas.draw_rect(r, colour)
	for px: Vector2i in p["ring"]:
		canvas.draw_rect(Rect2(Vector2(px), Vector2.ONE), colour)


## The strength for a scene id (ALPHA when the scene has none).
static func strength_for(scene_id: StringName) -> float:
	return float(STRENGTH.get(scene_id, ALPHA))
