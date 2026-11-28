extends RefCounted
## Pure snapshot-driven mob poses and decorations; core owns state lengths and all contact geometry.
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
const WHITE := preload("res://art/build/sprites_white.png")
const AnimLib := preload("res://presentation/common/anim_library.gd")  # the owner's SpriteFrames: frame order and free-running timing
## The bar over a mob (the owner, 2026-11-28, after the TikTok reference: "improve the healthbar and lvl design on the top of the
## mob"; wired on "Yes, wire them"; docs/PLAN_hit_feedback.md): the level in a framed badge joined to the left of a copper-rimmed bar,
## its fill bevelled, the health just lost as a cream chunk that lingers, then drains (`ghosts`, kept by bar_drain.gd).
static var ghosts: Dictionary = {}  # mob id -> the health its bar still shows (lost health drains to its hp)
const BAR_WIDTH: int = 34
const BOSS_BAR_WIDTH: int = 58
const BAR_HEIGHT: int = 7
const DIGITS: Dictionary = {"0":["111","101","101","101","111"], "1":["010","110","010","010","111"], "2":["111","001","111","100","111"], "3":["111","001","111","001","111"], "4":["101","101","111","001","001"], "5":["111","100","111","001","111"], "6":["111","100","111","101","111"], "7":["111","001","010","010","010"], "8":["111","101","111","101","111"], "9":["111","101","111","001","111"]}
const STATES: Dictionary = {
 "warden": {"idle":["idle",6,12,true], "alert":["wake",4,6,false], "chase":["walk",6,7,true], "return":["walk",6,7,true], "windup":["cleave_tell",5,1,false], "strike":["cleave_strike",3,2,false], "recover":["recover",4,4,false], "stagger":["exposed",4,8,true], "hurt":["hurt",2,5,false], "dead":["death",8,8,false]},
 "glowmoth": {"idle":["idle",24,2,true], "alert":["idle",24,2,true], "chase":["move",12,2,true], "return":["move",12,2,true], "windup":["shot_tell",4,1,false], "strike":["shot_release",2,4,false], "recover":["idle",24,2,true], "hurt":["hurt",2,5,false], "dead":["death",4,8,false]},
 "mossling": {"idle":["play_idle",24,6,true], "alert":["spawn",4,6,false], "chase":["walk",6,5,true], "return":["walk",6,5,true], "windup":["attack_tell",3,1,false], "strike":["attack_lunge",3,3,false], "recover":["attack_recover",3,8,false], "crash":["attack_recover",3,8,true], "stagger":["attack_recover",3,8,true], "hurt":["hurt",2,5,false], "dead":["death",5,8,false]},
 "stag": {"idle":["idle",4,14,true], "alert":["idle",4,6,false], "chase":["walk",6,6,true], "return":["walk",6,6,true], "windup":["slam_raise",4,1,false], "strike":["slam_strike",3,2,false], "recover":["slam_recover",4,8,false], "crash":["charge_crash",3,10,true], "stagger":["stagger",4,10,true], "hurt":["hurt",3,4,false], "roar":["phase2_roar",6,9,false], "dead":["death",8,9,false]},
 "boar": {"idle":["graze_idle",36,6,true], "alert":["idle",4,6,false], "chase":["walk",6,5,true], "return":["walk",6,5,true], "windup":["charge_tell",4,1,false], "strike":["charge_run",4,2,true], "recover":["crash_stun",3,9,false], "crash":["crash_stun",3,9,true], "stagger":["crash_stun",3,9,true], "hurt":["hurt",2,5,false], "dead":["death",5,8,false]}}
