extends RefCounted
## One tick of player intent, built by presentation (keyboard/controller mapping lives there).

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var attack_held: bool = false
var parry_pressed: bool = false
var dash_pressed: bool = false
var weapon_active_pressed: bool = false  # right click: the equipped weapon's active (Black Katana buff / Lightning Form / Reaper's Coil, aimed by `aim`)
var weapon_equip: StringName = &""  # equip exactly this weapon this tick (the character menu's request); empty = none. Same rules as the old Q swap: idle or walk only, no active running, after the swap lockout
var skill_pressed: int = 0
var interact_pressed: bool = false
