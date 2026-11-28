extends Node2D
## Damage numbers and the hit counter (the owner's TikTok reference, 2026-11-28; docs/PLAN_hit_feedback.md). Every hit Totoy lands
## pops its own chunky pixel number over the mob: it bounces in one size bigger, rises and fades, the next hits on the same mob
## scattered round it so they stack instead of overwriting each other. A counter (an exposed mob) and the killing blow pop bigger.
## A "x12 HITS" counter by Totoy counts his hits until he stops for COMBO_GAP. Colours stay off gold and red (the parry and dodge
## cues): cream, the song's pale blue for counters, near-white for the kill. Cosmetic memory of events only: the core decides every
## hit and its damage.
const ExploreCore := preload("res://core/explore_core.gd")
const GameEvent := preload("res://core/game_event.gd")

const LIFE: int = 42  # ticks a number stays
const FADE: int = 10  # its last ticks fade out
const RISE: float = 16.0  # px it rises, easing out over RISE_TICKS
const RISE_TICKS: float = 24.0
const POP: int = 3  # ticks a normal hit's number shows one size bigger as it lands (the big ones are big already)
const COMBO_GAP: int = 90  # the hit counter keeps counting while hits come this close together
const COMBO_FADE: int = 20
const MAX_NUMBERS: int = 24
## Where the next number on the same mob lands, round the first (so a combo stacks into a little cloud of numbers).
const SCATTER: Array[Vector2] = [Vector2(0, 0), Vector2(9, -3), Vector2(-9, -2), Vector2(14, -7), Vector2(-13, -6), Vector2(5, -10), Vector2(-5, -9)]
## How far above its feet a mob's numbers start (its head), by type; bosses higher.
const HEAD: Dictionary = {&"mossling": 24.0, &"boar": 30.0, &"glowmoth": 34.0, &"stag": 56.0, &"warden": 80.0, &"colossus": 96.0}
## Bold 5x7 digits and the few letters the counter needs ("#" lit, "." clear); widths vary.
const GLYPHS: Dictionary = {
	"0": [".###.", "##.##", "##.##", "##.##", "##.##", "##.##", ".###."],
	"1": ["..##.", ".###.", "..##.", "..##.", "..##.", "..##.", ".####"],
	"2": [".###.", "##.##", "...##", "..##.", ".##..", "##...", "#####"],
	"3": ["####.", "...##", "...##", ".###.", "...##", "...##", "####."],
	"4": ["##.##", "##.##", "##.##", "#####", "...##", "...##", "...##"],
	"5": ["#####", "##...", "####.", "...##", "...##", "##.##", ".###."],
	"6": [".###.", "##...", "####.", "##.##", "##.##", "##.##", ".###."],
	"7": ["#####", "...##", "..##.", "..##.", ".##..", ".##..", ".##.."],
	"8": [".###.", "##.##", "##.##", ".###.", "##.##", "##.##", ".###."],
	"9": [".###.", "##.##", "##.##", ".####", "...##", "...##", ".###."],
	"x": ["....", "....", "##.#", ".##.", ".##.", "#.##", "...."],
	"H": ["##.##", "##.##", "##.##", "#####", "##.##", "##.##", "##.##"],
	"I": ["####", ".##.", ".##.", ".##.", ".##.", ".##.", "####"],
	"T": ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.."],
	"S": [".####", "##...", "##...", ".###.", "...##", "...##", "####."],
	" ": ["..", "..", "..", "..", "..", "..", ".."],
}

var view: ExploreCore.ExploreSnapshot
var colors: Dictionary = {}
## {at (where it starts), amount, tick, target, style (&"hit", &"counter", &"kill")}
var numbers: Array[Dictionary] = []
var combo: int = 0
var combo_last: int = -1000
var _per_target: Dictionary = {}  # mob id -> hits shown on it (for the scatter)
var _textures: Dictionary = {}


func clear() -> void:
	numbers.clear()
	_per_target.clear()
	combo = 0
	combo_last = -1000


func sync(value: ExploreCore.ExploreSnapshot, palette: Dictionary) -> void:
	view = value
	colors = palette
	z_index = 7
	numbers = numbers.filter(func(n: Dictionary) -> bool: return value.tick - int(n["tick"]) < LIFE)
	queue_redraw()


