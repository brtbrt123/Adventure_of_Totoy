extends RefCounted
## The combat vertical slice: one room, the player (sword) against the Mossbound Colossus.
## No rendering. Presentation calls step() once per 60 Hz tick, then reads snapshot() and last_events.
## Same seed + same inputs => same results (deterministic).

const Tuning := preload("res://core/tuning.gd")
const InputFrame := preload("res://core/input_frame.gd")
const GameEvent := preload("res://core/game_event.gd")
const Telegraph := preload("res://core/telegraph.gd")
const Snapshots := preload("res://core/snapshots.gd")
const PlayerState := preload("res://core/player.gd")
const BossState := preload("res://core/boss.gd")
const SkillAttack := preload("res://core/skill_attack.gd")
const Obstacle := preload("res://core/obstacle.gd")
const ArenaLayout := preload("res://core/arena_layout.gd")
const Weapons := preload("res://core/weapons.gd")
const Aspects := preload("res://core/aspects.gd")
const Lantern := preload("res://core/lantern.gd")
const Echo := preload("res://core/echo.gd")
const Collision := preload("res://core/collision.gd")

const RESULT_PLAYING: StringName = &"playing"
const RESULT_VICTORY: StringName = &"victory"
const RESULT_DEFEAT: StringName = &"defeat"

signal event_emitted(event: GameEvent)

var tick: int = 0
var result: StringName = RESULT_PLAYING
## Ticks since the fight ended (0 while playing). The simulation is frozen after the result, but this keeps
## counting so presentation can play end animations (the hero's fall, a victory pose) from it.
var result_ticks: int = 0
var player: PlayerState = PlayerState.new()
var boss: BossState = BossState.new()
## Events produced by the most recent step(), in order.
var last_events: Array[GameEvent] = []

## Live skill attacks (melee arcs, dash lanes, travelling projectiles). A projectile outlives the player's state.
var skill_attacks: Array[SkillAttack] = []

## The solid props of the ruins (pillars, trees, boulders): the player and the boss cannot walk through them.
var obstacles: Array[Obstacle] = ArenaLayout.build()

## Spirit Lanterns in the world (at most one per player; a new one replaces the old one).
var lanterns: Array[Lantern] = []
## Phantom Cut echoes waiting to land, in queue order: {land_tick, base, posture, combo_index, weapon_id, hit_tick}.
var phantom_echoes: Array[Dictionary] = []
## Echo Step anchors in the world (at most one per player).
var echoes: Array[Echo] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_attack_id: int = 1
var _next_lantern_id: int = 1
var _next_echo_id: int = 1


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func step(input: InputFrame) -> void:
	last_events = []
	if result != RESULT_PLAYING:
		result_ticks += 1
		return
	tick += 1
	var events: Array[GameEvent] = []
	var player_before: Vector2 = player.position
	player.barrage_target_alive = boss.state != BossState.STATE_DEAD
	player.echo_exists = _player_echo() != null
	player.step(input, tick, events)
	player.position = move_resolved(player_before, player.position, Tuning.PLAYER_RADIUS)
	_place_echo(events)
	_resolve_lightning_barrage(events)
	_resolve_reaper_coil(events)
	if player.ward_release_pending:
		_release_ward(&"expired", events)
	_resolve_echo_recall(events)
	_resolve_player_attack(events)
	_resolve_phantom_echoes(events)
	_spawn_released_skill(events)
	var boss_before: Vector2 = boss.position
	boss.step(tick, player.position, _rng, events)
	boss.position = move_resolved(boss_before, boss.position, Tuning.BOSS_RADIUS)
	_resolve_telegraphs(events)
	_clamp_to_arena()
	_resolve_skill_attacks(player_before, events)
	_separate_from_boss()
	_resolve_lanterns(events)
	if player.state == PlayerState.STATE_DEAD:
		for echo: Echo in echoes.duplicate():
			_remove_echo(echo, &"death", events)
	if boss.state == BossState.STATE_DEAD or player.state == PlayerState.STATE_DEAD:
		phantom_echoes.clear()  # nobody left to hit, or nobody left to echo
	_check_result(events)
	last_events = events
	for event: GameEvent in events:
		event_emitted.emit(event)


## Start the fight with a saved loadout (SaveProfile: weapon_id, equipped_aspects). Call it right after new(), before
## the first step. Unknown weapons and invalid aspect lists are ignored (the defaults stay).
func apply_profile(profile: Object) -> void:
	var weapon: Variant = profile.get("weapon_id")
	if weapon is StringName and Weapons.is_known(weapon):
		player.weapon_id = weapon
	var aspects: Variant = profile.get("equipped_aspects")
	if aspects is Array:
		player.set_equipped_aspects(aspects)


func snapshot() -> Snapshots.GameSnapshot:
	var snap: Snapshots.GameSnapshot = Snapshots.GameSnapshot.new()
	snap.tick = tick
	snap.result = result
	snap.result_ticks = result_ticks
	snap.player = _player_snapshot()
	snap.entities.append(_boss_snapshot())
	for telegraph: Telegraph in boss.telegraphs:
		var t: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
		t.id = telegraph.id
		t.owner_id = telegraph.owner_id
		t.attack = telegraph.attack
		t.kind = telegraph.kind
		t.shape = telegraph.shape
		t.center = telegraph.center
		t.muzzle = telegraph.muzzle
		t.direction = telegraph.direction
		t.size = telegraph.size
		t.inner_size = telegraph.inner_size
		t.half_angle = telegraph.half_angle
		t.width = telegraph.width
		t.start_tick = telegraph.start_tick
		t.hit_tick = telegraph.hit_tick
		t.end_tick = telegraph.end_tick
		snap.telegraphs.append(t)
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
	for obstacle: Obstacle in obstacles:
		var o: Snapshots.ObstacleSnapshot = Snapshots.ObstacleSnapshot.new()
		o.id = obstacle.id
		o.visual_id = obstacle.visual_id
		o.feet = obstacle.feet
		o.visual_scale = obstacle.visual_scale
		o.center = obstacle.center
		o.radius = obstacle.radius
		snap.obstacles.append(o)
	var hud: Snapshots.HudSnapshot = Snapshots.HudSnapshot.new()
	hud.player_hp = player.hp
	hud.player_max_hp = Tuning.PLAYER_MAX_HP
	hud.dash_cooldown_ticks = player.dash_cooldown
	hud.dash_cooldown_max = Tuning.DASH_COOLDOWN_TICKS
	hud.edge = player.edge
	hud.edge_max = Tuning.EDGE_MAX
	hud.boss_hp = boss.hp
	hud.boss_max_hp = Tuning.BOSS_MAX_HP
	hud.boss_posture = boss.posture
	hud.boss_posture_max = Tuning.BOSS_POSTURE_MAX
	hud.counter_window_ticks_left = boss.broken_ticks_left if boss.state == BossState.STATE_BROKEN else 0
	hud.skill_cooldown_ticks = player.skill_cooldowns.duplicate()
	hud.equipped_aspects = player.equipped_aspects.duplicate()
	for aspect: StringName in Aspects.ALL:
		hud.aspect_cooldowns[aspect] = player.aspect_cooldowns.get(aspect, 0)
	for i: int in player.equipped_aspects.size():
		hud.aspect_slots.append(_aspect_slot_row(i + 1, player.equipped_aspects[i]))
	hud.phantom_ticks_left = player.phantom_ticks_left
	hud.phantom_duration = Tuning.PHANTOM_CUT_DURATION_TICKS
	hud.retaliate_ticks_left = player.retaliate_ticks
	hud.weapon_buff_duration = Weapons.active_duration(player.weapon_id)
	hud.weapon_buff_cooldown_ticks = player.buff_cooldown
	hud.weapon_buff_cooldown_max = Weapons.active_cooldown(player.weapon_id)
	hud.weapon_buff_edge_cost = Weapons.active_edge_cost(player.weapon_id)
	for weapon: StringName in Weapons.IDS:
		hud.weapon_cooldowns[weapon] = player.active_cooldowns.get(weapon, 0)
	hud.weapon_swap_lockout_ticks = player.swap_lockout
	hud.weapon_swap_lockout_max = Tuning.WEAPON_SWAP_LOCKOUT_TICKS
	snap.hud = hud
	return snap


