extends RefCounted
## Visual cadence only. State lifetimes and impacts always come from snapshots.
const Snapshots := preload("res://core/snapshots.gd")
const DIRECTIONS: Array[String] = ["down", "up", "right"]
# [frame count, ticks per frame, loop]. Windups use telegraph progress instead.
const PLAYER: Dictionary = {
	"idle": [2, 24, true], "walk": [4, 9, true], "dash": [2, 3, false],
	"parry": [3, 4, false], "parry_recovery": [1, 1, false],
	"attack_windup": [2, 4, false], "attack_active": [1, 3, false],
	"attack_recovery": [2, 5, false], "dead": [1, 1, false],
}
const BOSS: Dictionary = {
 "idle": [2, 32, true], "gold_slam_windup": [3, 1, false],
 "gold_slam_strike": [2, 2, false], "red_sweep_windup": [3, 1, false],
 "red_sweep_strike": [4, 1, false], "red_sweep_recover": [1, 1, false],
 "red_shards_windup": [3, 1, false], "red_shards_strike": [2, 3, false],
 "red_stomp_windup": [3, 1, false], "red_stomp_strike": [2, 2, false],
 "gold_combo_windup": [3, 1, false], "gold_combo_strike": [2, 2, false],
 "red_charge_windup": [3, 1, false], "red_charge_strike": [2, 2, true],
 "recover": [1, 1, false], "posture_broken": [2, 12, true], "dead": [1, 1, false],
}
const STRIKE_HOLD_TICKS: int = 4
# Frame pixel anchor: both feet meet the same core ground point in every pose.
const HERO_ANCHOR: Vector2 = Vector2(16, 31)

static func hero_pixel(position: Vector2, facing: Vector2, pixel: Vector2) -> Vector2:
	var local: Vector2 = pixel
	if mirrored(facing):
		local.x = 31.0 - local.x
	return position.round() - HERO_ANCHOR + local

static func direction(facing: Vector2) -> String:
	if absf(facing.x) > absf(facing.y):
		return "right"
	return "down" if facing.y >= 0.0 else "up"

static func mirrored(facing: Vector2) -> bool:
	return absf(facing.x) > absf(facing.y) and facing.x < 0.0

static func frame_index(spec: Array, ticks: int) -> int:
	var count: int = int(spec[0])
	var elapsed: int = floori(float(maxi(0, ticks)) / int(spec[1]))
	return (elapsed % count if bool(spec[2]) else mini(count - 1, elapsed)) + 1

static func choose(actor: Snapshots.EntitySnapshot, snap: Snapshots.GameSnapshot, last_attack: Dictionary) -> String:
	var state: String = String(actor.state)
	if actor.visual_id == &"totoy":
		if not PLAYER.has(state):
			return "totoy_" + state + "_" + direction(actor.facing) + "_1"
		return "totoy_%s_%s_%d" % [state, direction(actor.facing), frame_index(PLAYER[state], actor.state_ticks)]
	if actor.state == &"attack":
		var tell: Snapshots.TelegraphSnapshot = attack_tell(actor.id, snap)
		if tell != null:
			var phase: String = "strike" if snap.tick >= tell.hit_tick else "windup"
			state = String(tell.attack) + "_" + phase
			if not BOSS.has(state):
				return "%s_%s_1" % [actor.visual_id, state]
			var index: int = frame_index(BOSS[state], snap.tick - tell.hit_tick)
			if phase == "windup":
				var start_tick: int = tell.start_tick
				# The second combo lift starts after the observed first strike hold.
				for earlier: Snapshots.TelegraphSnapshot in snap.telegraphs:
					if earlier.owner_id == actor.id and earlier.attack == tell.attack and earlier.hit_tick < tell.hit_tick:
						start_tick = maxi(start_tick, earlier.end_tick + STRIKE_HOLD_TICKS + 1)
				var progress: float = clampf(float(snap.tick - start_tick) / maxi(1, tell.hit_tick - start_tick), 0.0, 1.0)
				index = mini(int(BOSS[state][0]) - 1, floori(progress * int(BOSS[state][0]))) + 1
			return "%s_%s_%d" % [actor.visual_id, state, index]
	if actor.state == &"recover" and not last_attack.is_empty():
		var end_tick: int = int(last_attack["end_tick"])
		var attack: String = String(last_attack["attack"])
		if snap.tick > end_tick and snap.tick <= end_tick + STRIKE_HOLD_TICKS:
			state = attack + "_strike"
			return "%s_%s_%d" % [actor.visual_id, state, frame_index(BOSS[state], snap.tick - int(last_attack["hit_tick"]))]
		if attack == "red_sweep":
			state = "red_sweep_recover"
	if not BOSS.has(state):
		return String(actor.visual_id) + "_" + state + "_1"
	return "%s_%s_%d" % [actor.visual_id, state, frame_index(BOSS[state], actor.state_ticks)]

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for state: String in PLAYER:
		for facing: String in DIRECTIONS:
			for n: int in range(1, int(PLAYER[state][0]) + 1):
				names.append("totoy_%s_%s_%d" % [state, facing, n])
	for state: String in BOSS:
		for n: int in range(1, int(BOSS[state][0]) + 1):
			names.append("mossbound_colossus_%s_%d" % [state, n])
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
