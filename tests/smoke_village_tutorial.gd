extends SceneTree
## Real exploration presentation, isolated save, both village variants.
const Explore := preload("res://presentation/explore/explore_scene.gd")
const Intent := preload("res://core/input_frame.gd")
const Store := preload("res://core/save_store.gd")
const Bot := preload("res://tests/explore_bot.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const TelegraphView := preload("res://presentation/arena/telegraph_view.gd")
var failures: Array[String] = []
const SAVE: String = "user://smoke_village_tutorial.json"


func _init() -> void:
	call_deferred("run")


func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func frame(attack: bool = false, parry: bool = false, dash: bool = false) -> Intent:
	var input: Intent = Intent.new()
	input.aim = Vector2.UP
	input.attack_pressed = attack
	input.attack_held = attack
	input.parry_pressed = parry
	input.dash_pressed = dash
	return input


func next_line(scene: Explore) -> void:
	var input: Intent = Intent.new()
	input.interact_pressed = true
	scene.advance(input)


func wait_warning(scene: Explore) -> bool:
	for i: int in 400:
		if not scene.snapshot.telegraphs.is_empty() and scene.snapshot.telegraphs[0].hit_tick>scene.snapshot.tick+6:
			return true
		scene.advance(frame())
	return false


func spawn(id: StringName) -> Explore:
	Engine.set_meta(Explore.START_META, {"scene": id})
	var scene: Explore = (load("res://presentation/explore/explore_scene.tscn") as PackedScene).instantiate() as Explore
	scene.set_physics_process(false)
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.fade_phase = &""
	scene._update_hud()
	return scene


func run() -> void:
	var old_path: String = OS.get_environment(Store.PATH_ENV)
	OS.set_environment(Store.PATH_ENV, SAVE)
	Engine.set_meta(Explore.PERSIST_META, true)
	for id: StringName in [&"village_layered"]:
		Store.delete(SAVE)
		var scene: Explore = spawn(id)
		expect(scene.conversation.controls_open, "%s: first visit controls" % id)
		scene.dismiss_controls()
		expect(Store.load_profile().story_flags.has(&"seen_controls"), "controls remembered on dismissal")
		# Mira: a typing press reveals only; subsequent presses advance every actual line.
		for npc: Dictionary in scene.snapshot.npcs:
			if npc["id"] == &"mira":
				scene.core.place_at(npc["position"] + Vector2(16, 2))
		scene.advance(frame())
		next_line(scene)
		expect(not scene.snapshot.dialogue.is_empty(), "%s: Mira opens" % id)
		var line: int = int(scene.snapshot.dialogue.get("index", -1))
		next_line(scene)
		expect(scene.conversation.complete() and int(scene.snapshot.dialogue.get("index", -2)) == line, "typing press reveals without advancing")
		for i: int in 20:
			if scene.snapshot.dialogue.is_empty():
				break
			expect(scene.conversation.full_text() == scene.snapshot.dialogue["text"], "box text equals core text")
			expect(scene.conversation.wrapped_lines(scene.conversation.full_text()).size() <= 3, "line fits three rows")
			scene.conversation.finish_typing()
			next_line(scene)
		expect(scene.snapshot.dialogue.is_empty() and Store.load_profile().story_flags.has(&"met_mira"), "Mira completion saved")
		next_line(scene)
		var skip: Intent = Intent.new()
		skip.skip_pressed = true
		scene.advance(skip)
		expect(scene.snapshot.dialogue.is_empty(), "skip immediate even during reveal")
		scene.core.set_flag(&"met_tovan")
		scene.core.set_flag(&"received_first_sword")  # the handover: only an armed hero fights in the yard
		scene.advance(frame())
		var stand: Vector2 = Vector2.ZERO
		for object: Dictionary in scene.snapshot.objects:
			if object["kind"] == &"dummy":
				stand = object["stand"]
		var bot: Bot = Bot.new()
		expect(bot.plan(scene.snapshot.size, scene.core.obstacles, scene.snapshot.hero.position, stand), "walkable route to training post")
		for i: int in 2400:
			if scene.snapshot.hero.position.distance_to(stand) < 2:
				break
			scene.advance(bot.next_input(scene.snapshot.hero.position))
		expect(scene.snapshot.hero.position.distance_to(stand) < 4, "walked to post")
		expect(scene.hud.training_hint().contains(Bindings.action_label("arena_attack")),"attack is first lesson")
		for swing: int in 3:
			scene.advance(frame(true))
			expect(scene.snapshot.hero.state == &"attack_windup" and scene.hero_frame.contains("attack"), "attack uses combat animation")
			var impact_seen: bool = false
			var slash_seen: bool = false
			for i: int in 90:
				scene.advance(frame())
				impact_seen = impact_seen or not scene.practice_effects.is_empty()
				slash_seen = slash_seen or not scene.practice_view.slash_effect().is_empty()
				if scene.snapshot.hero.state == &"idle":
					break
			expect(int(scene.snapshot.training["hits"]) == swing + 1, "post counts one hit per swing")
			expect(impact_seen, "post hit reaction recorded")
			expect(slash_seen, "imported slash accompanies the swing")
			expect(scene.frames.has(scene.hero_frame), "combat pose exists")
		expect(scene.hud.training_hint().contains(Bindings.action_label("arena_dash")),"dash prompt uses map after attack")
		var remap: InputEventKey=InputEventKey.new()
		remap.physical_keycode=KEY_V
		InputMap.action_erase_events("arena_dash")
		InputMap.action_add_event("arena_dash",remap)
		expect(scene.hud.training_hint().contains("V"),"dash hint follows remapped input")
		Bindings.register()
		var ring: Dictionary=scene.snapshot.training["ring"]
		scene.core.place_at(ring["center"]+Vector2(-26,0))
		var ring_dash: Intent=frame(false,false,true)
		ring_dash.move=Vector2.RIGHT
		scene.advance(ring_dash)
		for i: int in 40:scene.advance(frame())
		expect(scene.snapshot.story_flags.has(&"lesson_dash"),"dash through actual ring")
		scene.core.place_at(stand)
		scene.advance(frame())
		if wait_warning(scene):
			var tell: RefCounted = scene.snapshot.telegraphs[0]
			expect(tell.kind == &"gold" and TelegraphView.warning_visible(tell, scene.snapshot.tick) and TelegraphView.outline(tell).size() > 3, "gold warning geometry visible")
			for i: int in 120:
				scene.advance(frame(false, scene.snapshot.tick == tell.hit_tick - 5))
				if scene.snapshot.telegraphs.is_empty():
					break
		else:
			expect(false, "gold warning arrives")
		expect(scene.snapshot.story_flags.has(&"lesson_parry"), "parry lesson")
		if wait_warning(scene):
			var tell: RefCounted = scene.snapshot.telegraphs[0]
			expect(tell.kind == &"red" and TelegraphView.warning_visible(tell, scene.snapshot.tick), "red warning visible")
			for i: int in 120:
				var dodge: bool = scene.snapshot.tick == tell.hit_tick - 3
				var input: Intent = frame(false, false, dodge)
				input.move = Vector2.DOWN if dodge else Vector2.ZERO
				scene.advance(input)
				if scene.snapshot.telegraphs.is_empty():
					break
		else:
			expect(false, "red warning arrives")
		for flag: StringName in [&"lesson_dash", &"lesson_attack", &"lesson_parry", &"lesson_dodge", &"training_done"]:
			expect(scene.snapshot.story_flags.has(flag) and Store.load_profile().story_flags.has(flag), "%s saved" % flag)
		expect(scene.toast_message == "TRAINING COMPLETE", "completion confirmation")
		scene.request_aspect_equip(&"not_an_aspect", 1)
		expect(not scene.snapshot.story_flags.has(&"lesson_aspect"), "rejected aspect does not teach lesson")
		scene.core.set_flag(&"aspect_owned_sprint")  # separate equip fixture; full Edda chain has its own smoke
		scene.advance(frame())
		scene.request_aspect_equip(&"sprint", 1)
		expect(Store.load_profile().story_flags.has(&"lesson_aspect"), "aspect equip lesson saved")
		expect(int(scene.practice_view.audio.played.get("swing", 0)) >= 3, "recorded sword swishes")
		expect(int(scene.practice_view.audio.played.get("perfect_parry", 0)) + int(scene.practice_view.audio.played.get("deflect", 0)) >= 1, "recorded parry cue")
		expect(scene.practice_view.audio.music_active and scene.practice_view.audio.music.stream.get_length() > 20.0, "village music loop configured")
		# A confirmed receipt fixture exercises only presentation, not item-grant rules.
		scene.show_reward({"kind": &"weapon", "name": "Black Katana", "icon": "ui_weapon_sword_1", "quantity": 1})
		scene.reward_popup.advance(0.0)
		expect(scene.reward_popup.receipt.get("name", "") == "Black Katana", "weapon receipt popup")
		scene.show_reward({"kind": &"item", "name": "Healing Herb", "quantity": 2})
		scene.reward_popup.blocked = true
		var left: float = scene.reward_popup.seconds_left
		scene.reward_popup.advance(10.0)
		expect(scene.reward_popup.seconds_left == left and not scene.reward_popup.visible, "dialogue pauses reward popup")
		scene.reward_popup.blocked = false
		scene.reward_popup.advance(4.0)
		expect(scene.reward_popup.receipt.get("quantity", 0) == 2, "item receipt queue and quantity")
		scene.enter_scene(id)
		expect(not scene.conversation.controls_open and scene.snapshot.story_flags.has(&"training_done"), "scene entry restores flags")
		scene.queue_free()
		await process_frame
		var resumed: Explore = spawn(id)
		expect(resumed.snapshot.story_flags.has(&"met_mira") and not resumed.conversation.controls_open, "CONTINUE profile flags restored")
		for npc: Dictionary in resumed.snapshot.npcs:
			if npc["id"] == &"mira":
				resumed.core.place_at(npc["position"] + Vector2(16, 2))
		resumed.advance(frame())
		next_line(resumed)
		expect(resumed.snapshot.dialogue.get("dialogue_id", &"") == &"mira_after_edda", "advanced follow-up selected from restored equip-lesson flags")
		resumed.queue_free()
		await process_frame
	# All existing portrait names and every authored line fit the presentation contract.
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/chapter1.json")) as Dictionary
	var view: Explore.ConversationView = Explore.ConversationView.new()
	root.add_child(view)
	for id: String in book["dialogues"]:
		var dialogue: Dictionary = book["dialogues"][id]
		for row: Dictionary in dialogue["lines"]:
			expect(view.wrapped_lines(row["text"]).size() <= 3, "authored line fits: " + id)
			var portrait: String = String(row.get("portrait", dialogue.get("portrait", "")))
			expect(view.portrait_frames.has("portrait_%s_neutral" % portrait), "portrait exists: " + portrait)
	view.queue_free()
	Store.delete(SAVE)
	OS.set_environment(Store.PATH_ENV, old_path)
	Engine.remove_meta(Explore.PERSIST_META)
	if failures.is_empty():
		print("VILLAGE TUTORIAL AND DIALOGUE OK")
		quit(0)
	else:
		for message: String in failures:
			printerr("FAIL " + message)
		quit(1)