## One HUD row for skill slot `slot` (1-3) holding `aspect`: what to draw on the Z/X/C icon.
func _aspect_slot_row(slot: int, aspect: StringName) -> Dictionary:
	var running: bool = false
	var ticks_left: int = 0
	match aspect:
		Aspects.PHANTOM_CUT:
			running = player.phantom_ticks_left > 0
			ticks_left = player.phantom_ticks_left
		Aspects.SPIRIT_LANTERN:
			var lantern: Lantern = _player_lantern()
			running = lantern != null
			ticks_left = maxi(0, lantern.end_tick() - tick) if lantern != null else 0
		Aspects.SPRINT:
			running = player.sprint_ticks_left > 0
			ticks_left = player.sprint_ticks_left
		Aspects.ECHO_STEP:
			var echo: Echo = _player_echo()
			running = echo != null
			ticks_left = maxi(0, echo.due_tick() - tick) if echo != null else 0
		Aspects.STONE_WARD:
			running = player.state == PlayerState.STATE_WARD
			ticks_left = player.ward_ticks_left if running else 0
		_:
			running = player.skill_id == aspect
	return {
		"slot": slot, "aspect_id": aspect, "name": Aspects.display_name(aspect), "kind": Aspects.kind(aspect),
		"edge_cost": Aspects.edge_cost(aspect), "cooldown_ticks": int(player.aspect_cooldowns.get(aspect, 0)),
		"cooldown_max": Aspects.cooldown(aspect), "running": running, "ticks_left": ticks_left,
		"duration": Aspects.duration(aspect), "needs_retaliation": Aspects.needs_retaliation(aspect),
		"stored": player.ward_stored if aspect == Aspects.STONE_WARD and running else 0,
	}


func _player_lantern() -> Lantern:
	for lantern: Lantern in lanterns:
		if lantern.owner_id == player.id:
			return lantern
	return null


func _player_snapshot() -> Snapshots.EntitySnapshot:
	var e: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	e.id = player.id
	e.visual_id = PlayerState.VISUAL_ID
	e.state = player.state
	e.state_ticks = player.state_ticks
	e.position = player.position
	e.facing = player.facing
	e.hp = player.hp
	e.max_hp = Tuning.PLAYER_MAX_HP
	e.invulnerable = player.is_invulnerable()
	e.combo_index = player.combo_index
	e.skill_id = player.skill_id
	e.weapon_id = player.weapon_id
	e.weapon_buff_active = player.is_buff_active()
	e.weapon_buff_ticks_left = player.buff_ticks
	e.attack_speed_mult = player.swing_speed_mult if String(player.state).begins_with("attack_") else player.attack_speed_mult()
	e.weapon_form = player.active_form()
	e.move_speed_mult = player.move_speed_mult()
	e.combo_max = player.combo_max()
	e.lightning_blink_index = player.last_blink_direction
	e.lightning_blink_tick = player.last_blink_tick
	e.lightning_blink_from = player.last_blink_from
	e.lightning_blink_to = player.last_blink_to
	e.lightning_barrage_slash = player.barrage_slash if player.barrage_running else 0
	e.lightning_barrage_slash_tick = player.barrage_slash_tick if player.barrage_running else -1
	e.reaper_coil_phase = player.coil_phase if player.coil_running else &""
	e.reaper_coil_phase_tick = player.coil_phase_tick if player.coil_running else 0
	e.reaper_coil_from = player.position if player.coil_running else Vector2.ZERO
	e.reaper_coil_target = player.coil_target if player.coil_running else Vector2.ZERO
	e.reaper_coil_spin_hit = player.coil_spin_hit if player.coil_running else 0
	e.equipped_aspects = player.equipped_aspects.duplicate()
	e.phantom_ticks_left = player.phantom_ticks_left
	e.phantom_pending_echoes = phantom_echoes.size()
	e.sprint_ticks_left = player.sprint_ticks_left
	e.echo_invuln_ticks = player.echo_invuln_ticks()
	e.ward_ticks_left = player.ward_ticks_left if player.state == PlayerState.STATE_WARD else 0
	e.ward_stored = player.ward_stored if player.state == PlayerState.STATE_WARD else 0
	return e


func _boss_snapshot() -> Snapshots.EntitySnapshot:
	var e: Snapshots.EntitySnapshot = Snapshots.EntitySnapshot.new()
	e.id = boss.id
	e.visual_id = BossState.VISUAL_ID
	e.state = boss.state
	e.state_ticks = boss.state_ticks
	e.position = boss.position
	e.facing = boss.facing
	e.hp = boss.hp
	e.max_hp = Tuning.BOSS_MAX_HP
	e.posture = boss.posture
	e.posture_max = Tuning.BOSS_POSTURE_MAX
	e.dragged = boss.dragged
	e.stagger_ticks_left = boss.stagger_ticks_left if boss.state == BossState.STATE_STAGGERED else 0
	return e


