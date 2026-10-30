extends RefCounted
## Exploration mode: the hero walking through one scene of the chapter (village_layered, woodland_layered, forest_layered,
## glade_layered; the arena works too, without the boss). No rendering. Presentation calls step() once per 60 Hz tick with an InputFrame,
## then reads snapshot() and last_events. Deterministic: same scene, entry and inputs = same result.
##
## The hero is the arena's Player (core/player.gd) fed only `move` and `dash_pressed`, so walking speed
## (Tuning.PLAYER_SPEED), the dash (DASH_SPEED, DASH_TICKS, DASH_COOLDOWN_TICKS) and facing are exactly the fight's;
## states are idle, walk and dash, plus attack and parry where the scene allows fighting (below); no skills or weapon actives.
## Movement is resolved against
## the scene's solid colliders with the same swept collision as the fight (core/collision.gd) and kept
## `margin` px inside the world.
##
## Each tick, after moving: checkpoints (reaching one that is not the last recorded emits `checkpoint` and records it),
## exits (the hero's body touching an exit rectangle emits `scene_exit` once; the hero then stops: presentation fades
## and builds the target scene's core at `target_entry`; an exit the hero spawned inside is ignored until he has left
## it), the interact target (the nearest NPC or object within INTERACT_RANGE) and, on `interact_pressed` in idle or
## walk, an `interact` event naming it. On an NPC it also starts that NPC's conversation (core/dialogue_book.gd, chosen by the
## story flags): the hero stops, `interact_pressed` shows the next line, `skip_pressed` ends it, and a finished or skipped
## conversation sets its flags (`flag_set`). NPCs turn toward the hero when he is near.
##
## A scene with a training post (a `dummy` object, the village) has a TrainingYard (core/training_yard.gd): once Tovan has been
## heard and the hero stands in the yard he may also attack and parry (`attack_pressed`, `attack_held`, `parry_pressed`, `aim`),
## the post teaches dash, attack, parry and dodge and sets the `lesson_*` flags. Everywhere else those inputs are ignored.
## The hero starts unarmed: Tovan's first conversation hands him the Black Katana (flag `received_first_sword`, event `item_received`),
## and only an armed hero fights in the yard (`ExploreSnapshot.armed`).
##
## A scene with "encounters" (the Woodland Approach) has a MobField (core/mob_field.gd): an armed hero may attack and parry anywhere in it,
## the mobs wake, chase and attack by their own rules, and the hero can fall (`hero_defeated`, then he stands up at the last checkpoint
## HERO_DEFEAT_TICKS later with every uncleared encounter whole again). Clearing an encounter sets the flag `cleared_<id>` and pays its reward
## into `inventory` (`item_received`); `use_herb_pressed` heals. docs/architecture.md "Chapter route, mobs and encounters".
const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
const PlayerState := preload("res://core/player.gd")
const Obstacle := preload("res://core/obstacle.gd")
const Collision := preload("res://core/collision.gd")
const SceneDefs := preload("res://core/scene_defs.gd")
const DialogueBook := preload("res://core/dialogue_book.gd")
const TrainingYard := preload("res://core/training_yard.gd")
const MobField := preload("res://core/mob_field.gd")
const QuestBook := preload("res://core/quest_book.gd")
const Aspects := preload("res://core/aspects.gd")
const ExploreSkills := preload("res://core/explore_skills.gd")

