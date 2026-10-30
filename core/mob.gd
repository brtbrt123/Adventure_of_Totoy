extends RefCounted
## One regular enemy of an exploration scene (core/mob_field.gd runs it). Plain data: the field owns every rule.
## States: idle (not woken), alert (the pack just woke), chase, windup (the warning runs, aim locked), strike (the lunge or charge),
## recover, crash (a charge hit a prop: stunned, exposed), stagger (its gold lunge was parried: stunned, exposed), hurt,
## return (walking home after the hero left the leash), dead (kept for MOB_DEATH_TICKS so presentation can play it).
const Tuning := preload("res://core/tuning.gd")
const Telegraph := preload("res://core/telegraph.gd")

var id: int = 0
var type: StringName = &""
var encounter_id: StringName = &""
var home: Vector2 = Vector2.ZERO
var position: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.LEFT
var hp: int = 0
var max_hp: int = 0
var radius: float = 6.0
var state: StringName = &"idle"
var state_ticks: int = 0
var cooldown: int = 0  # ticks until it may begin an attack
var slot: int = 0  # its place in the encounter (staggers the first attacks)
var telegraph: Telegraph = null  # the warning of the attack in progress
var attack_dir: Vector2 = Vector2.RIGHT  # aim of the attack in progress, locked when the windup began
var strike_left: int = 0  # strike ticks left
var attack_done: bool = false  # the strike already hit the hero (or was parried): once per attack
var last_hit_tick: int = -1000  # the tick the hero's blow last landed (hit flash)
var last_swing: int = -1  # the swing serial of the last blow taken (one hit per swing)
var dragged: bool = false  # held by Reaper's Coil: the field leaves it alone until the coil lets go
var phase: int = 1  # the Stag's second phase (roots) starts after it roars
var attack_index: int = 0  # which attack a many-attack mob tries next
var current_attack: Dictionary = {}  # the attack row in progress (many-attack mobs); empty = the type's one attack
var extra_telegraphs: Array[Telegraph] = []  # the other warnings of a many-site attack (the Stag's eight roots); `telegraph` is the first
var summoner_id: int = 0  # the Stag that summoned this mob (0 = a regular mob)
var regen_acc: float = 0.0  # fractional health owed by the summon regeneration
var regen_ticks: int = 0  # ticks the regeneration has run without a break (it reports once a second)
var regen_pending: int = 0  # health healed since the last mob_healed event
var cast_start: int = -1  # absolute tick the chant began (-1 = not casting)
var cast_release: int = -1  # absolute tick the chant releases
var summon_ready_tick: int = -1  # the next tick a summon may begin (-1 = not set yet)
var chain_next: StringName = &""  # the attack an unparried Cleave follows with (Warden), tried before the rotation
var killed: bool = false  # felled for good (story flag killed_<encounter>_<n>): a reset never revives it


## Fills a fresh mob (home and position, full health, idle).
func setup(p_id: int, p_type: StringName, p_encounter: StringName, p_home: Vector2, p_slot: int) -> void:
	id = p_id
	type = p_type
	encounter_id = p_encounter
	home = p_home
	position = p_home
	slot = p_slot
	radius = float(Tuning.MOBS[p_type]["radius"])
	max_hp = int(Tuning.MOBS[p_type]["hp"])
	hp = max_hp


func stats() -> Dictionary:
	return Tuning.MOBS[type]


func attack_stats() -> Dictionary:
	return current_attack if not current_attack.is_empty() else Tuning.MOBS[type]["attack"]


## The attack rows of a mob with several (the Stag); empty for the others.
func attacks() -> Array:
	return Tuning.MOBS[type].get("attacks", [])


func is_alive() -> bool:
	return state != &"dead"


## Stunned and exposed (takes MOB_EXPOSED_MULT damage).
func is_exposed() -> bool:
	return state == &"crash" or state == &"stagger"


## True for a mob a Stag called (it counts for nothing: no EXP, drop, flag, and not for clearing the encounter).
func is_summoned() -> bool:
	return summoner_id != 0


## Drops the running warning (and the extra ones of a many-site attack).
func clear_telegraph() -> void:
	telegraph = null
	extra_telegraphs.clear()


## Every running warning of this mob, the first one first.
func all_telegraphs() -> Array[Telegraph]:
	var out: Array[Telegraph] = []
	if telegraph != null:
		out.append(telegraph)
		out.append_array(extra_telegraphs)
	return out


## Wearing a guard (the Warden's rune): hits do Tuning.MOBS[type].guard x damage. Gone while it is stunned.
func is_guarded() -> bool:
	return is_alive() and Tuning.MOBS[type].has("guard") and not is_exposed()


## In the middle of an attack (windup or strike): counts against MOB_MAX_ATTACKERS.
func is_attacking() -> bool:
	return state == &"windup" or state == &"strike"


func set_state(new_state: StringName) -> void:
	if state != new_state:
		state = new_state
		state_ticks = 0


## Back to its place, whole, and not woken.
func reset() -> void:
	position = home
	hp = max_hp
	state = &"idle"
	state_ticks = 0
	cooldown = 0
	clear_telegraph()
	strike_left = 0
	attack_done = false
	last_swing = -1
	dragged = false
	phase = 1
	attack_index = 0
	current_attack = {}
	chain_next = &""
	regen_acc = 0.0
	regen_ticks = 0
	regen_pending = 0
	cast_start = -1
	cast_release = -1
	summon_ready_tick = -1
