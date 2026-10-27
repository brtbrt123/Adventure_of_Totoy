extends RefCounted
## Tovan's practice post: the village's combat tutorial. A scene with a `dummy` object (the training post) gets one yard.
## Once the hero has heard Tovan (flag `met_tovan`) and stands within YARD_RADIUS of the post, ExploreCore lets him attack
## and parry (the rest of exploration never does), and the post teaches four lessons in order of difficulty:
##   dash   start a dash in the yard
##   attack hit the post HITS_NEEDED times
##   parry  the post winds up a GOLD cone (warning drawn by presentation like the boss's); parry it in the window
##   dodge  the post winds up a RED circle; dash (or leave) so it misses
## Each lesson sets the story flag `lesson_<name>` (ExploreCore emits `flag_set`); when all four are set `training_done` is
## set too (Tovan then says something else). Practice hits cost nothing: the hero has no HP loss here, he only sees
## `training_hero_hit`. No randomness: the post attacks REST_TICKS after the last one, the gold lesson first, then the red.
## The geometry (Telegraph) is the one the fight uses, so the same warning drawing works.

const Tuning := preload("res://core/tuning.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Telegraph := preload("res://core/telegraph.gd")
const Weapons := preload("res://core/weapons.gd")
const PlayerState := preload("res://core/player.gd")

const WAKE_FLAG: StringName = &"met_tovan"
const DONE_FLAG: StringName = &"training_done"
const LESSONS: Array[StringName] = [&"dash", &"attack", &"parry", &"dodge"]
## The hero may fight within this distance of the post's feet.
const YARD_RADIUS: float = 96.0
## The post's body is a circle this big, BODY_LIFT above its feet.
const BODY_RADIUS: float = 9.0
const BODY_LIFT: float = 12.0
const HITS_NEEDED: int = 3
## Ticks between the end of one practice attack and the warning of the next.
const REST_TICKS: int = 90
## Warning length (the telegraph is dangerous after this) and how long it stays dangerous.
const WARN_TICKS: int = 54
const ACTIVE_TICKS: int = 5
const GOLD_SIZE: float = 44.0
const GOLD_HALF_ANGLE: float = 0.9
const RED_SIZE: float = 40.0
const OWNER_ID: int = 100  # the post's id in telegraph snapshots and parry events

var object_id: StringName = &""
var base: Vector2 = Vector2.ZERO  # the post's feet
var hits: int = 0
var telegraph: Telegraph = null
var last_hit_tick: int = -1000
var _rest: int = REST_TICKS
var _dashed: bool = false  # a dash started while the current warning ran
var _next_id: int = 1


## The yard of a scene def (its first `dummy` object), or null when it has none.
static func for_scene(def: Dictionary) -> RefCounted:
	for object: Dictionary in def.get("objects", []):
		if object["kind"] == &"dummy":
			var yard: RefCounted = load("res://core/training_yard.gd").new()
			yard.object_id = object["id"]
			yard.base = object["position"]
			return yard
	return null


func center() -> Vector2:
	return base - Vector2(0, BODY_LIFT)


func lesson_flag(lesson: StringName) -> StringName:
	return StringName("lesson_" + String(lesson))


func is_awake(flags: Array[StringName]) -> bool:
	return flags.has(WAKE_FLAG)


## True when the hero may fight now: Tovan has been heard and he stands in the yard.
func is_on(flags: Array[StringName], hero: Vector2) -> bool:
	return is_awake(flags) and hero.distance_to(base) <= YARD_RADIUS


## The next lesson to show a prompt for (&"" when all are done or the yard is not on).
func hint(flags: Array[StringName], hero: Vector2) -> StringName:
	if not is_on(flags, hero):
		return &""
	for lesson: StringName in LESSONS:
		if not flags.has(lesson_flag(lesson)):
			return lesson
	return &""


func lessons(flags: Array[StringName]) -> Dictionary:
	var out: Dictionary = {}
	for lesson: StringName in LESSONS:
		out[lesson] = flags.has(lesson_flag(lesson))
	return out


## One tick after the hero moved. `core` is the ExploreCore (player, tick, story_flags, _grant_flag()).
func resolve(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var flags: Array[StringName] = core.story_flags
	var on: bool = is_on(flags, player.position)
	if not on:
		telegraph = null
		_rest = REST_TICKS
		return
	for event: GameEvent in events:
		if event.type == GameEvent.DASH_STARTED:
			_dashed = true
			_grant(core, &"dash", events)
	_resolve_swing(core, events)
	if telegraph != null:
		_resolve_telegraph(core, events)
	elif not (flags.has(lesson_flag(&"parry")) and flags.has(lesson_flag(&"dodge"))):
		_rest -= 1
		if _rest <= 0:
			_spawn(core)


func _resolve_swing(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	if player.state != PlayerState.STATE_ATTACK_ACTIVE or player.attack_hit_done:
		return
	var weapon: StringName = player.weapon_id
	var swing: int = player.combo_index - 1
	var to_post: Vector2 = center() - player.position
	var dist: float = to_post.length()
	if dist - BODY_RADIUS > Tuning.ATTACK_RANGE * Weapons.range_mults(weapon)[swing]:
		return
	if dist > 0.0001 and player.facing.dot(to_post / dist) < Weapons.arc_dot(weapon):
		return
	player.attack_hit_done = true
	hits += 1
	last_hit_tick = core.tick
	events.append(GameEvent.new(GameEvent.TRAINING_POST_HIT, core.tick, {"scene": core.scene_id, "object_id": object_id, "hits": hits, "combo_index": player.combo_index, "position": center()}))
	if hits >= HITS_NEEDED:
		_grant(core, &"attack", events)


func _spawn(core: RefCounted) -> void:
	var flags: Array[StringName] = core.story_flags
	var gold: bool = not flags.has(lesson_flag(&"parry"))
	var t: Telegraph = Telegraph.new()
	t.id = _next_id
	_next_id += 1
	t.owner_id = OWNER_ID
	t.attack = &"practice_gold" if gold else &"practice_red"
	t.kind = Telegraph.KIND_GOLD if gold else Telegraph.KIND_RED
	t.shape = Telegraph.SHAPE_CONE if gold else Telegraph.SHAPE_CIRCLE
	t.center = center()
	t.muzzle = center()
	var toward: Vector2 = (core.player as PlayerState).position - center()
	t.direction = toward.normalized() if toward.length_squared() > 0.0001 else Vector2.RIGHT
	t.size = GOLD_SIZE if gold else RED_SIZE
	t.half_angle = GOLD_HALF_ANGLE if gold else 0.0
	t.start_tick = core.tick
	t.hit_tick = core.tick + WARN_TICKS
	t.end_tick = t.hit_tick + ACTIVE_TICKS
	telegraph = t
	_dashed = false


func _resolve_telegraph(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var t: Telegraph = telegraph
	if core.tick >= t.hit_tick and core.tick <= t.end_tick and not t.has_hit and t.overlaps_circle(player.position, Tuning.PLAYER_RADIUS):
		var since: int = player.parry_ticks_since_press()
		if t.kind == Telegraph.KIND_GOLD and since >= 0 and since < Tuning.PARRY_ACTIVE_TICKS:
			t.has_hit = true
			events.append(GameEvent.new(GameEvent.PARRY_SUCCEEDED, core.tick, {
				"player_id": player.id, "attacker_id": OWNER_ID, "telegraph_id": t.id,
				"quality": &"perfect" if since < Tuning.PARRY_PERFECT_TICKS else &"early", "position": player.position,
			}))
			player.on_parry_success(center() - player.position)
			_grant(core, &"parry", events)
		elif not player.is_invulnerable():
			t.has_hit = true
			events.append(GameEvent.new(GameEvent.TRAINING_HERO_HIT, core.tick, {"scene": core.scene_id, "kind": t.kind, "position": player.position}))
	if core.tick > t.end_tick:
		if t.kind == Telegraph.KIND_RED and not t.has_hit and _dashed:
			events.append(GameEvent.new(GameEvent.TRAINING_DODGED, core.tick, {"scene": core.scene_id, "position": player.position}))
			_grant(core, &"dodge", events)
		telegraph = null
		_rest = REST_TICKS


## Sets the lesson's flag (once) and, when it was the last one, `training_done`.
func _grant(core: RefCounted, lesson: StringName, events: Array[GameEvent]) -> void:
	if not core._grant_flag(lesson_flag(lesson), events):
		return
	for other: StringName in LESSONS:
		if not (core.story_flags as Array[StringName]).has(lesson_flag(other)):
			return
	core._grant_flag(DONE_FLAG, events)


## What presentation shows: {object_id, awake, active, hint, lessons {name: bool}, done, hits, hits_needed, center, since_hit}.
func view(core: RefCounted) -> Dictionary:
	var flags: Array[StringName] = core.story_flags
	var hero: Vector2 = (core.player as PlayerState).position
	return {
		"object_id": object_id, "awake": is_awake(flags), "active": is_on(flags, hero), "hint": hint(flags, hero),
		"lessons": lessons(flags), "done": flags.has(DONE_FLAG), "hits": mini(hits, HITS_NEEDED), "hits_needed": HITS_NEEDED,
		"center": center(), "since_hit": core.tick - last_hit_tick,
	}


## The post's current warning as the fight's telegraph snapshot (an empty array when it rests).
func telegraph_snapshots() -> Array[Snapshots.TelegraphSnapshot]:
	var out: Array[Snapshots.TelegraphSnapshot] = []
	if telegraph == null:
		return out
	var s: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
	s.id = telegraph.id
	s.owner_id = telegraph.owner_id
	s.attack = telegraph.attack
	s.kind = telegraph.kind
	s.shape = telegraph.shape
	s.center = telegraph.center
	s.muzzle = telegraph.muzzle
	s.direction = telegraph.direction
	s.size = telegraph.size
	s.half_angle = telegraph.half_angle
	s.start_tick = telegraph.start_tick
	s.hit_tick = telegraph.hit_tick
	s.end_tick = telegraph.end_tick
	out.append(s)
	return out