## The story flag that means the hero owns his first sword (Tovan's handover, DialogueBook grants). A save that has met Tovan
## but has no such flag is an older save from before the handover existed: it is treated as armed (set_story_flags).
const ARMED_FLAG: StringName = &"received_first_sword"
## The item that heals (Tuning.HERB_HEAL); mobs drop it.
const HERB_ITEM: StringName = &"herb"
## The item slots of the HUD (keys 1 and 2): the item each holds and the story flag that unlocks it ("" = the sword). Slot 2 is not
## given to the hero yet: no flag sets it, so presentation shows it locked.
const ITEM_SLOTS: Array[Dictionary] = [{"item": &"herb", "unlock": &"unlocked_item_slot_1"}, {"item": &"", "unlock": &"unlocked_item_slot_2"}]
## The Aspect sockets (Z, X, C) follow `ASPECT_UNLOCKS`: socket 1 opens with Edda's equip lesson. Only the Aspects in EXPLORATION_ASPECTS work here.
const ASPECTS_IN_EXPLORATION: bool = true
const ASPECT_UNLOCKS: Array[StringName] = [&"lesson_aspect", &"unlocked_aspect_slot_2", &"unlocked_aspect_slot_3"]
## The Aspects that work in exploration: all of them. Skills hit mobs through MobField.hit_mob() (core/explore_skills.gd).
const EXPLORATION_ASPECTS: Array[StringName] = Aspects.ALL
## An Aspect is owned once Edda or a reward gave it: the story flag aspect_owned_<id>.
const ASPECT_OWNED_PREFIX: String = "aspect_owned_"
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
	## The lantern switches that are lit (a scene with a `puzzle`; empty elsewhere). The pedestal sprites follow this.
	var lit_switches: Array[StringName] = []
	## The story flags set so far (what the save keeps).
	var story_flags: Array[StringName] = []
	## True once he owns his first sword (flag received_first_sword); before that the hero is unarmed and cannot fight.
	var armed: bool = false
	## The running conversation, {} when none: {npc_id, dialogue_id, index (0-based), count, speaker, portrait, text}.
	var dialogue: Dictionary = {}
	## The training post (a scene with a `dummy` object), {} elsewhere: see TrainingYard.view(). `telegraphs` is its current
	## warning in the fight's snapshot type (gold = parry it, red = dodge it); empty when the post rests.
	var training: Dictionary = {}
	var telegraphs: Array[Snapshots.TelegraphSnapshot] = []
	## The scene's mobs and encounters (core/mob_field.gd mob_views / encounter_views); empty in a scene without "encounters". The mobs'
	## warnings are in `telegraphs`.
	var mobs: Array[Dictionary] = []
	var encounters: Array[Dictionary] = []
	## What the hero carries: {item id: count} (herbs from mobs). Presentation saves it (SaveProfile.inventory) on item_received and item_used.
	var inventory: Dictionary = {}
	## Hero level (1..Tuning.LEVEL_MAX), EXP earned inside this level, and what this level needs (0 at the top level), plus the total EXP the
	## save keeps (SaveProfile.exp_total). The hero's max health is `hero.max_hp`. Presentation saves exp_total on exp_gained.
	var level: int = 1
	var exp: int = 0
	var exp_to_next: int = 0
	var exp_total: int = 0
	## The village sequence (core/quest_book.gd): the current step as {id, text, target (an NPC or object id, may be empty), position (where the
	## marker goes, ZERO when unknown)}; {} when every step is done. `unlocked` says which abilities the hero may use now:
	## {attack, dash, parry, item_slot_1, aspect_socket_1}.
	var objective: Dictionary = {}
	var unlocked: Dictionary = {}
	## The HUD's item boxes [{slot (1 or 2), item (id or empty), unlocked, count}] and Aspect sockets [{slot (1-3), aspect (equipped id), unlocked}].
	var item_slots: Array[Dictionary] = []
	var aspect_slots: Array[Dictionary] = []
	## The hero's world objects (same classes as the fight's snapshot): live skill attacks, Spirit Lanterns, Echo Step anchors.
	var skill_attacks: Array[Snapshots.SkillAttackSnapshot] = []
	var lanterns: Array[Snapshots.LanternSnapshot] = []
	var echoes: Array[Snapshots.EchoSnapshot] = []
	## The Aspects he owns (what the menu may equip), the stat points he has spent ({stat: count}), the ones left to spend, and each stat's cap.
	var owned_aspects: Array[StringName] = []
	var stats: Dictionary = {}
	var stat_points_unspent: int = 0
	var stat_caps: Dictionary = {}
	## True from the tick the hero fell until he stands up again at the checkpoint (Tuning.HERO_DEFEAT_TICKS later).
	var defeated: bool = false
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
var lit_switches: Array[StringName] = []  # the lantern switches lit so far (the scene's `puzzle`, if any)
var story_flags: Array[StringName] = []
var book: Dictionary = DialogueBook.default_book()
var player: PlayerState = PlayerState.new()
var obstacles: Array[Obstacle] = []
var last_events: Array[GameEvent] = []
var last_checkpoint: StringName = &""
var exiting: bool = false
var exit_fired: Dictionary = {}  # exit id -> true once fired (never twice per entry)
var pending_exit: Dictionary = {}
var interact_target: Dictionary = {}
var npc_facing_left: Dictionary = {}  # npc id -> bool
var training: TrainingYard = null  # the scene's practice post, if it has one
var skills: ExploreSkills = ExploreSkills.new()
var mobs: MobField = null  # the scene's encounters, if it has any
var quests: Dictionary = QuestBook.default_book()  # the village sequence
var inventory: Dictionary = {}  # item id -> count
var exp_total: int = 0  # all the EXP the hero earned (his level follows)
var stats: Dictionary = {&"vitality": 0, &"might": 0, &"agility": 0}  # stat points spent
var _defeat_ticks: int = 0  # ticks since the hero fell (0 = on his feet)
var _talk: Dictionary = {}  # the running conversation: {npc_id, dialogue_id, index}; {} when none
var _armed: Dictionary = {}  # exit id -> true once the hero has been outside it
var _blocked_told: Dictionary = {}  # exit id -> true while the hero stands in a closed exit (the message is said once per visit)
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
	if gate_open:  # an opened gate was opened by lighting every switch (the save keeps only the gate)
		lit_switches.append_array(_puzzle_switches())
	obstacles = SceneDefs.build_obstacles(scene_id, gate_open, lit_switches)
	entry_id = entry if def["entries"].has(entry) else StringName(def["default_entry"])
	place_at(def["entries"][entry_id])
	for npc: Dictionary in def["npcs"]:
		npc_facing_left[npc["id"]] = bool(npc.get("face_left", false))
	training = TrainingYard.for_scene(def)
	mobs = MobField.for_scene(def)
	_apply_stats()
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


