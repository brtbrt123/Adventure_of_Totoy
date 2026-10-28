extends RefCounted
## Pure snapshot-driven mob poses and decorations; core owns state lengths and all contact geometry.
const Snapshots := preload("res://core/snapshots.gd")
const Tuning := preload("res://core/tuning.gd")
const WHITE := preload("res://art/build/sprites_white.png")
const STATES: Dictionary = {
 "mossling": {"idle":["idle",4,12,true], "alert":["spawn",4,6,false], "chase":["walk",6,5,true], "return":["walk",6,5,true], "windup":["attack_tell",3,1,false], "strike":["attack_lunge",3,3,false], "recover":["attack_recover",3,8,false], "crash":["attack_recover",3,8,true], "stagger":["attack_recover",3,8,true], "hurt":["hurt",2,5,false], "dead":["death",5,8,false]},
 "boar": {"idle":["idle",4,14,true], "alert":["idle",4,6,false], "chase":["walk",6,5,true], "return":["walk",6,5,true], "windup":["charge_tell",4,1,false], "strike":["charge_run",4,4,true], "recover":["crash_stun",3,9,false], "crash":["crash_stun",3,9,true], "stagger":["crash_stun",3,9,true], "hurt":["hurt",2,5,false], "dead":["death",5,8,false]}}
static func frame(mob: Dictionary, tells: Array[Snapshots.TelegraphSnapshot], tick: int) -> String:
	var table: Dictionary = STATES[String(mob["type"])]
	var pose: Array = table.get(String(mob["state"]), table["idle"])
	var n: int = int(mob["state_ticks"]) / int(pose[2])
	if mob["state"] == &"windup":
		for tell: Snapshots.TelegraphSnapshot in tells:
			if tell.owner_id == mob["id"]:
				n = floori(float(tick-tell.start_tick) / maxi(1,tell.hit_tick-tell.start_tick) * int(pose[1]))
	if mob["state"] == &"dead":
		n = floori(float(mob["state_ticks"]) / Tuning.MOB_DEATH_TICKS * int(pose[1]))
	n = posmod(n,int(pose[1])) if bool(pose[3]) else clampi(n,0,int(pose[1])-1)
	return "%s_%s_right_%d" % [mob["type"],pose[0],n+1]
static func decorate(canvas: CanvasItem, mob: Dictionary, colors: Dictionary) -> void:
	if mob["state"] == &"dead": return
	var at: Vector2 = mob["position"]
	var top: Vector2 = (at-Vector2(0,31 if mob["type"] == &"boar" else 25)).round()
	if int(mob["hp"]) < int(mob["max_hp"]):
		if mob.has("level"):
			draw_level(canvas, top + Vector2(-7,-7), int(mob["level"]), colors)
		canvas.draw_rect(Rect2(top+Vector2(-11,0),Vector2(22,4)),colors["0"])
		canvas.draw_rect(Rect2(top+Vector2(-10,1),Vector2(floori(20.0*float(mob["hp"])/int(mob["max_hp"])),2)),colors["7"])
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
