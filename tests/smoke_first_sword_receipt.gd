extends SceneTree
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const Store := preload("res://core/save_store.gd")
const Profile := preload("res://core/save_profile.gd")
const SAVE: String = "user://smoke_first_sword_receipt.json"
var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func spawn(id: StringName) -> Explore:
	Engine.set_meta(Explore.START_META, {"scene": id})
	var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	if scene.conversation.controls_open:
		scene.dismiss_controls()
	return scene


func talk(scene: Explore, skip: bool) -> void:
	for npc: Dictionary in scene.snapshot.npcs:
		if npc["id"] == &"tovan":
			scene.core.place_at(npc["position"] + Vector2(0, 16))
	scene.advance(Intent.new())
	var press: Intent = Intent.new()
	press.interact_pressed = true
	scene.advance(press)
	expect(not scene.snapshot.dialogue.is_empty(), "Tovan conversation opens")
	if skip:
		var input: Intent = Intent.new()
		input.skip_pressed = true
		scene.advance(input)
	else:
		for i: int in 20:
			if scene.snapshot.dialogue.is_empty():
				break
			scene.conversation.finish_typing()
			scene.advance(press)


func run() -> void:
	var previous: String = OS.get_environment(Store.PATH_ENV)
	OS.set_environment(Store.PATH_ENV, SAVE)
	Engine.set_meta(Explore.PERSIST_META, true)
	for id: StringName in [&"village", &"village_layered"]:
		for skipped: bool in [false, true]:
			Store.delete(SAVE)
			var scene: Explore = spawn(id)
			expect(not scene.snapshot.armed and scene.reward_popup.pending.is_empty(), "fresh village unarmed without a receipt")
			talk(scene, skipped)
			expect(scene.snapshot.armed and Store.load_profile().story_flags.has(&"received_first_sword"), "handover saved")
			expect(scene.reward_popup.pending.size() == 1, "one handover receipt, finished or skipped")
			if not scene.reward_popup.pending.is_empty():
				expect(scene.reward_popup.pending[0]["icon"] == "ui_weapon_totoy_blade_1" and scene.reward_popup.pending[0]["quantity"] == 1, "weapon icon and quantity from event")
			scene.reward_popup.advance(0)
			expect(scene.reward_popup.receipt.get("name", "") == "Black Katana", "receipt displayed")
			scene.reward_popup.advance(4)
			talk(scene, false)
			expect(scene.reward_popup.pending.is_empty(), "second conversation gives no receipt")
			scene.enter_scene(&"forest")
			scene.enter_scene(id)
			expect(scene.reward_popup.pending.is_empty(), "scene change gives no receipt")
			scene.queue_free()
			await process_frame
			var resumed: Explore = spawn(id)
			expect(resumed.snapshot.armed and resumed.reward_popup.pending.is_empty(), "reload armed without another receipt")
			resumed.queue_free()
			await process_frame
		# Legacy save migration arms silently, without replaying the award.
		Store.delete(SAVE)
		var legacy: Profile = Profile.new()
		legacy.story_flags = [&"met_tovan", &"seen_controls"]
		Store.save(legacy)
		var older: Explore = spawn(id)
		expect(older.snapshot.armed and older.reward_popup.pending.is_empty(), "older save migrates silently")
		older.queue_free()
		await process_frame
	Store.delete(SAVE)
	OS.set_environment(Store.PATH_ENV, previous)
	Engine.remove_meta(Explore.PERSIST_META)
	if failures.is_empty():
		print("FIRST SWORD RECEIPT OK")
		quit(0)
	else:
		for label: String in failures:
			printerr("FAIL " + label)
		quit(1)