## The debug override and the lantern puzzle: opens or closes the root gate. The hero is pushed out of the gate if he
## stands in it. Emits `gate_changed` with the next step. Closing it again unlights the switches.
func set_gate_open(open: bool) -> void:
	if open == gate_open:
		return
	gate_open = open
	lit_switches.clear()
	if open:  # an open gate means every switch is lit
		lit_switches.append_array(_puzzle_switches())
	obstacles = SceneDefs.build_obstacles(scene_id, gate_open, lit_switches)
	player.position = _clamp(player.position)
	_queued.append(GameEvent.new(GameEvent.GATE_CHANGED, tick, {"scene": scene_id, "gate_open": gate_open}))


## Replaces the story flags (CONTINUE from a save). No events.
func set_story_flags(flags: Array[StringName]) -> void:
	story_flags.clear()
	for flag: StringName in flags:
		if not story_flags.has(flag):
			story_flags.append(flag)
	if story_flags.has(&"met_tovan") and not story_flags.has(ARMED_FLAG):
		story_flags.append(ARMED_FLAG)  # an older save: Tovan was met before the handover existed; do not trap the tutorial
	_migrate_old_flags()
	for flag: StringName in QuestBook.missing_unlocks(quests, story_flags):
		story_flags.append(flag)  # the step he is on has already unlocked what it teaches
	if mobs != null:
		mobs.sync_flags(story_flags)  # a cleared encounter stays cleared


## A save from before the village sequence had these steps: whatever he finished then counts now, so nothing is locked behind a task
## he already did (older lessons unlock their abilities; the Elder's errand and Edda's visit come with her lesson).
func _migrate_old_flags() -> void:
	var add: Array[StringName] = []
	if story_flags.has(&"lesson_parry"):
		add.append_array([&"lesson_attack", &"lesson_dash"])
	if story_flags.has(&"lesson_dodge") or story_flags.has(&"training_done"):
		add.append_array([&"lesson_attack", &"lesson_dash", &"lesson_parry", &"lesson_dodge"])
	for lesson: StringName in [&"attack", &"dash", &"parry"]:
		if story_flags.has(StringName("lesson_" + String(lesson))) or add.has(StringName("lesson_" + String(lesson))):
			add.append(StringName("unlocked_" + String(lesson)))
	if story_flags.has(&"met_edda") or story_flags.has(&"lesson_aspect"):
		add.append_array([&"met_elder", &"basket_found", &"elder_done", &"unlocked_item_slot_1"])
	if story_flags.has(&"lesson_aspect"):
		add.append(&"met_edda")
	for flag: StringName in add:
		if not story_flags.has(flag):
			story_flags.append(flag)


## Replaces the EXP (CONTINUE from a save). No events; the hero starts the scene at full health of his level.
func set_exp(total: int) -> void:
	exp_total = maxi(0, total)
	player.hp = hero_max_hp()


## The hero's level for his EXP (1..Tuning.LEVEL_MAX).
func level() -> int:
	var lv: int = 1
	var left: int = exp_total
	while lv < Tuning.LEVEL_MAX and left >= Tuning.EXP_TO_NEXT[lv - 1]:
		left -= Tuning.EXP_TO_NEXT[lv - 1]
		lv += 1
	return lv


## EXP earned inside the current level.
func exp_in_level() -> int:
	var lv: int = 1
	var left: int = exp_total
	while lv < Tuning.LEVEL_MAX and left >= Tuning.EXP_TO_NEXT[lv - 1]:
		left -= Tuning.EXP_TO_NEXT[lv - 1]
		lv += 1
	return 0 if lv >= Tuning.LEVEL_MAX else left


## What the current level needs to reach the next one (0 at the top level).
func exp_to_next() -> int:
	var lv: int = level()
	return 0 if lv >= Tuning.LEVEL_MAX else Tuning.EXP_TO_NEXT[lv - 1]


func hero_max_hp() -> int:
	return Tuning.PLAYER_MAX_HP + Tuning.LEVEL_HP_BONUS * (level() - 1) + Tuning.VITALITY_HP_PER_POINT * int(stats[&"vitality"])


## The hero's damage multiplier from the Might stat (his blows against mobs).
func damage_mult() -> float:
	return 1.0 + Tuning.MIGHT_DAMAGE_PER_POINT * float(stats[&"might"])


## Stat points: 2 per level above 1; those not spent yet are free to place (the menu sends `spend_stat`).
func stat_points_total() -> int:
	return Tuning.STAT_POINTS_PER_LEVEL * (level() - 1)


func stat_points_spent() -> int:
	var total: int = 0
	for stat: StringName in Tuning.STAT_IDS:
		total += int(stats[stat])
	return total


func stat_points_unspent() -> int:
	return maxi(0, stat_points_total() - stat_points_spent())


## Replaces the spent points (CONTINUE from a save): each stat is kept inside its cap and the total inside the points the level gives.
func set_stats(values: Dictionary) -> void:
	for stat: StringName in Tuning.STAT_IDS:
		stats[stat] = clampi(int(values.get(stat, values.get(String(stat), 0))), 0, int(Tuning.STAT_CAP[stat]))
	var over: int = stat_points_spent() - stat_points_total()
	for stat: StringName in Tuning.STAT_IDS:
		var cut: int = mini(over, int(stats[stat]))
		if cut > 0:
			stats[stat] = int(stats[stat]) - cut
			over -= cut
	_apply_stats()
	player.hp = hero_max_hp()


