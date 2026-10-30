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
const Weapons := preload("res://core/weapons.gd")
const Obstacle := preload("res://core/obstacle.gd")
const MobField := preload("res://core/mob_field.gd")

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


## Before the hero's own step: he must know whether an echo anchor exists (Echo Step needs none, or recalls), and whether a
## mob stands in front of him for the weapon's active (Lightning Form, Reaper's Coil).
func before_player(core: RefCounted, input: RefCounted) -> void:
	core.player.echo_exists = _player_echo(core) != null
	core.player.barrage_target_alive = false
	if input.weapon_active_pressed and Weapons.active_needs_target(core.player.weapon_id):
		var direction: Vector2 = input.aim if input.aim.length_squared() > 0.0001 else core.player.facing
		_target_id = pick_target(_target_rows(core), core.player.position, direction)
		core.player.barrage_target_alive = _target_id >= 0


var _target_id: int = -1


## The mob a targeted active starts on: the nearest one in front of the hero (within Tuning.ROAD_TARGET_RANGE and the
## Tuning.ROAD_TARGET_CONE_DOT cone around `direction`), or one touching him; -1 when none. `rows` are {id, position, radius}.
static func pick_target(rows: Array, hero_position: Vector2, direction: Vector2) -> int:
	var best: int = -1
	var best_distance: float = INF
	var forward: Vector2 = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	for row: Dictionary in rows:
		var at: Vector2 = row["position"]
		var gap: float = hero_position.distance_to(at) - float(row.get("radius", 6.0))
		if gap > Tuning.ROAD_TARGET_RANGE:
			continue
		var to_mob: Vector2 = at - hero_position
		var in_front: bool = to_mob.length_squared() < 0.0001 or forward.dot(to_mob.normalized()) >= Tuning.ROAD_TARGET_CONE_DOT
		if not in_front and gap > Tuning.PLAYER_RADIUS:
			continue
		if gap < best_distance:
			best_distance = gap
			best = int(row["id"])
	return best


func _target_rows(core: RefCounted) -> Array:
	var rows: Array = []
	for row: Dictionary in core.mobs.living():
		rows.append({"id": row["mob"].id, "position": row["mob"].position, "radius": row["mob"].radius})
	return rows


