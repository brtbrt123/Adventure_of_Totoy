extends Node
## Mixed owner/CC0 sources: provenance and unconfirmed owner licences in presentation/audio/sources.json.
## Event results choose the cue; audio never decides hits.
const GameEvent := preload("res://core/game_event.gd")
const CUES: Dictionary = {
	"electric_shock": preload("res://presentation/audio/owner/electric_shock_short.wav"),
	"lightning_blink": preload("res://presentation/audio/owner/lightning_blink.wav"),
	"lightning_crack": preload("res://presentation/audio/owner/lightning_crack.wav"),
	"sprint": preload("res://presentation/audio/owner/sprint_whoosh.wav"),
	"echo_place": preload("res://presentation/audio/owner/echo_place.wav"),
	"echo_recall": preload("res://presentation/audio/owner/echo_recall.wav"),
	"ward_raise": preload("res://presentation/audio/owner/ward_raise.wav"),
	"ward_release": preload("res://presentation/audio/owner/ward_release.wav"),
	"phantom_cut": preload("res://presentation/audio/owner/phantom_cut.wav"),
	"chain_coil": preload("res://presentation/audio/owner/chain_coil.wav"),
	"aspect_bind": preload("res://presentation/audio/owner/aspect_bind.wav"),
	"root_gate_open": preload("res://presentation/audio/owner/root_gate_open.wav"),
	"lantern_light": preload("res://presentation/audio/owner/lantern_light.wav"),
	"chest_open": preload("res://presentation/audio/owner/chest_open.wav"),
	"lesson_complete": preload("res://presentation/audio/owner/lesson_complete.wav"),
	"try_again": preload("res://presentation/audio/owner/try_again.wav"),
	"dialogue_blip": preload("res://presentation/audio/owner/dialogue_blip.ogg"),

	"weapon_buff_start": preload("res://presentation/audio/candidates/vehicle/seax-unsheathe-02.wav"),
	"weapon_buff_end": preload("res://presentation/audio/candidates/vehicle/tin-whistle-whoosh-02.wav"),
	"release_breaking_edge": preload("res://presentation/audio/candidates/z_metal_clash_candidate.wav"),
	"release_gale_cut": preload("res://presentation/audio/candidates/x_air_cut_candidate.wav"),
	"release_moon_cleave": preload("res://presentation/audio/candidates/c_energy_aura_candidate.wav"),
	"skill_breaking_edge": preload("res://presentation/audio/swing.wav"),
	"skill_gale_cut": preload("res://presentation/audio/dash.wav"),
	"skill_moon_cleave": preload("res://presentation/audio/posture_break.wav"),
	"golem_slam": preload("res://presentation/audio/golem_slam.wav"),
	"golem_stomp": preload("res://presentation/audio/golem_stomp.wav"),
	"golem_sweep": preload("res://presentation/audio/golem_sweep.wav"),
	"golem_charge": preload("res://presentation/audio/golem_charge.wav"),
	"golem_beam": preload("res://presentation/audio/golem_beam.wav"),

	"armor_hit": preload("res://presentation/audio/armor_hit.wav"),
	"counter_hit": preload("res://presentation/audio/counter_hit.wav"),
	"deflect": preload("res://presentation/audio/deflect.wav"),
	"perfect_parry": preload("res://presentation/audio/perfect_parry.wav"),
	"posture_break": preload("res://presentation/audio/posture_break.wav"),
	"player_hurt": preload("res://presentation/audio/player_hurt.wav"),
	"swing": preload("res://presentation/audio/swing.wav"),
	"dash": preload("res://presentation/audio/dash.wav"),
	"gold_warning": preload("res://presentation/audio/gold_warning.wav"),
	"red_warning": preload("res://presentation/audio/red_warning.wav"),
}
const PITCH: Dictionary = {"skill_moon_cleave": 0.7}
const MUSIC: AudioStreamOggVorbis = preload("res://presentation/audio/music/heavy_boss_battle_1_bpm200.ogg")
const VARIATIONS: Dictionary = {
	"armor_hit": [preload("res://presentation/audio/armor_hit.wav"), preload("res://presentation/audio/armor_hit_2.wav"), preload("res://presentation/audio/armor_hit_3.wav")],
	"swing": [preload("res://presentation/audio/swing.wav"), preload("res://presentation/audio/swing_2.wav")],
}
const EVENT_CUES: Dictionary = {
	&"lightning_blink": "lightning_blink", &"lightning_strike": "lightning_crack",
	&"sprint_started": "sprint", &"echo_placed": "echo_place", &"echo_recall": "echo_recall",
	&"ward_raised": "ward_raise", &"ward_released": "ward_release", &"phantom_cut_started": "phantom_cut",
	&"reaper_coil_started": "chain_coil", &"aspect_equipped": "aspect_bind", &"switch_lit": "lantern_light",
	&"training_hero_hit": "try_again",
}
const BARRAGE_HUM := preload("res://presentation/audio/owner/lightning_barrage_hum.wav")
var barrage_hum: AudioStreamPlayer
var hum_active: bool = false
var voices: Array[AudioStreamPlayer] = []
var played: Dictionary = {}
var last_ticks: Dictionary = {}
var next_voice: int = 0
var music: AudioStreamPlayer
var music_active: bool = false
var duck_remaining: float = 0.0

