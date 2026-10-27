extends Node2D
## Cosmetic state transitions only. Core events confirm contacts; a whiff still has a swish.
const ExploreCore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const VillageAudio := preload("res://presentation/explore/village_audio.gd")
var audio: VillageAudio
var snapshot: ExploreCore.ExploreSnapshot
var frames: Dictionary = {}
var atlas: Texture2D
var impacts: Array[Dictionary] = []
var previous_state: StringName = &""
var previous_combo: int = -1
var seen_tells: Dictionary = {}


func _ready() -> void:
	audio = VillageAudio.new()
	add_child(audio)
	z_index = 5


func enter_scene(id: StringName) -> void:
	previous_state = &""
	previous_combo = -1
	seen_tells.clear()
	impacts.clear()
	audio.last_ticks.clear()
	audio.set_music_active(id in [&"village", &"village_layered"])


func sync(value: ExploreCore.ExploreSnapshot, events: Array[Dictionary], art_frames: Dictionary, sheet: Texture2D) -> void:
	snapshot = value
	frames = art_frames
	atlas = sheet
	impacts = events
	var hero: Snapshots.EntitySnapshot = snapshot.hero
	if hero.state == &"attack_active" and (previous_state != hero.state or previous_combo != hero.combo_index):
		audio.cue("swing", snapshot.tick, 0.8)
	for tell: Snapshots.TelegraphSnapshot in snapshot.telegraphs:
		if not seen_tells.has(tell.id):
			seen_tells[tell.id] = true
			audio.cue("gold_warning" if tell.kind == &"gold" else "red_warning", snapshot.tick, 0.45)
	for effect: Dictionary in impacts:
		if int(effect["tick"]) != snapshot.tick:
			continue
		if effect["type"] == &"parry_succeeded":
			audio.cue("perfect_parry" if bool(effect["perfect"]) else "deflect", snapshot.tick)
		else:
			audio.cue("armor_hit", snapshot.tick, 0.65)
	previous_state = hero.state
	previous_combo = hero.combo_index
	queue_redraw()


func slash_effect() -> Dictionary:
	if snapshot == null:
		return {}
	var hero: Snapshots.EntitySnapshot = snapshot.hero
	if hero.state != &"attack_active" and not (hero.state == &"attack_recovery" and hero.state_ticks < 6):
		return {}
	var index: int = mini(5, hero.state_ticks / 2) + 1
	if hero.state == &"attack_recovery":
		index = mini(6, 4 + hero.state_ticks / 2)
	return {"key": "fx_slash_small_%d" % index, "at": hero.position + Vector2(-13 if hero.facing.x < -0.3 else 13, -14), "left": hero.facing.x < -0.3}


func _draw_frame(key: String, at: Vector2, left: bool = false, scale_value: float = 1.0) -> void:
	if atlas == null or not frames.has(key):
		return
	var frame: Dictionary = frames[key]
	var size: Vector2 = Vector2(frame["w"], frame["h"]) * scale_value
	var anchor: Vector2 = Vector2(frame["ax"], frame["ay"]) * scale_value
	var origin: Vector2 = at - Vector2(size.x - anchor.x if left else anchor.x, anchor.y)
	draw_texture_rect_region(atlas, Rect2(origin.round(), Vector2(-size.x if left else size.x, size.y)), Rect2(frame["x"], frame["y"], frame["w"], frame["h"]))


func _draw() -> void:
	if snapshot == null:
		return
	var slash: Dictionary = slash_effect()
	if not slash.is_empty():
		_draw_frame(slash["key"], slash["at"], slash["left"], 1.5)
	for effect: Dictionary in impacts:
		var age: int = snapshot.tick - int(effect["tick"])
		if age < 0 or age >= 12:
			continue
		var parry: bool = effect["type"] == &"parry_succeeded"
		var at: Vector2 = Vector2(effect["at"]) + (Vector2(0, -14) if parry else Vector2.ZERO)
		_draw_frame("fx_%s_%d" % ["parry" if parry else "hit", mini(5, age / 2) + 1], at, false, 1.15 if bool(effect["perfect"]) else 1.0)
		if age < 2:
			_draw_frame("fx_flash_1", at, false, 0.55 if parry else 0.4)
