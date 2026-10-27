extends SceneTree
## Offline asset preparation; never routes the decoded samples to the sound device.
func _init() -> void:
	var source: AudioStreamMP3 = AudioStreamMP3.new()
	source.data = FileAccess.get_file_as_bytes("res://data/audio/owner_sounds/electric_shock.mp3")
	var playback: AudioStreamPlayback = source.instantiate_playback()
	if not playback.has_method("mix_audio"):
		printerr("mix_audio unavailable")
		quit(1)
		return
	var rate: int = int(AudioServer.get_mix_rate())
	playback.start()
	var samples: PackedVector2Array = playback.mix_audio(1.0, roundi(rate * 1.85))
	playback.stop()
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 4)
	for i: int in samples.size():
		var time: float = float(i) / rate
		var gain: float = minf(1.0, time / 0.005) * clampf((1.85 - time) / 0.2, 0.0, 1.0)
		data.encode_s16(i * 4, roundi(clampf(samples[i].x * gain, -1.0, 1.0) * 32767))
		data.encode_s16(i * 4 + 2, roundi(clampf(samples[i].y * gain, -1.0, 1.0) * 32767))
	var output: AudioStreamWAV = AudioStreamWAV.new()
	output.format = AudioStreamWAV.FORMAT_16_BITS
	output.stereo = true
	output.mix_rate = rate
	output.data = data
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://presentation/audio/owner"))
	var result: Error = output.save_to_wav("res://presentation/audio/owner/electric_shock_short.wav")
	print("Shock decoded without playback: %d frames at %d Hz, %.3fs, error %d" % [samples.size(), rate, output.get_length(), result])
	quit(0 if result == OK and output.get_length() <= 1.86 else 1)