## The normal weapon swing (skills are resolved from their SkillAttack objects instead). Reach, damage and Edge gain come
## from the equipped weapon's tables (core/weapons.gd). The Dual Dagger's last swing also calls a lightning strike.
func _resolve_player_attack(events: Array[GameEvent]) -> void:
	if player.attack_hit_done or boss.state == BossState.STATE_DEAD or player.state != PlayerState.STATE_ATTACK_ACTIVE:
		return
	var weapon: StringName = player.weapon_id
	var swing: int = player.combo_index - 1
	var to_boss: Vector2 = boss.position - player.position
	var dist: float = to_boss.length()
	if dist - Tuning.BOSS_RADIUS > Tuning.ATTACK_RANGE * Weapons.range_mults(weapon)[swing]:
		return
	if dist > 0.0001 and player.facing.dot(to_boss / dist) < Weapons.arc_dot(weapon):
		return
	player.attack_hit_done = true
	var base: float = Tuning.ATTACK_DAMAGE * Weapons.damage_mults(weapon)[swing] * player.swing_damage_mult
	var posture: float = Weapons.swing_posture(weapon, player.combo_index)
	var counter: bool = _land_player_hit(base, Weapons.edge_per_hit(weapon), {"combo_index": player.combo_index, "weapon_id": weapon}, events, posture)
	if player.phantom_ticks_left > 0:
		phantom_echoes.append({
			"land_tick": tick + Tuning.PHANTOM_CUT_DELAY_TICKS, "hit_tick": tick, "combo_index": player.combo_index, "weapon_id": weapon,
			"base": base * Tuning.PHANTOM_CUT_DAMAGE_MULT, "posture": posture * Tuning.PHANTOM_CUT_POSTURE_MULT,
		})
	if Weapons.has_lightning_finisher(weapon) and player.combo_index == Weapons.combo_max(weapon):
		_lightning_strike(counter, player.swing_damage_mult, {"combo_index": player.combo_index, "source": &"swing"}, events)


## Phantom Cut echoes whose time has come land on the boss where it stands now (no range check, the phantom steps
## in), in queue order. An echo is its own hit: armored (x ARMOR_DAMAGE_FACTOR, the queued posture) or a counter while
## the posture is broken (x COUNTER_DAMAGE_MULT, no Edge bonus); it never gains or spends Edge, never touches the
## combo or the swing's one-hit rule and never calls a finisher. Events: phantom_echo, then attack_hit with echo true.
func _resolve_phantom_echoes(events: Array[GameEvent]) -> void:
	while not phantom_echoes.is_empty() and int(phantom_echoes[0]["land_tick"]) <= tick:
		var echo: Dictionary = phantom_echoes.pop_front()
		if boss.state == BossState.STATE_DEAD or player.state == PlayerState.STATE_DEAD:
			phantom_echoes.clear()
			return
		var counter: bool = boss.state == BossState.STATE_BROKEN
		var base: float = echo["base"]
		var damage: int = roundi(base * Tuning.COUNTER_DAMAGE_MULT) if counter else maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR))
		events.append(GameEvent.new(GameEvent.PHANTOM_ECHO, tick, {
			"entity_id": player.id, "target_id": boss.id, "damage": damage, "swing_combo_index": echo["combo_index"],
			"position": boss.position, "weapon_id": echo["weapon_id"], "hit_tick": echo["hit_tick"],
			"kind": &"counter" if counter else &"normal",
		}))
		events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
			"attacker_id": player.id, "target_id": boss.id, "damage": damage, "kind": &"counter" if counter else &"normal",
			"position": boss.position, "echo": true, "swing_combo_index": echo["combo_index"], "weapon_id": echo["weapon_id"],
		}))
		boss.take_damage(damage, tick, events, player.id)
		if not counter:
			boss.add_posture(float(echo["posture"]), tick, events)


## Spirit Lanterns: pulse k lands on placement + k x SPIRIT_LANTERN_PULSE_INTERVAL_TICKS (after this tick's movement and
## the boss's hits); the player inside the radius heals and gains Edge (both capped). After the last pulse (its final
## tick) the lantern expires. The player's death removes them (reason death).
func _resolve_lanterns(events: Array[GameEvent]) -> void:
	if lanterns.is_empty():
		return
	if player.state == PlayerState.STATE_DEAD:
		for lantern: Lantern in lanterns.duplicate():
			_remove_lantern(lantern, &"death", events)
		return
	for lantern: Lantern in lanterns.duplicate():
		if lantern.pulses_done < Tuning.SPIRIT_LANTERN_PULSES and tick >= lantern.pulse_tick(lantern.pulses_done + 1):
			lantern.pulses_done += 1
			var inside: bool = lantern.covers(player.position)
			var healed: int = 0
			var gained: float = 0.0
			if inside:
				healed = mini(Tuning.SPIRIT_LANTERN_HEAL_PER_PULSE, Tuning.PLAYER_MAX_HP - player.hp)
				gained = minf(Tuning.SPIRIT_LANTERN_EDGE_PER_PULSE, Tuning.EDGE_MAX - player.edge)
				player.hp += healed
				player.edge += gained
			events.append(GameEvent.new(GameEvent.LANTERN_PULSE, tick, {
				"lantern_id": lantern.id, "entity_id": lantern.owner_id, "position": lantern.position, "radius": lantern.radius,
				"pulse_index": lantern.pulses_done, "healed": healed, "edge_gained": gained, "player_inside": inside,
			}))
		if tick >= lantern.end_tick():
			_remove_lantern(lantern, &"expired", events)


## The lantern skill reached skill_active: place the lantern at the player's feet (replacing the player's old one) and
## start the aspect's cooldown.
func _place_lantern(events: Array[GameEvent]) -> void:
	for old: Lantern in lanterns.duplicate():
		if old.owner_id == player.id:
			_remove_lantern(old, &"replaced", events)
	var lantern: Lantern = Lantern.new()
	lantern.id = _next_lantern_id
	_next_lantern_id += 1
	lantern.owner_id = player.id
	lantern.position = player.position
	lantern.placed_tick = tick
	lanterns.append(lantern)
	player.aspect_cooldowns[Aspects.SPIRIT_LANTERN] = Aspects.cooldown(Aspects.SPIRIT_LANTERN)
	events.append(GameEvent.new(GameEvent.LANTERN_PLACED, tick, {
		"lantern_id": lantern.id, "entity_id": player.id, "position": lantern.position, "radius": lantern.radius,
		"duration": Tuning.SPIRIT_LANTERN_DURATION_TICKS, "pulses": Tuning.SPIRIT_LANTERN_PULSES,
		"pulse_interval": Tuning.SPIRIT_LANTERN_PULSE_INTERVAL_TICKS,
	}))


func _remove_lantern(lantern: Lantern, reason: StringName, events: Array[GameEvent]) -> void:
	lanterns.erase(lantern)
	events.append(GameEvent.new(GameEvent.LANTERN_EXPIRED, tick, {
		"lantern_id": lantern.id, "entity_id": lantern.owner_id, "position": lantern.position, "reason": reason,
		"pulses_done": lantern.pulses_done,
	}))


func _player_echo() -> Echo:
	for echo: Echo in echoes:
		if echo.owner_id == player.id:
			return echo
	return null


