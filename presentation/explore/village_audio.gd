extends "res://presentation/arena/combat_audio.gd"
## Recorded combat cues shared with the boss; a quiet original village-only music loop.
const VILLAGE_MUSIC := preload("res://presentation/audio/music/lanternfen_evening.wav")


func _ready() -> void:
	super._ready()
	var loop: AudioStreamWAV = VILLAGE_MUSIC.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop


func _process(delta: float) -> void:
	duck_remaining = maxf(0.0, duck_remaining - delta)
	if music == null:
		return
	var target: float = (-32.0 if duck_remaining > 0 else -26.0) if music_active else -60.0
	music.volume_db = move_toward(music.volume_db, target, delta * 24.0)
	if not music_active and music.volume_db <= -59.0:
		music.stop()
