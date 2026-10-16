extends Node
## CC0 recordings: credits and source edits are in presentation/audio/.
## Event results choose the cue; audio never decides hits.
const CUES: Dictionary = {
	"skill_breaking_edge": preload("res://presentation/audio/counter_hit.wav"),
	"skill_gale_cut": preload("res://presentation/audio/dash.wav"),
	"skill_moon_cleave": preload("res://presentation/audio/swing_2.wav"),
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
const MUSIC: AudioStreamOggVorbis = preload("res://presentation/audio/music/heavy_boss_battle_1_bpm200.ogg")
const VARIATIONS: Dictionary = {
	"armor_hit": [preload("res://presentation/audio/armor_hit.wav"), preload("res://presentation/audio/armor_hit_2.wav"), preload("res://presentation/audio/armor_hit_3.wav")],
	"swing": [preload("res://presentation/audio/swing.wav"), preload("res://presentation/audio/swing_2.wav")],
}
var voices: Array[AudioStreamPlayer] = []
var played: Dictionary = {}
var last_ticks: Dictionary = {}
var next_voice: int = 0
var music: AudioStreamPlayer
var music_active: bool = false
var duck_remaining: float = 0.0

func _ready() -> void:
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
	if key in ["perfect_parry", "deflect", "counter_hit", "golem_slam", "golem_stomp"]:
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
	voice.volume_db = -10.0 + linear_to_db(clampf(strength, 0.2, 1.0))
	voice.play()

func reset() -> void:
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
