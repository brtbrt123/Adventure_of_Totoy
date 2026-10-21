extends RefCounted
## Visual cadence only. State lifetimes and impacts always come from snapshots.
const PlayerState := preload("res://core/player.gd")
const Tuning := preload("res://core/tuning.gd")
const Snapshots := preload("res://core/snapshots.gd")
const Weapons := preload("res://core/weapons.gd")
const ScytheEffects := preload("res://presentation/arena/scythe_effects.gd")
const WardEchoSprintEffects := preload("res://presentation/arena/ward_echo_sprint_effects.gd")
## Stone Ward pose frame counts (raise, hold loop, drop) of every hero set.
const WARD_POSES: Dictionary = {"ward_raise": 4, "ward_hold": 4, "ward_drop": 3}
## Hero frame sets by equipped weapon (same numbering per state): katana, dagger, dagger in Lightning Form, scythe.
const SET_KATANA: String = "hero2"
const SET_DAGGER: String = "totoy_dagger"
const SET_LIGHTNING: String = "totoy_lightning"
const SET_SCYTHE: String = "totoy_scythe"
## Poses the Lightning Form set has art for; any other pose (victory) uses the plain dagger frame.
const LIGHTNING_POSES: Array[String] = ["idle", "walk", "dash", "parry", "hurt", "attack1", "attack2", "attack3", "attack4"]
const DIRECTIONS: Array[String] = ["right"]
# [frame count, ticks per frame, loop]. Sword phases use per-swing tuning;
# boss windups use telegraph progress. Attack entries only declare frame counts.
const PLAYER: Dictionary = {
	"idle": [4, 12, true], "walk": [6, 5, true], "dash": [4, 1, false],
	"parry": [6, 2, false], "parry_recovery": [1, 1, false],
	"attack_windup": [2, 1, false], "attack_active": [2, 1, false],
	"attack_recovery": [2, 1, false], "dead": [1, 1, false],
	"hurt": [4, 3, false], "victory": [6, 8, false],
}
const BOSS: Dictionary = {
	"idle": [4, 16, true], "walk": [6, 5, true],
	"slam": [6, 3, false], "sweep": [6, 3, false], "stomp": [6, 3, false],
	"charge": [6, 3, false], "beam": [6, 3, false],
	"staggered": [4, 8, true], "hurt": [4, 3, false],
	"roar": [6, 5, false], "death": [8, 6, false],
}
const ATTACKS: Dictionary = {"gold_slam": "slam", "gold_combo": "slam", "red_sweep": "sweep", "red_stomp": "stomp", "red_charge": "charge", "red_shards": "beam"}
const STRIKE_HOLD_TICKS: int = 4
## Destination position stays fixed when Godot flips a negative-width region.
static func destination(at: Vector2, frame: Dictionary, left: bool) -> Rect2:
	var w: float = float(frame["w"])
	var h: float = float(frame["h"])
	var anchor: Vector2 = Vector2(float(frame.get("ax", w * 0.5)), float(frame.get("ay", h - 4)))
	return Rect2(at.round() - Vector2(w - anchor.x if left else anchor.x, anchor.y), Vector2(-w if left else w, h))

static func direction(_facing: Vector2) -> String:
	return "right"

static func mirrored(facing: Vector2) -> bool:
	return facing.x < -0.3

static func frame_index(spec: Array, ticks: int) -> int:
	var count: int = int(spec[0])
	var elapsed: int = floori(float(maxi(0, ticks)) / int(spec[1]))
	return (elapsed % count if bool(spec[2]) else mini(count - 1, elapsed)) + 1

