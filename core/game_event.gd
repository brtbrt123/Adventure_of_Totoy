extends RefCounted
## A fact that already happened in the core. Presentation reacts with sound, particles, shake and UI.
## Payload keys per type are listed in docs/architecture.md.

const ATTACK_TELEGRAPHED: StringName = &"attack_telegraphed"
const ATTACK_HIT: StringName = &"attack_hit"
const PARRY_SUCCEEDED: StringName = &"parry_succeeded"
const PARRY_FAILED: StringName = &"parry_failed"
const POSTURE_BROKEN: StringName = &"posture_broken"
const COUNTER_WINDOW_OPENED: StringName = &"counter_window_opened"
const COUNTER_WINDOW_CLOSED: StringName = &"counter_window_closed"
const DASH_STARTED: StringName = &"dash_started"
const WEAPON_BUFF_STARTED: StringName = &"weapon_buff_started"
const WEAPON_BUFF_ENDED: StringName = &"weapon_buff_ended"
const SKILL_STARTED: StringName = &"skill_started"
const SKILL_RELEASED: StringName = &"skill_released"
const DASH_READY: StringName = &"dash_ready"
const DAMAGE_TAKEN: StringName = &"damage_taken"
const ENTITY_DIED: StringName = &"entity_died"
const BOSS_PHASE_CHANGED: StringName = &"boss_phase_changed"
const GAME_RESULT: StringName = &"game_result"

var type: StringName = &""
var tick: int = 0
var data: Dictionary = {}


func _init(p_type: StringName = &"", p_tick: int = 0, p_data: Dictionary = {}) -> void:
	type = p_type
	tick = p_tick
	data = p_data