## After the hero moved this tick. `player_before` is where he stood before the move (a dash lane sweeps from there).
func after_move(core: RefCounted, player_before: Vector2, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	_place_echo(core, events)
	_resolve_lightning_barrage(core, events)
	_resolve_reaper_coil(core, events)
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


# ---- targets: the mob in front, and the clump around it -------------------------------------------------------------------

## The damage multiplier per target when `count` mobs are hit by one cast: the more are hit, the less each takes
## (Tuning.MULTI_HIT_FALLOFF per extra target, never below Tuning.MULTI_HIT_MIN_MULT).
static func multi_hit_mult(count: int) -> float:
	return maxf(Tuning.MULTI_HIT_MIN_MULT, 1.0 - Tuning.MULTI_HIT_FALLOFF * float(maxi(0, count - 1)))


## The row ({"enc", "mob"}) of the barrage's or coil's main target, or {} once it fell or is gone.
func _target_row(core: RefCounted) -> Dictionary:
	return _find_mob(core, _target_id)


## The target fell mid-cast: the nearest other living mob in range takes over (the cast goes on), else {}.
func _retarget(core: RefCounted) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for row: Dictionary in core.mobs.living():
		var distance: float = core.player.position.distance_to(row["mob"].position) - float(row["mob"].radius)
		if distance <= Tuning.ROAD_TARGET_RANGE and distance < best_distance:
			best_distance = distance
			best = row
	if not best.is_empty():
		_target_id = best["mob"].id
	return best


# ---- Lightning Form (the Dual Dagger's barrage) ----------------------------------------------------------------------------

## Started on the activation tick (the target was picked before the hero's step); then, on a fixed timeline counted from
## the activation, one blink-slash per side of LIGHTNING_BLINK_ORDER around the target. Every slash hits every mob within the
## dagger's reach of where the hero lands, so a clump takes it together. Ends when the timeline is over, nothing is left to
## hit (boss_dead is the reason name the hero's own code knows) or the hero dies.
func _resolve_lightning_barrage(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var tick: int = core.tick
	if player.barrage_requested:
		player.barrage_requested = false
		if not _target_row(core).is_empty() and player.state != PlayerState.STATE_DEAD:
			for attack: SkillAttack in skill_attacks.duplicate():
				if attack.shape != SkillAttack.SHAPE_PROJECTILE:
					skill_attacks.erase(attack)
			player.start_barrage(tick, events)
		return
	if not player.barrage_running or player.state != PlayerState.STATE_LIGHTNING_BARRAGE:
		return
	if _target_row(core).is_empty() and _retarget(core).is_empty():
		player.end_barrage(tick, events, &"boss_dead")
		return
	var t: int = player.state_ticks - Tuning.LIGHTNING_BARRAGE_START_DELAY_TICKS
	if t < 0:
		return
	var slash: int = t / Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS
	var phase: int = t % Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS
	if slash < Weapons.barrage_slashes():
		if phase == 0 and not _target_row(core).is_empty():
			_barrage_blink(core, slash, events)
		if phase == Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS:
			_barrage_hit(core, slash, events)
	if player.state_ticks >= Weapons.barrage_total_ticks():
		player.end_barrage(tick, events, &"complete")


## Where a blink in direction `index` (0-7) would land: next to the target, kept in the scene and out of the solids. (The fight's
## 30 px from a boss of radius 20 is a 10 px gap to its edge: the same gap from this mob's edge.)
func _blink_spot(core: RefCounted, mob: RefCounted, index: int) -> Vector2:
	var gap: float = Tuning.LIGHTNING_BLINK_DISTANCE - Tuning.BOSS_RADIUS
	return core.clamp_to_scene(mob.position + Weapons.blink_direction(index) * (float(mob.radius) + gap))


func _blink_spot_ok(core: RefCounted, mob: RefCounted, spot: Vector2, reach: float) -> bool:
	var dist: float = spot.distance_to(mob.position)
	if dist < float(mob.radius) + Tuning.PLAYER_RADIUS or dist > reach:
		return false
	for obstacle: Obstacle in core.obstacles:
		if spot.distance_to(obstacle.center) < obstacle.radius + Tuning.PLAYER_RADIUS - 0.001:
			return false
	return spot == core.clamp_to_scene(spot)


## Barrage slash `slash` (0-based) starts: blink to its side of LIGHTNING_BLINK_ORDER. A blocked side falls back to the nearest
## free side this barrage has not used yet (else the nearest free one). No free spot: the slash stays put.
func _barrage_blink(core: RefCounted, slash: int, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var mob: RefCounted = _target_row(core)["mob"]
	player.barrage_slash = slash + 1
	player.barrage_slash_tick = core.tick
	var wanted: int = Tuning.LIGHTNING_BLINK_ORDER[slash % Tuning.LIGHTNING_BLINK_ORDER.size()]
	var reach: float = float(mob.radius) + Tuning.ATTACK_RANGE * Weapons.range_mults(player.weapon_id)[0]
	var chosen: int = -1
	var fallback: int = -1
	for offset: int in [0, 1, -1, 2, -2, 3, -3, 4]:
		var index: int = posmod(wanted + offset, 8)
		if not _blink_spot_ok(core, mob, _blink_spot(core, mob, index), reach):
			continue
		if not player.barrage_sides.has(index):
			chosen = index
			break
		if fallback < 0:
			fallback = index
	if chosen < 0:
		chosen = fallback
	if chosen < 0:
		return
	player.barrage_sides.append(chosen)
	var spot: Vector2 = _blink_spot(core, mob, chosen)
	var from: Vector2 = player.position
	player.apply_blink(spot, mob.position - spot, chosen, core.tick)
	events.append(GameEvent.new(GameEvent.LIGHTNING_BLINK, core.tick, {
		"entity_id": player.id, "from": from, "to": spot, "direction_index": chosen, "target_id": mob.id, "barrage_slash": slash + 1,
	}))


## Barrage slash `slash` lands: it turns to the target and hits every mob within the dagger's reach (the clump), each for the
## damage shared out by how many there are. The last slash also calls the lightning strike on the main target.
func _barrage_hit(core: RefCounted, slash: int, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var row: Dictionary = _target_row(core)
	if not row.is_empty():
		var to_target: Vector2 = row["mob"].position - player.position
		if to_target.length() > 0.0001:
			player.facing = to_target.normalized()
	var reach: float = Tuning.ATTACK_RANGE * Weapons.range_mults(player.weapon_id)[0]
	var hit_rows: Array[Dictionary] = []
	for candidate: Dictionary in core.mobs.living():
		if player.position.distance_to(candidate["mob"].position) - float(candidate["mob"].radius) <= reach:
			hit_rows.append(candidate)
	if hit_rows.is_empty():
		return
	var mult: float = player.damage_mult() * core.damage_mult()
	var base: float = Tuning.ATTACK_DAMAGE * Tuning.LIGHTNING_BARRAGE_DAMAGE_MULT * mult * multi_hit_mult(hit_rows.size())
	var gained: bool = false
	var main_counter: bool = false
	for candidate: Dictionary in hit_rows:
		var counter: bool = candidate["mob"].is_exposed()
		gained = gained or not counter
		if not row.is_empty() and candidate["mob"].id == row["mob"].id:
			main_counter = counter
		if core.mobs.hit_mob(core, candidate["enc"], candidate["mob"], base, {"barrage_slash": slash + 1, "weapon_id": player.weapon_id, "targets_hit": hit_rows.size()}, events):
			break
	if gained:
		player.edge = minf(Tuning.EDGE_MAX, player.edge + Tuning.LIGHTNING_BARRAGE_EDGE_PER_HIT)
	if slash + 1 == Weapons.barrage_slashes():
		var again: Dictionary = _target_row(core)
		if not again.is_empty():
			_lightning_strike(core, again, main_counter, mult, events)


## A Dual Dagger finisher connected (the barrage's last slash): a bolt from the sky hits the main target (no telegraph).
func _lightning_strike(core: RefCounted, row: Dictionary, counter: bool, mult: float, events: Array[GameEvent]) -> void:
	var mob: RefCounted = row["mob"]
	var base: float = Tuning.LIGHTNING_STRIKE_DAMAGE * mult
	events.append(GameEvent.new(GameEvent.LIGHTNING_STRIKE, core.tick, {
		"attacker_id": core.player.id, "target_id": mob.id, "position": mob.position, "damage": maxi(1, roundi(base)),
		"kind": &"counter" if counter else &"normal", "combo_index": 0, "source": &"barrage", "barrage_slash": Weapons.barrage_slashes(),
	}))
	core.mobs.hit_mob(core, row["enc"], mob, base, {"lightning_strike": true, "weapon_id": core.player.weapon_id}, events)


# ---- Reaper's Coil (the Chain Scythe's active) ------------------------------------------------------------------------------

var _hooked: int = -1  # the mob the chain caught
var _dragged: Array[int] = []  # it and the mobs clumped around it: all pulled in together


## One phase after the other (player.coil_phase, its tick counted by player.coil_phase_tick): HOOK (the chain flies out in the
## aim direction) -> DRAG (the hooked mob and the clump around it are pulled in, then stunned) -> SPIN (hits every mob around
## the hero, the damage shared out by how many) -> RECOVERY, or on a miss HOOK -> PULL (the hero is pulled to where the chain
## stopped) -> RECOVERY.
func _resolve_reaper_coil(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var tick: int = core.tick
	if player.coil_requested:
		player.coil_requested = false
		if _target_id >= 0 and player.state != PlayerState.STATE_DEAD:
			for attack: SkillAttack in skill_attacks.duplicate():
				if attack.shape != SkillAttack.SHAPE_PROJECTILE:
					skill_attacks.erase(attack)
			_hooked = -1
			_dragged.clear()
			player.start_reaper_coil(tick, events)
		return
	if not _dragged.is_empty() and not (player.coil_running and player.coil_phase == PlayerState.COIL_DRAG):
		_release_dragged(core, events)  # the coil ended mid-drag (the hero died): never leave them held
	if not player.coil_running or player.state != PlayerState.STATE_REAPER_COIL:
		return
	player.coil_phase_tick += 1
	match player.coil_phase:
		PlayerState.COIL_HOOK:
			_coil_hook(core, events)
		PlayerState.COIL_DRAG:
			_coil_drag(core, events)
		PlayerState.COIL_PULL:
			_coil_pull(core)
		PlayerState.COIL_SPIN:
			_coil_spin(core, events)
		PlayerState.COIL_RECOVERY:
			var recovery: int = Tuning.REAPER_COIL_RECOVERY_TICKS if player.coil_hooked else Tuning.REAPER_COIL_PULL_RECOVERY_TICKS
			if player.coil_phase_tick >= recovery:
				player.end_reaper_coil(tick, events, &"complete" if player.coil_hooked else &"missed")


## HOOK: the chain's tip is coil_phase_tick * REAPER_COIL_HOOK_SPEED px out. The first thing along the whole chain decides: a
## mob (hooked, DRAG next), a solid or the scene's edge (missed, PULL next); nothing yet within range: it keeps flying.
func _coil_hook(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var origin: Vector2 = player.coil_from
	var dir: Vector2 = player.coil_dir
	var length: float = float(player.coil_phase_tick) * Tuning.REAPER_COIL_HOOK_SPEED
	var contact: Dictionary = _chain_contact(core, origin, dir, length)
	var point: Vector2 = origin + dir * float(contact["distance"])
	player.coil_target = point
	var kind: StringName = contact["kind"]
	if kind == &"":
		return
	if kind == &"boss":
		var row: Dictionary = contact["row"]
		var mob: RefCounted = row["mob"]
		_hooked = mob.id
		player.coil_hooked = true
		player.coil_drag_from = mob.position
		var cancelled: StringName = &""
		if mob.is_attacking():
			cancelled = mob.telegraph.attack if mob.telegraph != null else &"attack"
		# the clump: every living mob close to the hooked one comes with it
		_dragged.clear()
		for other: Dictionary in core.mobs.living():
			if other["mob"].id == mob.id or other["mob"].position.distance_to(mob.position) <= Tuning.CLUMP_RADIUS:
				var held: RefCounted = other["mob"]
				held.clear_telegraph()
				held.dragged = true
				held.set_state(&"hurt")
				_dragged.append(held.id)
				if other["enc"].state == MobField.DORMANT:
					core.mobs._wake(core, other["enc"], events)
		events.append(GameEvent.new(GameEvent.REAPER_COIL_HOOKED, core.tick, {
			"entity_id": player.id, "target_id": mob.id, "from": origin, "to": point, "cancelled_attack": cancelled, "clump": _dragged.size(),
		}))
		player.set_coil_phase(PlayerState.COIL_DRAG)
	else:
		events.append(GameEvent.new(GameEvent.REAPER_COIL_MISSED, core.tick, {
			"entity_id": player.id, "from": origin, "to": point, "blocked_by": kind,
		}))
		player.set_coil_phase(PlayerState.COIL_PULL)


## What a chain of `length` px from `origin` in unit direction `dir` touches first: {"kind", "distance"} (and "row" for a mob).
## kind is `boss` (a mob, widened by half the chain width: the name is the one the hero's own code and the drawing know),
## `prop` (a solid), `wall` (the scene's edge), `range` (REAPER_COIL_HOOK_RANGE) or empty (nothing yet: distance is the tip).
func _chain_contact(core: RefCounted, origin: Vector2, dir: Vector2, length: float) -> Dictionary:
	var half: float = Tuning.REAPER_COIL_CHAIN_WIDTH * 0.5
	var wall: float = _ray_scene_exit(core, origin, dir)
	var limit: float = minf(Tuning.REAPER_COIL_HOOK_RANGE, wall)
	var reach: float = minf(length, limit)
	var kind: StringName = &""
	var best: float = INF
	var best_row: Dictionary = {}
	for row: Dictionary in core.mobs.living():
		var to_mob: float = ray_circle_entry(origin, dir, row["mob"].position, float(row["mob"].radius) + half)
		if to_mob >= 0.0 and to_mob <= reach and to_mob < best:
			kind = &"boss"
			best = to_mob
			best_row = row
	for obstacle: Obstacle in core.obstacles:
		var to_prop: float = ray_circle_entry(origin, dir, obstacle.center, obstacle.radius + half)
		if to_prop >= 0.0 and to_prop <= reach and to_prop < best:
			kind = &"prop"
			best = to_prop
			best_row = {}
	if kind != &"":
		var out: Dictionary = {"kind": kind, "distance": best}
		if not best_row.is_empty():
			out["row"] = best_row
		return out
	if length >= limit:
		return {"kind": &"wall" if wall < Tuning.REAPER_COIL_HOOK_RANGE else &"range", "distance": limit}
	return {"kind": &"", "distance": reach}


## Distance along the ray from `origin` (unit `dir`) at which it first comes within `radius` of `center`; 0 when it starts
## inside, -1 when it never does.
static func ray_circle_entry(origin: Vector2, dir: Vector2, center: Vector2, radius: float) -> float:
	var to_center: Vector2 = center - origin
	var dist_sq: float = to_center.length_squared()
	if dist_sq <= radius * radius:
		return 0.0
	var along: float = to_center.dot(dir)
	if along <= 0.0:
		return -1.0
	var off_sq: float = dist_sq - along * along
	if off_sq > radius * radius:
		return -1.0
	return along - sqrt(radius * radius - off_sq)


## How far the ray from `origin` (inside the scene) in unit `dir` goes before it leaves the walkable area.
func _ray_scene_exit(core: RefCounted, origin: Vector2, dir: Vector2) -> float:
	var low: Vector2 = Vector2(core.margin, core.margin)
	var high: Vector2 = core.size - low
	var exit: float = INF
	if dir.x > 0.0001:
		exit = minf(exit, (high.x - origin.x) / dir.x)
	elif dir.x < -0.0001:
		exit = minf(exit, (low.x - origin.x) / dir.x)
	if dir.y > 0.0001:
		exit = minf(exit, (high.y - origin.y) / dir.y)
	elif dir.y < -0.0001:
		exit = minf(exit, (low.y - origin.y) / dir.y)
	return maxf(0.0, exit)


## DRAG: pull the hooked mob and its clump REAPER_COIL_DRAG_SPEED px toward the hero (through the solids) until the hooked one is
## adjacent. It ends when it arrived, a tick gains less than REAPER_COIL_DRAG_BLOCKED_PX, or after REAPER_COIL_DRAG_MAX_TICKS;
## then they are stunned (exposed) and the spin begins.
func _coil_drag(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var main: Dictionary = _find_mob(core, _hooked)
	if main.is_empty():
		player.set_coil_phase(PlayerState.COIL_SPIN)
		return
	var main_mob: RefCounted = main["mob"]
	var gained: float = 0.0
	var arrived: bool = false
	for id: int in _dragged:
		var row: Dictionary = _find_mob(core, id)
		if row.is_empty():
			continue
		var mob: RefCounted = row["mob"]
		var goal: float = float(mob.radius) + Tuning.PLAYER_RADIUS + Tuning.REAPER_COIL_DRAG_GAP
		var before: Vector2 = mob.position
		var dist: float = before.distance_to(player.position)
		if dist > goal + 0.01:
			var step: float = minf(Tuning.REAPER_COIL_DRAG_SPEED, dist - goal)
			var wanted: Vector2 = before + (player.position - before) / dist * step
			mob.position = core.clamp_to_scene(Collision.move_resolved(core.obstacles, before, wanted, float(mob.radius)))
			if id == _hooked:
				gained = dist - mob.position.distance_to(player.position)
		var to_hero: Vector2 = player.position - mob.position
		if to_hero.length_squared() > 0.0001:
			mob.facing = to_hero.normalized()
		if id == _hooked:
			arrived = mob.position.distance_to(player.position) <= goal + 0.01
	var to_main: Vector2 = main_mob.position - player.position
	if to_main.length_squared() > 0.0001:
		player.facing = to_main.normalized()
		player.coil_target = main_mob.position - player.facing * float(main_mob.radius)
	if arrived or gained < Tuning.REAPER_COIL_DRAG_BLOCKED_PX or player.coil_phase_tick >= Tuning.REAPER_COIL_DRAG_MAX_TICKS:
		_release_dragged(core, events)
		events.append(GameEvent.new(GameEvent.REAPER_COIL_DRAG, core.tick, {
			"entity_id": player.id, "target_id": main_mob.id, "from": player.coil_drag_from, "to": main_mob.position,
			"ticks": player.coil_phase_tick, "stagger_ticks": Tuning.MOB_STAGGER_TICKS,
		}))
		player.set_coil_phase(PlayerState.COIL_SPIN)


## Let go of everything the chain held: each is stunned and exposed for the usual stagger.
func _release_dragged(core: RefCounted, events: Array[GameEvent]) -> void:
	for id: int in _dragged:
		var row: Dictionary = _find_mob(core, id)
		if row.is_empty():
			continue
		var mob: RefCounted = row["mob"]
		mob.dragged = false
		mob.set_state(&"stagger")
		events.append(GameEvent.new(GameEvent.MOB_STAGGERED, core.tick, {"scene": core.scene_id, "mob_id": mob.id, "reason": &"coil", "position": mob.position}))
	_dragged.clear()


## PULL (missed hook): move the hero REAPER_COIL_PULL_SPEED px toward the anchor (coil_target) through the solids, never into a
## mob. Ends on arrival, when blocked, or after Weapons.reaper_coil_pull_max_ticks().
func _coil_pull(core: RefCounted) -> void:
	var player: PlayerState = core.player
	var anchor: Vector2 = player.coil_target
	var before: Vector2 = player.position
	var dist: float = before.distance_to(anchor)
	var done: bool = dist <= Tuning.REAPER_COIL_DRAG_BLOCKED_PX
	if not done:
		var wanted: Vector2 = before + (anchor - before) / dist * minf(Tuning.REAPER_COIL_PULL_SPEED, dist)
		var moved: Vector2 = core.clamp_to_scene(Collision.move_resolved(core.obstacles, before, wanted, Tuning.PLAYER_RADIUS))
		for row: Dictionary in core.mobs.living():
			if moved.distance_to(row["mob"].position) < float(row["mob"].radius) + Tuning.PLAYER_RADIUS:
				moved = before  # a mob stands in the way: stop here
		player.position = moved
		var left: float = moved.distance_to(anchor)
		done = left <= Tuning.REAPER_COIL_DRAG_BLOCKED_PX or dist - left < Tuning.REAPER_COIL_DRAG_BLOCKED_PX
	if done or player.coil_phase_tick >= Weapons.reaper_coil_pull_max_ticks():
		player.set_coil_phase(PlayerState.COIL_RECOVERY)


## SPIN: a full circle around the hero. Spin hit k lands on spin tick Weapons.reaper_coil_spin_hit_tick(k) and hits every living
## mob whose edge is within REAPER_COIL_SPIN_RADIUS, each for the damage shared out by how many there are.
func _coil_spin(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var held: Dictionary = _find_mob(core, _hooked)
	if not held.is_empty():
		var to_held: Vector2 = held["mob"].position - player.position
		if to_held.length_squared() > 0.0001:
			player.facing = to_held.normalized()
	var next_hit: int = player.coil_spin_hit + 1
	if next_hit <= Tuning.REAPER_COIL_SPIN_HITS and player.coil_phase_tick == Weapons.reaper_coil_spin_hit_tick(next_hit):
		player.coil_spin_hit = next_hit
		var rows: Array[Dictionary] = []
		for row: Dictionary in core.mobs.living():
			if player.position.distance_to(row["mob"].position) - float(row["mob"].radius) <= Tuning.REAPER_COIL_SPIN_RADIUS:
				rows.append(row)
		events.append(GameEvent.new(GameEvent.REAPER_COIL_SPIN, core.tick, {
			"entity_id": player.id, "hit_index": next_hit, "position": player.position,
			"radius": Tuning.REAPER_COIL_SPIN_RADIUS, "connects": not rows.is_empty(),
		}))
		var base: float = Tuning.ATTACK_DAMAGE * Tuning.REAPER_COIL_SPIN_DAMAGE_MULT * player.damage_mult() * core.damage_mult() * multi_hit_mult(rows.size())
		var gained: bool = false
		for row: Dictionary in rows:
			gained = gained or not row["mob"].is_exposed()
			if core.mobs.hit_mob(core, row["enc"], row["mob"], base, {"weapon_id": player.weapon_id, "reaper_coil_hit": next_hit, "targets_hit": rows.size()}, events):
				break
		if gained:
			player.edge = minf(Tuning.EDGE_MAX, player.edge + Tuning.REAPER_COIL_EDGE_PER_HIT)
	if player.coil_phase_tick >= Tuning.REAPER_COIL_SPIN_TICKS:
		player.set_coil_phase(PlayerState.COIL_RECOVERY)


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
