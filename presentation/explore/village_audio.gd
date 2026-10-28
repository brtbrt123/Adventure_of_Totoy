extends "res://presentation/arena/combat_audio.gd"
## Recorded combat cues shared with the boss; a quiet original village-only music loop.
const FOREST_AMBIENCE := preload("res://presentation/audio/owner/night_forest_ambience_loop.wav")
var ambience: AudioStreamPlayer
var ambience_active: bool = false
const VILLAGE_MUSIC := preload("res://presentation/audio/music/lanternfen_evening.wav")


func _ready() -> void:
	super._ready()
	var loop: AudioStreamWAV = VILLAGE_MUSIC.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	ambience = AudioStreamPlayer.new()
	var forest_loop: AudioStreamWAV = FOREST_AMBIENCE.duplicate() as AudioStreamWAV
	forest_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	forest_loop.loop_end = roundi(forest_loop.get_length() * forest_loop.mix_rate)
	ambience.stream = forest_loop
	ambience.volume_db = -60.0
	add_child(ambience)


func _process(delta: float) -> void:
	duck_remaining = maxf(0.0, duck_remaining - delta)
	if ambience != null:
		var ambience_target: float = (-40.0 if duck_remaining > 0 else -34.0) if ambience_active else -60.0
		ambience.volume_db = move_toward(ambience.volume_db, ambience_target, delta * 20.0)
		if not ambience_active and ambience.volume_db <= -59.0:
			ambience.stop()
	if music == null:
		return
	var target: float = (-32.0 if duck_remaining > 0 else -26.0) if music_active else -60.0
	music.volume_db = move_toward(music.volume_db, target, delta * 24.0)
	if not music_active and music.volume_db <= -59.0:
		music.stop()


func set_scene(id: StringName) -> void:
	set_music_active(id in [&"village_layered"])
	ambience_active = id in [&"woodland_layered", &"forest_layered", &"glade_layered"]
	if ambience_active and not ambience.playing and DisplayServer.get_name() != "headless":
		ambience.play()

## Existing recordings reused at restrained levels; owner must judge the live mix.
func handle_event(event: GameEvent, scene: StringName = &"arena") -> void:
	super.handle_event(event, scene)
	match event.type:
		&"encounter_started", &"mob_alerted": cue("dash",event.tick,0.3)
		&"attack_telegraphed": cue("gold_warning" if event.data.get("kind",&"") == &"gold" else "red_warning",event.tick,0.45)
		&"attack_hit": cue("counter_hit" if event.data.get("kind",&"") == &"counter" else "armor_hit",event.tick,0.65)
		&"parry_succeeded": cue("perfect_parry" if event.data.get("quality",&"") == &"perfect" else "deflect",event.tick)
		&"mob_staggered": cue("posture_break",event.tick,0.35)
		&"mob_defeated": cue("golem_sweep",event.tick,0.25)
		&"encounter_cleared": cue("lesson_complete",event.tick,0.55)
		&"item_used": cue("lantern_light",event.tick,0.45)
		&"damage_taken", &"hero_defeated": cue("player_hurt",event.tick,0.65)
		&"hero_respawned": cue("aspect_bind",event.tick,0.45)
