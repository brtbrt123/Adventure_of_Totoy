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
const HINT_Y: float = 196.0


## The ribbon behind the scene-name toast (top right).
func toast_rect() -> Rect2:
	var w: float = ceilf(text_width(toast_text, 1, menu_font(), TOAST_SIZE)) + 58.0
	return Rect2(380.0 - w, 3, w, 16)


## The plate behind the interact hint: centred above the target (kept on screen), else at the bottom centre.
func hint_rect() -> Rect2:
	var w: float = ceilf(text_width(hint_text, 1, null, 7)) + 12.0
	if hint_at == Vector2.INF:
		return Rect2(floorf(192.0 - w * 0.5), HINT_Y - 3.0, w, 13)
	var x: float = clampf(floorf(hint_at.x - w * 0.5), 2.0, 382.0 - w)
	var y: float = clampf(floorf(hint_at.y - 12.0), 22.0, 202.0)
	return Rect2(x, y, w, 13)


func _draw() -> void:
	if colors.is_empty():
		return
	if fight_hud:
		_draw_combat()
	_draw_progression()
	if toast_text != "" and toast_alpha > 0.0 and not bool(training.get("active", false)) and (combat==null or combat.objective.is_empty()):
		var rect: Rect2 = toast_rect()
		Kit.ribbon(self, rect, toast_alpha)
		outlined(Vector2(rect.position.x + (rect.size.x - text_width(toast_text, 1, menu_font(), TOAST_SIZE)) * 0.5, rect.position.y + 2), toast_text, Color(colors["1"], toast_alpha), Color(colors["0"], toast_alpha), 1, menu_font(), TOAST_SIZE)
	if hint_text != "" and fade_alpha <= 0.0:
		var plate: Rect2 = hint_rect()
		Kit.button(self, plate, &"normal")
		outlined(plate.position + Vector2(6, 4), hint_text, colors["1"], colors["0"], 1, null, 7)
	if bool(training.get("active", false)):
		_draw_training_cards()
	if not debug_lines.is_empty():
		var y: float = 24.0
		draw_rect(Rect2(3, y - 2, 170, debug_lines.size() * 8 + 4), Color(colors["0"], 0.7))
		for line: String in debug_lines:
			lettering(Vector2(6, y), line, colors["p"], 1, stat_font())
			y += 8
	if fade_alpha > 0.0:
		draw_rect(Rect2(-4, -4, 392, 224), Color(colors["0"], clampf(fade_alpha, 0.0, 1.0)))


## Same teal frame, corner gems, title face and body font as the controls/dialogue cards.
func _draw_training_cards() -> void:
	var dy: int=122  # keep the post, its warnings and the practice ring unobscured
	var lesson: String = String(training.get("hint", ""))
	var titles: Dictionary = {"dash": "Dash", "attack": "Attack", "parry": "Parry gold", "dodge": "Dodge red"}
	var details: Dictionary = {"dash": "Dash through the marked ring.", "attack": "Hit the post: %d / %d" % [training.get("hits", 0), training.get("hits_needed", 3)], "parry": "Press just before the gold hit.", "dodge": "Dash through the red hit."}
	var actions: Dictionary = {"dash": "arena_dash", "attack": "arena_attack", "parry": "arena_parry", "dodge": "arena_dash"}
	var feedback: bool = not training_feedback.is_empty() and toast_alpha > 0.0
	if titles.has(lesson) or (bool(training.get("done", false)) and feedback):
		UiPanel.draw_panel(self, Rect2(6, 6+dy, 196, 34), &"info", colors)
		lettering(Vector2(15, 13+dy), titles.get(lesson, "Training complete"), colors["u"], 1, menu_font(), 8)
		lettering(Vector2(15, 26+dy), training_feedback if feedback else String(details.get(lesson, "All four lessons learned.")), colors["1"], 1, ui_font(), 8)
		var key: String = Bindings.action_label(actions[lesson]) if actions.has(lesson) else "Done"
		var width: float = text_width(key, 1, ui_font(), 8) + 10
		var badge: Rect2 = Rect2(193 - width, 12+dy, width, 13)
		Kit.button(self, badge, &"normal")
		lettering(badge.position + Vector2(5, 4), key, colors["1"], 1, ui_font(), 8)
	UiPanel.draw_panel(self, Rect2(244, 180, 134, 32), &"info", colors)
	var checks: Dictionary = training.get("lessons", {})
	var names: Array[String] = ["attack", "dash", "parry", "dodge"]
	for i: int in names.size():
		var name: String = names[i]
		var done: bool = bool(checks.get(name, false))
		var x: float = 254 + (i % 2) * 62
		var y: float = 188 + (i / 2) * 11
		var tone: Color = colors["u"] if done else (colors["1"] if name == lesson else colors["o"])
		UiPanel.outline(self, Rect2(x, y, 5, 5), tone)
		if done:
			draw_polyline(PackedVector2Array([Vector2(x + 1, y + 2), Vector2(x + 2, y + 3), Vector2(x + 4, y)]), tone)
		lettering(Vector2(x + 8, y), name, tone, 1, ui_font(), 8)
		if name == lesson:
			draw_rect(Rect2(x + 8, y + 7, 40, 1), colors["t"])

