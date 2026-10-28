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
	return Tuning.MOBS[type]["attack"]


func is_alive() -> bool:
	return state != &"dead"


## Stunned and exposed (takes MOB_EXPOSED_MULT damage).
func is_exposed() -> bool:
	return state == &"crash" or state == &"stagger"


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
	telegraph = null
	strike_left = 0
	attack_done = false
	last_swing = -1
