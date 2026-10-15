extends RefCounted
## Visual cadence only. State lifetimes and impacts always come from snapshots.
const Snapshots := preload("res://core/snapshots.gd")
const DIRECTIONS: Array[String] = ["down", "up", "right"]
# [frame count, ticks per frame, loop]. Windups use telegraph progress instead.
const PLAYER: Dictionary = {
	"idle": [2, 24, true], "walk": [4, 9, true], "dash": [2, 3, false],
	"parry": [2, 3, false], "parry_recovery": [1, 1, false],
	"attack_windup": [1, 1, false], "attack_active": [1, 1, false],
	"attack_recovery": [1, 1, false], "dead": [1, 1, false],
}
const BOSS: Dictionary = {
	"idle": [2, 32, true], "gold_slam_windup": [2, 1, false],
	"gold_slam_strike": [1, 1, false], "red_sweep_windup": [2, 1, false],
	"red_sweep_strike": [1, 1, false], "red_shards_windup": [2, 1, false],
	"red_shards_strike": [1, 1, false], "recover": [1, 1, false],
	"posture_broken": [2, 12, true], "dead": [1, 1, false],
}
const STRIKE_HOLD_TICKS: int = 4

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
		for tell: Snapshots.TelegraphSnapshot in snap.telegraphs:
			if tell.owner_id != actor.id:
				continue
			var phase: String = "strike" if snap.tick >= tell.hit_tick else "windup"
			state = String(tell.attack) + "_" + phase
			if not BOSS.has(state):
				return String(actor.visual_id) + "_" + state + "_1"
			var index: int = 1
			if phase == "windup":
				var progress: float = clampf(float(snap.tick - tell.start_tick) / maxi(1, tell.hit_tick - tell.start_tick), 0.0, 1.0)
				index = mini(int(BOSS[state][0]) - 1, floori(progress * int(BOSS[state][0]))) + 1
			return "%s_%s_%d" % [actor.visual_id, state, index]
	# Retain only the observed strike pose into the start of recovery. A cancelled
	# attack, break, idle or death never inherits this hold.
	if actor.state == &"recover" and not last_attack.is_empty():
		var end_tick: int = int(last_attack["end_tick"])
		if snap.tick > end_tick and snap.tick <= end_tick + STRIKE_HOLD_TICKS:
			return "%s_%s_strike_1" % [actor.visual_id, last_attack["attack"]]
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
