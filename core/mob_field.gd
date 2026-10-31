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
	var managed: bool = false  # a trial's encounter: its mobs come and go with the waves; it never clears itself, leashes or remembers kills
	var max_attackers: int = Tuning.MOB_MAX_ATTACKERS


var scene_id: StringName = &""
var encounters: Array[Encounter] = []
var _next_telegraph: int = 1000
var _next_summoned_id: int = 5000
var projectiles: Array[Dictionary] = []  # orbs in flight (see _fire)
var _next_projectile: int = 1
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
		enc.managed = bool(r.get("managed", false))
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
		if flags.has(enc.flag) and not enc.managed:
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
			if mob.is_alive() and mob.state != &"idle" and not mob.dragged:
				_step_mob(core, enc, mob, _count_attackers(enc), events)
		_separate(core, enc)
		_regen(core, enc, events)
	_step_projectiles(core, events)


func _count_attackers(enc: Encounter) -> int:
	var n: int = 0
	for mob: Mob in enc.mobs:
		if mob.is_attacking():
			n += 1
	return n


## ---- managed encounters (a trial's waves, core/trial.gd) ----------------------------------------------------------------------

## A new mob in a managed encounter at `at`, awake (alert, then it chases); the encounter is active. Returns it.
func add_mob(core: RefCounted, encounter_id: StringName, type: StringName, at: Vector2, events: Array[GameEvent]) -> Mob:
	var enc: Encounter = _find(encounter_id)
	var mob: Mob = Mob.new()
	mob.setup(_next_summoned_id, type, enc.id, at, 200 + enc.mobs.size())
	_next_summoned_id += 1
	mob.state = &"alert"
	mob.facing = _toward(at, core.player.position, Vector2.LEFT)
	mob.cooldown = Tuning.MOB_FIRST_COOLDOWN + Tuning.MOB_COOLDOWN_STAGGER * (enc.mobs.size() % 4)
	enc.mobs.append(mob)
	enc.state = ACTIVE
	enc.touched = true
	events.append(GameEvent.new(GameEvent.MOB_ALERTED, core.tick, {"scene": scene_id, "mob_id": mob.id, "encounter_id": enc.id, "position": at}))
	return mob


## Living mobs of an encounter (0 when there is no such encounter).
func alive_in(encounter_id: StringName) -> int:
	var enc: Encounter = _find(encounter_id)
	return 0 if enc == null else _alive(enc).size()


## How many mobs of the encounter may wind up or strike at once (the trial raises it to 4).
func set_max_attackers(encounter_id: StringName, count: int) -> void:
	var enc: Encounter = _find(encounter_id)
	if enc != null:
		enc.max_attackers = count


## A managed encounter is quiet again (its trial was won): dormant, untouched, with no living mobs left to fight.
func rest(encounter_id: StringName) -> void:
	var enc: Encounter = _find(encounter_id)
	if enc != null:
		enc.state = DORMANT
		enc.touched = false
		enc.max_attackers = Tuning.MOB_MAX_ATTACKERS


func _find(encounter_id: StringName) -> Encounter:
	for enc: Encounter in encounters:
		if enc.id == encounter_id:
			return enc
	return null


## ---- mob projectiles (the Glowmoth orb) ------------------------------------------------------------------------------------

## The release of a projectile attack: the orb leaves the mob along the locked aim, the warning lane is done.
func _fire(core: RefCounted, enc: Encounter, mob: Mob, atk: Dictionary, events: Array[GameEvent]) -> void:
	var spec: Dictionary = atk["projectile"]
	var orb: Dictionary = {
		"id": _next_projectile, "owner_id": mob.id, "encounter_id": enc.id, "visual": StringName(spec["visual"]), "position": mob.position,
		"direction": mob.attack_dir, "speed": float(spec["speed"]), "radius": float(spec["radius"]), "range": float(atk["reach"]),
		"travelled": 0.0, "damage": int(atk["damage"]), "fired_tick": core.tick,
	}
	_next_projectile += 1
	projectiles.append(orb)
	mob.clear_telegraph()
	mob.attack_done = true
	events.append(GameEvent.new(GameEvent.MOB_PROJECTILE_FIRED, core.tick, {
		"scene": scene_id, "projectile_id": orb["id"], "owner_id": mob.id, "visual": orb["visual"], "position": orb["position"],
		"direction": orb["direction"], "speed": orb["speed"], "radius": orb["radius"],
	}))


