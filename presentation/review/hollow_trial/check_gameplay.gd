extends SceneTree
## Real core, real input for altar/chest; automated lethal hits accelerate wave clears (not manual play).
const Explore := preload("res://presentation/explore/explore_scene.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const MobView := preload("res://presentation/explore/mob_view.gd")
var scene: Explore
var failures: int = 0
var seen: Dictionary = {}
const OUT: String = "res://presentation/review/hollow_trial/"

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("TRIAL GAMEPLAY FAIL: ",label)

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func contrast_proof() -> void:
	if DisplayServer.get_name()=="headless": return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(512,352)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map: Node2D = load("res://presentation/maps/hollow_trial_layered.tscn").instantiate() as Node2D
	viewport.add_child(map)
	map.set("animate_preview",false)
	map.call("sync_snapshot",scene.snapshot.trial,scene.snapshot.story_flags,scene.snapshot.tick)
	var actors: Array[Dictionary] = []
	for mob: Dictionary in scene.snapshot.mobs:
		actors.append({"frame":MobView.frame(mob,scene.snapshot.telegraphs,scene.snapshot.tick),"at":mob["position"],"left":Vector2(mob["facing"]).x<0})
	actors.append({"frame":scene.hero_frame,"at":scene.snapshot.hero.position,"left":scene.facing_left})
	for actor: Dictionary in actors:
		var f: Dictionary = scene.frames[actor["frame"]]
		var node: Node2D = Node2D.new()
		node.position = Vector2(actor["at"]).round()
		node.use_parent_material = true
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load("res://art/build/sprites/%s.png" % actor["frame"]) as Texture2D
		sprite.centered = false
		sprite.flip_h = actor["left"]
		sprite.offset = Vector2(-(float(f["w"])-float(f["ax"])) if actor["left"] else -float(f["ax"]),-float(f["ay"]))
		sprite.use_parent_material = true
		node.add_child(sprite)
		map.get_node("Props").add_child(node)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.resize(1024,704,Image.INTERPOLATE_NEAREST)
	image.save_png(OUT+"contrast_actual_wave2_2x.png")
	viewport.queue_free()
	await process_frame

func step(input: InputFrame = InputFrame.new()) -> void:
	scene.core.player.hp = scene.core.hero_max_hp() # keeps the unattended capture alive; damage still resolves in core
	scene.advance(input)
	scene.fade_phase = &""
	for event: GameEvent in scene.core.last_events:
		seen[event.type] = true

func finish_live_mobs() -> void:
	var events: Array[GameEvent] = []
	for enc: Object in scene.core.mobs.encounters:
		for mob: Object in enc.mobs:
			if mob.is_alive():
				scene.core.mobs.hit_mob(scene.core,enc,mob,10000.0,{},events)
	scene.snapshot = scene.core.snapshot()
	for event: GameEvent in events:
		scene._on_event(event)

func run() -> void:
	Engine.set_meta(Explore.START_META,{"scene":&"hollow_trial_layered"})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	scene.core.set_story_flags([&"received_first_sword",&"debug_all_unlocked"])
	scene.snapshot = scene.core.snapshot()
	scene.fade_phase = &""
	scene._refresh_props()
	scene._update_hud()
	check(scene.prop_placements.size()==32,"32 registered gameplay props")
	check(scene.material != null,"night shader is active in real Explore")
	check(scene.practice_view.audio.ambience_active,"night forest ambience active in trial")
	for i: int in 130:
		if scene.snapshot.hero.position.distance_to(Vector2(256,204))<4:
			break
		var input: InputFrame = InputFrame.new()
		input.move = (Vector2(256,204)-scene.snapshot.hero.position).normalized()
		step(input)
	check(scene.snapshot.interact_target==&"altar","walk from entry reaches real altar interaction")
	await shot("game_idle_altar")
	var press: InputFrame = InputFrame.new()
	press.interact_pressed = true
	step(press)
	check(bool(scene.snapshot.trial.get("sealed",false)),"E starts real sealed trial")
	check(String(scene.prop_placements[2]["type"]).ends_with("barrier_closed"),"real core seal draws closed entry")
	var warned: bool = false
	var combat: bool = false
	var wave2_ticks: int = 0
	for i: int in 3000:
		step()
		if not warned and not scene.trial_fx.warnings.is_empty():
			warned = true
			await shot("game_spawn_warning")
		var wave: int = int(scene.snapshot.trial.get("wave",0))
		if wave==2 and int(scene.snapshot.trial.get("alive",0))>0:
			wave2_ticks += 1
		if wave==2 and wave2_ticks>=60 and not combat:
			combat = true
			await shot("game_wave2_warden_boars")
			await contrast_proof()
		if int(scene.snapshot.trial.get("alive",0))>0 and (wave!=2 or combat):
			finish_live_mobs()
		if scene.snapshot.trial.get("state",&"")==&"won":
			break
	check(warned and combat,"real warned spawn and Warden/Boar wave captured")
	check(seen.has(&"trial_won") and scene.snapshot.story_flags.has(&"cleared_hollow_trial"),"core wins three waves and grants flag")
	check(String(scene.prop_placements[0]["type"]).ends_with("altar_lit"),"real win selects lit altar")
	check(String(scene.prop_placements[2]["type"]).ends_with("barrier_open"),"real win releases seal")
	await shot("game_trial_won")
	# Return to the same altar stand with movement intents, then E opens the on-altar chest.
	for i: int in 130:
		if scene.snapshot.hero.position.distance_to(Vector2(256,204))<4:
			break
		var input: InputFrame = InputFrame.new()
		input.move = (Vector2(256,204)-scene.snapshot.hero.position).normalized()
		step(input)
	step(press)
	check(scene.snapshot.story_flags.has(&"trial_chest_opened"),"same altar E opens actual chest")
	check(String(scene.prop_placements[1]["type"]).ends_with("chest_open"),"real chest flag selects open art")
	await shot("game_chest_open_reward")
	scene.queue_free()
	await process_frame
	if failures==0:
		print("HOLLOW TRIAL GAMEPLAY PRESENTATION OK / core-driven, HP restoration and lethal-hit test assist")
	quit(1 if failures else 0)
