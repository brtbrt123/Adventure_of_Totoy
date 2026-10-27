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
const WEAPON_SWAPPED: StringName = &"weapon_swapped"
const LIGHTNING_STRIKE: StringName = &"lightning_strike"
const LIGHTNING_BLINK: StringName = &"lightning_blink"
const LIGHTNING_BARRAGE_STARTED: StringName = &"lightning_barrage_started"
const LIGHTNING_BARRAGE_ENDED: StringName = &"lightning_barrage_ended"
const REAPER_COIL_STARTED: StringName = &"reaper_coil_started"
const REAPER_COIL_HOOKED: StringName = &"reaper_coil_hooked"
const REAPER_COIL_MISSED: StringName = &"reaper_coil_missed"
const REAPER_COIL_DRAG: StringName = &"reaper_coil_drag"
const REAPER_COIL_SPIN: StringName = &"reaper_coil_spin"
const REAPER_COIL_ENDED: StringName = &"reaper_coil_ended"
const ASPECT_EQUIPPED: StringName = &"aspect_equipped"
const LANTERN_PLACED: StringName = &"lantern_placed"
const LANTERN_PULSE: StringName = &"lantern_pulse"
const LANTERN_EXPIRED: StringName = &"lantern_expired"
const PHANTOM_CUT_STARTED: StringName = &"phantom_cut_started"
const PHANTOM_CUT_ENDED: StringName = &"phantom_cut_ended"
const PHANTOM_ECHO: StringName = &"phantom_echo"
const SPRINT_STARTED: StringName = &"sprint_started"
const SPRINT_ENDED: StringName = &"sprint_ended"
const ECHO_PLACED: StringName = &"echo_placed"
const ECHO_RECALL: StringName = &"echo_recall"
const ECHO_EXPIRED: StringName = &"echo_expired"
const WARD_RAISED: StringName = &"ward_raised"
const WARD_BLOCKED: StringName = &"ward_blocked"
const WARD_RELEASED: StringName = &"ward_released"
const SKILL_STARTED: StringName = &"skill_started"
const SKILL_RELEASED: StringName = &"skill_released"
const DASH_READY: StringName = &"dash_ready"
const DAMAGE_TAKEN: StringName = &"damage_taken"
const ENTITY_DIED: StringName = &"entity_died"
const BOSS_PHASE_CHANGED: StringName = &"boss_phase_changed"
const GAME_RESULT: StringName = &"game_result"
# exploration (core/explore_core.gd)
const SCENE_EXIT: StringName = &"scene_exit"
const CHECKPOINT: StringName = &"checkpoint"
const INTERACT: StringName = &"interact"
const GATE_CHANGED: StringName = &"gate_changed"
## A lantern switch was lit: data {scene, switch_id, lit (every lit switch id), all_lit}.
const SWITCH_LIT: StringName = &"switch_lit"

var type: StringName = &""
var tick: int = 0
var data: Dictionary = {}


func _init(p_type: StringName = &"", p_tick: int = 0, p_data: Dictionary = {}) -> void:
	type = p_type
	tick = p_tick
	data = p_data