static func choose(actor: Snapshots.EntitySnapshot, snap: Snapshots.GameSnapshot, last_attack: Dictionary) -> String:
	var state: String = String(actor.state)
	if actor.visual_id == &"totoy":
		var ticks: int = actor.state_ticks
		if snap.result == &"victory":
			state = "victory"
			ticks = snap.result_ticks
		var prefix: String = hero_set(actor)
		if state == "dead":
			return hero_frame(prefix, "hurt", 4)
		if state.begins_with("skill_"):
			return skill_frame(actor.skill_id, actor.state, ticks, prefix)
		if state == String(PlayerState.STATE_REAPER_COIL):
			# Reaper's Coil poses by the core's phase and phase tick (wind-up/throw, haul, spin, catch).
			return ScytheEffects.coil_frame(actor.reaper_coil_phase, actor.reaper_coil_phase_tick)
		if state == String(PlayerState.STATE_LIGHTNING_BARRAGE):
			return barrage_frame(prefix, actor.lightning_barrage_slash, snap.tick - actor.lightning_barrage_slash_tick)
		if state.begins_with("attack_"):
			# Per-weapon swing tables (the dagger has 4 swings) at the speed core locked for this swing.
			var swing: int = clampi(actor.combo_index, 1, Weapons.combo_max(actor.weapon_id))
			var phase: int = 0 if state == "attack_windup" else (1 if state == "attack_active" else 2)
			var base: int = Weapons.swing_phases(actor.weapon_id, swing)[phase]
			var duration: int = maxi(1, PlayerState.scaled_ticks(base, actor.attack_speed_mult))
			# A one-tick phase (dagger swings in Lightning Form) shows its key pose, the second frame (the strike).
			var index: int = 2 if duration == 1 else mini(1, maxi(0, ticks) * 2 / duration) + 1
			return hero_frame(prefix, "attack%d" % swing, phase * 2 + index)
		if state == "parry_recovery":
			return hero_frame(prefix, "parry", 6)
		if state == String(PlayerState.STATE_WARD):
			# Stone Ward: raise, hold loop, drop on the last ticks, timed by the core's ward_ticks_left.
			return ward_frame(prefix, actor.ward_ticks_left)
		if state == "walk":
			# The walk cycle runs at the walking speed's rate (twice as fast while Sprint runs).
			return hero_frame(prefix, "walk", frame_index(PLAYER["walk"], walk_ticks(ticks, actor.move_speed_mult)))
		if not PLAYER.has(state):
			state = "idle"
		return hero_frame(prefix, state, frame_index(PLAYER[state], ticks))
	if state == "dead":
		return "golem2_death_%d" % frame_index(BOSS["death"], snap.result_ticks)
	if state == "attack":
		var tell: Snapshots.TelegraphSnapshot = attack_tell(actor.id, snap)
		if tell != null:
			var pose: String = ATTACKS.get(String(tell.attack), "slam")
			var index: int = 4 + mini(2, maxi(0, snap.tick - tell.hit_tick) / 3)
			if snap.tick < tell.hit_tick:
				var start_tick: int = tell.start_tick
				for earlier: Snapshots.TelegraphSnapshot in snap.telegraphs:
					if earlier.owner_id == actor.id and earlier.attack == tell.attack and earlier.hit_tick < tell.hit_tick:
						start_tick = maxi(start_tick, earlier.end_tick + STRIKE_HOLD_TICKS + 1)
				var progress: float = clampf(float(snap.tick - start_tick) / maxi(1, tell.hit_tick - start_tick), 0.0, 1.0)
				index = mini(2, floori(progress * 3)) + 1
			return "golem2_%s_%d" % [pose, index]
	if state == "recover" and not last_attack.is_empty():
		var index: int = 4 + mini(2, maxi(0, snap.tick - int(last_attack["hit_tick"])) / 3)
		return "golem2_%s_%d" % [ATTACKS.get(String(last_attack["attack"]), "slam"), index]
	if state == "posture_broken":
		state = "staggered"
	if state == "recover":
		state = "idle"
	return "golem2_%s_%d" % [state, frame_index(BOSS.get(state, BOSS["idle"]), actor.state_ticks)]

## Walk-cycle ticks scaled by the move speed multiplier (the cycle plays `mult` times as fast; 1.0 unchanged).
static func walk_ticks(ticks: int, mult: float) -> int:
	return floori(maxi(0, ticks) * maxf(1.0, mult))

## `<set>_ward_<raise|hold|drop>_right_<n>` from ward_ticks_left (WardEchoSprintEffects.ward_pose has the timing).
static func ward_frame(prefix: String, ward_ticks_left: int) -> String:
	if prefix == SET_LIGHTNING:
		prefix = SET_DAGGER
	var pose: Array = WardEchoSprintEffects.ward_pose(maxi(1, ward_ticks_left))
	return hero_frame(prefix, "ward_%s" % pose[0], int(pose[1]))

