extends RefCounted
## A trial room (the Hollow Trial, data/scenes/hollow_trial_layered_props.json "trial", docs/PLAN_hollow_trial.md): pressing E at the altar
## starts timed WAVES of mobs that arrive at the room's spawn points (each group warned `warn_ticks` before it appears), the entry is sealed
## until the trial ends, the waves come one after the other, and surviving the last one sets the trial's flag (the altar lights) and lets
## the hero open the chest once for its reward. Falling ends the try: the room resets and the hero can start again.
##
## States: idle (the altar waits) -> starting (`start_ticks`, the room wakes) -> wave -> between (`between_ticks`) -> wave ... -> won.
## The mobs live in the scene's MobField under a MANAGED encounter (core/mob_field.gd: it never clears itself, leashes or remembers kills);
## this object only decides when and where they come. Everything is deterministic: no random numbers.
##
## Events: trial_started, trial_wave_started {wave}, trial_spawn_warned {wave, positions, types, arrive_tick}, trial_wave_cleared {wave},
## trial_won, trial_failed {wave}, plus flag_set (the trial flag, the chest flag), chest_opened and item_received (the reward).
const GameEvent := preload("res://core/game_event.gd")

const IDLE: StringName = &"idle"
const STARTING: StringName = &"starting"
const WAVE: StringName = &"wave"
const BETWEEN: StringName = &"between"
const WON: StringName = &"won"

var cfg: Dictionary = {}
var state: StringName = IDLE
var wave: int = 0
var sealed: bool = false
var _timer: int = 0  # the tick the current starting/between phase ends
var _pending: Array[Dictionary] = []  # groups of this wave not warned yet: {due, mobs}
var _arriving: Array[Dictionary] = []  # warned groups: {arrive, mobs, positions}


## The trial of a scene def (its "trial" block), or null when it has none.
static func for_scene(def: Dictionary) -> RefCounted:
	if not def.has("trial"):
		return null
	var trial: RefCounted = load("res://core/trial.gd").new()
	trial.cfg = def["trial"]
	return trial


func waves() -> int:
	return (cfg["waves"] as Array).size()


func flag() -> StringName:
	return StringName(str(cfg["flag"]))


func chest_flag() -> StringName:
	return StringName(str(cfg["chest_flag"]))


func is_active() -> bool:
	return state == STARTING or state == WAVE or state == BETWEEN


## The story flags were replaced (CONTINUE): a won trial stays won, anything else starts idle.
func sync_flags(flags: Array[StringName]) -> void:
	state = WON if flags.has(flag()) else IDLE
	wave = waves() if state == WON else 0
	sealed = false
	_pending.clear()
	_arriving.clear()


## The tags prop states read ("trial:sealed" closes the entry roots).
func tags() -> Array[StringName]:
	var out: Array[StringName] = []
	if sealed:
		out.append(&"sealed")
	return out


## E on the altar (idle, armed: the trial starts) or on the chest (after a win, once: the reward). Other targets do nothing here.
func use(core: RefCounted, target: StringName, events: Array[GameEvent]) -> void:
	if target == StringName(str(cfg["altar"])) and state == IDLE and core.is_armed():
		state = STARTING
		wave = 0
		_timer = core.tick + int(cfg["start_ticks"])
		_set_sealed(core, true)
		events.append(GameEvent.new(GameEvent.TRIAL_STARTED, core.tick, {"scene": core.scene_id, "waves": waves(), "first_wave_tick": _timer}))
	elif target == StringName(str(cfg["chest"])) and state == WON and core._grant_flag(chest_flag(), events):
		events.append(GameEvent.new(GameEvent.CHEST_OPENED, core.tick, {"scene": core.scene_id, "object_id": target}))
		core.give_item(cfg["reward"], StringName(str(cfg["chest"])), events)


## One tick of the trial, after the mobs moved and fought.
func step(core: RefCounted, events: Array[GameEvent]) -> void:
	match state:
		STARTING, BETWEEN:
			if core.tick >= _timer:
				_begin_wave(core, wave + 1, events)
		WAVE:
			for i: int in range(_pending.size() - 1, -1, -1):
				var group: Dictionary = _pending[i]
				if core.tick >= int(group["due"]):
					_pending.remove_at(i)
					_warn(core, group, events)
			for i: int in range(_arriving.size() - 1, -1, -1):
				var group: Dictionary = _arriving[i]
				if core.tick >= int(group["arrive"]):
					_arriving.remove_at(i)
					var types: Array = group["mobs"]
					var positions: Array = group["positions"]
					for n: int in types.size():
						core.mobs.add_mob(core, _encounter(), StringName(str(types[n])), positions[n], events)
			if _pending.is_empty() and _arriving.is_empty() and core.mobs.alive_in(_encounter()) == 0:
				_wave_cleared(core, events)


