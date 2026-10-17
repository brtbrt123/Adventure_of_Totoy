extends RefCounted
## Read-only views the core hands to presentation each tick. Presentation must not mutate them or keep
## references to core objects. Use: const Snapshots := preload("res://core/snapshots.gd").


class EntitySnapshot:
	extends RefCounted
	var id: int = 0
	var visual_id: StringName = &""  # maps to art, for example &"totoy", &"mossbound_colossus"
	var state: StringName = &"idle"
	var state_ticks: int = 0
	var position: Vector2 = Vector2.ZERO
	var facing: Vector2 = Vector2.DOWN
	var hp: int = 0
	var max_hp: int = 0
	var posture: float = 0.0
	var posture_max: float = 0.0
	var invulnerable: bool = false
	var combo_index: int = 0  # player only (1-3, see docs/architecture.md); 0 for other entities
	var weapon_id: StringName = &""  # player only: the equipped weapon, e.g. &"black_katana"
	var weapon_buff_active: bool = false  # player only
	var weapon_buff_ticks_left: int = 0  # player only: ticks of buff left, 0 when not active
	var attack_speed_mult: float = 1.0  # player only: the speed of the swing in progress (locked at its start), else the current buff speed
	var skill_id: StringName = &""  # player only: the skill in progress during skill_* states, else empty


class TelegraphSnapshot:
	extends RefCounted
	var id: int = 0
	var owner_id: int = 0
	var attack: StringName = &""
	var kind: StringName = &"red"  # gold = parry it, red = dodge it
	var shape: StringName = &"circle"  # circle, cone, line, ring
	var center: Vector2 = Vector2.ZERO
	var muzzle: Vector2 = Vector2.ZERO  # where the attack leaves the boss (red_shards: the chest core, equal to center)
	var direction: Vector2 = Vector2.RIGHT
	var size: float = 0.0
	var inner_size: float = 0.0  # ring: inner radius, the inside is safe
	var half_angle: float = 0.0
	var width: float = 0.0
	var start_tick: int = 0
	var hit_tick: int = 0
	var end_tick: int = 0


class SkillAttackSnapshot:
	extends RefCounted
	## A skill attack that is live right now: a melee arc, a dash lane or a travelling projectile.
	var id: int = 0  # the same id appears in the skill_released and attack_hit events
	var owner_id: int = 0
	var skill_id: StringName = &""
	var shape: StringName = &"arc"  # arc (melee), lane (dash corridor), projectile
	var position: Vector2 = Vector2.ZERO  # arc: the player; lane: the dash head (the player); projectile: its centre now
	var direction: Vector2 = Vector2.RIGHT
	var start: Vector2 = Vector2.ZERO  # lane/projectile: where it began
	var end: Vector2 = Vector2.ZERO  # lane/projectile: where it ends if nothing shortens it
	var width: float = 0.0  # lane width / projectile width
	var size: float = 0.0  # arc: reach in pixels
	var half_angle: float = 0.0  # arc: half the arc, radians
	var start_tick: int = 0
	var end_tick: int = 0  # last tick it can hit (projectile: when it runs out of travel)
	var ticks_left: int = 0
	var hit_target_ids: Array[int] = []


class HudSnapshot:
	extends RefCounted
	var player_hp: int = 0
	var player_max_hp: int = 0
	var dash_cooldown_ticks: int = 0
	var dash_cooldown_max: int = 0
	var edge: float = 0.0
	var edge_max: float = 0.0
	var boss_hp: int = 0
	var boss_max_hp: int = 0
	var boss_posture: float = 0.0
	var boss_posture_max: float = 0.0
	var counter_window_ticks_left: int = 0
	var skill_cooldown_ticks: Array[int] = [0, 0, 0]  # ticks left per skill 1-3
	var weapon_buff_duration: int = 0  # full duration of the weapon buff (0 if the weapon has none)
	var weapon_buff_cooldown_ticks: int = 0  # ticks until the weapon active can be used again
	var weapon_buff_cooldown_max: int = 0
	var weapon_buff_edge_cost: float = 0.0
	var retaliate_ticks_left: int = 0  # Breaking Edge: ticks left after a successful parry


class GameSnapshot:
	extends RefCounted
	var tick: int = 0
	var result: StringName = &"playing"  # playing, victory, defeat
	var result_ticks: int = 0  # ticks since the result; keeps counting while the simulation is frozen
	var player: EntitySnapshot = null
	var entities: Array[EntitySnapshot] = []  # everything except the player
	var telegraphs: Array[TelegraphSnapshot] = []
	var skill_attacks: Array[SkillAttackSnapshot] = []
	var hud: HudSnapshot = null
