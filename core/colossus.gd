extends "res://core/mob.gd"
## The Mossbound Colossus on the road: chapter 1's final boss in Rootcrown (docs/PLAN_colossus_step3.md, parts 3a to 3c).
## core/mob_field.gd owns it like any mob (id, place, health, state, warnings, the chain's drag, death and the encounter) and
## calls step(), receive_hit(), push_hero() and the drag hooks; everything special is here: waking, the arena's armour, posture
## and counter rules, parries, three phases, ten attacks (two with a follow-up warning; the Song Flare's rings and gold blow), the
## Briar Ring that rises at each phase change, the solid body. No rendering.
## Deterministic: its own small generator
## picks the attacks. Numbers: core/tuning.gd MOBS.colossus and COLOSSUS_*. The title screen's practice fight keeps the old
## core/boss.gd.
##
## States: idle (asleep, cannot be hurt), alert (rising, cannot be hurt), chase, windup (a warning runs), strike (dangerous),
## recover, posture_broken (the counter window), stagger (Reaper's Coil's stun), roar (phase 2 or 3 begins), dead.
const GameEvent := preload("res://core/game_event.gd")
const Weapons := preload("res://core/weapons.gd")
const PlayerState := preload("res://core/player.gd")
const Collision := preload("res://core/collision.gd")

const STATE_BROKEN: StringName = &"posture_broken"
const ATTACK_SLAM: StringName = &"gold_slam"
const ATTACK_SWEEP: StringName = &"red_sweep"
const ATTACK_SHARDS: StringName = &"red_shards"
const ATTACK_STOMP: StringName = &"red_stomp"
const ATTACK_COMBO: StringName = &"gold_combo"
const ATTACK_CHARGE: StringName = &"red_charge"
const ATTACK_SNARE: StringName = &"root_snare"
const ATTACK_BOULDER: StringName = &"boulder_toss"
const ATTACK_GRAB: StringName = &"heartroot_grab"
const ATTACK_FLARE: StringName = &"song_flare"
const BRIAR: StringName = &"briar_ring"  # not an attack of the rotation: it rises when a phase begins (Tuning.COLOSSUS_BRIAR)

var posture: float = 0.0
var broken_left: int = 0
var stun_left: int = 0
## Tests and scripted encounters can force the next attack (one of the ids); it ignores distance and phase.
var next_attack_override: StringName = &""

var _last_attack: StringName = &""
var _random: int = 1
var _first_hit: int = 0
var _last_end: int = 0
var _recover_ticks: int = 0
var _charge: Telegraph = null
var _charge_from: Vector2 = Vector2.ZERO
var _follow_due: int = -1  # the tick the running attack's follow-up warning begins (-1: none waiting)
## The Briar Ring while it warns or stands: a red ring whose inside (inner_size round the encounter's centre) is safe. It outlives
## attacks, breaks and drags; the hero's defeat (reset) and the boss's fall end it.
var briar: Telegraph = null


func setup(p_id: int, p_type: StringName, p_encounter: StringName, p_home: Vector2, p_slot: int) -> void:
	super(p_id, p_type, p_encounter, p_home, p_slot)
	_random = p_id * 2654435 + 1


func reset() -> void:
	super()
	posture = 0.0
	broken_left = 0
	stun_left = 0
	next_attack_override = &""
	_last_attack = &""
	_random = id * 2654435 + 1
	_charge = null
	_follow_due = -1
	briar = null


## The counter window: only a broken posture exposes it.
func is_exposed() -> bool:
	return state == STATE_BROKEN


## Asleep or still rising: blows and skills pass it by.
func is_targetable() -> bool:
	return is_alive() and state != &"idle" and state != &"alert"


## What the snapshot adds for its bars.
func view_extra() -> Dictionary:
	return {
		"posture": posture, "posture_max": Tuning.COLOSSUS_POSTURE_MAX, "break_ticks": Tuning.COLOSSUS_BREAK_TICKS,
		"broken_ticks_left": broken_left if state == STATE_BROKEN else 0, "invulnerable": not is_targetable(),
	}