## Echo Step was pressed this tick (Player.echo_requested): place the anchor where the player stands after this tick's
## movement, kept in the arena and out of the props (arena_point).
func _place_echo(events: Array[GameEvent]) -> void:
	if not player.echo_requested:
		return
	player.echo_requested = false
	if player.state == PlayerState.STATE_DEAD:
		return
	var echo: Echo = Echo.new()
	echo.id = _next_echo_id
	_next_echo_id += 1
	echo.owner_id = player.id
	echo.position = arena_point(player.position, Tuning.PLAYER_RADIUS)
	echo.placed_tick = tick
	echoes.append(echo)
	events.append(GameEvent.new(GameEvent.ECHO_PLACED, tick, {
		"echo_id": echo.id, "entity_id": player.id, "position": echo.position, "duration": Tuning.ECHO_STEP_DELAY_TICKS,
	}))


## The player's echo is due (placed + ECHO_STEP_DELAY_TICKS, or later while a barrage or coil still runs): teleport the
## player back to it. A raised ward releases first (where the player stood). Whatever else ran stops (Player.echo_recall):
## melee skill attacks that follow the player (arc, lane) end with it, a projectile flies on. The arrival spot is the
## anchor kept in the arena and out of props; if the boss stands on it, the nearest free spot next to the boss.
func _resolve_echo_recall(events: Array[GameEvent]) -> void:
	var echo: Echo = _player_echo()
	if echo == null or tick < echo.due_tick() or player.state == PlayerState.STATE_DEAD:
		return
	if player.state == PlayerState.STATE_LIGHTNING_BARRAGE or player.state == PlayerState.STATE_REAPER_COIL:
		return  # never interrupted: the recall waits until it ends
	var from: Vector2 = player.position
	if player.state == PlayerState.STATE_WARD:
		player.end_ward_early()
		_release_ward(&"recall", events)
	for attack: SkillAttack in skill_attacks.duplicate():
		if attack.shape != SkillAttack.SHAPE_PROJECTILE:
			skill_attacks.erase(attack)
	var spot: Vector2 = arena_point(echo.position, Tuning.PLAYER_RADIUS)
	var min_dist: float = Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS
	if boss.state != BossState.STATE_DEAD and spot.distance_to(boss.position) < min_dist:
		var away: Vector2 = spot - boss.position
		if away.length_squared() < 0.0001:
			away = from - boss.position
		spot = _free_spot(away.normalized() if away.length_squared() > 0.0001 else Vector2.LEFT, min_dist)
	player.echo_recall(spot)
	echoes.erase(echo)
	events.append(GameEvent.new(GameEvent.ECHO_RECALL, tick, {
		"echo_id": echo.id, "entity_id": player.id, "from": from, "to": spot, "anchor": echo.position,
		"invuln_ticks": Tuning.ECHO_STEP_INVULN_TICKS, "waited": tick - echo.due_tick(),
	}))


func _remove_echo(echo: Echo, reason: StringName, events: Array[GameEvent]) -> void:
	echoes.erase(echo)
	events.append(GameEvent.new(GameEvent.ECHO_EXPIRED, tick, {
		"echo_id": echo.id, "entity_id": echo.owner_id, "position": echo.position, "reason": reason,
	}))


## The Stone Ward ended (`expired` on its timer, `recall` by an Echo Step): release the shockwave around the player. The
## boss is hit when its circle is within STONE_WARD_RADIUS of the player: (base + stored x mult) x the damage multiplier
## under the skill hit rules (armored: x ARMOR_DAMAGE_FACTOR, posture, Edge gain; counter while the posture is broken:
## x COUNTER_DAMAGE_MULT, no Edge change). Events: ward_released, then on a hit attack_hit (aspect_id stone_ward,
## ward_release true) and the boss's damage_taken.
func _release_ward(reason: StringName, events: Array[GameEvent]) -> void:
	player.ward_release_pending = false
	var stored: int = player.ward_stored
	player.ward_stored = 0
	var hit: bool = boss.state != BossState.STATE_DEAD and player.position.distance_to(boss.position) - Tuning.BOSS_RADIUS <= Tuning.STONE_WARD_RADIUS
	var counter: bool = boss.state == BossState.STATE_BROKEN
	var damage: int = 0
	var base: float = (Tuning.STONE_WARD_BASE_DAMAGE + float(stored) * Tuning.STONE_WARD_STORE_MULT) * player.damage_mult()
	if hit:
		damage = roundi(base * Tuning.COUNTER_DAMAGE_MULT) if counter else maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR))
	events.append(GameEvent.new(GameEvent.WARD_RELEASED, tick, {
		"entity_id": player.id, "position": player.position, "stored": stored, "radius": Tuning.STONE_WARD_RADIUS,
		"damage": damage, "hit": hit, "reason": reason,
	}))
	if not hit:
		return
	if not counter:
		player.edge = minf(Tuning.EDGE_MAX, player.edge + Tuning.STONE_WARD_EDGE_GAIN)
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
		"attacker_id": player.id, "target_id": boss.id, "damage": damage, "kind": &"counter" if counter else &"normal",
		"position": boss.position, "aspect_id": Aspects.STONE_WARD, "ward_release": true,
	}))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(Tuning.STONE_WARD_POSTURE + float(stored) * Tuning.STONE_WARD_POSTURE_PER_STORED, tick, events)


## One player weapon hit on the boss under the normal-hit rules: armored (x ARMOR_DAMAGE_FACTOR, gains `edge_gain`
## Edge, `posture` posture) or, while the boss's posture is broken, a counter (x COUNTER_DAMAGE_MULT plus the
## Edge bonus; spends all Edge). `extra` is merged into the attack_hit event. Returns true for a counter.
func _land_player_hit(base: float, edge_gain: float, extra: Dictionary, events: Array[GameEvent], posture: float = Tuning.NORMAL_HIT_POSTURE) -> bool:
	var counter: bool = boss.state == BossState.STATE_BROKEN
	var damage: int
	if counter:
		damage = roundi(base * Tuning.COUNTER_DAMAGE_MULT + player.edge * Tuning.EDGE_COUNTER_BONUS)
		player.edge = 0.0  # the counter spends all Edge
	else:
		damage = maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR))
		player.edge = minf(Tuning.EDGE_MAX, player.edge + edge_gain)
	var data: Dictionary = {
		"attacker_id": player.id, "target_id": boss.id, "damage": damage,
		"kind": &"counter" if counter else &"normal", "position": boss.position,
	}
	data.merge(extra)
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, data))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(posture, tick, events)
	return counter


