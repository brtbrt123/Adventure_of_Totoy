extends "res://presentation/arena/hud.gd"
## The exploration HUD-lite (screen space, 320x180, text at window resolution like the fight HUD): the scene-name toast
## top left when a scene is entered, the interact hint ("[E] TALK" near an NPC), the debug lines (F1) and the
## transition fade. Presentation only: explore_scene.gd sets the fields from the ExploreCore snapshot.

## The scene name and how strongly it shows (0..1; explore_scene.gd fades it out).
var toast_text: String = ""
var toast_alpha: float = 0.0
## "[E] TALK" etc.; empty = nothing in range.
var hint_text: String = ""
## Where the hint's plate is centred (screen space, its bottom edge): above the target's head; INF = bottom centre.
var hint_at: Vector2 = Vector2.INF
## 0 = clear, 1 = the screen is ink (the 0.3 s fade between scenes).
var fade_alpha: float = 0.0
var debug_lines: Array[String] = []
var training: Dictionary = {}
var herb_count: int = 0
var explore_hp: int = 0
var explore_max_hp: int = 0
var fight_hud: bool = false
var training_feedback: String = ""
var training_at: Vector2 = Vector2.INF
const Bindings := preload("res://presentation/arena/input_bindings.gd")


func training_hint() -> String:
	match String(training.get("hint", "")):
		"dash": return "Dash through ring: " + Bindings.action_label("arena_dash")
		"attack": return "Attack 3 times: %s (%d/%d)" % [Bindings.action_label("arena_attack"), training.get("hits", 0), training.get("hits_needed", 3)]
		"parry": return "Parry GOLD just before hit: " + Bindings.action_label("arena_parry")
		"dodge": return "Dash through RED: " + Bindings.action_label("arena_dash")
	return ""


const TOAST_SIZE: int = 11
const HINT_Y: float = 160.0


## The plate behind the scene-name toast (top left).
func toast_rect() -> Rect2:
	var w: float = ceilf(text_width(toast_text, 1, menu_font(), TOAST_SIZE)) + 14.0
	return Rect2(4, 4, w, 15)


## The plate behind the interact hint: centred above the target (kept on screen), else at the bottom centre.
func hint_rect() -> Rect2:
	var w: float = ceilf(text_width(hint_text)) + 10.0
	if hint_at == Vector2.INF:
		return Rect2(floorf(160.0 - w * 0.5), HINT_Y - 3.0, w, 12)
	var x: float = clampf(floorf(hint_at.x - w * 0.5), 2.0, 318.0 - w)
	var y: float = clampf(floorf(hint_at.y - 12.0), 22.0, 166.0)
	return Rect2(x, y, w, 12)


func _draw() -> void:
	if colors.is_empty():
		return
	if fight_hud:
		_draw_combat()
	_draw_progression()
	if toast_text != "" and toast_alpha > 0.0 and not bool(training.get("active", false)) and (combat==null or combat.objective.is_empty()):
		var rect: Rect2 = toast_rect()
		draw_rect(rect, Color(colors["0"], 0.78 * toast_alpha))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 1), Vector2(rect.size.x, 1)), Color(colors["u"], toast_alpha))
		outlined(rect.position + Vector2(7, 3), toast_text, Color(colors["1"], toast_alpha), Color(colors["0"], toast_alpha), 1, menu_font(), TOAST_SIZE)
	if hint_text != "" and fade_alpha <= 0.0:
		var plate: Rect2 = hint_rect()
		draw_rect(plate, Color(colors["0"], 0.78))
		draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1)), colors["v"])
		outlined(plate.position + Vector2(5, 3), hint_text, colors["1"], colors["0"])
	if bool(training.get("active", false)):
		_draw_training_cards()
	if not debug_lines.is_empty():
		var y: float = 24.0
		draw_rect(Rect2(3, y - 2, 170, debug_lines.size() * 8 + 4), Color(colors["0"], 0.7))
		for line: String in debug_lines:
			lettering(Vector2(6, y), line, colors["p"], 1, stat_font())
			y += 8
	if fade_alpha > 0.0:
		draw_rect(Rect2(-4, -4, 328, 188), Color(colors["0"], clampf(fade_alpha, 0.0, 1.0)))