# ---- one tick ---------------------------------------------------------------------------------------------------------------

## One tick, after the hero moved. `core` is the ExploreCore, `field` its MobField (for warning ids).
func step(core: RefCounted, field: RefCounted, events: Array[GameEvent]) -> void:
	state_ticks += 1
	if state in [&"chase", &"windup", &"strike", &"recover", &"stagger", &"roar"]:
		posture = maxf(0.0, posture - Tuning.COLOSSUS_POSTURE_DECAY)
	match state:
		&"alert":
			facing = _toward(core.player.position)
			if state_ticks >= Tuning.COLOSSUS_WAKE_TICKS:
				cooldown = Tuning.COLOSSUS_FIRST_ATTACK_TICKS
				set_state(&"chase")
		&"chase":
			_chase(core, field, events)
		&"windup", &"strike":
			if state == &"windup" and core.tick >= _first_hit:
				set_state(&"strike")
			if _follow_due >= 0 and core.tick >= _follow_due:
				_begin_follow(core, field, events)
			_step_charge(core)
			_resolve(core, events)
			if state == &"strike" and core.tick >= _last_end:  # a perfect parry may have broken it just now
				_end_attack()
		&"recover":
			if state_ticks >= _recover_ticks:
				cooldown = Tuning.COLOSSUS_COOLDOWN_TICKS[phase - 1]
				set_state(&"chase")
		STATE_BROKEN:
			broken_left -= 1
			if broken_left <= 0:
				posture = 0.0
				events.append(GameEvent.new(GameEvent.COUNTER_WINDOW_CLOSED, core.tick, {"entity_id": id}))
				_recover_ticks = Tuning.COLOSSUS_BREAK_RECOVER_TICKS
				set_state(&"recover")
		&"stagger":
			if stun_left <= 0:
				_recover_ticks = Tuning.COLOSSUS_STUN_RECOVER_TICKS
				set_state(&"recover")
			else:
				stun_left -= 1
		&"roar":
			if state_ticks >= Tuning.COLOSSUS_ROAR_TICKS:
				cooldown = Tuning.COLOSSUS_COOLDOWN_TICKS[phase - 1]
				set_state(&"chase")
	_step_briar(core, events)


## The Briar Ring stands from its strike for `lasts` ticks: every `every` ticks a hero outside its safe circle takes its damage (a dash
## or a ward answers it like any blow). Then it is gone.
func _step_briar(core: RefCounted, events: Array[GameEvent]) -> void:
	if briar == null:
		return
	if core.tick > briar.end_tick:
		briar = null
		return
	var player: PlayerState = core.player
	if briar.is_dangerous_at(core.tick) and (core.tick - briar.hit_tick) % int(Tuning.COLOSSUS_BRIAR["every"]) == 0 \
			and briar.overlaps_circle(player.position, Tuning.PLAYER_RADIUS):
		player.take_damage(briar.damage, core.tick, events, id)


## Every warning to draw: the attack's and the Briar Ring's.
func all_telegraphs() -> Array[Telegraph]:
	var out: Array[Telegraph] = super.all_telegraphs()
	if briar != null:
		out.append(briar)
	return out


## The hero cannot stand inside the body, whatever moved: him or it. The scene's solids still hold him.
func push_hero(core: RefCounted) -> void:
	var player: PlayerState = core.player
	var reach: float = radius + Tuning.PLAYER_RADIUS
	var offset: Vector2 = player.position - position
	if not is_alive() or offset.length() >= reach:
		return
	var away: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else Vector2.DOWN
	player.position = core.clamp_to_scene(position + away * (reach + 0.01))


func _chase(core: RefCounted, field: RefCounted, events: Array[GameEvent]) -> void:
	var hero: Vector2 = core.player.position
	facing = _toward(hero)
	if cooldown > 0:
		cooldown -= 1
	if cooldown <= 0 and _begin_attack(core, field, events):
		return
	if position.distance_to(hero) > radius + Tuning.PLAYER_RADIUS + Tuning.COLOSSUS_HOLD_GAP:
		var speed: float = float(stats()["speed"])
		position = Collision.move_resolved(core.obstacles, position, position + facing * speed, radius)


