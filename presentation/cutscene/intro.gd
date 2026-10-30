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
## Where the 320x180 panel sits in the 384x216 view.
const PANEL_ORIGIN: Vector2 = Vector2(32, 18)
var overscan: Texture2D
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)
var _next_requested: bool = false
var _skip_requested: bool = false
var _exit_start_alpha: float = 0.0
var _caption_lines: Array[String] = []
## The layout you set in intro.tscn: the script only grows or shrinks things from it (the card upward, the hint strip from its right edge).
var _card_base: Rect2 = Rect2()
var _caption_margin: Vector2 = Vector2.ZERO
var _plate_right: float = 0.0
var _voice_exit_levels: Array[float] = []
@onready var picture: TextureRect = $Picture
@onready var card: NinePatchRect = $CaptionCard
@onready var caption: Label = $CaptionCard/Caption
@onready var hint_plate: ColorRect = $HintPlate
@onready var hint: Label = $HintPlate/Hint
@onready var flash: ColorRect = $Flash
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	_remember_layout()
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
	_sync()


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
	_sync()


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
	_sync()


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


## The caption card for the lines now shown: the card you placed in intro.tscn, grown upward (its bottom edge stays) when there are
## more lines than its height holds.
func caption_rect() -> Rect2:
	var height: float = maxf(_card_base.size.y, float(_caption_lines.size() * 8 + 10))
	return Rect2(_card_base.position.x, _card_base.end.y - height, _card_base.size.x, height)


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


## The screen is the editable scene intro.tscn (Backdrop, Picture, CaptionCard with its Caption, HintPlate with its Hint, Flash,
## Fade): open it in Godot to move or restyle anything. This script only says what each node shows.
func _draw() -> void:
	pass  # the arena HUD's drawing is not wanted here; everything on this screen is a node


func _remember_layout() -> void:
	_card_base = Rect2(card.position, card.size)
	_caption_margin = card.size - caption.size
	_plate_right = hint_plate.position.x + hint_plate.size.x


func _sync() -> void:
	if picture == null or colors.is_empty():
		return
	var effect: String = str(current_beat().get("effect", "fade_in"))
	# the approved panels are 320x180 pixel art: shown 1:1 in the middle of the 384x216 view, never scaled
	if overscan != null and effect in ["pan_down", "slow_zoom"]:
		var crop: AtlasTexture = AtlasTexture.new()
		crop.atlas = overscan
		crop.region = panel_region()
		picture.texture = crop
	else:
		picture.texture = panel
	var card_rect: Rect2 = caption_rect()
	card.position = card_rect.position
	card.size = card_rect.size
	var shown: PackedStringArray = PackedStringArray()
	var remaining: int = int(reveal)
	for line: String in _caption_lines:
		shown.append(line.substr(0, maxi(0, remaining)))
		remaining -= line.length() + 1
	caption.text = "\n".join(shown)
	caption.size = card_rect.size - _caption_margin
	var hint_text: String = ("%s: %s   %s: Skip" % [Bindings.action_label("dialogue_next"), "Next" if complete() else "Reveal", Bindings.action_label("dialogue_skip")]).to_upper()
	hint.text = hint_text
	var width: float = ceilf(hint.get_theme_font("font").get_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x)
	hint_plate.size.x = width + 3.0
	hint_plate.position.x = _plate_right - hint_plate.size.x
	hint.size.x = width + 1.0
	flash.visible = effect == "flash" and beat_ticks < 6 and fade_phase == &""
	flash.color = Color(colors["p"], (1.0 - float(beat_ticks) / 6.0) * 0.5)
	var alpha: float = fade_alpha()
	fade.visible = alpha > 0.0
	fade.color = Color(colors["0"], alpha)
