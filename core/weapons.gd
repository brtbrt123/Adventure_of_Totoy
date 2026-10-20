extends RefCounted
## Per-weapon numbers, looked up by weapon_id. The numbers themselves live in core/tuning.gd; this file only picks the
## right ones, so the player and the core never branch on a weapon by hand. An unknown weapon id swings like the
## katana and has no active (duration, cooldown and cost 0).
## Use: const Weapons := preload("res://core/weapons.gd").

const Tuning := preload("res://core/tuning.gd")

## The swap order (weapon_swap_pressed goes to the next one, wrapping).
const IDS: Array[StringName] = [Tuning.WEAPON_BLACK_KATANA, Tuning.WEAPON_DUAL_DAGGER, Tuning.WEAPON_CHAIN_SCYTHE]
## What the weapon's active is called in events and in snapshot.player.weapon_form.
const FORM_BLACK_KATANA_BUFF: StringName = &"black_katana_buff"
const FORM_LIGHTNING: StringName = &"lightning_form"
const FORM_REAPER_COIL: StringName = &"reaper_coil"


static func is_known(weapon: StringName) -> bool:
	return IDS.has(weapon)


## The weapon a swap changes to (the same id for an unknown weapon: no swap).
static func next(weapon: StringName) -> StringName:
	var i: int = IDS.find(weapon)
	return weapon if i < 0 else IDS[(i + 1) % IDS.size()]


# --- normal swings ---

static func combo_max(weapon: StringName) -> int:
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.DAGGER_COMBO_MAX
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.SCYTHE_COMBO_MAX
	return Tuning.COMBO_MAX


static func windup_ticks(weapon: StringName) -> Array[int]:
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.DAGGER_SWING_WINDUP_TICKS
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.SCYTHE_SWING_WINDUP_TICKS
	return Tuning.SWING_WINDUP_TICKS


static func active_ticks(weapon: StringName) -> Array[int]:
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.DAGGER_SWING_ACTIVE_TICKS
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.SCYTHE_SWING_ACTIVE_TICKS
	return Tuning.SWING_ACTIVE_TICKS


static func recovery_ticks(weapon: StringName) -> Array[int]:
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.DAGGER_SWING_RECOVERY_TICKS
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.SCYTHE_SWING_RECOVERY_TICKS
	return Tuning.SWING_RECOVERY_TICKS


## Base phase lengths of swing `combo_index` (1-based): [windup, active, recovery], before the attack speed.
static func swing_phases(weapon: StringName, combo_index: int) -> Array[int]:
	var i: int = combo_index - 1
	return [windup_ticks(weapon)[i], active_ticks(weapon)[i], recovery_ticks(weapon)[i]]


static func damage_mults(weapon: StringName) -> Array[float]:
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.DAGGER_SWING_DAMAGE_MULT
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.SCYTHE_SWING_DAMAGE_MULT
	return Tuning.SWING_DAMAGE_MULT


static func range_mults(weapon: StringName) -> Array[float]:
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.DAGGER_SWING_RANGE_MULT
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.SCYTHE_SWING_RANGE_MULT
	return Tuning.SWING_RANGE_MULT


## The swing's arc: the boss counts as in front when facing.dot(direction to the boss) >= this (lower = wider).
static func arc_dot(weapon: StringName) -> float:
	return Tuning.SCYTHE_ARC_DOT if weapon == Tuning.WEAPON_CHAIN_SCYTHE else Tuning.ATTACK_ARC_DOT


## Posture a normal (not counter) hit of swing `combo_index` (1-based) adds.
static func swing_posture(weapon: StringName, combo_index: int) -> float:
	if weapon == Tuning.WEAPON_CHAIN_SCYTHE:
		return Tuning.SCYTHE_SWING_POSTURE[combo_index - 1]
	return Tuning.NORMAL_HIT_POSTURE


static func edge_per_hit(weapon: StringName) -> float:
	match weapon:
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.DAGGER_EDGE_PER_HIT
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.SCYTHE_EDGE_PER_HIT
	return Tuning.EDGE_PER_HIT


## True when the last swing of the weapon's combo calls a lightning strike when it connects.
static func has_lightning_finisher(weapon: StringName) -> bool:
	return weapon == Tuning.WEAPON_DUAL_DAGGER


# --- the active (right click) ---

## True when activating the weapon's active also runs the automatic Lightning Barrage (Dual Dagger).
static func has_lightning_barrage(weapon: StringName) -> bool:
	return weapon == Tuning.WEAPON_DUAL_DAGGER