func _ready() -> void:
	barrage_hum = AudioStreamPlayer.new()
	barrage_hum.stream = BARRAGE_HUM
	barrage_hum.volume_db = -25.0
	add_child(barrage_hum)
	music = AudioStreamPlayer.new()
	var loop_stream: AudioStreamOggVorbis = MUSIC.duplicate() as AudioStreamOggVorbis
	loop_stream.loop = true
	music.stream = loop_stream
	music.volume_db = -60.0
	add_child(music)
	for n: int in range(8):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.volume_db = -10.0
		add_child(voice)
		voices.append(voice)

func set_music_active(active: bool) -> void:
	music_active = active
	if active and music != null and not music.playing and DisplayServer.get_name() != "headless":
		music.play()

func _process(delta: float) -> void:
	duck_remaining = maxf(0.0, duck_remaining - delta)
	if music == null:
		return
	var target: float = (-25.0 if duck_remaining > 0.0 else -18.0) if music_active else -60.0
	music.volume_db = move_toward(music.volume_db, target, delta * (110.0 if duck_remaining > 0.0 else 40.0))
	if not music_active and music.volume_db <= -59.0:
		music.stop()

func cue(key: String, tick: int, strength: float = 1.0) -> void:
	if not CUES.has(key):
		return
	# Three shard telegraphs share a tick: one warning, not three stacked sounds.
	if int(last_ticks.get(key, -999)) == tick:
		return
	last_ticks[key] = tick
	played[key] = int(played.get(key, 0)) + 1
	if key in ["perfect_parry", "deflect", "counter_hit", "golem_slam", "golem_stomp", "release_moon_cleave", "release_gale_cut", "release_breaking_edge", "ward_release", "lightning_crack"]:
		duck_remaining = 0.22
	if DisplayServer.get_name() == "headless" or voices.is_empty():
		return
	var voice: AudioStreamPlayer = voices[next_voice]
	for candidate: AudioStreamPlayer in voices:
		if not candidate.playing:
			voice = candidate
			break
	next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	var alternatives: Array = VARIATIONS.get(key, [CUES[key]])
	voice.stream = alternatives[(int(played[key]) - 1) % alternatives.size()]
	voice.pitch_scale = float(PITCH.get(key, 1.0))
	voice.volume_db = -10.0 + linear_to_db(clampf(strength, 0.2, 1.0)) - (2.0 if key == "skill_moon_cleave" else 0.0) + (2.0 if key.begins_with("release_") else 0.0)
	voice.play()

func reset() -> void:
	stop_barrage()
	music_active = false
	duck_remaining = 0.0
	if music != null:
		music.stop()
		music.volume_db = -60.0
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	last_ticks.clear()
	played.clear()

func _exit_tree() -> void:
	reset()
	if music != null:
		music.stream = null


## Confirmed facts only, shared by arena and exploration; no timers invent gameplay events.
func handle_event(event: GameEvent, scene: StringName = &"arena") -> void:
	if EVENT_CUES.has(event.type):
		cue(EVENT_CUES[event.type], event.tick, 0.55 if event.type == &"echo_placed" else 0.8)
	match event.type:
		&"lightning_barrage_started":
			cue("electric_shock", event.tick)
			if not hum_active:
				hum_active = true
				if DisplayServer.get_name() != "headless":
					barrage_hum.play()
		&"lightning_barrage_ended", &"game_result":
			stop_barrage()
		&"gate_changed":
			if bool(event.data.get("gate_open", false)):
				cue("root_gate_open", event.tick, 0.8)
		&"interact":
			if event.data.get("target_id", &"") == &"chest":
				cue("chest_open", event.tick, 0.8)
		&"flag_set":
			var flag: String = String(event.data.get("flag", ""))
			if scene in [&"village_layered"] and (flag.begins_with("lesson_") or flag == "training_done"):
				cue("lesson_complete", event.tick, 0.7)


func stop_barrage() -> void:
	hum_active = false
	if barrage_hum != null:
		barrage_hum.stop()
