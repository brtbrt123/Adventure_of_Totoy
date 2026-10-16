extends Node
## Original combat audio. Event results choose the cue; audio never decides hits.
const CUES: Dictionary = {
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
var voices: Array[AudioStreamPlayer] = []
var played: Dictionary = {}
var last_ticks: Dictionary = {}
var next_voice: int = 0

func _ready() -> void:
	for n: int in range(8):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.volume_db = -10.0
		add_child(voice)
		voices.append(voice)

func cue(key: String, tick: int, strength: float = 1.0) -> void:
	if not CUES.has(key):
		return
	# Three shard telegraphs share a tick: one warning, not three stacked sounds.
	if int(last_ticks.get(key, -999)) == tick:
		return
	last_ticks[key] = tick
	played[key] = int(played.get(key, 0)) + 1
	if DisplayServer.get_name() == "headless" or voices.is_empty():
		return
	var voice: AudioStreamPlayer = voices[next_voice]
	for candidate: AudioStreamPlayer in voices:
		if not candidate.playing:
			voice = candidate
			break
	next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	voice.stream = CUES[key]
	voice.volume_db = -10.0 + linear_to_db(clampf(strength, 0.2, 1.0))
	voice.play()

func reset() -> void:
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	last_ticks.clear()
	played.clear()

func _exit_tree() -> void:
	reset()