## True when the hero stands where the fight camera shows the whole boss.
func sees(hero: Vector2) -> bool:
	var d: Vector2 = hero - position
	return absf(d.x) <= Tuning.COLOSSUS_SIGHT_SIDE and d.y >= -Tuning.COLOSSUS_SIGHT_ABOVE and d.y <= Tuning.COLOSSUS_SIGHT_BELOW


static func attack_row(attack: StringName) -> Dictionary:
	for row: Dictionary in Tuning.COLOSSUS_ATTACKS:
		if row["id"] == attack:
			return row
	return {}


## The attacks that may start now: this phase's, fitting the distance, not the one just used (unless it is the only one).
func choices(dist: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in Tuning.COLOSSUS_ATTACKS:
		if int(row["phase"]) <= phase and dist >= float(row["start_min"]) and dist <= float(row["start_max"]):
			out.append(row)
	if out.size() > 1:
		out = out.filter(func(row: Dictionary) -> bool: return row["id"] != _last_attack)
	return out


func _begin_attack(core: RefCounted, field: RefCounted, events: Array[GameEvent]) -> bool:
	var hero: Vector2 = core.player.position
	var row: Dictionary = {}
	if next_attack_override != &"":
		row = attack_row(next_attack_override)
		next_attack_override = &""
	elif sees(hero):
		var open: Array[Dictionary] = choices(position.distance_to(hero))
		if not open.is_empty():
			_random = (_random * 1103515245 + 12345) & 0x7fffffff
			row = open[(_random >> 8) % open.size()]
	if row.is_empty():
		return false
	_last_attack = row["id"]
	current_attack = row
	facing = _toward(hero)  # the aim is locked here: no warning changes after this
	var warnings: Array[Telegraph] = build_warnings(core, field, row)
	telegraph = warnings[0]
	extra_telegraphs.assign(warnings.slice(1))
	_first_hit = warnings[0].hit_tick
	_last_end = 0
	for warning: Telegraph in warnings:
		_last_end = maxi(_last_end, warning.end_tick)
	_charge = warnings[0] if row["id"] == ATTACK_CHARGE else null
	_follow_due = _first_hit if row.has("follow") else -1
	_charge_from = position
	_recover_ticks = int(row["recover"])
	set_state(&"windup")
	var ids: Array[int] = []
	for warning: Telegraph in warnings:
		ids.append(warning.id)
	events.append(GameEvent.new(GameEvent.ATTACK_TELEGRAPHED, core.tick, {
		"telegraph_id": telegraph.id, "telegraph_ids": ids, "sites": ids.size(), "owner_id": id, "kind": telegraph.kind, "attack": telegraph.attack,
		"scene": core.scene_id, "mob_id": id, "hit_tick": _first_hit, "end_tick": _last_end,
	}))
	return true


## The warnings of attack `row` aimed at the hero now. Each is the hit area itself.
func build_warnings(core: RefCounted, field: RefCounted, row: Dictionary) -> Array[Telegraph]:
	var hero: Vector2 = core.player.position
	var aim: Vector2 = _toward(hero)
	var hit: int = core.tick + roundi(int(row["windup"]) * windup_factor())
	var out: Array[Telegraph] = []
	match StringName(row["id"]):
		ATTACK_SLAM:
			var slam: Telegraph = _warning(field, row, Telegraph.SHAPE_CIRCLE, hero, aim, core.tick, hit)
			slam.size = float(row["radius"])
			out.append(slam)
		ATTACK_SWEEP:
			var sweep: Telegraph = _warning(field, row, Telegraph.SHAPE_CONE, position, aim, core.tick, hit)
			sweep.size = float(row["radius"])
			sweep.half_angle = deg_to_rad(float(row["half_angle_deg"]))
			out.append(sweep)
		ATTACK_SHARDS:
			var muzzle: Vector2 = position + Tuning.COLOSSUS_SHARDS_ORIGIN
			var beam: Vector2 = (hero - muzzle).normalized() if hero != muzzle else aim
			for turn: float in [-1.0, 0.0, 1.0]:
				var lane: Telegraph = _warning(field, row, Telegraph.SHAPE_LINE, muzzle, beam.rotated(deg_to_rad(float(row["spread_deg"]) * turn)), core.tick, hit)
				lane.muzzle = muzzle
				lane.size = float(row["length"])
				lane.width = float(row["width"])
				out.append(lane)
		ATTACK_STOMP:
			var stomp: Telegraph = _warning(field, row, Telegraph.SHAPE_RING, position, aim, core.tick, hit)
			stomp.size = float(row["outer"])
			stomp.inner_size = float(row["inner"])
			out.append(stomp)
		ATTACK_COMBO:
			for blow: int in int(row["blows"]):
				var at: Vector2 = core.clamp_to_scene(hero + aim * float(row["offset"]) * blow)
				var circle: Telegraph = _warning(field, row, Telegraph.SHAPE_CIRCLE, at, aim, core.tick, hit + int(row["gap"]) * blow)
				circle.size = float(row["radius"])
				out.append(circle)
		ATTACK_CHARGE, ATTACK_SNARE, ATTACK_GRAB:
			var lane: Telegraph = _warning(field, row, Telegraph.SHAPE_LINE, position, aim, core.tick, hit)
			lane.size = float(row["length"])
			lane.width = float(row["width"])
			out.append(lane)
		ATTACK_BOULDER:
			var stone: Telegraph = _warning(field, row, Telegraph.SHAPE_CIRCLE, hero, aim, core.tick, hit)
			stone.size = float(row["radius"])
			out.append(stone)
		ATTACK_FLARE:  # three red rings, each on its own beat, then the gold blow
			for wave: Variant in row["waves"]:
				var ring: Telegraph = _warning(field, row, Telegraph.SHAPE_RING, position, aim, core.tick, core.tick + roundi(int(wave[2]) * windup_factor()))
				ring.inner_size = float(wave[0])
				ring.size = float(wave[1])
				out.append(ring)
			var blow: Telegraph = _warning(field, row, Telegraph.SHAPE_CIRCLE, position, aim, core.tick, core.tick + roundi(int(row["gold_after"]) * windup_factor()))
			blow.kind = Telegraph.KIND_GOLD
			blow.size = float(row["gold_radius"])
			blow.damage = int(row["gold_damage"])
			out.append(blow)
	return out


## The windup factor of this phase (phases 2 and 3 warn for less long).
func windup_factor() -> float:
	return 1.0 if phase == 1 else Tuning.COLOSSUS_PHASE2_WINDUP_FACTOR


## The follow-up warning of attack `row`, beginning now (its first warning `first` has just struck): the Root Snare's second
## lane aimed at where the hero went, the Boulder Toss's ring of shock round where the stone landed.
func build_follow(core: RefCounted, field: RefCounted, row: Dictionary, first: Telegraph) -> Array[Telegraph]:
	var spec: Dictionary = row["follow"]
	var hit: int = core.tick + roundi(int(spec["windup"]) * windup_factor())
	var out: Array[Telegraph] = []
	var follow: Telegraph
	if row["id"] == ATTACK_BOULDER:
		follow = _warning(field, row, Telegraph.SHAPE_RING, first.center, first.direction, core.tick, hit)
		follow.size = float(spec["outer"])
		follow.inner_size = float(spec["inner"])
	else:
		follow = _warning(field, row, Telegraph.SHAPE_LINE, position, _toward(core.player.position), core.tick, hit)
		follow.size = float(spec["length"])
		follow.width = float(spec["width"])
	follow.damage = int(spec["damage"])
	follow.end_tick = hit + int(spec["active"]) - 1
	out.append(follow)
	return out


func _begin_follow(core: RefCounted, field: RefCounted, events: Array[GameEvent]) -> void:
	_follow_due = -1
	if telegraph == null:
		return
	var added: Array[Telegraph] = build_follow(core, field, current_attack, telegraph)
	extra_telegraphs.append_array(added)
	var ids: Array[int] = []
	for warning: Telegraph in added:
		_last_end = maxi(_last_end, warning.end_tick)
		ids.append(warning.id)
	events.append(GameEvent.new(GameEvent.ATTACK_TELEGRAPHED, core.tick, {
		"telegraph_id": ids[0], "telegraph_ids": ids, "sites": ids.size(), "owner_id": id, "kind": added[0].kind, "attack": added[0].attack,
		"scene": core.scene_id, "mob_id": id, "hit_tick": added[0].hit_tick, "end_tick": _last_end, "follow": true,
	}))


func _warning(field: RefCounted, row: Dictionary, shape: StringName, center: Vector2, direction: Vector2, start: int, hit: int) -> Telegraph:
	var out: Telegraph = Telegraph.new()
	out.id = field.take_telegraph_id()
	out.owner_id = id
	out.attack = row["id"]
	out.kind = row["kind"]
	out.shape = shape
	out.center = center
	out.muzzle = position
	out.direction = direction
	out.damage = int(row["damage"])
	out.start_tick = start
	out.hit_tick = hit
	out.end_tick = hit + int(row["active"]) - 1
	return out


## While the charge is dangerous the body travels along the locked lane (it stops at a solid or the scene's edge).
func _step_charge(core: RefCounted) -> void:
	if _charge == null or core.tick < _charge.hit_tick or core.tick > _charge.end_tick:
		return
	var progress: float = float(core.tick - _charge.hit_tick + 1) / float(_charge.end_tick - _charge.hit_tick + 1)
	var wanted: Vector2 = _charge_from + _charge.direction * _charge.size * progress
	var low: Vector2 = Vector2(radius, radius)
	position = Collision.move_resolved(core.obstacles, position, wanted, radius).clamp(low, core.size - low)


## Every warning that is dangerous now and covers the hero: a gold one met by the parry window is parried, anything else wounds
## him (unless a dash or a ward answers it). Each warning acts once.
func _resolve(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	for warning: Telegraph in super.all_telegraphs():  # the attack's warnings (the Briar Ring hurts at its own pace)
		if player.state == PlayerState.STATE_DEAD or state == STATE_BROKEN:
			return
		if warning.has_hit or not warning.is_dangerous_at(core.tick) or not warning.overlaps_circle(player.position, Tuning.PLAYER_RADIUS):
			continue
		var since: int = player.parry_ticks_since_press()
		if warning.kind == Telegraph.KIND_GOLD and since >= 0 and since < Tuning.PARRY_ACTIVE_TICKS:
			warning.has_hit = true
			var perfect: bool = since < Tuning.PARRY_PERFECT_TICKS
			events.append(GameEvent.new(GameEvent.PARRY_SUCCEEDED, core.tick, {
				"player_id": player.id, "attacker_id": id, "telegraph_id": warning.id, "quality": &"perfect" if perfect else &"early",
				"position": player.position,
			}))
			player.on_parry_success(position - player.position)
			player.position = Collision.push_out(core.obstacles, player.position, Tuning.PLAYER_RADIUS)
			add_posture(Tuning.COLOSSUS_POSTURE_MAX if perfect else float(current_attack.get("parry_posture", Tuning.PARRY_EARLY_POSTURE)), core.tick, events)
			continue
		var blocked_before: int = player.ward_blocks
		if player.take_damage(warning.damage, core.tick, events, id) or player.ward_blocks > blocked_before:
			warning.has_hit = true


func _end_attack() -> void:
	clear_telegraph()
	_charge = null
	_follow_due = -1
	set_state(&"recover")


# ---- the hero's blows -------------------------------------------------------------------------------------------------------

## One hit of the hero on the Colossus (MobField.hit_mob hands it over). `base` already holds the weapon, skill and Might
## multipliers; `extra` says what hit (the keys MobField and ExploreSkills pass). Armoured: ARMOR_DAMAGE_FACTOR damage plus
## posture (a swing also earns its Edge). Broken: COUNTER_DAMAGE_MULT damage, and the weapon's own blows add and spend the
## Edge. Returns true when it fell and that cleared the encounter.
func receive_hit(core: RefCounted, field: RefCounted, enc: RefCounted, base: float, extra: Dictionary, events: Array[GameEvent]) -> bool:
	if not is_targetable():
		return false
	var player: PlayerState = core.player
	var echo: bool = bool(extra.get("echo", false))
	var swing: bool = extra.has("combo_index") and not echo
	var weapon_blow: bool = swing or extra.has("barrage_slash") or extra.has("reaper_coil_hit") \
		or StringName(extra.get("skill_id", &"")) == Weapons.FORM_DISINTEGRATION
	var counter: bool = is_exposed()
	var damage: int
	if counter:
		var bonus: float = player.edge * Tuning.EDGE_COUNTER_BONUS if weapon_blow else 0.0
		damage = roundi(base * Tuning.COUNTER_DAMAGE_MULT + bonus)
		if weapon_blow:
			player.edge = 0.0
	else:
		damage = maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR))
		if swing:
			player.edge = minf(Tuning.EDGE_MAX, player.edge + Weapons.edge_per_hit(StringName(extra["weapon_id"])))
	hp = maxi(0, hp - damage)
	last_hit_tick = core.tick
	enc.touched = true
	var data: Dictionary = {"attacker_id": player.id, "target_id": id, "damage": damage, "kind": &"counter" if counter else &"normal", "position": position}
	data.merge(extra)
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, core.tick, data))
	if hp <= 0:
		if counter:
			events.append(GameEvent.new(GameEvent.COUNTER_WINDOW_CLOSED, core.tick, {"entity_id": id}))
		dragged = false
		briar = null
		field.kill(core, enc, self, events)
		return field.is_cleared(enc)
	if not counter:
		add_posture(posture_of(extra), core.tick, events)
	var reached: int = phase
	for i: int in Tuning.COLOSSUS_PHASE_HP_FRACTIONS.size():
		if float(hp) <= float(max_hp) * Tuning.COLOSSUS_PHASE_HP_FRACTIONS[i]:
			reached = maxi(reached, i + 2)
	if reached > phase:
		_begin_phase(core, field, enc, reached, events)
	return false