## True when activating the weapon's active runs Reaper's Coil (Chain Scythe).
static func has_reaper_coil(weapon: StringName) -> bool:
	return weapon == Tuning.WEAPON_CHAIN_SCYTHE


## True when the active needs a living boss (the scripted ones: the barrage and Reaper's Coil).
static func active_needs_target(weapon: StringName) -> bool:
	return has_lightning_barrage(weapon) or has_reaper_coil(weapon)


## Slashes in a Lightning Barrage: one per side in LIGHTNING_BLINK_ORDER.
static func barrage_slashes() -> int:
	return Tuning.LIGHTNING_BLINK_ORDER.size()


## Ticks from the activation to the end of a full barrage.
static func barrage_total_ticks() -> int:
	return Tuning.LIGHTNING_BARRAGE_START_DELAY_TICKS + (barrage_slashes() - 1) * Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS + Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS + Tuning.LIGHTNING_BARRAGE_RECOVERY_TICKS


## Most ticks the Reaper's Coil hook can fly (it stops earlier on the boss, a prop or the wall).
static func reaper_coil_hook_ticks() -> int:
	return ceili(Tuning.REAPER_COIL_HOOK_RANGE / Tuning.REAPER_COIL_HOOK_SPEED)


## Most ticks a missed hook's pull can last (it ends earlier when the player arrives or is blocked).
static func reaper_coil_pull_max_ticks() -> int:
	return ceili(Tuning.REAPER_COIL_HOOK_RANGE / Tuning.REAPER_COIL_PULL_SPEED) + 1


## Ticks from the activation to the end of the longest Reaper's Coil (a hook at full range and the longest drag; the
## miss path is shorter). The form's duration; a shorter coil ends the form when it ends.
static func reaper_coil_total_ticks() -> int:
	var hit: int = reaper_coil_hook_ticks() + Tuning.REAPER_COIL_DRAG_MAX_TICKS + Tuning.REAPER_COIL_SPIN_TICKS + Tuning.REAPER_COIL_RECOVERY_TICKS
	var miss: int = reaper_coil_hook_ticks() + reaper_coil_pull_max_ticks() + Tuning.REAPER_COIL_PULL_RECOVERY_TICKS
	return maxi(hit, miss)


## Spin tick (1-based within the spin phase) of spin hit `hit_index` (1-based).
static func reaper_coil_spin_hit_tick(hit_index: int) -> int:
	return Tuning.REAPER_COIL_SPIN_FIRST_HIT_TICK + (hit_index - 1) * Tuning.REAPER_COIL_SPIN_HIT_INTERVAL_TICKS


static func has_active(weapon: StringName) -> bool:
	return is_known(weapon)


static func active_form(weapon: StringName) -> StringName:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return FORM_BLACK_KATANA_BUFF
		Tuning.WEAPON_DUAL_DAGGER:
			return FORM_LIGHTNING
		Tuning.WEAPON_CHAIN_SCYTHE:
			return FORM_REAPER_COIL
	return &""


static func active_duration(weapon: StringName) -> int:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_BUFF_DURATION_TICKS
		Tuning.WEAPON_DUAL_DAGGER:
			return barrage_total_ticks()  # Lightning Form is only the barrage
		Tuning.WEAPON_CHAIN_SCYTHE:
			return reaper_coil_total_ticks()  # the "form" is only the skill
	return 0


static func active_cooldown(weapon: StringName) -> int:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.LIGHTNING_FORM_COOLDOWN_TICKS
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.REAPER_COIL_COOLDOWN_TICKS
	return 0


static func active_edge_cost(weapon: StringName) -> float:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_BUFF_EDGE_COST
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.LIGHTNING_FORM_EDGE_COST
		Tuning.WEAPON_CHAIN_SCYTHE:
			return Tuning.REAPER_COIL_EDGE_COST
	return 0.0


static func active_attack_speed_mult(weapon: StringName) -> float:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_ATTACK_SPEED_MULT
	return 1.0


static func active_damage_mult(weapon: StringName) -> float:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_DAMAGE_MULT
	return 1.0


static func active_move_speed_mult(weapon: StringName) -> float:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_MOVE_SPEED_MULT
	return 1.0


## The unit vector of blink direction `index` (0-7): Vector2.RIGHT rotated by index * 45 degrees (y points down).
static func blink_direction(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(float(posmod(index, 8)) * PI / 4.0)