## A Dual Dagger finisher connected (swing 4, or the barrage's last slash): a bolt from the sky hits the same boss (no
## telegraph, it always lands). It uses the hit's counter flag (a hit that just broke the posture does not turn the
## bolt into a counter). `extra` (combo_index, source, barrage_slash) is merged into the lightning_strike event.
func _lightning_strike(counter: bool, damage_mult: float, extra: Dictionary, events: Array[GameEvent]) -> void:
	if boss.state == BossState.STATE_DEAD:
		return  # the hit itself finished the boss
	var base: float = Tuning.LIGHTNING_STRIKE_DAMAGE * damage_mult
	var damage: int = roundi(base * Tuning.COUNTER_DAMAGE_MULT) if counter else maxi(1, roundi(base * Tuning.ARMOR_DAMAGE_FACTOR))
	var data: Dictionary = {
		"attacker_id": player.id, "target_id": boss.id, "position": boss.position, "damage": damage,
		"kind": &"counter" if counter else &"normal",
	}
	data.merge(extra)
	events.append(GameEvent.new(GameEvent.LIGHTNING_STRIKE, tick, data))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(Tuning.LIGHTNING_STRIKE_POSTURE, tick, events)


## Lightning Barrage (Dual Dagger active): started on the activation tick when the boss is alive; then, on a fixed
## timeline counted from the activation (player.state_ticks), one blink-slash per side of LIGHTNING_BLINK_ORDER. Ends
## when the timeline is over, the boss dies (boss_dead) or the player dies (death, see Player.die).
func _resolve_lightning_barrage(events: Array[GameEvent]) -> void:
	if player.barrage_requested:
		player.barrage_requested = false
		if boss.state != BossState.STATE_DEAD and player.state != PlayerState.STATE_DEAD:
			# Melee skill attacks that follow the player (arc, lane) stop with whatever the player was doing.
			for attack: SkillAttack in skill_attacks.duplicate():
				if attack.shape != SkillAttack.SHAPE_PROJECTILE:
					skill_attacks.erase(attack)
			player.start_barrage(tick, events)
		return
	if not player.barrage_running or player.state != PlayerState.STATE_LIGHTNING_BARRAGE:
		return
	if boss.state == BossState.STATE_DEAD:
		player.end_barrage(tick, events, &"boss_dead")
		return
	var t: int = player.state_ticks - Tuning.LIGHTNING_BARRAGE_START_DELAY_TICKS
	if t < 0:
		return
	var slash: int = t / Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS
	var phase: int = t % Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS
	if slash < Weapons.barrage_slashes():
		if phase == 0:
			_barrage_blink(slash, events)
		if phase == Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS:
			_barrage_hit(slash, events)
	if boss.state == BossState.STATE_DEAD:
		player.end_barrage(tick, events, &"boss_dead")
	elif player.state_ticks >= Weapons.barrage_total_ticks():
		player.end_barrage(tick, events, &"complete")


## Barrage slash `slash` (0-based) starts: blink to its side of LIGHTNING_BLINK_ORDER. A blocked side falls back to the
## nearest free side this barrage has not used yet (else the nearest free one). No free spot: the slash stays put.
func _barrage_blink(slash: int, events: Array[GameEvent]) -> void:
	player.barrage_slash = slash + 1
	player.barrage_slash_tick = tick
	var wanted: int = Tuning.LIGHTNING_BLINK_ORDER[slash % Tuning.LIGHTNING_BLINK_ORDER.size()]
	var reach: float = Tuning.BOSS_RADIUS + Tuning.ATTACK_RANGE * Weapons.range_mults(player.weapon_id)[0]
	var chosen: int = -1
	var fallback: int = -1
	for offset: int in [0, 1, -1, 2, -2, 3, -3, 4]:
		var index: int = posmod(wanted + offset, 8)
		if not _blink_spot_ok(blink_spot(index), reach):
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
	var spot: Vector2 = blink_spot(chosen)
	var from: Vector2 = player.position
	player.apply_blink(spot, boss.position - spot, chosen, tick)
	events.append(GameEvent.new(GameEvent.LIGHTNING_BLINK, tick, {
		"entity_id": player.id, "from": from, "to": spot, "direction_index": chosen, "target_id": boss.id,
		"barrage_slash": slash + 1,
	}))


## Barrage slash `slash` (0-based) lands: it turns to the boss and hits if the boss is within the dagger's reach (one hit
## per slash, normal-hit rules). The last slash also calls the lightning strike.
func _barrage_hit(slash: int, events: Array[GameEvent]) -> void:
	var to_boss: Vector2 = boss.position - player.position
	var dist: float = to_boss.length()
	if dist > 0.0001:
		player.facing = to_boss / dist
	if dist - Tuning.BOSS_RADIUS > Tuning.ATTACK_RANGE * Weapons.range_mults(player.weapon_id)[0]:
		return
	var mult: float = player.damage_mult()
	var base: float = Tuning.ATTACK_DAMAGE * Tuning.LIGHTNING_BARRAGE_DAMAGE_MULT * mult
	var counter: bool = _land_player_hit(base, Tuning.LIGHTNING_BARRAGE_EDGE_PER_HIT, {"barrage_slash": slash + 1, "weapon_id": player.weapon_id}, events)
	if slash + 1 == Weapons.barrage_slashes():
		_lightning_strike(counter, mult, {"combo_index": 0, "source": &"barrage", "barrage_slash": slash + 1}, events)


## Reaper's Coil (Chain Scythe active): started on the activation tick when the boss is alive; then, one phase after
## the other (player.coil_phase, its tick counted by player.coil_phase_tick): HOOK (the chain flies out) -> DRAG (the
## boss is pulled in, then stunned) -> SPIN (two hits) -> RECOVERY, or on a miss HOOK -> PULL (the player is pulled to
## where the chain stopped) -> RECOVERY. Ends when the timeline is over, the boss dies (boss_dead) or the player dies
## (death, see Player.die).
func _resolve_reaper_coil(events: Array[GameEvent]) -> void:
	if player.coil_requested:
		player.coil_requested = false
		if boss.state != BossState.STATE_DEAD and player.state != PlayerState.STATE_DEAD:
			for attack: SkillAttack in skill_attacks.duplicate():
				if attack.shape != SkillAttack.SHAPE_PROJECTILE:
					skill_attacks.erase(attack)
			player.start_reaper_coil(tick, events)
		return
	if boss.dragged and not (player.coil_running and player.coil_phase == PlayerState.COIL_DRAG):
		boss.end_drag(Tuning.REAPER_COIL_STAGGER_TICKS)  # the coil ended mid-drag (the player died): never leave it held
	if not player.coil_running or player.state != PlayerState.STATE_REAPER_COIL:
		return
	if boss.state == BossState.STATE_DEAD:
		player.end_reaper_coil(tick, events, &"boss_dead")
		return
	player.coil_phase_tick += 1
	match player.coil_phase:
		PlayerState.COIL_HOOK:
			_coil_hook(events)
		PlayerState.COIL_DRAG:
			_coil_drag(events)
		PlayerState.COIL_PULL:
			_coil_pull()
		PlayerState.COIL_SPIN:
			_coil_spin(events)
		PlayerState.COIL_RECOVERY:
			var recovery: int = Tuning.REAPER_COIL_RECOVERY_TICKS if player.coil_hooked else Tuning.REAPER_COIL_PULL_RECOVERY_TICKS
			if player.coil_phase_tick >= recovery:
				player.end_reaper_coil(tick, events, &"complete" if player.coil_hooked else &"missed")
				return
	if player.coil_running and boss.state == BossState.STATE_DEAD:
		player.end_reaper_coil(tick, events, &"boss_dead")