## The posture one armoured hit fills, the arena's amounts.
static func posture_of(extra: Dictionary) -> float:
	var weapon: StringName = StringName(extra.get("weapon_id", &""))
	if extra.has("echo"):
		return Weapons.swing_posture(weapon, int(extra.get("swing_combo_index", 1))) * Tuning.PHANTOM_CUT_POSTURE_MULT
	if extra.has("lightning_strike"):
		return Tuning.LIGHTNING_STRIKE_POSTURE
	if extra.has("barrage_slash"):
		return Tuning.NORMAL_HIT_POSTURE
	if extra.has("reaper_coil_hit"):
		return Tuning.REAPER_COIL_SPIN_POSTURE
	if extra.has("ward_release"):
		return Tuning.STONE_WARD_POSTURE + float(extra.get("ward_stored", 0)) * Tuning.STONE_WARD_POSTURE_PER_STORED
	if extra.has("skill_id"):
		var skill: StringName = StringName(extra["skill_id"])
		return Tuning.DISINTEGRATION_POSTURE if skill == Weapons.FORM_DISINTEGRATION else float(PlayerState.skill_profile(skill)["posture"])
	if extra.has("combo_index"):
		return Weapons.swing_posture(weapon, int(extra["combo_index"]))
	return Tuning.NORMAL_HIT_POSTURE


