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


class TelegraphSnapshot:
	extends RefCounted
	var id: int = 0
	var owner_id: int = 0
	var attack: StringName = &""
	var kind: StringName = &"red"  # gold = parry it, red = dodge it
	var shape: StringName = &"circle"  # circle, cone, line, ring
	var center: Vector2 = Vector2.ZERO
	var direction: Vector2 = Vector2.RIGHT
	var size: float = 0.0
	var inner_size: float = 0.0  # ring: inner radius, the inside is safe
	var half_angle: float = 0.0
	var width: float = 0.0
	var start_tick: int = 0
	var hit_tick: int = 0
	var end_tick: int = 0


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


class GameSnapshot:
	extends RefCounted
	var tick: int = 0
	var result: StringName = &"playing"  # playing, victory, defeat
	var result_ticks: int = 0  # ticks since the result; keeps counting while the simulation is frozen
	var player: EntitySnapshot = null
	var entities: Array[EntitySnapshot] = []  # everything except the player
	var telegraphs: Array[TelegraphSnapshot] = []
	var hud: HudSnapshot = null