## The hero frame whose per-frame overlays (Phantom glow, sprint aura and afterimages, echo shield) fit `frame`: a
## Stone Ward frame is idle frame ((n - 1) % 4) + 1 of its set with the slab, same anchor (manifest idle_frame), so it
## borrows that idle frame's overlays; every other frame is its own.
static func overlay_frame(frame: String) -> String:
	var at: int = frame.find("_ward_")
	if at < 0:
		return frame
	var n: int = int(frame.get_slice("_", frame.get_slice_count("_") - 1))
	return "%s_idle_right_%d" % [frame.substr(0, at), (maxi(1, n) - 1) % 4 + 1]

## Lightning Barrage pose: slash n (1-8) cycles the four dagger swings; `age` ticks after its blink it shows the windup
## key frame, then the strike (on the hit tick, LIGHTNING_BARRAGE_HIT_DELAY_TICKS after the blink) and the follow
## through. Before the first slash (the activation tick) the swing 1 start pose.
static func barrage_frame(prefix: String, slash: int, age: int) -> String:
	if slash <= 0:
		return hero_frame(prefix, "attack1", 1)
	var swing: int = (slash - 1) % 4 + 1
	var hit: int = Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS
	var n: int
	if age < hit:
		n = 2 if age < hit - 1 or hit < 2 else 3
	elif age == hit:
		n = 4
	elif age <= hit + 1:
		n = 5
	else:
		n = 6
	return hero_frame(prefix, "attack%d" % swing, n)

## Which hero frame set the actor is drawn with: the equipped weapon, and the Lightning Form look while it runs.
static func hero_set(actor: Snapshots.EntitySnapshot) -> String:
	if actor.weapon_form == Weapons.FORM_LIGHTNING:
		return SET_LIGHTNING
	match actor.weapon_id:
		Tuning.WEAPON_DUAL_DAGGER: return SET_DAGGER
		Tuning.WEAPON_CHAIN_SCYTHE: return SET_SCYTHE
	return SET_KATANA

## The weapon a hero frame set belongs to.
static func set_weapon(prefix: String) -> StringName:
	match prefix:
		SET_DAGGER, SET_LIGHTNING: return Tuning.WEAPON_DUAL_DAGGER
		SET_SCYTHE: return Tuning.WEAPON_CHAIN_SCYTHE
	return Tuning.WEAPON_BLACK_KATANA

## `<set>_<pose>_right_<n>`; the Lightning set borrows the dagger frame for poses it has no art for.
static func hero_frame(prefix: String, pose: String, n: int) -> String:
	if prefix == SET_LIGHTNING and pose not in LIGHTNING_POSES:
		prefix = SET_DAGGER
	return "%s_%s_right_%d" % [prefix, pose, n]

## Every frame a hero set can request (all states, swings 1..combo_max of its weapon).
static func hero_names(prefix: String) -> Array[String]:
	var names: Array[String] = []
	for state: String in ["idle", "walk", "dash", "parry", "hurt", "victory"]:
		for n: int in range(1, int(PLAYER[state][0]) + 1):
			names.append(hero_frame(prefix, state, n))
	var swings: int = Weapons.combo_max(set_weapon(prefix))
	for swing: int in range(1, swings + 1):
		for n: int in range(1, 7):
			names.append(hero_frame(prefix, "attack%d" % swing, n))
	if prefix != SET_LIGHTNING:  # the Lightning set never wards (it uses the dagger frames)
		for pose: String in WARD_POSES:
			for n: int in range(1, int(WARD_POSES[pose]) + 1):
				names.append(hero_frame(prefix, pose, n))
	return names

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for prefix: String in [SET_KATANA, SET_DAGGER, SET_LIGHTNING, SET_SCYTHE]:
		for name_key: String in hero_names(prefix):
			if not names.has(name_key):
				names.append(name_key)
	names.append_array(ScytheEffects.coil_names())
	for state: String in BOSS:
		for n: int in range(1, int(BOSS[state][0]) + 1):
			names.append("golem2_%s_%d" % [state, n])
	return names