## HOOK: the chain's tip is coil_phase_tick * REAPER_COIL_HOOK_SPEED px out. The first thing along the whole chain
## decides: the boss (hooked, DRAG next), a solid prop or the arena wall (missed, PULL next); nothing yet within range:
## it keeps flying; full range without contact: missed at the tip.
func _coil_hook(events: Array[GameEvent]) -> void:
	var origin: Vector2 = player.coil_from
	var dir: Vector2 = player.coil_dir
	var length: float = float(player.coil_phase_tick) * Tuning.REAPER_COIL_HOOK_SPEED
	var contact: Dictionary = coil_chain_contact(origin, dir, length)
	var point: Vector2 = origin + dir * float(contact["distance"])
	player.coil_target = point
	var kind: StringName = contact["kind"]
	if kind == &"":
		return
	if kind == &"boss":
		player.coil_hooked = true
		player.coil_drag_from = boss.position
		var cancelled: StringName = boss.interrupt_for_drag()
		events.append(GameEvent.new(GameEvent.REAPER_COIL_HOOKED, tick, {
			"entity_id": player.id, "target_id": boss.id, "from": origin, "to": point, "cancelled_attack": cancelled,
		}))
		player.set_coil_phase(PlayerState.COIL_DRAG)
	else:
		events.append(GameEvent.new(GameEvent.REAPER_COIL_MISSED, tick, {
			"entity_id": player.id, "from": origin, "to": point, "blocked_by": kind,
		}))
		player.set_coil_phase(PlayerState.COIL_PULL)


## What a chain of `length` px from `origin` in unit direction `dir` touches first: {"kind", "distance"}. kind is
## `boss` (the boss circle widened by half the chain width), `prop` (a solid prop, widened the same way), `wall` (it
## reached the arena edge), `range` (it reached REAPER_COIL_HOOK_RANGE) or empty (nothing yet: distance is the tip).
func coil_chain_contact(origin: Vector2, dir: Vector2, length: float) -> Dictionary:
	var half: float = Tuning.REAPER_COIL_CHAIN_WIDTH * 0.5
	var wall: float = _ray_arena_exit(origin, dir)
	var limit: float = minf(Tuning.REAPER_COIL_HOOK_RANGE, wall)
	var reach: float = minf(length, limit)
	var kind: StringName = &""
	var best: float = INF
	if boss.state != BossState.STATE_DEAD:
		var to_boss: float = ray_circle_entry(origin, dir, boss.position, Tuning.BOSS_RADIUS + half)
		if to_boss >= 0.0 and to_boss <= reach:
			kind = &"boss"
			best = to_boss
	for obstacle: Obstacle in obstacles:
		var to_prop: float = ray_circle_entry(origin, dir, obstacle.center, obstacle.radius + half)
		if to_prop >= 0.0 and to_prop <= reach and to_prop < best:
			kind = &"prop"
			best = to_prop
	if kind != &"":
		return {"kind": kind, "distance": best}
	if length >= limit:
		return {"kind": &"wall" if wall < Tuning.REAPER_COIL_HOOK_RANGE else &"range", "distance": limit}
	return {"kind": &"", "distance": reach}


## Distance along the ray from `origin` (unit `dir`) at which it first comes within `radius` of `center`; 0 when it
## starts inside, -1 when it never does.
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


## How far the ray from `origin` (inside the arena) in unit `dir` goes before it leaves the walkable arena.
func _ray_arena_exit(origin: Vector2, dir: Vector2) -> float:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
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


## DRAG: pull the boss REAPER_COIL_DRAG_SPEED px toward the player (through the prop sweep, kept in the arena) until
## it is adjacent. It ends when the boss arrived, a tick gains less than REAPER_COIL_DRAG_BLOCKED_PX (props block it)
## or after REAPER_COIL_DRAG_MAX_TICKS; then the boss's stun starts and the spin begins.
func _coil_drag(events: Array[GameEvent]) -> void:
	var goal: float = Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS + Tuning.REAPER_COIL_DRAG_GAP
	var before: Vector2 = boss.position
	var dist: float = before.distance_to(player.position)
	var gained: float = 0.0
	if dist > goal + 0.01:
		var step: float = minf(Tuning.REAPER_COIL_DRAG_SPEED, dist - goal)
		var wanted: Vector2 = before + (player.position - before) / dist * step
		boss.position = arena_point(move_resolved(before, wanted, Tuning.BOSS_RADIUS), Tuning.BOSS_RADIUS)
		gained = dist - boss.position.distance_to(player.position)
	var to_boss: Vector2 = boss.position - player.position
	if to_boss.length_squared() > 0.0001:
		player.facing = to_boss.normalized()
		boss.facing = -player.facing
		player.coil_target = boss.position - player.facing * Tuning.BOSS_RADIUS
	var arrived: bool = to_boss.length() <= goal + 0.01
	if arrived or gained < Tuning.REAPER_COIL_DRAG_BLOCKED_PX or player.coil_phase_tick >= Tuning.REAPER_COIL_DRAG_MAX_TICKS:
		boss.end_drag(Tuning.REAPER_COIL_STAGGER_TICKS)
		events.append(GameEvent.new(GameEvent.REAPER_COIL_DRAG, tick, {
			"entity_id": player.id, "target_id": boss.id, "from": player.coil_drag_from, "to": boss.position,
			"ticks": player.coil_phase_tick, "stagger_ticks": Tuning.REAPER_COIL_STAGGER_TICKS if boss.state == BossState.STATE_STAGGERED else 0,
		}))
		player.set_coil_phase(PlayerState.COIL_SPIN)


## PULL (missed hook): move the player REAPER_COIL_PULL_SPEED px toward the anchor (coil_target) through the prop
## sweep, never into the boss. Ends on arrival, when blocked or after Weapons.reaper_coil_pull_max_ticks().
func _coil_pull() -> void:
	var anchor: Vector2 = player.coil_target
	var before: Vector2 = player.position
	var dist: float = before.distance_to(anchor)
	var done: bool = dist <= Tuning.REAPER_COIL_DRAG_BLOCKED_PX
	if not done:
		var wanted: Vector2 = before + (anchor - before) / dist * minf(Tuning.REAPER_COIL_PULL_SPEED, dist)
		var moved: Vector2 = arena_point(move_resolved(before, wanted, Tuning.PLAYER_RADIUS), Tuning.PLAYER_RADIUS)
		if moved.distance_to(boss.position) < Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS:
			moved = before  # the boss stands in the way: stop here
		player.position = moved
		var left: float = moved.distance_to(anchor)
		done = left <= Tuning.REAPER_COIL_DRAG_BLOCKED_PX or dist - left < Tuning.REAPER_COIL_DRAG_BLOCKED_PX
	if done or player.coil_phase_tick >= Weapons.reaper_coil_pull_max_ticks():
		player.set_coil_phase(PlayerState.COIL_RECOVERY)


