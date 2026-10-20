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

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_attack_id: int = 1


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
	player.step(input, tick, events)
	player.position = move_resolved(player_before, player.position, Tuning.PLAYER_RADIUS)
	_resolve_lightning_barrage(events)
	_resolve_reaper_coil(events)
	_resolve_player_attack(events)
	_spawn_released_skill(events)
	var boss_before: Vector2 = boss.position
	boss.step(tick, player.position, _rng, events)
	boss.position = move_resolved(boss_before, boss.position, Tuning.BOSS_RADIUS)
	_resolve_telegraphs(events)
	_clamp_to_arena()
	_resolve_skill_attacks(player_before, events)
	_separate_from_boss()
	_check_result(events)
	last_events = events
	for event: GameEvent in events:
		event_emitted.emit(event)


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
	if Weapons.has_lightning_finisher(weapon) and player.combo_index == Weapons.combo_max(weapon):
		_lightning_strike(counter, player.swing_damage_mult, {"combo_index": player.combo_index, "source": &"swing"}, events)


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
		# Red attacks are never parried; gold attacks that were not parried hit like any other.
		if player.take_damage(telegraph.damage, tick, events, telegraph.owner_id):
			telegraph.has_hit = true
			events.append(GameEvent.new(GameEvent.ATTACK_HIT, tick, {
				"attacker_id": telegraph.owner_id, "target_id": player.id, "damage": telegraph.damage,
				"kind": telegraph.kind, "position": player.position,
			}))


func _clamp_to_arena() -> void:
	player.position = arena_point(player.position, Tuning.PLAYER_RADIUS)
	boss.position = arena_point(boss.position, Tuning.BOSS_RADIUS)


## `point` kept inside the walkable arena and pushed out of the solid props (for a body of `radius`). When a prop stands
## too close to the wall for the body to fit straight out of it (the wall clamp pushes it back in), the nearest spot
## that fits is searched on small rings around it (2 px steps, 16 directions), so nothing is left inside a prop.
func arena_point(point: Vector2, radius: float) -> Vector2:
	var low: Vector2 = Vector2(Tuning.ARENA_MARGIN, Tuning.ARENA_MARGIN)
	var high: Vector2 = Tuning.ARENA_SIZE - low
	var spot: Vector2 = push_out_of_obstacles(point.clamp(low, high), radius).clamp(low, high)
	if _fits_props(spot, radius):
		return spot
	for ring: int in range(1, 17):
		for k: int in 16:
			var candidate: Vector2 = spot + Vector2.RIGHT.rotated(float(k) * TAU / 16.0) * (2.0 * ring)
			candidate = push_out_of_obstacles(candidate.clamp(low, high), radius).clamp(low, high)
			if _fits_props(candidate, radius):
				return candidate
	return spot


func _fits_props(point: Vector2, radius: float) -> bool:
	for obstacle: Obstacle in obstacles:
		if point.distance_to(obstacle.center) < obstacle.radius + radius - 0.001:
			return false
	return true


## Moves a circle of `radius` from `before` towards `after` in steps of at most OBSTACLE_SWEEP_STEP pixels, pushing
## it out of every solid prop after each step: it slides along them and cannot tunnel, however fast it moves.
func move_resolved(before: Vector2, after: Vector2, radius: float) -> Vector2:
	var delta: Vector2 = after - before
	var steps: int = maxi(1, ceili(delta.length() / Tuning.OBSTACLE_SWEEP_STEP))
	var step_delta: Vector2 = delta / steps
	var current: Vector2 = before
	for i: int in steps:
		current = push_out_of_obstacles(current + step_delta, radius)
	return current


## The nearest position at which a circle of `radius` at `point` touches no solid prop.
func push_out_of_obstacles(point: Vector2, radius: float) -> Vector2:
	var current: Vector2 = point
	for pass_index: int in 2:  # a second pass settles a circle squeezed between two props
		for obstacle: Obstacle in obstacles:
			var offset: Vector2 = current - obstacle.center
			var reach: float = obstacle.radius + radius
			var dist_sq: float = offset.length_squared()
			if dist_sq < reach * reach:
				var dist: float = sqrt(dist_sq)
				var dir: Vector2 = offset / dist if dist > 0.0001 else Vector2.DOWN
				current = obstacle.center + dir * reach
	return current


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