## The hero fell and the room was reset (ExploreCore._check_defeat): the try is over, the altar waits again.
func fail(core: RefCounted, events: Array[GameEvent]) -> void:
	if not is_active():
		return
	var lost: int = wave
	state = IDLE
	wave = 0
	_pending.clear()
	_arriving.clear()
	_set_sealed(core, false)
	events.append(GameEvent.new(GameEvent.TRIAL_FAILED, core.tick, {"scene": core.scene_id, "wave": lost}))


## What presentation reads: {state, wave, waves, alive, next_tick, sealed} (next_tick: when the next wave or group comes, -1 = none).
func view(core: RefCounted) -> Dictionary:
	var next: int = -1
	if state == STARTING or state == BETWEEN:
		next = _timer
	elif state == WAVE:
		for group: Dictionary in _arriving:
			next = int(group["arrive"]) if next < 0 else mini(next, int(group["arrive"]))
		for group: Dictionary in _pending:
			next = int(group["due"]) if next < 0 else mini(next, int(group["due"]))
	return {"state": state, "wave": wave, "waves": waves(), "alive": core.mobs.alive_in(_encounter()) if core.mobs != null else 0,
		"next_tick": next, "sealed": sealed}


func _encounter() -> StringName:
	return StringName(str(cfg["encounter"]))


func _set_sealed(core: RefCounted, value: bool) -> void:
	if sealed == value:
		return
	sealed = value
	core.rebuild_obstacles()


func _begin_wave(core: RefCounted, number: int, events: Array[GameEvent]) -> void:
	state = WAVE
	wave = number
	_pending.clear()
	_arriving.clear()
	for row: Variant in (cfg["waves"] as Array)[number - 1]["groups"]:
		var group: Dictionary = row
		_pending.append({"due": core.tick + int(group["after"]), "mobs": group["mobs"]})
	events.append(GameEvent.new(GameEvent.TRIAL_WAVE_STARTED, core.tick, {"scene": core.scene_id, "wave": wave, "waves": waves()}))
	core.mobs.set_max_attackers(_encounter(), int(cfg.get("max_attackers", 2)))


## A group is announced at its spawn points; its mobs appear `warn_ticks` later. The points are the ones farthest from the hero
## (never closer than `spawn_clearance`), in a fixed order, so the same fight always spawns the same way.
func _warn(core: RefCounted, group: Dictionary, events: Array[GameEvent]) -> void:
	var types: Array = group["mobs"]
	var points: Array = cfg["spawn_points"]
	var hero: Vector2 = core.player.position
	var order: Array = []
	for i: int in points.size():
		var p: Vector2 = Vector2(float(points[i][0]), float(points[i][1]))
		order.append({"at": p, "dist": p.distance_to(hero), "index": i})
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["dist"]) - float(b["dist"])) > 0.001:
			return float(a["dist"]) > float(b["dist"])
		return int(a["index"]) < int(b["index"]))
	var usable: Array = order.filter(func(o: Dictionary) -> bool: return float(o["dist"]) >= float(cfg.get("spawn_clearance", 48)))
	if usable.is_empty():
		usable = order
	var positions: Array = []
	for n: int in types.size():
		positions.append(usable[n % usable.size()]["at"])
	var arrive: int = core.tick + int(cfg["warn_ticks"])
	_arriving.append({"arrive": arrive, "mobs": types, "positions": positions})
	events.append(GameEvent.new(GameEvent.TRIAL_SPAWN_WARNED, core.tick, {"scene": core.scene_id, "wave": wave, "positions": positions.duplicate(),
		"types": types.duplicate(), "arrive_tick": arrive}))


func _wave_cleared(core: RefCounted, events: Array[GameEvent]) -> void:
	events.append(GameEvent.new(GameEvent.TRIAL_WAVE_CLEARED, core.tick, {"scene": core.scene_id, "wave": wave, "waves": waves()}))
	if wave >= waves():
		state = WON
		core.mobs.rest(_encounter())
		_set_sealed(core, false)
		core._grant_flag(flag(), events)
		events.append(GameEvent.new(GameEvent.TRIAL_WON, core.tick, {"scene": core.scene_id}))
		return
	state = BETWEEN
	_timer = core.tick + int(cfg["between_ticks"])
