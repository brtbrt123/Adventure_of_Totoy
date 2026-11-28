extends "res://presentation/explore/colossus_view.gd"
## MOCK-UP only (presentation/review/colossus_sweep/capture_sweep.gd): the Colossus's view with the REWORKED Gold Sweep (frames in
## art/reference/colossus_body_v1/sweep_v2/, not in the atlas yet) drawn in place of the game's sweep, timed as proposed: the windup
## over its warning, the four swing frames starting 4 and 2 ticks before the blow, on it and 4 after, two recover frames. Every
## other pose is the game's own.

const NEW: String = "res://art/reference/colossus_body_v1/sweep_v2/"
const SWING: Array[int] = [-4, -2, 0, 4]

var _textures: Dictionary = {}
var _frames: Dictionary = {}


func _new_frame(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> Dictionary:
	if StringName(mob.get("attack_id", &"")) != &"red_sweep":
		return {}
	var t: int = int(mob["state_ticks"])
	if mob["state"] == &"recover":
		return {"frame": "colossus_sweep_recover_right_%d" % (1 + t * 2 / RECOVER_HOLD), "shake": 0} if t < RECOVER_HOLD else {}
	if mob["state"] != &"windup" and mob["state"] != &"strike":
		return {}
	for tell: Snapshots.TelegraphSnapshot in tells:
		if tell.owner_id != int(mob["id"]) or tell.attack != &"red_sweep":
			continue
		var to: int = tick - tell.hit_tick
		if to < SWING[0]:
			var p: float = _warned(tell, tick)
			return {"frame": "colossus_sweep_windup_right_%d" % mini(2, 1 + floori(p / WINDUP_SPREAD * 2.0)), "shake": 1 if p > TREMBLE else 0}
		var n: int = 1
		for i: int in SWING.size():
			if to >= SWING[i]:
				n = i + 1
		return {"frame": "colossus_sweep_strike_right_%d" % n, "shake": 0}
	return {"frame": "colossus_sweep_strike_right_4", "shake": 0} if mob["state"] == &"strike" else {}


func draw_body(canvas: CanvasItem, item: Dictionary, frames: Dictionary, sprites: Texture2D, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> void:
	var pick: Dictionary = _new_frame(item["mob"], tells, tick)
	if pick.is_empty():
		super(canvas, item, frames, sprites, tells, tick)
		return
	var name: String = pick["frame"]
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(NEW + name + ".png")))
	if _frames.is_empty():
		_frames = JSON.parse_string(FileAccess.get_file_as_string(NEW + "frames.json"))["frames"]
	var m: Dictionary = _frames[name]
	var shake: float = float(int(pick["shake"]) * (1 if posmod(tick / 2, 2) == 0 else -1))
	var corner: Vector2 = (Vector2(item["at"]).round() - Vector2(float(m["ax"]), float(m["ay"])) + Vector2(shake, 0.0)).round()
	var tint: Color = item["tint"]
	if int(item["mob"].get("since_hit", 1000)) < 4:
		tint = Color(tint.r * 2.0, tint.g * 2.0, tint.b * 2.0, tint.a)  # the game flashes it white after a blow
	canvas.draw_texture(_textures[name], corner, tint)
