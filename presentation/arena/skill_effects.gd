extends RefCounted
## Cosmetic skill animation only. No hit tests, cooldowns or movement live here.
const Snapshots := preload("res://core/snapshots.gd")
const ArenaAnimation := preload("res://presentation/arena/animation.gd")
const SKILLS: Array[StringName] = [&"breaking_edge", &"gale_cut", &"moon_cleave"]
const DISSIPATE_TICKS: int = 12

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for skill: StringName in SKILLS:
		for frame: int in range(1, 7):
			names.append("fx_aspect_%s_%d" % [skill, frame])
	return names

static func plan(hero: Snapshots.EntitySnapshot) -> Dictionary:
	if not hero.state.begins_with("skill_") or not hero.skill_id in SKILLS:
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
		index = 4 + mini(2, ticks * 3 / maxi(1, fade_ticks))
	var direction: Vector2 = hero.facing.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var reach: float = -10.0 if hero.skill_id == &"gale_cut" and hero.state == &"skill_windup" else 16.0
	return {"key": "fx_aspect_%s_%d" % [hero.skill_id, index], "at": (hero.position - Vector2(0, 12) + direction * reach).round(), "rotation": direction.angle(), "frame": index}
