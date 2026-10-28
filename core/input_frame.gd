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
var skill_pressed: int = 0  # slot 1-3 pressed this tick (Z/X/C), else 0: triggers the aspect equipped in that slot
var aspect_equip: StringName = &""  # equip this aspect (an Aspects.ALL id) into aspect_equip_slot this tick (the character menu); empty = none. Idle or walk only, never while a weapon buff/form runs; no lockout
var aspect_equip_slot: int = 0  # 1-3, the slot for aspect_equip
var interact_pressed: bool = false  # also the dialogue's "next line"
var skip_pressed: bool = false  # ends a running dialogue (ignored otherwise)
var use_herb_pressed: bool = false  # the older name of use_item_slot = 1 (the herb); still honoured, new code sends use_item_slot
var use_item_slot: int = 0  # exploration only: item slot 1 or 2 pressed this tick (keys 1 and 2), else 0. Slot 1 is the herb (heals Tuning.HERB_HEAL hp); slot 2 is locked until a flag unlocks it
