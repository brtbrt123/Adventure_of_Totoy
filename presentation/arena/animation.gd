extends RefCounted
## Visual cadence only. State lifetimes and impacts always come from snapshots.
const Snapshots := preload("res://core/snapshots.gd")
const DIRECTIONS: Array[String] = ["right"]
# [frame count, ticks per frame, loop]. Windups use telegraph progress instead.
const PLAYER: Dictionary = {
	"idle": [4, 12, true], "walk": [6, 5, true], "dash": [4, 1, false],
	"parry": [6, 2, false], "parry_recovery": [1, 1, false],
	"attack_windup": [2, 4, false], "attack_active": [2, 2, false],
	"attack_recovery": [2, 5, false], "dead": [1, 1, false],
	"hurt": [4, 3, false], "victory": [6, 8, false],
}
const BOSS: Dictionary = {
	"idle": [4, 16, true], "walk": [6, 5, true],
	"slam": [6, 3, false], "sweep": [6, 3, false], "stomp": [6, 3, false],
	"charge": [6, 3, false], "beam": [6, 3, false],
	"staggered": [4, 8, true], "hurt": [4, 3, false],
	"roar": [6, 5, false], "death": [8, 6, false],
}
const ATTACKS: Dictionary = {"gold_slam": "slam", "gold_combo": "slam", "red_sweep": "sweep", "red_stomp": "stomp", "red_charge": "charge", "red_shards": "beam"}
const STRIKE_HOLD_TICKS: int = 4
## Destination position stays fixed when Godot flips a negative-width region.
static func destination(at: Vector2, frame: Dictionary, left: bool) -> Rect2:
	var w: float = float(frame["w"])
	var h: float = float(frame["h"])
	var anchor: Vector2 = Vector2(float(frame.get("ax", w * 0.5)), float(frame.get("ay", h - 4)))
	return Rect2(at.round() - Vector2(w - anchor.x if left else anchor.x, anchor.y), Vector2(-w if left else w, h))

static func direction(_facing: Vector2) -> String:
	return "right"

static func mirrored(facing: Vector2) -> bool:
	return facing.x < -0.3

static func frame_index(spec: Array, ticks: int) -> int:
	var count: int = int(spec[0])
	var elapsed: int = floori(float(maxi(0, ticks)) / int(spec[1]))
	return (elapsed % count if bool(spec[2]) else mini(count - 1, elapsed)) + 1

static func choose(actor: Snapshots.EntitySnapshot, snap: Snapshots.GameSnapshot, last_attack: Dictionary) -> String:
	var state: String = String(actor.state)
	if actor.visual_id == &"totoy":
		var ticks: int = actor.state_ticks
		if snap.result == &"victory":
			state = "victory"
			ticks = snap.result_ticks
		if state == "dead":
			return "hero2_hurt_right_4"
		if state.begins_with("attack_"):
			var offset: int = 0 if state == "attack_windup" else (2 if state == "attack_active" else 4)
			return "hero2_attack1_right_%d" % (offset + frame_index(PLAYER[state], ticks))
		if state == "parry_recovery":
			return "hero2_parry_right_6"
		return "hero2_%s_right_%d" % [state, frame_index(PLAYER.get(state, PLAYER["idle"]), ticks)]
	if state == "dead":
		return "golem2_death_%d" % frame_index(BOSS["death"], snap.result_ticks)
	if state == "attack":
		var tell: Snapshots.TelegraphSnapshot = attack_tell(actor.id, snap)
		if tell != null:
			var pose: String = ATTACKS.get(String(tell.attack), "slam")
			var index: int = 4 + mini(2, maxi(0, snap.tick - tell.hit_tick) / 3)
			if snap.tick < tell.hit_tick:
				var start_tick: int = tell.start_tick
				for earlier: Snapshots.TelegraphSnapshot in snap.telegraphs:
					if earlier.owner_id == actor.id and earlier.attack == tell.attack and earlier.hit_tick < tell.hit_tick:
						start_tick = maxi(start_tick, earlier.end_tick + STRIKE_HOLD_TICKS + 1)
				var progress: float = clampf(float(snap.tick - start_tick) / maxi(1, tell.hit_tick - start_tick), 0.0, 1.0)
				index = mini(2, floori(progress * 3)) + 1
			return "golem2_%s_%d" % [pose, index]
	if state == "recover" and not last_attack.is_empty():
		var index: int = 4 + mini(2, maxi(0, snap.tick - int(last_attack["hit_tick"])) / 3)
		return "golem2_%s_%d" % [ATTACKS.get(String(last_attack["attack"]), "slam"), index]
	if state == "posture_broken":
		state = "staggered"
	if state == "recover":
		state = "idle"
	return "golem2_%s_%d" % [state, frame_index(BOSS.get(state, BOSS["idle"]), actor.state_ticks)]

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for state: String in ["idle", "walk", "dash", "parry", "hurt", "victory"]:
		for n: int in range(1, int(PLAYER[state][0]) + 1):
			names.append("hero2_%s_right_%d" % [state, n])
	for n: int in range(1, 7):
		names.append("hero2_attack1_right_%d" % n)
	for state: String in BOSS:
		for n: int in range(1, int(BOSS[state][0]) + 1):
			names.append("golem2_%s_%d" % [state, n])
	return names

## Prefer the most recent impact through its visual hold, then the next warning.
## Sorting by hit time makes the result independent of telegraph array order.
static func attack_tell(owner_id: int, snap: Snapshots.GameSnapshot) -> Snapshots.TelegraphSnapshot:
	var struck: Snapshots.TelegraphSnapshot = null
	var upcoming: Snapshots.TelegraphSnapshot = null
	for tell: Snapshots.TelegraphSnapshot in snap.telegraphs:
		if tell.owner_id != owner_id:
			continue
		if snap.tick >= tell.hit_tick:
			if struck == null or tell.hit_tick > struck.hit_tick:
				struck = tell
		elif upcoming == null or tell.hit_tick < upcoming.hit_tick:
			upcoming = tell
	if struck != null and (upcoming == null or snap.tick <= struck.end_tick + STRIKE_HOLD_TICKS):
		return struck
	return upcoming

static func boss_mirrored(actor: Snapshots.EntitySnapshot, snap: Snapshots.GameSnapshot, history: Dictionary) -> bool:
	var tell: Snapshots.TelegraphSnapshot = attack_tell(actor.id, snap)
	if tell != null and tell.attack in [&"red_charge", &"red_sweep"]:
		return tell.direction.x < 0.0
	return actor.state == &"recover" and history.get("attack", &"") in [&"red_charge", &"red_sweep"] and float(history.get("direction_x", 1.0)) < 0.0