func handle_event(event: GameEvent, state: ExploreCore.ExploreSnapshot) -> void:
	match event.type:
		GameEvent.ATTACK_HIT:
			if int(event.data.get("attacker_id", -1)) != state.hero.id:
				return
			var target: int = int(event.data.get("target_id", -1))
			var k: int = int(_per_target.get(target, 0))
			_per_target[target] = k + 1
			var head: float = 24.0
			for mob: Dictionary in state.mobs:
				if int(mob["id"]) == target:
					head = float(HEAD.get(mob["type"], 56.0 if bool(mob.get("boss", false)) else 24.0))
			var at: Vector2 = Vector2(event.data.get("position", state.hero.position)) + Vector2(0, -head) + SCATTER[k % SCATTER.size()]
			numbers.append({"at": at, "amount": int(event.data.get("damage", 0)), "tick": event.tick, "target": target,
				"style": &"counter" if event.data.get("kind", &"") == &"counter" else &"hit"})
			if numbers.size() > MAX_NUMBERS:
				numbers.pop_front()
			combo = combo + 1 if event.tick - combo_last <= COMBO_GAP else 1
			combo_last = event.tick
		GameEvent.MOB_DEFEATED:  # the blow that felled it pops biggest
			var id: int = int(event.data.get("mob_id", -1))
			for i: int in range(numbers.size() - 1, -1, -1):
				if int(numbers[i]["target"]) == id and int(numbers[i]["tick"]) == event.tick:
					numbers[i]["style"] = &"kill"
					break
			_per_target.erase(id)


func _draw() -> void:
	if view == null or colors.is_empty():
		return
	for n: Dictionary in numbers:
		var age: int = view.tick - int(n["tick"])
		var style: StringName = n["style"]
		var size: int = (2 if age < POP else 1) if style == &"hit" else 2
		var rise: float = RISE * (1.0 - pow(1.0 - clampf(float(age) / RISE_TICKS, 0.0, 1.0), 3.0))
		var fill: Color = colors["1"] if style == &"hit" else (colors["o"] if style == &"counter" else colors["p"])
		var alpha: float = clampf(float(LIFE - age) / float(FADE), 0.0, 1.0)
		_text(str(int(n["amount"])), Vector2(n["at"]) + Vector2(0, -rise), size, fill, alpha, true)
	var since: int = view.tick - combo_last
	if combo >= 2 and since <= COMBO_GAP + COMBO_FADE:
		var alpha: float = clampf(float(COMBO_GAP + COMBO_FADE - since) / float(COMBO_FADE), 0.0, 1.0)
		_text("x%d HITS" % combo, view.hero.position + Vector2(12, -40 - (2 if since < 3 else 0)), 1, colors["1"], alpha, false)  # it hops on each hit


## `text` in the pixel glyphs, `size` px per glyph pixel, with a dark outline; centred on `at` (or starting at it), whole pixels.
func _text(text: String, at: Vector2, size: int, fill: Color, alpha: float, centred: bool) -> void:
	var key: String = "%s|%d|%s" % [text, size, fill.to_html()]
	if not _textures.has(key):
		_textures[key] = _render(text, size, fill)
	var texture: ImageTexture = _textures[key]
	var corner: Vector2 = at - Vector2(texture.get_width() * 0.5 if centred else 0.0, texture.get_height() * 0.5)
	draw_texture(texture, corner.round(), Color(1, 1, 1, alpha))


func _render(text: String, size: int, fill: Color) -> ImageTexture:
	var width: int = 1
	for ch: String in text:
		width += (GLYPHS.get(ch, GLYPHS[" "])[0] as String).length() + 1
	var image: Image = Image.create(width * size + 2, 9 * size, false, Image.FORMAT_RGBA8)
	var lit: Array[Vector2i] = []
	var x: int = 1
	for ch: String in text:
		var rows: Array = GLYPHS.get(ch, GLYPHS[" "])
		for y: int in rows.size():
			var row: String = rows[y]
			for gx: int in row.length():
				if row[gx] == "#":
					lit.append(Vector2i(x + gx, y + 1))
		x += (rows[0] as String).length() + 1
	var ink: Color = colors["0"]
	for p: Vector2i in lit:  # the outline: every neighbour of a lit pixel, one glyph pixel wide
		for dy: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				image.fill_rect(Rect2i((p.x + dx) * size, (p.y + dy) * size, size, size), ink)
	for p: Vector2i in lit:
		image.fill_rect(Rect2i(p.x * size, p.y * size, size, size), fill)
	return ImageTexture.create_from_image(image)