## The stats the player sees at work: the dash cooldown and the walking speed live in the Player.
func _apply_stats() -> void:
	player.dash_cooldown_bonus = Tuning.AGILITY_DASH_COOLDOWN_TICKS_PER_POINT * mini(int(stats[&"agility"]), Tuning.AGILITY_DASH_POINTS)
	player.stat_speed_mult = 1.0 + Tuning.AGILITY_SPEED_PER_POINT * float(stats[&"agility"])


func _spend_stat(stat: StringName, events: Array[GameEvent]) -> void:
	if not Tuning.STAT_IDS.has(stat) or stat_points_unspent() <= 0 or int(stats[stat]) >= int(Tuning.STAT_CAP[stat]):
		return
	var before: int = hero_max_hp()
	stats[stat] = int(stats[stat]) + 1
	_apply_stats()
	player.hp = mini(hero_max_hp(), player.hp + (hero_max_hp() - before))  # a point of vitality is health right away
	events.append(GameEvent.new(GameEvent.STAT_SPENT, tick, {"scene": scene_id, "stat": stat, "value": int(stats[stat]), "unspent": stat_points_unspent(), "max_hp": hero_max_hp()}))


## Takes every point back: free, and only in Lanternfen (the village).
func _respec(events: Array[GameEvent]) -> void:
	if scene_id != SceneDefs.VILLAGE_LAYERED or stat_points_spent() == 0:
		return
	for stat: StringName in Tuning.STAT_IDS:
		stats[stat] = 0
	_apply_stats()
	player.hp = mini(player.hp, hero_max_hp())
	events.append(GameEvent.new(GameEvent.STATS_RESET, tick, {"scene": scene_id, "unspent": stat_points_unspent()}))


## The weapon and the three Aspects in his slots (CONTINUE: SaveProfile.weapon_id / equipped_aspects). Anything invalid is ignored.
func set_loadout(weapon: StringName, aspects: Array[StringName]) -> void:
	if [Tuning.WEAPON_BLACK_KATANA, Tuning.WEAPON_DUAL_DAGGER, Tuning.WEAPON_CHAIN_SCYTHE].has(weapon):
		player.weapon_id = weapon
	if Aspects.is_valid_loadout(aspects):
		player.equipped_aspects = aspects.duplicate()


## True when he owns `aspect` (the flag aspect_owned_<id>, or a debug flag).
func owns_aspect(aspect: StringName) -> bool:
	return story_flags.has(QuestBook.DEBUG_FLAG) or story_flags.has(StringName(ASPECT_OWNED_PREFIX + String(aspect)))


## The Aspect in socket `slot` (1-3) may be used now: the socket is unlocked, he owns the Aspect and it works in exploration.
func _aspect_usable(slot: int) -> bool:
	if slot < 1 or slot > ASPECT_UNLOCKS.size() or slot > player.equipped_aspects.size():
		return false
	var aspect: StringName = player.equipped_aspects[slot - 1]
	return ASPECTS_IN_EXPLORATION and (story_flags.has(QuestBook.DEBUG_FLAG) or story_flags.has(ASPECT_UNLOCKS[slot - 1])) and EXPLORATION_ASPECTS.has(aspect) and owns_aspect(aspect)


## EXP for the hero: `exp_gained`, and `level_up` (with a full heal) for every level it crosses.
func give_exp(amount: int, source: int, events: Array[GameEvent]) -> void:
	if amount <= 0:
		return
	var before: int = level()
	exp_total += amount
	events.append(GameEvent.new(GameEvent.EXP_GAINED, tick, {"scene": scene_id, "amount": amount, "source": source, "level": level(), "exp": exp_in_level(), "exp_to_next": exp_to_next()}))
	for lv: int in range(before + 1, level() + 1):
		player.hp = hero_max_hp()
		events.append(GameEvent.new(GameEvent.LEVEL_UP, tick, {"scene": scene_id, "level": lv, "max_hp": hero_max_hp(), "points": Tuning.STAT_POINTS_PER_LEVEL}))


## Replaces the inventory (CONTINUE from a save). No events. Unknown or empty counts are dropped.
func set_inventory(items: Dictionary) -> void:
	inventory.clear()
	for key: Variant in items:
		var count: int = clampi(int(items[key]), 0, Tuning.INVENTORY_MAX_STACK)
		if count > 0:
			inventory[StringName(str(key))] = count


## The hero receives `reward` ({reward_id, kind, item, name, quantity}): the inventory grows (capped) and `item_received` follows,
## the same event as a dialogue grant. `source` says where it came from (an encounter id).
func give_item(reward: Dictionary, source: StringName, events: Array[GameEvent]) -> void:
	var item: StringName = StringName(str(reward["item"]))
	var quantity: int = int(reward.get("quantity", 1))
	inventory[item] = mini(Tuning.INVENTORY_MAX_STACK, int(inventory.get(item, 0)) + quantity)
	events.append(GameEvent.new(GameEvent.ITEM_RECEIVED, tick, {
		"scene": scene_id, "reward_id": StringName(str(reward["reward_id"])), "kind": StringName(str(reward.get("kind", "item"))), "item_id": item,
		"name": str(reward["name"]), "quantity": quantity, "source": source,
	}))