## SPIN: a full circle around the player. Spin hit k lands on spin tick Weapons.reaper_coil_spin_hit_tick(k) and
## hits the boss when its edge is within REAPER_COIL_SPIN_RADIUS (normal-hit rules: armor, counter, posture).
func _coil_spin(events: Array[GameEvent]) -> void:
	var to_boss: Vector2 = boss.position - player.position
	if to_boss.length_squared() > 0.0001:
		player.facing = to_boss.normalized()
	var next_hit: int = player.coil_spin_hit + 1
	if next_hit <= Tuning.REAPER_COIL_SPIN_HITS and player.coil_phase_tick == Weapons.reaper_coil_spin_hit_tick(next_hit):
		player.coil_spin_hit = next_hit
		var connects: bool = to_boss.length() - Tuning.BOSS_RADIUS <= Tuning.REAPER_COIL_SPIN_RADIUS
		events.append(GameEvent.new(GameEvent.REAPER_COIL_SPIN, tick, {
			"entity_id": player.id, "hit_index": next_hit, "position": player.position,
			"radius": Tuning.REAPER_COIL_SPIN_RADIUS, "connects": connects,
		}))
		if connects:
			var base: float = Tuning.ATTACK_DAMAGE * Tuning.REAPER_COIL_SPIN_DAMAGE_MULT * player.damage_mult()
			_land_player_hit(base, Tuning.REAPER_COIL_EDGE_PER_HIT, {"weapon_id": player.weapon_id, "reaper_coil_hit": next_hit}, events, Tuning.REAPER_COIL_SPIN_POSTURE)
	if player.coil_phase_tick >= Tuning.REAPER_COIL_SPIN_TICKS:
		player.set_coil_phase(PlayerState.COIL_RECOVERY)


## Where a blink in direction `index` (0-7) would land: next to the boss, kept in the arena and out of solid props.
func blink_spot(index: int) -> Vector2:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	var spot: Vector2 = (boss.position + Weapons.blink_direction(index) * Tuning.LIGHTNING_BLINK_DISTANCE).clamp(low, high)
	return push_out_of_obstacles(spot, Tuning.PLAYER_RADIUS).clamp(low, high)


## A blink spot must be inside the arena, outside the boss and every prop, and within the swing's reach of the boss.
func _blink_spot_ok(spot: Vector2, reach: float) -> bool:
	var dist: float = spot.distance_to(boss.position)
	if dist < Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS or dist > reach:
		return false
	for obstacle: Obstacle in obstacles:
		if spot.distance_to(obstacle.center) < obstacle.radius + Tuning.PLAYER_RADIUS - 0.001:
			return false
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	return spot == spot.clamp(low, high)


## The player just entered skill_active: create the attack that belongs to the skill (once per cast).
func _spawn_released_skill(events: Array[GameEvent]) -> void:
	var skill: StringName = player.pending_release
	if skill == &"":
		return
	player.pending_release = &""
	if skill == PlayerState.SKILL_SPIRIT_LANTERN:
		_place_lantern(events)
		return
	var attack: SkillAttack = SkillAttack.new()
	attack.id = _next_attack_id
	_next_attack_id += 1
	attack.owner_id = player.id
	attack.skill_id = skill
	attack.direction = player.skill_dir
	attack.damage_mult = player.damage_mult()
	attack.start_tick = tick
	attack.position = player.position
	attack.start = player.position
	attack.end = player.position
	match skill:
		PlayerState.SKILL_BREAKING_EDGE:
			attack.shape = SkillAttack.SHAPE_ARC
			attack.size = Tuning.BREAKING_EDGE_RANGE
			attack.arc_dot = Tuning.BREAKING_EDGE_ARC_DOT
			attack.end_tick = tick + Tuning.BREAKING_EDGE_ACTIVE_TICKS - 1
		PlayerState.SKILL_GALE_CUT:
			attack.shape = SkillAttack.SHAPE_LANE
			attack.width = Tuning.GALE_CUT_LANE_WIDTH
			attack.end = player.position + player.skill_dir * Tuning.GALE_CUT_DISTANCE
			attack.end_tick = tick + Tuning.GALE_CUT_ACTIVE_TICKS
		_:
			attack.shape = SkillAttack.SHAPE_PROJECTILE
			attack.width = Tuning.MOON_CLEAVE_WIDTH
			attack.speed = Tuning.MOON_CLEAVE_SPEED
			attack.length = Tuning.MOON_CLEAVE_TRAVEL
			attack.start = player.position + player.skill_dir * Tuning.MOON_CLEAVE_SPAWN_OFFSET
			attack.position = attack.start
			attack.end = attack.start + player.skill_dir * Tuning.MOON_CLEAVE_TRAVEL
			attack.end_tick = tick + ceili(Tuning.MOON_CLEAVE_TRAVEL / Tuning.MOON_CLEAVE_SPEED)
	skill_attacks.append(attack)
	events.append(GameEvent.new(GameEvent.SKILL_RELEASED, tick, {
		"attack_id": attack.id, "entity_id": player.id, "skill_id": skill, "shape": attack.shape,
		"position": attack.position, "direction": attack.direction, "start": attack.start, "end": attack.end,
		"width": attack.width,
	}))


## Advance and test every live skill attack. `player_before` is where the player stood before this tick's
## movement: with the final position it is the segment actually travelled (walls and the solid boss included).
func _resolve_skill_attacks(player_before: Vector2, events: Array[GameEvent]) -> void:
	for attack: SkillAttack in skill_attacks.duplicate():
		var done: bool = false
		match attack.shape:
			SkillAttack.SHAPE_ARC:
				attack.position = player.position
				if _arc_touches_boss(attack):
					_skill_hit(attack, events)
				done = tick >= attack.end_tick
			SkillAttack.SHAPE_LANE:
				attack.position = player.position
				if SkillAttack.segment_touches_circle(player_before, player.position, boss.position, Tuning.BOSS_RADIUS + attack.width * 0.5):
					_skill_hit(attack, events)
				done = player.state != PlayerState.STATE_SKILL_ACTIVE
			_:
				var from: Vector2 = attack.position
				if tick > attack.start_tick:
					var step: float = minf(attack.speed, attack.length - attack.travelled)
					attack.position += attack.direction * step
					attack.travelled += step
				if SkillAttack.segment_touches_circle(from, attack.position, boss.position, Tuning.BOSS_RADIUS + attack.width * 0.5):
					_skill_hit(attack, events)
				done = attack.travelled >= attack.length
		if done:
			skill_attacks.erase(attack)


