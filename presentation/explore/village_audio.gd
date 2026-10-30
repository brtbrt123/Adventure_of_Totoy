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
	ambience_active = id in [&"woodland_layered", &"forest_layered", &"root_hollow_layered", &"glade_layered"]
	if ambience_active and not ambience.playing and DisplayServer.get_name() != "headless":
		ambience.play()

## Owner-generated woodland recordings; retained originals and gain report in audio/woodland.
var mob_types: Dictionary = {}
const WOODLAND_CUES: Dictionary = {
	"boar_alert": preload("res://presentation/audio/woodland/boar_alert.wav"),
	"boar_charge": preload("res://presentation/audio/woodland/boar_charge.wav"),
	"boar_crash": preload("res://presentation/audio/woodland/boar_crash.wav"),
	"boar_death": preload("res://presentation/audio/woodland/boar_death.wav"),
	"boar_hurt": preload("res://presentation/audio/woodland/boar_hurt.wav"),
	"herb_use": preload("res://presentation/audio/woodland/herb_use.wav"),
	"item_received": preload("res://presentation/audio/woodland/item_received.wav"),
	"level_up": preload("res://presentation/audio/woodland/level_up.wav"),
	"mob_stagger": preload("res://presentation/audio/woodland/mob_stagger.wav"),
	"mossling_alert": preload("res://presentation/audio/woodland/mossling_alert.wav"),
	"mossling_death": preload("res://presentation/audio/woodland/mossling_death.wav"),
	"mossling_hurt": preload("res://presentation/audio/woodland/mossling_hurt.wav"),
	"slot_locked": preload("res://presentation/audio/woodland/slot_locked.wav"),
}
func cue(key: String, tick: int, strength: float = 1.0) -> void:
	if not WOODLAND_CUES.has(key):
		super.cue(key,tick,strength)
		return
	# Pack alerts share one cue; don't multiply loudness for each creature.
	var gap: int = 12 if key.ends_with("alert") or key=="slot_locked" else 1
	if tick-int(last_ticks.get(key,-1000))<gap:return
	last_ticks[key] = tick
	played[key] = int(played.get(key,0))+1
	if DisplayServer.get_name()=="headless" or voices.is_empty():return
	var voice: AudioStreamPlayer = voices[next_voice]
	for candidate: AudioStreamPlayer in voices:
		if not candidate.playing:
			voice = candidate
			break
	next_voice = (next_voice+1)%voices.size()
	voice.stop()
	voice.stream = WOODLAND_CUES[key]
	voice.pitch_scale = 1.0
	voice.volume_db = -13.0+linear_to_db(clampf(strength,0.2,1.0))
	voice.play()
func handle_event(event: GameEvent, scene: StringName = &"arena") -> void:
	super.handle_event(event,scene)
	var mob_type: String = String(event.data.get("type",mob_types.get(int(event.data.get("mob_id",event.data.get("target_id",-1))),"mossling")))
	match event.type:
		&"mob_alerted":cue(mob_type+"_alert",event.tick,0.65)
		&"attack_telegraphed":
			cue("gold_warning" if event.data.get("kind",&"")==&"gold" else "red_warning",event.tick,0.6)
			if mob_type=="boar":cue("boar_charge",event.tick,0.55)
		&"attack_hit":
			cue("counter_hit" if event.data.get("kind",&"")==&"counter" else "armor_hit",event.tick,0.55)
			cue(mob_type+"_hurt",event.tick,0.65)
		&"parry_succeeded":cue("perfect_parry" if event.data.get("quality",&"")==&"perfect" else "deflect",event.tick)
		&"mob_staggered":cue("boar_crash" if event.data.get("reason",&"")==&"crash" else "mob_stagger",event.tick,0.65)
		&"mob_defeated":cue(mob_type+"_death",event.tick,0.7)
		&"encounter_cleared":cue("lesson_complete",event.tick,0.5)
		&"item_used":cue("herb_use",event.tick,0.8)
		&"item_received":cue("item_received",event.tick,0.8)
		&"level_up":cue("level_up",event.tick)
		&"damage_taken", &"hero_defeated":cue("player_hurt",event.tick,0.65)
		&"hero_respawned":cue("aspect_bind",event.tick,0.45)