func add_posture(amount: float, tick: int, events: Array[GameEvent]) -> void:
	if state == STATE_BROKEN or not is_targetable():
		return
	posture = minf(Tuning.COLOSSUS_POSTURE_MAX, posture + amount)
	if posture < Tuning.COLOSSUS_POSTURE_MAX:
		return
	clear_telegraph()  # a broken boss drops its attack
	_charge = null
	_follow_due = -1
	stun_left = 0  # a break replaces Reaper's Coil's stun
	broken_left = Tuning.COLOSSUS_BREAK_TICKS
	set_state(STATE_BROKEN)
	events.append(GameEvent.new(GameEvent.POSTURE_BROKEN, tick, {"entity_id": id, "window_ticks": broken_left, "position": position}))
	events.append(GameEvent.new(GameEvent.COUNTER_WINDOW_OPENED, tick, {"entity_id": id, "window_ticks": broken_left}))


## Health below a COLOSSUS_PHASE_HP_FRACTIONS mark: phase `new_phase` (one blow that crosses both marks goes straight to 3). It drops
## its attack and roars; the attacks of that phase join; from phase 2 on the warnings are shorter. Broken or held by the chain it
## changes phase without the roar. Either way the Briar Ring rises round the encounter (a new one replaces a standing one).
func _begin_phase(core: RefCounted, field: RefCounted, enc: RefCounted, new_phase: int, events: Array[GameEvent]) -> void:
	phase = new_phase
	events.append(GameEvent.new(GameEvent.BOSS_PHASE_CHANGED, core.tick, {"entity_id": id, "phase": phase, "scene": core.scene_id, "position": position}))
	_raise_briar(core, field, enc.anchor, events)
	if state == STATE_BROKEN or state == &"stagger" or dragged:
		return
	clear_telegraph()
	_charge = null
	_follow_due = -1
	set_state(&"roar")


