extends RefCounted
## Per-aspect data, looked up by aspect id (the Aspects are the skills in the Z/X/C slots). The numbers live in
## core/tuning.gd; this file only picks them, so the player, the core and presentation never branch by hand.
## Use: const Aspects := preload("res://core/aspects.gd").

const Tuning := preload("res://core/tuning.gd")

const BREAKING_EDGE: StringName = &"breaking_edge"
const GALE_CUT: StringName = &"gale_cut"
const MOON_CLEAVE: StringName = &"moon_cleave"
const SPIRIT_LANTERN: StringName = &"spirit_lantern"
const PHANTOM_CUT: StringName = &"phantom_cut"
const SPRINT: StringName = &"sprint"
const ECHO_STEP: StringName = &"echo_step"
const STONE_WARD: StringName = &"stone_ward"

## Every aspect the player owns, in the menu's order.
const ALL: Array[StringName] = [BREAKING_EDGE, GALE_CUT, MOON_CLEAVE, SPIRIT_LANTERN, PHANTOM_CUT, SPRINT, ECHO_STEP, STONE_WARD]
## What a new fight (and a save without the field) slots into 1, 2, 3: the old fixed set.
const DEFAULT_EQUIPPED: Array[StringName] = [BREAKING_EDGE, GALE_CUT, MOON_CLEAVE]

## A skill is used like a skill (most run skill_windup -> skill_active -> skill_recovery; Stone Ward has its own `ward`
## state; Echo Step is a free action that only places an anchor); a buff is a free action (no state change) with a
## timed effect.
const KIND_SKILL: StringName = &"skill"
const KIND_BUFF: StringName = &"buff"


static func is_known(aspect: StringName) -> bool:
	return ALL.has(aspect)


## True for a list of exactly SKILL_COUNT different known aspects.
static func is_valid_loadout(aspects: Array) -> bool:
	if aspects.size() != Tuning.SKILL_COUNT:
		return false
	var seen: Array[StringName] = []
	for value: Variant in aspects:
		if not (value is StringName or value is String):
			return false
		var aspect: StringName = StringName(value)
		if not is_known(aspect) or seen.has(aspect):
			return false
		seen.append(aspect)
	return true


static func display_name(aspect: StringName) -> String:
	match aspect:
		BREAKING_EDGE:
			return "Breaking Edge"
		GALE_CUT:
			return "Gale Cut"
		MOON_CLEAVE:
			return "Moon Cleave"
		SPIRIT_LANTERN:
			return "Spirit Lantern"
		PHANTOM_CUT:
			return "Phantom Cut"
		SPRINT:
			return "Sprint"
		ECHO_STEP:
			return "Echo Step"
		STONE_WARD:
			return "Stone Ward"
	return ""


static func kind(aspect: StringName) -> StringName:
	return KIND_BUFF if aspect == PHANTOM_CUT or aspect == SPRINT else KIND_SKILL


## True for the aspects used as a free action on the press (no state change, any state but dead, the barrage and the
## coil): Phantom Cut, Sprint, Echo Step. The others go through the skill rules (idle, walk or a swing's recovery).
static func is_free_action(aspect: StringName) -> bool:
	return aspect == PHANTOM_CUT or aspect == SPRINT or aspect == ECHO_STEP


static func edge_cost(aspect: StringName) -> float:
	match aspect:
		BREAKING_EDGE:
			return Tuning.BREAKING_EDGE_EDGE_COST
		GALE_CUT:
			return Tuning.GALE_CUT_EDGE_COST
		MOON_CLEAVE:
			return Tuning.MOON_CLEAVE_EDGE_COST
		SPIRIT_LANTERN:
			return Tuning.SPIRIT_LANTERN_EDGE_COST
		PHANTOM_CUT:
			return Tuning.PHANTOM_CUT_EDGE_COST
		SPRINT:
			return Tuning.SPRINT_EDGE_COST
		ECHO_STEP:
			return Tuning.ECHO_STEP_EDGE_COST
		STONE_WARD:
			return Tuning.STONE_WARD_EDGE_COST
	return 0.0


## The full cooldown in ticks (Breaking Edge has none: it is gated by the retaliation window instead).
static func cooldown(aspect: StringName) -> int:
	match aspect:
		BREAKING_EDGE:
			return Tuning.BREAKING_EDGE_COOLDOWN_TICKS
		GALE_CUT:
			return Tuning.GALE_CUT_COOLDOWN_TICKS
		MOON_CLEAVE:
			return Tuning.MOON_CLEAVE_COOLDOWN_TICKS
		SPIRIT_LANTERN:
			return Tuning.SPIRIT_LANTERN_COOLDOWN_TICKS
		PHANTOM_CUT:
			return Tuning.PHANTOM_CUT_COOLDOWN_TICKS
		SPRINT:
			return Tuning.SPRINT_COOLDOWN_TICKS
		ECHO_STEP:
			return Tuning.ECHO_STEP_COOLDOWN_TICKS
		STONE_WARD:
			return Tuning.STONE_WARD_COOLDOWN_TICKS
	return 0


## How long the aspect's effect runs once started (lantern life, phantom / sprint buff, the echo until the recall, the
## ward), 0 for the instant skills.
static func duration(aspect: StringName) -> int:
	match aspect:
		SPIRIT_LANTERN:
			return Tuning.SPIRIT_LANTERN_DURATION_TICKS
		PHANTOM_CUT:
			return Tuning.PHANTOM_CUT_DURATION_TICKS
		SPRINT:
			return Tuning.SPRINT_DURATION_TICKS
		ECHO_STEP:
			return Tuning.ECHO_STEP_DELAY_TICKS
		STONE_WARD:
			return Tuning.STONE_WARD_DURATION_TICKS
	return 0


## True when the aspect can only be used inside the retaliation window after a successful parry.
static func needs_retaliation(aspect: StringName) -> bool:
	return aspect == BREAKING_EDGE
