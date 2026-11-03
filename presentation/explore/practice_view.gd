extends Node2D
const AnimLib := preload("res://presentation/common/anim_library.gd")  # the owner's effect timing (presentation/animations/effects, docs/ANIMATION_EDITING.md)
## Cosmetic state transitions only. Core events confirm contacts; a whiff still has a swish.
const ExploreCore := preload("res://core/explore_core.gd")
const Snapshots := preload("res://core/snapshots.gd")
const VillageAudio := preload("res://presentation/explore/village_audio.gd")
const SwingArc := preload("res://presentation/common/swing_arc.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
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
	audio.set_scene(id)


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
		elif effect["type"] == &"training_post_hit":
			audio.cue("armor_hit", snapshot.tick, 0.65)
	previous_state = hero.state
	previous_combo = hero.combo_index
	queue_redraw()


## The blades' slash the shared hero_fx layer draws this tick (swing_arc.gd plan), {} for none.
func slash_effect() -> Dictionary:
	if snapshot == null or not snapshot.armed:
		return {}
	var hero: Snapshots.EntitySnapshot = snapshot.hero
	return SwingArc.plan(hero, hero.facing.x < -0.3, ArenaAnimation.choose(hero, Snapshots.GameSnapshot.new(), {}))


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
	# The blades' slash draws once through the shared hero_fx base, at the hero's sorted depth. This node keeps the
	# practice audio and confirmed impact effects; it must not add a separate road-only swing crescent.
	for effect: Dictionary in impacts:
		var age: int = snapshot.tick - int(effect["tick"])
		if age < 0 or age >= 12:
			continue
		if effect["type"] in [&"training_post_hit", &"parry_succeeded"]:
			continue  # the shared hero_fx layer draws these (frame, sparks, ground ring, light): drawing them here doubled them
		var parry: bool = bool(effect.get("counter", false))
		var at: Vector2 = Vector2(effect["at"]) + (Vector2(0, -14) if parry else Vector2.ZERO)
		var burst_fx: String = "fx_parry" if parry else "fx_hit"
		_draw_frame("%s_%d" % [burst_fx, AnimLib.effect_at(burst_fx, age, [6, 2, false])], at)  # one size: never scaled
