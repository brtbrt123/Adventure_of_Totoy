extends SceneTree
const Audio := preload("res://presentation/arena/combat_audio.gd")
const VillageAudio := preload("res://presentation/explore/village_audio.gd")
const Conversation := preload("res://presentation/explore/conversation_view.gd")
const Event := preload("res://core/game_event.gd")
var failures: Array[String] = []
var blips: int = 0


func _init() -> void:
	call_deferred("run")


func expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func run() -> void:
	var fireflies: GDScript = preload("res://presentation/common/ambient_fireflies.gd")
	var original_regions: Dictionary = fireflies._regions.duplicate(true)
	fireflies._regions = {"forest_layered": []}
	expect(fireflies.drawables(&"forest_layered", 0, Vector2(480, 288)).is_empty(), "empty firefly region is safe")
	fireflies._regions = original_regions
	var audio: Audio = Audio.new()
	root.add_child(audio)
	var routes: Dictionary = {&"lightning_blink": "lightning_blink", &"lightning_strike": "lightning_crack", &"sprint_started": "sprint", &"echo_placed": "echo_place", &"echo_recall": "echo_recall", &"ward_raised": "ward_raise", &"ward_released": "ward_release", &"phantom_cut_started": "phantom_cut", &"reaper_coil_started": "chain_coil", &"aspect_equipped": "aspect_bind", &"switch_lit": "lantern_light", &"training_hero_hit": "try_again"}
	for event: StringName in routes:
		audio.handle_event(Event.new(event, 10, {}))
		var key: String = routes[event]
		expect(int(audio.played.get(key, 0)) == 1, "owner cue for " + String(event))
		expect(Audio.CUES[key].resource_path.begins_with("res://presentation/audio/owner/"), "cue uses supplied asset " + key)
	expect(audio.duck_remaining > 0, "major release/strike ducks music")
	audio.handle_event(Event.new(&"gate_changed", 11, {"gate_open": false}))
	expect(not audio.played.has("root_gate_open"), "closing gate silent")
	audio.handle_event(Event.new(&"gate_changed", 12, {"gate_open": true}))
	expect(audio.played.get("root_gate_open", 0) == 1, "opening gate cue")
	audio.handle_event(Event.new(&"interact", 13, {"target_id": &"chest"}))
	expect(audio.played.get("chest_open", 0) == 1, "chest interaction cue")
	audio.handle_event(Event.new(&"flag_set", 14, {"flag": &"lesson_dash"}), &"village_layered")
	audio.handle_event(Event.new(&"flag_set", 14, {"flag": &"training_done"}), &"village_layered")
	expect(audio.played.get("lesson_complete", 0) == 1, "simultaneous lesson flags do not stack")
	audio.handle_event(Event.new(&"lightning_barrage_started", 15, {}))
	expect(audio.hum_active and audio.played.get("electric_shock", 0) == 1, "barrage starts shock and quiet hum")
	expect(Audio.CUES["electric_shock"].get_length() > 1.5 and Audio.CUES["electric_shock"].get_length() <= 2.0, "shock capped below two seconds")
	audio.handle_event(Event.new(&"lightning_barrage_ended", 16, {}))
	expect(not audio.hum_active, "barrage end stops hum")
	audio.handle_event(Event.new(&"lightning_barrage_started", 17, {}))
	audio.reset()
	expect(not audio.hum_active and audio.played.is_empty(), "retry clears audio and hum")
	var village: VillageAudio = VillageAudio.new()
	root.add_child(village)
	for id: StringName in [&"forest_layered", &"glade_layered"]:
		village.set_scene(id)
		expect(village.ambience_active and not village.music_active, "ambience only outside village")
	village.set_scene(&"village_layered")
	expect(village.music_active and not village.ambience_active, "village reverses ambience/music")
	expect(village.ambience.stream.get_length() > 19 and village.ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "crossfaded ambience configured to loop")
	var view: Conversation = Conversation.new()
	root.add_child(view)
	view.blip = func() -> void: blips += 1
	view.sync({"dialogue_id": "blip_test", "index": 0, "text": "a b c d e f"})
	for i: int in 60:
		view.tick()
	expect(blips == 2, "one blip per three non-space characters")
	view.sync({"dialogue_id": "blip_test", "index": 1, "text": "Instant reveal is silent"})
	view.finish_typing()
	view.tick()
	expect(blips == 2, "reveal press does not flood blips")
	view.queue_free()
	audio.queue_free()
	village.queue_free()
	await process_frame
	if failures.is_empty():
		print("OWNER AUDIO OK")
		quit(0)
	else:
		for label: String in failures:
			printerr("FAIL " + label)
		quit(1)