const Kit := preload("res://presentation/common/ui_kit.gd")
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
## One item slot (kit frame, the game's own herb icon, count and key) or Aspect socket (kit diamond around the game's own
## Aspect icon, key in the stem).
func combat_slot(at: Vector2, key: String, value: Dictionary, item: bool) -> void:
	var unlocked: bool = bool(value.get("unlocked", false))
	if item:
		var rect: Rect2 = Rect2(at, Vector2(26, 26))
		Kit.slot(self, rect, &"normal" if unlocked else &"locked")
		if unlocked and String(value.get("item", "")) == "herb":
			ui("hud_copper_herb", Rect2(at + Vector2(5, 5), Vector2(16, 16)))
		var badge: Rect2 = Rect2(at + Vector2(-2, 19), Vector2(9, 9))
		UiPanel.key_badge(self, badge.position, colors)
		lettering(badge.position + Vector2(4.5 - text_width(key, 1, ui_font(), 6) * 0.5, 2.5), key, colors["1" if unlocked else "g"], 1, ui_font(), 6)
		if unlocked:
			outlined(at + Vector2(18, 18), str(value.get("count", 0)), colors["1"], colors["0"], 1, ui_font(), 7)
		return
	var owned: bool = combat == null or combat.owned_aspects.has(StringName(value.get("aspect", &"")))
	Kit.socket(self, at, not unlocked or not owned)
	if unlocked and owned:
		var icon: Rect2 = Kit.socket_icon_rect(at)
		ui(aspect_icon(StringName(value.get("aspect", &""))), icon, Vector2(4, 4), Vector2(16, 16))
		if not bool(value.get("usable", false)):
			draw_rect(icon, Color(colors["0"], 0.6))
	draw_socket_key(at, key, colors["1" if unlocked and owned else "g"])