## Sets a story flag (a new one emits `flag_set` with the next step). Returns true when it was new.
func set_flag(flag: StringName) -> bool:
	if story_flags.has(flag):
		return false
	story_flags.append(flag)
	_queued.append(GameEvent.new(GameEvent.FLAG_SET, tick, {"flag": flag, "flags": story_flags.duplicate()}))
	var later: Array[GameEvent] = []
	_flag_added(flag, later)
	_queued.append_array(later)
	return true


## Sets a flag now and announces it in `events` (the training yard's lessons). Returns true when it was new.
func _grant_flag(flag: StringName, events: Array[GameEvent]) -> bool:
	if story_flags.has(flag):
		return false
	story_flags.append(flag)
	events.append(GameEvent.new(GameEvent.FLAG_SET, tick, {"flag": flag, "flags": story_flags.duplicate()}))
	_flag_added(flag, events)
	return true


## A new story flag was set (and announced): pay the village step it completes, then unlock what the next step teaches.
func _flag_added(flag: StringName, events: Array[GameEvent]) -> void:
	for step: Dictionary in QuestBook.steps_done_by(quests, flag):
		_pay_step(step, events)
	for unlock: StringName in QuestBook.missing_unlocks(quests, story_flags):
		_grant_flag(unlock, events)


func _pay_step(step: Dictionary, events: Array[GameEvent]) -> void:
	var reward: Dictionary = step.get("reward", {})
	var items: Array[StringName] = []
	events.append(GameEvent.new(GameEvent.QUEST_COMPLETED, tick, {"scene": scene_id, "step_id": StringName(str(step["id"])), "exp": int(reward.get("exp", 0)), "items": items}))
	give_exp(int(reward.get("exp", 0)), 0, events)
	for item: Variant in reward.get("items", []):
		var row: Dictionary = item
		give_item(row, StringName(str(step["id"])), events)
		items.append(StringName(str(row["item"])))
	for flag: Variant in reward.get("flags", []):
		_grant_flag(StringName(str(flag)), events)


## True when the hero may use `ability` (attack, dash, parry): its quest step has begun, or a debug flag lifts every lock.
func is_unlocked(ability: StringName) -> bool:
	return story_flags.has(QuestBook.DEBUG_FLAG) or story_flags.has(StringName(QuestBook.ABILITY_FLAGS.get(ability, &"")))


func is_armed() -> bool:
	return story_flags.has(ARMED_FLAG)


func has_flag(flag: StringName) -> bool:
	return story_flags.has(flag)


func is_talking() -> bool:
	return not _talk.is_empty()


