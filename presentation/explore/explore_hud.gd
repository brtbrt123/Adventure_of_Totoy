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
	elif strip != null:
		strip.visible = false
	_sync_overlay()
	if not debug_lines.is_empty():
		var y: float = 24.0
		draw_rect(Rect2(3, y - 2, 170, debug_lines.size() * 8 + 4), Color(colors["0"], 0.7))
		for line: String in debug_lines:
			lettering(Vector2(6, y), line, colors["p"], 1, stat_font())
			y += 8
	if fade_alpha > 0.0:
		draw_rect(Rect2(-4, -4, 392, 224), Color(colors["0"], clampf(fade_alpha, 0.0, 1.0)))


const ExploreOverlay := preload("res://presentation/ui/explore_overlay.tscn")
var overlay: Control = null


## Hands the road's messages (objective, ribbon, banner, chips, hint, tutorial cards) to the scene presentation/ui/explore_overlay.tscn.
func _sync_overlay() -> void:
	if overlay == null:
		overlay = ExploreOverlay.instantiate()
		add_child(overlay)
	var data: Dictionary = {}
	var training_on: bool = bool(training.get("active", false))
	if combat != null:
		if not combat.objective.is_empty():
			data["objective"] = String(combat.objective.get("text", ""))
		if not combat.trial.is_empty():
			var trial: Dictionary = combat.trial
			match String(trial.get("state","idle")):
				"idle": data["objective"] = "E at altar: begin trial."
				"starting": data["objective"] = "The trial awakens."
				"wave": data["objective"] = "WAVE %d/%d - %s" % [trial["wave"],trial["waves"],("INCOMING" if int(trial["alive"])==0 else "%d LEFT" % int(trial["alive"]))]
				"between": data["objective"] = "Wave %d cleared." % int(trial["wave"])
				"won": data["objective"] = "Trial complete." if combat.story_flags.has(&"trial_chest_opened") else "Open the trial chest."
		if level_banner_visible():
			data["level_up"] = {"sub": "+%d stat points" % level_points}
		if feedback_active(combat.tick, task_tick, 100):
			data["task"] = task_message
		if feedback_active(combat.tick, gate_tick, 160):
			var rows: Array[String] = [""]
			for word: String in gate_message.split(" "):
				var candidate: String = rows[-1] + (" " if not rows[-1].is_empty() else "") + word
				if text_width(candidate, 1, ui_font(), 8) > 330:
					rows.append(word)
				else:
					rows[-1] = candidate
			data["gate"] = rows.slice(0, 2)
		var x0: int = 60 if fight_hud else 6
		var y0: int = 152 if fight_hud else 190
		var items: Array = []
		for i: int in 3:
			items.append({"unlocked": bool(combat.unlocked.get(["dash", "attack", "parry"][i], false)), "key": Bindings.action_label(["arena_dash", "arena_attack", "arena_parry"][i]).replace("Left click", "LMB")})
		data["chips"] = {"x": x0, "y": y0, "items": items}
		if feedback_active(combat.tick, locked_tick, 70):
			data["locked"] = {"text": locked_message, "x": x0, "y": y0 - 11}
		data["tab"] = {"text": "TAB" + (" !" if combat.stat_points_unspent > 0 else ""), "x": 6 if fight_hud else 160, "y": 176 if fight_hud else 198}
	if toast_text != "" and toast_alpha > 0.0 and not training_on:
		data["toast"] = {"text": toast_text, "alpha": toast_alpha}
	if hint_text != "" and fade_alpha <= 0.0:
		var plate: Rect2 = hint_rect()
		data["hint"] = {"text": hint_text, "x": plate.position.x, "y": plate.position.y}
	if training_on:
		_sync_training(data)
	overlay.apply(data)


