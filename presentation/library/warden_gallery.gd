@tool
extends Node2D
## The Runebound Warden gallery (owner 2026-11-01: see every animation and effect in the Godot editor). Open
## presentation/library/warden_gallery.tscn: it plays in the 2D view without running the game. Zoom in on a panel to inspect it.
##
## Everything is drawn by the game's own code, so the gallery shows exactly what the game shows:
## - the 14 body animations, looping, at the frame timings the game plays (presentation/explore/mob_view.gd and the attack lengths in
##   core/tuning.gd);
## - each attack as a loop (wind-up with its hit area outlined, the strike with its effect at the real hit size, the torn ground after),
##   drawn by presentation/explore/warden_effects.gd: the Cleave pointing right and turned down-left (to judge turned pixels), the
##   Lash, the Spore Ring;
## - the other effect frames (ring charge, guard hit, guard break, footstep, death) and every particle burst kind
##   (presentation/explore/creature_particles.gd), each re-thrown when it ends.
## It reads the built atlas (art/build/sprites.png/json): after changing art, run build_art.py and the gallery shows the new frames.
## Nothing here is game logic; the telegraphs are made-up loops, not the core's.

const Snapshots := preload("res://core/snapshots.gd")
const WardenEffects := preload("res://presentation/explore/warden_effects.gd")
const Particles := preload("res://presentation/explore/creature_particles.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const ActorShadow := preload("res://presentation/common/actor_shadow.gd")
const AnimLib := preload("res://presentation/common/anim_library.gd")  # warden.tres: the owner's frame order and timing
const TICKS_PER_SECOND: float = 60.0

## The body animations and their ticks per frame (idle, wake, walk, hurt, exposed: mob_view.gd STATES; tells and strikes: the
## attack's windup or strike ticks spread over its frames; death: MOB_DEATH_TICKS 40 over 8 frames).
const BODY: Array = [["idle", 12], ["wake", 6], ["walk", 7], ["cleave_tell", 8], ["cleave_strike", 2], ["lash_tell", 9], ["lash_strike", 3],
	["ring_tell", 11], ["ring_strike", 2], ["recover", 4], ["guard_hit", 5], ["hurt", 5], ["exposed", 8], ["death", 5]]
## The attack loops: name, shape, kind, windup, strike ticks, size (the telegraph's real size), width, half angle, direction (degrees).
const ATTACKS: Array = [
	["Cleave (gold, parry)", &"cone", &"gold", 40, 6, 58.0, 0.0, 0.9, 0.0],
	["Cleave turned (down-left)", &"cone", &"gold", 40, 6, 58.0, 0.0, 0.9, 135.0],
	["Lash (red, dodge)", &"line", &"red", 44, 8, 150.0, 20.0, 0.0, 0.0],
	["Spore Ring (red, dodge)", &"circle", &"red", 56, 5, 48.0, 0.0, 0.0, 0.0],
]
const AFTER_TICKS: int = 40  # each attack loop: windup, strike, then this long (recover, torn ground) before it starts again
const PARTICLE_KINDS: Array[String] = ["slam", "roots", "kick", "crash", "roar", "stomp", "chips", "chant", "release", "heal", "mist", "pop", "reveal", "orb_trail"]

@export var playing: bool = true  ## untick to freeze every loop on its current tick
@export_range(0.1, 2.0, 0.05) var speed: float = 1.0  ## 1 = game speed (60 ticks a second)
@export var facing_left: bool = false  ## mirror the body animations (the game mirrors the Warden when it faces left)
@export var show_labels: bool = true

var time: float = 0.0
var frames: Dictionary = {}
var atlas: Texture2D
var colors: Dictionary = {}
var effects: Array = []  # one WardenEffects per attack loop (its telegraph and torn ground)


func _ready() -> void:
	_load()


func _load() -> void:
	AnimLib.clear_cache()  # the owner may have edited warden.tres
	frames = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	atlas = load("res://art/build/sprites.png")
	colors.clear()
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))["colors"]:
		colors[entry["symbol"]] = Color(entry["hex"])
	effects.clear()
	for i: int in ATTACKS.size():
		effects.append(WardenEffects.new())