func step(input: InputFrame) -> void:
	tick += 1
	var events: Array[GameEvent] = []
	for queued: GameEvent in _queued:
		queued.tick = tick
		events.append(queued)
	_queued.clear()
	var frame: InputFrame = InputFrame.new()
	var talking: bool = is_talking()
	var fallen: bool = player.state == PlayerState.STATE_DEAD
	if not exiting and not talking and not fallen:
		frame.move = input.move
		frame.dash_pressed = input.dash_pressed and is_unlocked(&"dash")
		if (training != null and training.is_on(story_flags, player.position)) or (mobs != null and is_armed()):
			frame.attack_pressed = input.attack_pressed and is_unlocked(&"attack")
			frame.attack_held = input.attack_held and is_unlocked(&"attack")
			frame.parry_pressed = input.parry_pressed and is_unlocked(&"parry")
			frame.aim = input.aim
			frame.weapon_active_pressed = input.weapon_active_pressed  # the weapon's active (Black Form); the targeted ones refuse (no boss here)
		if _aspect_usable(input.skill_pressed):
			frame.skill_pressed = input.skill_pressed
	var before: Vector2 = player.position
	skills.before_player(self, frame)
	player.step(frame, tick, events)
	player.position = _clamp(Collision.move_resolved(obstacles, before, player.position, Tuning.PLAYER_RADIUS))
	skills.after_move(self, before, events)
	if training != null:
		training.resolve(self, events)
	if mobs != null:
		mobs.resolve(self, events)
	_use_item(input, talking, events)
	if not talking and not exiting and player.state != PlayerState.STATE_DEAD:
		if input.spend_stat != &"":
			_spend_stat(input.spend_stat, events)
		if input.respec_stats:
			_respec(events)
	if (mobs == null or not mobs.is_engaged()) and player.state != PlayerState.STATE_DEAD:
		player.edge = minf(Tuning.EDGE_MAX, player.edge + Tuning.EXPLORE_EDGE_REGEN_PER_TICK)
	_check_defeat(events)
	if not exiting:
		_check_checkpoints(events)
		_check_exits(events)
	_update_npcs()
	interact_target = _find_interact_target()
	if talking:
		_talk_input(input, events)
	elif input.interact_pressed and not exiting and not interact_target.is_empty() and (player.state == PlayerState.STATE_IDLE or player.state == PlayerState.STATE_WALK):
		events.append(GameEvent.new(GameEvent.INTERACT, tick, {"scene": scene_id, "target_id": interact_target["id"], "kind": interact_target["kind"], "position": interact_target["position"]}))
		_use_switch(interact_target["id"], events)
		_open_chest(interact_target["id"], events)
		if interact_target["kind"] == &"npc":
			_start_talk(interact_target["id"], events)
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
	hero.max_hp = hero_max_hp()
	hero.invulnerable = player.is_invulnerable()
	hero.weapon_id = player.weapon_id
	hero.combo_index = player.combo_index
	hero.combo_max = player.combo_max()
	hero.attack_speed_mult = player.swing_speed_mult if String(player.state).begins_with("attack_") else player.attack_speed_mult()
	hero.move_speed_mult = player.move_speed_mult()
	hero.equipped_aspects = player.equipped_aspects.duplicate()
	hero.sprint_ticks_left = player.sprint_ticks_left
	hero.skill_id = player.skill_id
	hero.weapon_buff_active = player.is_buff_active()
	hero.weapon_buff_ticks_left = player.buff_ticks
	hero.weapon_form = player.active_form()
	hero.lightning_blink_index = player.last_blink_direction
	hero.lightning_blink_tick = player.last_blink_tick
	hero.lightning_blink_from = player.last_blink_from
	hero.lightning_blink_to = player.last_blink_to
	hero.lightning_barrage_slash = player.barrage_slash if player.barrage_running else 0
	hero.lightning_barrage_slash_tick = player.barrage_slash_tick if player.barrage_running else -1
	hero.reaper_coil_phase = player.coil_phase if player.coil_running else &""
	hero.reaper_coil_phase_tick = player.coil_phase_tick if player.coil_running else 0
	hero.reaper_coil_from = player.position if player.coil_running else Vector2.ZERO
	hero.reaper_coil_target = player.coil_target if player.coil_running else Vector2.ZERO
	hero.reaper_coil_spin_hit = player.coil_spin_hit if player.coil_running else 0
	hero.phantom_ticks_left = player.phantom_ticks_left
	hero.phantom_pending_echoes = skills.phantom_echoes.size()
	hero.echo_invuln_ticks = player.echo_invuln_ticks()
	hero.ward_ticks_left = player.ward_ticks_left if player.state == PlayerState.STATE_WARD else 0
	hero.ward_stored = player.ward_stored if player.state == PlayerState.STATE_WARD else 0
	snap.hero = hero
	skills.fill_snapshot(self, snap)
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
	snap.lit_switches = lit_switches.duplicate()
	snap.story_flags = story_flags.duplicate()
	snap.armed = is_armed()
	snap.dialogue = _dialogue_view()
	if training != null:
		snap.training = training.view(self)
		snap.telegraphs = training.telegraph_snapshots()
	if mobs != null:
		snap.mobs = mobs.mob_views(tick)
		snap.encounters = mobs.encounter_views()
		snap.telegraphs.append_array(mobs.telegraph_snapshots())
	snap.inventory = inventory.duplicate()
	snap.objective = _objective_view()
	snap.unlocked = {"attack": is_unlocked(&"attack"), "dash": is_unlocked(&"dash"), "parry": is_unlocked(&"parry"),
		"item_slot_1": _slot_unlocked(ITEM_SLOTS[0]), "aspect_socket_1": ASPECTS_IN_EXPLORATION and (story_flags.has(ASPECT_UNLOCKS[0]) or story_flags.has(QuestBook.DEBUG_FLAG))}
	snap.stats = stats.duplicate()
	snap.stat_points_unspent = stat_points_unspent()
	snap.stat_caps = Tuning.STAT_CAP.duplicate()
	for aspect: StringName in Aspects.ALL:
		if owns_aspect(aspect):
			snap.owned_aspects.append(aspect)
	snap.level = level()
	snap.exp = exp_in_level()
	snap.exp_to_next = exp_to_next()
	snap.exp_total = exp_total
	for i: int in ITEM_SLOTS.size():
		var slot: Dictionary = ITEM_SLOTS[i]
		snap.item_slots.append({"slot": i + 1, "item": slot["item"], "unlocked": _slot_unlocked(slot), "count": int(inventory.get(slot["item"], 0)) if slot["item"] != &"" else 0})
	for i: int in ASPECT_UNLOCKS.size():
		snap.aspect_slots.append({"slot": i + 1, "aspect": player.equipped_aspects[i] if i < player.equipped_aspects.size() else &"", "unlocked": ASPECTS_IN_EXPLORATION and (story_flags.has(ASPECT_UNLOCKS[i]) or story_flags.has(QuestBook.DEBUG_FLAG)), "usable": _aspect_usable(i + 1)})
	snap.defeated = player.state == PlayerState.STATE_DEAD
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


func _slot_unlocked(slot: Dictionary) -> bool:
	if slot["item"] == &"":
		return false
	return story_flags.has(QuestBook.DEBUG_FLAG) or story_flags.has(slot["unlock"])


