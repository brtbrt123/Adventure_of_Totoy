extends "res://presentation/arena/hud.gd"
## ART REVIEW ONLY. Fixture numbers/unlocks never enter a gameplay snapshot.
const MobView := preload("res://presentation/explore/mob_view.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
var mode: String = "hud_proposal"
var textures: Dictionary = {}
var world: Node2D
var board_size: Vector2 = Vector2(320,180)
var fill: float = 0.5
func _ready() -> void:
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json"))["colors"]:
		colors[entry["symbol"]] = Color(entry["hex"])
	portrait_atlas = load("res://art/build/sprites.png") as Texture2D
	ui_frames = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	var dir: DirAccess = DirAccess.open("res://art/reference/woodland_polish_v1/grids")
	for file: String in dir.get_files():
		if not file.ends_with(".txt"):continue
		var rows: Array[String] = []
		for line: String in FileAccess.get_file_as_string(dir.get_current_dir()+"/"+file).split("\n"):
			var clean: String = line.strip_edges()
			if not clean.is_empty() and not clean.begins_with("#"):rows.append(clean)
		var picture: Image = Image.create(rows[0].length(),rows.size(),false,Image.FORMAT_RGBA8)
		for y: int in rows.size():
			for x: int in rows[y].length():
				var symbol: String = rows[y][x]
				picture.set_pixel(x,y,Color.TRANSPARENT if symbol == "." else colors[symbol])
		textures[file.get_basename()] = ImageTexture.create_from_image(picture)
	queue_redraw()
func label_at(at: Vector2, value: String, color: String = "1", size: int = 8) -> void:
	outlined(at,value,colors[color],colors["0"],1,ui_font(),size)
func icon(name: String, at: Vector2, scale_value: int = 1) -> void:
	var texture: Texture2D = textures[name]
	draw_texture_rect(texture,Rect2(at,texture.get_size()*scale_value),false)
func plate(rect: Rect2, strong: bool = false) -> void:
	UiPanel.draw_panel(self,rect,&"menu" if strong else &"info",colors,false)
func badge(at: Vector2, key: String, dim: bool = false) -> void:
	draw_rect(Rect2(at,Vector2(8,8)),colors["0"])
	UiPanel.outline(self,Rect2(at,Vector2(8,8)),colors["f" if dim else "t"])
	label_at(at+Vector2(2,1),key,"g" if dim else "1",7)
func slot(at: Vector2, key: String, locked: bool, count: String = "--", aspect: String = "") -> void:
	plate(Rect2(at,Vector2(26,26)))
	if locked:
		draw_rect(Rect2(at+Vector2(3,3),Vector2(20,20)),colors["8"])
		UiPanel.outline(self,Rect2(at+Vector2(1,1),Vector2(24,24)),colors["f"])
		icon("lock",at+Vector2(5,3))
	else:
		if aspect.is_empty():icon("herb_bundle",at+Vector2(5,3))
		else:ui(aspect,Rect2(at+Vector2(1,1),Vector2(24,24)))
	badge(at+Vector2(-1,19),key,locked)
	label_at(at+Vector2(18,18),count,"g" if locked else "1",7)
func gauge(at: Vector2, fraction: float, level: String, glow: bool = false, unavailable: bool = false) -> void:
	plate(Rect2(at+Vector2(-3,-14),Vector2(22,13)))
	centered(at.x+8,at.y-11,"LV "+level,colors["g" if unavailable else "1"],colors["0"],1,null,7)
	plate(Rect2(at,Vector2(16,72)))
	var amount: int = floori(62.0*fraction)
	if amount>0:draw_rect(Rect2(at+Vector2(5,67-amount),Vector2(6,amount)),colors["u"])
	if amount>0:draw_rect(Rect2(at+Vector2(5,67-amount),Vector2(6,1)),colors["p"])
	if glow:
		UiPanel.outline(self,Rect2(at-Vector2.ONE,Vector2(18,74)),colors["p"])
		icon("heal_3",at+Vector2(-4,-5))
	centered(at.x+8,at.y+76,"EXP",colors["g" if unavailable else "u"],colors["0"],1,null,7)
func mob_plate(at: Vector2, name: String, level: String, hp: float, ghost: float, strong: bool = false) -> void:
	var width: int = 76 if strong else 58
	var height: int = 16 if strong else 14
	plate(Rect2(at,Vector2(width,height)),strong)
	label_at(at+Vector2(4,3),"L"+level,"v" if strong else "u",7)
	label_at(at+Vector2(17,3),name,"1",7)
	draw_rect(Rect2(at+Vector2(4,height-6),Vector2(width-8,3)),colors["e"])
	draw_rect(Rect2(at+Vector2(4,height-6),Vector2(floori((width-8)*ghost),3)),colors["i"])
	draw_rect(Rect2(at+Vector2(4,height-6),Vector2(floori((width-8)*hp),3)),colors["v" if strong else "u"])
func creature(key: String, feet: Vector2, white: bool = false) -> void:
	var f: Dictionary = ui_frames[key]
	draw_texture_rect_region(MobView.WHITE if white else portrait_atlas,Rect2(feet-Vector2(f["ax"],f["ay"]),Vector2(f["w"],f["h"])),Rect2(f["x"],f["y"],f["w"],f["h"]))
func draw_hud() -> void:
	var live: bool = mode == "hud_snapshot"
	var locked: bool = mode == "hud_locked" or mode == "hud_down"
	var down: bool = mode == "hud_down"
	var title: String = "ART REVIEW - SAMPLE HP / EXP VALUES" if not locked else "ART REVIEW - LOCKED / UNKNOWN FIXTURE"
	if live:title = "ART REVIEW - CURRENT SNAPSHOT FIELDS"
	draw_rect(Rect2(24,4,280,13),colors["0"])
	label_at(Vector2(29,7),title,"u",7)
	var exp_fill: float = (float(world.snapshot.exp)/maxi(1,world.snapshot.exp_to_next) if world.snapshot.exp_to_next>0 else 1.0) if live else (0.0 if locked else 0.55)
	gauge(Vector2(6,47),exp_fill,str(world.snapshot.level) if live else ("?" if locked else "5"),mode == "hud_gain",locked)
	ui("ui_weapon_frame_1",Rect2(3,130,48,48))
	ui("ui_weapon_totoy_blade_1",Rect2(11,138,32,32))
	plate(Rect2(54,148,113,29))
	bar(Vector2(60,153),100,world.snapshot.hero.hp if live else (0 if down else 74),world.snapshot.hero.max_hp if live else 140,colors["t"],6,-1.0 if live else 108)
	label_at(Vector2(64,153),("%d / %d" % [world.snapshot.hero.hp,world.snapshot.hero.max_hp]) if live else ("DOWN" if down else "74 / 140"),"1",7)
	bar(Vector2(60,164),88,0 if down or live else 45,100,colors["v"],3)
	if live:label_at(Vector2(89,162),"--","g",7)
	bar(Vector2(60,171),72,0 if down else 80,100,colors["n"],2)
	ui("ui_icon_edge_1",Rect2(52,161,6,6))
	ui("ui_icon_dash_1",Rect2(52,168,6,6))
	slot(Vector2(60,118),"1",not bool(world.snapshot.item_slots[0].get("unlocked",false)) if live else locked,str(world.snapshot.item_slots[0]["count"]) if live else ("--" if locked else "3"))
	slot(Vector2(92,118),"2",true)
	slot(Vector2(178,148),"Z",true)
	slot(Vector2(210,148),"X",true)
	slot(Vector2(242,148),"C",true)
	if world != null:
		var index: int = 0
		for mob: Dictionary in world.snapshot.mobs:
			if index>=1:break
			var pos: Vector2 = Vector2(mob["position"])-world.view_origin
			mob_plate((pos-Vector2(32,43)).round(),"Mossling",str(mob["level"]) if live else ("?" if locked else "2"),float(mob["hp"])/int(mob["max_hp"]) if live else (0.7 if index==0 else 1.0),float(mob["hp"])/int(mob["max_hp"]) if live else (0.9 if index==0 else 1.0))
			index += 1
	if mode == "hud_gain":
		plate(Rect2(117,27,89,15))
		centered(161,31,"LEVEL UP",colors["p"],colors["0"],1,null,9)
	if down:
		draw_rect(Rect2(Vector2.ZERO,Vector2(320,180)),Color(colors["0"],0.48))
		plate(Rect2(107,77,106,18))
		centered(160,82,"DOWN - RETURNING",colors["o"],colors["0"],1,null,8)
func draw_gauges() -> void:
	label_at(Vector2(9,8),"EXP GAUGE - FIXTURE LEVELS / FILLS","u",10)
	for i: int in 6:
		var x: float = 23+i*48
		gauge(Vector2(x,51),[0.0,0.25,0.5,0.95,1.0,1.0][i],str(10 if i==5 else (5 if i<4 else 6)),i==4)
		label_at(Vector2(x-1,142),["0%","25%","50%","95%","UP","MAX"][i],"1",8)
	label_at(Vector2(12,164),"Gain: rise + teal glint. Level up: brief banner + sound.","o",7)
func draw_slots() -> void:
	label_at(Vector2(10,8),"HERB / ITEM / ASPECT STATES - REVIEW","u",10)
	icon("herb_bundle",Vector2(22,40),4)
	label_at(Vector2(17,113),"16 x 16 native","o",8)
	slot(Vector2(112,48),"1",false,"3")
	slot(Vector2(157,48),"2",true)
	slot(Vector2(202,48),"Z",false,"","ui_aspect_breaking_edge_1")
	slot(Vector2(247,48),"X",true)
	label_at(Vector2(110,83),"Ready", "1",8)
	label_at(Vector2(155,83),"Locked","g",8)
	label_at(Vector2(200,83),"Ready","1",8)
	label_at(Vector2(246,83),"Locked","g",8)
	UiPanel.outline(self,Rect2(111,112,28,28),colors["p"])
	slot(Vector2(112,113),"1",false,"2")
	icon("heal_2",Vector2(114,111))
	label_at(Vector2(151,120),"item_used: burst + slot flash", "o",8)
	label_at(Vector2(111,149),"Exploration: Aspects + slot 2 locked.","g",8)
func draw_mob_bars() -> void:
	label_at(Vector2(8,8),"MOB PLATES - HERO LV 5 FIXTURE", "u",10)
	label_at(Vector2(12,29),"Normal / lower level","o",8)
	label_at(Vector2(174,29),"Stronger / lilac frame","v",8)
	mob_plate(Vector2(29,62),"Mossling","2",fill,minf(1.0,fill+0.25))
	mob_plate(Vector2(177,48),"Thorn Boar","8",fill,minf(1.0,fill+0.25),true)
	creature("mossling_idle_right_1",Vector2(61,105))
	creature("boar_idle_right_1",Vector2(219,105))
	label_at(Vector2(9,122),"HP %d%% - pale grey = delayed damage" % int(fill*100),"1",8)
	mob_plate(Vector2(30,149),"Mossling","?",0.5,0.65)
	label_at(Vector2(108,153),"Unknown level: neutral plate", "g",8)
func draw_drop() -> void:
	label_at(Vector2(9,8),"MOB DROP - VISUAL RECEIPT / NO PICKUP RULE","u",9)
	for n: int in 4:
		var at: Vector2 = Vector2(35+n*77,70)
		creature("mossling_death_right_%d" % mini(5,n+2),at+Vector2(0,28))
		icon("heal_"+str(n+1),at-Vector2(12,10+n*2))
		icon("herb_bundle",at-Vector2(8,8+n*3))
		label_at(at+Vector2(-20,45),"%d ticks" % (n*6),"g",7)
	label_at(Vector2(15,145),"mob_dropped -> brief herb glint -> item_received", "o",8)
	label_at(Vector2(15,164),"Inventory changes only when the core says so.","g",8)
func draw_numbers() -> void:
	label_at(Vector2(9,8),"FLOATING TEXT - COMBO HITS MERGE", "u",10)
	for i: int in 4:
		var at: Vector2 = Vector2(38+i*77,71)
		if i==2:draw_rect(Rect2(at-Vector2(4,4),Vector2(31,16)),colors["0"])
		label_at(at,["12","36","-12","+35"][i],["1","o","v","6"][i],12 if i==1 else 10)
		label_at(at+Vector2(-12,26),["Mob hit","Counter","Hero hurt","Heal"][i],["o","p","v","u"][i],7)
	label_at(Vector2(16,133),"10 + 8 + 12 -> 30 (one number per target)","o",9)
	label_at(Vector2(16,157),"Ink outline; short rise/fade. No warning gold/red.","g",8)
func draw_effects(page: int) -> void:
	label_at(Vector2(8,7),"EFFECT FRAMES - HARD PIXELS / REVIEW", "u",9)
	var names: Array[String] = []
	names.assign(["heal","alert","hit","parry"] if page==0 else ["dust","stagger","death","exposed"])
	for row: int in 4:
		var y: int = 27+row*35
		label_at(Vector2(8,y+8),names[row].capitalize(),"1",8)
		for n: int in 6:
			draw_rect(Rect2(95+n*34,y,27,27),colors["8"])
			icon(names[row]+"_"+str(n+1),Vector2(96+n*34,y+1))
func draw_states(mob_type: String) -> void:
	label_at(Vector2(8,7),mob_type.to_upper()+" STATES - REFERENCE BODIES + PROPOSED FX", "u",8)
	var states: Array[String] = ["idle","alert","chase","windup","strike","recover","crash","stagger","hurt","return","dead"]
	for row: int in states.size():
		var y: int = 28+row*33
		label_at(Vector2(5,y+12),states[row],"o",8)
		draw_rect(Rect2(75,y,239,1),colors["8"])
		for n: int in 4:
			var age: int = n*8
			var sample: Dictionary = {"type":mob_type,"state":StringName(states[row]),"state_ticks":age,"id":9}
			var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
			tell.owner_id=9
			tell.hit_tick=36 if mob_type=="mossling" else 50
			var tells: Array[Snapshots.TelegraphSnapshot]=[tell]
			var key: String = MobView.frame(sample,tells,age)
			# Boar recovery rises from its crouch; stagger holds a dazed pose with orbiting stars.
			if mob_type=="boar" and states[row]=="recover":key="boar_charge_tell_right_%d" % (4-n)
			if mob_type=="mossling" and states[row]=="stagger":key="mossling_hurt_right_%d" % (n%2+1)
			var foot: Vector2 = Vector2(100+n*54,y+30)
			creature(key,foot,states[row]=="hurt" and n==0)
			var fx: String = {"alert":"alert","crash":"dust","stagger":"stagger","dead":"death"}.get(states[row],"")
			if not fx.is_empty():icon(fx+"_"+str(mini(6,n+1)),foot-Vector2(12,32 if fx in ["alert","stagger"] else 18))
func _draw() -> void:
	if colors.is_empty() or textures.is_empty():return
	if mode.begins_with("hud_"):
		draw_hud()
		return
	draw_rect(Rect2(Vector2.ZERO,board_size),colors["0"])
	match mode:
		"gauges":draw_gauges()
		"slots":draw_slots()
		"mob_bars":draw_mob_bars()
		"numbers":draw_numbers()
		"drop":draw_drop()
		"effects_a":draw_effects(0)
		"effects_b":draw_effects(1)
		"states_mossling":draw_states("mossling")
		"states_boar":draw_states("boar")
