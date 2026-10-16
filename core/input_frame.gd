extends RefCounted
## One tick of player intent, built by presentation (keyboard/controller mapping lives there).

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var attack_held: bool = false
var parry_pressed: bool = false
var dash_pressed: bool = false
var weapon_active_pressed: bool = false  # right click: the equipped weapon's active (Black Katana buff)
var skill_pressed: int = 0
var interact_pressed: bool = false