## Same teal frame, corner gems, title face and body font as the controls/dialogue cards.
func _draw_training_cards() -> void:
	var dy: int=104  # keep the post, its warnings and the practice ring unobscured
	var lesson: String = String(training.get("hint", ""))
	var titles: Dictionary = {"dash": "Dash", "attack": "Attack", "parry": "Parry gold", "dodge": "Dodge red"}
	var details: Dictionary = {"dash": "Dash through the marked ring.", "attack": "Hit the post: %d / %d" % [training.get("hits", 0), training.get("hits_needed", 3)], "parry": "Press just before the gold hit.", "dodge": "Dash through the red hit."}
	var actions: Dictionary = {"dash": "arena_dash", "attack": "arena_attack", "parry": "arena_parry", "dodge": "arena_dash"}
	var feedback: bool = not training_feedback.is_empty() and toast_alpha > 0.0
	if titles.has(lesson) or (bool(training.get("done", false)) and feedback):
		UiPanel.draw_panel(self, Rect2(6, 6+dy, 184, 29), &"info", colors)
		lettering(Vector2(14, 12+dy), titles.get(lesson, "Training complete"), colors["u"], 1, menu_font(), 8)
		lettering(Vector2(14, 25+dy), training_feedback if feedback else String(details.get(lesson, "All four lessons learned.")), colors["1"], 1, ui_font(), 8)
		var key: String = Bindings.action_label(actions[lesson]) if actions.has(lesson) else "Done"
		var width: float = text_width(key, 1, ui_font(), 8) + 10
		var badge: Rect2 = Rect2(182 - width, 10+dy, width, 12)
		draw_rect(badge, colors["8"])
		UiPanel.outline(self, badge, colors["t"])
		lettering(badge.position + Vector2(5, 3), key, colors["1"], 1, ui_font(), 8)
	UiPanel.draw_panel(self, Rect2(180, 145, 134, 29), &"info", colors)
	var checks: Dictionary = training.get("lessons", {})
	var names: Array[String] = ["attack", "dash", "parry", "dodge"]
	for i: int in names.size():
		var name: String = names[i]
		var done: bool = bool(checks.get(name, false))
		var x: float = 188 + (i % 2) * 63
		var y: float = 152 + (i / 2) * 11
		var tone: Color = colors["u"] if done else (colors["1"] if name == lesson else colors["o"])
		UiPanel.outline(self, Rect2(x, y, 5, 5), tone)
		if done:
			draw_polyline(PackedVector2Array([Vector2(x + 1, y + 2), Vector2(x + 2, y + 3), Vector2(x + 4, y)]), tone)
		lettering(Vector2(x + 8, y), name, tone, 1, ui_font(), 8)
		if name == lesson:
			draw_rect(Rect2(x + 8, y + 7, 40, 1), colors["t"])

const ExploreCore := preload("res://core/explore_core.gd")
const GameEvent := preload("res://core/game_event.gd")
var combat: ExploreCore.ExploreSnapshot
var exp_fill: float = -1.0
var exp_glow_tick: int = -1000
var level_up_tick: int = -1000
var item_flash_tick: int = -1000
var shown_level: int = 0
var combat_scene: StringName = &""
var dash_peak: int=1
var dash_previous: int=0
func sync_combat(value: ExploreCore.ExploreSnapshot) -> void:
	var changed: bool = combat_scene != value.scene_id or (combat != null and value.tick < combat.tick)
	if changed:reset_combat_feedback()
	if changed:
		dash_peak=1
		dash_previous=0
	if value.dash_cooldown_ticks>dash_previous:dash_peak=value.dash_cooldown_ticks
	dash_previous=value.dash_cooldown_ticks
	combat = value
	combat_scene = value.scene_id
	var target: float = 1.0 if value.exp_to_next == 0 else clampf(float(value.exp)/value.exp_to_next,0.0,1.0)
	if changed or exp_fill < 0.0: exp_fill = target
	elif shown_level != value.level: exp_fill = 0.0
	else: exp_fill = move_toward(exp_fill,target,0.035)
	shown_level = value.level
