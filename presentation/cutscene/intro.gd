extends "res://presentation/arena/hud.gd"
## The intro book owns its story and timings; this scene only presents it.
const Book := preload("res://core/cutscene_book.gd")
const Explore := preload("res://presentation/explore/explore_scene.gd")
const SaveStore := preload("res://core/save_store.gd")
const SaveProfile := preload("res://core/save_profile.gd")
const Bindings := preload("res://presentation/arena/input_bindings.gd")
const VillageAudio := preload("res://presentation/explore/village_audio.gd")
const EXPLORE_SCENE: String = "res://presentation/explore/explore_scene.tscn"
const PANEL_DIRECTORY: String = "res://presentation/cutscene/panels/"
const MUSIC_PATH: String = "res://presentation/audio/music/intro_theme.wav"
const FADE_TICKS: int = 12
const EXIT_TICKS: int = 18
const CHARACTERS_PER_SECOND: float = 38.0
const CAPTION_SIZE: int = 8
const CAPTION_WIDTH: float = 290.0
const BEAT_CUES: Dictionary = {
	"night": "lantern_light", "dark": "echo_recall", "heartloom": "echo_recall",
	"road": "aspect_bind", "lantern": "lantern_light", "gate": "root_gate_open",
}

var book: Dictionary = {}
var beats: Array = []
var index: int = 0
var reveal: float = 0.0
var tick: int = 0
var hold_ticks: int = 0
var beat_ticks: int = 0
var fade_phase: StringName = &"in"
var fade_ticks: int = 0
var finished: bool = false
var handed_over: bool = false
var skipped: bool = false
var save_error: int = OK
var save_attempts: int = 0
var audio: VillageAudio
var panel: Texture2D
var overscan: Texture2D
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)
var _next_requested: bool = false
var _skip_requested: bool = false
var _exit_start_alpha: float = 0.0
var _caption_lines: Array[String] = []
var _voice_exit_levels: Array[float] = []


func _ready() -> void:
	Bindings.register()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/palette.json")) as Dictionary
	for entry: Dictionary in palette.get("colors", []):
		colors[entry["symbol"]] = Color.html(entry["hex"])
	if book.is_empty():
		book = Book.default_book()
	beats = Book.beats(book, Book.INTRO)
	audio = VillageAudio.new()
	add_child(audio)
	# The intro controls its own envelope. Neither village nor combat music starts here.
	audio.set_process(false)
	if ResourceLoader.exists(MUSIC_PATH):
		var theme: AudioStreamWAV = load(MUSIC_PATH).duplicate() as AudioStreamWAV
		theme.loop_mode = AudioStreamWAV.LOOP_FORWARD
		theme.loop_begin = 0
		theme.loop_end = roundi(theme.get_length() * theme.mix_rate)
		audio.music.stream = theme
		audio.set_music_active(true)
	if beats.is_empty():
		finish()
	else:
		_enter_beat()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("dialogue_skip") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_skip_requested = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dialogue_next"):
		_next_requested = true
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	advance(_next_requested, _skip_requested)
	_next_requested = false
	_skip_requested = false


func current_beat() -> Dictionary:
	return beats[index] as Dictionary if index >= 0 and index < beats.size() else {}


func full_text() -> String:
	return " ".join(current_beat().get("lines", []))


func complete() -> bool:
	return int(reveal) >= full_text().length()


## One fixed 60 Hz presentation tick, also used directly by headless tests.
func advance(next_pressed: bool = false, skip_pressed: bool = false) -> void:
	if handed_over:
		return
	tick += 1
	if skip_pressed and bool(Book.cutscene(book, Book.INTRO).get("skippable", true)):
		finish(true)
	if finished:
		fade_ticks += 1
		if fade_ticks >= EXIT_TICKS:
			_handover()
	elif fade_phase != &"":
		fade_ticks += 1
		if fade_ticks >= FADE_TICKS:
			if fade_phase == &"out":
				index += 1
				_enter_beat()
			else:
				fade_phase = &""
				fade_ticks = 0
	else:
		beat_ticks += 1
		if next_pressed:
			if complete():
				_next_beat()
			else:
				reveal = full_text().length()
				hold_ticks = 0
		elif not complete():
			reveal = minf(reveal + CHARACTERS_PER_SECOND / 60.0, full_text().length())
		else:
			hold_ticks += 1
			if hold_ticks >= int(current_beat().get("hold", 300)):
				_next_beat()
	_update_audio()
	queue_redraw()


func _next_beat() -> void:
	if index + 1 >= beats.size():
		finish()
	else:
		fade_phase = &"out"
		fade_ticks = 0


func _enter_beat() -> void:
	reveal = 0.0
	hold_ticks = 0
	beat_ticks = 0
	fade_phase = &"in"
	fade_ticks = 0
	var beat: Dictionary = current_beat()
	var path: String = PANEL_DIRECTORY + str(beat.get("art", ""))
	panel = load(path + ".png") as Texture2D if ResourceLoader.exists(path + ".png") else null
	overscan = load(path + "_overscan.png") as Texture2D if ResourceLoader.exists(path + "_overscan.png") else null
	_caption_lines = wrapped_lines(full_text())
	if audio != null:
		var cue: String = str(beat.get("sound", ""))
		if cue.is_empty():
			cue = str(BEAT_CUES.get(str(beat.get("id", "")), ""))
		if not cue.is_empty():
			audio.cue(cue, tick, 0.28)
		audio.ambience_active = str(beat.get("id", "")) in ["weather", "road"]
		if audio.ambience_active and not audio.ambience.playing and DisplayServer.get_name() != "headless":
			audio.ambience.play()
	queue_redraw()