## The Briar Ring round `centre`: it warns for COLOSSUS_BRIAR.windup ticks, then stands for `lasts`.
func _raise_briar(core: RefCounted, field: RefCounted, centre: Vector2, events: Array[GameEvent]) -> void:
	var spec: Dictionary = Tuning.COLOSSUS_BRIAR
	var ring: Telegraph = Telegraph.new()
	ring.id = field.take_telegraph_id()
	ring.owner_id = id
	ring.attack = BRIAR
	ring.kind = Telegraph.KIND_RED
	ring.shape = Telegraph.SHAPE_RING
	ring.center = centre
	ring.muzzle = centre
	ring.direction = Vector2.UP
	ring.inner_size = float(spec["safe_radius"])
	ring.size = float(spec["outer"])
	ring.damage = int(spec["damage"])
	ring.start_tick = core.tick
	ring.hit_tick = core.tick + int(spec["windup"])
	ring.end_tick = ring.hit_tick + int(spec["lasts"]) - 1
	briar = ring
	events.append(GameEvent.new(GameEvent.ATTACK_TELEGRAPHED, core.tick, {
		"telegraph_id": ring.id, "telegraph_ids": [ring.id], "sites": 1, "owner_id": id, "kind": ring.kind, "attack": BRIAR,
		"scene": core.scene_id, "mob_id": id, "hit_tick": ring.hit_tick, "end_tick": ring.end_tick,
	}))


# ---- Reaper's Coil ----------------------------------------------------------------------------------------------------------

## The chain caught it: its attack is dropped and it stands stunned while dragged. A broken one stays broken.
func on_hooked() -> void:
	clear_telegraph()
	_charge = null
	_follow_due = -1
	if state != STATE_BROKEN:
		stun_left = 0
		set_state(&"stagger")


## The drag is over: the stun runs COLOSSUS_STUN_TICKS more (a broken posture's window just goes on).
func on_released() -> void:
	if state == &"stagger":
		stun_left = Tuning.COLOSSUS_STUN_TICKS


func coil_stun_ticks() -> int:
	return Tuning.COLOSSUS_STUN_TICKS


func _toward(point: Vector2) -> Vector2:
	var d: Vector2 = point - position
	return d.normalized() if d.length_squared() > 0.0001 else facing
