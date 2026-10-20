extends RefCounted
## Per-weapon numbers, looked up by weapon_id. The numbers themselves live in core/tuning.gd; this file only picks the
## right ones, so the player and the core never branch on a weapon by hand. An unknown weapon id swings like the
## katana and has no active (duration, cooldown and cost 0).
## Use: const Weapons := preload("res://core/weapons.gd").

const Tuning := preload("res://core/tuning.gd")

## The swap order (weapon_swap_pressed goes to the next one, wrapping).
const IDS: Array[StringName] = [Tuning.WEAPON_BLACK_KATANA, Tuning.WEAPON_DUAL_DAGGER]
## What the weapon's active is called in events and in snapshot.player.weapon_form.
const FORM_BLACK_KATANA_BUFF: StringName = &"black_katana_buff"
const FORM_LIGHTNING: StringName = &"lightning_form"


static func is_known(weapon: StringName) -> bool:
	return IDS.has(weapon)


## The weapon a swap changes to (the same id for an unknown weapon: no swap).
static func next(weapon: StringName) -> StringName:
	var i: int = IDS.find(weapon)
	return weapon if i < 0 else IDS[(i + 1) % IDS.size()]


# --- normal swings ---

static func combo_max(weapon: StringName) -> int:
	return Tuning.DAGGER_COMBO_MAX if weapon == Tuning.WEAPON_DUAL_DAGGER else Tuning.COMBO_MAX


static func windup_ticks(weapon: StringName) -> Array[int]:
	return Tuning.DAGGER_SWING_WINDUP_TICKS if weapon == Tuning.WEAPON_DUAL_DAGGER else Tuning.SWING_WINDUP_TICKS


static func active_ticks(weapon: StringName) -> Array[int]:
	return Tuning.DAGGER_SWING_ACTIVE_TICKS if weapon == Tuning.WEAPON_DUAL_DAGGER else Tuning.SWING_ACTIVE_TICKS


static func recovery_ticks(weapon: StringName) -> Array[int]:
	return Tuning.DAGGER_SWING_RECOVERY_TICKS if weapon == Tuning.WEAPON_DUAL_DAGGER else Tuning.SWING_RECOVERY_TICKS


## Base phase lengths of swing `combo_index` (1-based): [windup, active, recovery], before the attack speed.
static func swing_phases(weapon: StringName, combo_index: int) -> Array[int]:
	var i: int = combo_index - 1
	return [windup_ticks(weapon)[i], active_ticks(weapon)[i], recovery_ticks(weapon)[i]]


static func damage_mults(weapon: StringName) -> Array[float]:
	return Tuning.DAGGER_SWING_DAMAGE_MULT if weapon == Tuning.WEAPON_DUAL_DAGGER else Tuning.SWING_DAMAGE_MULT


static func range_mults(weapon: StringName) -> Array[float]:
	return Tuning.DAGGER_SWING_RANGE_MULT if weapon == Tuning.WEAPON_DUAL_DAGGER else Tuning.SWING_RANGE_MULT


static func edge_per_hit(weapon: StringName) -> float:
	return Tuning.DAGGER_EDGE_PER_HIT if weapon == Tuning.WEAPON_DUAL_DAGGER else Tuning.EDGE_PER_HIT


## True when the last swing of the weapon's combo calls a lightning strike when it connects.
static func has_lightning_finisher(weapon: StringName) -> bool:
	return weapon == Tuning.WEAPON_DUAL_DAGGER


# --- the active (right click) ---

## True when activating the weapon's active also runs the automatic Lightning Barrage (Dual Dagger).
static func has_lightning_barrage(weapon: StringName) -> bool:
	return weapon == Tuning.WEAPON_DUAL_DAGGER


## Slashes in a Lightning Barrage: one per side in LIGHTNING_BLINK_ORDER.
static func barrage_slashes() -> int:
	return Tuning.LIGHTNING_BLINK_ORDER.size()


## Ticks from the activation to the end of a full barrage.
static func barrage_total_ticks() -> int:
	return Tuning.LIGHTNING_BARRAGE_START_DELAY_TICKS + (barrage_slashes() - 1) * Tuning.LIGHTNING_BARRAGE_INTERVAL_TICKS + Tuning.LIGHTNING_BARRAGE_HIT_DELAY_TICKS + Tuning.LIGHTNING_BARRAGE_RECOVERY_TICKS


static func has_active(weapon: StringName) -> bool:
	return is_known(weapon)


static func active_form(weapon: StringName) -> StringName:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return FORM_BLACK_KATANA_BUFF
		Tuning.WEAPON_DUAL_DAGGER:
			return FORM_LIGHTNING
	return &""


static func active_duration(weapon: StringName) -> int:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_BUFF_DURATION_TICKS
		Tuning.WEAPON_DUAL_DAGGER:
			return barrage_total_ticks()  # Lightning Form is only the barrage
	return 0


static func active_cooldown(weapon: StringName) -> int:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_BUFF_COOLDOWN_TICKS
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.LIGHTNING_FORM_COOLDOWN_TICKS
	return 0


static func active_edge_cost(weapon: StringName) -> float:
	match weapon:
		Tuning.WEAPON_BLACK_KATANA:
			return Tuning.BLACK_KATANA_BUFF_EDGE_COST
		Tuning.WEAPON_DUAL_DAGGER:
			return Tuning.LIGHTNING_FORM_EDGE_COST
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
