extends RefCounted
## Cosmetic skill animation only. No hit tests, cooldowns or movement live here.
const Snapshots := preload("res://core/snapshots.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const CombatEffects := preload("res://presentation/arena/combat_effects.gd")
const SKILLS: Array[StringName] = [&"breaking_edge", &"gale_cut", &"moon_cleave"]
const DISSIPATE_TICKS: int = 18
const TRAIL_TICKS: int = 36

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for skill: StringName in SKILLS:
		for frame: int in range(1, 7):
			names.append("fx_aspect2_%s_%d" % [skill, frame])
	return names

static func plan(hero: Snapshots.EntitySnapshot) -> Dictionary:
	if not hero.state.begins_with("skill_") or not hero.skill_id in SKILLS:
		return {}
	# Moon release is a world attack, never an attached melee crescent.
	if hero.skill_id == &"moon_cleave" and hero.state != &"skill_windup":
		return {}
	var durations: Array[int] = ArenaAnimation.skill_durations(hero.skill_id)
	var index: int = 3
	var ticks: int = maxi(0, hero.state_ticks)
	if hero.state == &"skill_windup":
		var hold: int = maxi(1, durations[0] / 4) if hero.skill_id == &"moon_cleave" else maxi(1, durations[0] / 2)
		index = 1 if ticks < hold else 2
	elif hero.state == &"skill_active":
		# All three strikes arrive on the first active tick. Keep the peak there.
		index = 3
	elif hero.state == &"skill_recovery":
		var fade_ticks: int = mini(DISSIPATE_TICKS, durations[2])
		if ticks >= fade_ticks:
			return {}
		# Let the strike read before it dissolves; this never extends damage.
		var peak_hold: int = mini(4, fade_ticks / 3)
		index = 3 if ticks < peak_hold else 4 + mini(2, (ticks - peak_hold) * 3 / maxi(1, fade_ticks - peak_hold))
	var direction: Vector2 = hero.facing.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var reach: float = -10.0 if hero.skill_id == &"gale_cut" and hero.state == &"skill_active" else 16.0
	return {"key": "fx_aspect2_%s_%d" % [hero.skill_id, index], "at": (hero.position - Vector2(0, 12) + direction * reach).round(), "rotation": direction.angle(), "frame": index}


static func _stroke(plan_data: Array[Dictionary], points: PackedVector2Array, color: Color, width: float) -> void:
	CombatEffects.stroke(plan_data, points, color, width)

static func accents(hero: Snapshots.EntitySnapshot, colors: Dictionary) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var effect: Dictionary = plan(hero)
	if effect.is_empty():
		return commands
	var at: Vector2 = effect["at"]
	var direction: Vector2 = Vector2.from_angle(float(effect["rotation"]))
	if hero.skill_id == &"breaking_edge":
		var radius: float = 19.0 if int(effect["frame"]) == 3 else 5.0
		if hero.state == &"skill_windup" or int(effect["frame"]) == 3:
			for angle: float in [-0.75, 0.75]:
				var axis: Vector2 = direction.rotated(angle) * radius
				var cut: PackedVector2Array = PackedVector2Array([at - axis, at + axis])
				_stroke(commands, cut, colors["0"], 5.0)
				_stroke(commands, cut, colors["x"], 3.0)
				_stroke(commands, cut, colors["1"], 1.0)
	elif hero.skill_id == &"moon_cleave" and hero.state == &"skill_windup":
		var duration: int = maxi(1, ArenaAnimation.skill_durations(hero.skill_id)[0])
		var progress: float = clampf(float(hero.state_ticks) / duration, 0.0, 1.0)
		var radius: float = 8.0 + floorf(progress * 8.0)
		var ring: PackedVector2Array = PackedVector2Array()
		for point: int in range(25):
			ring.append(at + Vector2.from_angle(TAU * point / 24.0) * radius)
		_stroke(commands, ring, colors["0"], 4.0)
		_stroke(commands, ring, colors["v"], 2.0)
		for ray: int in range(4):
			var axis: Vector2 = Vector2.from_angle(TAU * ray / 4.0 + float(hero.state_ticks) * 0.08)
			_stroke(commands, PackedVector2Array([at + axis * (radius + 6.0), at + axis * (radius + 1.0)]), colors["p"], 1.0)
	return commands

## Only the path actually travelled is recorded. This is cosmetic, never a hit lane.
static func trail(from: Vector2, to: Vector2, age: int, colors: Dictionary) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	if age < 0 or age >= TRAIL_TICKS or from.is_equal_approx(to):
		return commands
	var axis: PackedVector2Array = PackedVector2Array([from - Vector2(0, 2), to - Vector2(0, 2)])
	_stroke(commands, axis, colors["0"], 7.0)
	_stroke(commands, axis, colors["n"] if age < 18 else colors["l"], 5.0)
	_stroke(commands, axis, colors["p"] if age < 12 else colors["o"], 2.0)
	if age < 10:
		var normal: Vector2 = (to - from).normalized().orthogonal()
		_stroke(commands, PackedVector2Array([to - normal * 4.0, to + normal * 4.0]), colors["o"], 1.0)
	return commands


## Core attack objects own projectile position/lifetime, independently of player state.
static func projectiles(snap: Snapshots.GameSnapshot) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	for attack: Snapshots.SkillAttackSnapshot in snap.skill_attacks:
		if attack.shape != &"projectile" or attack.skill_id != &"moon_cleave":
			continue
		var age: int = maxi(0, snap.tick - attack.start_tick)
		var frame: int = 4 if attack.ticks_left <= 3 else 3 + posmod(age / 4, 2)
		plans.append({"attack_id": attack.id, "key": "fx_aspect2_moon_cleave_%d" % frame, "frame": frame, "at": attack.position, "rotation": attack.direction.angle(), "width": attack.width, "visual_width": maxf(64.0, attack.width), "age": age, "ticks_left": attack.ticks_left, "trail_length": minf(56.0, attack.start.distance_to(attack.position))})
	return plans