## The tutorial cards' words: the lesson card (title, detail, key) and the four-lesson checklist.
func _sync_training(data: Dictionary) -> void:
	var lesson: String = String(training.get("hint", ""))
	var titles: Dictionary = {"dash": "Dash", "attack": "Attack", "parry": "Parry gold", "dodge": "Dodge red"}
	var details: Dictionary = {"dash": "Dash through the marked ring.", "attack": "Hit the post: %d / %d" % [training.get("hits", 0), training.get("hits_needed", 3)], "parry": "Press just before the gold hit.", "dodge": "Dash through the red hit."}
	var actions: Dictionary = {"dash": "arena_dash", "attack": "arena_attack", "parry": "arena_parry", "dodge": "arena_dash"}
	var feedback: bool = not training_feedback.is_empty() and toast_alpha > 0.0
	if titles.has(lesson) or (bool(training.get("done", false)) and feedback):
		data["lesson"] = {"title": titles.get(lesson, "Training complete"), "detail": training_feedback if feedback else String(details.get(lesson, "All four lessons learned.")), "key": Bindings.action_label(actions[lesson]) if actions.has(lesson) else "Done"}
	data["checklist"] = {"names": ["attack", "dash", "parry", "dodge"], "done": training.get("lessons", {}), "current": lesson}


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
var hp_shown: float = -1.0
var hp_ghost: float = -1.0
var hp_delay: int = 0
var hp_tick: int = -1
func sync_combat(value: ExploreCore.ExploreSnapshot) -> void:
	var changed: bool = combat_scene != value.scene_id or (combat != null and value.tick < combat.tick)
	if changed:reset_combat_feedback()
	var elapsed: int = maxi(0, value.tick - hp_tick)
	var hp: float = float(value.hero.hp)
	if changed or hp_shown < 0.0 or hp > hp_shown:
		hp_ghost = hp
		hp_delay = 0
	elif hp < hp_shown:
		hp_delay = 18
	else:
		hp_delay = maxi(0, hp_delay - elapsed)
		if hp_delay == 0:
			hp_ghost = move_toward(hp_ghost, hp, elapsed * maxf(1.0, value.hero.max_hp * 0.025))
	hp_shown = hp
	hp_tick = value.tick
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
	hp_shown = -1.0
	hp_tick = -1
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
## The bottom strip, level pillar and sockets are the editable scene presentation/ui/hud_strip.tscn (open it in Godot to
## move or re-texture anything); this script only hands it numbers from the snapshot.
var strip: Control = null


func _ready() -> void:
	strip = HudStrip.instantiate()
	strip.visible = false
	add_child(strip)


func _sync_strip() -> void:
	if strip == null:
		return
	strip.visible = fight_hud and combat != null and not colors.is_empty()
	if not strip.visible:
		return
	strip.atlas = portrait_atlas
	strip.frames = ui_frames
	var items: Array = []
	for i: int in 2:
		items.append(combat.item_slots[i] if i < combat.item_slots.size() else {})
	var aspects: Array = []
	for i: int in 3:
		var value: Dictionary = combat.aspect_slots[i] if i < combat.aspect_slots.size() else {}
		aspects.append({"unlocked": bool(value.get("unlocked", false)), "owned": combat.owned_aspects.has(StringName(value.get("aspect", &""))), "usable": bool(value.get("usable", false)), "icon": aspect_icon(StringName(value.get("aspect", &"")))})
	var dash_ready: float = float(maxi(0, dash_peak - combat.dash_cooldown_ticks)) / maxf(1.0, float(dash_peak)) if bool(combat.unlocked.get("dash", false)) else 0.0
	strip.apply({
		"armed": combat.armed, "weapon_glyph": "ui_weapon_totoy_blade_1",
		"hp": combat.hero.hp, "max_hp": combat.hero.max_hp, "ghost": hp_ghost if hp_ghost >= 0.0 else combat.hero.hp,
		"edge": -1.0,  # Edge is not in ExploreSnapshot: an unavailable track, never an invented value
		"dash": dash_ready, "items": items, "aspects": aspects,
		"level": combat.level, "exp": clampf(exp_fill, 0.0, 1.0), "exp_label": "MAX" if combat.exp_to_next == 0 else "EXP",
		"defeated": combat.defeated,
	})


func _draw_combat() -> void:
	if combat == null:return
	_sync_strip()
	var pillar: Vector2 = Vector2(4, 36)
	if feedback_active(combat.tick, exp_glow_tick, 24):UiPanel.outline(self, Rect2(pillar.x + 6, pillar.y + 29, 9, 78), colors["p"])
	if feedback_active(combat.tick, item_flash_tick, 15):UiPanel.outline(self, Rect2(207, 183, 28, 28), colors["u"])
	if combat.defeated:
		draw_rect(Rect2(0, 164, 384, 52), Color(colors["0"], 0.6))

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
