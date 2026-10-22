extends RefCounted
## Exploration mode: the hero walking through one non-combat scene (chapter 1: village, forest route, Stag glade; the
## arena works too, without the boss). No rendering. Presentation calls step() once per 60 Hz tick with an InputFrame,
## then reads snapshot() and last_events. Deterministic: same scene, entry and inputs = same result.
##
## The hero is the arena's Player (core/player.gd) fed only `move` and `dash_pressed`, so walking speed
## (Tuning.PLAYER_SPEED), the dash (DASH_SPEED, DASH_TICKS, DASH_COOLDOWN_TICKS) and facing are exactly the fight's;
## states are idle, walk and dash only (no attacks, parries or skills in exploration). Movement is resolved against
## the scene's solid colliders with the same swept collision as the fight (core/collision.gd) and kept
## `margin` px inside the world.
##
## Each tick, after moving: checkpoints (reaching one that is not the last recorded emits `checkpoint` and records it),
## exits (the hero's body touching an exit rectangle emits `scene_exit` once; the hero then stops: presentation fades
## and builds the target scene's core at `target_entry`; an exit the hero spawned inside is ignored until he has left
## it), the interact target (the nearest NPC or object within INTERACT_RANGE) and, on `interact_pressed` in idle or
## walk, an `interact` event naming it (no action yet: dialogue is step 2). NPCs turn toward the hero when he is near.
const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
const PlayerState := preload("res://core/player.gd")
const Obstacle := preload("res://core/obstacle.gd")
const Collision := preload("res://core/collision.gd")
const SceneDefs := preload("res://core/scene_defs.gd")

## The hero can interact with an NPC or object when his centre is this close to its feet or its stand point.
const INTERACT_RANGE: float = 24.0
## A checkpoint is reached when the hero's centre is this close to its point.
const CHECKPOINT_RADIUS: float = 12.0
## NPCs within this distance of the hero turn to face him (otherwise they face their default way).
const NPC_FACE_RANGE: float = 56.0


## The read-only view of one exploration tick (a new one per snapshot() call; do not keep core objects).
class ExploreSnapshot:
	extends RefCounted
	var tick: int = 0
	var scene_id: StringName = &""
	var scene_name: String = ""
	var size: Vector2 = Vector2.ZERO
	var hero: Snapshots.EntitySnapshot
	var dash_cooldown_ticks: int = 0
	## [{id, visual, position, facing_left, near}] (near = the hero is within NPC_FACE_RANGE)
	var npcs: Array[Dictionary] = []
	## [{id, kind, position, stand}]
	var objects: Array[Dictionary] = []
	## The NPC or object the interact key would use now (empty: nothing in range), and its kind (&"npc" for people).
	var interact_target: StringName = &""
	var interact_kind: StringName = &""
	var interact_position: Vector2 = Vector2.ZERO
	var gate_open: bool = false
	var last_checkpoint: StringName = &""
	## True from the tick an exit fired: the hero no longer moves; presentation changes scene.
	var exiting: bool = false
	var exit_target_scene: StringName = &""
	var exit_target_entry: StringName = &""
	## For the debug overlay: [{center, radius}], [{id, rect, ...}], [{id, position}], {entry id: Vector2}.
	var obstacles: Array[Dictionary] = []
	var exits: Array = []
	var checkpoints: Array = []
	var entries: Dictionary = {}


var tick: int = 0
var scene_id: StringName = &""
var entry_id: StringName = &""
var def: Dictionary = {}
var size: Vector2 = Vector2.ZERO
var margin: float = Tuning.PLAYER_RADIUS
var gate_open: bool = false
var player: PlayerState = PlayerState.new()
var obstacles: Array[Obstacle] = []
var last_events: Array[GameEvent] = []
var last_checkpoint: StringName = &""
var exiting: bool = false
var exit_fired: Dictionary = {}  # exit id -> true once fired (never twice per entry)
var pending_exit: Dictionary = {}
var interact_target: Dictionary = {}
var npc_facing_left: Dictionary = {}  # npc id -> bool
var _armed: Dictionary = {}  # exit id -> true once the hero has been outside it
var _queued: Array[GameEvent] = []  # events raised between steps (gate changes), emitted with the next step