func _process(delta: float) -> void:
	if playing:
		time += delta * speed
	queue_redraw()


func _draw() -> void:
	if atlas == null or frames.is_empty():
		_load()
	var tick: int = int(time * TICKS_PER_SECOND)
	var font: Font = ThemeDB.fallback_font
	var y: float = 0.0
	_title(font, Vector2(0, y), "RUNEBOUND WARDEN: body animations (looping at game speed)")
	y += 14.0
	for i: int in BODY.size():
		var cell: Vector2 = Vector2((i % 7) * 104, y + (i / 7) * 120)
		_panel(cell, Vector2(100, 112))
		var anim: String = BODY[i][0]
		var count: int = AnimLib.count("warden", anim, _count("warden_%s_right_" % anim))
		var spec: Array = [count, int(BODY[i][1]), true]
		var n: int = AnimLib.at("warden", anim, tick % (AnimLib.length("warden", anim, count * int(BODY[i][1])) + 12), spec)
		var feet: Vector2 = cell + Vector2(50, 100)
		ActorShadow.draw(self, feet, WardenEffects.SHADOW_RADIUS)
		_body(anim, n, feet, facing_left)
		_label(font, cell + Vector2(3, 9), "%s  %d/%d" % [anim, n, count])
	y += 250.0
	_title(font, Vector2(0, y), "ATTACKS: wind-up (hit area outlined), strike (effect at the real hit size), torn ground")
	y += 14.0
	for i: int in ATTACKS.size():
		var cell: Vector2 = Vector2(0, y + i * 170) if i < 2 else Vector2(380, y + (i - 2) * 170)
		_panel(cell, Vector2(370, 160))
		_attack(i, cell, tick, font)
	y += 350.0
	_title(font, Vector2(0, y), "EFFECT FRAMES (fx_warden2_*, loops) and the death")
	y += 14.0
	var loops: Array = [["ring_charge", 4, 6, "ring charge (at the chest)"], ["guard_hit", 4, 3, "guard hit"], ["guard_break", 6, 3, "guard break (parried)"],
		["footstep", 4, 4, "footstep"]]
	for i: int in loops.size():
		var cell: Vector2 = Vector2(i * 104, y)
		_panel(cell, Vector2(100, 80))
		var period: int = int(loops[i][1]) * int(loops[i][2]) + 20
		var n: int = (tick % period) / int(loops[i][2]) + 1
		if n <= int(loops[i][1]):
			WardenEffects.placed(self, String(loops[i][0]), n, cell + Vector2(50, 45 if i < 3 else 60), frames, atlas, i < 3)
		_label(font, cell + Vector2(3, 9), String(loops[i][3]))
	var death: Vector2 = Vector2(4 * 104, y)
	_panel(death, Vector2(100, 112))
	var dn: int = (tick % 60) / 5 + 1
	var dfeet: Vector2 = death + Vector2(50, 100)
	if dn <= 8:
		_body("death", dn, dfeet, facing_left)
		WardenEffects.sprite(self, "death_debris", dn, dfeet, frames, atlas, facing_left)
	if dn <= 4:
		WardenEffects.sprite(self, "death_flash", dn, dfeet, frames, atlas, facing_left)
	_label(font, death + Vector2(3, 9), "death + debris")
	y += 122.0
	_title(font, Vector2(0, y), "PARTICLES (creature_particles.gd), each burst thrown again when it ends")
	y += 14.0
	for i: int in PARTICLE_KINDS.size():
		var kind: String = PARTICLE_KINDS[i]
		var cell: Vector2 = Vector2((i % 7) * 104, y + (i / 7) * 90)
		_panel(cell, Vector2(100, 84))
		var life: int = Particles.max_life(kind) + 10
		var burst: Dictionary = {"kind": kind, "at": cell + Vector2(50, 56), "tick": 0, "seed": 1000 + i * 7919, "dir": Vector2.RIGHT, "half_angle": 0.9, "size": 36.0}
		var bursts: Array[Dictionary] = [burst]
		Particles.draw(self, bursts, tick % life, colors)
		_label(font, cell + Vector2(3, 9), kind)