## Prefer the most recent impact through its visual hold, then the next warning.
## Sorting by hit time makes the result independent of telegraph array order.
static func attack_tell(owner_id: int, snap: Snapshots.GameSnapshot) -> Snapshots.TelegraphSnapshot:
	var struck: Snapshots.TelegraphSnapshot = null
	var upcoming: Snapshots.TelegraphSnapshot = null
	for tell: Snapshots.TelegraphSnapshot in snap.telegraphs:
		if tell.owner_id != owner_id:
			continue
		if snap.tick >= tell.hit_tick:
			if struck == null or tell.hit_tick > struck.hit_tick:
				struck = tell
		elif upcoming == null or tell.hit_tick < upcoming.hit_tick:
			upcoming = tell
	if struck != null and (upcoming == null or snap.tick <= struck.end_tick + STRIKE_HOLD_TICKS):
		return struck
	return upcoming

## Charge source art faces left; sweep source art uses the opposite convention.
static func _boss_attack_mirrored(attack: StringName, direction_x: float) -> bool:
	if attack == &"red_charge":
		return direction_x > 0.0
	return attack == &"red_sweep" and direction_x < 0.0

static func boss_mirrored(actor: Snapshots.EntitySnapshot, snap: Snapshots.GameSnapshot, history: Dictionary) -> bool:
	var tell: Snapshots.TelegraphSnapshot = attack_tell(actor.id, snap)
	if tell != null:
		return _boss_attack_mirrored(tell.attack, tell.direction.x)
	return actor.state == &"recover" and _boss_attack_mirrored(history.get("attack", &""), float(history.get("direction_x", 0.0)))

## Placeholder poses only; phase lengths are owned by core tuning.
static func skill_durations(skill: StringName) -> Array[int]:
	match skill:
		&"breaking_edge": return [Tuning.BREAKING_EDGE_WINDUP_TICKS, Tuning.BREAKING_EDGE_ACTIVE_TICKS, Tuning.BREAKING_EDGE_RECOVERY_TICKS]
		&"gale_cut": return [Tuning.GALE_CUT_WINDUP_TICKS, Tuning.GALE_CUT_ACTIVE_TICKS, Tuning.GALE_CUT_RECOVERY_TICKS]
		&"moon_cleave": return [Tuning.MOON_CLEAVE_WINDUP_TICKS, Tuning.MOON_CLEAVE_ACTIVE_TICKS, Tuning.MOON_CLEAVE_RECOVERY_TICKS]
		&"spirit_lantern": return [Tuning.SPIRIT_LANTERN_WINDUP_TICKS, Tuning.SPIRIT_LANTERN_ACTIVE_TICKS, Tuning.SPIRIT_LANTERN_RECOVERY_TICKS]
	return [1, 1, 1]

static func skill_frame(skill: StringName, state: StringName, ticks: int, prefix: String = SET_KATANA) -> String:
	var phase: int = 0 if state == &"skill_windup" else (1 if state == &"skill_active" else 2)
	var duration: int = maxi(1, skill_durations(skill)[phase])
	var elapsed: int = clampi(ticks, 0, duration - 1)
	if skill == &"gale_cut" and phase == 1:
		return hero_frame(prefix, "dash", mini(3, elapsed * 4 / duration) + 1)
	var part: int = mini(1, elapsed * 2 / duration)
	if skill == &"moon_cleave" and phase == 0:
		# Establish the pose, then hold frame 2 through the committed charge.
		part = 0 if elapsed < maxi(1, duration / 5) else 1
	return hero_frame(prefix, "attack%d" % (1 if skill == &"gale_cut" else 3), phase * 2 + part + 1)

## Shared phase lengths for cosmetic trails, using the speed locked by core per swing.
static func swing_durations(actor: Snapshots.EntitySnapshot) -> Array[int]:
	var base: Array[int] = Weapons.swing_phases(actor.weapon_id, clampi(actor.combo_index, 1, Weapons.combo_max(actor.weapon_id)))
	return [PlayerState.scaled_ticks(base[0], actor.attack_speed_mult), PlayerState.scaled_ticks(base[1], actor.attack_speed_mult), PlayerState.scaled_ticks(base[2], actor.attack_speed_mult)]