## Item slot 1 (the herb) heals Tuning.HERB_HEAL hp (never above the maximum) and is used up; nothing happens at full health, with none
## left, in a locked slot, while talking, leaving or fallen.
func _use_item(input: InputFrame, talking: bool, events: Array[GameEvent]) -> void:
	var wanted: int = input.use_item_slot if input.use_item_slot != 0 else (1 if input.use_herb_pressed else 0)
	if wanted < 1 or wanted > ITEM_SLOTS.size() or talking or exiting or player.state == PlayerState.STATE_DEAD:
		return
	var slot: Dictionary = ITEM_SLOTS[wanted - 1]
	if slot["item"] != HERB_ITEM or not _slot_unlocked(slot):
		return
	if int(inventory.get(HERB_ITEM, 0)) <= 0 or player.hp >= hero_max_hp():
		return
	var healed: int = mini(Tuning.HERB_HEAL, hero_max_hp() - player.hp)
	player.hp += healed
	inventory[HERB_ITEM] = int(inventory[HERB_ITEM]) - 1
	if int(inventory[HERB_ITEM]) <= 0:
		inventory.erase(HERB_ITEM)
	events.append(GameEvent.new(GameEvent.ITEM_USED, tick, {"scene": scene_id, "item_id": HERB_ITEM, "healed": healed, "hp": player.hp, "count": int(inventory.get(HERB_ITEM, 0))}))


## The hero fell: `hero_defeated` on the first tick, then, Tuning.HERO_DEFEAT_TICKS later, he stands up at the last checkpoint (or the
## entry he came in by) with full health and every uncleared encounter is whole again (`hero_respawned`).
func _check_defeat(events: Array[GameEvent]) -> void:
	if player.state != PlayerState.STATE_DEAD:
		_defeat_ticks = 0
		return
	if _defeat_ticks == 0:
		events.append(GameEvent.new(GameEvent.HERO_DEFEATED, tick, {"scene": scene_id, "position": player.position}))
	_defeat_ticks += 1
	if _defeat_ticks < Tuning.HERO_DEFEAT_TICKS:
		return
	var weapon: StringName = player.weapon_id
	var aspects: Array[StringName] = player.equipped_aspects.duplicate()
	skills.clear()
	player = PlayerState.new()
	player.weapon_id = weapon
	player.equipped_aspects = aspects
	var c: Dictionary = SceneDefs.checkpoint(scene_id, last_checkpoint)
	place_at(c["position"] if not c.is_empty() else def["entries"][entry_id])
	player.hp = hero_max_hp()
	_defeat_ticks = 0
	if mobs != null:
		mobs.reset_all(tick, &"defeat", events)
	events.append(GameEvent.new(GameEvent.HERO_RESPAWNED, tick, {"scene": scene_id, "checkpoint_id": last_checkpoint if not c.is_empty() else &"", "position": player.position}))


## Starts the NPC's conversation for the flags set so far (nothing when it has none).
func _start_talk(npc_id: StringName, events: Array[GameEvent]) -> void:
	var id: StringName = DialogueBook.pick(book, npc_id, story_flags)
	if id == &"" or DialogueBook.dialogue(book, id).is_empty() or DialogueBook.line(DialogueBook.dialogue(book, id), 0).is_empty():
		return
	_talk = {"npc_id": npc_id, "dialogue_id": id, "index": 0}
	events.append(GameEvent.new(GameEvent.DIALOGUE_STARTED, tick, {"scene": scene_id, "npc_id": npc_id, "dialogue_id": id}))


## While talking: skip ends the conversation, interact shows the next line (and ends it after the last).
func _talk_input(input: InputFrame, events: Array[GameEvent]) -> void:
	var def_: Dictionary = DialogueBook.dialogue(book, _talk["dialogue_id"])
	if input.skip_pressed:
		_end_talk(def_, true, events)
	elif input.interact_pressed:
		_talk["index"] = int(_talk["index"]) + 1
		if int(_talk["index"]) >= (def_["lines"] as Array).size():
			_end_talk(def_, false, events)
		else:
			events.append(GameEvent.new(GameEvent.DIALOGUE_ADVANCED, tick, {"scene": scene_id, "npc_id": _talk["npc_id"], "dialogue_id": _talk["dialogue_id"], "index": _talk["index"]}))


