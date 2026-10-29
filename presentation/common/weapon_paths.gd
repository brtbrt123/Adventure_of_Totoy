extends RefCounted
## Pose-fitted regular-swing trails. No scene, target or boss dependency: all hero renderers use this selector.
## The actor's actual selected pose chooses active art; recovery dissolves briefly, then stops. No hit/range rules.
const Snapshots := preload("res://core/snapshots.gd")
const SETS: Dictionary = {"hero2": "katana", "totoy_dagger": "daggers", "totoy_lightning": "daggers", "totoy_scythe": "scythe"}
const RECOVERY_TICKS: int = 6


static func key(actor: Snapshots.EntitySnapshot, pose: String) -> String:
	if actor == null or actor.state not in [&"attack_active", &"attack_recovery"]:
		return ""
	var split: PackedStringArray = pose.split("_attack")
	if split.size() != 2 or not SETS.has(split[0]):
		return ""  # includes the unarmed set and an interrupted/hurt/skill pose
	var parts: PackedStringArray = split[1].split("_")
	if parts.size() != 3 or parts[1] != "right":
		return ""
	var swing: int = int(parts[0])
	var stage: int = int(parts[2])
	if swing < 1 or swing > (4 if SETS[split[0]] == "daggers" else 3):
		return ""
	if actor.state == &"attack_active":
		if stage not in [3, 4]:
			return ""
		stage -= 2
	else:
		if stage not in [5, 6] or actor.state_ticks < 0 or actor.state_ticks >= RECOVERY_TICKS:
			return ""
		stage = 3 + mini(1, actor.state_ticks / 3)
	return "fx_weapon_path_%s_attack%d_%d" % [SETS[split[0]], swing, stage]