func _arc_touches_boss(attack: SkillAttack) -> bool:
	var to_boss: Vector2 = boss.position - attack.position
	var dist: float = to_boss.length()
	if dist - Tuning.BOSS_RADIUS > attack.size:
		return false
	return dist <= 0.0001 or attack.direction.dot(to_boss / dist) >= attack.arc_dot


func _skill_hit(attack: SkillAttack, events: Array[GameEvent]) -> void:
	if attack.has_hit(boss.id) or boss.state == BossState.STATE_DEAD:
		return
	attack.hit_targets.append(boss.id)
	var profile: Dictionary = PlayerState.skill_profile(attack.skill_id)
	var counter: bool = boss.state == BossState.STATE_BROKEN
	var damage: int
	if counter:
		damage = roundi(profile["damage"] * attack.damage_mult * Tuning.COUNTER_DAMAGE_MULT)
	else:
		damage = maxi(1, roundi(profile["damage"] * attack.damage_mult * Tuning.ARMOR_DAMAGE_FACTOR))
		player.edge = minf(Tuning.EDGE_MAX, player.edge + profile["edge_gain"])
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
		"attacker_id": player.id, "target_id": boss.id, "damage": damage,
		"kind": &"counter" if counter else &"normal", "position": boss.position,
		"skill_id": attack.skill_id, "attack_id": attack.id,
	}))
	boss.take_damage(damage, tick, events, player.id)
	if not counter:
		boss.add_posture(profile["posture"], tick, events)


func _resolve_telegraphs(events: Array[GameEvent]) -> void:
	if player.state == PlayerState.STATE_DEAD:
		return
	for telegraph: Telegraph in boss.telegraphs.duplicate():
		if telegraph.has_hit or not telegraph.is_dangerous_at(tick):
			continue
		if not telegraph.overlaps_circle(player.position, Tuning.PLAYER_RADIUS):
			continue
		var since: int = player.parry_ticks_since_press()
		if telegraph.kind == Telegraph.KIND_GOLD and since >= 0 and since < Tuning.PARRY_ACTIVE_TICKS:
			telegraph.has_hit = true
			var perfect: bool = since < Tuning.PARRY_PERFECT_TICKS
			events.append(GameEvent.new(GameEvent.PARRY_SUCCEEDED, tick, {
				"player_id": player.id, "attacker_id": telegraph.owner_id, "telegraph_id": telegraph.id,
				"quality": &"perfect" if perfect else &"early", "position": player.position,
			}))
			player.on_parry_success(boss.position - player.position)
			boss.add_posture(Tuning.BOSS_POSTURE_MAX if perfect else Tuning.PARRY_EARLY_POSTURE, tick, events)
			continue
		# Red attacks are never parried; gold attacks that were not parried hit like any other. A Stone Ward blocks the
		# hit (Player.take_damage stores it): the telegraph is used up, so one attack is blocked and stored once.
		var blocks_before: int = player.ward_blocks
		if player.take_damage(telegraph.damage, tick, events, telegraph.owner_id):
			telegraph.has_hit = true
			events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
				"attacker_id": telegraph.owner_id, "target_id": player.id, "damage": telegraph.damage,
				"kind": telegraph.kind, "position": player.position,
			}))
		elif player.ward_blocks > blocks_before:
			telegraph.has_hit = true


func _clamp_to_arena() -> void:
	player.position = arena_point(player.position, Tuning.PLAYER_RADIUS)
	boss.position = arena_point(boss.position, Tuning.BOSS_RADIUS)


## `point` kept inside the walkable arena and pushed out of the solid props (for a body of `radius`). When a prop stands
## too close to the wall for the body to fit straight out of it (the wall clamp pushes it back in), the nearest spot
## that fits is searched on small rings around it (2 px steps, 16 directions), so nothing is left inside a prop.
func arena_point(point: Vector2, radius: float) -> Vector2:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	return Collision.clamp_point(obstacles, point, radius, low, Tuning.ARENA_SIZE - low)


func _fits_props(point: Vector2, radius: float) -> bool:
	return Collision.fits(obstacles, point, radius)


## Moves a circle of `radius` from `before` towards `after` in steps of at most OBSTACLE_SWEEP_STEP pixels, pushing
## it out of every solid prop after each step: it slides along them and cannot tunnel, however fast it moves.
func move_resolved(before: Vector2, after: Vector2, radius: float) -> Vector2:
	return Collision.move_resolved(obstacles, before, after, radius)


## The nearest position at which a circle of `radius` at `point` touches no solid prop.
func push_out_of_obstacles(point: Vector2, radius: float) -> Vector2:
	return Collision.push_out(obstacles, point, radius)


## Gale Cut passes through the boss only while the dash itself runs (skill_active). Skill attacks are
## resolved before this, so the corridor is the path really travelled, walls included.
func _player_passes_through_boss() -> bool:
	return player.state == PlayerState.STATE_SKILL_ACTIVE and player.skill_id == PlayerState.SKILL_GALE_CUT


## The boss is solid: push the player out of it. The tick the dash ends (or is interrupted) the player may
## be inside the boss; they are moved to the nearest free spot and never left overlapping.
func _separate_from_boss() -> void:
	if _player_passes_through_boss():
		return
	var min_dist: float = Tuning.BOSS_RADIUS + Tuning.PLAYER_RADIUS
	var offset: Vector2 = player.position - boss.position
	if offset.length() >= min_dist:
		return
	var push_dir: Vector2 = offset.normalized() if offset.length_squared() > 0.0001 else (player.skill_dir if player.skill_dir.length_squared() > 0.0001 else Vector2.LEFT)
	player.position = _free_spot(push_dir, min_dist)


## boss + dir * min_dist, kept inside the arena and out of the props. If the wall or a prop pushes that back into the
## boss (the boss stands near a wall or a prop), try the other directions around the boss, nearest to `dir` first.
func _free_spot(dir: Vector2, min_dist: float) -> Vector2:
	var best: Vector2 = arena_point(boss.position + dir * min_dist, Tuning.PLAYER_RADIUS)
	if best.distance_to(boss.position) >= min_dist - 0.01:
		return best
	var farthest: float = best.distance_to(boss.position)
	for step: int in range(1, 9):
		for sign: float in [1.0, -1.0]:
			var candidate: Vector2 = arena_point(boss.position + dir.rotated(sign * step * PI / 8.0) * min_dist, Tuning.PLAYER_RADIUS)
			var d: float = candidate.distance_to(boss.position)
			if d >= min_dist - 0.01:
				return candidate
			if d > farthest:
				farthest = d
				best = candidate
	return best


func _check_result(events: Array[GameEvent]) -> void:
	if boss.state == BossState.STATE_DEAD:
		result = RESULT_VICTORY
	elif player.state == PlayerState.STATE_DEAD:
		result = RESULT_DEFEAT
	else:
		return
	events.append(GameEvent.new(GameEvent.GAME_RESULT, tick, {"result": result}))