## One attack loop: the body plays its tell, strike and recover; the hit area is outlined during the windup; warden_effects.gd draws
## the strike and the torn ground exactly as in the game.
func _attack(i: int, cell: Vector2, tick: int, font: Font) -> void:
	var spec: Array = ATTACKS[i]
	var windup: int = spec[3]
	var strike: int = spec[4]
	var t: int = tick % (windup + strike + AFTER_TICKS)
	var feet: Vector2 = cell + (Vector2(80, 110) if spec[1] != &"circle" else Vector2(185, 100))
	if i == 1:
		feet = cell + Vector2(255, 92)  # room for the slash down-left and the body above it
	var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	tell.id = 9000 + i
	tell.owner_id = 1
	tell.shape = spec[1]
	tell.kind = spec[2]
	tell.center = feet
	tell.direction = Vector2.from_angle(deg_to_rad(float(spec[8])))
	tell.size = spec[5]
	tell.width = spec[6]
	tell.half_angle = spec[7]
	tell.start_tick = 0
	tell.hit_tick = windup
	tell.end_tick = windup + strike
	var fx: WardenEffects = effects[i]
	var scars: Array[Dictionary] = []
	if t >= windup:
		scars.append({"tell": tell, "tick": windup})
	fx.tells = {1: tell}
	fx.scars = scars
	if t < windup:
		draw_polyline(TelegraphView.outline(tell), colors["x"] if tell.kind == &"gold" else colors["z"], 1.0)
	fx.draw_ground(self, t, colors, frames, atlas)
	var left: bool = tell.direction.x < -0.1
	var anim: String = String(spec[0]).get_slice(" ", 0).to_lower().replace("spore", "ring")
	var body: String
	var n: int
	if t < windup:
		body = anim + "_tell"
		n = t * 5 / windup + 1
	elif t < windup + strike:
		body = anim + "_strike"
		n = (t - windup) * 3 / strike + 1
	elif t < windup + strike + 16:
		body = "recover"
		n = (t - windup - strike) / 4 + 1
	else:
		body = "idle"
		n = (t / 12) % 6 + 1
	ActorShadow.draw(self, feet, WardenEffects.SHADOW_RADIUS)
	_body(body, n, feet, left)
	if body == "ring_tell":
		WardenEffects.placed(self, "ring_charge", (t / 6) % 4 + 1, WardenEffects.chest_world({"position": feet, "facing": Vector2.RIGHT}, "warden_%s_right_%d" % [body, n]), frames, atlas)
	var phase: String = "wind-up" if t < windup else ("STRIKE" if t < windup + strike else "after")
	_label(font, cell + Vector2(3, 9), "%s  %s  t=%d" % [spec[0], phase, t])


func _body(anim: String, n: int, feet: Vector2, left: bool) -> void:
	var key: String = AnimLib.key("warden", anim, n, "warden_%s_right_%d" % [anim, n])
	if not frames.has(key):
		return
	var f: Dictionary = frames[key]
	draw_texture_rect_region(atlas, ArenaAnimation.destination(feet, f, left), Rect2(f["x"], f["y"], f["w"], f["h"]))


func _count(prefix: String) -> int:
	var n: int = 0
	while frames.has(prefix + str(n + 1)):
		n += 1
	return n


func _panel(at: Vector2, size: Vector2) -> void:
	draw_rect(Rect2(at, size), Color(0.29, 0.24, 0.2))  # the forest floor's dirt, like the contact sheets
	draw_rect(Rect2(at, size), Color(0.11, 0.094, 0.141), false, 1.0)


func _label(font: Font, at: Vector2, text: String) -> void:
	if show_labels:
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.96, 0.93, 0.84))


func _title(font: Font, at: Vector2, text: String) -> void:
	if show_labels:
		draw_string(font, at + Vector2(0, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.96, 0.78, 0.27))