static func frame(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int, guard_hit_tick: int = -1000) -> String:
	var table: Dictionary = STATES[String(mob["type"])]
	var pose: Array = table.get(String(mob["state"]), table["idle"])
	if mob["type"] == &"warden":
		if mob["state"] in [&"windup", &"strike"]:
			var attack: String = String(mob.get("attack", &"" )).trim_prefix("warden_")
			if attack in ["cleave", "lash", "ring"]:
				pose = [attack + ("_tell" if mob["state"] == &"windup" else "_strike"), 5 if mob["state"] == &"windup" else 3, 1, false]
		elif not bool(mob.get("guarded", true)) and mob["state"] != &"dead":
			pose = ["hurt",2,5,false] if mob["state"] == &"hurt" else ["exposed",4,8,true]
		elif bool(mob.get("guarded", true)) and (mob["state"] == &"hurt" or tick - guard_hit_tick < 10):
			pose = ["guard_hit",2,5,false]
	if mob["type"]==&"mossling" and mob["state"]==&"stagger":pose=["hurt",2,6,true]
	if mob["type"]==&"boar" and mob["state"]==&"recover":pose=["charge_tell",4,6,false]
	if mob["type"] == &"stag":
		if mob["state"] == &"idle":pose=["breathe",24,6,true]
		elif mob["state"] in [&"chase", &"return"]:pose=["amble",12,5,true]
		elif mob.get("attack_id", &"") == &"stag_roots" and mob["state"] == &"windup":pose=["phase2_roar",6,1,false]
		elif mob.get("attack_id", &"") == &"stag_summon":
			if mob["state"] == &"windup":pose=["chant",28,3,false]
			elif mob["state"] in [&"strike", &"recover"]:pose=["summon",10,6,false]
	if mob["type"]==&"stag" and mob.get("attack_id", &"") == &"stag_charge":
		if mob["state"]==&"windup":pose=["charge_tell",5,1,false]
		elif mob["state"]==&"strike":pose=["charge_run",4,3,true]
	# Dormant encounters leave idle state_ticks at zero. Use the simulation clock so they animate
	# before aggro, freeze with pause and stop immediately when core reports another state.
	var clock: int = tick + int(mob["id"]) * 17 if mob["state"] == &"idle" else int(mob["state_ticks"])
	var type: String = String(mob["type"])
	var count: int = AnimLib.count(type, String(pose[0]), int(pose[1]))
	var spec: Array = [count, int(pose[2]), bool(pose[3])]
	var primary: Array = _primary(type, String(pose[0]))
	var owners_pace: bool = primary.is_empty() or (int(primary[0]) == int(pose[2]) and bool(primary[1]) == bool(pose[3]))
	var n: int = (AnimLib.at(type, String(pose[0]), clock, spec) - 1) if owners_pace else clock / int(pose[2])
	if mob["type"] == &"warden" and pose[0] == "guard_hit" and tick - guard_hit_tick < 10:
		n = (tick - guard_hit_tick) / 5
	if mob["type"] == &"warden" and mob["state"] == &"strike":
		for tell: Snapshots.TelegraphSnapshot in tells:
			if tell.owner_id == mob["id"]:
				n = floori(float(tick - tell.hit_tick) / maxi(1, tell.end_tick - tell.hit_tick) * count)
	if mob["state"] == &"windup":
		for tell: Snapshots.TelegraphSnapshot in tells:
			if tell.owner_id == mob["id"]:
				n = floori(float(tick-tell.start_tick) / maxi(1,tell.hit_tick-tell.start_tick) * count)
	# A non-damaging summon needs cast progress from core, never an invented damage warning.
	if mob.get("attack_id", &"") == &"stag_summon" and mob["state"] == &"windup" and mob.has("cast_start_tick") and mob.has("cast_release_tick"):
		n = floori(float(tick - int(mob["cast_start_tick"])) / maxi(1, int(mob["cast_release_tick"]) - int(mob["cast_start_tick"])) * count)
	# The release frames run on from the release tick through strike AND recover (state_ticks restarts between them).
	if mob.get("attack_id", &"") == &"stag_summon" and mob["state"] in [&"strike", &"recover"] and int(mob.get("cast_release_tick", -1)) >= 0:
		n = (tick - int(mob["cast_release_tick"])) / int(pose[2])
	if mob["type"]==&"boar" and mob["state"]==&"windup" and n>=2:
		n=2+posmod(int(mob["state_ticks"])/4,2)
	if mob["state"] == &"dead":
		n = floori(float(mob["state_ticks"]) / Tuning.MOB_DEATH_TICKS * count)
	n = posmod(n,count) if bool(pose[3]) else clampi(n,0,count-1)
	if mob["type"]==&"boar" and mob["state"]==&"recover":n=3-n
	return AnimLib.key(type, String(pose[0]), n + 1, "%s_%s_right_%d" % [type, pose[0], n + 1])
## The pace (ticks per frame, loop) the pose's SpriteFrames animation started from: its first use in STATES (presentation/animations,
## tools/godot/generate_sprite_frames.gd). That use plays at the owner's timing; another state playing the same pose at another pace
## (the Stag's startled idle, a looping stun) keeps the code's pace with the owner's frames.
static func _primary(type: String, pose_name: String) -> Array:
	for state: String in STATES.get(type, {}):
		var pose: Array = STATES[type][state]
		if pose[0] == pose_name:
			return [int(pose[2]), bool(pose[3])]
	return []
