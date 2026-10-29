extends RefCounted
## The hero's Aspects on the road, resolved against mobs. The fight's GameCore resolves the same Aspects against the boss
## (core/game_core.gd); the hero's own states and timers (core/player.gd) are shared, so this file only holds what lives in the
## world: Spirit Lanterns, Echo Step anchors, Phantom Cut echoes and the live skill attacks (Breaking Edge arc, Gale Cut lane,
## Moon Cleave projectile), plus the Stone Ward's shockwave. A hit on a mob goes through MobField.hit_mob(), so an exposed mob
## takes the counter multiplier, a felled mob pays exp and drops, and a cleared group is cleared the same way as for a swing.
## No rendering. ExploreCore owns one of these and calls before_player(), after_move() and on_swing_hit().
const Tuning := preload("res://core/tuning.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
const PlayerState := preload("res://core/player.gd")
const Aspects := preload("res://core/aspects.gd")
const Lantern := preload("res://core/lantern.gd")
const Echo := preload("res://core/echo.gd")
const SkillAttack := preload("res://core/skill_attack.gd")
const Collision := preload("res://core/collision.gd")

var lanterns: Array[Lantern] = []
var echoes: Array[Echo] = []
## Phantom Cut echoes waiting to land, in queue order: {land_tick, mob_id, base, combo_index, weapon_id, hit_tick}.
var phantom_echoes: Array[Dictionary] = []
var skill_attacks: Array[SkillAttack] = []
var _next_attack_id: int = 1
var _next_lantern_id: int = 1
var _next_echo_id: int = 1


## Everything the hero left in the world is gone (a new scene, the hero's defeat).
func clear() -> void:
	lanterns.clear()
	echoes.clear()
	phantom_echoes.clear()
	skill_attacks.clear()


## Before the hero's own step: he must know whether an echo anchor exists (Echo Step needs none, or recalls).
func before_player(core: RefCounted) -> void:
	core.player.echo_exists = _player_echo(core) != null
	core.player.barrage_target_alive = false  # Lightning Form and Reaper's Coil need a boss to aim at; the road has none


## After the hero moved this tick. `player_before` is where he stood before the move (a dash lane sweeps from there).
func after_move(core: RefCounted, player_before: Vector2, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	_place_echo(core, events)
	if player.ward_release_pending:
		_release_ward(core, &"expired", events)
	_resolve_echo_recall(core, events)
	_resolve_phantom_echoes(core, events)
	_spawn_released_skill(core, events)
	_resolve_skill_attacks(core, player_before, events)
	_resolve_lanterns(core, events)
	if player.state == PlayerState.STATE_DEAD:
		for echo: Echo in echoes.duplicate():
			_remove_echo(core, echo, &"death", events)
		phantom_echoes.clear()


## The hero's swing landed on `mob_id` with `base` damage (before the exposed multiplier). While Phantom Cut runs, an echo of it
## follows PHANTOM_CUT_DELAY_TICKS later on the same mob.
func on_swing_hit(core: RefCounted, mob_id: int, base: float, combo_index: int, weapon: StringName) -> void:
	if core.player.phantom_ticks_left <= 0:
		return
	phantom_echoes.append({
		"land_tick": core.tick + Tuning.PHANTOM_CUT_DELAY_TICKS, "hit_tick": core.tick, "mob_id": mob_id, "combo_index": combo_index,
		"weapon_id": weapon, "base": base * Tuning.PHANTOM_CUT_DAMAGE_MULT,
	})


# ---- Phantom Cut ----------------------------------------------------------------------------------------------------------

func _resolve_phantom_echoes(core: RefCounted, events: Array[GameEvent]) -> void:
	while not phantom_echoes.is_empty() and int(phantom_echoes[0]["land_tick"]) <= core.tick:
		var echo: Dictionary = phantom_echoes.pop_front()
		if core.player.state == PlayerState.STATE_DEAD:
			phantom_echoes.clear()
			return
		var target: Dictionary = _find_mob(core, int(echo["mob_id"]))
		if target.is_empty():
			continue  # the mob fell or went home before the echo landed
		var mob: RefCounted = target["mob"]
		events.append(GameEvent.new(GameEvent.PHANTOM_ECHO, core.tick, {
			"entity_id": core.player.id, "target_id": mob.id, "damage": maxi(1, roundi(float(echo["base"]))), "swing_combo_index": echo["combo_index"],
			"position": mob.position, "weapon_id": echo["weapon_id"], "hit_tick": echo["hit_tick"], "kind": &"normal",
		}))
		if core.mobs.hit_mob(core, target["enc"], mob, float(echo["base"]), {"echo": true, "swing_combo_index": echo["combo_index"], "weapon_id": echo["weapon_id"]}, events):
			return


func _find_mob(core: RefCounted, mob_id: int) -> Dictionary:
	for row: Dictionary in core.mobs.living():
		if int(row["mob"].id) == mob_id:
			return row
	return {}


# ---- Spirit Lantern -------------------------------------------------------------------------------------------------------

## Pulse k lands on placement + k x SPIRIT_LANTERN_PULSE_INTERVAL_TICKS: the hero inside the light heals and gains Edge (both
## capped). After the last pulse the lantern expires. The hero's death removes them.
func _resolve_lanterns(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	if lanterns.is_empty():
		return
	if player.state == PlayerState.STATE_DEAD:
		for lantern: Lantern in lanterns.duplicate():
			_remove_lantern(core, lantern, &"death", events)
		return
	for lantern: Lantern in lanterns.duplicate():
		if lantern.pulses_done < Tuning.SPIRIT_LANTERN_PULSES and core.tick >= lantern.pulse_tick(lantern.pulses_done + 1):
			lantern.pulses_done += 1
			var inside: bool = lantern.covers(player.position)
			var healed: int = 0
			var gained: float = 0.0
			if inside:
				healed = mini(Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE, core.hero_max_hp() - player.hp)
				gained = minf(Tuning.SPIRIT_LANTERN_EDGE_PER_PULSE, Tuning.EDGE_MAX - player.edge)
				player.hp += healed
				player.edge += gained
			events.append(GameEvent.new(GameEvent.LANTERN_PULSE, core.tick, {
				"lantern_id": lantern.id, "entity_id": lantern.owner_id, "position": lantern.position, "radius": lantern.radius,
				"pulse_index": lantern.pulses_done, "healed": healed, "edge_gained": gained, "player_inside": inside,
			}))
		if core.tick >= lantern.end_tick():
			_remove_lantern(core, lantern, &"expired", events)


func _place_lantern(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	for old: Lantern in lanterns.duplicate():
		if old.owner_id == player.id:
			_remove_lantern(core, old, &"replaced", events)
	var lantern: Lantern = Lantern.new()
	lantern.id = _next_lantern_id
	_next_lantern_id += 1
	lantern.owner_id = player.id
	lantern.position = player.position
	lantern.placed_tick = core.tick
	lanterns.append(lantern)
	player.aspect_cooldowns[Aspects.SPIRIT_LANTERN] = Aspects.cooldown(Aspects.SPIRIT_LANTERN)
	events.append(GameEvent.new(GameEvent.LANTERN_PLACED, core.tick, {
		"lantern_id": lantern.id, "entity_id": player.id, "position": lantern.position, "radius": lantern.radius,
		"duration": Tuning.SPIRIT_LANTERN_DURATION_TICKS, "pulses": Tuning.SPIRIT_LANTERN_PULSES,
		"pulse_interval": Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS,
	}))


func _remove_lantern(core: RefCounted, lantern: Lantern, reason: StringName, events: Array[GameEvent]) -> void:
	lanterns.erase(lantern)
	events.append(GameEvent.new(GameEvent.LANTERN_EXPIRED, core.tick, {
		"lantern_id": lantern.id, "entity_id": lantern.owner_id, "position": lantern.position, "reason": reason, "pulses_done": lantern.pulses_done,
	}))


# ---- Echo Step ------------------------------------------------------------------------------------------------------------

func _player_echo(core: RefCounted) -> Echo:
	for echo: Echo in echoes:
		if echo.owner_id == core.player.id:
			return echo
	return null


## Echo Step was pressed this tick: place the anchor where the hero stands after the move.
func _place_echo(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	if not player.echo_requested:
		return
	player.echo_requested = false
	if player.state == PlayerState.STATE_DEAD:
		return
	var echo: Echo = Echo.new()
	echo.id = _next_echo_id
	_next_echo_id += 1
	echo.owner_id = player.id
	echo.position = player.position
	echo.placed_tick = core.tick
	echoes.append(echo)
	events.append(GameEvent.new(GameEvent.ECHO_PLACED, core.tick, {
		"echo_id": echo.id, "entity_id": player.id, "position": echo.position, "duration": Tuning.ECHO_STEP_DELAY_TICKS,
	}))


## The echo is due: the hero is pulled back to it (a raised ward releases first; a skill attack that follows him ends, a
## projectile flies on). The way back is swept against the scene's solids, so he never arrives inside a wall.
func _resolve_echo_recall(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var echo: Echo = _player_echo(core)
	if echo == null or core.tick < echo.due_tick() or player.state == PlayerState.STATE_DEAD:
		return
	if player.state == PlayerState.STATE_LIGHTNING_BARRAGE or player.state == PlayerState.STATE_REAPER_COIL:
		return  # never interrupted: the recall waits until it ends
	var from: Vector2 = player.position
	if player.state == PlayerState.STATE_WARD:
		player.end_ward_early()
		_release_ward(core, &"recall", events)
	for attack: SkillAttack in skill_attacks.duplicate():
		if attack.shape != SkillAttack.SHAPE_PROJECTILE:
			skill_attacks.erase(attack)
	var spot: Vector2 = core.clamp_to_scene(Collision.move_resolved(core.obstacles, from, echo.position, Tuning.PLAYER_RADIUS))
	player.echo_recall(spot)
	echoes.erase(echo)
	events.append(GameEvent.new(GameEvent.ECHO_RECALL, core.tick, {
		"echo_id": echo.id, "entity_id": player.id, "from": from, "to": spot, "anchor": echo.position,
		"invuln_ticks": Tuning.ECHO_STEP_INVULN_TICKS, "waited": core.tick - echo.due_tick(),
	}))


func _remove_echo(core: RefCounted, echo: Echo, reason: StringName, events: Array[GameEvent]) -> void:
	echoes.erase(echo)
	events.append(GameEvent.new(GameEvent.ECHO_EXPIRED, core.tick, {
		"echo_id": echo.id, "entity_id": echo.owner_id, "position": echo.position, "reason": reason,
	}))


# ---- Stone Ward -----------------------------------------------------------------------------------------------------------

## The ward ended (`expired` on its timer, `recall` by an Echo Step): a shockwave around the hero hits every living mob whose
## circle is within STONE_WARD_RADIUS: (base + stored x mult) x the damage multipliers. Events: ward_released, then one
## attack_hit (aspect_id stone_ward, ward_release true) per mob hit.
func _release_ward(core: RefCounted, reason: StringName, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	player.ward_release_pending = false
	var stored: int = player.ward_stored
	player.ward_stored = 0
	var base: float = (Tuning.STONE_WARD_BASE_DAMAGE + float(stored) * Tuning.STONE_WARD_STORE_MULT) * player.damage_mult() * core.damage_mult()
	var hit_rows: Array[Dictionary] = []
	for row: Dictionary in core.mobs.living():
		if player.position.distance_to(row["mob"].position) - float(row["mob"].radius) <= Tuning.STONE_WARD_RADIUS:
			hit_rows.append(row)
	events.append(GameEvent.new(GameEvent.WARD_RELEASED, core.tick, {
		"entity_id": player.id, "position": player.position, "stored": stored, "radius": Tuning.STONE_WARD_RADIUS,
		"damage": roundi(base) if not hit_rows.is_empty() else 0, "hit": not hit_rows.is_empty(), "reason": reason,
	}))
	if hit_rows.is_empty():
		return
	player.edge = minf(Tuning.EDGE_MAX, player.edge + Tuning.STONE_WARD_EDGE_GAIN)
	for row: Dictionary in hit_rows:
		if core.mobs.hit_mob(core, row["enc"], row["mob"], base, {"aspect_id": Aspects.STONE_WARD, "ward_release": true}, events):
			return


# ---- skill attacks (Breaking Edge, Gale Cut, Moon Cleave) -----------------------------------------------------------------

## A skill reached its active frames: the lantern is placed at once; the others become a live attack.
func _spawn_released_skill(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var skill: StringName = player.pending_release
	if skill == &"":
		return
	player.pending_release = &""
	if skill == PlayerState.SKILL_SPIRIT_LANTERN:
		_place_lantern(core, events)
		return
	var attack: SkillAttack = SkillAttack.new()
	attack.id = _next_attack_id
	_next_attack_id += 1
	attack.owner_id = player.id
	attack.skill_id = skill
	attack.direction = player.skill_dir
	attack.damage_mult = player.damage_mult() * core.damage_mult()
	attack.start_tick = core.tick
	attack.position = player.position
	attack.start = player.position
	attack.end = player.position
	match skill:
		PlayerState.SKILL_BREAKING_EDGE:
			attack.shape = SkillAttack.SHAPE_ARC
			attack.size = Tuning.BREAKING_EDGE_RANGE
			attack.arc_dot = Tuning.BREAKING_EDGE_ARC_DOT
			attack.end_tick = core.tick + Tuning.BREAKING_EDGE_ACTIVE_TICKS - 1
		PlayerState.SKILL_GALE_CUT:
			attack.shape = SkillAttack.SHAPE_LANE
			attack.width = Tuning.GALE_CUT_LANE_WIDTH
			attack.end = player.position + player.skill_dir * Tuning.GALE_CUT_DISTANCE
			attack.end_tick = core.tick + Tuning.GALE_CUT_ACTIVE_TICKS
		_:
			attack.shape = SkillAttack.SHAPE_PROJECTILE
			attack.width = Tuning.MOON_CLEAVE_WIDTH
			attack.speed = Tuning.MOON_CLEAVE_SPEED
			attack.length = Tuning.MOON_CLEAVE_TRAVEL
			attack.start = player.position + player.skill_dir * Tuning.MOON_CLEAVE_SPAWN_OFFSET
			attack.position = attack.start
			attack.end = attack.start + player.skill_dir * Tuning.MOON_CLEAVE_TRAVEL
			attack.end_tick = core.tick + ceili(Tuning.MOON_CLEAVE_TRAVEL / Tuning.MOON_CLEAVE_SPEED)
	skill_attacks.append(attack)
	events.append(GameEvent.new(GameEvent.SKILL_RELEASED, core.tick, {
		"attack_id": attack.id, "entity_id": player.id, "skill_id": skill, "shape": attack.shape,
		"position": attack.position, "direction": attack.direction, "start": attack.start, "end": attack.end, "width": attack.width,
	}))


## Advance and test every live skill attack against every living mob; a cast hits each mob at most once.
func _resolve_skill_attacks(core: RefCounted, player_before: Vector2, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	for attack: SkillAttack in skill_attacks.duplicate():
		var done: bool = false
		var from: Vector2 = attack.position
		match attack.shape:
			SkillAttack.SHAPE_ARC:
				attack.position = player.position
			SkillAttack.SHAPE_LANE:
				attack.position = player.position
			_:
				if core.tick > attack.start_tick:
					var step: float = minf(attack.speed, attack.length - attack.travelled)
					attack.position += attack.direction * step
					attack.travelled += step
		for row: Dictionary in core.mobs.living():
			var mob: RefCounted = row["mob"]
			if attack.has_hit(mob.id) or not _touches(attack, mob, player_before, from, player.position):
				continue
			attack.hit_targets.append(mob.id)
			var profile: Dictionary = PlayerState.skill_profile(attack.skill_id)
			var exposed: bool = mob.is_exposed()
			if not exposed:
				player.edge = minf(Tuning.EDGE_MAX, player.edge + float(profile["edge_gain"]))
			if core.mobs.hit_mob(core, row["enc"], mob, float(profile["damage"]) * attack.damage_mult, {"skill_id": attack.skill_id, "attack_id": attack.id}, events):
				break
		match attack.shape:
			SkillAttack.SHAPE_ARC:
				done = core.tick >= attack.end_tick
			SkillAttack.SHAPE_LANE:
				done = player.state != PlayerState.STATE_SKILL_ACTIVE
			_:
				done = attack.travelled >= attack.length
		if done:
			skill_attacks.erase(attack)


func _touches(attack: SkillAttack, mob: RefCounted, player_before: Vector2, projectile_from: Vector2, player_now: Vector2) -> bool:
	match attack.shape:
		SkillAttack.SHAPE_ARC:
			var to_mob: Vector2 = mob.position - attack.position
			var dist: float = to_mob.length()
			if dist - float(mob.radius) > attack.size:
				return false
			return dist <= 0.0001 or attack.direction.dot(to_mob / dist) >= attack.arc_dot
		SkillAttack.SHAPE_LANE:
			return SkillAttack.segment_touches_circle(player_before, player_now, mob.position, float(mob.radius) + attack.width * 0.5)
	return SkillAttack.segment_touches_circle(projectile_from, attack.position, mob.position, float(mob.radius) + attack.width * 0.5)


# ---- the snapshot ---------------------------------------------------------------------------------------------------------

## The world objects for ExploreSnapshot (the same snapshot classes the fight's GameSnapshot uses, so one drawing serves both).
func fill_snapshot(core: RefCounted, snap: RefCounted) -> void:
	var tick: int = core.tick
	for attack: SkillAttack in skill_attacks:
		var a: Snapshots.SkillAttackSnapshot = Snapshots.SkillAttackSnapshot.new()
		a.id = attack.id
		a.owner_id = attack.owner_id
		a.skill_id = attack.skill_id
		a.shape = attack.shape
		a.position = attack.position
		a.direction = attack.direction
		a.start = attack.start
		a.end = attack.end
		a.width = attack.width
		a.size = attack.size
		a.half_angle = acos(clampf(attack.arc_dot, -1.0, 1.0)) if attack.shape == SkillAttack.SHAPE_ARC else 0.0
		a.start_tick = attack.start_tick
		a.end_tick = attack.end_tick
		a.ticks_left = maxi(0, attack.end_tick - tick)
		a.hit_target_ids = attack.hit_targets.duplicate()
		snap.skill_attacks.append(a)
	for lantern: Lantern in lanterns:
		var l: Snapshots.LanternSnapshot = Snapshots.LanternSnapshot.new()
		l.id = lantern.id
		l.owner_id = lantern.owner_id
		l.position = lantern.position
		l.radius = lantern.radius
		l.placed_tick = lantern.placed_tick
		l.duration = Tuning.SPIRIT_LANTERN_DURATION_TICKS
		l.ticks_left = maxi(0, lantern.end_tick() - tick)
		l.pulse_index = lantern.pulses_done
		l.pulses = Tuning.SPIRIT_LANTERN_PULSES
		l.next_pulse_in = maxi(0, lantern.pulse_tick(lantern.pulses_done + 1) - tick) if lantern.pulses_done < Tuning.SPIRIT_LANTERN_PULSES else 0
		snap.lanterns.append(l)
	for echo: Echo in echoes:
		var s: Snapshots.EchoSnapshot = Snapshots.EchoSnapshot.new()
		s.id = echo.id
		s.owner_id = echo.owner_id
		s.position = echo.position
		s.placed_tick = echo.placed_tick
		s.duration = Tuning.ECHO_STEP_DELAY_TICKS
		s.ticks_left = maxi(0, echo.due_tick() - tick)
		snap.echoes.append(s)
