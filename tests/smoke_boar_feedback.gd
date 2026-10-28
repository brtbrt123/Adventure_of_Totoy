extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
var failures: int = 0
var capture: bool = false
var scene: Explore
var captured: Dictionary = {}
const OUT: String = "res://art/reference/boar_feedback_20261028/"
func _init() -> void:call_deferred("run")
func expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("BOAR FEEDBACK FAIL: ",label)
func snap(label: String) -> void:
	if not capture or captured.has(label):return
	captured[label] = true
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"capture "+label)
func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	if capture:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.remove_meta(Explore.PERSIST_META)
	Engine.set_meta(Explore.START_META,{"scene":Explore.SceneDefs.WOODLAND_LAYERED})
	scene = load("res://presentation/explore/explore_scene.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	await process_frame
	var motion: RefCounted = scene.encounter_effects.boar_motion
	var sample: Dictionary = {}
	for mob: Dictionary in scene.snapshot.mobs:
		if mob["type"]==&"boar":sample=mob.duplicate(true);break
	var view: Explore.ExploreCore.ExploreSnapshot = scene.core.snapshot()
	view.mobs.assign([sample])
	sample["state"] = &"windup"
	sample["state_ticks"] = 20
	motion.sync(view)
	expect(not motion.plans(view).is_empty(),"windup hoof scrape plans")
	sample["state"] = &"strike"
	view.tick += 1
	motion.sync(view)
	expect(motion.bursts.size()==1,"launch puff on actual state transition")
	for i: int in 8:
		view.tick += 1
		sample["position"] += Vector2(sample["facing"])*3.4
		motion.sync(view)
	expect(motion.marks.size()>0,"charge leaves sampled movement trail")
	var mark_count: int = motion.marks.size()
	view.tick += 2
	motion.sync(view)
	expect(motion.marks.size()==mark_count,"stationary strike does not invent movement")
	sample["state"] = &"crash"
	view.tick += 1
	motion.sync(view)
	var impact: bool = false
	for plan: Dictionary in motion.plans(view):impact = impact or plan["family"]=="hit"
	expect(impact,"crash transition adds impact burst")
	view.tick += 30
	sample["state"] = &"idle"
	motion.sync(view)
	expect(motion.plans(view).is_empty(),"trail and impact expire")
	motion.clear()
	expect(motion.previous.is_empty(),"scene reset clears motion history")
	# Real encounter, no forced enemy states, invulnerability or changed attack tuning.
	scene.core.set_flag(&"received_first_sword")
	scene.core.place_at(Vector2(560,276))
	var seen_strike: bool = false
	var seen_windup: bool = false
	for tick: int in 260:
		scene.advance(Explore.InputFrame.new())
		for mob: Dictionary in scene.snapshot.mobs:
			if mob["type"]!=&"boar":continue
			if mob["state"]==&"windup":
				seen_windup = true
				if int(mob["state_ticks"]) in [8,24,40]:await snap("windup_%02d" % mob["state_ticks"])
			if mob["state"]==&"strike":
				seen_strike = true
				if int(mob["state_ticks"]) in [4,8,12,16,20,24,28,32]:await snap("charge_%02d" % mob["state_ticks"])
			if mob["state"]==&"crash" and int(mob["state_ticks"]) in [0,4,8]:await snap("crash_%02d" % mob["state_ticks"])
			if mob["state"]==&"recover" and int(mob["state_ticks"]) in [4,12]:await snap("recover_%02d" % mob["state_ticks"])
	expect(seen_windup and seen_strike,"real Boar telegraph and charge still occur")
	expect(scene.practice_view.audio.played.has("boar_charge"),"real charge retains supplied sound")
	scene.queue_free()
	await process_frame
	print("BOAR FEEDBACK OK" if failures==0 else "BOAR FEEDBACK FAILED")
	quit(0 if failures==0 else 1)
