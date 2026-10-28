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
## Conversations (core/dialogue_book.gd): data {scene, npc_id, dialogue_id}; `dialogue_advanced` adds index (the line now shown);
## `dialogue_ended` adds skipped and flags_set; `flag_set` is {flag, flags (all set flags)}.
const DIALOGUE_STARTED: StringName = &"dialogue_started"
const DIALOGUE_ADVANCED: StringName = &"dialogue_advanced"
const DIALOGUE_ENDED: StringName = &"dialogue_ended"
const FLAG_SET: StringName = &"flag_set"
## The hero received something for good (a dialogue grant, core/dialogue_book.gd): data {scene, reward_id, kind (weapon or item),
## item_id, name, quantity, source (the NPC)}. Emitted once, on the tick the flag that records the grant is first set, never when a
## save is loaded and never again when he talks to the NPC again.
const ITEM_RECEIVED: StringName = &"item_received"
## The training post (core/training_yard.gd): `training_post_hit` {scene, object_id, hits, combo_index, position}; `training_hero_hit` {scene,
## kind (gold or red), position} (a practice hit, no damage); `training_dodged` {scene, position}. A parry uses `parry_succeeded` (attacker_id 100).
const TRAINING_POST_HIT: StringName = &"training_post_hit"
const TRAINING_HERO_HIT: StringName = &"training_hero_hit"
const TRAINING_DODGED: StringName = &"training_dodged"
## A lantern switch was lit: data {scene, switch_id, lit (every lit switch id), all_lit}.
const SWITCH_LIT: StringName = &"switch_lit"

var type: StringName = &""
var tick: int = 0
var data: Dictionary = {}


func _init(p_type: StringName = &"", p_tick: int = 0, p_data: Dictionary = {}) -> void:
	type = p_type
	tick = p_tick
	data = p_data
## Mobs (core/mob_field.gd). `encounter_started` {scene, encounter_id}; `mob_alerted` {scene, mob_id, type, encounter_id, position} (the pack
## woke); `mob_staggered` {scene, mob_id, reason (parry or crash), position}; `mob_defeated` {scene, mob_id, type, encounter_id, position};
## `mob_leashed` {scene, mob_id, encounter_id} (it gave up and walks home); `encounter_reset` {scene, encounter_id, reason (leash or defeat)};
## `encounter_cleared` {scene, encounter_id, reward_id}. A mob's warning is `attack_telegraphed` (owner_id = mob id); the hero's blows are
## `attack_hit` {attacker_id, target_id (mob id), damage, kind (normal or counter), position, combo_index, weapon_id}; his wounds are
## `damage_taken` {entity_id, amount, source_id (mob id)}; a parry is `parry_succeeded` {attacker_id (mob id), ...} as at the post.
const ENCOUNTER_STARTED: StringName = &"encounter_started"
const MOB_ALERTED: StringName = &"mob_alerted"
const MOB_STAGGERED: StringName = &"mob_staggered"
const MOB_DEFEATED: StringName = &"mob_defeated"
const MOB_LEASHED: StringName = &"mob_leashed"
const ENCOUNTER_RESET: StringName = &"encounter_reset"
const ENCOUNTER_CLEARED: StringName = &"encounter_cleared"
## The hero fell (`hero_defeated` {scene, position}) and, HERO_DEFEAT_TICKS later, stood up at the last checkpoint with full health
## (`hero_respawned` {scene, checkpoint_id, position}); every uncleared encounter of the scene is whole again.
const HERO_DEFEATED: StringName = &"hero_defeated"
const HERO_RESPAWNED: StringName = &"hero_respawned"
## `exp_gained` {scene, amount, source (mob id), level, exp (inside the level), exp_to_next}; `level_up` {scene, level, max_hp} (the hero is healed
## to full); `mob_dropped` {scene, mob_id, item_id, position} (a felled mob's drop, always followed by its `item_received`).
const EXP_GAINED: StringName = &"exp_gained"
const LEVEL_UP: StringName = &"level_up"
const MOB_DROPPED: StringName = &"mob_dropped"
## An item was used: {scene, item_id, healed, hp, count (left)}.
const ITEM_USED: StringName = &"item_used"