func reset_combat_feedback() -> void:
	exp_glow_tick = -1000
	level_up_tick = -1000
	item_flash_tick = -1000
	task_tick=-1000
	gate_tick=-1000
	locked_tick=-1000
static func feedback_active(now: int, started: int, duration: int) -> bool:
	return started>=0 and now>=started and now-started<duration
func level_banner_visible() -> bool:
	return combat != null and feedback_active(combat.tick,level_up_tick,65)
func combat_event(event: GameEvent) -> void:
	match event.type:
		GameEvent.EXP_GAINED: exp_glow_tick = event.tick
		GameEvent.LEVEL_UP:
			level_up_tick = event.tick
			level_points = int(event.data.get("points",0))
		GameEvent.QUEST_COMPLETED:
			task_tick=event.tick
			task_message="Task complete +%d EXP" % int(event.data.get("exp",0))
		GameEvent.ITEM_USED: item_flash_tick = event.tick
func combat_slot(at: Vector2, key: String, value: Dictionary, item: bool) -> void:
	ui("hud_copper_slot",Rect2(at,Vector2(24,24)))
	var unlocked: bool = bool(value.get("unlocked",false))
	if not unlocked:
		draw_rect(Rect2(at+Vector2(3,3),Vector2(18,18)),colors["e"])
		ui("hud_copper_lock",Rect2(at+Vector2(8,3),Vector2(8,16)))
	elif item and String(value.get("item","")) == "herb":
		ui("hud_copper_herb",Rect2(at+Vector2(4,2),Vector2(16,16)))
	elif not item:
		ui(aspect_icon(StringName(value.get("aspect",&""))),Rect2(at+Vector2.ONE,Vector2(22,22)))
		if not bool(value.get("usable",false)):
			draw_rect(Rect2(at+Vector2(3,3),Vector2(18,18)),Color(colors["0"],0.65))
			if combat!=null and not combat.owned_aspects.has(StringName(value.get("aspect",&""))):ui("hud_copper_lock",Rect2(at+Vector2(8,3),Vector2(8,16)))
	var badge: Rect2 = Rect2(at+Vector2(-1,17),Vector2(8,8))
	draw_rect(badge,colors["0"])
	UiPanel.outline(self,badge,colors["g"])
	outlined(badge.position+Vector2(2,1),key,colors["1" if unlocked else "g"],colors["0"],1,ui_font(),7)
	if item:
		outlined(at+Vector2(17,17),str(value.get("count",0)) if unlocked else "-",colors["1" if unlocked else "g"],colors["0"],1,ui_font(),7)
func _draw_combat() -> void:
	if combat == null:return
	ui("hud_copper_weapon",Rect2(3,130,48,48))
	if combat.armed:ui("ui_weapon_totoy_blade_1",Rect2(11,138,32,32))
	ui("hud_copper_meters",Rect2(54,146,112,32))
	bar(Vector2(62,153),94,combat.hero.hp,combat.hero.max_hp,colors["A"],6)
	outlined(Vector2(64,153),"%d / %d" % [combat.hero.hp,combat.hero.max_hp],colors["1"],colors["0"],1,ui_font(),7)
	# Edge is not in ExploreSnapshot. Show an unavailable track, never invent a value.
	outlined(Vector2(92,162),"--",colors["g"],colors["0"],1,ui_font(),6)
	bar(Vector2(62,170),72,maxi(0,dash_peak-combat.dash_cooldown_ticks) if bool(combat.unlocked.get("dash",false)) else 0,dash_peak,colors["v"],2)
	for i: int in 2:
		combat_slot(Vector2(178+i*28,150),str(i+1),combat.item_slots[i] if i<combat.item_slots.size() else {},true)
	for i: int in 3:
		combat_slot(Vector2(234+i*28,150),["Z","X","C"][i],combat.aspect_slots[i] if i<combat.aspect_slots.size() else {},false)
	ui("hud_copper_exp",Rect2(6,45,16,80))
	ui("hud_copper_level",Rect2(2,27,24,16))
	centered(14,32,"LV.%d" % combat.level,colors["1"],colors["0"],1,ui_font(),7)
	var height: int = floori(64*clampf(exp_fill,0.0,1.0))
	draw_rect(Rect2(12,117-height,4,height),colors["u"])
	if height>0:draw_rect(Rect2(12,117-height,4,1),colors["p"])
	centered(14,127,"MAX" if combat.exp_to_next==0 else "EXP",colors["o"],colors["0"],1,ui_font(),7)
	if feedback_active(combat.tick,exp_glow_tick,24):UiPanel.outline(self,Rect2(7,46,14,78),colors["p"])
	if feedback_active(combat.tick,item_flash_tick,15):UiPanel.outline(self,Rect2(177,149,26,26),colors["u"])
	if combat.defeated:
		draw_rect(Rect2(0,130,320,50),Color(colors["0"],0.6))
		centered(105,155,"DOWN",colors["o"],colors["0"],1,ui_font(),9)