func _draw_combat() -> void:
	if combat == null:return
	var weapon: Vector2 = weapon_rect().position - Vector2(0, 2)
	Kit.medallion(self, weapon)
	if combat.armed:ui("ui_weapon_totoy_blade_1", Rect2(Kit.medallion_centre(weapon) - Vector2(16, 16), Vector2(32, 32)))
	var hp: String = "%d / %d" % [combat.hero.hp, combat.hero.max_hp]
	outlined(Vector2(STRIP_X + 2, HP_Y - 11), "HEALTH", colors["u"], colors["0"], 1, null, 7)
	outlined(Vector2(STRIP_X + STRIP_W - 2 - text_width(hp, 1, ui_font(), 8), HP_Y - 12), hp, colors["1"], colors["0"], 1, ui_font(), 8)
	Kit.bar(self, Vector2(STRIP_X, HP_Y), STRIP_W, [["fill_health", float(combat.hero.hp) / maxf(1.0, float(combat.hero.max_hp))]])
	# Edge is not in ExploreSnapshot. Show an unavailable track, never invent a value.
	outlined(Vector2(STRIP_X + 2, THIN_Y - 8), "EDGE  --", colors["g"], colors["0"], 1, null, 6)
	Kit.bar(self, Vector2(STRIP_X, THIN_Y), 84, [], true)
	outlined(Vector2(STRIP_X + 100, THIN_Y - 8), "DASH", colors["v"], colors["0"], 1, null, 6)
	var dash_ready: float = float(maxi(0, dash_peak - combat.dash_cooldown_ticks)) / maxf(1.0, float(dash_peak)) if bool(combat.unlocked.get("dash", false)) else 0.0
	Kit.bar(self, Vector2(STRIP_X + 98, THIN_Y), 38, [["fill_exp_thin", dash_ready]], true)
	for i: int in 2:
		combat_slot(Vector2(208 + i * 30, 184), str(i + 1), combat.item_slots[i] if i < combat.item_slots.size() else {}, true)
	for i: int in 3:
		combat_slot(aspect_rects()[i].position, ["Z", "X", "C"][i], combat.aspect_slots[i] if i < combat.aspect_slots.size() else {}, false)
	# the level pillar: the number sits in its pennant, the violet EXP rises in the tube
	var pillar: Vector2 = Vector2(4, 36)
	Kit.pillar(self, pillar, 118.0, clampf(exp_fill, 0.0, 1.0), colors["v"], colors["p"])
	var level: String = str(combat.level)
	var level_size: int = 11 if level.length() < 2 else 8
	centered(pillar.x + 10.5, pillar.y + 6, level, colors["1"], colors["0"], 1, ui_font(), level_size)
	centered(pillar.x + 10.5, pillar.y + 121, "MAX" if combat.exp_to_next == 0 else "EXP", colors["o"], colors["0"], 1, ui_font(), 6)
	if feedback_active(combat.tick, exp_glow_tick, 24):UiPanel.outline(self, Rect2(pillar.x + 6, pillar.y + 29, 9, 78), colors["p"])
	if feedback_active(combat.tick, item_flash_tick, 15):UiPanel.outline(self, Rect2(207, 183, 28, 28), colors["u"])
	if combat.defeated:
		draw_rect(Rect2(0, 164, 384, 52), Color(colors["0"], 0.6))
		centered(192, 186, "DOWN", colors["o"], colors["0"], 1, ui_font(), 9)

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
		var objective: String = String(combat.objective.get("text",""))
		var plate_w: float = clampf(text_width(objective,1,ui_font(),8)+34.0,120.0,300.0)
		Kit.bar(self,Vector2(4,4),plate_w,[])
		outlined(Vector2(18,8),objective,colors["1"],colors["0"],1,ui_font(),8)
	if level_banner_visible():
		UiPanel.draw_panel(self,Rect2(264,24,116,36),&"info",colors,false)
		centered(322,31,"LEVEL UP",colors["p"],colors["0"],1,ui_font(),8)
		centered(322,43,"+%d stat points" % level_points,colors["u"],colors["0"],1,ui_font(),7)
	if feedback_active(combat.tick,task_tick,100):
		outlined(Vector2(9,24),task_message,colors["u"],colors["0"],1,ui_font(),8)
	if feedback_active(combat.tick,gate_tick,160):
		UiPanel.draw_panel(self,Rect2(14,44,356,34),&"info",colors,false)
		var words: PackedStringArray=gate_message.split(" ")
		var rows: Array[String]=[""]
		for word: String in words:
			var candidate: String=rows[-1]+(" " if not rows[-1].is_empty() else "")+word
			if text_width(candidate,1,ui_font(),8)>330:rows.append(word)
			else:rows[-1]=candidate
		for i: int in mini(2,rows.size()):outlined(Vector2(26,52+i*9),rows[i],colors["1"],colors["0"],1,ui_font(),8)
	var x0: int=60 if fight_hud else 6
	var y0: int=152 if fight_hud else 190
	for i: int in 3:
		var name: String=["dash","attack","parry"][i]
		var unlocked: bool=bool(combat.unlocked.get(name,false))
		var at: Vector2=Vector2(x0+i*38,y0)
		var chip: Rect2=Rect2(at,Vector2(36,17))
		Kit.button(self,chip,&"normal" if unlocked else &"locked")
		var key: String=Bindings.action_label(["arena_dash","arena_attack","arena_parry"][i]).replace("Left click","LMB")
		if not unlocked:Kit.put(self,"icon_padlock",at+Vector2(5,4))
		var key_x: float=chip.position.x+(21.0 if not unlocked else 18.0)
		outlined(Vector2(key_x-text_width(key,1,ui_font(),6)*0.5,at.y+6),key,colors["p" if unlocked else "g"],colors["0"],1,ui_font(),6)
	if feedback_active(combat.tick,locked_tick,70):outlined(Vector2(x0,y0-11),locked_message,colors["o"],colors["0"],1,ui_font(),7)
	outlined(Vector2(6,176) if fight_hud else Vector2(160,198),"TAB"+(" !" if combat.stat_points_unspent>0 else ""),colors["u"],colors["0"],1,ui_font(),7)
