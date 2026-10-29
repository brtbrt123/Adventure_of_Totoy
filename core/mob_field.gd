extends RefCounted
## The mobs of one exploration scene: encounters made of regular enemies (core/mob.gd; numbers in Tuning.MOBS). ExploreCore owns one
## MobField for a scene that has "encounters" in its scene file (data/scenes/<scene>_props.json) and calls resolve() every tick after the
## hero moved. No rendering, no randomness: same scene and inputs = same fight. docs/architecture.md "Mobs and encounters".
##
## Encounter: a group of mobs standing at their homes, with a rectangle (the fight floor), a leash radius around its centre and a reward.
##   dormant  nobody woke: the mobs stand idle in plain view. An ARMED hero (flag received_first_sword) within a mob's `aggro` radius,
##            or any blow he lands on one of them, wakes the WHOLE encounter (`encounter_started`, `mob_alerted` per mob). An unarmed
##            hero is ignored: he cannot fight, so nothing wakes.
##   active   the mobs alert (MOB_ALERT_TICKS), chase and attack. At most MOB_MAX_ATTACKERS wind up or strike at once; the others hold
##            `wait` px away. The hero beyond the leash for MOB_LEASH_GRACE_TICKS: the mobs give up (`mob_leashed`), walk home at
##            MOB_RETURN_SPEED_MULT and heal (the encounter is dormant again); beyond it for MOB_RESET_TICKS an uncleared encounter that was
##            touched is whole again, dead mobs included (`encounter_reset`, reason leash). A mob that gets beyond its `tether` from home
##            also walks home. The hero's defeat resets every uncleared encounter (reason defeat), and leaving the scene destroys the core.
##   cleared  the last mob fell: the flag `cleared_<id>` is set (saved with the story flags: a cleared encounter never spawns again,
##            also after CONTINUE), `encounter_cleared` and the encounter's own `reward` (if its scene row has one) as `item_received`.
## Every felled mob is felled for good: the flag `killed_<encounter>_<n>` is set the first time (and only then it pays its `exp` as
## `exp_gained` and rolls its `drop` once, the same result every time: `mob_dropped` + `item_received`), a reset or CONTINUE never brings it
## back and it never pays twice.
## Attacks (each mob has one): the warning is a Telegraph LINE locked on the hero when the windup began; `strike` moves the mob along it.
##   mossling lunge   GOLD: parry it while the lunge connects (parry window) and it is stunned and exposed; a dash dodges it; a normal hit
##                    during the windup cancels it.
##   boar charge      RED: dash through it (parry does nothing); it cannot be interrupted; a charge that hits a prop crashes: stunned and
##                    exposed.
## Exposed mobs take MOB_EXPOSED_MULT damage (`attack_hit` kind counter). The hero's swing hits every mob in its arc once.
const Tuning := preload("res://core/tuning.gd")
const GameEvent := preload("res://core/game_event.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Telegraph := preload("res://core/telegraph.gd")
const Weapons := preload("res://core/weapons.gd")
const PlayerState := preload("res://core/player.gd")
const Collision := preload("res://core/collision.gd")
const Mob := preload("res://core/mob.gd")

const FLAG_PREFIX: String = "cleared_"
const DORMANT: StringName = &"dormant"
const ACTIVE: StringName = &"active"
const CLEARED: StringName = &"cleared"
const FIRST_MOB_ID: int = 201  # mob ids (telegraph owners, event ids); 1 is the hero, 100 the training post


class Encounter:
	extends RefCounted
	var id: StringName = &""
	var label: String = ""
	var rect: Rect2 = Rect2()
	var anchor: Vector2 = Vector2.ZERO
	var leash: float = 160.0
	var reward: Dictionary = {}
	var flag: StringName = &""
	var state: StringName = &"dormant"
	var outside_ticks: int = 0
	var mobs: Array[Mob] = []
	var touched: bool = false  # something happened here since the encounter was whole (a wake, a blow): a reset has something to undo


var scene_id: StringName = &""
var encounters: Array[Encounter] = []
var _next_telegraph: int = 1000
var _swing_serial: int = 0
var _was_swinging: bool = false


## The field of a scene def (its "encounters" rows), or null when it has none.
static func for_scene(def: Dictionary) -> RefCounted:
	var rows: Array = def.get("encounters", [])
	if rows.is_empty():
		return null
	var field: RefCounted = load("res://core/mob_field.gd").new()
	field.scene_id = def["id"]
	var next_id: int = FIRST_MOB_ID
	for row: Variant in rows:
		var r: Dictionary = row
		var enc: Encounter = Encounter.new()
		enc.id = StringName(str(r["id"]))
		enc.label = str(r.get("name", r["id"]))
		var rect: Array = r["rect"]
		enc.rect = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
		enc.anchor = enc.rect.get_center()
		enc.leash = float(r.get("leash", 160.0))
		enc.reward = r.get("reward", {})
		enc.flag = StringName(FLAG_PREFIX + String(enc.id))
		var slot: int = 0
		for m: Variant in r["mobs"]:
			var spec: Dictionary = m
			var mob: Mob = Mob.new()
			mob.setup(next_id, StringName(str(spec["type"])), enc.id, Vector2(float(spec["x"]), float(spec["y"])), slot)
			enc.mobs.append(mob)
			next_id += 1
			slot += 1
		field.encounters.append(enc)
	return field


## The flag that records an encounter as cleared.
static func flag_of(encounter_id: StringName) -> StringName:
	return StringName(FLAG_PREFIX + String(encounter_id))


## The story flags were replaced (CONTINUE): every encounter whose flag is set is cleared and its mobs are gone, no events.
func sync_flags(flags: Array[StringName]) -> void:
	for enc: Encounter in encounters:
		if flags.has(enc.flag):
			enc.state = CLEARED
			enc.mobs.clear()
			continue
		for mob: Mob in enc.mobs:
			if flags.has(kill_flag(enc, mob)):  # felled in an earlier visit: stays down
				mob.killed = true
				mob.hp = 0
				mob.state = &"dead"
				mob.state_ticks = Tuning.MOB_DEATH_TICKS + 1


## The story flag that records a mob as felled.
static func kill_flag(enc: Encounter, mob: Mob) -> StringName:
	return StringName("killed_%s_%d" % [String(enc.id), mob.slot + 1])


## The same number in [0, 1) for the same mob, always: a drop is decided by the mob, not by luck at the moment.
static func drop_roll(mob_id: int) -> float:
	var x: int = (mob_id * 7919 + 12353) & 0x7fffffff
	x = (x * 1103515245 + 12345) & 0x7fffffff
	x = (x * 1103515245 + 12345) & 0x7fffffff
	return float((x >> 8) % 1000) / 1000.0


## The fight is on: some encounter is awake.
func is_engaged() -> bool:
	for enc: Encounter in encounters:
		if enc.state == ACTIVE:
			return true
	return false


## Distance from `point` to the nearest mob home of an encounter that is not cleared (INF when none): where safe spots must keep away.
func nearest_home_distance(point: Vector2) -> float:
	var best: float = INF
	for enc: Encounter in encounters:
		if enc.state == CLEARED:
			continue
		for mob: Mob in enc.mobs:
			best = minf(best, point.distance_to(mob.home))
	return best


## One tick, after the hero moved. `core` is the ExploreCore (player, tick, obstacles, story_flags, is_armed(), give_item(), _grant_flag()).
func resolve(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	for enc: Encounter in encounters:
		for mob: Mob in enc.mobs:
			if mob.state == &"dead":
				mob.state_ticks = mini(mob.state_ticks + 1, Tuning.MOB_DEATH_TICKS + 1)
	if player.state == PlayerState.STATE_DEAD:
		return
	var swinging: bool = player.state == PlayerState.STATE_ATTACK_ACTIVE
	if swinging and not _was_swinging:
		_swing_serial += 1
	_was_swinging = swinging
	var armed: bool = core.is_armed()
	for enc: Encounter in encounters:
		if enc.state == CLEARED:
			continue
		if enc.state == DORMANT and armed:
			for mob: Mob in enc.mobs:
				if mob.is_alive() and mob.state == &"idle" and player.position.distance_to(mob.position) <= float(mob.stats()["aggro"]):
					_wake(core, enc, events)
					break
		if armed and swinging:
			_hero_blows(core, enc, events)
		if enc.state == CLEARED:
			continue
		_leash(core, enc, events)
		for mob: Mob in enc.mobs:
			if mob.is_alive() and mob.state != &"idle":
				_step_mob(core, enc, mob, _count_attackers(enc), events)
		_separate(core, enc)


func _count_attackers(enc: Encounter) -> int:
	var n: int = 0
	for mob: Mob in enc.mobs:
		if mob.is_attacking():
			n += 1
	return n


func _alive(enc: Encounter) -> Array[Mob]:
	var out: Array[Mob] = []
	for mob: Mob in enc.mobs:
		if mob.is_alive():
			out.append(mob)
	return out


func _wake(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	enc.state = ACTIVE
	enc.touched = true
	enc.outside_ticks = 0
	events.append(GameEvent.new(GameEvent.ENCOUNTER_STARTED, core.tick, {"scene": scene_id, "encounter_id": enc.id}))
	var hero: Vector2 = core.player.position
	for mob: Mob in _alive(enc):
		mob.telegraph = null
		mob.cooldown = Tuning.MOB_FIRST_COOLDOWN + Tuning.MOB_COOLDOWN_STAGGER * mob.slot
		mob.facing = _toward(mob.position, hero, mob.facing)
		mob.set_state(&"alert")
		events.append(GameEvent.new(GameEvent.MOB_ALERTED, core.tick, {"scene": scene_id, "mob_id": mob.id, "type": mob.type, "encounter_id": enc.id, "position": mob.position}))


## The hero's distance from the encounter: give up after MOB_LEASH_GRACE_TICKS, start over after MOB_RESET_TICKS.
func _leash(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	var inside: bool = core.player.position.distance_to(enc.anchor) <= enc.leash
	enc.outside_ticks = 0 if inside else enc.outside_ticks + 1
	if enc.state == ACTIVE and enc.outside_ticks >= Tuning.MOB_LEASH_GRACE_TICKS:
		_give_up(core, enc, events)
	if enc.outside_ticks >= Tuning.MOB_RESET_TICKS and enc.touched and enc.state == DORMANT:
		reset_encounter(enc, core.tick, &"leash", events)


func _give_up(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	enc.state = DORMANT
	for mob: Mob in _alive(enc):
		mob.telegraph = null
		mob.set_state(&"return")
		events.append(GameEvent.new(GameEvent.MOB_LEASHED, core.tick, {"scene": scene_id, "mob_id": mob.id, "encounter_id": enc.id}))


## Every uncleared encounter whole again (the hero's defeat). Emits `encounter_reset` for those that had been touched.
func reset_all(tick: int, reason: StringName, events: Array[GameEvent]) -> void:
	for enc: Encounter in encounters:
		if enc.state != CLEARED:
			reset_encounter(enc, tick, reason, events)


func reset_encounter(enc: Encounter, tick: int, reason: StringName, events: Array[GameEvent]) -> void:
	var was_touched: bool = enc.touched
	for mob: Mob in enc.mobs:
		if not mob.killed:
			mob.reset()
	enc.state = DORMANT
	enc.outside_ticks = 0
	enc.touched = false
	if was_touched:
		events.append(GameEvent.new(GameEvent.ENCOUNTER_RESET, tick, {"scene": scene_id, "encounter_id": enc.id, "reason": reason}))


# ---- the hero's blows -------------------------------------------------------------------------------------------------------

func _hero_blows(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var weapon: StringName = player.weapon_id
	var swing: int = player.combo_index - 1
	for mob: Mob in _alive(enc):
		if mob.last_swing == _swing_serial:
			continue
		var to_mob: Vector2 = mob.position - player.position
		var dist: float = to_mob.length()
		if dist - mob.radius > Tuning.ATTACK_RANGE * Weapons.range_mults(weapon)[swing]:
			continue
		if dist > 0.0001 and player.facing.dot(to_mob / dist) < Weapons.arc_dot(weapon):
			continue
		mob.last_swing = _swing_serial
		player.attack_hit_done = true
		var base: float = Tuning.ATTACK_DAMAGE * Weapons.damage_mults(weapon)[swing] * player.swing_damage_mult * float(core.damage_mult())
		var cleared: bool = hit_mob(core, enc, mob, base, {"combo_index": player.combo_index, "weapon_id": weapon}, events)
		core.skills.on_swing_hit(core, mob.id, base, player.combo_index, weapon)
		if cleared:
			return


## Every living mob of the encounters that are not cleared, with its encounter: [{"enc", "mob"}]. The hero's skills (aspects)
## look for their targets here.
func living() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enc: Encounter in encounters:
		if enc.state == CLEARED:
			continue
		for mob: Mob in _alive(enc):
			out.append({"enc": enc, "mob": mob})
	return out


## One hero hit on `mob` of `enc`: wakes a dormant group, an exposed mob takes Tuning.MOB_EXPOSED_MULT (kind counter), the
## hit may fell it (exp, drop, the group's clear) or interrupt its windup. `base` is the damage before that multiplier;
## `extra` is merged into the attack_hit event (combo_index, weapon_id, skill_id, ...). Returns true when the hit cleared
## the whole encounter (the caller stops looking for more targets then).
func hit_mob(core: RefCounted, enc: Encounter, mob: Mob, base: float, extra: Dictionary, events: Array[GameEvent]) -> bool:
	var player: PlayerState = core.player
	if enc.state == DORMANT:
		_wake(core, enc, events)
	var exposed: bool = mob.is_exposed()
	var damage: int = maxi(1, roundi(base * (Tuning.MOB_EXPOSED_MULT if exposed else 1.0)))
	mob.hp = maxi(0, mob.hp - damage)
	mob.last_hit_tick = core.tick
	enc.touched = true
	var data: Dictionary = {
		"attacker_id": player.id, "target_id": mob.id, "damage": damage, "kind": &"counter" if exposed else &"normal",
		"position": mob.position,
	}
	data.merge(extra)
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, core.tick, data))
	if mob.hp <= 0:
		_kill(core, enc, mob, events)
		if enc.state == CLEARED:
			return true
	elif mob.state == &"windup" and bool(mob.attack_stats()["interrupt"]):
		mob.telegraph = null
		mob.cooldown = int(mob.attack_stats()["cooldown"])
		mob.set_state(&"hurt")
	elif mob.state in [&"alert", &"chase", &"recover", &"hurt", &"return"]:
		mob.set_state(&"hurt")
	return false


func _kill(core: RefCounted, enc: Encounter, mob: Mob, events: Array[GameEvent]) -> void:
	mob.hp = 0
	mob.telegraph = null
	mob.set_state(&"dead")
	events.append(GameEvent.new(GameEvent.MOB_DEFEATED, core.tick, {"scene": scene_id, "mob_id": mob.id, "type": mob.type, "encounter_id": enc.id, "position": mob.position}))
	mob.killed = true
	var flag: StringName = kill_flag(enc, mob)
	if core._grant_flag(flag, events):  # the first time only
		var stats: Dictionary = mob.stats()
		core.give_exp(int(stats["exp"]), mob.id, events)
		var drop: Dictionary = stats["drop"]
		if drop_roll(mob.id) < float(drop["chance"]):
			events.append(GameEvent.new(GameEvent.MOB_DROPPED, core.tick, {"scene": scene_id, "mob_id": mob.id, "item_id": drop["item"], "position": mob.position}))
			core.give_item({"reward_id": "%s_drop" % flag, "kind": "item", "item": drop["item"], "name": String(drop["item"]).capitalize(), "quantity": 1}, enc.id, events)
	if _alive(enc).is_empty():
		_clear(core, enc, events)


func _clear(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	enc.state = CLEARED
	core._grant_flag(enc.flag, events)
	events.append(GameEvent.new(GameEvent.ENCOUNTER_CLEARED, core.tick, {"scene": scene_id, "encounter_id": enc.id, "reward_id": StringName(str(enc.reward.get("reward_id", "")))}))
	if not enc.reward.is_empty():
		core.give_item(enc.reward, enc.id, events)


# ---- one mob ----------------------------------------------------------------------------------------------------------------

func _step_mob(core: RefCounted, enc: Encounter, mob: Mob, attackers: int, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	mob.state_ticks += 1
	if mob.cooldown > 0:
		mob.cooldown -= 1
	var atk: Dictionary = mob.attack_stats()
	match mob.state:
		&"alert":
			mob.facing = _toward(mob.position, player.position, mob.facing)
			if mob.state_ticks >= Tuning.MOB_ALERT_TICKS:
				mob.set_state(&"chase")
		&"chase":
			_chase(core, enc, mob, attackers, events)
		&"windup":
			mob.facing = mob.attack_dir
			if mob.state_ticks >= int(atk["windup"]):
				mob.set_state(&"strike")
				mob.strike_left = int(atk["strike_ticks"])
		&"strike":
			_strike(core, mob, events)
		&"recover":
			if mob.state_ticks >= int(atk["recover"]):
				mob.set_state(&"chase")
		&"crash":
			if mob.state_ticks >= int(atk["crash"]):
				mob.set_state(&"chase")
		&"stagger":
			if mob.state_ticks >= Tuning.MOB_STAGGER_TICKS:
				mob.set_state(&"chase")
		&"hurt":
			if mob.state_ticks >= Tuning.MOB_HURT_TICKS:
				mob.set_state(&"chase")
		&"return":
			_walk_home(core, mob)
	if mob.state == &"chase" and mob.position.distance_to(mob.home) > float(mob.stats()["tether"]):
		mob.set_state(&"return")
		events.append(GameEvent.new(GameEvent.MOB_LEASHED, core.tick, {"scene": scene_id, "mob_id": mob.id, "encounter_id": enc.id}))


func _chase(core: RefCounted, enc: Encounter, mob: Mob, attackers: int, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var atk: Dictionary = mob.attack_stats()
	var to_hero: Vector2 = player.position - mob.position
	var dist: float = to_hero.length()
	mob.facing = _toward(mob.position, player.position, mob.facing)
	if mob.cooldown <= 0 and dist >= float(atk["start_min"]) and dist <= float(atk["start_max"]) and attackers < Tuning.MOB_MAX_ATTACKERS:
		_begin_attack(core, mob, events)
		return
	var stats: Dictionary = mob.stats()
	var hold: float = float(stats["hold"])
	if attackers >= Tuning.MOB_MAX_ATTACKERS:
		hold = maxf(hold, float(stats["wait"]))
	if dist > hold:
		_move(core, mob, to_hero / dist, float(stats["speed"]))


func _begin_attack(core: RefCounted, mob: Mob, events: Array[GameEvent]) -> void:
	var atk: Dictionary = mob.attack_stats()
	var dir: Vector2 = _toward(mob.position, core.player.position, mob.facing)
	mob.attack_dir = dir
	mob.facing = dir
	mob.attack_done = false
	mob.set_state(&"windup")
	var t: Telegraph = Telegraph.new()
	t.id = _next_telegraph
	_next_telegraph += 1
	t.owner_id = mob.id
	t.attack = StringName(atk["id"])
	t.kind = StringName(atk["kind"])
	t.shape = Telegraph.SHAPE_LINE
	t.center = mob.position
	t.muzzle = mob.position
	t.direction = dir
	t.size = float(atk["strike_speed"]) * float(atk["strike_ticks"]) + mob.radius
	t.width = float(atk["width"])
	t.damage = int(atk["damage"])
	t.start_tick = core.tick
	t.hit_tick = core.tick + int(atk["windup"])
	t.end_tick = t.hit_tick + int(atk["strike_ticks"])
	mob.telegraph = t
	events.append(GameEvent.new(GameEvent.ATTACK_TELEGRAPHED, core.tick, {
		"telegraph_id": t.id, "owner_id": mob.id, "kind": t.kind, "attack": t.attack, "scene": scene_id, "mob_id": mob.id,
		"hit_tick": t.hit_tick, "end_tick": t.end_tick,
	}))


func _strike(core: RefCounted, mob: Mob, events: Array[GameEvent]) -> void:
	var atk: Dictionary = mob.attack_stats()
	var speed: float = float(atk["strike_speed"])
	var before: Vector2 = mob.position
	mob.position = Collision.move_resolved(core.obstacles, before, before + mob.attack_dir * speed, mob.radius)
	mob.strike_left -= 1
	var player: PlayerState = core.player
	if not mob.attack_done and player.position.distance_to(mob.position) <= mob.radius + Tuning.PLAYER_RADIUS:
		_land(core, mob, atk, events)
	var crash: int = int(atk["crash"])
	if mob.state == &"strike" and crash > 0 and mob.position.distance_to(before) < speed * 0.5:
		mob.telegraph = null
		mob.cooldown = int(atk["cooldown"])
		mob.set_state(&"crash")
		events.append(GameEvent.new(GameEvent.MOB_STAGGERED, core.tick, {"scene": scene_id, "mob_id": mob.id, "reason": &"crash", "position": mob.position}))
	elif mob.state == &"strike" and mob.strike_left <= 0:
		mob.telegraph = null
		mob.cooldown = int(atk["cooldown"])
		mob.set_state(&"recover")


## The strike reached the hero: a gold lunge met by the parry window is parried, anything else wounds him unless he is invulnerable.
func _land(core: RefCounted, mob: Mob, atk: Dictionary, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var since: int = player.parry_ticks_since_press()
	if StringName(atk["kind"]) == Telegraph.KIND_GOLD and since >= 0 and since < Tuning.PARRY_ACTIVE_TICKS:
		mob.attack_done = true
		var t: Telegraph = mob.telegraph
		events.append(GameEvent.new(GameEvent.PARRY_SUCCEEDED, core.tick, {
			"player_id": player.id, "attacker_id": mob.id, "telegraph_id": t.id if t != null else 0,
			"quality": &"perfect" if since < Tuning.PARRY_PERFECT_TICKS else &"early", "position": player.position,
		}))
		player.on_parry_success(mob.position - player.position)
		player.position = Collision.push_out(core.obstacles, player.position, Tuning.PLAYER_RADIUS)
		mob.telegraph = null
		mob.cooldown = int(atk["cooldown"])
		mob.set_state(&"stagger")
		events.append(GameEvent.new(GameEvent.MOB_STAGGERED, core.tick, {"scene": scene_id, "mob_id": mob.id, "reason": &"parry", "position": mob.position}))
	elif player.take_damage(int(atk["damage"]), core.tick, events, mob.id):
		mob.attack_done = true


func _walk_home(core: RefCounted, mob: Mob) -> void:
	var to_home: Vector2 = mob.home - mob.position
	var step: float = float(mob.stats()["speed"]) * Tuning.MOB_RETURN_SPEED_MULT
	if to_home.length() <= step:
		mob.position = mob.home
		mob.hp = mob.max_hp
		mob.set_state(&"idle")
		return
	mob.facing = to_home.normalized()
	_move(core, mob, to_home.normalized(), step)


func _move(core: RefCounted, mob: Mob, dir: Vector2, speed: float) -> void:
	mob.position = Collision.move_resolved(core.obstacles, mob.position, mob.position + dir * speed, mob.radius)


## Mobs push each other apart (never into a prop) so a pack does not stack on one spot.
func _separate(core: RefCounted, enc: Encounter) -> void:
	var live: Array[Mob] = _alive(enc)
	for i: int in live.size():
		for j: int in range(i + 1, live.size()):
			var a: Mob = live[i]
			var b: Mob = live[j]
			if a.state == &"strike" or b.state == &"strike":
				continue
			var gap: Vector2 = b.position - a.position
			var want: float = a.radius + b.radius
			var dist: float = gap.length()
			if dist >= want:
				continue
			var push: Vector2 = (gap / dist if dist > 0.001 else Vector2.RIGHT) * (want - dist) * Tuning.MOB_SEPARATION_PUSH
			a.position = Collision.move_resolved(core.obstacles, a.position, a.position - push, a.radius)
			b.position = Collision.move_resolved(core.obstacles, b.position, b.position + push, b.radius)


static func _toward(from: Vector2, to: Vector2, fallback: Vector2) -> Vector2:
	var d: Vector2 = to - from
	return d.normalized() if d.length_squared() > 0.0001 else fallback


# ---- what presentation reads --------------------------------------------------------------------------------------------------

## Every mob worth drawing: [{id, type, visual_id, level, encounter_id, position, facing, state, state_ticks, hp, max_hp, radius, exposed,
## attack (the warning's attack id, else empty), since_hit (ticks since the hero's blow)}]; a defeated one only for MOB_DEATH_TICKS.
func mob_views(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enc: Encounter in encounters:
		for mob: Mob in enc.mobs:
			if mob.state == &"dead" and mob.state_ticks >= Tuning.MOB_DEATH_TICKS:
				continue
			out.append({
				"id": mob.id, "type": mob.type, "visual_id": mob.type, "level": int(mob.stats()["level"]), "encounter_id": enc.id, "position": mob.position, "facing": mob.facing,
				"state": mob.state, "state_ticks": mob.state_ticks, "hp": mob.hp, "max_hp": mob.max_hp, "radius": mob.radius,
				"exposed": mob.is_exposed(), "attack": mob.telegraph.attack if mob.telegraph != null else &"", "since_hit": tick - mob.last_hit_tick,
			})
	return out


## [{id, name, state (dormant, active, cleared), rect, anchor, leash, alive, total, reward_id}].
func encounter_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enc: Encounter in encounters:
		var alive: int = _alive(enc).size()
		out.append({
			"id": enc.id, "name": enc.label, "state": enc.state, "rect": enc.rect, "anchor": enc.anchor, "leash": enc.leash,
			"alive": alive, "total": enc.mobs.size(), "reward_id": StringName(str(enc.reward.get("reward_id", ""))),
		})
	return out


## The mobs' running warnings in the fight's snapshot type (gold = parry it, red = dash it).
func telegraph_snapshots() -> Array[Snapshots.TelegraphSnapshot]:
	var out: Array[Snapshots.TelegraphSnapshot] = []
	for enc: Encounter in encounters:
		for mob: Mob in enc.mobs:
			var t: Telegraph = mob.telegraph
			if t == null:
				continue
			var s: Snapshots.TelegraphSnapshot = Snapshots.TelegraphSnapshot.new()
			s.id = t.id
			s.owner_id = t.owner_id
			s.attack = t.attack
			s.kind = t.kind
			s.shape = t.shape
			s.center = t.center
			s.muzzle = t.muzzle
			s.direction = t.direction
			s.size = t.size
			s.width = t.width
			s.start_tick = t.start_tick
			s.hit_tick = t.hit_tick
			s.end_tick = t.end_tick
			out.append(s)
	return out
