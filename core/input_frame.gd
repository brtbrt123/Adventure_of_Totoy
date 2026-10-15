extends RefCounted
## One tick of player intent, built by presentation (keyboard/controller mapping lives there).

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var attack_pressed: bool = false
var attack_held: bool = false
var parry_pressed: bool = false
var dash_pressed: bool = false
var skill_pressed: int = 0
var interact_pressed: bool = false