static func decorate(canvas: CanvasItem, mob: Dictionary, colors: Dictionary, hero_at: Vector2, frames: Dictionary, atlas: Texture2D) -> void:
	if mob["state"] == &"dead": return
	var at: Vector2 = mob["position"]
	var boss: bool = bool(mob.get("boss", false))
	# A Glowmoth floats: its bar sits over its wings (sprite top ~29 px), not across them.
	var top: Vector2 = (at-Vector2(0,60 if boss else (31 if mob["type"] == &"boar" else (36 if mob["type"] == &"glowmoth" else 25)))).round()
	if mob["type"] == &"warden":
		top = (at - Vector2(0, 86)).round()  # above the 79 px Warden (tools/art/rig_warden_v2.py, 1.5x smaller since 2026-10-31)
	if int(mob["hp"]) < int(mob["max_hp"]) or at.distance_to(hero_at)<72.0:
		draw_bar(canvas, top, mob, colors)
	if bool(mob["exposed"]):
		canvas.draw_polyline(PackedVector2Array([top+Vector2(0,-8),top+Vector2(3,-5),top+Vector2(0,-2),top+Vector2(-3,-5),top+Vector2(0,-8)]),colors["u"],1.0)
	if mob["state"] == &"alert":
		canvas.draw_rect(Rect2(top+Vector2(-1,-8),Vector2(2,4)),colors["1"])
		canvas.draw_rect(Rect2(top+Vector2(-1,-3),Vector2(2,1)),colors["1"])

## The redesigned bar, centred on `top` (its top edge): [level badge][bar]. A summoned moth shows only its bar (stacked badges are noise).
static func draw_bar(canvas: CanvasItem, top: Vector2, mob: Dictionary, colors: Dictionary) -> void:
	var width: int = BOSS_BAR_WIDTH if bool(mob.get("boss", false)) else BAR_WIDTH
	var badge: bool = mob.has("level") and int(mob.get("summoner_id", 0)) == 0
	var digits: String = str(int(mob.get("level", 1)))
	var badge_width: int = 4 * digits.length() + 5
	var total: int = width + (badge_width - 1 if badge else 0)
	var x0: float = roundf(top.x - float(total) * 0.5)
	var y0: float = top.y
	var bx: float = x0 + (badge_width - 1 if badge else 0)
	canvas.draw_rect(Rect2(bx, y0, width, BAR_HEIGHT), colors["0"])  # the ink outline
	canvas.draw_rect(Rect2(bx + 1, y0 + 1, width - 2, 1), colors["r"])  # copper rim: lit above
	canvas.draw_rect(Rect2(bx + 1, y0 + BAR_HEIGHT - 2, width - 2, 1), colors["a"])  # and shaded below
	var inside: Rect2 = Rect2(bx + 1, y0 + 2, width - 2, BAR_HEIGHT - 4)
	canvas.draw_rect(inside, colors["e"])
	var max_hp: float = maxf(1.0, float(mob["max_hp"]))
	var hp: float = float(mob["hp"])
	var fill: float = floorf(inside.size.x * clampf(hp / max_hp, 0.0, 1.0))
	var ghost: float = floorf(inside.size.x * clampf(float(ghosts.get(int(mob["id"]), hp)) / max_hp, 0.0, 1.0))
	if ghost > fill:  # the health just lost, lingering before it drains
		canvas.draw_rect(Rect2(inside.position + Vector2(fill, 0), Vector2(ghost - fill, inside.size.y)), colors["1"])
	if fill > 0.0:  # the fill, bevelled: lit, mid and shaded rows
		canvas.draw_rect(Rect2(inside.position, Vector2(fill, 1)), colors["5"])
		canvas.draw_rect(Rect2(inside.position + Vector2(0, 1), Vector2(fill, 1)), colors["4"])
		canvas.draw_rect(Rect2(inside.position + Vector2(0, 2), Vector2(fill, inside.size.y - 2)), colors["3"])
	if badge:  # the level: a framed box joined to the bar's left, its number in cream
		canvas.draw_rect(Rect2(x0, y0 - 1, badge_width, BAR_HEIGHT + 2), colors["0"])
		canvas.draw_rect(Rect2(x0 + 1, y0, badge_width - 2, BAR_HEIGHT), colors["q"])
		canvas.draw_rect(Rect2(x0 + 2, y0 + 1, badge_width - 4, BAR_HEIGHT - 2), colors["0"])
		for i: int in digits.length():
			var rows: Array = DIGITS.get(digits[i], DIGITS["0"])
			for y: int in 5:
				for x: int in 3:
					if rows[y][x] == "1":
						canvas.draw_rect(Rect2(x0 + 3 + i * 4 + x, y0 + 1 + y, 1, 1), colors["1"])