## `entry` empty = the scene's default entry. An unknown scene gives an empty world (and pushes an error).
func _init(p_scene_id: StringName = SceneDefs.START_SCENE, entry: StringName = &"", p_gate_open: bool = false) -> void:
	scene_id = p_scene_id
	def = SceneDefs.get_def(scene_id)
	if def.is_empty():
		push_error("ExploreCore: unknown scene " + String(scene_id))
		return
	size = def["size"]
	margin = float(def["margin"])
	gate_open = p_gate_open
	obstacles = SceneDefs.build_obstacles(scene_id, gate_open)
	entry_id = entry if def["entries"].has(entry) else StringName(def["default_entry"])
	place_at(def["entries"][entry_id])
	for npc: Dictionary in def["npcs"]:
		npc_facing_left[npc["id"]] = bool(npc.get("face_left", false))
	_update_npcs()
	interact_target = _find_interact_target()


## A core whose hero stands on checkpoint `checkpoint_id` of `p_scene_id` (CONTINUE from a save); the checkpoint
## counts as already recorded. An unknown checkpoint falls back to the default entry.
static func at_checkpoint(p_scene_id: StringName, checkpoint_id: StringName, p_gate_open: bool = false) -> RefCounted:
	var core: RefCounted = load("res://core/explore_core.gd").new(p_scene_id, &"", p_gate_open)
	var c: Dictionary = SceneDefs.checkpoint(p_scene_id, checkpoint_id)
	if not c.is_empty():
		core.place_at(c["position"])
		core.last_checkpoint = checkpoint_id
	return core


## Puts the hero at `point` (kept in the world and out of colliders), idle, facing into the scene. Re-arms exits.
func place_at(point: Vector2) -> void:
	player.position = _clamp(point)
	player.facing = Vector2.LEFT if player.position.x > size.x * 0.5 else Vector2.RIGHT
	_armed.clear()
	for exit: Dictionary in def.get("exits", []):
		_armed[exit["id"]] = not _touches(exit["rect"])


## The debug override (and later the lantern puzzle): opens or closes the forest's root gate. The hero is pushed out
## of the gate if he stands in it. Emits `gate_changed` with the next step.
func set_gate_open(open: bool) -> void:
	if open == gate_open:
		return
	gate_open = open
	obstacles = SceneDefs.build_obstacles(scene_id, gate_open)
	player.position = _clamp(player.position)
	_queued.append(GameEvent.new(GameEvent.GATE_CHANGED, tick, {"scene": scene_id, "gate_open": gate_open}))


func step(input: InputFrame) -> void:
	tick += 1
	var events: Array[GameEvent] = []
	for queued: GameEvent in _queued:
		queued.tick = tick
		events.append(queued)
	_queued.clear()
	var frame: InputFrame = InputFrame.new()
	if not exiting:
		frame.move = input.move
		frame.dash_pressed = input.dash_pressed
	var before: Vector2 = player.position
	player.step(frame, tick, events)
	player.position = _clamp(Collision.move_resolved(obstacles, before, player.position, Tuning.PLAYER_RADIUS))
	if not exiting:
		_check_checkpoints(events)
		_check_exits(events)
	_update_npcs()
	interact_target = _find_interact_target()
	if input.interact_pressed and not exiting and not interact_target.is_empty() and (player.state == PlayerState.STATE_IDLE or player.state == PlayerState.STATE_WALK):
		events.append(GameEvent.new(GameEvent.INTERACT, tick, {"scene": scene_id, "target_id": interact_target["id"], "kind": interact_target["kind"], "position": interact_target["position"]}))
	last_events = events