func _end_talk(def_: Dictionary, skipped: bool, events: Array[GameEvent]) -> void:
	var finished: Dictionary = _talk
	_talk = {}
	var added: Array[StringName] = []
	for flag: StringName in DialogueBook.flags_set_by(def_):
		if not story_flags.has(flag):
			story_flags.append(flag)
			added.append(flag)
	events.append(GameEvent.new(GameEvent.DIALOGUE_ENDED, tick, {"scene": scene_id, "npc_id": finished["npc_id"], "dialogue_id": finished["dialogue_id"], "skipped": skipped, "flags_set": added}))
	for flag: StringName in added:
		events.append(GameEvent.new(GameEvent.FLAG_SET, tick, {"flag": flag, "flags": story_flags.duplicate()}))
	for flag: StringName in added:
		_flag_added(flag, events)
	for grant: Dictionary in DialogueBook.grants_of(def_):
		var flag: StringName = StringName(grant["flag"])
		if story_flags.has(flag):
			continue  # the grant is the flag: never twice, not after a reload, not when talking again
		story_flags.append(flag)
		events.append(GameEvent.new(GameEvent.FLAG_SET, tick, {"flag": flag, "flags": story_flags.duplicate()}))
		events.append(GameEvent.new(GameEvent.ITEM_RECEIVED, tick, {
			"scene": scene_id, "reward_id": StringName(grant["reward_id"]), "kind": StringName(grant["kind"]), "item_id": StringName(grant["item"]),
			"name": String(grant["name"]), "quantity": int(grant.get("quantity", 1)), "source": finished["npc_id"],
		}))
		_flag_added(flag, events)


## What the dialogue box shows now, {} when nobody is talking.
func _dialogue_view() -> Dictionary:
	if _talk.is_empty():
		return {}
	var def_: Dictionary = DialogueBook.dialogue(book, _talk["dialogue_id"])
	var row: Dictionary = DialogueBook.line(def_, int(_talk["index"]))
	return {"npc_id": _talk["npc_id"], "dialogue_id": _talk["dialogue_id"], "index": int(_talk["index"]), "count": (def_["lines"] as Array).size(), "speaker": row["speaker"], "portrait": row["portrait"], "text": row["text"]}


## The current village step for the HUD ({} when the sequence is finished); the position is where the NPC or object stands in THIS scene.
func _objective_view() -> Dictionary:
	var step: Dictionary = QuestBook.current(quests, story_flags)
	if step.is_empty():
		return {}
	var target: StringName = StringName(str(step.get("target", "")))
	var at: Vector2 = Vector2.ZERO
	for npc: Dictionary in def.get("npcs", []):
		if npc["id"] == target:
			at = npc["position"]
	for object: Dictionary in def.get("objects", []):
		if object["id"] == target:
			at = object["position"]
	return {"id": StringName(str(step["id"])), "text": str(step["objective"]), "target": target, "position": at}


## The Elder's errand: the village chest opens once, only after the Elder asked for his basket.
func _open_chest(target: StringName, events: Array[GameEvent]) -> void:
	if scene_id != SceneDefs.VILLAGE_LAYERED or target != &"chest" or not story_flags.has(&"met_elder"):
		return
	if _grant_flag(&"basket_found", events):
		events.append(GameEvent.new(GameEvent.CHEST_OPENED, tick, {"scene": scene_id, "object_id": target}))


## The switch ids of the scene's lantern puzzle (empty: the scene has none).
func _puzzle_switches() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in def.get("puzzle", {}).get("switches", []):
		out.append(StringName(id))
	return out


## E on a puzzle switch lights it (once); when the last one is lit the gate opens. Other targets do nothing here.
func _use_switch(target: StringName, events: Array[GameEvent]) -> void:
	var switches: Array[StringName] = _puzzle_switches()
	if not switches.has(target) or lit_switches.has(target):
		return
	lit_switches.append(target)
	var all_lit: bool = lit_switches.size() == switches.size()
	events.append(GameEvent.new(GameEvent.SWITCH_LIT, tick, {"scene": scene_id, "switch_id": target, "lit": lit_switches.duplicate(), "all_lit": all_lit}))
	if all_lit:
		set_gate_open(true)  # rebuilds the colliders and queues gate_changed for the next step
	else:
		obstacles = SceneDefs.build_obstacles(scene_id, gate_open, lit_switches)


## True when the hero's body (PLAYER_RADIUS) touches `rect`.
func _touches(rect: Rect2) -> bool:
	var nearest: Vector2 = player.position.clamp(rect.position, rect.end)
	return nearest.distance_to(player.position) <= Tuning.PLAYER_RADIUS


## A point kept inside the scene and out of the solids (the hero's Echo Step arrives here).
func clamp_to_scene(point: Vector2) -> Vector2:
	return _clamp(point)


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
			_blocked_told.erase(exit["id"])
			continue
		if not _armed.get(exit["id"], false) or exit_fired.has(exit["id"]):
			continue
		if exit.get("gate", &"") == &"road" and not (story_flags.has(QuestBook.DEBUG_FLAG) or QuestBook.road_open(quests, story_flags)):
			if not _blocked_told.has(exit["id"]):
				_blocked_told[exit["id"]] = true
				events.append(GameEvent.new(GameEvent.EXIT_BLOCKED, tick, {"scene": scene_id, "exit_id": exit["id"], "text": QuestBook.blocked_text(quests)}))
			continue
		if exit.has("requires_flag") and not (story_flags.has(QuestBook.DEBUG_FLAG) or story_flags.has(exit["requires_flag"])):
			if not _blocked_told.has(exit["id"]):
				_blocked_told[exit["id"]] = true
				events.append(GameEvent.new(GameEvent.EXIT_BLOCKED, tick, {"scene": scene_id, "exit_id": exit["id"], "text": String(exit.get("blocked_text", ""))}))
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
