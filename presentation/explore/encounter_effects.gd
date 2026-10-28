extends "res://presentation/arena/hud.gd"
## Cosmetic event history only. Damage, healing, drops and state timing remain core-owned.
const ExploreCore := preload("res://core/explore_core.gd")
const GameEvent := preload("res://core/game_event.gd")
var view: ExploreCore.ExploreSnapshot
var effects: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
func clear() -> void:
	effects.clear()
	numbers.clear()
func sync(value: ExploreCore.ExploreSnapshot, palette: Dictionary, frames: Dictionary, atlas: Texture2D) -> void:
	view = value
	colors = palette
	ui_frames = frames
	portrait_atlas = atlas
	z_index = 6
	effects = effects.filter(func(e: Dictionary) -> bool: return value.tick-int(e["tick"])<36)
	numbers = numbers.filter(func(e: Dictionary) -> bool: return value.tick-int(e["tick"])<40)
	queue_redraw()
func number(at: Vector2, amount: int, style: String, target: int, tick: int) -> void:
	for entry: Dictionary in numbers:
		if entry["target"] == target and entry["style"] == style and tick-int(entry["last"])<=10:
			entry["amount"] = int(entry["amount"])+amount
			entry["last"] = tick
			entry["tick"] = tick
			entry["at"] = at
			return
	numbers.append({"at":at,"amount":amount,"style":style,"target":target,"tick":tick,"last":tick})
	if numbers.size()>12:numbers.pop_front()
func handle_event(event: GameEvent, state: ExploreCore.ExploreSnapshot) -> void:
	var at: Vector2 = event.data.get("position",state.hero.position)
	var family: String = ""
	match event.type:
		GameEvent.ATTACK_HIT:
			var kind: String = "counter" if event.data.get("kind",&"")==&"counter" else "mob"
			number(at,int(event.data.get("damage",0)),kind,int(event.data.get("target_id",-1)),event.tick)
			family = "hit"
		GameEvent.DAMAGE_TAKEN:
			number(state.hero.position,int(event.data.get("amount",0)),"hero",state.hero.id,event.tick)
		GameEvent.ITEM_USED:
			number(state.hero.position,int(event.data.get("healed",0)),"heal",state.hero.id,event.tick)
			family = "heal"
		GameEvent.MOB_ALERTED: family = "alert"
		GameEvent.PARRY_SUCCEEDED: family = "parry"
		GameEvent.MOB_STAGGERED: family = "dust" if event.data.get("reason",&"")==&"crash" else "stagger"
		GameEvent.MOB_DEFEATED: family = "death"
		GameEvent.MOB_DROPPED: family = "drop"
	if not family.is_empty():effects.append({"family":family,"at":at,"tick":event.tick})
func fx(family: String, at: Vector2, age: int) -> void:
	ui("woodland_fx_%s_%d" % [family,mini(6,age/4+1)],Rect2((at-Vector2(12,12)).round(),Vector2(24,24)))
func _draw() -> void:
	if view == null or colors.is_empty():return
	for e: Dictionary in effects:
		var age: int = view.tick-int(e["tick"])
		var at: Vector2 = e["at"]
		if e["family"] == "drop":
			ui("hud_copper_herb",Rect2((at-Vector2(8,12+mini(age,18))).round(),Vector2(16,16)))
		elif age<24:fx(e["family"],at-Vector2(0,0 if e["family"] in ["dust","death"] else 12),age)
	for mob: Dictionary in view.mobs:
		if mob["state"] in [&"stagger",&"crash"]:fx("stagger",mob["position"]-Vector2(0,30),posmod(view.tick,24))
		if bool(mob["exposed"]) and mob["state"]!=&"dead":fx("exposed",mob["position"]-Vector2(0,37),posmod(view.tick,24))
	for entry: Dictionary in numbers:
		var age: int = view.tick-int(entry["tick"])
		var style: String = entry["style"]
		var at: Vector2 = (Vector2(entry["at"])+Vector2(-6,-30-age*0.4)).round()
		var color: Color = colors[{"mob":"1","counter":"o","hero":"v","heal":"6"}[style]]
		color.a = clampf(float(40-age)/12.0,0.0,1.0)
		var text: String = ("-" if style=="hero" else ("+" if style=="heal" else ""))+str(entry["amount"])
		if style=="hero":draw_rect(Rect2(at-Vector2(2,1),Vector2(text_width(text,1,ui_font(),8)+4,10)),Color(colors["0"],color.a))
		outlined(at,text,color,Color(colors["0"],color.a),1,ui_font(),10 if style=="counter" else 8)