## Moves every orb one tick (in steps no longer than its radius, so it cannot skip the hero or a thin prop) and ends it on a hit,
## a prop or its full range. A hero who is invulnerable (a dash) is passed through.
func _step_projectiles(core: RefCounted, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	for i: int in range(projectiles.size() - 1, -1, -1):
		var orb: Dictionary = projectiles[i]
		var radius: float = float(orb["radius"])
		var speed: float = float(orb["speed"])
		var steps: int = maxi(1, ceili(speed / maxf(1.0, radius)))
		var reason: StringName = &""
		for s: int in steps:
			var at: Vector2 = Vector2(orb["position"]) + Vector2(orb["direction"]) * (speed / steps)
			orb["position"] = at
			orb["travelled"] = float(orb["travelled"]) + speed / steps
			if at.distance_to(player.position) <= radius + Tuning.PLAYER_RADIUS:
				var warded: bool = player.state == PlayerState.STATE_WARD  # Stone Ward stores the blow and stops the orb
				if player.take_damage(int(orb["damage"]), core.tick, events, int(orb["owner_id"])) or warded:
					reason = &"hit"
					break
			if not Collision.fits(core.obstacles, at, radius):
				reason = &"prop"
				break
			if float(orb["travelled"]) >= float(orb["range"]):
				reason = &"range"
				break
		if reason != &"":
			_end_projectile(core.tick, i, reason, events)


func _end_projectile(tick: int, index: int, reason: StringName, events: Array[GameEvent]) -> void:
	var orb: Dictionary = projectiles[index]
	projectiles.remove_at(index)
	events.append(GameEvent.new(GameEvent.MOB_PROJECTILE_ENDED, tick, {
		"scene": scene_id, "projectile_id": orb["id"], "owner_id": orb["owner_id"], "visual": orb["visual"], "position": orb["position"], "reason": reason,
	}))


## Ends the orbs of one mob (it died) or of a whole encounter (it reset or cleared).
func _end_projectiles_of(tick: int, owner_id: int, encounter_id: StringName, reason: StringName, events: Array[GameEvent]) -> void:
	for i: int in range(projectiles.size() - 1, -1, -1):
		var orb: Dictionary = projectiles[i]
		if (owner_id != 0 and int(orb["owner_id"]) == owner_id) or (encounter_id != &"" and orb["encounter_id"] == encounter_id):
			_end_projectile(tick, i, reason, events)


## The orbs in flight for presentation: [{id, owner_id, visual, position, direction, radius, fired_tick}].
func projectile_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for orb: Dictionary in projectiles:
		out.append({"id": orb["id"], "owner_id": orb["owner_id"], "visual": orb["visual"], "position": orb["position"], "direction": orb["direction"],
			"radius": orb["radius"], "fired_tick": orb["fired_tick"]})
	return out


## The mobs of the encounter that are alive and were not summoned (they decide when it is cleared).
func _alive_regular(enc: Encounter) -> Array[Mob]:
	var out: Array[Mob] = []
	for mob: Mob in enc.mobs:
		if mob.is_alive() and not mob.is_summoned():
			out.append(mob)
	return out


func _regular_total(enc: Encounter) -> int:
	var n: int = 0
	for mob: Mob in enc.mobs:
		if not mob.is_summoned():
			n += 1
	return n


func _encounter_of(mob: Mob) -> Encounter:
	for enc: Encounter in encounters:
		if enc.id == mob.encounter_id:
			return enc
	return null


## Living mobs `caster` summoned.
func live_summons(enc: Encounter, caster: Mob) -> int:
	var n: int = 0
	for mob: Mob in enc.mobs:
		if mob.summoner_id == caster.id and mob.is_alive():
			n += 1
	return n


func _despawn_summons(enc: Encounter, caster: Mob) -> void:
	for i: int in range(enc.mobs.size() - 1, -1, -1):
		if enc.mobs[i].summoner_id == caster.id:
			enc.mobs.remove_at(i)


func _despawn_all_summons(enc: Encounter) -> void:
	for i: int in range(enc.mobs.size() - 1, -1, -1):
		if enc.mobs[i].is_summoned():
			enc.mobs.remove_at(i)


## True when `mob` (a caster) may chant now: none of its moths lives and the lockout since its last cast is over (the first one a little
## after the fight began).
func _summon_ready(core: RefCounted, enc: Encounter, mob: Mob) -> bool:
	var cfg: Dictionary = mob.stats()["summon"]
	if mob.summon_ready_tick < 0:
		mob.summon_ready_tick = core.tick + int(cfg["first_ready"])
	return core.tick >= mob.summon_ready_tick and live_summons(enc, mob) == 0


## The chant: the horns glow for the windup, no warning area (nothing here hurts). cast_start/cast_release are absolute ticks.
func _begin_chant(core: RefCounted, mob: Mob, atk: Dictionary, events: Array[GameEvent]) -> void:
	mob.attack_dir = _toward(mob.position, core.player.position, mob.facing)
	mob.facing = mob.attack_dir
	mob.attack_done = true
	mob.cast_start = core.tick
	mob.cast_release = core.tick + int(atk["windup"])
	mob.set_state(&"windup")
	events.append(GameEvent.new(GameEvent.MOB_SUMMON_STARTED, core.tick, {
		"scene": scene_id, "mob_id": mob.id, "attack": StringName(atk["id"]), "cast_start_tick": mob.cast_start, "cast_release_tick": mob.cast_release,
	}))


## The release: exactly `count` moths at valid places around the caster (free ground, not on the hero, not at an exit), awake and staggered.
func _summon(core: RefCounted, enc: Encounter, mob: Mob, events: Array[GameEvent]) -> void:
	var cfg: Dictionary = mob.stats()["summon"]
	var positions: Array[Vector2] = _summon_positions(core, mob, int(cfg["count"]), cfg)
	var ids: Array[int] = []
	for i: int in positions.size():
		var moth: Mob = Mob.new()
		moth.setup(_next_summoned_id, StringName(cfg["type"]), enc.id, positions[i], 100 + i)
		_next_summoned_id += 1
		moth.summoner_id = mob.id
		moth.state = &"chase"
		moth.cooldown = Tuning.MOB_FIRST_COOLDOWN + Tuning.MOB_COOLDOWN_STAGGER * i
		moth.facing = _toward(positions[i], core.player.position, Vector2.LEFT)
		enc.mobs.append(moth)
		ids.append(moth.id)
	mob.summon_ready_tick = core.tick + int(cfg["lockout"])
	events.append(GameEvent.new(GameEvent.MOB_SUMMONED, core.tick, {"scene": scene_id, "mob_id": mob.id, "summoned_ids": ids, "positions": positions.duplicate()}))


# ---- deterministic placement (the same tick and mob give the same places; no random generator is used) ----------------------------

static func _lcg(state: int) -> int:
	return (state * 1103515245 + 12345) & 0x7fffffff


static func _unit(state: int) -> float:
	return float((state >> 8) % 10000) / 10000.0


## A spot a burst or a moth may use: inside the world, clear of props and the walkable edge, away from the exits.
func _spot_ok(core: RefCounted, p: Vector2, clearance: float) -> bool:
	var size: Vector2 = core.def.get("size", Vector2(100000, 100000))
	if not Rect2(Vector2.ZERO, size).grow(-12.0).has_point(p):
		return false
	if not Collision.fits(core.obstacles, p, clearance):
		return false
	for row: Variant in core.def.get("exits", []):
		var exit_row: Dictionary = row
		if (exit_row["rect"] as Rect2).grow(40.0).has_point(p):
			return false
	return true


## True when the hero standing at `from` can reach, within `reach` px, a free spot that none of the bursts (circles of `radius`) covers.
func _has_escape(core: RefCounted, from: Vector2, sites: Array[Vector2], radius: float, reach: float) -> bool:
	var margin: float = radius + Tuning.PLAYER_RADIUS + 2.0
	var r: float = margin
	while r <= reach:
		for k: int in 16:
			var q: Vector2 = from + Vector2.RIGHT.rotated(float(k) * TAU / 16.0) * r
			if not _spot_ok(core, q, Tuning.PLAYER_RADIUS):
				continue
			var clear: bool = true
			for s: Vector2 in sites:
				if q.distance_to(s) <= margin:
					clear = false
					break
			if clear:
				return true
		r += 4.0
	return false


## The `sites` centres of a many-burst attack: the first where the hero stands (target lock, as the single burst always did), the others at
## valid, mutually distinct spots over the fight floor and a margin around it, rejecting any spot that would leave the hero no way out.
func _root_sites(core: RefCounted, mob: Mob, atk: Dictionary) -> Array[Vector2]:
	var enc: Encounter = _encounter_of(mob)
	var radius: float = float(atk["reach"])
	var spacing: float = float(atk.get("site_spacing", 40.0))
	var reach: float = float(atk.get("escape_reach", 70.0))
	var hero: Vector2 = core.player.position
	var sites: Array[Vector2] = [hero]
	var area: Rect2 = enc.rect.grow(60.0)
	var state: int = _lcg(mob.id * 7919 + core.tick * 104729 + 17)
	var tries: int = 0
	while sites.size() < int(atk["sites"]) and tries < 600:
		tries += 1
		state = _lcg(state)
		var x: float = area.position.x + _unit(state) * area.size.x
		state = _lcg(state)
		var y: float = area.position.y + _unit(state) * area.size.y
		var p: Vector2 = Vector2(roundf(x), roundf(y))
		if not _spot_ok(core, p, radius * 0.5):
			continue
		var distinct: bool = true
		for s: Vector2 in sites:
			if s.distance_to(p) < spacing:
				distinct = false
				break
		if not distinct:
			continue
		var trial: Array[Vector2] = sites.duplicate()
		trial.append(p)
		if not _has_escape(core, hero, trial, radius, reach):
			continue
		sites.append(p)
	return sites


## `count` places for summoned moths on a ring around `caster`, never on the hero or at an exit, apart from each other; the ring widens when the
## first pass finds too few, so the number is always exact.
func _summon_positions(core: RefCounted, caster: Mob, count: int, cfg: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var state: int = _lcg(caster.id * 6151 + core.tick * 31337 + 5)
	var widen: float = 0.0
	var tries: int = 0
	while out.size() < count and tries < 4000:
		tries += 1
		if tries % 400 == 0:
			widen += 30.0
		state = _lcg(state)
		var angle: float = _unit(state) * TAU
		state = _lcg(state)
		var dist: float = float(cfg["ring_min"]) + _unit(state) * (float(cfg["ring_max"]) + widen - float(cfg["ring_min"]))
		var p: Vector2 = (caster.position + Vector2.RIGHT.rotated(angle) * dist).round()
		if not _spot_ok(core, p, 8.0):
			continue
		if p.distance_to(core.player.position) < 28.0:
			continue
		var apart: bool = true
		for q: Vector2 in out:
			if q.distance_to(p) < 20.0:
				apart = false
				break
		if apart:
			out.append(p)
	while out.size() < count:  # unreachable on any real map; keeps "exactly five" even so
		out.append(caster.position + Vector2(float(out.size()) * 12.0, 0.0))
	return out


# ---- the Stag's regeneration -------------------------------------------------------------------------------------------------

## While any moth this caster called lives, the caster heals `regen_per_second` of its maximum health each second IN TOTAL (never per moth),
## accumulating the fraction; it reports the healed amount once a second and when it stops. Dead casters do not heal.
func _regen(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	for mob: Mob in enc.mobs:
		if not mob.stats().has("summon"):
			continue
		var live: int = live_summons(enc, mob)
		var active: bool = live > 0 and mob.is_alive()
		if active:
			if mob.hp < mob.max_hp:
				mob.regen_acc += float(mob.max_hp) * float(mob.stats()["summon"]["regen_per_second"]) * Tuning.TICK_DT
				var whole: int = mini(int(mob.regen_acc), mob.max_hp - mob.hp)
				if whole > 0:
					mob.hp += whole
					mob.regen_acc -= float(whole)
					mob.regen_pending += whole
			else:
				mob.regen_acc = 0.0
			mob.regen_ticks += 1
			if mob.regen_ticks % 60 == 0:
				_report_regen(core, mob, live, events)
		elif mob.regen_ticks > 0 or mob.regen_pending > 0:
			_report_regen(core, mob, live, events)
			mob.regen_ticks = 0
			mob.regen_acc = 0.0


func _report_regen(core: RefCounted, mob: Mob, live: int, events: Array[GameEvent]) -> void:
	if mob.regen_pending > 0:
		events.append(GameEvent.new(GameEvent.MOB_HEALED, core.tick, {
			"scene": scene_id, "mob_id": mob.id, "amount": mob.regen_pending, "hp": mob.hp, "live_summons": live, "source": &"summons",
		}))
	mob.regen_pending = 0


## True when `mob` regenerates now: it is alive and at least one moth of its own lives.
func regen_active(enc: Encounter, mob: Mob) -> bool:
	return mob.stats().has("summon") and mob.is_alive() and live_summons(enc, mob) > 0


## True when another mob of `mob`'s type is winding up or striking (a `solo_attack` type attacks one at a time).
func _type_attacking(enc: Encounter, mob: Mob) -> bool:
	for other: Mob in enc.mobs:
		if other != mob and other.type == mob.type and other.is_attacking():
			return true
	return false


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
		mob.clear_telegraph()
		mob.cooldown = Tuning.MOB_FIRST_COOLDOWN + Tuning.MOB_COOLDOWN_STAGGER * mob.slot
		mob.facing = _toward(mob.position, hero, mob.facing)
		mob.set_state(&"alert")
		events.append(GameEvent.new(GameEvent.MOB_ALERTED, core.tick, {"scene": scene_id, "mob_id": mob.id, "type": mob.type, "encounter_id": enc.id, "position": mob.position}))


## The hero's distance from the encounter: give up after MOB_LEASH_GRACE_TICKS, start over after MOB_RESET_TICKS.
func _leash(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	if enc.managed:
		return
	var inside: bool = core.player.position.distance_to(enc.anchor) <= enc.leash
	enc.outside_ticks = 0 if inside else enc.outside_ticks + 1
	if enc.state == ACTIVE and enc.outside_ticks >= Tuning.MOB_LEASH_GRACE_TICKS:
		_give_up(core, enc, events)
	if enc.outside_ticks >= Tuning.MOB_RESET_TICKS and enc.touched and enc.state == DORMANT:
		reset_encounter(enc, core.tick, &"leash", events)


func _give_up(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	enc.state = DORMANT
	for mob: Mob in _alive(enc):
		mob.clear_telegraph()
		mob.set_state(&"return")
		events.append(GameEvent.new(GameEvent.MOB_LEASHED, core.tick, {"scene": scene_id, "mob_id": mob.id, "encounter_id": enc.id}))


## Every uncleared encounter whole again (the hero's defeat). Emits `encounter_reset` for those that had been touched.
func reset_all(tick: int, reason: StringName, events: Array[GameEvent]) -> void:
	for enc: Encounter in encounters:
		if enc.state != CLEARED:
			reset_encounter(enc, tick, reason, events)


func reset_encounter(enc: Encounter, tick: int, reason: StringName, events: Array[GameEvent]) -> void:
	var was_touched: bool = enc.touched
	_end_projectiles_of(tick, 0, enc.id, &"reset", events)
	_despawn_all_summons(enc)
	if enc.managed:  # a trial's mobs only exist during the try
		enc.mobs.clear()
		enc.max_attackers = Tuning.MOB_MAX_ATTACKERS
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
	var guarded: bool = mob.is_guarded()
	var multiplier: float = Tuning.MOB_EXPOSED_MULT if exposed else (float(mob.stats()["guard"]) if guarded else 1.0)
	var damage: int = maxi(1, roundi(base * multiplier))
	mob.hp = maxi(0, mob.hp - damage)
	mob.last_hit_tick = core.tick
	enc.touched = true
	var data: Dictionary = {
		"attacker_id": player.id, "target_id": mob.id, "damage": damage, "kind": &"counter" if exposed else &"normal",
		"position": mob.position,
	}
	if guarded:
		data["guarded"] = true  # a reduced hit on a guarded mob (presentation: the guard-hit spark and sound)
	data.merge(extra)
	events.append(GameEvent.new(GameEvent.ATTACK_HIT, core.tick, data))
	if mob.hp <= 0:
		_kill(core, enc, mob, events)
		if enc.state == CLEARED:
			return true
	elif mob.phase == 1 and mob.stats().has("phase2_hp") and float(mob.hp) <= float(mob.max_hp) * float(mob.stats()["phase2_hp"]):
		_begin_phase_two(core, mob, events)
	elif mob.state == &"windup" and bool(mob.attack_stats()["interrupt"]):
		mob.clear_telegraph()
		mob.cooldown = int(mob.attack_stats()["cooldown"])
		mob.set_state(&"hurt")
	elif mob.state in [&"alert", &"chase", &"recover", &"hurt", &"return"]:
		mob.set_state(&"hurt")
	return false


func _kill(core: RefCounted, enc: Encounter, mob: Mob, events: Array[GameEvent]) -> void:
	mob.hp = 0
	mob.clear_telegraph()
	mob.set_state(&"dead")
	events.append(GameEvent.new(GameEvent.MOB_DEFEATED, core.tick, {"scene": scene_id, "mob_id": mob.id, "type": mob.type, "encounter_id": enc.id, "position": mob.position}))
	_end_projectiles_of(core.tick, mob.id, &"", &"owner", events)
	if mob.is_summoned():  # a called moth pays nothing and is not remembered
		return
	if enc.managed:  # a trial wave: pays EXP and rolls its drop, is not remembered, and the trial (not the field) decides what comes next
		var paid: Dictionary = mob.stats()
		core.give_exp(int(paid["exp"]), mob.id, events)
		var roll: Dictionary = paid["drop"]
		if drop_roll(mob.id) < float(roll["chance"]):
			events.append(GameEvent.new(GameEvent.MOB_DROPPED, core.tick, {"scene": scene_id, "mob_id": mob.id, "item_id": roll["item"], "position": mob.position}))
			core.give_item({"reward_id": "%s_drop_%d" % [String(enc.id), mob.id], "kind": "item", "item": roll["item"], "name": String(roll["item"]).capitalize(), "quantity": 1}, enc.id, events)
		if mob.stats().has("summon"):
			_despawn_summons(enc, mob)
		return
	mob.killed = true
	if mob.stats().has("summon"):  # the caster fell: its moths (and their orbs) go with it
		for moth: Mob in enc.mobs:
			if moth.summoner_id == mob.id:
				_end_projectiles_of(core.tick, moth.id, &"", &"owner", events)
		_despawn_summons(enc, mob)
	var flag: StringName = kill_flag(enc, mob)
	if core._grant_flag(flag, events):  # the first time only
		var stats: Dictionary = mob.stats()
		core.give_exp(int(stats["exp"]), mob.id, events)
		var drop: Dictionary = stats["drop"]
		if drop_roll(mob.id) < float(drop["chance"]):
			events.append(GameEvent.new(GameEvent.MOB_DROPPED, core.tick, {"scene": scene_id, "mob_id": mob.id, "item_id": drop["item"], "position": mob.position}))
			core.give_item({"reward_id": "%s_drop" % flag, "kind": "item", "item": drop["item"], "name": String(drop["item"]).capitalize(), "quantity": 1}, enc.id, events)
	if _alive_regular(enc).is_empty():
		_clear(core, enc, events)


func _clear(core: RefCounted, enc: Encounter, events: Array[GameEvent]) -> void:
	enc.state = CLEARED
	_end_projectiles_of(core.tick, 0, enc.id, &"reset", events)
	_despawn_all_summons(enc)
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
				if atk.has("summon"):
					_summon(core, enc, mob, events)
				elif atk.has("projectile"):
					_fire(core, enc, mob, atk, events)
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
		&"roar":
			if mob.state_ticks >= int(mob.stats().get("roar_ticks", 48)):
				mob.set_state(&"chase")
		&"return":
			_walk_home(core, mob)
	if mob.state == &"chase" and mob.position.distance_to(mob.home) > float(mob.stats()["tether"]):
		mob.set_state(&"return")
		events.append(GameEvent.new(GameEvent.MOB_LEASHED, core.tick, {"scene": scene_id, "mob_id": mob.id, "encounter_id": enc.id}))


func _chase(core: RefCounted, enc: Encounter, mob: Mob, attackers: int, events: Array[GameEvent]) -> void:
	var player: PlayerState = core.player
	var to_hero: Vector2 = player.position - mob.position
	var dist: float = to_hero.length()
	mob.facing = _toward(mob.position, player.position, mob.facing)
	if mob.cooldown <= 0 and attackers < enc.max_attackers and not (bool(mob.stats().get("solo_attack", false)) and _type_attacking(enc, mob)):
		var chosen: Dictionary = _pick_attack(core, enc, mob, dist)
		if not chosen.is_empty():
			mob.current_attack = chosen if not mob.attacks().is_empty() else {}
			_begin_attack(core, mob, events)
			return
	var stats: Dictionary = mob.stats()
	var hold: float = float(stats["hold"])
	if attackers >= enc.max_attackers:
		hold = maxf(hold, float(stats["wait"]))
	if dist > hold:
		_move(core, mob, to_hero / dist, float(stats["speed"]))


func _begin_attack(core: RefCounted, mob: Mob, events: Array[GameEvent]) -> void:
	var atk: Dictionary = mob.attack_stats()
	if atk.has("summon"):
		_begin_chant(core, mob, atk, events)
		return
	mob.cast_start = -1
	mob.cast_release = -1
	var dir: Vector2 = _toward(mob.position, core.player.position, mob.facing)
	mob.attack_dir = dir
	var shape: StringName = StringName(atk.get("shape", &"line"))
	mob.facing = dir
	mob.attack_done = false
	mob.set_state(&"windup")
	var t: Telegraph = Telegraph.new()
	t.id = _next_telegraph
	_next_telegraph += 1
	t.owner_id = mob.id
	t.attack = StringName(atk["id"])
	t.kind = StringName(atk["kind"])
	t.shape = shape
	t.center = mob.position
	t.muzzle = mob.position
	t.direction = dir
	match shape:
		Telegraph.SHAPE_CONE:
			t.size = float(atk["reach"]) + mob.radius
			t.half_angle = float(atk["half_angle"])
		Telegraph.SHAPE_CIRCLE:
			t.center = mob.position if bool(atk.get("centered", false)) else core.player.position  # the burst lands where the hero stood when it began (or around the mob)
			t.muzzle = mob.position
			t.size = float(atk["reach"])
		_:
			t.size = float(atk["reach"]) if bool(atk.get("stationary", false)) else float(atk["strike_speed"]) * float(atk["strike_ticks"]) + mob.radius
			t.width = float(atk["width"])
	t.damage = int(atk["damage"])
	t.start_tick = core.tick
	t.hit_tick = core.tick + int(atk["windup"])
	t.end_tick = t.hit_tick + int(atk["strike_ticks"])
	mob.telegraph = t
	var ids: Array[int] = [t.id]
	if atk.has("sites"):  # many separate bursts (the Stag's eight roots): each site gets its own warning, all committed together
		var sites: Array[Vector2] = _root_sites(core, mob, atk)
		t.center = sites[0]
		for i: int in range(1, sites.size()):
			var more: Telegraph = Telegraph.new()
			more.id = _next_telegraph
			_next_telegraph += 1
			more.owner_id = t.owner_id
			more.attack = t.attack
			more.kind = t.kind
			more.shape = t.shape
			more.center = sites[i]
			more.muzzle = t.muzzle
			more.direction = t.direction
			more.size = t.size
			more.damage = t.damage
			more.start_tick = t.start_tick
			more.hit_tick = t.hit_tick
			more.end_tick = t.end_tick
			mob.extra_telegraphs.append(more)
			ids.append(more.id)
	events.append(GameEvent.new(GameEvent.ATTACK_TELEGRAPHED, core.tick, {
		"telegraph_id": t.id, "telegraph_ids": ids, "sites": ids.size(), "owner_id": mob.id, "kind": t.kind, "attack": t.attack, "scene": scene_id, "mob_id": mob.id,
		"hit_tick": t.hit_tick, "end_tick": t.end_tick,
	}))


func _strike(core: RefCounted, mob: Mob, events: Array[GameEvent]) -> void:
	var atk: Dictionary = mob.attack_stats()
	if atk.has("summon") or atk.has("projectile"):  # the release frames: the chant or the orb already left
		mob.strike_left -= 1
		if mob.strike_left <= 0:
			mob.cooldown = int(atk["cooldown"])
			mob.set_state(&"recover")
		return
	if StringName(atk.get("shape", &"line")) != Telegraph.SHAPE_LINE or bool(atk.get("stationary", false)):
		_strike_area(core, mob, atk, events)
		return
	var speed: float = float(atk["strike_speed"])
	var before: Vector2 = mob.position
	mob.position = Collision.move_resolved(core.obstacles, before, before + mob.attack_dir * speed, mob.radius)
	mob.strike_left -= 1
	var player: PlayerState = core.player
	if not mob.attack_done and player.position.distance_to(mob.position) <= mob.radius + Tuning.PLAYER_RADIUS:
		_land(core, mob, atk, events)
	var crash: int = int(atk["crash"])
	if mob.state == &"strike" and crash > 0 and mob.position.distance_to(before) < speed * 0.5:
		mob.clear_telegraph()
		mob.cooldown = int(atk["cooldown"])
		mob.set_state(&"crash")
		events.append(GameEvent.new(GameEvent.MOB_STAGGERED, core.tick, {"scene": scene_id, "mob_id": mob.id, "reason": &"crash", "position": mob.position}))
	elif mob.state == &"strike" and mob.strike_left <= 0:
		mob.clear_telegraph()
		mob.cooldown = int(atk["cooldown"])
		mob.set_state(&"recover")


## A cone or a burst: the mob stands still; whatever the warning covers is hit for the whole strike window (once).
func _strike_area(core: RefCounted, mob: Mob, atk: Dictionary, events: Array[GameEvent]) -> void:
	mob.strike_left -= 1
	var covered: bool = false
	for warning: Telegraph in mob.all_telegraphs():
		if warning.overlaps_circle(core.player.position, Tuning.PLAYER_RADIUS):
			covered = true
	if not mob.attack_done and covered:
		_land(core, mob, atk, events)
	if mob.state == &"strike" and mob.strike_left <= 0:
		mob.clear_telegraph()
		mob.cooldown = int(atk["cooldown"])
		if atk.has("chain"):  # not parried (a parry left the strike state): the next attack follows quickly
			mob.chain_next = StringName(atk["chain"]["id"])
			mob.cooldown = int(atk["chain"]["delay"])
		mob.set_state(&"recover")


## The attack a many-attack mob starts from `dist` away: the next one in its rotation that fits the distance and its phase; for a one-attack
## mob its own row when the distance fits. {} when none fits yet.
func _pick_attack(core: RefCounted, enc: Encounter, mob: Mob, dist: float) -> Dictionary:
	var rows: Array = mob.attacks()
	if mob.chain_next != &"":
		var wanted: StringName = mob.chain_next
		mob.chain_next = &""
		for row: Dictionary in rows:
			if StringName(row["id"]) == wanted:
				return row
	if rows.is_empty():
		var one: Dictionary = mob.attack_stats()
		return one if dist >= float(one["start_min"]) and dist <= float(one["start_max"]) else {}
	for offset: int in rows.size():
		var row: Dictionary = rows[(mob.attack_index + offset) % rows.size()]
		if int(row.get("phase", 1)) > mob.phase:
			continue
		if row.has("summon") and not _summon_ready(core, enc, mob):
			continue
		if dist >= float(row["start_min"]) and dist <= float(row["start_max"]):
			mob.attack_index = (mob.attack_index + offset + 1) % rows.size()
			return row
	return {}


## The Stag at half health: it stops attacking, roars, and the roots join its attacks.
func _begin_phase_two(core: RefCounted, mob: Mob, events: Array[GameEvent]) -> void:
	mob.phase = 2
	mob.clear_telegraph()
	mob.cooldown = int(mob.stats().get("roar_ticks", 48)) + 20
	mob.set_state(&"roar")
	events.append(GameEvent.new(GameEvent.BOSS_PHASE_CHANGED, core.tick, {"entity_id": mob.id, "phase": 2, "scene": scene_id, "position": mob.position}))


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
		mob.clear_telegraph()
		mob.chain_next = &""
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
				"exposed": mob.is_exposed(), "guarded": mob.is_guarded(), "dragged": mob.dragged, "boss": bool(mob.stats().get("boss", false)), "phase": mob.phase, "attack_id": mob.attack_stats()["id"], "attack": mob.telegraph.attack if mob.telegraph != null else &"", "since_hit": tick - mob.last_hit_tick,
				"summoner_id": mob.summoner_id, "regen_active": regen_active(enc, mob), "live_summons": live_summons(enc, mob) if mob.stats().has("summon") else 0,
				"cast_start_tick": mob.cast_start, "cast_release_tick": mob.cast_release,
			})
	return out


## [{id, name, state (dormant, active, cleared), rect, anchor, leash, alive, total, reward_id}].
func encounter_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enc: Encounter in encounters:
		var alive: int = _alive_regular(enc).size()
		out.append({
			"id": enc.id, "name": enc.label, "state": enc.state, "rect": enc.rect, "anchor": enc.anchor, "leash": enc.leash,
			"alive": alive, "total": _regular_total(enc), "reward_id": StringName(str(enc.reward.get("reward_id", ""))),
		})
	return out


## The mobs' running warnings in the fight's snapshot type (gold = parry it, red = dash it).
func telegraph_snapshots() -> Array[Snapshots.TelegraphSnapshot]:
	var out: Array[Snapshots.TelegraphSnapshot] = []
	for enc: Encounter in encounters:
		for mob: Mob in enc.mobs:
			for t: Telegraph in mob.all_telegraphs():
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
				s.half_angle = t.half_angle  # a cone is drawn from this: without it the warning is a flat line
				s.inner_size = t.inner_size
				s.start_tick = t.start_tick
				s.hit_tick = t.hit_tick
				s.end_tick = t.end_tick
				out.append(s)
	return out