func snapshot() -> ExploreSnapshot:
	var snap: ExploreSnapshot = ExploreSnapshot.new()
	snap.tick = tick
	snap.scene_id = scene_id
	snap.scene_name = String(def.get("name", ""))
	snap.size = size
	var hero: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	hero.id = player.id
	hero.visual_id = &"totoy"
	hero.state = player.state
	hero.state_ticks = player.state_ticks
	hero.position = player.position
	hero.facing = player.facing
	hero.hp = player.hp
	hero.max_hp = Tuning.PLAYER_MAX_HP
	hero.invulnerable = player.is_invulnerable()
	hero.weapon_id = player.weapon_id
	hero.combo_index = 1
	hero.combo_max = player.combo_max()
	hero.move_speed_mult = player.move_speed_mult()
	hero.equipped_aspects = player.equipped_aspects.duplicate()
	snap.hero = hero
	snap.dash_cooldown_ticks = player.dash_cooldown
	for npc: Dictionary in def.get("npcs", []):
		var at: Vector2 = npc["position"]
		snap.npcs.append({"id": npc["id"], "visual": npc["visual"], "position": at, "facing_left": bool(npc_facing_left.get(npc["id"], false)), "near": at.distance_to(player.position) <= NPC_FACE_RANGE})
	for object: Dictionary in def.get("objects", []):
		snap.objects.append(object.duplicate())
	if not interact_target.is_empty():
		snap.interact_target = interact_target["id"]
		snap.interact_kind = interact_target["kind"]
		snap.interact_position = interact_target["position"]
	snap.gate_open = gate_open
	snap.last_checkpoint = last_checkpoint
	snap.exiting = exiting
	snap.exit_target_scene = pending_exit.get("target_scene", &"")
	snap.exit_target_entry = pending_exit.get("target_entry", &"")
	for o: Obstacle in obstacles:
		snap.obstacles.append({"center": o.center, "radius": o.radius})
	snap.exits = def.get("exits", []).duplicate(true)
	snap.checkpoints = def.get("checkpoints", []).duplicate(true)
	snap.entries = def.get("entries", {}).duplicate()
	return snap


## True when the hero's body (PLAYER_RADIUS) touches `rect`.
func _touches(rect: Rect2) -> bool:
	var nearest: Vector2 = player.position.clamp(rect.position, rect.end)
	return nearest.distance_to(player.position) <= Tuning.PLAYER_RADIUS


func _clamp(point: Vector2) -> Vector2:
	var low: Vector2 = Vector2(margin, margin)
	return Collision.clamp_point(obstacles, point, Tuning.PLAYER_RADIUS, low, size - low)


func _check_checkpoints(events: Array[GameEvent]) -> void:
	for c: Dictionary in def.get("checkpoints", []):
		var at: Vector2 = c["position"]
		if c["id"] != last_checkpoint and at.distance_to(player.position) <= CHECKPOINT_RADIUS:
			last_checkpoint = c["id"]
			events.append(GameEvent.new(GameEvent.CHECKPOINT, tick, {"scene": scene_id, "checkpoint_id": c["id"], "position": at}))


func _check_exits(events: Array[GameEvent]) -> void:
	for exit: Dictionary in def.get("exits", []):
		var touching: bool = _touches(exit["rect"])
		if not touching:
			_armed[exit["id"]] = true
			continue
		if not _armed.get(exit["id"], false) or exit_fired.has(exit["id"]):
			continue
		exit_fired[exit["id"]] = true
		exiting = true
		pending_exit = {"exit_id": exit["id"], "target_scene": exit["target_scene"], "target_entry": exit["target_entry"]}
		events.append(GameEvent.new(GameEvent.SCENE_EXIT, tick, {"scene": scene_id, "exit_id": exit["id"], "target_scene": exit["target_scene"], "target_entry": exit["target_entry"]}))
		return


func _update_npcs() -> void:
	for npc: Dictionary in def.get("npcs", []):
		var at: Vector2 = npc["position"]
		if at.distance_to(player.position) <= NPC_FACE_RANGE:
			if absf(player.position.x - at.x) >= 2.0:
				npc_facing_left[npc["id"]] = player.position.x < at.x
		else:
			npc_facing_left[npc["id"]] = bool(npc.get("face_left", false))


## The nearest NPC or object within INTERACT_RANGE of the hero (its feet or its stand point), as
## {id, kind (npc for people), position}; {} when nothing is in range.
func _find_interact_target() -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INTERACT_RANGE
	for npc: Dictionary in def.get("npcs", []):
		var d: float = (npc["position"] as Vector2).distance_to(player.position)
		if d <= best_d:
			best_d = d
			best = {"id": npc["id"], "kind": &"npc", "position": npc["position"]}
	for object: Dictionary in def.get("objects", []):
		if object["kind"] == &"decor":
			continue
		var d: float = minf((object["position"] as Vector2).distance_to(player.position), (object["stand"] as Vector2).distance_to(player.position))
		if d <= best_d:
			best_d = d
			best = {"id": object["id"], "kind": object["kind"], "position": object["position"]}
	return best
