extends SceneTree
const MobView := preload("res://presentation/explore/mob_view.gd")
const FX := preload("res://presentation/explore/warden_effects.gd")
const Glow := preload("res://presentation/explore/creature_glow.gd")
const Explore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const GameEvent := preload("res://core/game_event.gd")
const Audio := preload("res://presentation/explore/village_audio.gd")
const Tuning := preload("res://core/tuning.gd")
var failures: int = 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("WARDEN FAIL: ", label)

func run() -> void:
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/build/sprites.json"))["frames"]
	var view: Explore.ExploreSnapshot = Explore.ExploreSnapshot.new()
	view.scene_id = &"glade_layered"
	var mob: Dictionary = {"id":900,"type":&"warden","state":&"idle","state_ticks":0,"position":Vector2(120,140),"facing":Vector2.RIGHT,"guarded":true,"attack":&"","attack_id":&"warden_lash"}
	view.mobs.append(mob)
	for state: String in MobView.STATES["warden"]:
		for attack: StringName in [&"warden_cleave", &"warden_lash", &"warden_ring"]:
			for age: int in [0,1,4,12,40,89,120]:
				mob["state"] = StringName(state)
				mob["attack"] = attack
				mob["state_ticks"] = age
				var key: String = MobView.frame(mob, [], age)
				check(frames.has(key), "frame exists: " + key)
				check(FX.attachments.has(key), "pose attachment exists: " + key)
	mob["state"] = &"idle"
	mob["state_ticks"] = 0
	check(MobView.frame(mob, [], 0) != MobView.frame(mob, [], 12), "dormant idle uses simulation clock")
	mob["state"] = &"windup"
	mob["attack"] = &"warden_cleave"
	check(MobView.frame(mob, [], 0).contains("cleave_tell"), "current attack overrides queued Lash")
	var tell: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	tell.id = 700
	tell.owner_id = 900
	tell.attack = &"warden_cleave"
	tell.shape = &"cone"
	tell.size = 83.0
	tell.half_angle = 0.72
	tell.direction = Vector2(0.6,0.8)
	tell.center = mob["position"]
	tell.start_tick = 10
	tell.hit_tick = 50
	tell.end_tick = 56
	view.telegraphs.append(tell)
	view.tick = 45
	var fx: FX = FX.new()
	fx.sync(view)
	check(fx.active_tells(view.tick).is_empty(), "no damage flash in windup")
	mob["state"] = &"strike"
	view.tick = 50
	fx.sync(view)
	check(fx.active_tells(50).size() == 1 and fx.tells[900].size == 83.0 and fx.tells[900].direction == tell.direction, "full arbitrary core geometry retained at first active tick")
	check(MobView.frame(mob, view.telegraphs, 55).ends_with("_3"), "all strike poses fit actual active interval")
	var before: String = var_to_str(view.mobs)
	fx.sync(view)
	check(var_to_str(view.mobs) == before, "pause does not mutate snapshot")
	var event: GameEvent = GameEvent.new(&"attack_hit",50,{"target_id":900,"guarded":true})
	fx.handle_event(event,view)
	check(fx.hits.has(900) and MobView.frame(mob,view.telegraphs,50).contains("cleave_strike"), "guard sparks do not replace attacking pose")
	view.tick = 56
	mob["state"] = &"recover"
	fx.sync(view)
	check(fx.active_tells(56).is_empty(), "active flash ends exactly at end_tick")
	mob["state"] = &"stagger"
	mob["guarded"] = false
	view.tick = 57
	fx.sync(view)
	check(fx.tells.is_empty() and MobView.frame(mob,[],57).contains("exposed"), "parry cancels ground effect and darkens pose")
	check(Glow.halo_plan([],57,[],view.mobs).is_empty(), "unguarded rune has no halo")
	mob["state"] = &"dead"
	mob["state_ticks"] = Tuning.MOB_DEATH_TICKS - 1
	check(MobView.frame(mob,[],60).ends_with("_8"), "final death frame reached before removal")
	view.scene_id = &"forest_layered"
	view.tick = 58
	view.mobs.clear()
	fx.sync(view)
	check(fx.hits.is_empty() and fx.breaks.is_empty() and fx.arrivals.is_empty(), "transition clears cosmetics")
	var audio: Audio = Audio.new()
	root.add_child(audio)
	audio.mob_types[900] = "warden"
	check(audio.warden_voices.size() == 2, "separate two-voice foley cap")
	audio.handle_event(event)
	check(audio.played.has("warden_guard_hit") and not audio.played.has("armor_hit"), "guard hit has distinct cue")
	audio.handle_event(GameEvent.new(&"attack_telegraphed",60,{"attack":&"warden_cleave","kind":&"gold","mob_id":900}))
	check(audio.played.has("gold_warning") and audio.played.has("warden_cleave_tell"), "foley retains warning layer")
	mob["state"] = &"strike"
	view.mobs.append(mob)
	audio.sync_wardens(view.mobs,view.telegraphs,50,view.scene_id)
	audio.sync_wardens(view.mobs,view.telegraphs,51,view.scene_id)
	check(int(audio.played.get("warden_cleave_strike",0)) == 1, "strike cue once, including whiff")
	audio.reset()
	mob["state"] = &"stagger"
	audio.sync_wardens(view.mobs,view.telegraphs,50,view.scene_id)
	check(not audio.played.has("warden_cleave_strike"), "parry plays no delayed strike")
	audio.queue_free()
	await process_frame
	if failures == 0:
		print("WARDEN PRESENTATION OK")
	quit(1 if failures else 0)