## Save immediately, even when skipping a transition. Repeated calls never save or route twice.
func finish(skip: bool = false) -> void:
	if finished:
		return
	_exit_start_alpha = fade_alpha()
	finished = true
	skipped = skip
	fade_phase = &"exit"
	fade_ticks = 0
	var profile: SaveProfile = SaveStore.load_profile()
	var flag: StringName = Book.flag_of(book, Book.INTRO)
	if flag != &"" and not profile.story_flags.has(flag):
		profile.story_flags.append(flag)
	save_attempts += 1
	save_error = SaveStore.save(profile)
	if save_error != OK:
		push_warning("Intro progress could not be saved: %s" % error_string(save_error))
	if audio != null:
		for voice: AudioStreamPlayer in audio.voices:
			_voice_exit_levels.append(voice.volume_db)
	queue_redraw()


func _handover() -> void:
	if handed_over:
		return
	handed_over = true
	Engine.set_meta(Explore.PERSIST_META, true)
	Engine.set_meta(Explore.START_META, {"scene": &"village_layered", "entry": &"arrival", "checkpoint": &"", "gate_open": false, "intro_arrival": true})
	if audio != null:
		audio.reset()
		audio.ambience.stop()
	change_scene.call(EXPLORE_SCENE)


func fade_alpha() -> float:
	match fade_phase:
		&"in": return clampf(1.0 - float(fade_ticks) / FADE_TICKS, 0.0, 1.0)
		&"out": return clampf(float(fade_ticks) / FADE_TICKS, 0.0, 1.0)
		&"exit": return lerpf(_exit_start_alpha, 1.0, clampf(float(fade_ticks) / EXIT_TICKS, 0.0, 1.0))
	return 0.0


func _update_audio() -> void:
	if audio == null:
		return
	var gain: float = maxf(0.0001, 1.0 - float(fade_ticks) / EXIT_TICKS) if finished else minf(1.0, float(tick) / 60.0)
	audio.music.volume_db = -28.0 + linear_to_db(maxf(gain, 0.0001))
	audio.ambience.volume_db = -36.0 + linear_to_db(maxf(gain, 0.0001))
	if not audio.ambience_active:
		audio.ambience.stop()
	if finished:
		for i: int in _voice_exit_levels.size():
			audio.voices[i].volume_db = _voice_exit_levels[i] + linear_to_db(maxf(gain, 0.0001))


## Stable wrapping before typewriter reveal; no word shifts while a line is being typed.
func wrapped_lines(text: String) -> Array[String]:
	var rows: Array[String] = []
	var row: String = ""
	for word: String in text.split(" ", false):
		var candidate: String = word if row.is_empty() else row + " " + word
		if ui_font().get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE).x > CAPTION_WIDTH and not row.is_empty():
			rows.append(row)
			row = word
		else:
			row = candidate
	if not row.is_empty():
		rows.append(row)
	return rows


func caption_rect() -> Rect2:
	var height: int = maxi(32, _caption_lines.size() * 8 + 10)
	return Rect2(5, 179 - height, 310, height)


## An overscan crop always maps one source pixel to one game pixel. Smooth fractional zoom
## would change the pixel grid, so slow_zoom uses a restrained integer focal drift instead.
func panel_region() -> Rect2:
	if overscan == null:
		return Rect2(0, 0, 320, 180)
	var excess: Vector2i = Vector2i(overscan.get_size()) - Vector2i(320, 180)
	var progress: float = clampf(float(beat_ticks) / (float(full_text().length()) * 60.0 / CHARACTERS_PER_SECOND + int(current_beat().get("hold", 300))), 0.0, 1.0)
	var x: int = int(excess.x / 2)
	var y: int = int(excess.y / 2)
	match str(current_beat().get("effect", "fade_in")):
		"pan_down": y = roundi(progress * excess.y)
		"slow_zoom": x = clampi(x - 2 + roundi(progress * 4.0), 0, excess.x)
	return Rect2(x, y, 320, 180)


func _draw() -> void:
	if colors.is_empty():
		return
	draw_rect(Rect2(0, 0, 320, 180), colors["0"])
	var effect: String = str(current_beat().get("effect", "fade_in"))
	if overscan != null and effect in ["pan_down", "slow_zoom"]:
		draw_texture_rect_region(overscan, Rect2(0, 0, 320, 180), panel_region())
	elif panel != null:
		draw_texture(panel, Vector2.ZERO)
	var card: Rect2 = caption_rect()
	UiPanel.draw_panel(self, card, &"info", colors)
	var remaining: int = int(reveal)
	for i: int in _caption_lines.size():
		var shown: String = _caption_lines[i].substr(0, maxi(0, remaining))
		draw_string(ui_font(), Vector2(14, card.position.y + 11 + i * 8), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_SIZE, colors["1"])
		remaining -= _caption_lines[i].length() + 1
	var hint: String = "%s: %s   %s: Skip" % [Bindings.action_label("dialogue_next"), "Next" if complete() else "Reveal", Bindings.action_label("dialogue_skip")]
	var width: float = text_width(hint, 1, ui_font(), 7)
	draw_rect(Rect2(313 - ceilf(width), 4, ceilf(width) + 3, 10), colors["0"])
	lettering(Vector2(314 - ceilf(width), 6), hint, colors["p"], 1, ui_font(), 7)
	if effect == "flash" and beat_ticks < 6 and fade_phase == &"":
		draw_rect(Rect2(0, 0, 320, 180), Color(colors["p"], (1.0 - float(beat_ticks) / 6.0) * 0.5))
	var alpha: float = fade_alpha()
	if alpha > 0.0:
		draw_rect(Rect2(0, 0, 320, 180), Color(colors["0"], alpha))
