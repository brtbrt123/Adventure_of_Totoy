extends RefCounted
## Pure snapshot-driven mob poses and decorations; core owns state lengths and all contact geometry.
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
const WHITE := preload("res://art/build/sprites_white.png")
const Kit := preload("res://presentation/common/ui_kit.gd")
const STATES: Dictionary = {
 "mossling": {"idle":["play_idle",24,6,true], "alert":["spawn",4,6,false], "chase":["walk",6,5,true], "return":["walk",6,5,true], "windup":["attack_tell",3,1,false], "strike":["attack_lunge",3,3,false], "recover":["attack_recover",3,8,false], "crash":["attack_recover",3,8,true], "stagger":["attack_recover",3,8,true], "hurt":["hurt",2,5,false], "dead":["death",5,8,false]},
 "stag": {"idle":["idle",4,14,true], "alert":["idle",4,6,false], "chase":["walk",6,6,true], "return":["walk",6,6,true], "windup":["slam_raise",4,1,false], "strike":["slam_strike",3,2,false], "recover":["slam_recover",4,8,false], "crash":["charge_crash",3,10,true], "stagger":["stagger",4,10,true], "hurt":["hurt",3,4,false], "roar":["phase2_roar",6,9,false], "dead":["death",8,9,false]},
 "boar": {"idle":["graze_idle",36,6,true], "alert":["idle",4,6,false], "chase":["walk",6,5,true], "return":["walk",6,5,true], "windup":["charge_tell",4,1,false], "strike":["charge_run",4,2,true], "recover":["crash_stun",3,9,false], "crash":["crash_stun",3,9,true], "stagger":["crash_stun",3,9,true], "hurt":["hurt",2,5,false], "dead":["death",5,8,false]}}
static func frame(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> String:
	var table: Dictionary = STATES[String(mob["type"])]
	var pose: Array = table.get(String(mob["state"]), table["idle"])
	if mob["type"]==&"mossling" and mob["state"]==&"stagger":pose=["hurt",2,6,true]
	if mob["type"]==&"boar" and mob["state"]==&"recover":pose=["charge_tell",4,6,false]
	if mob["type"]==&"stag" and mob.get("attack_id", &"") == &"stag_charge":
		if mob["state"]==&"windup":pose=["charge_tell",5,1,false]
		elif mob["state"]==&"strike":pose=["charge_run",4,3,true]
	# Dormant encounters leave idle state_ticks at zero. Use the simulation clock so they animate
	# before aggro, freeze with pause and stop immediately when core reports another state.
	var clock: int = tick + int(mob["id"]) * 17 if mob["state"] == &"idle" and mob["type"] in [&"mossling", &"boar"] else int(mob["state_ticks"])
	var n: int = clock / int(pose[2])
	if mob["state"] == &"windup":
		for tell: Snapshots.TelegraphSnapshot in tells:
			if tell.owner_id == mob["id"]:
				n = floori(float(tick-tell.start_tick) / maxi(1,tell.hit_tick-tell.start_tick) * int(pose[1]))
	if mob["type"]==&"boar" and mob["state"]==&"windup" and n>=2:
		n=2+posmod(int(mob["state_ticks"])/4,2)
	if mob["state"] == &"dead":
		n = floori(float(mob["state_ticks"]) / Tuning.MOB_DEATH_TICKS * int(pose[1]))
	n = posmod(n,int(pose[1])) if bool(pose[3]) else clampi(n,0,int(pose[1])-1)
	if mob["type"]==&"boar" and mob["state"]==&"recover":n=3-n
	return "%s_%s_right_%d" % [mob["type"],pose[0],n+1]
static func decorate(canvas: CanvasItem, mob: Dictionary, colors: Dictionary, hero_at: Vector2, frames: Dictionary, atlas: Texture2D) -> void:
	if mob["state"] == &"dead": return
	var at: Vector2 = mob["position"]
	var boss: bool = bool(mob.get("boss", false))
	var top: Vector2 = (at-Vector2(0,60 if boss else (31 if mob["type"] == &"boar" else 25))).round()
	if int(mob["hp"]) < int(mob["max_hp"]) or at.distance_to(hero_at)<72.0:
		if mob.has("level"):
			draw_level(canvas, top + Vector2(-7,-7), int(mob["level"]), colors)
		var bar_width: int = 56 if boss else 32
		Kit.bar(canvas, top + Vector2(-bar_width / 2, 0), bar_width, [["fill_health_thin", float(mob["hp"]) / maxi(1, int(mob["max_hp"]))]], true)
	if bool(mob["exposed"]):
		canvas.draw_polyline(PackedVector2Array([top+Vector2(0,-8),top+Vector2(3,-5),top+Vector2(0,-2),top+Vector2(-3,-5),top+Vector2(0,-8)]),colors["u"],1.0)
	if mob["state"] == &"alert":
		canvas.draw_rect(Rect2(top+Vector2(-1,-8),Vector2(2,4)),colors["1"])
		canvas.draw_rect(Rect2(top+Vector2(-1,-3),Vector2(2,1)),colors["1"])

## Tiny hard-pixel level label leaves the original HP bar unchanged.
static func draw_level(canvas: CanvasItem, at: Vector2, level: int, colors: Dictionary) -> void:
	var glyphs: Dictionary = {"L":["100","100","100","100","111"], "0":["111","101","101","101","111"], "1":["010","110","010","010","111"], "2":["111","001","111","100","111"], "3":["111","001","111","001","111"], "4":["101","101","111","001","001"], "5":["111","100","111","001","111"], "6":["111","100","111","101","111"], "7":["111","001","010","010","010"], "8":["111","101","111","101","111"], "9":["111","101","111","001","111"]}
	var text: String = "L" + str(level)
	canvas.draw_rect(Rect2(at-Vector2.ONE,Vector2(text.length()*4+1,7)),colors["0"])
	for i: int in text.length():
		var rows: Array = glyphs.get(text[i],glyphs["0"])
		for y: int in 5:
			for x: int in 3:
				if rows[y][x] == "1":canvas.draw_rect(Rect2(at+Vector2(i*4+x,y),Vector2.ONE),colors["1"])