var task_message: String=""
var task_tick: int=-1000
var gate_message: String=""
var gate_tick: int=-1000
var locked_message: String=""
var locked_tick: int=-1000
var level_points: int=0
func locked_hint(text: String) -> void:
	locked_message=text
	locked_tick=combat.tick if combat!=null else 0
func _draw_progression() -> void:
	if combat==null:return
	if not combat.objective.is_empty():
		UiPanel.draw_panel(self,Rect2(5,5,310,16),&"info",colors,false)
		outlined(Vector2(12,10),String(combat.objective.get("text","")),colors["1"],colors["0"],1,ui_font(),8)
	if level_banner_visible():
		UiPanel.draw_panel(self,Rect2(206,24,108,25),&"info",colors,false)
		centered(260,28,"LEVEL UP",colors["p"],colors["0"],1,ui_font(),8)
		centered(260,39,"+%d stat points" % level_points,colors["u"],colors["0"],1,ui_font(),7)
	if feedback_active(combat.tick,task_tick,100):
		outlined(Vector2(9,25),task_message,colors["u"],colors["0"],1,ui_font(),8)
	if feedback_active(combat.tick,gate_tick,160):
		UiPanel.draw_panel(self,Rect2(12,35,296,27),&"info",colors,false)
		var words: PackedStringArray=gate_message.split(" ")
		var rows: Array[String]=[""]
		for word: String in words:
			var candidate: String=rows[-1]+(" " if not rows[-1].is_empty() else "")+word
			if text_width(candidate,1,ui_font(),8)>278:rows.append(word)
			else:rows[-1]=candidate
		for i: int in mini(2,rows.size()):outlined(Vector2(20,43+i*8),rows[i],colors["1"],colors["0"],1,ui_font(),8)
	var x0: int=60 if fight_hud else 6
	var y0: int=126 if fight_hud else 155
	for i: int in 3:
		var name: String=["dash","attack","parry"][i]
		var unlocked: bool=bool(combat.unlocked.get(name,false))
		var at: Vector2=Vector2(x0+i*34,y0)
		draw_rect(Rect2(at,Vector2(32,17)),colors["0"])
		UiPanel.outline(self,Rect2(at,Vector2(32,17)),colors["t" if unlocked else "f"])
		if not unlocked:ui("hud_copper_lock",Rect2(at+Vector2(1,2),Vector2(6,12)))
		var key: String=Bindings.action_label(["arena_dash","arena_attack","arena_parry"][i]).replace("Left click","LMB")
		outlined(at+Vector2(9 if not unlocked else 3,5),key,colors["p" if unlocked else "g"],colors["0"],1,ui_font(),6)
	if feedback_active(combat.tick,locked_tick,70):outlined(Vector2(x0,y0-11),locked_message,colors["o"],colors["0"],1,ui_font(),7)
	outlined(Vector2(6,118) if fight_hud else Vector2(124,160),"TAB"+(" !" if combat.stat_points_unspent>0 else ""),colors["u"],colors["0"],1,ui_font(),7)
